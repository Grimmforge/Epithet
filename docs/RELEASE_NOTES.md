# Release Notes

---

## [1.2.0] - 2026-07-17

### Added

- **Epithet Achievements system** — Added account- and character-scoped achievements for title spotting and ownership, including progression tiers, coverage goals, crossover achievements, secret achievements, and persistent earned records.
- **Ownership snapshot tracking** — Added per-character ownership detection storage to support ownership and crossover achievement checks.
- **Achievement notifications** — Added achievement-earned alerts with chat output and configurable notification toggle in settings.
- **Dedicated Epithet Achievements modal** — Added a separate achievements popup (distinct from Spotting Log) opened from a new 1:1 header button.
- **Achievement tile detail overlay** — Achievement tiles are now clickable and open a themed detail overlay with description, earned/progress status, and contextual detail.
- **Versioned What’s New feature** — Added a packaged, version-mapped What’s New dialog with per-version first-run and has-new flags, plus `/epithet whatsnew` to reopen.
- **Documentation** — Added a dedicated technical guide for the What’s New system in `docs/WHATS_NEW_FEATURE.md`.

### Changed

- **Header controls layout** — Added and iterated the achievements launcher icon in the main header; adjusted header count/progress/toggle spacing to avoid overlap.
- **Achievements visual style** — Converted achievements to responsive square tiles that dynamically fill row width, with icon-first presentation and improved earned/unearned readability.
- **Secret achievement presentation** — Secret unearned achievements now use masked visuals and question-mark imagery until revealed.
- **Achievement icon set** — Implemented per-achievement icon mapping and updated several specific icons based on latest tuning.
- **Tooltip and naming polish** — Renamed user-facing "Spotting Achievements" references to **Epithet Achievements** and aligned tooltip copy.

### Fixed

- **Startup event error** — Removed invalid event registration that could stop addon initialization and suppress other startup features.
- **Crossover timestamp reliability** — Updated crossover checks (including Window Shopper/Takes One to Know One) to prefer reliable ownership timing signals when available, reducing false positives from baseline scan timing.
- **What’s New SimpleHTML compatibility** — Fixed API-usage issues across `SetJustify*`, `SetSpacing`, and `SetFont`; added robust content-height fallback for clients without `SimpleHTML:GetStringHeight()`.

## [1.1.0] - 2026-06-09

### Added

- **Favourites** — Mark any earned title as a favourite using the new star button in the detail panel. Favourited titles are pinned to the top of the Collected group in "Collected First" sort mode and display with a star prefix in the title list. A new "Favourites Only" filter in the sidebar lets you view just your starred titles.
- **About modal** — A new info button in the title bar opens an about overlay showing addon and author information.
- **Rarity info popup** — A `?` button in the rarity card opens a small popup explaining how rarity percentages are estimated.
- **Faction badges on list rows** — Alliance and Horde faction badges now appear as small overlay icons on the rarity gem in the title list, matching the tint scheme used in the detail panel (gold for Alliance, red for Horde).
- **Dev scripts** — Added `link-release.ps1`, `link-ptr.ps1`, `unlink-release.ps1`, and `unlink-ptr.ps1` PowerShell scripts for symlinking dist packages into WoW for independent local testing before a CurseForge push.

### Changed

- **Faction icons** — Replaced the old placeholder faction icons (which carried attribution requirements) with new custom cutout versions. Alliance is tinted gold; Horde is tinted red.
- **Title list meta row** — Each row in the title list now shows a third line with expansion and category (e.g. "The War Within · PvP Rank"), making it easier to scan the list without opening the detail panel.
- **Source card descriptions** — The detail panel source card now shows richer contextual descriptions for achievement-, quest-, and item-sourced titles, and the obtainability reason is displayed below the unobtainable/feat-of-strength banner when present.
- **Sort: favourites bubble up** — Within the earned group in "Collected First" sort mode, favourited titles are sorted above non-favourited ones.

---

## [1.0.0] [1.0.1] - Initial Release

### Added

- Initial project setup and structure
