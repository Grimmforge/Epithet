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
local StaticPopupDialogs = StaticPopupDialogs
local StaticPopup_Show = StaticPopup_Show
local gsub = string.gsub
local match = string.match
local tostring = tostring

local function Trim(value)
    local s = tostring(value or "")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    return s
end

-- The dialogue used to be rendered by handing a hand-built HTML string to a
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
--
-- A line may open with either "*" or "-" as its bullet marker (both are
-- common markdown convention, and content has been authored with both), and
-- "[label](url)" - optionally bullet-prefixed - becomes a clickable "link"
-- block. WoW can't open a browser from an addon, so a link block doesn't
-- navigate anywhere; see WhatsNew:ShowLinkPopup for what clicking it does.
local function BuildBlocks(body)
    local src = tostring(body or "")
    local blocks = {}

    for line in src:gmatch("[^\r\n]+") do
        if not line:match("^%s*$") then
            local h2 = match(line, "^%s*##%s+(.+)$")
            local h1 = (not h2) and match(line, "^%s*#%s+(.+)$")
            local linkLabel, linkURL
            if not h2 and not h1 then
                linkLabel, linkURL = match(line, "^%s*[%*%-]?%s*%[(.-)%]%((.-)%)%s*$")
            end
            local bullet = (not h2 and not h1 and not linkLabel) and match(line, "^%s*[%*%-]%s+(.+)$")
            local imageDirective = match(line, "^%s*!%[[^%]]*%]%((.+)%)%s*$")

            if imageDirective and imageDirective ~= "" then
                local path, w, h = ParseImageDirective(imageDirective)
                blocks[#blocks + 1] = { type = "image", path = path, w = w, h = h }
            elseif h2 then
                blocks[#blocks + 1] = { type = "h2", text = RenderInlineColor(h2) }
            elseif h1 then
                blocks[#blocks + 1] = { type = "h1", text = RenderInlineColor(h1) }
            elseif linkLabel then
                blocks[#blocks + 1] = { type = "link", text = RenderInlineColor(linkLabel), url = Trim(linkURL) }
            elseif bullet then
                blocks[#blocks + 1] = { type = "bullet", text = RenderInlineColor(bullet) }
            else
                blocks[#blocks + 1] = { type = "p", text = RenderInlineColor(line) }
            end
        end
    end

    return blocks
end

-- UTF-8 encoded Cyrillic (U+0400-U+04FF -> lead byte 0xD0-0xD3) is the one
-- script the client's FRIZQT__ font doesn't cover but the bundled Unicode font
-- does (see Fonts/README.md). Checked per rendered block rather than gated on
-- the active display locale (contrast Theme.NeedsBundledFont): a line can
-- deliberately mix scripts - e.g. this very file's own multilingual "Bonjour,
-- Привет, Hello!" heading - regardless of which language the reader has
-- Epithet set to.
local function ContainsCyrillic(text)
    return text ~= nil and text:find("[\208-\211][\128-\191]") ~= nil
end

-- Picks the bundled Unicode font over the client font only for the blocks
-- that actually need it, so the popup's typography stays the client's own
-- FRIZQT__ everywhere else.
local function ApplyBlockFont(fontLike, path, size, text)
    if T and T.ApplyUnicodeSansFont and ContainsCyrillic(text) then
        T.ApplyUnicodeSansFont(fontLike, size)
    else
        fontLike:SetFont(path, size, "")
    end
end

-- Layout constants: content width matches the scroll frame's inner width
-- (760 dialogue - 18 left inset - 38 right inset - scrollbar allowance), and
-- each block type carries its own font/colour plus the gap it always gets
-- above it, so headings and images are guaranteed breathing room regardless
-- of how the source markdown is formatted.
local BODY_WIDTH = 690
local BULLET_INDENT = 14
local IMAGE_GAP_BEFORE = 14

-- WoW hyperlink blue, distinct from the theme's gold body/emphasis colours so a
-- link visibly reads as clickable; brightens further on hover.
local LINK_COLOR = { 0.45, 0.73, 1.0 }
local LINK_HOVER_COLOR = { 0.68, 0.86, 1.0 }

-- gapAfter is a heading's own trailing margin, added under it regardless of
-- what follows - relying solely on the next block's gapBefore isn't enough,
-- because a heading rendered in a different font (e.g. the bundled Unicode
-- font a Cyrillic-containing heading switches to, see ApplyBlockFont) can have
-- different line-height metrics than GetStringHeight() assumes elsewhere,
-- which visibly eats into that gap.
local BLOCK_STYLE = {
    h1 = { font = "Fonts\\FRIZQT__.TTF", size = 18, color = { 0.96, 0.89, 0.65 }, gapBefore = 18, gapAfter = 10 },
    h2 = { font = "Fonts\\FRIZQT__.TTF", size = 14, color = { 0.90, 0.80, 0.52 }, gapBefore = 16, gapAfter = 8 },
    p = { font = "Fonts\\FRIZQT__.TTF", size = 12, color = { 0.86, 0.82, 0.74 }, gapBefore = 10 },
    bullet = { font = "Fonts\\FRIZQT__.TTF", size = 12, color = { 0.86, 0.82, 0.74 }, gapBefore = 10, gapBeforeSameType = 4 },
    link = { font = "Fonts\\FRIZQT__.TTF", size = 12, color = LINK_COLOR, gapBefore = 10, gapBeforeSameType = 4 },
}

-- Bullets and links both render as an indented "• " list row, and sit tight
-- against a same-type neighbour (see BLOCK_STYLE[...].gapBeforeSameType).
local function IsListItem(blockType)
    return blockType == "bullet" or blockType == "link"
end

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

-- A link block needs to be clickable, which a FontString can never be, so it
-- gets its own pooled Button (with a FontString label) instead of reusing
-- AcquireTextWidget. See WhatsNew:ShowLinkPopup for what a click does.
function WhatsNew:AcquireLinkWidget(index)
    self.linkWidgets = self.linkWidgets or {}
    local btn = self.linkWidgets[index]
    if not btn then
        btn = CreateFrame("Button", nil, self.dialogContent)
        btn:EnableMouse(true)

        local label = btn:CreateFontString(nil, "ARTWORK")
        label:SetJustifyH("LEFT")
        label:SetJustifyV("TOP")
        label:SetWordWrap(true)
        label:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        label:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
        btn.label = label

        btn:SetScript("OnEnter", function(self_)
            self_.label:SetTextColor(LINK_HOVER_COLOR[1], LINK_HOVER_COLOR[2], LINK_HOVER_COLOR[3], 1)
        end)
        btn:SetScript("OnLeave", function(self_)
            self_.label:SetTextColor(LINK_COLOR[1], LINK_COLOR[2], LINK_COLOR[3], 1)
        end)
        btn:SetScript("OnClick", function(self_)
            self:ShowLinkPopup(self_.url)
        end)

        self.linkWidgets[index] = btn
    end
    return btn
end

-- Lays out one block per pooled widget, top to bottom, and returns the total
-- content height so the caller can size the scroll child. Widgets are pooled
-- and reused across calls since a FontString/Texture/Button can't be
-- destroyed, only hidden; any left over from a previous, longer body get
-- hidden at the end.
function WhatsNew:RenderBody(rawBody)
    self.textWidgets = self.textWidgets or {}
    self.imageWidgets = self.imageWidgets or {}
    self.linkWidgets = self.linkWidgets or {}

    local blocks = BuildBlocks(rawBody)
    local textIndex, imageIndex, linkIndex = 0, 0, 0
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
            if IsListItem(block.type) and IsListItem(prevType) then
                gap = style.gapBeforeSameType
            end
            y = y + gap

            local indent = IsListItem(block.type) and BULLET_INDENT or 0
            local width = BODY_WIDTH - indent

            if block.type == "link" then
                linkIndex = linkIndex + 1
                local btn = self:AcquireLinkWidget(linkIndex)
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", self.dialogContent, "TOPLEFT", indent, -y)
                btn:SetWidth(width)
                ApplyBlockFont(btn.label, style.font, style.size, block.text)
                btn.label:SetTextColor(style.color[1], style.color[2], style.color[3], 1)
                btn.label:SetText("\226\128\162  " .. block.text)
                btn.url = block.url
                btn:SetHeight(math.max(style.size + 4, btn.label:GetStringHeight() or 0))
                btn:Show()

                y = y + btn:GetHeight()
            else
                textIndex = textIndex + 1
                local fs = self:AcquireTextWidget(textIndex)
                fs:ClearAllPoints()
                fs:SetPoint("TOPLEFT", self.dialogContent, "TOPLEFT", indent, -y)
                fs:SetWidth(width)
                ApplyBlockFont(fs, style.font, style.size, block.text)
                fs:SetTextColor(style.color[1], style.color[2], style.color[3], 1)
                fs:SetText(block.type == "bullet" and ("\226\128\162  " .. block.text) or block.text)
                fs:Show()

                y = y + (fs:GetStringHeight() or (style.size + 4))
            end

            if style.gapAfter then
                y = y + style.gapAfter
            end
        end

        prevType = block.type
    end

    for i = textIndex + 1, #self.textWidgets do
        self.textWidgets[i]:Hide()
    end
    for i = imageIndex + 1, #self.imageWidgets do
        self.imageWidgets[i]:Hide()
    end
    for i = linkIndex + 1, #self.linkWidgets do
        self.linkWidgets[i]:Hide()
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

-- A What's New field (title/body) may be either a plain string (single language)
-- or a table keyed by locale, e.g. { enUS = [[...]], ruRU = [[...]] }. Resolve
-- against ns.activeLocale - the language Epithet:OnInitialize applied from the
-- player's own language picker (Options -> Epithet -> Language), which can
-- differ from the game client's own GetLocale() - falling back to that only if
-- ApplyLocale genuinely hasn't run yet, then to English so a version that
-- hasn't been translated still renders rather than showing blank. English
-- content is keyed "enUS" here, but ns.activeLocale normalises an English
-- client/preference to "enGB" (see LocaleManager.lua), so that lookup misses
-- and falls through to value.enUS below - by design, not a bug.
function WhatsNew:LocalizeField(value)
    if type(value) == "table" then
        local locale = ns.activeLocale or (GetLocale and GetLocale()) or "enUS"
        return value[locale] or value.enUS or value.enGB or value.default or ""
    end
    return value
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
    -- create=true lazily bootstraps per-version state for older saved DB snapshots.
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

-- WoW addons can't open an external browser, so a link block's click handler
-- opens a small Blizzard StaticPopup with the URL pre-selected in an edit box
-- instead - the standard WoW addon pattern for "here's a link, please copy it
-- yourself" (the same trick the Spotting Log's export/import modal uses for
-- its payload text). Registered lazily on first use, not at file load, so
-- L[...] resolves against the locale Epithet:OnInitialize has already applied
-- by the time a player can actually click a link.
function WhatsNew:ShowLinkPopup(url)
    if not url or url == "" then
        return
    end

    if not StaticPopupDialogs["EPITHET_WHATSNEW_LINK"] then
        StaticPopupDialogs["EPITHET_WHATSNEW_LINK"] = {
            text = (L and L["WHATS_NEW_LINK_PROMPT"]) or "Copy this link:\nIt's already selected below - press Ctrl+C to copy it.",
            button1 = OKAY,
            hasEditBox = true,
            editBoxWidth = 350,
            -- Read popup.data rather than trusting an OnShow(self, data) call
            -- signature: dialog.data is what StaticPopup_Show's 4th argument
            -- reliably lands on, and that held even when the data wasn't also
            -- being threaded through as OnShow's second parameter (which is
            -- what left this edit box blank). Also try the legacy
            -- "<name>EditBox" global as a fallback in case a client's popup
            -- template doesn't expose the editBox parentKey.
            OnShow = function(popup)
                local edit = popup.editBox or (popup.GetName and _G[popup:GetName() .. "EditBox"])
                if not edit then return end
                local linkURL = popup.data and popup.data.url
                edit:SetText(linkURL or "")
                edit:HighlightText()
                edit:SetFocus()
            end,
            EditBoxOnEnterPressed = function(popup) popup:GetParent():Hide() end,
            EditBoxOnEscapePressed = function(popup) popup:GetParent():Hide() end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    StaticPopup_Show("EPITHET_WHATSNEW_LINK", nil, nil, { url = url })
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

    -- Bordered button chrome shared by the header close button and the
    -- bottom Dismiss button. With no iconPath it renders a text label (the
    -- original Dismiss look); with one it centres that texture instead - used
    -- for the close button so it matches the tinted-icon close button already
    -- established in UI/MainFrame.xml rather than inventing a second style.
    local function Skin(button, iconPath)
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

        if iconPath then
            local icon = button:CreateTexture(nil, "OVERLAY")
            icon:SetSize(18, 18)
            icon:SetPoint("CENTER")
            icon:SetTexture(iconPath)
            icon:SetVertexColor(0.91, 0.78, 0.45)
            button.icon = icon

            button:SetScript("OnEnter", function(self_)
                self_.bg:SetColorTexture(0.16, 0.12, 0.07, 1.0)
                self_.icon:SetVertexColor(0.96, 0.89, 0.65)
            end)
            button:SetScript("OnLeave", function(self_)
                self_.bg:SetColorTexture(0.11, 0.08, 0.04, 1.0)
                self_.icon:SetVertexColor(0.91, 0.78, 0.45)
            end)
        else
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
    end

    -- Logo, left of the title - the same wax-seal mark used in the main
    -- window's own title bar (UI/MainFrame.xml), for a consistent look.
    local logo = frame:CreateTexture(nil, "ARTWORK")
    logo:SetSize(28, 28)
    logo:SetPoint("TOPLEFT", 14, -10)
    logo:SetTexture("Interface\\AddOns\\Epithet\\icons\\logo\\epithet-wax-seal-red-mark-32")

    local heading = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    heading:SetPoint("RIGHT", frame, "RIGHT", -46, 0)
    heading:SetJustifyH("LEFT")

    -- Sized and skinned to match UI/MainFrame.xml's own close button (26x26
    -- hit area, tinted-icon style) - the plain 18x18 text "x" this replaces
    -- was a noticeably smaller and harder-to-hit target than that button.
    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetSize(26, 26)
    closeButton:SetPoint("TOPRIGHT", -8, -8)
    Skin(closeButton, "Interface\\AddOns\\Epithet\\icons\\ui\\epithet-ui-close-16")

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

    local title = self:LocalizeField(content.title) or ((L and L["WHATS_NEW_HEADING"]) or "What's New")
    self.dialogHeading:SetText(title)

    local totalHeight = self:RenderBody(self:LocalizeField(content.body) or "")
    self.dialogContent:SetHeight(math.max(1, totalHeight + 16))
    self.dialogScroll:SetVerticalScroll(0)

    frame:Show()
end

function WhatsNew:ShowForCurrentVersionIfNeeded()
    -- Startup display is deferred and guarded so only one popup can be scheduled per session.
    if self.shownThisSession or self.pendingShow then
        return
    end

    local profile = ns.Epithet and ns.Epithet.db and ns.Epithet.db.profile
    if profile and profile.showWhatsNewOnStartup == false then
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
