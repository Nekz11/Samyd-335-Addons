-- RetailPartyFrames - options window (/rpf) and the Interface > AddOns launcher

local _, ns = ...

local floor = math.floor
local counter = 0

local AUTHOR_CHAR = "Samyd"
local AUTHOR_REALM = "Blackrock"
local DONATE_URL = "https://www.warmane.com/account/services"
local COIN_ICON = "Interface\\Icons\\INV_Misc_Coin_01"

local window, pages, tabs, pageByTitle = nil, {}, {}, {}

local function NextName()
    counter = counter + 1
    return "RetailPartyFramesOption" .. counter
end

------------------------------------------------------------------------
-- Settings access: "a.b.c" walks nested tables, "global:" reads the account-wide table
------------------------------------------------------------------------
local function Resolve(key)
    local root = ns.db
    if string.find(key, "^global:") then
        root = ns.global
        key = string.sub(key, 8)
    end
    local t = root
    local last
    for part in string.gmatch(key, "[^%.]+") do
        if last then
            if type(t[last]) ~= "table" then t[last] = {} end
            t = t[last]
        end
        last = part
    end
    return t, last
end

local function Get(key)
    local t, k = Resolve(key)
    return t[k]
end

local function Set(key, value)
    local t, k = Resolve(key)
    t[k] = value
end

local function GetDefault(key)
    local root = ns.defaults
    if string.find(key, "^global:") then
        root = ns.globalDefaults
        key = string.sub(key, 8)
    end
    local t = root
    local last
    for part in string.gmatch(key, "[^%.]+") do
        if last then
            t = t[last]
            if type(t) ~= "table" then return nil end
        end
        last = part
    end
    return ns.DeepCopy(t[last])
end

function ns:Refresh()
    self:RefreshAll()
end

-- Snap a slider value to its step without float garbage (0.35000000000000003)
local function Snap(v, step)
    v = floor(v / step + 0.5) * step
    if step < 1 then
        local decimals = math.max(0, math.ceil(-math.log10(step)))
        v = tonumber(string.format("%." .. decimals .. "f", v))
    end
    return v
end

------------------------------------------------------------------------
-- Basic widgets (parent = a page frame)
------------------------------------------------------------------------
local function Column(p, x, y)
    return { p = p, x = x, y = y }
end

local function Header(col, text)
    local fs = col.p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", col.x, col.y)
    fs:SetText(text)
    col.y = col.y - 20
end

local function Text(p, x, y, width, text, font, height)
    local fs = p:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetHeight(height or 60)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetText(text)
    return fs
end

local function Note(col, text, height)
    local fs = Text(col.p, col.x + 4, col.y, 260, text, "GameFontDisableSmall", height or 28)
    col.y = col.y - (height or 28) - 4
    return fs
end

local function Check(col, label, key, tip, onChange)
    local cb = CreateFrame("CheckButton", NextName(), col.p, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", col.x, col.y)
    _G[cb:GetName() .. "Text"]:SetText(label)
    cb.tooltipText = label
    cb.tooltipRequirement = tip
    cb.key = key
    cb:SetScript("OnClick", function(self)
        Set(key, self:GetChecked() and true or false)
        PlaySound(self:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
        if onChange then onChange() else ns:Refresh() end
    end)
    cb.Refresh = function(self) self:SetChecked(Get(key) and true or false) end
    col.p.widgets[#col.p.widgets + 1] = cb
    col.y = col.y - 26
    return cb
end

local function Slider(col, label, key, minV, maxV, step, fmt, onChange)
    col.y = col.y - 14
    local name = NextName()
    local s = CreateFrame("Slider", name, col.p, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", col.x + 4, col.y)
    s:SetWidth(200)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s.key = key
    _G[name .. "Low"]:SetText(minV)
    _G[name .. "High"]:SetText(maxV)
    local text = _G[name .. "Text"]
    local function label_for(v)
        return label .. ": |cffffffff" .. string.format(fmt or "%d", v) .. "|r"
    end
    s:SetScript("OnValueChanged", function(self, v)
        v = Snap(v, step)
        text:SetText(label_for(v))
        if self.refreshing then return end
        if Get(key) ~= v then
            Set(key, v)
            if onChange then onChange() else ns:Refresh() end
        end
    end)
    s.Refresh = function(self)
        self.refreshing = true
        local v = Get(key) or minV
        self:SetValue(v)
        text:SetText(label_for(v))
        self.refreshing = false
    end
    col.p.widgets[#col.p.widgets + 1] = s
    col.y = col.y - 36
    return s
end

-- generic dropdown: options = list of {value, label} or a function returning it; get/set callbacks
local function RawDropdown(p, x, y, width, label, options, get, set)
    if label then
        local fs = p:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", x + 2, y)
        fs:SetText(label)
        y = y - 12
    end
    local dd = CreateFrame("Frame", NextName(), p, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", x - 16, y)
    UIDropDownMenu_SetWidth(dd, width or 170)
    local function opts()
        return type(options) == "function" and options() or options
    end
    local function textFor(v)
        for _, o in ipairs(opts()) do
            if o[1] == v then return o[2] end
        end
        return v == nil and "" or tostring(v)
    end
    UIDropDownMenu_Initialize(dd, function(_, level)
        for _, o in ipairs(opts()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = o[2]
            info.value = o[1]
            info.checked = (get() == o[1])
            info.func = function(btn)
                set(btn.value)
                UIDropDownMenu_SetSelectedValue(dd, btn.value)
                UIDropDownMenu_SetText(dd, textFor(btn.value))
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    dd.Refresh = function()
        UIDropDownMenu_SetSelectedValue(dd, get())
        UIDropDownMenu_SetText(dd, textFor(get()))
    end
    return dd
end

local function Dropdown(col, label, key, options, onChange)
    local dd = RawDropdown(col.p, col.x, col.y, 170, label, options,
        function() return Get(key) end,
        function(v)
            Set(key, v)
            if onChange then onChange() else ns:Refresh() end
        end)
    dd.key = key
    col.p.widgets[#col.p.widgets + 1] = dd
    col.y = col.y - 52
    return dd
end

local function Button(p, x, y, width, label, onClick, point)
    local b = CreateFrame("Button", NextName(), p, "UIPanelButtonTemplate")
    b:SetPoint(point or "TOPLEFT", x, y)
    b:SetWidth(width)
    b:SetHeight(22)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

local function EditBox(p, x, y, width, label)
    local eb = CreateFrame("EditBox", NextName(), p, "InputBoxTemplate")
    eb:SetPoint("TOPLEFT", x + 6, y)
    eb:SetWidth(width)
    eb:SetHeight(20)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    if label then
        local fs = p:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        fs:SetPoint("BOTTOMLEFT", eb, "TOPLEFT", -4, 2)
        fs:SetText(label)
    end
    return eb
end

-- edit box bound to a string setting (saved on Enter / focus lost)
local function TextSetting(col, label, key, width, onChange)
    col.y = col.y - 14
    local eb = EditBox(col.p, col.x, col.y, width or 180, label)
    local function save(self)
        local v = ns.Trim(self:GetText())
        if Get(key) ~= v then
            Set(key, v)
            if onChange then onChange() else ns:Refresh() end
        end
        self:ClearFocus()
    end
    eb:SetScript("OnEnterPressed", save)
    eb:SetScript("OnEditFocusLost", save)
    eb.Refresh = function(self) self:SetText(tostring(Get(key) or "")) end
    col.p.widgets[#col.p.widgets + 1] = eb
    col.y = col.y - 30
    return eb
end

-- read-only box whose content is selected on click, so Ctrl+C copies it (WoW cannot open URLs)
local function CopyBox(p, x, y, width, text, label)
    local eb = EditBox(p, x, y, width, label)
    eb:SetText(text)
    eb:SetScript("OnTextChanged", function(self)
        if self:GetText() ~= text then self:SetText(text) end
    end)
    eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    eb:SetScript("OnMouseUp", function(self) self:HighlightText() end)
    return eb
end

local function ColorSwatch(col, label, key, onChange)
    local b = CreateFrame("Button", NextName(), col.p)
    b:SetPoint("TOPLEFT", col.x + 4, col.y - 2)
    b:SetWidth(18)
    b:SetHeight(18)
    b.border = b:CreateTexture(nil, "BACKGROUND")
    b.border:SetAllPoints(b)
    b.border:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.border:SetVertexColor(0.3, 0.3, 0.3, 1)
    b.swatch = b:CreateTexture(nil, "ARTWORK")
    b.swatch:SetPoint("TOPLEFT", 2, -2)
    b.swatch:SetPoint("BOTTOMRIGHT", -2, 2)
    b.swatch:SetTexture("Interface\\Buttons\\WHITE8X8")
    local fs = col.p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("LEFT", b, "RIGHT", 6, 0)
    fs:SetText(label)
    b.key = key
    local function apply(r, g, bl)
        Set(key, { r, g, bl })
        b.swatch:SetVertexColor(r, g, bl)
        if onChange then onChange() else ns:Refresh() end
    end
    b:SetScript("OnClick", function()
        local c = Get(key) or { 1, 1, 1 }
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r = c[1], g = c[2], b = c[3] }
        ColorPickerFrame.func = function()
            local r, g, bl = ColorPickerFrame:GetColorRGB()
            apply(r, g, bl)
        end
        ColorPickerFrame.cancelFunc = function(prev)
            apply(prev.r, prev.g, prev.b)
        end
        ColorPickerFrame:SetColorRGB(c[1], c[2], c[3])
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end)
    b.Refresh = function(self)
        local c = Get(key) or { 1, 1, 1 }
        self.swatch:SetVertexColor(c[1], c[2], c[3])
    end
    col.p.widgets[#col.p.widgets + 1] = b
    col.y = col.y - 26
    return b
end

local function MediaOptions(kind)
    return function()
        local t = {}
        for _, name in ipairs(ns:MediaList(kind)) do t[#t + 1] = { name, name } end
        return t
    end
end

local function SpellLabel(id, cd, extra)
    local name, _, icon = GetSpellInfo(id)
    local s = string.format("|T%s:14:14:0:0|t %s |cff888888(%d)|r", icon or "Interface\\Icons\\INV_Misc_QuestionMark", name or "Unknown spell", id)
    if cd then s = s .. string.format("  |cffffffff%ds|r", cd) end
    if extra then s = s .. "  |cff888888" .. extra .. "|r" end
    return s
end

------------------------------------------------------------------------
-- Row list (used for spells, bindings, profiles)
------------------------------------------------------------------------
local function MakeList(p, x, y, width, rows, title, onAction, actionLabel, onSelect)
    if title then
        local fs = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        fs:SetPoint("TOPLEFT", x, y)
        fs:SetText(title)
        y = y - 18
    end
    local list = { rows = {}, count = rows }
    for i = 1, rows do
        local row = CreateFrame("Button", nil, p)
        row:SetPoint("TOPLEFT", x, y - (i - 1) * 21)
        row:SetWidth(width)
        row:SetHeight(20)
        row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", actionLabel and -70 or -2, 0)
        row.text:SetJustifyH("LEFT")
        if onSelect then
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints(row)
            hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            hl:SetBlendMode("ADD")
            row.sel = row:CreateTexture(nil, "BACKGROUND")
            row.sel:SetAllPoints(row)
            row.sel:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            row.sel:SetBlendMode("ADD")
            row.sel:Hide()
            row:SetScript("OnClick", function(self) onSelect(self.key, self.item) end)
        end
        if actionLabel then
            row.btn = CreateFrame("Button", NextName(), row, "UIPanelButtonTemplate")
            row.btn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            row.btn:SetWidth(64)
            row.btn:SetHeight(18)
            row.btn:SetText(actionLabel)
            row.btn:SetScript("OnClick", function(self) onAction(self:GetParent().key, self:GetParent().item) end)
        end
        row:Hide()
        list.rows[i] = row
    end
    list.more = p:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    list.more:SetPoint("TOPLEFT", x, y - rows * 21)
    list.more:Hide()
    list.height = (title and 18 or 0) + rows * 21 + 14
    return list
end

local function FillList(list, items, selectedKey)
    for i, row in ipairs(list.rows) do
        local it = items[i]
        if it then
            row.key = it.key
            row.item = it
            row.text:SetText(it.label)
            if row.sel then
                if selectedKey ~= nil and it.key == selectedKey then row.sel:Show() else row.sel:Hide() end
            end
            row:Show()
        else
            row:Hide()
        end
    end
    if #items > list.count then
        list.more:SetText(string.format("... and %d more", #items - list.count))
        list.more:Show()
    else
        list.more:Hide()
    end
end

-- spell id set editor: tbl[id] = true (set) or array of ids (array)
local function IdListEditor(p, x, y, width, rows, title, getTable, mode, onChange)
    local box = EditBox(p, x, y - 18, 80, nil)
    local hint = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    hint:SetPoint("BOTTOMLEFT", box, "TOPLEFT", -4, 2)
    hint:SetText(title)
    local list
    local function changed()
        if onChange then onChange() end
        ns:RefreshOptions()
    end
    local function add()
        local id = tonumber(box:GetText())
        if not id or not GetSpellInfo(id) then
            ns:Print("Please enter a valid spell id.")
            return
        end
        local t = getTable()
        if mode == "set" then
            t[id] = true
        else
            for _, v in ipairs(t) do if v == id then box:SetText("") return end end
            t[#t + 1] = id
        end
        box:SetText("")
        changed()
    end
    box:SetScript("OnEnterPressed", add)
    local addBtn = Button(p, x + 96, y - 18, 60, "Add", add)
    addBtn:SetHeight(20)
    list = MakeList(p, x, y - 44, width, rows, nil, function(key)
        local t = getTable()
        if mode == "set" then
            t[key] = nil
        else
            for i = #t, 1, -1 do if t[i] == key then table.remove(t, i) end end
        end
        changed()
    end, "Remove")
    local w = { Refresh = function()
        local items = {}
        local t = getTable()
        if mode == "set" then
            for id in pairs(t) do items[#items + 1] = { key = id, label = SpellLabel(id) } end
            table.sort(items, function(a, b) return a.key < b.key end)
        else
            for _, id in ipairs(t) do items[#items + 1] = { key = id, label = SpellLabel(id) } end
        end
        FillList(list, items)
    end }
    p.widgets[#p.widgets + 1] = w
    return y - 44 - rows * 21 - 16
end

------------------------------------------------------------------------
-- Donation block (used on the Support page and in the Interface > AddOns entry)
------------------------------------------------------------------------
local function DonateBlock(p, x, y, width)
    local icon = p:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(COIN_ICON)
    icon:SetWidth(36)
    icon:SetHeight(36)
    icon:SetPoint("TOPLEFT", x, y)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local h = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    h:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    h:SetText("Enjoying RetailPartyFrames?")

    local sub = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sub:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -4)
    sub:SetWidth(width - 50)
    sub:SetHeight(42)
    sub:SetJustifyH("LEFT")
    sub:SetJustifyV("TOP")
    sub:SetText("The addon is free and made in my spare time. If it helps you, you can say thanks with a few Warmane coins - every bit is appreciated!")

    local yy = y - 72
    local box = CreateFrame("Frame", nil, p)
    box:SetPoint("TOPLEFT", x, yy)
    box:SetWidth(width)
    box:SetHeight(58)
    box:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    box:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    box:SetBackdropBorderColor(1, 0.82, 0, 0.8)

    local l1 = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    l1:SetPoint("TOPLEFT", 12, -10)
    l1:SetText("Send coins to:")
    local l2 = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    l2:SetPoint("TOPLEFT", l1, "TOPRIGHT", 8, 2)
    l2:SetText("|cff00ff96" .. AUTHOR_CHAR .. "|r  -  " .. AUTHOR_REALM)
    local l3 = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    l3:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -8)
    l3:SetText("warmane.com  >  Account  >  Services")

    yy = yy - 58 - 22
    CopyBox(p, x, yy, width - 8, DONATE_URL, "Link (click, then Ctrl+C to copy)")
    local hint = p:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", x, yy - 24)
    hint:SetText("WoW cannot open websites, so paste the link into your browser.")
    return yy - 40
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------
local LAUNCHER_W = 395 -- usable width inside Blizzard's Interface > AddOns panel (3.3.5 panel is ~440 wide)
local WIN_W, WIN_H = 760, 560
local SIDE_W = 150
local PAGE_W = WIN_W - SIDE_W - 48
local TAB_H = 23

local function SelectPage(index)
    for i, p in ipairs(pages) do
        if i == index then
            p:Show()
            p.refresh()
            tabs[i].selected:Show()
            tabs[i].text:SetTextColor(1, 1, 1)
        else
            p:Hide()
            tabs[i].selected:Hide()
            tabs[i].text:SetTextColor(1, 0.82, 0)
        end
    end
    window.current = index
end

local function NewPage(title, desc)
    local p = CreateFrame("Frame", nil, window.content)
    p:SetAllPoints(window.content)
    p.widgets = {}
    p.title = title
    p:Hide()

    local t = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -14)
    t:SetText(title)

    local d = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4)
    d:SetWidth(PAGE_W - 32)
    d:SetHeight(28)
    d:SetJustifyH("LEFT")
    d:SetJustifyV("TOP")
    d:SetText(desc or "")

    p.refresh = function()
        for _, w in ipairs(p.widgets) do w:Refresh() end
    end
    p.default = function()
        for _, w in ipairs(p.widgets) do
            if w.key then Set(w.key, GetDefault(w.key)) end
        end
        p.refresh()
        ns:Refresh()
    end

    pages[#pages + 1] = p
    local index = #pages
    pageByTitle[title] = index

    -- sidebar tab
    local tab = CreateFrame("Button", NextName(), window)
    tab:SetPoint("TOPLEFT", window.sidebar, "TOPLEFT", 4, -6 - (index - 1) * TAB_H)
    tab:SetWidth(SIDE_W - 8)
    tab:SetHeight(TAB_H - 1)
    tab.text = tab:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    tab.text:SetPoint("LEFT", 10, 0)
    tab.text:SetText(title)
    local hl = tab:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(tab)
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetBlendMode("ADD")
    hl:SetAlpha(0.5)
    tab.selected = tab:CreateTexture(nil, "ARTWORK")
    tab.selected:SetAllPoints(tab)
    tab.selected:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    tab.selected:SetBlendMode("ADD")
    tab.selected:Hide()
    tab:SetScript("OnClick", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        SelectPage(index)
    end)
    tabs[index] = tab
    return p
end

local function CreateWindow()
    window = CreateFrame("Frame", "RetailPartyFramesWindow", UIParent)
    window:SetWidth(WIN_W)
    window:SetHeight(WIN_H)
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    if sw and sh and sw > 0 and sh > 0 then
        window:SetScale(math.min(1, (sw * 0.92) / WIN_W, (sh * 0.92) / WIN_H))
    end
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(self) self:StartMoving() end)
    window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    window:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    window:Hide()
    tinsert(UISpecialFrames, "RetailPartyFramesWindow") -- Escape closes it

    local header = window:CreateTexture(nil, "ARTWORK")
    header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    header:SetWidth(320)
    header:SetHeight(64)
    header:SetPoint("TOP", window, "TOP", 0, 12)
    local title = window:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", header, "TOP", 0, -14)
    title:SetText("RetailPartyFrames  |cff888888v" .. ns.version .. "|r")

    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -4, -4)

    local side = CreateFrame("Frame", nil, window)
    side:SetPoint("TOPLEFT", window, "TOPLEFT", 16, -34)
    side:SetWidth(SIDE_W)
    side:SetPoint("BOTTOM", window, "BOTTOM", 0, 52)
    side:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    side:SetBackdropColor(0, 0, 0, 0.5)
    side:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    window.sidebar = side

    local content = CreateFrame("Frame", nil, window)
    content:SetPoint("TOPLEFT", side, "TOPRIGHT", 8, 0)
    content:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -16, 52)
    content:SetBackdrop(side:GetBackdrop())
    content:SetBackdropColor(0, 0, 0, 0.5)
    content:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    window.content = content

    window.lockBtn = Button(window, 16, 18, 120, "Unlock frames", function() ns:ToggleLock() end, "BOTTOMLEFT")
    window.testBtn = Button(window, 142, 18, 110, "Test mode", function() ns:CycleTestMode() end, "BOTTOMLEFT")
    Button(window, 258, 18, 120, "Reset position", function() ns:ResetPosition() end, "BOTTOMLEFT")
    Button(window, 384, 18, 120, "Page defaults", function()
        local p = pages[window.current or 1]
        if p and p.default then p.default() end
    end, "BOTTOMLEFT")
    local support = Button(window, -18, 18, 170, "|T" .. COIN_ICON .. ":14:14:0:0|t Support the author", function()
        SelectPage(pageByTitle["Support"] or #pages)
    end, "BOTTOMRIGHT")
    support:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Like the addon?")
        GameTooltip:AddLine("Send a few Warmane coins to " .. AUTHOR_CHAR .. " - " .. AUTHOR_REALM .. ".", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    support:SetScript("OnLeave", function() GameTooltip:Hide() end)

    window:SetScript("OnShow", function()
        ns:RefreshOptions()
        SelectPage(window.current or 1)
    end)
end

------------------------------------------------------------------------
-- Text popup (export / import)
------------------------------------------------------------------------
local popup
local function TextPopup(title, text, editable, onAccept, acceptLabel, withName)
    if not popup then
        popup = CreateFrame("Frame", "RetailPartyFramesTextPopup", UIParent)
        popup:SetWidth(520)
        popup:SetHeight(360)
        popup:SetPoint("CENTER")
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetToplevel(true)
        popup:EnableMouse(true)
        popup:SetMovable(true)
        popup:RegisterForDrag("LeftButton")
        popup:SetScript("OnDragStart", function(self) self:StartMoving() end)
        popup:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        popup:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        tinsert(UISpecialFrames, "RetailPartyFramesTextPopup")
        popup.title = popup:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        popup.title:SetPoint("TOP", 0, -18)
        local close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)

        local scroll = CreateFrame("ScrollFrame", NextName(), popup, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 20, -48)
        scroll:SetPoint("BOTTOMRIGHT", -40, 80)
        local eb = CreateFrame("EditBox", NextName(), scroll)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(440)
        eb:SetHeight(230)
        eb:SetScript("OnTextChanged", function(self)
            -- grow with the content so the scroll frame can scroll it
            local lines = select(2, string.gsub(self:GetText(), "\n", "")) + 1
            local needed = math.max(230, lines * 14 + math.floor(string.len(self:GetText()) / 70) * 14)
            self:SetHeight(needed)
        end)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scroll:SetScrollChild(eb)
        popup.edit = eb
        local bg = popup:CreateTexture(nil, "BACKGROUND")
        bg:SetPoint("TOPLEFT", scroll, "TOPLEFT", -4, 4)
        bg:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 4, -4)
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetVertexColor(0, 0, 0, 0.5)

        popup.nameBox = EditBox(popup, 20, -296, 180, nil)
        popup.nameLabel = popup:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        popup.nameLabel:SetPoint("BOTTOMLEFT", popup.nameBox, "TOPLEFT", -4, 2)
        popup.nameLabel:SetText("Profile name")
        popup.hint = popup:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        popup.hint:SetPoint("BOTTOMLEFT", 22, 22)
        popup.accept = Button(popup, -20, 18, 120, "OK", nil, "BOTTOMRIGHT")
        popup.selectAll = Button(popup, -146, 18, 100, "Select all", function()
            popup.edit:SetFocus()
            popup.edit:HighlightText()
        end, "BOTTOMRIGHT")
    end
    popup.title:SetText(title)
    popup.edit:SetText(text or "")
    popup.edit:SetCursorPosition(0)
    if editable then
        popup.edit:Enable()
        popup.hint:SetText("Paste the string (Ctrl+V), optionally enter a name, then press " .. (acceptLabel or "OK") .. ".")
    else
        popup.edit:Enable()
        popup.hint:SetText("Click 'Select all', then Ctrl+C to copy the string.")
    end
    if withName then popup.nameBox:Show() popup.nameLabel:Show() else popup.nameBox:Hide() popup.nameLabel:Hide() end
    popup.nameBox:SetText("")
    popup.accept:SetText(acceptLabel or "OK")
    popup.accept:SetScript("OnClick", function()
        if onAccept then
            if onAccept(popup.edit:GetText(), popup.nameBox:GetText()) == false then return end
        end
        popup:Hide()
    end)
    popup:Show()
    if not editable then
        popup.edit:SetFocus()
        popup.edit:HighlightText()
    end
end

------------------------------------------------------------------------
-- Pages
------------------------------------------------------------------------
local TOP = -56

local function BuildGeneral()
    local p = NewPage("General", "What is shown when. Settings apply immediately; use Test mode (bottom) to preview without a group.")
    local L = Column(p, 16, TOP)
    Header(L, "Groups")
    Check(L, "Show myself", "showPlayer", "Include your own frame in the party frames.")
    Check(L, "Show when solo", "showSolo", "Show your own frame even when you are not in a group.")
    Check(L, "Hide Blizzard party frames", "hideBlizzard", "Requires /reload to bring them back after unchecking.")
    L.y = L.y - 6
    Dropdown(L, "In a raid show", "raidMode", {
        { "RAID", "Raid frames" },
        { "PARTY", "My group as party frames" },
        { "BOTH", "Raid frames and party frames" },
    })
    Header(L, "Frames")
    Check(L, "Swap to vehicle when a member enters one", "vehicleSwap", "Shows the vehicle's health instead of the passenger (needs /reload to take full effect).")
    Dropdown(L, "Unit tooltips", "tooltips", {
        { "ALWAYS", "Always" },
        { "OOC", "Only out of combat" },
        { "NEVER", "Never" },
    })
    Slider(L, "Out of combat alpha", "oocAlpha", 0.2, 1, 0.05, "%.2f")
    Check(L, "Minimap button", "global:minimap.show", nil, function() ns:UpdateMinimapButton() end)

    local R = Column(p, 300, TOP)
    Header(R, "Announcements (off by default)")
    Check(R, "Announce used cooldowns", "announce.cooldowns", "Posts 'Name: Spell on Target' when a tracked cooldown of the categories below is used. Everyone with this on will post - use it on one character only.", function() end)
    Check(R, "Announce my dispels", "announce.dispels", "Posts what you dispelled from whom.", function() end)
    Dropdown(R, "Channel", "announce.channel", {
        { "AUTO", "Raid or party (automatic)" },
        { "PARTY", "Party" },
        { "RAID", "Raid" },
        { "SAY", "Say" },
        { "SELF", "Only me (chat frame)" },
    }, function() end)
    Header(R, "Announce these categories")
    Check(R, "External defensives", "announce.categories.external", nil, function() end)
    Check(R, "Raid cooldowns", "announce.categories.raid", nil, function() end)
    Check(R, "Interrupts", "announce.categories.interrupt", nil, function() end)
    Check(R, "Personal defensives", "announce.categories.defensive", nil, function() end)
    Note(R, "Nothing is posted while test mode is active.")
end

local function BuildParty()
    local p = NewPage("Party", "Layout of the party frames (player + up to 4 members). Also used in arenas and, if chosen, for your own group in raids.")
    local L = Column(p, 16, TOP)
    Header(L, "Order")
    Dropdown(L, "Sort by", "sortMode", {
        { "ROLE", "Role (tank, healer, damage)" },
        { "GROUP", "Group order" },
        { "CLASS", "Class" },
        { "NAME", "Name" },
    })
    Dropdown(L, "My frame", "playerPosition", {
        { "FIRST", "First" },
        { "LAST", "Last" },
        { "SORTED", "Sorted with the group" },
    })
    Dropdown(L, "Orientation", "orientation", {
        { "VERTICAL", "Vertical" },
        { "HORIZONTAL", "Horizontal" },
    })
    Header(L, "Pets")
    Check(L, "Show party pets", "partyPets", "Pets appear next to their owner (right of the frame in vertical layout, below in horizontal).")
    Slider(L, "Pet width", "petWidth", 40, 250, 1)
    Slider(L, "Pet height", "petHeight", 10, 60, 1)

    local R = Column(p, 300, TOP)
    Header(R, "Size")
    Slider(R, "Frame width", "width", 60, 250, 1)
    Slider(R, "Frame height", "height", 24, 120, 1)
    Slider(R, "Spacing", "spacing", 0, 20, 1)
    Slider(R, "Scale", "scale", 0.5, 2, 0.05, "%.2f")
    Note(R, "Drag the frames with 'Unlock frames' (bottom left) or /rpf move.", 20)
end

local function BuildRaid()
    local p = NewPage("Raid", "Raid frames for 10 to 40 players and battlegrounds. 'Test mode' twice shows a 25-man preview.")
    local L = Column(p, 16, TOP)
    Header(L, "Layout")
    Dropdown(L, "Arrangement", "raidLayout", {
        { "GROUPS", "One block per raid group" },
        { "COMBINED", "One block, sorted" },
    })
    Dropdown(L, "Units grow", "raidOrientation", {
        { "VERTICAL", "Downwards (columns)" },
        { "HORIZONTAL", "To the right (rows)" },
    })
    Dropdown(L, "Sorted blocks: group by", "raidGroupBy", {
        { "GROUP", "Raid group" },
        { "CLASS", "Class" },
        { "LFGROLE", "Role (tank, healer, damage)" },
        { "ROLE", "Main tank / assist first" },
        { "NONE", "Nothing (plain list)" },
    })
    Dropdown(L, "Sort inside a block by", "raidSort", {
        { "INDEX", "Raid order" },
        { "NAME", "Name" },
    })
    Slider(L, "Groups per line / column", "raidGroupsPerLine", 1, 8, 1)
    Slider(L, "Groups shown", "raidMaxGroups", 1, 8, 1)

    local R = Column(p, 300, TOP)
    Header(R, "Size")
    Slider(R, "Frame width", "raidWidth", 40, 160, 1)
    Slider(R, "Frame height", "raidHeight", 14, 80, 1)
    Slider(R, "Spacing", "raidSpacing", 0, 10, 1)
    Slider(R, "Spacing between groups", "raidGroupSpacing", 0, 30, 1)
    Slider(R, "Scale", "raidScale", 0.5, 2, 0.05, "%.2f")
    Header(R, "Extras")
    Check(R, "Group labels", "raidShowLabels")
    Check(R, "Raid pets", "raidPets", "Pets of all raid members in their own block next to the raid.")
    Check(R, "Main tank / main assist frames", "mtFrames", "Separate movable frames for the raid's main tanks and assists (set by the raid leader).")
end

local function BuildRaidStyle()
    local p = NewPage("Raid style", "What the smaller raid frames show. Colors, fonts and textures are shared with the Display page.")
    local L = Column(p, 16, TOP)
    Header(L, "Bars and text")
    Dropdown(L, "Power bars", "raidPowerBar", {
        { "NONE", "None" },
        { "HEALERS", "Healers only" },
        { "MANA", "Mana users" },
        { "ALL", "All" },
    })
    Dropdown(L, "Health text", "raidHealthText", {
        { "NONE", "None" },
        { "HEALTH", "Health remaining" },
        { "LOST", "Health lost" },
        { "PERCENT", "Percent" },
    })
    Slider(L, "Font size", "raidFontSize", 6, 16, 1)
    Header(L, "Modules")
    Check(L, "Cast bars in raid frames", "raidCastbar")
    Check(L, "Cooldown icons in raid frames", "raidCooldowns", "Can get busy in 25-man raids; the cooldown category filters still apply.")

    local R = Column(p, 300, TOP)
    Header(R, "Auras")
    Slider(R, "Max debuffs", "raidMaxDebuffs", 0, 4, 1)
    Slider(R, "Debuff size", "raidDebuffSize", 8, 30, 1)
    Slider(R, "Max buffs", "raidMaxBuffs", 0, 4, 1)
    Slider(R, "Buff size", "raidBuffSize", 8, 30, 1)
    Slider(R, "Pet debuffs", "petMaxDebuffs", 0, 3, 1)
end

local function BuildDisplay()
    local p = NewPage("Display", "Colors, bars, fonts and textures - shared by party, raid and pet frames.")
    local L = Column(p, 16, TOP)
    Header(L, "Health color")
    Dropdown(L, "Color mode", "healthColor", {
        { "CLASS", "Class color" },
        { "GRADIENT", "Green to red by health" },
        { "CUSTOM", "One color for everyone" },
    })
    ColorSwatch(L, "Custom health color", "healthCustom")
    Check(L, "Low health highlight", "lowHealthHighlight", "Dark red background and red percent text below the threshold.")
    Slider(L, "Low health threshold (%)", "lowHealthPercent", 5, 60, 5)
    Header(L, "Border and background")
    Check(L, "Display border", "showBorder")
    ColorSwatch(L, "Border color", "borderColor")
    Slider(L, "Background alpha", "bgAlpha", 0, 1, 0.05, "%.2f")
    Slider(L, "Frame alpha", "frameAlpha", 0.2, 1, 0.05, "%.2f")

    local R = Column(p, 300, TOP)
    Dropdown(R, "Health text", "healthText", {
        { "NONE", "None" },
        { "HEALTH", "Health remaining" },
        { "LOST", "Health lost" },
        { "PERCENT", "Percent" },
    })
    Dropdown(R, "Power bars", "powerBar", {
        { "HEALERS", "Healers only" },
        { "ALL", "All" },
        { "MANA", "Mana users" },
        { "NONE", "None" },
    })
    Dropdown(R, "Bar texture", "texture", MediaOptions("statusbar"))
    Dropdown(R, "Font", "font", MediaOptions("font"))
    Dropdown(R, "Font outline", "fontOutline", {
        { "NONE", "Shadow" },
        { "OUTLINE", "Outline" },
    })
    Slider(R, "Font size", "fontSize", 7, 18, 1)
    Slider(R, "Status text size", "statusTextSize", 7, 18, 1)
    Slider(R, "Power bar height", "powerHeight", 2, 15, 1)
end

local function BuildIcons()
    local p = NewPage("Icons & status", "Indicators drawn on top of the frames and how names and range are handled.")
    local L = Column(p, 16, TOP)
    Header(L, "Icons")
    Check(L, "Role icon", "roleIcon")
    Check(L, "Leader / assistant icon", "leaderIcon")
    Check(L, "Raid target icon", "raidIcon")
    Check(L, "Ready check", "readyCheck")
    Check(L, "Aggro highlight", "aggro", "Red/orange border when the unit has aggro.")
    Check(L, "Highlight my target", "targetHighlight")
    Check(L, "Highlight my focus", "focusHighlight")
    Check(L, "Incoming heals", "healPrediction", "Needs LibHealComm-4.0 (loaded by another addon, e.g. a 3.3.5 healing addon).")
    Check(L, "'Res' on dead players being resurrected", "resIncoming")
    Check(L, "AFK / DND text", "afkText")
    Check(L, "Arena: enemies targeting this unit", "arenaTargets", "Shows how many arena opponents target the unit (red when 2 or more).")
    Check(L, "Battleground: flag carrier icon", "bgFlags")

    local R = Column(p, 300, TOP)
    Header(R, "Names")
    Check(R, "Class colored names", "nameClassColor")
    Check(R, "Show level before the name", "showLevel")
    Slider(R, "Max name length (0 = no limit)", "nameLength", 0, 20, 1)
    Header(R, "Range")
    Dropdown(R, "Range check", "rangeCheck", {
        { "UNIT", "Follow / inspect range (UnitInRange)" },
        { "SPELL", "A spell's range (healers: 40 yards)" },
    })
    TextSetting(R, "Spell for the range check (empty = class default)", "rangeSpell", 200)
    Slider(R, "Out of range alpha", "rangeAlpha", 0.1, 1, 0.05, "%.2f")
end

local function BuildAuras()
    local p = NewPage("Buffs & Debuffs", "Debuffs you can dispel are shown first; the frame gets a colored border and glow in the debuff type color. Raid encounter debuffs can be shown larger.")
    local L = Column(p, 16, TOP)
    Header(L, "Debuffs")
    Check(L, "Display only dispellable debuffs", "onlyDispellable")
    Check(L, "Dispel border + glow on the frame", "dispelHighlight")
    Check(L, "Dispel type icons (top right)", "dispelIndicators")
    Check(L, "Highlight all debuff types", "highlightAllTypes", "Also highlight types you cannot remove yourself (good for calling dispels).")
    Check(L, "Hide trivial debuffs", "hideTrivialDebuffs", "Weakened Soul, Forbearance, Sated/Exhaustion, Hypothermia, Chill of the Throne, ...")
    Check(L, "Priority debuffs larger and first", "priorityDebuffs", "Known raid encounter debuffs (ICC, ToC, Ulduar, Naxx) and your whitelist.")
    Check(L, "Sound when I can dispel something", "dispelSound")
    Dropdown(L, "Dispel sound", "dispelSoundFile", MediaOptions("sound"), function()
        PlaySoundFile(ns:Fetch("sound", ns.db.dispelSoundFile))
    end)

    local R = Column(p, 300, TOP)
    Slider(R, "Max debuffs", "maxDebuffs", 0, 6, 1)
    Slider(R, "Debuff size", "debuffSize", 8, 32, 1)
    Slider(R, "Priority debuff size", "prioritySize", 10, 40, 1)
    Header(R, "Buffs")
    Check(R, "Only my buffs", "onlyMyBuffs", "Like retail: only your HoTs/shields.")
    Check(R, "Only whitelisted buffs", "buffWhitelistOnly", "Show nothing but the buff whitelist (Aura filters page).")
    Check(R, "Aura tooltips", "auraTooltips", "Mouseover tooltips on aura icons (icons then catch clicks).")
    Slider(R, "Max buffs", "maxBuffs", 0, 6, 1)
    Slider(R, "Buff size", "buffSize", 8, 32, 1)
    Slider(R, "Hide buffs longer than (sec)", "buffMaxDuration", 30, 3600, 30)
end

local function BuildAuraFilters()
    local p = NewPage("Aura filters", "Spell ids to always hide, always show (as priority debuffs) or always show as buffs. Press Enter or 'Add' after typing an id.")
    local half = floor((PAGE_W - 48) / 2)
    local function refresh() ns:UpdateAllButtons() end
    IdListEditor(p, 16, TOP - 4, half, 6, "Debuff blacklist (never shown)",
        function() return ns.db.debuffBlacklist end, "set", refresh)
    IdListEditor(p, 32 + half, TOP - 4, half, 6, "Debuff whitelist (always shown, priority)",
        function() return ns.db.debuffWhitelist end, "set", refresh)
    IdListEditor(p, 16, TOP - 226, half, 6, "Buff whitelist (always shown)",
        function() return ns.db.buffWhitelist end, "set", refresh)
    Text(p, 32 + half, TOP - 226, half,
        "Tip: Shift + right-click a cooldown icon hides that spell; hidden cooldowns are managed on the Spell editor page.\n\nSpell ids can be looked up on wowhead.com (WotLK) or with /dump GetSpellInfo(id) in game.",
        "GameFontHighlightSmall", 120)
end

local function BuildIndicators()
    local p = NewPage("Indicators", "Small colored squares in the frame corners for your own HoTs and shields - with timer and stacks. Defaults depend on your class.")
    local L = Column(p, 16, TOP)
    local function refresh()
        ns:InvalidateIndicators()
        ns:LayoutAllButtons()
        ns:UpdateAllButtons()
    end
    Header(L, "Settings")
    Check(L, "Enable indicators", "indicators.enabled", nil, refresh)
    Check(L, "Only auras cast by me", "indicators.mine", nil, refresh)
    Check(L, "Show remaining time", "indicators.showTimer", nil, refresh)
    Check(L, "Show stacks", "indicators.showStacks", nil, refresh)
    Slider(L, "Size", "indicators.size", 4, 16, 1, nil, refresh)
    Slider(L, "Timer below (sec)", "indicators.timerThreshold", 1, 30, 1, nil, refresh)
    L.y = L.y - 4
    Button(p, 16, L.y, 200, "Reset slots to class defaults", function()
        ns.db.indicators.slots = nil
        refresh()
        ns:RefreshOptions()
    end)
    L.y = L.y - 30
    Note(L, "Colors: top-left green, top-right yellow, bottom-left blue, bottom-right pink, center white.", 40)

    -- slot editor
    local slot = "TOPLEFT"
    local slotOpts = {}
    local slotNames = { TOPLEFT = "Top left (green)", TOPRIGHT = "Top right (yellow)", BOTTOMLEFT = "Bottom left (blue)", BOTTOMRIGHT = "Bottom right (pink)", CENTER = "Center (white)" }
    for _, s in ipairs(ns.IndicatorSlots) do slotOpts[#slotOpts + 1] = { s, slotNames[s] or s } end
    local R = Column(p, 300, TOP)
    local dd = RawDropdown(p, 300, R.y, 150, "Corner", slotOpts, function() return slot end, function(v)
        slot = v
        ns:RefreshOptions()
    end)
    p.widgets[#p.widgets + 1] = dd
    IdListEditor(p, 300, TOP - 46, PAGE_W - 316, 7, "Spells in this corner (first match wins)",
        function()
            local slots = ns:EnsureIndicatorSlots()
            slots[slot] = slots[slot] or {}
            return slots[slot]
        end, "array", refresh)
end

local function BuildCastbars()
    local p = NewPage("Cast bars & reminders", "Cast bar strip inside each frame (yellow = cast, green = channel, grey = not interruptible, red = interrupted) and the missing-buff reminder icon.")
    local L = Column(p, 16, TOP)
    Header(L, "Cast bars")
    Check(L, "Show cast bars (party frames)", "castbar")
    Check(L, "Show spell icon", "castbarIcon")
    Check(L, "Show spell name", "castbarText")
    Check(L, "Show remaining time", "castbarTimer")
    Slider(L, "Cast bar height", "castbarHeight", 4, 20, 1)
    Note(L, "Raid frames have their own switch on the 'Raid style' page.", 20)
    local R = Column(p, 300, TOP)
    local function refresh()
        ns:InvalidateReminders()
        ns:LayoutAllButtons()
        ns:UpdateAllButtons()
    end
    Header(R, "Missing buff reminders")
    Check(R, "Show an icon when a buff of mine is missing", "reminders.enabled", "Priests: Fortitude, Spirit, Shadow Protection. Mages: Intellect. Druids: Mark of the Wild. Paladins: any blessing. Only buffs you actually know.", refresh)
    Check(R, "Hide in combat", "reminders.hideInCombat", nil, refresh)
    Dropdown(R, "Position", "reminders.position", {
        { "BOTTOMRIGHT", "Bottom right" },
        { "TOPRIGHT", "Top right" },
        { "CENTER", "Center" },
    }, refresh)
    Slider(R, "Icon size", "reminders.size", 8, 24, 1, nil, refresh)
    Slider(R, "Icon alpha", "reminders.alpha", 0.2, 1, 0.05, "%.2f", refresh)
end

local function BuildCooldowns()
    local p = NewPage("Party cooldowns", "Tracked from the combat log - nobody else needs the addon. Group members are inspected for talents and glyphs; what cannot be inspected is picked up on first use.")
    local L = Column(p, 16, TOP)
    Header(L, "Behaviour")
    Check(L, "Enable party cooldowns", "cooldowns")
    Check(L, "Show only spells on cooldown", "cdOnlyActive")
    Check(L, "Show countdown text", "cdText")
    Check(L, "Desaturate while on cooldown", "cdDesaturate")
    Check(L, "Glow while the effect is active", "cdGlow")
    Check(L, "Track my own cooldowns", "cdShowSelf")
    Check(L, "Learn talent/glyph cooldowns", "cdLearn")
    Check(L, "Inspect group talents", "cdInspect", "Reads talents and glyphs of party members (28 yards) so talent cooldowns show up right away with the correct duration. /rpf inspect forces a refresh.")
    Check(L, "Icon tooltips", "cdTooltips", "Icons catch the mouse when enabled. Shift + right-click an icon to hide that spell.")
    Check(L, "Arena: PvP trinket first", "cdArenaTrinket")
    L.y = L.y - 4
    Dropdown(L, "Position", "cdAnchor", {
        { "RIGHT", "Right of the frame" },
        { "LEFT", "Left of the frame" },
        { "BOTTOM", "Below the frame" },
        { "TOP", "Above the frame" },
    })

    local R = Column(p, 300, TOP)
    Header(R, "Categories")
    for _, c in ipairs(ns.CDCategories) do
        Check(R, c.label, "cdCategories." .. c.key)
    end
    Slider(R, "Icon size", "cdSize", 12, 40, 1)
    Slider(R, "Icons per row", "cdPerRow", 1, 10, 1)
    Slider(R, "Max icons", "cdMax", 1, 16, 1)
    Slider(R, "Spacing", "cdSpacing", 0, 8, 1)
end

function ns:CustomSpellsChanged()
    self:RebuildSpellIndex()
    self:ForEachButton(function(b) self:UpdateCooldownIcons(b) end)
    self:RefreshOptions()
end

local function BuildSpellEditor()
    local p = NewPage("Spell editor", "Add spells the tracker does not know, override a cooldown (enter an existing spell id), or restore spells you hid with Shift + right-click.")
    local y = -80

    local idBox = EditBox(p, 16, y, 80, "Spell ID")
    local cdBox = EditBox(p, 110, y, 80, "Cooldown (sec)")

    local nameText = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    nameText:SetPoint("TOPLEFT", 16, y - 24)
    nameText:SetPoint("RIGHT", p, "RIGHT", -16, 0)
    nameText:SetJustifyH("LEFT")
    idBox:SetScript("OnTextChanged", function(self)
        local id = tonumber(self:GetText())
        local name = id and GetSpellInfo(id)
        if name then
            local e = ns.SpellIndex[id]
            nameText:SetText(SpellLabel(id, e and e.cd, e and "already tracked - the cooldown will be overridden"))
            if e and cdBox:GetText() == "" then cdBox:SetText(tostring(e.cd)) end
        else
            nameText:SetText(id and "|cffff6060Unknown spell id|r" or "")
        end
    end)

    local classOpts = { { "ANY", "Any class" } }
    for _, token in ipairs(ns.ClassTokens) do
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
        local label = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or token
        if c then label = string.format("|cff%02x%02x%02x%s|r", floor(c.r * 255), floor(c.g * 255), floor(c.b * 255), label) end
        classOpts[#classOpts + 1] = { token, label }
    end
    local catOpts = {}
    for _, c in ipairs(ns.CDCategories) do catOpts[#catOpts + 1] = { c.key, c.label } end

    local state = { class = "ANY", cat = "utility" }
    local d1 = RawDropdown(p, 210, y + 14, 120, "Class", classOpts, function() return state.class end, function(v) state.class = v end)
    local d2 = RawDropdown(p, 345, y + 14, 120, "Category", catOpts, function() return state.cat end, function(v) state.cat = v end)
    d1.Refresh()
    d2.Refresh()

    Button(p, 16, y - 44, 140, "Add / override", function()
        local id, cd = tonumber(idBox:GetText()), tonumber(cdBox:GetText())
        if not id or not GetSpellInfo(id) then ns:Print("Please enter a valid spell id.") return end
        if not cd or cd <= 0 then ns:Print("Please enter the cooldown in seconds.") return end
        local list = ns.db.customSpells
        for i = #list, 1, -1 do
            if tonumber(list[i].id) == id then table.remove(list, i) end
        end
        local existing = ns.SpellIndex[id]
        list[#list + 1] = { id = id, cd = cd, class = existing and existing.class or state.class, cat = existing and existing.cat or state.cat }
        idBox:SetText("")
        cdBox:SetText("")
        ns:CustomSpellsChanged()
    end)
    Button(p, 162, y - 44, 140, "Remove all custom", function()
        ns.db.customSpells = {}
        ns:CustomSpellsChanged()
    end)

    local half = floor((PAGE_W - 48) / 2)
    local customList = MakeList(p, 16, y - 84, half, 7, "Custom spells and overrides", function(key)
        local list = ns.db.customSpells
        for i = #list, 1, -1 do
            if tonumber(list[i].id) == key then table.remove(list, i) end
        end
        ns:CustomSpellsChanged()
    end, "Remove")

    local hiddenList = MakeList(p, 32 + half, y - 84, half, 7, "Hidden spells", function(key)
        ns.db.cdHidden[key] = nil
        ns:CustomSpellsChanged()
    end, "Show")

    p.widgets[#p.widgets + 1] = { Refresh = function()
        local items = {}
        for _, cs in ipairs(ns.db.customSpells) do
            local id = tonumber(cs.id)
            if id then
                local base
                for _, e in ipairs(ns.SpellDB) do if e.id == id then base = e break end end
                items[#items + 1] = { key = id, label = SpellLabel(id, tonumber(cs.cd), base and ("was " .. base.cd .. "s") or (cs.class or "ANY")) }
            end
        end
        FillList(customList, items)
        items = {}
        for id in pairs(ns.db.cdHidden) do
            items[#items + 1] = { key = id, label = SpellLabel(id) }
        end
        table.sort(items, function(a, b) return a.key < b.key end)
        FillList(hiddenList, items)
    end }
end

local function BuildClickCast()
    local p = NewPage("Click-casting", "Bind spells, macros and actions to mouse buttons on the frames. Changes apply out of combat. If Clique is loaded it takes over by default.")
    local L = Column(p, 16, TOP)
    local function apply() ns:ApplyAllClickBindings() ns:RefreshOptions() end
    Check(L, "Enable built-in click-casting", "clickCast.enabled", nil, apply)
    Check(L, "Let Clique handle clicks when it is loaded", "clickCast.respectClique", nil, apply)
    local status = Text(p, 20, L.y, 260, "", "GameFontDisableSmall", 30)
    L.y = L.y - 34

    local selected = 1
    local list = MakeList(p, 16, L.y, 260, 8, "Bindings (click to edit)", function(key)
        ns:RemoveClickBinding(key)
        selected = 1
        ns:RefreshOptions()
    end, "Remove", function(key)
        selected = key
        ns:RefreshOptions()
    end)
    Button(p, 16, L.y - list.height - 2, 120, "New binding", function()
        selected = ns:AddClickBinding()
        ns:RefreshOptions()
    end)

    -- editor for the selected binding
    local ex = 300
    local ey = TOP
    local eh = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    eh:SetPoint("TOPLEFT", ex, ey)
    eh:SetText("Edit binding")
    local function current()
        return ns.db.clickCast.bindings[selected]
    end
    local function changed()
        ns:ApplyAllClickBindings()
        ns:RefreshOptions()
    end
    local dButton = RawDropdown(p, ex, ey - 22, 120, "Mouse button", ns.ClickButtons,
        function() local b = current() return b and tonumber(b.button) or 1 end,
        function(v) local b = current() if b then b.button = v changed() end end)
    local dMod = RawDropdown(p, ex + 150, ey - 22, 120, "Modifier", ns.ClickModifiers,
        function() local b = current() return b and (b.mod or "") or "" end,
        function(v) local b = current() if b then b.mod = v changed() end end)
    local dType = RawDropdown(p, ex, ey - 74, 120, "Action", ns.ClickTypes,
        function() local b = current() return b and b.type or "target" end,
        function(v) local b = current() if b then b.type = v changed() end end)
    local valueBox = EditBox(p, ex, ey - 134, 250, "Spell name (exact) or macro text")
    local function saveValue(self)
        local b = current()
        if b then
            local v = ns.Trim(self:GetText())
            if b.value ~= v then
                b.value = v
                changed()
            end
        end
        self:ClearFocus()
    end
    valueBox:SetScript("OnEnterPressed", saveValue)
    valueBox:SetScript("OnEditFocusLost", saveValue)
    local conflict = Text(p, ex, ey - 162, 250, "", "GameFontRedSmall", 30)
    Text(p, ex, ey - 200, PAGE_W - ex - 16,
        "Examples:\n|cffffffffCast spell|r - Flash Heal, Rejuvenation, Power Word: Shield\n|cffffffffMacro|r - /cast [@mouseover] Cleanse\n|cffffffffAssist|r targets the unit's target.\n\nUnmodified left/right clicks default to target and the unit menu when no binding exists.",
        "GameFontHighlightSmall", 120)

    p.widgets[#p.widgets + 1] = { Refresh = function()
        local items = {}
        for i, b in ipairs(ns.db.clickCast.bindings) do
            local btnLabel = "?"
            for _, o in ipairs(ns.ClickButtons) do if o[1] == tonumber(b.button) then btnLabel = o[2] end end
            local modLabel = ""
            for _, o in ipairs(ns.ClickModifiers) do if o[1] == (b.mod or "") and o[1] ~= "" then modLabel = o[2] .. " + " end end
            local typeLabel = b.type
            for _, o in ipairs(ns.ClickTypes) do if o[1] == b.type then typeLabel = o[2] end end
            local val = (b.type == "spell" or b.type == "macro") and (b.value ~= "" and b.value or "|cffff6060(empty)|r") or ""
            items[#items + 1] = { key = i, label = string.format("%s%s: %s %s", modLabel, btnLabel, typeLabel, val) }
        end
        if selected > #items then selected = #items end
        if selected < 1 then selected = 1 end
        FillList(list, items, selected)
        local b = current()
        dButton.Refresh()
        dMod.Refresh()
        dType.Refresh()
        valueBox:SetText(b and b.value or "")
        if b and (b.type == "spell" or b.type == "macro") then valueBox:Show() else valueBox:Hide() end
        conflict:SetText(ns:ClickBindingConflict(selected) and "Another binding uses the same button and modifier." or "")
        if ns:CliqueActive() and ns.db.clickCast.enabled then
            status:SetText("Clique is loaded and handles the clicks. Uncheck the option above to use these bindings instead.")
        elseif not ns.db.clickCast.enabled then
            status:SetText("Disabled: left-click targets, right-click opens the unit menu.")
        else
            status:SetText(string.format("%d binding(s) active on all frames.", #items))
        end
    end }
end

local function BuildProfiles()
    local p = NewPage("Profiles", "Profiles hold every setting. Each character remembers its profile; profiles can switch automatically by group type.")
    local L = Column(p, 16, TOP)
    local function names()
        local t = {}
        for _, n in ipairs(ns:ProfileNames()) do t[#t + 1] = { n, n } end
        return t
    end
    local function namesWithNone()
        local t = { { "", "(keep current)" } }
        for _, n in ipairs(ns:ProfileNames()) do t[#t + 1] = { n, n } end
        return t
    end
    Header(L, "Active profile")
    local dActive = RawDropdown(p, 16, L.y, 170, nil, names,
        function() return ns:ActiveProfileName() end,
        function(v) ns:SetProfile(v, true) end)
    p.widgets[#p.widgets + 1] = dActive
    L.y = L.y - 40
    local newBox = EditBox(p, 16, L.y - 14, 170, "New profile")
    L.y = L.y - 40
    Button(p, 16, L.y, 125, "Create (copy current)", function()
        local ok, err = ns:CreateProfile(newBox:GetText(), ns:ActiveProfileName())
        if ok then ns:SetProfile(ns.Trim(newBox:GetText()), true) newBox:SetText("") else ns:Print(err) end
        ns:RefreshOptions()
    end)
    Button(p, 146, L.y, 125, "Create (defaults)", function()
        local ok, err = ns:CreateProfile(newBox:GetText(), nil)
        if ok then ns:SetProfile(ns.Trim(newBox:GetText()), true) newBox:SetText("") else ns:Print(err) end
        ns:RefreshOptions()
    end)
    L.y = L.y - 34
    local other = ""
    local dOther = RawDropdown(p, 16, L.y, 170, "Other profile", names,
        function() return other end, function(v) other = v end)
    p.widgets[#p.widgets + 1] = dOther
    L.y = L.y - 52
    Button(p, 16, L.y, 125, "Copy into current", function()
        if other == "" or other == ns:ActiveProfileName() then ns:Print("Pick another profile first.") return end
        ns:CopyProfileInto(other)
        ns:RefreshOptions()
    end)
    Button(p, 146, L.y, 125, "Delete", function()
        if other == "" then ns:Print("Pick a profile first.") return end
        if other == ns:ActiveProfileName() then ns:Print("The active profile cannot be deleted.") return end
        ns:DeleteProfile(other)
        other = ""
        ns:RefreshOptions()
    end)
    L.y = L.y - 30
    Button(p, 16, L.y, 125, "Reset current", function()
        ns:ResetProfile()
        ns:RefreshOptions()
    end)
    L.y = L.y - 36
    Header(L, "Presets")
    local presetKey = ns.Presets[1] and ns.Presets[1].key or ""
    local presetOpts = {}
    for _, pr in ipairs(ns.Presets) do presetOpts[#presetOpts + 1] = { pr.key, pr.key } end
    local dPreset = RawDropdown(p, 16, L.y, 150, nil, presetOpts,
        function() return presetKey end, function(v) presetKey = v end)
    dPreset.Refresh()
    Button(p, 196, L.y - 2, 100, "Create", function()
        local name, err = ns:CreatePresetProfile(presetKey)
        if not name then ns:Print(err) return end
        ns:Print("Profile '" .. name .. "' created from preset.")
        ns:SetProfile(name, true)
        ns:RefreshOptions()
    end)
    local presetText = Text(p, 16, L.y - 30, 270, "", "GameFontHighlightSmall", 44)
    p.widgets[#p.widgets + 1] = { Refresh = function()
        local pr = ns:PresetByKey(presetKey)
        presetText:SetText(pr and pr.description or "")
    end }
    L.y = L.y - 80
    Header(L, "Share")
    Button(p, 16, L.y, 125, "Export", function()
        TextPopup("Export profile '" .. ns:ActiveProfileName() .. "'", ns:ExportProfile(), false, nil, "Close", false)
    end)
    Button(p, 146, L.y, 125, "Import", function()
        TextPopup("Import profile", "", true, function(text, name)
            local ok, result = ns:ImportProfile(text, name)
            if not ok then
                ns:Print(result)
                return false
            end
            ns:Print("Profile '" .. result .. "' imported.")
            ns:SetProfile(result, true)
            ns:RefreshOptions()
        end, "Import", true)
    end)

    local R = Column(p, 300, TOP)
    Header(R, "Automatic profiles")
    Check(R, "Switch profile by group type", "global:autoProfiles.enabled", nil, function() ns:UpdateGroupType(true) end)
    for _, key in ipairs({ "solo", "party", "raid10", "raid25", "raid40", "arena", "bg" }) do
        Dropdown(R, ns.GroupTypeLabels[key], "global:autoProfiles." .. key, namesWithNone, function() ns:UpdateGroupType(true) end)
    end
end

local function BuildSupport()
    local sup = NewPage("Support", "Thanks for using RetailPartyFrames!")
    local bottom = DonateBlock(sup, 16, TOP - 4, PAGE_W - 32)
    Text(sup, 16, bottom - 6, PAGE_W - 32,
        "Found a bug or missing a feature? Whisper or mail |cffffffff" .. AUTHOR_CHAR .. "|r on " .. AUTHOR_REALM ..
        ". Include the output of |cffffffff/rpf debug|r and the Lua error text if you have one.\n\n" ..
        "Slash commands: |cffffffff/rpf|r options  |cffffffff/rpf move|r unlock  |cffffffff/rpf test|r preview (party, raid, off)  " ..
        "|cffffffff/rpf reset|r positions  |cffffffff/rpf profile <name>|r  |cffffffff/rpf inspect|r  |cffffffff/rpf minimap|r  |cffffffff/rpf debug|r\n\n" ..
        "Key bindings for the options window, test mode and lock are in the game's Key Bindings menu under RetailPartyFrames.",
        "GameFontHighlightSmall", 150)
end

local function BuildPages()
    BuildGeneral()
    BuildParty()
    BuildRaid()
    BuildRaidStyle()
    BuildDisplay()
    BuildIcons()
    BuildAuras()
    BuildAuraFilters()
    BuildIndicators()
    BuildCastbars()
    BuildCooldowns()
    BuildSpellEditor()
    BuildClickCast()
    BuildProfiles()
    BuildSupport()
end

------------------------------------------------------------------------
-- Interface > AddOns entry (launcher + donation info)
------------------------------------------------------------------------
local function BuildLauncher()
    local p = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer or UIParent)
    p.name = "RetailPartyFrames"
    p:Hide()

    local t = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText("RetailPartyFrames  |cff888888v" .. ns.version .. "|r")

    local d = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
    d:SetWidth(LAUNCHER_W)
    d:SetHeight(32)
    d:SetJustifyH("LEFT")
    d:SetJustifyV("TOP")
    d:SetText("Retail-style party and raid frames with cast bars, party cooldowns, dispel highlighting, indicators and click-casting. All settings live in their own window.")

    Button(p, 16, -70, 220, "Open RetailPartyFrames options", function()
        HideUIPanel(InterfaceOptionsFrame)
        ns:OpenOptions()
    end)
    Button(p, 242, -70, 110, "Test mode", function() ns:CycleTestMode() end)
    local hint = p:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 16, -98)
    hint:SetText("or type /rpf")

    DonateBlock(p, 16, -140, LAUNCHER_W)

    p.okay = function() end
    p.cancel = function() end
    p.default = function() end
    InterfaceOptions_AddCategory(p)
end

------------------------------------------------------------------------
-- Public
------------------------------------------------------------------------
function ns:RefreshOptions()
    if not window then return end
    window.lockBtn:SetText(self.db.locked and "Unlock frames" or "Lock frames")
    window.testBtn:SetText(self.testMode == "party" and "Test: party" or self.testMode == "raid" and "Test: raid" or "Test mode")
    if window:IsShown() then
        local p = pages[window.current or 1]
        if p then p.refresh() end
    end
end

local buildError

local function Build()
    if window then return true end
    local ok, err = pcall(function()
        CreateWindow()
        BuildPages()
        BuildLauncher()
    end)
    if not ok then
        buildError = err
        window = nil
        return false
    end
    return true
end

function ns:OpenOptions(pageTitle)
    if not window and not Build() then
        self:Print("|cffff4040The options window could not be built:|r " .. tostring(buildError))
        self:ReportInitErrors()
        self:Print("Frames still work. Use /rpf move, /rpf test, /rpf reset in the meantime.")
        return
    end
    if pageTitle and pageByTitle[pageTitle] then
        window.current = pageByTitle[pageTitle]
        if window:IsShown() then SelectPage(window.current) else window:Show() end
        return
    end
    if window:IsShown() then
        window:Hide()
    else
        window:Show()
    end
end

ns:RegisterInit(function()
    if not Build() then error(buildError) end
    ns:RefreshOptions()
end, "options")
