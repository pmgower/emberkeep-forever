# CurseForge listing: copy and paste

Written for the rename from Kinfolk to **Emberkeep**. The 0.1.0 screenshots still show "Kinfolk" in the title bar, so retake them with the next release. Paste everything below the "Description" line into the
project's **Description** field (CurseForge accepts Markdown).

**Logo:** `curseforge/emberkeep-logo.png` (400x400).

**Screenshots (gallery order).** Take them on a character below max level with at least three alts
seen, in the default Frost Steel scheme, with UI scale and window scale at 100%:

1. **Rested tab:** `/emberkeep` with three or more alts listed. Ideally one is full (blue bar), one is
   filling in an inn (green) and one is outside (orange). File: `emberkeep-rested-screenshot-001.png`
2. **Row tooltip:** hover the top row (a full alt) so the tooltip shows Rested, Full for, Well
   Rested, Last zone (inn) and "play … next". File: `emberkeep-tooltip-screenshot-001.png`
3. **Overview tab:** every alt with level, gold, zone and last seen, plus the All characters total row.
   File: `emberkeep-overview-screenshot-001.png`
4. **Minimap button tooltip:** hover the keep tower button to show "Play next" and the counts.
   File: `emberkeep-minimap-screenshot-001.png`
5. **Login line:** the chat line "Emberkeep: play next … (N% rested)" right after logging in.
   Crop to the chat box. File: `emberkeep-login-hint-screenshot-001.png`
6. **Options page:** Esc > Options > AddOns > Emberkeep, showing every option.
   File: `emberkeep-options-screenshot-001.png`
7. **Optional: color schemes.** The window in Deepwater or Twilight next to Frost Steel.
   File: `emberkeep-themes-screenshot-001.png`

**Project name:** Emberkeep: Forever

**Summary (one line):** A home base for your alts in WoW Forever: who to play next for rested XP, plus every alt's level, gold and whereabouts.

**Categories:** Miscellaneous (main), Data Export, Chat & Communication. Pick the closest CurseForge offers; "Alts" isn't a category.

**License:** MIT

**Game version:** Forever (1.60.1)

---

## Description

# Emberkeep: Forever

*Formerly Kinfolk: Forever. After updating, log in on each alt once to fill your list again.*

**Always know which alt to play next.** Rested XP builds up while you're logged out, but it stops at 150% of a level. Past that, it's wasted. Emberkeep remembers every character you log in on and works out where each one's rested XP is right now. It tells you who to play next and which alts are already full.

It's a small, read-only helper. It never changes your characters, gold or items, and it doesn't talk to other players.

## What you get

* **Rested tab**: your levelling alts ranked by who to play next.
  * **Order:** full alts first (alphabetically), then by how full they are.
  * **Bars:** each alt has one, coloured blue when full and rested XP is going to waste, green when filling in an inn, and orange when filling outside.
  * **Full in:** time until each alt is full.
  * Max-level alts are left out.
* **Overview tab**: every character with level, gold, zone and when you last played them, plus your **total gold** across all of them.
* **Row tooltips**: rested %, when it fills (or how long it has been full), your Well Rested rank, and where you logged out.
* **Minimap button**: hover for "Play next" and a count of full alts. Left-click toggles the window and right-click opens the options.
* **Login reminder**: one chat line when you log in, naming who to play next. You can turn it off.
* **Full Forever names**: "Jango Fett" everywhere, or first names only if you prefer.
* **Themed window**: resizable, movable, and closes with Esc. Four color schemes and a scale slider.
* **Easy bug reports**: `/emberkeep feedback` (or ctrl-click the minimap button) gives you a link to a GitHub bug report with the details filled in. No character names are included.

## How it works

1. **Log in on each alt once.** Emberkeep saves its level, gold, zone and rested XP.
2. **Play as normal.** It updates as you level, earn gold and walk in and out of inns.
3. **Open `/emberkeep`** (or click the minimap button) to see who's full and who to play next.

Rested XP is only readable on the character you're logged in on. For your other alts, Emberkeep works it out from their last reading: 5% of a level per 8 hours in an inn, a quarter of that elsewhere, up to 150%. It includes the Legacy **Well Rested** perk, which adds 4% to the rate and the cap per rank.

## Commands

| Command | What it does |
| --- | --- |
| `/emberkeep` | Show or hide the window |
| `/emberkeep options` | Open the options page |
| `/emberkeep forget <name>` | Remove a character you deleted |
| `/emberkeep reset` | Put the window back in the middle of the screen |
| `/emberkeep version` | Show the version |
| `/emberkeep feedback` | Report a bug: a link to a GitHub bug report with your details filled in (also ctrl-click the minimap button) |
| `/emberkeep debug` | Print what Emberkeep sees, for bug reports |

## Coming next

Emberkeep is built around "focuses", one tab per question you ask about your alts. Rested is the first. Next up:

* **Gear**: each alt's equipped items.
* **Bags, bank and mail**: find an item on any alt without logging in.
* **Max-level focuses**: things to track once your alts hit the cap.

Tell us what you'd like next in the comments or on GitHub.

## Please help verify

Two rested numbers aren't confirmed in WoW Forever yet: the rate away from an inn, and exactly how Well Rested raises the cap. If an alt's "Full in" is off when you log back in, please tell us in the comments or on GitHub.

## Source, issues and license

Open source under the MIT license: https://github.com/pmgower/emberkeep-forever

Minimap button uses LibDBIcon and LibDataBroker (public domain / BSD).
