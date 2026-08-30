-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) Grimmsforge

local _, ns = ...

local TitleIndex = {}
ns.TitleIndex = TitleIndex

local GetNumTitles = GetNumTitles
local GetTitleName = GetTitleName
local UnitIsPlayer = UnitIsPlayer
local UnitName = UnitName
local UnitPVPName = UnitPVPName
local pairs, ipairs, next = pairs, ipairs, next

local index = nil
local built = false

local function Trim(value)
    if not value then return "" end
    value = tostring(value)
    value = value:gsub("^%s+", "")
    value = value:gsub("%s+$", "")
    return value
end

local function Normalize(value)
    value = Trim(value)
    value = value:gsub("^[%s,]+", "")
    value = value:gsub("[%s,]+$", "")
    value = value:gsub("%s+", " ")
    return value:lower()
end

local function ExtractFragment(raw)
    if not raw or raw == "" then
        return nil
    end

    local before = raw:match("^(.-)%%s") or ""
    local after = raw:match("%%s(.*)$") or ""

    if before:match("%S") then
        return Normalize(before)
    end

    if after:match("%S") then
        return Normalize(after)
    end

    return nil
end

local function StripLeading(full, base)
    if not full or not base then return "" end
    if full:sub(1, #base) == base then
        return full:sub(#base + 1)
    end

    local _, e = full:find(base, 1, true)
    if e then
        return full:sub(e + 1)
    end

    return ""
end

local function StripTrailing(full, base)
    if not full or not base then return "" end
    if full:sub(-#base) == base then
        return full:sub(1, #full - #base)
    end

    local s = full:find(base, 1, true)
    if s then
        return full:sub(1, s - 1)
    end

    return ""
end

local function EscapePattern(text)
    return (text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

-- Reused across calls to avoid allocating a fresh table on every Resolve()
-- (this runs from the UNIT_NAME_UPDATE / PLAYER_TARGET_CHANGED hot path).
local candidateScratch = {}

local function PushCandidate(candidates, value)
    local normalized = Normalize(value)
    if normalized ~= "" then
        candidates[#candidates + 1] = normalized
    end
end

local function BuildCandidates(full, base)
    local candidates = candidateScratch
    for i = #candidates, 1, -1 do
        candidates[i] = nil
    end

    if full and full:find(",", 1, true) then
        local commaSuffix = full:match("^[^,]+,%s*(.+)$")
        if commaSuffix then
            PushCandidate(candidates, commaSuffix)
        end
    end

    if base and base ~= "" then
        local basePlain = base:match("^([^%-]+)") or base
        local baseEsc = EscapePattern(base)
        local basePlainEsc = EscapePattern(basePlain)

        PushCandidate(candidates, StripLeading(full, base))
        PushCandidate(candidates, StripTrailing(full, base))

        if basePlain ~= base then
            PushCandidate(candidates, StripLeading(full, basePlain))
            PushCandidate(candidates, StripTrailing(full, basePlain))
        end

        local prefixed = full:gsub("%s*" .. baseEsc .. "$", "", 1)
        if prefixed ~= full then
            PushCandidate(candidates, prefixed)
        end

        local prefixedPlain = full:gsub("%s*" .. basePlainEsc .. "$", "", 1)
        if prefixedPlain ~= full then
            PushCandidate(candidates, prefixedPlain)
        end
    end

    return candidates
end

function TitleIndex:Reset()
    index = nil
    built = false
end

function TitleIndex:Build()
    if built and index then
        return index
    end

    if ns.TitleData and ns.TitleData.Scan then
        ns.TitleData:Scan()
    end

    index = {}

    local recordsByID = ns.TitleData and ns.TitleData.recordsByID
    if recordsByID then
        -- Index the RECORD's own id, never the key being iterated. Scan collapses
        -- API-duplicate titles (Grunt is both 16 and 169) onto one record that
        -- every alias id maps to, so the iterated key is whichever duplicate
        -- pairs() happens to reach first — an order that can differ between
        -- sessions. Since the spotting log is keyed by title id, drifting between
        -- 16 and 169 would log one title as two and inflate the spotted count.
        -- record.titleID is always the canonical row, so resolution is stable.
        for _, record in pairs(recordsByID) do
            if record and record.titleID then
                -- TitleData:Scan() already fetched and classified this string;
                -- reuse it instead of a second GetTitleName() + parse pass.
                local raw = record.raw or (GetTitleName and GetTitleName(record.titleID))
                local fragment = ExtractFragment(raw)
                if fragment and fragment ~= "" and not index[fragment] then
                    index[fragment] = record.titleID
                end
            end
        end
    else
        local maxID = GetNumTitles and GetNumTitles() or 0
        for titleID = 1, maxID do
            local raw = GetTitleName and GetTitleName(titleID) or nil
            local fragment = ExtractFragment(raw)
            if fragment and fragment ~= "" and not index[fragment] then
                index[fragment] = titleID
            end
        end
    end

    built = true
    return index
end

function TitleIndex:EnsureBuilt()
    if not built or not index then
        self:Build()
    end
    return index
end

function TitleIndex:Resolve(unit)
    if not unit or not UnitIsPlayer or not UnitIsPlayer(unit) then
        return nil
    end

    local base = UnitName and UnitName(unit)
    local full = UnitPVPName and UnitPVPName(unit) or nil
    if unit == "target" and TargetFrameName and TargetFrameName.GetText then
        full = full or TargetFrameName:GetText()
    end

    if not full or full == "" or not base or base == "" then
        return nil
    end

    local idx = self:EnsureBuilt()
    if not idx then
        return nil
    end

    if not next(idx) then
        self:Reset()
        idx = self:Build() or {}
    end

    local candidates = BuildCandidates(full, base)
    for _, candidate in ipairs(candidates) do
        local titleID = idx[candidate]
        if titleID then
            return titleID
        end
    end

    return nil
end
