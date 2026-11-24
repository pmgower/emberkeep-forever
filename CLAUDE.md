# Kinfolk: Forever

WoW Forever addon: a home base for all your alts. A roster of every character, switchable
focuses on it (the first: which alt to play next for rested XP), and later each alt's gear, bags,
bank and mail.
Domain terms are in CONTEXT.md. The plan and slice list are in docs/KICKOFF.md.

## Facts the code can't show
- Game client: WoW Forever, `## Interface: 16001` (check in game: `/dump select(4, GetBuildInfo())`).
  It is a modern client, not 1.12: `C_Container`, `C_Bank` tabs, `C_Traits`, `issecretvalue`.
- Verify Classic facts against Forever sources before relying on them. Alts Forever's source
  (github.com/KadmaiDev/AltsForever) notes which APIs its author checked in game.
- Bank data is only readable while the bank is open; mail only at the mailbox. XP max reads 0
  during logout. Never let an empty read overwrite a saved snapshot.

## How work is checked
- `scripts/check.sh` is the gate: luacheck, Core purity (no WoW globals in `Kinfolk/Core`),
  StyLua, busted, TOC check. Hooks in `.claude/settings.json` run it on Stop and TaskCompleted
  and lint each edited file; CI runs the same script.
- Deny rules cover secrets, the game's `WTF/` folder, force pushes and tag pushes.

## Git
- Atomic commits whose message says why. One slice per PR. Rebase only, never merge commits.
- No AI attribution in commits or PRs.
- Releases: a `v*` tag runs the packager to CurseForge. Only Paul tags, from his PC.
- Installs for in-game testing copy `Kinfolk/` into
  `D:\Blizzard Games\World of Warcraft\_forever_\Interface\AddOns\`, then `/reload`.
