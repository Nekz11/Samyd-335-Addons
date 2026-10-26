BetterPlates 2.0.2 - WoW 3.3.5a (Warmane)
Enhanced Blizzard nameplates for WotLK 3.3.5a, inspired by BetterBlizzPlates.
Author: Samyd @ Blackrock

INSTALL
1. Copy the folder "BetterPlates" into  <WoW folder>\Interface\AddOns\
   (result: ...\Interface\AddOns\BetterPlates\BetterPlates.toc)
2. Disable other nameplate addons (TidyPlates, Aloft, Kui, ElvUI nameplates ...).
3. Restart the client completely after installing or updating (new files).
4. In game: /bbp opens the settings window (16 pages, search box in the sidebar).
   Toggle nameplates as usual with V / Shift+V / Ctrl+V, or via the minimap button.
   Language: English; German on German clients.

FEATURES
General & style
- Own health bar: width/height, textures (incl. custom path), fonts (incl. custom path),
  border style (none/thin/thick/glow), background (dark/class-tinted/transparent)
- Health text: percent / value / value+percent / value÷max / missing, decimals, position,
  only on target; optional green-to-red health gradient on NPCs
- Names: inside the bar or above, max length, abbreviations (L. Marrowgar), realm strip,
  hide name, hide name while casting; level in difficulty color, elite "+", "??" bosses
- Target: white border, glow, arrows, scale, dim non-targets; focus orange; mouseover border
- Raid icon position/size, every element has X/Y offsets (Positions page)
- Color pickers for all bar, border, cast, threat, raid and PvP colors (right-click = reset)
- Quick setup presets "PvP Arena" and "PvE Raid" (complete setups incl. zone rules) plus
  6 design presets: Classic Blizzard, Clean Flat, Modern, PvP Big, Raid Minimal, Healer
- Stacking (own logic, spacing/max height, per zone type), minimap button, update rate

Friend & foe
- Green border on friendly players, smaller friendly plates, names only (always or in
  BG/arena), class icon instead of name, name color green/red, only group members,
  low-health flash on friends
- Trivial (grey) NPCs fade/small/hide, hide critters, Murloc mode

Indicators
- Class icons, healer marker (combat log), party pointer arrows, totem icons with timers,
  important totems/NPCs highlighted, small pets, execute marker (+ bar color)

Cast bars
- Blizzard data on your target, combat-log bars on every other plate with a known unit
- Icon side, timer formats, name length, emphasized casts (red, taller, optional sound),
  hidden casts, "Interrupted: Name" flash, interrupt icon with cooldown seconds

Auras
- Own debuffs, PvP CC/immunities/buffs by category, interrupt lockouts, my HoTs/buffs on
  friends, dispellable debuffs on group members (by your class), key auras (bigger),
  white-/blacklist, 1-2 rows, grow direction, stacks, pandemic coloring, only on target

Diminishing returns
- Per enemy from the combat log: 15 WotLK categories, 1/2 - 1/4 - immune, 18 s reset timer

Raid & dungeon
- Threat modes (DPS/Healer or Tank) from the client's threat glow, threat percent on target
- Built-in list of 140+ important adds (Naxx, Ulduar, ToC, ICC, RS, OS, Onyxia, ICC 5-mans)
  with red glow / yellow border, bosses bigger, own raid NPC list

PvP
- Flag carrier highlight (WSG/EotS) with icon, glow and optional sound
- Targeted-by counter (party colors or number), arena "targets YOU / party N" indicator,
  PvP trinket 2-minute timer, arena numbers, healer priority dimming

Profiles & zones
- Profiles (per character choice, shared storage), create/copy/rename/delete/reset
- Zone rules: per Open World / Dungeon / Raid / Battleground / Arena override Blizzard
  nameplate toggles and 20+ addon features ("Suggested raid/arena rules" buttons)
- Import/export strings (!BP2!...)

LIMITS OF THE 3.3.5a CLIENT
- Nameplates have no unit link. NPCs show auras and cast names once you target
  or mouse over them. Players are recognized via the combat log.
- Classes are collected from: group, target, focus, mouseover, combat log, chat,
  guild, friends, targets of group members. Players never seen keep reaction color.
- Not possible: absorb shields, resource/combo points, range fading, spec detection,
  click-through plates, native stacking, quest markers, cast target names.

COMMANDS
/bbp               settings window
/bbp test          demo of all elements on your target's nameplate (16 s)
/bbp profile <n>   switch profile (no name = list)
/bbp friends | enemies | all   toggle nameplates
/bbp stack         toggle stacking
/bbp export        print export string
/bbp reset         reset current profile
/bbp debug         diagnostics to chat
/bbp donate        donation info (Warmane Coins)

KEY BINDINGS (Key Bindings > BetterPlates)
Toggle friendly / enemy / all nameplates, toggle stacking, open settings, test mode.

DONATE
If this addon helps you, you can send a few Warmane Coins to the author:
https://www.warmane.com/account/services  ->  character Samyd, realm Blackrock
Thank you!
