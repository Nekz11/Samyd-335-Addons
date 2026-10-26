-- WArena: totem tracker – icons for important enemy totems (grounding, tremor, cleansing, ...) with
-- remaining time; removed as soon as the totem dies
local _, ns = ...
local Totems = ns:NewModule("Totems")
ns.Totems = Totems

local floor, mmax, tsort = math.floor, math.max, table.sort
local GetTime = GetTime

ns:AddDefaults({
	totems = true, totemSize = 70, totemPos = "right", totemSpacing = 2, totemMax = 5,
	totemGrounding = true, totemTremor = true, totemCleansing = true, totemEarthbind = true, totemManaTide = true,
	totemStoneclaw = true, totemWindfury = false, totemFire = false,
})

-- key, option key, summon spell ids, duration
ns.TotemDB = {
	{ key = "Grounding", opt = "totemGrounding", ids = { 8177 }, dur = 45, prio = 1 },
	{ key = "Tremor",    opt = "totemTremor",    ids = { 8143 }, dur = 300, prio = 2 },
	{ key = "Cleansing", opt = "totemCleansing", ids = { 8170 }, dur = 300, prio = 3 },
	{ key = "ManaTide",  opt = "totemManaTide",  ids = { 16190 }, dur = 12, prio = 4 },
	{ key = "Earthbind", opt = "totemEarthbind", ids = { 2484 }, dur = 45, prio = 5 },
	{ key = "Stoneclaw", opt = "totemStoneclaw", ids = { 5730, 6390, 6391, 6392, 10427, 10428, 25525, 58580, 58581, 58582 }, dur = 15, prio = 6 },
	{ key = "Windfury",  opt = "totemWindfury",  ids = { 8512 }, dur = 300, prio = 7 },
	{ key = "Fire",      opt = "totemFire",      ids = { 3599, 6363, 6364, 6365, 10437, 10438, 25552, 58699, 58703, 58704, 8190, 10585, 10586, 10587, 25551, 58731, 58734, 58735 }, dur = 60, prio = 8 },
}

local byName = {}
local function Build()
	for _, t in ipairs(ns.TotemDB) do
		for _, id in ipairs(t.ids) do
			local name, _, icon = GetSpellInfo(id)
			if name then
				t.name, t.icon = t.name or name, t.icon or icon
				byName[name] = t
			end
		end
	end
end

local totemGUIDs = {} -- totem guid -> { frame, icon }

local function Layout(f)
	local cfg = f.cfg
	local list = {}
	for _, ic in pairs(f.totemIcons) do if ic.used then list[#list + 1] = ic end end
	tsort(list, function(a, b) return a.entry.prio < b.entry.prio end)
	local prev, n = nil, 0
	local size, gap = f.totemIconSize, cfg.totemSpacing
	for _, ic in ipairs(list) do
		if n < cfg.totemMax then
			n = n + 1
			ic:ClearAllPoints()
			if prev then ic:SetPoint("LEFT", prev, "RIGHT", gap, 0) else ic:SetPoint("LEFT", f.totemHolder, "LEFT", 0, 0) end
			prev = ic
			ic:Show()
		else
			ic:Hide()
		end
	end
	f.totemHolder:SetWidth(mmax(1, n * (size + gap) - gap))
end

local function OnExpire(self)
	self.used = nil
	if self.guid then totemGUIDs[self.guid] = nil end
	self.guid = nil
	self:Hide()
	Layout(self.owner)
end

local function GetIcon(f, entry)
	local ic = f.totemIcons[entry.key]
	if not ic then
		ic = ns:CreateIcon(f)
		ic.owner, ic.entry = f, entry
		ic.OnExpire = OnExpire
		ic.icon:SetTexture(entry.icon or ns.QMARK)
		ns:SetIconSize(ic, f.totemIconSize)
		ic:Hide()
		f.totemIcons[entry.key] = ic
	end
	return ic
end

function Totems:Summoned(f, entry, guid)
	local cfg = f.cfg
	if not cfg.totems or not cfg[entry.opt] then return end
	local ic = GetIcon(f, entry)
	if ic.guid then totemGUIDs[ic.guid] = nil end
	ic.used, ic.guid = true, guid
	if guid then totemGUIDs[guid] = ic end
	ns:StartIconCooldown(ic, GetTime(), entry.dur)
	ic.border:SetTexture(0.2, 0.8, 1, 1)
	Layout(f)
	ns:Fire("ENEMY_TOTEM", f, entry)
end

function Totems:Destroyed(guid)
	local ic = totemGUIDs[guid]
	if not ic then return end
	ns:StartIconCooldown(ic)
	OnExpire(ic)
end

function Totems:Clear(f)
	for _, ic in pairs(f.totemIcons) do
		if ic.guid then totemGUIDs[ic.guid] = nil end
		ic.used, ic.guid = nil, nil
		ns:StartIconCooldown(ic)
		ic:Hide()
	end
	Layout(f)
end

ns.Frames:RegisterElement("totems", {
	order = 32,
	create = function(f)
		f.totemIcons = {}
		f.totemIconSize = 26
		f.totemHolder = CreateFrame("Frame", nil, f)
		ns:Size(f.totemHolder, 1, 26)
	end,
	layout = function(f, cfg, chain)
		f.totemIconSize = mmax(10, floor(cfg.height * cfg.totemSize / 100))
		f.totemHolder:SetHeight(f.totemIconSize)
		for _, ic in pairs(f.totemIcons) do ns:SetIconSize(ic, f.totemIconSize) end
		if cfg.totems then
			local pos = chain:Side(cfg.totemPos)
			chain:Place(f.totemHolder, pos, (pos == "left" or pos == "right") and 8 or 4)
		else
			f.totemHolder:ClearAllPoints()
			f.totemHolder:SetPoint("LEFT", f, "RIGHT", 2000, 0)
		end
		Layout(f)
	end,
	reset = function(f) Totems:Clear(f) end,
	test = function(f, i)
		if not f.cfg.totems or i ~= 2 then return end
		Totems:Summoned(f, ns.TotemDB[1], "TESTTOTEM1")
		Totems:Summoned(f, ns.TotemDB[2], "TESTTOTEM2")
	end,
})

ns:RegisterMessage("ENEMY_CLEU", function(_, sub, sf, df, spellId, spellName, extra1, extra2, extra3, srcName, dstName)
	if sub == "SPELL_SUMMON" and sf and spellName then
		local entry = byName[spellName]
		if entry then Totems:Summoned(sf, entry, nil) end
	end
end)

-- totems are separate units: SPELL_SUMMON carries the totem's guid as destination
ns:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", function(_, _, sub, srcGUID, srcName, _, dstGUID, dstName, _, spellId, spellName)
	if not ns.state.inArena or ns.state.testMode then return end
	if sub == "SPELL_SUMMON" then
		local f = ns.Frames:ByGUID(srcGUID)
		local entry = f and spellName and byName[spellName]
		if entry and dstGUID then
			local ic = f.totemIcons[entry.key]
			if ic and ic.used then
				ic.guid = dstGUID
				totemGUIDs[dstGUID] = ic
			end
		end
	elseif sub == "UNIT_DIED" or sub == "UNIT_DESTROYED" then
		if dstGUID and totemGUIDs[dstGUID] then Totems:Destroyed(dstGUID) end
	end
end)

function Totems:OnInit() Build() end

function Totems:OnSettingChanged(key, value)
	if key == "totems" and not value then ns.Frames:Each(function(f) Totems:Clear(f) end) end
end
