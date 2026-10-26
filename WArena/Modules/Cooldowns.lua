-- WArena: enemy cooldown tracker – one row of icons per enemy, driven by the combat log
local _, ns = ...
local CD = ns:NewModule("Cooldowns")
ns.Cooldowns = CD

local floor, mmax, mmin, tsort = math.floor, math.max, math.min, table.sort
local GetTime = GetTime

ns:AddDefaults({
	cooldowns = true, cdSize = 70, cdPos = "below", cdMax = 8, cdShowReady = true, cdReadyAlpha = 0.45,
	cdGlow = true, cdSpacing = 2, cdUsageFlash = 5,
	cdInterrupt = true, cdDefensive = true, cdExternal = true, cdOffensive = true, cdCc = true, cdUtility = false, cdHeal = true,
})

local function CatKey(cat) return "cd" .. cat:sub(1, 1):upper() .. cat:sub(2) end
CD.CatKey = CatKey

local function Sorter(a, b)
	if a.entry.prio ~= b.entry.prio then return a.entry.prio < b.entry.prio end
	local ea, eb = a.expires or 0, b.expires or 0
	if (ea > 0) ~= (eb > 0) then return ea > 0 end -- on cooldown first
	if ea ~= eb then return ea < eb end
	return a.entry.id < b.entry.id
end

local function Layout(f)
	local cfg = f.cfg
	local list = {}
	for _, ic in pairs(f.cds) do
		if ic.used then list[#list + 1] = ic end
	end
	tsort(list, Sorter)
	local size, gap, maxN = f.cdIconSize, cfg.cdSpacing, cfg.cdMax
	local prev, n = nil, 0
	local vertical = false
	local leftward = cfg.cdPos == "left"
	for i, ic in ipairs(list) do
		if n < maxN then
			n = n + 1
			ic:ClearAllPoints()
			if leftward then
				if prev then ic:SetPoint("RIGHT", prev, "LEFT", -gap, 0) else ic:SetPoint("RIGHT", f.cdHolder, "RIGHT", 0, 0) end
			else
				if prev then ic:SetPoint("LEFT", prev, "RIGHT", gap, 0) else ic:SetPoint("LEFT", f.cdHolder, "LEFT", 0, 0) end
			end
			prev = ic
			ic:Show()
		else
			ic:Hide()
		end
	end
	f.cdHolder:SetWidth(mmax(1, n * (size + gap) - gap))
end
CD.Layout = Layout

local function OnExpire(self)
	local f, cfg = self.owner, self.owner.cfg
	ns:IconGlow(self, false)
	if cfg.cdShowReady then
		self:SetAlpha(cfg.cdReadyAlpha)
	else
		self.used = nil
		self:Hide()
	end
	Layout(f)
	ns:Fire("ENEMY_CD_READY", f, self.entry)
end

local function GetIcon(f, entry)
	local ic = f.cds[entry.key]
	if not ic then
		ic = ns:CreateIcon(f)
		ic.owner, ic.entry = f, entry
		ic.OnExpire = OnExpire
		ic.icon:SetTexture(entry.icon or ns.QMARK)
		ns:SetIconSize(ic, f.cdIconSize)
		ic:Hide()
		f.cds[entry.key] = ic
	end
	return ic
end

local function Enabled(cfg, entry)
	return cfg.cooldowns and cfg[CatKey(entry.cat)]
end

function CD:Start(f, entry, now, duration)
	local cfg = f.cfg
	if not Enabled(cfg, entry) then return end
	now = now or GetTime()
	local ic = GetIcon(f, entry)
	ic.used = true
	ic:SetAlpha(1)
	duration = duration or entry.cd
	if duration and duration > 0 then
		ns:StartIconCooldown(ic, now, duration)
	else
		-- no real cooldown: flash as "used"
		ns:StartIconCooldown(ic, now, cfg.cdUsageFlash or 5, true)
	end
	if cfg.cdGlow and entry.active and entry.active > 0 then
		ns:IconGlow(ic, true)
		ic.activeUntil = now + entry.active
		ns:After(entry.active, function()
			if ic.activeUntil and GetTime() >= ic.activeUntil - 0.05 then ns:IconGlow(ic, false); ic.activeUntil = nil end
		end)
	end
	Layout(f)
	ns:Fire("ENEMY_CD_USED", f, entry)
end

function CD:Reset(f, entry)
	local ic = f.cds[entry.key]
	if not ic or not ic.used then return end
	ns:StartIconCooldown(ic)
	ns:IconGlow(ic, false)
	OnExpire(ic)
end

function CD:Clear(f)
	for _, ic in pairs(f.cds) do
		ic.used, ic.activeUntil = nil, nil
		ns:StartIconCooldown(ic)
		ns:IconGlow(ic, false)
		ic:Hide()
	end
	Layout(f)
end

-- which entries match a spell name for this enemy
local function Match(f, spellName)
	local list = ns.CooldownIndex[spellName]
	if not list then return end
	local hit
	for _, e in ipairs(list) do
		if not f.class or e.class == f.class or e.class == "ANY" then
			hit = e
			break
		end
	end
	return hit
end

-- remaining cooldown of an interrupt (seconds) or 0 when ready, nil when unknown
function CD:InterruptLeft(f)
	local best
	for _, ic in pairs(f.cds) do
		if ic.used and ic.entry.cat == "interrupt" then
			local left = ic.expires and (ic.expires - GetTime()) or 0
			if left < 0 then left = 0 end
			if not best or left < best then best = left end
		end
	end
	return best
end

---------------------------------------------------------------------------
-- frame element
---------------------------------------------------------------------------
ns.Frames:RegisterElement("cooldowns", {
	order = 30,
	create = function(f)
		f.cds = {}
		f.cdIconSize = 26
		f.cdHolder = CreateFrame("Frame", nil, f)
		ns:Size(f.cdHolder, 1, 26)
	end,
	layout = function(f, cfg, chain)
		f.cdIconSize = mmax(12, floor(cfg.height * cfg.cdSize / 100))
		f.cdHolder:SetHeight(f.cdIconSize)
		for _, ic in pairs(f.cds) do ns:SetIconSize(ic, f.cdIconSize) end
		local pos = chain:Side(cfg.cdPos)
		if cfg.cooldowns then
			chain:Place(f.cdHolder, pos, (pos == "left" or pos == "right") and 8 or 4)
		else
			f.cdHolder:ClearAllPoints()
			f.cdHolder:SetPoint("LEFT", f, "RIGHT", 2000, 0)
		end
		Layout(f)
	end,
	reset = function(f) CD:Clear(f) end,
	test = function(f, i)
		if not f.cfg.cooldowns then return end
		local now = GetTime()
		local function use(id, ago)
			local e = ns.CooldownByKey[f.class .. ":" .. id]
			if e then
				local ic
				CD:Start(f, e, now - (ago or 0))
			end
		end
		if i == 1 then
			use(6552, 4); use(871, 2); use(100, 10); use(1719, 200)
		elseif i == 2 then
			use(15487, 20); use(33206, 1); use(10890, 12); use(34433, 100)
		else
			use(2139, 23); use(45438, 0); use(1953, 5); use(44572, 10)
		end
	end,
})

---------------------------------------------------------------------------
-- combat log
---------------------------------------------------------------------------
ns:RegisterMessage("ENEMY_CLEU", function(_, sub, sf, df, spellId, spellName)
	if not sf or not spellName then return end
	if sub ~= "SPELL_CAST_SUCCESS" and sub ~= "SPELL_SUMMON" then return end
	local resets = ns.CooldownResetByName[spellName]
	if resets then
		for _, ic in pairs(sf.cds) do
			if ic.used and ic.entry.name and resets[ic.entry.name] then CD:Reset(sf, ic.entry) end
		end
	end
	local e = Match(sf, spellName)
	if e then CD:Start(sf, e, GetTime()) end
end)

function CD:OnSettingChanged(key, value)
	if key == "cooldowns" and not value then
		ns.Frames:Each(function(f) CD:Clear(f) end)
	elseif key:sub(1, 2) == "cd" and value == false then
		ns.Frames:Each(function(f)
			for _, ic in pairs(f.cds) do
				if ic.used and CatKey(ic.entry.cat) == key then ic.used = nil; ns:StartIconCooldown(ic); ic:Hide() end
			end
			Layout(f)
		end)
	end
end
