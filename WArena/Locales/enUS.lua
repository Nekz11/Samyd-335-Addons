-- WArena: strings (English only for now, but kept in one place)
local _, ns = ...

local L = setmetatable({}, { __index = function(t, k) rawset(t, k, k) return k end })
ns.L = L

L["loaded"] = "loaded – type /warena for options."
L["Not possible in combat."] = "Not possible in combat."
L["Not available inside an arena."] = "Not available inside an arena."
L["Interrupted"] = "Interrupted"
L["Interrupted: %s"] = "Interrupted: %s"
L["Dead"] = "Dead"
L["Arena %d"] = "Arena %d"
L["Boss %d"] = "Boss %d"
L["drag to move"] = "drag to move"

-- announcements
L["ANN_TRINKET"] = "%s used trinket!"
L["ANN_TRINKET_READY"] = "%s trinket ready!"
L["ANN_RACIAL"] = "%s used %s!"
L["ANN_DRINK"] = "%s is drinking!"
L["ANN_LOWHP"] = "%s low health (%d%%)!"
L["ANN_RESURRECT"] = "%s is resurrecting %s!"
L["ANN_SPEC"] = "%s is %s %s"
L["ANN_HEALER"] = "Healer: %s (%s)"
L["ANN_FLAG_PICKED"] = "%s picked up the flag!"
L["ANN_FLAG_DROPPED"] = "Flag dropped!"
L["ANN_ENEMY_TEAM"] = "Enemy team: %s"
L["ANN_SHADOWSIGHT"] = "Shadow Sight in %d s!"
L["ANN_SHADOWSIGHT_UP"] = "Shadow Sight is up!"
L["ANN_GATES"] = "Gates open!"

-- HUD
L["Preparation"] = "Preparation"
L["Shadow Sight"] = "Shadow Sight"
L["Match"] = "Match"

-- BG
L["Enemies"] = "Enemies"
L["list frozen in combat"] = "list frozen in combat"
L["Flag carrier"] = "Flag carrier"
L["Healer"] = "Healer"
