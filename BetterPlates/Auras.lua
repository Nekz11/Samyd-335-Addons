-- BetterPlates - Auras
-- 3.3.5a-Plaketten haben keine Unit-Zuordnung, UnitAura geht nur über
-- target/focus/mouseover/party/arena. Deshalb: Combat-Log + Unit-Scans,
-- gespeichert pro GUID, und die Plakette sucht sich ihre GUID.

local ADDON, ns = ...
if type(ns) ~= "table" then BetterPlatesNS = BetterPlatesNS or {} ns = BetterPlatesNS ADDON = "BetterPlates" end
local A = {}
ns.Auras = A

local store = {}       -- [GUID] = { [key] = aura }
local durations = {}   -- [Spell-ID] = zuletzt gesehene Dauer
A.store = store

local GetTime, GetSpellInfo, UnitAura, UnitGUID = GetTime, GetSpellInfo, UnitAura, UnitGUID
local pairs, wipe, sort, min, format, ceil = pairs, wipe, table.sort, math.min, string.format, math.ceil
local band = bit.band
local PLAYER_FLAG = COMBATLOG_OBJECT_TYPE_PLAYER or 0x400
local HOSTILE_FLAG = COMBATLOG_OBJECT_REACTION_HOSTILE or 0x40
local DISPEL_COLORS = { Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0.2, 1 }, Poison = { 0.2, 0.8, 0.2 }, Disease = { 0.6, 0.4, 0.1 } }
ns.DISPEL_COLORS = DISPEL_COLORS

-- Tabellen wiederverwenden: in der Arena feuert UNIT_AURA sehr oft, und jede
-- neue Tabelle landet beim Garbage Collector (Ruckler).
local pool = {}
local function NewAura()
	local n = #pool
	if n > 0 then
		local a = pool[n]
		pool[n] = nil
		return a
	end
	return {}
end
local function FreeAura(a)
	a.lockout, a.mineBuff, a.dispel = nil, nil, nil
	pool[#pool + 1] = a
end

local AURA_ADD = { SPELL_AURA_APPLIED = true, SPELL_AURA_REFRESH = true, SPELL_AURA_APPLIED_DOSE = true }
local AURA_REMOVE = { SPELL_AURA_REMOVED = true, SPELL_AURA_BROKEN = true, SPELL_AURA_BROKEN_SPELL = true }
local HEAL_EVENTS = {
	SPELL_CAST_SUCCESS = true, SPELL_HEAL = true, SPELL_PERIODIC_HEAL = true,
	SPELL_AURA_APPLIED = true, SPELL_SUMMON = true,
}

local WATCH_UNITS = {
	target = true, focus = true, mouseover = true,
	party1 = true, party2 = true, party3 = true, party4 = true,
	arena1 = true, arena2 = true, arena3 = true, arena4 = true, arena5 = true,
}

----------------------------------------------------------------
-- Combat-Log
----------------------------------------------------------------
-- 3.3.5a-Format: timestamp, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...
ns:On("COMBAT_LOG_EVENT_UNFILTERED", function(_, _, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, _, auraType, amount)
	if not ns.pvpAuras then return end

	if srcName and srcFlags and band(srcFlags, PLAYER_FLAG) > 0 then
		ns:CacheGUID(srcGUID, srcName)
		if spellName and HEAL_EVENTS[event] and ns.healerSpells[spellName] then
			ns.healers[srcName] = true
		end
	end
	if dstName and dstFlags and band(dstFlags, PLAYER_FLAG) > 0 then
		ns:CacheGUID(dstGUID, dstName)
	end

	if not dstGUID then return end

	if AURA_ADD[event] then
		-- Flaggenträger (Schlachtfeld)
		local flagSide = ns.FLAG_AURAS and ns.FLAG_AURAS[spellId]
		if flagSide then
			ns.flagCarriers[dstGUID] = flagSide
			if ns.db.flagSound and event == "SPELL_AURA_APPLIED" and dstFlags and band(dstFlags, HOSTILE_FLAG) > 0 then
				ns.PlayAlert(ns.db.castSoundId)
			end
		end
		if ns.auraBlock[spellName] then return end
		local isMe = srcGUID == ns.playerGUID
		local mine = isMe and auraType == "DEBUFF"
		local mineBuff = isMe and auraType == "BUFF" and ns.myBuffs[spellName] and true or false
		local cat = ns.pvpAuras[spellName] or (ns.auraExtra[spellName] and "custom") or nil
		if not mine and not mineBuff and not cat then return end

		local t = store[dstGUID]
		if not t then
			t = {}
			store[dstGUID] = t
		end
		local key = mine and ("m" .. spellId) or (mineBuff and ("b" .. spellId)) or spellId
		local a = t[key]
		if not a then
			a = NewAura()
			t[key] = a
		end
		local now = GetTime()
		local dur = durations[spellId] or 0
		local _, _, icon = GetSpellInfo(spellId)
		a.spellId = spellId
		a.name = spellName
		a.icon = icon
		a.duration = dur
		a.expires = dur > 0 and (now + dur) or 0
		a.added = now
		if event == "SPELL_AURA_APPLIED_DOSE" then
			a.count = amount or 0
		elseif event == "SPELL_AURA_APPLIED" then
			a.count = 0
		end
		a.cat = cat
		a.mine = mine
		a.mineBuff = mineBuff
		a.prio = cat and ns.AURA_PRIO[cat] or (mineBuff and 8) or 10

	elseif AURA_REMOVE[event] then
		if ns.FLAG_AURAS and ns.FLAG_AURAS[spellId] then ns.flagCarriers[dstGUID] = nil end
		local t = store[dstGUID]
		if t then
			t[spellId] = nil
			t["d" .. spellId] = nil
			if srcGUID == ns.playerGUID or event ~= "SPELL_AURA_REMOVED" then
				t["m" .. spellId] = nil
				t["b" .. spellId] = nil
			end
		end

	elseif event == "SPELL_CAST_SUCCESS" and ns.TRINKETS and ns.TRINKETS[spellId] then
		-- PvP-Schmuck / Jeder Mann für sich: Cooldown merken
		ns.trinkets[srcGUID] = { ready = GetTime() + ns.TRINKETS[spellId] }

	elseif event == "SPELL_SUMMON" and dstName then
		local dur = ns.TOTEM_DURATION and ns.TOTEM_DURATION[spellId]
		if dur then
			local s = ns.totemSummons[dstName]
			if not s then s = {} ns.totemSummons[dstName] = s end
			s.expires = GetTime() + dur
			s.duration = dur
			s.guid = dstGUID
		end

	elseif event == "SPELL_INTERRUPT" then
		-- Unterbrechung = Schul-Lockout als Pseudo-Aura (blauer Rahmen)
		local lock = ns.LOCKOUTS and ns.LOCKOUTS[spellId]
		if lock then
			local t = store[dstGUID]
			if not t then t = {} store[dstGUID] = t end
			local a = t["lock"] or NewAura()
			t["lock"] = a
			local _, _, icon = GetSpellInfo(spellId)
			local now = GetTime()
			a.spellId = spellId
			a.name = spellName
			a.icon = icon
			a.duration = lock
			a.expires = now + lock
			a.added = now
			a.count = 0
			a.cat = "silence"
			a.lockout = true
			a.mine = false
			a.prio = ns.AURA_PRIO.silence
			a.stamp = -1
		end
	elseif event == "UNIT_DIED" or event == "UNIT_DESTROYED" then
		store[dstGUID] = nil
		ns.flagCarriers[dstGUID] = nil
		if ns.DR then ns.DR:Clear(dstGUID) end
	end
end)

-- Nebentabellen (Flaggen, Schmuck, Totems)
ns.flagCarriers = {}
ns.trinkets = {}
ns.totemSummons = {}
ns.myBuffs = ns.myBuffs or {}
function ns.CleanupTracking()
	local now = GetTime()
	for guid, t in pairs(ns.trinkets) do
		if t.ready < now then ns.trinkets[guid] = nil end
	end
	for name, s in pairs(ns.totemSummons) do
		if s.expires < now then ns.totemSummons[name] = nil end
	end
end

-- Alarmton (Index in ns.SOUNDS)
ns.SOUNDS = {
	{ "Raid warning", "RaidWarning" },
	{ "Ready check", "ReadyCheck" },
	{ "Whisper", "TellMessage" },
	{ "PvP queue", "PVPTHROUGHQUEUE" },
	{ "Quest failed", "igQuestFailed" },
	{ "Level up", "LevelUp" },
	{ "Auction window", "AuctionWindowOpen" },
}
local lastAlert = 0
function ns.PlayAlert(id)
	local now = GetTime()
	if now - lastAlert < 1 then return end
	lastAlert = now
	local s = ns.SOUNDS[id or 1] or ns.SOUNDS[1]
	pcall(PlaySound, s[2])
end

----------------------------------------------------------------
-- Unit-Scan (genaue Dauer + Abgleich)
----------------------------------------------------------------
local FILTERS = { "HARMFUL", "HELPFUL" }

local scanStamp = 0

function A:ScanUnit(unit)
	if not ns.pvpAuras then return end
	local guid = UnitGUID(unit)
	if not guid then return end

	local t = store[guid]
	if not t then
		t = {}
		store[guid] = t
	end
	local now = GetTime()
	scanStamp = scanStamp + 1
	local stamp = scanStamp

	for f = 1, #FILTERS do
		local filter = FILTERS[f]
		local friendlyUnit = UnitIsFriend and UnitIsFriend("player", unit)
		for i = 1, 40 do
			local name, _, icon, count, dtype, duration, expires, caster, _, _, spellId = UnitAura(unit, i, filter)
			if not name then break end
			local mine = filter == "HARMFUL" and caster == "player"
			local mineBuff = filter == "HELPFUL" and caster == "player" and ns.myBuffs[name] and true or false
			local dispel = nil
			if filter == "HARMFUL" and friendlyUnit and dtype and dtype ~= "" and ns.db.dispelIndicator then
				if ns.db.dispelAll or (ns.canDispel and ns.canDispel[dtype]) then dispel = dtype end
			end
			local cat = ns.pvpAuras[name] or (ns.auraExtra[name] and "custom") or nil
			if (mine or mineBuff or dispel or cat) and not ns.auraBlock[name] then
				local id = spellId or name
				if spellId and duration and duration > 0 then durations[spellId] = duration end
				local key = mine and ("m" .. id) or (mineBuff and ("b" .. id)) or (dispel and ("d" .. id)) or id
				duration = duration or 0
				expires = expires or 0
				local a = t[key]
				if not a then
					a = NewAura()
					t[key] = a
					a.added = now
				elseif duration == 0 and a.expires > now then
					-- Fremde Auren liefern teils keine Dauer: bekannte Restzeit behalten
					duration, expires = a.duration, a.expires
				end
				a.spellId = spellId
				a.name = name
				a.icon = icon
				a.duration = duration
				a.expires = expires
				a.count = count or 0
				a.cat = cat
				a.mine = mine
				a.mineBuff = mineBuff
				a.dispel = dispel
				a.prio = cat and ns.AURA_PRIO[cat] or (dispel and 1.5) or (mineBuff and 8) or 10
				a.stamp = stamp
			end
		end
	end

	-- alles, was der Scan nicht mehr gesehen hat, ist weg (Lockouts bleiben, die sieht UnitAura nicht)
	for key, a in pairs(t) do
		if a.stamp ~= stamp and key ~= "lock" then
			t[key] = nil
			FreeAura(a)
		end
	end
end

-- UNIT_AURA bündeln: pro Einheit höchstens ein Scan pro Tick
local dirty = {}
local anyDirty = false

function A:Flush()
	if not anyDirty then return end
	anyDirty = false
	for unit in pairs(dirty) do
		dirty[unit] = nil
		A:ScanUnit(unit)
	end
end

local function MarkDirty(unit)
	dirty[unit] = true
	anyDirty = true
end

ns:On("UNIT_AURA", function(_, unit)
	if WATCH_UNITS[unit] then MarkDirty(unit) end
end)
ns:On("PLAYER_TARGET_CHANGED", function() A:ScanUnit("target") end)
ns:On("PLAYER_FOCUS_CHANGED", function() A:ScanUnit("focus") end)
ns:On("UPDATE_MOUSEOVER_UNIT", function() A:ScanUnit("mouseover") end)
ns:On("ARENA_OPPONENT_UPDATE", function(_, unit)
	if unit and WATCH_UNITS[unit] then MarkDirty(unit) end
end)
ns:On("PLAYER_ENTERING_WORLD", function() wipe(store) end)

-- Alte Einträge entfernen (wird von Plates alle 30 s aufgerufen)
function A:Cleanup()
	local now = GetTime()
	for guid, t in pairs(store) do
		for key, a in pairs(t) do
			if (a.expires > 0 and a.expires < now) or (a.expires == 0 and now - (a.added or 0) > 120) then
				t[key] = nil
				FreeAura(a)
			end
		end
		if not next(t) then store[guid] = nil end
	end
end

----------------------------------------------------------------
-- Anzeige auf der Plakette
----------------------------------------------------------------
local list = {}

local function Sorter(a, b)
	local pa, pb = a.prio, b.prio
	if ns.db.auraMineFirst then
		if a.mine then pa = 0.5 end
		if b.mine then pb = 0.5 end
	end
	if pa ~= pb then return pa < pb end
	local ea, eb = a.expires, b.expires
	if ea ~= eb then
		if ea == 0 then return false end
		if eb == 0 then return true end
		return ea < eb
	end
	return (a.name or "") < (b.name or "")
end

local function GetIcon(d, i)
	local icons = d.auraIcons
	local b = icons[i]
	if b then return b end

	b = CreateFrame("Frame", nil, d.auraFrame)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints(b)
	b.tex = b:CreateTexture(nil, "ARTWORK")
	b.tex:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	b.tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	b.cd:SetAllPoints(b.tex)
	if b.cd.SetReverse then b.cd:SetReverse(true) end
	-- OmniCC & Co. sollen keinen eigenen Text auf unsere Icons schreiben
	b.cd.noCooldownCount = true
	b.cd.noOCC = true

	local ov = CreateFrame("Frame", nil, b)
	ov:SetAllPoints(b)
	ov:SetFrameLevel(b.cd:GetFrameLevel() + 2)
	b.time = ov:CreateFontString(nil, "OVERLAY")
	b.time:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.count = ov:CreateFontString(nil, "OVERLAY")
	b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, 0)

	icons[i] = b
	return b
end

local function FormatTime(rem)
	if rem >= 60 then
		return format("%dm", ceil(rem / 60))
	elseif rem >= 10 then
		return format("%d", rem)
	end
	return format("%.1f", rem)
end

-- Icons in Reihen anordnen (zentriert / links / rechts, 1-2 Reihen, Schlüssel-Auren größer)
local rowW = {}
local function Layout(d, n, sizes)
	local db = ns.db
	local icons = d.auraIcons
	local rows = db.auraRows or 1
	local perRow = math.ceil(n / rows)
	if perRow < 1 then perRow = 1 end
	local gap = db.auraSpacing or 2
	local grow = db.auraGrow or 1
	-- Breite je Reihe
	wipe(rowW)
	local maxW, rowH = 0, {}
	for i = 1, n do
		local r = math.ceil(i / perRow)
		rowW[r] = (rowW[r] or 0) + sizes[i] + (i > 1 and ((i - 1) % perRow ~= 0) and gap or 0)
		rowH[r] = math.max(rowH[r] or 0, sizes[i])
		if rowW[r] > maxW then maxW = rowW[r] end
	end
	local y = 0
	local i = 1
	for r = 1, math.ceil(n / perRow) do
		local x
		if grow == 2 then x = 0
		elseif grow == 3 then x = maxW - rowW[r]
		else x = (maxW - rowW[r]) / 2 end
		for k = 1, perRow do
			if i > n then break end
			local b = icons[i]
			b:ClearAllPoints()
			b:SetPoint("BOTTOMLEFT", d.auraFrame, "BOTTOMLEFT", x, y)
			x = x + sizes[i] + gap
			i = i + 1
		end
		y = y + rowH[r] + gap
	end
	d.auraFrame:SetWidth(maxW)
	d.auraFrame:SetHeight(y - gap)
end

local sizes = {}
function A:UpdatePlate(d)
	local db = ns.db
	local icons = d.auraIcons
	local n = 0
	local t = db.auras and d.guid and store[d.guid]
	if t and db.auraOnlyTarget and not d.isTarget then t = nil end

	if t then
		wipe(list)
		local now = GetTime()
		local cats = db.auraCats
		for key, a in pairs(t) do
			if a.expires > 0 and a.expires < now then
				t[key] = nil
			elseif a.lockout then
				if db.lockoutAura then list[#list + 1] = a end
			elseif a.dispel then
				if db.dispelIndicator then list[#list + 1] = a end
			elseif a.mineBuff then
				if db.myBuffsOnFriends then list[#list + 1] = a end
			elseif a.mine and db.myDebuffs then
				list[#list + 1] = a
			elseif a.cat and db.pvpAuras and (a.cat == "custom" or not cats or cats[a.cat] ~= false) then
				list[#list + 1] = a
			end
		end
		sort(list, Sorter)
		n = min(#list, db.maxAuras)

		local base = db.auraSize
		local font = ns.GetFont and ns.GetFont() or (ns.fonts[db.font] or ns.fonts[1])[2]
		local layoutKey = 0
		for i = 1, n do
			local a = list[i]
			local b = GetIcon(d, i)
			local size = base
			if ns.keyAuras[a.name] then size = floor(base * 1.4 + 0.5) end
			sizes[i] = size
			layoutKey = layoutKey * 64 + size

			if b.size ~= size or b.font ~= font then
				b.size, b.font = size, font
				b:SetWidth(size)
				b:SetHeight(size)
				b.time:SetFont(font, math.max(size * 0.45, 7), "OUTLINE")
				b.count:SetFont(font, math.max(size * 0.4, 7), "OUTLINE")
				d.auraLayoutKey = nil
			end

			if b.iconPath ~= a.icon then
				b.iconPath = a.icon
				b.tex:SetTexture(a.icon)
			end
			local cat = a.cat or (a.dispel and ("d" .. a.dispel)) or (a.mineBuff and "hot") or "none"
			if b.bgCat ~= cat then
				b.bgCat = cat
				local c = a.cat and ns.AURA_COLORS[a.cat] or (a.dispel and DISPEL_COLORS[a.dispel]) or (a.mineBuff and ns.AURA_COLORS.hot)
				if c then
					b.bg:SetTexture(c[1], c[2], c[3], 1)
				else
					b.bg:SetTexture(0, 0, 0, 1)
				end
			end

			if b.cdExp ~= a.expires then
				b.cdExp = a.expires
				if a.duration > 0 and a.expires > 0 then
					b.cd:SetCooldown(a.expires - a.duration, a.duration)
					b.cd:Show()
				else
					b.cd:Hide()
				end
			end

			if db.auraTimer and a.expires > 0 then
				local rem = a.expires - now
				b.time:SetText(FormatTime(rem))
				-- Pandemic: eigene DoTs mit < 30 % Restzeit rot (Zeit zum Erneuern)
				local pand = db.pandemic and a.mine and a.duration > 0 and rem < a.duration * 0.3
				if b.pand ~= pand then
					b.pand = pand
					if pand then b.time:SetTextColor(1, 0.3, 0.3) else b.time:SetTextColor(1, 1, 1) end
				end
			else
				b.time:SetText("")
			end
			local cnt = (db.auraStacks and a.count and a.count > 1) and a.count or 0
			if b.lastCount ~= cnt then
				b.lastCount = cnt
				b.count:SetText(cnt > 0 and cnt or "")
			end
			b:Show()
		end
		layoutKey = layoutKey * 16 + (db.auraRows or 1) * 4 + (db.auraGrow or 1)
		if d.auraLayoutKey ~= layoutKey or d.auraLayoutN ~= n then
			d.auraLayoutKey, d.auraLayoutN = layoutKey, n
			Layout(d, n, sizes)
		end
	end

	for i = n + 1, #icons do
		icons[i]:Hide()
	end

	if n > 0 then
		d.auraFrame:Show()
	else
		d.auraFrame:Hide()
	end
end


----------------------------------------------------------------
-- Zauberleisten aus dem Kampflog
-- Der 3.3.5a-Client zeigt Blizzards Plaketten-Zauberleiste nur beim Ziel.
-- Für alle anderen Plaketten mit bekannter GUID bauen wir die Leiste aus
-- SPELL_CAST_START / SUCCESS / FAILED / INTERRUPT nach.
----------------------------------------------------------------
local C = {}
ns.Casts = C
local casts = {}        -- [GUID] = { name, icon, start, duration, channel }
C.store = casts
C.castDur = {}          -- [Zaubername] = tatsächliche Dauer (von UnitCastingInfo gelernt)
local castPool = {}

-- Kanalisierte Zauber: Spell-ID -> Basisdauer in Sekunden
local CHANNELS = {
	[15407] = 3,   -- Gedankenschinden
	[48045] = 5,   -- Gedankenschlag
	[47540] = 2,   -- Sühne
	[64901] = 8,   -- Hymne der Hoffnung
	[64843] = 8,   -- Göttliche Hymne
	[689] = 5,     -- Blutsauger
	[1120] = 15,   -- Seelendieb
	[5138] = 5,    -- Mana entziehen
	[5740] = 8,    -- Feuerregen
	[1949] = 15,   -- Höllenfeuer
	[755] = 10,    -- Gesundheitsentzug
	[5143] = 5,    -- Arkane Geschosse
	[10] = 8,      -- Blizzard
	[12051] = 6,   -- Hervorrufung
	[740] = 8,     -- Gelassenheit
	[16914] = 10,  -- Hurrikan
	[1510] = 6,    -- Salve
	[20577] = 10,  -- Kannibalismus
	[746] = 8,     -- Erste Hilfe
	[27640] = 2,   -- Baron Rivendares Seelenentzug (Beispiel NPC)
}
local channelByName

local function BuildChannels()
	channelByName = {}
	for id, dur in pairs(CHANNELS) do
		local name = GetSpellInfo(id)
		if name then channelByName[name] = dur end
	end
end

local function NewCast()
	local n = #castPool
	if n > 0 then local c = castPool[n] castPool[n] = nil return c end
	return {}
end

local function EndCast(guid)
	local c = casts[guid]
	if c then
		casts[guid] = nil
		castPool[#castPool + 1] = c
	end
end
C.EndCast = EndCast

local function StartCast(guid, spellId, spellName, channel, now)
	if not channelByName then BuildChannels() end
	local name, _, icon, _, _, _, castTime = GetSpellInfo(spellId)
	name = spellName or name
	local duration
	if channel then
		duration = channelByName[name]
	else
		duration = C.castDur[name] or (castTime and castTime > 0 and castTime / 1000) or nil
	end
	if not duration or duration <= 0 then return end
	if ns.castHide[name] then return end
	local c = casts[guid] or NewCast()
	casts[guid] = c
	c.name = name
	c.icon = icon
	c.start = now
	c.duration = duration
	c.channel = channel and true or false
	c.spellId = spellId
	c.interruptedAt = nil
	c.interruptedBy = nil
	c.emphasis = ns.castEmphasis and ns.castEmphasis[name] or false
	if c.emphasis and ns.db.castSound then ns.PlayAlert(ns.db.castSoundId) end
end

ns:On("COMBAT_LOG_EVENT_UNFILTERED", function(_, _, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName)
	if not srcGUID then return end
	if event == "SPELL_CAST_START" then
		StartCast(srcGUID, spellId, spellName, false, GetTime())
	elseif event == "SPELL_CAST_SUCCESS" then
		local c = casts[srcGUID]
		if c and not c.channel and (c.spellId == spellId or c.name == spellName) then
			-- Zauber fertig
			EndCast(srcGUID)
		else
			if not channelByName then BuildChannels() end
			if channelByName[spellName] then StartCast(srcGUID, spellId, spellName, true, GetTime()) end
		end
	elseif event == "SPELL_CAST_FAILED" then
		EndCast(srcGUID)
	elseif event == "SPELL_INTERRUPT" then
		local c = dstGUID and casts[dstGUID]
		if c then
			-- kurz rot "Unterbrochen" zeigen, dann weg
			c.interruptedAt = GetTime()
			c.interruptedBy = srcName
		end
	elseif event == "UNIT_DIED" or event == "UNIT_DESTROYED" then
		if dstGUID then EndCast(dstGUID) end
	end
end)

-- Echte Zauberzeiten lernen (Haste), wenn wir eine Einheit direkt sehen
function C:Learn(unit)
	local name, _, _, _, startTime, endTime = UnitCastingInfo(unit)
	if name and startTime and endTime and endTime > startTime then
		C.castDur[name] = (endTime - startTime) / 1000
	end
end

-- Abgelaufene Zauber wegräumen (vom Plates-Tick aufgerufen)
function C:Expire(now)
	for guid, c in pairs(casts) do
		if c.interruptedAt then
			if now > c.interruptedAt + 0.8 then EndCast(guid) end
		elseif now > c.start + c.duration + 0.5 then
			EndCast(guid)
		end
	end
end

-- Höchste Auren-Kategorie einer Einheit (für Balkenfarbe nach Aura)
function A:TopCategory(guid)
	local t = guid and store[guid]
	if not t then return end
	local best, bestPrio = nil, 99
	local now = GetTime()
	for _, a in pairs(t) do
		if a.cat and a.prio < bestPrio and (a.expires == 0 or a.expires > now) then
			best, bestPrio = a.cat, a.prio
		end
	end
	return best
end

ns:On("PLAYER_ENTERING_WORLD", function() wipe(casts) end)
