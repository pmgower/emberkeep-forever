# CurseForge listing: copy and paste

Paste everything below the "Description" line into the project's **Description** field (CurseForge accepts Markdown).

**Logo:** `curseforge/emberkeep-logo.png` (400x400).

**Screenshots (gallery order).** Take them on a character below max level with at least three alts
seen, in the default Frost Steel scheme, with UI scale and window scale at 100%. Files marked
*0.5.0* were retaken for 0.5.0; the rest still match.

1. **Rested tab** *(0.5.0)*: alts in an inn, outside and in a sleeping bag, with the Bag buff
   column. File: `emberkeep-rested-screenshot-001.png`
2. **Row tooltip** *(0.5.0)*: a sleeping-bag alt, with Rested, Well Rested, the Sleeping bag buff
   and Last zone (sleeping bag). File: `emberkeep-tooltip-screenshot-001.png`
3. **Search tab** *(0.5.0)*: an item on two alts, with where each has it.
   File: `emberkeep-search-screenshot-001.png`
4. **Alt panel, Mail tab** *(0.5.0)*: mail to collect, soonest to expire first, beside Overview's
   Mail column. File: `emberkeep-mail-screenshot-001.png`
5. **Alt panel, Bank tab** *(0.5.0)*. File: `emberkeep-bank-screenshot-001.png`
6. **Alt panel, Gear tab** *(0.5.0)*. File: `emberkeep-gear-screenshot-001.png`
7. **Alt panel, Bags tab** *(0.5.0)*. File: `emberkeep-bags-screenshot-001.png`
8. **Overview tab** *(0.5.0)*: level, time played, gold, zone, last seen and Mail, plus the All
   characters total row. File: `emberkeep-overview-screenshot-001.png`
9. **Professions tab** *(0.5.0)*: every alt's skills, a column per profession.
   File: `emberkeep-professions-screenshot-001.png`
10. **Minimap button tooltip:** "Play next" and the counts. File: `emberkeep-minimap-screenshot-001.png`
11. **Login line:** the chat line "Emberkeep: play next … (N% rested)" right after logging in.
    File: `emberkeep-login-hint-screenshot-001.png`
12. **Options page** *(0.5.0)*: Esc > Options > AddOns > Emberkeep, with every option.
    File: `emberkeep-options-screenshot-001.png`
13. **Characters page:** the table and Remove buttons. File: `emberkeep-characters-screenshot-001.png`
14. **Character window button.** File: `emberkeep-character-button-screenshot-001.png`
15. **Right-click menu:** Remove on an alt's row. File: `emberkeep-remove-menu-screenshot-002.png`
16. **Bug report window:** `/emberkeep feedback`. File: `emberkeep-feedback-screenshot-002.png`
17. **Optional: color schemes.** File: `emberkeep-themes-screenshot-001.png`

**Project name:** Emberkeep: Forever

**Summary (one line):** A home base for your alts in WoW Forever: who to play next for rested XP, every alt's gear, bags, bank and mail, and search across all of them.

**Categories:** Miscellaneous (main), Data Export, Chat & Communication. Pick the closest CurseForge offers; "Alts" isn't a category.

**License:** MIT (set in the project settings; the description doesn't mention it)

**Game version:** Forever (1.60.1)

---

## Description

# Emberkeep: Forever

**A home base for all your alts.** Emberkeep keeps track of every character you play, so you can see your whole roster at a glance, whether they're levelling or already at the cap. It covers rested XP, an overview of every alt, their professions, and each alt's gear, bags, bank and mail, with a search across all of them.

**Always know which alt to play next.** Rested XP builds up while you're logged out, but it stops at 150% of a level. Past that, it's wasted. Emberkeep remembers every character you log in on and works out where each one's rested XP is right now. It tells you who to play next and which alts are already full.

It's a small, read-only helper. It never changes your characters, gold or items, and it doesn't talk to other players.

## What you get

* **Rested tab**: your levelling alts ranked by who to play next.
  * **Order:** full alts first (alphabetically), then by how full they are.
  * **Bars:** each alt has one, coloured blue when full and rested XP is going to waste, green when filling in an inn, and orange when filling outside.
  * **Full in:** time until each alt is full.
  * **Well Rested:** each alt's rank in the Legacy perk, with what it does in the tooltip.
  * **Zone:** where each alt logged out, next to whether they're in an inn, outside or in a **Cozy Sleeping Bag**.
  * **Bag buff:** each alt's sleeping bag XP buff (+1% to +3%) and how long it had left when they logged out.
  * Max-level alts are left out.
* **Search tab**: find any item on any alt as you type, with how many each one has and where: bags, bank, mail or worn.
  * **Search words** like Baganator's: `linen`, `#epic`, `#bank`, `#gear & >30`, `linen & !#bags`. The empty search box lists them all.
  * Click an alt to open their panel where the item is. Nothing is printed to chat.
* **Professions tab**: every alt's profession skills side by side, with a column for each profession, Cooking, Fishing and First Aid included. Gray titles show the ones none of your alts have; click a title to sort.
* **Overview tab**: every character with level, time played, gold, zone and when you last played them, plus your **total gold** and **total time played** across all of them. A **Mail** column shows how soon each alt's mail expires.
* **Alt panel**: click an alt to see their gear, bags, bank and mail beside the window, without logging in on them.
  * **Gear:** item names, item levels and tooltips, in two columns or a list. Empty slots and outleveled items are marked.
  * **Bags:** every item with its count, and how many slots are free.
  * **Bank:** everything in their bank, bank tabs included. Open the bank once on each alt to save it.
  * **Mail:** mail with items or gold to collect, soonest to expire first, with whether it then goes back or is deleted. Mail you send (or send back) to an alt shows straight away.
  * **Up** and **Down** step through your alts. Shift-click an item to link it in chat.
* **Row tooltips**: rested %, when it fills (or how long it has been full), your Well Rested rank, the sleeping bag buff, time played, and where you logged out, down to the inn or city district.
* **Character window button**: opens the panel from the game's own Character window.
* **Minimap button**: hover for "Play next" and a count of full alts. Left-click toggles the window and right-click opens the options.
* **Login reminder**: one chat line when you log in, naming who to play next. You can turn it off.
* **Mail warning**: a chat line at login for any alt whose mail expires within 3 days, so nothing is deleted by surprise. You can turn it off.
* **Full Forever names**: "Jango Fett" everywhere, or first names only if you prefer.
* **Themed window**: resizable, movable, and closes with Esc. Four color schemes and a scale slider.
* **Characters page**: Options > AddOns > Emberkeep > Characters lists every saved alt with a **Remove** button, for alts you've deleted. You can also right-click an alt's row in the window.
* **Easy bug reports**: `/emberkeep feedback` (or ctrl-click the minimap button) gives you a link to a bug report form with the details filled in. No character names are included.

## How it works

1. **Log in on each alt once.** Emberkeep saves its level, gold, zone, rested XP, gear, bags and professions. Open the bank and a mailbox once on each to save those too: they can only be read there.
2. **Play as normal.** It updates as you level, earn gold and walk in and out of inns.
3. **Open `/emberkeep`** (or click the minimap button) to see who's full and who to play next.

Rested XP is only readable on the character you're logged in on. For your other alts, Emberkeep works it out from their last reading: 5% of a level per 8 hours in an inn, a quarter of that elsewhere, up to 150%. It includes each alt's own rank in the Legacy **Well Rested** perk, which adds 4% to the rate and the cap per rank.

## Commands

| Command | What it does |
| --- | --- |
| `/emberkeep` | Show or hide the window |
| `/emberkeep search <text>` | Open the Search tab, already searching for that |
| `/emberkeep options` | Open the options page |
| `/emberkeep remove <name>` | Remove a character you deleted (also Options > AddOns > Emberkeep > Characters, or right-click their row) |
| `/emberkeep reset` | Put the window back in the middle of the screen |
| `/emberkeep version` | Show the version |
| `/emberkeep feedback` | Report a bug: a link to a bug report form with your details filled in (also ctrl-click the minimap button) |
| `/emberkeep debug` | Print what Emberkeep sees, for bug reports |

## Coming next

Emberkeep is built around "focuses", one tab per question you ask about your alts. Rested, Overview, Professions and Search so far. Next up:

* **Max-level focuses**: things to track once your alts hit the cap.

Tell us what you'd like next in the comments.

## Please help verify

One rested number isn't confirmed in WoW Forever yet: the rate away from an inn. If an alt's "Full in" is off when you log back in, please tell us in the comments.

## Credits

The minimap button uses LibDBIcon and LibDataBroker.
