-- =============================================================================
-- Epithet — Social Layouts Registry
-- Shared layout assets and dispatchers. Individual layouts register from Core/layouts/*.lua.
-- =============================================================================
local _, ns = ...

local Layouts = ns.Layouts or {}
ns.Layouts = Layouts

Layouts.order = Layouts.order or {}
Layouts.registry = Layouts.registry or {}
Layouts.defaultKey = Layouts.defaultKey or "classic"

local WHITE = "Interface\\Buttons\\WHITE8X8"
local CROWN_ICON = "Interface\\AddOns\\Epithet\\icons\\logo\\epithet-crown-mark-32"
local CROWN_Y_OFFSET = -7
local CROWN_SIZE_MULTIPLIER = 1.2

local RARITY_GEMS = {
    "Interface\\AddOns\\Epithet\\icons\\rarity\\epithet-rarity-1-common-32",
    "Interface\\AddOns\\Epithet\\icons\\rarity\\epithet-rarity-2-uncommon-32",
    "Interface\\AddOns\\Epithet\\icons\\rarity\\epithet-rarity-3-rare-32",
    "Interface\\AddOns\\Epithet\\icons\\rarity\\epithet-rarity-4-epic-32",
    "Interface\\AddOns\\Epithet\\icons\\rarity\\epithet-rarity-5-legendary-32",
}

local function RegisterFallbackClassic(self)
    self:RegisterLayout("classic", {
        label = "Current (Classic)",
        labelKey = "SOCIAL_LAYOUT_CLASSIC",
        metrics = {
            layoutStyle = "classic",
            frameHeight = 58,
            minWidth = 248,
            maxWidth = 448,
            edgeInsetY = 3,
            leftInsetX = 4,
            leftColWidth = 44,
            gemSize = 40,
            centerGapX = 9,
            centerTopOffset = -6,
            centerBottomOffset = 6,
            portraitRightInset = 1,
            portraitTopInset = 4,
            portraitBottomInset = 3,
            portraitMinWidth = 20,
            crownBaseScale = 0.65,
            crownMinSize = 24,
            widthTailPad = 8,
        },

        ApplyLayout = function(layouts, frame, m)
            frame.dynamicTitleHeight = nil
            frame:SetHeight(m.frameHeight)

            if frame.leftCol then
                frame.leftCol:ClearAllPoints()
                frame.leftCol:SetPoint("TOPLEFT", frame, "TOPLEFT", m.leftInsetX, -m.edgeInsetY)
                frame.leftCol:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", m.leftInsetX, m.edgeInsetY)
                frame.leftCol:SetWidth(m.leftColWidth)
            end
            if frame.gem then
                frame.gem:SetSize(m.gemSize, m.gemSize)
            end

            layouts:LayoutTargetPortrait(frame)

            if frame.centerCol and frame.leftCol and frame.portraitShell then
                frame.centerCol:ClearAllPoints()
                frame.centerCol:SetPoint("TOPLEFT", frame.leftCol, "TOPRIGHT", m.centerGapX, m.centerTopOffset)
                frame.centerCol:SetPoint("BOTTOMRIGHT", frame.portraitShell, "BOTTOMLEFT", -m.centerGapX, m.centerBottomOffset)
            end

            if frame.titleRow and frame.centerCol then
                frame.titleRow:ClearAllPoints()
                frame.titleRow:SetPoint("TOPLEFT", frame.centerCol, "TOPLEFT", 0, 0)
                frame.titleRow:SetPoint("TOPRIGHT", frame.centerCol, "TOPRIGHT", 0, 0)
                frame.titleRow:SetHeight(20)
            end

            if frame.rarityRow and frame.centerCol then
                frame.rarityRow:ClearAllPoints()
                frame.rarityRow:SetPoint("BOTTOMLEFT", frame.centerCol, "BOTTOMLEFT", 0, 0)
                frame.rarityRow:SetPoint("BOTTOMRIGHT", frame.centerCol, "BOTTOMRIGHT", 0, 0)
                frame.rarityRow:SetHeight(18)
            end

            if frame.titleText then
                frame.titleText:SetWordWrap(false)
                frame.titleText:SetJustifyH("LEFT")
                frame.titleText:SetJustifyV("MIDDLE")
            end

            if frame.rarityText then
                frame.rarityText:SetWordWrap(false)
                frame.rarityText:SetJustifyH("LEFT")
                frame.rarityText:SetJustifyV("MIDDLE")
            end

            if frame.crownFrame then
                frame.crownFrame:Show()
            end

            if frame.portraitTopRule and frame.portraitBottomRule then
                frame.portraitTopRule:Hide()
                frame.portraitBottomRule:Hide()
            end
        end,

        LayoutPortrait = function(layouts, frame, m)
            if not frame or not frame.portraitShell then return end

            local topInset = m.portraitTopInset or m.portraitInsetY or 3
            local bottomInset = m.portraitBottomInset or m.portraitInsetY or 3
            local portraitW = math.max(m.portraitMinWidth, (frame:GetHeight() or m.frameHeight) - (topInset + bottomInset))

            frame.portraitShell:ClearAllPoints()
            frame.portraitShell:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -m.portraitRightInset, -topInset)
            frame.portraitShell:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -m.portraitRightInset, bottomInset)
            frame.portraitShell:SetWidth(portraitW)

            if frame.crownFrame then
                local crownSize = math.max(m.crownMinSize, math.floor((portraitW * m.crownBaseScale * layouts:GetCrownSizeMultiplier()) + 0.5))
                frame.crownFrame:SetSize(crownSize, crownSize)
                frame.crownFrame:ClearAllPoints()
                frame.crownFrame:SetPoint("BOTTOM", frame.portraitShell, "TOP", 0, layouts:GetCrownYOffset())
            end

            if frame.portraitTopRule and frame.portraitBottomRule then
                frame.portraitTopRule:Hide()
                frame.portraitBottomRule:Hide()
            end

            if frame.portrait and frame.portraitUnit then
                layouts:ApplyPortraitTexture(frame.portrait, frame.portraitUnit, "classic", frame.portraitShell)
            end
        end,

        SizePill = function(layouts, frame, m)
            if not frame or not frame.titleText or not frame.rarityText then return end

            local titleWidth = frame.titleText:GetStringWidth() or 0
            local rarityWidth = frame.rarityText:GetStringWidth() or 0
            local textColWidth = math.max(titleWidth, rarityWidth)

            local topInset = m.portraitTopInset or m.portraitInsetY or 3
            local bottomInset = m.portraitBottomInset or m.portraitInsetY or 3
            local portraitW = math.max(m.portraitMinWidth, (frame:GetHeight() or m.frameHeight) - (topInset + bottomInset))

            local width = math.max(m.minWidth, math.min(m.maxWidth,
                math.floor(m.leftColWidth + m.centerGapX + textColWidth + m.centerGapX + portraitW + m.widthTailPad)
            ))

            frame:SetWidth(width)
            frame:SetHeight(m.frameHeight)
            layouts:LayoutTargetPortrait(frame)
        end,
    })
end

local function RegisterFallbackPortrait(self)
    self:RegisterLayout("portrait", {
        label = "Portrait Card",
        labelKey = "SOCIAL_LAYOUT_PORTRAIT",
        metrics = {
            layoutStyle = "portrait",
            frameWidth = 164,
            frameHeight = 176,
            edgeInsetX = 6,
            edgeInsetY = 6,
            row1Height = 18,
            rowGap = 5,
            portraitRowHeight = 74,
            titleRowHeight = 20,
            titleMinHeight = 18,
            titleMaxHeight = 56,
            gemColWidth = 20,
            gemTextGap = 6,
            gemSize = 16,
            portraitSideInset = 0,
            crownBaseScale = 0.20,
            crownMinSize = 24,
        },

        ApplyLayout = function(layouts, frame, m)
            local edgeY = m.edgeInsetY or 0
            local row1Height = m.row1Height or 18
            local rowGap = m.rowGap or 5
            local portraitHeight = m.portraitRowHeight or 74
            local titleHeight = frame.dynamicTitleHeight or m.titleMinHeight or m.titleRowHeight or 20
            local frameHeight = (edgeY * 2) + row1Height + (rowGap * 2) + portraitHeight + titleHeight

            frame:SetSize(m.frameWidth, frameHeight)

            if frame.centerCol then
                frame.centerCol:ClearAllPoints()
                frame.centerCol:SetPoint("TOPLEFT", frame, "TOPLEFT", m.edgeInsetX, -m.edgeInsetY)
                frame.centerCol:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -m.edgeInsetX, m.edgeInsetY)
            end

            if frame.leftCol then
                frame.leftCol:ClearAllPoints()
                frame.leftCol:SetPoint("TOPLEFT", frame.centerCol, "TOPLEFT", 0, 0)
                frame.leftCol:SetPoint("BOTTOMLEFT", frame.centerCol, "TOPLEFT", 0, -m.row1Height)
                frame.leftCol:SetWidth(m.gemColWidth)
            end

            if frame.rarityRow then
                frame.rarityRow:ClearAllPoints()
                frame.rarityRow:SetPoint("TOPLEFT", frame.centerCol, "TOPLEFT", m.gemColWidth + m.gemTextGap, 0)
                frame.rarityRow:SetPoint("TOPRIGHT", frame.centerCol, "TOPRIGHT", 0, 0)
                frame.rarityRow:SetHeight(m.row1Height)
            end

            if frame.titleRow then
                frame.titleRow:ClearAllPoints()
                frame.titleRow:SetPoint("BOTTOMLEFT", frame.centerCol, "BOTTOMLEFT", 0, 0)
                frame.titleRow:SetPoint("BOTTOMRIGHT", frame.centerCol, "BOTTOMRIGHT", 0, 0)
                frame.titleRow:SetHeight(titleHeight)
            end

            if frame.titleText then
                frame.titleText:SetWordWrap(true)
                frame.titleText:SetJustifyH("LEFT")
                frame.titleText:SetJustifyV("TOP")
            end

            if frame.rarityText then
                frame.rarityText:SetWordWrap(false)
                frame.rarityText:SetJustifyH("LEFT")
                frame.rarityText:SetJustifyV("MIDDLE")
            end

            if frame.gem then
                frame.gem:SetSize(m.gemSize, m.gemSize)
            end

            if frame.crownFrame then
                frame.crownFrame:Hide()
            end

            if frame.portraitTopRule and frame.portraitBottomRule then
                frame.portraitTopRule:Show()
                frame.portraitBottomRule:Show()
            end

            layouts:LayoutTargetPortrait(frame)
        end,

        LayoutPortrait = function(layouts, frame, m)
            if not frame or not frame.portraitShell then return end

            local edgeY = m.edgeInsetY or 0
            local row1Height = m.row1Height or 18
            local rowGap = m.rowGap or 5
            local titleRowHeight = frame.dynamicTitleHeight or m.titleMinHeight or m.titleRowHeight or 20
            local portraitHeight = m.portraitRowHeight or 74
            local sideInset = m.portraitSideInset or m.edgeInsetX or 0

            local portraitTop = edgeY + row1Height + rowGap
            local portraitBottom = edgeY + titleRowHeight + rowGap
            local frameHeight = (edgeY * 2) + row1Height + (rowGap * 2) + portraitHeight + titleRowHeight

            frame:SetHeight(frameHeight)

            frame.portraitShell:ClearAllPoints()
            frame.portraitShell:SetPoint("TOPLEFT", frame, "TOPLEFT", sideInset, -portraitTop)
            frame.portraitShell:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -sideInset, portraitBottom)

            if frame.portraitTopRule and frame.portraitBottomRule then
                frame.portraitTopRule:ClearAllPoints()
                frame.portraitTopRule:SetPoint("BOTTOMLEFT", frame.portraitShell, "TOPLEFT", 0, 0)
                frame.portraitTopRule:SetPoint("BOTTOMRIGHT", frame.portraitShell, "TOPRIGHT", 0, 0)

                frame.portraitBottomRule:ClearAllPoints()
                frame.portraitBottomRule:SetPoint("TOPLEFT", frame.portraitShell, "BOTTOMLEFT", 0, 0)
                frame.portraitBottomRule:SetPoint("TOPRIGHT", frame.portraitShell, "BOTTOMRIGHT", 0, 0)
            end

            if frame.crownFrame then
                frame.crownFrame:Hide()
            end

            if frame.portrait and frame.portraitUnit then
                layouts:ApplyPortraitTexture(frame.portrait, frame.portraitUnit, "portrait", frame.portraitShell)
            end
        end,

        SizePill = function(layouts, frame, m)
            if not frame or not frame.titleText or not frame.rarityText then return end

            local edgeX = m.edgeInsetX or 6
            local titleWidth = math.max(80, (m.frameWidth or 164) - (edgeX * 2))
            local titleMinHeight = m.titleMinHeight or m.titleRowHeight or 20
            local titleMaxHeight = m.titleMaxHeight or 56

            frame.titleText:SetWordWrap(false)
            frame.titleText:SetWidth(titleWidth)

            local singleWidth = frame.titleText:GetStringWidth() or titleWidth
            local lineHeight = math.max(12, math.ceil(frame.titleText:GetStringHeight() or titleMinHeight))
            local lines = math.max(1, math.ceil(singleWidth / titleWidth))
            local measured = lines * lineHeight
            frame.dynamicTitleHeight = math.max(titleMinHeight, math.min(titleMaxHeight, measured))

            frame.titleText:SetWordWrap(true)

            layouts:ApplyLayoutToFrame(frame, { layout = "portrait" })
            layouts:LayoutTargetPortrait(frame)
        end,
    })
end

function Layouts:RegisterLayout(key, definition)
    if type(key) ~= "string" or key == "" or type(definition) ~= "table" then
        return
    end

    if not self.registry[key] then
        self.order[#self.order + 1] = key
    end
    self.registry[key] = definition
end

function Layouts:GetDefaultLayoutKey()
    return self.defaultKey
end

function Layouts:IsValidLayoutKey(key)
    return type(key) == "string" and self.registry[key] ~= nil
end

function Layouts:GetLayoutDefinition(profile)
    local key = profile and profile.layout or nil
    if not self:IsValidLayoutKey(key) then
        key = self.defaultKey
    end
    return self.registry[key], key
end

function Layouts:GetLayoutOptions(L)
    local options = {}
    for _, key in ipairs(self.order) do
        local def = self.registry[key]
        if def then
            local label = (def.labelKey and L and L[def.labelKey]) or def.label or key
            options[#options + 1] = { key = key, label = label }
        end
    end
    return options
end

function Layouts:GetPreviewStyle(profile)
    local def, key = self:GetLayoutDefinition(profile)
    if not def then
        def = self.registry[self.defaultKey]
        key = self.defaultKey
    end
    local metrics = def and def.metrics
    return {
        key = key,
        metrics = metrics,
        crownOffset = CROWN_Y_OFFSET,
        crownMultiplier = CROWN_SIZE_MULTIPLIER,
        crownIcon = CROWN_ICON,
        rarityGem = RARITY_GEMS[5],
    }
end

function Layouts:GetWhiteTexture()
    return WHITE
end

function Layouts:GetCrownIcon()
    return CROWN_ICON
end

function Layouts:GetCrownYOffset()
    return CROWN_Y_OFFSET
end

function Layouts:GetCrownSizeMultiplier()
    return CROWN_SIZE_MULTIPLIER
end

function Layouts:GetRarityGem(quality)
    local q = tonumber(quality) or 1
    if q < 1 then q = 1 end
    if q > #RARITY_GEMS then q = #RARITY_GEMS end
    return RARITY_GEMS[q]
end

function Layouts:MakeHintPill(parent)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetBackdrop({
        bgFile = WHITE,
        edgeFile = WHITE,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.06, 0.05, 0.03, 0.92)
    frame:SetBackdropBorderColor(0.95, 0.84, 0.52, 0.95)
    frame:Hide()
    return frame
end

function Layouts:ApplyPortraitTexture(texture, unit, style, shell)
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

function Layouts:ApplyLayoutToFrame(frame, profile)
    if not frame then return end
    local def, key = self:GetLayoutDefinition(profile)
    local m = def and def.metrics
    if not m then return end

    frame.layoutKey = key
    frame.layoutMetrics = m
    if def.ApplyLayout then
        def.ApplyLayout(self, frame, m, profile)
    end
end

function Layouts:LayoutTargetPortrait(frame)
    if not frame then return end
    local def = frame.layoutKey and self.registry[frame.layoutKey] or nil
    if not def and frame.layoutMetrics then
        local fallbackDef = self.registry[self.defaultKey]
        def = fallbackDef
    end
    if def and def.LayoutPortrait then
        def.LayoutPortrait(self, frame, frame.layoutMetrics or def.metrics)
    end
end

function Layouts:SizeTargetPill(frame, profile)
    if not frame then return end
    self:ApplyLayoutToFrame(frame, profile)
    local def = frame.layoutKey and self.registry[frame.layoutKey] or nil
    if def and def.SizePill then
        def.SizePill(self, frame, frame.layoutMetrics or def.metrics)
    end
end

function Layouts:SetTargetPillContent(frame, titleText, quality, rarityText)
    if not frame or not frame.gem or not frame.titleText or not frame.rarityText then return end

    local q = tonumber(quality) or 1
    if q < 1 or q > 5 then q = 1 end

    frame.gem:SetTexture(self:GetRarityGem(q))
    frame.titleText:SetText(titleText or "")
    frame.rarityText:SetText(rarityText or "UNKNOWN")

    local style = (frame.layoutMetrics and frame.layoutMetrics.layoutStyle) or "classic"
    frame.portraitUnit = "target"
    self:ApplyPortraitTexture(frame.portrait, "target", style, frame.portraitShell)

    local qCol = ns.QUALITY_COLOURS and ns.QUALITY_COLOURS[q]
    if qCol and qCol.text then
        frame.rarityText:SetTextColor(qCol.text.r, qCol.text.g, qCol.text.b)
    end

    if ns.SocialLayer and ns.SocialLayer.SizeTargetPill then
        ns.SocialLayer:SizeTargetPill(frame)
    end
end

function Layouts:SetTargetPillPlaceholder(frame)
    if not frame or not frame.gem or not frame.titleText or not frame.rarityText then return end

    frame.gem:SetTexture(self:GetRarityGem(3))
    frame.titleText:SetText(ns.L and (ns.L["SOCIAL_TARGET_PLACEHOLDER_TITLE"] or "Example Title") or "Example Title")
    frame.rarityText:SetText(ns.L and (ns.L["SOCIAL_TARGET_PLACEHOLDER_RARITY"] or "RARE") or "RARE")

    local qCol = ns.QUALITY_COLOURS and ns.QUALITY_COLOURS[3]
    if qCol and qCol.text then
        frame.rarityText:SetTextColor(qCol.text.r, qCol.text.g, qCol.text.b)
    end

    local style = (frame.layoutMetrics and frame.layoutMetrics.layoutStyle) or "classic"
    frame.portraitUnit = "player"
    self:ApplyPortraitTexture(frame.portrait, "player", style, frame.portraitShell)

    if ns.SocialLayer and ns.SocialLayer.SizeTargetPill then
        ns.SocialLayer:SizeTargetPill(frame)
    end
end

if not Layouts.registry.classic then
    RegisterFallbackClassic(Layouts)
end

if not Layouts.registry.portrait then
    RegisterFallbackPortrait(Layouts)
end
