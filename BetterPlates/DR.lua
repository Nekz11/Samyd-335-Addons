-- BetterPlates - Diminishing Returns
-- Verfolgt pro GUID die DR-Stufe je Kategorie aus dem Kampflog.
-- WotLK-Regel: Stufe 1 (volle Dauer) -> 1/2 -> 1/4 -> immun; Reset 18 s
-- nachdem die letzte Aura der Kategorie abgelaufen ist.

local ADDON, ns = ...
if type(ns) ~= "table" then BetterPlatesNS = BetterPlatesNS or {} ns = BetterPlatesNS ADDON = "BetterPlates" end

local D = {}
ns.DR = D

local pairs, ipairs, wipe, floor, format, min = pairs, ipairs, wipe, math.floor, string.format, math.min
local GetTime, GetSpellInfo = GetTime, GetSpellInfo
local band = bit.band
local PLAYER_FLAG = COMBATLOG_OBJECT_TYPE_PLAYER or 0x400
local HOSTILE_FLAG = COMBATLOG_OBJECT_REACTION_HOSTILE or 0x40

D.RESET = 18
D.MAX_ACTIVE = 15   -- längster CC in WotLK (ohne Verbannen); danach gilt die Aura als abgelaufen
D.store = {}        -- [GUID] = { [cat] = { level = n, expires = t, applied = t, active = bool, icon = tex } }
D.catOrder = { "stun", "cheapshot", "fear", "horror", "incapacitate", "disorient", "silence", "root", "entrapment", "cyclone", "banish", "sleep", "charge", "disarm", "mc" }

local pool = {}
local function NewEntry()
	local n = #pool
	if n > 0 then local e = pool[n] pool[n] = nil return e end
	return {}
end
local function Free(e)
	e.level, e.expires, e.applied, e.active, e.icon = nil, nil, nil, nil, nil
	pool[#pool + 1] = e
end

-- Stufenfarbe: 1 = grün (nächste Anwendung halb), 2 = gelb (viertel), 3 = rot (immun)
D.LEVEL_COLORS = { { 0.2, 0.9, 0.2 }, { 1, 0.85, 0.1 }, { 1, 0.2, 0.2 } }
D.LEVEL_TEXT = { "½", "¼", "0" }

local function Category(spellId)
	local t = ns.DR_SPELLS
	return t and t[spellId]
end

local function Applied(guid, cat, spellId, now)
	local t = D.store[guid]
	if not t then t = {} D.store[guid] = t end
	local e = t[cat]
	if not e then
		e = NewEntry()
		e.level = 0
		t[cat] = e
	end
	-- aktive Aura, deren Ende wir verpasst haben (kein REMOVED-Ereignis): als abgelaufen behandeln
	if e.active and e.applied and now - e.applied > D.MAX_ACTIVE then
		e.active = false
		e.expires = e.applied + D.MAX_ACTIVE + D.RESET
	end
	-- abgelaufen und Reset vorbei -> neu anfangen
	if e.expires and now > e.expires and not e.active then
		e.level = 0
	end
	e.level = min((e.level or 0) + 1, 3)
	e.active = true
	e.applied = now
	e.expires = nil
	local _, _, icon = GetSpellInfo(spellId)
	e.icon = icon or e.icon
end

local function Removed(guid, cat, now)
	local t = D.store[guid]
	local e = t and t[cat]
	if not e then return end
	e.active = false
	e.expires = now + D.RESET
end

ns:On("COMBAT_LOG_EVENT_UNFILTERED", function(_, _, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, _, auraType)
	if not dstGUID or auraType ~= "DEBUFF" then return end
	local db = ns.db
	if not db or not db.dr then return end
	if event ~= "SPELL_AURA_APPLIED" and event ~= "SPELL_AURA_REFRESH" and event ~= "SPELL_AURA_REMOVED" then return end
	local cat = Category(spellId)
	if not cat then return end
	if db.drOnlyPlayers and dstFlags and band(dstFlags, PLAYER_FLAG) == 0 then return end
	if db.drOnlyEnemies and dstFlags and band(dstFlags, HOSTILE_FLAG) == 0 then return end
	local now = GetTime()
	if event == "SPELL_AURA_REMOVED" then
		Removed(dstGUID, cat, now)
	else
		Applied(dstGUID, cat, spellId, now)
	end
end)

-- Aufräumen (alle 30 s vom Plates-Tick aufgerufen)
function D:Cleanup()
	local now = GetTime()
	for guid, t in pairs(self.store) do
		for cat, e in pairs(t) do
			if e.active and e.applied and now - e.applied > D.MAX_ACTIVE then
				e.active = false
				e.expires = e.applied + D.MAX_ACTIVE + D.RESET
			end
			if not e.active and e.expires and now > e.expires then
				t[cat] = nil
				Free(e)
			end
		end
		if not next(t) then self.store[guid] = nil end
	end
end
ns:On("PLAYER_ENTERING_WORLD", function() D:Reset() end)

function D:Reset()
	for guid, t in pairs(self.store) do
		for cat, e in pairs(t) do Free(e) end
		self.store[guid] = nil
	end
end

----------------------------------------------------------------
-- Anzeige auf der Plakette
----------------------------------------------------------------
local list = {}
local function Sorter(a, b) return a.order < b.order end

local function GetIcon(d, i)
	local icons = d.drIcons
	local b = icons[i]
	if b then return b end
	b = CreateFrame("Frame", nil, d.drFrame)
	b.tex = b:CreateTexture(nil, "ARTWORK")
	b.tex:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	b.tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints(b)
	b.bg:SetTexture(0, 0, 0, 1)
	b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	b.cd:SetAllPoints(b.tex)
	if b.cd.SetReverse then b.cd:SetReverse(true) end
	b.cd.noCooldownCount = true
	local over = CreateFrame("Frame", nil, b)
	over:SetAllPoints(b)
	over:SetFrameLevel(b:GetFrameLevel() + 5)
	b.text = over:CreateFontString(nil, "OVERLAY")
	b.text:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
	b.time = over:CreateFontString(nil, "OVERLAY")
	b.time:SetPoint("TOP", b, "BOTTOM", 0, 1)
	icons[i] = b
	return b
end

local function SetFont(fs, font, size)
	if fs.font ~= font or fs.size ~= size then
		fs.font, fs.size = font, size
		fs:SetFont(font, size, "OUTLINE")
	end
end

function D:UpdatePlate(d)
	local db = ns.db
	local icons = d.drIcons
	local n = 0
	local t = db.dr and d.guid and self.store[d.guid]
	local inst = ns.instanceType
	if t and not db.drInWorld and not d.testRaidPrio and inst ~= "arena" and inst ~= "pvp" then t = nil end

	if t then
		wipe(list)
		local now = GetTime()
		local cats = db.drCats
		local order = 0
		for _, cat in ipairs(self.catOrder) do
			order = order + 1
			local e = t[cat]
			if e and e.active and e.applied and now - e.applied > D.MAX_ACTIVE then
				e.active = false
				e.expires = e.applied + D.MAX_ACTIVE + D.RESET
			end
			if e and (cats == nil or cats[cat] ~= false) then
				if e.active or (e.expires and now <= e.expires) then
					e.cat = cat
					e.order = order
					list[#list + 1] = e
				end
			end
		end
		n = min(#list, 6)
		local size = db.drSize
		local font = ns.GetFont and ns.GetFont() or "Fonts\\FRIZQT__.TTF"
		local total = n * size + (n - 1) * 2
		local x = -total / 2
		for i = 1, n do
			local e = list[i]
			local b = GetIcon(d, i)
			if b.size ~= size then
				b.size = size
				b:SetWidth(size)
				b:SetHeight(size)
				SetFont(b.text, font, floor(size * 0.55))
				SetFont(b.time, font, floor(size * 0.45))
			end
			b:ClearAllPoints()
			b:SetPoint("BOTTOMLEFT", d.drFrame, "BOTTOM", x, 10)
			x = x + size + 2
			if b.icon ~= e.icon then
				b.icon = e.icon
				b.tex:SetTexture(e.icon)
			end
			local lvl = e.level or 1
			if lvl < 1 then lvl = 1 elseif lvl > 3 then lvl = 3 end
			if b.level ~= lvl then
				b.level = lvl
				local c = D.LEVEL_COLORS[lvl]
				b.bg:SetTexture(c[1], c[2], c[3], 1)
				b.text:SetText(D.LEVEL_TEXT[lvl])
				b.text:SetTextColor(c[1], c[2], c[3])
			end
			if e.active then
				b.time:SetText("")
				if b.cdActive then b.cdActive = false b.cd:Hide() end
			else
				local rem = e.expires - now
				b.time:SetFormattedText("%d", rem > 0 and rem or 0)
				if b.cdStart ~= e.expires then
					b.cdStart = e.expires
					b.cd:SetCooldown(e.expires - D.RESET, D.RESET)
					b.cd:Show()
					b.cdActive = true
				end
			end
			if not b.shown then b.shown = true b:Show() end
		end
	end
	for i = n + 1, #icons do
		local b = icons[i]
		if b.shown then b.shown = false b:Hide() end
	end
	if d.drShown ~= (n > 0) then
		d.drShown = n > 0
		if n > 0 then d.drFrame:Show() else d.drFrame:Hide() end
	end
	return n
end

-- Testmodus: drei Kategorien mit unterschiedlichen Stufen
function D:Fake(guid)
	local now = GetTime()
	local t = self.store[guid]
	if not t then t = {} self.store[guid] = t end
	local samples = { { "stun", 853, 1 }, { "incapacitate", 118, 2 }, { "silence", 2139, 3 } }
	for _, s in ipairs(samples) do
		local e = t[s[1]] or NewEntry()
		t[s[1]] = e
		e.level = s[3]
		e.active = false
		e.expires = now + D.RESET
		e.applied = now
		local _, _, icon = GetSpellInfo(s[2])
		e.icon = icon
	end
end

function D:Clear(guid)
	local t = self.store[guid]
	if not t then return end
	for cat, e in pairs(t) do Free(e) end
	self.store[guid] = nil
end
