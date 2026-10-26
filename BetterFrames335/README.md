# BetterFrames 335

Better default Blizzard unit frames for **WoW 3.3.5a** (Interface 30300, e.g. Warmane).
Original implementation inspired by the feature set of BetterBlizzFrames — no code from it is used.

## Install
Copy the `BetterFrames335` folder to `World of Warcraft/Interface/AddOns/`, then type `/bbf` in game.

## Features (v2)
- **Unit frames:** class colored health bars (pets after owner, shamans blue, NPC reaction colors), class colored names / name background / level text, hide realm names, "Arena 1-5" names, class icon portraits, player elite art, mini focus frame, per-frame scale (player, target, focus, pet, ToT, party), clickthrough frames
- **Frame parts:** hide mana bars / names / level text / ToT / ToT debuffs, ToT offsets, status text format (short numbers, percent, current only ...), smooth bars
- **Textures & fonts:** statusbar texture for health / mana / castbars / XP bar (built-in or custom path), unit frame fonts (built-in or custom, outline, sizes)
- **Auras (target & focus):** buffs/debuffs per frame, max counts, only mine, no permanent, under one minute, whitelist mode, blacklist/whitelist/important lists, sizes, gaps, offsets, per row, sorting (important / purgeable / mine first), purge glow, important glow, refresh glow, DoT border, spell ID tooltips, clickthrough auras, Shift+Alt / Ctrl+Alt click to edit lists
- **Player auras:** buff & debuff filters (blacklist, whitelist mode, under one minute), custom size / per row / gaps, cooldown spiral, hide duration text, stack font size
- **Castbars:** party castbars (attached or free stack), self bar, pet castbar, per-castbar customization for player/target/focus (size, icon, border, text, timer), detach target/focus castbar, cast timers, textures
- **Interrupts:** kick window highlight on target/focus castbars, enemy interrupt cooldown icon (combat log tracked), green castbar while their interrupt is down
- **Indicators:** combat (in/out, enemies/players/arena only), absorb shield with duration and estimated amount, racial indicator (Human / Night Elf / Orc / Undead), stealth indicator
- **Hide:** gryphons, PvP/leader icons, group number, damage text, rest/combat glow, pet frame, arena frames, stance / pet bar, bag & chat buttons, minimap buttons & clock, UI errors; situational: minimap / tracker / party frames in arena, boss frames in party / raid
- **Misc:** minimap button (left: options, right: move mode, shift: castbar test), chat filters (emotes, system, talent spam, arena NPC talk), battleground / arena queue timer with pop sound
- **Move frames:** `/bbf move` shows drag boxes over Player, Target, Focus, Pet, Party, Castbar, Buffs, Minimap, Boss, Arena, party castbars, queue timer, detached castbars; right-click a box resets it
- **Profiles:** per character profiles, copy, delete, export / import string
- **Presets:** "PvP - Arena" and "PvE - Raid" one-click setups (General / Profiles tab or `/bbf preset arena|raid`); aura lists and positions are kept

## Commands
- `/bbf` — open the options window (also: Esc > Interface > AddOns > BetterFrames 335 > "Open options window")
- `/bbf move` — toggle frame move mode
- `/bbf test` — castbar test mode
- `/bbf bl|wl|imp add|del|list <name or spellID>` — edit lists
- `/bbf profile <name>` — switch / create a profile
- `/bbf preset arena|raid` — apply a preset to the current profile
- `/bbf cpu` — CPU usage per addon (needs `/console scriptProfile 1` + reload)
- `/bbf reset` — reset the current profile

## Notes
- 3.3.5 has no API for absorb amounts — the shown amount is the spell's base value minus absorbed damage seen in the combat log (estimate).
- Interrupt cooldowns are tracked from the combat log with base cooldowns (talents not included).
- Not possible on 3.3.5: overshields, quest indicator, castbar target text, Loss of Control frame, class resources.

## Support
If you like the addon you can send a few Warmane coins to **Samyd** on **Blackrock**: https://www.warmane.com/account/services (in game: /bbf > "Buy me a coffee").
