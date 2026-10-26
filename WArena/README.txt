WArena 2.0 – PvP frames for WotLK 3.3.5a (Warmane)
====================================================

Install
-------
Copy the "WArena" folder to  World of Warcraft\Interface\AddOns\
The folder must be named exactly "WArena" and contain WArena.toc directly.
Updating from 1.x: your old settings are migrated into the "Default" profile automatically.
The old files Core.lua, Data.lua, Options.lua and LIESMICH.txt in the WArena folder are no
longer used and can be deleted.

Getting started
---------------
/warena              opens the options window (also: minimap button, Esc > Interface > AddOns > WArena)
/warena unlock       green boxes appear for everything that can be moved (frames, alerts, HUD,
                     battleground list, boss frames) – drag them, then /warena lock
Test frames, the battleground list preview and boss frame preview are shown automatically while the
options window is open, so every change is visible live.

Key bindings: Esc > Key Bindings > WArena – target / focus arena 1-5, target / focus the enemy healer,
toggle options, toggle test frames, lock/unlock.

What it does
------------
ARENA
- Enemy frames (arena1-5) with class icon, name, health, power, spec text, arena number badge,
  healer role icon, pet line (hunter/warlock/DK/mage pets)
- Left click = target, right click = focus, middle click configurable; yellow/blue border for
  target/focus; optional unit tooltips
- Healer always last (or first) – detected from spec (talent spells / buffs) or as the only healing
  class on the team; re-sorting happens out of combat
- Class icon shows the most important aura (immunities, CC, silences, defensives, roots, offensives),
  optional aura row with every tracked aura and timer
- PvP trinket + racial cooldowns (Will of the Forsaken also triggers the 45 s trinket cooldown),
  glow when the trinket is ready again
- DR tracker: stun, fear, disorient, scatter, horror, silence, root, cyclone, charm, disarm – every
  source counts, colors + optional ½ ¼ 0 text, configurable reset time
- Enemy cooldown tracker: interrupts, defensives, externals, offensives, CC, utility, big heals –
  from the combat log, glow while active, dimmed when ready, Cold Snap / Preparation / Readiness resets
- Cast bar (4 positions) with interruptible / channel / shielded / interrupted colors and
  "Interrupted: <name>"
- Indicators: "targeting you" marker, party target icons, enemy target text, range fade, drink icon
  with counter, stealth icon, low health overlay
- Announcements (chat / party / say / screen alerts + sounds): trinket used/ready, racial, drinking,
  low health, resurrect, spec detected, healer detected, enemy team overview, interrupts,
  "switched to you", flag carrier, Shadow Sight, gates
- Arena HUD: preparation countdown, match timer, Shadow Sight timer (90 s) with warning
- Match history (map, bracket, composition, duration, win/loss) and spec memory for known enemy names

BATTLEGROUND
- Enemy list from the scoreboard: class, spec/role, kills/deaths, health when known (target, focus,
  mouseover, party/raid targets), dead state, healers first, 1-3 columns
- Click a row to target (/targetexact), right click to focus; rows freeze in combat (secure frames)
- Flag carrier tracking (WSG / EotS) with announcement, friendly carrier in the header

PVE
- Boss frames (boss1-4) with the same engine: health, power, cast bar, boss target, "targeting you",
  party targets; Blizzard boss frames can be hidden

PRESETS
- PvP – Arena, PvP – Battleground, PvE – Raid: one click switches the modules for a play style
  (Themes & Presets page or /warena preset arena | bg | raid); the look is not changed

LOOK & FEEL
- Themes: Classic, Modern, Minimal, Gladius, Glass (own Glass/Smooth textures included)
- Every color via color picker (health, backgrounds, text, borders, cast bar states, DR levels,
  low health, alerts, HUD), border styles, outline/shadow, LibSharedMedia textures/fonts/sounds
- Profiles per character, copy / rename / delete, import & export as text string

Notes
-----
- 3.3.5 has no spec API for enemies: specs appear after the first talent spell or buff is seen.
- Base cooldowns are used for enemy cooldowns (talents and glyphs of enemies are invisible).
- Layout changes made in combat are applied when combat ends; nothing is changed on secure frames
  in combat.
- Everything is written from scratch; no code from sArena Reloaded or other arena addons.

Support the author
------------------
If you like WArena you can donate Warmane coins: https://www.warmane.com/account/services
Character: Samyd   Realm: Blackrock   (copy fields on the About tab / Interface > AddOns > WArena)
