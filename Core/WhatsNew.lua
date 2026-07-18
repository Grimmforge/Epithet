-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) Grimmforge

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

local function EscapeHTML(value)
    value = tostring(value or "")
    value = gsub(value, "&", "&amp;")
    value = gsub(value, "<", "&lt;")
    value = gsub(value, ">", "&gt;")
    return value
end

local function RenderInline(value)
    local text = EscapeHTML(value)
    text = gsub(text, "%*%*(.-)%*%*", "<b>%1</b>")
    text = gsub(text, "%*(.-)%*", "<i>%1</i>")
    return text
end

local function BuildHTMLFromBody(body)
    local src = tostring(body or "")
    local html = { "<html><body>" }

    for line in src:gmatch("[^\r\n]+") do
        local h2 = match(line, "^%s*##%s+(.+)$")
        local h1 = match(line, "^%s*#%s+(.+)$")
        local imagePath = match(line, "^%s*!%[[^%]]*%]%((.+)%)%s*$")

        if imagePath and imagePath ~= "" then
            html[#html + 1] = "<p>|T" .. imagePath .. ":96:96|t</p>"
        elseif h2 then
            html[#html + 1] = "<h2>" .. RenderInline(h2) .. "</h2>"
        elseif h1 then
            html[#html + 1] = "<h1>" .. RenderInline(h1) .. "</h1>"
        elseif line:match("^%s*$") then
            html[#html + 1] = "<p> </p>"
        else
            html[#html + 1] = "<p>" .. RenderInline(line) .. "</p>"
        end
    end

    html[#html + 1] = "</body></html>"
    return table.concat(html, "\n")
end

local function EstimateBodyHeight(body)
    local src = tostring(body or "")
    local total = 0

    for line in src:gmatch("[^\r\n]+") do
        local h2 = match(line, "^%s*##%s+(.+)$")
        local h1 = match(line, "^%s*#%s+(.+)$")
        local imagePath = match(line, "^%s*!%[[^%]]*%]%((.+)%)%s*$")

        if imagePath and imagePath ~= "" then
            total = total + 106
        elseif h1 then
            total = total + 28
        elseif h2 then
            total = total + 22
        elseif line:match("^%s*$") then
            total = total + 10
        else
            total = total + 16
        end
    end

    return math.max(64, total + 24)
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

    local html = CreateFrame("SimpleHTML", nil, scroll)
    html:SetWidth(690)
    html:SetHeight(1)
    html:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    html:SetJustifyH("h1", "LEFT")
    html:SetJustifyH("h2", "LEFT")
    html:SetJustifyH("p", "LEFT")
    html:SetJustifyV("h1", "TOP")
    html:SetJustifyV("h2", "TOP")
    html:SetJustifyV("p", "TOP")
    html:SetSpacing("h1", 4)
    html:SetSpacing("h2", 3)
    html:SetSpacing("p", 2)
    html:SetFont("h1", "Fonts\\FRIZQT__.TTF", 18, "")
    html:SetFont("h2", "Fonts\\FRIZQT__.TTF", 14, "")
    html:SetFont("p", "Fonts\\FRIZQT__.TTF", 12, "")
    html:SetTextColor("h1", 0.96, 0.89, 0.65, 1)
    html:SetTextColor("h2", 0.90, 0.80, 0.52, 1)
    html:SetTextColor("p", 0.86, 0.82, 0.74, 1)

    scroll:SetScrollChild(html)

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
    self.dialogHTML = html
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

    local rawBody = content.body or ""
    local bodyHTML = BuildHTMLFromBody(rawBody)
    self.dialogHTML:SetText(bodyHTML)

    local htmlHeight = nil
    if self.dialogHTML.GetStringHeight then
        htmlHeight = self.dialogHTML:GetStringHeight()
    end
    if not htmlHeight or htmlHeight <= 0 then
        htmlHeight = EstimateBodyHeight(rawBody)
    end
    self.dialogHTML:SetHeight(math.max(1, htmlHeight + 32))
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
