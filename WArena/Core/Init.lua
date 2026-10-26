-- WArena: core – namespace, event bus, module registry, saved variables, profiles, ticker
local ADDON, ns = ...

ns.name = ADDON
ns.version = (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or "2.0.0"
ns.MAX_ARENA = 5
ns.MAX_BOSS = 4

local L = ns.L
local tinsert, tremove, pairs, ipairs, type, next = table.insert, table.remove, pairs, ipairs, type, next
local GetTime, InCombatLockdown = GetTime, InCombatLockdown

---------------------------------------------------------------------------
-- chat output
---------------------------------------------------------------------------
function ns:Print(msg, ...)
	if select("#", ...) > 0 then msg = string.format(msg, ...) end
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99WArena|r: " .. tostring(msg))
end

function ns:Debug(msg, ...)
	if not (ns.db and ns.db.debug) then return end
	if select("#", ...) > 0 then msg = string.format(msg, ...) end
	DEFAULT_CHAT_FRAME:AddMessage("|cff999999WArena debug:|r " .. tostring(msg))
end

---------------------------------------------------------------------------
-- event bus (several handlers per event) + internal messages
---------------------------------------------------------------------------
local Core = CreateFrame("Frame", "WArenaCore", UIParent)
ns.Core = Core
local eventHandlers, msgHandlers = {}, {}

function ns:RegisterEvent(event, fn)
	local list = eventHandlers[event]
	if not list then
		list = {}
		eventHandlers[event] = list
		Core:RegisterEvent(event)
	end
	list[#list + 1] = fn
end

function ns:RegisterEvents(fn, ...)
	for i = 1, select("#", ...) do ns:RegisterEvent((select(i, ...)), fn) end
end

Core:SetScript("OnEvent", function(_, event, ...)
	local list = eventHandlers[event]
	if not list then return end
	for i = 1, #list do list[i](event, ...) end
end)

function ns:RegisterMessage(name, fn)
	local list = msgHandlers[name]
	if not list then list = {}; msgHandlers[name] = list end
	list[#list + 1] = fn
end

function ns:Fire(name, ...)
	local list = msgHandlers[name]
	if not list then return end
	for i = 1, #list do list[i](name, ...) end
end

---------------------------------------------------------------------------
-- combat deferral
---------------------------------------------------------------------------
local deferred, deferredOrder = {}, {}

function ns:Defer(fn)
	if InCombatLockdown() then
		if not deferred[fn] then
			deferred[fn] = true
			deferredOrder[#deferredOrder + 1] = fn
		end
		return false
	end
	fn()
	return true
end

ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if #deferredOrder > 0 then
		local list = deferredOrder
		deferred, deferredOrder = {}, {}
		for i = 1, #list do list[i]() end
	end
	ns:Fire("COMBAT_ENDED")
end)

ns:RegisterEvent("PLAYER_REGEN_DISABLED", function() ns:Fire("COMBAT_STARTED") end)

---------------------------------------------------------------------------
-- single ticker (10 Hz) for all periodic work + one-shot timers
---------------------------------------------------------------------------
local tickers, timers = {}, {}
local tickAccum = 0

function ns:AddTicker(interval, fn, owner)
	local t = { interval = interval, fn = fn, next = GetTime() + interval, owner = owner }
	tickers[#tickers + 1] = t
	return t
end

function ns:RemoveTicker(t)
	for i = #tickers, 1, -1 do
		if tickers[i] == t then tremove(tickers, i) end
	end
end

function ns:After(delay, fn)
	local t = { at = GetTime() + delay, fn = fn }
	timers[#timers + 1] = t
	return t
end

function ns:CancelTimer(t)
	if t then t.cancelled = true end
end

Core:SetScript("OnUpdate", function(_, elapsed)
	tickAccum = tickAccum + elapsed
	if tickAccum < 0.1 then return end
	tickAccum = 0
	local now = GetTime()
	for i = 1, #tickers do
		local t = tickers[i]
		if t and now >= t.next then
			t.next = now + t.interval
			t.fn(now)
		end
	end
	for i = #timers, 1, -1 do
		local t = timers[i]
		if t.cancelled then
			tremove(timers, i)
		elseif now >= t.at then
			tremove(timers, i)
			t.fn()
		end
	end
end)

---------------------------------------------------------------------------
-- modules
---------------------------------------------------------------------------
ns.modules = {}
ns.M = {}

function ns:RegisterModule(name, mod)
	mod.name = name
	ns.modules[#ns.modules + 1] = mod
	ns.M[name] = mod
	return mod
end

function ns:NewModule(name)
	return ns:RegisterModule(name, {})
end

---------------------------------------------------------------------------
-- defaults (modules add their own keys while their file loads)
---------------------------------------------------------------------------
ns.defaults = {
	debug = false,
	migrated202 = false,
	locked = true,
	point = { "RIGHT", "UIParent", "RIGHT", -260, 120 },
}

function ns:AddDefaults(tbl)
	for k, v in pairs(tbl) do
		if ns.defaults[k] == nil then ns.defaults[k] = v end
	end
end

local function CopyValue(v)
	if type(v) ~= "table" then return v end
	local t = {}
	for k, x in pairs(v) do t[k] = CopyValue(x) end
	return t
end
ns.CopyValue = CopyValue

function ns:CopyTable(src)
	return CopyValue(src)
end

local function ApplyDefaults(profile)
	for k, v in pairs(ns.defaults) do
		if profile[k] == nil then
			profile[k] = CopyValue(v)
		elseif type(v) == "table" and type(profile[k]) == "table" and v.r ~= nil then
			-- color tables: fill missing channels
			for ck, cv in pairs(v) do if profile[k][ck] == nil then profile[k][ck] = cv end end
		end
	end
end

---------------------------------------------------------------------------
-- saved variables + profiles
---------------------------------------------------------------------------
ns.db, ns.global = nil, nil
local charKey

function ns:CharKey()
	if not charKey then
		local realm = GetRealmName and GetRealmName() or "Realm"
		local name = UnitName and UnitName("player") or "Player"
		charKey = name .. " - " .. realm
	end
	return charKey
end

function ns:ProfileNames()
	local out = {}
	if not WArenaDB or not WArenaDB.profiles then return out end
	for n in pairs(WArenaDB.profiles) do out[#out + 1] = n end
	table.sort(out)
	return out
end

function ns:CurrentProfileName()
	return WArenaDB.chars[ns:CharKey()] or "Default"
end

function ns:ActivateProfile(name, silent)
	if not WArenaDB.profiles[name] then
		WArenaDB.profiles[name] = {}
	end
	WArenaDB.chars[ns:CharKey()] = name
	ns.db = WArenaDB.profiles[name]
	ApplyDefaults(ns.db)
	if not ns.db.migrated202 then
		-- 2.0.0/2.0.1 shipped with range fade on and low opacities; frames were hard to see
		ns.db.migrated202 = true
		ns.db.indRange = false
		if (ns.db.rangeAlpha or 1) < 0.6 then ns.db.rangeAlpha = 0.6 end
		if (ns.db.unseenAlpha or 1) < 0.65 then ns.db.unseenAlpha = 0.65 end
	end
	if ns.initialized then
		for _, mod in ipairs(ns.modules) do
			if mod.OnProfileChanged then mod:OnProfileChanged() end
		end
		ns:Layout()
		ns:Fire("PROFILE_CHANGED", name)
		if not silent then ns:Print("Profile '%s' active.", name) end
	end
end

function ns:ResetProfile()
	local name = ns:CurrentProfileName()
	WArenaDB.profiles[name] = {}
	ns:ActivateProfile(name, true)
end

local function MigrateLegacy()
	-- WArena 1.x stored a flat table; move it into the Default profile once
	if WArenaDB.profiles then return end
	local legacy = {}
	for k, v in pairs(WArenaDB) do legacy[k] = v; WArenaDB[k] = nil end
	WArenaDB.profiles = { Default = legacy }
end

local function SetupDB()
	WArenaDB = WArenaDB or {}
	MigrateLegacy()
	WArenaDB.profiles = WArenaDB.profiles or { Default = {} }
	WArenaDB.chars = WArenaDB.chars or {}
	WArenaDB.global = WArenaDB.global or {}
	ns.global = WArenaDB.global
	ns.global.minimap = ns.global.minimap or { angle = 220, hide = false }
	ns.global.version = ns.version
	ns:ActivateProfile(ns:CurrentProfileName(), true)
end

---------------------------------------------------------------------------
-- settings
---------------------------------------------------------------------------
function ns:Get(key)
	return ns.db and ns.db[key]
end

function ns:Set(key, value)
	if not ns.db then return end
	ns.db[key] = value
	for _, mod in ipairs(ns.modules) do
		if mod.OnSettingChanged then mod:OnSettingChanged(key, value) end
	end
	ns:Fire("SETTING_CHANGED", key, value)
	ns:Layout()
end

function ns:SetColor(key, r, g, b, a)
	local c = ns.db[key]
	if type(c) ~= "table" then c = {}; ns.db[key] = c end
	c.r, c.g, c.b, c.a = r, g, b, a or c.a or 1
	ns:Set(key, c)
end

local layoutPending = false
function ns:Layout()
	if not ns.initialized then return end
	if InCombatLockdown() then
		layoutPending = true
		ns:Defer(function()
			if layoutPending then ns:Layout() end
		end)
		return
	end
	layoutPending = false
	for _, mod in ipairs(ns.modules) do
		if mod.OnLayout then mod:OnLayout() end
	end
	ns:Fire("LAYOUT")
end

---------------------------------------------------------------------------
-- zone / state tracking
---------------------------------------------------------------------------
ns.state = { inArena = false, inBG = false, instanceType = "none", testMode = false, arenaSize = 0 }

local function UpdateZone()
	local _, instanceType = IsInInstance()
	instanceType = instanceType or "none"
	local st = ns.state
	local wasArena, wasBG = st.inArena, st.inBG
	st.instanceType = instanceType
	st.inArena = instanceType == "arena"
	st.inBG = instanceType == "pvp"
	if st.inArena and not wasArena then
		st.testMode = false
		st.arenaSize = 0
		ns:Fire("ARENA_ENTER")
	elseif wasArena and not st.inArena then
		ns:Fire("ARENA_LEAVE")
	end
	if st.inBG and not wasBG then
		ns:Fire("BG_ENTER")
	elseif wasBG and not st.inBG then
		ns:Fire("BG_LEAVE")
	end
	ns:Fire("ZONE_CHANGED", instanceType)
end
ns.UpdateZone = UpdateZone

function ns:ArenaTeamSize()
	for i = 1, (MAX_BATTLEFIELD_QUEUES or 3) do
		local status, _, _, _, _, teamSize = GetBattlefieldStatus(i)
		if status == "active" and teamSize and teamSize > 0 then return teamSize end
	end
	return 0
end

---------------------------------------------------------------------------
-- startup
---------------------------------------------------------------------------
ns:RegisterEvent("ADDON_LOADED", function(_, name)
	if name ~= ADDON then
		if name == "Blizzard_ArenaUI" or name == "Blizzard_BattlefieldMinimap" then ns:Fire("BLIZZARD_ADDON_LOADED", name) end
		return
	end
	SetupDB()
	for _, mod in ipairs(ns.modules) do
		if mod.OnInit then mod:OnInit() end
	end
	ns.initialized = true
	ns:Layout()
	for _, mod in ipairs(ns.modules) do
		if mod.OnEnable then mod:OnEnable() end
	end
	ns:Print(L["loaded"])
end)

ns:RegisterEvents(function() UpdateZone() end, "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA")

---------------------------------------------------------------------------
-- slash commands (modules add sub-commands via ns:AddCommand)
---------------------------------------------------------------------------
local commands, commandOrder = {}, {}
function ns:AddCommand(word, help, fn)
	commands[word] = { help = help, fn = fn }
	commandOrder[#commandOrder + 1] = word
end

SLASH_WARENA1 = "/warena"
SLASH_WARENA2 = "/wa335"
SlashCmdList["WARENA"] = function(msg)
	if not ns.db then return end
	local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = (cmd or ""):lower()
	if cmd == "" then
		if ns.OpenOptions then ns:OpenOptions() else ns:Print("Options window failed to load. Enable /console scriptErrors 1 and /reload.") end
		return
	end
	local c = commands[cmd]
	if c then
		c.fn(rest)
	else
		ns:Print("Commands:")
		DEFAULT_CHAT_FRAME:AddMessage("  /warena – options window")
		for _, w in ipairs(commandOrder) do
			DEFAULT_CHAT_FRAME:AddMessage("  /warena " .. w .. " – " .. commands[w].help)
		end
	end
end
