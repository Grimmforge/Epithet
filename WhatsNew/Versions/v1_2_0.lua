-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) Grimmforge

local _, ns = ...

ns.WhatsNewContent = ns.WhatsNewContent or { versions = {} }

ns.WhatsNewContent.versions["1.2.0"] = {
    hasNew = true,
    title = "Epithet 1.2.0",
    body = [[
# Epithet 1.2.0

## Highlights

**Title Spotting** and **Meta Achievements** are now fully integrated.

* The Spotting log records first seen and last seen data for each distinct title.
* Entries keep first spotter, first zone, title type, rarity, and class context when available.
* Repeat sightings now build history with per-title sighting counts.

## Meta Achievements

**Epithet Achievements** now has a dedicated modal with a responsive tile grid.

* Achievement tiles are icon-forward and use per-achievement WoW icon mappings.
* Secret achievements use masked visuals until revealed.
* Clicking an achievement tile opens a detail overlay with progress and earn details.

Achievement groups now include:

* **Spotting (account-wide):** progression and exploration goals like *First Sighting*, *Roll Call*, *Full Spectrum*, and *Grand Tour*.
* **Collection (per-character):** ownership milestones such as *First of My Name*, *Peerage*, and *Dressed for Every Occasion*.
* **Crossovers (per-character):** relationship checks between spotting history and owned titles, including *Takes One to Know One* and *Window Shopper*.

## Spotting and Crossovers

Crossover checks now use more reliable ownership timing data when available.

## Tip

Use /epithet whatsnew to open this window again.

![Epithet](Interface\AddOns\Epithet\icons\logo\epithet-wax-seal-red-mark-64)
]],
}
