-- =============================================================================
-- Epithet — Social Layout: Classic
-- =============================================================================
local _, ns = ...

local Layouts = ns.Layouts
local CreateFrame = CreateFrame
local floor = math.floor

local PORTRAIT_MODE_2D = "2d"
local PORTRAIT_MODE_3D = "3d"
local DEFAULT_EDIT_HINT_TOP_OFFSET_Y = 3

local function ResolvePortraitMode(frame, m)
    local mode = (frame and frame.portraitModeOverride)
        or (m and m.portraitMode)
        or (ns.GetPortraitMode and ns.GetPortraitMode())
        or PORTRAIT_MODE_3D

    if type(mode) == "string" then
        mode = mode:lower()
    end
    if mode ~= PORTRAIT_MODE_2D then
        mode = PORTRAIT_MODE_3D
    end
    return mode
end

local function EnsurePortraitModel(frame)
    if not frame or frame.portraitModel or not frame.portraitShell then return end

    frame.portraitModel = CreateFrame("PlayerModel", nil, frame.portraitShell)
    frame.portraitModel:SetFrameLevel(frame.portraitShell:GetFrameLevel() + 2)
    if frame.portraitModel.SetCamDistanceScale then
        frame.portraitModel:SetCamDistanceScale(1.0)
    end
    if frame.portraitModel.SetPortraitZoom then
        frame.portraitModel:SetPortraitZoom(1)
    end
end

if not Layouts or not Layouts.RegisterLayout then
    return
end

Layouts:RegisterLayout("classic", {
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

    ApplyLayout = function(self, frame, m)
        if frame.editHintTop then
            frame.editHintTop:ClearAllPoints()
            frame.editHintTop:SetPoint("BOTTOM", frame, "TOP", 0, DEFAULT_EDIT_HINT_TOP_OFFSET_Y)
        end

        if frame.portraitMask then
            if frame.portrait and frame.portrait.RemoveMaskTexture and frame.portraitTextureMasked then
                frame.portrait:RemoveMaskTexture(frame.portraitMask)
                frame.portraitTextureMasked = false
            end
            if frame.portraitBG and frame.portraitBG.RemoveMaskTexture and frame.portraitBGMasked then
                frame.portraitBG:RemoveMaskTexture(frame.portraitMask)
                frame.portraitBGMasked = false
            end
        end

        local mode = ResolvePortraitMode(frame, m)
        frame.portraitMode = mode
        if mode == PORTRAIT_MODE_3D then
            EnsurePortraitModel(frame)
        end

        if frame.portraitRingFrame then
            frame.portraitRingFrame:Hide()
        end

        if frame.scrollBackdrop then
            frame.scrollBackdrop:Hide()
        end

        if frame.bannerFill then frame.bannerFill:Hide() end
        if frame.bannerTabLeft then frame.bannerTabLeft:Hide() end
        if frame.bannerTabRight then frame.bannerTabRight:Hide() end
        if frame.bannerTabLeftTop then frame.bannerTabLeftTop:Hide() end
        if frame.bannerTabLeftBottom then frame.bannerTabLeftBottom:Hide() end
        if frame.bannerTabRightTop then frame.bannerTabRightTop:Hide() end
        if frame.bannerTabRightBottom then frame.bannerTabRightBottom:Hide() end
        if frame.bannerTopLine then frame.bannerTopLine:Hide() end
        if frame.bannerBottomLine then frame.bannerBottomLine:Hide() end
        if frame.bannerLeftLine then frame.bannerLeftLine:Hide() end
        if frame.bannerRightLine then frame.bannerRightLine:Hide() end
        if frame.bannerTailTrimLeft then frame.bannerTailTrimLeft:Hide() end
        if frame.bannerTailTrimRight then frame.bannerTailTrimRight:Hide() end

        if mode == PORTRAIT_MODE_3D then
            if frame.portrait then frame.portrait:Hide() end
            if frame.portraitModel then frame.portraitModel:Show() end
        else
            if frame.portraitModel then frame.portraitModel:Hide() end
            if frame.portrait then frame.portrait:Show() end
        end

        if frame.SetBackdropColor then
            if ns.Theme and ns.Theme.col then
                frame:SetBackdropColor(ns.Theme.col.bg0.r, ns.Theme.col.bg0.g, ns.Theme.col.bg0.b, 0.86)
                frame:SetBackdropBorderColor(ns.Theme.col.goldDeep.r, ns.Theme.col.goldDeep.g, ns.Theme.col.goldDeep.b, 0.9)
            else
                frame:SetBackdropColor(0.08, 0.06, 0.04, 0.86)
                frame:SetBackdropBorderColor(0.72, 0.58, 0.26, 0.9)
            end
        end

        if frame.portraitBG then
            frame.portraitBG:SetColorTexture(0.05, 0.05, 0.05, 1.0)
        end

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

        self:LayoutTargetPortrait(frame)

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
            frame.titleText:SetShadowOffset(0, 0)
        end

        if frame.rarityText then
            frame.rarityText:SetWordWrap(false)
            frame.rarityText:SetJustifyH("LEFT")
            frame.rarityText:SetJustifyV("MIDDLE")
            frame.rarityText:SetShadowOffset(0, 0)
        end

        if frame.crownFrame then
            frame.crownFrame:Show()
        end

        if frame.portraitTopRule and frame.portraitBottomRule then
            frame.portraitTopRule:Hide()
            frame.portraitBottomRule:Hide()
        end
    end,

    LayoutPortrait = function(self, frame, m)
        if not frame or not frame.portraitShell then return end

        if frame.portraitRingFrame then
            frame.portraitRingFrame:Hide()
        end

        local mode = frame.portraitMode or ResolvePortraitMode(frame, m)

        local topInset = m.portraitTopInset or m.portraitInsetY or 3
        local bottomInset = m.portraitBottomInset or m.portraitInsetY or 3
        local portraitW = math.max(m.portraitMinWidth, (frame:GetHeight() or m.frameHeight) - (topInset + bottomInset))

        frame.portraitShell:ClearAllPoints()
        frame.portraitShell:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -m.portraitRightInset, -topInset)
        frame.portraitShell:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -m.portraitRightInset, bottomInset)
        frame.portraitShell:SetWidth(portraitW)

        if mode == PORTRAIT_MODE_3D and frame.portraitModel then
            if frame.portrait then frame.portrait:Hide() end
            frame.portraitModel:Show()
            frame.portraitModel:ClearAllPoints()
            frame.portraitModel:SetPoint("TOPLEFT", frame.portraitShell, "TOPLEFT", 0, 0)
            frame.portraitModel:SetPoint("BOTTOMRIGHT", frame.portraitShell, "BOTTOMRIGHT", 0, 0)
            if frame.portraitUnit and frame.portraitModel.SetUnit then
                local ok = pcall(frame.portraitModel.SetUnit, frame.portraitModel, frame.portraitUnit)
                if not ok then
                    pcall(frame.portraitModel.SetUnit, frame.portraitModel, "player")
                end
                if frame.portraitModel.RefreshUnit then
                    pcall(frame.portraitModel.RefreshUnit, frame.portraitModel)
                end
            end
        elseif frame.portrait then
            if frame.portraitModel then frame.portraitModel:Hide() end
            frame.portrait:ClearAllPoints()
            frame.portrait:SetPoint("TOPLEFT", frame.portraitShell, "TOPLEFT", 0, -1)
            frame.portrait:SetPoint("BOTTOMRIGHT", frame.portraitShell, "BOTTOMRIGHT", -1, 0)
            frame.portrait:Show()
        end

        if frame.crownFrame then
            local crownSize = math.max(m.crownMinSize, floor((portraitW * m.crownBaseScale * self:GetCrownSizeMultiplier()) + 0.5))
            frame.crownFrame:SetSize(crownSize, crownSize)
            frame.crownFrame:ClearAllPoints()
            frame.crownFrame:SetPoint("BOTTOM", frame.portraitShell, "TOP", 0, self:GetCrownYOffset())
        end

        if frame.portraitTopRule and frame.portraitBottomRule then
            frame.portraitTopRule:Hide()
            frame.portraitBottomRule:Hide()
        end

        if mode ~= PORTRAIT_MODE_3D and frame.portrait and frame.portraitUnit then
            self:ApplyPortraitTexture(frame.portrait, frame.portraitUnit, "classic", frame.portraitShell)
        end
    end,

    SizePill = function(self, frame, m)
        if not frame or not frame.titleText or not frame.rarityText then return end

        local titleWidth = frame.titleText:GetStringWidth() or 0
        local rarityWidth = frame.rarityText:GetStringWidth() or 0
        local textColWidth = math.max(titleWidth, rarityWidth)

        local topInset = m.portraitTopInset or m.portraitInsetY or 3
        local bottomInset = m.portraitBottomInset or m.portraitInsetY or 3
        local portraitW = math.max(m.portraitMinWidth, (frame:GetHeight() or m.frameHeight) - (topInset + bottomInset))

        local width = math.max(m.minWidth, math.min(m.maxWidth,
            floor(m.leftColWidth + m.centerGapX + textColWidth + m.centerGapX + portraitW + m.widthTailPad)
        ))

        frame:SetWidth(width)
        frame:SetHeight(m.frameHeight)
        self:LayoutTargetPortrait(frame)
    end,
})
