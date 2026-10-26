# Changelog

## 2.1.0
- Remaining time is shown on buff and debuff icons (seconds, minutes above 60 s, red in the last
  5 s); option 'Remaining time on buff / debuff icons' with a threshold (default: below 60 s)
- Debuff filter is now a mode: 'Important only' (new default: dispellable, crowd control, silences,
  roots, disarms, healing reduction, dispel traps, raid debuffs, whitelist), 'Only dispellable' or
  'Everything'. Existing profiles keep their behaviour ('only dispellable' stays, otherwise important)
- Buff filter is now a mode: 'Important + my own' (new default: externals, shields, HoTs, immunities
  and big offensive cooldowns from anyone plus your own short buffs), 'All short buffs' (old
  behaviour, honours 'Only my buffs') or 'Whitelist only'

## 2.0.7
- Frames redraw completely when the player behind a unit token changes (role sort, group moves,
  two players trading places) - previously the old occupant's health, auras and cooldowns could linger
- Party frames inside a raid follow changes of my own subgroup
- Vehicle swap now really shows the vehicle's health and power (name, auras and cooldowns stay the
  member's); clicks already went to the vehicle
- Clique: frames are only handed to Clique while 'Let Clique handle clicks' is on, so the built-in
  bindings win when it is off
- Test mode: corner indicators of the preview no longer vanish after a few seconds
- Movers follow the profile's lock state after a profile switch, reset or import
- Moving the raid frames while the raid preview is shown re-anchors the preview
- 'Page defaults' also applies settings with their own apply step (e.g. the minimap button)

## 2.0.6
- Error handler: no more error cascades when Blizzard's own error window throws (3.3.5 'cursorOffset'
  bug); errors are attributed to the addon correctly
- Inspection: results are only used when they belong to the unit we asked for (other addons such as
  LibGroupTalents in Details! inspect too), ClearInspectPlayer() is no longer called, retries are capped
- Cooldown reset only on a real transition into an arena / battleground (not on /reload or option clicks)
- Cold Snap also resets Frost Nova for the learning logic
- Opening the Indicators page no longer writes one class's defaults into the shared profile
- Click-casting editor no longer sticks out of the page
- Deleting a profile clears automatic mappings that pointed to it; 'Page defaults' on the Profiles page
  re-evaluates the automatic profile
- Announcements use the battleground channel inside battlegrounds

## 2.0.5
- Cooldowns have an importance level; new option 'Show spells' (essential only / essential + useful /
  everything), default essential + useful, arena preset essential only. Icons are sorted by importance.
- Party cooldowns options page no longer overflows

## 2.0.4
- Arena and battleground: tracked cooldowns are reset when a new match is entered (preparation buff)

## 2.0.3
- Built-in Lua error log (`/rpf errors`, saved with the settings) for bug reports

## 2.0.2
- Automatic profiles: group types without a mapping (and switching the automatic off) return to the
  profile you picked yourself instead of keeping the last automatic one
- Presets take over positions, scale, solo frame and lock state from your current profile
- One-time repair of profiles created by 2.0.1

## 2.0.1
- Built-in presets "PvP - Arena" and "PvE - Raid": created as profiles on first start and mapped to
  arenas / raids automatically; re-creatable from the Profiles page

## 2.0.0
- Raid frames: group blocks or one sorted block, columns/rows, group labels, separate raid style
  settings, raid pets, main tank / main assist frames, 25-man preview
- Party pets
- Profiles per character, automatic switching by group type (solo / party / raid 10 / 25 / 40 /
  arena / battleground), export / import, reset / copy / delete; 1.x settings migrate automatically
- Built-in click-casting (spell, macro, target, menu, focus, assist) with Clique detection
- Corner indicators for own HoTs / shields with timers and stacks, per-class defaults, editable
- Priority debuffs (ICC / ToC / Ulduar / Naxxramas), debuff blacklist / whitelist, buff whitelist,
  dispel sound
- Health color modes (class / gradient / custom), low health highlight, border color, font outline,
  name length, level, status text size, frame alpha, out-of-combat fading
- Range check by spell, focus highlight, "Res" incoming, AFK / DND, vehicle swap
- Arena target counter, PvP trinket first; battleground flag carrier icon
- Minimap button, key bindings, optional cooldown / dispel announcements, tooltip modes
- Raid-wide cooldown tracking, test mode cycles party / raid / off
- Options window reorganised into 15 pages

## 1.2.x
- Own options window with sidebar, Support page, Interface > AddOns launcher, layout fixes

## 1.1.x
- Talent and glyph inspection for party members, spell editor, startup error reporting,
  `/rpf debug`

## 1.0.x
- Party frames in retail raid frame style, in-frame cast bars, party cooldowns from the combat
  log, dispel highlighting
