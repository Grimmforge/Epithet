-- =============================================================================
-- Epithet — Social Layouts Registry
-- Shared layout assets and dispatchers. Individual layouts register from Core/SocialLayouts/*.lua.
-- =============================================================================
local _, ns = ...

local Layouts = ns.Layouts or {}
ns.Layouts = Layouts

Layouts.order = Layouts.order or {}
Layouts.registry = Layouts.registry or {}
Layouts.defaultKey = Layouts.defaultKey or "portrait"

local WHITE = "Interface\\Buttons\\WHITE8X8"
local CROWN_ICON = "Interface\\AddOns\\Epithet\\icons\\logo\\epithet-crown-mark-32"
local CROWN_Y_OFFSET = -7
local CROWN_SIZE_MULTIPLIER = 1.2

local floor = math.floor
local ceil = math.ceil
local max = math.max

local RARITY_GEMS = ns.Theme and ns.Theme.RarityGems32

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

    -- Keep portrait first for stable picker ordering regardless of registration order.
    if self.registry["portrait"] then
        local portraitDef = self.registry["portrait"]
        local portraitLabel = (portraitDef.labelKey and L and L[portraitDef.labelKey]) or portraitDef.label or "portrait"
        options[#options + 1] = { key = "portrait", label = portraitLabel }
    end

    for _, key in ipairs(self.order) do
        if key ~= "portrait" then
        local def = self.registry[key]
        if def then
            local label = (def.labelKey and L and L[def.labelKey]) or def.label or key
            options[#options + 1] = { key = key, label = label }
        end
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

-- Resize a font string in place, keeping the font file and flags it was built
-- with. Every layout has to set its own title size on each pass: the font string
-- is shared between layouts, so a size left behind by the previous one sticks.
function Layouts:SetFontSize(fontString, size)
    if not (fontString and fontString.GetFont and fontString.SetFont) then return end
    size = tonumber(size)
    if not size then return end

    local path, current, flags = fontString:GetFont()
    if not path or current == size then return end
    fontString:SetFont(path, size, flags)
end

-- Measure how a piece of text lays out, before anything visible is resized.
--
-- The visible title/rarity font strings are anchored on both sides (SetAllPoints
-- on their row), and a region anchored left AND right ignores SetWidth — so they
-- cannot answer "how tall would you be at width N?" without first being torn off
-- their anchors. This probe is anchored by a single point, so constraining its
-- width really does wrap it and GetStringHeight reports the wrapped height.
--
-- Returns naturalWidth (the unwrapped single-line width), lineHeight, and the
-- number of lines the text needs at wrapWidth (capped at maxLines when given).
-- Pass wrapWidth = 0/nil to only ask for the natural width.
function Layouts:MeasureText(frame, source, text, wrapWidth, maxLines)
    if not (frame and frame.CreateFontString and source and source.GetFont) then
        return 0, 0, 1
    end

    local path, size, flags = source:GetFont()
    if not path then return 0, 0, 1 end

    local probe = frame.__epithetTextProbe
    if not probe then
        probe = frame:CreateFontString(nil, "BACKGROUND")
        probe:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        -- Left shown so the client definitely lays it out, but fully transparent
        -- and emptied after every measurement, so it draws nothing either way.
        probe:SetAlpha(0)
        frame.__epithetTextProbe = probe
    end

    probe:SetFont(path, size or 12, flags)
    local spacing = (source.GetSpacing and source:GetSpacing()) or 0
    if probe.SetSpacing then probe:SetSpacing(spacing) end

    probe:SetWordWrap(false)
    probe:SetWidth(0)
    probe:SetText(text or "")

    local naturalWidth = probe:GetStringWidth() or 0
    local lineHeight = probe:GetStringHeight() or 0
    if lineHeight <= 0 then
        lineHeight = (size or 12) + 2
    end

    local lines = 1
    wrapWidth = tonumber(wrapWidth) or 0
    if wrapWidth > 0 and naturalWidth > wrapWidth then
        probe:SetWordWrap(true)
        probe:SetWidth(wrapWidth)

        -- wrapped = n * lineHeight + (n - 1) * spacing, solved for n.
        local wrapped = probe:GetStringHeight() or lineHeight
        lines = floor(((wrapped + spacing) / (lineHeight + spacing)) + 0.5)

        -- Words never break, so dividing the natural width by the wrap width can
        -- only ever undercount lines. Use it as a floor in case GetStringHeight
        -- reports a stale single line before the string has been laid out once.
        local estimate = ceil(naturalWidth / wrapWidth)
        if lines < estimate then lines = estimate end
        if lines < 1 then lines = 1 end
    end

    maxLines = tonumber(maxLines)
    if maxLines and maxLines >= 1 and lines > maxLines then
        lines = maxLines
    end

    -- Don't leave the measured string parked on a live region.
    probe:SetText("")

    return naturalWidth, lineHeight, lines
end

-- Height of a text block of `lines` lines, for a font measured at `lineHeight`.
function Layouts:TextBlockHeight(lines, lineHeight, spacing)
    lines = max(1, tonumber(lines) or 1)
    lineHeight = tonumber(lineHeight) or 0
    spacing = tonumber(spacing) or 0
    return ceil((lines * lineHeight) + ((lines - 1) * spacing))
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

-- Drop the text-driven sizes SizePill left on a frame. Layouts derive their own
-- geometry from these, so carrying one layout's numbers into another would size
-- the plate from measurements taken with a different font and banner.
function Layouts:ClearDynamicLayout(frame)
    if not frame then return end
    frame.dynamicTitleLines = nil
    frame.dynamicTitleHeight = nil
    frame.dynamicFrameWidth = nil
    frame.dynamicFrameHeight = nil
    frame.dynamicBannerWidth = nil
    frame.dynamicBannerHeight = nil
end

function Layouts:ApplyLayoutToFrame(frame, profile)
    if not frame then return end
    local def, key = self:GetLayoutDefinition(profile)
    local m = def and def.metrics
    if not m then return end

    if frame.layoutKey ~= key then
        self:ClearDynamicLayout(frame)
    end

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
    frame.rarityText:SetText(rarityText or (ns.L and ns.L["RARITY_UNKNOWN"]) or "UNKNOWN")

    local style = (frame.layoutMetrics and frame.layoutMetrics.layoutStyle) or "classic"
    frame.portraitUnit = "target"
    self:ApplyPortraitTexture(frame.portrait, "target", style, frame.portraitShell)

    local qCol = ns.QUALITY_COLOURS and ns.QUALITY_COLOURS[q]
    if qCol and qCol.text then
        frame.rarityText:SetTextColor(qCol.text.r, qCol.text.g, qCol.text.b)
    end

    -- Reflow width/height after content updates so text and metrics stay aligned.
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

-- Core/SocialLayouts/classic.lua and Core/SocialLayouts/portrait.lua register themselves
-- when they load (toc order places them right after this file).
