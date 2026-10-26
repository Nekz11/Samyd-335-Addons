-- WArena: match history (arena) and spec memory for enemy names
local _, ns = ...
local L = ns.L
local History = ns:NewModule("History")
ns.History = History

local format, floor, tinsert, tremove = string.format, math.floor, table.insert, table.remove
local GetTime = GetTime
local MAX_ENTRIES = 100

ns:AddDefaults({ historyEnabled = true, historyAnnounce = true, specMemory = true })

---------------------------------------------------------------------------
-- storage (global, shared by all characters)
---------------------------------------------------------------------------
local function Store()
	ns.global.history = ns.global.history or {}
	ns.global.specs = ns.global.specs or {}
	return ns.global.history, ns.global.specs
end

local current -- the match being played

local function MapName()
	local name = GetRealZoneText and GetRealZoneText() or "Arena"
	return name
end

local function Bracket()
	local size = ns.state.arenaSize or 0
	if size == 0 then size = ns:ArenaTeamSize() end
	return size > 0 and (size .. "v" .. size) or "?"
end

---------------------------------------------------------------------------
-- match tracking
---------------------------------------------------------------------------
ns:RegisterMessage("ARENA_ENTER", function()
	current = { map = MapName(), bracket = Bracket(), start = GetTime(), enemies = {}, result = "?" , date = date("%Y-%m-%d %H:%M") }
end)

local function CaptureEnemies()
	if not current then return end
	for k in pairs(current.enemies) do current.enemies[k] = nil end
	for i = 1, ns.Frames:Count() do
		local f = ns.Frames:Get(i)
		if f.class then
			current.enemies[#current.enemies + 1] = { id = i, name = f.name, class = f.class, spec = f.spec, dead = f.dead }
		end
	end
	if current.bracket == "?" then current.bracket = Bracket() end
end

ns:RegisterMessage("ENEMY_SEEN", CaptureEnemies)
ns:RegisterMessage("ENEMY_SPEC", CaptureEnemies)
ns:RegisterMessage("ENEMY_DIED", CaptureEnemies)

local function MyTeamIndex()
	if GetBattlefieldArenaFaction then
		local ok, idx = pcall(GetBattlefieldArenaFaction)
		if ok and idx ~= nil then return idx end
	end
end

local function Finish(result)
	if not current then return end
	CaptureEnemies()
	current.duration = floor(GetTime() - current.start)
	current.result = result or current.result or "?"
	local list = Store()
	tinsert(list, 1, current)
	while #list > MAX_ENTRIES do tremove(list) end
	if ns.db.historyAnnounce then
		local comp = {}
		for _, e in ipairs(current.enemies) do comp[#comp + 1] = (ns.CLASS_NAMES[e.class] or e.class) .. (e.spec and (" " .. e.spec) or "") end
		ns:Print("Match recorded: %s – %s (%s) vs %s", current.result == "W" and "|cff40ff40Win|r" or current.result == "L" and "|cffff4040Loss|r" or "Unknown",
			current.map, current.bracket, #comp > 0 and table.concat(comp, ", ") or "?")
	end
	current = nil
end

-- the winner is known at the scoreboard; GetBattlefieldWinner returns the team index
ns:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", function()
	if not current or not ns.state.inArena or not ns.db.historyEnabled then return end
	local winner = GetBattlefieldWinner and GetBattlefieldWinner()
	if winner ~= nil then
		local mine = MyTeamIndex()
		local result = "?"
		if mine ~= nil then result = (winner == mine) and "W" or "L" end
		Finish(result)
	end
end)

ns:RegisterMessage("ARENA_LEAVE", function()
	if current and ns.db.historyEnabled then
		-- no winner seen (left early or crashed): still record the match
		Finish(current.result)
	end
	current = nil
end)

function History:List()
	local list = Store()
	return list
end

function History:Clear()
	ns.global.history = {}
end

function History:Stats()
	local list = Store()
	local w, l, n = 0, 0, #list
	for _, m in ipairs(list) do
		if m.result == "W" then w = w + 1 elseif m.result == "L" then l = l + 1 end
	end
	return n, w, l
end

---------------------------------------------------------------------------
-- spec memory: remember the spec of enemy names, pre-fill it next time
---------------------------------------------------------------------------
ns:RegisterMessage("ENEMY_SPEC", function(_, f, spec)
	if not ns.db.specMemory or not f.name or not spec or ns.state.testMode or f.kind ~= "arena" then return end
	local _, specs = Store()
	specs[f.name] = { class = f.class, spec = spec, seen = time and time() or 0 }
end)

ns:RegisterMessage("ENEMY_IDENTITY", function(_, f)
	if not ns.db.specMemory or f.spec or not f.name or ns.state.testMode or f.kind ~= "arena" then return end
	local _, specs = Store()
	local rec = specs[f.name]
	if rec and rec.class == f.class and rec.spec then
		ns.Frames:SetSpec(f, rec.spec, "memory")
	end
end)

function History:ForgetSpecs()
	ns.global.specs = {}
end

function History:SpecCount()
	local _, specs = Store()
	local n = 0
	for _ in pairs(specs) do n = n + 1 end
	return n
end

ns:AddCommand("history", "show the last 10 arena matches", function()
	local list = Store()
	if #list == 0 then ns:Print("No matches recorded yet.") return end
	ns:Print("Last matches:")
	for i = 1, math.min(10, #list) do
		local m = list[i]
		local comp = {}
		for _, e in ipairs(m.enemies) do comp[#comp + 1] = (ns.CLASS_NAMES[e.class] or e.class):sub(1, 4) .. (e.spec and ("/" .. e.spec:sub(1, 4)) or "") end
		DEFAULT_CHAT_FRAME:AddMessage(format("  %s %s %s %s – %s (%s)", m.date or "", m.result == "W" and "|cff40ff40W|r" or m.result == "L" and "|cffff4040L|r" or "?",
			m.bracket or "", m.map or "", table.concat(comp, " "), ns:FormatClock(m.duration or 0)))
	end
end)
