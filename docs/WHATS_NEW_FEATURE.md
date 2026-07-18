# Epithet What’s New Feature

## Overview

The What’s New feature shows a themed, centered popup after login when a given addon version has unseen update content.

It is designed to:

- Show once per version by default
- Be controlled by per-version flags in SavedVariables
- Load content from packaged version files
- Render simple markdown-like content with headings, emphasis, and images

## File layout

Core runtime:

- Core/WhatsNew.lua

Content registry:

- WhatsNew/Content.lua

Per-version content:

- WhatsNew/versions/v1_1_1.lua

Addon packaging/load order:

- Epithet.toc

## How content is mapped to versions

Each version file registers an entry in ns.WhatsNewContent.versions.

Example shape:

- key: 1.1.1
- fields:
  - hasNew: boolean
  - title: popup title text
  - body: markdown-like multiline string

The runtime reads the current addon version from metadata and looks up a matching entry in ns.WhatsNewContent.versions.

## Display logic

The popup is shown only when all conditions below are true:

1. There is content for the current version
2. firstRun is true for that version
3. hasNew is true for that version

There is also session protection to avoid duplicate popups from repeated PLAYER_ENTERING_WORLD event firing.

## SavedVariables model

Stored under EpithetDB.whatsNew.

Shape:

- byVersion
  - [version]
    - firstRun: boolean
    - hasNew: boolean

Behavior:

- On first encounter of a version, defaults are initialized
- Closing the popup sets firstRun to false and hasNew to false for current version

## Popup behavior

- Appears centered on screen after login delay
- Uses Epithet-style visuals and button skinning
- Is dismissible via close control or close button
- Can be reopened manually with slash command:
  - /epithet whatsnew

## Content format support

The body renderer supports these patterns per line:

- '# Heading 1'
- '## Heading 2'
- Plain paragraph lines
- Inline bold using double stars
- Inline italics using single stars
- Image line using markdown image syntax:
  - ![alt](texturePath)

Notes:

- Rendering is converted into SimpleHTML tags
- Image lines are rendered through WoW texture tag output

## Rendering implementation notes

The feature uses a SimpleHTML widget.

Important API constraints for SimpleHTML in WoW:

- SetJustifyH requires textType and justification
- SetJustifyV requires textType and justification
- SetSpacing requires textType and spacing
- SetFont requires textType, font file, size, and flags

This is stricter than normal FontString APIs and is a common source of runtime regressions.

## Height calculation and client compatibility

Some clients do not expose GetStringHeight on SimpleHTML.

To remain stable:

- Runtime attempts GetStringHeight only when method exists
- If unavailable or non-positive, a deterministic estimator computes body height from source lines

This prevents nil-call errors and keeps scroll sizing usable across client variants.

## How to add a new release entry

1. Create a new file in WhatsNew/versions, for example v1_1_2.lua
2. Register ns.WhatsNewContent.versions[1.1.2] with title, body, and hasNew
3. Add the new file to Epithet.toc under the What’s New content section
4. Bump addon version metadata in Epithet.toc

## Operational notes

- If hasNew is false, popup will not auto-show even on first run
- Reopen command bypasses auto-show gating and displays current version content directly
- Clearing EpithetDB.whatsNew.byVersion forces the system to treat versions as unseen again

## Troubleshooting checklist

If popup does not appear:

- Confirm current addon version has a matching entry in ns.WhatsNewContent.versions
- Confirm the version file is listed in Epithet.toc
- Confirm EpithetDB.whatsNew.byVersion[currentVersion].firstRun is true
- Confirm EpithetDB.whatsNew.byVersion[currentVersion].hasNew is true

If popup errors at runtime:

- Re-check SimpleHTML API calls use textType arguments
- Ensure SetFont includes a flags argument
- Ensure height path handles clients without GetStringHeight

If content appears blank:

- Validate body text in the version file is non-empty
- Validate image texture paths resolve in-game
