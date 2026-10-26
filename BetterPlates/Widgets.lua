-- BetterPlates - Widgets
-- Bausteine für das Optionsfenster: Seiten mit Scrollbereich, Checkboxen,
-- Schieberegler, Auswahl-Buttons, Dropdowns, Farbwähler, Textfelder, Suche.

local ADDON, ns = ...
if type(ns) ~= "table" then BetterPlatesNS = BetterPlatesNS or {} ns = BetterPlatesNS ADDON = "BetterPlates" end
local L = ns.L or setmetatable({}, { __index = function(t, k) return k end })
local format, floor, tonumber, type, ipairs, pairs = string.format, math.floor, tonumber, type, ipairs, pairs

local W = {}
ns.Widgets = W

W.ACCENT = { 0.2, 0.8, 1.0 }
W.COL_W = 262
W.BACKDROP = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
W.FLAT = {
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Buttons\\WHITE8X8",
	edgeSize = 1,
}

local count = 0
function W.NextName()
	count = count + 1
	return "BetterPlatesWidget" .. count
end
local NextName = W.NextName

----------------------------------------------------------------
-- Werte lesen/schreiben: "key" oder "colors.hostile" (verschachtelt)
----------------------------------------------------------------
local function Split(path)
	local a, b = path:match("^([^%.]+)%.(.+)$")
	return a, b
end

function W.GetValue(path)
	local db = ns.db
	if not db then return nil end
	local a, b = Split(path)
	if a then
		local t = db[a]
		return type(t) == "table" and t[b] or nil
	end
	return db[path]
end

-- Plaketten höchstens alle 0,1 s neu aufbauen (Slider/Farbwähler feuern sehr oft)
local refreshFrame = CreateFrame("Frame")
refreshFrame:Hide()
refreshFrame:SetScript("OnUpdate", function(self, elapsed)
	self.t = (self.t or 0) + elapsed
	if self.t >= 0.1 then
		self.t = 0
		self:Hide()
		if ns.Plates and ns.db then ns.Plates:RefreshAll() end
	end
end)
function W.Refresh()
	refreshFrame:Show()
end

function W.SetValue(path, v)
	local a, b = Split(path)
	if a then
		local t = ns.db and ns.db[a]
		if type(t) == "table" then t[b] = v end
		-- Profil teilt die Untertabelle, daher nichts weiter nötig
	else
		ns:Set(path, v, true)
	end
	W.Refresh()
end

----------------------------------------------------------------
-- Suche: alle Widgets mit Label registrieren
----------------------------------------------------------------
W.registry = {}
local function Register(page, widget, label)
	widget.page = page
	widget.label = label
	W.registry[#W.registry + 1] = widget
	page.widgets[#page.widgets + 1] = widget
end

----------------------------------------------------------------
-- Platzierung
----------------------------------------------------------------
local function Place(page, widget, col, height, xOff)
	local c = page.content
	widget:SetPoint("TOPLEFT", c, "TOPLEFT", page.colX[col] + (xOff or 0), page.y[col])
	page.y[col] = page.y[col] - height
	if -page.y[col] > page.maxY then page.maxY = -page.y[col] end
end
W.Place = Place

function W.Tooltip(widget, text)
	if not text then return end
	widget.tip = text
	widget:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L[self.tip], 1, 1, 1, 1, 1)
		GameTooltip:Show()
	end)
	widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

----------------------------------------------------------------
-- Seite mit Scrollbereich
----------------------------------------------------------------
function W.Page(win, title, group)
	local scroll = CreateFrame("ScrollFrame", NextName(), win.content, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", win.content, "TOPLEFT", 4, -4)
	scroll:SetPoint("BOTTOMRIGHT", win.content, "BOTTOMRIGHT", -26, 4)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetWidth(540)
	content:SetHeight(400)
	scroll:SetScrollChild(content)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local cur = self:GetVerticalScroll() or 0
		local maxV = self:GetVerticalScrollRange() or 0
		local v = cur - delta * 40
		if v < 0 then v = 0 elseif v > maxV then v = maxV end
		self:SetVerticalScroll(v)
	end)

	local page = scroll
	page.content = content
	page.widgets = {}
	page.colX = { 16, 16 + W.COL_W + 20 }
	page.y = { -40, -40 }
	page.maxY = 40
	page.title = title
	page.group = group
	page:Hide()
	page:SetScript("OnShow", function(self)
		for _, w in ipairs(self.widgets) do if w.Refresh then w:Refresh() end end
		self.content:SetHeight(self.maxY + 24)
	end)

	local head = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	head:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -12)
	head:SetText(L[title])
	page.head = head
	return page
end

function W.Header(page, col, text)
	local fs = page.content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	page.y[col] = page.y[col] - 8
	Place(page, fs, col, 20)
	fs:SetText(L[text])
	fs:SetTextColor(W.ACCENT[1], W.ACCENT[2], W.ACCENT[3])
	local line = page.content:CreateTexture(nil, "ARTWORK")
	line:SetTexture(1, 1, 1, 0.15)
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -2)
	line:SetWidth(W.COL_W - 10)
	page.y[col] = page.y[col] - 4
	return fs
end

function W.Note(page, col, text, height)
	local fs = page.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	fs:SetWidth(W.COL_W - 12)
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	fs:SetTextColor(0.7, 0.7, 0.7)
	Place(page, fs, col, height or 40, 4)
	fs:SetText(L[text])
	return fs
end

-- Leerzeile
function W.Space(page, col, h)
	page.y[col] = page.y[col] - (h or 10)
end

----------------------------------------------------------------
-- Checkbox
----------------------------------------------------------------
function W.Check(page, col, label, key, tip, getter, setter)
	local name = NextName()
	local cb = CreateFrame("CheckButton", name, page.content, "OptionsCheckButtonTemplate")
	local text = _G[name .. "Text"]
	text:SetText(L[label])
	text:SetWidth(W.COL_W - 36)
	text:SetJustifyH("LEFT")
	W.Tooltip(cb, tip)
	Place(page, cb, col, 26)

	cb.Refresh = function(self)
		local v
		if getter then v = getter() else v = W.GetValue(key) end
		self:SetChecked(v and true or false)
		if key and ns.Profiles and ns.Profiles.profile and ns.Profiles:IsOverridden(key) then
			text:SetTextColor(1, 0.75, 0.3)
		else
			text:SetTextColor(1, 1, 1)
		end
	end
	cb:SetScript("OnClick", function(self)
		local v = self:GetChecked() and true or false
		if setter then setter(v) W.Refresh() else W.SetValue(key, v) end
		PlaySound(v and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
	end)
	Register(page, cb, label)
	return cb
end

----------------------------------------------------------------
-- Schieberegler
----------------------------------------------------------------
function W.Slider(page, col, label, key, minV, maxV, step, fmt, onChange)
	local name = NextName()
	local s = CreateFrame("Slider", name, page.content, "OptionsSliderTemplate")
	s:SetWidth(W.COL_W - 24)
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	fmt = fmt or "%d"
	_G[name .. "Low"]:SetText(format(fmt, minV))
	_G[name .. "High"]:SetText(format(fmt, maxV))
	page.y[col] = page.y[col] - 14
	Place(page, s, col, 36, 6)

	local function ShowValue(v)
		_G[name .. "Text"]:SetText(L[label] .. ": " .. format(fmt, v))
	end
	s.Refresh = function(self)
		self.updating = true
		local v = W.GetValue(key) or minV
		self:SetValue(v)
		ShowValue(v)
		self.updating = nil
	end
	s:SetScript("OnValueChanged", function(self, v)
		v = floor(v / step + 0.5) * step
		if step < 1 then v = tonumber(format("%.2f", v)) end
		ShowValue(v)
		if self.updating then return end
		if W.GetValue(key) ~= v then
			W.SetValue(key, v)
			if onChange then onChange(v) end
		end
	end)
	Register(page, s, label)
	return s
end

----------------------------------------------------------------
-- Auswahl-Button (Links weiter, Rechts zurück)
----------------------------------------------------------------
function W.Cycle(page, col, label, key, list, onChange)
	local b = CreateFrame("Button", NextName(), page.content, "UIPanelButtonTemplate")
	b:SetWidth(W.COL_W - 24)
	b:SetHeight(22)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	Place(page, b, col, 28, 4)

	b.Refresh = function(self)
		local entry = list[W.GetValue(key) or 1]
		if type(entry) == "table" then entry = entry[1] end
		self:SetText(L[label] .. ": " .. L[tostring(entry or "?")])
	end
	b:SetScript("OnClick", function(self, button)
		local v = (W.GetValue(key) or 1) + (button == "RightButton" and -1 or 1)
		if v > #list then v = 1 elseif v < 1 then v = #list end
		W.SetValue(key, v)
		PlaySound("igMainMenuOptionCheckBoxOn")
		self:Refresh()
		if onChange then onChange(v) end
	end)
	W.Tooltip(b, "Left-click: next, right-click: previous")
	Register(page, b, label)
	return b
end

----------------------------------------------------------------
-- Dropdown (eigenes Menü, keine Blizzard-Dropdown-Globals)
----------------------------------------------------------------
local menu
local function GetMenu()
	if menu then return menu end
	menu = CreateFrame("Frame", "BetterPlatesMenu", UIParent)
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:SetBackdrop(W.FLAT)
	menu:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
	menu:SetBackdropBorderColor(1, 1, 1, 0.2)
	menu:SetWidth(200)
	menu:EnableMouse(true)
	menu.rows = {}
	menu:Hide()
	menu:SetClampedToScreen(true)
	menu:SetScript("OnUpdate", function(self)
		-- schließen, wenn die Maus das Menü verlässt (nicht, solange das Suchfeld den Fokus hat)
		local owner = self.owner
		if owner and owner.HasFocus and owner:HasFocus() then self.away = 0 return end
		if not self:IsMouseOver(8, -8, -8, 8) and not (owner and owner:IsMouseOver()) then
			self.away = (self.away or 0) + 1
			if self.away > 20 then self:Hide() end
		else
			self.away = 0
		end
	end)
	return menu
end

-- items: { {text=, value=}, ... } ; onPick(value)
function W.ShowMenu(owner, items, current, onPick)
	local m = GetMenu()
	m.owner = owner
	m.away = 0
	for _, r in ipairs(m.rows) do r:Hide() end
	local h = 6
	for i, item in ipairs(items) do
		local row = m.rows[i]
		if not row then
			row = CreateFrame("Button", nil, m)
			row:SetHeight(18)
			row:SetPoint("LEFT", m, "LEFT", 4, 0)
			row:SetPoint("RIGHT", m, "RIGHT", -4, 0)
			row.hl = row:CreateTexture(nil, "HIGHLIGHT")
			row.hl:SetAllPoints(row)
			row.hl:SetTexture(W.ACCENT[1], W.ACCENT[2], W.ACCENT[3], 0.25)
			row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			row.text:SetPoint("LEFT", row, "LEFT", 6, 0)
			row.text:SetJustifyH("LEFT")
			m.rows[i] = row
		end
		row:SetPoint("TOP", m, "TOP", 0, -h)
		row.text:SetText(item.text)
		if item.value == current then row.text:SetTextColor(W.ACCENT[1], W.ACCENT[2], W.ACCENT[3]) else row.text:SetTextColor(1, 1, 1) end
		row:SetScript("OnClick", function()
			m:Hide()
			onPick(item.value)
		end)
		row:Show()
		h = h + 18
	end
	m:SetHeight(h + 6)
	m:ClearAllPoints()
	m:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
	m:SetWidth(owner:GetWidth() or 200)
	m:Show()
end

-- list: { {label, value = v}, ... } oder { "A", "B" } bzw. { {label, pfad}, ... } (Wert = Index)
function W.Dropdown(page, col, label, key, list, onChange)
	local fs = page.content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	page.y[col] = page.y[col] - 4
	Place(page, fs, col, 16, 4)
	fs:SetText(L[label])

	local b = CreateFrame("Button", NextName(), page.content, "UIPanelButtonTemplate")
	b:SetWidth(W.COL_W - 24)
	b:SetHeight(22)
	Place(page, b, col, 28, 4)
	b.arrow = b:CreateTexture(nil, "OVERLAY")
	b.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
	b.arrow:SetWidth(16)
	b.arrow:SetHeight(16)
	b.arrow:SetPoint("RIGHT", b, "RIGHT", -4, 0)

	local function Items()
		local items = {}
		for i, e in ipairs(list) do
			if type(e) == "table" then
				items[i] = { text = L[e[1]], value = e.value ~= nil and e.value or i }
			else
				items[i] = { text = L[e], value = i }
			end
		end
		return items
	end
	b.Refresh = function(self)
		local cur = W.GetValue(key)
		local text = "?"
		for _, it in ipairs(Items()) do if it.value == cur then text = it.text end end
		self:SetText(text)
	end
	b:SetScript("OnClick", function(self)
		W.ShowMenu(self, Items(), W.GetValue(key), function(v)
			W.SetValue(key, v)
			self:Refresh()
			if onChange then onChange(v) end
		end)
	end)
	Register(page, b, label)
	return b
end

----------------------------------------------------------------
-- Farbwähler
----------------------------------------------------------------
function W.Color(page, col, label, path, tip)
	local b = CreateFrame("Button", NextName(), page.content)
	b:SetWidth(W.COL_W - 24)
	b:SetHeight(22)
	Place(page, b, col, 26, 4)
	b.swatch = b:CreateTexture(nil, "ARTWORK")
	b.swatch:SetWidth(16)
	b.swatch:SetHeight(16)
	b.swatch:SetPoint("LEFT", b, "LEFT", 2, 0)
	b.swatch:SetTexture(1, 1, 1, 1)
	b.swatchBorder = b:CreateTexture(nil, "BACKGROUND")
	b.swatchBorder:SetPoint("TOPLEFT", b.swatch, "TOPLEFT", -1, 1)
	b.swatchBorder:SetPoint("BOTTOMRIGHT", b.swatch, "BOTTOMRIGHT", 1, -1)
	b.swatchBorder:SetTexture(0, 0, 0, 1)
	b.text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	b.text:SetPoint("LEFT", b.swatch, "RIGHT", 6, 0)
	b.text:SetText(L[label])
	b.hl = b:CreateTexture(nil, "HIGHLIGHT")
	b.hl:SetAllPoints(b)
	b.hl:SetTexture(1, 1, 1, 0.08)
	W.Tooltip(b, tip or "Click to pick a color. Right-click resets to default.")

	local function Current()
		local c = W.GetValue(path)
		if type(c) ~= "table" then return 1, 1, 1 end
		return c[1] or 1, c[2] or 1, c[3] or 1
	end
	b.Refresh = function(self)
		local r, g, bl = Current()
		self.swatch:SetTexture(r, g, bl, 1)
	end
	local function Apply(r, g, bl)
		local c = W.GetValue(path)
		if type(c) ~= "table" then return end
		c[1], c[2], c[3] = r, g, bl
		b:Refresh()
		W.Refresh()
	end
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			local a, k = Split(path)
			local def = a and ns.defaults[a] and ns.defaults[a][k]
			if def then Apply(def[1], def[2], def[3]) end
			return
		end
		local r, g, bl = Current()
		local prevR, prevG, prevB = r, g, bl
		ColorPickerFrame.hasOpacity = false
		ColorPickerFrame.previousValues = { prevR, prevG, prevB }
		ColorPickerFrame.func = function()
			local nr, ng, nb = ColorPickerFrame:GetColorRGB()
			Apply(nr, ng, nb)
		end
		ColorPickerFrame.cancelFunc = function() Apply(prevR, prevG, prevB) end
		ColorPickerFrame:SetColorRGB(r, g, bl)
		ColorPickerFrame:Hide()
		ColorPickerFrame:Show()
	end)
	Register(page, b, label)
	return b
end

----------------------------------------------------------------
-- Einzeiliges Textfeld, speichert bei Enter / Fokusverlust
----------------------------------------------------------------
function W.EditLine(page, col, label, key, tip, onSave)
	local fs = page.content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	page.y[col] = page.y[col] - 4
	Place(page, fs, col, 16, 4)
	fs:SetText(L[label])
	fs:SetWidth(W.COL_W - 12)
	fs:SetJustifyH("LEFT")
	local box = CreateFrame("EditBox", NextName(), page.content, "InputBoxTemplate")
	box:SetWidth(W.COL_W - 30)
	box:SetHeight(22)
	box:SetAutoFocus(false)
	box:SetFontObject(ChatFontNormal)
	Place(page, box, col, 30, 10)
	W.Tooltip(box, tip)
	local function Save(self)
		local v = self:GetText() or ""
		if W.GetValue(key) ~= v then
			W.SetValue(key, v)
			if onSave then onSave(v) W.Refresh() end
		end
	end
	box:SetScript("OnEnterPressed", function(self) Save(self) self:ClearFocus() end)
	box:SetScript("OnEditFocusLost", Save)
	box:SetScript("OnEscapePressed", function(self) self:SetText(W.GetValue(key) or "") self:ClearFocus() end)
	box.Refresh = function(self) self:SetText(W.GetValue(key) or "") self:SetCursorPosition(0) end
	Register(page, box, label)
	return box
end

-- Mehrzeiliges Textfeld (Import/Export, Listen)
function W.EditArea(page, col, label, height, getter, setter)
	local fs = page.content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	page.y[col] = page.y[col] - 4
	Place(page, fs, col, 16, 4)
	fs:SetText(L[label])

	local holder = CreateFrame("Frame", nil, page.content)
	holder:SetWidth(W.COL_W - 24)
	holder:SetHeight(height)
	holder:SetBackdrop(W.FLAT)
	holder:SetBackdropColor(0, 0, 0, 0.5)
	holder:SetBackdropBorderColor(1, 1, 1, 0.15)
	Place(page, holder, col, height + 8, 4)

	local scroll = CreateFrame("ScrollFrame", NextName(), holder, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", holder, "TOPLEFT", 4, -4)
	scroll:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -24, 4)
	local box = CreateFrame("EditBox", NextName(), scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetFontObject(ChatFontSmall)
	box:SetWidth(W.COL_W - 56)
	box:SetHeight(height - 8)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	scroll:SetScrollChild(box)
	box.Refresh = function(self)
		if getter then self:SetText(getter() or "") end
	end
	if setter then
		box:SetScript("OnEditFocusLost", function(self) setter(self:GetText() or "") end)
	end
	holder.box = box
	holder.Refresh = function() box:Refresh() end
	Register(page, holder, label)
	return holder, box
end

----------------------------------------------------------------
-- Buttons
----------------------------------------------------------------
function W.Button(parent, text, width, onClick)
	local b = CreateFrame("Button", NextName(), parent, "UIPanelButtonTemplate")
	b:SetWidth(width)
	b:SetHeight(22)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

-- Button in einer Seitenspalte
function W.PageButton(page, col, text, onClick, tip)
	local b = W.Button(page.content, L[text], W.COL_W - 24, onClick)
	Place(page, b, col, 28, 4)
	W.Tooltip(b, tip)
	Register(page, b, text)
	return b
end

-- Zwei Buttons nebeneinander
function W.ButtonPair(page, col, text1, fn1, text2, fn2)
	local w = (W.COL_W - 30) / 2
	local b1 = W.Button(page.content, L[text1], w, fn1)
	local b2 = W.Button(page.content, L[text2], w, fn2)
	Place(page, b1, col, 28, 4)
	b2:SetPoint("LEFT", b1, "RIGHT", 6, 0)
	Register(page, b1, text1)
	Register(page, b2, text2)
	return b1, b2
end

-- Textfeld, das sich beim Klick komplett markiert (zum Kopieren mit Strg+C)
function W.CopyBox(parent, width, text)
	local box = CreateFrame("EditBox", NextName(), parent, "InputBoxTemplate")
	box:SetWidth(width)
	box:SetHeight(24)
	box:SetAutoFocus(false)
	box:SetFontObject(ChatFontNormal)
	box.value = text
	box:SetText(text)
	local function Reset(self)
		self:SetText(self.value)
		self:HighlightText()
	end
	box:SetScript("OnEditFocusGained", Reset)
	box:SetScript("OnMouseUp", function(self) self:HighlightText() end)
	box:SetScript("OnTextChanged", function(self, user) if user then Reset(self) end end)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	box:SetScript("OnChar", function(self) Reset(self) end)
	return box
end

----------------------------------------------------------------
-- Zonen-Override: "Profile / On / Off" bzw. Werteliste
----------------------------------------------------------------
function W.Override(page, col, def, zoneGetter)
	local b = CreateFrame("Button", NextName(), page.content, "UIPanelButtonTemplate")
	b:SetWidth(W.COL_W - 24)
	b:SetHeight(22)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	Place(page, b, col, 26, 4)
	local P = ns.Profiles
	local values = def.values or { true, false }
	local labels = def.valueLabels
	local function Label(v)
		if v == nil then return "|cff888888" .. L["Profile"] .. "|r" end
		if labels then
			for i, val in ipairs(values) do if val == v then return L[labels[i]] end end
		end
		if v == true then return "|cff33ff33" .. L["On"] .. "|r" end
		if v == false then return "|cffff5555" .. L["Off"] .. "|r" end
		return tostring(v)
	end
	b.Refresh = function(self)
		local v = P:GetOverride(zoneGetter(), def.key)
		self:SetText(L[def.label] .. ": " .. Label(v))
	end
	b:SetScript("OnClick", function(self, button)
		local cur = P:GetOverride(zoneGetter(), def.key)
		-- Reihenfolge: Profil -> values[1] -> values[2] ... -> Profil
		local idx = 0
		for i, v in ipairs(values) do if v == cur then idx = i end end
		idx = idx + (button == "RightButton" and -1 or 1)
		if idx > #values then idx = 0 elseif idx < 0 then idx = #values end
		local v = idx == 0 and nil or values[idx]
		P:SetOverride(zoneGetter(), def.key, v)
		PlaySound("igMainMenuOptionCheckBoxOn")
		self:Refresh()
	end)
	W.Tooltip(b, "Left-click: next, right-click: previous. \"Profile\" = no override in this zone.")
	Register(page, b, def.label)
	return b
end

----------------------------------------------------------------
-- Suche
----------------------------------------------------------------
function W.Search(query)
	query = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local hits = {}
	if query == "" then return hits end
	for _, w in ipairs(W.registry) do
		local label = w.label and L[w.label] or ""
		if label:lower():find(query, 1, true) then
			hits[#hits + 1] = w
			if #hits >= 12 then break end
		end
	end
	return hits
end

-- Widget hervorheben (kurzes Aufblinken)
function W.Flash(widget)
	if not widget.flash then
		local t = widget:CreateTexture(nil, "OVERLAY")
		t:SetAllPoints(widget)
		t:SetTexture(W.ACCENT[1], W.ACCENT[2], W.ACCENT[3], 0.35)
		widget.flash = t
	end
	widget.flash:Show()
	widget.flashUntil = GetTime() + 1.5
	widget:SetScript("OnUpdate", function(self)
		if GetTime() > (self.flashUntil or 0) then
			self.flash:Hide()
			self:SetScript("OnUpdate", nil)
		end
	end)
end
