-- WArena: indicators – targeting you, party targets, enemy target, range, drink, low health, stealth
local _, ns = ...
local Ind = ns:NewModule("Indicators")
ns.Indicators = Ind

local floor, mmax, mmin = math.floor, math.max, math.min
local GetTime, UnitExists, UnitIsUnit = GetTime, UnitExists, UnitIsUnit

ns:AddDefaults({
	indTargetingYou = true, indPartyTargets = true, indEnemyTarget = true, indEnemyTargetMode = "name",
	indRange = false, rangeAlpha = 0.6, indDrink = true, indLowHP = true, lowHPThreshold = 25,
	lowHPColor = { r = 1, g = 0.1, b = 0.1, a = 0.6 }, indStealth = true,
	indIconSize = 14,
})

local PARTY_UNITS = { "player", "party1", "party2", "party3", "party4" }
local rangeSpell -- name of the spell used for range checks (resolved once)

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function ResolveRangeSpell()
	if rangeSpell ~= nil then return rangeSpell end
	local _, class = UnitClass("player")
	local list = class and ns.RangeSpells[class]
	rangeSpell = false
	if list then
		for _, id in ipairs(list) do
			local name = GetSpellInfo(id)
			if name and (not IsSpellKnown or IsSpellKnown(id)) then
				-- IsSpellInRange returns nil for unknown spells; we accept the first known one
				rangeSpell = name
				break
			end
		end
	end
	return rangeSpell
end

local function ApplyAlpha(f)
	local cfg = f.cfg
	if ns.state.testMode then f:SetAlpha(1) return end
	if f.unseen then
		f:SetAlpha(cfg.unseenAlpha)
	elseif f.outOfRange and cfg.indRange then
		f:SetAlpha(cfg.rangeAlpha)
	else
		f:SetAlpha(1)
	end
end

---------------------------------------------------------------------------
-- targeting you / enemy target / party targets
---------------------------------------------------------------------------
function Ind:UpdateEnemyTarget(f)
	local cfg = f.cfg
	local unit = f.unit .. "target"
	local tyou = false
	if (UnitExists(f.unit) or ns.state.testMode) and f.cfg.indTargetingYou then
		tyou = f.testTargetingYou or (UnitExists(unit) and UnitIsUnit(unit, "player"))
	end
	ns:Show(f.targetingYou, tyou and cfg.indTargetingYou)
	if cfg.indEnemyTarget then
		local txt = ""
		if f.testEnemyTarget then
			txt = f.testEnemyTarget
		elseif UnitExists(unit) then
			local name = UnitName(unit)
			local _, class = UnitClass(unit)
			if cfg.indEnemyTargetMode == "class" and class then
				txt = ns.CLASS_NAMES[class] or name
			else
				txt = ns:ShortName(name)
			end
			if class then txt = ns:Colored(txt, class) end
		end
		f.targetText:SetText(txt ~= "" and ("> " .. txt) or "")
		f.targetText:Show()
	else
		f.targetText:Hide()
	end
	if tyou ~= f.wasTargetingYou then
		f.wasTargetingYou = tyou
		ns:Fire("ENEMY_TARGETING_YOU", f, tyou)
	end
end

function Ind:UpdatePartyTargets(f)
	local cfg = f.cfg
	local n = 0
	if cfg.indPartyTargets and (UnitExists(f.unit) or ns.state.testMode) then
		if ns.state.testMode and f.testPartyTargets then
			for _, class in ipairs(f.testPartyTargets) do
				n = n + 1
				local t = f.partyTargets[n]
				if t then ns:SetClassIcon(t, class); t:Show() end
			end
		else
			for _, pu in ipairs(PARTY_UNITS) do
				if UnitExists(pu) and UnitExists(pu .. "target") and UnitIsUnit(pu .. "target", f.unit) then
					n = n + 1
					local t = f.partyTargets[n]
					if t then
						local _, class = UnitClass(pu)
						ns:SetClassIcon(t, class)
						t:Show()
					end
				end
			end
		end
	end
	for i = n + 1, #f.partyTargets do f.partyTargets[i]:Hide() end
	f.partyTargetCount = n
end

function Ind:UpdateAllTargets()
	ns.Frames:EachVisible(function(f)
		Ind:UpdateEnemyTarget(f)
		Ind:UpdatePartyTargets(f)
	end)
end

---------------------------------------------------------------------------
-- drink / stealth / low hp
---------------------------------------------------------------------------
function Ind:SetDrink(f, drinking, duration, expires)
	local cfg = f.cfg
	if drinking and cfg.indDrink then
		f.drinkCount = (f.drinkCount or 0) + 1
		f.drink.corner:SetText(f.drinkCount > 1 and ("x" .. f.drinkCount) or "")
		if duration and duration > 0 and expires then
			ns:StartIconCooldown(f.drink, expires - duration, duration)
		else
			ns:StartIconCooldown(f.drink)
		end
		f.drink:Show()
	else
		ns:StartIconCooldown(f.drink)
		f.drink:Hide()
	end
end

function Ind:UpdateLowHP(f)
	local cfg = f.cfg
	local low = cfg.indLowHP and f.hpPct and not f.dead and f.hpPct * 100 <= cfg.lowHPThreshold
	if low then
		f.lowHP:SetTexture(ns:Color("lowHPColor"))
		f.lowHP:Show()
	else
		f.lowHP:Hide()
	end
	if low and not f.wasLow then ns:Fire("ENEMY_LOWHP", f, floor((f.hpPct or 0) * 100 + 0.5)) end
	f.wasLow = low or nil
end

function Ind:UpdateStealth(f)
	ns:Show(f.stealthIcon, f.cfg.indStealth and f.unseen and not f.dead)
	ApplyAlpha(f)
end

---------------------------------------------------------------------------
-- frame element
---------------------------------------------------------------------------
ns.Frames:RegisterElement("indicators", {
	order = 50,
	create = function(f)
		local layer = CreateFrame("Frame", nil, f)
		layer:SetAllPoints()
		layer:SetFrameLevel(f.textLayer:GetFrameLevel() + 1)
		f.indLayer = layer

		f.targetingYou = ns:NewText(layer, "CENTER")
		f.targetingYou:SetText("!")
		f.targetingYou:SetTextColor(1, 0.15, 0.15)
		f.targetingYou:Hide()

		f.targetText = ns:NewText(layer, "RIGHT")
		f.targetText:Hide()

		f.partyTargets = {}
		for i = 1, 5 do
			local t = layer:CreateTexture(nil, "OVERLAY")
			t:Hide()
			f.partyTargets[i] = t
		end

		f.drink = ns:CreateIcon(f)
		f.drink.icon:SetTexture(ns.DRINK_TEX)
		f.drink:Hide()

		f.stealthIcon = layer:CreateTexture(nil, "OVERLAY")
		f.stealthIcon:SetTexture(ns.EYE_TEX)
		f.stealthIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		f.stealthIcon:Hide()

		f.lowHP = f.hp:CreateTexture(nil, "OVERLAY")
		f.lowHP:SetAllPoints(f.hp)
		f.lowHP:SetTexture(1, 0.1, 0.1, 0.6)
		f.lowHP:SetBlendMode("ADD")
		f.lowHP:Hide()
	end,
	layout = function(f, cfg, chain)
		local H = cfg.height
		local s = cfg.indIconSize
		ns:SetFont(f.targetingYou, mmax(12, floor(H * 0.7)), "THICKOUTLINE")
		f.targetingYou:ClearAllPoints()
		f.targetingYou:SetPoint("CENTER", f.iconHolder, "CENTER", 0, 0)

		ns:SetFont(f.targetText, mmax(7, cfg.fontSize - 2))
		f.targetText:ClearAllPoints()
		if cfg.powerBar then
			f.targetText:SetPoint("RIGHT", f.power, "RIGHT", -3, 0)
		else
			f.targetText:SetPoint("BOTTOMRIGHT", f.hp, "BOTTOMRIGHT", -3, 1)
		end

		for i, t in ipairs(f.partyTargets) do
			ns:Size(t, s, s)
			t:ClearAllPoints()
			t:SetPoint("BOTTOMLEFT", f.hp, "TOPLEFT", (i - 1) * (s + 1), 2)
		end

		ns:SetIconSize(f.drink, mmax(12, floor(H * 0.6)))
		f.drink:ClearAllPoints()
		f.drink:SetPoint("BOTTOMRIGHT", f.hp, "TOPRIGHT", 0, 2)

		ns:Size(f.stealthIcon, s, s)
		f.stealthIcon:ClearAllPoints()
		f.stealthIcon:SetPoint("TOPRIGHT", f.iconHolder, "TOPRIGHT", 2, 2)
	end,
	reset = function(f)
		f.targetingYou:Hide()
		f.targetText:SetText("")
		for _, t in ipairs(f.partyTargets) do t:Hide() end
		f.drinkCount, f.wasLow, f.wasTargetingYou, f.outOfRange = nil, nil, nil, nil
		f.testTargetingYou, f.testEnemyTarget, f.testPartyTargets = nil, nil, nil
		ns:StartIconCooldown(f.drink)
		f.drink:Hide()
		f.stealthIcon:Hide()
		f.lowHP:Hide()
	end,
	update = function(f)
		Ind:UpdateEnemyTarget(f)
		Ind:UpdatePartyTargets(f)
		Ind:UpdateLowHP(f)
		Ind:UpdateStealth(f)
	end,
	test = function(f, i)
		if i == 1 then
			f.testTargetingYou = true
			f.testEnemyTarget = ns:Colored("You", select(2, UnitClass("player")))
			f.testPartyTargets = { "PALADIN", "ROGUE" }
		elseif i == 2 then
			f.testEnemyTarget = ns:Colored("Teammate", "PALADIN")
			f.testPartyTargets = { "ROGUE" }
			Ind:SetDrink(f, true, 20, GetTime() + 12)
		else
			f.testEnemyTarget = ""
			Ind:UpdateLowHP(f)
		end
		Ind:UpdateEnemyTarget(f)
		Ind:UpdatePartyTargets(f)
		Ind:UpdateLowHP(f)
	end,
})

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------
ns:RegisterEvent("UNIT_TARGET", function(_, unit)
	if ns.state.testMode then return end
	local f = ns.Frames:ByUnit(unit)
	if f then Ind:UpdateEnemyTarget(f) end
	if unit == "player" or unit:sub(1, 5) == "party" then Ind:UpdateAllTargets() end
end)
ns:RegisterEvents(function() if not ns.state.testMode then Ind:UpdateAllTargets() end end, "PLAYER_TARGET_CHANGED", "PARTY_MEMBERS_CHANGED")

ns:RegisterMessage("ENEMY_DRINK", function(_, f, drinking, duration, expires) Ind:SetDrink(f, drinking, duration, expires) end)
ns:RegisterMessage("ENEMY_HEALTH", function(_, f) Ind:UpdateLowHP(f) end)
ns:RegisterMessage("ENEMY_SEEN", function(_, f) Ind:UpdateStealth(f); Ind:UpdateEnemyTarget(f); Ind:UpdatePartyTargets(f) end)
ns:RegisterMessage("ENEMY_UNSEEN", function(_, f) Ind:UpdateStealth(f) end)
ns:RegisterMessage("ENEMY_DIED", function(_, f) f.wasLow = nil; f.lowHP:Hide() end)

-- range check (4 Hz)
ns:AddTicker(0.25, function()
	if not ns.db or not ns.db.indRange or not ns.state.inArena or ns.state.testMode then return end
	local spell = ResolveRangeSpell()
	ns.Frames:EachVisible(function(f)
		if UnitExists(f.unit) then
			local inRange
			if spell then
				inRange = IsSpellInRange(spell, f.unit)
			end
			if inRange == nil then
				inRange = CheckInteractDistance(f.unit, 4) and 1 or 0 -- 28 yd fallback
			end
			local oor = inRange == 0
			if oor ~= (f.outOfRange or false) then
				f.outOfRange = oor or nil
				ApplyAlpha(f)
			end
		end
	end)
end)

-- low hp pulse (10 Hz)
ns:AddTicker(0.1, function()
	ns.Frames:EachVisible(function(f)
		if f.lowHP:IsShown() then ns:Pulse(f.lowHP, 0.35) end
		if f.targetingYou:IsShown() then ns:Pulse(f.targetingYou, 0.25) end
	end)
end)

function Ind:OnSettingChanged(key)
	if key:sub(1, 3) == "ind" or key == "lowHPThreshold" then
		ns.Frames:Each(function(f)
			Ind:UpdateEnemyTarget(f); Ind:UpdatePartyTargets(f); Ind:UpdateLowHP(f); Ind:UpdateStealth(f)
		end)
	end
end
