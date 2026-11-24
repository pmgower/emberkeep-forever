# Kickoff brief: alt tracker addon Kinfolk: Forever

Goal: a WoW Forever home base for all my alts: one roster, each alt's gear, bags, bank and mail, and switchable focuses on top. The first focus is which alt to play next for rested XP; at max level other focuses (cooldowns, lockouts, gold, upgrades) take over. It's for me, and later for any Forever player with several alts.

## Domain terms (go into CONTEXT.md)

| Term | Meaning |
| --- | --- |
| Character | One alt, keyed `Name-Realm`, with class, faction, level, last seen |
| Rest observation | What the game reported at a moment: rested XP, XP to level, resting or not, Well Rested rank, time |
| Rest projection | Rested XP now, the cap and time to full, computed from the last observation (pure function) |
| Capped | Projected rested has reached the cap, so further rest is wasted |
| Play-next ranking | Alts below max level, capped first (longest capped first), then by rested as a share of the cap. **Assumption, tell me if you rank differently.** |
| Focus | One way of ranking or reading the roster, shown as a view. Each is its own module over the same roster (play next is the first; others are added later without touching the core). |
| Snapshot | Items in one location (Equipped, Bags, Bank, Mail) plus `observedAt` |
| Stale | A snapshot shown with "as of" because it can only be refreshed at the bank or mailbox |

Rates: 5% of a level per 8 h resting, 1/4 of that elsewhere (unverified on Forever), cap 150%, Well Rested +4% rate and +4% cap per rank (cap formula unverified). Details: the MVP proposal doc.

## What done looks like

1. On login, chat says which alt to play next, and `/kinfolk` opens the roster on its Play next focus: a Frost Steel window listing alts by that ranking with rested %, time to full, and a capped flag.
2. An alt left in an inn for a day projects within 1 percentage point of what the game shows when I log in on it.
3. I can open any alt's equipped gear, bags, bank and mail, with tooltips and shift-click links; bank and mail show "as of".
4. An empty read (logout XP = 0, closed bank) never wipes saved data.
5. Must not change: BagQuests and BagQuests_Alts keep working untouched, and no other addon's saved data is touched.

## Slices (one PR each, each usable in game)

| # | Slice | Pass/fail check |
| --- | --- | --- |
| 0 | Repo setup: CLAUDE.md, CONTEXT.md, deny rules, hooks (luacheck, StyLua, busted, TOC check; exit 2), CI running the same, release workflow. Addon loads and `/kinfolk` prints its version. | A deliberately broken test makes the hook exit 2 and CI fail. In game: `/reload`, no Lua errors, version prints. |
| 1 | Roster: save each character on login/logout, window lists name, class, level, last seen. | busted roster specs. In game: log in on 2 alts, both listed. |
| 2 | Play next (MVP): rest observation, projection, ranking, window columns, login chat line. | busted projection/ranking specs incl. cap, away rate, Well Rested, logout-zero guard. In game: ranking and rested % match the XP bar on the current alt. |
| 3 | Equipped gear panel per alt. | busted snapshot specs. In game: an alt's gear matches its character sheet. |
| 4 | Bags grid per alt with free slots. | busted specs. In game: bag counts match after looting. |
| 5 | Bank grid, captured on bank open, "as of" shown. | busted specs incl. closed-bank guard. In game: visit bank, log alt, view it from another alt. |
| 6 | Mail list, captured at mailbox plus items sent by your alts, expiry warning. | busted specs. In game: mail an item to an alt, it shows before they open the box. |

Each PR: real luacheck/StyLua/busted output, the adversarial review findings and fixes, and a 2-minute in-game checklist.

## Things that can't be undone

- Creating the GitHub repo and CurseForge project (you).
- Release tags / CurseForge uploads: only on your go, from your PC.
- Writing to the live `WTF/` folder: never. Installs only copy addon files into `Interface/AddOns`.

## Risk tier

All slices are addon-only Lua with no secrets, auth or data outside SavedVariables: tier "merge when green", your call. The release workflow in slice 0 touches CI secrets (CurseForge token), so that PR gets the higher tier: review plus your eyes before merge.
