-- =============================================================================
-- Epithet — Locale: enGB (default)
-- NOTE: WoW Lua 5.1 does NOT support \xNN hex escapes. Use decimal byte escapes
--       (e.g. \226\128\148 = em dash) or plain ASCII.
-- =============================================================================
local _, ns = ...

local L = {}
ns.L = L

-- Common glyphs (decimal byte escapes)
local DOT   = "\194\183"        -- middle dot ·
local DASH  = "\226\128\148"    -- em dash —
local CHECK = "\226\156\147"    -- check mark ✓

-- Window
L["WINDOW_TITLE"] = "TITLES"
L["CLOSE"] = "Close"

-- Header band
L["TITLES_EARNED"] = "TITLES EARNED"
L["TITLES_EARNED_OBTAINABLE"] = "OBTAINABLE EARNED"
L["TOGGLE_ALL_TITLES"] = "Show all titles in count"
L["TOGGLE_OBTAINABLE_ONLY"] = "Show only obtainable titles in count"
L["TOGGLE_OBTAINABLE_LABEL"] = "Obtainable only"

-- Filter sidebar
L["SEARCH_PLACEHOLDER"] = "Search titles or sources..."
L["STATUS"] = "STATUS"
L["STATUS_ALL"] = "All"
L["STATUS_EARNED"] = "Earned"
L["STATUS_UNEARNED"] = "Unearned"
L["RARITY_TIER"] = "Rarity Tier"
L["TYPE"] = "Type"
L["EXPANSION"] = "Expansion"
L["ADDITIONAL_FILTERS"] = "Additional Filters"
L["RESET_ALL_FILTERS"] = "Reset all filters"
L["FAVOURITES_ONLY"] = "Favourites only"
L["ADD_FAVOURITE"] = "Add to Favourites"
L["REMOVE_FAVOURITE"] = "Remove from Favourites"
L["PREFIX"] = "Prefix"
L["SUFFIX"] = "Suffix"

-- Rarity names
L["COMMON"] = "Common"
L["UNCOMMON"] = "Uncommon"
L["RARE"] = "Rare"
L["EPIC"] = "Epic"
L["LEGENDARY"] = "Legendary"

-- List header
L["N_TITLES"] = "%d titles"
L["SORT_COLLECTED_FIRST"] = "Collected first"
L["SORT_BY_EXPANSION"] = "By expansion"
L["SORT_ALPHABETICAL"] = "Alphabetical"
L["SORT_BY_QUALITY"] = "By quality"
L["SORT_BY_CATEGORY"] = "By category"

-- Group headers
L["GROUP_COLLECTED"] = "COLLECTED"
L["GROUP_NOT_COLLECTED"] = "NOT YET COLLECTED"

-- Detail panel
L["PREVIEW_HOVERING"] = "PREVIEW " .. DASH .. " HOVERING"
L["PREFIX_TITLE"] = "Prefix title"
L["SUFFIX_TITLE"] = "Suffix title"
L["HOW_TO_OBTAIN"] = "HOW TO OBTAIN"
L["HELD_BY_ESTIMATE"] = "Held by an estimated %s%% of active characters."
L["EXPANSION_LABEL"] = "Expansion"
L["CATEGORY_LABEL"] = "Category"
L["AVAILABILITY_LABEL"] = "Availability"
L["ACCOUNT_WIDE"] = "Account-wide"
L["NO_LONGER_OBTAINABLE"] = "No longer obtainable"
L["CURRENT_PATCH"] = "Current patch " .. DOT .. " 12.0.5"
L["EARNED_DATE"] = "Earned %s"
L["NOT_YET_EARNED"] = "Not yet earned"

-- Action footer
L["SET_AS_MY_TITLE"] = "Set as My Title"
L["SET_NOTE"] = "Shown beneath your name to other players."
L["CURRENT_TITLE"] = "Current Title"
L["CURRENT_NOTE"] = "This title is displayed above your character."
L["LOCKED_BUTTON"] = "Not Yet Earned"
L["LOCKED_NOTE"] = "Earn this title to set it as your own."

-- Empty states
L["NO_MATCH"] = "No titles match these filters."
L["NO_SELECTION"] = "Select a title to view its source and rarity."

-- Bottom bar / rarity legend
L["RARITY"] = "RARITY"
L["SOURCE_LEGEND"] = "SOURCE"

-- Rarity explanation (fallback only; primary copy lives in EpithetData.rarityNote)
L["RARITY_NOTE"] = "Rarity is estimated from the global earn-rate of the linked source " .. DASH ..
    " the share of active level-capped characters who hold it, drawn from Blizzard's achievement " ..
    "statistics. Sources held by fewer than 1% of players are rated Legendary; the most widely-held " ..
    "rank and holiday titles are Common. Estimates refresh weekly and are independent of a title's " ..
    "in-game item-quality colour."

-- Minimap
L["MINIMAP_TOOLTIP_TITLE"] = "Epithet"
L["MINIMAP_TOOLTIP_LEFT"] = "Left-click to open the title browser."
L["MINIMAP_TOOLTIP_RIGHT"] = "Right-click to hide this button."
L["MINIMAP_HIDDEN"] = "Minimap button hidden. Type /epithet minimap to show it again."
L["MINIMAP_SHOWN"] = "Minimap button shown."

-- Social layer / title spotting
L["SOCIAL_LAYER"] = "Title Spotting"
L["SOCIAL_LAYER_DESC"] = "Inspecting total strangers is practically a core ability by now. Point it at their titles too: spot what another players have chosen to wear and jump straight in to how it's earned in Epithet."
L["SOCIAL_ENABLED"] = "Enable title spotting"
L["SOCIAL_STATE_SECTION"] = "Feature State"
L["SOCIAL_TARGET_UNLOCK"] = "Unlock target nameplate (drag to move)"
L["SOCIAL_TARGET_RESET"] = "Reset target nameplate position"
L["SOCIAL_TARGET_EDIT_HINT"] = "EDIT MODE · Left-drag to move · Right-click to lock"
L["SOCIAL_TARGET_EDIT_TOP"] = "EDIT MODE"
L["SOCIAL_TARGET_EDIT_BOTTOM"] = "Left-drag to move · Right-click to lock"
L["SOCIAL_TARGET_PLACEHOLDER_TITLE"] = "Example Title"
L["SOCIAL_TARGET_PLACEHOLDER_RARITY"] = "RARE"
L["SOCIAL_PRESTIGE_FORMAT"] = "%s %s"
L["SOCIAL_LAYOUT_SECTION"] = "Nameplate Layout"
L["SOCIAL_LAYOUT_CLASSIC"] = "Slimline"
L["SOCIAL_LAYOUT_PORTRAIT"] = "Portrait Card"
L["SOCIAL_LAYOUT_PREVIEW"] = "Layout Preview"
L["SOCIAL_LAYOUT_PREVIEW_NOTE"] = "Preview uses sample data."
L["SOCIAL_LAYOUT_FUNNY_TOGGLE"] = "Show funny long-title preview"
L["SOCIAL_BEHAVIOUR_SECTION"] = "Visibility Rules"
L["SOCIAL_FADE_SECTION"] = "Fade"
L["SOCIAL_FADE_ENABLE"] = "Fade target nameplates after a delay"
L["SOCIAL_FADE_DURATION"] = "Fade delay"
L["SOCIAL_FADE_DURATION_FMT"] = "%.1f seconds before fade"
L["SOCIAL_SPOTTING_NOTIFY"] = "Show spotting confirmations in chat"
L["SOCIAL_POSITION_SECTION"] = "Position"

L["SPOTTING_NEW_SPOT_FMT"] = "Spotted: %s"
L["SPOTTING_LOG_TOOLTIP"] = "Spotting Log (%d found)"
L["SPOTTING_LOG_TOOLTIP_LEFT"] = "Left-click: Open title spotting log."
L["SPOTTING_LOG_TOOLTIP_RIGHT"] = "Right-click: Shout your spotting stats in /s."
L["SPOTTING_LOG_SHOUT_FMT_1"] = "I've admired %d strangers a completely normal amount!"
L["SPOTTING_LOG_SHOUT_FMT_2"] = "I have inspected %d strangers against their knowledge and consent!"
L["SPOTTING_LOG_SHOUT_FMT_3"] = "I've been quietly judging the titles of %d strangers!"
L["SPOTTING_LOG_SHOUT_FMT_4"] = "%d strangers have been observed. None of them noticed. Excellent."
L["SPOTTING_LOG_SHOUT_FMT_5"] = "I've stalked %d unsuspecting adventurers for their titles alone!"
L["SPOTTING_LOG_HEADING"] = "Spotting Log"
L["SPOTTING_LOG_COUNT_FMT"] = "%d titles spotted"
L["SPOTTING_LOG_COUNT_PROGRESS_FMT"] = "%d / %d titles spotted"
L["SPOTTING_LOG_COUNT_REMAINING_FMT"] = "%d titles remaining"
L["SPOTTING_LOG_EMPTY"] = "Nothing spotted yet. Target players in the wild to log the titles they are wearing."
L["SPOTTING_LOG_EMPTY_REMAINING"] = "No remaining titles in the current catalogue."
L["SPOTTING_LOG_GATED"] = "Title spotting is off. Sightings are not being recorded."
L["SPOTTING_LOG_OPEN_SETTINGS"] = "Enable in Settings"
L["SPOTTING_SCOPE_SPOTTED"] = "Spotted"
L["SPOTTING_SCOPE_REMAINING"] = "Remaining"
L["SPOTTING_VIEW_LIST"] = "List"
L["SPOTTING_VIEW_GRID"] = "Grid"
L["SPOTTING_EXPORT_BUTTON"] = "Export"
L["SPOTTING_IMPORT_BUTTON"] = "Import"
L["SPOTTING_EXPORT_TITLE"] = "Export Spotting Log"
L["SPOTTING_IMPORT_TITLE"] = "Import Spotting Log"
L["SPOTTING_TRANSFER_NOTE"] = "Copy or paste the full payload below."
L["SPOTTING_TRANSFER_COPY"] = "Select All"
L["SPOTTING_TRANSFER_IMPORT"] = "Import"
L["SPOTTING_TRANSFER_CLOSE"] = "Close"
L["SPOTTING_IMPORT_SUCCESS_FMT"] = "Imported %d spotting entries."
L["SPOTTING_IMPORT_FAILED_FMT"] = "Import failed: %s"
L["SPOTTING_NOT_SPOTTED"] = "Remaining"
L["SPOTTING_NOT_SPOTTED_YET"] = "Not spotted yet."
L["SPOTTING_TOOLTIP_FIRST_FMT"] = "First spotted on %s in %s on %s"
L["SPOTTING_TOOLTIP_COUNT_FMT"] = "Seen %d times"
L["SPOTTING_TOOLTIP_LAST_FMT"] = "Last seen on %s as %s"

-- Source kinds
L["KIND_ACHIEVEMENT"] = "Achievement"
L["KIND_QUEST"] = "Quest"
L["KIND_REPUTATION"] = "Reputation"
L["KIND_PVP_RANK"] = "PvP Rank"
L["KIND_FEAT"] = "Feat of Strength"
L["KIND_ITEM"] = "Item"
L["KIND_PROMOTION"] = "Promotion"

-- Filter facets (new)
L["CATEGORY"] = "Category"
L["KIND"] = "Source Kind"
L["FACTION"] = "Faction"
L["FACTION_ALLIANCE"] = "Alliance"
L["FACTION_HORDE"] = "Horde"
L["FACTION_BOTH"] = "Both Factions"
L["AVAILABILITY"] = "Availability"
L["HIDE_UNOBTAINABLE"] = "Hide unobtainable"
L["HIDE_TIME_SENSITIVE"] = "Hide time-sensitive"
L["UNKNOWN_SOURCE"] = "Unknown source"
L["FEAT_OF_STRENGTH"] = "Feat of Strength (may be unobtainable)"

-- Source descriptions
L["SOURCE_ACHIEVEMENT_DESC"] = "Awarded by the achievement %s"
L["SOURCE_QUEST_DESC"] = "Awarded during the quest %s"
L["SOURCE_ITEM_DESC"] = "Granted by %s"

-- Meta grid
L["LAST_ASSESSED"] = "Last assessed"

-- Availability labels
L["AVAILABILITY_SEASONAL"] = "Seasonal"
L["AVAILABILITY_LIMITED"] = "Limited"
L["AVAILABILITY_PROMOTIONAL"] = "Promotional"
L["AVAILABILITY_TEMPORARY"] = "Temporary"
L["AVAILABILITY_REMOVED"] = "Removed"
L["AVAILABILITY_PERMANENT"] = "Permanent"
