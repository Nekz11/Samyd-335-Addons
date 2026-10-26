-- WArena: boss frames (boss1-4) for dungeons/raids, built on the same frame engine
local _, ns = ...
local L = ns.L
local Boss = ns:NewModule("Boss")
ns.Boss = Boss

local MAXB = ns.MAX_BOSS
local UnitExists, InCombatLockdown = UnitExists, InCombatLockdown

ns:AddDefaults({
	bossEnabled = true, bossHideBlizzard = true, bossTest = false,
	boss_point = { "RIGHT", "UIParent", "RIGHT", -260, -140 },
	boss_width = 200, boss_height = 36, boss_scale = 1, boss_spacing = 14, boss_growUp = false,
	boss_castPos = "below", boss_castHeight = 14, boss_powerBar = true, boss_powerHeight = 6,
	boss_healthText = "both", boss_nameMode = "name", boss_classcolor = false, boss_healthGradient = true,
	boss_indTargetingYou = true, boss_indPartyTargets = true, boss_indEnemyTarget = true, boss_indLowHP = false,
})

-- settings that are always off for bosses
local OVERRIDE = {
	trinket = false, racial = false, dr = false, cooldowns = false, pets = false, arenaId = false,
	spec = false, aura = false, auraRow = false, totems = false, indRange = false, indDrink = false, indStealth = false, mirror = false,
	healer = "off", healerIcon = false, nameLimit = 0,
}

local cfg = setmetatable({}, { __index = function(_, k)
	local o = OVERRIDE[k]
	if o ~= nil then return o end
	local db = ns.db
	if not db then return nil end
	local v = db["boss_" .. k]
	if v ~= nil then return v end
	return db[k]
end })
Boss.cfg = cfg

local anchor = CreateFrame("Frame", "WArenaBossAnchor", UIParent)
local frames, unitToFrame = {}, {}
Boss.frames = frames
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()
local shownCount = 0

local function Update(f)
	local F = ns.Frames
	F:UpdateIdentity(f)
	F:UpdateHealth(f)
	F:UpdatePower(f)
	F:UpdateAuras(f)
	F:UpdateCast(f)
	ns.Indicators:UpdateEnemyTarget(f)
	ns.Indicators:UpdatePartyTargets(f)
	ns.Indicators:UpdateLowHP(f)
end

local function Scan()
	local db = ns.db
	if not db or not db.bossEnabled then return end
	if db.bossTest then return end
	local n = 0
	for i = 1, MAXB do
		local f = frames[i]
		if UnitExists(f.unit) then
			n = i
			Update(f)
		else
			ns.Frames:ResetFrame(f)
		end
	end
	if n ~= shownCount then
		shownCount = n
		ns:Defer(function()
			for i = 1, MAXB do ns:Show(frames[i], i <= shownCount) end
		end)
	end
end

function Boss:UpdateBorders()
	for i = 1, MAXB do
		local f = frames[i]
		local shown = false
		if f:IsShown() and UnitExists(f.unit) then
			if cfg.targetBorder and UnitIsUnit("target", f.unit) then
				f.border:SetBackdropBorderColor(ns:Color("targetColor"))
				shown = true
			elseif cfg.focusBorder and UnitIsUnit("focus", f.unit) then
				f.border:SetBackdropBorderColor(ns:Color("focusColor"))
				shown = true
			end
		end
		ns:Show(f.border, shown)
	end
end

local function HideBlizzardBoss()
	if not ns.db.bossHideBlizzard then return end
	ns:Defer(function()
		for i = 1, MAXB do
			local bf = _G["Boss" .. i .. "TargetFrame"]
			if bf then
				bf:UnregisterAllEvents()
				bf:SetParent(hiddenParent)
				bf:Hide()
			end
		end
	end)
end

---------------------------------------------------------------------------
-- test
---------------------------------------------------------------------------
local TEST = {
	{ name = "Lord Marrowgar", hp = 0.72 }, { name = "Bone Spike", hp = 0.4 },
}

function Boss:FillTest()
	local F = ns.Frames
	for i, t in ipairs(TEST) do
		local f = frames[i]
		F:ResetFrame(f)
		f.name, f.class, f.className = t.name, "WARRIOR", "Boss"
		F:UpdateName(f)
		f.hp:SetMinMaxValues(0, 1000000)
		f.hp:SetValue(t.hp * 1000000)
		f.hpPct = t.hp
		f.hpText:SetText(ns:Short(t.hp * 1000000) .. " | " .. math.floor(t.hp * 100) .. "%")
		F:ColorHealth(f)
		f.power:SetMinMaxValues(0, 100)
		f.power:SetValue(35)
		f.power:SetStatusBarColor(1, 0, 0)
		if i == 1 then
			f.testTargetingYou = true
			f.testEnemyTarget = ns:Colored("You", "ROGUE")
			f.testPartyTargets = { "WARRIOR", "PALADIN", "MAGE" }
			F:FakeCast(f, "Bone Storm", ns.QMARK, 3)
		else
			f.testEnemyTarget = ns:Colored("Healer", "PRIEST")
		end
		ns.Indicators:UpdateEnemyTarget(f)
		ns.Indicators:UpdatePartyTargets(f)
	end
	ns:Defer(function()
		for i = 1, MAXB do ns:Show(frames[i], i <= #TEST) end
	end)
end

function Boss:SetTest(on)
	if InCombatLockdown() then ns:Print(L["Not possible in combat."]) return end
	ns.db.bossTest = on
	if on then
		self:FillTest()
	else
		for i = 1, MAXB do ns.Frames:ResetFrame(frames[i]) end
		shownCount = -1
		Scan()
		if shownCount <= 0 then for i = 1, MAXB do frames[i]:Hide() end end
	end
end

---------------------------------------------------------------------------
-- layout / init
---------------------------------------------------------------------------
function Boss:OnLayout()
	local db = ns.db
	anchor:SetScale(cfg.scale)
	ns:SetPointFromTable(anchor, db.boss_point)
	local W, H, S = cfg.width, cfg.height, cfg.spacing
	local below, above = ns.Frames:StackExtents(cfg)
	local step = H + S + below + above
	ns:Size(anchor, W, 2 * step - S)
	for i = 1, MAXB do
		local f = frames[i]
		f:ClearAllPoints()
		if cfg.growUp then
			f:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, (i - 1) * step + below)
		else
			f:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -((i - 1) * step + above))
		end
		ns.Frames:LayoutFrame(f)
	end
	if db.bossTest then self:FillTest() end
	if not db.bossEnabled then
		ns:Defer(function() for i = 1, MAXB do frames[i]:Hide() end end)
	end
end

function Boss:OnInit()
	for i = 1, MAXB do
		local f = ns.Frames:CreateUnitFrame(i, "boss" .. i, "WArenaBoss" .. i, "boss", anchor, cfg)
		frames[i] = f
		unitToFrame["boss" .. i] = f
		ns.Frames:ResetFrame(f)
	end
	ns:MakeMovable(anchor, "WArena boss frames", function(p) ns.db.boss_point = p end)
	ns:RegisterMessage("LOCK_CHANGED", function(_, locked)
		ns:Show(anchor.mover, not locked)
		if not locked and not ns.db.bossTest then Boss:SetTest(true) elseif locked and ns.db.bossTest and not (ns.OptionsOpen and ns:OptionsOpen()) then Boss:SetTest(false) end
	end)
	ns:RegisterMessage("TEST_MODE", function(_, on)
		if on and not ns.db.bossTest then Boss:SetTest(true) elseif not on and ns.db.bossTest then Boss:SetTest(false) end
	end)
	if not ns.db.locked then anchor.mover:Show() end
	HideBlizzardBoss()
	ns.db.bossTest = false
end

function Boss:OnProfileChanged()
	shownCount = -1
	Scan()
end

function Boss:OnSettingChanged(key, value)
	if key == "bossEnabled" then
		if value then shownCount = -1; Scan() else ns:Defer(function() for i = 1, MAXB do frames[i]:Hide() end end) end
	elseif key == "bossHideBlizzard" and value then
		HideBlizzardBoss()
	end
end

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------
ns:RegisterEvents(function() Scan() end, "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "UNIT_TARGETABLE_CHANGED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA")

local function UnitEvent(method)
	return function(_, unit)
		local f = unitToFrame[unit]
		if f and ns.db and ns.db.bossEnabled and not ns.db.bossTest then ns.Frames[method](ns.Frames, f) end
	end
end
ns:RegisterEvents(UnitEvent("UpdateHealth"), "UNIT_HEALTH", "UNIT_MAXHEALTH")
ns:RegisterEvents(UnitEvent("UpdatePower"), "UNIT_MANA", "UNIT_RAGE", "UNIT_ENERGY", "UNIT_RUNIC_POWER", "UNIT_MAXMANA", "UNIT_MAXRAGE", "UNIT_MAXENERGY", "UNIT_MAXRUNIC_POWER", "UNIT_DISPLAYPOWER")
ns:RegisterEvent("UNIT_AURA", UnitEvent("UpdateAuras"))
ns:RegisterEvent("UNIT_NAME_UPDATE", UnitEvent("UpdateIdentity"))
ns:RegisterEvents(UnitEvent("UpdateCast"), "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_CHANNEL_STOP")
ns:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", function(_, unit)
	local f = unitToFrame[unit]
	if f and not ns.db.bossTest then ns.Frames:CastInterrupted(f) end
end)
ns:RegisterEvent("UNIT_TARGET", function(_, unit)
	if ns.db and ns.db.bossTest then return end
	local f = unitToFrame[unit]
	if f then ns.Indicators:UpdateEnemyTarget(f) end
	if unit == "player" or unit:sub(1, 5) == "party" then
		for i = 1, MAXB do if frames[i]:IsShown() then ns.Indicators:UpdatePartyTargets(frames[i]) end end
	end
end)
ns:RegisterEvents(function() if not (ns.db and ns.db.bossTest) then Boss:UpdateBorders() end end, "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED")
ns:RegisterMessage("ENEMY_HEALTH", function(_, f) if f.kind == "boss" then ns.Indicators:UpdateLowHP(f) end end)

-- a slow safety scan while inside instances (engage events are not always reliable on private servers)
ns:AddTicker(2, function()
	local it = ns.state.instanceType
	if it == "party" or it == "raid" then Scan() end
end)

ns:AddCommand("boss", "toggle boss frame preview", function() Boss:SetTest(not ns.db.bossTest) end)
