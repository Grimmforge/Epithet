-- =============================================================================
-- Epithet — Addon Core
-- Initialisation, slash commands, minimap button, event wiring, persistence.
-- =============================================================================
local ADDON_NAME, ns = ...

local Epithet = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME)
ns.Epithet = Epithet

local C_Timer = C_Timer

-- ---------------------------------------------------------------------------
-- Saved variable defaults
-- ---------------------------------------------------------------------------
local DB_DEFAULTS = {
    profile = {
        filters = {
            search   = "",
            status   = "all",
            rarity   = {},
            type     = {},
            exp      = {},
            cat      = {},
            kind     = {},
            faction  = {},
            hideUnobtainable   = false,
            hideTimeSensitive  = false,
            favouritesOnly     = false,
        },
        favourites = {},          -- set keyed by lowercase title text: { ["the explorer"] = true }
        sort = "collectedFirst",  -- "collectedFirst" | "expansion" | "alphabetical" | "quality" | "category"
        obtainableOnly = false,   -- toggle: show earned % against obtainable pool only
        social = {
            enabled = true,
            layout = "portrait",
            animatedPortrait = true,
            fadeNameplates = false,
            fadeDuration = 4.0,
            previewFunnyTitle = false,
            spotNotify = true,
            achievementNotify = true,
            achievementNotifyMode = "full",
            achievementAlertAnchor = "uiparent",
            spotLogScope = "spotted",
            spotLogView = "grid",
            hideInCombat = false,
            hideInGroup = false,
            targetAnchorX = 0,
            targetAnchorY = -120,
            targetUnlock = false,
        },
        framePoint = nil,         -- {point, relPoint, x, y}
        scale = 1.0,
        minimap = { hide = false },
    },
}

-- ---------------------------------------------------------------------------
-- Print helper
-- ---------------------------------------------------------------------------
local function Print(msg)
    print("|cffe8c873Epithet:|r " .. msg)
end
ns.Print = Print

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------
function Epithet:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("EpithetDB", DB_DEFAULTS, true)

    -- Sanitise saved filters: search is ephemeral (don't persist across sessions)
    -- and ensure new facet tables exist for profiles saved before they were added.
    local f = self.db.profile.filters
    f.search = ""
    f.cat = f.cat or {}
    f.kind = f.kind or {}
    f.faction = f.faction or {}
    local s = self.db.profile.social or {}
    s.enabled = (s.enabled ~= false)
    s.targetAnchorPoint = nil -- legacy field removed; target is always anchored below target frame.
    if type(s.layout) ~= "string" then s.layout = "portrait" end
    if ns.SocialLayer and ns.SocialLayer.IsValidLayoutKey and not ns.SocialLayer:IsValidLayoutKey(s.layout) then
        if ns.SocialLayer.GetDefaultLayoutKey then
            s.layout = ns.SocialLayer:GetDefaultLayoutKey()
        else
            s.layout = "portrait"
        end
    end
    if type(s.targetAnchorX) ~= "number" then s.targetAnchorX = 0 end
    if type(s.targetAnchorY) ~= "number" then s.targetAnchorY = -120 end
    s.animatedPortrait = (s.animatedPortrait ~= false)
    s.fadeNameplates = (s.fadeNameplates == true)
    local fadeSeconds = tonumber(s.fadeDuration)
    if not fadeSeconds then fadeSeconds = 5.0 end
    if fadeSeconds < 0.5 then fadeSeconds = 0.5 end
    if fadeSeconds > 20.0 then fadeSeconds = 20.0 end
    s.fadeDuration = fadeSeconds
    s.previewFunnyTitle = (s.previewFunnyTitle == true)
    s.spotNotify = (s.spotNotify ~= false)
    local mode = s.achievementNotifyMode
    if mode ~= "full" and mode ~= "silent" and mode ~= "off" then
        if s.achievementNotify == false then
            mode = "off"
        else
            mode = "full"
        end
    end
    s.achievementNotifyMode = mode
    s.achievementNotify = (mode ~= "off")
    if s.achievementAlertAnchor ~= "uiparent" and s.achievementAlertAnchor ~= "alertframe" then
        s.achievementAlertAnchor = "uiparent"
    end
    if s.spotLogScope ~= "spotted" and s.spotLogScope ~= "remaining" then
        s.spotLogScope = "spotted"
    end
    if s.spotLogView ~= "list" and s.spotLogView ~= "grid" then
        s.spotLogView = "grid"
    end
    s.hideInCombat = (s.hideInCombat == true)
    s.hideInGroup = (s.hideInGroup == true)
    s.targetUnlock = false
    self.db.profile.social = s

    -- Slash commands
    SLASH_EPITHET1 = "/epithet"
    SLASH_EPITHET2 = "/titles"
    SlashCmdList["EPITHET"] = function(input)
        self:HandleSlash(input)
    end

    -- Minimap button
    self:SetupMinimapButton()

    if ns.SpottingLog and ns.SpottingLog.Init then
        ns.SpottingLog:Init()
    end
    if ns.SpottingAchievements and ns.SpottingAchievements.Init then
        ns.SpottingAchievements:Init()
    end
    if ns.WhatsNew and ns.WhatsNew.Init then
        ns.WhatsNew:Init()
    end

    if ns.Settings and ns.Settings.Init then
        ns.Settings:Init()
    end

    if ns.SocialLayer and ns.SocialLayer:Init() then
        ns.SocialLayer:ApplySettings()
    end
end

function Epithet:OnEnable()
    -- Register events via a lightweight frame
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if self[event] then
            self[event](self, ...)
        end
    end)
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("ACHIEVEMENT_EARNED")
    -- Only "player"/"target" are ever handled below; let the client filter
    -- delivery instead of receiving every unit's update and checking in Lua.
    self.eventFrame:RegisterUnitEvent("UNIT_NAME_UPDATE", "player", "target")
    self.eventFrame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "player", "target")
    self.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

    if ns.SocialLayer and ns.SocialLayer:Init() then
        ns.SocialLayer:ApplySettings()
    end

    if ns.SpottingCapture and ns.SpottingCapture.Init then
        ns.SpottingCapture:Init()
    end
end

-- ---------------------------------------------------------------------------
-- Event handlers
-- ---------------------------------------------------------------------------
function Epithet:PLAYER_ENTERING_WORLD()
    ns.TitleData.dirty = true
    ns.TitleData:Scan()
    if ns.TitleIndex and ns.TitleIndex.Build then
        ns.TitleIndex:Build()
    end
    if ns.MainFrame and ns.MainFrame:IsShown() then
        ns.MainFrame:FullRefresh()
    end

    if ns.WhatsNew and ns.WhatsNew.ShowForCurrentVersionIfNeeded then
        ns.WhatsNew:ShowForCurrentVersionIfNeeded()
    end
end

function Epithet:ACHIEVEMENT_EARNED()
    -- A new title may have unlocked
    ns.TitleData.dirty = true
    ns.TitleData:Scan()
    if ns.TitleIndex and ns.TitleIndex.Reset then
        -- Invalidate the name-fragment index so a newly earned title becomes
        -- resolvable by SpottingCapture/SocialLayer without a relog.
        ns.TitleIndex:Reset()
    end
    if ns.MainFrame and ns.MainFrame:IsShown() then
        ns.MainFrame:FullRefresh()
    end
end

function Epithet:UNIT_NAME_UPDATE(unit)
    if unit == "player" then
        ns.TitleData:RefreshActiveState()
        if ns.MainFrame and ns.MainFrame:IsShown() then
            ns.MainFrame:FullRefresh()
        end
    end
    if ns.SocialLayer then
        ns.SocialLayer:HandleUnitUpdate(unit)
    end
end

function Epithet:UNIT_PORTRAIT_UPDATE(unit)
    if not ns.SocialLayer then return end
    if unit == "target" or unit == "player" then
        ns.SocialLayer:RefreshTargetFrame()
    end
end

function Epithet:PLAYER_TARGET_CHANGED()
    if ns.SocialLayer then
        ns.SocialLayer:HandleTargetChanged()
    end
end

function Epithet:PLAYER_REGEN_DISABLED()
    if ns.SocialLayer then
        ns.SocialLayer:RefreshTargetFrame()
    end
end

function Epithet:PLAYER_REGEN_ENABLED()
    if ns.SocialLayer then
        ns.SocialLayer:RefreshTargetFrame()
    end
end

-- GROUP_ROSTER_UPDATE can fire in rapid bursts in large raids; debounce so a
-- burst of N events results in one refresh instead of N.
local GROUP_ROSTER_DEBOUNCE = 0.2

function Epithet:GROUP_ROSTER_UPDATE()
    if not ns.SocialLayer then return end
    if self.groupRosterRefreshPending then return end
    self.groupRosterRefreshPending = true
    C_Timer.After(GROUP_ROSTER_DEBOUNCE, function()
        self.groupRosterRefreshPending = false
        if ns.SocialLayer then
            ns.SocialLayer:RefreshTargetFrame()
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Slash command handler
-- ---------------------------------------------------------------------------
function Epithet:HandleSlash(input)
    local cmd = input and input:trim():lower() or ""
    local adminArgs = cmd:match("^admin%s*(.-)%s*$")
    if adminArgs then
        local admin = ns.AdminCommands
        if admin and type(admin.HandleSlash) == "function" then
            local ok, handled, message = pcall(admin.HandleSlash, admin, adminArgs, Print)
            if not ok then
                Print("Admin command failed: " .. tostring(handled))
                return
            end
            if handled then
                if message and message ~= "" then
                    Print(message)
                end
                return
            end
            Print("Unknown admin command. Try /epithet admin achievement")
            return
        end

        Print("Admin commands are not available in this build.")
        return
    end

    if cmd == "minimap" then
        local hide = not self.db.profile.minimap.hide
        self.db.profile.minimap.hide = hide
        local LDBIcon = LibStub("LibDBIcon-1.0", true)
        if LDBIcon then
            if hide then
                LDBIcon:Hide("Epithet")
                Print(ns.L["MINIMAP_HIDDEN"])
            else
                LDBIcon:Show("Epithet")
                Print(ns.L["MINIMAP_SHOWN"])
            end
        end
        return
    elseif cmd == "scan" then
        ns.TitleData.dirty = true
        ns.TitleData:Scan()
        Print("Title scan complete: " .. (ns.TitleData.earnedCount or 0) .. " / " .. (ns.TitleData.totalCount or 0))
        return
    elseif cmd == "debug" then
        -- Dump the raw GetTitleName format + classified type for the first
        -- known titles, to verify prefix/suffix detection in this client.
        local shown = 0
        for id = 1, (GetNumTitles and GetNumTitles() or 0) do
            local raw = GetTitleName and GetTitleName(id)
            if raw and raw ~= "" then
                local rec = ns.TitleData.GetRecord and ns.TitleData:GetRecord(id)
                local t = rec and rec.type or "?"
                Print(string.format("|cffe8c873[%d]|r '%s'  ->  %s", id, raw:gsub("|", "||"), t))
                shown = shown + 1
                if shown >= 25 then break end
            end
        end
        Print("Showed " .. shown .. " raw titles. (Run /epithet scan first if empty.)")
        return
    elseif cmd == "whatsnew" then
        if ns.WhatsNew and ns.WhatsNew.Show then
            ns.WhatsNew:Show(ns.WhatsNew:GetCurrentVersion())
        end
        return
    end

    -- Default: toggle window
    if ns.MainFrame then
        ns.MainFrame:Toggle()
    end
end

-- ---------------------------------------------------------------------------
-- Minimap button (LibDataBroker + LibDBIcon)
-- ---------------------------------------------------------------------------
function Epithet:SetupMinimapButton()
    local LDB = LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    if not LDB or not LDBIcon then return end

    local L = ns.L
    local launcher = LDB:NewDataObject("Epithet", {
        type = "launcher",
        text = "Epithet",
        icon = "Interface\\AddOns\\Epithet\\icons\\logo\\epithet-wax-seal-red-minimap-32",
        OnClick = function(_, button)
            if button == "LeftButton" then
                if ns.MainFrame then
                    ns.MainFrame:Toggle()
                end
            elseif button == "RightButton" then
                self.db.profile.minimap.hide = true
                LDBIcon:Hide("Epithet")
                Print(L["MINIMAP_HIDDEN"])
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(L["MINIMAP_TOOLTIP_TITLE"], 1, 1, 1)
            tooltip:AddLine(L["MINIMAP_TOOLTIP_LEFT"], 0.7, 0.7, 0.7)
            tooltip:AddLine(L["MINIMAP_TOOLTIP_RIGHT"], 0.7, 0.7, 0.7)
            if ns.TitleData.earnedCount and ns.TitleData.totalCount then
                tooltip:AddLine(string.format("Collected: %d / %d",
                    ns.TitleData.earnedCount, ns.TitleData.totalCount), 0.5, 0.8, 0.5)
            end
        end,
    })

    LDBIcon:Register("Epithet", launcher, self.db.profile.minimap)
end
