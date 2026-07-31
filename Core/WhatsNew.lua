-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) Grimmsforge

local ADDON_NAME, ns = ...
local L = ns.L
local T = ns.Theme

local WhatsNew = {}
ns.WhatsNew = WhatsNew

local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetAddOnMetadata = GetAddOnMetadata
local UIParent = UIParent
local gsub = string.gsub
local match = string.match
local tostring = tostring

-- The dialog used to be rendered by handing a hand-built HTML string to a
-- SimpleHTML widget, but that widget only parses markup if the whole document
-- is "well-formed" by its own undocumented rules - anything it doesn't like
-- (a bare quote character was one culprit) makes it silently fall back to
-- showing the raw tags as text, with no error to debug against. Rendering
-- each block as a real FontString/Texture below sidesteps that whole class of
-- bug: there's no markup to get wrong, just plain text (which can freely
-- contain quotes, apostrophes, whatever) plus WoW's native |cff..|r colour
-- codes for emphasis.

-- Image lines may optionally pin a display size with a trailing "=WIDTHxHEIGHT"
-- (e.g. "![alt](path =460x230)"), so non-square art doesn't get squashed into
-- the default 96x96 icon box. Falls back to 96x96 when no size is given.
local DEFAULT_IMAGE_SIZE = 96

local function ParseImageDirective(raw)
    local path, w, h = match(raw, "^(.-)%s*=%s*(%d+)x(%d+)%s*$")
    if not path then
        path = raw
    end
    return path, tonumber(w) or DEFAULT_IMAGE_SIZE, tonumber(h) or DEFAULT_IMAGE_SIZE
end

-- **bold** and *emphasis* become WoW colour-code runs instead of HTML tags -
-- there's no italic font loaded, so emphasis just gets a different tint.
local BOLD_COLOR = "fff6e2a6"
local EMPHASIS_COLOR = "ffe8c873"

local function RenderInlineColor(value)
    local text = tostring(value or "")
    text = gsub(text, "%*%*(.-)%*%*", "|c" .. BOLD_COLOR .. "%1|r")
    text = gsub(text, "%*(.-)%*", "|c" .. EMPHASIS_COLOR .. "%1|r")
    return text
end

-- Turns the markdown-ish body text into a flat list of layout blocks. Blank
-- lines in the source are ignored entirely - spacing between blocks is a
-- fixed property of the block types involved (see BLOCK_STYLE), not
-- something content authors need to remember to add.
local function BuildBlocks(body)
    local src = tostring(body or "")
    local blocks = {}

    for line in src:gmatch("[^\r\n]+") do
        if not line:match("^%s*$") then
            local h2 = match(line, "^%s*##%s+(.+)$")
            local h1 = (not h2) and match(line, "^%s*#%s+(.+)$")
            local bullet = (not h2 and not h1) and match(line, "^%s*%*%s+(.+)$")
            local imageDirective = match(line, "^%s*!%[[^%]]*%]%((.+)%)%s*$")

            if imageDirective and imageDirective ~= "" then
                local path, w, h = ParseImageDirective(imageDirective)
                blocks[#blocks + 1] = { type = "image", path = path, w = w, h = h }
            elseif h2 then
                blocks[#blocks + 1] = { type = "h2", text = RenderInlineColor(h2) }
            elseif h1 then
                blocks[#blocks + 1] = { type = "h1", text = RenderInlineColor(h1) }
            elseif bullet then
                blocks[#blocks + 1] = { type = "bullet", text = RenderInlineColor(bullet) }
            else
                blocks[#blocks + 1] = { type = "p", text = RenderInlineColor(line) }
            end
        end
    end

    return blocks
end

-- Layout constants: content width matches the scroll frame's inner width
-- (760 dialog - 18 left inset - 38 right inset - scrollbar allowance), and
-- each block type carries its own font/colour plus the gap it always gets
-- above it, so headings and images are guaranteed breathing room regardless
-- of how the source markdown is formatted.
local BODY_WIDTH = 690
local BULLET_INDENT = 14
local IMAGE_GAP_BEFORE = 14

local BLOCK_STYLE = {
    h1 = { font = "Fonts\\FRIZQT__.TTF", size = 18, color = { 0.96, 0.89, 0.65 }, gapBefore = 18 },
    h2 = { font = "Fonts\\FRIZQT__.TTF", size = 14, color = { 0.90, 0.80, 0.52 }, gapBefore = 16 },
    p = { font = "Fonts\\FRIZQT__.TTF", size = 12, color = { 0.86, 0.82, 0.74 }, gapBefore = 10 },
    bullet = { font = "Fonts\\FRIZQT__.TTF", size = 12, color = { 0.86, 0.82, 0.74 }, gapBefore = 10, gapBeforeSameType = 4 },
}

function WhatsNew:AcquireTextWidget(index)
    self.textWidgets = self.textWidgets or {}
    local fs = self.textWidgets[index]
    if not fs then
        fs = self.dialogContent:CreateFontString(nil, "ARTWORK")
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        fs:SetWordWrap(true)
        self.textWidgets[index] = fs
    end
    return fs
end

function WhatsNew:AcquireImageWidget(index)
    self.imageWidgets = self.imageWidgets or {}
    local tex = self.imageWidgets[index]
    if not tex then
        tex = self.dialogContent:CreateTexture(nil, "ARTWORK")
        self.imageWidgets[index] = tex
    end
    return tex
end

-- Lays out one block per pooled widget, top to bottom, and returns the total
-- content height so the caller can size the scroll child. Widgets are pooled
-- and reused across calls since a FontString/Texture can't be destroyed, only
-- hidden; any left over from a previous, longer body get hidden at the end.
function WhatsNew:RenderBody(rawBody)
    self.textWidgets = self.textWidgets or {}
    self.imageWidgets = self.imageWidgets or {}

    local blocks = BuildBlocks(rawBody)
    local textIndex, imageIndex = 0, 0
    local y = 0
    local prevType = nil

    for _, block in ipairs(blocks) do
        if block.type == "image" then
            y = y + IMAGE_GAP_BEFORE
            imageIndex = imageIndex + 1
            local tex = self:AcquireImageWidget(imageIndex)
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", self.dialogContent, "TOPLEFT", 0, -y)
            tex:SetSize(block.w, block.h)
            tex:SetTexture(block.path)
            tex:Show()
            y = y + block.h
        else
            local style = BLOCK_STYLE[block.type]
            local gap = style.gapBefore
            if block.type == "bullet" and prevType == "bullet" then
                gap = style.gapBeforeSameType
            end
            y = y + gap

            textIndex = textIndex + 1
            local fs = self:AcquireTextWidget(textIndex)
            fs:ClearAllPoints()
            local indent = (block.type == "bullet") and BULLET_INDENT or 0
            fs:SetPoint("TOPLEFT", self.dialogContent, "TOPLEFT", indent, -y)
            fs:SetWidth(BODY_WIDTH - indent)
            fs:SetFont(style.font, style.size, "")
            fs:SetTextColor(style.color[1], style.color[2], style.color[3], 1)
            fs:SetText(block.type == "bullet" and ("\226\128\162  " .. block.text) or block.text)
            fs:Show()

            y = y + (fs:GetStringHeight() or (style.size + 4))
        end

        prevType = block.type
    end

    for i = textIndex + 1, #self.textWidgets do
        self.textWidgets[i]:Hide()
    end
    for i = imageIndex + 1, #self.imageWidgets do
        self.imageWidgets[i]:Hide()
    end

    return y
end

function WhatsNew:GetCurrentVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "0.0.0"
    end
    if GetAddOnMetadata then
        return GetAddOnMetadata(ADDON_NAME, "Version") or "0.0.0"
    end
    return "0.0.0"
end

function WhatsNew:GetContentForVersion(version)
    local container = ns.WhatsNewContent and ns.WhatsNewContent.versions
    if type(container) ~= "table" then
        return nil
    end
    return container[version]
end

function WhatsNew:EnsureState()
    _G.EpithetDB = _G.EpithetDB or {}
    local db = _G.EpithetDB
    db.whatsNew = db.whatsNew or {
        byVersion = {},
    }
    db.whatsNew.byVersion = db.whatsNew.byVersion or {}
    return db.whatsNew
end

function WhatsNew:GetStateForVersion(version, create)
    local state = self:EnsureState()
    local byVersion = state.byVersion
    local item = byVersion[version]

    if not item and create then
        item = {
            firstRun = true,
            hasNew = true,
        }
        byVersion[version] = item
    end

    return item
end

function WhatsNew:ShouldShow(version)
    local content = self:GetContentForVersion(version)
    if not content then
        return false
    end

    local state = self:GetStateForVersion(version, true)
    if state.hasNew == nil then
        state.hasNew = content.hasNew ~= false
    end

    if state.firstRun == nil then
        state.firstRun = true
    end

    return state.firstRun == true and state.hasNew == true
end

function WhatsNew:DismissCurrentVersion()
    local version = self:GetCurrentVersion()
    local state = self:GetStateForVersion(version, true)
    state.firstRun = false
    state.hasNew = false
end

function WhatsNew:EnsureDialog()
    if self.dialog then
        return self.dialog
    end

    local frame = CreateFrame("Frame", "EpithetWhatsNewDialog", UIParent, "BackdropTemplate")
    frame:SetSize(760, 520)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(220)
    frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    if T and T.col then
        frame:SetBackdropColor(T.col.bg0.r, T.col.bg0.g, T.col.bg0.b, 0.98)
        frame:SetBackdropBorderColor(T.col.line.r, T.col.line.g, T.col.line.b, 0.9)
    else
        frame:SetBackdropColor(0.08, 0.06, 0.03, 0.98)
        frame:SetBackdropBorderColor(0.55, 0.45, 0.26, 0.9)
    end
    frame:Hide()

    local heading = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 14, -12)
    heading:SetPoint("TOPRIGHT", -40, -12)
    heading:SetJustifyH("LEFT")

    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetSize(18, 18)
    closeButton:SetPoint("TOPRIGHT", -10, -10)
    local closeText = closeButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeText:SetPoint("CENTER")
    closeText:SetText("x")
    closeText:SetTextColor(0.95, 0.90, 0.75)

    local divider = frame:CreateTexture(nil, "BORDER")
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -38)
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -38)
    divider:SetHeight(1)
    divider:SetColorTexture(0.55, 0.45, 0.26, 0.35)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -48)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -38, 52)

    local body = CreateFrame("Frame", nil, scroll)
    body:SetWidth(BODY_WIDTH)
    body:SetHeight(1)
    body:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)

    scroll:SetScrollChild(body)

    -- Bottom cutoff marker: draw in a dedicated overlay frame with higher
    -- frame level than the scroll child so it always sits above content.
    local scrollCutoffOverlay = CreateFrame("Frame", nil, frame)
    scrollCutoffOverlay:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    scrollCutoffOverlay:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 0, 0)
    scrollCutoffOverlay:SetFrameStrata(frame:GetFrameStrata())
    scrollCutoffOverlay:SetFrameLevel((body:GetFrameLevel() or frame:GetFrameLevel() or 1) + 20)

    local scrollCutoffBottom = scrollCutoffOverlay:CreateTexture(nil, "OVERLAY")
    scrollCutoffBottom:SetPoint("BOTTOMLEFT", scrollCutoffOverlay, "BOTTOMLEFT", 0, 0)
    scrollCutoffBottom:SetPoint("BOTTOMRIGHT", scrollCutoffOverlay, "BOTTOMRIGHT", 0, 0)
    scrollCutoffBottom:SetHeight(1)
    scrollCutoffBottom:SetColorTexture(0.95, 0.82, 0.48, 0.95)

    local scrollCutoffBottomSoft = scrollCutoffOverlay:CreateTexture(nil, "OVERLAY")
    scrollCutoffBottomSoft:SetPoint("BOTTOMLEFT", scrollCutoffBottom, "TOPLEFT", 0, 0)
    scrollCutoffBottomSoft:SetPoint("BOTTOMRIGHT", scrollCutoffBottom, "TOPRIGHT", 0, 0)
    scrollCutoffBottomSoft:SetHeight(1)
    scrollCutoffBottomSoft:SetColorTexture(0.95, 0.82, 0.48, 0.35)

    local dismiss = CreateFrame("Button", nil, frame)
    dismiss:SetSize(220, 24)
    dismiss:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 14)

    local function Skin(button)
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

        local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER")
        label:SetTextColor(0.91, 0.78, 0.45)
        button.label = label

        button:SetScript("OnEnter", function(self_)
            self_.bg:SetColorTexture(0.16, 0.12, 0.07, 1.0)
            self_.label:SetTextColor(0.96, 0.89, 0.65)
        end)

        button:SetScript("OnLeave", function(self_)
            self_.bg:SetColorTexture(0.11, 0.08, 0.04, 1.0)
            self_.label:SetTextColor(0.91, 0.78, 0.45)
        end)
    end

    Skin(dismiss)
    dismiss.label:SetText((L and L["WHATS_NEW_CLOSE"]) or "Close")

    closeButton:SetScript("OnClick", function()
        self:DismissCurrentVersion()
        frame:Hide()
    end)

    dismiss:SetScript("OnClick", function()
        self:DismissCurrentVersion()
        frame:Hide()
    end)

    self.dialog = frame
    self.dialogHeading = heading
    self.dialogContent = body
    self.dialogScroll = scroll

    return frame
end

function WhatsNew:Show(version)
    local content = self:GetContentForVersion(version)
    if not content then
        return
    end

    local frame = self:EnsureDialog()
    if not frame then
        return
    end

    local title = content.title or ((L and L["WHATS_NEW_HEADING"]) or "What's New")
    self.dialogHeading:SetText(title)

    local totalHeight = self:RenderBody(content.body or "")
    self.dialogContent:SetHeight(math.max(1, totalHeight + 16))
    self.dialogScroll:SetVerticalScroll(0)

    frame:Show()
end

function WhatsNew:ShowForCurrentVersionIfNeeded()
    if self.shownThisSession or self.pendingShow then
        return
    end

    local version = self:GetCurrentVersion()
    if not self:ShouldShow(version) then
        return
    end

    self.pendingShow = true

    if C_Timer and C_Timer.After then
        C_Timer.After(2.5, function()
            self.pendingShow = false
            if self.shownThisSession then
                return
            end
            self.shownThisSession = true
            self:Show(version)
        end)
    else
        self.pendingShow = false
        self.shownThisSession = true
        self:Show(version)
    end
end

function WhatsNew:Init()
    if self.initialized then
        return
    end
    self.initialized = true
end
