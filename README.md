# Epithet

A World of Warcraft addon that lets you browse every player title, see how each is earned and how rare it is, track the ones you're still missing, spot titles other players are wearing out in the world, and earn Epithet Achievements along the way.

## Features

### Title Browser

- **Full title catalogue** - enumerates all titles via the client API, joined with a curated static database containing source info, expansion, and rarity.
- **Rarity tiers** - colour-coded Common → Legendary, displayed in standard WoW item-quality colours, with an in-app popup explaining how the percentages are estimated.
- **Collection tracking** - earned vs unearned at a glance, with a collected count (optionally scoped to obtainable-only titles).
- **Filters** - by expansion, status (earned/unearned), rarity, type, category, prefix/suffix, faction, favourites-only, hide-unobtainable, hide-time-sensitive, and free-text search.
- **Favourites** - star any earned title; favourites pin to the top of the Collected group in "Collected First" sort mode and show a star prefix in the list.
- **Set title** - "Set as My Title" button wired to a hardware event (required by the protected `SetCurrentTitle` API).
- **About modal** - addon and author info from a title-bar info button.

### Title Spotting (Social Layer)

- **Target nameplate overlay** - shows the title currently displayed by whoever you're targeting, anchored below the Blizzard target frame.
- **Two layouts** - "Slimline" (classic) and "Portrait Card", with an optional animated 3D portrait, configurable fade-out on target loss, and a draggable/lockable position.
- **Visibility rules** - optional auto-hide in combat or in a group, so the overlay stays out of the way when it isn't wanted.
- **Spotting Log** - a persistent, per-character log of titles you've spotted on other players, with list/grid views and scope toggle (spotted vs. remaining), plus import/export for sharing logs.
- **Epithet Achievements** - a dedicated achievement system built on top of spotting and collection data: progression tiers, coverage goals, crossover and secret achievements, earned-record persistence, and optional chat notifications. Opened from its own header button, separate from the Spotting Log.

### Quality of Life

- **What's New popup** - a themed, version-mapped changelog dialog shown once per update; reopen anytime with `/epithet whatsnew`.
- **Minimap button** - via LibDataBroker/LibDBIcon, with a tooltip showing your current collected count; toggle with `/epithet minimap`.
- **Slash commands** - `/epithet` (or `/titles`) toggles the browser window; see [Usage In-Game](#usage-in-game) for the full list.

## Project Structure

```txt
Epithet/
├── Epithet.toc              # Addon manifest
├── Core/
│   ├── Epithet.lua          # Addon bootstrap, slash commands, minimap button, event wiring
│   ├── Theme.lua            # Shared theme helpers and palette
│   ├── TitleData.lua        # Live title scan and static data bridge
│   ├── Filters.lua          # Filtering, sorting, and display list logic
│   ├── Settings.lua         # Blizzard settings panel
│   ├── SocialLayer.lua      # Target-frame title spotting overlay
│   ├── WhatsNew.lua         # What's New popup runtime
│   ├── SocialLayouts.lua    # Social layout registry
│   └── SocialLayouts/
│       ├── classic.lua      # "Slimline" layout implementation
│       └── portrait.lua     # "Portrait Card" layout implementation
├── UI/
│   ├── MainFrame.xml        # Main window layout
│   ├── MainFrame.lua        # Main window controller
│   ├── TitleList.lua        # Virtualized title list
│   ├── Sidebar.lua          # Filter sidebar
│   └── Detail.lua           # Title detail panel
├── Spotting/
│   ├── TitleIndex.lua       # Runtime title fragment index
│   ├── Capture.lua          # Spot capture and debounce logic
│   ├── Achievements.lua     # Epithet Achievements system
│   ├── Log.lua              # Spot log persistence and import/export
│   └── LogbookUI.lua        # Spotting log and achievements UI
├── WhatsNew/
│   ├── Content.lua          # What's New content registry
│   └── Versions/
│       ├── v1_2_0.lua       # Content for a single version's popup
│       └── v1_2_0/          # That version's own dedicated art (banners, screenshots)
├── data/
│   ├── TitlesDB.lua         # Bundled static title database
│   └── schema.json          # Data schema
├── Locales/
│   └── enGB.lua             # Default locale strings
├── libs/                    # Embedded Ace3 + LibDataBroker/LibDBIcon (see below)
├── icons/
├── docs/                    # Release notes and technical guides
├── scripts/                 # Build, fetch-libs, link, and release scripts
├── LICENSE
└── README.md
```

## API Research (Warcraft Wiki - confirmed 12.0.1 mainline)

| Function                   | Signature                                   | Notes                                                               |
| -------------------------- | ------------------------------------------- | ------------------------------------------------------------------- |
| `GetNumTitles()`           | `numTitles = GetNumTitles()`                | Returns the **highest** title ID (sparse - gaps exist)              |
| `GetTitleName(titleId)`    | `name, playerTitle = GetTitleName(titleId)` | Trailing space in `name` → prefix; otherwise suffix                 |
| `IsTitleKnown(titleId)`    | `isKnown = IsTitleKnown(titleId)`           | Boolean - the character has earned it                               |
| `GetCurrentTitle()`        | `currentTitle = GetCurrentTitle()`          | Returns active title ID (0 = none)                                  |
| `SetCurrentTitle(titleId)` | `SetCurrentTitle(titleId)`                  | **Protected** - must originate from a hardware event (button click) |

The API exposes **only** the title list and known/unknown state. It does **not** provide rarity or source - hence the static data table.

## Rarity Heuristic

Since no authoritative rarity feed exists, rarity is derived from acquisition category:

| Tier | Label     | Criteria                                                                            |
| ---- | --------- | ----------------------------------------------------------------------------------- |
| 5    | Legendary | Seasonal PvP Glad/R1/Hero, Grand Marshal/High Warlord, Scarab Lord                  |
| 4    | Epic      | Removed/unobtainable, Challenge Mode Gold, Hall of Fame, Cutting Edge, "the Insane" |
| 3    | Rare      | Multi-patch meta-achievements (Loremaster, Glory metas), M+ score titles            |
| 2    | Uncommon  | Single achievements, holiday metas, campaign completion, exploration                |
| 1    | Common    | Baseline rep grinds, low PvP ranks, trivial quest rewards                           |

Override any title by adding its ID to `RARITY_OVERRIDES` in `tools/generate-titles.js`.

## Dependencies

- **Ace3** (AceAddon-3.0, AceDB-3.0, CallbackHandler-1.0) - BSD licensed.
- **LibDataBroker-1.1** and **LibDBIcon-1.0** - power the minimap launcher button.
- All dependencies are OSI-approved.

### Installing libs

Download from [CurseForge](https://www.curseforge.com/wow/addons/ace3) or run `scripts/fetch/fetch-libs.ps1`. Place in `libs/`:

```txt
libs/
├── LibStub/
├── CallbackHandler-1.0/
├── AceAddon-3.0/
├── AceDB-3.0/
├── LibDataBroker-1.1/
└── LibDBIcon-1.0/
```

## Usage In-Game

1. Install the addon to `Interface/AddOns/Epithet/`.
2. `/epithet` or `/titles` - opens the title browser.
3. `/epithet scan` - forces a title rescan.
4. `/epithet minimap` - toggles the minimap launcher button.
5. `/epithet whatsnew` - reopens the What's New dialog for the current version.
6. `/epithet debug` - dumps raw title API output for the first known titles (troubleshooting).
7. Title Spotting, the Spotting Log, and Epithet Achievements are configured from the addon's Options panel and opened via the header buttons in the main window.

## Contributing

Found a missing title, incorrect data, or an obtainability change? Open an issue using one of the templates below:

| Template                                                                                                  | When to use                                                          |
| --------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| **[New Title](../../issues/new?labels=new-title&template=new-title.md)**                                  | A title exists in-game but is missing from the database              |
| **[Title Correction](../../issues/new?labels=correction&template=title-correction.md)**                   | Any field on an existing title is wrong (rarity, source, type, etc.) |
| **[Obtainability Change](../../issues/new?labels=obtainability-change&template=obtainability-change.md)** | A title was removed, re-added, or made seasonal in a patch           |
| **[Bulk Update](../../issues/new?labels=bulk-update&template=bulk-update.md)**                            | Multiple titles added/changed in a single patch or event             |
| **[Feature Request](../../issues/new?labels=enhancement&template=feature_request.yml)**                   | An idea for a new feature or improvement                             |

Please include patch notes, in-game screenshots, or official sources as evidence where possible.

See [docs/RELEASE_NOTES.md](docs/RELEASE_NOTES.md) for the full version history, and [docs/WHATS_NEW_FEATURE.md](docs/WHATS_NEW_FEATURE.md) for how the in-game What's New system works.

## Licence

Apache-2.0 license - see [LICENSE](LICENSE).

## Contributors

It's great to see people enjoying Epithet as an add-on to the extent that they get involved in improving the tool, below are some of Epithets contributors

### Locale Contributors

- [Hubbotu](https://github.com/Hubbotu) - Contributing the the ruRU locale/lang files.

