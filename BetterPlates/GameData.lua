-- BetterPlates - GameData
-- Spieldaten für 3.3.5a: Diminishing-Returns-Kategorien, wichtige Raid-NPCs,
-- Schlachtfeld-Flaggen, Totem-Dauern, Lockouts, PvP-Schmuck, Dispel-Matrix.
-- Quellen: DRData-1.0 / DRList-1.0 (WotLK), warcraft.wiki.gg, Wowhead-WotLK (enUS/deDE).

local ADDON, ns = ...
if type(ns) ~= "table" then BetterPlatesNS = BetterPlatesNS or {} ns = BetterPlatesNS ADDON = "BetterPlates" end

-- ============================================================================
-- 1. DIMINISHING RETURNS
-- ============================================================================
-- Quelle: DRData-1.0 (WotLK) + DRList-1.0 (wotlk-Abschnitt), abgeglichen mit warcraft.wiki.gg.
-- Spell-IDs sind die Aura-IDs, die im Kampflog als SPELL_AURA_APPLIED erscheinen
-- (z. B. Intercept Stun 20253 statt Intercept 20252, Spell Lock 24259 statt 19244).
--
-- Kategorien in 3.3.5a (Blizzard-Regeln):
--   stun         = kontrollierte Stuns (ctrlstun) UND Proc-/Zufallsstuns (rndstun) -- auf Wunsch
--                  zusammengefasst; im Spiel sind das ZWEI getrennte DR-Kategorien!
--                  Die Zufallsstuns sind zusätzlich in DR_RANDOM markiert.
--   cheapshot    = Cheap Shot + Pounce (teilen DR nur untereinander, Patch 3.0.8 / 3.1)
--   fear         = Furcht inkl. Blind (seit 3.0 Fear-DR) und Seduction
--   horror       = Death Coil, Psychic Horror
--   incapacitate = "disorient" bei DRData: Polymorph, Sap, Gouge, Repentance, Hungering Cold,
--                  Freezing Trap/Arrow, Wyvern Sting, Shackle Undead, Hex, Dragon's Breath
--   disorient    = Scatter Shot (in 3.3.5a eigene Kategorie "scatters")
--   silence      = alle Silences (seit 3.0.8 mit DR)
--   root         = kontrollierte Roots (ctrlroot) UND Zufallsroots (rndroot) zusammengefasst
--                  (analog zu stun; im Spiel zwei Kategorien; Zufallsroots in DR_RANDOM)
--   entrapment   = Entrapment (eigene Kategorie in 3.3.5a)
--   cyclone      = Cyclone (nur mit sich selbst)
--   banish       = Banish (eigene Kategorie in 3.3.5a)
--   sleep        = Hibernate (eigene Kategorie in 3.3.5a)
--   charge       = Charge-Stun (nur mit sich selbst)
--   disarm       = Entwaffnen
--   mc           = Mind Control (nur mit sich selbst)
--   Taunt-DR (seit 3.3.0) wird hier absichtlich nicht geführt.

local DR_RESET = 18 -- Sekunden, bis eine DR-Kategorie zurückgesetzt wird (Data.RESET_TIME in DRData-1.0)

local DR_SPELLS = {
    -------------------------------------------------------------------------
    -- STUN (kontrolliert)
    -------------------------------------------------------------------------
    -- Druide
    [5211]  = "stun", -- Bash R1
    [6798]  = "stun", -- Bash R2
    [8983]  = "stun", -- Bash R3
    [22570] = "stun", -- Maim R1
    [49802] = "stun", -- Maim R2
    -- Jäger
    [24394] = "stun", -- Intimidation (Stun-Aura des Pets)
    [50519] = "stun", -- Sonic Blast (Pet) R1
    [53564] = "stun", -- Sonic Blast R2
    [53565] = "stun", -- Sonic Blast R3
    [53566] = "stun", -- Sonic Blast R4
    [53567] = "stun", -- Sonic Blast R5
    [53568] = "stun", -- Sonic Blast R6
    [50518] = "stun", -- Ravage (Pet) R1
    [53558] = "stun", -- Ravage R2
    [53559] = "stun", -- Ravage R3
    [53560] = "stun", -- Ravage R4
    [53561] = "stun", -- Ravage R5
    [53562] = "stun", -- Ravage R6
    -- Magier
    [44572] = "stun", -- Deep Freeze
    -- Paladin
    [853]   = "stun", -- Hammer of Justice R1
    [5588]  = "stun", -- Hammer of Justice R2
    [5589]  = "stun", -- Hammer of Justice R3
    [10308] = "stun", -- Hammer of Justice R4
    [2812]  = "stun", -- Holy Wrath R1 (Hotfix 09/2009: normale Stun-DR)
    [10318] = "stun", -- Holy Wrath R2
    [27139] = "stun", -- Holy Wrath R3
    [48816] = "stun", -- Holy Wrath R4
    [48817] = "stun", -- Holy Wrath R5
    -- Schurke
    [408]   = "stun", -- Kidney Shot R1
    [8643]  = "stun", -- Kidney Shot R2
    -- Schamane
    [58861] = "stun", -- Bash (Feral Spirit / Geisterwölfe)
    -- Hexenmeister
    [30283] = "stun", -- Shadowfury R1
    [30413] = "stun", -- Shadowfury R2
    [30414] = "stun", -- Shadowfury R3
    [47846] = "stun", -- Shadowfury R4
    [47847] = "stun", -- Shadowfury R5
    [60995] = "stun", -- Demon Charge (Metamorphose)
    [30153] = "stun", -- Intercept (Felguard) R1
    [30195] = "stun", -- Intercept (Felguard) R2
    [30197] = "stun", -- Intercept (Felguard) R3
    [47995] = "stun", -- Intercept (Felguard) R4
    [22703] = "stun", -- Inferno Effect (Infernal-Beschwörung) -- unsicher
    -- Krieger
    [12809] = "stun", -- Concussion Blow
    [46968] = "stun", -- Shockwave
    [20253] = "stun", -- Intercept Stun R1
    [20614] = "stun", -- Intercept Stun R2
    [20615] = "stun", -- Intercept Stun R3
    [25273] = "stun", -- Intercept Stun R4
    [25274] = "stun", -- Intercept Stun R5
    -- Todesritter
    [47481] = "stun", -- Gnaw (Ghul) -- unsicher (Aura-ID = Zauber-ID in 3.3.5a)
    -- Volksfähigkeit
    [20549] = "stun", -- War Stomp (Tauren)

    -------------------------------------------------------------------------
    -- STUN (Zufalls-/Proc-Stuns, in 3.3.5a eigene Kategorie "rndstun"; siehe DR_RANDOM)
    -------------------------------------------------------------------------
    [16922] = "stun", -- Celestial Focus (Starfire-Stun)
    [28445] = "stun", -- Improved Concussive Shot
    [12355] = "stun", -- Impact
    [20170] = "stun", -- Seal of Justice Stun
    [39796] = "stun", -- Stoneclaw Stun
    [12798] = "stun", -- Revenge Stun
    [5530]  = "stun", -- Mace Stun Effect (Mace Specialization)
    [15283] = "stun", -- Stunning Blow (Waffenproc)
    [56]    = "stun", -- Stun (Waffenproc)
    [34510] = "stun", -- Stormherald / Deep Thunder (Waffenproc)

    -------------------------------------------------------------------------
    -- CHEAP SHOT / POUNCE (eigene Kategorie seit 3.0.8)
    -------------------------------------------------------------------------
    [1833]  = "cheapshot", -- Cheap Shot
    [9005]  = "cheapshot", -- Pounce R1
    [9823]  = "cheapshot", -- Pounce R2
    [9827]  = "cheapshot", -- Pounce R3
    [27006] = "cheapshot", -- Pounce R4
    [49803] = "cheapshot", -- Pounce R5

    -------------------------------------------------------------------------
    -- FEAR
    -------------------------------------------------------------------------
    [1513]  = "fear", -- Scare Beast R1
    [14326] = "fear", -- Scare Beast R2
    [14327] = "fear", -- Scare Beast R3
    [10326] = "fear", -- Turn Evil
    [8122]  = "fear", -- Psychic Scream R1
    [8124]  = "fear", -- Psychic Scream R2
    [10888] = "fear", -- Psychic Scream R3
    [10890] = "fear", -- Psychic Scream R4
    [2094]  = "fear", -- Blind (seit 3.0 Fear-DR, nicht Disorient!)
    [5782]  = "fear", -- Fear R1
    [6213]  = "fear", -- Fear R2
    [6215]  = "fear", -- Fear R3
    [6358]  = "fear", -- Seduction (Sukkubus)
    [5484]  = "fear", -- Howl of Terror R1
    [17928] = "fear", -- Howl of Terror R2
    [5246]  = "fear", -- Intimidating Shout (Hauptziel, "cower")
    [20511] = "fear", -- Intimidating Shout (Furcht auf Nebenziele)
    [5134]  = "fear", -- Flash Bomb Fear (Gegenstand)

    -------------------------------------------------------------------------
    -- HORROR
    -------------------------------------------------------------------------
    [6789]  = "horror", -- Death Coil R1
    [17925] = "horror", -- Death Coil R2
    [17926] = "horror", -- Death Coil R3
    [27223] = "horror", -- Death Coil R4
    [47859] = "horror", -- Death Coil R5
    [47860] = "horror", -- Death Coil R6
    [64044] = "horror", -- Psychic Horror

    -------------------------------------------------------------------------
    -- INCAPACITATE ("disorient" in DRData-1.0)
    -------------------------------------------------------------------------
    [118]   = "incapacitate", -- Polymorph R1
    [12824] = "incapacitate", -- Polymorph R2
    [12825] = "incapacitate", -- Polymorph R3
    [12826] = "incapacitate", -- Polymorph R4
    [28271] = "incapacitate", -- Polymorph: Turtle
    [28272] = "incapacitate", -- Polymorph: Pig
    [61025] = "incapacitate", -- Polymorph: Serpent
    [61305] = "incapacitate", -- Polymorph: Black Cat
    [61721] = "incapacitate", -- Polymorph: Rabbit
    [61780] = "incapacitate", -- Polymorph: Turkey
    [6770]  = "incapacitate", -- Sap R1
    [2070]  = "incapacitate", -- Sap R2
    [11297] = "incapacitate", -- Sap R3
    [51724] = "incapacitate", -- Sap R4
    [1776]  = "incapacitate", -- Gouge
    [20066] = "incapacitate", -- Repentance
    [49203] = "incapacitate", -- Hungering Cold (Zauber)
    [51209] = "incapacitate", -- Hungering Cold (Eis-Aura) -- unsicher
    [3355]  = "incapacitate", -- Freezing Trap Effect R1
    [14308] = "incapacitate", -- Freezing Trap Effect R2
    [14309] = "incapacitate", -- Freezing Trap Effect R3
    [60210] = "incapacitate", -- Freezing Arrow Effect
    [19386] = "incapacitate", -- Wyvern Sting R1
    [24132] = "incapacitate", -- Wyvern Sting R2
    [24133] = "incapacitate", -- Wyvern Sting R3
    [27068] = "incapacitate", -- Wyvern Sting R4
    [49011] = "incapacitate", -- Wyvern Sting R5
    [49012] = "incapacitate", -- Wyvern Sting R6
    [9484]  = "incapacitate", -- Shackle Undead R1
    [9485]  = "incapacitate", -- Shackle Undead R2
    [10955] = "incapacitate", -- Shackle Undead R3
    [51514] = "incapacitate", -- Hex -- unsicher (DRData: "Guessing"; Wrath Classic: Incapacitate)
    [31661] = "incapacitate", -- Dragon's Breath R1 (3.3.5a: DR mit Polymorph/Sap; Wrath Classic: mit Scatter Shot) -- unsicher
    [33041] = "incapacitate", -- Dragon's Breath R2 -- unsicher
    [33042] = "incapacitate", -- Dragon's Breath R3 -- unsicher
    [33043] = "incapacitate", -- Dragon's Breath R4 -- unsicher
    [42949] = "incapacitate", -- Dragon's Breath R5 -- unsicher
    [42950] = "incapacitate", -- Dragon's Breath R6 -- unsicher
    -- Ingenieurs-Granaten/Bomben (Sapped-Mechanik, teilen DR mit Sap/Polymorph)
    [13327] = "incapacitate", -- Reckless Charge (Gegenstand)
    [4068]  = "incapacitate", -- Iron Grenade
    [12421] = "incapacitate", -- Mithril Frag Bomb
    [19769] = "incapacitate", -- Thorium Grenade
    [19784] = "incapacitate", -- Dark Iron Bomb
    [30216] = "incapacitate", -- Fel Iron Bomb
    [30217] = "incapacitate", -- Adamantite Grenade
    [30461] = "incapacitate", -- The Bigger One
    [54466] = "incapacitate", -- Saronite Grenade
    [67769] = "incapacitate", -- Cobalt Frag Bomb
    [67890] = "incapacitate", -- Cobalt Frag Bomb (Frag Belt)

    -------------------------------------------------------------------------
    -- DISORIENT (Scatter Shot; eigene Kategorie "scatters" in 3.3.5a)
    -------------------------------------------------------------------------
    [19503] = "disorient", -- Scatter Shot

    -------------------------------------------------------------------------
    -- SILENCE
    -------------------------------------------------------------------------
    [47476] = "silence", -- Strangulate
    [34490] = "silence", -- Silencing Shot
    [18469] = "silence", -- Silenced - Improved Counterspell R1
    [55021] = "silence", -- Silenced - Improved Counterspell R2
    [63529] = "silence", -- Silenced - Shield of the Templar
    [15487] = "silence", -- Silence (Priester)
    [1330]  = "silence", -- Garrote - Silence
    [18425] = "silence", -- Silenced - Improved Kick
    [24259] = "silence", -- Spell Lock (Silence-Aura des Teufelsjägers)
    [31117] = "silence", -- Unstable Affliction (Dispel-Silence)
    [43523] = "silence", -- Unstable Affliction (Dispel-Silence, Variante) -- unsicher
    [18498] = "silence", -- Silenced - Gag Order (Shield Bash)
    [74347] = "silence", -- Silenced - Gag Order (Heroic Throw) -- unsicher
    [28730] = "silence", -- Arcane Torrent (Mana)
    [25046] = "silence", -- Arcane Torrent (Energie)
    [50613] = "silence", -- Arcane Torrent (Runenmacht)
    [53588] = "silence", -- Nether Shock (Netherrochen-Pet) R1
    [53589] = "silence", -- Nether Shock R2

    -------------------------------------------------------------------------
    -- ROOT (kontrolliert)
    -------------------------------------------------------------------------
    [339]   = "root", -- Entangling Roots R1
    [1062]  = "root", -- Entangling Roots R2
    [5195]  = "root", -- Entangling Roots R3
    [5196]  = "root", -- Entangling Roots R4
    [9852]  = "root", -- Entangling Roots R5
    [9853]  = "root", -- Entangling Roots R6
    [26989] = "root", -- Entangling Roots R7
    [53308] = "root", -- Entangling Roots R8
    [19975] = "root", -- Entangling Roots (Nature's Grasp) R1
    [19974] = "root", -- Entangling Roots (Nature's Grasp) R2
    [19973] = "root", -- Entangling Roots (Nature's Grasp) R3
    [19972] = "root", -- Entangling Roots (Nature's Grasp) R4
    [19971] = "root", -- Entangling Roots (Nature's Grasp) R5
    [19970] = "root", -- Entangling Roots (Nature's Grasp) R6
    [27010] = "root", -- Entangling Roots (Nature's Grasp) R7
    [53313] = "root", -- Entangling Roots (Nature's Grasp) R8
    [50245] = "root", -- Pin (Krabben-Pet) R1
    [53544] = "root", -- Pin R2
    [53545] = "root", -- Pin R3
    [53546] = "root", -- Pin R4
    [53547] = "root", -- Pin R5
    [53548] = "root", -- Pin R6
    [122]   = "root", -- Frost Nova R1
    [865]   = "root", -- Frost Nova R2
    [6131]  = "root", -- Frost Nova R3
    [10230] = "root", -- Frost Nova R4
    [27088] = "root", -- Frost Nova R5
    [42917] = "root", -- Frost Nova R6
    [33395] = "root", -- Freeze (Wasserelementar)
    [64695] = "root", -- Earthgrab (Storm, Earth and Fire / Earthbind-Totem)
    [63685] = "root", -- Freeze (Frozen Power / Frost Shock)
    [39965] = "root", -- Frost Grenade (Gegenstand)
    [55536] = "root", -- Frostweave Net (Gegenstand)
    -- Chains of Ice (45524) ist ein Snare ohne DR -> absichtlich NICHT enthalten.

    -------------------------------------------------------------------------
    -- ROOT (Zufalls-/Proc-Roots, in 3.3.5a eigene Kategorie "rndroot"; siehe DR_RANDOM)
    -------------------------------------------------------------------------
    [12494] = "root", -- Frostbite
    [55080] = "root", -- Shattered Barrier
    [23694] = "root", -- Improved Hamstring
    [58373] = "root", -- Glyph of Hamstring
    [47168] = "root", -- Improved Wing Clip

    -------------------------------------------------------------------------
    -- ENTRAPMENT (eigene Kategorie in DRData-1.0 / TrinityCore 3.3.5)
    -------------------------------------------------------------------------
    [19185] = "entrapment", -- Entrapment R1
    [64803] = "entrapment", -- Entrapment R2
    [64804] = "entrapment", -- Entrapment R3

    -------------------------------------------------------------------------
    -- CYCLONE / BANISH / SLEEP / CHARGE / MIND CONTROL
    -------------------------------------------------------------------------
    [33786] = "cyclone", -- Cyclone
    [710]   = "banish",  -- Banish R1
    [18647] = "banish",  -- Banish R2
    [2637]  = "sleep",   -- Hibernate R1
    [18657] = "sleep",   -- Hibernate R2
    [18658] = "sleep",   -- Hibernate R3
    [7922]  = "charge",  -- Charge Stun
    [605]   = "mc",      -- Mind Control R1 (3.3.5a: ein Rang, 605)
    [10911] = "mc",      -- Mind Control (alter Rang) -- unsicher
    [10912] = "mc",      -- Mind Control (alter Rang) -- unsicher
    [13181] = "mc",      -- Gnomish Mind Control Cap
    [67799] = "mc",      -- Mind Amplification Dish

    -------------------------------------------------------------------------
    -- DISARM
    -------------------------------------------------------------------------
    [676]   = "disarm", -- Disarm (Krieger)
    [51722] = "disarm", -- Dismantle
    [53359] = "disarm", -- Chimera Shot - Scorpid
    [50541] = "disarm", -- Snatch (Vogel-Pet) R1
    [53537] = "disarm", -- Snatch R2
    [53538] = "disarm", -- Snatch R3
    [53540] = "disarm", -- Snatch R4
    [53542] = "disarm", -- Snatch R5
    [53543] = "disarm", -- Snatch R6
    [64058] = "disarm", -- Psychic Horror (Disarm-Effekt)
    [64346] = "disarm", -- Fiery Payback
}

-- Zufalls-/Proc-Effekte, die in 3.3.5a eine EIGENE DR-Kategorie (rndstun / rndroot) haben.
-- Wer stun/root getrennt tracken will, kann hiermit aufsplitten.
local DR_RANDOM = {
    [16922] = "rndstun", [28445] = "rndstun", [12355] = "rndstun", [20170] = "rndstun",
    [39796] = "rndstun", [12798] = "rndstun", [5530] = "rndstun", [15283] = "rndstun",
    [56] = "rndstun", [34510] = "rndstun",
    [12494] = "rndroot", [55080] = "rndroot", [23694] = "rndroot", [58373] = "rndroot",
    [47168] = "rndroot",
}

-- Kategorienamen deDE / enUS + repräsentative Icon-Spell-ID (für GetSpellTexture)
local DR_CATEGORY_NAMES = {
    stun         = { de = "Betäubung",           en = "Stun",            icon = 408   }, -- Kidney Shot
    cheapshot    = { de = "Fieser Trick/Anspringen", en = "Cheap Shot/Pounce", icon = 1833 }, -- Cheap Shot
    fear         = { de = "Furcht",              en = "Fear",            icon = 5782  }, -- Fear
    horror       = { de = "Grauen",              en = "Horror",          icon = 6789  }, -- Death Coil
    incapacitate = { de = "Handlungsunfähig",    en = "Incapacitate",    icon = 118   }, -- Polymorph
    disorient    = { de = "Desorientiert",       en = "Disorient",       icon = 19503 }, -- Scatter Shot
    silence      = { de = "Stille",              en = "Silence",         icon = 15487 }, -- Silence
    root         = { de = "Bewegungsunfähig",    en = "Root",            icon = 339   }, -- Entangling Roots
    entrapment   = { de = "Umklammern",          en = "Entrapment",      icon = 19184 }, -- Entrapment (Talent)
    cyclone      = { de = "Wirbelsturm",         en = "Cyclone",         icon = 33786 }, -- Cyclone
    banish       = { de = "Verbannen",           en = "Banish",          icon = 710   }, -- Banish
    sleep        = { de = "Winterschlaf",        en = "Sleep",           icon = 2637  }, -- Hibernate
    charge       = { de = "Sturmangriff",        en = "Charge",          icon = 100   }, -- Charge
    disarm       = { de = "Entwaffnen",          en = "Disarm",          icon = 676   }, -- Disarm
    mc           = { de = "Gedankenkontrolle",   en = "Mind Control",    icon = 605   }, -- Mind Control
}

-- ============================================================================
-- 2. WICHTIGE RAID-/DUNGEON-NPCs (Adds)
-- ============================================================================
-- Quelle: Wowhead WotLK-Datenbank (NPC-Tooltips, Locale enUS + deDE), 2026-10-26 abgefragt.
-- Format: { "enUS Name", "deDE Name", "ZONE", prio, npcId }
--   prio 1 = sofort töten / unterbrechen / kiten;  prio 2 = wichtig
--   ZONE: NAXX, OS, EOE, VOA, ULD, TOC, ONY, ICC, RS, FOS, POS, HOR
-- deDE-Namen wurden per Wowhead-deDE-Tooltip verifiziert, sofern nicht "-- unsicher".
local RAID_NPCS = {
    -- Icecrown Citadel (ICC)
    { "Val'kyr Shadowguard",      "Schattenwächterin der Val'kyr",   "ICC", 1, 36609 },
    { "Blood Beast",              "Blutbestie",                      "ICC", 1, 38508 },
    { "Kinetic Bomb",             "Kinetische Bombe",                "ICC", 1, 38454 },
    { "Dark Nucleus",             "Dunkler Kern",                    "ICC", 1, 38369 },
    { "Volatile Ooze",            "Flüchtiger Schlamm",              "ICC", 1, 37697 },
    { "Gas Cloud",                "Gaswolke",                        "ICC", 1, 37562 },
    { "Bone Spike",               "Knochenstachel",                  "ICC", 1, 38711 },
    { "Vile Spirit",              "Widerwärtiger Geist",             "ICC", 1, 37799 },
    { "Raging Spirit",            "Tobender Geist",                  "ICC", 1, 36701 },
    { "Ice Sphere",               "Eissphäre",                       "ICC", 1, 36633 },
    { "Shambling Horror",         "Torkelnder Schrecken",            "ICC", 1, 37698 },
    { "Drudge Ghoul",             "Ghulsklave",                      "ICC", 2, 37695 },
    { "Spirit Warden",            "Geisteraufseher",                 "ICC", 1, 36824 },
    { "Wicked Spirit",            "Boshafter Geist",                 "ICC", 2, 39190 },
    { "Empowered Adherent",       "Machterfüllter Kultist",          "ICC", 1, 38136 },
    { "Reanimated Fanatic",       "Wiederbelebter Fanatiker",        "ICC", 2, 38009 },
    { "Reanimated Adherent",      "Wiederbelebter Kultist",          "ICC", 2, 38010 },
    { "Cult Fanatic",             "Fanatischer Kultist",             "ICC", 2, 37890 },
    { "Cult Adherent",            "Treuer Kultist",                  "ICC", 1, 37949 },
    { "Deformed Fanatic",         "Deformierter Fanatiker",          "ICC", 1, 38135 },
    { "Little Ooze",              "Kleiner Schlamm",                 "ICC", 2, 36897 },
    { "Big Ooze",                 "Großer Schlamm",                  "ICC", 2, 36899 },
    { "Mutated Abomination",      "Mutierte Monstrosität",           "ICC", 2, 37672 },
    { "Blazing Skeleton",         "Loderndes Skelett",               "ICC", 1, 36791 },
    { "Suppresser",               "Unterdrücker",                    "ICC", 1, 37863 },
    { "Blistering Zombie",        "Mörderischer Zombie",             "ICC", 2, 37934 },
    { "Gluttonous Abomination",   "Gefräßige Monstrosität",          "ICC", 2, 37886 },
    { "Risen Archmage",           "Auferstandener Erzmagier",        "ICC", 1, 37868 },
    { "Rot Worm",                 "Faulwurm",                        "ICC", 2, 37907 },
    { "Mana Void",                "Manaleere",                       "ICC", 2, 38068 },
    { "Ice Tomb",                 "Eisgrab",                         "ICC", 1, 36980 },
    { "Kor'kron Battle-Mage",     "Kriegsmagier der Kor'kron",       "ICC", 1, 37117 },
    { "Skybreaker Sorcerer",      "Zauberer der Himmelsbrecher",     "ICC", 1, 37116 },
    { "Kor'kron Axethrower",      "Axtwerfer der Kor'kron",          "ICC", 2, 36968 },
    { "Skybreaker Rifleman",      "Scharfschütze der Himmelsbrecher","ICC", 2, 36969 },
    { "Kor'kron Rocketeer",       "Raketenschütze der Kor'kron",     "ICC", 2, 36982 },
    { "Skybreaker Mortar Soldier","Mörsersoldat der Himmelsbrecher", "ICC", 2, 36978 },
    { "Nerub'ar Broodkeeper",     "Bruthüter der Nerub'ar",          "ICC", 1, 36725 },
    { "Deathbound Ward",          "Todesgeweihter Wächter",          "ICC", 2, 37007 },

    -- Ruby Sanctum (RS)
    { "Combustion",               "Verbrennung",                     "RS", 1, 40001 },
    { "Consumption",              "Verzehrung",                      "RS", 1, 40135 },
    { "Living Inferno",           "Lebendiges Inferno",              "RS", 1, 40681 },
    { "Living Ember",             "Lebendiger Funken",               "RS", 2, 40683 },
    { "Onyx Flamecaller",         "Onyxflammenrufer",                "RS", 1, 39814 },
    { "Shadow Orb",               "Schattenkugel",                   "RS", 2, 40083 },

    -- Trial of the Crusader (TOC)
    { "Snobold Vassal",           "Schneeboldvasall",                "TOC", 1, 34800 },
    { "Mistress of Pain",         "Herrin der Schmerzen",            "TOC", 1, 34826 },
    { "Felflame Infernal",        "Teuflische Höllenbestie",         "TOC", 1, 34815 },
    { "Nether Portal",            "Netherportal",                    "TOC", 1, 34825 },
    { "Infernal Volcano",         "Höllischer Vulkan",               "TOC", 1, 34813 },
    { "Nerubian Burrower",        "Nerubischer Gräber",              "TOC", 1, 34607 },
    { "Swarm Scarab",             "Schwarmskarabäus",                "TOC", 2, 34605 },
    { "Frost Sphere",             "Frostsphäre",                     "TOC", 2, 34606 },
    { "Concentrated Light",       "Konzentriertes Licht",            "TOC", 2, 34630 },
    { "Concentrated Darkness",    "Konzentrierte Nacht",             "TOC", 2, 34628 },
    -- Fraktionschampions: Heiler (Horde-Team, gegen Allianz)
    { "Liandra Suncaller",        "Liandra Sonnenrufer",             "TOC", 1, 34445 }, -- Heilig-Paladin
    { "Caiphus the Stern",        "Caiphus der Ernste",              "TOC", 1, 34447 }, -- Disziplin-Priester
    { "Broln Stouthorn",          "Broln Starkhorn",                 "TOC", 1, 34455 }, -- Wiederherstellungs-Schamane
    { "Erin Misthoof",            "Erin Nebelhuf",                   "TOC", 1, 34459 }, -- Wiederherstellungs-Druide
    -- Fraktionschampions: Heiler (Allianz-Team, gegen Horde)
    { "Velanaa",                  "Velanaa",                         "TOC", 1, 34465 }, -- Heilig-Paladin
    { "Anthar Forgemender",       "Anthar Schmiedenformer",          "TOC", 1, 34466 }, -- Disziplin-Priester
    { "Saamul",                   "Saamul",                          "TOC", 1, 34470 }, -- Wiederherstellungs-Schamane
    { "Melador Valestrider",      "Melador Talwanderer",             "TOC", 1, 34469 }, -- Wiederherstellungs-Druide
    { "Brienna Nightfell",        "Brienna Tiefnacht",               "TOC", 2, 34473 }, -- Schatten-Priester
    { "Thrakgar",                 "Thrakgar",                        "TOC", 2, 34444 }, -- Verstärker-Schamane

    -- Ulduar (ULD)
    { "Iron Construct",           "Eisernes Konstrukt",              "ULD", 1, 33121 },
    { "Dark Rune Guardian",       "Dunkler Runenwächter",            "ULD", 2, 33388 },
    { "Dark Rune Watcher",        "Dunkler Runenbetrachter",         "ULD", 1, 33453 }, -- Kettenblitz unterbrechen
    { "Dark Rune Sentinel",       "Dunkle Runenschildwache",         "ULD", 2, 33846 },
    { "Heart of the Deconstructor","Herz des Dekonstruktors",        "ULD", 1, 33329 },
    { "XS-013 Scrapbot",          "XS-013 Schrottbot",               "ULD", 1, 33343 },
    { "XM-024 Pummeller",         "XM-024 Verprügler",               "ULD", 2, 33344 },
    { "XE-321 Boombot",           "XE-321 Bummbot",                  "ULD", 1, 33346 },
    { "Right Arm",                "Rechter Arm",                     "ULD", 1, 32934 },
    { "Rubble",                   "Geröll",                          "ULD", 2, 33768 },
    { "Sanctum Sentry",           "Späher des Sanktums",             "ULD", 2, 34014 },
    { "Feral Defender",           "Wilder Verteidiger",              "ULD", 1, 34035 },
    { "Flash Freeze",             "Blitzeis",                        "ULD", 1, 32926 },
    { "Runic Colossus",           "Runenverzierter Koloss",          "ULD", 2, 32872 },
    { "Ancient Rune Giant",       "Uralter Runengigant",             "ULD", 2, 32873 },
    { "Dark Rune Acolyte",        "Dunkler Runenakolyt",             "ULD", 1, 32886 }, -- Heiler, unterbrechen
    { "Dark Rune Evoker",         "Dunkler Runenhervorrufer",        "ULD", 1, 32878 }, -- Heiler, unterbrechen
    { "Jormungar Behemoth",       "Jormungarungetüm",                "ULD", 2, 32882 },
    { "Ancient Conservator",      "Uralter Konservator",             "ULD", 1, 33203 },
    { "Detonating Lasher",        "Explodierender Peitscher",        "ULD", 1, 32918 },
    { "Ancient Water Spirit",     "Uralter Wassergeist",             "ULD", 2, 33202 },
    { "Storm Lasher",             "Sturmpeitscher",                  "ULD", 2, 32919 },
    { "Snaplasher",               "Knallpeitscher",                  "ULD", 2, 32916 },
    { "Eonar's Gift",             "Eonars Geschenk",                 "ULD", 1, 33228 },
    { "Assault Bot",              "Angriffsbot",                     "ULD", 1, 34057 },
    { "Bomb Bot",                 "Bombenbot",                       "ULD", 1, 33836 },
    { "Junk Bot",                 "Schrottbot",                      "ULD", 2, 33855 },
    { "Emergency Fire Bot",       "Notfallfeuerbot",                 "ULD", 2, 34147 },
    { "Saronite Animus",          "Saronitanimus",                   "ULD", 1, 33524 },
    { "Saronite Vapors",          "Saronitdämpfe",                   "ULD", 2, 33488 },
    { "Guardian of Yogg-Saron",   "Wächter des Yogg-Saron",          "ULD", 1, 33136 },
    { "Crusher Tentacle",         "Schmettertentakel",               "ULD", 1, 33966 },
    { "Constrictor Tentacle",     "Würgetentakel",                   "ULD", 1, 33983 },
    { "Corruptor Tentacle",       "Verderbertentakel",               "ULD", 1, 33985 },
    { "Immortal Guardian",        "Unvergängliche Wache",            "ULD", 2, 33988 },
    { "Brain of Yogg-Saron",      "Yogg-Sarons Gehirn",              "ULD", 2, 33890 },
    { "Ominous Cloud",            "Ominöse Wolke",                   "ULD", 2, 33292 },
    { "Collapsing Star",          "Kollabierender Stern",            "ULD", 1, 32955 },
    { "Living Constellation",     "Lebendige Konstellation",         "ULD", 1, 33052 },
    { "Dark Matter",              "Dunkle Materie",                  "ULD", 2, 33089 },

    -- Naxxramas (NAXX)
    { "Crypt Guard",              "Gruftwache",                      "NAXX", 1, 16573 },
    { "Corpse Scarab",            "Leichenskarabäus",                "NAXX", 2, 16698 },
    { "Naxxramas Worshipper",     "Jünger von Naxxramas",            "NAXX", 1, 16506 }, -- Mind Control / Opfer
    { "Naxxramas Follower",       "Anhänger von Naxxramas",          "NAXX", 2, 16505 },
    { "Plagued Warrior",          "Verseuchter Krieger",             "NAXX", 2, 16984 },
    { "Plagued Champion",         "Verseuchter Champion",            "NAXX", 2, 16983 },
    { "Plagued Guardian",         "Verseuchter Wächter",             "NAXX", 1, 16981 },
    { "Spore",                    "Spore",                           "NAXX", 2, 16286 },
    { "Death Knight Understudy",  "Reservist der Todesritter",       "NAXX", 1, 16803 },
    { "Unrelenting Trainee",      "Unerbittlicher Lehrling",         "NAXX", 2, 16124 },
    { "Unrelenting Deathknight",  "Unerbittlicher Todesritter",      "NAXX", 2, 16125 },
    { "Unrelenting Rider",        "Unerbittlicher Reiter",           "NAXX", 2, 16126 },
    { "Zombie Chow",              "Zombiefraß",                      "NAXX", 1, 16360 },
    { "Soldier of the Frozen Wastes","Soldat der Eisigen Weiten",    "NAXX", 2, 16427 },
    { "Unstoppable Abomination",  "Unaufhaltsame Monstrosität",      "NAXX", 1, 16428 },
    { "Soul Weaver",              "Seelenwirker",                    "NAXX", 1, 16429 },
    { "Guardian of Icecrown",     "Wächter von Eiskrone",            "NAXX", 1, 16441 },

    -- Obsidian Sanctum (OS)
    { "Twilight Whelp",           "Zwielichtwelpe",                  "OS", 2, 30890 },
    { "Acolyte of Shadron",       "Akolyt von Shadron",              "OS", 1, 31218 },
    { "Acolyte of Vesperon",      "Akolyt von Vesperon",             "OS", 1, 31219 },
    { "Lava Blaze",               "Lavaflamme",                      "OS", 2, 30643 },

    -- Onyxia's Lair (ONY)
    { "Onyxian Whelp",            "Welpe von Onyxia",                "ONY", 2, 11262 },
    { "Onyxian Lair Guard",       "Wache von Onyxias Hort",          "ONY", 1, 36561 },

    -- Vault of Archavon (VOA)
    { "Tempest Minion",           "Sturmdiener",                     "VOA", 1, 33998 },
    { "Frozen Orb",               "Gefrorene Kugel",                 "VOA", 1, 38456 },

    -- ICC-5er: Forge of Souls (FOS), Pit of Saron (POS), Halls of Reflection (HOR)
    { "Corrupted Soul Fragment",  "Korrumpiertes Seelenfragment",    "FOS", 1, 36535 },
    { "Deathwhisper Necrolyte",   "Nekrolyt der Todesflüsterer",     "POS", 1, 36788 },
    { "Ymirjar Deathbringer",     "Todesbringer der Ymirjar",        "POS", 1, 36892 },
    { "Ymirjar Flamebearer",      "Flammenträger der Ymirjar",       "POS", 1, 36893 },
    { "Ghostly Priest",           "Geisterhafter Priester",          "HOR", 1, 38175 },
    { "Phantom Mage",             "Phantomhafter Magier",            "HOR", 1, 38172 },
    { "Shadowy Mercenary",        "Schattenhafter Söldner",          "HOR", 2, 38177 },
    { "Spectral Footman",         "Spektraler Fußsoldat",            "HOR", 2, 38173 },
    { "Tortured Rifleman",        "Gequälter Scharfschütze",         "HOR", 2, 38176 },
    { "Raging Ghoul",             "Tobender Ghul",                   "HOR", 2, 36940 },
    { "Risen Witch Doctor",       "Auferstandener Hexendoktor",      "HOR", 1, 36941 },
    { "Lumbering Abomination",    "Schwerfällige Monstrosität",      "HOR", 1, 37069 },
}

-- ============================================================================
-- 3. SCHLACHTFELD-FLAGGEN / ORBS (Aura-IDs auf dem Träger)
-- ============================================================================
-- Quelle: Wowhead WotLK Spell-Tooltips 23333 / 23335 / 34976 / 46392 / 46393.
-- Alterac Valley und Arathi Basin haben keine Träger-Auren.
local FLAG_AURAS = {
    [23333] = "WSG_H",   -- Warsong Flag: Horde-Flagge, getragen von einem Allianz-Spieler
    [23335] = "WSG_A",   -- Silverwing Flag: Allianz-Flagge, getragen von einem Horde-Spieler
    [34976] = "EOTS",    -- Netherstorm Flag (Eye of the Storm), fraktionsneutral
    [46392] = "FOCUSED_ASSAULT", -- Focused Assault (Flaggenträger-Debuff nach 3 Min, seit 3.2)
    [46393] = "BRUTAL_ASSAULT",  -- Brutal Assault (Flaggenträger-Debuff nach 6 Min, seit 3.2)
}

-- ============================================================================
-- 4. TOTEM-DAUERN (Sekunden) je Totem-Zauber-ID, Schamane 3.3.5a
-- ============================================================================
-- Quelle: Wowhead WotLK Spell-Tooltips (Searing R1/R4/R6/R7/R8 = 30/45/55/60/60, Magma 20,
-- Stoneclaw 15, Earthbind 45, Mana Tide 12, Cleansing 300 geprüft); Rang-IDs aus Wowhead.
-- Fire Nova Totem existiert in 3.3.5a nicht mehr (seit 3.3.0 Zauber "Fire Nova").
-- Grace of Air, Windwall, Tranquil Air, Poison/Disease Cleansing wurden in 3.0/3.1 entfernt.
local TOTEM_DURATION = {
    -- Erde
    [2484]  = 45,  -- Earthbind Totem
    [8143]  = 300, -- Tremor Totem
    [2062]  = 120, -- Earth Elemental Totem
    [5730]  = 15,  -- Stoneclaw Totem R1
    [6390]  = 15,  -- Stoneclaw Totem R2
    [6391]  = 15,  -- Stoneclaw Totem R3
    [6392]  = 15,  -- Stoneclaw Totem R4
    [10427] = 15,  -- Stoneclaw Totem R5
    [10428] = 15,  -- Stoneclaw Totem R6
    [25525] = 15,  -- Stoneclaw Totem R7
    [58580] = 15,  -- Stoneclaw Totem R8
    [58581] = 15,  -- Stoneclaw Totem R9
    [58582] = 15,  -- Stoneclaw Totem R10
    [8071]  = 300, -- Stoneskin Totem R1
    [8154]  = 300, -- Stoneskin Totem R2
    [8155]  = 300, -- Stoneskin Totem R3
    [10406] = 300, -- Stoneskin Totem R4
    [10407] = 300, -- Stoneskin Totem R5
    [10408] = 300, -- Stoneskin Totem R6
    [25508] = 300, -- Stoneskin Totem R7
    [25509] = 300, -- Stoneskin Totem R8
    [58751] = 300, -- Stoneskin Totem R9
    [58753] = 300, -- Stoneskin Totem R10
    [8075]  = 300, -- Strength of Earth Totem R1
    [8160]  = 300, -- Strength of Earth Totem R2
    [8161]  = 300, -- Strength of Earth Totem R3
    [10442] = 300, -- Strength of Earth Totem R4
    [25361] = 300, -- Strength of Earth Totem R5
    [25528] = 300, -- Strength of Earth Totem R6
    [57622] = 300, -- Strength of Earth Totem R7
    [58643] = 300, -- Strength of Earth Totem R8
    -- Feuer
    [2894]  = 120, -- Fire Elemental Totem
    [3599]  = 30,  -- Searing Totem R1
    [6363]  = 35,  -- Searing Totem R2
    [6364]  = 40,  -- Searing Totem R3
    [6365]  = 45,  -- Searing Totem R4
    [10437] = 50,  -- Searing Totem R5
    [10438] = 55,  -- Searing Totem R6
    [25533] = 60,  -- Searing Totem R7
    [58699] = 60,  -- Searing Totem R8
    [58703] = 60,  -- Searing Totem R9
    [58704] = 60,  -- Searing Totem R10
    [8190]  = 20,  -- Magma Totem R1
    [10585] = 20,  -- Magma Totem R2
    [10586] = 20,  -- Magma Totem R3
    [10587] = 20,  -- Magma Totem R4
    [25552] = 20,  -- Magma Totem R5
    [58731] = 20,  -- Magma Totem R6
    [58734] = 20,  -- Magma Totem R7
    [8227]  = 300, -- Flametongue Totem R1
    [8249]  = 300, -- Flametongue Totem R2
    [10526] = 300, -- Flametongue Totem R3
    [16387] = 300, -- Flametongue Totem R4
    [25557] = 300, -- Flametongue Totem R5
    [58649] = 300, -- Flametongue Totem R6
    [58652] = 300, -- Flametongue Totem R7
    [58656] = 300, -- Flametongue Totem R8
    [8181]  = 300, -- Frost Resistance Totem R1
    [10478] = 300, -- Frost Resistance Totem R2
    [10479] = 300, -- Frost Resistance Totem R3
    [25560] = 300, -- Frost Resistance Totem R4
    [58741] = 300, -- Frost Resistance Totem R5
    [58745] = 300, -- Frost Resistance Totem R6
    [30706] = 300, -- Totem of Wrath R1
    [57720] = 300, -- Totem of Wrath R2
    [57721] = 300, -- Totem of Wrath R3
    [57722] = 300, -- Totem of Wrath R4
    -- Wasser
    [16190] = 12,  -- Mana Tide Totem
    [8170]  = 300, -- Cleansing Totem
    [5394]  = 300, -- Healing Stream Totem R1
    [6375]  = 300, -- Healing Stream Totem R2
    [6377]  = 300, -- Healing Stream Totem R3
    [10462] = 300, -- Healing Stream Totem R4
    [10463] = 300, -- Healing Stream Totem R5
    [25567] = 300, -- Healing Stream Totem R6
    [58755] = 300, -- Healing Stream Totem R7
    [58756] = 300, -- Healing Stream Totem R8
    [58757] = 300, -- Healing Stream Totem R9
    [5675]  = 300, -- Mana Spring Totem R1
    [10495] = 300, -- Mana Spring Totem R2
    [10496] = 300, -- Mana Spring Totem R3
    [10497] = 300, -- Mana Spring Totem R4
    [25570] = 300, -- Mana Spring Totem R5
    [58774] = 300, -- Mana Spring Totem R6
    [58775] = 300, -- Mana Spring Totem R7
    [58776] = 300, -- Mana Spring Totem R8
    [8184]  = 300, -- Fire Resistance Totem R1
    [10537] = 300, -- Fire Resistance Totem R2
    [10538] = 300, -- Fire Resistance Totem R3
    [25563] = 300, -- Fire Resistance Totem R4
    [58737] = 300, -- Fire Resistance Totem R5
    [58739] = 300, -- Fire Resistance Totem R6
    -- Luft
    [8177]  = 45,  -- Grounding Totem
    [8512]  = 300, -- Windfury Totem
    [3738]  = 300, -- Wrath of Air Totem
    [6495]  = 300, -- Sentry Totem
    [10595] = 300, -- Nature Resistance Totem R1
    [10600] = 300, -- Nature Resistance Totem R2
    [10601] = 300, -- Nature Resistance Totem R3
    [25574] = 300, -- Nature Resistance Totem R4
    [58746] = 300, -- Nature Resistance Totem R5
    [58749] = 300, -- Nature Resistance Totem R6
}

-- ============================================================================
-- 5. ZAUBERSPERRE / UNTERBRECHUNG (Lockout-Dauer in Sekunden) 3.3.5a
-- ============================================================================
-- Quelle: Spell-Tooltips 3.3.5a (Wowhead WotLK), DRList-1.0 Silence-IDs, Patchnotes 3.0.8.
-- Enthält sowohl die Unterbrechungs-Zauber selbst (SPELL_INTERRUPT im Kampflog) als auch die
-- Silence-Auren (SPELL_AURA_APPLIED). Earth Shock unterbricht seit 3.0 NICHT mehr.
local INTERRUPT_LOCKOUT = {
    -- Zauber, die unterbrechen (Schul-Lockout)
    [1766]  = 5, -- Kick (Schurke; in 3.x nur noch ein Rang)
    [6552]  = 4, -- Pummel (Krieger)
    [72]    = 6, -- Shield Bash (Krieger)
    [2139]  = 8, -- Counterspell (Magier)
    [47528] = 4, -- Mind Freeze (Todesritter)
    [57994] = 2, -- Wind Shear (Schamane)
    [19244] = 5, -- Spell Lock R1 (Teufelsjäger) - Lockout 5 s, Stille 3 s
    [19647] = 6, -- Spell Lock R2 (Teufelsjäger) - Lockout 6 s, Stille 3 s
    [16979] = 4, -- Feral Charge - Bear (Druide; unterbricht + Lockout 4 s)
    -- Silence-Auren (Dauer der Stille)
    [34490] = 3, -- Silencing Shot (Jäger)
    [47476] = 5, -- Strangulate (Todesritter)
    [15487] = 5, -- Silence (Priester)
    [28730] = 2, -- Arcane Torrent (Mana)
    [25046] = 2, -- Arcane Torrent (Energie)
    [50613] = 2, -- Arcane Torrent (Runenmacht)
    [24259] = 3, -- Spell Lock (Silence-Aura)
    [31117] = 5, -- Unstable Affliction (Dispel-Silence)
    [1330]  = 3, -- Garrote - Silence
    [18498] = 3, -- Silenced - Gag Order (Shield Bash / Heroic Throw)
    [74347] = 3, -- Silenced - Gag Order (Heroic Throw) -- unsicher
    [18425] = 2, -- Silenced - Improved Kick
    [18469] = 4, -- Silenced - Improved Counterspell R1 (3.3.5a: beide Ränge 4 s)
    [55021] = 4, -- Silenced - Improved Counterspell R2
    [63529] = 3, -- Silenced - Shield of the Templar (Avenger's Shield)
    [53588] = 2, -- Nether Shock (Netherrochen-Pet) R1
    [53589] = 2, -- Nether Shock R2
}

-- ============================================================================
-- 6. DISPELBARE DEBUFF-TYPEN PRO KLASSE (3.3.5a, freundliche Ziele)
-- ============================================================================
-- Quelle: Klassenzauber 3.3.5a (Wowhead WotLK): Dispel Magic 527/988, Cure Disease 528,
-- Abolish Disease 552, Mass Dispel 32375, Cleanse 4987, Purify 1152, Cure Toxins 526 (seit 3.2
-- zusammengelegt), Cleanse Spirit 51886 (Talent), Remove Curse 475 (Magier) / 2782 (Druide),
-- Cure Poison 8946, Abolish Poison 2893, Devour Magic 19505 (Teufelsjäger).
local DISPEL = {
    PRIEST      = { Magic = true, Disease = true },
    PALADIN     = { Magic = true, Disease = true, Poison = true },
    SHAMAN      = { Disease = true, Poison = true },                 -- Curse nur mit Talent Cleanse Spirit (Resto, 51886)
    DRUID       = { Curse = true, Poison = true },
    MAGE        = { Curse = true },
    WARLOCK     = { Magic = true },                                  -- nur per Teufelsjäger "Devour Magic" (Pet-Zauber)
    HUNTER      = {},
    ROGUE       = {},
    WARRIOR     = {},
    DEATHKNIGHT = {},
}

-- Talente/Spezialfälle, die das Dispel-Set erweitern (zur Laufzeit per Talentabfrage ergänzen)
local DISPEL_TALENTS = {
    SHAMAN = { spellId = 51886, adds = { Curse = true }, note = "Cleanse Spirit (Wiederherstellung, Tier 7) ersetzt Cure Toxins und entfernt zusätzlich Flüche" },
    PRIEST = { spellId = 64129, adds = {}, note = "Body and Soul (Disc): Abolish Disease auf sich selbst entfernt zusätzlich Gifte" },
}

-- Offensive Dispels (gegnerische Buffs entfernen), zur Vollständigkeit
local DISPEL_OFFENSIVE = {
    PRIEST  = { spellId = 527,   types = { Magic = true } },             -- Dispel Magic (R1 527, R2 988)
    SHAMAN  = { spellId = 370,   types = { Magic = true } },             -- Purge (R1 370, R2 8012)
    MAGE    = { spellId = 30449, types = { Magic = true } },             -- Spellsteal
    WARLOCK = { spellId = 19505, types = { Magic = true } },             -- Devour Magic (Teufelsjäger)
    HUNTER  = { spellId = 19801, types = { Magic = true, Enrage = true } }, -- Tranquilizing Shot (3.x: 1 Magie + 1 Wutanfall)
}

-- ============================================================================
-- Export in den Addon-Namensraum
-- ============================================================================
ns.DR_SPELLS = DR_SPELLS
ns.DR_RANDOM = DR_RANDOM
ns.DR_RESET = DR_RESET
ns.DR_CATEGORY_NAMES = DR_CATEGORY_NAMES
ns.RAID_NPCS = RAID_NPCS
ns.TOTEM_DURATION = TOTEM_DURATION
ns.LOCKOUTS = INTERRUPT_LOCKOUT
ns.DISPEL = DISPEL
ns.DISPEL_TALENTS = DISPEL_TALENTS
ns.DISPEL_OFFENSIVE = DISPEL_OFFENSIVE

-- Flaggen: Aura -> welche Flagge getragen wird (für Icon und Farbe)
ns.FLAG_AURAS = {}
local FLAG_SIDE = { WSG_H = "HORDE", WSG_A = "ALLIANCE", EOTS = "NEUTRAL" }
for id, key in pairs(FLAG_AURAS) do
	if FLAG_SIDE[key] then ns.FLAG_AURAS[id] = FLAG_SIDE[key] end
end
ns.FLAG_ASSAULT = { [46392] = 1, [46393] = 2 } -- Fokussierter / Brutaler Angriff (Träger-Debuffs)

-- PvP-Schmuck: [Spell-ID] = Cooldown in Sekunden
ns.TRINKETS = {
	[42292] = 120,  -- PvP-Schmuck (Medaillon)
	[59752] = 120,  -- Jeder Mann für sich (Mensch)
	[7744] = 120,   -- Wille der Verlassenen
}
