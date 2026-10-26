-- WArena: options window shell and widget helpers
local _, ns = ...
local L = ns.L
local W = {}
ns.Widgets = W

local floor, format = math.floor, string.format
local WIN_W, WIN_H = 780, 600
local NAV_W = 150

---------------------------------------------------------------------------
-- window
---------------------------------------------------------------------------
local win = CreateFrame("Frame", "WArenaOptions", UIParent)
W.win = win
win:SetWidth(WIN_W)
win:SetHeight(WIN_H)
win:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
win:SetFrameStrata("DIALOG")
win:SetToplevel(true)
win:SetMovable(true)
win:EnableMouse(true)
win:SetClampedToScreen(true)
win:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
win:Hide()
tinsert(UISpecialFrames, "WArenaOptions") -- closes with Escape

local titleBg = win:CreateTexture(nil, "ARTWORK")
titleBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
titleBg:SetWidth(320)
titleBg:SetHeight(64)
titleBg:SetPoint("TOP", win, "TOP", 0, 12)
local title = win:CreateFontString(nil, "ARTWORK", "GameFontNormal")
title:SetPoint("TOP", titleBg, "TOP", 0, -14)
title:SetText("WArena " .. ns.version)

local drag = CreateFrame("Frame", nil, win)
drag:SetPoint("TOPLEFT", 12, -8)
drag:SetPoint("TOPRIGHT", -40, -8)
drag:SetHeight(32)
drag:EnableMouse(true)
drag:RegisterForDrag("LeftButton")
drag:SetScript("OnDragStart", function() win:StartMoving() end)
drag:SetScript("OnDragStop", function() win:StopMovingOrSizing() end)

local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -6, -6)

-- navigation (left)
local nav = CreateFrame("Frame", nil, win)
nav:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -40)
nav:SetWidth(NAV_W)
nav:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 16, 44)
nav:SetBackdrop({ bgFile = ns.WHITE, edgeFile = ns.WHITE, edgeSize = 1 })
nav:SetBackdropColor(0, 0, 0, 0.35)
nav:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)

-- content (right) with scrolling
local content = CreateFrame("Frame", nil, win)
content:SetPoint("TOPLEFT", nav, "TOPRIGHT", 8, 0)
content:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -18, 44)
content:SetBackdrop({ bgFile = ns.WHITE, edgeFile = ns.WHITE, edgeSize = 1 })
content:SetBackdropColor(0, 0, 0, 0.25)
content:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)

local scroll = CreateFrame("ScrollFrame", "WArenaOptionsScroll", content, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -4)
scroll:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -26, 4)
local scrollChild = CreateFrame("Frame", nil, scroll)
scrollChild:SetWidth(WIN_W - NAV_W - 80)
scrollChild:SetHeight(1)
scroll:SetScrollChild(scrollChild)
W.PAGE_W = WIN_W - NAV_W - 80
W.COL1, W.COL2 = 12, 320

local footer = win:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
footer:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 22, 20)
footer:SetText("Left click = target, right click = focus  |  Esc closes  |  /warena")

local widgets = {}
local pages, navButtons = {}, {}
W.widgets, W.pages = widgets, pages

---------------------------------------------------------------------------
-- generic helpers
---------------------------------------------------------------------------
local function db() return ns.db end

local function Tooltip(frame, text, desc)
	if not GameTooltip then return end
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, 1, 1, 1)
		if desc then GameTooltip:AddLine(desc, nil, nil, nil, true) end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
W.Tooltip = Tooltip

function W:Refresh()
	if not db() then return end
	for _, w in ipairs(widgets) do
		if w.page == nil or w.page:IsShown() then w:Refresh() end
	end
	ns:Fire("OPTIONS_REFRESH")
end

local function Register(w, page)
	w.page = page
	widgets[#widgets + 1] = w
end

-- value access with optional custom get/set (opts.get / opts.set)
local function GetValue(opts, key)
	if opts and opts.get then return opts.get() end
	return db()[key]
end
local function SetValue(opts, key, v)
	if opts and opts.set then opts.set(v) else ns:Set(key, v) end
	if opts and opts.onChange then opts.onChange(v) end
end

---------------------------------------------------------------------------
-- static widgets
---------------------------------------------------------------------------
function W:Header(page, text, x, y)
	local h = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	h:SetPoint("TOPLEFT", x, y)
	h:SetText(text)
	local line = page:CreateTexture(nil, "ARTWORK")
	line:SetTexture(1, 0.82, 0, 0.35)
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -2)
	line:SetWidth(280)
	return h
end

function W:Note(page, text, x, y, width, template)
	local n = page:CreateFontString(nil, "ARTWORK", template or "GameFontDisableSmall")
	n:SetPoint("TOPLEFT", x, y)
	n:SetWidth(width or 280)
	n:SetJustifyH("LEFT")
	n:SetText(text)
	return n
end

function W:Label(page, text, x, y, template, width)
	local fs = page:CreateFontString(nil, "ARTWORK", template or "GameFontHighlightSmall")
	fs:SetPoint("TOPLEFT", x, y)
	if width then fs:SetWidth(width) end
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	return fs
end

---------------------------------------------------------------------------
-- check box
---------------------------------------------------------------------------
local checkCount = 0
function W:Check(page, key, label, desc, x, y, opts)
	checkCount = checkCount + 1
	local cb = CreateFrame("CheckButton", "WArenaOpt_cb" .. checkCount, page, "InterfaceOptionsCheckButtonTemplate")
	cb:SetPoint("TOPLEFT", x, y)
	local text = _G[cb:GetName() .. "Text"]
	if text then text:SetText(label) end
	cb:SetScript("OnClick", function(self)
		local v = self:GetChecked() and true or false
		if opts and opts.invert then v = not v end
		SetValue(opts, key, v)
		W:Refresh()
	end)
	cb.Refresh = function(self)
		local v = GetValue(opts, key) and true or false
		if opts and opts.invert then v = not v end
		self:SetChecked(v)
	end
	Tooltip(cb, label, desc)
	Register(cb, page)
	return cb
end

---------------------------------------------------------------------------
-- slider
---------------------------------------------------------------------------
local sliderCount = 0
function W:Slider(page, key, label, minV, maxV, step, x, y, fmt, desc, opts)
	sliderCount = sliderCount + 1
	local name = "WArenaOpt_sl" .. sliderCount
	local s = CreateFrame("Slider", name, page, "OptionsSliderTemplate")
	s:SetPoint("TOPLEFT", x, y - 14)
	s:SetWidth(opts and opts.width or 270)
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	local low, high, text = _G[name .. "Low"], _G[name .. "High"], _G[name .. "Text"]
	if low then low:SetText(minV) end
	if high then high:SetText(maxV) end
	fmt = fmt or "%d"
	local function SetLabel(v) if text then text:SetText(format("%s: " .. fmt, label, v)) end end
	s:SetScript("OnValueChanged", function(self, v)
		v = floor(v / step + 0.5) * step
		if step < 1 then v = tonumber(format("%.2f", v)) end
		SetLabel(v)
		if self.updating then return end
		if GetValue(opts, key) ~= v then SetValue(opts, key, v) end
	end)
	s.Refresh = function(self)
		local v = GetValue(opts, key) or minV
		self.updating = true
		self:SetValue(v)
		self.updating = false
		SetLabel(v)
	end
	Tooltip(s, label, desc)
	Register(s, page)
	return s
end

---------------------------------------------------------------------------
-- dropdown  (items: list of {value, text} or a function returning one)
---------------------------------------------------------------------------
local ddCount = 0
function W:Dropdown(page, key, label, items, x, y, width, desc, opts)
	ddCount = ddCount + 1
	local dd = CreateFrame("Frame", "WArenaOpt_dd" .. ddCount, page, "UIDropDownMenuTemplate")
	dd:SetPoint("TOPLEFT", x - 16, y - 14)
	UIDropDownMenu_SetWidth(dd, width or 150)
	local lbl = page:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	lbl:SetPoint("TOPLEFT", x, y)
	lbl:SetText(label)
	local function Items()
		if type(items) == "function" then return items() end
		return items
	end
	local function TextFor(v)
		for _, it in ipairs(Items()) do if it[1] == v then return it[2] end end
		return v == nil and "" or tostring(v)
	end
	local function Init()
		if not db() then return end -- still loading: saved variables are not available yet
		local current = GetValue(opts, key)
		for _, it in ipairs(Items()) do
			local info = UIDropDownMenu_CreateInfo()
			info.text, info.value = it[2], it[1]
			info.func = function(self)
				local v = (type(self) == "table" and self.value ~= nil) and self.value or it[1]
				UIDropDownMenu_SetSelectedValue(dd, v)
				UIDropDownMenu_SetText(dd, TextFor(v))
				SetValue(opts, key, v)
				W:Refresh()
			end
			info.checked = (current == it[1])
			UIDropDownMenu_AddButton(info)
		end
	end
	UIDropDownMenu_Initialize(dd, Init)
	dd.Refresh = function()
		UIDropDownMenu_Initialize(dd, Init)
		local v = GetValue(opts, key)
		UIDropDownMenu_SetSelectedValue(dd, v)
		UIDropDownMenu_SetText(dd, TextFor(v))
	end
	if desc then Tooltip(_G[dd:GetName() .. "Button"] or dd, label, desc) end
	Register(dd, page)
	return dd
end

---------------------------------------------------------------------------
-- color swatch (uses ColorPickerFrame with opacity)
---------------------------------------------------------------------------
local colorCount = 0
function W:Color(page, key, label, x, y, desc, opts)
	colorCount = colorCount + 1
	local b = CreateFrame("Button", "WArenaOpt_col" .. colorCount, page)
	b:SetPoint("TOPLEFT", x, y)
	b:SetWidth(18)
	b:SetHeight(18)
	b.border = b:CreateTexture(nil, "BACKGROUND")
	b.border:SetAllPoints()
	b.border:SetTexture(1, 1, 1, 1)
	b.swatch = b:CreateTexture(nil, "ARTWORK")
	b.swatch:SetPoint("TOPLEFT", 1, -1)
	b.swatch:SetPoint("BOTTOMRIGHT", -1, 1)
	b.swatch:SetTexture(1, 1, 1, 1)
	local lbl = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	lbl:SetPoint("LEFT", b, "RIGHT", 6, 0)
	lbl:SetText(label)
	local function Current()
		local c = GetValue(opts, key)
		if type(c) == "table" then return c.r or 1, c.g or 1, c.b or 1, c.a or 1 end
		return 1, 1, 1, 1
	end
	local function Apply(r, g, bb, a)
		if opts and opts.set then opts.set({ r = r, g = g, b = bb, a = a }) else ns:SetColor(key, r, g, bb, a) end
		b.swatch:SetTexture(r, g, bb, 1)
	end
	b:SetScript("OnClick", function()
		local r, g, bb, a = Current()
		local prevR, prevG, prevB, prevA = r, g, bb, a
		ColorPickerFrame.hasOpacity = true
		ColorPickerFrame.opacity = 1 - a
		ColorPickerFrame.previousValues = { prevR, prevG, prevB, prevA }
		ColorPickerFrame.func = function()
			local nr, ng, nb = ColorPickerFrame:GetColorRGB()
			local na = 1 - (OpacitySliderFrame and OpacitySliderFrame:GetValue() or 0)
			Apply(nr, ng, nb, na)
		end
		ColorPickerFrame.opacityFunc = ColorPickerFrame.func
		ColorPickerFrame.cancelFunc = function() Apply(prevR, prevG, prevB, prevA) end
		ColorPickerFrame:SetColorRGB(r, g, bb)
		ColorPickerFrame:Hide()
		ColorPickerFrame:Show()
	end)
	b.reset = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	b.reset:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
	b.reset:SetWidth(44)
	b.reset:SetHeight(16)
	b.reset:SetText("reset")
	b.reset:SetScript("OnClick", function()
		local d = ns.defaults[key]
		if type(d) == "table" then Apply(d.r, d.g, d.b, d.a or 1) end
	end)
	b.Refresh = function(self)
		local r, g, bb = Current()
		self.swatch:SetTexture(r, g, bb, 1)
	end
	Tooltip(b, label, desc or "Click to pick a color.")
	Register(b, page)
	return b
end

---------------------------------------------------------------------------
-- buttons / edit boxes
---------------------------------------------------------------------------
function W:Button(page, label, width, x, y, onClick, desc)
	local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	b:SetPoint("TOPLEFT", x, y)
	b:SetWidth(width)
	b:SetHeight(24)
	b:SetText(label)
	b:SetScript("OnClick", function(self)
		onClick(self)
		W:Refresh()
	end)
	if desc then Tooltip(b, label, desc) end
	return b
end

-- single-line edit box; onEnter(text) is called on Enter
function W:EditBox(page, label, width, x, y, onEnter, desc)
	local eb = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
	eb:SetPoint("TOPLEFT", x + 6, y - 14)
	eb:SetWidth(width)
	eb:SetHeight(22)
	eb:SetAutoFocus(false)
	eb:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
	eb:SetText("")
	eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	eb:SetScript("OnEnterPressed", function(self)
		if onEnter then onEnter(self:GetText(), self) end
		self:ClearFocus()
		W:Refresh()
	end)
	if label then
		local lbl = page:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		lbl:SetPoint("TOPLEFT", x, y)
		lbl:SetText(label)
	end
	if desc then Tooltip(eb, label or "", desc) end
	return eb
end

-- read-only edit box: click selects everything, so Ctrl+C copies it
function W:CopyBox(page, text, width, x, y)
	local eb = self:EditBox(page, nil, width, x, y + 14)
	eb:SetText(text)
	eb:SetCursorPosition(0)
	eb.value = text
	eb:SetScript("OnTextChanged", function(self)
		if self:GetText() ~= self.value then
			self:SetText(self.value)
			self:HighlightText()
		end
	end)
	eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	eb:SetScript("OnMouseUp", function(self) self:SetFocus(); self:HighlightText() end)
	eb:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
	return eb
end

-- multi-line text box inside a scroll frame (for import/export)
local mlCount = 0
function W:MultiLine(page, width, height, x, y)
	mlCount = mlCount + 1
	local holder = CreateFrame("Frame", nil, page)
	holder:SetPoint("TOPLEFT", x, y)
	holder:SetWidth(width)
	holder:SetHeight(height)
	holder:SetBackdrop({ bgFile = ns.WHITE, edgeFile = ns.WHITE, edgeSize = 1 })
	holder:SetBackdropColor(0, 0, 0, 0.5)
	holder:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
	local sf = CreateFrame("ScrollFrame", "WArenaOpt_ml" .. mlCount, holder, "UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT", 4, -4)
	sf:SetPoint("BOTTOMRIGHT", -24, 4)
	local eb = CreateFrame("EditBox", nil, sf)
	eb:SetMultiLine(true)
	eb:SetAutoFocus(false)
	eb:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
	eb:SetWidth(width - 32)
	eb:SetHeight(height - 8)
	eb:SetText("")
	eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	sf:SetScrollChild(eb)
	holder:SetScript("OnMouseUp", function() eb:SetFocus() end)
	holder.edit = eb
	return holder
end

---------------------------------------------------------------------------
-- pages / navigation
---------------------------------------------------------------------------
function W:NewPage(name, height)
	local page = CreateFrame("Frame", nil, scrollChild)
	page:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
	page:SetWidth(W.PAGE_W)
	page:SetHeight(height or 500)
	page:Hide()
	page.title = name
	local idx = #pages + 1
	pages[idx] = page

	local b = CreateFrame("Button", nil, nav)
	b:SetHeight(22)
	b:SetPoint("TOPLEFT", nav, "TOPLEFT", 4, -6 - (idx - 1) * 24)
	b:SetPoint("RIGHT", nav, "RIGHT", -4, 0)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	b.bg:SetTexture(1, 0.82, 0, 0.25)
	b.bg:Hide()
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	b.text:SetPoint("LEFT", b, "LEFT", 8, 0)
	b.text:SetText(name)
	b:SetScript("OnClick", function() W:ShowPage(idx) end)
	b:SetScript("OnEnter", function(self) if W.page ~= idx then self.bg:SetTexture(1, 1, 1, 0.08); self.bg:Show() end end)
	b:SetScript("OnLeave", function(self) if W.page ~= idx then self.bg:Hide() end end)
	navButtons[idx] = b
	return page
end

function W:ShowPage(idx)
	for i, p in ipairs(pages) do
		ns:Show(p, i == idx)
		local b = navButtons[i]
		if i == idx then
			b.bg:SetTexture(1, 0.82, 0, 0.25)
			b.bg:Show()
			b.text:SetTextColor(1, 0.82, 0)
		else
			b.bg:Hide()
			b.text:SetTextColor(1, 1, 1)
		end
	end
	self.page = idx
	local p = pages[idx]
	scrollChild:SetHeight(p and p:GetHeight() or 1)
	scroll:SetVerticalScroll(0)
	self:Refresh()
end

function W:PageByTitle(name)
	for i, p in ipairs(pages) do if p.title == name then return i end end
end

---------------------------------------------------------------------------
-- open / close
---------------------------------------------------------------------------
local testWasOn
win:SetScript("OnShow", function(self)
	testWasOn = ns.state.testMode
	if not testWasOn and not ns.state.inArena and not InCombatLockdown() then ns.SetTest(true) end
	W:ShowPage(W.page or 1)
end)
win:SetScript("OnHide", function()
	if ns.state.testMode and not testWasOn and not InCombatLockdown() then ns.SetTest(false) end
end)

function ns:OptionsOpen() return win:IsShown() end
function ns:OpenOptions(pageName)
	if pageName then
		local idx = W:PageByTitle(pageName)
		if idx then W.page = idx end
		win:Show()
		return
	end
	if win:IsShown() then win:Hide() else win:Show() end
end
