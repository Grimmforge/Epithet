-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) Grimmforge

local _, ns = ...
local L = ns.L
local T = ns.Theme

local LogbookUI = {}
ns.LogbookUI = LogbookUI

local CHECK_ICON = "Interface\\AddOns\\Epithet\\icons\\ui\\epithet-ui-check-32"
local LOCK_ICON = "Interface\\AddOns\\Epithet\\icons\\ui\\epithet-ui-lock-32"
local BINOCULARS_ICON = "Interface\\Icons\\INV_Misc_Spyglass_03"
local CLASS_ICON = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

local ROW_HEIGHT = 28
local TILE_SIZE = 104
local TILE_GAP = 10

local SHOUT_FORMAT_KEYS = {
    "SPOTTING_LOG_SHOUT_FMT_1",
    "SPOTTING_LOG_SHOUT_FMT_2",
    "SPOTTING_LOG_SHOUT_FMT_3",
    "SPOTTING_LOG_SHOUT_FMT_4",
    "SPOTTING_LOG_SHOUT_FMT_5",
}

local SHOUT_FORMAT_FALLBACKS = {
    "I've admired %d strangers a completely normal amount!",
    "I have inspected %d strangers against their knowledge and consent!",
    "I've been quietly judging the titles of %d strangers!",
    "%d strangers have been observed. None of them noticed. Excellent.",
    "I've stalked %d unsuspecting adventurers for their titles alone!",
}

local staticByID = nil

local function CountTableKeys(tbl)
    local n = 0
    for _ in pairs(tbl or {}) do
        n = n + 1
    end
    return n
end

local function GetSocialProfile()
    return ns.Epithet and ns.Epithet.db and ns.Epithet.db.profile and ns.Epithet.db.profile.social or nil
end

local function GetShoutFormatByIndex(index)
    local i = tonumber(index) or 1
    if i < 1 or i > #SHOUT_FORMAT_KEYS then
        i = 1
    end

    local key = SHOUT_FORMAT_KEYS[i]
    local localized = key and L and L[key]
    return localized or SHOUT_FORMAT_FALLBACKS[i], i
end

local function BuildStaticIndex()
    if staticByID then
        return staticByID
    end

    staticByID = {}
    local titles = ns.EpithetData and ns.EpithetData.titles
    if not titles then
        return staticByID
    end

    for key, data in pairs(titles) do
        local id = data and tonumber(data.titleID)
        if id and not staticByID[id] then
            staticByID[id] = {
                titleID = id,
                text = data.text or key,
                type = data.type,
                q = data.q,
                kind = data.kind,
                cat = data.cat,
                exp = data.exp,
            }
        end
    end

    return staticByID
end

local function GetCatalogueCount()
    if ns.TitleData and ns.TitleData.Scan then
        ns.TitleData:Scan()
    end

    local runtimeTotal = ns.TitleData and ns.TitleData.totalCount
    if tonumber(runtimeTotal) and runtimeTotal > 0 then
        return runtimeTotal
    end

    local byID = BuildStaticIndex()
    local count = CountTableKeys(byID)
    if count > 0 then
        return count
    end

    return (ns.TitleData and ns.TitleData.totalCount) or 0
end

local function GetDisplayRecord(titleID, entry)
    if ns.TitleData and ns.TitleData.GetRecord then
        local runtime = ns.TitleData:GetRecord(titleID)
        if runtime then
            return runtime
        end
    end

    local byID = BuildStaticIndex()
    local staticRecord = byID[tonumber(titleID)]
    if staticRecord then
        return staticRecord
    end

    if entry and entry.titleText and entry.titleText ~= "" then
        return {
            titleID = tonumber(titleID),
            text = entry.titleText,
            type = entry.titleType,
            q = entry.quality,
            kind = entry.kind,
            cat = entry.cat,
        }
    end

    if entry then
        return {
            titleID = tonumber(titleID),
            text = "Title #" .. tostring(titleID),
            type = entry.titleType,
            q = entry.quality,
            kind = entry.kind,
            cat = entry.cat,
        }
    end

    return nil
end

local function BuildDateString(epoch)
    if not epoch then
        return "?"
    end
    return date("%d %b %Y", epoch)
end

local function GetRarityColour(quality)
    local q = tonumber(quality) or 1
    local colours = ns.QUALITY_COLOURS and ns.QUALITY_COLOURS[q]
    if colours and colours.text then
        return colours.text.r, colours.text.g, colours.text.b
    end
    return 0.9, 0.82, 0.62
end

local function GetClassCoords(classTag)
    local coords = _G.CLASS_ICON_TCOORDS
    if not coords or not classTag then
        return nil
    end
    return coords[classTag]
end

local function OpenSpottingSettings()
    if ns.Settings and ns.Settings.OpenSpottingSettings then
        ns.Settings:OpenSpottingSettings()
        return
    end

    local settings = _G.Settings
    if settings and settings.OpenToCategory and ns.Settings and ns.Settings.category then
        local category = ns.Settings.category
        local categoryID = (type(category) == "table" and category.GetID and category:GetID()) or category.ID or category
        settings.OpenToCategory(categoryID)
        return
    end

    if _G.InterfaceOptionsFrame_OpenToCategory and ns.Settings and ns.Settings.panel then
        _G.InterfaceOptionsFrame_OpenToCategory(ns.Settings.panel)
        _G.InterfaceOptionsFrame_OpenToCategory(ns.Settings.panel)
    end
end

local function SkinEpithetButton(button)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.11, 0.08, 0.04, 1.0)
    button.bg = bg

    local top = button:CreateTexture(nil, "BORDER")
    top:SetHeight(1)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetColorTexture(0.49, 0.37, 0.15, 1.0)

    local bottom = button:CreateTexture(nil, "BORDER")
    bottom:SetHeight(1)
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetColorTexture(0.49, 0.37, 0.15, 1.0)

    local left = button:CreateTexture(nil, "BORDER")
    left:SetWidth(1)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetColorTexture(0.49, 0.37, 0.15, 1.0)

    local right = button:CreateTexture(nil, "BORDER")
    right:SetWidth(1)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetColorTexture(0.49, 0.37, 0.15, 1.0)

    button.borders = { top, bottom, left, right }

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", button, "CENTER", 0, 0)
    label:SetTextColor(0.91, 0.78, 0.45)
    button.label = label

    button:SetScript("OnEnter", function(self_)
        if self_.selected then return end
        self_.bg:SetColorTexture(0.16, 0.12, 0.07, 1.0)
        self_.label:SetTextColor(0.96, 0.89, 0.65)
        for _, border in ipairs(self_.borders) do
            border:SetColorTexture(0.91, 0.78, 0.45, 1.0)
        end
    end)

    button:SetScript("OnLeave", function(self_)
        if self_.selected then return end
        self_.bg:SetColorTexture(0.11, 0.08, 0.04, 1.0)
        self_.label:SetTextColor(0.91, 0.78, 0.45)
        for _, border in ipairs(self_.borders) do
            border:SetColorTexture(0.49, 0.37, 0.15, 1.0)
        end
    end)
end

local function SetButtonSelected(button, selected)
    if not button then return end
    button.selected = selected and true or false
    if button.selected then
        button.bg:SetColorTexture(0.20, 0.15, 0.08, 1.0)
        button.label:SetTextColor(1.0, 0.92, 0.70)
        for _, border in ipairs(button.borders) do
            border:SetColorTexture(0.95, 0.82, 0.48, 1.0)
        end
    else
        button.bg:SetColorTexture(0.11, 0.08, 0.04, 1.0)
        button.label:SetTextColor(0.91, 0.78, 0.45)
        for _, border in ipairs(button.borders) do
            border:SetColorTexture(0.49, 0.37, 0.15, 1.0)
        end
    end
end

function LogbookUI:LoadPrefs()
    local social = GetSocialProfile()
    local view = social and social.spotLogView or "grid"
    local scope = social and social.spotLogScope or "spotted"

    if view ~= "list" and view ~= "grid" then
        view = "grid"
    end
    if scope ~= "spotted" and scope ~= "remaining" then
        scope = "spotted"
    end

    self.viewMode = view
    self.scopeMode = scope
end

function LogbookUI:SavePrefs()
    local social = GetSocialProfile()
    if not social then return end
    social.spotLogView = self.viewMode or "list"
    social.spotLogScope = self.scopeMode or "spotted"
end

function LogbookUI:Init(mainFrame)
    if self.initialized then return end
    self.initialized = true
    self.mainFrame = mainFrame

    self:LoadPrefs()
    self.shoutCycleIndex = 1
    self:CreateButton(mainFrame)
    self:CreatePanel(mainFrame)
    self:RefreshButton()
end

function LogbookUI:CreateButton(mainFrame)
    local header = mainFrame and mainFrame.Header
    if not header then return end

    local button = CreateFrame("Button", nil, header)
    button:SetPoint("TOPRIGHT", header, "TOPRIGHT", -8, -8)
    button:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -8, 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    SkinEpithetButton(button)
    button.label:SetText("")

    local function SyncSpotButtonSize()
        local h = button:GetHeight() or 0
        if h <= 0 and header.GetHeight then
            h = math.max(0, (header:GetHeight() or 0) - 16)
        end
        if h > 0 then
            button:SetWidth(h)
        end
    end

    header:HookScript("OnSizeChanged", SyncSpotButtonSize)
    button:HookScript("OnShow", SyncSpotButtonSize)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
    icon:SetTexture(BINOCULARS_ICON)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetVertexColor(0.86, 0.74, 0.40, 0.95)
    button.icon = icon

    button:SetScript("OnClick", function(_, mouseButton)
        local count = ns.SpottingLog and ns.SpottingLog.Count and ns.SpottingLog:Count() or 0
        if mouseButton == "RightButton" then
            local fmt, idx = GetShoutFormatByIndex(self.shoutCycleIndex)
            if _G and _G.SendChatMessage then
                _G.SendChatMessage(string.format(fmt, count), "SAY")
            end
            self.shoutCycleIndex = (idx % #SHOUT_FORMAT_KEYS) + 1
            return
        end

        self:Toggle()
    end)
    button:SetScript("OnEnter", function(self_)
        icon:SetVertexColor(1.0, 0.9, 0.55, 1.0)
        GameTooltip:SetOwner(self_, "ANCHOR_BOTTOMRIGHT")
        local count = ns.SpottingLog and ns.SpottingLog.Count and ns.SpottingLog:Count() or 0
        GameTooltip:SetText((L and L["SPOTTING_LOG_TOOLTIP"] and string.format(L["SPOTTING_LOG_TOOLTIP"], count)) or ("Spotting Log (" .. count .. " found)"), 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine((L and L["SPOTTING_LOG_TOOLTIP_LEFT"]) or "Left-click: Open title spotting log.", 0.85, 0.82, 0.72, true)
        GameTooltip:AddLine((L and L["SPOTTING_LOG_TOOLTIP_RIGHT"]) or "Right-click: Shout your spotting stats in /s.", 0.85, 0.82, 0.72, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        icon:SetVertexColor(0.86, 0.74, 0.40, 0.95)
        GameTooltip:Hide()
    end)

    -- Ensure square sizing is correct immediately on creation.
    SyncSpotButtonSize()

    self.button = button
end

function LogbookUI:CreateModeButton(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(82, 22)
    SkinEpithetButton(button)
    button.label:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

function LogbookUI:EnsureTransferModal()
    if self.transferModal then
        return self.transferModal
    end

    local panel = self.panel
    if not panel then return nil end

    local modal = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    modal:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -92)
    modal:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 24)
    -- Keep modal at least on the same strata as the parent panel so it cannot
    -- render behind it when opened from the toolbar buttons.
    modal:SetFrameStrata(panel:GetFrameStrata() or "FULLSCREEN_DIALOG")
    modal:SetFrameLevel((panel:GetFrameLevel() or 1) + 50)
    modal:EnableMouse(true)
    modal:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    modal:SetBackdropColor(0.06, 0.05, 0.03, 0.98)
    modal:SetBackdropBorderColor(0.55, 0.45, 0.26, 0.95)
    modal:Hide()

    local heading = modal:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("TOPLEFT", 12, -10)
    heading:SetPoint("TOPRIGHT", -12, -10)
    heading:SetJustifyH("LEFT")
    modal.heading = heading

    local note = modal:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)
    note:SetPoint("TOPRIGHT", -12, -6)
    note:SetJustifyH("LEFT")
    note:SetText((L and L["SPOTTING_TRANSFER_NOTE"]) or "Copy/paste the payload below.")

    local editorWrap = CreateFrame("Frame", nil, modal, "BackdropTemplate")
    editorWrap:SetPoint("TOPLEFT", modal, "TOPLEFT", 12, -48)
    editorWrap:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -32, 48)
    editorWrap:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    editorWrap:SetBackdropColor(0.08, 0.07, 0.05, 1.0)
    editorWrap:SetBackdropBorderColor(0.40, 0.34, 0.22, 0.95)

    local scroll = CreateFrame("ScrollFrame", nil, editorWrap, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", editorWrap, "TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", editorWrap, "BOTTOMRIGHT", -26, 4)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetAutoFocus(false)
    edit:SetMultiLine(true)
    edit:SetFontObject(ChatFontNormal)
    edit:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    edit:SetWidth(520)
    edit:SetHeight(180)
    edit:SetScript("OnEscapePressed", function() modal:Hide() end)
    edit:SetScript("OnTextChanged", function(self_)
        local w = math.max(520, (self_:GetStringWidth() or 0) + 24)
        self_:SetWidth(w)
    end)
    scroll:SetScrollChild(edit)

    local function ResizeTransferEditor()
        local wrapW = editorWrap:GetWidth() or 0
        local wrapH = editorWrap:GetHeight() or 0
        local minW = math.max(520, wrapW - 40)
        local minH = math.max(140, wrapH - 10)
        if (edit:GetWidth() or 0) < minW then
            edit:SetWidth(minW)
        end
        edit:SetHeight(minH)
    end

    editorWrap:SetScript("OnMouseDown", function()
        edit:SetFocus()
    end)
    editorWrap:SetScript("OnSizeChanged", ResizeTransferEditor)
    ResizeTransferEditor()

    local primary = CreateFrame("Button", nil, modal)
    primary:SetSize(120, 24)
    primary:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -12, 12)
    SkinEpithetButton(primary)
    modal.primaryButton = primary

    local secondary = CreateFrame("Button", nil, modal)
    secondary:SetSize(120, 24)
    secondary:SetPoint("RIGHT", primary, "LEFT", -8, 0)
    SkinEpithetButton(secondary)
    secondary.label:SetText((L and L["SPOTTING_TRANSFER_CLOSE"]) or "Close")
    secondary:SetScript("OnClick", function() modal:Hide() end)

    modal.scroll = scroll
    modal.edit = edit
    self.transferModal = modal
    return modal
end

function LogbookUI:OpenExportModal()
    local modal = self:EnsureTransferModal()
    if not modal then return end

    local payload = (ns.SpottingLog and ns.SpottingLog.Export and ns.SpottingLog:Export()) or ""
    modal.heading:SetText((L and L["SPOTTING_EXPORT_TITLE"]) or "Export Spotting Log")
    modal.primaryButton.label:SetText((L and L["SPOTTING_TRANSFER_COPY"]) or "Select All")
    modal.primaryButton:SetScript("OnClick", function()
        modal.edit:HighlightText(0, -1)
        modal.edit:SetFocus()
    end)

    modal.edit:SetText(payload)
    modal:Show()
    -- Apply focus only after the modal is visible so keybinds (e.g. "C") do
    -- not win over copy shortcuts when exporting.
    modal.edit:SetFocus()
    modal.edit:HighlightText(0, -1)
end

function LogbookUI:OpenImportModal()
    local modal = self:EnsureTransferModal()
    if not modal then return end

    modal.heading:SetText((L and L["SPOTTING_IMPORT_TITLE"]) or "Import Spotting Log")
    modal.primaryButton.label:SetText((L and L["SPOTTING_TRANSFER_IMPORT"]) or "Import")
    modal.primaryButton:SetScript("OnClick", function()
        local text = modal.edit:GetText() or ""
        local ok, changed, err = false, 0, "Import unavailable"
        if ns.SpottingLog and ns.SpottingLog.Import then
            ok, changed, err = ns.SpottingLog:Import(text)
        end
        if ok then
            if ns.Print then
                ns.Print((L and L["SPOTTING_IMPORT_SUCCESS_FMT"] and string.format(L["SPOTTING_IMPORT_SUCCESS_FMT"], changed or 0)) or ("Imported " .. tostring(changed or 0) .. " spotting entries."))
            end
            modal:Hide()
            self:Refresh()
            self:RefreshButton()
        else
            if ns.Print then
                ns.Print((L and L["SPOTTING_IMPORT_FAILED_FMT"] and string.format(L["SPOTTING_IMPORT_FAILED_FMT"], err or "Unknown error")) or ("Import failed: " .. tostring(err or "Unknown error")))
            end
        end
    end)

    modal.edit:SetText("")
    modal.edit:SetFocus()
    modal:Show()
end

function LogbookUI:CreatePanel(mainFrame)
    local panel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -40)
    panel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -10, 10)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetFrameLevel((mainFrame:GetFrameLevel() or 1) + 200)
    panel:EnableMouse(true)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    if T and T.col then
        panel:SetBackdropColor(T.col.bg0.r, T.col.bg0.g, T.col.bg0.b, 1.0)
        panel:SetBackdropBorderColor(T.col.line.r, T.col.line.g, T.col.line.b, 0.8)
    else
        panel:SetBackdropColor(0.08, 0.06, 0.03, 1.0)
        panel:SetBackdropBorderColor(0.55, 0.45, 0.26, 0.8)
    end
    panel:Hide()

    local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 14, -12)
    heading:SetText(L and L["SPOTTING_LOG_HEADING"] or "Spotting Log")
    self.heading = heading

    local countText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    countText:SetPoint("TOPRIGHT", -36, -16)
    countText:SetJustifyH("RIGHT")
    self.countText = countText

    local close = CreateFrame("Button", nil, panel)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -10, -10)
    local closeText = close:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeText:SetPoint("CENTER")
    closeText:SetText("x")
    closeText:SetTextColor(0.95, 0.90, 0.75)
    close:SetScript("OnClick", function() self:Hide() end)

    local controlsRow = CreateFrame("Frame", nil, panel)
    controlsRow:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -38)
    controlsRow:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -38)
    controlsRow:SetHeight(24)

    local spottedBtn = self:CreateModeButton(controlsRow, (L and L["SPOTTING_SCOPE_SPOTTED"]) or "Spotted", function()
        self.scopeMode = "spotted"
        self:SavePrefs()
        self:Refresh()
    end)
    spottedBtn:SetPoint("LEFT", controlsRow, "LEFT", 0, 0)

    local remainingBtn = self:CreateModeButton(controlsRow, (L and L["SPOTTING_SCOPE_REMAINING"]) or "Remaining", function()
        self.scopeMode = "remaining"
        self:SavePrefs()
        self:Refresh()
    end)
    remainingBtn:SetPoint("LEFT", spottedBtn, "RIGHT", 6, 0)

    local viewSep = panel:CreateTexture(nil, "BORDER")
    viewSep:SetWidth(1)
    viewSep:SetHeight(18)
    viewSep:SetPoint("LEFT", remainingBtn, "RIGHT", 9, 0)
    viewSep:SetColorTexture(0.55, 0.45, 0.26, 0.7)

    local listBtn = self:CreateModeButton(controlsRow, (L and L["SPOTTING_VIEW_LIST"]) or "List", function()
        self.viewMode = "list"
        self:SavePrefs()
        self:Refresh()
    end)
    listBtn:SetPoint("LEFT", viewSep, "RIGHT", 9, 0)

    local gridBtn = self:CreateModeButton(controlsRow, (L and L["SPOTTING_VIEW_GRID"]) or "Grid", function()
        self.viewMode = "grid"
        self:SavePrefs()
        self:Refresh()
    end)
    gridBtn:SetPoint("LEFT", listBtn, "RIGHT", 6, 0)

    local importBtn = self:CreateModeButton(controlsRow, (L and L["SPOTTING_IMPORT_BUTTON"]) or "Import", function()
        self:OpenImportModal()
    end)
    importBtn:SetPoint("RIGHT", controlsRow, "RIGHT", 0, 0)

    local exportBtn = self:CreateModeButton(controlsRow, (L and L["SPOTTING_EXPORT_BUTTON"]) or "Export", function()
        self:OpenExportModal()
    end)
    exportBtn:SetPoint("RIGHT", importBtn, "LEFT", -6, 0)

    local divider = panel:CreateTexture(nil, "BORDER")
    divider:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -70)
    divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -70)
    divider:SetHeight(1)
    divider:SetColorTexture(0.55, 0.45, 0.26, 0.35)

    local contentArea = CreateFrame("Frame", nil, panel)
    contentArea:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -76)
    contentArea:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 12)

    local listWrap = CreateFrame("Frame", nil, contentArea)
    listWrap:SetAllPoints(contentArea)

    local listScroll = CreateFrame("ScrollFrame", nil, listWrap, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", listWrap, "TOPLEFT", 0, 0)
    listScroll:SetPoint("BOTTOMRIGHT", listWrap, "BOTTOMRIGHT", 0, 0)
    listScroll:EnableMouseWheel(true)

    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetPoint("TOPLEFT", listScroll, "TOPLEFT", 0, 0)
    listContent:SetPoint("TOPRIGHT", listScroll, "TOPRIGHT", 0, 0)
    listContent:SetWidth(math.max(1, (listWrap:GetWidth() or 0) - 8))
    listContent:SetHeight(1)
    listScroll:SetScrollChild(listContent)

    listWrap:SetScript("OnSizeChanged", function(self_)
        local width = math.max(1, (self_:GetWidth() or 0) - 8)
        listContent:SetWidth(width)
    end)

    listScroll:SetScript("OnMouseWheel", function(self_, delta)
        local current = self_:GetVerticalScroll() or 0
        local step = 32
        local maxScroll = math.max(0, (listContent:GetHeight() or 0) - (self_:GetHeight() or 0))
        if delta > 0 then
            self_:SetVerticalScroll(math.max(0, current - step))
        else
            self_:SetVerticalScroll(math.min(maxScroll, current + step))
        end
    end)

    local gridWrap = CreateFrame("Frame", nil, contentArea)
    gridWrap:SetAllPoints(contentArea)

    local gridScroll = CreateFrame("ScrollFrame", nil, gridWrap, "UIPanelScrollFrameTemplate")
    gridScroll:SetPoint("TOPLEFT", gridWrap, "TOPLEFT", 0, 0)
    gridScroll:SetPoint("BOTTOMRIGHT", gridWrap, "BOTTOMRIGHT", 0, 0)
    gridScroll:EnableMouseWheel(true)

    local gridContent = CreateFrame("Frame", nil, gridScroll)
    gridContent:SetPoint("TOPLEFT", gridScroll, "TOPLEFT", 0, 0)
    gridContent:SetWidth(math.max(1, (gridWrap:GetWidth() or 0) - 8))
    gridContent:SetHeight(1)
    gridScroll:SetScrollChild(gridContent)

    gridWrap:SetScript("OnSizeChanged", function(self_)
        local width = math.max(1, (self_:GetWidth() or 0) - 8)
        gridContent:SetWidth(width)
    end)

    gridScroll:SetScript("OnMouseWheel", function(self_, delta)
        local current = self_:GetVerticalScroll() or 0
        local step = 48
        local maxScroll = math.max(0, (gridContent:GetHeight() or 0) - (self_:GetHeight() or 0))
        if delta > 0 then
            self_:SetVerticalScroll(math.max(0, current - step))
        else
            self_:SetVerticalScroll(math.min(maxScroll, current + step))
        end
    end)

    local empty = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    empty:SetPoint("CENTER", panel, "CENTER", 0, -12)
    empty:SetPoint("LEFT", panel, "LEFT", 60, 0)
    empty:SetPoint("RIGHT", panel, "RIGHT", -60, 0)
    empty:SetJustifyH("CENTER")
    empty:SetText(L and L["SPOTTING_LOG_EMPTY"] or "Nothing spotted yet. Target players in the wild to log the titles they are wearing.")
    empty:Hide()

    local gated = CreateFrame("Frame", nil, panel)
    gated:SetAllPoints(panel)
    gated:Hide()

    local gatedText = gated:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    gatedText:SetPoint("CENTER", gated, "CENTER", 0, 8)
    gatedText:SetPoint("LEFT", gated, "LEFT", 70, 0)
    gatedText:SetPoint("RIGHT", gated, "RIGHT", -70, 0)
    gatedText:SetJustifyH("CENTER")
    gatedText:SetText(L and L["SPOTTING_LOG_GATED"] or "Title spotting is off. Sightings are not being recorded.")

    local settingsButton = CreateFrame("Button", nil, gated)
    settingsButton:SetSize(170, 24)
    settingsButton:SetPoint("TOP", gatedText, "BOTTOM", 0, -12)
    SkinEpithetButton(settingsButton)
    settingsButton.label:SetText(L and L["SPOTTING_LOG_OPEN_SETTINGS"] or "Enable in Settings")
    settingsButton:SetScript("OnClick", function()
        OpenSpottingSettings()
    end)

    panel:SetScript("OnShow", function()
        self.stateWasEnabled = nil
        self.elapsed = 0
        self:Refresh()
    end)

    panel:SetScript("OnUpdate", function(_, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < 0.5 then
            return
        end
        self.elapsed = 0

        local enabled = ns.IsTitleSpottingEnabled and ns.IsTitleSpottingEnabled() or false
        if self.stateWasEnabled ~= enabled then
            self:Refresh()
        end
    end)

    self.panel = panel
    self.scopeSpottedBtn = spottedBtn
    self.scopeRemainingBtn = remainingBtn
    self.viewListBtn = listBtn
    self.viewGridBtn = gridBtn
    self.exportBtn = exportBtn
    self.importBtn = importBtn
    self.listWrap = listWrap
    self.listScroll = listScroll
    self.listContent = listContent
    self.gridWrap = gridWrap
    self.gridScroll = gridScroll
    self.gridContent = gridContent
    self.emptyState = empty
    self.gatedState = gated
    self.rows = {}
    self.tiles = {}
    self.entries = {}
end

function LogbookUI:Toggle()
    if not self.panel then return end
    if self.panel:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function LogbookUI:Show()
    if not self.panel then return end
    self.panel:Raise()
    self.panel:Show()
    self:Refresh()
end

function LogbookUI:Hide()
    if not self.panel then return end
    self.panel:Hide()
end

function LogbookUI:BuildEntries(scopeMode)
    local entries = {}

    if ns.TitleData and ns.TitleData.Scan then
        ns.TitleData:Scan()
    end

    if scopeMode == "remaining" then
        local records = (ns.TitleData and ns.TitleData.records) or {}
        for _, record in ipairs(records) do
            local spotted = ns.SpottingLog and ns.SpottingLog.Has and ns.SpottingLog:Has(record.titleID)
            if not spotted then
                entries[#entries + 1] = {
                    titleID = record.titleID,
                    record = record,
                    log = nil,
                    isSpotted = false,
                }
            end
        end

        table.sort(entries, function(a, b)
            return (a.record.text or "") < (b.record.text or "")
        end)

        return entries
    end

    if not (ns.SpottingLog and ns.SpottingLog.Iterate) then
        return entries
    end

    for titleID, entry in ns.SpottingLog:Iterate() do
        local record = GetDisplayRecord(titleID, entry)
        if record and entry then
            entries[#entries + 1] = {
                titleID = titleID,
                record = record,
                log = entry,
                isSpotted = true,
            }
        end
    end

    table.sort(entries, function(a, b)
        local aSeen = tonumber(a.log and a.log.firstSeen) or 0
        local bSeen = tonumber(b.log and b.log.firstSeen) or 0
        if aSeen == bSeen then
            return (a.record.text or "") < (b.record.text or "")
        end
        return aSeen > bSeen
    end)

    return entries
end

function LogbookUI:ConfigureEntryTooltip(owner, data)
    local record = data.record
    local log = data.log

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(record.text or "", 1, 1, 1)

    if data.isSpotted and log then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine((L and L["SPOTTING_TOOLTIP_FIRST_FMT"] and string.format(L["SPOTTING_TOOLTIP_FIRST_FMT"], log.firstName or "?", log.firstZone or "?", BuildDateString(log.firstSeen))) or "", 0.85, 0.82, 0.72, true)
        GameTooltip:AddLine((L and L["SPOTTING_TOOLTIP_COUNT_FMT"] and string.format(L["SPOTTING_TOOLTIP_COUNT_FMT"], tonumber(log.count) or 1)) or "", 0.85, 0.82, 0.72, true)
        GameTooltip:AddLine((L and L["SPOTTING_TOOLTIP_LAST_FMT"] and string.format(L["SPOTTING_TOOLTIP_LAST_FMT"], BuildDateString(log.lastSeen), log.lastName or "?")) or "", 0.85, 0.82, 0.72, true)
    else
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine((L and L["SPOTTING_NOT_SPOTTED_YET"]) or "Not spotted yet.", 0.85, 0.82, 0.72, true)
    end

    GameTooltip:Show()
end

function LogbookUI:AcquireRow(index)
    local row = self.rows[index]
    if row then return row end

    row = CreateFrame("Button", nil, self.listContent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("LEFT", self.listContent, "LEFT", 0, 0)
    row:SetPoint("RIGHT", self.listContent, "RIGHT", 0, 0)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 0.02)
    row.bg = bg

    local state = row:CreateTexture(nil, "ARTWORK")
    state:SetSize(16, 16)
    state:SetPoint("LEFT", 6, 0)
    row.state = state

    local portrait = row:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(16, 16)
    portrait:SetPoint("LEFT", state, "RIGHT", 6, 0)
    portrait:SetTexture(CLASS_ICON)
    portrait:Hide()
    row.portrait = portrait

    local title = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("LEFT", portrait, "RIGHT", 6, 0)
    title:SetPoint("RIGHT", row, "RIGHT", -230, 0)
    title:SetJustifyH("LEFT")
    row.title = title

    local meta = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    meta:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    meta:SetJustifyH("RIGHT")
    meta:SetTextColor(0.72, 0.66, 0.56)
    row.meta = meta

    row:SetScript("OnEnter", function(self_)
        self_.bg:SetColorTexture(1, 1, 1, 0.05)
        if self_.data then
            self:ConfigureEntryTooltip(self_, self_.data)
        end
    end)

    row:SetScript("OnLeave", function(self_)
        self_.bg:SetColorTexture(1, 1, 1, 0.02)
        GameTooltip:Hide()
    end)

    self.rows[index] = row
    return row
end

function LogbookUI:RefreshRows(entries)
    local totalHeight = math.max(1, #entries * ROW_HEIGHT)
    self.listContent:SetHeight(totalHeight)

    for i, data in ipairs(entries) do
        local row = self:AcquireRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.listContent, "TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
        row:SetPoint("RIGHT", self.listContent, "RIGHT", 0, 0)
        row:Show()
        row.data = data

        local r, g, b = GetRarityColour(data.record.q)
        row.title:SetText(data.record.text or "")
        row.title:SetTextColor(r, g, b)

        if data.isSpotted then
            row.state:SetTexture(CHECK_ICON)
            row.state:SetVertexColor(0.90, 0.74, 0.30, 1.0)
            local classCoords = GetClassCoords(data.log and data.log.classTag)
            if classCoords then
                row.portrait:SetTexCoord(classCoords[1], classCoords[2], classCoords[3], classCoords[4])
                row.portrait:Show()
            else
                row.portrait:Hide()
            end

            local source = data.record.kind or data.record.cat or ""
            local seen = BuildDateString(data.log and data.log.firstSeen)
            local playerName = data.log and (data.log.lastName or data.log.firstName) or nil
            local tail = playerName and (seen .. " - " .. playerName) or seen
            row.meta:SetText((source ~= "" and (source .. " - " .. tail)) or tail)
        else
            row.state:SetTexture(LOCK_ICON)
            row.state:SetVertexColor(0.56, 0.52, 0.45, 1.0)
            row.portrait:Hide()

            local source = data.record.kind or data.record.cat or ""
            row.meta:SetText((source ~= "" and source) or ((L and L["SPOTTING_NOT_SPOTTED_YET"]) or "Not spotted yet"))
        end
    end

    for i = #entries + 1, #self.rows do
        self.rows[i]:Hide()
        self.rows[i].data = nil
    end
end

function LogbookUI:AcquireTile(index)
    local tile = self.tiles[index]
    if tile then return tile end

    tile = CreateFrame("Button", nil, self.gridContent, "BackdropTemplate")
    tile:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    tile:SetBackdropColor(0.11, 0.09, 0.06, 0.92)
    tile:SetBackdropBorderColor(0.55, 0.45, 0.26, 0.55)

    local state = tile:CreateTexture(nil, "ARTWORK")
    state:SetSize(16, 16)
    state:SetPoint("TOPLEFT", 6, -6)
    tile.state = state

    local portrait = tile:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(16, 16)
    portrait:SetPoint("TOPRIGHT", -6, -6)
    portrait:SetTexture(CLASS_ICON)
    portrait:Hide()
    tile.portrait = portrait

    local title = tile:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", tile, "TOPLEFT", 8, -26)
    title:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -8, -26)
    title:SetPoint("BOTTOM", tile, "BOTTOM", 0, 26)
    title:SetJustifyH("CENTER")
    title:SetJustifyV("MIDDLE")
    title:SetWordWrap(true)
    tile.title = title

    local meta = tile:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    meta:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 6, 6)
    meta:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -6, 6)
    meta:SetJustifyH("CENTER")
    meta:SetWordWrap(false)
    tile.meta = meta

    tile:SetScript("OnEnter", function(self_)
        self_:SetBackdropBorderColor(0.83, 0.70, 0.36, 0.9)
        if self_.data then
            self:ConfigureEntryTooltip(self_, self_.data)
        end
    end)

    tile:SetScript("OnLeave", function(self_)
        self_:SetBackdropBorderColor(0.55, 0.45, 0.26, 0.55)
        GameTooltip:Hide()
    end)

    self.tiles[index] = tile
    return tile
end

function LogbookUI:RefreshTiles(entries)
    local width = math.max(1, self.gridContent:GetWidth() or 1)
    local cols = math.max(1, math.floor((width + TILE_GAP) / (TILE_SIZE + TILE_GAP)))
    local rows = math.max(1, math.ceil(#entries / cols))
    local totalHeight = (rows * TILE_SIZE) + ((rows - 1) * TILE_GAP)
    self.gridContent:SetHeight(math.max(1, totalHeight))

    for i, data in ipairs(entries) do
        local tile = self:AcquireTile(i)
        tile:SetSize(TILE_SIZE, TILE_SIZE)

        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local x = col * (TILE_SIZE + TILE_GAP)
        local y = row * (TILE_SIZE + TILE_GAP)

        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", self.gridContent, "TOPLEFT", x, -y)
        tile:Show()
        tile.data = data

        local r, g, b = GetRarityColour(data.record.q)
        tile.title:SetText(data.record.text or "")
        tile.title:SetTextColor(r, g, b)

        if data.isSpotted then
            tile.state:SetTexture(CHECK_ICON)
            tile.state:SetVertexColor(0.90, 0.74, 0.30, 1.0)
            local classCoords = GetClassCoords(data.log and data.log.classTag)
            if classCoords then
                tile.portrait:SetTexCoord(classCoords[1], classCoords[2], classCoords[3], classCoords[4])
                tile.portrait:Show()
            else
                tile.portrait:Hide()
            end
            tile.meta:SetText(BuildDateString(data.log and data.log.firstSeen))
        else
            tile.state:SetTexture(LOCK_ICON)
            tile.state:SetVertexColor(0.56, 0.52, 0.45, 1.0)
            tile.portrait:Hide()
            tile.meta:SetText((L and L["SPOTTING_NOT_SPOTTED"]) or "Remaining")
        end
    end

    for i = #entries + 1, #self.tiles do
        self.tiles[i]:Hide()
        self.tiles[i].data = nil
    end
end

function LogbookUI:RefreshButton()
    if not self.button then return end
    local count = ns.SpottingLog and ns.SpottingLog.Count and ns.SpottingLog:Count() or 0
    self.button.count = count
end

function LogbookUI:RefreshModeButtons()
    if not self.scopeSpottedBtn or not self.scopeRemainingBtn then return end

    SetButtonSelected(self.scopeSpottedBtn, self.scopeMode == "spotted")
    SetButtonSelected(self.scopeRemainingBtn, self.scopeMode == "remaining")
    SetButtonSelected(self.viewListBtn, self.viewMode == "list")
    SetButtonSelected(self.viewGridBtn, self.viewMode == "grid")
end

function LogbookUI:Refresh()
    if not self.panel then return end

    self:RefreshButton()
    self:RefreshModeButtons()

    local enabled = ns.IsTitleSpottingEnabled and ns.IsTitleSpottingEnabled() or false
    self.stateWasEnabled = enabled

    local spottedCount = ns.SpottingLog and ns.SpottingLog.Count and ns.SpottingLog:Count() or 0
    local totalCatalogue = GetCatalogueCount()
    if self.countText then
        if self.scopeMode == "remaining" then
            local remaining = math.max(0, totalCatalogue - spottedCount)
            self.countText:SetText((L and L["SPOTTING_LOG_COUNT_REMAINING_FMT"] and string.format(L["SPOTTING_LOG_COUNT_REMAINING_FMT"], remaining)) or (remaining .. " titles remaining"))
        else
            self.countText:SetText((L and L["SPOTTING_LOG_COUNT_PROGRESS_FMT"] and string.format(L["SPOTTING_LOG_COUNT_PROGRESS_FMT"], spottedCount, totalCatalogue)) or (spottedCount .. " / " .. totalCatalogue .. " titles spotted"))
        end
    end

    if not enabled then
        self.gatedState:Show()
        self.listWrap:Hide()
        self.gridWrap:Hide()
        self.emptyState:Hide()
        return
    end

    self.gatedState:Hide()
    self.entries = self:BuildEntries(self.scopeMode)

    if #self.entries == 0 then
        self.listWrap:Hide()
        self.gridWrap:Hide()
        self.emptyState:Show()
        if self.scopeMode == "remaining" then
            self.emptyState:SetText((L and L["SPOTTING_LOG_EMPTY_REMAINING"]) or "No remaining titles in the current catalogue.")
        else
            self.emptyState:SetText((L and L["SPOTTING_LOG_EMPTY"]) or "Nothing spotted yet. Target players in the wild to log the titles they are wearing.")
        end
        return
    end

    self.emptyState:Hide()

    if self.viewMode == "grid" then
        self.listWrap:Hide()
        self.gridWrap:Show()
        self:RefreshTiles(self.entries)
    else
        self.gridWrap:Hide()
        self.listWrap:Show()
        self:RefreshRows(self.entries)
    end
end

function LogbookUI:OnLogUpdated()
    if self.panel and self.panel:IsShown() then
        self:Refresh()
    else
        self:RefreshButton()
    end
end

function LogbookUI:HandleSpottingStateChanged()
    if self.panel and self.panel:IsShown() then
        self:Refresh()
    end
end
