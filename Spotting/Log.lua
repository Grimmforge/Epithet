-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) Grimmforge

local _, ns = ...

local Log = {}
ns.SpottingLog = Log

local EXPORT_MAGIC = "EPITHET_SPOTLOG_V1"
local EXPORT_MAGIC_B64 = "EPITHET_SPOTLOG_B64_V1"
local B64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local GetUnitName = GetUnitName
local GetZoneText = GetZoneText
local UnitName = UnitName
local time = time

local function GetRootDB()
    local db = _G.EpithetDB
    if type(db) ~= "table" then
        return nil
    end
    return db
end

local function GetStore()
    local db = GetRootDB()
    if not db then
        return nil
    end

    if type(db.spotted) ~= "table" then
        db.spotted = {}
    end

    return db.spotted
end

local function NormalizeEntry(entry, now)
    if type(entry) ~= "table" then
        return nil
    end

    local firstSeen = tonumber(entry.firstSeen) or now
    local lastSeen = tonumber(entry.lastSeen) or firstSeen
    local count = tonumber(entry.count) or 1
    if count < 1 then count = 1 end
    count = math.floor(count)

    return {
        firstSeen = firstSeen,
        lastSeen = lastSeen,
        count = count,
        firstName = entry.firstName,
        firstZone = entry.firstZone,
        lastName = entry.lastName,
        classTag = entry.classTag,
        titleText = entry.titleText,
        titleType = entry.titleType,
        quality = entry.quality,
        kind = entry.kind,
        cat = entry.cat,
    }
end

local function EscapeValue(value)
    if value == nil then return "" end
    value = tostring(value)
    value = value:gsub("\\", "\\\\")
    value = value:gsub("\n", "\\n")
    value = value:gsub("|", "\\p")
    return value
end

local function UnescapeValue(value)
    if not value or value == "" then return nil end

    local out = {}
    local i = 1
    while i <= #value do
        local ch = value:sub(i, i)
        if ch == "\\" and i < #value then
            local nxt = value:sub(i + 1, i + 1)
            if nxt == "n" then
                out[#out + 1] = "\n"
            elseif nxt == "p" then
                out[#out + 1] = "|"
            elseif nxt == "\\" then
                out[#out + 1] = "\\"
            else
                out[#out + 1] = nxt
            end
            i = i + 2
        else
            out[#out + 1] = ch
            i = i + 1
        end
    end

    return table.concat(out)
end

local function SplitFields(line)
    local fields = {}
    local start = 1

    while true do
        local idx = line:find("|", start, true)
        if not idx then
            fields[#fields + 1] = line:sub(start)
            break
        end
        fields[#fields + 1] = line:sub(start, idx - 1)
        start = idx + 1
    end

    return fields
end

local function Base64Encode(data)
    if type(data) ~= "string" or data == "" then
        return ""
    end

    local out = {}
    local len = #data
    local i = 1

    while i <= len do
        local b1 = data:byte(i) or 0
        local b2 = data:byte(i + 1) or 0
        local b3 = data:byte(i + 2) or 0

        local n = (b1 * 65536) + (b2 * 256) + b3
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64

        local hasB2 = (i + 1) <= len
        local hasB3 = (i + 2) <= len

        out[#out + 1] = B64_ALPHABET:sub(c1 + 1, c1 + 1)
        out[#out + 1] = B64_ALPHABET:sub(c2 + 1, c2 + 1)
        out[#out + 1] = hasB2 and B64_ALPHABET:sub(c3 + 1, c3 + 1) or "="
        out[#out + 1] = hasB3 and B64_ALPHABET:sub(c4 + 1, c4 + 1) or "="

        i = i + 3
    end

    return table.concat(out)
end

local function Base64Decode(data)
    if type(data) ~= "string" then
        return nil, "Invalid payload"
    end

    data = data:gsub("%s+", "")
    if data == "" then
        return ""
    end
    if (#data % 4) ~= 0 then
        return nil, "Malformed base64 payload"
    end

    local decodeMap = {}
    for i = 1, #B64_ALPHABET do
        decodeMap[B64_ALPHABET:sub(i, i)] = i - 1
    end

    local out = {}
    local idx = 1
    while idx <= #data do
        local c1 = data:sub(idx, idx)
        local c2 = data:sub(idx + 1, idx + 1)
        local c3 = data:sub(idx + 2, idx + 2)
        local c4 = data:sub(idx + 3, idx + 3)

        local v1 = decodeMap[c1]
        local v2 = decodeMap[c2]
        local v3 = (c3 == "=") and 0 or decodeMap[c3]
        local v4 = (c4 == "=") and 0 or decodeMap[c4]

        if v1 == nil or v2 == nil or v3 == nil or v4 == nil then
            return nil, "Invalid base64 characters"
        end

        local n = (v1 * 262144) + (v2 * 4096) + (v3 * 64) + v4
        local b1 = math.floor(n / 65536) % 256
        local b2 = math.floor(n / 256) % 256
        local b3 = n % 256

        out[#out + 1] = string.char(b1)
        if c3 ~= "=" then
            out[#out + 1] = string.char(b2)
        end
        if c4 ~= "=" then
            out[#out + 1] = string.char(b3)
        end

        idx = idx + 4
    end

    return table.concat(out)
end

function Log:Init()
    local store = GetStore()
    if not store then
        return
    end

    local now = time()
    local toDelete = {}
    local toWrite = {}

    for key, entry in pairs(store) do
        local titleID = tonumber(key)
        if not titleID then
            toDelete[#toDelete + 1] = key
        else
            local normalized = NormalizeEntry(entry, now)
            if not normalized then
                toDelete[#toDelete + 1] = key
            else
                toWrite[titleID] = normalized
                if key ~= titleID then
                    toDelete[#toDelete + 1] = key
                end
            end
        end
    end

    for _, key in ipairs(toDelete) do
        store[key] = nil
    end

    for titleID, entry in pairs(toWrite) do
        store[titleID] = entry
    end
end

function Log:Record(titleID, unit, info)
    titleID = tonumber(titleID)
    if not titleID then
        return false
    end

    local store = GetStore()
    if not store then
        return false
    end

    local now = time()
    local fullName = (GetUnitName and unit and GetUnitName(unit, true)) or (UnitName and unit and UnitName(unit)) or "Unknown"
    local zone = (GetZoneText and GetZoneText()) or "Unknown"
    local titleText = info and info.titleText or nil
    local titleType = info and info.titleType or nil
    local quality = info and info.quality or nil
    local kind = info and info.kind or nil
    local cat = info and info.cat or nil
    local classTag = info and info.classTag or nil

    local entry = store[titleID]
    if type(entry) ~= "table" then
        store[titleID] = {
            firstSeen = now,
            lastSeen = now,
            count = 1,
            firstName = fullName,
            firstZone = zone,
            lastName = fullName,
            classTag = classTag,
            titleText = titleText,
            titleType = titleType,
            quality = quality,
            kind = kind,
            cat = cat,
        }
        return true
    end

    entry.lastSeen = now
    entry.lastName = fullName
    entry.count = math.max(1, math.floor(tonumber(entry.count) or 1) + 1)

    if not entry.firstSeen then
        entry.firstSeen = now
    end
    if not entry.firstName or entry.firstName == "" then
        entry.firstName = fullName
    end
    if not entry.firstZone or entry.firstZone == "" then
        entry.firstZone = zone
    end
    if (not entry.titleText or entry.titleText == "") and titleText and titleText ~= "" then
        entry.titleText = titleText
    end
    if not entry.titleType and titleType then
        entry.titleType = titleType
    end
    if not entry.quality and quality then
        entry.quality = quality
    end
    if not entry.kind and kind then
        entry.kind = kind
    end
    if not entry.cat and cat then
        entry.cat = cat
    end
    if not entry.classTag and classTag then
        entry.classTag = classTag
    end

    return false
end

function Log:Has(titleID)
    local store = GetStore()
    if not store then return false end
    return store[tonumber(titleID)] ~= nil
end

function Log:GetEntry(titleID)
    local store = GetStore()
    if not store then return nil end
    return store[tonumber(titleID)]
end

function Log:Count()
    local store = GetStore()
    if not store then return 0 end

    local count = 0
    for _ in pairs(store) do
        count = count + 1
    end

    return count
end

function Log:Iterate()
    local store = GetStore()
    if not store then
        local function EmptyIterator()
            return nil
        end
        return EmptyIterator
    end

    return next, store, nil
end

function Log:Export()
    local store = GetStore()
    if not store then
        return EXPORT_MAGIC
    end

    local lines = { EXPORT_MAGIC }
    for titleID, entry in pairs(store) do
        local normalized = NormalizeEntry(entry, time())
        if normalized then
            lines[#lines + 1] = table.concat({
                tostring(titleID),
                tostring(normalized.firstSeen or ""),
                tostring(normalized.lastSeen or ""),
                tostring(normalized.count or ""),
                EscapeValue(normalized.firstName),
                EscapeValue(normalized.firstZone),
                EscapeValue(normalized.lastName),
                EscapeValue(normalized.classTag),
                EscapeValue(normalized.titleText),
                EscapeValue(normalized.titleType),
                EscapeValue(normalized.quality),
                EscapeValue(normalized.kind),
                EscapeValue(normalized.cat),
            }, "|")
        end
    end

    table.sort(lines, function(a, b)
        if a == EXPORT_MAGIC then return true end
        if b == EXPORT_MAGIC then return false end
        return a < b
    end)

    local raw = table.concat(lines, "\n")
    local encoded = Base64Encode(raw)
    return EXPORT_MAGIC_B64 .. "\n" .. encoded
end

function Log:Import(payload)
    if type(payload) ~= "string" then
        return false, 0, "Invalid payload"
    end

    payload = payload:gsub("\r\n", "\n")
    payload = payload:gsub("\r", "\n")

    local firstLine = payload:match("^([^\n]+)")
    if firstLine == EXPORT_MAGIC_B64 then
        local encoded = payload:match("^[^\n]+\n?(.*)$") or ""
        local decoded, decodeErr = Base64Decode(encoded)
        if not decoded or decoded == "" then
            return false, 0, decodeErr or "Invalid base64 export"
        end
        payload = decoded
        firstLine = payload:match("^([^\n]+)")
    end

    if firstLine ~= EXPORT_MAGIC then
        return false, 0, "Invalid export format"
    end

    local store = GetStore()
    if not store then
        return false, 0, "SavedVariables unavailable"
    end

    local imported = 0
    for line in payload:gmatch("[^\n]+") do
        if line ~= EXPORT_MAGIC and line ~= "" then
            local fields = SplitFields(line)
            local titleID = tonumber(fields[1] or "")
            if titleID then
                local incoming = NormalizeEntry({
                    firstSeen = tonumber(fields[2] or ""),
                    lastSeen = tonumber(fields[3] or ""),
                    count = tonumber(fields[4] or ""),
                    firstName = UnescapeValue(fields[5] or ""),
                    firstZone = UnescapeValue(fields[6] or ""),
                    lastName = UnescapeValue(fields[7] or ""),
                    classTag = UnescapeValue(fields[8] or ""),
                    titleText = UnescapeValue(fields[9] or ""),
                    titleType = UnescapeValue(fields[10] or ""),
                    quality = UnescapeValue(fields[11] or ""),
                    kind = UnescapeValue(fields[12] or ""),
                    cat = UnescapeValue(fields[13] or ""),
                }, time())

                if incoming then
                    local current = store[titleID]
                    if type(current) ~= "table" then
                        store[titleID] = incoming
                        imported = imported + 1
                    else
                        local changed = false

                        if (tonumber(incoming.firstSeen) or 0) < (tonumber(current.firstSeen) or math.huge) then
                            current.firstSeen = incoming.firstSeen
                            current.firstName = incoming.firstName
                            current.firstZone = incoming.firstZone
                            changed = true
                        end

                        if (tonumber(incoming.lastSeen) or 0) > (tonumber(current.lastSeen) or 0) then
                            current.lastSeen = incoming.lastSeen
                            current.lastName = incoming.lastName
                            if incoming.classTag then
                                current.classTag = incoming.classTag
                            end
                            changed = true
                        end

                        local mergedCount = math.max(tonumber(current.count) or 1, tonumber(incoming.count) or 1)
                        if mergedCount ~= (tonumber(current.count) or 1) then
                            current.count = mergedCount
                            changed = true
                        end

                        if (not current.titleText or current.titleText == "") and incoming.titleText then
                            current.titleText = incoming.titleText
                            changed = true
                        end
                        if (not current.titleType or current.titleType == "") and incoming.titleType then
                            current.titleType = incoming.titleType
                            changed = true
                        end
                        if (not current.quality or current.quality == "") and incoming.quality then
                            current.quality = incoming.quality
                            changed = true
                        end
                        if (not current.kind or current.kind == "") and incoming.kind then
                            current.kind = incoming.kind
                            changed = true
                        end
                        if (not current.cat or current.cat == "") and incoming.cat then
                            current.cat = incoming.cat
                            changed = true
                        end
                        if (not current.classTag or current.classTag == "") and incoming.classTag then
                            current.classTag = incoming.classTag
                            changed = true
                        end

                        if changed then
                            imported = imported + 1
                        end
                    end
                end
            end
        end
    end

    return true, imported
end
