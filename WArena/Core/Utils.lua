-- WArena: utilities – media, fonts, formatting, colors, sounds, icon widgets
local _, ns = ...

local floor, ceil, format, mmax, mmin = math.floor, math.ceil, string.format, math.max, math.min
local GetTime = GetTime

ns.WHITE = "Interface\\Buttons\\WHITE8X8"
ns.QMARK = "Interface\\Icons\\INV_Misc_QuestionMark"
ns.CLASS_TEX = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
ns.TRINKET_A = "Interface\\Icons\\INV_Jewelry_TrinketPVP_01"
ns.TRINKET_H = "Interface\\Icons\\INV_Jewelry_TrinketPVP_02"
ns.ROLE_TEX = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
ns.HEALER_COORDS = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 }
ns.TANK_COORDS = { 0, 19 / 64, 22 / 64, 41 / 64 }
ns.DPS_COORDS = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 }
ns.DRINK_TEX = "Interface\\Icons\\INV_Drink_07"
ns.EYE_TEX = "Interface\\Icons\\Ability_Stealth"
ns.FLAG_A_TEX = "Interface\\Icons\\INV_BannerPVP_02"
ns.FLAG_H_TEX = "Interface\\Icons\\INV_BannerPVP_01"
ns.GLOW_TEX = "Interface\\Buttons\\UI-ActionButton-Border"

---------------------------------------------------------------------------
-- media (built-in + LibSharedMedia if present)
---------------------------------------------------------------------------
ns.TEXTURES = {
	{ "Blizzard", "Interface\\TargetingFrame\\UI-StatusBar" },
	{ "Flat",     ns.WHITE },
	{ "Raid",     "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
	{ "Skills",   "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
	{ "Glass",    "Interface\\AddOns\\WArena\\Media\\Glass" },
	{ "Smooth",   "Interface\\AddOns\\WArena\\Media\\Smooth" },
}
ns.FONTS = {
	{ "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
	{ "Arial Narrow",  "Fonts\\ARIALN.TTF" },
	{ "Morpheus",      "Fonts\\MORPHEUS.TTF" },
	{ "Skurri",        "Fonts\\skurri.TTF" },
}
ns.SOUNDS = {
	{ "None", nil },
	{ "Raid warning", "Sound\\Interface\\RaidWarning.wav" },
	{ "Ready check", "Sound\\Interface\\ReadyCheck.wav" },
	{ "Alarm clock", "Sound\\Interface\\AlarmClockWarning3.wav" },
	{ "PvP flag taken", "Sound\\Interface\\PVPFlagTaken.wav" },
	{ "Map ping", "Sound\\Interface\\MapPing.wav" },
	{ "Bell", "Sound\\Doodad\\BellTollNightElf.wav" },
	{ "Gnome horn", "Sound\\Spells\\PVPFlagTakenHorde.wav" },
	{ "Level up", "Sound\\Interface\\LevelUp.wav" },
}

local function LSM()
	return LibStub and LibStub("LibSharedMedia-3.0", true)
end

function ns:MediaList(kind)
	local out, seen = {}, {}
	local list = kind == "statusbar" and ns.TEXTURES or ns.FONTS
	for _, e in ipairs(list) do
		if not e[2]:find("WArena\\Media") or ns.HAS_MEDIA_FOLDER then
			out[#out + 1] = e[1]
			seen[e[1]] = true
		end
	end
	local lsm = LSM()
	if lsm then
		for _, n in ipairs(lsm:List(kind)) do
			if not seen[n] then out[#out + 1] = n; seen[n] = true end
		end
	end
	return out
end

function ns:Media(kind, name)
	local list = kind == "statusbar" and ns.TEXTURES or ns.FONTS
	for _, e in ipairs(list) do
		if e[1] == name then return e[2] end
	end
	local lsm = LSM()
	if lsm then
		local p = lsm:Fetch(kind, name, true)
		if p then return p end
	end
	return list[1][2]
end

function ns:Texture()
	return ns:Media("statusbar", ns.db and ns.db.texture or "Blizzard")
end

-- outline flag from the profile ("OUTLINE", "THICKOUTLINE", "" or "MONOCHROME,OUTLINE")
function ns:FontFlags()
	local o = ns.db and ns.db.fontOutline or "OUTLINE"
	if o == "NONE" then return "" end
	return o
end

-- SetFont returns false for an invalid font file; fall back to the default font
function ns:SetFont(fs, size, flags, fontName)
	size = mmax(6, floor((size or 11) + 0.5))
	flags = flags or ns:FontFlags()
	local path = ns:Media("font", fontName or (ns.db and ns.db.font) or "Friz Quadrata")
	if not fs:SetFont(path, size, flags) then
		fs:SetFont(ns.FONTS[1][2], size, flags)
	end
	local shadow = ns.db and ns.db.fontShadow
	if shadow then
		fs:SetShadowColor(0, 0, 0, 1)
		fs:SetShadowOffset(1, -1)
	else
		fs:SetShadowOffset(0, 0)
	end
end

function ns:NewText(parent, justify, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	fs:SetFont(ns.FONTS[1][2], 11, "OUTLINE")
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

function ns:NewBar(parent)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetStatusBarTexture(ns.TEXTURES[1][2])
	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints()
	bar.bg:SetTexture(0, 0, 0, 0.55)
	return bar
end

function ns:Size(f, w, h)
	f:SetWidth(w)
	f:SetHeight(h)
end

function ns:Show(f, shown)
	if shown then f:Show() else f:Hide() end
end

---------------------------------------------------------------------------
-- formatting
---------------------------------------------------------------------------
function ns:FormatTime(left)
	if left >= 3600 then
		return format("%dh", floor(left / 3600))
	elseif left >= 60 then
		return format("%d:%02d", floor(left / 60), floor(left % 60))
	elseif left >= 10 then
		return format("%d", ceil(left))
	end
	return format("%.1f", left)
end

function ns:FormatClock(sec)
	sec = mmax(0, floor(sec))
	return format("%d:%02d", floor(sec / 60), sec % 60)
end

function ns:Short(n)
	if n >= 1e6 then return format("%.1fm", n / 1e6) end
	if n >= 1e3 then return format("%.1fk", n / 1e3) end
	return tostring(floor(n))
end

function ns:Round(v, step)
	step = step or 1
	return floor(v / step + 0.5) * step
end

function ns:Trim(s)
	return (s or ""):match("^%s*(.-)%s*$")
end

function ns:ShortName(name)
	if not name then return "" end
	return (name:match("^([^%-]+)")) or name
end

---------------------------------------------------------------------------
-- colors
---------------------------------------------------------------------------
function ns:ClassColor(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 0.7, 0.7, 0.7
end

function ns:ClassHex(class)
	local r, g, b = ns:ClassColor(class)
	return format("%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

function ns:Colored(text, class)
	return "|cff" .. ns:ClassHex(class) .. tostring(text) .. "|r"
end

function ns:Color(key)
	local c = ns.db and ns.db[key]
	if type(c) == "table" then return c.r or 1, c.g or 1, c.b or 1, c.a or 1 end
	return 1, 1, 1, 1
end

function ns:PowerColor(ptype, ptoken)
	local c = (ptoken and PowerBarColor[ptoken]) or PowerBarColor[ptype] or PowerBarColor["MANA"]
	if c then return c.r, c.g, c.b end
	return 0, 0, 1
end

-- health gradient green -> yellow -> red
function ns:HealthGradient(pct)
	local r, g
	if pct > 0.5 then
		r, g = (1 - pct) * 2, 1
	else
		r, g = 1, pct * 2
	end
	return r, g, 0
end

---------------------------------------------------------------------------
-- sounds
---------------------------------------------------------------------------
function ns:SoundPath(name)
	for _, e in ipairs(ns.SOUNDS) do
		if e[1] == name then return e[2] end
	end
	local lsm = LSM()
	if lsm then return lsm:Fetch("sound", name, true) end
end

function ns:SoundList()
	local out, seen = {}, {}
	for _, e in ipairs(ns.SOUNDS) do out[#out + 1] = e[1]; seen[e[1]] = true end
	local lsm = LSM()
	if lsm then
		for _, n in ipairs(lsm:List("sound")) do
			if not seen[n] then out[#out + 1] = n end
		end
	end
	return out
end

function ns:PlaySound(name)
	local path = ns:SoundPath(name)
	if path and PlaySoundFile then PlaySoundFile(path, "Master") end
end

---------------------------------------------------------------------------
-- class helpers
---------------------------------------------------------------------------
ns.CLASS_TOKENS = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
ns.CLASS_NAMES = {
	WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
	DEATHKNIGHT = "Death Knight", SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
}
ns.HEALER_CLASSES = { PRIEST = true, DRUID = true, SHAMAN = true, PALADIN = true }

-- localized class name -> token (built lazily from LOCALIZED_CLASS_NAMES_* when available)
local classByName
function ns:ClassToken(localized)
	if not localized then return end
	if not classByName then
		classByName = {}
		for _, tbl in ipairs({ LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE }) do
			if type(tbl) == "table" then
				for token, name in pairs(tbl) do classByName[name] = token end
			end
		end
		for token, name in pairs(ns.CLASS_NAMES) do classByName[name] = classByName[name] or token end
	end
	return classByName[localized]
end

function ns:SetClassIcon(tex, class, style)
	local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
	if coords then
		tex:SetTexture(ns.CLASS_TEX)
		local crop = (style == "crop") and 0.04 or 0.015
		tex:SetTexCoord(coords[1] + crop, coords[2] - crop, coords[3] + crop, coords[4] - crop)
	else
		tex:SetTexture(ns.QMARK)
		tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
end

---------------------------------------------------------------------------
-- icon widget with cooldown sweep, timer text and corner text
---------------------------------------------------------------------------
local function Timer_OnUpdate(self, elapsed)
	self.tick = (self.tick or 0) + elapsed
	if self.tick < 0.1 then return end
	self.tick = 0
	local left = (self.expires or 0) - GetTime()
	if left <= 0 then
		self.timer:SetText("")
		self:SetScript("OnUpdate", nil)
		self.expires = nil
		if self.OnExpire then self:OnExpire() end
		return
	end
	if self.showText then
		self.timer:SetText(ns:FormatTime(left))
		if left < 5 then self.timer:SetTextColor(1, 0.3, 0.3) elseif left < 15 then self.timer:SetTextColor(1, 1, 0.3) else self.timer:SetTextColor(1, 1, 1) end
	else
		self.timer:SetText("")
	end
end

function ns:CreateIcon(parent)
	local b = CreateFrame("Frame", nil, parent)
	b.border = b:CreateTexture(nil, "BACKGROUND")
	b.border:SetPoint("TOPLEFT", -1, 1)
	b.border:SetPoint("BOTTOMRIGHT", 1, -1)
	b.border:SetTexture(0, 0, 0, 1)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	b.cd:SetAllPoints(b.icon)
	b.overlay = CreateFrame("Frame", nil, b)
	b.overlay:SetAllPoints()
	b.overlay:SetFrameLevel(b.cd:GetFrameLevel() + 2)
	b.timer = b.overlay:CreateFontString(nil, "OVERLAY")
	b.timer:SetFont(ns.FONTS[1][2], 11, "OUTLINE") -- a font must be set before any SetText
	b.timer:SetPoint("CENTER", 0, 0)
	b.corner = b.overlay:CreateFontString(nil, "OVERLAY")
	b.corner:SetFont(ns.FONTS[1][2], 10, "OUTLINE")
	b.corner:SetPoint("TOPLEFT", 1, -1)
	b.glow = b.overlay:CreateTexture(nil, "OVERLAY")
	b.glow:SetTexture(ns.GLOW_TEX)
	b.glow:SetBlendMode("ADD")
	b.glow:SetPoint("TOPLEFT", -6, 6)
	b.glow:SetPoint("BOTTOMRIGHT", 6, -6)
	b.glow:SetVertexColor(1, 0.8, 0.2, 0.9)
	b.glow:Hide()
	return b
end

function ns:SetIconSize(b, size)
	ns:Size(b, size, size)
	ns:SetFont(b.timer, floor(size * 0.38))
	ns:SetFont(b.corner, floor(size * 0.34))
end

-- no start/duration = clear; silent = invisible timer (only for automatic cleanup)
function ns:StartIconCooldown(b, start, duration, silent)
	if duration and duration > 0 then
		b.expires = start + duration
		if silent then
			b.cd:Hide()
			b.showText = false
		else
			b.cd:SetCooldown(start, duration)
			b.cd:Show()
			b.showText = (ns.db and ns.db.cdText) and not OmniCC
		end
		b.tick = 1
		b:SetScript("OnUpdate", Timer_OnUpdate)
	else
		b.cd:Hide()
		b.expires = nil
		b.timer:SetText("")
		b:SetScript("OnUpdate", nil)
	end
end

function ns:IconGlow(b, on)
	if on then b.glow:Show() else b.glow:Hide() end
end

---------------------------------------------------------------------------
-- simple pulse animation without the animation system (3.3.5 safe)
---------------------------------------------------------------------------
function ns:Pulse(tex, speed)
	tex.pulseT = (tex.pulseT or 0) + (speed or 0.1)
	local a = 0.55 + 0.45 * math.sin(tex.pulseT)
	tex:SetAlpha(a)
end

---------------------------------------------------------------------------
-- borders / backdrops
---------------------------------------------------------------------------
ns.BACKDROP_THIN = { edgeFile = ns.WHITE, edgeSize = 1 }
ns.BACKDROP_THICK = { edgeFile = ns.WHITE, edgeSize = 2 }
ns.BACKDROP_GLOW = { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 }

function ns:ApplyBorderStyle(frame, style, r, g, b, a)
	frame:ClearAllPoints()
	if style == "glow" then
		frame:SetBackdrop(ns.BACKDROP_GLOW)
		frame:SetPoint("TOPLEFT", -5, 5)
		frame:SetPoint("BOTTOMRIGHT", 5, -5)
	elseif style == "thick" then
		frame:SetBackdrop(ns.BACKDROP_THICK)
		frame:SetPoint("TOPLEFT", -2, 2)
		frame:SetPoint("BOTTOMRIGHT", 2, -2)
	else
		frame:SetBackdrop(ns.BACKDROP_THIN)
		frame:SetPoint("TOPLEFT", -1, 1)
		frame:SetPoint("BOTTOMRIGHT", 1, -1)
	end
	frame:SetBackdropBorderColor(r or 1, g or 1, b or 1, a or 1)
end

---------------------------------------------------------------------------
-- movable anchor helper (green box while unlocked)
---------------------------------------------------------------------------
function ns:MakeMovable(frame, label, onMoved)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	local mover = CreateFrame("Frame", nil, frame)
	mover:SetAllPoints()
	mover:SetFrameStrata("DIALOG")
	mover:SetBackdrop({ bgFile = ns.WHITE, edgeFile = ns.WHITE, edgeSize = 1 })
	mover:SetBackdropColor(0.2, 0.8, 0.4, 0.25)
	mover:SetBackdropBorderColor(0.2, 0.8, 0.4, 1)
	mover:EnableMouse(true)
	mover:RegisterForDrag("LeftButton")
	mover.text = mover:CreateFontString(nil, "OVERLAY")
	mover.text:SetFont(ns.FONTS[1][2], 12, "OUTLINE")
	mover.text:SetPoint("BOTTOM", mover, "TOP", 0, 4)
	mover.text:SetText(label .. " – " .. ns.L["drag to move"])
	mover:SetScript("OnDragStart", function()
		if InCombatLockdown() then return end
		frame:StartMoving()
	end)
	mover:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		local p, _, rp, x, y = frame:GetPoint()
		onMoved({ p, "UIParent", rp, x, y })
	end)
	mover:Hide()
	frame.mover = mover
	return mover
end

function ns:SetPointFromTable(frame, p)
	frame:ClearAllPoints()
	frame:SetPoint(p[1], UIParent, p[3], p[4], p[5])
end
