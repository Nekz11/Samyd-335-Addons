-- BetterPlates - Options
-- Eigenes Einstellungsfenster (/bbp) mit Seitenleiste, Suche, Profilen und
-- Zonen-Regeln, dazu ein Eintrag unter Interface > AddOns, der das Fenster öffnet.

local ADDON, ns = ...
if type(ns) ~= "table" then BetterPlatesNS = BetterPlatesNS or {} ns = BetterPlatesNS ADDON = "BetterPlates" end
local L = ns.L or setmetatable({}, { __index = function(t, k) return k end })
local W = ns.Widgets
local P = ns.Profiles
local format, floor, ipairs, pairs = string.format, math.floor, ipairs, pairs

local WIN_W, WIN_H = 780, 590
local SIDEBAR_W = 160
local ACCENT = W.ACCENT
local BACKDROP, FLAT = W.BACKDROP, W.FLAT
local Header, Note, Check, Slider, Cycle, Dropdown, ColorPick, EditLine, EditArea, Button, PageButton, ButtonPair, CopyBox, Space =
	W.Header, W.Note, W.Check, W.Slider, W.Cycle, W.Dropdown, W.Color, W.EditLine, W.EditArea, W.Button, W.PageButton, W.ButtonPair, W.CopyBox, W.Space

-- Blizzard-CVar als Checkbox
local function CVarCheck(page, col, label, cvar, tip)
	return Check(page, col, label, nil, tip,
		function() local ok, v = pcall(GetCVar, cvar) return ok and v == "1" end,
		function(v) pcall(SetCVar, cvar, v and "1" or "0") end)
end

local function RefreshPage(page)
	for _, w in ipairs(page.widgets) do if w.Refresh then w:Refresh() end end
end

----------------------------------------------------------------
-- Spenden-Fenster
----------------------------------------------------------------
local function CreateDonateFrame()
	local f = CreateFrame("Frame", "BetterPlatesDonate", UIParent)
	f:SetWidth(420)
	f:SetHeight(250)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
	f:SetFrameStrata("DIALOG")
	f:SetBackdrop(BACKDROP)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()
	tinsert(UISpecialFrames, "BetterPlatesDonate")

	local header = f:CreateTexture(nil, "ARTWORK")
	header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	header:SetWidth(300)
	header:SetHeight(64)
	header:SetPoint("TOP", f, "TOP", 0, 12)
	local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetPoint("TOP", header, "TOP", 0, -14)
	title:SetText(L["Support the author"])

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

	local heart = f:CreateTexture(nil, "ARTWORK")
	heart:SetTexture("Interface\\Icons\\INV_ValentinesCandy")
	heart:SetWidth(36)
	heart:SetHeight(36)
	heart:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -40)
	heart:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	local text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("TOPLEFT", heart, "TOPRIGHT", 10, -2)
	text:SetPoint("RIGHT", f, "RIGHT", -24, 0)
	text:SetJustifyH("LEFT")
	text:SetText(L["If this addon helps you, you can send a few Warmane Coins to its author. Thank you!"])

	local l1 = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	l1:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -96)
	l1:SetText(L["1. Open this page (Ctrl+C to copy):"])
	local url = CopyBox(f, 360, ns.DONATE_URL)
	url:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 6, -6)

	local l2 = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	l2:SetPoint("TOPLEFT", url, "BOTTOMLEFT", -6, -12)
	l2:SetText(L["2. Send coins to this character:"])
	local char = CopyBox(f, 360, ns.DONATE_CHAR)
	char:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 6, -6)

	local hint = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 24, 20)
	hint:SetText(L["Click a field to select it, then press Ctrl+C."])

	local thanks = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	thanks:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 18)
	thanks:SetText(L["Thank you!"])
	thanks:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])

	f:SetScript("OnShow", function()
		url:SetText(ns.DONATE_URL)
		char:SetText(ns.DONATE_CHAR)
	end)
	return f
end

function ns:ToggleDonate()
	if not ns.donateFrame then ns.donateFrame = CreateDonateFrame() end
	if ns.donateFrame:IsShown() then ns.donateFrame:Hide() else ns.donateFrame:Show() end
end

----------------------------------------------------------------
-- Popups
----------------------------------------------------------------
StaticPopupDialogs["BETTERPLATES_RESET"] = {
	text = L["Reset the current profile to defaults?"],
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		P:Reset()
		ns:RebuildAuraLists()
		ns:Refresh()
		if ns.optionsWindow and ns.optionsWindow.current then RefreshPage(ns.optionsWindow.current) end
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

StaticPopupDialogs["BETTERPLATES_DELETE_PROFILE"] = {
	text = L["Delete profile %s?"],
	button1 = YES,
	button2 = NO,
	OnAccept = function(self, data)
		if P:Delete(data) then
			ns:Print(format(L["Profile %s deleted."], tostring(data)))
			if ns.optionsWindow and ns.optionsWindow.current then RefreshPage(ns.optionsWindow.current) end
		end
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

----------------------------------------------------------------
-- Fenster-Gerüst
----------------------------------------------------------------
local function SelectPage(win, page)
	for _, p in ipairs(win.pages) do
		if p == page then
			p:Show()
			p.tab:LockHighlight()
			p.tab.text:SetTextColor(1, 1, 1)
		else
			p:Hide()
			p.tab:UnlockHighlight()
			p.tab.text:SetTextColor(0.8, 0.8, 0.8)
		end
	end
	win.current = page
end

local function AddTab(win, page)
	local index = #win.pages + 1
	local tab = CreateFrame("Button", nil, win.sidebar)
	tab:SetWidth(SIDEBAR_W - 16)
	tab:SetHeight(24)
	tab:SetPoint("TOPLEFT", win.sidebar, "TOPLEFT", 8, -8 - (index - 1) * 26)
	tab:SetBackdrop(FLAT)
	tab:SetBackdropColor(1, 1, 1, 0.04)
	tab:SetBackdropBorderColor(1, 1, 1, 0.08)
	local hl = tab:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints(tab)
	hl:SetTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.18)
	tab:SetHighlightTexture(hl)
	tab.text = tab:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	tab.text:SetPoint("LEFT", tab, "LEFT", 10, 0)
	tab.text:SetText(L[page.title])
	tab:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		SelectPage(win, page)
	end)
	page.tab = tab
	win.pages[index] = page
end

local function NewPage(win, title)
	return W.Page(win, title)
end

----------------------------------------------------------------
-- Suche
----------------------------------------------------------------
local function CreateSearch(win)
	local box = CreateFrame("EditBox", W.NextName(), win.sidebar, "InputBoxTemplate")
	box:SetWidth(SIDEBAR_W - 24)
	box:SetHeight(20)
	box:SetAutoFocus(false)
	box:SetFontObject(ChatFontSmall)
	box:SetPoint("BOTTOMLEFT", win.sidebar, "BOTTOMLEFT", 14, 8)
	local label = win.sidebar:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	label:SetPoint("BOTTOMLEFT", box, "TOPLEFT", -4, 2)
	label:SetText(L["Search settings"])
	box:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	box:SetScript("OnTextChanged", function(self, user)
		if not user then return end
		local hits = W.Search(self:GetText())
		if #hits == 0 then
			if BetterPlatesMenu then BetterPlatesMenu:Hide() end
			return
		end
		local items = {}
		for i, w in ipairs(hits) do
			items[i] = { text = "|cff888888" .. L[w.page.title] .. ":|r " .. L[w.label], value = w }
		end
		W.ShowMenu(self, items, nil, function(w)
			SelectPage(win, w.page)
			W.Flash(w)
			box:SetText("")
			box:ClearFocus()
		end)
	end)
	win.search = box
end

----------------------------------------------------------------
-- Seiten
----------------------------------------------------------------
local function PageGeneral(win)
	local pg = NewPage(win, "General")
	Header(pg, 1, "Quick setup")
	PageButton(pg, 1, "Preset: PvP Arena", function()
		P:ApplyPreset(P:PresetByName("PvP Arena"))
		RefreshPage(pg)
		ns:Print(L["Preset applied: PvP Arena. Arena and battleground zone rules were written too (Zones page)."])
	end, "Complete arena/BG setup: enemies big with class icons, DR, auras, lockouts, trinket & kick timers, emphasized arena casts with sound, friends as names only in PvP, stacking off. Also writes arena/BG zone rules.")
	PageButton(pg, 1, "Preset: PvE Raid", function()
		P:ApplyPreset(P:PresetByName("PvE Raid"))
		RefreshPage(pg)
		ns:Print(L["Preset applied: PvE Raid. Raid and dungeon zone rules were written too (Zones page)."])
	end, "Complete raid/dungeon setup: threat colors (DPS/Healer), important adds highlighted, bosses bigger, my debuffs, HoTs and dispels on friends, stacking on, no PvP auras/DR, dungeon kicks emphasized. Also writes raid/dungeon zone rules.")
	Note(pg, 1, "Tip: create a copy of your profile first (Profiles page) if you want to keep your current settings.", 40)
	Header(pg, 1, "Size & Font")
	Slider(pg, 1, "Width", "width", 60, 220, 2)
	Slider(pg, 1, "Height", "height", 4, 30, 1)
	Slider(pg, 1, "Target scale", "targetScale", 1, 1.6, 0.05, "%.2f")
	Slider(pg, 1, "Font size", "fontSize", 6, 20, 1)
	Dropdown(pg, 1, "Font", "font", ns.fonts)
	EditLine(pg, 1, "Custom font path (optional)", "customFont", "Example: Interface\\AddOns\\SharedMedia\\fonts\\Expressway.ttf. Leave empty to use the font above.")
	Check(pg, 1, "Font outline", "outline")
	Check(pg, 1, "Font shadow", "fontShadow", "Only when outline is off.")

	Header(pg, 2, "Layout")
	Check(pg, 2, "Stack nameplates instead of overlapping", "stacking",
		"Overlapping nameplates move up; your target stays in place. The 3.3.5a client cannot do this itself. Note: clicking still works at the original spot above the head.")
	Check(pg, 2, "Stack in arena and battlegrounds too", "stackingPvP",
		"Off by default: in PvP you click nameplates, and a shifted display no longer matches the click area.")
	Check(pg, 2, "Stack in dungeons and raids", "stackingRaid")
	Slider(pg, 2, "Stack spacing", "stackSpacing", 0, 12, 1)
	Slider(pg, 2, "Maximum stack height", "stackMaxHeight", 50, 400, 10)
	Header(pg, 2, "Misc")
	Check(pg, 2, "Minimap button", "minimapButton", "Left-click: settings, right-click: toggle friendly nameplates, middle-click: toggle stacking.")
	Slider(pg, 2, "Update interval (seconds)", "updateRate", 0.05, 0.3, 0.01, "%.2f")
	Note(pg, 2, "Lower = smoother, higher = less CPU. 0.10 is a good default.", 30)
	return pg
end

local function PageStyle(win)
	local pg = NewPage(win, "Style")
	Header(pg, 1, "Bars")
	Dropdown(pg, 1, "Texture", "texture", ns.textures)
	EditLine(pg, 1, "Custom texture path (optional)", "customTexture", "Example: Interface\\AddOns\\SharedMedia\\statusbar\\Smooth. Leave empty to use the texture above.")
	Dropdown(pg, 1, "Border style", "borderStyle", { "None", "Thin", "Thick", "Glow" })
	Dropdown(pg, 1, "Background", "bgStyle", { "Dark", "Class-tinted", "Transparent" })
	Slider(pg, 1, "Background opacity", "bgAlpha", 0, 1, 0.05, "%.2f")
	Check(pg, 1, "Health gradient on NPCs (green to red)", "healthGradient")
	Header(pg, 1, "Health text")
	Dropdown(pg, 1, "Health text", "healthText", ns.healthTextModes)
	Dropdown(pg, 1, "Health text position", "healthTextPos", { "Center", "Left", "Right" })
	Slider(pg, 1, "Health text size", "healthFontSize", 6, 18, 1)
	Check(pg, 1, "Percent with one decimal", "healthDecimals")
	Check(pg, 1, "Health text only on target", "healthTextOnlyTarget")
	Header(pg, 1, "Target & mouseover")
	Dropdown(pg, 1, "Target highlight", "targetStyle", { "Border", "Glow", "Border + Glow" })
	Check(pg, 1, "Arrows next to the target", "targetArrows")
	Check(pg, 1, "White border around the target", "targetBorder")
	Slider(pg, 1, "Dim non-targets", "nonTargetAlpha", 0.3, 1, 0.05, "%.2f")
	Check(pg, 1, "Mouseover border", "mouseoverHighlight")

	Header(pg, 2, "Names")
	Check(pg, 2, "Name inside the bar", "nameInBar")
	Check(pg, 2, "Hide names (bars only)", "hideName")
	Check(pg, 2, "Hide name while casting", "hideNameOnCast")
	Slider(pg, 2, "Maximum name length (0 = off)", "nameMaxLen", 0, 30, 1)
	Check(pg, 2, "Abbreviate long NPC names", "abbrevNames", "\"Lord Marrowgar\" becomes \"L. Marrowgar\".")
	Check(pg, 2, "Remove realm from names", "stripRealm")
	Check(pg, 2, "Class color on names", "nameClassColor")
	Header(pg, 2, "Level")
	Check(pg, 2, "Hide level", "hideLevel")
	Check(pg, 2, "Hide level on max-level players", "hideLevelMaxPlayers")
	Check(pg, 2, "Level in difficulty color", "levelColor")
	Check(pg, 2, "Elite marker (+)", "eliteMark")
	Check(pg, 2, "Bosses: bigger plate and ?? level", "bossBig")
	Header(pg, 2, "Raid icon")
	Dropdown(pg, 2, "Raid icon position", "raidIconPos", { "Right", "Left", "Above name", "Hidden" })
	Slider(pg, 2, "Raid icon size", "raidIconSize", 10, 40, 1)
	Header(pg, 2, "Presets")
	for i, preset in ipairs(P.PRESETS) do
		PageButton(pg, 2, preset.name, function()
			P:ApplyPreset(i)
			RefreshPage(pg)
			ns:Print(format(L["Preset applied: %s"], L[preset.name]))
		end, preset.desc)
	end
	return pg
end

local function PageColors(win)
	local pg = NewPage(win, "Colors")
	Header(pg, 1, "Bars")
	ColorPick(pg, 1, "Hostile NPC", "colors.hostile")
	ColorPick(pg, 1, "Neutral NPC", "colors.neutral")
	ColorPick(pg, 1, "Friendly NPC", "colors.friendlyNpc")
	ColorPick(pg, 1, "Friendly player (no class color)", "colors.friendlyPlayer")
	ColorPick(pg, 1, "Enemy player (no class color)", "colors.enemyPlayer")
	Check(pg, 1, "Class color on enemy players", "classColorEnemy")
	Check(pg, 1, "Class color on friendly players", "classColorFriendly",
		"Classes are known for your group and for players seen in the combat log, chat, guild, friends list, or targeted/moused over.")
	ColorPick(pg, 1, "Background", "colors.bg")
	ColorPick(pg, 1, "Border", "colors.border")
	ColorPick(pg, 1, "Execute", "colors.execute")
	ColorPick(pg, 1, "Low health flash (friends)", "colors.lowHealth")
	Header(pg, 1, "Borders & glow")
	ColorPick(pg, 1, "Target", "colors.target")
	ColorPick(pg, 1, "Focus", "colors.focus")
	ColorPick(pg, 1, "Friendly player border", "colors.friendBorder")
	ColorPick(pg, 1, "Mouseover", "colors.mouseover")

	Header(pg, 2, "Cast bar")
	ColorPick(pg, 2, "Cast", "colors.castNormal")
	ColorPick(pg, 2, "Channel", "colors.castChannel")
	ColorPick(pg, 2, "Not interruptible", "colors.castNoInt")
	ColorPick(pg, 2, "Emphasized", "colors.castEmph")
	ColorPick(pg, 2, "Interrupted", "colors.castInterrupted")
	Header(pg, 2, "Threat")
	ColorPick(pg, 2, "Has aggro (DPS) / lost aggro (tank)", "colors.threatAggro")
	ColorPick(pg, 2, "Warning", "colors.threatWarn")
	ColorPick(pg, 2, "Safe (tank)", "colors.threatSafe")
	Header(pg, 2, "Raid & PvP")
	ColorPick(pg, 2, "Raid NPC priority 1", "colors.raidNpc1")
	ColorPick(pg, 2, "Raid NPC priority 2", "colors.raidNpc2")
	ColorPick(pg, 2, "Alliance flag carrier", "colors.flagAlliance")
	ColorPick(pg, 2, "Horde flag carrier", "colors.flagHorde")
	Note(pg, 2, "Right-click a color to reset it to default.", 30)
	return pg
end

local function PagePositions(win)
	local pg = NewPage(win, "Positions")
	Note(pg, 1, "Pixel offsets relative to the default position of each element.", 30)
	Header(pg, 1, "Texts")
	Slider(pg, 1, "Name X", "nameX", -60, 60, 1)
	Slider(pg, 1, "Name Y", "nameY", -30, 30, 1)
	Slider(pg, 1, "Health text X", "healthX", -60, 60, 1)
	Slider(pg, 1, "Health text Y", "healthY", -30, 30, 1)
	Header(pg, 1, "Cast bar")
	Slider(pg, 1, "Cast bar X", "castX", -60, 60, 1)
	Slider(pg, 1, "Cast bar Y", "castY", -30, 30, 1)
	Header(pg, 1, "Raid icon")
	Slider(pg, 1, "Raid icon X", "raidX", -60, 60, 1)
	Slider(pg, 1, "Raid icon Y", "raidY", -30, 30, 1)

	Header(pg, 2, "Icons above the plate")
	Slider(pg, 2, "Class icon X", "classIconX", -60, 60, 1)
	Slider(pg, 2, "Class icon Y", "classIconY", -30, 30, 1)
	Slider(pg, 2, "Auras X", "aurasX", -60, 60, 1)
	Slider(pg, 2, "Auras Y", "aurasY", -30, 30, 1)
	Slider(pg, 2, "DR icons X", "drX", -60, 60, 1)
	Slider(pg, 2, "DR icons Y", "drY", -30, 30, 1)
	Slider(pg, 2, "Totem icon X", "totemX", -60, 60, 1)
	Slider(pg, 2, "Totem icon Y", "totemY", -30, 30, 1)
	Slider(pg, 2, "Party pointer X", "partyX", -60, 60, 1)
	Slider(pg, 2, "Party pointer Y", "partyY", -30, 30, 1)
	Slider(pg, 2, "Targeted-by X", "targetedX", -60, 60, 1)
	Slider(pg, 2, "Targeted-by Y", "targetedY", -30, 30, 1)
	return pg
end

local function PageFriendFoe(win)
	local pg = NewPage(win, "Friend & Foe")
	Header(pg, 1, "Friendly players")
	Check(pg, 1, "Green border around friendly players", "friendlyBorder",
		"Enemies keep a black border; your target white, focus orange.")
	Slider(pg, 1, "Size of friendly nameplates", "friendlyScale", 0.5, 1, 0.05, "%.2f")
	Check(pg, 1, "Friends: names only, no bar", "friendlyNameOnly",
		"Friendly players and NPCs show only their name (class colored). Your target keeps its bar.")
	Check(pg, 1, "Names only in battlegrounds & arena", "friendlyNameOnlyPvP",
		"Switches friends to \"names only\" automatically while you are in a battleground or arena.")
	Check(pg, 1, "Friends: class icon instead of name", "friendlyClassIconOnly",
		"With \"names only\": friendly players with a known class show just their class icon (battleground style).")
	Check(pg, 1, "Friends: only my group members", "friendlyOnlyGroup",
		"Friendly players outside your party/raid get an invisible nameplate.")
	Check(pg, 1, "Low health flash on friends", "lowHealthFlash")
	Slider(pg, 1, "Low health threshold", "lowHealthPct", 10, 60, 5, "%d%%")
	Header(pg, 1, "Names")
	Check(pg, 1, "Name color: friends green, enemies red", "nameReactionColor",
		"Overrides class-colored names for players.")

	Header(pg, 2, "NPCs")
	Dropdown(pg, 2, "Trivial (grey level) NPCs", "trivialMode", { "Normal", "Fade", "Small", "Hide" })
	Check(pg, 2, "Hide critters", "hideCritters", "Rats, rabbits, frogs and the like.")
	Check(pg, 2, "Murloc mode", "murlocMode", "All NPC names become Mrglglgl. For fun.")
	Header(pg, 2, "Tips")
	Note(pg, 2, "Class colors look the same on both sides. Pick what tells them apart for you: the green border (default), smaller friendly plates, or friends as names only.", 70)
	Note(pg, 2, "Fastest for PvP: hide friendly nameplates completely. Use the Blizzard page, the V / Shift+V keys, the BetterPlates key binding \"Toggle friendly nameplates\", or a zone rule (Zones page).", 80)
	return pg
end

local function PageIndicators(win)
	local pg = NewPage(win, "Indicators")
	Header(pg, 1, "Target & Focus")
	Check(pg, 1, "Orange border around the focus", "focusIndicator")
	Header(pg, 1, "Totems & Pets")
	Check(pg, 1, "Highlight important totems", "totemIndicator",
		"Tremor, Grounding, Cleansing, Earthbind, Mana Tide, Elementals, Shadowfiend, Gargoyle, Lightwell: large icon with colored border.")
	Check(pg, 1, "Icon on all totems", "allTotemIcons",
		"Every totem (friendly too) shows its spell icon, smaller and with a black border. Important enemy totems keep the large colored icon.")
	Check(pg, 1, "Totem timers", "totemTimers", "Remaining duration from the combat log (summon time + known totem duration).")
	Slider(pg, 1, "Totem icon size", "totemSize", 16, 48, 1)
	Check(pg, 1, "Hide unimportant totems", "hideOtherTotems")
	Check(pg, 1, "Smaller nameplates for pets", "smallPets",
		"Water Elemental, Mirror Images, Treants, Spirit Wolves, ghouls, snakes: 70% size.")

	Header(pg, 2, "Players")
	Check(pg, 2, "Class icon on enemies", "classIconEnemy")
	Check(pg, 2, "Class icon on friends", "classIconFriendly")
	Slider(pg, 2, "Class icon size", "classIconSize", 12, 40, 1)
	Check(pg, 2, "Mark healers", "healerIndicator",
		"Detects healers by typical healer spells in the combat log (e.g. Penance, Holy Shock, Riptide, Wild Growth).")
	Check(pg, 2, "Party pointer arrows", "partyPointer",
		"Colored arrow above your party members' nameplates (1 red, 2 green, 3 blue, 4 yellow).")
	Header(pg, 2, "Execute")
	Check(pg, 2, "Execute marker", "execute", "Line on the bar at the threshold; health text turns red below it.")
	Check(pg, 2, "Color bar below threshold", "executeColor")
	Slider(pg, 2, "Execute threshold", "executePct", 5, 50, 1, "%d%%")
	return pg
end

local function PageCasts(win)
	local pg = NewPage(win, "Cast bar")
	Header(pg, 1, "Cast bar")
	Check(pg, 1, "Own cast bar", "castbar")
	Slider(pg, 1, "Height", "castHeight", 4, 20, 1)
	Check(pg, 1, "Spell icon", "castIcon")
	Dropdown(pg, 1, "Icon side", "castIconSide", { "Left", "Right" })
	Check(pg, 1, "Remaining time", "castTimer")
	Dropdown(pg, 1, "Timer format", "castTimerFormat", { "Remaining", "Remaining / total", "Percent" })
	Check(pg, 1, "Spell name", "castName", "The 3.3.5a client only provides the name for target, focus, mouseover and arena opponents; all others come from the combat log.")
	Slider(pg, 1, "Maximum spell name length (0 = off)", "castNameMaxLen", 0, 30, 1)

	Header(pg, 2, "Interrupts")
	Check(pg, 2, "Interrupt icon (ready / on cooldown)", "castInterruptIcon",
		"Shows your interrupt next to interruptible cast bars: green border = ready, red = on cooldown.")
	Check(pg, 2, "Cooldown seconds on the interrupt icon", "kickCdText")
	Check(pg, 2, "Show \"Interrupted by ...\"", "castInterrupted",
		"When a cast is interrupted, the bar turns red for a moment and names the interrupter.")
	Header(pg, 2, "Alerts")
	Check(pg, 2, "Sound on emphasized casts", "castSound", "Plays the chosen sound when a cast from your emphasize list starts (see Lists).")
	Dropdown(pg, 2, "Alert sound", "castSoundId", ns.SOUNDS)
	PageButton(pg, 2, "Play sound", function() ns.PlayAlert(ns.db.castSoundId) end)
	Note(pg, 2, "Grey = not interruptible, yellow = cast, green = channel, red = emphasized (see Lists). Your target uses Blizzard's exact cast data; all other plates get a cast bar from the combat log.", 70)
	return pg
end

local function PageAuras(win)
	local pg = NewPage(win, "Auras")
	Header(pg, 1, "What to show")
	Check(pg, 1, "Show auras", "auras")
	Check(pg, 1, "My debuffs", "myDebuffs")
	Check(pg, 1, "PvP: crowd control, immunities, buffs", "pvpAuras",
		"Stuns, polymorph, fear, silence, roots, Divine Shield, Ice Block etc. - from anyone.")
	Check(pg, 1, "Interrupt lockout as aura", "lockoutAura",
		"After a kick, counterspell etc. the locked spell school is shown as a blue-bordered aura with the lockout duration.")
	Check(pg, 1, "My HoTs / buffs on friends", "myBuffsOnFriends",
		"Rejuvenation, Renew, Riptide, Earth Shield, Beacon, Shield, Lifebloom stacks and more - only your own.")
	Check(pg, 1, "Dispellable debuffs on group members", "dispelIndicator",
		"Party members: debuffs your class can remove (Magic blue, Curse purple, Poison green, Disease brown).")
	Check(pg, 1, "... show all debuff types, not only mine to dispel", "dispelAll")
	Check(pg, 1, "Auras only on the target", "auraOnlyTarget")
	Header(pg, 1, "Categories")
	Check(pg, 1, "Stuns", "auraCats.stun")
	Check(pg, 1, "Crowd control", "auraCats.cc")
	Check(pg, 1, "Silences", "auraCats.silence")
	Check(pg, 1, "Roots", "auraCats.root")
	Check(pg, 1, "Disarms", "auraCats.disarm")
	Check(pg, 1, "Immunities", "auraCats.immune")
	Check(pg, 1, "Important buffs", "auraCats.buff")

	Header(pg, 2, "Layout")
	Slider(pg, 2, "Icon size", "auraSize", 12, 40, 1)
	Slider(pg, 2, "Maximum count", "maxAuras", 1, 12, 1)
	Dropdown(pg, 2, "Rows", "auraRows", { { "1", value = 1 }, { "2", value = 2 } })
	Dropdown(pg, 2, "Grow direction", "auraGrow", { "Centered", "Left to right", "Right to left" })
	Slider(pg, 2, "Spacing", "auraSpacing", 0, 8, 1)
	Check(pg, 2, "Remaining time as number", "auraTimer")
	Check(pg, 2, "Stack count", "auraStacks")
	Check(pg, 2, "My auras first", "auraMineFirst")
	Check(pg, 2, "Pandemic: my DoTs turn red below 30% time", "pandemic")
	Header(pg, 2, "Lists")
	EditLine(pg, 2, "Key auras (shown 40% larger)", "keyAuraList",
		"Spell IDs or names, comma separated. Example: Divine Shield, 45438, Deterrence", function() ns:RebuildAuraLists() end)
	EditLine(pg, 2, "Extra auras (spell IDs or names)", "auraWhitelist",
		"Always show these auras from anyone, with a white border. Example: 48108, Living Bomb", function() ns:RebuildAuraLists() end)
	EditLine(pg, 2, "Never show (spell IDs or names)", "auraBlacklist",
		"These auras are never shown on nameplates.", function() ns:RebuildAuraLists() end)
	Note(pg, 2, "Players are tracked via the combat log, NPCs once you target or mouse over them.", 30)
	return pg
end

local function PageDR(win)
	local pg = NewPage(win, "Diminishing Returns")
	Header(pg, 1, "Tracking")
	Check(pg, 1, "Show diminishing returns", "dr",
		"Tracks CC categories per enemy from the combat log: after 1 application the next lasts 1/2, then 1/4, then immune. Resets 18 s after the effect ends.")
	Slider(pg, 1, "Icon size", "drSize", 12, 36, 1)
	Check(pg, 1, "Only enemies", "drOnlyEnemies")
	Check(pg, 1, "Only players", "drOnlyPlayers")
	Check(pg, 1, "Also in the open world and dungeons", "drInWorld", "By default DR icons are shown in arena and battlegrounds only.")
	Note(pg, 1, "Colors: green = next lasts half, yellow = quarter, red = immune. The number below is the reset timer.", 50)

	Header(pg, 2, "Categories")
	local names = ns.DR_CATEGORY_NAMES or {}
	for _, cat in ipairs(ns.DR.catOrder) do
		local n = names[cat]
		local label = n and (GetLocale() == "deDE" and n.de or n.en) or cat
		Check(pg, 2, label, "drCats." .. cat)
	end
	return pg
end

local function PageLists(win)
	local pg = NewPage(win, "Lists")
	Header(pg, 1, "Cast bars")
	EditLine(pg, 1, "Emphasize casts (spell IDs or names)", "castEmphasisList",
		"These casts get a red, taller bar so you never miss them. Example: Polymorph, 48785, Cyclone", function() ns:RebuildAuraLists() end)
	EditLine(pg, 1, "Hide cast bars for (spell IDs or names)", "castHideList",
		"No cast bar is shown for these spells.", function() ns:RebuildAuraLists() end)
	Note(pg, 1, "Spell IDs or names, comma separated. Names must match your client language.", 40)
	Header(pg, 1, "Quick fill")
	PageButton(pg, 1, "Add arena casts to emphasize list", function()
		local add = "Polymorph, Fear, Cyclone, Hex, Repentance, Mind Control, Seduction, Mana Burn, Drain Mana, Entangling Roots, Chaos Bolt, Lava Burst, Greater Heal, Healing Wave, Chain Heal, Penance, Holy Light, Regrowth, Nourish, Resurrection"
		local cur = ns.db.castEmphasisList or ""
		ns:Set("castEmphasisList", cur ~= "" and (cur .. ", " .. add) or add, true)
		ns:RebuildAuraLists() ns:Refresh() RefreshPage(pg)
	end, "Appends common arena casts (English names - edit for a German client).")
	PageButton(pg, 1, "Add dungeon kicks to emphasize list", function()
		local add = "Shadow Bolt Volley, Heal, Frostbolt, Chain Heal, Mind Flay, Flash Heal, Greater Heal, Fireball, Shadow Bolt, Arcane Blast, Lightning Bolt, Holy Light"
		local cur = ns.db.castEmphasisList or ""
		ns:Set("castEmphasisList", cur ~= "" and (cur .. ", " .. add) or add, true)
		ns:RebuildAuraLists() ns:Refresh() RefreshPage(pg)
	end, "Appends casts worth interrupting in 5-man dungeons (English names).")
	PageButton(pg, 1, "Clear emphasize list", function()
		ns:Set("castEmphasisList", "", true) ns:RebuildAuraLists() ns:Refresh() RefreshPage(pg)
	end)

	Header(pg, 2, "NPCs")
	EditLine(pg, 2, "Hide nameplates of (NPC names)", "hideNpcList",
		"These NPCs get an invisible nameplate (still clickable). Example: Snake Trap snakes, Explosive Decoy", function() ns:RebuildAuraLists() end)
	EditLine(pg, 2, "Fade nameplates of (NPC names)", "fadeNpcList",
		"These NPCs are shown at 30% opacity.", function() ns:RebuildAuraLists() end)
	EditLine(pg, 2, "Color NPCs (Name:rrggbb)", "colorNpcList",
		"Custom bar color per NPC. Example: Shadowfiend:aa33ff, Training Dummy:00ff00", function() ns:RebuildAuraLists() end)
	EditLine(pg, 2, "Extra raid NPCs (Name or Name:2)", "raidNpcCustom",
		"Added to the built-in raid NPC list. Priority 1 (default) = red glow, Name:2 = yellow border.", function() ns:RebuildAuraLists() end)
	Note(pg, 2, "Your current target is never hidden or faded. Names are not case sensitive.", 40)
	return pg
end

local function PageRaid(win)
	local pg = NewPage(win, "Raid & Dungeon")
	Header(pg, 1, "Threat")
	Dropdown(pg, 1, "Threat mode", "threatMode", { "Off", "DPS / Healer", "Tank" })
	Note(pg, 1, "DPS/Healer: red = you have aggro, orange = about to pull. Tank: green = secure aggro, orange = losing it. Based on the client's threat glow (works for every NPC in combat).", 70)
	Check(pg, 1, "Threat percent on the target's health text", "threatPercent")
	Check(pg, 1, "Threat color (raw Blizzard glow color)", "threatColor", "Simple mode: colors NPC bars with the glow color. Ignored when a threat mode is active.")
	Header(pg, 1, "Bosses & adds")
	Check(pg, 1, "Highlight important raid & dungeon NPCs", "raidNpcHighlight",
		"Built-in list for Naxxramas, Ulduar, ToC, ICC, Ruby Sanctum, OS, Onyxia and the ICC 5-mans. Priority 1: red glow and bigger plate; priority 2: yellow border.")
	Check(pg, 1, "Bosses: bigger plate", "bossBig")
	Note(pg, 1, "Add your own NPCs on the Lists page.", 24)

	Header(pg, 2, "Healing")
	Check(pg, 2, "My HoTs / buffs on friends", "myBuffsOnFriends")
	Check(pg, 2, "Dispellable debuffs on group members", "dispelIndicator")
	Check(pg, 2, "Low health flash on friends", "lowHealthFlash")
	Header(pg, 2, "Declutter")
	Note(pg, 2, "Use the Zones page to turn off friendly plates, pets, totems and auras in raids automatically - or apply the preset below.", 50)
	PageButton(pg, 2, "Preset: PvE Raid", function()
		P:ApplyPreset(P:PresetByName("PvE Raid"))
		RefreshPage(pg)
	end, "Complete raid/dungeon setup incl. zone rules.")
	PageButton(pg, 2, "Preset: Raid Minimal", function()
		for i, p in ipairs(P.PRESETS) do if p.name == "Raid Minimal" then P:ApplyPreset(i) end end
		RefreshPage(pg)
	end)
	PageButton(pg, 2, "Preset: Healer", function()
		for i, p in ipairs(P.PRESETS) do if p.name == "Healer" then P:ApplyPreset(i) end end
		RefreshPage(pg)
	end)
	return pg
end

local function PagePvP(win)
	local pg = NewPage(win, "PvP")
	Header(pg, 1, "Battleground")
	Check(pg, 1, "Flag carrier highlight", "flagCarrier",
		"Warsong Gulch / Eye of the Storm: the carrier gets a flag icon, a colored glow and a bigger plate.")
	Check(pg, 1, "Sound when an enemy picks up the flag", "flagSound")
	Check(pg, 1, "Healer priority: dim enemy non-healers", "healerPriority")
	Check(pg, 1, "Targeted-by counter", "targetedBy",
		"Shows how many of your party/raid members target this enemy (colored squares in a party, a number in a raid).")
	Dropdown(pg, 1, "Targeted-by style", "targetedByStyle", { "Squares", "Number" })
	Header(pg, 1, "Arena")
	Check(pg, 1, "Arena numbers instead of names", "arenaNumbers")
	Check(pg, 1, "Enemy targets me / my party (arena)", "enemyTargetIndicator",
		"Shows YOU (red) or the party number next to an arena opponent who targets you or a party member.")
	Check(pg, 1, "PvP trinket used (2 min timer)", "trinketIndicator")
	Check(pg, 1, "Diminishing returns", "dr")

	Header(pg, 2, "Recommended PvP setup")
	Note(pg, 2, "Friends as names only in BG/arena, class icons on enemies, DR on, emphasized arena casts with sound, stacking off. The PvP Big preset sets most of this.", 70)
	PageButton(pg, 2, "Preset: PvP Arena", function()
		P:ApplyPreset(P:PresetByName("PvP Arena"))
		RefreshPage(pg)
	end, "Complete arena/BG setup incl. zone rules.")
	PageButton(pg, 2, "Preset: PvP Big", function()
		for i, p in ipairs(P.PRESETS) do if p.name == "PvP Big" then P:ApplyPreset(i) end end
		RefreshPage(pg)
	end)
	Note(pg, 2, "Arena numbers, healer marks and interrupt lockouts come from the combat log - no unit link is needed.", 50)
	return pg
end

local function PageZones(win)
	local pg = NewPage(win, "Zones")
	local zoneIdx = 1
	local function Zone() return P.ZONES[zoneIdx] end
	Note(pg, 1, "Rules per zone type override the profile while you are in that zone. \"Profile\" means no override. Orange labels on other pages show an active override.", 60)
	local sel = CreateFrame("Button", W.NextName(), pg.content, "UIPanelButtonTemplate")
	sel:SetWidth(W.COL_W - 24)
	sel:SetHeight(24)
	W.Place(pg, sel, 1, 32, 4)
	sel.Refresh = function(self)
		local cur = P:CurrentZone()
		self:SetText(L["Zone"] .. ": " .. L[P.ZONE_LABELS[Zone()]] .. (Zone() == cur and ("  |cff33ff33(" .. L["you are here"] .. ")|r") or ""))
	end
	sel:SetScript("OnClick", function(self)
		local items = {}
		for i, z in ipairs(P.ZONES) do items[i] = { text = L[P.ZONE_LABELS[z]], value = i } end
		W.ShowMenu(self, items, zoneIdx, function(v)
			zoneIdx = v
			RefreshPage(pg)
		end)
	end)
	pg.widgets[#pg.widgets + 1] = sel
	Space(pg, 1, 6)
	Header(pg, 1, "Blizzard nameplates in this zone")
	local col = 1
	local n = 0
	for _, def in ipairs(P.ZONE_KEYS) do
		if def.cvar then
			W.Override(pg, 1, def, Zone)
		end
	end
	Header(pg, 2, "BetterPlates features in this zone")
	for _, def in ipairs(P.ZONE_KEYS) do
		if not def.cvar then
			W.Override(pg, 2, def, Zone)
		end
	end
	PageButton(pg, 1, "Clear all rules for this zone", function()
		local zt = P.profile.zones[Zone()]
		wipe(zt)
		P:ApplyZone()
		RefreshPage(pg)
	end)
	PageButton(pg, 1, "Suggested raid rules", function()
		local z = "raid"
		P:SetOverride(z, "cvar:nameplateShowFriends", false)
		P:SetOverride(z, "cvar:nameplateShowFriendlyPets", false)
		P:SetOverride(z, "cvar:nameplateShowEnemyPets", false)
		P:SetOverride(z, "cvar:nameplateShowFriendlyTotems", false)
		P:SetOverride(z, "pvpAuras", false)
		P:SetOverride(z, "dr", false)
		P:SetOverride(z, "stacking", false)
		P:SetOverride(z, "threatMode", 2)
		P:SetOverride(z, "raidNpcHighlight", true)
		zoneIdx = 3
		RefreshPage(pg)
	end, "Raid: no friendly plates, no pets/totems, no PvP auras, no DR, threat mode DPS/Healer, raid NPC highlight on.")
	PageButton(pg, 1, "Suggested arena rules", function()
		local z = "arena"
		P:SetOverride(z, "cvar:nameplateShowEnemies", true)
		P:SetOverride(z, "cvar:nameplateShowFriends", true)
		P:SetOverride(z, "friendlyNameOnly", true)
		P:SetOverride(z, "dr", true)
		P:SetOverride(z, "arenaNumbers", true)
		P:SetOverride(z, "stacking", false)
		P:SetOverride(z, "classIconEnemy", true)
		P:SetOverride(z, "raidNpcHighlight", false)
		zoneIdx = 5
		RefreshPage(pg)
	end, "Arena: friends as names only, DR on, arena numbers, class icons on enemies, stacking off.")
	return pg
end

local function PageProfiles(win)
	local pg = NewPage(win, "Profiles")
	Header(pg, 1, "Active profile")
	local cur = CreateFrame("Button", W.NextName(), pg.content, "UIPanelButtonTemplate")
	cur:SetWidth(W.COL_W - 24)
	cur:SetHeight(24)
	W.Place(pg, cur, 1, 30, 4)
	cur.Refresh = function(self) self:SetText(L["Profile"] .. ": " .. tostring(P.name)) end
	cur:SetScript("OnClick", function(self)
		local items = {}
		for i, n in ipairs(P:GetNames()) do items[i] = { text = n, value = n } end
		W.ShowMenu(self, items, P.name, function(v)
			if P:Activate(v) then
				P:ApplyZone()
				ns:Print(format(L["Profile %s activated."], v))
				RefreshPage(pg)
			end
		end)
	end)
	pg.widgets[#pg.widgets + 1] = cur
	Note(pg, 1, "Each character remembers its own profile choice. Profiles themselves are shared by all characters on this account.", 44)

	Header(pg, 1, "Manage")
	local nameBox
	local fs = pg.content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	W.Place(pg, fs, 1, 16, 4)
	fs:SetText(L["New profile name"])
	nameBox = CreateFrame("EditBox", W.NextName(), pg.content, "InputBoxTemplate")
	nameBox:SetWidth(W.COL_W - 30)
	nameBox:SetHeight(22)
	nameBox:SetAutoFocus(false)
	nameBox:SetFontObject(ChatFontNormal)
	W.Place(pg, nameBox, 1, 30, 10)
	nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	local function NewName()
		local n = (nameBox:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if n == "" then ns:Print(L["Enter a profile name first."]) return end
		return n
	end
	ButtonPair(pg, 1, "Create (defaults)", function()
		local n = NewName() if not n then return end
		if P:Create(n) then P:Activate(n) P:ApplyZone() nameBox:SetText("") RefreshPage(pg) else ns:Print(L["A profile with this name already exists."]) end
	end, "Copy current", function()
		local n = NewName() if not n then return end
		if P:Create(n, P.name) then P:Activate(n) P:ApplyZone() nameBox:SetText("") RefreshPage(pg) else ns:Print(L["A profile with this name already exists."]) end
	end)
	ButtonPair(pg, 1, "Rename current", function()
		local n = NewName() if not n then return end
		if P:Rename(P.name, n) then nameBox:SetText("") RefreshPage(pg) else ns:Print(L["Cannot rename: name taken or Default profile."]) end
	end, "Delete current", function()
		if P.name == P.DEFAULT_NAME then ns:Print(L["The Default profile cannot be deleted."]) return end
		local victim = P.name
		P:Activate(P.DEFAULT_NAME)
		P:ApplyZone()
		local dlg = StaticPopup_Show("BETTERPLATES_DELETE_PROFILE", victim)
		if dlg then dlg.data = victim end
		RefreshPage(pg)
	end)
	PageButton(pg, 1, "Reset current profile to defaults", function() StaticPopup_Show("BETTERPLATES_RESET") end)

	Header(pg, 2, "Export")
	local exportArea, exportBox = EditArea(pg, 2, "Export string (click, Ctrl+A, Ctrl+C)", 90, function() return P:Export(true) end)
	exportBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	PageButton(pg, 2, "Refresh export string", function() exportArea:Refresh() end)
	Header(pg, 2, "Import")
	local importArea, importBox = EditArea(pg, 2, "Paste an import string here", 90)
	local importName = CreateFrame("EditBox", W.NextName(), pg.content, "InputBoxTemplate")
	importName:SetWidth(W.COL_W - 30)
	importName:SetHeight(22)
	importName:SetAutoFocus(false)
	importName:SetFontObject(ChatFontNormal)
	local fs2 = pg.content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	W.Place(pg, fs2, 2, 16, 4)
	fs2:SetText(L["Import into new profile (empty = current)"])
	W.Place(pg, importName, 2, 30, 10)
	importName:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	importName:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	PageButton(pg, 2, "Import", function()
		local str = importBox:GetText() or ""
		local into = (importName:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
		local ok, info = P:Import(str, into ~= "" and into or nil)
		if ok then
			ns:Print(format(L["Import successful: %d settings."], info))
			if into ~= "" then P:Activate(into) P:ApplyZone() end
			importBox:SetText("")
			RefreshPage(pg)
			ns:Refresh()
		else
			ns:Print(L["Import failed"] .. ": " .. tostring(info))
		end
	end)
	return pg
end

local function PageBlizzard(win)
	local pg = NewPage(win, "Blizzard")
	Header(pg, 1, "Friendly nameplates")
	CVarCheck(pg, 1, "Friendly players & NPCs", "nameplateShowFriends")
	CVarCheck(pg, 1, "Friendly pets", "nameplateShowFriendlyPets")
	CVarCheck(pg, 1, "Friendly guardians", "nameplateShowFriendlyGuardians")
	CVarCheck(pg, 1, "Friendly totems", "nameplateShowFriendlyTotems")
	Header(pg, 1, "Enemy nameplates")
	CVarCheck(pg, 1, "Enemy players & NPCs", "nameplateShowEnemies")
	CVarCheck(pg, 1, "Enemy pets", "nameplateShowEnemyPets")
	CVarCheck(pg, 1, "Enemy guardians", "nameplateShowEnemyGuardians")
	CVarCheck(pg, 1, "Enemy totems", "nameplateShowEnemyTotems")
	Header(pg, 2, "Other")
	CVarCheck(pg, 2, "Class colors from the client", "ShowClassColorInNameplate",
		"Lets the client color enemy players by class when it knows them. BetterPlates adds its own class detection on top.")
	CVarCheck(pg, 2, "Cast bars on nameplates", "ShowVKeyCastbar",
		"Client cast bar on your target's nameplate. Needed for exact cast data on the target.")
	CVarCheck(pg, 2, "Spell icon on the client cast bar", "ShowVKeyCastbarSpellName")
	Note(pg, 2, "These are the client's own nameplate settings (same as the V key and Interface > Names). Key bindings for toggling friendly/enemy/all nameplates are under Key Bindings > BetterPlates. Per-zone rules are on the Zones page.", 90)
	return pg
end

local function PageHelp(win)
	local pg = NewPage(win, "Help & About")
	local c = pg.content
	local function Block(anchor, yOff, headText, bodyText)
		local head = c:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		head:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
		head:SetText(L[headText])
		head:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
		local body = c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		body:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
		body:SetWidth(520)
		body:SetJustifyH("LEFT")
		body:SetText(bodyText)
		return body
	end
	local intro = c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	intro:SetPoint("TOPLEFT", c, "TOPLEFT", 20, -44)
	intro:SetWidth(520)
	intro:SetJustifyH("LEFT")
	intro:SetText(L["Enhanced Blizzard nameplates for WotLK 3.3.5a, inspired by BetterBlizzPlates."] .. "\n|cff888888" .. ADDON .. " " .. ns.VERSION .. "  -  Samyd @ Blackrock|r")

	local cmds = Block(intro, -16, "Commands",
		"|cffffd100/bbp|r  -  " .. L["open settings"] ..
		"\n|cffffd100/bbp test|r  -  " .. L["demo of all elements on your target's nameplate"] ..
		"\n|cffffd100/bbp profile <name>|r  -  " .. L["switch profile"] ..
		"\n|cffffd100/bbp friends|r, |cffffd100/bbp enemies|r, |cffffd100/bbp all|r  -  " .. L["toggle nameplates"] ..
		"\n|cffffd100/bbp stack|r  -  " .. L["toggle stacking"] ..
		"\n|cffffd100/bbp export|r  -  " .. L["print export string"] ..
		"\n|cffffd100/bbp reset|r  -  " .. L["reset current profile"] ..
		"\n|cffffd100/bbp debug|r  -  " .. L["diagnostics to chat"])
	local keys = Block(cmds, -14, "Key bindings",
		L["Key Bindings > BetterPlates: toggle friendly / enemy / all nameplates, stacking, settings, test mode."])
	local lim = Block(keys, -14, "Limits of the 3.3.5a client",
		L["Nameplates have no unit link in 3.3.5a. Players are recognized via the combat log; NPCs show auras and cast names once targeted or moused over."] .. "\n" ..
		L["Not possible on this client: absorb shields, resource/combo points, range fading, talent spec detection, click-through plates, native stacking, quest markers, cast target names, combat state of non-targets."])
	local tips = Block(lim, -14, "Tips",
		L["Orange labels mark settings overridden by a zone rule. Use the search box in the sidebar to find any setting. Right-click colors to reset them."])
	pg.maxY = 560

	-- Spenden-Box
	local box = CreateFrame("Frame", nil, c)
	box:SetPoint("TOPLEFT", tips, "BOTTOMLEFT", -4, -20)
	box:SetWidth(528)
	box:SetHeight(92)
	box:SetBackdrop(FLAT)
	box:SetBackdropColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.08)
	box:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.4)
	local coin = box:CreateTexture(nil, "ARTWORK")
	coin:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
	coin:SetWidth(40)
	coin:SetHeight(40)
	coin:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	coin:SetPoint("LEFT", box, "LEFT", 14, 0)
	local bt = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	bt:SetPoint("TOPLEFT", coin, "TOPRIGHT", 12, 2)
	bt:SetText(L["Enjoying BetterPlates?"])
	local bd = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	bd:SetPoint("TOPLEFT", bt, "BOTTOMLEFT", 0, -4)
	bd:SetPoint("RIGHT", box, "RIGHT", -170, 0)
	bd:SetHeight(36)
	bd:SetJustifyH("LEFT")
	bd:SetJustifyV("TOP")
	bd:SetText(L["If this addon helps you, you can send a few Warmane Coins to its author. Thank you!"])
	local db = Button(box, L["Donate Warmane Coins"], 150, function() ns:ToggleDonate() end)
	db:SetPoint("RIGHT", box, "RIGHT", -12, 0)
	return pg
end

----------------------------------------------------------------
-- Hauptfenster
----------------------------------------------------------------
local function CreateWindow()
	local win = CreateFrame("Frame", "BetterPlatesOptions", UIParent)
	win:SetWidth(WIN_W)
	win:SetHeight(WIN_H)
	win:SetPoint("CENTER")
	win:SetFrameStrata("HIGH")
	win:SetToplevel(true)
	win:SetBackdrop(BACKDROP)
	win:SetMovable(true)
	win:EnableMouse(true)
	win:RegisterForDrag("LeftButton")
	win:SetScript("OnDragStart", win.StartMoving)
	win:SetScript("OnDragStop", win.StopMovingOrSizing)
	win:SetClampedToScreen(true)
	win:Hide()
	tinsert(UISpecialFrames, "BetterPlatesOptions")
	win.pages = {}

	local header = win:CreateTexture(nil, "ARTWORK")
	header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	header:SetWidth(320)
	header:SetHeight(64)
	header:SetPoint("TOP", win, "TOP", 0, 12)
	local title = win:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetPoint("TOP", header, "TOP", 0, -14)
	title:SetText("|cff33ccffBetter|rPlates " .. ns.VERSION)

	local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -4, -4)

	local sidebar = CreateFrame("Frame", nil, win)
	sidebar:SetWidth(SIDEBAR_W)
	sidebar:SetPoint("TOPLEFT", win, "TOPLEFT", 14, -36)
	sidebar:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 14, 52)
	sidebar:SetBackdrop(FLAT)
	sidebar:SetBackdropColor(0, 0, 0, 0.35)
	sidebar:SetBackdropBorderColor(1, 1, 1, 0.08)
	win.sidebar = sidebar

	local content = CreateFrame("Frame", nil, win)
	content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, 0)
	content:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -14, 52)
	content:SetBackdrop(FLAT)
	content:SetBackdropColor(0, 0, 0, 0.25)
	content:SetBackdropBorderColor(1, 1, 1, 0.08)
	win.content = content

	-- Fußzeile
	local reset = Button(win, L["Reset profile"], 130, function() StaticPopup_Show("BETTERPLATES_RESET") end)
	reset:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 16, 18)
	local test = Button(win, L["Test mode"], 110, function() ns.Plates:Test() end)
	test:SetPoint("LEFT", reset, "RIGHT", 6, 0)
	W.Tooltip(test, "Target something with a nameplate, then click: all elements are demonstrated for 16 seconds.")
	local donate = Button(win, "|cffffd100" .. L["Donate"] .. "|r  |TInterface\\Icons\\INV_Misc_Coin_01:14:14:0:0:64:64:4:60:4:60|t", 140, function() ns:ToggleDonate() end)
	donate:SetPoint("LEFT", test, "RIGHT", 6, 0)
	W.Tooltip(donate, "If this addon helps you, you can send a few Warmane Coins to its author. Thank you!")
	local hint = win:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("LEFT", donate, "RIGHT", 10, 0)
	hint:SetText("/bbp " .. L["opens this window"])
	local closeBtn = Button(win, L["Close"], 100, function() win:Hide() end)
	closeBtn:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -16, 18)

	local general = PageGeneral(win)
	AddTab(win, general)
	AddTab(win, PageStyle(win))
	AddTab(win, PageColors(win))
	AddTab(win, PagePositions(win))
	AddTab(win, PageFriendFoe(win))
	AddTab(win, PageIndicators(win))
	AddTab(win, PageCasts(win))
	AddTab(win, PageAuras(win))
	AddTab(win, PageDR(win))
	AddTab(win, PageLists(win))
	AddTab(win, PageRaid(win))
	AddTab(win, PagePvP(win))
	AddTab(win, PageZones(win))
	AddTab(win, PageProfiles(win))
	AddTab(win, PageBlizzard(win))
	AddTab(win, PageHelp(win))
	CreateSearch(win)
	SelectPage(win, general)
	return win
end

function ns:ToggleOptions(show)
	if not ns.optionsWindow then ns.optionsWindow = CreateWindow() end
	local win = ns.optionsWindow
	if show == false or (show == nil and win:IsShown()) then
		win:Hide()
	else
		win:Show()
		if win.current then win.current:Hide() win.current:Show() end
	end
end

----------------------------------------------------------------
-- Eintrag unter Interface > AddOns (öffnet das Fenster)
----------------------------------------------------------------
function ns:CreateOptions()
	if ns.optionsPanel then return end
	local panel = CreateFrame("Frame", nil, UIParent)
	panel.name = "BetterPlates"
	ns.optionsPanel = panel
	local PAD = 16

	local function Text(template, anchorTo, yOff, color)
		local fs = panel:CreateFontString(nil, "ARTWORK", template)
		fs:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, yOff)
		fs:SetPoint("RIGHT", panel, "RIGHT", -PAD - 8, 0)
		fs:SetJustifyH("LEFT")
		fs:SetJustifyV("TOP")
		if color then fs:SetTextColor(color[1], color[2], color[3]) end
		return fs
	end
	local function Section(anchorTo, yOff, text)
		local fs = Text("GameFontNormal", anchorTo, yOff, ACCENT)
		fs:SetText(L[text])
		local line = panel:CreateTexture(nil, "ARTWORK")
		line:SetTexture(1, 1, 1, 0.15)
		line:SetHeight(1)
		line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
		line:SetPoint("RIGHT", panel, "RIGHT", -PAD - 8, 0)
		return fs
	end

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -PAD)
	title:SetText("|cff33ccffBetter|rPlates  |cffffd100" .. ns.VERSION .. "|r")
	local desc = Text("GameFontHighlight", title, -6)
	desc:SetText(L["Enhanced Blizzard nameplates for WotLK 3.3.5a, inspired by BetterBlizzPlates."])

	local sec1 = Section(desc, -18, "Settings")
	local info1 = Text("GameFontHighlightSmall", sec1, -10)
	info1:SetText(L["All settings live in a separate, movable window with a sidebar."])
	local open = Button(panel, L["Open settings"], 200, function()
		InterfaceOptionsFrame:Hide()
		ns:ToggleOptions(true)
	end)
	open:SetPoint("TOPLEFT", info1, "BOTTOMLEFT", 0, -10)
	local openHint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	openHint:SetPoint("LEFT", open, "RIGHT", 10, 0)
	openHint:SetText(L["or type"] .. "  |cffffd100/bbp|r")

	local sec2 = Section(open, -22, "Support")
	local ask = Text("GameFontNormal", sec2, -10)
	ask:SetText(L["Enjoying BetterPlates?"] .. "  |TInterface\\Icons\\INV_Misc_Coin_01:16:16:0:0:64:64:4:60:4:60|t")
	local info2 = Text("GameFontHighlightSmall", ask, -6)
	info2:SetText(L["If this addon helps you, you can send a few Warmane Coins to its author. Thank you!"])

	local box = CreateFrame("Frame", nil, panel)
	box:SetPoint("TOPLEFT", info2, "BOTTOMLEFT", 0, -10)
	box:SetPoint("RIGHT", panel, "RIGHT", -PAD - 8, 0)
	box:SetHeight(50)
	box:SetBackdrop(FLAT)
	box:SetBackdropColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.08)
	box:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.4)
	local sendTo = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	sendTo:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -8)
	sendTo:SetText(L["Send coins to:"] .. "  |cffffffff" .. ns.DONATE_CHAR .. "|r")
	local path = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	path:SetPoint("TOPLEFT", sendTo, "BOTTOMLEFT", 0, -4)
	path:SetText("warmane.com  >  Account  >  Services")
	path:SetTextColor(0.75, 0.75, 0.75)

	local linkLabel = Text("GameFontNormalSmall", box, -10)
	linkLabel:SetText(L["Link (click, then Ctrl+C to copy):"])
	local link = CopyBox(panel, 200, ns.DONATE_URL)
	link:SetPoint("TOPLEFT", linkLabel, "BOTTOMLEFT", 6, -4)
	link:SetPoint("RIGHT", panel, "RIGHT", -PAD - 8, 0)
	local linkHint = Text("GameFontDisableSmall", link, -4)
	linkHint:SetPoint("TOPLEFT", link, "BOTTOMLEFT", -6, -4)
	linkHint:SetText(L["WoW cannot open websites, so paste the link into your browser."])

	local donate = Button(panel, L["Donate Warmane Coins"], 200, function() ns:ToggleDonate() end)
	donate:SetPoint("TOPLEFT", linkHint, "BOTTOMLEFT", 0, -10)
	local thanks = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	thanks:SetPoint("LEFT", donate, "RIGHT", 10, 0)
	thanks:SetText(L["Thank you!"])
	thanks:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])

	InterfaceOptions_AddCategory(panel)
end

----------------------------------------------------------------
-- Slash-Befehle
----------------------------------------------------------------
SLASH_BETTERPLATES1 = "/bbp"
SLASH_BETTERPLATES2 = "/betterplates"
SlashCmdList.BETTERPLATES = function(msg)
	msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local cmd, arg = msg:match("^(%S+)%s*(.-)$")
	cmd = (cmd or ""):lower()
	if cmd == "reset" then
		StaticPopup_Show("BETTERPLATES_RESET")
	elseif cmd == "debug" then
		ns.Plates:Debug()
	elseif cmd == "stack" then
		if arg == "" then BetterPlates_ToggleStacking() else ns.Plates:DebugStack() end
	elseif cmd == "plates" then
		ns.Plates:DebugPlates()
	elseif cmd == "donate" then
		ns:ToggleDonate()
	elseif cmd == "test" then
		ns.Plates:Test()
	elseif cmd == "friends" then
		BetterPlates_ToggleFriends()
	elseif cmd == "enemies" then
		BetterPlates_ToggleEnemies()
	elseif cmd == "all" then
		BetterPlates_ToggleAll()
	elseif cmd == "profile" then
		if arg == "" then
			ns:Print(L["Profiles"] .. ": " .. table.concat(P:GetNames(), ", ") .. "  (" .. L["active"] .. ": " .. tostring(P.name) .. ")")
		elseif P:Activate(arg) then
			P:ApplyZone()
			ns:Print(format(L["Profile %s activated."], arg))
		else
			ns:Print(format(L["No profile named %s."], arg))
		end
	elseif cmd == "export" then
		ns:Print(P:Export(true))
	elseif cmd == "help" then
		ns:Print("/bbp | test | profile <name> | friends | enemies | all | stack | export | reset | debug | donate")
	else
		ns:ToggleOptions()
	end
end
