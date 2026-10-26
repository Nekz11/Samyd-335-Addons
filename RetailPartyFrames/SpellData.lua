-- RetailPartyFrames - cooldown database (WotLK 3.3.5a, base cooldowns without talents/glyphs)
-- cd       = base cooldown in seconds
-- cat      = category (see ns.CDCategories)
-- ids      = every rank / alternative spell id that triggers this cooldown
-- talent   = only shown after the player has been seen using it
-- prio     = 1 essential (trinket, big defensives, interrupts, hard CC), 2 useful (default), 3 minor
-- active   = buff duration, the icon glows while active
-- race     = racial ability (UnitRace token)

local _, ns = ...

ns.CDCategories = {
    { key = "interrupt", label = "Interrupts" },
    { key = "external",  label = "External defensives" },
    { key = "defensive", label = "Personal defensives" },
    { key = "raid",      label = "Raid / group cooldowns" },
    { key = "cc",        label = "Crowd control" },
    { key = "utility",   label = "Utility" },
    { key = "offensive", label = "Offensive" },
    { key = "racial",    label = "Racials" },
    { key = "pvp",       label = "PvP trinket" },
}
local CAT_ORDER = {}
for i, c in ipairs(ns.CDCategories) do CAT_ORDER[c.key] = i end

local DB = {}
local function add(class, id, cd, cat, opts)
    local e = { id = id, class = class, cd = cd, cat = cat, prio = 2 }
    if opts then
        for k, v in pairs(opts) do e[k] = v end
    end
    DB[#DB + 1] = e
end

-- WARRIOR
add("WARRIOR", 6552, 10, "interrupt", { prio = 1 })                                         -- Pummel
add("WARRIOR", 72, 12, "interrupt", {  ids = { 72, 1671, 1672, 29704 } , prio = 1 })      -- Shield Bash
add("WARRIOR", 871, 300, "defensive", {  active = 12 , prio = 1 })                        -- Shield Wall
add("WARRIOR", 12975, 180, "defensive", {  talent = true, active = 20 , prio = 1 })       -- Last Stand
add("WARRIOR", 23920, 10, "defensive", { active = 5 })                        -- Spell Reflection
add("WARRIOR", 55694, 180, "defensive", { active = 10 })                      -- Enraged Regeneration
add("WARRIOR", 3411, 30, "utility")                                           -- Intervene
add("WARRIOR", 1161, 180, "utility", { prio = 3 })                                          -- Challenging Shout
add("WARRIOR", 5246, 120, "cc", { prio = 1 })                                               -- Intimidating Shout
add("WARRIOR", 46968, 20, "cc", { talent = true })                            -- Shockwave
add("WARRIOR", 12809, 30, "cc", { talent = true })                            -- Concussion Blow
add("WARRIOR", 1719, 300, "offensive", { active = 12 })                       -- Recklessness
add("WARRIOR", 64382, 300, "offensive", { prio = 1 })                                       -- Shattering Throw
add("WARRIOR", 46924, 90, "offensive", {  talent = true, active = 6 , prio = 1 })         -- Bladestorm
add("WARRIOR", 676, 60, "utility")                                            -- Disarm
add("WARRIOR", 18499, 30, "utility", { active = 10 })                         -- Berserker Rage

-- PALADIN
add("PALADIN", 642, 300, "defensive", {  ids = { 642, 1020 }, active = 12 , prio = 1 })   -- Divine Shield
add("PALADIN", 498, 180, "defensive", {  ids = { 498, 5573 }, active = 12 , prio = 1 })   -- Divine Protection
add("PALADIN", 10278, 300, "external", {  ids = { 1022, 5599, 10278 }, active = 10 , prio = 1 }) -- Hand of Protection
add("PALADIN", 6940, 120, "external", {  active = 12 , prio = 1 })                        -- Hand of Sacrifice
add("PALADIN", 48788, 1200, "external", {  ids = { 633, 2800, 10310, 27154, 48788 } , prio = 1 }) -- Lay on Hands
add("PALADIN", 31821, 120, "raid", {  talent = true, active = 6 , prio = 1 })             -- Aura Mastery
add("PALADIN", 64205, 120, "raid", {  talent = true, active = 10 , prio = 1 })            -- Divine Sacrifice
add("PALADIN", 1044, 25, "utility", {  active = 6 , prio = 1 })                           -- Hand of Freedom
add("PALADIN", 1038, 120, "utility", {  active = 10 , prio = 3 })                         -- Hand of Salvation
add("PALADIN", 10308, 60, "cc", {  ids = { 853, 5588, 5589, 10308 } , prio = 1 })         -- Hammer of Justice
add("PALADIN", 20066, 60, "cc", {  talent = true , prio = 1 })                            -- Repentance
add("PALADIN", 31884, 180, "offensive", {  active = 20 , prio = 1 })                      -- Avenging Wrath

-- DEATH KNIGHT
add("DEATHKNIGHT", 47528, 10, "interrupt", { prio = 1 })                                    -- Mind Freeze
add("DEATHKNIGHT", 47476, 120, "interrupt", { prio = 1 })                                   -- Strangulate
add("DEATHKNIGHT", 48792, 120, "defensive", {  active = 12 , prio = 1 })                  -- Icebound Fortitude
add("DEATHKNIGHT", 48707, 45, "defensive", {  active = 5 , prio = 1 })                    -- Anti-Magic Shell
add("DEATHKNIGHT", 55233, 60, "defensive", { talent = true, active = 10 })    -- Vampiric Blood
add("DEATHKNIGHT", 49039, 120, "defensive", { talent = true, active = 10 })   -- Lichborne
add("DEATHKNIGHT", 51271, 60, "defensive", { talent = true, active = 20 })    -- Unbreakable Armor
add("DEATHKNIGHT", 51052, 120, "raid", {  talent = true, active = 10 , prio = 1 })        -- Anti-Magic Zone
add("DEATHKNIGHT", 49016, 180, "offensive", {  talent = true, active = 30 , prio = 3 })   -- Hysteria
add("DEATHKNIGHT", 49028, 90, "offensive", { talent = true })                 -- Dancing Rune Weapon
add("DEATHKNIGHT", 49206, 180, "offensive", { talent = true })                -- Summon Gargoyle
add("DEATHKNIGHT", 42650, 600, "offensive")                                   -- Army of the Dead
add("DEATHKNIGHT", 49576, 35, "utility", { prio = 1 })                                      -- Death Grip
add("DEATHKNIGHT", 48982, 30, "defensive", { talent = true })                 -- Rune Tap
add("DEATHKNIGHT", 48743, 120, "defensive")                                   -- Death Pact
add("DEATHKNIGHT", 61999, 600, "raid", { prio = 3 })                                        -- Raise Ally

-- DRUID
add("DRUID", 16979, 15, "interrupt", { talent = true })                       -- Feral Charge - Bear
add("DRUID", 22812, 60, "defensive", {  active = 12 , prio = 1 })                         -- Barkskin
add("DRUID", 61336, 180, "defensive", {  talent = true, active = 20 , prio = 1 })         -- Survival Instincts
add("DRUID", 22842, 180, "defensive", { active = 10 })                        -- Frenzied Regeneration
add("DRUID", 48477, 600, "raid", {  ids = { 20484, 20739, 20742, 20747, 20748, 26994, 48477 } , prio = 1 }) -- Rebirth
add("DRUID", 29166, 180, "raid", { active = 10 })                             -- Innervate
add("DRUID", 48447, 480, "raid", {  ids = { 740, 8918, 9862, 9863, 26983, 48446, 48447 }, active = 8 , prio = 1 }) -- Tranquility
add("DRUID", 8983, 60, "cc", { ids = { 5211, 6798, 8983 } })                  -- Bash
add("DRUID", 17116, 180, "utility", {  talent = true , prio = 1 })                        -- Nature's Swiftness
add("DRUID", 5209, 180, "utility", { prio = 3 })                                            -- Challenging Roar
add("DRUID", 50334, 180, "offensive", { talent = true, active = 15 })         -- Berserk
add("DRUID", 53201, 90, "offensive", { talent = true, ids = { 48505, 53199, 53200, 53201 } }) -- Starfall

-- HUNTER
add("HUNTER", 34490, 20, "interrupt", {  talent = true , prio = 1 })                      -- Silencing Shot
add("HUNTER", 19263, 90, "defensive", {  active = 5 , prio = 1 })                         -- Deterrence
add("HUNTER", 5384, 30, "defensive")                                          -- Feign Death
add("HUNTER", 34477, 30, "utility", { prio = 3 })                                           -- Misdirection
add("HUNTER", 53271, 60, "utility", { prio = 1 })                                           -- Master's Call
add("HUNTER", 23989, 180, "utility", {  talent = true , prio = 1 })                       -- Readiness
add("HUNTER", 14311, 30, "cc", {  ids = { 1499, 14310, 14311, 60192 } , prio = 1 })       -- Freezing Trap / Arrow
add("HUNTER", 19503, 30, "cc", {  talent = true , prio = 1 })                             -- Scatter Shot
add("HUNTER", 3045, 300, "offensive", {  active = 15 , prio = 3 })                        -- Rapid Fire
add("HUNTER", 19574, 120, "offensive", {  talent = true, active = 18 , prio = 1 })        -- Bestial Wrath
add("HUNTER", 49012, 60, "cc", {  talent = true, ids = { 19386, 24132, 24133, 27068, 49011, 49012 } , prio = 1 }) -- Wyvern Sting
add("HUNTER", 19577, 60, "cc", { talent = true })                             -- Intimidation

-- MAGE
add("MAGE", 2139, 24, "interrupt", { prio = 1 })                                            -- Counterspell
add("MAGE", 45438, 300, "defensive", {  active = 10 , prio = 1 })                         -- Ice Block
add("MAGE", 66, 180, "defensive")                                             -- Invisibility
add("MAGE", 12051, 240, "utility")                                            -- Evocation
add("MAGE", 11958, 480, "utility", {  talent = true , prio = 1 })                         -- Cold Snap
add("MAGE", 44572, 30, "cc", {  talent = true , prio = 1 })                               -- Deep Freeze
add("MAGE", 42950, 20, "cc", { talent = true, ids = { 31661, 33041, 33042, 33043, 42949, 42950 } }) -- Dragon's Breath
add("MAGE", 12472, 180, "offensive", { talent = true, active = 20 })          -- Icy Veins
add("MAGE", 12042, 120, "offensive", { talent = true, active = 15 })          -- Arcane Power
add("MAGE", 11129, 120, "offensive", { talent = true })                       -- Combustion
add("MAGE", 55342, 180, "offensive", {  active = 30 , prio = 3 })                         -- Mirror Image
add("MAGE", 42917, 25, "cc", { ids = { 122, 865, 6131, 10230, 27088, 42917 } }) -- Frost Nova
add("MAGE", 12043, 120, "utility", { talent = true })                         -- Presence of Mind

-- PRIEST
add("PRIEST", 15487, 45, "interrupt", {  talent = true , prio = 1 })                      -- Silence
add("PRIEST", 33206, 180, "external", {  talent = true, active = 8 , prio = 1 })          -- Pain Suppression
add("PRIEST", 47788, 180, "external", {  talent = true, active = 10 , prio = 1 })         -- Guardian Spirit
add("PRIEST", 47585, 120, "defensive", {  talent = true, active = 6 , prio = 1 })         -- Dispersion
add("PRIEST", 48173, 120, "defensive", { talent = true, ids = { 19236, 19238, 19240, 19241, 19242, 19243, 25437, 48172, 48173 } }) -- Desperate Prayer
add("PRIEST", 64843, 480, "raid", {  active = 8 , prio = 1 })                             -- Divine Hymn
add("PRIEST", 64901, 360, "raid", { active = 8 })                             -- Hymn of Hope
add("PRIEST", 6346, 180, "utility")                                           -- Fear Ward
add("PRIEST", 34433, 300, "utility", { prio = 3 })                                          -- Shadowfiend
add("PRIEST", 10890, 30, "cc", {  ids = { 8122, 8124, 10888, 10890 } , prio = 1 })        -- Psychic Scream
add("PRIEST", 64044, 120, "cc", {  talent = true , prio = 1 })                            -- Psychic Horror
add("PRIEST", 10060, 120, "offensive", { talent = true, active = 15 })        -- Power Infusion
add("PRIEST", 14751, 180, "utility", {  talent = true , prio = 3 })                       -- Inner Focus

-- ROGUE
add("ROGUE", 1766, 10, "interrupt", {  ids = { 1766, 1767, 1768, 1769, 38768 } , prio = 1 }) -- Kick
add("ROGUE", 31224, 90, "defensive", {  active = 5 , prio = 1 })                          -- Cloak of Shadows
add("ROGUE", 26669, 180, "defensive", {  ids = { 5277, 26669 }, active = 15 , prio = 1 }) -- Evasion
add("ROGUE", 26889, 180, "defensive", {  ids = { 1856, 1857, 26889 } , prio = 1 })        -- Vanish
add("ROGUE", 57934, 30, "utility", { prio = 3 })                                            -- Tricks of the Trade
add("ROGUE", 14185, 480, "utility", {  talent = true , prio = 1 })                        -- Preparation
add("ROGUE", 2094, 180, "cc", { prio = 1 })                                                 -- Blind
add("ROGUE", 8643, 20, "cc", { ids = { 408, 8643 } })                         -- Kidney Shot
add("ROGUE", 13750, 180, "offensive", {  talent = true, active = 15 , prio = 1 })         -- Adrenaline Rush
add("ROGUE", 51690, 120, "offensive", { talent = true })                      -- Killing Spree
add("ROGUE", 36554, 30, "utility", { talent = true })                         -- Shadowstep
add("ROGUE", 51722, 60, "utility", { prio = 1 })                                            -- Dismantle
add("ROGUE", 11305, 180, "utility", { ids = { 2983, 8696, 11305 } })          -- Sprint
add("ROGUE", 1776, 10, "cc", { prio = 3 })                                                  -- Gouge

-- SHAMAN
add("SHAMAN", 57994, 6, "interrupt", { prio = 1 })                                          -- Wind Shear
add("SHAMAN", 30823, 60, "defensive", {  talent = true, active = 15 , prio = 1 })         -- Shamanistic Rage
add("SHAMAN", 2825, 300, "raid", {  active = 40 , prio = 1 })                             -- Bloodlust
add("SHAMAN", 32182, 300, "raid", {  active = 40 , prio = 1 })                            -- Heroism
add("SHAMAN", 16190, 300, "raid", { talent = true, active = 12 })             -- Mana Tide Totem
add("SHAMAN", 21169, 1800, "raid", { ids = { 20608, 21169 } })                 -- Reincarnation (30 min base, talent -15)
add("SHAMAN", 16188, 180, "utility", {  talent = true , prio = 1 })                       -- Nature's Swiftness
add("SHAMAN", 8177, 15, "utility", { prio = 1 })                                            -- Grounding Totem
add("SHAMAN", 51514, 45, "cc", { prio = 1 })                                                -- Hex
add("SHAMAN", 59159, 45, "cc", { talent = true, ids = { 51490, 59156, 59158, 59159 } }) -- Thunderstorm
add("SHAMAN", 2894, 600, "offensive")                                         -- Fire Elemental Totem
add("SHAMAN", 51533, 180, "offensive", { talent = true })                     -- Feral Spirit

-- WARLOCK
add("WARLOCK", 19647, 24, "interrupt", {  ids = { 19244, 19647 }, usage = true , prio = 1 }) -- Spell Lock (Felhunter)
add("WARLOCK", 47883, 900, "raid", { ids = { 20707, 20762, 20763, 20764, 20765, 27239, 47883 } }) -- Soulstone
add("WARLOCK", 47860, 120, "cc", {  ids = { 6789, 17925, 17926, 27223, 47859, 47860 } , prio = 1 }) -- Death Coil
add("WARLOCK", 17928, 40, "cc", {  ids = { 5484, 17928 } , prio = 1 })                   -- Howl of Terror
add("WARLOCK", 47847, 20, "cc", {  talent = true, ids = { 30283, 30413, 30414, 47846, 47847 } , prio = 1 }) -- Shadowfury
add("WARLOCK", 48020, 30, "utility", { talent = true })                       -- Demonic Circle: Teleport
add("WARLOCK", 47241, 180, "offensive", { talent = true, active = 30 })       -- Metamorphosis
add("WARLOCK", 47891, 30, "defensive", {  ids = { 6229, 11739, 11740, 28610, 47890, 47891 }, active = 30 , prio = 3 }) -- Shadow Ward
add("WARLOCK", 18708, 180, "utility", {  talent = true , prio = 3 })                      -- Fel Domination

-- RACIALS
add("RACIAL", 59752, 120, "racial", {  race = "Human" , prio = 1 })                       -- Every Man for Himself
add("RACIAL", 7744, 120, "racial", {  race = "Scourge" , prio = 1 })                      -- Will of the Forsaken
add("RACIAL", 20594, 120, "racial", { race = "Dwarf", active = 8 })           -- Stoneform
add("RACIAL", 20589, 105, "racial", {  race = "Gnome" , prio = 1 })                       -- Escape Artist (1:45)
add("RACIAL", 58984, 120, "racial", { race = "NightElf" })                    -- Shadowmeld
add("RACIAL", 20549, 120, "racial", { race = "Tauren" })                      -- War Stomp
add("RACIAL", 59547, 180, "racial", {  race = "Draenei", ids = { 28880, 59542, 59543, 59544, 59545, 59547, 59548 } , prio = 3 }) -- Gift of the Naaru
add("RACIAL", 20572, 120, "racial", {  race = "Orc", ids = { 20572, 33697, 33702 } , prio = 3 }) -- Blood Fury
add("RACIAL", 26297, 180, "racial", {  race = "Troll" , prio = 3 })                       -- Berserking
add("RACIAL", 28730, 120, "racial", { race = "BloodElf", ids = { 28730, 25046, 50613 } }) -- Arcane Torrent

-- ANY CLASS
add("ANY", 42292, 120, "pvp", {  usage = true , prio = 1 })                               -- PvP Trinket

-- Spells that reset other cooldowns
ns.SpellResets = {
    [11958] = { 45438, 12472, 44572, 42917 },                                         -- Cold Snap
    [14185] = { 26669, 26889, 36554, 11305 },                                  -- Preparation
    [23989] = { 19263, 34477, 5384, 34490, 53271, 14311, 19503, 3045, 49012, 19577 }, -- Readiness
}

------------------------------------------------------------------------
-- Talents that shorten tracked cooldowns
-- key = spell id of the talent's first rank (matched against the inspected talent NAME,
-- so a wrong id simply matches nothing). flat = seconds per rank, pct = percent per rank.
------------------------------------------------------------------------
ns.TalentMods = {}
local function talent(id, ...)
    ns.TalentMods[id] = { ... }
end
talent(13981, { 26889, flat = { 30, 60 } }, { 2094, flat = { 30, 60 } }, { 31224, flat = { 7.5, 15 } }) -- Elusiveness
talent(15274, { 34433, flat = { 30, 60 } })                                   -- Veiled Shadows (Shadowfiend)
talent(20174, { 10278, flat = { 60, 120 } })                                  -- Guardian's Favor (Hand of Protection)
talent(20487, { 10308, flat = { 10, 20 } })                                   -- Improved Hammer of Justice
talent(16184, { 21169, flat = { 420, 900 } })                                 -- Improved Reincarnation
talent(34491, { 14311, flat = { 2, 4, 6 } })                                  -- Resourcefulness (traps)
talent(31670, { 42917, pct = { 7, 14, 20 } }, { 45438, pct = { 7, 14, 20 } }, { 12472, pct = { 7, 14, 20 } }) -- Ice Floes
talent(14908, { 10890, flat = { 2, 4 } })                                     -- Improved Psychic Scream
talent(16940, { 8983, flat = { 15, 30 } })                                    -- Brutal Impact (Bash)
talent(16258, { 8177, flat = { 2, 4 } })                                      -- Guardian Totems (Grounding Totem)
talent(49588, { 49576, flat = { 5, 10 } })                                    -- Unholy Command (Death Grip)
talent(29590, { 18499, pct = { 11, 22, 33 } }, { 1719, pct = { 11, 22, 33 } }) -- Intensify Rage

-- Glyphs that shorten tracked cooldowns: affected spell id -> seconds of reduction.
-- A glyph counts when its name contains the spell name ("Glyph of Shield Wall"), locale independent.
ns.GlyphMods = {
    [871] = 120,     -- Glyph of Shield Wall
    [12975] = 60,    -- Glyph of Last Stand
    [23920] = 1,     -- Glyph of Spell Reflection
    [46924] = 15,    -- Glyph of Bladestorm
    [48788] = 300,   -- Glyph of Lay on Hands
    [47585] = 45,    -- Glyph of Dispersion
    [6346] = 60,     -- Glyph of Fear Ward
    [47476] = 20,    -- Glyph of Strangulate
    [5384] = 5,      -- Glyph of Feign Death
    [19574] = 20,    -- Glyph of Bestial Wrath
    [49012] = 6,     -- Glyph of Wyvern Sting
    [17928] = 8,     -- Glyph of Howl of Terror
    [2894] = 300,    -- Glyph of Fire Elemental Totem
    [53201] = 30,    -- Glyph of Starfall
}

------------------------------------------------------------------------
-- Priority debuffs: shown first and larger (raid encounters, 3.3.5)
-- Unknown ids simply never match. Editable via the black-/whitelist in the options.
------------------------------------------------------------------------
ns.PriorityDebuffs = {}
local function prio(...)
    for i = 1, select("#", ...) do ns.PriorityDebuffs[select(i, ...)] = true end
end
-- Icecrown Citadel
prio(69065)                                   -- Impaled (Marrowgar)
prio(71289, 71001)                            -- Dominate Mind, Death and Decay (Deathwhisper)
prio(72293, 72385, 72410, 72442, 72443)       -- Mark of the Fallen Champion, Boiling Blood, Rune of Blood (Saurfang)
prio(69279, 69240, 71218, 72272, 72273, 72219, 72551, 72552, 72553) -- Gas Spore, Vile Gas, Gastric Bloat (Festergut)
prio(69674, 71224, 73022, 73023, 69508)       -- Mutated Infection, Slime Spray (Rotface)
prio(70447, 72836, 72837, 72838, 70672, 72455, 72832, 72833, 70911, 72854, 72855, 72856, 72451, 72463, 72671, 72672) -- Putricide
prio(72999, 71718, 72040, 72041, 71822)       -- Shadow Prison, Conflagration, Shadow Resonance (Blood Council)
prio(71340, 71341, 71264, 71265, 71266, 71267, 70867, 70877, 70879, 71473, 71474, 71525, 71530, 71531, 71532, 71533, 70923, 71623) -- Blood-Queen
prio(70106, 69649, 70123, 71056, 71057, 71058, 69762, 69766, 70126, 70127, 72528, 72529, 72530, 71665, 72443) -- Sindragosa
prio(70337, 70338, 73912, 73913, 73914, 73785, 73786, 73787, 73788, 73789, 73790, 73791, 73792, 73793, 73794, 73795, 73796, 73797, 73798, 73799, 70541, 73779, 73780, 73781, 68980, 74325, 74296, 74297, 74323, 69409, 73797, 72743, 72754, 73708, 73709, 73710, 73539, 69242) -- Lich King
-- Trial of the Crusader
prio(66869, 66823, 67618, 67619, 67620, 66331, 66881, 67704, 66689, 66758)      -- Beasts of Northrend
prio(66197, 68123, 68124, 68125, 66237, 67049, 67050, 67051, 66334, 67905, 67906, 67907) -- Jaraxxus
prio(66013, 67700, 68509, 68510, 66118, 67630, 68646, 68647, 67574, 66012, 66193, 67847) -- Anub'arak
prio(65950, 66001, 67590, 67602, 67603, 67604, 65879, 65916, 67591, 67592, 67593) -- Twin Val'kyr
-- Ulduar
prio(62717, 63477, 62681, 64771, 63024, 64234, 63018, 65121, 64637, 61903, 63355, 64002, 62166, 63981)
prio(62188, 62469, 62331, 62130, 62283, 62930, 62589, 63571, 63276, 62660, 63802, 63830, 63881, 64125, 64126, 64164, 64168, 63666, 65026, 62997, 64529, 64389, 64678)
-- Naxxramas / misc
prio(28169, 55593, 28059, 55849, 55881, 28062, 29213, 29214, 28522, 54022, 56272, 54362, 55665, 28796, 29107)

------------------------------------------------------------------------
-- Corner indicator defaults per class (spell ids of the buff; matched by name)
-- slots: TOPLEFT, TOPRIGHT, BOTTOMLEFT, BOTTOMRIGHT, CENTER
------------------------------------------------------------------------
ns.IndicatorDefaults = {
    PRIEST   = { TOPLEFT = { 139 }, TOPRIGHT = { 17 }, BOTTOMLEFT = { 41635, 33076 }, BOTTOMRIGHT = { 6788 }, CENTER = { 47788, 33206 } },
    DRUID    = { TOPLEFT = { 774 }, TOPRIGHT = { 8936 }, BOTTOMLEFT = { 33763 }, BOTTOMRIGHT = { 48438 }, CENTER = {} },
    PALADIN  = { TOPLEFT = { 53563 }, TOPRIGHT = { 53601, 58597 }, BOTTOMLEFT = { 66922 }, BOTTOMRIGHT = { 25771 }, CENTER = { 10278, 6940 } },
    SHAMAN   = { TOPLEFT = { 974 }, TOPRIGHT = { 61295 }, BOTTOMLEFT = { 51945 }, BOTTOMRIGHT = { 16177 }, CENTER = {} },
    MAGE     = { TOPLEFT = { 54646 }, TOPRIGHT = {}, BOTTOMLEFT = {}, BOTTOMRIGHT = {}, CENTER = {} },
    WARLOCK  = { TOPLEFT = { 20707 }, TOPRIGHT = {}, BOTTOMLEFT = {}, BOTTOMRIGHT = {}, CENTER = {} },
    DEFAULT  = { TOPLEFT = {}, TOPRIGHT = {}, BOTTOMLEFT = {}, BOTTOMRIGHT = {}, CENTER = {} },
}
-- these indicator spells are debuffs (looked up with HARMFUL instead of HELPFUL)
ns.IndicatorDebuffs = { [6788] = true, [25771] = true }

------------------------------------------------------------------------
-- Resurrection spells (any rank) -> "Res" text on the target's frame while being cast
------------------------------------------------------------------------
ns.ResurrectSpells = {}
for _, id in ipairs({ 2006, 2010, 10880, 10881, 20770, 25435, 48171,   -- Resurrection
                      7328, 10322, 10324, 20772, 20773, 48949, 48950,  -- Redemption
                      2008, 20609, 20610, 20776, 20777, 25590, 49277,  -- Ancestral Spirit
                      50769, 50768, 50767, 50766, 50765, 50764, 50763, -- Revive
                      20484, 20739, 20742, 20747, 20748, 26994, 48477, -- Rebirth
                      61999 }) do                                      -- Raise Ally
    ns.ResurrectSpells[id] = true
end

------------------------------------------------------------------------
-- Battleground flags carried as auras
------------------------------------------------------------------------
ns.FlagAuras = {
    [23333] = "Interface\\Icons\\INV_BannerPVP_01",   -- Warsong Flag (Horde carrier)
    [23335] = "Interface\\Icons\\INV_BannerPVP_02",   -- Silverwing Flag (Alliance carrier)
    [34976] = "Interface\\Icons\\INV_BannerPVP_03",   -- Netherstorm Flag
}

------------------------------------------------------------------------
-- Important auras for the "important only" aura filters. One id per spell; the lists are
-- matched by spell NAME at runtime, so every rank is covered.
------------------------------------------------------------------------
ns.ImportantDebuffIds = {
    -- crowd control: incapacitates / fears / polymorphs
    118, 28271, 28272, 61305, 61721, 61780,   -- Polymorph (+ pig/turtle/rabbit/cat/turkey)
    5782, 8122, 5484, 6789, 5246, 1513, 10326, -- Fear, Psychic Scream, Howl of Terror, Death Coil, Intimidating Shout, Scare Beast, Turn Evil
    51514, 33786, 3355, 60210, 19386, 6770, 2094, 1776, 20066, 6358, 605, 2637, 710, 9484, 19503, 31661, 64044,
    -- Hex, Cyclone, Freezing Trap, Freezing Arrow, Wyvern Sting, Sap, Blind, Gouge, Repentance, Seduction, Mind Control, Hibernate, Banish, Shackle, Scatter Shot, Dragon's Breath, Psychic Horror
    -- stuns
    408, 1833, 853, 5211, 9005, 22570, 12809, 7922, 20253, 46968, 44572, 12355, 20549, 30283, 19577, 47481, 49203, 2812, 5530, 12798,
    -- silences
    15487, 1330, 18425, 18498, 19244, 18469, 47476, 28730, 34490,
    -- roots
    122, 339, 19185, 12494, 45524, 33395,
    -- disarms
    676, 51722,
    -- healing reduction / dispel traps / mana drain
    12294, 13218, 19434, 56112, 48301, 30108, 34914, 3034,
}
ns.ImportantBuffIds = {
    -- externals and shields
    33206, 47788, 17, 10278, 6940, 1044, 1038, 6346, 10060, 29166, 64205, 31821, 23920,
    -- Pain Suppression, Guardian Spirit, PW:S, Hand of Protection, Hand of Sacrifice, Hand of Freedom, Hand of Salvation, Fear Ward, Power Infusion, Innervate, Divine Sacrifice, Aura Mastery, Spell Reflection
    -- heals over time
    139, 774, 8936, 33763, 48438, 61295, 7001, 65081, 2893, 552,
    -- Renew, Rejuvenation, Regrowth, Lifebloom, Wild Growth, Riptide, Lightwell Renew, Body and Soul, Abolish Poison, Abolish Disease
    -- personal defensives / immunities
    642, 498, 45438, 19263, 5277, 31224, 22812, 871, 12975, 48707, 48792, 47585, 55694, 46924, 22842, 61336, 16689, 8178, 30823, 7744, 16188,
    -- Divine Shield, Divine Protection, Ice Block, Deterrence, Evasion, Cloak of Shadows, Barkskin, Shield Wall, Last Stand, AMS, IBF, Dispersion, Enraged Regeneration, Bladestorm, Frenzied Regeneration, Survival Instincts, Nature's Grasp, Grounding Totem Effect, Shamanistic Rage, Will of the Forsaken, Nature's Swiftness
    -- big offensive cooldowns (useful to see on a team mate in arena)
    2825, 32182, 12472, 12042, 31884, 1719, 12292, 19574, 50334, 47241, 13750, 51713, 51690, 49016,
    -- Bloodlust, Heroism, Icy Veins, Arcane Power, Avenging Wrath, Recklessness, Death Wish, Bestial Wrath, Berserk, Metamorphosis, Adrenaline Rush, Shadow Dance, Killing Spree, Hysteria
}

local importantDebuffNames, importantBuffNames
local function ResolveNames(ids)
    local names = {}
    for _, id in ipairs(ids) do
        local name = GetSpellInfo(id)
        if name then names[name] = true end
    end
    return names
end
function ns:ImportantDebuffNames()
    if not importantDebuffNames then importantDebuffNames = ResolveNames(self.ImportantDebuffIds) end
    return importantDebuffNames
end
function ns:ImportantBuffNames()
    if not importantBuffNames then importantBuffNames = ResolveNames(self.ImportantBuffIds) end
    return importantBuffNames
end

------------------------------------------------------------------------
-- Indexes (rebuilt whenever custom spells change)
------------------------------------------------------------------------
ns.SpellDB = DB
ns.SpellIndex = {}
ns.ClassSpells = {}
ns.ClassTokens = { "WARRIOR", "PALADIN", "DEATHKNIGHT", "DRUID", "HUNTER", "MAGE", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK" }

function ns:RebuildSpellIndex()
    local index, byClass = {}, {}
    local entries = {}
    for _, e in ipairs(DB) do
        local c = {}
        for k, v in pairs(e) do c[k] = v end
        entries[#entries + 1] = c
        index[c.id] = c
    end

    -- user additions / overrides from the options panel
    local custom = self.db and self.db.customSpells
    if custom then
        for _, cs in ipairs(custom) do
            local id, cd = tonumber(cs.id), tonumber(cs.cd)
            if id and cd and cd > 0 then
                local e = index[id]
                if e then
                    e.cd = cd
                    if cs.cat and CAT_ORDER[cs.cat] then e.cat = cs.cat end
                    e.custom = true
                else
                    local class = cs.class or "ANY"
                    e = { id = id, cd = cd, class = class, cat = (cs.cat and CAT_ORDER[cs.cat]) and cs.cat or "utility", custom = true, prio = 1 }
                    entries[#entries + 1] = e
                    index[id] = e
                end
            end
        end
    end

    for _, e in ipairs(entries) do
        e.order = CAT_ORDER[e.cat] or 99
        if e.ids then
            for _, id in ipairs(e.ids) do index[id] = e end
        end
        byClass[e.class] = byClass[e.class] or {}
        table.insert(byClass[e.class], e)
    end
    for _, list in pairs(byClass) do
        table.sort(list, function(a, b)
            if a.prio ~= b.prio then return a.prio < b.prio end
            if a.order ~= b.order then return a.order < b.order end
            if a.cd ~= b.cd then return a.cd < b.cd end
            return a.id < b.id
        end)
    end
    self.SpellIndex, self.ClassSpells = index, byClass
end

ns:RebuildSpellIndex()
