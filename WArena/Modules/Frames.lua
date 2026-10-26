-- WArena: unit frame engine – arena1-5 (+ pets), layout chains, cast bar, test mode.
-- Other modules add elements through Frames:RegisterElement (DR, cooldowns, indicators).
local _, ns = ...
local L = ns.L
local Frames = ns:NewModule("Frames")
ns.Frames = Frames

local floor, mmax, mmin, format = math.floor, math.max, math.min, string.format
local GetTime, UnitExists, UnitGUID, InCombatLockdown = GetTime, UnitExists, UnitGUID, InCombatLockdown
local MAX = ns.MAX_ARENA

ns:AddDefaults({
	-- size & position
	scale = 1.0, width = 180, height = 40, spacing = 24, growUp = false, horizontal = false, mirror = false,
	bgAlpha = 0.6, unseenAlpha = 0.65,
	blizzard = false,
	-- sorting / roles
	healer = "last", healerIcon = true,
	-- bars & text
	texture = "Blizzard", font = "Friz Quadrata", fontSize = 11, fontOutline = "OUTLINE", fontShadow = false,
	classcolor = true, healthGradient = false, healthColor = { r = 0.1, g = 0.8, b = 0.1, a = 1 },
	healthBg = { r = 0, g = 0, b = 0, a = 0.55 }, powerBg = { r = 0, g = 0, b = 0, a = 0.55 },
	textColor = { r = 1, g = 1, b = 1, a = 1 },
	powerBar = true, powerHeight = 8,
	healthText = "percent", nameMode = "name", nameLimit = 12, spec = true, specMode = "text", arenaId = true,
	iconStyle = "blizzard",
	-- borders
	borderStyle = "thin", borderColor = { r = 0, g = 0, b = 0, a = 1 },
	targetBorder = true, targetColor = { r = 1, g = 0.85, b = 0, a = 1 },
	focusBorder = true, focusColor = { r = 0.3, g = 0.6, b = 1, a = 1 },
	-- trinket / racial
	trinket = true, racial = true, iconSize = 100, iconSide = "right", cdText = true, trinketReadyGlow = true,
	-- auras on the class icon
	aura = true, auraTimer = true,
	auraImmune = true, auraCC = true, auraSilence = true, auraDefensive = true, auraRoot = true, auraOffensive = true,
	-- cast bar
	castbar = true, castPos = "left", castWidth = 75, castHeight = 16, castIcon = true, castName = true, castTime = true,
	castHold = 1.5, castColor = { r = 1, g = 0.75, b = 0, a = 1 }, castChannelColor = { r = 0.3, g = 0.7, b = 1, a = 1 },
	castShieldColor = { r = 0.6, g = 0.6, b = 0.6, a = 1 }, castInterruptColor = { r = 1, g = 0.1, b = 0.1, a = 1 },
	-- pets
	pets = true, petHeight = 12,
	-- clicks
	middleClick = "none", tooltips = false,
})

---------------------------------------------------------------------------
-- state
---------------------------------------------------------------------------
local frames, unitToFrame, guidToFrame, nameToFrame = {}, {}, {}, {}
local elements, elementOrder = {}, {}
local anchor = CreateFrame("Frame", "WArenaAnchor", UIParent)
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()
local arenaCount = 0
local pendingShow

Frames.frames = frames
Frames.anchor = anchor

function Frames:Get(i) return frames[i] end
function Frames:ByUnit(unit) return unitToFrame[unit] end
function Frames:ByGUID(guid) return guid and guidToFrame[guid] end
function Frames:ByName(name) return name and nameToFrame[name] end
function Frames:Count() return ns.state.testMode and 3 or arenaCount end
function Frames:Each(fn) for i = 1, MAX do fn(frames[i], i) end end
function Frames:EachVisible(fn) for i = 1, self:Count() do fn(frames[i], i) end end

---------------------------------------------------------------------------
-- element registry
-- element = { order = n, create = fn(f), layout = fn(f, cfg, chain), reset = fn(f), test = fn(f, i), update = fn(f) }
---------------------------------------------------------------------------
function Frames:RegisterElement(name, el)
	el.name = name
	elements[name] = el
	elementOrder[#elementOrder + 1] = el
	table.sort(elementOrder, function(a, b) return (a.order or 50) < (b.order or 50) end)
	-- frames may already exist (element registered late)
	for i = 1, MAX do
		if frames[i] and el.create and not frames[i].elements[name] then
			frames[i].elements[name] = true
			el.create(frames[i])
		end
	end
end

---------------------------------------------------------------------------
-- cast bar
---------------------------------------------------------------------------
local function Cast_OnUpdate(self, elapsed)
	local db = ns.db
	local now = GetTime()
	if self.casting then
		local v = now - self.startTime
		if v >= self.duration then
			if self.fakeLoop then
				self.startTime, v = now, 0
			else
				self.casting = nil
				self:Hide()
				return
			end
		end
		self:SetValue(v)
		self.time:SetText(db.castTime and format("%.1f", self.duration - v) or "")
	elseif self.channeling then
		local v = self.endTime - now
		if v <= 0 then
			self.channeling = nil
			self:Hide()
			return
		end
		self:SetValue(v)
		self.time:SetText(db.castTime and format("%.1f", v) or "")
	elseif self.holdTime then
		self.holdTime = self.holdTime - elapsed
		if self.holdTime <= 0 then
			self.holdTime, self.interruptedBy = nil, nil
			self:Hide()
		end
	else
		self:Hide()
	end
end

local function CastColor(c, key)
	local r, g, b, a = ns:Color(key)
	c:SetStatusBarColor(r, g, b, a)
end

function Frames:UpdateCast(f)
	local c, unit, cfg = f.cast, f.unit, f.cfg
	if not cfg.castbar then c:Hide() return end
	local name, _, text, icon, startMS, endMS, _, _, notInt = UnitCastingInfo(unit)
	local channel
	if not name then
		name, _, text, icon, startMS, endMS, _, notInt = UnitChannelInfo(unit)
		channel = name and true or nil
	end
	if not name then
		if not c.holdTime then
			c.casting, c.channeling = nil, nil
			c:Hide()
		end
		return
	end
	c.holdTime, c.interruptedBy, c.fakeLoop = nil, nil, nil
	c.startTime, c.endTime = startMS / 1000, endMS / 1000
	c.duration = mmax(0.01, c.endTime - c.startTime)
	c:SetMinMaxValues(0, c.duration)
	c.casting, c.channeling = not channel, channel
	c.icon:SetTexture(icon)
	c.text:SetText(cfg.castName and (text or name) or "")
	c.spellName = name
	if notInt then CastColor(c, "castShieldColor") elseif channel then CastColor(c, "castChannelColor") else CastColor(c, "castColor") end
	c:Show()
	ns:Fire("ENEMY_CAST", f, name, notInt, channel)
end

function Frames:CastInterrupted(f, byName)
	local c, cfg = f.cast, f.cfg
	if not cfg.castbar or (cfg.castHold or 0) <= 0 then c:Hide() return end
	if c.interruptedBy and not byName then return end -- keep the name from the combat log
	c.casting, c.channeling, c.fakeLoop = nil, nil, nil
	c:SetMinMaxValues(0, 1)
	c:SetValue(1)
	CastColor(c, "castInterruptColor")
	c.interruptedBy = byName
	c.text:SetText(byName and format(L["Interrupted: %s"], ns:ShortName(byName)) or L["Interrupted"])
	c.time:SetText("")
	c.holdTime = cfg.castHold
	c:Show()
end

function Frames:FakeCast(f, name, icon, duration)
	local c = f.cast
	c.holdTime, c.interruptedBy, c.channeling = nil, nil, nil
	c.casting, c.fakeLoop = true, true
	c.startTime, c.duration = GetTime(), duration
	c:SetMinMaxValues(0, duration)
	c.icon:SetTexture(icon)
	c.text:SetText(f.cfg.castName and name or "")
	CastColor(c, "castColor")
	c:Show()
end

---------------------------------------------------------------------------
-- frame contents
---------------------------------------------------------------------------
local function SetClassIcon(f)
	ns:SetClassIcon(f.classIcon, f.class, f.cfg.iconStyle)
end

function Frames:ColorHealth(f)
	local cfg = f.cfg
	local r, g, b
	if cfg.classcolor and f.class then
		r, g, b = ns:ClassColor(f.class)
	elseif cfg.healthGradient and f.hpPct then
		r, g, b = ns:HealthGradient(f.hpPct)
	elseif f.class then
		r, g, b = ns:Color("healthColor")
	else
		r, g, b = 0.4, 0.4, 0.4
	end
	f.hp:SetStatusBarColor(r, g, b)
	local tr, tg, tb = ns:Color("textColor")
	if f.class and not cfg.classcolor then
		f.nameText:SetTextColor(ns:ClassColor(f.class))
	else
		f.nameText:SetTextColor(tr, tg, tb)
	end
	f.hpText:SetTextColor(tr, tg, tb)
end

function Frames:SetSpec(f, spec, source)
	if f.spec == spec then return end
	f.spec = spec
	self:UpdateSpecText(f)
	if spec then
		f.role = ns.SpecRole[spec]
		ns:Fire("ENEMY_SPEC", f, spec, source)
		self:RequestSort()
	end
end

function Frames:UpdateSpecText(f)
	local cfg = f.cfg
	local txt = ""
	if cfg.spec and f.spec then
		txt = f.spec
		if cfg.specMode == "short" then txt = txt:sub(1, 4) end
	end
	f.specText:SetText(txt)
end

function Frames:TrySpec(f, name)
	if f.spec or not name then return end
	local sp = ns:LookupSpec(f.class, name)
	if sp then self:SetSpec(f, sp, name) end
end

local function SetTrinketIcon(f, faction)
	if faction == "Horde" then
		f.trinket.icon:SetTexture(ns.TRINKET_H)
	elseif faction == "Alliance" then
		f.trinket.icon:SetTexture(ns.TRINKET_A)
	else
		f.trinket.icon:SetTexture(UnitFactionGroup("player") == "Horde" and ns.TRINKET_A or ns.TRINKET_H)
	end
end

function Frames:UpdateName(f)
	local cfg, mode = f.cfg, f.cfg.nameMode
	local txt
	if mode == "number" then
		txt = format(f.kind == "boss" and L["Boss %d"] or L["Arena %d"], f.id)
	elseif mode == "class" then
		txt = f.className or f.name or format(L["Arena %d"], f.id)
	elseif mode == "spec" then
		txt = f.spec or f.className or f.name or format(L["Arena %d"], f.id)
	else
		txt = f.name or format(L["Arena %d"], f.id)
	end
	local limit = cfg.nameLimit or 0
	if limit > 0 and #txt > limit then txt = txt:sub(1, limit) end
	f.nameText:SetText(txt)
end

local function HealthString(cfg, hp, maxhp)
	local mode = cfg.healthText
	if mode == "none" then return "" end
	local pct = floor(hp / maxhp * 100 + 0.5) .. "%"
	if mode == "current" then return ns:Short(hp) end
	if mode == "both" then return ns:Short(hp) .. " | " .. pct end
	if mode == "deficit" then local d = maxhp - hp; return d > 0 and ("-" .. ns:Short(d)) or "" end
	return pct
end

function Frames:UpdateIdentity(f)
	local unit = f.unit
	if not UnitExists(unit) then return end
	local guid = UnitGUID(unit)
	if f.guid and guid and f.guid ~= guid then
		-- a different unit took this slot: forget everything about the old one
		self:ResetFrame(f)
	end
	if f.name and nameToFrame[f.name] == f then nameToFrame[f.name] = nil end
	f.guid = guid
	if guid then guidToFrame[guid] = f end
	f.name = UnitName(unit)
	if f.name then nameToFrame[f.name] = f end
	local className, class = UnitClass(unit)
	if class then f.class, f.className = class, className end
	self:UpdateName(f)
	local _, race = UnitRace(unit)
	if race and ns.Racials[race] and ns.Racials[race].icon then
		f.race = race
		if not f.racial.expires then f.racial.icon:SetTexture(ns.Racials[race].icon) end
	end
	SetTrinketIcon(f, UnitFactionGroup(unit))
	if not f.auraActive then SetClassIcon(f) end
	self:ColorHealth(f)
	self:RequestSort()
	ns:Fire("ENEMY_IDENTITY", f)
end

function Frames:UpdateHealth(f)
	local unit = f.unit
	if not UnitExists(unit) then return end
	local hp, maxhp = UnitHealth(unit), UnitHealthMax(unit)
	if not maxhp or maxhp <= 0 then maxhp = 1 end
	f.hp:SetMinMaxValues(0, maxhp)
	local feign = UnitIsFeignDeath and UnitIsFeignDeath(unit)
	local dead = UnitIsDeadOrGhost(unit) and not feign
	f.dead = dead or nil
	if dead then
		f.hp:SetValue(0)
		f.hpPct = 0
		f.hpText:SetText(f.cfg.healthText ~= "none" and L["Dead"] or "")
		f.cast:Hide()
	else
		f.hp:SetValue(hp)
		f.hpPct = hp / maxhp
		f.hpText:SetText(HealthString(f.cfg, hp, maxhp))
	end
	if f.cfg.healthGradient and not f.cfg.classcolor then self:ColorHealth(f) end
	ns:Fire("ENEMY_HEALTH", f, f.hpPct, dead)
end

function Frames:UpdatePower(f)
	local unit = f.unit
	if not UnitExists(unit) then return end
	local ptype, ptoken = UnitPowerType(unit)
	f.power:SetStatusBarColor(ns:PowerColor(ptype, ptoken))
	local maxp = UnitPowerMax(unit)
	if not maxp or maxp <= 0 then maxp = 1 end
	f.power:SetMinMaxValues(0, maxp)
	f.power:SetValue(UnitPower(unit))
end

local AURA_FILTERS = { "HARMFUL", "HELPFUL" }

function Frames:ShowAura(f, icon, duration, expires, name)
	f.auraActive = name or true
	f.classIcon:SetTexture(icon)
	f.classIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	if f.cfg.auraTimer and duration and duration > 0 and expires then
		f.auraCD:SetCooldown(expires - duration, duration)
		f.auraCD:Show()
	else
		f.auraCD:Hide()
	end
end

function Frames:ClearAura(f)
	if f.auraActive then
		f.auraActive = nil
		f.auraCD:Hide()
		SetClassIcon(f)
	end
end

function Frames:UpdateAuras(f)
	local unit, cfg = f.unit, f.cfg
	if not UnitExists(unit) then return end
	local bestPrio, bestIcon, bestDur, bestExp, bestName = 0
	local drinking, drinkDur, drinkExp
	for _, filter in ipairs(AURA_FILTERS) do
		local i = 1
		while true do
			local name, _, icon, count, _, duration, expires, caster = UnitAura(unit, i, filter)
			if not name then break end
			local c = ns.Lookup.aura[name]
			if c and cfg.aura and cfg["aura" .. c.key] and c.prio > bestPrio then
				bestPrio, bestIcon, bestDur, bestExp, bestName = c.prio, icon, duration, expires, name
			end
			if ns.Lookup.drink[name] then drinking, drinkDur, drinkExp = true, duration, expires end
			-- talent buffs/auras reveal the caster's spec (also when cast on a teammate)
			local cf = caster and unitToFrame[caster]
			if cf then self:TrySpec(cf, name) end
			i = i + 1
		end
	end
	if bestIcon then
		self:ShowAura(f, bestIcon, bestDur, bestExp, bestName)
	else
		self:ClearAura(f)
	end
	if drinking ~= f.drinking then
		f.drinking = drinking
		ns:Fire("ENEMY_DRINK", f, drinking, drinkDur, drinkExp)
	end
	ns:Fire("ENEMY_AURAS", f)
end

function Frames:UpdateBorders()
	for i = 1, MAX do
		local f = frames[i]
		local shown = false
		if f:IsShown() and (UnitExists(f.unit) or ns.state.testMode and f.testTarget) then
			local cfg = f.cfg
			if cfg.targetBorder and (f.testTarget or UnitIsUnit("target", f.unit)) then
				f.border:SetBackdropBorderColor(ns:Color("targetColor"))
				shown = true
			elseif cfg.focusBorder and UnitIsUnit("focus", f.unit) then
				f.border:SetBackdropBorderColor(ns:Color("focusColor"))
				shown = true
			end
		end
		ns:Show(f.border, shown)
	end
	ns:Fire("TARGET_CHANGED")
end

function Frames:UpdatePet(f)
	local p = f.pet
	if not f.cfg.pets then p:Hide() return end
	local unit = p.unit
	if not UnitExists(unit) then p:Hide() return end
	local hp, maxhp = UnitHealth(unit), UnitHealthMax(unit)
	if not maxhp or maxhp <= 0 then maxhp = 1 end
	p.hp:SetMinMaxValues(0, maxhp)
	p.hp:SetValue(hp)
	p.name:SetText(UnitName(unit) or "")
	if UnitIsDeadOrGhost(unit) then p.hp:SetValue(0) end
	p:Show()
end

function Frames:UpdateAll(f)
	self:UpdateIdentity(f)
	self:UpdateHealth(f)
	self:UpdatePower(f)
	self:UpdateAuras(f)
	self:UpdateCast(f)
	self:UpdatePet(f)
	for _, el in ipairs(elementOrder) do
		if el.update then el.update(f) end
	end
end

function Frames:ResetFrame(f)
	if f.guid then guidToFrame[f.guid] = nil end
	if f.name and nameToFrame[f.name] == f then nameToFrame[f.name] = nil end
	f.guid, f.class, f.className, f.name, f.race, f.spec, f.role = nil, nil, nil, nil, nil, nil, nil
	f.auraActive, f.isHealer, f.drinking, f.dead, f.hpPct, f.testTarget, f.unseen = nil, nil, nil, nil, nil, nil, nil
	self:UpdateName(f)
	f.hpText:SetText("")
	f.hp:SetMinMaxValues(0, 1)
	f.hp:SetValue(1)
	f.power:SetMinMaxValues(0, 1)
	f.power:SetValue(0)
	f.spec = nil
	self:UpdateSpecText(f)
	SetClassIcon(f)
	self:ColorHealth(f)
	f.auraCD:Hide()
	f.roleIcon:Hide()
	SetTrinketIcon(f, nil)
	ns:StartIconCooldown(f.trinket)
	ns:IconGlow(f.trinket, false)
	f.racial.icon:SetTexture(ns.QMARK)
	ns:StartIconCooldown(f.racial)
	local c = f.cast
	c.casting, c.channeling, c.holdTime, c.interruptedBy, c.fakeLoop, c.spellName = nil, nil, nil, nil, nil, nil
	c:Hide()
	f.pet:Hide()
	f.border:Hide()
	f:SetAlpha(1)
	for _, el in ipairs(elementOrder) do
		if el.reset then el.reset(f) end
	end
	ns:Fire("ENEMY_RESET", f)
end

---------------------------------------------------------------------------
-- creation
---------------------------------------------------------------------------
local function OnEnter(self)
	if not self.cfg.tooltips or not UnitExists(self.unit) then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetUnit(self.unit)
	GameTooltip:Show()
end
local function OnLeave() GameTooltip:Hide() end

function Frames:CreateUnitFrame(i, unit, globalName, kind, parent, cfg)
	local f = CreateFrame("Button", globalName, parent, "SecureUnitButtonTemplate")
	f.id, f.unit, f.kind, f.cfg, f.slot, f.elements = i, unit, kind, cfg, i, {}
	f:SetAttribute("unit", unit)
	f:SetAttribute("type1", "target")
	f:SetAttribute("type2", "focus")
	f:RegisterForClicks("AnyUp")
	f:SetScript("OnEnter", OnEnter)
	f:SetScript("OnLeave", OnLeave)
	f:Hide()

	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()
	f.bg:SetTexture(0, 0, 0, 0.6)

	f.frameBorder = CreateFrame("Frame", nil, f)
	f.frameBorder:SetFrameLevel(f:GetFrameLevel())
	f.border = CreateFrame("Frame", nil, f)
	f.border:SetFrameLevel(f:GetFrameLevel() + 6)
	f.border:Hide()

	f.iconHolder = CreateFrame("Frame", nil, f)
	f.classIcon = f.iconHolder:CreateTexture(nil, "ARTWORK")
	f.classIcon:SetAllPoints()
	f.auraCD = CreateFrame("Cooldown", nil, f.iconHolder, "CooldownFrameTemplate")
	f.auraCD:SetAllPoints(f.classIcon)
	f.auraCD:SetReverse(true)

	f.hp = ns:NewBar(f)
	f.power = ns:NewBar(f)
	f.textLayer = CreateFrame("Frame", nil, f)
	f.textLayer:SetAllPoints()
	f.textLayer:SetFrameLevel(f.hp:GetFrameLevel() + 3)
	f.nameText = ns:NewText(f.textLayer, "LEFT")
	f.hpText = ns:NewText(f.textLayer, "RIGHT")
	f.specText = ns:NewText(f.textLayer, "LEFT")
	f.idText = ns:NewText(f.textLayer, "RIGHT")
	f.idText:SetText(i)
	f.roleIcon = f.textLayer:CreateTexture(nil, "OVERLAY")
	f.roleIcon:SetTexture(ns.ROLE_TEX)
	f.roleIcon:SetTexCoord(ns.HEALER_COORDS[1], ns.HEALER_COORDS[2], ns.HEALER_COORDS[3], ns.HEALER_COORDS[4])
	f.roleIcon:Hide()

	f.trinket = ns:CreateIcon(f)
	f.racial = ns:CreateIcon(f)

	local c = ns:NewBar(f)
	c:Hide()
	c.icon = c:CreateTexture(nil, "ARTWORK")
	c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	c.text = ns:NewText(c, "LEFT")
	c.time = ns:NewText(c, "RIGHT")
	c:SetScript("OnUpdate", Cast_OnUpdate)
	f.cast = c

	-- pet line
	local p = CreateFrame("Frame", nil, f)
	p.unit = unit:gsub("^arena", "arenapet")
	p.hp = ns:NewBar(p)
	p.hp:SetAllPoints()
	p.hp:SetStatusBarColor(0.5, 0.5, 0.5)
	p.name = ns:NewText(p, "LEFT")
	p.name:SetPoint("LEFT", p, "LEFT", 2, 0)
	p.name:SetPoint("RIGHT", p, "RIGHT", -2, 0)
	p:Hide()
	f.pet = p

	for _, el in ipairs(elementOrder) do
		if el.create then
			f.elements[el.name] = true
			el.create(f)
		end
	end
	return f
end

---------------------------------------------------------------------------
-- layout engine
---------------------------------------------------------------------------
-- chain object passed to element layouts
local Chain = {}
Chain.__index = Chain

function Chain:Place(obj, pos, gap, extraOffset)
	obj:ClearAllPoints()
	extraOffset = extraOffset or 0
	if pos == "right" then
		obj:SetPoint("LEFT", self.right, "RIGHT", gap + extraOffset, 0); self.right = obj
	elseif pos == "left" then
		obj:SetPoint("RIGHT", self.left, "LEFT", -gap - extraOffset, 0); self.left = obj
	elseif pos == "below" then
		obj:SetPoint("TOPLEFT", self.below, "BOTTOMLEFT", extraOffset, -gap); self.below = obj
	else
		obj:SetPoint("BOTTOMLEFT", self.above, "TOPLEFT", extraOffset, gap); self.above = obj
	end
end

-- mirror swaps left/right
function Chain:Side(pos)
	if self.mirror then
		if pos == "left" then return "right" elseif pos == "right" then return "left" end
	end
	return pos
end

function Frames:LayoutFrame(f)
	local cfg = f.cfg
	local W, H = cfg.width, cfg.height
	ns:Size(f, W, H)
	local tex = ns:Media("statusbar", cfg.texture)
	f.hp:SetStatusBarTexture(tex)
	f.power:SetStatusBarTexture(tex)
	f.cast:SetStatusBarTexture(tex)
	f.pet.hp:SetStatusBarTexture(tex)
	f.bg:SetTexture(0, 0, 0, cfg.bgAlpha)
	f.hp.bg:SetTexture(ns:Color("healthBg"))
	f.power.bg:SetTexture(ns:Color("powerBg"))

	-- frame border
	if cfg.borderStyle == "none" then
		f.frameBorder:Hide()
	else
		local r, g, b, a = ns:Color("borderColor")
		ns:ApplyBorderStyle(f.frameBorder, cfg.borderStyle, r, g, b, a)
		f.frameBorder:Show()
	end
	ns:ApplyBorderStyle(f.border, cfg.borderStyle == "glow" and "glow" or "thick", 1, 1, 1, 1)

	local mirror = cfg.mirror
	if f.kind == "arena" then
		f:SetAttribute("type3", (cfg.middleClick ~= "none") and cfg.middleClick or nil)
	end
	-- class icon
	ns:Size(f.iconHolder, H, H)
	f.iconHolder:ClearAllPoints()
	if mirror then f.iconHolder:SetPoint("RIGHT", f, "RIGHT", 0, 0) else f.iconHolder:SetPoint("LEFT", f, "LEFT", 0, 0) end
	local roleSize = mmax(10, floor(H * 0.45))
	ns:Size(f.roleIcon, roleSize, roleSize)
	f.roleIcon:ClearAllPoints()
	f.roleIcon:SetPoint("TOPLEFT", f.iconHolder, "TOPLEFT", -3, 3)
	if not f.auraActive then SetClassIcon(f) end

	-- bars
	local pH = cfg.powerBar and mmin(cfg.powerHeight, H - 8) or 0
	f.hp:ClearAllPoints()
	if mirror then
		f.hp:SetPoint("TOPRIGHT", f.iconHolder, "TOPLEFT", -2, 0)
		f.hp:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	else
		f.hp:SetPoint("TOPLEFT", f.iconHolder, "TOPRIGHT", 2, 0)
		f.hp:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	end
	f.hp:SetHeight(pH > 0 and (H - pH - 1) or H)
	f.power:ClearAllPoints()
	if pH > 0 then
		f.power:SetPoint("TOPLEFT", f.hp, "BOTTOMLEFT", 0, -1)
		f.power:SetPoint("TOPRIGHT", f.hp, "BOTTOMRIGHT", 0, -1)
		f.power:SetHeight(pH)
		f.power:Show()
	else
		f.power:Hide()
	end

	-- texts
	local fs = cfg.fontSize
	ns:SetFont(f.nameText, fs)
	ns:SetFont(f.hpText, fs)
	ns:SetFont(f.specText, fs - 2)
	ns:SetFont(f.idText, fs - 2)
	f.nameText:ClearAllPoints()
	f.nameText:SetPoint("LEFT", f.hp, "LEFT", 3, 0)
	f.nameText:SetPoint("RIGHT", f.hpText, "LEFT", -2, 0)
	f.hpText:ClearAllPoints()
	f.hpText:SetPoint("RIGHT", f.hp, "RIGHT", -3, 0)
	f.specText:ClearAllPoints()
	if pH > 0 then
		f.specText:SetPoint("LEFT", f.power, "LEFT", 3, 0)
	else
		f.specText:SetPoint("BOTTOMLEFT", f.hp, "BOTTOMLEFT", 3, 1)
	end
	f.idText:ClearAllPoints()
	f.idText:SetPoint("BOTTOMRIGHT", f.iconHolder, "BOTTOMRIGHT", -1, 1)
	ns:Show(f.idText, cfg.arenaId)
	self:UpdateName(f)
	self:UpdateSpecText(f)
	self:ColorHealth(f)

	-- pet line directly below the frame (inside the spacing)
	local p = f.pet
	ns:Size(p, W - H - 2, cfg.petHeight)
	p:ClearAllPoints()
	if mirror then p:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -1) else p:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -1) end
	ns:SetFont(p.name, mmax(7, cfg.petHeight - 3))

	-- chains
	-- things placed below start under the pet line when pets are enabled (hidden frames still anchor)
	local chain = setmetatable({ right = f, left = f, below = cfg.pets and p or f, above = f, mirror = mirror }, Chain)
	f.chain = chain

	-- trinket / racial
	local iconSize = mmax(12, floor(H * cfg.iconSize / 100))
	ns:SetIconSize(f.trinket, iconSize)
	ns:SetIconSize(f.racial, iconSize)
	local side = chain:Side(cfg.iconSide == "left" and "left" or "right")
	if cfg.trinket then chain:Place(f.trinket, side, 4); f.trinket:Show() else f.trinket:ClearAllPoints(); f.trinket:Hide() end
	if cfg.racial then chain:Place(f.racial, side, 3); f.racial:Show() else f.racial:ClearAllPoints(); f.racial:Hide() end

	-- registered elements (DR, cooldowns, indicators ...)
	for _, el in ipairs(elementOrder) do
		if el.layout then el.layout(f, cfg, chain) end
	end

	-- cast bar (last, so it sits outside everything else)
	local c = f.cast
	local castH = cfg.castHeight
	local iconW = cfg.castIcon and (castH + 2) or 0
	if cfg.castIcon then ns:Size(c.icon, castH, castH); c.icon:Show() else c.icon:Hide() end
	local pos = chain:Side(cfg.castPos)
	c:ClearAllPoints()
	if pos == "right" or pos == "left" then
		ns:Size(c, mmax(40, floor(W * cfg.castWidth / 100)), castH)
		chain:Place(c, pos, 6, (pos == "right") and iconW or 0)
	else
		ns:Size(c, W - iconW, castH)
		if pos == "below" then
			c:SetPoint("TOPLEFT", chain.below, "BOTTOMLEFT", iconW, -4)
			chain.below = c
		else
			c:SetPoint("BOTTOMLEFT", chain.above, "TOPLEFT", iconW, 4)
			chain.above = c
		end
	end
	c.icon:ClearAllPoints()
	c.icon:SetPoint("RIGHT", c, "LEFT", -2, 0)
	ns:SetFont(c.text, mmax(7, castH - 5))
	ns:SetFont(c.time, mmax(7, castH - 5))
	c.text:ClearAllPoints()
	c.text:SetPoint("LEFT", c, "LEFT", 2, 0)
	c.text:SetPoint("RIGHT", c, "RIGHT", cfg.castTime and -28 or -2, 0)
	c.time:ClearAllPoints()
	c.time:SetPoint("RIGHT", c, "RIGHT", -2, 0)
	if not cfg.castbar then c:Hide() end
end

---------------------------------------------------------------------------
-- healer detection / sorting
---------------------------------------------------------------------------
local function DetectHealers(n)
	local healer, found = {}, false
	for i = 1, n do
		local f = frames[i]
		if f.spec and ns.HealerSpecs[f.spec] then healer[i], found = true, true end
	end
	if not found then
		-- spec unknown: exactly one healing-capable class on the team = healer
		local allKnown, count, cand = true, 0, nil
		for i = 1, n do
			local f = frames[i]
			if not f.class then
				allKnown = false
			elseif ns.HEALER_CLASSES[f.class] and not f.spec then
				count, cand = count + 1, i
			end
		end
		if allKnown and count == 1 then healer[cand] = true end
	end
	for i = 1, MAX do
		local f = frames[i]
		local was = f.isHealer
		f.isHealer = healer[i] or nil
		ns:Show(f.roleIcon, f.isHealer and ns.db.healerIcon)
		if f.isHealer and not was then ns:Fire("ENEMY_HEALER", f) end
	end
	return healer
end

-- returns arena IDs 1..n in display order
local function ComputeOrder(n)
	local order = {}
	local healer = DetectHealers(n)
	local mode = ns.db.healer
	if mode == "off" or n < 2 then
		for i = 1, n do order[i] = i end
		return order
	end
	if mode == "first" then
		for i = 1, n do if healer[i] then order[#order + 1] = i end end
		for i = 1, n do if not healer[i] then order[#order + 1] = i end end
	else
		for i = 1, n do if not healer[i] then order[#order + 1] = i end end
		for i = 1, n do if healer[i] then order[#order + 1] = i end end
	end
	return order
end

function Frames:OnLayout()
	local db = ns.db
	for i = 1, MAX do frames[i].slot = i end
	for slot, id in ipairs(ComputeOrder(self:Count())) do frames[id].slot = slot end
	local W, H, S = db.width, db.height, db.spacing
	anchor:SetScale(db.scale)
	ns:SetPointFromTable(anchor, db.point)
	if db.horizontal then
		ns:Size(anchor, 3 * W + 2 * S, H)
	else
		ns:Size(anchor, W, 3 * H + 2 * S)
	end
	for i = 1, MAX do
		local f = frames[i]
		f:ClearAllPoints()
		local off = (f.slot - 1) * ((db.horizontal and W or H) + S)
		if db.horizontal then
			f:SetPoint("TOPLEFT", anchor, "TOPLEFT", off, 0)
		elseif db.growUp then
			f:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, off)
		else
			f:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -off)
		end
		self:LayoutFrame(f)
	end
	if ns.state.testMode then self:FillTest() end
end

function Frames:RequestSort()
	if not ns.initialized then return end
	for slot, id in ipairs(ComputeOrder(self:Count())) do
		if frames[id].slot ~= slot then
			ns:Layout() -- moves now, or after combat
			return
		end
	end
end

function Frames:ShowFrames(n)
	if InCombatLockdown() then
		pendingShow = n
		ns:Defer(function() if pendingShow then self:ShowFrames(pendingShow) end end)
		return
	end
	pendingShow = nil
	for i = 1, MAX do ns:Show(frames[i], i <= n) end
	self:UpdateBorders()
	ns:Fire("FRAMES_SHOWN", n)
end

---------------------------------------------------------------------------
-- test mode
---------------------------------------------------------------------------
local TEST = {
	{ name = "Testwarrior", className = "Warrior", class = "WARRIOR", race = "Human",   spec = "Arms",       hp = 0.82, ptoken = "RAGE", pet = nil },
	{ name = "Testpriest",  className = "Priest",  class = "PRIEST",  race = "Scourge", spec = "Discipline", hp = 0.55, ptoken = "MANA", pet = "Shadowfiend" },
	{ name = "Testmage",    className = "Mage",    class = "MAGE",    race = "Gnome",   spec = "Frost",      hp = 0.21, ptoken = "MANA", pet = "Water Elemental" },
}

function Frames:FillTest()
	local now = GetTime()
	local db = ns.db
	for i, t in ipairs(TEST) do
		local f = frames[i]
		self:ResetFrame(f)
		f.class, f.className, f.name, f.race = t.class, t.className, t.name, t.race
		f.guid = "TEST" .. i
		guidToFrame[f.guid] = f
		nameToFrame[f.name] = f
		self:UpdateName(f)
		SetClassIcon(f)
		f.hp:SetMinMaxValues(0, 24000)
		f.hp:SetValue(t.hp * 24000)
		f.hpPct = t.hp
		f.hpText:SetText(HealthString(f.cfg, t.hp * 24000, 24000))
		self:ColorHealth(f)
		local pc = PowerBarColor[t.ptoken]
		if pc then f.power:SetStatusBarColor(pc.r, pc.g, pc.b) end
		f.power:SetMinMaxValues(0, 100)
		f.power:SetValue(70)
		f.spec = t.spec
		f.role = ns.SpecRole[t.spec]
		self:UpdateSpecText(f)
		local r = ns.Racials[t.race]
		if r and r.icon then f.racial.icon:SetTexture(r.icon) end
		if t.pet and db.pets then
			f.pet.hp:SetMinMaxValues(0, 100)
			f.pet.hp:SetValue(60)
			f.pet.name:SetText(t.pet)
			f.pet:Show()
		end
	end
	ns:StartIconCooldown(frames[1].trinket, now - 30, ns.TRINKET_CD)
	ns:StartIconCooldown(frames[2].racial, now - 60, 120)
	if db.trinketReadyGlow then ns:IconGlow(frames[3].trinket, true) end
	if db.aura and db.auraCC then
		local _, _, polyIcon = GetSpellInfo(118)
		self:ShowAura(frames[3], polyIcon or ns.QMARK, 8, now + 8, "Polymorph")
	end
	if db.castbar then
		local healName, _, healIcon = GetSpellInfo(2060)
		self:FakeCast(frames[2], healName or "Greater Heal", healIcon or ns.QMARK, 2.5)
	end
	frames[1].testTarget = true
	DetectHealers(3)
	for _, el in ipairs(elementOrder) do
		if el.test then
			for i = 1, 3 do el.test(frames[i], i) end
		end
	end
	self:UpdateBorders()
	ns:Fire("TEST_FILLED")
end

function Frames:SetTest(on)
	if InCombatLockdown() then ns:Print(L["Not possible in combat."]) return end
	if on and ns.state.inArena then ns:Print(L["Not available inside an arena."]) return end
	ns.state.testMode = on
	if on then
		self:FillTest()
		self:ShowFrames(3)
		self:RequestSort()
	else
		for i = 1, MAX do self:ResetFrame(frames[i]) end
		self:ShowFrames(ns.state.inArena and arenaCount or 0)
	end
	ns:Fire("TEST_MODE", on)
end

function Frames:SetLocked(locked)
	ns.db.locked = locked
	ns:Fire("LOCK_CHANGED", locked)
	if locked then
		anchor.mover:Hide()
		if ns.state.testMode and not (ns.OptionsOpen and ns:OptionsOpen()) then self:SetTest(false) end
	else
		anchor.mover:Show()
		if not ns.state.inArena and not ns.state.testMode then self:SetTest(true) end
	end
end

---------------------------------------------------------------------------
-- Blizzard arena frames
---------------------------------------------------------------------------
local function HideBlizzardArena()
	if ns.db.blizzard then return end
	ns:Defer(function()
		if ArenaEnemyFrames then
			ArenaEnemyFrames:UnregisterAllEvents()
			ArenaEnemyFrames:SetParent(hiddenParent)
			ArenaEnemyFrames:Hide()
			for i = 1, MAX do
				for _, suffix in ipairs({ "", "CastingBar", "PetFrame" }) do
					local bf = _G["ArenaEnemyFrame" .. i .. suffix]
					if bf then bf:UnregisterAllEvents() end
				end
			end
		end
	end)
end

---------------------------------------------------------------------------
-- arena enter / leave
---------------------------------------------------------------------------
local function ScanArena()
	if not ns.state.inArena then return end
	arenaCount = mmax(arenaCount, ns:ArenaTeamSize())
	for i = 1, MAX do
		if UnitExists("arena" .. i) then
			arenaCount = mmax(arenaCount, i)
			Frames:UpdateAll(frames[i])
		end
	end
	ns.state.arenaSize = arenaCount
	Frames:ShowFrames(arenaCount)
	Frames:RequestSort()
end

ns:RegisterMessage("ARENA_ENTER", function()
	arenaCount = 0
	for i = 1, MAX do Frames:ResetFrame(frames[i]) end
	ScanArena()
end)
ns:RegisterMessage("ZONE_CHANGED", function() if ns.state.inArena then ScanArena() end end)
ns:RegisterMessage("ARENA_LEAVE", function()
	arenaCount = 0
	for i = 1, MAX do Frames:ResetFrame(frames[i]) end
	Frames:ShowFrames(ns.state.testMode and 3 or 0)
end)

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------
function Frames:OnInit()
	ns:BuildSpellLookups()
	ns:BuildCooldownIndex()
	for i = 1, MAX do
		local f = self:CreateUnitFrame(i, "arena" .. i, "WArenaFrame" .. i, "arena", anchor, ns.db)
		frames[i] = f
		unitToFrame["arena" .. i] = f
		self:ResetFrame(f)
	end
	ns:MakeMovable(anchor, "WArena", function(p) ns.db.point = p end)
	if not ns.db.locked then anchor.mover:Show() end
	if IsAddOnLoaded("Blizzard_ArenaUI") then HideBlizzardArena() end
	ns:RegisterMessage("BLIZZARD_ADDON_LOADED", function(_, name) if name == "Blizzard_ArenaUI" then HideBlizzardArena() end end)
end

function Frames:OnProfileChanged()
	for i = 1, MAX do frames[i].cfg = ns.db end
	if not ns.db.locked then anchor.mover:Show() else anchor.mover:Hide() end
end

function Frames:OnSettingChanged(key, value)
	if key == "aura" and not value then
		for i = 1, MAX do self:ClearAura(frames[i]) end
	elseif key == "castbar" and not value then
		for i = 1, MAX do frames[i].cast:Hide() end
	elseif key == "pets" then
		for i = 1, MAX do self:UpdatePet(frames[i]) end
	end
	if ns.state.inArena then
		for i = 1, arenaCount do if UnitExists(frames[i].unit) then self:UpdateAll(frames[i]) end end
	end
end

ns:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", function() if ns.state.inArena then ScanArena() end end)

ns:RegisterEvent("ARENA_OPPONENT_UPDATE", function(_, unit, updateType)
	local f = unitToFrame[unit]
	if not f or ns.state.testMode then return end
	if updateType == "seen" then
		if not ns.state.inArena then ns.UpdateZone() end
		Frames:UpdateAll(f)
		f.unseen = nil
		f:SetAlpha(1)
		if f.id > arenaCount then
			arenaCount = f.id
			ns.state.arenaSize = arenaCount
			Frames:ShowFrames(arenaCount)
		end
		Frames:RequestSort()
		Frames:UpdateBorders()
		ns:Fire("ENEMY_SEEN", f)
	elseif updateType == "unseen" then
		f.unseen = true
		f:SetAlpha(ns.db.unseenAlpha)
		f.cast:Hide()
		ns:Fire("ENEMY_UNSEEN", f)
	elseif updateType == "destroyed" then
		f.unseen = true
		f:SetAlpha(ns.db.unseenAlpha)
		f.cast:Hide()
	elseif updateType == "cleared" then
		Frames:ResetFrame(f)
	end
end)

local function UnitEvent(method)
	return function(_, unit)
		local f = unitToFrame[unit]
		if f and not ns.state.testMode then Frames[method](Frames, f) end
	end
end

ns:RegisterEvents(UnitEvent("UpdateHealth"), "UNIT_HEALTH", "UNIT_MAXHEALTH")
ns:RegisterEvents(UnitEvent("UpdatePower"), "UNIT_MANA", "UNIT_RAGE", "UNIT_ENERGY", "UNIT_RUNIC_POWER", "UNIT_MAXMANA",
	"UNIT_MAXRAGE", "UNIT_MAXENERGY", "UNIT_MAXRUNIC_POWER", "UNIT_DISPLAYPOWER")
ns:RegisterEvent("UNIT_AURA", UnitEvent("UpdateAuras"))
ns:RegisterEvent("UNIT_NAME_UPDATE", UnitEvent("UpdateIdentity"))
ns:RegisterEvents(UnitEvent("UpdateCast"), "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_CHANNEL_STOP")
ns:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", function(_, unit)
	local f = unitToFrame[unit]
	if f and not ns.state.testMode then Frames:CastInterrupted(f) end
end)
ns:RegisterEvents(function() if not ns.state.testMode then Frames:UpdateBorders() end end, "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED")

-- pets: UNIT_PET fires for the owner unit, health events for arenapetN
ns:RegisterEvent("UNIT_PET", function(_, unit)
	local f = unitToFrame[unit]
	if f and not ns.state.testMode then Frames:UpdatePet(f) end
end)
local petOwner = {}
for i = 1, MAX do petOwner["arenapet" .. i] = "arena" .. i end
ns:RegisterEvents(function(_, unit)
	local owner = petOwner[unit]
	local f = owner and unitToFrame[owner]
	if f and not ns.state.testMode then Frames:UpdatePet(f) end
end, "UNIT_HEALTH", "UNIT_MAXHEALTH")

-- 3.3.5 signature: timestamp, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, school, ...
ns:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", function(_, _, sub, srcGUID, srcName, _, dstGUID, dstName, _, spellId, spellName, _, extra1, extra2, extra3)
	if ns.state.testMode then return end
	local sf = srcGUID and guidToFrame[srcGUID]
	local df = dstGUID and guidToFrame[dstGUID]
	if not sf and not df then
		if ns.state.inBG then ns:Fire("CLEU_BG", sub, srcGUID, srcName, dstGUID, dstName, spellId, spellName, extra1, extra2, extra3) end
		return
	end
	if sf and spellName then
		if sub ~= "SPELL_AURA_REMOVED" then Frames:TrySpec(sf, spellName) end
		if sub == "SPELL_CAST_SUCCESS" then
			local now = GetTime()
			if ns.Lookup.trinket[spellName] then
				ns:StartIconCooldown(sf.trinket, now, ns.TRINKET_CD)
				ns:IconGlow(sf.trinket, false)
				sf.trinketReadyAt = now + ns.TRINKET_CD
				ns:Fire("ENEMY_TRINKET", sf, spellName)
			end
			local r = ns.Lookup.racial[spellName]
			if r then
				sf.racial.icon:SetTexture(r.icon)
				ns:StartIconCooldown(sf.racial, now, r.cd)
				if r.race == "Scourge" then
					-- Will of the Forsaken puts the PvP trinket on a 45 s cooldown
					local left = (sf.trinket.expires or 0) - now
					if left < 45 then
						ns:StartIconCooldown(sf.trinket, now, 45)
						ns:IconGlow(sf.trinket, false)
						sf.trinketReadyAt = now + 45
					end
				end
				ns:Fire("ENEMY_RACIAL", sf, spellName)
			end
			if ns.Lookup.resurrect[spellName] then ns:Fire("ENEMY_RESURRECT", sf, dstName, spellName) end
		elseif sub == "SPELL_CAST_START" then
			if ns.Lookup.resurrect[spellName] then ns:Fire("ENEMY_RESURRECT", sf, dstName, spellName) end
		end
	end
	if df then
		if sub == "SPELL_INTERRUPT" then
			Frames:CastInterrupted(df, srcName)
			ns:Fire("ENEMY_INTERRUPTED", df, srcName, extra2)
		elseif sub == "UNIT_DIED" then
			df.cast:Hide()
			ns:Fire("ENEMY_DIED", df)
		end
	end
	ns:Fire("ENEMY_CLEU", sub, sf, df, spellId, spellName, extra1, extra2, extra3, srcName, dstName)
end)

-- trinket ready glow
ns:AddTicker(0.5, function(now)
	if not ns.db or not ns.db.trinketReadyGlow then return end
	for i = 1, MAX do
		local f = frames[i]
		if f.trinketReadyAt and now >= f.trinketReadyAt then
			f.trinketReadyAt = nil
			ns:IconGlow(f.trinket, true)
			ns:Fire("ENEMY_TRINKET_READY", f)
			ns:After(6, function() ns:IconGlow(f.trinket, false) end)
		end
	end
end)

---------------------------------------------------------------------------
-- commands + API
---------------------------------------------------------------------------
ns:AddCommand("test", "toggle test frames", function() Frames:SetTest(not ns.state.testMode) end)
ns:AddCommand("unlock", "move the frames", function() Frames:SetLocked(false) end)
ns:AddCommand("lock", "lock the frames", function() Frames:SetLocked(true) end)
ns:AddCommand("reset", "reset the active profile", function()
	if InCombatLockdown() then ns:Print(L["Not possible in combat."]) return end
	ns:ResetProfile()
	ns:Print("Profile reset.")
end)

ns.IsTest = function() return ns.state.testMode end
ns.IsLocked = function() return ns.db.locked end
ns.InArena = function() return ns.state.inArena end
ns.ToggleTest = function() Frames:SetTest(not ns.state.testMode) end
ns.SetTest = function(on) Frames:SetTest(on) end
ns.SetLocked = function(locked) Frames:SetLocked(locked) end
