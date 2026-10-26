-- BetterPlates - Plates
-- 3.3.5a-Namensplaketten sind namenlose Kinder des WorldFrame ohne Unit-Token.
-- Wir finden sie per Scan, verstecken die Blizzard-Optik und zeichnen eigene
-- Elemente. Infos (Reaktion, Klasse, Ziel, Leben, Zauber) werden aus den
-- Blizzard-Elementen gelesen.

local ADDON, ns = ...
if type(ns) ~= "table" then BetterPlatesNS = BetterPlatesNS or {} ns = BetterPlatesNS ADDON = "BetterPlates" end
local Plates = {}
ns.Plates = Plates

local WorldFrame = WorldFrame
local CreateFrame = CreateFrame
local UnitExists, UnitName, UnitGUID = UnitExists, UnitName, UnitGUID
local UnitCastingInfo, UnitChannelInfo, GetTime = UnitCastingInfo, UnitChannelInfo, GetTime
local pairs, ipairs, select, type, tostring, pcall, next = pairs, ipairs, select, type, tostring, pcall, next
local floor, max, min, abs, format, sort = math.floor, math.max, math.min, math.abs, string.format, table.sort
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local WHITE = "Interface\\Buttons\\WHITE8X8"
local CLASS_TEX = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local BORDER_BACKDROP = { edgeFile = WHITE, edgeSize = 1 }
local BORDER_THICK = { edgeFile = WHITE, edgeSize = 2 }
local BORDER_GLOW = { edgeFile = WHITE, edgeSize = 3 }
local FLAT_BACKDROP = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 }
local FLAG_TEX = { ALLIANCE = "Interface\\WorldStateFrame\\AllianceFlag", HORDE = "Interface\\WorldStateFrame\\HordeFlag", NEUTRAL = "Interface\\Icons\\INV_BannerPVP_03" }
local TRINKET_TEX = "Interface\\Icons\\INV_Jewelry_TrinketPVP_01"

local all, visible = {}, {}
Plates.all, Plates.visible = all, visible

local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

-- Platzhalter für Elemente, die wir nicht finden (verhindert nil-Fehler)
local dummyTex = hiddenParent:CreateTexture()
dummyTex:Hide()
local dummyFont = hiddenParent:CreateFontString()
dummyFont:Hide()

----------------------------------------------------------------
-- Erkennung
----------------------------------------------------------------
local function TexPath(region)
	if not region or region:GetObjectType() ~= "Texture" then return "" end
	local t = region:GetTexture()
	return type(t) == "string" and t:lower() or ""
end

-- Erkennung wie bei TidyPlates: 2. Region ist die Rahmen-Textur
local function IsNamePlate(f)
	if f:GetName() then return false end
	local _, border = f:GetRegions()
	return TexPath(border):find("nameplate%-border") ~= nil
end

local function AsTexture(r)
	if r and r:GetObjectType() == "Texture" then return r end
end

local function GetParts(f)
	local p = {}
	p.hp, p.cb = f:GetChildren()

	local regions = { f:GetRegions() }

	-- Feste Reihenfolge des 3.3.5a-Clients (im Spiel per /bbp debug bestätigt):
	-- 1 Bedrohungs-Glow, 2 Rahmen, 3 Zauberrahmen (Textur dynamisch!), 4 Schild,
	-- 5 Zaubericon (Textur dynamisch), 6 Mouseover-Glow, 7 Name, 8 Level,
	-- 9 Boss-Totenkopf, 10 Raid-Symbol, 11 Elite-Drache.
	local function Font(r) if r and r:GetObjectType() == "FontString" then return r end end
	if #regions >= 11 and TexPath(regions[2]):find("nameplate%-border") and Font(regions[7]) and Font(regions[8]) then
		p.glow = AsTexture(regions[1])
		p.border = AsTexture(regions[2])
		p.cbborder = AsTexture(regions[3])
		p.shield = AsTexture(regions[4])
		p.icon = AsTexture(regions[5])
		p.highlight = AsTexture(regions[6])
		p.name = regions[7]
		p.level = regions[8]
		p.boss = AsTexture(regions[9])
		p.raid = AsTexture(regions[10])
		p.elite = AsTexture(regions[11])
	else
		-- Unbekannte Struktur: nach Texturpfad raten, erste Treffer behalten
		local fonts, unknown = {}, {}
		for i = 1, #regions do
			local r = regions[i]
			if r:GetObjectType() == "FontString" then
				fonts[#fonts + 1] = r
			else
				local t = TexPath(r)
				if t:find("ui%-targetingframe%-flash") and not p.glow then p.glow = r
				elseif t:find("nameplate%-border") and not p.border then p.border = r
				elseif t:find("nameplate%-castbar%-shield") and not p.shield then p.shield = r
				elseif t:find("nameplate%-glow") and not p.highlight then p.highlight = r
				elseif t:find("ui%-targetingframe%-skull") and not p.boss then p.boss = r
				elseif t:find("ui%-raidtargetingicons") and not p.raid then p.raid = r
				elseif t:find("elitenameplateicon") and not p.elite then p.elite = r
				else unknown[#unknown + 1] = r end
			end
		end
		p.name = fonts[1]
		p.level = fonts[2]
		p.cbborder = unknown[1]
		p.icon = unknown[2]
	end

	p.name = p.name or dummyFont
	p.level = p.level or dummyFont
	for _, key in ipairs({ "glow", "border", "cbborder", "shield", "icon", "highlight", "boss", "raid", "elite" }) do
		p[key] = p[key] or dummyTex
	end

	if not p.hp or p.hp:GetObjectType() ~= "StatusBar" then
		p.hp = CreateFrame("StatusBar", nil, hiddenParent)
		p.hpMissing = true
	end
	if not p.cb or p.cb:GetObjectType() ~= "StatusBar" then
		p.cb = CreateFrame("StatusBar", nil, hiddenParent)
	end
	return p
end

-- Blizzard-Elemente unsichtbar machen, aber lesbar lassen (IsShown, GetText ...).
local EMPTY = ns.MEDIA .. "empty"

local function KillTexture(r)
	r:SetTexCoord(0, 0, 0, 0)
	r:SetVertexColor(0, 0, 0, 0)
	r:SetAlpha(0)
	r:Hide()
end

local function Neutralize(p)
	for _, key in ipairs({ "glow", "shield", "cbborder", "icon", "highlight", "boss", "elite" }) do
		local r = p[key]
		if r ~= dummyTex then r:SetTexCoord(0, 0, 0, 0) end
	end
	if p.border ~= dummyTex then KillTexture(p.border) end
	if p.name ~= dummyFont then p.name:Hide() p.name:SetAlpha(0) end
	if p.level ~= dummyFont then p.level:Hide() p.level:SetAlpha(0) end
	p.hp:SetStatusBarTexture(EMPTY)
	p.hp:SetAlpha(0)
	local t = p.hp:GetStatusBarTexture()
	if t then t:SetAlpha(0) end
	p.cb:SetStatusBarTexture(EMPTY)
	p.cb:SetAlpha(0)
end

-- Blizzard setzt beim Anzeigen manches zurück: nochmal nachziehen
local function ReNeutralize(p)
	if p.name:IsShown() then p.name:Hide() end
	if p.name:GetAlpha() > 0 then p.name:SetAlpha(0) end
	if p.level:IsShown() then p.level:Hide() end
	if p.level:GetAlpha() > 0 then p.level:SetAlpha(0) end
	if p.border ~= dummyTex and (p.border:IsShown() or p.border:GetAlpha() > 0) then KillTexture(p.border) end
	if p.hp:GetAlpha() > 0 then p.hp:SetAlpha(0) end
	local t = p.hp:GetStatusBarTexture()
	if t and (t:GetAlpha() > 0 or t:GetTexture() ~= EMPTY) then
		p.hp:SetStatusBarTexture(EMPTY)
		t = p.hp:GetStatusBarTexture()
		if t then t:SetAlpha(0) end
	end
end

----------------------------------------------------------------
-- Stil-Hilfen
----------------------------------------------------------------
function ns.GetTexture()
	local db = ns.db
	if db.customTexture and db.customTexture ~= "" then return db.customTexture end
	return (ns.textures[db.texture] or ns.textures[1])[2]
end

function ns.GetFont()
	local db = ns.db
	if db.customFont and db.customFont ~= "" then return db.customFont end
	return (ns.fonts[db.font] or ns.fonts[1])[2]
end

local function Color(key)
	local c = ns.db.colors and ns.db.colors[key]
	if c then return c[1], c[2], c[3] end
	return 1, 1, 1
end
ns.Color = Color

local function NewBorder(parent, target)
	local b = CreateFrame("Frame", nil, parent)
	b:SetPoint("TOPLEFT", target, "TOPLEFT", -1, 1)
	b:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 1, -1)
	b:SetBackdrop(BORDER_BACKDROP)
	b:SetBackdropBorderColor(0, 0, 0, 1)
	b.style = 2
	return b
end

-- Rahmenstil umschalten (1 keiner, 2 dünn, 3 dick, 4 Glow)
local function SetBorderStyle(b, target, style)
	if b.style == style then return end
	b.style = style
	b:ClearAllPoints()
	if style == 1 then
		b:SetBackdrop(BORDER_BACKDROP)
		b:SetPoint("TOPLEFT", target, "TOPLEFT", -1, 1)
		b:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 1, -1)
		b:SetAlpha(0)
		return
	end
	b:SetAlpha(1)
	if style == 3 then
		b:SetBackdrop(BORDER_THICK)
		b:SetPoint("TOPLEFT", target, "TOPLEFT", -2, 2)
		b:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 2, -2)
	elseif style == 4 then
		b:SetBackdrop(BORDER_GLOW)
		b:SetPoint("TOPLEFT", target, "TOPLEFT", -3, 3)
		b:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 3, -3)
	else
		b:SetBackdrop(BORDER_BACKDROP)
		b:SetPoint("TOPLEFT", target, "TOPLEFT", -1, 1)
		b:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 1, -1)
	end
end

local function NewFont(parent)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
	return fs
end

local function SetFont(fs, font, size, outline, shadow)
	if size < 6 then size = 6 end
	fs:SetFont(font, size, outline and "OUTLINE" or "")
	if shadow == nil then shadow = ns.db.fontShadow end
	if shadow and not outline then
		fs:SetShadowColor(0, 0, 0, 1)
		fs:SetShadowOffset(1, -1)
	else
		fs:SetShadowOffset(0, 0)
	end
end

-- Rahmenfarbe nur setzen, wenn sie sich ändert (läuft jeden Tick)
local function BorderColor(b, r, g, bl, a)
	a = a or 1
	if b.cr == r and b.cg == g and b.cb == bl and b.ca == a then return end
	b.cr, b.cg, b.cb, b.ca = r, g, bl, a
	b:SetBackdropBorderColor(r, g, bl, a)
end

-- Alles hängt am eigenen Lebensbalken, also wandert der Versatz dorthin
local function SetStackOffset(d, y)
	if d.stackY == y then return end
	d.stackY = y
	d.hb:ClearAllPoints()
	d.hb:SetPoint("CENTER", d.hbAnchor, "CENTER", 0, y)
end

----------------------------------------------------------------
-- Aufbau der eigenen Elemente
----------------------------------------------------------------
local function CreateUI(d)
	local f, p = d.frame, d.parts

	local ui = CreateFrame("Frame", nil, f)
	ui:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	ui:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	d.ui = ui
	d.stackY = 0
	d.stackTarget = 0

	-- Lebensbalken, genau an der Stelle des Blizzard-Balkens
	local hb = CreateFrame("StatusBar", nil, ui)
	d.hbAnchor = p.hpMissing and ui or p.hp
	hb:SetPoint("CENTER", d.hbAnchor, "CENTER", 0, 0)
	hb:SetStatusBarTexture(WHITE)
	hb:SetMinMaxValues(0, 1)
	hb:SetValue(1)
	hb.bg = hb:CreateTexture(nil, "BACKGROUND")
	hb.bg:SetAllPoints(hb)
	hb.border = NewBorder(hb, hb)
	-- Glow für Ziel / Raid-NPCs / Flaggenträger (größerer, halbtransparenter Rahmen)
	hb.glow = CreateFrame("Frame", nil, hb)
	hb.glow:SetPoint("TOPLEFT", hb, "TOPLEFT", -4, 4)
	hb.glow:SetPoint("BOTTOMRIGHT", hb, "BOTTOMRIGHT", 4, -4)
	hb.glow:SetBackdrop(BORDER_GLOW)
	hb.glow:SetFrameLevel(hb:GetFrameLevel())
	hb.glow:Hide()
	d.hb = hb

	local over = CreateFrame("Frame", nil, hb)
	over:SetAllPoints(hb)
	over:SetFrameLevel(hb:GetFrameLevel() + 5)
	d.over = over

	d.nameText = NewFont(over)
	d.nameText:SetPoint("BOTTOM", hb, "TOP", 0, 3)

	d.healthText = NewFont(over)
	d.healthText:SetPoint("CENTER", hb, "CENTER", 0, 0)

	d.execTick = over:CreateTexture(nil, "OVERLAY")
	d.execTick:SetTexture(WHITE)
	d.execTick:SetVertexColor(1, 1, 1, 0.9)
	d.execTick:SetWidth(1)
	d.execTick:Hide()

	-- Ziel-Pfeile
	d.arrowL = over:CreateTexture(nil, "OVERLAY")
	d.arrowL:SetTexture(ns.MEDIA .. "arrow")
	d.arrowL:Hide()
	d.arrowR = over:CreateTexture(nil, "OVERLAY")
	d.arrowR:SetTexture(ns.MEDIA .. "arrow")
	d.arrowR:SetTexCoord(1, 0, 0, 1)
	d.arrowR:Hide()

	-- Klassen- und Heiler-Icon
	d.classIcon = over:CreateTexture(nil, "ARTWORK")
	d.classIcon:SetTexture(CLASS_TEX)
	d.classIcon:Hide()

	d.healerIcon = over:CreateTexture(nil, "ARTWORK")
	d.healerIcon:SetTexture(ns.MEDIA .. "healer")
	d.healerIcon:SetPoint("RIGHT", d.nameText, "LEFT", -2, 0)
	d.healerIcon:Hide()

	-- PvP-Schmuck benutzt (Arena): kleines Icon rechts vom Namen mit Restzeit
	d.trinketIcon = over:CreateTexture(nil, "ARTWORK")
	d.trinketIcon:SetTexture(TRINKET_TEX)
	d.trinketIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	d.trinketIcon:SetPoint("LEFT", d.nameText, "RIGHT", 2, 0)
	d.trinketIcon:Hide()
	d.trinketText = NewFont(over)
	d.trinketText:SetPoint("LEFT", d.trinketIcon, "RIGHT", 1, 0)
	d.trinketText:Hide()

	-- Party-Pfeil (zeigt nach unten auf den Mitspieler)
	d.partyArrow = over:CreateTexture(nil, "ARTWORK")
	d.partyArrow:SetTexture(ns.MEDIA .. "arrow")
	d.partyArrow:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
	d.partyArrow:Hide()

	-- Flaggen-Icon (Schlachtfeld)
	d.flagIcon = over:CreateTexture(nil, "ARTWORK")
	d.flagIcon:SetWidth(22)
	d.flagIcon:SetHeight(22)
	d.flagIcon:Hide()

	-- Totem-Icon
	local tf = CreateFrame("Frame", nil, ui)
	tf:SetFrameLevel(over:GetFrameLevel())
	tf.bg = tf:CreateTexture(nil, "BACKGROUND")
	tf.bg:SetAllPoints(tf)
	tf.icon = tf:CreateTexture(nil, "ARTWORK")
	tf.icon:SetPoint("TOPLEFT", tf, "TOPLEFT", 2, -2)
	tf.icon:SetPoint("BOTTOMRIGHT", tf, "BOTTOMRIGHT", -2, 2)
	tf.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	tf.cd = CreateFrame("Cooldown", nil, tf, "CooldownFrameTemplate")
	tf.cd:SetAllPoints(tf.icon)
	if tf.cd.SetReverse then tf.cd:SetReverse(true) end
	tf.cd.noCooldownCount = true
	local tfo = CreateFrame("Frame", nil, tf)
	tfo:SetAllPoints(tf)
	tfo:SetFrameLevel(tf:GetFrameLevel() + 5)
	tf.time = NewFont(tfo)
	tf.time:SetPoint("CENTER", tf, "CENTER", 0, 0)
	tf:Hide()
	d.totemFrame = tf

	-- "Wird anvisiert von": kleine Quadrate in Gruppenfarben / Zahl
	local tb = CreateFrame("Frame", nil, ui)
	tb:SetFrameLevel(over:GetFrameLevel())
	tb:SetWidth(1)
	tb:SetHeight(8)
	tb.squares = {}
	tb.text = NewFont(tb)
	tb.text:SetPoint("LEFT", tb, "LEFT", 0, 0)
	tb:Hide()
	d.targetedFrame = tb

	-- Zauberleiste
	local cast = CreateFrame("StatusBar", nil, ui)
	cast:SetPoint("TOPLEFT", hb, "BOTTOMLEFT", 0, -3)
	cast:SetPoint("TOPRIGHT", hb, "BOTTOMRIGHT", 0, -3)
	cast:SetStatusBarTexture(WHITE)
	cast.bg = cast:CreateTexture(nil, "BACKGROUND")
	cast.bg:SetAllPoints(cast)
	cast.border = NewBorder(cast, cast)
	local co = CreateFrame("Frame", nil, cast)
	co:SetAllPoints(cast)
	co:SetFrameLevel(cast:GetFrameLevel() + 5)
	cast.time = NewFont(co)
	cast.time:SetPoint("RIGHT", cast, "RIGHT", -2, 0)
	cast.text = NewFont(co)
	cast.text:SetPoint("LEFT", cast, "LEFT", 2, 0)
	cast.text:SetPoint("RIGHT", cast.time, "LEFT", -2, 0)
	cast.text:SetJustifyH("LEFT")

	local iconFrame = CreateFrame("Frame", nil, cast)
	iconFrame:SetPoint("TOPRIGHT", hb, "TOPLEFT", -3, 1)
	iconFrame.bg = iconFrame:CreateTexture(nil, "BACKGROUND")
	iconFrame.bg:SetAllPoints(iconFrame)
	iconFrame.bg:SetTexture(0, 0, 0, 1)
	cast.icon = iconFrame:CreateTexture(nil, "ARTWORK")
	cast.icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
	cast.icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
	cast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	cast.iconFrame = iconFrame

	-- Unterbrechungs-Icon (grün = bereit, rot = Cooldown)
	local kick = CreateFrame("Frame", nil, cast)
	kick:SetPoint("TOPLEFT", hb, "TOPRIGHT", 3, 1)
	kick:SetBackdrop(FLAT_BACKDROP)
	kick:SetBackdropColor(0, 0, 0, 1)
	kick.icon = kick:CreateTexture(nil, "ARTWORK")
	kick.icon:SetPoint("TOPLEFT", kick, "TOPLEFT", 1, -1)
	kick.icon:SetPoint("BOTTOMRIGHT", kick, "BOTTOMRIGHT", -1, 1)
	kick.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local ko = CreateFrame("Frame", nil, kick)
	ko:SetAllPoints(kick)
	ko:SetFrameLevel(kick:GetFrameLevel() + 5)
	kick.text = NewFont(ko)
	kick.text:SetPoint("CENTER", kick, "CENTER", 0, 0)
	kick:Hide()
	cast.kick = kick
	cast:Hide()
	d.cast = cast

	-- Auren
	d.auraFrame = CreateFrame("Frame", nil, ui)
	d.auraFrame:SetFrameLevel(over:GetFrameLevel() + 1)
	d.auraFrame:SetWidth(1)
	d.auraFrame:SetHeight(1)
	d.auraIcons = {}

	-- Diminishing Returns
	d.drFrame = CreateFrame("Frame", nil, ui)
	d.drFrame:SetFrameLevel(over:GetFrameLevel() + 1)
	d.drFrame:SetWidth(1)
	d.drFrame:SetHeight(1)
	d.drFrame:Hide()
	d.drIcons = {}

	-- Raid-Symbol neben den Balken
	if p.raid ~= dummyTex then
		p.raid:ClearAllPoints()
		p.raid:SetPoint("LEFT", hb, "RIGHT", 4, 0)
	end
end

----------------------------------------------------------------
-- Layout aus den Einstellungen
----------------------------------------------------------------
local function PlateScale(d)
	local db = ns.db
	local s = d.isTarget and db.targetScale or 1
	if d.small then s = s * 0.7 end
	if d.friendlyScaled then s = s * db.friendlyScale end
	if d.bigScale then s = s * d.bigScale end
	return s
end

local function Apply(d)
	local db = ns.db
	local tex = ns.GetTexture()
	local font = ns.GetFont()
	local scale = PlateScale(d)
	local w, h = floor(db.width * scale + 0.5001), floor(db.height * scale + 0.5001)
	d.w, d.h = w, h

	local hb = d.hb
	hb:SetWidth(w)
	hb:SetHeight(h)
	hb:SetStatusBarTexture(tex)
	hb.bg:SetTexture(tex)
	local br, bg, bb = Color("bg")
	if db.bgStyle == 3 then
		hb.bg:SetVertexColor(br, bg, bb, 0)
	else
		hb.bg:SetVertexColor(br, bg, bb, db.bgAlpha)
	end
	d.bgClass = nil
	SetBorderStyle(hb.border, hb, db.borderStyle)
	hb.border.cr = nil

	d.nameBig = nil
	SetFont(d.nameText, font, db.fontSize, db.outline)
	SetFont(d.healthText, font, db.healthFontSize, db.outline)
	SetFont(d.trinketText, font, max(db.fontSize - 2, 7), true)

	-- Name: über dem Balken oder im Balken
	d.nameText:ClearAllPoints()
	if db.nameInBar then
		d.nameText:SetPoint("LEFT", hb, "LEFT", 3 + db.nameX, db.nameY)
		d.nameText:SetJustifyH("LEFT")
	else
		d.nameText:SetPoint("BOTTOM", hb, "TOP", db.nameX, 3 + db.nameY)
		d.nameText:SetJustifyH("CENTER")
	end
	d.healthText:ClearAllPoints()
	if db.healthTextPos == 2 then
		d.healthText:SetPoint("LEFT", hb, "LEFT", 3 + db.healthX, db.healthY)
	elseif db.healthTextPos == 3 then
		d.healthText:SetPoint("RIGHT", hb, "RIGHT", -3 + db.healthX, db.healthY)
	else
		d.healthText:SetPoint("CENTER", hb, "CENTER", db.healthX, db.healthY)
	end

	local cast = d.cast
	cast:ClearAllPoints()
	cast:SetPoint("TOPLEFT", hb, "BOTTOMLEFT", db.castX, -3 + db.castY)
	cast:SetPoint("TOPRIGHT", hb, "BOTTOMRIGHT", db.castX, -3 + db.castY)
	cast:SetHeight(db.castHeight)
	d.castEmph = nil
	cast:SetStatusBarTexture(tex)
	cast.bg:SetTexture(tex)
	cast.bg:SetVertexColor(br, bg, bb, db.bgAlpha)
	SetFont(cast.text, font, max(db.castHeight, 7), true)
	SetFont(cast.time, font, max(db.castHeight, 7), true)
	local iconSize = h + db.castHeight + 5
	cast.iconFrame:SetWidth(iconSize)
	cast.iconFrame:SetHeight(iconSize)
	cast.iconFrame:ClearAllPoints()
	cast.kick:ClearAllPoints()
	if db.castIconSide == 2 then
		cast.iconFrame:SetPoint("TOPLEFT", hb, "TOPRIGHT", 3, 1)
		cast.kick:SetPoint("TOPRIGHT", hb, "TOPLEFT", -3, 1)
	else
		cast.iconFrame:SetPoint("TOPRIGHT", hb, "TOPLEFT", -3, 1)
		cast.kick:SetPoint("TOPLEFT", hb, "TOPRIGHT", 3, 1)
	end
	cast.kick:SetWidth(iconSize)
	cast.kick:SetHeight(iconSize)
	SetFont(cast.kick.text, font, max(floor(iconSize * 0.5), 7), true)
	d.partyArrow:SetWidth(db.fontSize + 10)
	d.partyArrow:SetHeight(db.fontSize + 10)

	local arrow = max(h + 6, 12)
	d.arrowL:SetWidth(arrow)
	d.arrowL:SetHeight(arrow)
	d.arrowR:SetWidth(arrow)
	d.arrowR:SetHeight(arrow)

	d.classIcon:SetWidth(db.classIconSize)
	d.classIcon:SetHeight(db.classIconSize)
	d.healerIcon:SetWidth(db.fontSize + 6)
	d.healerIcon:SetHeight(db.fontSize + 6)
	d.trinketIcon:SetWidth(db.fontSize + 4)
	d.trinketIcon:SetHeight(db.fontSize + 4)
	d.flagIcon:SetWidth(db.fontSize + 14)
	d.flagIcon:SetHeight(db.fontSize + 14)
	d.totemKey = nil
	SetFont(d.totemFrame.time, font, max(floor(db.totemSize * 0.4), 7), true)
	SetFont(d.targetedFrame.text, font, max(db.fontSize - 1, 7), true)

	local raid = d.parts.raid
	if raid ~= dummyTex then
		raid:ClearAllPoints()
		local rs = db.raidIconSize
		if db.raidIconPos == 2 then
			raid:SetPoint("RIGHT", hb, "LEFT", -4 + db.raidX, db.raidY)
		elseif db.raidIconPos == 3 then
			raid:SetPoint("BOTTOM", d.nameText, "TOP", db.raidX, 2 + db.raidY)
		elseif db.raidIconPos == 4 then
			raid:SetPoint("LEFT", hb, "RIGHT", 4, 0)
			rs = 0.01
		else
			raid:SetPoint("LEFT", hb, "RIGHT", 4 + db.raidX, db.raidY)
		end
		raid:SetWidth(rs)
		raid:SetHeight(rs)
	end

	d.execTick:ClearAllPoints()
	d.execX = nil
	d.topKey = nil
	d.nameOnly = nil
	d.classIconClass = nil
	d.totemShown = nil
	d.arrowLeftAnchor, d.arrowRightAnchor = nil, nil
	d.barR = nil
	d.healthStr = nil
	d.glowKey = nil
	d.nameColorKey = nil
end

-- "Nur Namen" für Freunde: Balken unsichtbar, Name bleibt
local function SetNameOnly(d, nameOnly)
	if d.nameOnly == nameOnly then return end
	d.nameOnly = nameOnly
	local a = nameOnly and 0 or 1
	local tex = d.hb:GetStatusBarTexture()
	if tex then tex:SetAlpha(a) end
	d.hb.bg:SetAlpha(a)
	if nameOnly then
		d.hb.border:Hide()
		d.hb.glow:Hide()
		d.glowKey = nil
		d.healthText:Hide()
		d.execTick:Hide()
	else
		d.hb.border:Show()
		d.healthText:Show()
	end
end

-- Glow um den Balken (Ziel, Raid-NPC, Flaggenträger)
local function SetGlow(d, key, r, g, b, a)
	if d.glowKey == key then return end
	d.glowKey = key
	if not key then
		d.hb.glow:Hide()
		return
	end
	d.hb.glow:SetBackdropBorderColor(r, g, b, a or 0.6)
	d.hb.glow:Show()
end

----------------------------------------------------------------
-- Leben
----------------------------------------------------------------
local function Gradient(pct)
	-- grün (100 %) -> gelb (50 %) -> rot (0 %)
	if pct > 50 then
		return 1 - (pct - 50) / 50, 1, 0
	end
	return 1, pct / 50, 0
end
ns.HealthGradient = Gradient

local function UpdateHealth(d)
	local hp = d.parts.hp
	local mn, mx = hp:GetMinMaxValues()
	local v = hp:GetValue() or 0
	mn = mn or 0
	if not mx or mx <= 0 then mx = 1 end
	d.hb:SetMinMaxValues(mn, mx)
	d.hb:SetValue(v)

	local db = ns.db
	local pct = v / mx * 100
	d.pct = pct
	local mode = db.healthText
	local text
	if db.healthTextOnlyTarget and not d.isTarget then
		mode = 1
	end
	if mode > 1 then
		local pctStr
		if db.healthDecimals then
			pctStr = format("%.1f%%", pct)
		else
			pctStr = format("%d%%", floor(pct + 0.5))
		end
		if mode == 2 then
			text = pctStr
		elseif mode == 3 then
			text = ns.ShortValue(v)
		elseif mode == 4 then
			text = ns.ShortValue(v) .. " - " .. pctStr
		elseif mode == 5 then
			text = ns.ShortValue(v) .. " / " .. ns.ShortValue(mx)
		elseif mode == 6 then
			local miss = mx - v
			text = miss > 0 and ("-" .. ns.ShortValue(miss)) or ""
		end
		if d.threatText then text = (text or "") .. d.threatText end
	end
	if text ~= d.healthStr then
		d.healthStr = text
		d.healthText:SetText(text or "")
	end

	local lowExec = false
	if db.execute then
		local x = floor(d.w * db.executePct / 100 + 0.5)
		if d.execX ~= x then
			d.execX = x
			d.execTick:ClearAllPoints()
			d.execTick:SetPoint("TOPLEFT", d.hb, "TOPLEFT", x, 0)
			d.execTick:SetPoint("BOTTOMLEFT", d.hb, "BOTTOMLEFT", x, 0)
		end
		if not d.nameOnly then d.execTick:Show() end
		lowExec = pct <= db.executePct and v > 0
	else
		d.execTick:Hide()
	end
	d.inExecute = lowExec
	if lowExec then
		local r, g, b = Color("execute")
		d.healthText:SetTextColor(r, g, b)
	else
		d.healthText:SetTextColor(1, 1, 1)
	end
end

----------------------------------------------------------------
-- Zauberleiste
----------------------------------------------------------------
local CAST_UNITS = { "target", "focus", "mouseover", "arena1", "arena2", "arena3", "arena4", "arena5" }

-- Eigener Unterbrechungszauber (Name, Icon) je Klasse
local INTERRUPTS = {
	WARRIOR = { 6552, 72 },          -- Zuschlagen, Schildhieb
	ROGUE = { 1766 },                -- Tritt
	MAGE = { 2139 },                 -- Gegenzauber
	SHAMAN = { 57994 },              -- Windstoß
	DEATHKNIGHT = { 47528, 47476 },  -- Gedankenfrost, Strangulieren
	HUNTER = { 34490 },              -- Unterdrückender Schuss
	PRIEST = { 15487 },              -- Stille
	WARLOCK = { 19647 },             -- Zaubersperre (Teufelsjäger)
}
local myKick  -- { name = ..., icon = ... }

function Plates:ResolveInterrupt()
	myKick = nil
	local _, class = UnitClass("player")
	local list = class and INTERRUPTS[class]
	if not list then return end
	local fallback
	for _, id in ipairs(list) do
		local name, _, icon = GetSpellInfo(id)
		if name and GetSpellInfo(name) then
			local usable = IsUsableSpell and IsUsableSpell(name)
			if usable then
				myKick = { name = name, icon = icon }
				return
			end
			fallback = fallback or { name = name, icon = icon }
		end
	end
	myKick = fallback
end

local function UpdateKick(d, interruptible)
	local kick = d.cast.kick
	if not ns.db.castInterruptIcon or not myKick or not interruptible then
		if kick:IsShown() then kick:Hide() end
		return
	end
	if kick.iconPath ~= myKick.icon then
		kick.iconPath = myKick.icon
		kick.icon:SetTexture(myKick.icon)
	end
	local start, dur = GetSpellCooldown(myKick.name)
	local rem = (start and start > 0 and dur and dur > 1.5) and (start + dur - GetTime()) or 0
	local ready = rem <= 0
	if kick.ready ~= ready then
		kick.ready = ready
		if ready then
			kick:SetBackdropBorderColor(0.2, 1, 0.2, 1)
			kick.icon:SetVertexColor(1, 1, 1)
			kick.text:SetText("")
		else
			kick:SetBackdropBorderColor(1, 0.2, 0.2, 1)
			kick.icon:SetVertexColor(0.5, 0.5, 0.5)
		end
	end
	if not ready and ns.db.kickCdText then
		local txt = format("%d", rem + 0.99)
		if kick.cdText ~= txt then
			kick.cdText = txt
			kick.text:SetText(txt)
		end
	elseif kick.cdText then
		kick.cdText = nil
		kick.text:SetText("")
	end
	if not kick:IsShown() then kick:Show() end
end

local function LookupCast(d)
	for i = 1, #CAST_UNITS do
		local u = CAST_UNITS[i]
		local guid = UnitGUID(u)
		if guid and ((d.guid and guid == d.guid) or (u == "target" and d.isTarget)) then
			local name = UnitCastingInfo(u)
			if name then return name, false end
			name = UnitChannelInfo(u)
			if name then return name, true end
		end
	end
end

local function CastTimerText(c, rem, total)
	local f = ns.db.castTimerFormat
	if rem < 0 then rem = 0 end
	if f == 2 then
		c.time:SetFormattedText("%.1f / %.1f", rem, total)
	elseif f == 3 then
		c.time:SetFormattedText("%d%%", total > 0 and (100 - rem / total * 100) or 0)
	else
		c.time:SetFormattedText("%.1f", rem)
	end
end

local function CastName(name)
	local maxLen = ns.db.castNameMaxLen
	if maxLen and maxLen > 0 and #name > maxLen then
		return name:sub(1, maxLen - 1) .. "…"
	end
	return name
end

-- Hervorgehobene Zauber: roter Balken, etwas höher
local function CastEmphasis(d, on)
	on = on and true or false
	if d.castEmph == on then return end
	d.castEmph = on
	local h = ns.db.castHeight
	d.cast:SetHeight(on and floor(h * 1.5 + 0.5) or h)
	if on then
		local r, g, b = Color("castEmph")
		d.cast.border:SetBackdropBorderColor(r, g, b, 1)
	end
end

-- "Unterbrochen (von X)" kurz einblenden
local function CastInterrupted(d, by)
	local c = d.cast
	c:SetMinMaxValues(0, 1)
	c:SetValue(1)
	c:SetStatusBarColor(Color("castInterrupted"))
	c.border:SetBackdropBorderColor(0, 0, 0, 1)
	c.time:SetText("")
	local L = ns.L
	if by and by ~= "" then
		c.text:SetFormattedText("%s: %s", L["Interrupted"], by)
	else
		c.text:SetText(L["Interrupted"])
	end
	d.cast.kick:Hide()
	d.castState = -1
end

local function CastColors(d, state)
	local c = d.cast
	if state == 1 or state == 11 then
		c:SetStatusBarColor(Color("castNoInt"))
		c.border:SetBackdropBorderColor(0.85, 0.85, 0.85, 1)
	elseif d.castEmph then
		local r, g, b = Color("castEmph")
		c:SetStatusBarColor(r, g, b)
		c.border:SetBackdropBorderColor(r, g, b, 1)
	else
		if state == 2 then
			c:SetStatusBarColor(Color("castChannel"))
		else
			c:SetStatusBarColor(Color("castNormal"))
		end
		c.border:SetBackdropBorderColor(0, 0, 0, 1)
	end
end

local function CastUpdate(d)
	local c, bc, db = d.cast, d.parts.cb, ns.db
	local mn, mx = bc:GetMinMaxValues()
	local v = bc:GetValue()
	if not mx or not v then return end
	mn = mn or 0
	c:SetMinMaxValues(mn, mx)
	c:SetValue(v)

	-- Kanalisierungen laufen rückwärts
	if d.castLast and v ~= d.castLast then
		d.castChannel = v < d.castLast
	end
	d.castLast = v

	local now = GetTime()
	if db.castName and not d.castSpell and (not d.castLookupAt or now - d.castLookupAt > 0.25) then
		d.castLookupAt = now
		local name, channel = LookupCast(d)
		if name then
			d.castSpell = name
			if d.castChannel == nil then d.castChannel = channel end
			c.text:SetText(CastName(name))
			if ns.castHide[name] then
				d.castHidden = true
				c:Hide()
				c.kick:Hide()
				return
			end
			CastEmphasis(d, ns.castEmphasis[name])
			if ns.castEmphasis[name] and db.castSound then ns.PlayAlert(db.castSoundId) end
		end
	end
	if d.castHidden then return end

	if db.castTimer then
		local rem = d.castChannel and (v - mn) or (mx - v)
		CastTimerText(c, rem, mx - mn)
	else
		c.time:SetText("")
	end

	UpdateKick(d, not d.parts.shield:IsShown())

	-- Farbe nur setzen, wenn sich der Zustand ändert (läuft jeden Frame)
	local state = d.parts.shield:IsShown() and 1 or (d.castChannel and 2 or 3)
	if d.castEmph then state = state + 10 end
	if d.castState ~= state then
		d.castState = state
		CastColors(d, state)
	end

	local tex = d.parts.icon:GetTexture()
	if tex ~= d.castTex then
		d.castTex = tex
		c.icon:SetTexture(tex)
	end
end

local cleuActive = {}

local function CastShow(d)
	d.castBlizz = true
	d.castCleu = nil
	cleuActive[d] = nil
	if d.isTarget then ns.Casts:Learn("target") end
	d.parts.cb:SetAlpha(0)
	d.parts.cb:SetStatusBarTexture(EMPTY)
	-- Blizzard setzt beim Zauberstart Texturen auf Icon und Zauberrahmen
	for _, key in ipairs({ "icon", "cbborder", "shield" }) do
		local r = d.parts[key]
		if r ~= dummyTex then r:SetTexCoord(0, 0, 0, 0) end
	end
	if not ns.db.castbar then
		d.cast:Hide()
		return
	end
	d.castLast, d.castChannel, d.castSpell, d.castTex, d.castState, d.castLookupAt = nil, nil, nil, nil, nil, nil
	d.castHidden = nil
	d.cast.text:SetText("")
	CastEmphasis(d, false)
	if ns.db.castIcon then d.cast.iconFrame:Show() else d.cast.iconFrame:Hide() end
	d.cast:Show()
	CastUpdate(d)
end

----------------------------------------------------------------
-- Zustand pro Tick
----------------------------------------------------------------
local tgtExists, tgtName, tgtGUID
local moExists, moName, moGUID
local targetPlate, targetGUID
local focusPlate, focusName, focusGUID
local partyIndex = {}   -- [Name] = 1..4
local PARTY_COLORS = { { 1, 0.35, 0.35 }, { 0.35, 1, 0.35 }, { 0.35, 0.6, 1 }, { 1, 1, 0.35 } }
local arenaNums = {}
local targetedBy = {}   -- [GUID] = Anzahl Gruppenmitglieder, die diese Einheit anvisieren
local targetedIdx = {}  -- [GUID] = { partyIdx, ... } (max 4, nur in der Gruppe)
local arenaAim = {}     -- [Arena-GUID] = "me" | partyIdx (Gegner zielt auf ...)
local lastTargeted = 0
local raidThreatText

local function GatherTargeted(now)
	if now - lastTargeted < 0.25 then return end
	lastTargeted = now
	wipe(targetedBy)
	for k, t in pairs(targetedIdx) do wipe(t) end
	wipe(arenaAim)
	local db = ns.db
	if not db.targetedBy and not db.enemyTargetIndicator then return end
	local nraid = GetNumRaidMembers()
	if db.targetedBy then
		if nraid > 0 then
			for i = 1, nraid do
				local g = UnitGUID("raid" .. i .. "target")
				if g then targetedBy[g] = (targetedBy[g] or 0) + 1 end
			end
		else
			for i = 1, 4 do
				local g = UnitGUID("party" .. i .. "target")
				if g then
					targetedBy[g] = (targetedBy[g] or 0) + 1
					local t = targetedIdx[g]
					if not t then t = {} targetedIdx[g] = t end
					t[#t + 1] = i
				end
			end
		end
	end
	if db.enemyTargetIndicator and ns.instanceType == "arena" then
		local me = ns.playerGUID
		for i = 1, 5 do
			local ag = UnitGUID("arena" .. i)
			if ag then
				local tg = UnitGUID("arena" .. i .. "target")
				if tg then
					if tg == me then
						arenaAim[ag] = "me"
					else
						for p = 1, 4 do
							if UnitGUID("party" .. p) == tg then arenaAim[ag] = p break end
						end
					end
				end
			end
		end
	end
end

local function GatherState()
	tgtExists = UnitExists("target")
	tgtName = tgtExists and UnitName("target")
	tgtGUID = tgtExists and UnitGUID("target")
	moExists = UnitExists("mouseover")
	moName = moExists and UnitName("mouseover")
	moGUID = moExists and UnitGUID("mouseover")

	wipe(arenaNums)
	if ns.instanceType == "arena" then
		for i = 1, 5 do
			local n = UnitName("arena" .. i)
			if n and n ~= UNKNOWNOBJECT then arenaNums[n] = i end
		end
	end

	-- Ziel-Plakette eindeutig bestimmen (gleichnamige Einheiten: warten, bis
	-- Blizzard die Nicht-Ziele abgeblendet hat)
	local prev = targetPlate
	targetPlate = nil
	if tgtExists then
		local candidate, count = nil, 0
		for _, d in pairs(visible) do
			if d.name == tgtName and d.frame:GetAlpha() > 0.99 then
				count = count + 1
				candidate = d
			end
		end
		if count == 1 then
			targetPlate = candidate
		elseif count > 1 and tgtGUID == targetGUID then
			if prev and visible[prev.frame] and prev.name == tgtName and prev.frame:GetAlpha() > 0.99 then
				targetPlate = prev
			end
		end
	end
	targetGUID = targetPlate and tgtGUID or nil
	if tgtGUID then
		for _, d in pairs(visible) do
			if d.guid == tgtGUID and d ~= targetPlate then d.guid = nil end
		end
	end

	-- Fokus: per Name, eindeutig und nicht die Ziel-Plakette
	focusPlate = nil
	focusName = UnitExists("focus") and UnitName("focus") or nil
	focusGUID = focusName and UnitGUID("focus") or nil
	if focusName and focusGUID ~= tgtGUID then
		local candidate, count = nil, 0
		for _, d in pairs(visible) do
			if d.name == focusName and d ~= targetPlate then
				count = count + 1
				candidate = d
			end
		end
		if count == 1 then focusPlate = candidate end
	end

	-- Gruppenmitglieder (für Party-Pfeile)
	wipe(partyIndex)
	if GetNumRaidMembers() == 0 then
		for i = 1, 4 do
			local n = UnitName("party" .. i)
			if n and n ~= UNKNOWNOBJECT then partyIndex[n] = i end
		end
	end

	-- Bedrohung am Ziel (genau, nur für das Ziel möglich)
	raidThreatText = nil
	if ns.db.threatMode > 1 and ns.db.threatPercent and tgtExists and UnitDetailedThreatSituation then
		local ok, isTanking, status, pct = pcall(UnitDetailedThreatSituation, "player", "target")
		if ok and pct and pct > 0 then raidThreatText = format(" %d%%", pct) end
	end

	GatherTargeted(GetTime())
end

local function Classify(r, g, b)
	if not r then return "OTHER" end
	if r > 0.9 and g < 0.15 and b < 0.15 then return "HOSTILE" end
	if r > 0.9 and g > 0.9 and b < 0.15 then return "NEUTRAL" end
	if r < 0.15 and g > 0.9 and b < 0.15 then return "FRIENDLY" end
	if r < 0.15 and g < 0.15 and b > 0.9 then return "FRIENDLY_PLAYER" end
	local class = ns.ClassFromColor(r, g, b)
	if class then return "ENEMY_PLAYER", class end
	return "OTHER"
end

-- Level-Text: Farbe (Schwierigkeit), Elite-/Rare-Kennzeichen, Boss
local function LevelString(d, p, isPlayer)
	local db = ns.db
	if p.boss:IsShown() then return "|cffff3333??|r" end
	local lvl = p.level:GetText()
	if not lvl or lvl == "" then return end
	if isPlayer and db.hideLevelMaxPlayers and lvl == tostring(MAX_PLAYER_LEVEL or 80) then return end
	if not isPlayer and db.eliteMark and p.elite:IsShown() then lvl = lvl .. "+" end
	if db.levelColor then
		local r, g, b = p.level:GetTextColor()
		return format("|cff%02x%02x%02x%s|r", (r or 1) * 255, (g or 1) * 255, (b or 1) * 255, lvl)
	end
	return lvl
end

-- Graue Level = triviale Gegner
local function IsTrivial(p)
	local r, g, b = p.level:GetTextColor()
	if not r then return false end
	return abs(r - g) < 0.05 and abs(g - b) < 0.05 and r > 0.4 and r < 0.7
end

local MURLOC = { "Mrglglgl", "Mrrrglglgl", "Rwlrwlrwl", "Aaaughibbrgubugbugrguburgle", "Mrglrgl" }

-- Anzeigename aufbereiten
local function DisplayName(d)
	local db = ns.db
	local name = d.name or ""
	if db.murlocMode and not d.isPlayer then
		local sum = 0
		for i = 1, #name do sum = sum + name:byte(i) end
		return MURLOC[(sum % #MURLOC) + 1]
	end
	if db.stripRealm then
		local dash = name:find("-", 1, true)
		if dash and dash > 1 then name = name:sub(1, dash - 1) end
	end
	if db.abbrevNames and not d.isPlayer and name:find(" ", 1, true) then
		-- Alle Wörter außer dem letzten abkürzen: "Lord Marrowgar" -> "L. Marrowgar"
		local words = {}
		for w in name:gmatch("%S+") do words[#words + 1] = w end
		if #words > 1 then
			local out = {}
			for i = 1, #words - 1 do
				local w = words[i]
				-- Artikel/Präpositionen überspringen
				if #w > 3 then out[#out + 1] = w:sub(1, 1) .. "." end
			end
			out[#out + 1] = words[#words]
			name = table.concat(out, " ")
		end
	end
	if db.nameMaxLen and db.nameMaxLen > 0 and #name > db.nameMaxLen then
		name = name:sub(1, db.nameMaxLen - 1) .. "…"
	end
	return name
end

local function NewUnit(d, name)
	d.name = name
	d.guid = nil
	if d.castCleu then
		d.castCleu = nil
		cleuActive[d] = nil
		if not d.castBlizz then d.cast:Hide() end
	end
	d.class = nil
	d.isPlayer = nil
	d.reaction = nil
	d.nameStr = nil
	d.nameKey = nil
	d.totem = ns.TotemInfo(name)
	d.nameLower = name and name:lower() or nil
	d.raidPrio = d.nameLower and ns.raidNpc and ns.raidNpc[d.nameLower] or nil
	d.healthStr = nil
	d.threatText = nil
	d.ui:SetAlpha(1)
	d.uiAlpha = 1
	d.testRaidPrio = nil
	d.flagShown = nil
	local small = (d.totem and d.totem.pet and ns.db.smallPets) and true or false
	if d.isTarget or small ~= d.small or d.friendlyScaled or d.bigScale then
		d.friendlyScaled = false
		d.isTarget = false
		d.small = small
		d.bigScale = nil
		Apply(d)
	end
end

-- Elemente über dem Namen stapeln: Party-Pfeil, Klassen-Icon, Totem, DR, Auren
local function LayoutTop(d, showClass, showTotem, showParty, showFlag, showDR)
	local db = ns.db
	local key = (showClass and 1 or 0) + (showTotem and 2 or 0) + (showParty and 4 or 0) + (showFlag and 8 or 0) + (showDR and 16 or 0)
	if key == d.topKey then return end
	d.topKey = key

	local anchor = db.nameInBar and d.hb or d.nameText
	if showParty then
		d.partyArrow:ClearAllPoints()
		d.partyArrow:SetPoint("BOTTOM", anchor, "TOP", db.partyX, db.partyY)
		anchor = d.partyArrow
	end
	if showFlag then
		d.flagIcon:ClearAllPoints()
		d.flagIcon:SetPoint("BOTTOM", anchor, "TOP", 0, 1)
		anchor = d.flagIcon
	end
	if showClass then
		d.classIcon:ClearAllPoints()
		d.classIcon:SetPoint("BOTTOM", anchor, "TOP", db.classIconX, 2 + db.classIconY)
		anchor = d.classIcon
	end
	if showTotem then
		d.totemFrame:ClearAllPoints()
		d.totemFrame:SetPoint("BOTTOM", anchor, "TOP", db.totemX, 2 + db.totemY)
		anchor = d.totemFrame
	end
	if showDR then
		d.drFrame:ClearAllPoints()
		d.drFrame:SetPoint("BOTTOM", anchor, "TOP", db.drX, 2 + db.drY)
		d.drFrame:SetHeight(db.drSize + 10)
		anchor = d.drFrame
	end
	d.auraFrame:ClearAllPoints()
	d.auraFrame:SetPoint("BOTTOM", anchor, "TOP", db.aurasX, 2 + db.aurasY)
end

-- Zauberleiste aus dem Kampflog (für alle Plaketten außer dem Ziel, das Blizzard liefert)
local function CleuCastFrame(d, now)
	local c = d.castCleu
	local cast = d.cast
	if c.interruptedAt then
		if d.castState ~= -1 then CastInterrupted(d, c.interruptedBy) end
		return
	end
	UpdateKick(d, true)
	local elapsed = now - c.start
	if elapsed > c.duration then elapsed = c.duration end
	if c.channel then
		cast:SetValue(c.duration - elapsed)
	else
		cast:SetValue(elapsed)
	end
	if ns.db.castTimer then CastTimerText(cast, c.duration - elapsed, c.duration) end
end

local function CleuCastStart(d, c, now)
	local cast = d.cast
	d.castCleu = c
	cleuActive[d] = true
	cast:SetMinMaxValues(0, c.duration)
	cast.text:SetText(ns.db.castName and CastName(c.name) or "")
	if not ns.db.castTimer then cast.time:SetText("") end
	if ns.db.castIcon then
		cast.icon:SetTexture(c.icon)
		cast.iconFrame:Show()
	else
		cast.iconFrame:Hide()
	end
	CastEmphasis(d, c.emphasis)
	CastColors(d, c.channel and 2 or 3)
	d.castState = nil
	cast:Show()
	CleuCastFrame(d, now)
end

local function CleuCastStop(d)
	d.castCleu = nil
	cleuActive[d] = nil
	if not d.castBlizz then d.cast:Hide() d.cast.kick:Hide() end
end

local function CleuCastCheck(d, now)
	local db = ns.db
	if d.castBlizz or not db.castbar or not d.guid then
		if d.castCleu then CleuCastStop(d) end
		return
	end
	local c = ns.Casts.store[d.guid]
	if c and c.interruptedAt and not db.castInterrupted then c = nil end
	if c and (c.interruptedAt or now <= c.start + c.duration) then
		if d.castCleu ~= c then CleuCastStart(d, c, now) end
	elseif d.castCleu then
		CleuCastStop(d)
	end
end

----------------------------------------------------------------
-- Bedrohung aus dem Blizzard-Glow
----------------------------------------------------------------
-- Rückgabe: nil (kein Glow), "aggro" (rot), "warn" (orange/gelb)
local function GlowState(p)
	if not p.glow:IsShown() then return nil end
	local r, g, b = p.glow:GetVertexColor()
	if not r then return nil end
	if r > 0.9 and g < 0.25 then return "aggro" end
	return "warn"
end

----------------------------------------------------------------
-- "Wird anvisiert von"
----------------------------------------------------------------
local function UpdateTargeted(d, reaction)
	local db = ns.db
	local tb = d.targetedFrame
	local n = db.targetedBy and d.guid and (reaction == "HOSTILE" or reaction == "NEUTRAL" or reaction == "ENEMY_PLAYER") and targetedBy[d.guid] or 0
	local aim = db.enemyTargetIndicator and d.guid and arenaAim[d.guid]
	if n == 0 and not aim then
		if tb:IsShown() then tb:Hide() end
		return
	end
	local idx = d.guid and targetedIdx[d.guid]
	local text = ""
	local key
	if aim == "me" then
		text = "|cffff3333" .. ns.L["YOU"] .. "|r"
		key = "me"
	elseif aim then
		local c = PARTY_COLORS[aim]
		text = format("|cff%02x%02x%02x%d|r", c[1] * 255, c[2] * 255, c[3] * 255, aim)
		key = "p" .. aim
	end
	local shownSquares = 0
	if n > 0 then
		if db.targetedByStyle == 2 or not idx or #idx == 0 then
			text = (text ~= "" and (text .. " ") or "") .. format("|cffffffff%d|r", n)
			key = (key or "") .. "n" .. n
		else
			key = (key or "") .. "s" .. table.concat(idx, "")
			for i = 1, #idx do
				local sq = tb.squares[i]
				if not sq then
					sq = tb:CreateTexture(nil, "ARTWORK")
					sq:SetTexture(WHITE)
					sq:SetWidth(7)
					sq:SetHeight(7)
					sq:SetPoint("LEFT", tb, "LEFT", (i - 1) * 9, 0)
					tb.squares[i] = sq
				end
				local c = PARTY_COLORS[idx[i]]
				sq:SetVertexColor(c[1], c[2], c[3], 1)
				sq:Show()
				shownSquares = i
			end
		end
	end
	for i = shownSquares + 1, #tb.squares do tb.squares[i]:Hide() end
	if tb.key ~= key then
		tb.key = key
		tb.text:ClearAllPoints()
		tb.text:SetPoint("LEFT", tb, "LEFT", shownSquares * 9, 0)
		tb.text:SetText(text)
	end
	if not tb:IsShown() then
		tb:ClearAllPoints()
		tb:SetPoint("LEFT", d.hb, "RIGHT", 4 + (d.parts.raid:IsShown() and db.raidIconPos == 1 and db.raidIconSize + 4 or 0) + db.targetedX, db.targetedY)
		tb:Show()
	end
end

----------------------------------------------------------------
-- Totem-Timer
----------------------------------------------------------------
local function UpdateTotemTimer(d, t)
	local tf = d.totemFrame
	local summons = ns.totemSummons
	local s = summons and d.name and summons[d.name]
	local now = GetTime()
	if ns.db.totemTimers and s and s.expires > now then
		if tf.cdKey ~= s.expires then
			tf.cdKey = s.expires
			tf.cd:SetCooldown(s.expires - s.duration, s.duration)
			tf.cd:Show()
		end
		local rem = s.expires - now
		local txt = rem >= 60 and format("%dm", rem / 60) or format("%d", rem)
		if tf.timeStr ~= txt then
			tf.timeStr = txt
			tf.time:SetText(txt)
		end
	elseif tf.cdKey then
		tf.cdKey = nil
		tf.timeStr = nil
		tf.cd:Hide()
		tf.time:SetText("")
	end
end

----------------------------------------------------------------
-- Hauptaktualisierung je Plakette (0,1 s)
----------------------------------------------------------------
local function UpdatePlate(d)
	local p, db = d.parts, ns.db
	ReNeutralize(p)
	local now = GetTime()
	CleuCastCheck(d, now)

	local name = p.name:GetText()
	if name ~= d.name then NewUnit(d, name) end

	-- Reaktion & Klasse aus der Balkenfarbe
	local r, g, b = p.hp:GetStatusBarColor()
	local reaction, class = Classify(r, g, b)
	if reaction == "HOSTILE" and d.name and (ns.guidByName[d.name] or ns.classCache[d.name]) then
		reaction = "ENEMY_PLAYER"
	end
	d.reaction = reaction
	d.isPlayer = reaction == "ENEMY_PLAYER" or reaction == "FRIENDLY_PLAYER"
	if class and d.name then ns.classCache[d.name] = class end
	if d.isPlayer then
		d.class = class or (d.name and ns.classCache[d.name])
	else
		d.class = nil
	end
	local enemy = reaction == "HOSTILE" or reaction == "NEUTRAL" or reaction == "ENEMY_PLAYER"
	local friendly = reaction == "FRIENDLY_PLAYER" or reaction == "FRIENDLY"
	local friendlyPlayer = reaction == "FRIENDLY_PLAYER"

	-- Ziel / Mouseover (Blizzard dimmt Nicht-Ziele, das Ziel hat Alpha 1)
	local isTarget = (d == targetPlate)
	if isTarget ~= d.isTarget then
		d.isTarget = isTarget
		Apply(d)
	end
	if isTarget then d.guid = tgtGUID end
	local isMouse = moExists and d.name == moName and p.highlight:IsShown()
	if isMouse and moGUID then
		for _, o in pairs(visible) do
			if o ~= d and o.guid == moGUID then o.guid = nil end
		end
		d.guid = moGUID
	end
	if d.isPlayer and not d.guid and d.name then d.guid = ns.guidByName[d.name] end
	local isFocus = (d == focusPlate)
	if isFocus and focusGUID and not d.guid then d.guid = focusGUID end

	-- Größenfaktoren: Freunde kleiner, Bosse / wichtige Raid-NPCs / Flaggenträger größer
	local fScaled = (friendlyPlayer and db.friendlyScale < 1 and not d.isTarget) and true or false
	local raidPrio = d.testRaidPrio or (db.raidNpcHighlight and enemy and d.raidPrio) or nil
	local flag = db.flagCarrier and d.guid and ns.flagCarriers and ns.flagCarriers[d.guid] or nil
	local isBoss = p.boss:IsShown()
	local trivial = not d.isPlayer and db.trivialMode > 1 and IsTrivial(p)
	local big = nil
	if db.bossBig and isBoss then big = 1.2 end
	if raidPrio == 1 then big = max(big or 1, 1.15) end
	if flag then big = max(big or 1, 1.2) end
	if trivial and db.trivialMode == 3 then big = 0.7 end
	if fScaled ~= (d.friendlyScaled or false) or big ~= d.bigScale then
		d.friendlyScaled = fScaled
		d.bigScale = big
		Apply(d)
	end

	-- Bedrohung
	local threat = nil
	if db.threatMode > 1 and (reaction == "HOSTILE" or reaction == "NEUTRAL") then
		local gs = GlowState(p)
		if db.threatMode == 3 then
			-- Tank: Aggro ist gut
			if gs == "aggro" then threat = "safe" elseif gs == "warn" then threat = "warn" end
		else
			if gs == "aggro" then threat = "aggro" elseif gs == "warn" then threat = "warn" end
		end
	end
	d.threatText = (isTarget and raidThreatText) or nil

	UpdateHealth(d)

	-- Balkenfarbe
	local cr, cg, cb
	if reaction == "FRIENDLY_PLAYER" then
		if db.classColorFriendly and d.class then
			local c = RAID_CLASS_COLORS[d.class]
			cr, cg, cb = c.r, c.g, c.b
		else
			cr, cg, cb = Color("friendlyPlayer")
		end
	elseif reaction == "ENEMY_PLAYER" then
		if db.classColorEnemy and d.class then
			local c = RAID_CLASS_COLORS[d.class]
			cr, cg, cb = c.r, c.g, c.b
		else
			cr, cg, cb = Color("enemyPlayer")
		end
	elseif reaction == "HOSTILE" then
		cr, cg, cb = Color("hostile")
	elseif reaction == "NEUTRAL" then
		cr, cg, cb = Color("neutral")
	elseif reaction == "FRIENDLY" then
		cr, cg, cb = Color("friendlyNpc")
	else
		cr, cg, cb = r or 1, g or 0, b or 0
	end
	if db.healthGradient and not d.isPlayer and d.pct then
		cr, cg, cb = Gradient(d.pct)
	end
	if threat then
		if threat == "aggro" then cr, cg, cb = Color("threatAggro")
		elseif threat == "warn" then cr, cg, cb = Color("threatWarn")
		else cr, cg, cb = Color("threatSafe") end
	elseif db.threatColor and (reaction == "HOSTILE" or reaction == "NEUTRAL") and p.glow:IsShown() then
		cr, cg, cb = p.glow:GetVertexColor()
	end
	if not d.isPlayer and d.nameLower then
		local nc = ns.colorNpc[d.nameLower]
		if nc then cr, cg, cb = nc[1], nc[2], nc[3] end
	end
	if db.executeColor and d.inExecute and enemy then
		cr, cg, cb = Color("execute")
	end
	if db.colorByAura and d.guid then
		local cat = ns.Auras:TopCategory(d.guid)
		local ac = cat and ns.AURA_COLORS[cat]
		if ac then cr, cg, cb = ac[1], ac[2], ac[3] end
	end
	if db.lowHealthFlash and friendlyPlayer and d.pct and d.pct <= db.lowHealthPct and d.pct > 0 then
		-- Blinken: halbe Sekunde rot, halbe Sekunde normal
		if floor(now * 2) % 2 == 0 then cr, cg, cb = Color("lowHealth") end
	end
	if d.barR ~= cr or d.barG ~= cg or d.barB ~= cb then
		d.barR, d.barG, d.barB = cr, cg, cb
		d.hb:SetStatusBarColor(cr, cg, cb)
		if db.bgStyle == 2 then
			d.hb.bg:SetVertexColor(cr * 0.25, cg * 0.25, cb * 0.25, db.bgAlpha)
		end
	end

	-- Freunde: nur Namen / nur Gruppe
	local inPvP = ns.instanceType == "pvp" or ns.instanceType == "arena"
	local nameOnlyWanted = db.friendlyNameOnly or (db.friendlyNameOnlyPvP and inPvP)
	local nameOnly = (nameOnlyWanted and friendly and not d.isTarget) and true or false
	SetNameOnly(d, nameOnly)
	local iconOnly = nameOnly and db.friendlyClassIconOnly and d.class and true or false

	-- Name (+ Level) bzw. Arena-Nummer
	local arenaNum = db.arenaNumbers and d.name and arenaNums[d.name]
	local text
	if arenaNum then
		text = tostring(arenaNum)
	elseif iconOnly or db.hideName then
		text = ""
	else
		text = DisplayName(d)
		if not db.hideLevel and not nameOnly then
			local lvl = LevelString(d, p, d.isPlayer)
			if lvl then text = lvl .. " " .. text end
		end
	end
	if db.hideNameOnCast and d.cast:IsShown() and not arenaNum then text = "" end
	if text ~= d.nameStr then
		d.nameStr = text
		d.nameText:SetText(text)
	end
	local bigName = (arenaNum and true or false) or (isBoss and db.bossBig)
	if bigName ~= d.nameBig then
		d.nameBig = bigName
		SetFont(d.nameText, ns.GetFont(), bigName and db.fontSize + (arenaNum and 6 or 2) or db.fontSize, db.outline)
	end
	-- Namensfarbe
	local nr, ng, nb = 1, 1, 1
	if db.nameReactionColor and d.isPlayer then
		if friendlyPlayer then nr, ng, nb = 0.3, 1, 0.3 else nr, ng, nb = 1, 0.3, 0.3 end
	elseif (db.nameClassColor or nameOnly) and d.class then
		local c = RAID_CLASS_COLORS[d.class]
		nr, ng, nb = c.r, c.g, c.b
	elseif nameOnly then
		nr, ng, nb = cr, cg, cb
	end
	if d.nameR ~= nr or d.nameG ~= ng or d.nameB ~= nb then
		d.nameR, d.nameG, d.nameB = nr, ng, nb
		d.nameText:SetTextColor(nr, ng, nb)
	end

	-- Klassen-Icon
	local showClass = d.class and (iconOnly or (reaction == "ENEMY_PLAYER" and db.classIconEnemy)
		or (reaction == "FRIENDLY_PLAYER" and db.classIconFriendly)) and true or false
	if showClass then
		local c = ns.CLASS_COORDS[d.class]
		if c then
			if d.classIconClass ~= d.class then
				d.classIconClass = d.class
				d.classIcon:SetTexCoord(c[1], c[2], c[3], c[4])
			end
			d.classIcon:Show()
		else
			showClass = false
			d.classIcon:Hide()
		end
	else
		d.classIcon:Hide()
	end

	-- Heiler
	local isHealer = d.isPlayer and d.name and ns.healers[d.name]
	if db.healerIndicator and isHealer then
		d.healerIcon:Show()
	else
		d.healerIcon:Hide()
	end

	-- PvP-Schmuck
	local trinket = db.trinketIndicator and d.guid and ns.trinkets and ns.trinkets[d.guid]
	if trinket and trinket.ready > now and reaction == "ENEMY_PLAYER" then
		local rem = trinket.ready - now
		local txt = rem >= 60 and format("%d:%02d", rem / 60, rem % 60) or format("%d", rem)
		if d.trinketStr ~= txt then
			d.trinketStr = txt
			d.trinketText:SetText(txt)
		end
		if not d.trinketIcon:IsShown() then
			d.trinketIcon:Show()
			d.trinketText:Show()
		end
	elseif d.trinketIcon:IsShown() then
		d.trinketIcon:Hide()
		d.trinketText:Hide()
		d.trinketStr = nil
	end

	-- Totems: wichtige feindliche groß mit Farbrahmen, alle anderen kleiner mit schwarzem Rahmen
	local t = d.totem
	local enemyNpc = reaction == "HOSTILE" or reaction == "NEUTRAL"
	local important = t and t.important and enemyNpc
	local showTotem = (t and db.totemIndicator and (important or db.allTotemIcons)) and true or false
	if showTotem then
		local key = important and 1 or 2
		if d.totemShown ~= t or d.totemKey ~= key then
			d.totemShown, d.totemKey = t, key
			d.totemFrame.icon:SetTexture(t.icon)
			if important then
				d.totemFrame.bg:SetTexture(t.r, t.g, t.b, 1)
			else
				d.totemFrame.bg:SetTexture(0, 0, 0, 1)
			end
			local size = important and db.totemSize or floor(db.totemSize * 0.7 + 0.5)
			d.totemFrame:SetWidth(size)
			d.totemFrame:SetHeight(size)
		end
		UpdateTotemTimer(d, t)
		d.totemFrame:Show()
	else
		d.totemFrame:Hide()
	end

	-- Flaggenträger
	if flag then
		if d.flagShown ~= flag then
			d.flagShown = flag
			d.flagIcon:SetTexture(FLAG_TEX[flag] or FLAG_TEX.ALLIANCE)
		end
		d.flagIcon:Show()
	else
		d.flagShown = nil
		d.flagIcon:Hide()
	end

	-- Sichtbarkeit der eigenen Elemente
	local alpha = 1
	if t and db.hideOtherTotems and not important then
		alpha = 0
	elseif not d.isPlayer and d.nameLower and not d.isTarget then
		if ns.hideNpc[d.nameLower] then alpha = 0
		elseif ns.fadeNpc[d.nameLower] then alpha = 0.3
		elseif trivial and db.trivialMode == 4 then alpha = 0
		elseif trivial and db.trivialMode == 2 then alpha = 0.4
		elseif db.hideCritters and ns.critters and ns.critters[d.nameLower] then alpha = 0 end
	elseif friendlyPlayer and db.friendlyOnlyGroup and not d.isTarget and d.name and not (ns.groupNames and ns.groupNames[d.name]) then
		alpha = 0
	end
	if alpha == 1 and db.healerPriority and inPvP and reaction == "ENEMY_PLAYER" and not isHealer and not d.isTarget then
		alpha = 0.55
	end
	if alpha == 1 and db.nonTargetAlpha < 1 and tgtExists and not d.isTarget then
		alpha = db.nonTargetAlpha
	end
	if d.uiAlpha ~= alpha then
		d.uiAlpha = alpha
		d.ui:SetAlpha(alpha)
	end

	-- Party-Pfeil
	local pidx = db.partyPointer and reaction == "FRIENDLY_PLAYER" and d.name and partyIndex[d.name]
	if pidx then
		if d.partyIdx ~= pidx then
			d.partyIdx = pidx
			local c = PARTY_COLORS[pidx]
			d.partyArrow:SetVertexColor(c[1], c[2], c[3])
		end
		d.partyArrow:Show()
	else
		d.partyArrow:Hide()
	end

	-- Diminishing Returns
	local drN = ns.DR and ns.DR:UpdatePlate(d) or 0

	LayoutTop(d, showClass, showTotem, pidx and true or false, flag and true or false, drN > 0)

	-- Rahmen: Ziel / Fokus / Mouseover / Freund / Raid-NPC
	local border = d.hb.border
	if nameOnly then
		-- kein Rahmen ohne Balken
	elseif d.isTarget and db.targetBorder and db.targetStyle ~= 2 then
		BorderColor(border, Color("target"))
	elseif isFocus and db.focusIndicator then
		BorderColor(border, Color("focus"))
	elseif isMouse and db.mouseoverHighlight then
		BorderColor(border, Color("mouseover"))
	elseif raidPrio then
		BorderColor(border, Color(raidPrio == 1 and "raidNpc1" or "raidNpc2"))
	elseif friendlyPlayer and db.friendlyBorder then
		BorderColor(border, Color("friendBorder"))
	else
		BorderColor(border, Color("border"))
	end

	-- Glow
	if nameOnly then
		SetGlow(d, nil)
	elseif d.isTarget and db.targetStyle >= 2 then
		local gr, gg, gb = Color("target")
		SetGlow(d, "target", gr, gg, gb, 0.7)
	elseif flag then
		local gr, gg, gb
		if flag == "HORDE" then gr, gg, gb = Color("flagHorde")
		elseif flag == "ALLIANCE" then gr, gg, gb = Color("flagAlliance")
		else gr, gg, gb = 1, 0.85, 0.1 end
		SetGlow(d, "flag" .. flag, gr, gg, gb, 0.8)
	elseif raidPrio == 1 then
		local gr, gg, gb = Color("raidNpc1")
		SetGlow(d, "raid1", gr, gg, gb, 0.6)
	else
		SetGlow(d, nil)
	end

	if d.isTarget and db.targetArrows then
		local left = (d.cast:IsShown() and d.cast.iconFrame:IsShown() and db.castIconSide == 1) and d.cast.iconFrame or d.hb
		local right = (p.raid:IsShown() and p.raid ~= dummyTex and db.raidIconPos == 1) and p.raid or d.hb
		if d.arrowLeftAnchor ~= left then
			d.arrowLeftAnchor = left
			d.arrowL:ClearAllPoints()
			d.arrowL:SetPoint("RIGHT", left, "LEFT", -2, 0)
		end
		if d.arrowRightAnchor ~= right then
			d.arrowRightAnchor = right
			d.arrowR:ClearAllPoints()
			d.arrowR:SetPoint("LEFT", right, "RIGHT", 2, 0)
		end
		if not d.arrowsShown then
			d.arrowsShown = true
			d.arrowL:Show()
			d.arrowR:Show()
		end
	elseif d.arrowsShown then
		d.arrowsShown = false
		d.arrowL:Hide()
		d.arrowR:Hide()
	end

	UpdateTargeted(d, reaction)
	ns.Auras:UpdatePlate(d)
end

----------------------------------------------------------------
-- Fehlerschutz: ein Fehler an einer Plakette darf nicht alle anderen stoppen.
-- Jede Fehlermeldung wird einmal im Chat gezeigt, der Rest unter /bbp errors.
----------------------------------------------------------------
local errors, errorCount = {}, 0
Plates.errors = errors
local function Report(where, err)
	err = tostring(err)
	local key = where .. ": " .. err
	errorCount = errorCount + 1
	if not errors[key] then
		errors[key] = 1
		errors[#errors + 1] = key
		if #errors <= 3 then
			ns:Print("|cffff5555Error|r (" .. where .. "): " .. err .. "  -  /bbp errors")
		end
	else
		errors[key] = errors[key] + 1
	end
end
local function SafeUpdate(d)
	local ok, err = pcall(UpdatePlate, d)
	if not ok then Report("UpdatePlate " .. tostring(d.name), err) end
end
function Plates:Errors()
	if #errors == 0 then ns:Print("No errors recorded.") return end
	ns:Print(format("%d errors (%d distinct):", errorCount, #errors))
	for i = 1, math.min(#errors, 10) do ns:Print("  " .. errors[errors[i]] .. "x " .. errors[i]) end
end

----------------------------------------------------------------
-- Anzeigen / Verstecken
----------------------------------------------------------------
local function PlateShow(d)
	visible[d.frame] = d
	ReNeutralize(d.parts)
	NewUnit(d, d.parts.name:GetText())
	SafeUpdate(d)
	if d.parts.cb:IsShown() then
		CastShow(d)
	else
		d.cast:Hide()
	end
end

local function PlateHide(d)
	visible[d.frame] = nil
	d.castCleu = nil
	d.castBlizz = false
	cleuActive[d] = nil
	d.stackTarget = 0
	SetStackOffset(d, 0)
	d.cast:Hide()
	d.guid = nil
	d.name = nil
	d.nameStr = nil
end

local function SetupPlate(f)
	local d = { frame = f, parts = GetParts(f) }
	all[f] = d
	local p = d.parts

	CreateUI(d)

	Neutralize(p)
	p.hp:HookScript("OnValueChanged", function() if visible[f] then UpdateHealth(d) end end)
	p.hp:HookScript("OnMinMaxChanged", function() if visible[f] then UpdateHealth(d) end end)

	p.cb:HookScript("OnShow", function()
		local ok, err = pcall(CastShow, d)
		if not ok then Report("CastShow", err) end
	end)
	p.cb:HookScript("OnHide", function() d.castBlizz = false d.cast:Hide() d.cast.kick:Hide() end)
	p.cb:HookScript("OnValueChanged", function()
		if d.cast:IsShown() then
			local ok, err = pcall(CastUpdate, d)
			if not ok then Report("CastUpdate", err) end
		end
	end)

	f:HookScript("OnShow", function() PlateShow(d) end)
	f:HookScript("OnHide", function() PlateHide(d) end)

	Apply(d)
	if f:IsShown() then PlateShow(d) end
end

local function ScanChildren(...)
	for i = 1, select("#", ...) do
		local f = select(i, ...)
		if not all[f] and IsNamePlate(f) then
			SetupPlate(f)
		end
	end
end

----------------------------------------------------------------
-- Öffentlich
----------------------------------------------------------------
function Plates:RefreshAll()
	GatherState()
	for f, d in pairs(all) do
		Apply(d)
		d.nameStr = nil
		d.execX = nil
		for i = 1, #d.auraIcons do d.auraIcons[i].size = nil end
		for i = 1, #d.drIcons do d.drIcons[i].size = nil end
		if visible[f] then
			SafeUpdate(d)
			if d.parts.cb:IsShown() then CastShow(d) else d.cast:Hide() end
		end
	end
	if ns.Minimap then ns.Minimap:Update() end
end

function Plates:TargetPlate() return targetPlate end

-- /bbp debug: zeigt, was der Client liefert und welche Addons mitlaufen
function Plates:Debug()
	local n, v = 0, 0
	for _ in pairs(all) do n = n + 1 end
	for _ in pairs(visible) do v = v + 1 end
	ns:Print(format("Plaketten erkannt: %d, sichtbar: %d, WorldFrame-Kinder: %d", n, v, WorldFrame:GetNumChildren()))

	local any
	for f, d in pairs(visible) do any = d break end
	if not any then
		for f, d in pairs(all) do any = d break end
	end
	if any then
		local f = any.frame
		ns:Print(format("Beispiel-Plakette: %d Kinder, Regionen:", select("#", f:GetChildren())))
		local regions = { f:GetRegions() }
		for i, r in ipairs(regions) do
			local info
			if r:GetObjectType() == "Texture" then
				info = tostring(r:GetTexture())
			else
				info = "Text=" .. tostring(r:GetText())
			end
			ns:Print(format("  %d %s %s %s", i, r:GetObjectType(), r:IsShown() and "an" or "aus", info))
		end
		ns:Print(format("  Name=%s Level=%s Ziel=%s Klasse=%s Reaktion=%s GUID=%s", tostring(any.name), tostring(any.parts.level:GetText()),
			tostring(any.isTarget), tostring(any.class), tostring(any.reaction), tostring(any.guid)))
		local p = any.parts
		local hpt = p.hp:GetStatusBarTexture()
		local r, g, b = p.hp:GetStatusBarColor()
		ns:Print(format("  Blizzard-HP: alpha=%.2f tex=%s texalpha=%s farbe=%.2f/%.2f/%.2f groesse=%dx%d",
			p.hp:GetAlpha(), hpt and tostring(hpt:GetTexture()) or "?", hpt and format("%.2f", hpt:GetAlpha()) or "?",
			r or 0, g or 0, b or 0, p.hp:GetWidth() or 0, p.hp:GetHeight() or 0))
		ns:Print(format("  Blizzard-Name: shown=%s alpha=%.2f  Rahmen: shown=%s alpha=%.2f  Plakette: alpha=%.2f groesse=%dx%d",
			tostring(p.name:IsShown()), p.name:GetAlpha(), tostring(p.border:IsShown()), p.border:GetAlpha(),
			any.frame:GetAlpha(), any.frame:GetWidth() or 0, any.frame:GetHeight() or 0))
		ns:Print(format("  Stapeln=%s n=%s off=%.1f/%.1f max=%.1f err=%s", tostring(ns.db.stacking), tostring(Plates.lastStackN),
			any.stackY or 0, any.stackTarget or 0, Plates.lastStackMax or 0, tostring(Plates.stackErrMsg)))
		local mr, mg, mb = any.hb:GetStatusBarColor()
		ns:Print(format("  Eigener Balken: farbe=%.2f/%.2f/%.2f groesse=%dx%d text=%s",
			mr or 0, mg or 0, mb or 0, any.hb:GetWidth() or 0, any.hb:GetHeight() or 0, tostring(any.nameText:GetText())))
	end
	ns:Print(format("Profil=%s Zone=%s Instanz=%s", tostring(ns.Profiles and ns.Profiles.name), tostring(ns.Profiles and ns.Profiles.activeZone), tostring(ns.instanceType)))

	local list = {}
	for i = 1, GetNumAddOns() do
		local name, _, _, enabled = GetAddOnInfo(i)
		if enabled and name ~= ADDON and (IsAddOnLoaded(i) or IsAddOnLoaded(name)) then
			list[#list + 1] = name
		end
	end
	ns:Print("Geladene Addons: " .. table.concat(list, ", "))
end

local KNOWN_PLATE_ADDONS = { "tidyplates", "aloft", "kuinameplates", "elvui", "tukui", "ncnameplates", "dnameplates",
	"nameplate", "threatplates", "caelnameplates", "ouf_nameplates", "rnameplates", "bnameplates", "sxnameplates" }

function Plates:WarnOthers()
	for i = 1, GetNumAddOns() do
		local name, _, _, enabled = GetAddOnInfo(i)
		if enabled and name ~= ADDON and IsAddOnLoaded(i) then
			local lower = name:lower()
			for _, pat in ipairs(KNOWN_PLATE_ADDONS) do
				if lower:find(pat, 1, true) and lower ~= "platebuffs" then
					ns:Print("|cffff5555Warning:|r addon \"" .. name .. "\" also modifies nameplates. Please disable it, otherwise both draw on top of each other.")
					break
				end
			end
		end
	end
end

----------------------------------------------------------------
-- Stapeln: 3.3.5a kennt kein Stapeln, die Engine setzt die Plaketten
-- überlappend. Die Rahmen selbst lassen sich nicht verschieben, aber unsere
-- Anzeige hängt als Kind daran und kann nach oben ausweichen.
----------------------------------------------------------------
local items = {}

local function ContentBox(d)
	local db = ns.db
	local w = d.w + 24
	local h = d.h + db.fontSize + 10
	if d.classIcon:IsShown() then h = h + db.classIconSize + 2 end
	if d.totemFrame:IsShown() then h = h + db.totemSize + 2 end
	if d.drFrame:IsShown() then h = h + db.drSize + 10 end
	if d.auraFrame:IsShown() then h = h + (db.auraSize + 2) * (db.auraRows or 1) end
	local below = 0
	if d.cast:IsShown() then below = db.castHeight + 4 end
	return w, h, below
end

local function StackSort(a, b)
	if a.target ~= b.target then return a.target end
	if a.y ~= b.y then return a.y < b.y end
	return a.x < b.x
end

local function Stack(elapsed)
	local db = ns.db
	local GAP = db.stackSpacing or 2
	local MAXH = db.stackMaxHeight or 200
	local n = 0
	for _, d in pairs(visible) do
		local f = d.frame
		local left, bottom = f:GetLeft(), f:GetBottom()
		local fw, fh = f:GetWidth(), f:GetHeight()
		local hpBottom = d.parts.hp:GetBottom()
		if left and bottom and fw and fh and d.w then
			local w, h, below = ContentBox(d)
			local barCenter = hpBottom and (hpBottom + (d.parts.hp:GetHeight() or 0) / 2) or (bottom + fh / 2)
			n = n + 1
			local it = items[n]
			if not it then it = {} items[n] = it end
			it.d = d
			it.x = left + fw / 2
			it.y = barCenter - d.h / 2 - below
			it.w = w
			it.h = h + below
			it.target = d.isTarget
			it.off = 0
		end
	end
	for i = n + 1, #items do items[i] = nil end
	sort(items, StackSort)
	Plates.lastStackN = n
	Plates.lastStackMax = 0

	for i = 1, n do
		local it = items[i]
		local off = 0
		if not it.target then
			local moved, guard = true, 0
			while moved and guard < 25 do
				moved, guard = false, guard + 1
				local y0 = it.y + off
				for j = 1, i - 1 do
					local o = items[j]
					if abs(o.x - it.x) < (o.w + it.w) / 2 then
						local oy0, oy1 = o.y + o.off, o.y + o.off + o.h
						if y0 < oy1 + GAP and y0 + it.h > oy0 - GAP then
							off = oy1 + GAP - it.y
							moved = true
							break
						end
					end
				end
			end
			if off > MAXH then off = MAXH end
		end
		it.off = off
		local cur = it.d.stackTarget or 0
		if off == 0 or abs(off - cur) > 3 then
			it.d.stackTarget = off
		else
			it.off = cur
		end
		if off > Plates.lastStackMax then Plates.lastStackMax = off end
	end

	local k = min(1, elapsed * 10)
	for i = 1, n do
		local d = items[i].d
		local cur = d.stackY
		local tgt = d.stackTarget
		local new = cur + (tgt - cur) * k
		if abs(new - tgt) < 1 then new = tgt end
		SetStackOffset(d, floor(new + 0.5))
	end
end

-- /bbp plates: alle sichtbaren Plaketten mit Zustand
function Plates:DebugPlates()
	local n = 0
	for f, d in pairs(visible) do
		n = n + 1
		if n <= 14 then
			local r, g, b = d.parts.hp:GetStatusBarColor()
			local hbTex = d.hb:GetStatusBarTexture()
			ns:Print(format("%s | %s | f=%.2f ui=%.2f hb=%s/%.2f %dx%d tex=%.2f | blizz %.2f/%.2f/%.2f hp=%s | st=%.0f | %s",
				tostring(d.name), tostring(d.reaction), f:GetAlpha(), d.ui:GetAlpha(), tostring(d.hb:IsShown()), d.hb:GetAlpha(),
				d.hb:GetWidth() or 0, d.hb:GetHeight() or 0, hbTex and hbTex:GetAlpha() or -1, r or 0, g or 0, b or 0,
				tostring(d.parts.hp:IsShown()), d.stackY or 0, d.hb:GetLeft() and format("x=%.0f y=%.0f", d.hb:GetLeft(), d.hb:GetBottom()) or "keine Position"))
		end
	end
	ns:Print("Sichtbare Plaketten: " .. n)
end

function Plates:DebugStack()
	ns:Print(format("Stapel-Elemente: %d (max %.1f, err=%s)", #items, Plates.lastStackMax or 0, tostring(Plates.stackErrMsg)))
	for i = 1, min(#items, 8) do
		local it = items[i]
		ns:Print(format("  %d %s x=%.0f y=%.0f w=%.0f h=%.0f off=%.1f cur=%.1f", i, tostring(it.d.name), it.x, it.y, it.w, it.h, it.off or 0, it.d.stackY or 0))
	end
end

----------------------------------------------------------------
-- Testmodus: /bbp test  - spielt auf der Ziel-Plakette alles durch
----------------------------------------------------------------
local testFrame
function Plates:Test()
	local d = targetPlate
	local guid = UnitGUID("target")
	local name = UnitName("target")
	local L = ns.L
	if not d or not guid then
		ns:Print(L["Test: target something with a nameplate first."])
		return
	end
	if testFrame and testFrame:IsShown() then
		ns:Print(L["Test already running."])
		return
	end
	d.guid = guid
	local me, meName = ns.playerGUID or "0x0", UnitName("player")
	local other, otherName = "0xF130000000000001", "Tester"
	local HOSTILE_PLAYER, FRIENDLY_PLAYER = 0x548, 0x511
	local function Cleu(event, src, srcName, srcFlags, dst, dstName, dstFlags, ...)
		ns:Fire("COMBAT_LOG_EVENT_UNFILTERED", GetTime(), event, src, srcName, srcFlags, dst, dstName, dstFlags, ...)
	end
	local wasHealer = ns.healers[name]
	local wasFlag = ns.flagCarriers and ns.flagCarriers[guid]
	local wasTrinket = ns.trinkets and ns.trinkets[guid]
	local steps = {
		{ 0, function()
			ns:Print(format(L["Test on %s: cast (emphasized), CC aura, own DoT, healer mark"], tostring(name)))
			Cleu("SPELL_CAST_START", guid, name, HOSTILE_PLAYER, nil, nil, 0, 116, (GetSpellInfo(116)), 16)
			local c = ns.Casts.store[guid]
			if c then c.duration = 6 c.emphasis = true end
			Cleu("SPELL_AURA_APPLIED", other, otherName, HOSTILE_PLAYER, guid, name, HOSTILE_PLAYER, 118, (GetSpellInfo(118)), 64, "DEBUFF")
			Cleu("SPELL_AURA_APPLIED", me, meName, FRIENDLY_PLAYER, guid, name, HOSTILE_PLAYER, 589, (GetSpellInfo(589)), 32, "DEBUFF")
			ns.healers[name] = true
		end },
		{ 3, function()
			ns:Print(L["Test: interrupt -> red 'Interrupted: Tester', then lockout aura (blue)"])
			Cleu("SPELL_INTERRUPT", other, otherName, HOSTILE_PLAYER, guid, name, HOSTILE_PLAYER, 2139, (GetSpellInfo(2139)), 0, 116, (GetSpellInfo(116)))
		end },
		{ 6, function()
			ns:Print(L["Test: stun aura (red) + normal cast"])
			Cleu("SPELL_AURA_APPLIED", other, otherName, HOSTILE_PLAYER, guid, name, HOSTILE_PLAYER, 853, (GetSpellInfo(853)), 1, "DEBUFF")
			Cleu("SPELL_CAST_START", guid, name, HOSTILE_PLAYER, nil, nil, 0, 116, (GetSpellInfo(116)), 16)
			local c = ns.Casts.store[guid]
			if c then c.duration = 5 end
		end },
		{ 9, function()
			ns:Print(L["Test: diminishing returns (3 levels), PvP trinket timer, flag carrier, raid NPC glow"])
			if ns.DR then ns.DR:Fake(guid) end
			ns.trinkets = ns.trinkets or {}
			ns.trinkets[guid] = { ready = GetTime() + 120 }
			ns.flagCarriers = ns.flagCarriers or {}
			ns.flagCarriers[guid] = "HORDE"
			d.testRaidPrio = 1
		end },
		{ 16, function()
			ns.Casts.EndCast(guid)
			ns.Auras.store[guid] = nil
			if ns.DR then ns.DR:Clear(guid) end
			ns.healers[name] = wasHealer
			if ns.trinkets then ns.trinkets[guid] = wasTrinket end
			if ns.flagCarriers then ns.flagCarriers[guid] = wasFlag end
			d.testRaidPrio = nil
			ns:Print(L["Test finished."])
		end },
	}
	testFrame = testFrame or CreateFrame("Frame")
	local t0, idx = GetTime(), 1
	testFrame:SetScript("OnUpdate", function(self)
		local step = steps[idx]
		if not step then self:Hide() return end
		if GetTime() - t0 >= step[1] then
			step[2]()
			idx = idx + 1
			if not steps[idx] then self:Hide() end
		end
	end)
	testFrame:Show()
end

local function UnstackAll()
	for _, d in pairs(all) do
		d.stackTarget = 0
		SetStackOffset(d, 0)
	end
end

-- Darf in dieser Zone gestapelt werden?
local function StackAllowed()
	local db = ns.db
	if not db.stacking then return false end
	local inst = ns.instanceType
	if inst == "arena" or inst == "pvp" then return db.stackingPvP end
	if inst == "raid" or inst == "party" then return db.stackingRaid end
	return true
end

function Plates:Init()
	if self.frame then return end
	pcall(self.WarnOthers, self)
	local lastChildren = 0
	local tick, cleanup, stackTick = 0, 0, 0
	local wasStacking = false
	local frame = CreateFrame("Frame")
	self.frame = frame

	frame:SetScript("OnUpdate", function(_, elapsed)
		local n = WorldFrame:GetNumChildren()
		if n ~= lastChildren then
			lastChildren = n
			ScanChildren(WorldFrame:GetChildren())
		end

		if next(cleuActive) then
			local now = GetTime()
			for d in pairs(cleuActive) do
				local c = d.castCleu
				if c and ns.Casts.store[d.guid] == c and (c.interruptedAt or now <= c.start + c.duration) then
					local ok, err = pcall(CleuCastFrame, d, now)
					if not ok then Report("CastFrame", err) CleuCastStop(d) end
				else
					CleuCastStop(d)
				end
			end
		end

		tick = tick + elapsed
		if tick >= (ns.db.updateRate or 0.1) then
			tick = 0
			local ok, err = pcall(ns.Auras.Flush, ns.Auras)
			if not ok then Report("Auras", err) end
			ns.Casts:Expire(GetTime())
			ok, err = pcall(GatherState)
			if not ok then Report("GatherState", err) end
			for _, d in pairs(visible) do
				SafeUpdate(d)
			end
		end

		if StackAllowed() then
			wasStacking = true
			stackTick = stackTick + elapsed
			if stackTick >= 0.06 then
				local ok, err = pcall(Stack, stackTick)
				if not ok then
					Plates.stackErrMsg = err
					if not Plates.stackErr then
						Plates.stackErr = true
						ns:Print("Fehler beim Stapeln: " .. tostring(err))
					end
				end
				stackTick = 0
			end
		elseif wasStacking then
			wasStacking = false
			UnstackAll()
		end

		cleanup = cleanup + elapsed
		if cleanup >= 30 then
			cleanup = 0
			ns.Auras:Cleanup()
			if ns.DR then ns.DR:Cleanup() end
			if ns.CleanupTracking then ns.CleanupTracking() end
		end
	end)

	-- Zielwechsel sofort zeigen
	ns:On("PLAYER_TARGET_CHANGED", function() tick = 1 end)
end
