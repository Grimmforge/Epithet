-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) Grimmsforge

local _, ns = ...

ns.WhatsNewContent = ns.WhatsNewContent or { versions = {} }

-- title/body may be a plain string or a table keyed by locale
-- (e.g. { enUS = [[...]], ruRU = [[...]] }). WhatsNew:LocalizeField resolves the
-- active locale and falls back to enUS, so adding a translation is purely
-- additive: drop a ruRU key alongside enUS below.
ns.WhatsNewContent.versions["1.2.0"] = {
    hasNew = true,
    title = { enUS = "Epithet 1.2.0" },
    body = {
        enUS = [[
                    # Epithet 1.2.0

                    ## You're being watched (in a nice way, I guess?)

                    Every title-bearer you walk past (and click on) now gets quietly stored away on record. Who had it, where you spotted them, and whether it's the first time you've seen it in the wild. Epithet's Spotting log remembers all of it, so you can finally prove you saw someone rocking "the Insane" before it was cool, well technically not, given when this feature's being released, but you get the drift.

                    * First spotted, last spotted, and how many times you've clocked it since.
                    * Where you saw it, who was wearing it, and what class and rarity it is.
                    * Oddly, not necessary details of what class and race you first saw wearing it, totally necessary.
                    * Bump into the same title again later and the count just ticks up in the background, quietly. No judgement. Okay, some judgement.


                    ![Title spotted](Interface\AddOns\Epithet\WhatsNew\Versions\v1_2_0\title-spotting.png =460x230)

                    ## 76 achievements for a hobby you didn't know you had

                    Staring at strangers' names now pays off. Open the new **Achievements** tab from the Logbook for a proper tile grid you can click through, complete with progress indicators and earn dates - and a healthy pile of secrets that stay hidden until you stumble into them.

                    Three ways to earn your reputation as a title menace:

                    * **Spotting (account-wide):** for the committed people-watcher. Chase down **Roll Call**, **Full Spectrum**, **Grand Tour**, and the increasingly concerning **Personal Space Is a Myth**.
                    * **Collection (per-character):** for showing off what you actually own, from **First of My Name** to the fully-decked-out **Dressed for Every Occasion**.
                    * **Crossovers (per-character):** the petty ones. **Takes One to Know One** and **Window Shopper** only unlock once your own collection and your spotting habit start talking to each other.

                    Earn one and a popup lets you know!

                    ## Tip

                    Missed all this? Use /epithet whatsnew to bring this window back any time.

                    ![Epithet](Interface\AddOns\Epithet\icons\logo\epithet-wax-seal-red-mark-64)
                ]]
    },
}
