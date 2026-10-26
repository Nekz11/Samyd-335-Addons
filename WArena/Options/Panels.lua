-- WArena: options pages
local _, ns = ...
local L = ns.L
local W = ns.Widgets
local format = string.format
local COL1, COL2 = W.COL1, W.COL2

---------------------------------------------------------------------------
-- small layout cursor: one y per column, auto-advancing
---------------------------------------------------------------------------
local function Cursor(page)
	local c = { page = page, y = { [COL1] = -8, [COL2] = -8 } }
	function c:header(x, text) W:Header(self.page, text, x, self.y[x]); self.y[x] = self.y[x] - 26 end
	function c:note(x, text, h, width) W:Note(self.page, text, x, self.y[x], width or 280); self.y[x] = self.y[x] - (h or 30) end
	function c:check(x, key, label, desc, opts) local w = W:Check(self.page, key, label, desc, x, self.y[x], opts); self.y[x] = self.y[x] - 26; return w end
	function c:slider(x, key, label, lo, hi, step, fmt, desc, opts) local w = W:Slider(self.page, key, label, lo, hi, step, x, self.y[x], fmt, desc, opts); self.y[x] = self.y[x] - 48; return w end
	function c:dropdown(x, key, label, items, desc, width, opts) local w = W:Dropdown(self.page, key, label, items, x, self.y[x], width or 150, desc, opts); self.y[x] = self.y[x] - 52; return w end
	function c:color(x, key, label, desc, opts) local w = W:Color(self.page, key, label, x, self.y[x], desc, opts); self.y[x] = self.y[x] - 24; return w end
	function c:button(x, label, width, fn, desc) local w = W:Button(self.page, label, width, x, self.y[x], fn, desc); self.y[x] = self.y[x] - 30; return w end
	function c:gap(x, h) self.y[x] = self.y[x] - (h or 10) end
	function c:finish() local h = math.min(self.y[COL1], self.y[COL2]); self.page:SetHeight(-h + 20) end
	return c
end

local POS4 = { { "right", "Right of the frame" }, { "left", "Left of the frame" }, { "below", "Below the frame" }, { "above", "Above the frame" } }
local POS4_CAST = { { "left", "Left of the frame" }, { "right", "Right of the frame" }, { "below", "Below the frame" }, { "above", "Above the frame" } }
local HEALTH_TEXT = { { "percent", "Percent" }, { "current", "Current health" }, { "both", "Current + percent" }, { "deficit", "Missing health" }, { "none", "None" } }
local NAME_MODE = { { "name", "Player name" }, { "class", "Class name" }, { "spec", "Spec (fallback class)" }, { "number", "Arena number" } }
local function Media(kind) return function() local out = {} for _, n in ipairs(ns:MediaList(kind)) do out[#out + 1] = { n, n } end return out end end
local function Sounds() local out = {} for _, n in ipairs(ns:SoundList()) do out[#out + 1] = { n, n } end return out end

---------------------------------------------------------------------------
-- 1 General
---------------------------------------------------------------------------
do
	local pg = W:NewPage("General")
	local c = Cursor(pg)
	c:header(COL1, "Frames")
	local testBtn = W:Button(pg, "Show test frames", 140, COL1, c.y[COL1], function() ns.ToggleTest() end)
	local lockBtn = W:Button(pg, "Unlock frames", 140, COL1 + 146, c.y[COL1], function() ns.SetLocked(not ns.IsLocked()) end)
	testBtn.Refresh = function(self) self:SetText(ns.state.testMode and "Hide test frames" or "Show test frames") end
	lockBtn.Refresh = function(self) self:SetText(ns.db.locked and "Unlock frames" or "Lock frames") end
	W.widgets[#W.widgets + 1] = testBtn
	W.widgets[#W.widgets + 1] = lockBtn
	c:gap(COL1, 30)
	c:note(COL1, "Test frames are shown automatically while this window is open (outside arenas). Unlock, then drag the green boxes (frames, alerts, HUD, battleground list, boss frames).", 44)
	c:dropdown(COL1, "healer", "Healer position", { { "last", "Always last frame" }, { "first", "Always first frame" }, { "off", "Keep arena order" } },
		"3v3: slot 3, 2v2: slot 2. Frames can only move out of combat.")
	c:check(COL1, "healerIcon", "Healer role icon", "Show a healer icon on the class icon of the detected healer.")
	c:check(COL1, "growUp", "Grow upwards", "Stack frames upwards instead of downwards.")
	c:check(COL1, "horizontal", "Horizontal layout", "Place the frames side by side instead of stacked.")
	c:check(COL1, "mirror", "Mirror layout", "Class icon on the right, side elements swap left/right.")
	c:check(COL1, "tooltips", "Unit tooltips on hover", nil)
	c:dropdown(COL1, "middleClick", "Middle click", { { "none", "Nothing" }, { "target", "Target" }, { "focus", "Focus" } })
	c:check(COL1, "blizzard", "Hide Blizzard arena frames", "Requires /reload to take effect.", { invert = true })
	c:check(COL1, "minimapHide", "Hide minimap button", nil, {
		get = function() return ns.global.minimap.hide end,
		set = function(v) ns.MinimapButton:SetHidden(v) end,
	})
	c:gap(COL1, 6)
	c:button(COL1, "Reset active profile", 160, function()
		if InCombatLockdown() then ns:Print(L["Not possible in combat."]) return end
		ns:ResetProfile()
	end, "Resets every setting of the active profile to the defaults.")

	c:header(COL2, "Size & position")
	c:slider(COL2, "scale", "Scale", 0.5, 2, 0.05, "%.2f")
	c:slider(COL2, "width", "Width", 100, 320, 5)
	c:slider(COL2, "height", "Height", 24, 80, 1)
	c:slider(COL2, "spacing", "Spacing between frames", 0, 100, 1)
	c:slider(COL2, "bgAlpha", "Background opacity", 0, 1, 0.05, "%.2f")
	c:slider(COL2, "unseenAlpha", "Opacity of stealthed enemies", 0.1, 1, 0.05, "%.2f")
	c:header(COL2, "Pets")
	c:check(COL2, "pets", "Show enemy pets", "Small health line below the owner (hunter, warlock, DK, mage pets).")
	c:slider(COL2, "petHeight", "Pet line height", 6, 20, 1)
	c:finish()
end

---------------------------------------------------------------------------
-- 2 Bars & Text
---------------------------------------------------------------------------
do
	local pg = W:NewPage("Bars & Text")
	local c = Cursor(pg)
	c:header(COL1, "Bars")
	c:dropdown(COL1, "texture", "Bar texture", Media("statusbar"), "Built-in textures plus LibSharedMedia if installed.", 180)
	c:check(COL1, "classcolor", "Class-colored health bars", "Otherwise the name is class-colored.")
	c:check(COL1, "healthGradient", "Health gradient (green > red)", "Used when class colors are off.")
	c:color(COL1, "healthColor", "Health color (no class color / gradient)")
	c:color(COL1, "healthBg", "Health bar background")
	c:color(COL1, "powerBg", "Power bar background")
	c:gap(COL1, 6)
	c:check(COL1, "powerBar", "Power bar", "Mana/rage/energy/runic power below the health bar.")
	c:slider(COL1, "powerHeight", "Power bar height", 3, 20, 1)
	c:header(COL1, "Borders")
	c:dropdown(COL1, "borderStyle", "Frame border", ns.BorderStyles)
	c:color(COL1, "borderColor", "Frame border color")
	c:gap(COL1, 6)
	c:check(COL1, "targetBorder", "Highlight my target", nil)
	c:color(COL1, "targetColor", "Target color")
	c:check(COL1, "focusBorder", "Highlight my focus", nil)
	c:color(COL1, "focusColor", "Focus color")

	c:header(COL2, "Text")
	c:dropdown(COL2, "font", "Font", Media("font"), "Built-in fonts plus LibSharedMedia if installed.", 180)
	c:slider(COL2, "fontSize", "Font size", 7, 18, 1)
	c:dropdown(COL2, "fontOutline", "Outline", ns.OutlineStyles)
	c:check(COL2, "fontShadow", "Text shadow", nil)
	c:color(COL2, "textColor", "Text color")
	c:gap(COL2, 6)
	c:dropdown(COL2, "healthText", "Health text", HEALTH_TEXT, nil, 180)
	c:dropdown(COL2, "nameMode", "Name", NAME_MODE, nil, 180)
	c:slider(COL2, "nameLimit", "Name length limit (0 = off)", 0, 20, 1)
	c:check(COL2, "spec", "Show spec", "Detected spec, shown on the power bar.")
	c:dropdown(COL2, "specMode", "Spec text", { { "text", "Full name" }, { "short", "Short (4 letters)" } })
	c:check(COL2, "arenaId", "Arena number on class icon", "Small number = real arena ID, useful for /focus arenaX macros.")
	c:dropdown(COL2, "iconStyle", "Class icon style", ns.IconStyles)
	c:finish()
end

---------------------------------------------------------------------------
-- 3 Icons & Auras
---------------------------------------------------------------------------
do
	local pg = W:NewPage("Icons & Auras")
	local c = Cursor(pg)
	c:header(COL1, "Trinket & racial")
	c:check(COL1, "trinket", "PvP trinket cooldown", "PvP trinket or Every Man for Himself.")
	c:check(COL1, "racial", "Racial cooldown", "Will of the Forsaken, Stoneform, Escape Artist, Arcane Torrent...")
	c:check(COL1, "trinketReadyGlow", "Glow when trinket comes off cooldown", nil)
	c:slider(COL1, "iconSize", "Icon size (% of frame height)", 50, 150, 5)
	c:dropdown(COL1, "iconSide", "Side", { { "right", "Right of the frame" }, { "left", "Left of the frame" } })
	c:check(COL1, "cdText", "Cooldown numbers on icons", "Disabled automatically when OmniCC is loaded.")
	c:header(COL1, "Aura row")
	c:check(COL1, "auraRow", "Show all tracked auras as a row", "In addition to the class icon: every tracked buff/debuff with timer.")
	c:check(COL1, "auraRowTimer", "Cooldown sweep", nil)
	c:slider(COL1, "auraRowSize", "Icon size (% of frame height)", 30, 120, 5)
	c:slider(COL1, "auraRowMax", "Maximum icons", 1, 12, 1)
	c:slider(COL1, "auraRowSpacing", "Spacing", 0, 8, 1)
	c:dropdown(COL1, "auraRowPos", "Position", POS4)
	c:note(COL1, "Aura row categories:", 18)
	for _, cat in ipairs(ns.AuraCategories) do
		c:check(COL1, "auraRow" .. cat.key, cat.label, nil)
	end

	c:header(COL2, "Auras on the class icon")
	c:check(COL2, "aura", "Replace class icon with important auras", "The most important active aura is shown instead of the class icon.")
	c:check(COL2, "auraTimer", "Cooldown sweep on auras", nil)
	c:note(COL2, "Categories (highest priority first):", 18)
	for _, cat in ipairs(ns.AuraCategories) do
		c:check(COL2, "aura" .. cat.key, cat.label, nil)
	end
	c:finish()
end

---------------------------------------------------------------------------
-- 4 DR
---------------------------------------------------------------------------
do
	local pg = W:NewPage("DR")
	local c = Cursor(pg)
	c:header(COL1, "Diminishing returns")
	c:check(COL1, "dr", "Enable DR tracker", "One icon per CC category. Every source counts (you, your partners, pets).")
	c:check(COL1, "drText", "Show DR level as text (½ ¼ 0)", nil)
	c:check(COL1, "drGrowLeft", "Grow icons to the left", nil)
	c:slider(COL1, "drSize", "Icon size (% of frame height)", 40, 130, 5)
	c:dropdown(COL1, "drPos", "Position", POS4)
	c:slider(COL1, "drReset", "DR reset time (seconds)", 15, 25, 1, nil, "Time after a CC ends until its DR resets. 18 s is the common value on 3.3.5 servers.")
	c:color(COL1, "drColor1", "Level 1 (next CC: half duration)")
	c:color(COL1, "drColor2", "Level 2 (next CC: quarter duration)")
	c:color(COL1, "drColor3", "Level 3 (immune)")

	c:header(COL2, "Categories")
	for _, cat in ipairs(ns.DROrder) do
		c:check(COL2, ns.DR.Key(cat), ns.DRLabels[cat] or cat, nil)
	end
	c:finish()
end

---------------------------------------------------------------------------
-- 5 Cooldowns
---------------------------------------------------------------------------
do
	local pg = W:NewPage("Cooldowns")
	local c = Cursor(pg)
	c:header(COL1, "Enemy cooldown tracker")
	c:check(COL1, "cooldowns", "Enable cooldown tracker", "Icons appear when an enemy uses a tracked ability. Interrupts are always shown first.")
	c:check(COL1, "cdShowReady", "Keep icons after the cooldown ends (dimmed)", nil)
	c:slider(COL1, "cdReadyAlpha", "Opacity of ready icons", 0.1, 1, 0.05, "%.2f")
	c:check(COL1, "cdGlow", "Glow while the ability is active", "e.g. Shield Wall, Evasion, Icy Veins.")
	c:slider(COL1, "cdSize", "Icon size (% of frame height)", 40, 130, 5)
	c:slider(COL1, "cdMax", "Maximum icons per enemy", 1, 16, 1)
	c:slider(COL1, "cdSpacing", "Icon spacing", 0, 8, 1)
	c:dropdown(COL1, "cdPos", "Position", POS4)

	c:header(COL2, "Categories")
	for _, cat in ipairs(ns.CDCategories) do
		c:check(COL2, ns.Cooldowns.CatKey(cat.key), cat.label, nil)
	end
	c:note(COL2, "Base cooldowns are used (no talent or glyph reductions, those are invisible for enemies). Cold Snap, Preparation and Readiness reset the affected icons.", 56)
	c:header(COL2, "Enemy totems")
	c:check(COL2, "totems", "Track important totems", "Grounding, Tremor, Cleansing... with remaining time; removed when the totem dies.")
	c:slider(COL2, "totemSize", "Icon size (% of frame height)", 40, 130, 5)
	c:dropdown(COL2, "totemPos", "Position", POS4)
	c:slider(COL2, "totemMax", "Maximum icons", 1, 8, 1)
	for _, t in ipairs(ns.TotemDB) do
		c:check(COL2, t.opt, t.key .. " Totem", nil)
	end
	c:finish()
end

---------------------------------------------------------------------------
-- 6 Cast bar
---------------------------------------------------------------------------
do
	local pg = W:NewPage("Cast bar")
	local c = Cursor(pg)
	c:header(COL1, "Cast bar")
	c:check(COL1, "castbar", "Enable cast bar", nil)
	c:dropdown(COL1, "castPos", "Position", POS4_CAST)
	c:slider(COL1, "castWidth", "Width (% of frame width)", 40, 150, 5, nil, "Only used for left/right positions.")
	c:slider(COL1, "castHeight", "Height", 8, 32, 1)
	c:slider(COL1, "castHold", "\"Interrupted\" display time (seconds)", 0, 3, 0.25, "%.2f", "0 disables the red interrupted bar.")

	c:header(COL2, "Contents & colors")
	c:check(COL2, "castIcon", "Spell icon", nil)
	c:check(COL2, "castName", "Spell name", nil)
	c:check(COL2, "castTime", "Remaining time", nil)
	c:gap(COL2, 6)
	c:color(COL2, "castColor", "Interruptible cast")
	c:color(COL2, "castChannelColor", "Channel")
	c:color(COL2, "castShieldColor", "Not interruptible")
	c:color(COL2, "castInterruptColor", "Interrupted")
	c:finish()
end

---------------------------------------------------------------------------
-- 7 Indicators
---------------------------------------------------------------------------
do
	local pg = W:NewPage("Indicators")
	local c = Cursor(pg)
	c:header(COL1, "Targets")
	c:check(COL1, "indTargetingYou", "\"Targeting you\" marker", "A pulsing red ! on the class icon while the enemy targets you.")
	c:check(COL1, "indPartyTargets", "Party target icons", "Class icons of your party members targeting this enemy (above the health bar).")
	c:check(COL1, "indEnemyTarget", "Enemy target text", "Who the enemy is targeting, on the power bar.")
	c:dropdown(COL1, "indEnemyTargetMode", "Enemy target as", { { "name", "Name" }, { "class", "Class" } })
	c:slider(COL1, "indIconSize", "Indicator icon size", 8, 24, 1)

	c:header(COL2, "State")
	c:check(COL2, "indRange", "Fade frames out of range", "Uses one of your class spells for the range check.")
	c:slider(COL2, "rangeAlpha", "Out-of-range opacity", 0.1, 1, 0.05, "%.2f")
	c:check(COL2, "indDrink", "Drink icon", "Shows while the enemy drinks, with a counter.")
	c:check(COL2, "indStealth", "Stealth icon", "Shown while an enemy is stealthed / unseen.")
	c:check(COL2, "indLowHP", "Low health overlay", nil)
	c:slider(COL2, "lowHPThreshold", "Low health threshold (%)", 5, 60, 1)
	c:color(COL2, "lowHPColor", "Low health color")
	c:header(COL1, "Nameplates")
	c:check(COL1, "plates", "Arena number on enemy nameplates", "Shows 1/2/3 above the nameplates of the arena enemies.")
	c:check(COL1, "plateSpec", "Add spec to the number", nil)
	c:check(COL1, "plateClassColor", "Class-colored", nil)
	c:slider(COL1, "plateSize", "Font size", 8, 30, 1)
	c:slider(COL1, "plateOffsetY", "Vertical offset", -20, 40, 1)
	c:finish()
end

---------------------------------------------------------------------------
-- 8 Announce
---------------------------------------------------------------------------
do
	local pg = W:NewPage("Announce")
	local c = Cursor(pg)
	c:header(COL1, "Announcements")
	c:check(COL1, "announce", "Enable announcements", nil)
	c:check(COL1, "annInArenaOnly", "Only inside arenas / battlegrounds", nil)
	c:check(COL1, "annSounds", "Play sounds", nil)
	c:slider(COL1, "annThrottle", "Repeat protection (seconds)", 0, 20, 1)
	c:slider(COL1, "annLowHPThreshold", "Low health announcement (%)", 5, 60, 1)
	c:header(COL2, "Screen alerts")
	c:slider(COL2, "annScreenScale", "Alert scale", 0.5, 2.5, 0.1, "%.1f")
	c:slider(COL2, "annScreenDuration", "Alert duration (seconds)", 1, 8, 0.5, "%.1f")
	c:color(COL2, "annScreenColor", "Default alert color")
	c:gap(COL2, 6)
	c:button(COL2, "Preview alerts", 140, function() ns.Announce:Test() end)
	local y = math.min(c.y[COL1], c.y[COL2]) - 6
	W:Header(pg, "Events", COL1, y)
	W:Label(pg, "Output", COL1 + 220, y - 2, "GameFontNormalSmall")
	W:Label(pg, "Sound", COL1 + 420, y - 2, "GameFontNormalSmall")
	y = y - 26
	for _, e in ipairs(ns.AnnounceEvents) do
		W:Label(pg, e.label, COL1, y - 16, "GameFontHighlightSmall", 210)
		W:Dropdown(pg, "ann_" .. e.key, "", ns.AnnounceChannels, COL1 + 220, y, 160)
		W:Dropdown(pg, "snd_" .. e.key, "", Sounds, COL1 + 420, y, 130)
		y = y - 40
	end
	pg:SetHeight(-y + 20)
end

---------------------------------------------------------------------------
-- 9 HUD
---------------------------------------------------------------------------
do
	local pg = W:NewPage("Arena HUD")
	local c = Cursor(pg)
	c:header(COL1, "Arena HUD")
	c:check(COL1, "hud", "Enable HUD", "Preparation countdown, match timer and Shadow Sight timer.")
	c:check(COL1, "hudPrep", "Preparation countdown", "Parsed from the arena system messages.")
	c:check(COL1, "hudMatch", "Match timer", nil)
	c:check(COL1, "hudShadowSight", "Shadow Sight timer", "Orbs spawn 90 s after the gates open.")
	c:slider(COL1, "hudWarnSS", "Shadow Sight warning (seconds before, 0 = off)", 0, 30, 1)
	c:button(COL1, "Preview HUD (20 s)", 160, function() ns.HUD:Demo(20) end)
	c:header(COL2, "Look")
	c:slider(COL2, "hudScale", "Scale", 0.5, 2.5, 0.1, "%.1f")
	c:slider(COL2, "hudFontSize", "Font size", 10, 40, 1)
	c:slider(COL2, "hudAlpha", "Opacity", 0.2, 1, 0.05, "%.2f")
	c:check(COL2, "hudBackground", "Background box", nil)
	c:color(COL2, "hudColor", "Text color")
	c:finish()
end

---------------------------------------------------------------------------
-- 10 Battleground
---------------------------------------------------------------------------
do
	local pg = W:NewPage("Battleground")
	local c = Cursor(pg)
	c:header(COL1, "Enemy list")
	c:check(COL1, "bgEnabled", "Enable battleground enemy list", "Roster from the scoreboard. Click a row to target, right click to focus.")
	local prev = W:Button(pg, "Preview list", 140, COL1, c.y[COL1], function() ns.Battleground:SetTest(not ns.db.bgTest) end)
	prev.Refresh = function(self) self:SetText(ns.db.bgTest and "Hide preview" or "Preview list") end
	W.widgets[#W.widgets + 1] = prev
	c:gap(COL1, 30)
	c:dropdown(COL1, "bgSort", "Sort by", { { "role", "Healers first, then class" }, { "class", "Class" }, { "name", "Name" }, { "health", "Health (lowest first)" }, { "kills", "Killing blows" } }, nil, 180)
	c:check(COL1, "bgHealersOnly", "Show healers only", nil)
	c:check(COL1, "bgHideDead", "Hide dead enemies", nil)
	c:check(COL1, "bgShowRole", "Healer icon", nil)
	c:check(COL1, "bgShowSpec", "Spec text", "From the scoreboard or detected from buffs.")
	c:check(COL1, "bgShowHealth", "Health (when known)", "Health is tracked from your target, focus, mouseover and party/raid targets.")
	c:check(COL1, "bgShowKD", "Kills / deaths", nil)
	c:check(COL1, "bgShowNumbers", "Row numbers", nil)
	c:check(COL1, "bgClassColorRow", "Class-colored row background", nil)
	c:check(COL1, "bgHeader", "Header with count and flag carriers", nil)
	c:check(COL1, "bgShowFriendlyFC", "Show friendly flag carrier", nil)
	c:slider(COL1, "bgRefresh", "Scoreboard refresh (seconds)", 5, 30, 1)
	c:slider(COL1, "bgHealthStale", "Health is stale after (seconds)", 5, 60, 1)

	c:header(COL2, "Layout")
	c:slider(COL2, "bgScale", "Scale", 0.5, 2, 0.05, "%.2f")
	c:slider(COL2, "bgWidth", "Row width", 100, 300, 5)
	c:slider(COL2, "bgRowHeight", "Row height", 12, 30, 1)
	c:slider(COL2, "bgFontSize", "Font size", 7, 16, 1)
	c:slider(COL2, "bgColumns", "Columns", 1, 3, 1)
	c:slider(COL2, "bgMaxRows", "Rows per column", 5, 40, 1)
	c:slider(COL2, "bgBgAlpha", "Background opacity", 0, 1, 0.05, "%.2f")
	c:note(COL2, "The flag carrier is tracked from the combat log (Warsong Gulch, Eye of the Storm) and announced via the Announce settings.", 44)
	c:finish()
end

---------------------------------------------------------------------------
-- 11 Boss frames
---------------------------------------------------------------------------
do
	local pg = W:NewPage("Boss frames")
	local c = Cursor(pg)
	c:header(COL1, "Boss frames (dungeons & raids)")
	c:check(COL1, "bossEnabled", "Enable boss frames", "boss1-4 units in encounters, using the same frame engine (no PvP elements).")
	c:check(COL1, "bossHideBlizzard", "Hide Blizzard boss frames", nil)
	local prev = W:Button(pg, "Preview boss frames", 160, COL1, c.y[COL1], function() ns.Boss:SetTest(not ns.db.bossTest) end)
	prev.Refresh = function(self) self:SetText(ns.db.bossTest and "Hide preview" or "Preview boss frames") end
	W.widgets[#W.widgets + 1] = prev
	c:gap(COL1, 30)
	c:dropdown(COL1, "boss_healthText", "Health text", HEALTH_TEXT, nil, 180)
	c:dropdown(COL1, "boss_nameMode", "Name", { { "name", "Boss name" }, { "number", "Boss number" } }, nil, 180)
	c:check(COL1, "boss_classcolor", "Class-colored health", nil)
	c:check(COL1, "boss_healthGradient", "Health gradient", nil)
	c:check(COL1, "boss_powerBar", "Power bar", nil)
	c:slider(COL1, "boss_powerHeight", "Power bar height", 3, 20, 1)
	c:check(COL1, "boss_indTargetingYou", "\"Targeting you\" marker", nil)
	c:check(COL1, "boss_indPartyTargets", "Party target icons", nil)
	c:check(COL1, "boss_indEnemyTarget", "Boss target text", nil)
	c:check(COL1, "boss_indLowHP", "Low health overlay", nil)

	c:header(COL2, "Layout")
	c:slider(COL2, "boss_scale", "Scale", 0.5, 2, 0.05, "%.2f")
	c:slider(COL2, "boss_width", "Width", 100, 320, 5)
	c:slider(COL2, "boss_height", "Height", 24, 80, 1)
	c:slider(COL2, "boss_spacing", "Spacing", 0, 60, 1)
	c:check(COL2, "boss_growUp", "Grow upwards", nil)
	c:dropdown(COL2, "boss_castPos", "Cast bar position", POS4_CAST)
	c:slider(COL2, "boss_castHeight", "Cast bar height", 8, 32, 1)
	c:finish()
end

---------------------------------------------------------------------------
-- 12 Themes
---------------------------------------------------------------------------
do
	local pg = W:NewPage("Themes & Presets")
	local c = Cursor(pg)
	c:header(COL1, "Presets (what is active)")
	c:note(COL1, "A preset switches the modules on or off for a play style – frames, trackers, HUD, announcements, battleground list, boss frames. The look stays as it is.", 44, 560)
	local py = c.y[COL1]
	for _, p in ipairs(ns.PresetList) do
		local b = W:Button(pg, p.name, 150, COL1, py, function()
			if InCombatLockdown() then ns:Print(L["Not possible in combat."]) return end
			ns.Themes:ApplyPreset(p.name)
		end)
		W:Label(pg, p.desc, COL1 + 160, py - 4, "GameFontHighlightSmall", 390)
		b.Refresh = function(self)
			if ns.db.preset == p.name then self:LockHighlight() else self:UnlockHighlight() end
		end
		W.widgets[#W.widgets + 1] = b
		py = py - 40
	end
	c.y[COL1] = py - 6
	c:header(COL1, "Themes (how it looks)")
	c:note(COL1, "A theme sets a group of look-related settings (texture, font, borders, colors, positions) at once. Everything stays editable afterwards.", 44, 560)
	local y = c.y[COL1]
	for _, t in ipairs(ns.ThemeList) do
		local b = W:Button(pg, t.name, 120, COL1, y, function()
			if InCombatLockdown() then ns:Print(L["Not possible in combat."]) return end
			ns.Themes:Apply(t.name)
		end)
		local d = W:Label(pg, t.desc, COL1 + 130, y - 4, "GameFontHighlightSmall", 420)
		b.Refresh = function(self)
			if ns.db.theme == t.name then self:LockHighlight() else self:UnlockHighlight() end
		end
		W.widgets[#W.widgets + 1] = b
		y = y - 40
	end
	W:Note(pg, "Tip: pick a theme first, then fine-tune on the Bars & Text page.", COL1, y - 10, 560)
	pg:SetHeight(-y + 60)
end

---------------------------------------------------------------------------
-- 13 Profiles
---------------------------------------------------------------------------
do
	local pg = W:NewPage("Profiles")
	local c = Cursor(pg)
	local P = ns.Profiles
	local function ProfileItems() local out = {} for _, n in ipairs(P:List()) do out[#out + 1] = { n, n } end return out end
	c:header(COL1, "Active profile")
	c:dropdown(COL1, "activeProfile", "Profile for this character", ProfileItems, nil, 180, {
		get = function() return P:Current() end,
		set = function(v) ns:ActivateProfile(v) end,
	})
	local status = W:Note(pg, "", COL1, c.y[COL1], 280, "GameFontHighlightSmall")
	status.Refresh = function(self)
		local chars = P:CharactersUsing(P:Current())
		self:SetText(format("Used by %d character(s).", #chars))
	end
	W.widgets[#W.widgets + 1] = status
	c:gap(COL1, 24)
	c:button(COL1, "Use this profile on all characters", 220, function() P:UseForAllCharacters() end)
	c:header(COL1, "Create / copy / delete")
	local newBox = W:EditBox(pg, "New profile name", 180, COL1, c.y[COL1], function(text)
		local ok, err = P:Create(text)
		if not ok then ns:Print(err) end
	end)
	W:Button(pg, "Create", 70, COL1 + 200, c.y[COL1] - 14, function()
		local ok, err = P:Create(newBox:GetText())
		if ok then newBox:SetText("") else ns:Print(err) end
	end)
	c:gap(COL1, 46)
	local copyFrom
	c:dropdown(COL1, "copyFrom", "Copy settings from", ProfileItems, "Overwrites the active profile with a copy of the chosen one.", 180, {
		get = function() return copyFrom end, set = function(v) copyFrom = v end,
	})
	c:button(COL1, "Copy into active profile", 180, function()
		if not copyFrom then ns:Print("Choose a profile first.") return end
		local ok, err = P:CopyFrom(copyFrom)
		if not ok then ns:Print(err) end
	end)
	local delName
	c:dropdown(COL1, "deleteProfile", "Delete profile", ProfileItems, "The active profile cannot be deleted.", 180, {
		get = function() return delName end, set = function(v) delName = v end,
	})
	c:button(COL1, "Delete", 100, function()
		if not delName then ns:Print("Choose a profile first.") return end
		local ok, err = P:Delete(delName)
		if ok then ns:Print("Profile '%s' deleted.", delName); delName = nil else ns:Print(err) end
	end)
	local renameBox = W:EditBox(pg, "Rename active profile to", 180, COL1, c.y[COL1], function(text)
		local ok, err = P:Rename(text)
		if not ok then ns:Print(err) end
	end)
	W:Button(pg, "Rename", 70, COL1 + 200, c.y[COL1] - 14, function()
		local ok, err = P:Rename(renameBox:GetText())
		if ok then renameBox:SetText("") else ns:Print(err) end
	end)
	c:gap(COL1, 50)

	c:header(COL2, "Export")
	c:note(COL2, "Generate a string, click into the box, Ctrl+A, Ctrl+C and share it.", 30, 400)
	local exportBox = W:MultiLine(pg, 400, 90, COL2, c.y[COL2])
	c:gap(COL2, 96)
	c:button(COL2, "Generate export string", 180, function()
		exportBox.edit:SetText(P:Export())
		exportBox.edit:HighlightText()
		exportBox.edit:SetFocus()
	end)
	c:header(COL2, "Import")
	c:note(COL2, "Paste a WArena export string below.", 20, 400)
	local importBox = W:MultiLine(pg, 400, 90, COL2, c.y[COL2])
	c:gap(COL2, 96)
	local importInfo = W:Note(pg, "", COL2, c.y[COL2], 400, "GameFontHighlightSmall")
	c:gap(COL2, 18)
	importBox.edit:SetScript("OnTextChanged", function(self)
		local n, err = P:Preview(self:GetText())
		if n then importInfo:SetText(format("|cff40ff40Valid string with %d settings.|r", n)) elseif self:GetText() ~= "" then importInfo:SetText("|cffff4040" .. (err or "Invalid") .. "|r") else importInfo:SetText("") end
	end)
	W:Button(pg, "Import into active profile", 180, COL2, c.y[COL2], function()
		if InCombatLockdown() then ns:Print(L["Not possible in combat."]) return end
		local ok, err = P:Import(importBox.edit:GetText())
		if ok then ns:Print("Profile imported.") importBox.edit:SetText("") else ns:Print(err) end
	end)
	local importName = W:EditBox(pg, nil, 120, COL2 + 190, c.y[COL2] + 14)
	importName:SetText("")
	W:Button(pg, "as new", 70, COL2 + 320, c.y[COL2], function()
		if InCombatLockdown() then ns:Print(L["Not possible in combat."]) return end
		local name = ns:Trim(importName:GetText())
		if name == "" then ns:Print("Enter a name for the new profile.") return end
		local ok, err = P:Import(importBox.edit:GetText(), name)
		if ok then ns:Print("Profile '%s' imported.", name) importBox.edit:SetText("") importName:SetText("") else ns:Print(err) end
	end)
	c:gap(COL2, 34)
	c:finish()
end

---------------------------------------------------------------------------
-- 14 History
---------------------------------------------------------------------------
do
	local pg = W:NewPage("History")
	local c = Cursor(pg)
	c:header(COL1, "Arena match history")
	c:check(COL1, "historyEnabled", "Record arena matches", "Map, bracket, enemy composition, duration and result (shared by all characters).")
	c:check(COL1, "historyAnnounce", "Chat summary after each match", nil)
	c:check(COL1, "specMemory", "Remember specs of enemy names", "Known enemies get their spec pre-filled before their first cast.")
	local stats = W:Note(pg, "", COL1, c.y[COL1], 560, "GameFontHighlightSmall")
	stats.Refresh = function(self)
		local n, w, l = ns.History:Stats()
		local pct = (w + l) > 0 and math.floor(w / (w + l) * 100 + 0.5) or 0
		self:SetText(format("%d matches recorded – |cff40ff40%d wins|r / |cffff4040%d losses|r (%d%%), %d enemy specs remembered.", n, w, l, pct, ns.History:SpecCount()))
	end
	W.widgets[#W.widgets + 1] = stats
	c:gap(COL1, 24)
	W:Button(pg, "Clear history", 120, COL1, c.y[COL1], function() ns.History:Clear() end)
	W:Button(pg, "Forget specs", 120, COL1 + 130, c.y[COL1], function() ns.History:ForgetSpecs() end)
	c:gap(COL1, 34)
	local y = c.y[COL1]
	W:Header(pg, "Last matches", COL1, y)
	y = y - 24
	local lines = {}
	for i = 1, 20 do
		local fs = W:Label(pg, "", COL1, y, "GameFontHighlightSmall", 580)
		lines[i] = fs
		y = y - 16
	end
	local listWidget = { Refresh = function()
		local list = ns.History:List()
		for i = 1, 20 do
			local m = list[i]
			if m then
				local comp = {}
				for _, e in ipairs(m.enemies or {}) do
					comp[#comp + 1] = ns:Colored((ns.CLASS_NAMES[e.class] or e.class or "?") .. (e.spec and (" " .. e.spec) or ""), e.class)
				end
				local res = m.result == "W" and "|cff40ff40WIN |r" or m.result == "L" and "|cffff4040LOSS|r" or "|cff999999 ?  |r"
				lines[i]:SetText(format("%s  %s  %s  %s  %s   %s", m.date or "", res, m.bracket or "", m.map or "", ns:FormatClock(m.duration or 0), table.concat(comp, ", ")))
			else
				lines[i]:SetText("")
			end
		end
	end }
	W.widgets[#W.widgets + 1] = listWidget
	pg:SetHeight(-y + 20)
end

---------------------------------------------------------------------------
-- support section (shared by About and the Interface panel)
---------------------------------------------------------------------------
local DONATE_URL = "https://www.warmane.com/account/services"
local DONATE_CHAR, DONATE_REALM = "Samyd", "Blackrock"

local function BuildSupport(parent, x, y, width)
	local h = W:Label(parent, "Buy me a coffee", x, y, "GameFontNormal")
	local coin = parent:CreateTexture(nil, "ARTWORK")
	coin:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
	coin:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	coin:SetWidth(16)
	coin:SetHeight(16)
	coin:SetPoint("LEFT", h, "RIGHT", 6, 0)
	W:Label(parent, "If WArena helps you win games, you can tip the author with Warmane coins. Open the link below in your browser, choose \"Donate coins\" and enter the character.",
		x, y - 18, "GameFontHighlightSmall", width)
	W:Label(parent, "Link (click to select, then Ctrl+C):", x, y - 54, "GameFontNormalSmall")
	local url = W:CopyBox(parent, DONATE_URL, width - 10, x, y - 68)
	W:Label(parent, "Character:", x, y - 100, "GameFontNormalSmall")
	W:CopyBox(parent, DONATE_CHAR, 120, x, y - 114)
	W:Label(parent, "Realm:", x + 150, y - 100, "GameFontNormalSmall")
	W:CopyBox(parent, DONATE_REALM, 120, x + 150, y - 114)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetPoint("TOPLEFT", x, y - 148)
	btn:SetWidth(170)
	btn:SetHeight(24)
	btn:SetText("Copy donation link")
	btn:SetScript("OnClick", function() url:SetFocus(); url:HighlightText() end)
	W:Label(parent, "Thank you!", x + 180, y - 154, "GameFontDisableSmall")
	return y - 180
end

---------------------------------------------------------------------------
-- 15 About
---------------------------------------------------------------------------
do
	local pg = W:NewPage("About")
	W:Label(pg, "WArena " .. ns.version, COL1, -8, "GameFontNormalLarge")
	W:Label(pg, "PvP frames for WotLK 3.3.5a (Warmane). Written from scratch – no code from other arena addons.", COL1, -34, "GameFontHighlightSmall", 560)
	W:Header(pg, "Quick help", COL1, -64)
	W:Label(pg,
		"• Left click a frame = target, right click = focus (middle click configurable)\n"
		.. "• Yellow border = your target, blue border = your focus; red ! = the enemy targets you\n"
		.. "• Class icon shows the most important aura (immunity, CC, silence, defensive); small number = real arena ID\n"
		.. "• DR icons: yellow = next CC half duration, orange = quarter, red = immune\n"
		.. "• Cooldown row: interrupts first, glow while active, dimmed when ready again\n"
		.. "• Cast bar: yellow = interruptible, blue = channel, grey = not interruptible, red = interrupted\n"
		.. "• Spec and healer are detected from talent spells and buffs, so they appear after the first casts\n"
		.. "• Key bindings: Esc > Key Bindings > WArena (target/focus arena 1-5 and the enemy healer)\n"
		.. "• Chat: /warena, /warena test, /warena unlock, /warena lock, /warena bg, /warena boss, /warena hud, /warena profile",
		COL1, -86, "GameFontHighlightSmall", 600)
	local y = BuildSupport(pg, COL1, -250, 560)
	pg:SetHeight(-y + 20)
end

---------------------------------------------------------------------------
-- entry in Interface > AddOns (the 3.3.5 panel area is only ~420 px wide)
---------------------------------------------------------------------------
local PANEL_W = 390
local panel = CreateFrame("Frame", "WArenaInterfacePanel", UIParent)
panel.name = "WArena"
W:Label(panel, "WArena " .. ns.version, 16, -16, "GameFontNormalLarge")
W:Label(panel, "PvP frames for WotLK 3.3.5a: arena enemy frames with DR, cooldowns, cast bars and indicators, "
	.. "battleground enemy list, boss frames, announcements, themes and profiles.", 16, -42, "GameFontHighlightSmall", PANEL_W)
W:Header(panel, "Settings", 16, -96)
W:Label(panel, "All settings live in a separate, movable window. Test frames are shown while it is open.", 16, -118, "GameFontHighlightSmall", PANEL_W)
local pb = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
pb:SetPoint("TOPLEFT", 16, -146)
pb:SetWidth(200)
pb:SetHeight(26)
pb:SetText("Open WArena options")
pb:SetScript("OnClick", function()
	if InterfaceOptionsFrame then InterfaceOptionsFrame:Hide() end
	ns:OpenOptions("General")
end)
W:Label(panel, "or type  /warena", 226, -152, "GameFontDisableSmall")
W:Header(panel, "Support", 16, -190)
BuildSupport(panel, 16, -214, PANEL_W)
InterfaceOptions_AddCategory(panel)
