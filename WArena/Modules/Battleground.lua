-- WArena: battleground enemy list – scoreboard based roster with class/spec/role, health tracking,
-- click-to-target rows, flag carrier tracking and announcements
local _, ns = ...
local L = ns.L
local BG = ns:NewModule("Battleground")
ns.Battleground = BG

local floor, mmax, mmin, format, tsort = math.floor, math.max, math.min, string.format, table.sort
local GetTime, UnitExists, UnitName, UnitIsUnit, InCombatLockdown = GetTime, UnitExists, UnitName, UnitIsUnit, InCombatLockdown
local MAX_ROWS = 40

ns:AddDefaults({
	bgEnabled = true, bgTest = false, bgPoint = { "RIGHT", "UIParent", "RIGHT", -40, 0 },
	bgScale = 1, bgWidth = 170, bgRowHeight = 18, bgColumns = 1, bgMaxRows = 15, bgSort = "role",
	bgHealersOnly = false, bgHideDead = false, bgShowSpec = true, bgShowHealth = true, bgShowKD = false,
	bgShowRole = true, bgRefresh = 10, bgShowFriendlyFC = true, bgHeader = true, bgBgAlpha = 0.5,
	bgFontSize = 11, bgHealthStale = 12, bgClassColorRow = true, bgShowNumbers = true,
})

---------------------------------------------------------------------------
-- state
---------------------------------------------------------------------------
local players = {}       -- name -> record
local ordered = {}       -- sorted list of records (current view)
local guidToName = {}
local friendlyFC, enemyFC
local inCombatFrozen = false
local lastScoreRequest = 0
local myFactionIndex    -- 0 Horde, 1 Alliance
local HEALTH_UNITS = { "target", "focus", "mouseover" }
for i = 1, 4 do HEALTH_UNITS[#HEALTH_UNITS + 1] = "party" .. i .. "target" end
for i = 1, 40 do HEALTH_UNITS[#HEALTH_UNITS + 1] = "raid" .. i .. "target" end

BG.players = players
BG.ordered = ordered

local function Record(name)
	local r = players[name]
	if not r then
		r = { name = name, hp = nil, hpTime = 0, dead = false, kills = 0, deaths = 0, damage = 0, healing = 0 }
		players[name] = r
	end
	return r
end

local function IsHealerRecord(r)
	if r.spec and ns.HealerSpecs[r.spec] then return true end
	if r.role == "HEALER" then return true end
	-- heuristic: healing-capable class with clearly more healing than damage
	if r.class and ns.HEALER_CLASSES[r.class] and r.healing > 20000 and r.healing > r.damage * 1.5 then return true end
	return false
end

---------------------------------------------------------------------------
-- scoreboard
---------------------------------------------------------------------------
local tokenSet = {}
for _, t in ipairs(ns.CLASS_TOKENS) do tokenSet[t] = true end

local function ParseScore(i)
	local a = { GetBattlefieldScore(i) }
	local name, kills, _, deaths, _, faction = a[1], a[2], a[3], a[4], a[5], a[6]
	local race, class, classToken, damage, healing, spec
	if tokenSet[a[10]] then
		-- 3.3.5 layout: ..., faction, rank, race, class, classToken, damageDone, healingDone
		race, class, classToken, damage, healing = a[8], a[9], a[10], a[11], a[12]
		spec = a[13]
	elseif tokenSet[a[9]] then
		-- layout without rank: ..., faction, race, class, classToken, damageDone, healingDone, ..., talentSpec
		race, class, classToken, damage, healing = a[7], a[8], a[9], a[10], a[11]
		spec = a[16] or a[12]
	else
		classToken = ns:ClassToken(a[9]) or ns:ClassToken(a[8])
		damage, healing = a[11] or 0, a[12] or 0
	end
	if type(spec) ~= "string" or spec == "" or tonumber(spec) then spec = nil end
	return name, kills or 0, deaths or 0, faction, race, classToken, damage or 0, healing or 0, spec
end

local function MyFactionIndex()
	if myFactionIndex == nil then
		myFactionIndex = (UnitFactionGroup("player") == "Alliance") and 1 or 0
	end
	return myFactionIndex
end

function BG:UpdateFromScore()
	if ns.db.bgTest then return end
	local n = GetNumBattlefieldScores()
	if not n or n == 0 then return end
	local seen = {}
	local mine = MyFactionIndex()
	for i = 1, n do
		local name, kills, deaths, faction, race, class, damage, healing, spec = ParseScore(i)
		if name and faction ~= nil and faction ~= mine then
			name = ns:ShortName(name)
			local r = Record(name)
			r.kills, r.deaths, r.damage, r.healing = kills, deaths, damage, healing
			r.race = race
			if class then r.class = class end
			if spec and not r.spec then r.spec = spec end
			r.role = r.spec and ns.SpecRole[r.spec] or r.role
			r.seen = true
			seen[name] = true
		end
	end
	for name, r in pairs(players) do
		if not seen[name] and r.seen then players[name] = nil end
	end
	self:Rebuild()
end

local function RequestScore(force)
	local now = GetTime()
	if force or now - lastScoreRequest >= (ns.db.bgRefresh or 10) then
		lastScoreRequest = now
		RequestBattlefieldScoreData()
	end
end

---------------------------------------------------------------------------
-- health tracking from any unit we can see
---------------------------------------------------------------------------
local function TrackUnit(unit)
	if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsEnemy("player", unit) then return end
	local name = UnitName(unit)
	if not name then return end
	name = ns:ShortName(name)
	local r = players[name]
	if not r then
		if not ns.state.inBG then return end
		r = Record(name)
		local _, class = UnitClass(unit)
		r.class = class
	end
	local maxhp = UnitHealthMax(unit)
	if maxhp and maxhp > 0 then
		r.hp = UnitHealth(unit) / maxhp
		r.hpTime = GetTime()
		r.dead = UnitIsDeadOrGhost(unit) and true or false
	end
	local guid = UnitGUID(unit)
	if guid then guidToName[guid] = name; r.guid = guid end
	if not r.spec then
		-- buffs on the unit may reveal the spec
		local i = 1
		while true do
			local aname, _, _, _, _, _, _, caster = UnitAura(unit, i, "HELPFUL")
			if not aname then break end
			if caster == unit then
				local sp = ns:LookupSpec(r.class, aname)
				if sp then r.spec = sp; r.role = ns.SpecRole[sp]; break end
			end
			i = i + 1
		end
	end
	return r
end

local function ScanHealthUnits()
	for _, u in ipairs(HEALTH_UNITS) do TrackUnit(u) end
end

---------------------------------------------------------------------------
-- rows
---------------------------------------------------------------------------
local list = CreateFrame("Frame", "WArenaBG", UIParent)
list:SetFrameStrata("MEDIUM")
list:SetBackdrop({ bgFile = ns.WHITE, edgeFile = ns.WHITE, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
list:SetBackdropColor(0, 0, 0, 0.5)
list:SetBackdropBorderColor(0, 0, 0, 0.9)
list:Hide()
list.header = ns:NewText(list, "LEFT")
list.header:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -4)
list.fcText = ns:NewText(list, "RIGHT")
list.fcText:SetPoint("TOPRIGHT", list, "TOPRIGHT", -6, -4)
list.frozen = ns:NewText(list, "RIGHT")
list.frozen:SetText("")
list.rows = {}
BG.frame = list

local function Row_OnEnter(self)
	local r = self.record
	if not r then return end
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText(r.name, ns:ClassColor(r.class))
	GameTooltip:AddLine((ns.CLASS_NAMES[r.class] or "?") .. (r.spec and (" – " .. r.spec) or ""), 1, 1, 1)
	GameTooltip:AddLine(format("Kills %d  Deaths %d", r.kills or 0, r.deaths or 0), 0.8, 0.8, 0.8)
	GameTooltip:AddLine(format("Damage %s  Healing %s", ns:Short(r.damage or 0), ns:Short(r.healing or 0)), 0.8, 0.8, 0.8)
	if r.hp then GameTooltip:AddLine(format("Health %d%% (%ds ago)", floor(r.hp * 100 + 0.5), floor(GetTime() - r.hpTime)), 0.6, 1, 0.6) end
	if r.flag then GameTooltip:AddLine(L["Flag carrier"], 1, 0.3, 0.3) end
	GameTooltip:AddLine("Left click: target   Right click: focus", 0.5, 0.5, 0.5)
	GameTooltip:Show()
end
local function Row_OnLeave() GameTooltip:Hide() end

local function CreateRow(i)
	local row = CreateFrame("Button", "WArenaBGRow" .. i, list, "SecureActionButtonTemplate")
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:SetAttribute("type1", "macro")
	row:SetAttribute("type2", "macro")
	row:SetScript("OnEnter", Row_OnEnter)
	row:SetScript("OnLeave", Row_OnLeave)
	row.bg = row:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints()
	row.bg:SetTexture(0, 0, 0, 0.3)
	row.hp = row:CreateTexture(nil, "BORDER")
	row.hp:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	row.hp:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	row.hp:SetWidth(1)
	row.hp:SetTexture(ns.WHITE)
	row.classIcon = row:CreateTexture(nil, "ARTWORK")
	row.classIcon:SetPoint("LEFT", row, "LEFT", 2, 0)
	row.role = row:CreateTexture(nil, "ARTWORK")
	row.role:SetTexture(ns.ROLE_TEX)
	row.role:SetTexCoord(ns.HEALER_COORDS[1], ns.HEALER_COORDS[2], ns.HEALER_COORDS[3], ns.HEALER_COORDS[4])
	row.role:SetPoint("LEFT", row.classIcon, "RIGHT", 2, 0)
	row.role:Hide()
	row.flag = row:CreateTexture(nil, "OVERLAY")
	row.flag:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	row.flag:SetPoint("RIGHT", row, "RIGHT", -2, 0)
	row.flag:Hide()
	row.name = ns:NewText(row, "LEFT")
	row.name:SetPoint("LEFT", row.role, "RIGHT", 2, 0)
	row.name:SetPoint("RIGHT", row.flag, "LEFT", -2, 0)
	row.info = ns:NewText(row, "RIGHT")
	row.info:SetPoint("RIGHT", row.flag, "LEFT", -2, 0)
	row.num = ns:NewText(row, "RIGHT")
	row.num:SetPoint("RIGHT", row.classIcon, "LEFT", -1, 0)
	row.highlight = row:CreateTexture(nil, "OVERLAY")
	row.highlight:SetAllPoints()
	row.highlight:SetTexture(1, 1, 1, 0.15)
	row.highlight:Hide()
	row.sel = CreateFrame("Frame", nil, row)
	row.sel:SetPoint("TOPLEFT", -1, 1)
	row.sel:SetPoint("BOTTOMRIGHT", 1, -1)
	row.sel:SetBackdrop(ns.BACKDROP_THIN)
	row.sel:Hide()
	row:Hide()
	list.rows[i] = row
	return row
end

for i = 1, MAX_ROWS do CreateRow(i) end

local function ApplyAttributes(row, name)
	-- only out of combat (secure attributes); the list keeps its old targets while frozen
	if InCombatLockdown() then inCombatFrozen = true return end
	if row.attrName == name then return end
	row.attrName = name
	if name then
		row:SetAttribute("macrotext1", "/targetexact " .. name)
		row:SetAttribute("macrotext2", "/focus " .. name)
	else
		row:SetAttribute("macrotext1", "")
		row:SetAttribute("macrotext2", "")
	end
end

local SORTERS = {
	name = function(a, b) return a.name < b.name end,
	class = function(a, b)
		if a.class ~= b.class then return (a.class or "~") < (b.class or "~") end
		return a.name < b.name
	end,
	role = function(a, b)
		local ha, hb = IsHealerRecord(a), IsHealerRecord(b)
		if ha ~= hb then return ha end
		if a.class ~= b.class then return (a.class or "~") < (b.class or "~") end
		return a.name < b.name
	end,
	health = function(a, b)
		local ha, hb = a.hp or 2, b.hp or 2
		if a.dead ~= b.dead then return not a.dead end
		if ha ~= hb then return ha < hb end
		return a.name < b.name
	end,
	kills = function(a, b)
		if (a.kills or 0) ~= (b.kills or 0) then return (a.kills or 0) > (b.kills or 0) end
		return a.name < b.name
	end,
}

function BG:Rebuild()
	local db = ns.db
	if InCombatLockdown() then
		-- rows are secure buttons: no re-sorting, moving or showing/hiding while in combat
		inCombatFrozen = true
		self:Refresh()
		return
	end
	for i = #ordered, 1, -1 do ordered[i] = nil end
	for _, r in pairs(players) do
		if (not db.bgHealersOnly or IsHealerRecord(r)) and (not db.bgHideDead or not r.dead) then
			ordered[#ordered + 1] = r
		end
	end
	tsort(ordered, SORTERS[db.bgSort] or SORTERS.role)
	self:Refresh()
end


local function RowHealthColor(r, now)
	if r.dead then return 0.3, 0.3, 0.3 end
	local age = now - (r.hpTime or 0)
	local pct = r.hp or 1
	local cr, cg, cb = ns:HealthGradient(pct)
	if age > (ns.db.bgHealthStale or 12) then
		return cr * 0.5, cg * 0.5, cb * 0.5
	end
	return cr, cg, cb
end

-- visual-only update of a row (allowed in combat)
local function RowVisuals(row, r, db, now, W, targetName, focusName)
	local cr, cg, cb = ns:ClassColor(r.class)
	if db.bgClassColorRow then
		row.bg:SetTexture(cr * 0.35, cg * 0.35, cb * 0.35, 0.6)
	else
		row.bg:SetTexture(0, 0, 0, 0.4)
	end
	row.name:SetText(r.name)
	row.name:SetTextColor(cr, cg, cb)
	if r.dead then row.name:SetTextColor(0.5, 0.5, 0.5) end
	local info = ""
	if db.bgShowKD then info = format("%d/%d", r.kills or 0, r.deaths or 0) end
	if db.bgShowSpec and r.spec then info = (info ~= "" and (info .. " ") or "") .. r.spec:sub(1, 4) end
	if db.bgShowHealth and r.hp and not r.dead then info = (info ~= "" and (info .. " ") or "") .. floor(r.hp * 100 + 0.5) .. "%" end
	if r.dead then info = L["Dead"] end
	row.info:SetText(info)
	if db.bgShowHealth then
		local pct = r.dead and 0 or (r.hp or 1)
		row.hp:SetWidth(mmax(1, W * pct))
		row.hp:SetTexture(RowHealthColor(r, now))
		row.hp:SetAlpha(0.35)
		row.hp:Show()
	else
		row.hp:Hide()
	end
	ns:Show(row.role, db.bgShowRole and IsHealerRecord(r))
	if r.flag then
		row.flag:SetTexture(r.flag == "Alliance" and ns.FLAG_A_TEX or ns.FLAG_H_TEX)
		row.flag:Show()
	else
		row.flag:Hide()
	end
	if targetName == r.name then
		row.sel:SetBackdropBorderColor(ns:Color("targetColor"))
		row.sel:Show()
	elseif focusName == r.name then
		row.sel:SetBackdropBorderColor(ns:Color("focusColor"))
		row.sel:Show()
	else
		row.sel:Hide()
	end
end

function BG:Refresh()
	local db = ns.db
	if not db.bgEnabled or not (ns.state.inBG or db.bgTest) then if not InCombatLockdown() then list:Hide() end return end
	local now = GetTime()
	local targetName = UnitExists("target") and ns:ShortName(UnitName("target")) or nil
	local focusName = UnitExists("focus") and ns:ShortName(UnitName("focus")) or nil
	if InCombatLockdown() then
		for i = 1, MAX_ROWS do
			local row = list.rows[i]
			if row.record and row:IsShown() then RowVisuals(row, row.record, db, now, db.bgWidth, targetName, focusName) end
		end
		if inCombatFrozen then
			list.frozen:SetText("|cffff8800" .. L["list frozen in combat"] .. "|r")
			list.frozen:ClearAllPoints()
			list.frozen:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -4, 2)
			list.frozen:Show()
		end
		return
	end
	local cols, maxRows = db.bgColumns, db.bgMaxRows
	local W, RH = db.bgWidth, db.bgRowHeight
	local headerH = db.bgHeader and (db.bgFontSize + 8) or 4
	local shown = 0
	local total = #ordered
	local perCol = mmin(maxRows, MAX_ROWS)
	local rowsShown = mmin(total, perCol * cols, MAX_ROWS)
	for i = 1, MAX_ROWS do
		local row = list.rows[i]
		local r = ordered[i]
		if r and i <= rowsShown then
			shown = shown + 1
			row.record = r
			local col = floor((i - 1) / perCol)
			local idx = (i - 1) % perCol
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", list, "TOPLEFT", 4 + col * (W + 4), -headerH - idx * (RH + 1))
			ns:Size(row, W, RH)
			ns:Size(row.classIcon, RH - 2, RH - 2)
			ns:Size(row.role, RH - 4, RH - 4)
			ns:Size(row.flag, RH - 2, RH - 2)
			ns:SetClassIcon(row.classIcon, r.class)
			if db.bgShowNumbers then row.num:SetText(i) ; row.num:Show() else row.num:Hide() end
			RowVisuals(row, r, db, now, W, targetName, focusName)
			ApplyAttributes(row, r.name)
			row:Show()
		else
			row.record = nil
			row:Hide()
			if not InCombatLockdown() then ApplyAttributes(row, nil) end
		end
	end
	local usedCols = mmax(1, mmin(cols, math.ceil(mmax(shown, 1) / perCol)))
	local rowsInFirst = mmin(shown, perCol)
	ns:Size(list, usedCols * (W + 4) + 4, headerH + mmax(rowsInFirst, 1) * (RH + 1) + 6)
	if db.bgHeader then
		list.header:SetText(format("%s (%d)", L["Enemies"], total))
		local fc = ""
		if enemyFC then fc = "|cffff4040" .. L["Flag carrier"] .. ": " .. enemyFC .. "|r" end
		if db.bgShowFriendlyFC and friendlyFC then fc = fc .. (fc ~= "" and "  " or "") .. "|cff40ff40FC: " .. friendlyFC .. "|r" end
		list.fcText:SetText(fc)
		list.header:Show()
		list.fcText:Show()
	else
		list.header:Hide()
		list.fcText:Hide()
	end
	list.frozen:Hide()
	list:Show()
end

---------------------------------------------------------------------------
-- flags (combat log + fallback on system messages)
---------------------------------------------------------------------------
local function SetFlag(name, side, carrierIsEnemy)
	name = name and ns:ShortName(name)
	if carrierIsEnemy then
		for _, r in pairs(players) do r.flag = nil end
		if name and players[name] then players[name].flag = side end
		enemyFC = name
		if name then
			ns.Announce:Send("flag", format(L["ANN_FLAG_PICKED"], name), "efc", 1, 0.3, 0.3)
		else
			ns.Announce:Send("flag", L["ANN_FLAG_DROPPED"], "efcdrop", 1, 0.6, 0.2)
		end
		ns:Fire(name and "FLAG_PICKED" or "FLAG_DROPPED", name, true)
	else
		friendlyFC = name
		ns:Fire(name and "FLAG_PICKED" or "FLAG_DROPPED", name, false)
	end
	BG:Refresh()
end

ns:RegisterMessage("CLEU_BG", function(_, sub, srcGUID, srcName, dstGUID, dstName, spellId, spellName)
	if not ns.state.inBG then return end
	if sub == "SPELL_AURA_APPLIED" and spellName and ns.Lookup.flag[spellName] then
		local side = ns.Lookup.flag[spellName]
		local short = dstName and ns:ShortName(dstName)
		local isEnemy = short and players[short] ~= nil
		if not isEnemy and dstGUID and guidToName[dstGUID] then isEnemy = true end
		SetFlag(dstName, side, isEnemy)
	elseif sub == "SPELL_AURA_REMOVED" and spellName and ns.Lookup.flag[spellName] then
		local short = dstName and ns:ShortName(dstName)
		if short and short == enemyFC then SetFlag(nil, nil, true) elseif short and short == friendlyFC then SetFlag(nil, nil, false) end
	elseif sub == "UNIT_DIED" and dstName then
		local r = players[ns:ShortName(dstName)]
		if r then
			r.dead = true
			r.hp = 0
			r.hpTime = GetTime()
			if r.flag then SetFlag(nil, nil, true) end
			BG:Refresh()
		end
	end
end)

-- system messages ("X captured the flag!", "The Alliance flag was dropped by X!")
ns:RegisterEvents(function(_, msg)
	if not ns.state.inBG or not msg then return end
	local lower = msg:lower()
	if lower:find("dropped") or lower:find("captured") or lower:find("returned") then
		if enemyFC and lower:find(enemyFC:lower(), 1, true) then SetFlag(nil, nil, true) end
		if friendlyFC and lower:find(friendlyFC:lower(), 1, true) then SetFlag(nil, nil, false) end
	end
end, "CHAT_MSG_BG_SYSTEM_ALLIANCE", "CHAT_MSG_BG_SYSTEM_HORDE", "CHAT_MSG_BG_SYSTEM_NEUTRAL")

---------------------------------------------------------------------------
-- events / tickers
---------------------------------------------------------------------------
ns:RegisterEvent("UPDATE_BATTLEFIELD_SCORE", function() if ns.state.inBG then BG:UpdateFromScore() end end)
ns:RegisterEvents(function(_, unit)
	if not ns.state.inBG or ns.db.bgTest then return end
	if unit == "target" or unit == "focus" or unit == "mouseover" or unit:find("target$") then
		if TrackUnit(unit) then BG:Refresh() end
	end
end, "UNIT_HEALTH", "UNIT_TARGET")
ns:RegisterEvents(function()
	if not ns.state.inBG or ns.db.bgTest then return end
	TrackUnit("target"); TrackUnit("focus"); TrackUnit("mouseover")
	BG:Refresh()
end, "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UPDATE_MOUSEOVER_UNIT")

ns:RegisterMessage("BG_ENTER", function()
	for k in pairs(players) do players[k] = nil end
	for k in pairs(guidToName) do guidToName[k] = nil end
	friendlyFC, enemyFC, inCombatFrozen = nil, nil, false
	myFactionIndex = nil
	RequestScore(true)
	BG:Rebuild()
end)
ns:RegisterMessage("BG_LEAVE", function()
	for k in pairs(players) do players[k] = nil end
	friendlyFC, enemyFC = nil, nil
	for i = 1, MAX_ROWS do ordered[i] = nil end
	list:Hide()
end)
ns:RegisterMessage("COMBAT_ENDED", function()
	if inCombatFrozen then
		inCombatFrozen = false
		if ns.state.inBG or ns.db.bgTest then BG:Rebuild() end
	end
end)

ns:AddTicker(1, function(now)
	if not ns.db or not ns.state.inBG or not ns.db.bgEnabled or ns.db.bgTest then return end
	RequestScore(false)
	ScanHealthUnits()
	-- dead players come back after 30 s at the latest (graveyard); clear stale death flags
	for _, r in pairs(players) do
		if r.dead and now - r.hpTime > 35 then r.dead = false; r.hp = nil end
	end
	BG:Refresh()
end)

---------------------------------------------------------------------------
-- test
---------------------------------------------------------------------------
local TEST_PLAYERS = {
	{ "Shadowstep", "ROGUE", "Subtlety" }, { "Holybubble", "PALADIN", "Holy" }, { "Frostyboi", "MAGE", "Frost" },
	{ "Treehugger", "DRUID", "Restoration" }, { "Deathgrip", "DEATHKNIGHT", "Unholy" }, { "Pewpew", "HUNTER", "Marksmanship" },
	{ "Mindflay", "PRIEST", "Shadow" }, { "Chainheal", "SHAMAN", "Restoration" }, { "Fearbomb", "WARLOCK", "Affliction" },
	{ "Mortalstrike", "WARRIOR", "Arms" }, { "Discopriest", "PRIEST", "Discipline" }, { "Lavaburst", "SHAMAN", "Elemental" },
	{ "Stormstrike", "SHAMAN", "Enhancement" }, { "Boomkin", "DRUID", "Balance" }, { "Retpala", "PALADIN", "Retribution" },
}

function BG:SetTest(on)
	ns.db.bgTest = on
	for k in pairs(players) do players[k] = nil end
	friendlyFC, enemyFC = nil, nil
	if on then
		for i, t in ipairs(TEST_PLAYERS) do
			local r = Record(t[1])
			r.class, r.spec, r.role = t[2], t[3], ns.SpecRole[t[3]]
			r.hp = 1 - (i % 5) * 0.2
			r.hpTime = GetTime() - (i % 3) * 8
			r.kills, r.deaths, r.damage, r.healing = i % 4, i % 3, i * 12000, (r.role == "HEALER") and i * 30000 or i * 2000
			r.dead = (i == 9)
		end
		players.Shadowstep.flag = "Alliance"
		enemyFC = "Shadowstep"
		friendlyFC = "Me"
	end
	self:Rebuild()
	if not on then list:Hide() end
end

---------------------------------------------------------------------------
-- layout / init
---------------------------------------------------------------------------
function BG:OnLayout()
	local db = ns.db
	list:SetScale(db.bgScale)
	ns:SetPointFromTable(list, db.bgPoint)
	list:SetBackdropColor(0, 0, 0, db.bgBgAlpha)
	ns:SetFont(list.header, db.bgFontSize + 1)
	ns:SetFont(list.fcText, db.bgFontSize - 1)
	ns:SetFont(list.frozen, db.bgFontSize - 2)
	for i = 1, MAX_ROWS do
		local row = list.rows[i]
		ns:SetFont(row.name, db.bgFontSize)
		ns:SetFont(row.info, db.bgFontSize - 2)
		ns:SetFont(row.num, db.bgFontSize - 3)
	end
	self:Rebuild()
end

function BG:OnInit()
	ns:MakeMovable(list, "WArena battleground list", function(p) ns.db.bgPoint = p end)
	ns:RegisterMessage("LOCK_CHANGED", function(_, locked)
		ns:Show(list.mover, not locked)
		if not locked and not ns.state.inBG and not ns.db.bgTest then BG:SetTest(true)
		elseif locked and ns.db.bgTest and not (ns.OptionsOpen and ns:OptionsOpen()) then BG:SetTest(false) end
	end)
	ns:RegisterMessage("TEST_MODE", function(_, on)
		if on and not ns.state.inBG and not ns.db.bgTest then BG:SetTest(true) elseif not on and ns.db.bgTest then BG:SetTest(false) end
	end)
	ns.db.bgTest = false
	if not ns.db.locked then list.mover:Show() end
end

function BG:OnSettingChanged(key)
	if key:sub(1, 2) == "bg" then self:Rebuild() end
end

ns:AddCommand("bg", "toggle battleground list preview", function() BG:SetTest(not ns.db.bgTest) end)
