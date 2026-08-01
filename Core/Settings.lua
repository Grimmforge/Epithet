-- =============================================================================
-- Epithet — Settings
-- AddOns options panel for the social layer.
-- =============================================================================
local _, ns = ...
local L = ns.L
local T = ns.Theme

local BlizzardSettings = _G.Settings

local Options = {}
ns.Settings = Options

local function ApplyPortraitTexture(texture, unit, style, shell)
    if not texture or not unit or not SetPortraitTexture then return end

    local ok = pcall(SetPortraitTexture, texture, unit, true)
    if not ok then
        ok = pcall(SetPortraitTexture, texture, unit, false)
        if not ok then
            SetPortraitTexture(texture, unit)
        end
    end

    if style == "portrait" and shell and shell.GetWidth and shell.GetHeight then
        local w = shell:GetWidth() or 0
        local h = shell:GetHeight() or 0
        if w > 0 and h > 0 then
            local aspect = w / h
            if aspect >= 1 then
                local spanY = math.max(0.20, math.min(1.0, 1 / aspect))
                local y0 = 0.5 - (spanY * 0.5)
                local y1 = 0.5 + (spanY * 0.5)
                texture:SetTexCoord(0, 1, y0, y1)
            else
                local spanX = math.max(0.20, math.min(1.0, aspect))
                local x0 = 0.5 - (spanX * 0.5)
                local x1 = 0.5 + (spanX * 0.5)
                texture:SetTexCoord(x0, x1, 0, 1)
            end
            return
        end
    end

    texture:SetTexCoord(0.15, 0.85, 0.15, 0.85)
end

local function GetProfile()
    return ns.Epithet and ns.Epithet.db and ns.Epithet.db.profile and ns.Epithet.db.profile.social or nil
end

local function NormalizeAchievementNotifyMode(profile)
    if not profile then
        return "full"
    end

    local mode = profile.achievementNotifyMode
    if mode ~= "full" and mode ~= "silent" and mode ~= "off" then
        if profile.achievementNotify == false then
            mode = "off"
        else
            mode = "full"
        end
    end

    profile.achievementNotifyMode = mode
    profile.achievementNotify = (mode ~= "off")
    return mode
end

local function NormalizeAchievementAlertAnchor(profile)
    if not profile then
        return "uiparent"
    end

    local mode = profile.achievementAlertAnchor
    if mode ~= "uiparent" and mode ~= "alertframe" then
        mode = "uiparent"
    end

    profile.achievementAlertAnchor = mode
    return mode
end

function ns.GetPortraitMode()
    local profile = GetProfile()
    if profile and profile.animatedPortrait == false then
        return "2d"
    end
    return "3d"
end

function ns.IsTitleSpottingEnabled()
    local profile = GetProfile()
    return profile and profile.enabled == true
end

function Options:OpenSpottingSettings()
    if BlizzardSettings and BlizzardSettings.OpenToCategory and self.category then
        local category = self.category
        local categoryID = (type(category) == "table" and category.GetID and category:GetID()) or category.ID or category
        BlizzardSettings.OpenToCategory(categoryID)
        return
    end

    if InterfaceOptionsFrame_OpenToCategory and self.panel then
        InterfaceOptionsFrame_OpenToCategory(self.panel)
        InterfaceOptionsFrame_OpenToCategory(self.panel)
    end
end

local function RefreshAll()
    if ns.SocialLayer then
        ns.SocialLayer:ApplySettings()
    end
end

-- Account-wide language preference helpers (stored in EpithetDB.global.locale).
local function GetLocalePref()
    local g = ns.Epithet and ns.Epithet.db and ns.Epithet.db.global
    return (g and g.locale) or "auto"
end

local function SetLocalePref(code)
    local g = ns.Epithet and ns.Epithet.db and ns.Epithet.db.global
    if g then g.locale = code end
end

local function LocalePrefLabel(pref)
    if not pref or pref == "auto" then
        return L["OPTIONS_LANGUAGE_AUTO"]
    end
    return ns.GetLocaleDisplayName and ns.GetLocaleDisplayName(pref) or pref
end

-- Builds the "Language" sub-tab and registers it under the parent Epithet
-- category. Kept separate from the spotting panel so language lives on its own
-- tab and is unaffected by the title-spotting feature toggle.
function Options:BuildLanguagePanel(parentCategory)
    if self.languagePanel then return self.languagePanel end

    if not StaticPopupDialogs["EPITHET_LOCALE_RELOAD"] then
        StaticPopupDialogs["EPITHET_LOCALE_RELOAD"] = {
            text = L["OPTIONS_LANGUAGE_RELOAD_PROMPT"],
            button1 = L["RELOAD_NOW"],
            button2 = L["LATER"],
            OnAccept = function() ReloadUI() end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    local panel = CreateFrame("Frame")
    panel.name = L["OPTIONS_LANGUAGE_SECTION"]
    self.languagePanel = panel

    local canvas = panel
    if T and T.Panel and T.col then
        local shell = T.Panel(panel, T.col.bg0, T.col.line, 0.35)
        shell:SetPoint("TOPLEFT", 8, -8)
        shell:SetPoint("BOTTOMRIGHT", -8, 8)

        local inset = T.Panel(shell, T.col.panel, T.col.lineSoft, 0.35)
        inset:SetPoint("TOPLEFT", 10, -10)
        inset:SetPoint("BOTTOMRIGHT", -10, 10)
        canvas = inset

        if T.Diamond then
            local tl = T.Diamond(shell, 8, T.col.gold); tl:SetPoint("TOPLEFT", shell, "TOPLEFT", 2, -2)
            local tr = T.Diamond(shell, 8, T.col.gold); tr:SetPoint("TOPRIGHT", shell, "TOPRIGHT", -2, -2)
            local bl = T.Diamond(shell, 8, T.col.gold); bl:SetPoint("BOTTOMLEFT", shell, "BOTTOMLEFT", 2, 2)
            local br = T.Diamond(shell, 8, T.col.gold); br:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", -2, 2)
        end
    end

    local title = (T and T.Serif and T.Serif(canvas, 20, T.col.goldBright)) or canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L["OPTIONS_LANGUAGE_SECTION"])

    local languageLabel = (T and T.Sans and T.Sans(canvas, 12, T.col.goldDim)) or canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    languageLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)
    languageLabel:SetText(L["OPTIONS_LANGUAGE_LABEL"])

    local languageDrop = CreateFrame("Frame", "EpithetLanguageDropdown", canvas, "UIDropDownMenuTemplate")
    languageDrop:SetPoint("TOPLEFT", languageLabel, "BOTTOMLEFT", -16, -4)
    UIDropDownMenu_SetWidth(languageDrop, 240)

    -- When the active locale needs the bundled font (e.g. Russian on a Western
    -- client), the language names are non-Latin, so the default game font would
    -- show boxes. Apply the locale font to the dropdown's own text and its menu
    -- items. Returns nil (no change) when the client font already covers it.
    local localeFont = T and T.LocaleFontObject and T.LocaleFontObject(12)
    if localeFont then
        local dropText = _G["EpithetLanguageDropdownText"]
        if dropText and dropText.SetFontObject then dropText:SetFontObject(localeFont) end
    end

    local languageNote = (T and T.Sans and T.Sans(canvas, 11, T.col.faint)) or canvas:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    languageNote:SetPoint("TOPLEFT", languageDrop, "BOTTOMLEFT", 16, -2)
    languageNote:SetWidth(480)
    languageNote:SetJustifyH("LEFT")
    languageNote:SetText(L["OPTIONS_LANGUAGE_NOTE"])

    local function RefreshLanguageDropdown()
        local pref = GetLocalePref()
        UIDropDownMenu_SetSelectedValue(languageDrop, pref)
        UIDropDownMenu_SetText(languageDrop, LocalePrefLabel(pref))
    end
    self.RefreshLanguageDropdown = RefreshLanguageDropdown

    UIDropDownMenu_Initialize(languageDrop, function(_, level)
        if level ~= 1 then return end
        local current = GetLocalePref()
        local function addOption(value, label)
            local info = UIDropDownMenu_CreateInfo()
            info.text = label
            info.value = value
            info.checked = (value == current)
            if localeFont then info.fontObject = localeFont end
            info.func = function()
                if value ~= GetLocalePref() then
                    SetLocalePref(value)
                    RefreshLanguageDropdown()
                    StaticPopup_Show("EPITHET_LOCALE_RELOAD")
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
        addOption("auto", L["OPTIONS_LANGUAGE_AUTO"])
        for _, code in ipairs(ns.GetAvailableLocales and ns.GetAvailableLocales() or {}) do
            addOption(code, ns.GetLocaleDisplayName and ns.GetLocaleDisplayName(code) or code)
        end
    end)

    panel:SetScript("OnShow", RefreshLanguageDropdown)
    RefreshLanguageDropdown()

    if BlizzardSettings and BlizzardSettings.RegisterCanvasLayoutSubcategory and parentCategory then
        local sub = BlizzardSettings.RegisterCanvasLayoutSubcategory(parentCategory, panel, panel.name)
        self.languageCategory = sub
        if sub and sub.SetOnRefresh then
            sub:SetOnRefresh(RefreshLanguageDropdown)
        end
    elseif InterfaceOptions_AddCategory then
        panel.parent = "Epithet"
        InterfaceOptions_AddCategory(panel)
    end

    return panel
end

function Options:Init()
    if self.initialized then return end
    self.initialized = true

    local panel = CreateFrame("Frame")
    panel.name = "Epithet"
    self.panel = panel

    local canvas = panel
    if T and T.Panel and T.col then
        local shell = T.Panel(panel, T.col.bg0, T.col.line, 0.35)
        shell:SetPoint("TOPLEFT", 8, -8)
        shell:SetPoint("BOTTOMRIGHT", -8, 8)

        local inset = T.Panel(shell, T.col.panel, T.col.lineSoft, 0.35)
        inset:SetPoint("TOPLEFT", 10, -10)
        inset:SetPoint("BOTTOMRIGHT", -10, 10)
        canvas = inset

        if T.Diamond then
            local tl = T.Diamond(shell, 8, T.col.gold)
            tl:SetPoint("TOPLEFT", shell, "TOPLEFT", 2, -2)
            local tr = T.Diamond(shell, 8, T.col.gold)
            tr:SetPoint("TOPRIGHT", shell, "TOPRIGHT", -2, -2)
            local bl = T.Diamond(shell, 8, T.col.gold)
            bl:SetPoint("BOTTOMLEFT", shell, "BOTTOMLEFT", 2, 2)
            local br = T.Diamond(shell, 8, T.col.gold)
            br:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", -2, 2)
        end
    end

    local viewport = canvas
    local scrollFrame = CreateFrame("ScrollFrame", nil, viewport, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", viewport, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", viewport, "BOTTOMRIGHT", -30, 8)
    scrollFrame:EnableMouseWheel(true)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
    scrollContent:SetSize(560, 760)
    scrollFrame:SetScrollChild(scrollContent)

    local function SyncScrollWidth()
        local frameWidth = scrollFrame:GetWidth() or 0
        local width = math.max(320, math.floor(frameWidth - 24))
        scrollContent:SetWidth(width)
    end

    scrollFrame:SetScript("OnSizeChanged", function()
        SyncScrollWidth()
    end)

    SyncScrollWidth()

    scrollFrame:SetScript("OnMouseWheel", function(self_, delta)
        local current = self_:GetVerticalScroll() or 0
        local step = 32
        local maxScroll = math.max(0, (scrollContent:GetHeight() or 0) - (self_:GetHeight() or 0))
        if delta > 0 then
            self_:SetVerticalScroll(math.max(0, current - step))
        else
            self_:SetVerticalScroll(math.min(maxScroll, current + step))
        end
    end)

    self.scrollFrame = scrollFrame
    self.scrollContent = scrollContent
    canvas = scrollContent

    local title = (T and T.Serif and T.Serif(canvas, 20, T.col.goldBright)) or canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L["SOCIAL_LAYER"] or "Title Spotting")

    local desc = (T and T.Sans and T.Sans(canvas, 12, T.col.text)) or canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(520)
    desc:SetJustifyH("LEFT")
    desc:SetText(L["SOCIAL_LAYER_DESC"] or "Inspecting total strangers is practically a core ability by now. Point it at their titles too: spot what another players have chosen to wear and jump straight in to how it's earned in Epithet.")

    local stateHeading = (T and T.Sans and T.Sans(canvas, 12, T.col.goldDim)) or canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    stateHeading:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -14)
    stateHeading:SetText(L["SOCIAL_STATE_SECTION"] or "Feature State")

    local function GetLayoutOptions()
        if ns.SocialLayer and ns.SocialLayer.GetLayoutOptions then
            return ns.SocialLayer:GetLayoutOptions()
        end
        return {
            { key = "classic", label = L["SOCIAL_LAYOUT_CLASSIC"] or "Slimline" },
        }
    end

    local function ResolveLayoutLabel(key)
        for _, option in ipairs(GetLayoutOptions()) do
            if option.key == key then
                return option.label
            end
        end
        return key or (L["SOCIAL_LAYOUT_CLASSIC"] or "Slimline")
    end

    local layoutHeading = (T and T.Sans and T.Sans(canvas, 12, T.col.goldDim)) or canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    layoutHeading:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -74)
    layoutHeading:SetText(L["SOCIAL_LAYOUT_SECTION"] or "Nameplate Layout")

    local layoutDrop = CreateFrame("Frame", "EpithetSocialLayoutDropdown", canvas, "UIDropDownMenuTemplate")
    layoutDrop:SetPoint("TOPLEFT", layoutHeading, "BOTTOMLEFT", -16, -4)
    UIDropDownMenu_SetWidth(layoutDrop, 240)

    local function RefreshLayoutDropdown()
        local profile = GetProfile()
        local key = profile and profile.layout or "classic"
        if ns.SocialLayer and ns.SocialLayer.IsValidLayoutKey and not ns.SocialLayer:IsValidLayoutKey(key) then
            if ns.SocialLayer.GetDefaultLayoutKey then
                key = ns.SocialLayer:GetDefaultLayoutKey()
            else
                key = "classic"
            end
            if profile then profile.layout = key end
        end
        UIDropDownMenu_SetSelectedValue(layoutDrop, key)
        UIDropDownMenu_SetText(layoutDrop, ResolveLayoutLabel(key))
    end

    UIDropDownMenu_Initialize(layoutDrop, function(_, level)
        if level ~= 1 then return end
        local profile = GetProfile()
        local current = profile and profile.layout or "classic"
        for _, option in ipairs(GetLayoutOptions()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            info.value = option.key
            info.checked = (option.key == current)
            info.func = function()
                local p = GetProfile()
                if p then p.layout = option.key end
                RefreshLayoutDropdown()
                RefreshAll()
                if Options and Options.Refresh then
                    Options:Refresh()
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    local previewHeading = (T and T.Sans and T.Sans(canvas, 12, T.col.goldDim)) or canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    previewHeading:SetPoint("TOPLEFT", layoutDrop, "BOTTOMLEFT", 16, -12)
    previewHeading:SetText(L["SOCIAL_LAYOUT_PREVIEW"] or "Layout Preview")

    local previewFrame = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    previewFrame:SetSize(520, 116)
    previewFrame:SetPoint("TOPLEFT", previewHeading, "BOTTOMLEFT", 0, -8)
    previewFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    if T and T.col then
        previewFrame:SetBackdropColor(T.col.bg0.r, T.col.bg0.g, T.col.bg0.b, 0.75)
        previewFrame:SetBackdropBorderColor(T.col.line.r, T.col.line.g, T.col.line.b, 0.7)
    else
        previewFrame:SetBackdropColor(0.08, 0.06, 0.04, 0.75)
        previewFrame:SetBackdropBorderColor(0.55, 0.46, 0.30, 0.7)
    end

    local previewPlate = CreateFrame("Frame", nil, previewFrame, "BackdropTemplate")
    previewPlate:SetPoint("CENTER", previewFrame, "CENTER", 0, 0)
    previewPlate:SetSize(244, 58)
    previewPlate:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    if T and T.col then
        previewPlate:SetBackdropColor(T.col.bg0.r, T.col.bg0.g, T.col.bg0.b, 0.9)
        previewPlate:SetBackdropBorderColor(T.col.goldDeep.r, T.col.goldDeep.g, T.col.goldDeep.b, 0.9)
    else
        previewPlate:SetBackdropColor(0.08, 0.06, 0.04, 0.9)
        previewPlate:SetBackdropBorderColor(0.72, 0.58, 0.26, 0.9)
    end

    previewPlate.leftCol = CreateFrame("Frame", nil, previewPlate)
    previewPlate.leftCol:SetPoint("TOPLEFT", previewPlate, "TOPLEFT", 4, -3)
    previewPlate.leftCol:SetPoint("BOTTOMLEFT", previewPlate, "BOTTOMLEFT", 4, 3)
    previewPlate.leftCol:SetWidth(44)

    previewPlate.gem = previewPlate.leftCol:CreateTexture(nil, "ARTWORK")
    previewPlate.gem:SetSize(40, 40)
    previewPlate.gem:SetPoint("CENTER", previewPlate.leftCol, "CENTER", 0, 0)

    previewPlate.portraitShell = CreateFrame("Frame", nil, previewPlate)
    previewPlate.portraitShell:SetPoint("TOPRIGHT", previewPlate, "TOPRIGHT", 0, -3)
    previewPlate.portraitShell:SetPoint("BOTTOMRIGHT", previewPlate, "BOTTOMRIGHT", 0, 3)
    previewPlate.portraitShell:SetWidth(52)

    previewPlate.portraitBG = previewPlate.portraitShell:CreateTexture(nil, "BACKGROUND")
    previewPlate.portraitBG:SetAllPoints(previewPlate.portraitShell)
    previewPlate.portraitBG:SetColorTexture(0.05, 0.05, 0.05, 1.0)

    previewPlate.portrait = previewPlate.portraitShell:CreateTexture(nil, "ARTWORK")
    previewPlate.portrait:SetPoint("TOPLEFT", previewPlate.portraitShell, "TOPLEFT", 0, -1)
    previewPlate.portrait:SetPoint("BOTTOMRIGHT", previewPlate.portraitShell, "BOTTOMRIGHT", -1, 0)
    previewPlate.portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    previewPlate.portraitTopRule = previewPlate:CreateTexture(nil, "BORDER")
    previewPlate.portraitTopRule:SetHeight(1)
    if T and T.col and T.col.line then
        previewPlate.portraitTopRule:SetColorTexture(T.col.line.r, T.col.line.g, T.col.line.b, 0.85)
    else
        previewPlate.portraitTopRule:SetColorTexture(0.70, 0.58, 0.31, 0.75)
    end
    previewPlate.portraitTopRule:Hide()

    previewPlate.portraitBottomRule = previewPlate:CreateTexture(nil, "BORDER")
    previewPlate.portraitBottomRule:SetHeight(1)
    if T and T.col and T.col.line then
        previewPlate.portraitBottomRule:SetColorTexture(T.col.line.r, T.col.line.g, T.col.line.b, 0.85)
    else
        previewPlate.portraitBottomRule:SetColorTexture(0.70, 0.58, 0.31, 0.75)
    end
    previewPlate.portraitBottomRule:Hide()

    previewPlate.crownFrame = CreateFrame("Frame", nil, previewFrame)
    previewPlate.crownFrame:SetFrameStrata("HIGH")
    previewPlate.crownFrame:SetFrameLevel(previewPlate:GetFrameLevel() + 8)
    previewPlate.crownFrame:SetSize(34, 34)
    previewPlate.crown = previewPlate.crownFrame:CreateTexture(nil, "OVERLAY")
    previewPlate.crown:SetAllPoints(previewPlate.crownFrame)

    previewPlate.centerCol = CreateFrame("Frame", nil, previewPlate)
    previewPlate.centerCol:SetPoint("TOPLEFT", previewPlate.leftCol, "TOPRIGHT", 9, -6)
    previewPlate.centerCol:SetPoint("BOTTOMRIGHT", previewPlate.portraitShell, "BOTTOMLEFT", -9, 6)

    previewPlate.titleRow = CreateFrame("Frame", nil, previewPlate.centerCol)
    previewPlate.titleRow:SetPoint("TOPLEFT", previewPlate.centerCol, "TOPLEFT", 0, 0)
    previewPlate.titleRow:SetPoint("TOPRIGHT", previewPlate.centerCol, "TOPRIGHT", 0, 0)
    previewPlate.titleRow:SetHeight(20)

    previewPlate.rarityRow = CreateFrame("Frame", nil, previewPlate.centerCol)
    previewPlate.rarityRow:SetPoint("BOTTOMLEFT", previewPlate.centerCol, "BOTTOMLEFT", 0, 0)
    previewPlate.rarityRow:SetPoint("BOTTOMRIGHT", previewPlate.centerCol, "BOTTOMRIGHT", 0, 0)
    previewPlate.rarityRow:SetHeight(18)

    local previewTitle = (T and T.Sans and T.Sans(previewPlate.titleRow, 11, T.col.goldBright)) or previewPlate.titleRow:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    previewTitle:SetAllPoints(previewPlate.titleRow)
    previewTitle:SetHeight(20)
    previewTitle:SetJustifyH("LEFT")
    previewTitle:SetJustifyV("MIDDLE")
    previewTitle:SetWordWrap(false)
    previewTitle:SetText(L["SAMPLE_TITLE"])
    previewPlate.titleText = previewTitle

    local previewRarity = (T and T.Sans and T.Sans(previewPlate.rarityRow, 10, T.col.muted)) or previewPlate.rarityRow:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    previewRarity:SetAllPoints(previewPlate.rarityRow)
    previewRarity:SetHeight(18)
    previewRarity:SetJustifyH("LEFT")
    previewRarity:SetJustifyV("MIDDLE")
    previewRarity:SetWordWrap(false)
    previewRarity:SetText(L["SAMPLE_RARITY"])
    previewPlate.rarityText = previewRarity

    local previewNote = (T and T.Sans and T.Sans(previewFrame, 11, T.col.faint)) or previewFrame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    previewNote:SetPoint("BOTTOMLEFT", previewFrame, "BOTTOMLEFT", 10, 8)
    previewNote:SetPoint("BOTTOMRIGHT", previewFrame, "BOTTOMRIGHT", -10, 8)
    previewNote:SetJustifyH("LEFT")
    previewNote:SetText(L["SOCIAL_LAYOUT_PREVIEW_NOTE"] or "Preview uses sample data.")

    local function RefreshLayoutPreview()
        local profile = GetProfile()
        local style = ns.SocialLayer and ns.SocialLayer.GetPreviewStyle and ns.SocialLayer:GetPreviewStyle(profile) or nil
        if not style or not style.metrics then return end

        -- Preview always renders a stable player portrait source.
        previewPlate.portraitUnit = "player"

        local key = style.key or "classic"
        local previewProfile = { layout = key }
        local layoutEngine = ns.Layouts

        local useFunnyTitle = profile and profile.previewFunnyTitle
        if useFunnyTitle then
            previewPlate.titleText:SetText(L["SAMPLE_FUNNY_TITLE"])
        else
            previewPlate.titleText:SetText(L["SAMPLE_TITLE"])
        end

        if layoutEngine and layoutEngine.ApplyLayoutToFrame and layoutEngine.SizeTargetPill then
            layoutEngine:ApplyLayoutToFrame(previewPlate, previewProfile)
            layoutEngine:SizeTargetPill(previewPlate, previewProfile)
        end

        local m = previewPlate.layoutMetrics or style.metrics
        previewFrame:SetHeight(math.max(116, (previewPlate:GetHeight() or (m and m.frameHeight) or 58) + 56))

        if previewPlate.crownFrame and m and m.layoutStyle ~= "portrait" then
            local topInset = m.portraitTopInset or m.portraitInsetY or 3
            local bottomInset = m.portraitBottomInset or m.portraitInsetY or 3
            local portraitW = math.max(m.portraitMinWidth or 20, (previewPlate:GetHeight() or m.frameHeight or 58) - (topInset + bottomInset))
            local crownSize = math.max(m.crownMinSize or 24, math.floor((portraitW * (m.crownBaseScale or 0.65) * style.crownMultiplier) + 0.5))
            previewPlate.crownFrame:SetSize(crownSize, crownSize)
            previewPlate.crownFrame:ClearAllPoints()
            previewPlate.crownFrame:SetPoint("BOTTOM", previewPlate.portraitShell, "TOP", 0, style.crownOffset)
            previewPlate.crown:SetTexture(style.crownIcon)
        end

        if previewPlate.portraitMode == "3d" then
            if previewPlate.portraitModel and previewPlate.portraitModel.SetUnit then
                local ok = pcall(previewPlate.portraitModel.SetUnit, previewPlate.portraitModel, "player")
                if ok and previewPlate.portraitModel.RefreshUnit then
                    pcall(previewPlate.portraitModel.RefreshUnit, previewPlate.portraitModel)
                end
            end
        else
            ApplyPortraitTexture(previewPlate.portrait, "player", m.layoutStyle, previewPlate.portraitShell)
        end

        previewPlate.gem:SetTexture(style.rarityGem)
        previewPlate.gem:SetVertexColor(0.90, 0.70, 0.25, 1.0)
        previewPlate.rarityText:SetTextColor(0.90, 0.70, 0.25)
    end

    local function MakeCheck(label, y, getter, setter)
        local box = CreateFrame("CheckButton", nil, canvas, "UICheckButtonTemplate")
        box:SetPoint("TOPLEFT", 16, y)
        box:SetSize(24, 24)
        box:SetScript("OnClick", function(self_)
            setter(self_:GetChecked() and true or false)
            RefreshAll()
            if Options and Options.Refresh then
                Options:Refresh()
            end
        end)
        local text = (T and T.Sans and T.Sans(canvas, 12, T.col.text)) or canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        text:SetPoint("LEFT", box, "RIGHT", 6, 0)
        text:SetText(label)
        box.text = text
        box.Refresh = function()
            box:SetChecked(getter() and true or false)
        end
        return box
    end

    local previewFunnyToggle = CreateFrame("CheckButton", nil, canvas, "UICheckButtonTemplate")
    previewFunnyToggle:SetPoint("TOPLEFT", 16, -316)
    previewFunnyToggle:SetSize(24, 24)
    local previewFunnyText = (T and T.Sans and T.Sans(canvas, 12, T.col.text)) or canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    previewFunnyText:SetPoint("LEFT", previewFunnyToggle, "RIGHT", 6, 0)
    previewFunnyText:SetText(L["SOCIAL_LAYOUT_FUNNY_TOGGLE"] or "Use funny title preview")
    previewFunnyToggle.text = previewFunnyText
    previewFunnyToggle:SetScript("OnClick", function(self_)
        local profile = GetProfile()
        if profile then
            profile.previewFunnyTitle = self_:GetChecked() and true or false
        end
        RefreshLayoutPreview()
    end)
    previewFunnyToggle.Refresh = function()
        local profile = GetProfile()
        previewFunnyToggle:SetChecked(profile and profile.previewFunnyTitle or false)
    end

    local animatedPortraitToggle = CreateFrame("CheckButton", nil, canvas, "UICheckButtonTemplate")
    animatedPortraitToggle:SetPoint("TOPLEFT", 16, -342)
    animatedPortraitToggle:SetSize(24, 24)
    local animatedPortraitText = (T and T.Sans and T.Sans(canvas, 12, T.col.text)) or canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    animatedPortraitText:SetPoint("LEFT", animatedPortraitToggle, "RIGHT", 6, 0)
    animatedPortraitText:SetText(L["SOCIAL_LAYOUT_ANIMATED_PORTRAIT_TOGGLE"] or "Toggle animated portrait")
    animatedPortraitToggle.text = animatedPortraitText
    animatedPortraitToggle:SetScript("OnClick", function(self_)
        local profile = GetProfile()
        if profile then
            profile.animatedPortrait = self_:GetChecked() and true or false
        end
        RefreshAll()
        RefreshLayoutPreview()
        if Options and Options.Refresh then
            Options:Refresh()
        end
    end)
    animatedPortraitToggle.Refresh = function()
        local profile = GetProfile()
        animatedPortraitToggle:SetChecked(profile == nil or profile.animatedPortrait ~= false)
    end

    local fadeHeading = (T and T.Sans and T.Sans(canvas, 12, T.col.goldDim)) or canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fadeHeading:SetPoint("TOPLEFT", animatedPortraitToggle, "BOTTOMLEFT", 0, -14)
    fadeHeading:SetText(L["SOCIAL_FADE_SECTION"] or "Fade")

    local fadeToggle = MakeCheck(L["SOCIAL_FADE_ENABLE"] or "Fade target nameplates over time", -372,
        function()
            local profile = GetProfile()
            return profile and profile.fadeNameplates == true
        end,
        function(value)
            local profile = GetProfile()
            if profile then profile.fadeNameplates = value end
        end)

    local fadeLabel = (T and T.Sans and T.Sans(canvas, 12, T.col.text)) or canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fadeLabel:SetText(L["SOCIAL_FADE_DURATION"] or "Fade delay")

    local fadeSlider = CreateFrame("Slider", "EpithetFadeDurationSlider", canvas, "OptionsSliderTemplate")
    fadeSlider:SetOrientation("HORIZONTAL")
    fadeSlider:SetMinMaxValues(0.5, 20.0)
    fadeSlider:SetValueStep(0.5)
    if fadeSlider.SetObeyStepOnDrag then
        fadeSlider:SetObeyStepOnDrag(true)
    end
    fadeSlider:SetWidth(280)
    fadeSlider:SetHeight(16)

    local fadeSliderText = _G[fadeSlider:GetName() .. "Text"]
    local fadeSliderLow = _G[fadeSlider:GetName() .. "Low"]
    local fadeSliderHigh = _G[fadeSlider:GetName() .. "High"]
    if fadeSliderText and fadeSliderText.SetText then
        fadeSliderText:SetText("")
    end
    if fadeSliderLow and fadeSliderLow.SetText then
        fadeSliderLow:SetText(L["FADE_SLIDER_LOW"])
    end
    if fadeSliderHigh and fadeSliderHigh.SetText then
        fadeSliderHigh:SetText(L["FADE_SLIDER_HIGH"])
    end

    local fadeValueText = (T and T.Sans and T.Sans(canvas, 11, T.col.faint)) or canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fadeValueText:SetJustifyH("LEFT")

    local function SetFadeValueText(value)
        local seconds = tonumber(value) or 4.0
        local fmt = L["SOCIAL_FADE_DURATION_FMT"] or "%.1f seconds before fade"
        fadeValueText:SetText(string.format(fmt, seconds))
    end

    fadeSlider:SetScript("OnValueChanged", function(self_, value)
        if Options and Options._refreshingFadeSlider then
            SetFadeValueText(value)
            return
        end
        local profile = GetProfile()
        if profile then
            profile.fadeDuration = value
        end
        SetFadeValueText(value)
        RefreshAll()
        if Options and Options.Refresh then
            Options:Refresh()
        end
    end)

    local enabled = MakeCheck(L["SOCIAL_ENABLED"] or "Enable title spotting", -94,
        function()
            local profile = GetProfile()
            return profile and profile.enabled
        end,
        function(value)
            local profile = GetProfile()
            if profile then profile.enabled = value end
            if ns.LogbookUI and ns.LogbookUI.HandleSpottingStateChanged then
                ns.LogbookUI:HandleSpottingStateChanged()
            end
        end)

    if enabled and enabled.text and enabled.text.SetTextColor then
        if T and T.col and T.col.goldBright then
            enabled.text:SetTextColor(T.col.goldBright.r, T.col.goldBright.g, T.col.goldBright.b, 1)
        else
            enabled.text:SetTextColor(1, 0.92, 0.72)
        end
    end

    local behaviourHeading = (T and T.Sans and T.Sans(canvas, 12, T.col.goldDim)) or canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    behaviourHeading:SetPoint("TOPLEFT", 16, -410)
    behaviourHeading:SetText(L["SOCIAL_BEHAVIOUR_SECTION"] or "Visibility Rules")

    local hideInCombat = MakeCheck(L["SOCIAL_HIDE_IN_COMBAT"] or "Hide target nameplate during combat", -370,
        function()
            local profile = GetProfile()
            return profile and profile.hideInCombat
        end,
        function(value)
            local profile = GetProfile()
            if profile then profile.hideInCombat = value end
        end)

    local hideInGroup = MakeCheck(L["SOCIAL_HIDE_IN_GROUP"] or "Hide target nameplate when grouped", -402,
        function()
            local profile = GetProfile()
            return profile and profile.hideInGroup
        end,
        function(value)
            local profile = GetProfile()
            if profile then profile.hideInGroup = value end
        end)

    local spotNotify = MakeCheck(L["SOCIAL_SPOTTING_NOTIFY"] or "Show spotting confirmations in chat", -434,
        function()
            local profile = GetProfile()
            return profile and profile.spotNotify ~= false
        end,
        function(value)
            local profile = GetProfile()
            if profile then profile.spotNotify = value end
        end)

    local achievementNotifyHeading = (T and T.Sans and T.Sans(canvas, 12, T.col.text)) or canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    achievementNotifyHeading:SetText(L["SOCIAL_ACHIEVEMENT_NOTIFY_MODE"] or "Achievement notification mode")

    local achievementNotifyDrop = CreateFrame("Frame", "EpithetAchievementNotifyDropdown", canvas, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(achievementNotifyDrop, 220)

    local function SetAchievementNotifyMode(mode)
        local profile = GetProfile()
        if not profile then
            return
        end
        if mode ~= "full" and mode ~= "silent" and mode ~= "off" then
            mode = "full"
        end
        profile.achievementNotifyMode = mode
        profile.achievementNotify = (mode ~= "off")
    end

    local function AchievementNotifyModeLabel(mode)
        if mode == "silent" then
            return L["SOCIAL_ACHIEVEMENT_NOTIFY_MODE_SILENT"] or "Popup only (mute sound)"
        elseif mode == "off" then
            return L["SOCIAL_ACHIEVEMENT_NOTIFY_MODE_OFF"] or "Off"
        end
        return L["SOCIAL_ACHIEVEMENT_NOTIFY_MODE_FULL"] or "Popup + sound"
    end

    local function RefreshAchievementNotifyDropdown()
        local profile = GetProfile()
        local mode = NormalizeAchievementNotifyMode(profile)
        UIDropDownMenu_SetSelectedValue(achievementNotifyDrop, mode)
        UIDropDownMenu_SetText(achievementNotifyDrop, AchievementNotifyModeLabel(mode))
    end

    UIDropDownMenu_Initialize(achievementNotifyDrop, function(_, level)
        if level ~= 1 then return end

        local profile = GetProfile()
        local current = NormalizeAchievementNotifyMode(profile)
        local modes = {
            { value = "full", label = AchievementNotifyModeLabel("full") },
            { value = "silent", label = AchievementNotifyModeLabel("silent") },
            { value = "off", label = AchievementNotifyModeLabel("off") },
        }

        for _, option in ipairs(modes) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            info.value = option.value
            info.checked = (option.value == current)
            info.func = function()
                SetAchievementNotifyMode(option.value)
                RefreshAchievementNotifyDropdown()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    local achievementAnchorHeading = (T and T.Sans and T.Sans(canvas, 12, T.col.text)) or canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    achievementAnchorHeading:SetText(L["SOCIAL_ACHIEVEMENT_ANCHOR_MODE"] or "Achievement popup anchor")

    local achievementAnchorDrop = CreateFrame("Frame", "EpithetAchievementAnchorDropdown", canvas, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(achievementAnchorDrop, 220)

    local achievementAnchorNote = (T and T.Sans and T.Sans(canvas, 11, T.col.faint)) or canvas:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    achievementAnchorNote:SetJustifyH("LEFT")
    achievementAnchorNote:SetJustifyV("TOP")
    achievementAnchorNote:SetWidth(500)

    local function AchievementAnchorModeLabel(mode)
        if mode == "alertframe" then
            return L["SOCIAL_ACHIEVEMENT_ANCHOR_ALERTFRAME"] or "Match Blizzard AlertFrame"
        end
        return L["SOCIAL_ACHIEVEMENT_ANCHOR_UIPARENT"] or "Screen top (UIParent)"
    end

    local function AchievementAnchorModeNote(mode)
        if mode == "alertframe" then
            return L["SOCIAL_ACHIEVEMENT_ANCHOR_ALERTFRAME_DESC"] or "Follows Blizzard achievement/loot toast area. If another addon moves or hides AlertFrame, this popup moves with it."
        end
        return L["SOCIAL_ACHIEVEMENT_ANCHOR_UIPARENT_DESC"] or "Anchors to the top-center of the screen. Most reliable if AlertFrame is moved or hidden by UI mods."
    end

    local function SetAchievementAnchorMode(mode)
        local profile = GetProfile()
        if not profile then
            return
        end

        if mode ~= "uiparent" and mode ~= "alertframe" then
            mode = "uiparent"
        end
        profile.achievementAlertAnchor = mode
    end

    local function RefreshAchievementAnchorDropdown()
        local profile = GetProfile()
        local mode = NormalizeAchievementAlertAnchor(profile)
        UIDropDownMenu_SetSelectedValue(achievementAnchorDrop, mode)
        UIDropDownMenu_SetText(achievementAnchorDrop, AchievementAnchorModeLabel(mode))
        achievementAnchorNote:SetText(AchievementAnchorModeNote(mode))
    end

    UIDropDownMenu_Initialize(achievementAnchorDrop, function(_, level)
        if level ~= 1 then return end

        local profile = GetProfile()
        local current = NormalizeAchievementAlertAnchor(profile)
        local modes = {
            { value = "uiparent", label = AchievementAnchorModeLabel("uiparent") },
            { value = "alertframe", label = AchievementAnchorModeLabel("alertframe") },
        }

        for _, option in ipairs(modes) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            info.value = option.value
            info.checked = (option.value == current)
            info.func = function()
                SetAchievementAnchorMode(option.value)
                RefreshAchievementAnchorDropdown()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    local positionHeading = (T and T.Sans and T.Sans(canvas, 12, T.col.goldDim)) or canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    positionHeading:SetPoint("TOPLEFT", 16, -462)
    positionHeading:SetText(L["SOCIAL_POSITION_SECTION"] or "Position")

    local unlockTarget = MakeCheck(L["SOCIAL_TARGET_UNLOCK"] or "Unlock target nameplate (drag to move)", -456,
        function()
            local profile = GetProfile()
            return profile and profile.targetUnlock
        end,
        function(value)
            local profile = GetProfile()
            if profile then profile.targetUnlock = value end
        end)

    local resetTarget = CreateFrame("Button", nil, canvas)
    resetTarget:SetSize(300, 30)
    resetTarget:SetPoint("TOPLEFT", 40, -488)

    local resetBG = resetTarget:CreateTexture(nil, "BACKGROUND")
    resetBG:SetAllPoints()
    resetBG:SetColorTexture(0.11, 0.08, 0.04, 1.0)
    resetTarget.bg = resetBG

    local rbTop = resetTarget:CreateTexture(nil, "BORDER")
    rbTop:SetHeight(1)
    rbTop:SetPoint("TOPLEFT")
    rbTop:SetPoint("TOPRIGHT")
    rbTop:SetColorTexture(0.49, 0.37, 0.15, 1.0)
    local rbBottom = resetTarget:CreateTexture(nil, "BORDER")
    rbBottom:SetHeight(1)
    rbBottom:SetPoint("BOTTOMLEFT")
    rbBottom:SetPoint("BOTTOMRIGHT")
    rbBottom:SetColorTexture(0.49, 0.37, 0.15, 1.0)
    local rbLeft = resetTarget:CreateTexture(nil, "BORDER")
    rbLeft:SetWidth(1)
    rbLeft:SetPoint("TOPLEFT")
    rbLeft:SetPoint("BOTTOMLEFT")
    rbLeft:SetColorTexture(0.49, 0.37, 0.15, 1.0)
    local rbRight = resetTarget:CreateTexture(nil, "BORDER")
    rbRight:SetWidth(1)
    rbRight:SetPoint("TOPRIGHT")
    rbRight:SetPoint("BOTTOMRIGHT")
    rbRight:SetColorTexture(0.49, 0.37, 0.15, 1.0)
    resetTarget.borders = { rbTop, rbBottom, rbLeft, rbRight }

    local resetIcon = resetTarget:CreateTexture(nil, "ARTWORK")
    resetIcon:SetTexture("Interface\\AddOns\\Epithet\\icons\\ui\\epithet-ui-reset-16")
    resetIcon:SetSize(14, 14)
    resetIcon:SetPoint("LEFT", resetTarget, "LEFT", 10, 0)
    resetIcon:SetVertexColor(0.73, 0.57, 0.25, 1.0)
    resetTarget.icon = resetIcon

    local resetText = (T and T.Sans and T.Sans(resetTarget, 12, T.col.gold)) or resetTarget:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resetText:SetDrawLayer("OVERLAY", 2)
    resetText:SetPoint("LEFT", resetIcon, "RIGHT", 8, 0)
    resetText:SetPoint("RIGHT", resetTarget, "RIGHT", -10, 0)
    resetText:SetJustifyH("LEFT")
    resetText:SetText(L["SOCIAL_TARGET_RESET"] or "Reset target nameplate position")
    resetTarget.text = resetText

    -- Keep section spacing resilient to copy length and preserve visual grouping.
    enabled:ClearAllPoints()
    enabled:SetPoint("TOPLEFT", stateHeading, "BOTTOMLEFT", 0, -6)

    layoutHeading:ClearAllPoints()
    layoutHeading:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -22)

    previewFunnyToggle:ClearAllPoints()
    previewFunnyToggle:SetPoint("TOPLEFT", previewFrame, "BOTTOMLEFT", 0, -12)

    animatedPortraitToggle:ClearAllPoints()
    animatedPortraitToggle:SetPoint("TOPLEFT", previewFunnyToggle, "BOTTOMLEFT", 0, -6)

    fadeHeading:ClearAllPoints()
    fadeHeading:SetPoint("TOPLEFT", animatedPortraitToggle, "BOTTOMLEFT", 0, -14)

    fadeToggle:ClearAllPoints()
    fadeToggle:SetPoint("TOPLEFT", fadeHeading, "BOTTOMLEFT", 0, -6)

    fadeLabel:ClearAllPoints()
    fadeLabel:SetPoint("TOPLEFT", fadeToggle.text, "BOTTOMLEFT", 0, -8)

    fadeSlider:ClearAllPoints()
    fadeSlider:SetPoint("TOPLEFT", fadeLabel, "BOTTOMLEFT", 0, -8)

    fadeValueText:ClearAllPoints()
    fadeValueText:SetPoint("LEFT", fadeSlider, "RIGHT", 10, 0)

    behaviourHeading:ClearAllPoints()
    behaviourHeading:SetPoint("LEFT", fadeHeading, "LEFT", 0, 0)
    behaviourHeading:SetPoint("TOP", fadeSlider, "BOTTOM", 0, -14)

    hideInCombat:ClearAllPoints()
    hideInCombat:SetPoint("TOPLEFT", behaviourHeading, "BOTTOMLEFT", 0, -6)

    hideInGroup:ClearAllPoints()
    hideInGroup:SetPoint("TOPLEFT", hideInCombat, "BOTTOMLEFT", 0, -8)

    spotNotify:ClearAllPoints()
    spotNotify:SetPoint("TOPLEFT", hideInGroup, "BOTTOMLEFT", 0, -8)

    achievementNotifyHeading:ClearAllPoints()
    achievementNotifyHeading:SetPoint("TOPLEFT", spotNotify, "BOTTOMLEFT", 4, -10)

    achievementNotifyDrop:ClearAllPoints()
    achievementNotifyDrop:SetPoint("TOPLEFT", achievementNotifyHeading, "BOTTOMLEFT", -20, -2)

    achievementAnchorHeading:ClearAllPoints()
    achievementAnchorHeading:SetPoint("TOPLEFT", achievementNotifyDrop, "BOTTOMLEFT", 20, -8)

    achievementAnchorDrop:ClearAllPoints()
    achievementAnchorDrop:SetPoint("TOPLEFT", achievementAnchorHeading, "BOTTOMLEFT", -20, -2)

    achievementAnchorNote:ClearAllPoints()
    achievementAnchorNote:SetPoint("TOPLEFT", achievementAnchorDrop, "BOTTOMLEFT", 20, -2)

    positionHeading:ClearAllPoints()
    positionHeading:SetPoint("TOPLEFT", achievementAnchorNote, "BOTTOMLEFT", 0, -12)

    unlockTarget:ClearAllPoints()
    unlockTarget:SetPoint("TOPLEFT", positionHeading, "BOTTOMLEFT", 0, -6)

    resetTarget:ClearAllPoints()
    resetTarget:SetPoint("TOPLEFT", unlockTarget, "BOTTOMLEFT", 0, -8)

    resetTarget:SetScript("OnEnter", function(self_)
        self_.bg:SetColorTexture(0.16, 0.12, 0.07, 1.0)
        self_.icon:SetVertexColor(0.91, 0.78, 0.45, 1.0)
        if self_.text and self_.text.SetTextColor then
            self_.text:SetTextColor(0.96, 0.89, 0.65)
        end
        for _, border in ipairs(self_.borders) do
            border:SetColorTexture(0.91, 0.78, 0.45, 1.0)
        end
    end)
    resetTarget:SetScript("OnLeave", function(self_)
        self_.bg:SetColorTexture(0.11, 0.08, 0.04, 1.0)
        self_.icon:SetVertexColor(0.73, 0.57, 0.25, 1.0)
        if self_.text and self_.text.SetTextColor then
            self_.text:SetTextColor(0.91, 0.78, 0.45)
        end
        for _, border in ipairs(self_.borders) do
            border:SetColorTexture(0.49, 0.37, 0.15, 1.0)
        end
    end)

    local dependentControls = {
        layoutHeading,
        layoutDrop,
        previewHeading,
        previewFrame,
        previewFunnyToggle,
        animatedPortraitToggle,
        fadeHeading,
        fadeToggle,
        fadeLabel,
        fadeSlider,
        fadeValueText,
        behaviourHeading,
        hideInCombat,
        hideInGroup,
        spotNotify,
        achievementNotifyHeading,
        achievementNotifyDrop,
        achievementAnchorHeading,
        achievementAnchorDrop,
        achievementAnchorNote,
        positionHeading,
        unlockTarget,
        resetTarget,
    }

    local function SetControlVisible(control, visible)
        if not control then return end
        if visible then
            control:Show()
        else
            control:Hide()
        end
        if control.text then
            if visible then
                control.text:Show()
            else
                control.text:Hide()
            end
        end
    end

    local function UpdateScrollBounds(bottomControl)
        if not self.scrollFrame or not self.scrollContent then return end

        local viewportHeight = self.scrollFrame:GetHeight() or 0
        local top = title and title.GetTop and title:GetTop() or nil
        local bottom = bottomControl and bottomControl.GetBottom and bottomControl:GetBottom() or nil
        local contentHeight

        if top and bottom then
            contentHeight = math.floor((top - bottom) + 40)
            contentHeight = math.max(viewportHeight + 4, contentHeight)
        else
            contentHeight = math.max(viewportHeight + 4, 760)
        end

        self.scrollContent:SetHeight(contentHeight)

        local maxScroll = math.max(0, contentHeight - viewportHeight)
        local current = self.scrollFrame:GetVerticalScroll() or 0
        if current > maxScroll then
            self.scrollFrame:SetVerticalScroll(maxScroll)
        end
    end

    local function SyncContentWidths()
        SyncScrollWidth()

        local contentWidth = self.scrollContent and self.scrollContent:GetWidth() or 560
        local bodyWidth = math.max(320, math.floor(contentWidth - 32))

        if desc and desc.SetWidth then
            desc:SetWidth(bodyWidth)
        end

        if previewFrame and previewFrame.SetWidth then
            previewFrame:SetWidth(bodyWidth)
        end
    end

    local function RefreshControls()
        SyncContentWidths()
        enabled:Refresh()
        local profile = GetProfile()
        local socialEnabled = profile and profile.enabled

        RefreshLayoutDropdown()
        RefreshLayoutPreview()
        previewFunnyToggle:Refresh()
        animatedPortraitToggle:Refresh()
        fadeToggle:Refresh()

        local profileFade = GetProfile()
        local fadeDuration = (profileFade and tonumber(profileFade.fadeDuration)) or 4.0
        if fadeDuration < 0.5 then fadeDuration = 0.5 end
        if fadeDuration > 20.0 then fadeDuration = 20.0 end
        if profileFade then profileFade.fadeDuration = fadeDuration end
        Options._refreshingFadeSlider = true
        fadeSlider:SetValue(fadeDuration)
        Options._refreshingFadeSlider = false
        SetFadeValueText(fadeDuration)

        for _, control in ipairs(dependentControls) do
            SetControlVisible(control, socialEnabled)
        end

        local fadeEnabled = socialEnabled and profileFade and profileFade.fadeNameplates
        if fadeEnabled then
            fadeSlider:Enable()
            fadeLabel:SetAlpha(1)
            fadeValueText:SetAlpha(1)
        else
            fadeSlider:Disable()
            fadeLabel:SetAlpha(0.55)
            fadeValueText:SetAlpha(0.55)
        end

        hideInCombat:Refresh()
        hideInGroup:Refresh()
        spotNotify:Refresh()
        RefreshAchievementNotifyDropdown()
        RefreshAchievementAnchorDropdown()
        unlockTarget:Refresh()
        UpdateScrollBounds((socialEnabled and resetTarget) or enabled)
    end

    self.Refresh = function(self_)
        if not self_ or not self_.panel then return end
        RefreshControls()
    end

    enabled:HookScript("OnClick", function()
        RefreshControls()
    end)

    panel:SetScript("OnShow", function()
        if self.scrollFrame then
            self.scrollFrame:SetVerticalScroll(0)
        end
        RefreshControls()
    end)

    resetTarget:SetScript("OnClick", function()
        local profile = GetProfile()
        if profile then
            profile.targetAnchorX = 0
            profile.targetAnchorY = -120
            profile.targetUnlock = false
        end
        if ns.SocialLayer and ns.SocialLayer.ResetTargetFramePosition then
            ns.SocialLayer:ResetTargetFramePosition()
        else
            RefreshAll()
        end
        RefreshControls()
    end)

    if BlizzardSettings and BlizzardSettings.RegisterCanvasLayoutCategory and BlizzardSettings.RegisterAddOnCategory then
        local category = BlizzardSettings.RegisterCanvasLayoutCategory(panel, panel.name)
        BlizzardSettings.RegisterAddOnCategory(category)
        self.category = category

        if category and category.SetOnRefresh then
            category:SetOnRefresh(function()
                RefreshControls()
            end)
        end

        -- Language lives on its own sub-tab under the Epithet category.
        self:BuildLanguagePanel(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        -- Legacy path: register the language panel as a child of "Epithet".
        self:BuildLanguagePanel(nil)
    end
end