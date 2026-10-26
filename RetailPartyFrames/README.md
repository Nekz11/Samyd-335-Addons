# RetailPartyFrames (WotLK 3.3.5a / Warmane)

Party and raid frames in the style of the retail raid frames - with cast bars inside the frames,
party cooldown tracking (OmniCD style, with talent inspection), dispel highlighting, Grid-style
corner indicators, built-in click-casting and profiles. No libraries required.

## Installation
1. Copy the `RetailPartyFrames` folder into `World of Warcraft\Interface\AddOns\`
   (the folder name must be exactly `RetailPartyFrames`).
2. Enable it in the AddOns list on the character selection screen.
3. In game: `/rpf` opens the options window, `/rpf test` shows a party preview, `/rpf test` again a
   25-man raid preview, a third time turns the preview off.

Updating from 1.x: your settings are migrated into the profile "Default" automatically.

## Commands
- `/rpf` - options window (also via Interface > AddOns > RetailPartyFrames or the minimap button)
- `/rpf move` - unlock the frames to drag them (right-click a blue area to lock again)
- `/rpf test [party|raid|off]` - preview without a group (turns itself off when combat starts)
- `/rpf reset` - reset all positions
- `/rpf profile [name]` - show or switch the profile
- `/rpf export` - open the profile export
- `/rpf inspect` - re-read talents and glyphs of the group
- `/rpf minimap` - toggle the minimap button
- `/rpf debug` - print the frame state to chat (for bug reports)

Key bindings (options window, test mode, lock) are in the game's Key Bindings menu.

## What it does

### Party frames
- Player + up to 4 members, sorted by role / group / class / name, vertical or horizontal
- Party pets next to their owner (optional)
- Used in dungeons, arenas and - if you want - for your own group inside raids

### Raid frames
- 10 to 40 players as one block per raid group or one sorted block (by group, class or main
  tank / assist), columns or rows, groups per line, group labels
- Separate size, font size, power bar, health text, cast bar, cooldown and aura settings for raid
  frames ("Raid style" page)
- Raid pets block, main tank / main assist frames (own movable block)
- 25-man preview without a raid (`/rpf test` twice)

### Everywhere
- Class colors or a green-to-red gradient or one custom color, low health highlight, border color,
  textures and fonts (LibSharedMedia is picked up when present), font outline, name length, level
- Role, leader / assistant and raid target icons, ready check, aggro border, target and focus
  highlight, out-of-range fading (by UnitInRange or by a spell's range), AFK / DND text,
  "Res" on dead players who are being resurrected, vehicle swap, out-of-combat fading
- Optional incoming heals (needs LibHealComm-4.0 from another addon)

### Buffs & debuffs
- Debuffs you can dispel come first; the frame gets a border and glow in the debuff color and small
  dispel type icons; optional sound when you can dispel something
- Priority debuffs (ICC, ToC, Ulduar, Naxxramas encounter debuffs) are shown larger and first;
  debuff blacklist / whitelist and buff whitelist with spell ids
- Buffs: like retail only your own HoTs and shields (Earth Shield, Beacon of Light etc. always)

### Indicators
- Small colored squares in the frame corners for your own HoTs and shields with remaining time and
  stacks (Grid style). Class defaults for priests, druids, paladins and shamans; every corner is
  editable with spell ids

### Cast bars
- Cast bar strip inside each frame: yellow = cast, green = channel, grey = not interruptible,
  red = interrupted

### Party cooldowns
- Read from the combat log - nobody else needs the addon: interrupts, personal and external
  defensives, raid cooldowns, crowd control, utility, offensive cooldowns, racials, PvP trinket
- Talent inspection like OmniCD: party members within 28 yards are inspected, so talent abilities
  show up right away and cooldown reductions from talents and glyphs are applied; dual-spec switches
  are picked up; shortened cooldowns are also learned from usage
- Spell editor: add spells, override cooldowns, hide spells (Shift + right-click an icon)
- Arena: the PvP trinket is shown first

### Arena & battleground
- Arena: a number on each frame shows how many enemies target that player (red from 2 on)
- Battleground: flag carrier icon on the frame
- Profiles can switch automatically for solo / party / raid 10 / 25 / 40 / arena / battleground

### Click-casting
- Bind spells, macro text, target, unit menu, focus or assist to mouse buttons with Shift / Ctrl /
  Alt. Clique takes over automatically when it is loaded (can be turned off)

### Profiles
- Any number of profiles, per character, copy / reset / delete, automatic switching by group type,
  export and import as text
- Presets "PvP - Arena" (big team frames, percent, mana, cast bars, trinket + defensives, enemy
  target counter) and "PvE - Raid" (compact raid blocks, health deficit, priority debuffs, dispel
  sound, main tanks). They are created on first start and switch on automatically in arenas and
  raids; "Default" stays your dungeon / party profile. Turn the automatic switch off on the Profiles
  page if you prefer one profile everywhere.

### Extras
- Minimap button (left: options, Shift+left: test mode, right: lock)
- Optional announcements of used cooldowns and your own dispels (off by default)

## Notes
- Blizzard party frames are hidden (option). After unchecking it, `/reload` brings them back.
- Cooldown durations are base values; inspection and usage adjust them.
- Raid cooldown tracking works for the whole raid; inspection covers the party (5 players).
- Everything that touches the frames is deferred while you are in combat and applied afterwards.
