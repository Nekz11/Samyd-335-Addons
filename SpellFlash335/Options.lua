-- SpellFlash 335 - options (Interface > AddOns panel + standalone window via /sf)

local ADDON, ns = ...

local DONATE_URL   = "https://www.warmane.com/account/services"
local DONATE_CHAR  = "Samyd"
local DONATE_REALM = "Blackrock"

local O, panel, donate
local refreshers = {}
local uid = 0

local function N(prefix)
	uid = uid + 1
	return "SpellFlash335" .. prefix .. uid
end

local function Size(f, w, h) f:SetWidth(w) f:SetHeight(h) end

-- every text gets a fixed width so it wraps instead of running out of the panel
local function Text(parent, text, x, y, w, font)
	local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormal")
	fs:SetPoint("TOPLEFT", x, y)
	fs:SetWidth(w)
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	fs:SetText(text)
	return fs
end

local function Tooltip(f, title, body, extra)
	f:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(title)
		if body then GameTooltip:AddLine(body, 1, 1, 1, true) end
		if extra then GameTooltip:AddLine(extra, 0.5, 0.8, 1, true) end
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- opts: tip, preview (function called on right click)
local function Check(parent, label, x, y, w, get, set, opts)
	opts = opts or {}
	local name = N("Check")
	local c = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
	Size(c, 26, 26)
	c:SetPoint("TOPLEFT", x, y)
	local t = _G[name .. "Text"]
	t:SetFontObject("GameFontHighlight")
	t:SetWidth(w - 30)
	t:SetJustifyH("LEFT")
	t:SetText(label)
	c:SetHitRectInsets(0, -(w - 30), 0, 0)   -- label is clickable too
	if opts.preview then c:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
	c:SetScript("OnClick", function(self, button)
		if button == "RightButton" and opts.preview then
			self:SetChecked(get() and true or false)   -- right click doesn't toggle
			opts.preview()
			return
		end
		set(self:GetChecked() and true or false)
		ns.RefreshOptions()
	end)
	if opts.tip then
		Tooltip(c, label, opts.tip, opts.preview and "Right-click: preview on your bars")
	end
	c.Refresh = function() c:SetChecked(get() and true or false) end
	refreshers[#refreshers + 1] = c
	return c
end

local function DBCheck(parent, label, x, y, w, key, tip)
	return Check(parent, label, x, y, w,
		function() return ns.db[key] end,
		function(v) ns.db[key] = v end,
		{ tip = tip })
end

local function Slider(parent, label, x, y, w, minv, maxv, step, fmt, key)
	local name = N("Slider")
	local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	s:SetPoint("TOPLEFT", x, y)
	s:SetWidth(w)
	s:SetMinMaxValues(minv, maxv)
	s:SetValueStep(step)
	_G[name .. "Low"]:SetText(string.format(fmt, minv))
	_G[name .. "High"]:SetText(string.format(fmt, maxv))
	local txt = _G[name .. "Text"]
	txt:SetWidth(w)
	s:SetScript("OnValueChanged", function(self, v)
		v = math.floor(v / step + 0.5) * step
		txt:SetText(label .. ": " .. string.format(fmt, v))
		if not self.updating then ns.db[key] = v end
	end)
	s.Refresh = function()
		local v = ns.db[key]
		s.updating = true
		s:SetValue(v)
		s.updating = false
		txt:SetText(label .. ": " .. string.format(fmt, v))
	end
	refreshers[#refreshers + 1] = s
	return s
end

local function PushButton(parent, label, x, y, w, onClick)
	local b = CreateFrame("Button", N("Btn"), parent, "UIPanelButtonTemplate")
	Size(b, w, 22)
	b:SetPoint("TOPLEFT", x, y)
	b:SetText(label)
	b:SetScript("OnClick", onClick)
	return b
end

-- button that steps through values = { {value, "Label", "tooltip"}, ... }
local function Cycle(parent, x, y, w, values, key)
	local b = PushButton(parent, "", x, y, w, nil)
	local function Index()
		for i, v in ipairs(values) do if v[1] == ns.db[key] then return i end end
		return 1
	end
	b:SetScript("OnClick", function(self)
		ns.db[key] = values[Index() % #values + 1][1]
		ns.RefreshOptions()
		if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
	end)
	b:SetScript("OnEnter", function(self)
		local v = values[Index()]
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(v[2])
		GameTooltip:AddLine(v[3], 1, 1, 1, true)
		GameTooltip:AddLine("Click to switch", 0.5, 0.8, 1)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b.Refresh = function() b:SetText(values[Index()][2]) end
	refreshers[#refreshers + 1] = b
	return b
end

local function ColorSwatch(parent, label, x, y, w)
	local b = CreateFrame("Button", nil, parent)
	Size(b, 18, 18)
	b:SetPoint("TOPLEFT", x, y)
	local bd = b:CreateTexture(nil, "BACKGROUND")
	bd:SetTexture(0.8, 0.8, 0.8)
	bd:SetPoint("TOPLEFT", -1, 1)
	bd:SetPoint("BOTTOMRIGHT", 1, -1)
	local sw = b:CreateTexture(nil, "ARTWORK")
	sw:SetAllPoints()
	local fs = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	fs:SetPoint("LEFT", b, "RIGHT", 8, 0)
	fs:SetWidth(w - 30)
	fs:SetJustifyH("LEFT")
	fs:SetText(label)
	b.Refresh = function()
		local c = ns.db.color
		sw:SetTexture(c.r, c.g, c.b)
		b:SetAlpha(ns.db.randomColor and 0.4 or 1)
	end
	b:SetScript("OnClick", function()
		local c = ns.db.color
		ColorPickerFrame.hasOpacity = false
		ColorPickerFrame.opacityFunc = nil
		ColorPickerFrame.previousValues = { c.r, c.g, c.b }
		ColorPickerFrame.func = function()
			local r, g, bl = ColorPickerFrame:GetColorRGB()
			c.r, c.g, c.b = r, g, bl
			b.Refresh()
		end
		ColorPickerFrame.cancelFunc = function(prev)
			prev = prev or ColorPickerFrame.previousValues
			c.r, c.g, c.b = prev[1], prev[2], prev[3]
			b.Refresh()
		end
		ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
		ColorPickerFrame:Hide()
		ColorPickerFrame:Show()
	end)
	refreshers[#refreshers + 1] = b
	return b
end

------------------------------------------------------------------------
-- Donate popup (WoW can't open a browser, so the link is copyable)
------------------------------------------------------------------------
local function CopyBox(parent, value, x, y, w)
	local e = CreateFrame("EditBox", N("Copy"), parent, "InputBoxTemplate")
	Size(e, w, 20)
	e:SetPoint("TOPLEFT", x, y)
	e:SetAutoFocus(false)
	e:SetFontObject("ChatFontNormal")
	e.fixed = value
	e:SetText(value)
	e:SetCursorPosition(0)
	e:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	e:SetScript("OnMouseUp", function(self) self:HighlightText() end)
	e:SetScript("OnTextChanged", function(self)
		if self:GetText() ~= self.fixed then
			self:SetText(self.fixed)
			self:HighlightText()
		end
	end)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	return e
end

local function ShowDonate()
	if not donate then
		local W = 400
		donate = CreateFrame("Frame", "SpellFlash335Donate", UIParent)
		Size(donate, W, 250)
		donate:SetPoint("CENTER", 0, 60)
		donate:SetFrameStrata("DIALOG")
		donate:SetToplevel(true)
		donate:EnableMouse(true)
		donate:SetMovable(true)
		donate:RegisterForDrag("LeftButton")
		donate:SetScript("OnDragStart", donate.StartMoving)
		donate:SetScript("OnDragStop", donate.StopMovingOrSizing)
		donate:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
		tinsert(UISpecialFrames, "SpellFlash335Donate")

		local icon = donate:CreateTexture(nil, "ARTWORK")
		icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
		Size(icon, 32, 32)
		icon:SetPoint("TOPLEFT", 22, -22)
		Text(donate, "Support SpellFlash 335", 62, -24, W - 110, "GameFontNormalLarge")
		Text(donate, "Completely optional - thank you!", 62, -44, W - 110, "GameFontHighlightSmall")

		local close = CreateFrame("Button", nil, donate, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", -6, -6)

		local iw = W - 44
		Text(donate,
			"If you enjoy the addon you can gift Warmane coins on the website. " ..
			"Open the link below in your browser and send them to this character:",
			22, -66, iw, "GameFontHighlight")

		Text(donate, "Website", 22, -112, 80, "GameFontNormalSmall")
		CopyBox(donate, DONATE_URL, 108, -108, iw - 92)
		Text(donate, "Character", 22, -140, 80, "GameFontNormalSmall")
		CopyBox(donate, DONATE_CHAR, 108, -136, 120)
		Text(donate, "Realm", 242, -140, 50, "GameFontNormalSmall")
		CopyBox(donate, DONATE_REALM, 290, -136, iw - 274)

		Text(donate, "Click a field and press Ctrl+C to copy it.", 22, -172, iw, "GameFontDisableSmall")
		PushButton(donate, "Close", (W - 120) / 2, -204, 120, function() donate:Hide() end)
	end
	donate:Show()
	donate:Raise()
end
ns.ShowDonate = ShowDonate

local function DonateButton(p, x, y, w)
	local b = PushButton(p, "Donate", x, y, w, ShowDonate)
	local ic = b:CreateTexture(nil, "OVERLAY")
	ic:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
	Size(ic, 16, 16)
	ic:SetPoint("LEFT", 8, 0)
	Tooltip(b, "Support SpellFlash 335",
		"Like the addon? You can gift Warmane coins to " .. DONATE_CHAR .. " (" .. DONATE_REALM .. "). Completely optional!")
	return b
end

------------------------------------------------------------------------
-- Shared layout, used by the Interface panel and the /sf window
-- (compact: fits the Interface > AddOns panel, ~410 px high)
------------------------------------------------------------------------
local MODES = {
	{ "ALL",    "Play: all together", "Every ticked effect plays at once on each key press." },
	{ "RANDOM", "Play: random",       "Each key press plays one random effect out of the ticked ones." },
	{ "CYCLE",  "Play: in turn",      "Each key press plays the next ticked effect, one after another." },
}

local function Build(p, x0, y0, W)
	local cw = math.floor(W / 3)               -- three columns
	local col = { x0, x0 + cw, x0 + 2 * cw }
	local y = y0

	Text(p, "General", x0, y, W)
	DBCheck(p, "Enable", col[1], y - 16, cw, "enabled")
	DBCheck(p, "Only in combat", col[2], y - 16, cw, "onlyCombat")
	DBCheck(p, "Mouse clicks", col[3], y - 16, cw, "mouse", "Also flash when you click a button with the mouse.")
	DBCheck(p, "Skip on cooldown", col[1], y - 40, cw, "skipCooldown", "Don't flash actions that are still on cooldown.")
	DBCheck(p, "Pressed look", col[2], y - 40, cw, "pushed", "Show the button as pressed when you use its keybind.")
	Check(p, "Minimap button", col[3], y - 40, cw,
		function() return not ns.db.minimap.hide end,
		function(v) ns.db.minimap.hide = not v end,
		{ tip = "Show the SpellFlash button on the minimap. Drag it to move it around." })
	y = y - 74

	Text(p, "Effects", x0, y, 60)
	Text(p, "tick as many as you like  -  right-click one to preview it", x0 + 62, y - 2, W - 62, "GameFontDisableSmall")
	for i, d in ipairs(ns.Effects) do
		local r, c = math.floor((i - 1) / 3), (i - 1) % 3 + 1
		Check(p, d.label, col[c], y - 16 - r * 24, cw,
			function() return ns.db.effects[d.key] end,
			function(v) ns.db.effects[d.key] = v end,
			{ tip = d.tip, preview = function() ns.Test(d.key) end })
	end
	y = y - 16 - math.ceil(#ns.Effects / 3) * 24 - 8

	Cycle(p, col[1] + 4, y, cw * 2 - 24, MODES, "mode")
	PushButton(p, "Test flash", col[3] + 4, y, cw - 24, function() ns.Test() end)
	y = y - 32

	ColorSwatch(p, "Colour", col[1] + 4, y - 4, cw)
	DBCheck(p, "Random colour", col[2], y, cw, "randomColor", "Every key press gets a different colour.")
	y = y - 40

	local sw = cw - 28
	Slider(p, "Duration", col[1] + 4, y, sw, 0.1, 1.0, 0.05, "%.2f", "duration")
	Slider(p, "Size", col[2] + 4, y, sw, 1.1, 2.5, 0.05, "%.2f", "size")
	Slider(p, "Intensity", col[3] + 4, y, sw, 0.2, 3.0, 0.1, "%.1f", "intensity")
	y = y - 44

	local note = Text(p,
		"With SnowfallKeyPress the flash happens on key down.  Commands: /sf  /sf toggle  /sf mode  /sf minimap  /sf test",
		x0, y, W, "GameFontDisableSmall")
	note:SetHeight(28)
	return y - 30
end

------------------------------------------------------------------------
-- /sf window
------------------------------------------------------------------------
local function CreateOptions()
	O = CreateFrame("Frame", "SpellFlash335Options", UIParent)
	Size(O, 500, 520)
	O:SetPoint("CENTER")
	O:SetFrameStrata("HIGH")
	O:SetToplevel(true)
	O:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	O:EnableMouse(true)
	O:SetMovable(true)
	O:SetClampedToScreen(true)
	O:RegisterForDrag("LeftButton")
	O:SetScript("OnDragStart", O.StartMoving)
	O:SetScript("OnDragStop", O.StopMovingOrSizing)
	O:Hide()
	tinsert(UISpecialFrames, "SpellFlash335Options")

	local hdr = O:CreateTexture(nil, "ARTWORK")
	hdr:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	Size(hdr, 320, 64)
	hdr:SetPoint("TOP", 0, 12)
	local title = O:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", hdr, "TOP", 0, -14)
	title:SetText(ns.title .. "  |cff888888v" .. ns.version .. "|r")

	local close = CreateFrame("Button", nil, O, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -6, -6)

	local bottom = Build(O, 26, -36, 500 - 52)
	DonateButton(O, 26, bottom, 120)
	O:SetHeight(-bottom + 44)
	O:SetScript("OnShow", function() ns.RefreshOptions() end)
end

function ns.RefreshOptions()
	for _, w in ipairs(refreshers) do w.Refresh() end
	if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
end

function ns.ToggleOptions()
	if not O then CreateOptions() end
	if O:IsShown() then O:Hide() else O:Show() end
end

------------------------------------------------------------------------
-- Interface > AddOns
------------------------------------------------------------------------
function ns.CreateInterfacePanel()
	panel = CreateFrame("Frame", "SpellFlash335Panel", UIParent)
	panel.name = ns.title
	panel:Hide()

	-- the container is ~620 px wide; build once we know the real size
	panel:SetScript("OnShow", function(self)
		if not self.built then
			self.built = true
			local W = math.floor((self:GetWidth() or 0) > 100 and self:GetWidth() or 600) - 32
			W = math.min(W, 580)
			Text(self, ns.title .. "  |cff888888v" .. ns.version .. "|r", 16, -16, W - 130, "GameFontNormalLarge")
			Text(self, "Flashes your action buttons when you press their keybind.", 16, -38, W - 130, "GameFontHighlightSmall")
			DonateButton(self, 16 + W - 120, -16, 120)
			Build(self, 16, -62, W)
		end
		ns.RefreshOptions()
	end)
	InterfaceOptions_AddCategory(panel)
end

------------------------------------------------------------------------
-- Minimap button
------------------------------------------------------------------------
local mm

local function MinimapPos()
	local a = math.rad(ns.db.minimap.angle or 200)
	local x, y = math.cos(a), math.sin(a)
	local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
	if shape == "SQUARE" then
		-- push the button out to the edge of a square minimap
		x = math.max(-1, math.min(1, x * 1.42))
		y = math.max(-1, math.min(1, y * 1.42))
	end
	local r = (Minimap:GetWidth() / 2) + 5
	mm:ClearAllPoints()
	mm:SetPoint("CENTER", Minimap, "CENTER", x * r, y * r)
end

local function MinimapTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine(ns.title)
	GameTooltip:AddLine(ns.db.enabled and "|cff00ff00Enabled|r" or "|cffff4040Disabled|r")
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("|cffffd100Left-click:|r options", 1, 1, 1)
	GameTooltip:AddLine("|cffffd100Right-click:|r enable / disable", 1, 1, 1)
	GameTooltip:AddLine("|cffffd100Shift-click:|r test flash", 1, 1, 1)
	GameTooltip:AddLine("|cffffd100Drag:|r move button", 1, 1, 1)
	GameTooltip:Show()
end

function ns.CreateMinimapButton()
	mm = CreateFrame("Button", "SpellFlash335MinimapButton", Minimap)
	Size(mm, 31, 31)
	mm:SetFrameStrata("MEDIUM")
	mm:SetFrameLevel(8)
	mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	mm:RegisterForDrag("LeftButton")
	mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local bg = mm:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	Size(bg, 20, 20)
	bg:SetPoint("TOPLEFT", 7, -5)

	mm.icon = mm:CreateTexture(nil, "ARTWORK")
	mm.icon:SetTexture("Interface\\Icons\\Spell_Nature_Lightning")
	Size(mm.icon, 18, 18)
	mm.icon:SetPoint("TOPLEFT", 7, -6)
	mm.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	local border = mm:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	Size(border, 53, 53)
	border:SetPoint("TOPLEFT")

	mm:SetScript("OnClick", function(self, button)
		if IsShiftKeyDown() then
			ns.Test()
		elseif button == "RightButton" then
			ns.db.enabled = not ns.db.enabled
			ns.Print(ns.db.enabled and "enabled" or "disabled")
			ns.RefreshOptions()
		else
			ns.ToggleOptions()
		end
		if GameTooltip:IsOwned(self) then MinimapTooltip(self) end
	end)
	mm:SetScript("OnEnter", MinimapTooltip)
	mm:SetScript("OnLeave", function() GameTooltip:Hide() end)

	mm:SetScript("OnDragStart", function(self)
		GameTooltip:Hide()
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local px, py = GetCursorPosition()
			local s = Minimap:GetEffectiveScale()
			ns.db.minimap.angle = math.deg(math.atan2(py / s - my, px / s - mx)) % 360
			MinimapPos()
		end)
	end)
	mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

	ns.UpdateMinimapButton()
end

function ns.UpdateMinimapButton()
	if not mm then return end
	if ns.db.minimap.hide then mm:Hide() return end
	mm:Show()
	mm.icon:SetDesaturated(not ns.db.enabled)
	MinimapPos()
end
