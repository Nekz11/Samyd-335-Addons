-- WArena: announcements (chat / screen) and sounds for important enemy events
local _, ns = ...
local L = ns.L
local Ann = ns:NewModule("Announce")
ns.Announce = Ann

local format, floor = string.format, math.floor
local GetTime = GetTime

-- every event: enabled, channel, sound
ns.AnnounceEvents = {
	{ key = "trinket",      label = "Enemy trinket used",        defChannel = "screen", defSound = "Raid warning" },
	{ key = "trinketReady", label = "Enemy trinket ready",       defChannel = "self",   defSound = "None" },
	{ key = "racial",       label = "Enemy racial used",         defChannel = "self",   defSound = "None" },
	{ key = "drink",        label = "Enemy drinking",            defChannel = "party",  defSound = "Map ping" },
	{ key = "lowhp",        label = "Enemy low health",          defChannel = "screen", defSound = "None" },
	{ key = "resurrect",    label = "Enemy resurrecting",        defChannel = "party",  defSound = "Alarm clock" },
	{ key = "spec",         label = "Enemy spec detected",       defChannel = "self",   defSound = "None" },
	{ key = "healer",       label = "Enemy healer detected",     defChannel = "self",   defSound = "None" },
	{ key = "enemyTeam",    label = "Enemy team overview",       defChannel = "self",   defSound = "None" },
	{ key = "interrupt",    label = "You interrupted a cast",    defChannel = "none",   defSound = "None" },
	{ key = "kickReady",    label = "Enemy interrupt ready again", defChannel = "none", defSound = "None" },
	{ key = "targetingYou", label = "Enemy switched to you",     defChannel = "none",   defSound = "None" },
	{ key = "flag",         label = "Flag picked up / dropped",  defChannel = "screen", defSound = "PvP flag taken" },
	{ key = "shadowsight",  label = "Shadow Sight timer",        defChannel = "screen", defSound = "Bell" },
	{ key = "gates",        label = "Gates open",                defChannel = "screen", defSound = "None" },
}

ns.AnnounceChannels = {
	{ "none", "Off" }, { "self", "Chat (only me)" }, { "screen", "Screen alert" }, { "both", "Chat + screen" },
	{ "party", "Party" }, { "say", "Say" }, { "raid", "Raid / party" },
}

local defaults = {
	announce = true, annThrottle = 5, annScreenScale = 1.2, annScreenDuration = 3, annScreenPoint = { "CENTER", "UIParent", "CENTER", 0, 220 },
	annScreenColor = { r = 1, g = 0.9, b = 0.2, a = 1 }, annSounds = true, annLowHPThreshold = 30, annInArenaOnly = true,
}
for _, e in ipairs(ns.AnnounceEvents) do
	defaults["ann_" .. e.key] = e.defChannel
	defaults["snd_" .. e.key] = e.defSound
end
ns:AddDefaults(defaults)

---------------------------------------------------------------------------
-- screen alert frame (3 stacked lines, newest on top)
---------------------------------------------------------------------------
local screen = CreateFrame("Frame", "WArenaAlerts", UIParent)
screen:SetWidth(400)
screen:SetHeight(90)
screen:SetFrameStrata("HIGH")
screen.lines = {}
for i = 1, 3 do
	local fs = screen:CreateFontString(nil, "OVERLAY")
	fs:SetFont(ns.FONTS[1][2], 20, "OUTLINE")
	fs:SetPoint("TOP", screen, "TOP", 0, -(i - 1) * 28)
	fs:SetText("")
	fs:Hide()
	screen.lines[i] = fs
end
screen.queue = {}

local function RefreshScreen()
	local db = ns.db
	for i, fs in ipairs(screen.lines) do
		local item = screen.queue[i]
		if item then
			fs:SetText(item.text)
			local r, g, b = ns:Color("annScreenColor")
			if item.r then r, g, b = item.r, item.g, item.b end
			fs:SetTextColor(r, g, b)
			fs:SetAlpha(item.alpha or 1)
			fs:Show()
		else
			fs:Hide()
		end
	end
end

function Ann:Screen(text, r, g, b)
	local db = ns.db
	table.insert(screen.queue, 1, { text = text, until_ = GetTime() + (db.annScreenDuration or 3), r = r, g = g, b = b })
	while #screen.queue > 3 do table.remove(screen.queue) end
	RefreshScreen()
end

ns:AddTicker(0.1, function(now)
	if #screen.queue == 0 then return end
	local changed = false
	for i = #screen.queue, 1, -1 do
		local item = screen.queue[i]
		local left = item.until_ - now
		if left <= 0 then
			table.remove(screen.queue, i)
			changed = true
		elseif left < 0.5 then
			item.alpha = left * 2
			changed = true
		end
	end
	if changed then RefreshScreen() end
end)

---------------------------------------------------------------------------
-- output
---------------------------------------------------------------------------
local lastSent = {}

local function Throttled(key, unitKey)
	local db = ns.db
	local k = key .. ":" .. tostring(unitKey or "")
	local now = GetTime()
	if lastSent[k] and now - lastSent[k] < (db.annThrottle or 5) then return true end
	lastSent[k] = now
	return false
end

local function InGroup()
	return (GetNumRaidMembers() > 0) or (GetNumPartyMembers() > 0)
end

function Ann:Send(key, text, unitKey, r, g, b)
	local db = ns.db
	if not db.announce then return end
	if db.annInArenaOnly and not ns.state.inArena and not ns.state.inBG and not ns.state.testMode then return end
	local channel = db["ann_" .. key] or "none"
	local sound = db["snd_" .. key]
	if channel == "none" and (not sound or sound == "None") then return end
	if Throttled(key, unitKey) then return end
	if channel == "self" or channel == "both" then
		ns:Print(text)
	end
	if channel == "screen" or channel == "both" then
		self:Screen(text, r, g, b)
	end
	if channel == "party" then
		if GetNumRaidMembers() > 0 then SendChatMessage(text, "RAID") elseif GetNumPartyMembers() > 0 then SendChatMessage(text, "PARTY") else ns:Print(text) end
	elseif channel == "raid" then
		if InGroup() then SendChatMessage(text, GetNumRaidMembers() > 0 and "RAID" or "PARTY") else ns:Print(text) end
	elseif channel == "say" then
		if ns.state.inArena or ns.state.inBG then SendChatMessage(text, "SAY") else ns:Print(text) end
	end
	if db.annSounds and sound and sound ~= "None" then ns:PlaySound(sound) end
	ns:Fire("ANNOUNCED", key, text)
end

local function EnemyLabel(f)
	local name = f.name and ns:ShortName(f.name) or format(L["Arena %d"], f.id)
	if f.class then return ns:Colored(name, f.class) end
	return name
end

local function PlainLabel(f)
	return (f.name and ns:ShortName(f.name)) or format(L["Arena %d"], f.id)
end

-- chat channels can't carry color codes; pick the right label per channel
local function Label(f, key)
	local channel = ns.db["ann_" .. key]
	if channel == "party" or channel == "say" or channel == "raid" then return PlainLabel(f) end
	return EnemyLabel(f)
end

---------------------------------------------------------------------------
-- event hooks
---------------------------------------------------------------------------
ns:RegisterMessage("ENEMY_TRINKET", function(_, f)
	Ann:Send("trinket", format(L["ANN_TRINKET"], Label(f, "trinket")), f.id, 1, 0.3, 0.3)
end)
ns:RegisterMessage("ENEMY_TRINKET_READY", function(_, f)
	Ann:Send("trinketReady", format(L["ANN_TRINKET_READY"], Label(f, "trinketReady")), f.id)
end)
ns:RegisterMessage("ENEMY_RACIAL", function(_, f, spell)
	Ann:Send("racial", format(L["ANN_RACIAL"], Label(f, "racial"), spell), f.id)
end)
ns:RegisterMessage("ENEMY_DRINK", function(_, f, drinking)
	if drinking then Ann:Send("drink", format(L["ANN_DRINK"], Label(f, "drink")), f.id, 0.4, 0.7, 1) end
end)
ns:RegisterMessage("ENEMY_HEALTH", function(_, f, pct, dead)
	if dead or not pct then f.annLow = nil return end
	local th = (ns.db.annLowHPThreshold or 30) / 100
	if pct <= th and not f.annLow then
		f.annLow = true
		Ann:Send("lowhp", format(L["ANN_LOWHP"], Label(f, "lowhp"), floor(pct * 100 + 0.5)), f.id, 1, 0.2, 0.2)
	elseif pct > th + 0.15 then
		f.annLow = nil
	end
end)
ns:RegisterMessage("ENEMY_RESURRECT", function(_, f, target)
	Ann:Send("resurrect", format(L["ANN_RESURRECT"], Label(f, "resurrect"), ns:ShortName(target or "?")), f.id, 1, 0.5, 0)
end)
ns:RegisterMessage("ENEMY_SPEC", function(_, f, spec)
	Ann:Send("spec", format(L["ANN_SPEC"], Label(f, "spec"), spec, f.className or ""), f.id .. spec)
end)
ns:RegisterMessage("ENEMY_HEALER", function(_, f)
	Ann:Send("healer", format(L["ANN_HEALER"], Label(f, "healer"), f.spec or f.className or "?"), f.id)
end)
ns:RegisterMessage("ENEMY_INTERRUPTED", function(_, f, srcName, spell)
	if srcName and UnitName("player") == srcName then
		Ann:Send("interrupt", format("Interrupted %s's %s", PlainLabel(f), spell or "cast"), f.id)
	end
end)
ns:RegisterMessage("ENEMY_TARGETING_YOU", function(_, f, on)
	if on then Ann:Send("targetingYou", format("%s is targeting you!", Label(f, "targetingYou")), f.id, 1, 0.3, 0.3) end
end)
ns:RegisterMessage("ENEMY_RESET", function(_, f) f.annLow = nil end)
ns:RegisterMessage("ENEMY_CD_READY", function(_, f, entry)
	if entry.cat == "interrupt" then
		Ann:Send("kickReady", format("%s: %s ready", Label(f, "kickReady"), entry.name or "interrupt"), f.id .. entry.key, 1, 0.6, 0.2)
	end
end)

-- enemy team overview once every visible enemy has a class
local teamAnnounced
ns:RegisterMessage("ENEMY_IDENTITY", function()
	if teamAnnounced or not ns.state.inArena then return end
	local n = ns.Frames:Count()
	if n == 0 then return end
	local parts = {}
	for i = 1, n do
		local f = ns.Frames:Get(i)
		if not f.class then return end
		parts[#parts + 1] = (ns.CLASS_NAMES[f.class] or f.class) .. (f.spec and (" (" .. f.spec .. ")") or "")
	end
	teamAnnounced = true
	Ann:Send("enemyTeam", format(L["ANN_ENEMY_TEAM"], table.concat(parts, " / ")), "team")
end)
ns:RegisterMessage("ARENA_ENTER", function() teamAnnounced = nil; lastSent = {} end)
ns:RegisterMessage("ARENA_LEAVE", function() teamAnnounced = nil end)

---------------------------------------------------------------------------
-- layout / test / commands
---------------------------------------------------------------------------
function Ann:OnLayout()
	local db = ns.db
	screen:SetScale(db.annScreenScale)
	ns:SetPointFromTable(screen, db.annScreenPoint)
	for _, fs in ipairs(screen.lines) do ns:SetFont(fs, 20, "OUTLINE") end
end

function Ann:OnInit()
	ns:MakeMovable(screen, "WArena alerts", function(p) ns.db.annScreenPoint = p end)
	ns:RegisterMessage("LOCK_CHANGED", function(_, locked) ns:Show(screen.mover, not locked) end)
	if not ns.db.locked then screen.mover:Show() end
end

function Ann:Test()
	local f = ns.Frames:Get(1)
	self:Screen(format(L["ANN_TRINKET"], EnemyLabel(f)), 1, 0.3, 0.3)
	ns:After(0.7, function() self:Screen(format(L["ANN_DRINK"], EnemyLabel(ns.Frames:Get(2))), 0.4, 0.7, 1) end)
	ns:After(1.4, function() self:Screen(format(L["ANN_LOWHP"], EnemyLabel(ns.Frames:Get(3)), 18), 1, 0.2, 0.2) end)
	ns:PlaySound(ns.db.snd_trinket)
end

ns:AddCommand("announce", "preview the screen alerts", function() Ann:Test() end)
