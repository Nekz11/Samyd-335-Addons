-- WArena: aura row – all tracked auras of an enemy as small icons with timers (not only the top one)
local _, ns = ...
local AR = ns:NewModule("AuraRow")
ns.AuraRow = AR

local floor, mmax, mmin, tsort = math.floor, math.max, math.min, table.sort
local GetTime, UnitExists = GetTime, UnitExists

ns:AddDefaults({
	auraRow = false, auraRowSize = 60, auraRowPos = "above", auraRowMax = 6, auraRowSpacing = 2, auraRowTimer = true,
	auraRowImmune = true, auraRowCC = true, auraRowSilence = true, auraRowDefensive = true, auraRowRoot = true, auraRowOffensive = true,
})

local function Layout(f)
	local cfg = f.cfg
	local list = {}
	for _, ic in pairs(f.auraIcons) do if ic.used then list[#list + 1] = ic end end
	tsort(list, function(a, b)
		if a.prio ~= b.prio then return a.prio > b.prio end
		return (a.expires or 0) < (b.expires or 0)
	end)
	local size, gap = f.auraIconSize, cfg.auraRowSpacing
	local prev, n = nil, 0
	for _, ic in ipairs(list) do
		if n < cfg.auraRowMax then
			n = n + 1
			ic:ClearAllPoints()
			if prev then ic:SetPoint("LEFT", prev, "RIGHT", gap, 0) else ic:SetPoint("LEFT", f.auraHolder, "LEFT", 0, 0) end
			prev = ic
			ic:Show()
		else
			ic:Hide()
		end
	end
	f.auraHolder:SetWidth(mmax(1, n * (size + gap) - gap))
end

local function OnExpire(self)
	self.used = nil
	self:Hide()
	Layout(self.owner)
end

local function GetIcon(f, name)
	local ic = f.auraIcons[name]
	if not ic then
		ic = ns:CreateIcon(f)
		ic.owner = f
		ic.OnExpire = OnExpire
		ns:SetIconSize(ic, f.auraIconSize)
		ic:Hide()
		f.auraIcons[name] = ic
	end
	return ic
end

function AR:Clear(f)
	for _, ic in pairs(f.auraIcons) do
		ic.used = nil
		ns:StartIconCooldown(ic)
		ic:Hide()
	end
	Layout(f)
end

function AR:Update(f)
	local cfg = f.cfg
	if not cfg.auraRow then return end
	local unit = f.unit
	if not UnitExists(unit) and not ns.state.testMode then return end
	for _, ic in pairs(f.auraIcons) do ic.seen = nil end
	local now = GetTime()
	for _, filter in ipairs({ "HARMFUL", "HELPFUL" }) do
		local i = 1
		while true do
			local name, _, icon, count, _, duration, expires = UnitAura(unit, i, filter)
			if not name then break end
			local c = ns.Lookup.aura[name]
			if c and cfg["auraRow" .. c.key] then
				local ic = GetIcon(f, name)
				ic.seen, ic.used, ic.prio = true, true, c.prio
				ic.icon:SetTexture(icon)
				ic.corner:SetText((count or 0) > 1 and count or "")
				if cfg.auraRowTimer and duration and duration > 0 and expires then
					if ic.expires ~= expires then ns:StartIconCooldown(ic, expires - duration, duration) end
				else
					ns:StartIconCooldown(ic)
					ic.expires = nil
				end
			end
			i = i + 1
		end
	end
	for _, ic in pairs(f.auraIcons) do
		if ic.used and not ic.seen then
			ic.used = nil
			ns:StartIconCooldown(ic)
			ic:Hide()
		end
	end
	Layout(f)
end

ns.Frames:RegisterElement("aurarow", {
	order = 35,
	create = function(f)
		f.auraIcons = {}
		f.auraIconSize = 24
		f.auraHolder = CreateFrame("Frame", nil, f)
		ns:Size(f.auraHolder, 1, 24)
	end,
	layout = function(f, cfg, chain)
		f.auraIconSize = mmax(10, floor(cfg.height * cfg.auraRowSize / 100))
		f.auraHolder:SetHeight(f.auraIconSize)
		for _, ic in pairs(f.auraIcons) do ns:SetIconSize(ic, f.auraIconSize) end
		if cfg.auraRow then
			local pos = chain:Side(cfg.auraRowPos)
			chain:Place(f.auraHolder, pos, (pos == "left" or pos == "right") and 8 or 4)
		else
			f.auraHolder:ClearAllPoints()
			f.auraHolder:SetPoint("LEFT", f, "RIGHT", 2000, 0)
		end
		Layout(f)
	end,
	reset = function(f) AR:Clear(f) end,
	update = function(f) AR:Update(f) end,
	test = function(f, i)
		if not f.cfg.auraRow then return end
		local now = GetTime()
		local function add(id, dur, prio)
			local name, _, icon = GetSpellInfo(id)
			if not name then return end
			local ic = GetIcon(f, name)
			ic.used, ic.prio = true, prio
			ic.icon:SetTexture(icon)
			ic.corner:SetText("")
			ns:StartIconCooldown(ic, now, dur)
		end
		if i == 1 then add(871, 12, 75); add(1719, 12, 30)
		elseif i == 2 then add(33206, 8, 75); add(17, 30, 75)
		else add(118, 8, 90); add(12472, 20, 30) end
		Layout(f)
	end,
})

ns:RegisterMessage("ENEMY_AURAS", function(_, f) AR:Update(f) end)

function AR:OnSettingChanged(key, value)
	if key == "auraRow" and not value then ns.Frames:Each(function(f) AR:Clear(f) end) end
end
