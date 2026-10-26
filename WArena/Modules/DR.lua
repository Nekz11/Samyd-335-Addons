-- WArena: diminishing returns per enemy and category (combat log based, any source counts)
local _, ns = ...
local DR = ns:NewModule("DR")
ns.DR = DR

local floor, mmax, mmin = math.floor, math.max, math.min
local GetTime = GetTime

ns:AddDefaults({
	dr = true, drSize = 75, drPos = "right", drReset = 18, drText = false, drGrowLeft = false,
	drStun = true, drFear = true, drDisorient = true, drScatter = true, drHorror = true,
	drSilence = true, drRoot = true, drCyclone = true, drCharm = true, drDisarm = false,
	drColor1 = { r = 1, g = 1, b = 0, a = 1 }, drColor2 = { r = 1, g = 0.5, b = 0, a = 1 }, drColor3 = { r = 1, g = 0, b = 0, a = 1 },
})

local DR_TEXT = { "½", "¼", "0" }

local function Key(cat) return "dr" .. cat:sub(1, 1):upper() .. cat:sub(2) end
DR.Key = Key

local function LayoutDR(f)
	local cfg = f.cfg
	local prev, n = nil, 0
	local leftward = cfg.drPos == "left" or cfg.drGrowLeft
	for _, cat in ipairs(ns.DROrder) do
		local d = f.dr[cat]
		if d and d:IsShown() then
			n = n + 1
			d:ClearAllPoints()
			if leftward then
				if prev then d:SetPoint("RIGHT", prev, "LEFT", -3, 0) else d:SetPoint("RIGHT", f.drHolder, "RIGHT", 0, 0) end
			else
				if prev then d:SetPoint("LEFT", prev, "RIGHT", 3, 0) else d:SetPoint("LEFT", f.drHolder, "LEFT", 0, 0) end
			end
			prev = d
		end
	end
	f.drHolder:SetWidth(mmax(1, n * (f.drIconSize + 3) - 3))
end

local function OnExpire(self)
	self.count, self.resetAt = 0, nil
	self:Hide()
	LayoutDR(self.owner)
end

local function GetIcon(f, cat)
	local d = f.dr[cat]
	if not d then
		d = ns:CreateIcon(f)
		d.owner, d.cat = f, cat
		d.OnExpire = OnExpire
		ns:SetIconSize(d, f.drIconSize)
		d:Hide()
		f.dr[cat] = d
	end
	return d
end

function DR:Applied(f, cat, icon)
	local cfg = f.cfg
	if not cfg.dr or not cfg[Key(cat)] then return end
	local d = GetIcon(f, cat)
	local now = GetTime()
	if not d.resetAt or now >= d.resetAt then d.count = 0 end
	d.count = (d.count or 0) + 1
	d.resetAt = math.huge
	d.icon:SetTexture(icon or ns.QMARK)
	local lvl = mmin(d.count, 3)
	local r, g, b = ns:Color("drColor" .. lvl)
	d.border:SetTexture(r, g, b, 1)
	d.corner:SetText(cfg.drText and DR_TEXT[lvl] or "")
	d.corner:SetTextColor(r, g, b)
	-- safety net in case the aura removal never shows up in the combat log
	ns:StartIconCooldown(d, now, 10 + cfg.drReset, true)
	d:Show()
	LayoutDR(f)
	ns:Fire("ENEMY_DR", f, cat, lvl)
end

function DR:Removed(f, cat)
	local d = f.dr[cat]
	if not d or not d:IsShown() then return end
	local now = GetTime()
	d.resetAt = now + f.cfg.drReset
	ns:StartIconCooldown(d, now, f.cfg.drReset)
end

function DR:Clear(f)
	for _, d in pairs(f.dr) do
		d.count, d.resetAt = 0, nil
		ns:StartIconCooldown(d)
		d:Hide()
	end
	LayoutDR(f)
end

function DR:Level(f, cat)
	local d = f.dr[cat]
	if d and d:IsShown() then return mmin(d.count or 0, 3) end
	return 0
end

---------------------------------------------------------------------------
-- frame element
---------------------------------------------------------------------------
ns.Frames:RegisterElement("dr", {
	order = 20,
	create = function(f)
		f.dr = {}
		f.drIconSize = 30
		f.drHolder = CreateFrame("Frame", nil, f)
		ns:Size(f.drHolder, 1, 30)
	end,
	layout = function(f, cfg, chain)
		f.drIconSize = mmax(12, floor(cfg.height * cfg.drSize / 100))
		f.drHolder:SetHeight(f.drIconSize)
		for _, d in pairs(f.dr) do ns:SetIconSize(d, f.drIconSize) end
		local pos = chain:Side(cfg.drPos)
		if cfg.dr then
			chain:Place(f.drHolder, pos, (pos == "left" or pos == "right") and 8 or 4)
		else
			f.drHolder:ClearAllPoints()
			f.drHolder:SetPoint("LEFT", f, "RIGHT", 2000, 0) -- parked off-screen
		end
		LayoutDR(f)
	end,
	reset = function(f) DR:Clear(f) end,
	test = function(f, i)
		if not f.cfg.dr then return end
		local _, _, stunIcon = GetSpellInfo(853)
		local _, _, fearIcon = GetSpellInfo(5782)
		local _, _, rootIcon = GetSpellInfo(122)
		if i == 1 then
			DR:Applied(f, "stun", stunIcon); DR:Removed(f, "stun")
			DR:Applied(f, "root", rootIcon); DR:Applied(f, "root", rootIcon); DR:Applied(f, "root", rootIcon); DR:Removed(f, "root")
		elseif i == 3 then
			DR:Applied(f, "fear", fearIcon); DR:Applied(f, "fear", fearIcon); DR:Removed(f, "fear")
		end
	end,
})

---------------------------------------------------------------------------
-- combat log
---------------------------------------------------------------------------
ns:RegisterMessage("ENEMY_CLEU", function(_, sub, sf, df, spellId, spellName, auraType)
	if not df or not spellName then return end
	local cat = ns.Lookup.dr[spellName]
	if not cat then return end
	if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" then
		if auraType == "DEBUFF" then
			local _, _, icon = GetSpellInfo(spellId)
			DR:Applied(df, cat, icon)
		end
	elseif sub == "SPELL_AURA_REMOVED" then
		if auraType == "DEBUFF" then DR:Removed(df, cat) end
	end
end)

function DR:OnSettingChanged(key, value)
	if key == "dr" and not value then
		ns.Frames:Each(function(f) DR:Clear(f) end)
	elseif key:sub(1, 2) == "dr" and value == false then
		local cat = key:sub(3):lower()
		ns.Frames:Each(function(f)
			local d = f.dr[cat]
			if d then d.count, d.resetAt = 0, nil; ns:StartIconCooldown(d); d:Hide(); LayoutDR(f) end
		end)
	end
end
