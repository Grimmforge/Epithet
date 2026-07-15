-- =============================================================================
-- Epithet — Social Layout: Portrait Card
-- =============================================================================
-- Portrait render mode is selectable: "2d" (masked texture) or "3d" (PlayerModel
-- cropped by an overlay ring). Resolution order, highest priority first:
--   1. frame.portraitModeOverride  -- explicit per-frame override set by caller
--   2. m.portraitMode              -- passed in via the layout metrics
--   3. ns.GetPortraitMode()        -- saved setting hook (e.g. options menu)
--   4. "3d"                        -- default
--
-- 2D mode is a true circle: the shell mask clips the texture. Models ignore the
-- texture mask pipeline, so 3D mode is cropped visually by an opaque ring drawn
-- over the model on a higher frame level. The ring is sized LARGER than the
-- background circle so its border covers the model's square corners.
--
-- Ring geometry (see EnsurePortraitRing / LayoutPortraitRing):
--   * portraitRingScale scales the ring frame relative to portraitDiameter.
--   * To hide the corners, ring outer diameter must be >= ~1.414 * model size,
--     so with portraitModelScale = 1.0 keep portraitRingScale >= ~1.45.
--   * The ring TGA's transparent hole should be about 1 / portraitRingScale of
--     the texture width (~0.67 at scale 1.5) so it lines up with the bg circle.
-- =============================================================================
local _, ns = ...

local Layouts = ns.Layouts
local CreateFrame = CreateFrame
local T = ns.Theme
local WHITE = "Interface\\Buttons\\WHITE8X8"
local PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
-- Supply your own ring border: opaque frame with a transparent circular centre.
-- For a quick test with no custom art, "Interface\\Minimap\\UI-Minimap-Border"
-- is a ready-made circular ring (its rope styling will not match the theme).
local PORTRAIT_RING = "Interface\\AddOns\\Epithet\\icons\\ui\\epithet-portrait-ring"
-- Swallowtail banner tail (left-pointing white silhouette, tinted per theme;
-- the right side reuses this flipped horizontally).
local BANNER_TAIL = "Interface\\AddOns\\Epithet\\icons\\ui\\epithet-banner-tail"
local BANNER_TAIL_TRIM = "Interface\\AddOns\\Epithet\\icons\\ui\\epithet-banner-tail-trim"

local PORTRAIT_MODE_2D = "2d"
local PORTRAIT_MODE_3D = "3d"
local PORTRAIT_EDIT_HINT_TOP_OFFSET_Y = 12

if not Layouts or not Layouts.RegisterLayout then
    return
end

-- Resolve the desired portrait render mode for a frame. Anything that is not an
-- explicit "2d" collapses to "3d" so an unexpected value fails safe.
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

-- Apply the title font at the configured size, reading the existing font path so
-- only the size changes. Called from ApplyLayout and before SizePill measures.
local function ApplyTitleFont(frame, m)
    if not frame or not frame.titleText or not frame.titleText.GetFont then return end
    local path, _, flags = frame.titleText:GetFont()
    if path then
        frame.titleText:SetFont(path, m.titleFontSize or 16, flags)
    end
end

local function AttachTextureMasks(frame)
    if not frame or not frame.portraitMask then return end

    if frame.portrait and frame.portrait.AddMaskTexture and not frame.portraitTextureMasked then
        frame.portrait:AddMaskTexture(frame.portraitMask)
        frame.portraitTextureMasked = true
    end

    if frame.portraitBG and frame.portraitBG.AddMaskTexture and not frame.portraitBGMasked then
        frame.portraitBG:AddMaskTexture(frame.portraitMask)
        frame.portraitBGMasked = true
    end
end

-- Circular mask for the 2D texture path only. Models cannot be masked, so the
-- model is deliberately left out of this and cropped by the ring instead.
local function EnsurePortraitMask(frame)
    if not frame or not frame.portraitShell or not frame.portrait or not frame.portraitBG then return end

    -- Mask already built: still make sure the textures pick it up.
    if frame.portraitMask then
        AttachTextureMasks(frame)
        return
    end

    if not frame.portrait.AddMaskTexture or not frame.portraitBG.AddMaskTexture then return end

    local mask = frame.portraitShell:CreateMaskTexture(nil, "ARTWORK")
    mask:SetTexture(PORTRAIT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(frame.portraitShell)
    frame.portraitMask = mask

    AttachTextureMasks(frame)
end

-- Lazily create the PlayerModel. Only called in 3D mode. Not masked; the ring
-- crops it.
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

-- Overlay ring that crops the 3D model to a circle. It lives on its own frame
-- ABOVE the model, because a texture on portraitShell would render beneath the
-- model (child frames always draw over their parent's textures).
local function EnsurePortraitRing(frame, m)
    if not frame or not frame.portraitShell then return end

    local texture = (m and m.portraitRingTexture) or PORTRAIT_RING

    if frame.portraitRing then
        frame.portraitRing:SetTexture(texture)
        return
    end

    local host = CreateFrame("Frame", nil, frame.portraitShell)
    host:EnableMouse(false)
    local modelLevel = (frame.portraitModel and frame.portraitModel:GetFrameLevel())
        or ((frame.portraitShell:GetFrameLevel() or 0) + 2)
    host:SetFrameLevel(modelLevel + 10)
    host:SetAllPoints(frame.portraitShell)
    frame.portraitRingFrame = host

    local ring = host:CreateTexture(nil, "OVERLAY")
    ring:SetTexture(texture)
    frame.portraitRing = ring
end

-- Size and place the ring larger than the background circle, or hide it (2D).
local function LayoutPortraitRing(frame, m, show)
    if not frame or not frame.portraitRing or not frame.portraitRingFrame then return end

    if not show then
        frame.portraitRingFrame:Hide()
        return
    end

    local ringScale = m.portraitRingScale or 1.5
    local d = math.max(1, math.floor(((m.portraitDiameter or 84) * ringScale) + 0.5))

    frame.portraitRingFrame:ClearAllPoints()
    frame.portraitRingFrame:SetPoint("CENTER", frame.portraitShell, "CENTER", 0, 0)
    frame.portraitRingFrame:SetSize(d, d)

    frame.portraitRing:ClearAllPoints()
    frame.portraitRing:SetAllPoints(frame.portraitRingFrame)
    frame.portraitRing:Show()
    frame.portraitRingFrame:Show()
end

local function EnsureBannerArt(frame)
    if not frame then return end
    if frame.bannerFill then return end

    frame.bannerFill = frame:CreateTexture(nil, "BACKGROUND")
    frame.bannerFill:SetTexture(WHITE)

    -- Swallowtail tails, one per side. Right reuses the left art, mirrored.
    frame.bannerTailLeft = frame:CreateTexture(nil, "BACKGROUND")
    frame.bannerTailLeft:SetTexture(BANNER_TAIL)

    frame.bannerTailRight = frame:CreateTexture(nil, "BACKGROUND")
    frame.bannerTailRight:SetTexture(BANNER_TAIL)
    frame.bannerTailRight:SetTexCoord(1, 0, 0, 1) -- flip horizontally

    frame.bannerTailTrimLeft = frame:CreateTexture(nil, "BORDER")
    frame.bannerTailTrimLeft:SetTexture(BANNER_TAIL_TRIM)

    frame.bannerTailTrimRight = frame:CreateTexture(nil, "BORDER")
    frame.bannerTailTrimRight:SetTexture(BANNER_TAIL_TRIM)
    frame.bannerTailTrimRight:SetTexCoord(1, 0, 0, 1) -- flip horizontally

    frame.bannerTopLine = frame:CreateTexture(nil, "BORDER")
    frame.bannerTopLine:SetTexture(WHITE)
    frame.bannerTopLine:SetHeight(1)

    frame.bannerBottomLine = frame:CreateTexture(nil, "BORDER")
    frame.bannerBottomLine:SetTexture(WHITE)
    frame.bannerBottomLine:SetHeight(1)

    frame.bannerLeftLine = frame:CreateTexture(nil, "BORDER")
    frame.bannerLeftLine:SetTexture(WHITE)
    frame.bannerLeftLine:SetWidth(1)

    frame.bannerRightLine = frame:CreateTexture(nil, "BORDER")
    frame.bannerRightLine:SetTexture(WHITE)
    frame.bannerRightLine:SetWidth(1)
end

local function LayoutBanner(frame, m)
    if not frame or not frame.centerCol then return end

    local bannerWidth = m.bannerWidth or m.frameWidth or 220
    local bannerHeight = m.bannerHeight or 62
    local tailWidth = m.bannerTailWidth or 42
    local tailHeight = m.bannerTailHeight or bannerHeight

    frame.centerCol:ClearAllPoints()
    frame.centerCol:SetPoint("BOTTOM", frame, "BOTTOM", 0, m.bannerBottomInset or 8)
    frame.centerCol:SetSize(bannerWidth, bannerHeight)

    local fill = (T and T.col and T.col.parch) or { r = 0.95, g = 0.91, b = 0.83 }
    local tab = (T and T.col and T.col.panel) or { r = 0.88, g = 0.84, b = 0.74 }
    local line = (T and T.col and T.col.goldDeep) or { r = 0.13, g = 0.11, b = 0.09 }

    if frame.bannerFill then
        frame.bannerFill:ClearAllPoints()
        frame.bannerFill:SetPoint("TOPLEFT", frame.centerCol, "TOPLEFT", 0, 0)
        frame.bannerFill:SetPoint("BOTTOMRIGHT", frame.centerCol, "BOTTOMRIGHT", 0, 0)
        frame.bannerFill:SetVertexColor(fill.r, fill.g, fill.b, 0.96)
        frame.bannerFill:Show()
    end

    -- Left swallowtail: attach edge meets the rectangle's left, point outward.
    if frame.bannerTailLeft then
        frame.bannerTailLeft:ClearAllPoints()
        frame.bannerTailLeft:SetPoint("RIGHT", frame.centerCol, "LEFT", 1, 0)
        frame.bannerTailLeft:SetSize(tailWidth, tailHeight)
        frame.bannerTailLeft:SetVertexColor(tab.r, tab.g, tab.b, 0.96)
        frame.bannerTailLeft:Show()
    end

    -- Right swallowtail: mirrored, attach edge meets the rectangle's right.
    if frame.bannerTailRight then
        frame.bannerTailRight:ClearAllPoints()
        frame.bannerTailRight:SetPoint("LEFT", frame.centerCol, "RIGHT", -1, 0)
        frame.bannerTailRight:SetSize(tailWidth, tailHeight)
        frame.bannerTailRight:SetVertexColor(tab.r, tab.g, tab.b, 0.96)
        frame.bannerTailRight:Show()
    end

    if frame.bannerTailTrimLeft and frame.bannerTailLeft then
        frame.bannerTailTrimLeft:ClearAllPoints()
        frame.bannerTailTrimLeft:SetAllPoints(frame.bannerTailLeft)
        frame.bannerTailTrimLeft:SetVertexColor(line.r, line.g, line.b, 0.92)
        frame.bannerTailTrimLeft:Show()
    end

    if frame.bannerTailTrimRight and frame.bannerTailRight then
        frame.bannerTailTrimRight:ClearAllPoints()
        frame.bannerTailTrimRight:SetAllPoints(frame.bannerTailRight)
        frame.bannerTailTrimRight:SetVertexColor(line.r, line.g, line.b, 0.92)
        frame.bannerTailTrimRight:Show()
    end

    local lineColor = { line.r, line.g, line.b, 0.92 }
    if frame.bannerTopLine then
        frame.bannerTopLine:ClearAllPoints()
        frame.bannerTopLine:SetPoint("TOPLEFT", frame.centerCol, "TOPLEFT", 1, -1)
        frame.bannerTopLine:SetPoint("TOPRIGHT", frame.centerCol, "TOPRIGHT", -1, -1)
        frame.bannerTopLine:SetColorTexture(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
        frame.bannerTopLine:Show()
    end
    if frame.bannerBottomLine then
        frame.bannerBottomLine:ClearAllPoints()
        frame.bannerBottomLine:SetPoint("BOTTOMLEFT", frame.centerCol, "BOTTOMLEFT", 1, 1)
        frame.bannerBottomLine:SetPoint("BOTTOMRIGHT", frame.centerCol, "BOTTOMRIGHT", -1, 1)
        frame.bannerBottomLine:SetColorTexture(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
        frame.bannerBottomLine:Show()
    end
    if frame.bannerLeftLine then
        frame.bannerLeftLine:ClearAllPoints()
        frame.bannerLeftLine:SetPoint("TOPLEFT", frame.centerCol, "TOPLEFT", 1, -1)
        frame.bannerLeftLine:SetPoint("BOTTOMLEFT", frame.centerCol, "BOTTOMLEFT", 1, 1)
        frame.bannerLeftLine:SetColorTexture(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
        frame.bannerLeftLine:Show()
    end
    if frame.bannerRightLine then
        frame.bannerRightLine:ClearAllPoints()
        frame.bannerRightLine:SetPoint("TOPRIGHT", frame.centerCol, "TOPRIGHT", -1, -1)
        frame.bannerRightLine:SetPoint("BOTTOMRIGHT", frame.centerCol, "BOTTOMRIGHT", -1, 1)
        frame.bannerRightLine:SetColorTexture(lineColor[1], lineColor[2], lineColor[3], lineColor[4])
        frame.bannerRightLine:Show()
    end
end

Layouts:RegisterLayout("portrait", {
    label = "Portrait Card",
    labelKey = "SOCIAL_LAYOUT_PORTRAIT",
    metrics = {
        layoutStyle = "portrait",
        -- portraitMode = "2d" or "3d". Leave unset to fall back to the saved
        -- setting (ns.GetPortraitMode) or the "3d" default.
        portraitMode = nil,
        frameWidth = 220,
        frameHeight = 168,
        edgeInsetX = 0,
        edgeInsetY = 0,
        row1Height = 18,
        rowGap = 6,
        portraitRowHeight = 80,
        titleRowHeight = 24,
        titleMinHeight = 20,
        titleMaxHeight = 52,         -- room for the larger centred title
        titleFontSize = 16,          -- title size; reads existing font path
        gemColWidth = 18,
        gemTextGap = 6,
        gemSize = 14,
        portraitSideInset = 0,
        portraitInset = 3,
        portraitScale = 0.70,        -- retained for the 2D path / compatibility
        portraitModelScale = 1.0,    -- 3D model fills the shell; ring does the crop
        portraitRingScale = 1.5,     -- ring frame size vs portraitDiameter (>= ~1.45)
        portraitRingTexture = nil,   -- optional override of PORTRAIT_RING
        portraitDiameter = 84,
        portraitTopInset = 6,
        bannerWidth = 208,
        bannerHeight = 64,
        bannerTailWidth = 42,        -- swallowtail length beyond the rectangle
        bannerTailHeight = nil,      -- defaults to bannerHeight
        bannerBottomInset = 8,
        crownBaseScale = 0.20,
        crownMinSize = 24,
    },

    ApplyLayout = function(self, frame, m)
        local mode = ResolvePortraitMode(frame, m)
        frame.portraitMode = mode -- cache resolved mode for LayoutPortrait

        if frame.editHintTop then
            frame.editHintTop:ClearAllPoints()
            frame.editHintTop:SetPoint("BOTTOM", frame, "TOP", 0, PORTRAIT_EDIT_HINT_TOP_OFFSET_Y)
        end

        -- Build the ring for both 2D and 3D modes.
        EnsurePortraitRing(frame, m)

        -- Only build the 3D model when we actually intend to use it.
        if mode == PORTRAIT_MODE_3D then
            EnsurePortraitModel(frame)
        end

        EnsurePortraitMask(frame)
        EnsureBannerArt(frame)

        if frame.scrollBackdrop then
            frame.scrollBackdrop:Hide()
        end

        if frame.SetBackdropColor then
            frame:SetBackdropColor(0, 0, 0, 0)
        end
        if frame.SetBackdropBorderColor then
            frame:SetBackdropBorderColor(0, 0, 0, 0)
        end

        local frameHeight = m.frameHeight or 168
        frame:SetSize(m.frameWidth, frameHeight)
        LayoutBanner(frame, m)

        if frame.leftCol then
            frame.leftCol:ClearAllPoints()
            frame.leftCol:SetPoint("TOPLEFT", frame.centerCol, "TOPLEFT", 8, -8)
            frame.leftCol:SetPoint("BOTTOMLEFT", frame.centerCol, "TOPLEFT", 8, -(8 + m.row1Height))
            frame.leftCol:SetWidth(m.gemColWidth)
        end

        if frame.rarityRow then
            frame.rarityRow:ClearAllPoints()
            frame.rarityRow:SetPoint("TOPLEFT", frame.centerCol, "TOPLEFT", 8 + m.gemColWidth + m.gemTextGap, -8)
            frame.rarityRow:SetPoint("TOPRIGHT", frame.centerCol, "TOPRIGHT", -8, -8)
            frame.rarityRow:SetHeight(m.row1Height)
        end

        -- Title row spans the full banner width (independent of the rarity row's
        -- gem inset) so the centred title can use the whole space.
        if frame.titleRow then
            local titleHeight = frame.dynamicTitleHeight or m.titleMinHeight or m.titleRowHeight or 20
            local titleTopY = -(8 + m.row1Height + 6) -- below the rarity row + gap
            frame.titleRow:ClearAllPoints()
            frame.titleRow:SetPoint("TOPLEFT", frame.centerCol, "TOPLEFT", 8, titleTopY)
            frame.titleRow:SetPoint("TOPRIGHT", frame.centerCol, "TOPRIGHT", -8, titleTopY)
            frame.titleRow:SetPoint("BOTTOM", frame.centerCol, "BOTTOM", 0, 8)
            frame.titleRow:SetHeight(titleHeight)
        end

        if frame.titleText then
            ApplyTitleFont(frame, m)
            frame.titleText:SetWordWrap(true)
            frame.titleText:SetJustifyH("CENTER")
            frame.titleText:SetJustifyV("MIDDLE")
            frame.titleText:SetShadowColor(0.08, 0.05, 0.01, 0.95)
            frame.titleText:SetShadowOffset(1, -1)
        end

        if frame.rarityText then
            frame.rarityText:SetWordWrap(false)
            frame.rarityText:SetJustifyH("LEFT")
            frame.rarityText:SetJustifyV("MIDDLE")
            frame.rarityText:SetShadowColor(0.08, 0.05, 0.01, 0.95)
            frame.rarityText:SetShadowOffset(1, -1)
        end

        if frame.gem then
            frame.gem:SetSize(m.gemSize, m.gemSize)
        end

        if frame.crownFrame then
            frame.crownFrame:Hide()
        end

        if frame.portraitTopRule and frame.portraitBottomRule then
            frame.portraitTopRule:Hide()
            frame.portraitBottomRule:Hide()
        end

        if frame.portraitBG then
            frame.portraitBG:SetColorTexture(0.09, 0.08, 0.08, 0.55)
        end

        -- Show the object for the active mode, hide the other (and the ring in 2D).
        if mode == PORTRAIT_MODE_3D and frame.portraitModel then
            if frame.portrait then frame.portrait:Hide() end
            frame.portraitModel:Show()
        else
            if frame.portraitModel then frame.portraitModel:Hide() end
            if frame.portrait then frame.portrait:Show() end
        end

        self:LayoutTargetPortrait(frame)
    end,

    LayoutPortrait = function(self, frame, m)
        if not frame or not frame.portraitShell then return end

        frame.portraitShell:ClearAllPoints()
        frame.portraitShell:SetPoint("TOP", frame, "TOP", 0, -(m.portraitTopInset or 6))
        frame.portraitShell:SetSize(m.portraitDiameter or 84, m.portraitDiameter or 84)

        local mode = frame.portraitMode or ResolvePortraitMode(frame, m)

        if frame.portraitTopRule and frame.portraitBottomRule then
            frame.portraitTopRule:Hide()
            frame.portraitBottomRule:Hide()
        end
        if frame.crownFrame then
            frame.crownFrame:Hide()
        end

        if mode == PORTRAIT_MODE_3D and frame.portraitModel then
            -- 3D PlayerModel, cropped by the overlay ring.
            if frame.portrait then frame.portrait:Hide() end
            frame.portraitModel:Show()

            local shellW = frame.portraitShell:GetWidth() or 0
            local shellH = frame.portraitShell:GetHeight() or 0
            local minDim = math.min(shellW, shellH)
            -- Fill the shell (or a touch over) so the ring's hole is fully covered;
            -- the ring hides the square corners that spill past the circle.
            local scale = m.portraitModelScale or 1.0
            local portraitSize = math.max(12, math.floor((minDim * scale) + 0.5))
            frame.portraitModel:ClearAllPoints()
            frame.portraitModel:SetPoint("CENTER", frame.portraitShell, "CENTER", 0, 0)
            frame.portraitModel:SetSize(portraitSize, portraitSize)

            if frame.portraitUnit and frame.portraitModel.SetUnit then
                local ok = pcall(frame.portraitModel.SetUnit, frame.portraitModel, frame.portraitUnit)
                if not ok then
                    pcall(frame.portraitModel.SetUnit, frame.portraitModel, "player")
                end
                if frame.portraitModel.RefreshUnit then
                    pcall(frame.portraitModel.RefreshUnit, frame.portraitModel)
                end
            end

            LayoutPortraitRing(frame, m, true)
        else
            -- 2D masked portrait texture. The mask is anchored to portraitShell,
            -- so size the texture to the shell for the circle to read cleanly.
            if frame.portraitModel then frame.portraitModel:Hide() end
            LayoutPortraitRing(frame, m, false)
            if frame.portrait then
                frame.portrait:Show()
                frame.portrait:ClearAllPoints()
                frame.portrait:SetAllPoints(frame.portraitShell)
                if frame.portraitUnit then
                    self:ApplyPortraitTexture(frame.portrait, frame.portraitUnit, "portrait", frame.portraitShell)
                end
            end
            LayoutPortraitRing(frame, m, true)
        end
    end,

    SizePill = function(self, frame, m)
        if not frame or not frame.titleText or not frame.rarityText then return end

        ApplyTitleFont(frame, m) -- measure with the final (larger) font

        local edgeX = 16
        local titleWidth = math.max(80, (m.bannerWidth or m.frameWidth or 220) - (edgeX * 2))
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

        self:ApplyLayoutToFrame(frame, { layout = "portrait" })
        self:LayoutTargetPortrait(frame)
    end,
})