-- BetterFrames335 - Options.lua
-- Standalone, movable options window with a tab column and scrollable pages (/bbf).
-- Interface > AddOns > BetterFrames 335 holds a small panel with a button that opens the window.

local BBF = BBF335
local M = BBF:NewModule("Options")
local db

local WINDOW_NAME = "BBF335Options"
local WIDTH, HEIGHT = 820, 600
local TABW = 128                  -- tab column width
local PAGEW = WIDTH - TABW - 60   -- usable page width
local COL2 = math.floor(PAGEW / 2) + 10
local PAGE_HEIGHT = 1100          -- scroll child height (pages scroll)

local count = 0
local function uid()
    count = count + 1
    return "BBF335Opt" .. count
end

----------------------------------------------------------------------
-- widgets
----------------------------------------------------------------------
local function Text(p, text, x, y, font, width)
    local fs = p:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
    if width then
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
    end
    fs:SetText(text)
    return fs
end

local function Button(p, text, w, onClick)
    local b = CreateFrame("Button", uid(), p, "UIPanelButtonTemplate")
    b:SetWidth(w or 100)
    b:SetHeight(22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

-- cursor based layout
local function Cursor(p, x, y) return { p = p, x = x, y = y } end

local function AddHeader(c, text)
    Text(c.p, text, c.x, c.y - 4, "GameFontNormal")
    c.y = c.y - 24
end

local function AddNote(c, text, width)
    local fs = Text(c.p, text, c.x, c.y - 2, nil, width or (COL2 - 30))
    c.y = c.y - fs:GetStringHeight() - 10
    -- GetStringHeight can be 0 before the first render; keep a sane minimum
    if fs:GetStringHeight() == 0 then c.y = c.y - 24 end
    return fs
end

local function AddCheck(c, key, label, indent, onChange)
    local name = uid()
    local cb = CreateFrame("CheckButton", name, c.p, "UICheckButtonTemplate")
    cb:SetWidth(24)
    cb:SetHeight(24)
    cb:SetPoint("TOPLEFT", c.p, "TOPLEFT", c.x + (indent or 0), c.y)
    local txt = _G[name .. "Text"]
    if txt then
        txt:SetText(label)
        txt:SetFontObject("GameFontHighlightSmall")
    end
    cb:SetScript("OnClick", function(self)
        db[key] = self:GetChecked() and true or false
        PlaySound(db[key] and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
        if onChange then onChange(db[key]) end
        BBF:ApplyAll()
    end)
    tinsert(c.p.bbfRefresh, function() cb:SetChecked(db[key]) end)
    c.y = c.y - 24
    return cb
end

local function AddSlider(c, key, label, minv, maxv, step, fmt)
    local name = uid()
    local s = CreateFrame("Slider", name, c.p, "OptionsSliderTemplate")
    s:SetWidth(COL2 - 60)
    s:SetPoint("TOPLEFT", c.p, "TOPLEFT", c.x + 4, c.y - 16)
    s.bbfSilent = true
    s:SetMinMaxValues(minv, maxv)
    s:SetValueStep(step)
    _G[name .. "Low"]:SetText(minv)
    _G[name .. "High"]:SetText(maxv)
    local label_fs = _G[name .. "Text"]
    local function SetLabel(v)
        label_fs:SetText(label .. ": |cffffffff" .. (fmt and format(fmt, v) or tostring(v)) .. "|r")
    end
    s:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / step + 0.5) * step
        SetLabel(v)
        if self.bbfSilent then return end
        if db[key] ~= v then
            db[key] = v
            BBF:ApplySoon(0.15)   -- debounced: dragging fires this many times per second
        end
    end)
    s.bbfSilent = nil
    tinsert(c.p.bbfRefresh, function()
        s.bbfSilent = true
        s:SetValue(db[key])
        SetLabel(db[key])
        s.bbfSilent = nil
    end)
    c.y = c.y - 50
    return s
end

-- options = { { value = , text = }, ... }
local function AddDropdown(c, key, label, options, width, onChange)
    local name = uid()
    Text(c.p, label, c.x + 4, c.y - 2, "GameFontNormalSmall")
    local dd = CreateFrame("Frame", name, c.p, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", c.p, "TOPLEFT", c.x - 14, c.y - 14)
    UIDropDownMenu_SetWidth(dd, width or 170)
    local function TextFor(v)
        for _, o in ipairs(options) do if o.value == v then return o.text end end
        return tostring(v)
    end
    local function SetShown()
        local t = _G[name .. "Text"]
        if t then t:SetText(TextFor(db[key])) end
    end
    UIDropDownMenu_Initialize(dd, function()
        for _, o in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = o.text
            info.value = o.value
            info.checked = (db[key] == o.value)
            info.func = function()
                db[key] = o.value
                UIDropDownMenu_SetSelectedValue(dd, o.value)
                SetShown()
                if onChange then onChange(o.value) end
                BBF:ApplyAll()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    tinsert(c.p.bbfRefresh, function()
        UIDropDownMenu_SetSelectedValue(dd, db[key])
        SetShown()
    end)
    c.y = c.y - 48
    return dd
end

-- text field bound to a db key (saved on Enter / focus loss)
local function AddEdit(c, key, label, width, onChange)
    Text(c.p, label, c.x + 4, c.y - 2, "GameFontNormalSmall")
    local eb = CreateFrame("EditBox", uid(), c.p, "InputBoxTemplate")
    eb:SetWidth(width or (COL2 - 60))
    eb:SetHeight(20)
    eb:SetPoint("TOPLEFT", c.p, "TOPLEFT", c.x + 10, c.y - 16)
    eb:SetAutoFocus(false)
    eb:SetFontObject("GameFontHighlightSmall")
    local function Save(self)
        local v = self:GetText()
        if db[key] ~= v then
            db[key] = v
            if onChange then onChange(v) end
            BBF:ApplyAll()
        end
    end
    eb:SetScript("OnEnterPressed", function(self) Save(self); self:ClearFocus() end)
    eb:SetScript("OnEditFocusLost", Save)
    eb:SetScript("OnEscapePressed", function(self) self:SetText(db[key] or ""); self:ClearFocus() end)
    tinsert(c.p.bbfRefresh, function() eb:SetText(db[key] or "") end)
    c.y = c.y - 44
    return eb
end

local function ReloadHint(v)
    if not v then BBF:Print("hidden elements come back after a /reload") end
end

----------------------------------------------------------------------
-- window, tab column & scrollable pages
----------------------------------------------------------------------
local window, pages, tabs = nil, {}, {}

local function SelectTab(index)
    for i, page in ipairs(pages) do
        if i == index then
            page.scroll:Show()
            tabs[i]:LockHighlight()
            tabs[i]:SetNormalFontObject("GameFontHighlight")
        else
            page.scroll:Hide()
            tabs[i]:UnlockHighlight()
            tabs[i]:SetNormalFontObject("GameFontNormal")
        end
    end
    db.lastTab = index
end

local function CreateWindow()
    local f = CreateFrame("Frame", WINDOW_NAME, UIParent)
    f:SetWidth(WIDTH)
    f:SetHeight(HEIGHT)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:Hide()

    local titleBg = f:CreateTexture(nil, "ARTWORK")
    titleBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    titleBg:SetWidth(300)
    titleBg:SetHeight(64)
    titleBg:SetPoint("TOP", f, "TOP", 0, 12)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", titleBg, "TOP", 0, -14)
    title:SetText("BetterFrames 335  |cff888888v" .. BBF.version .. "|r")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)

    -- tab column background
    local tabBg = CreateFrame("Frame", nil, f)
    tabBg:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -40)
    tabBg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 44)
    tabBg:SetWidth(TABW)
    tabBg:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    tabBg:SetBackdropColor(0, 0, 0, 0.4)
    f.tabBg = tabBg

    -- footer
    local reload = Button(f, "Reload UI", 90, function() ReloadUI() end)
    reload:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 16)
    local reset = Button(f, "Reset all", 90, function() StaticPopup_Show("BBF335_RESET") end)
    reset:SetPoint("RIGHT", reload, "LEFT", -6, 0)
    local donate = Button(f, "Buy me a coffee", 130, function() StaticPopup_Show("BBF335_DONATE") end)
    donate:SetPoint("RIGHT", reset, "LEFT", -14, 0)
    local move = Button(f, "Move frames", 110, function() f:Hide(); BBF:ToggleMove() end)
    move:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 16)
    local test = Button(f, "Test castbars", 110, function() BBF:ToggleCastTest() end)
    test:SetPoint("LEFT", move, "RIGHT", 6, 0)

    tinsert(UISpecialFrames, WINDOW_NAME)
    return f
end

StaticPopupDialogs["BBF335_RESET"] = {
    text = "BetterFrames 335: reset ALL settings of the current profile and reload the UI?",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        BetterFrames335DB.profiles[BBF:CurrentProfile()] = {}   -- refilled with defaults on load
        ReloadUI()
    end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

local function AddPage(title)
    local index = #pages + 1
    local scroll = CreateFrame("ScrollFrame", uid(), window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", window, "TOPLEFT", TABW + 24, -44)
    scroll:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -36, 46)
    local page = CreateFrame("Frame", nil, scroll)
    page:SetWidth(PAGEW)
    page:SetHeight(PAGE_HEIGHT)
    scroll:SetScrollChild(page)
    page.scroll = scroll
    page.bbfRefresh = {}
    scroll:SetScript("OnShow", function()
        for _, fn in ipairs(page.bbfRefresh) do fn() end
        scroll:SetVerticalScroll(0)
    end)
    scroll:Hide()
    pages[index] = page

    local tab = Button(window, title, TABW - 12, function() SelectTab(index) end)
    if index == 1 then
        tab:SetPoint("TOPLEFT", window.tabBg, "TOPLEFT", 6, -8)
    else
        tab:SetPoint("TOPLEFT", tabs[index - 1], "BOTTOMLEFT", 0, -2)
    end
    tabs[index] = tab
    return page
end

----------------------------------------------------------------------
-- donate
----------------------------------------------------------------------
local DONATE_URL   = "https://www.warmane.com/account/services"
local DONATE_CHAR  = "Samyd"
local DONATE_REALM = "Blackrock"
local DONATE_TEXT  = "Enjoying BetterFrames? You can send a few Warmane coins to |cffffffff" .. DONATE_CHAR
    .. "|r on |cffffffff" .. DONATE_REALM .. "|r. Thank you!"

-- read-only edit box: click = select all, Ctrl+C copies, typing can't change it
local function CopyBox(parent, text, width)
    local eb = CreateFrame("EditBox", uid(), parent, "InputBoxTemplate")
    eb:SetWidth(width or 300)
    eb:SetHeight(20)
    eb:SetAutoFocus(false)
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetText(text)
    eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    eb:SetScript("OnMouseUp", function(self) self:SetFocus(); self:HighlightText() end)
    eb:SetScript("OnTextChanged", function(self)
        if self:GetText() ~= text then self:SetText(text); self:HighlightText() end
    end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return eb
end

StaticPopupDialogs["BBF335_DONATE"] = {
    text = DONATE_TEXT .. "\n\nCopy the link below (Ctrl+C), open it in your browser and use the coin transfer:",
    button1 = CLOSE,
    hasEditBox = 1,
    editBoxWidth = 320,
    OnShow = function(self)
        local eb = _G[self:GetName() .. "EditBox"]
        if eb then
            eb:SetWidth(320)
            eb:SetText(DONATE_URL)
            eb:SetFocus()
            eb:HighlightText()
        end
    end,
    EditBoxOnTextChanged = function(self)
        if self:GetText() ~= DONATE_URL then self:SetText(DONATE_URL); self:HighlightText() end
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

----------------------------------------------------------------------
-- pages
----------------------------------------------------------------------
-- preset buttons (used on the General and Profiles pages)
local function AddPresets(p, c)
    AddHeader(c, "Presets")
    local x = c.x + 4
    for _, key in ipairs({ "arena", "raid" }) do
        local preset = BBF.presets[key]
        local b = Button(p, preset.name, 130, function()
            local d = StaticPopupDialogs["BBF335_PRESET"]
            d.text = "Apply the preset |cffffffff" .. preset.name .. "|r?\n\n" .. preset.desc
                .. "\n\nThis overwrites the related options of the current profile. Aura lists and frame positions are kept."
            d.OnAccept = function()
                BBF:ApplyPreset(key)
                for _, page in ipairs(pages) do
                    if page.scroll:IsShown() then for _, fn in ipairs(page.bbfRefresh) do fn() end end
                end
            end
            StaticPopup_Show("BBF335_PRESET")
        end)
        b:SetPoint("TOPLEFT", p, "TOPLEFT", x, c.y)
        x = x + 136
    end
    c.y = c.y - 28
    AddNote(c, "Tip: create a profile per role first (Profiles tab), then apply a preset to it. "
        .. "Also: /bbf preset arena | raid")
end

StaticPopupDialogs["BBF335_PRESET"] = {
    text = "Apply preset?",
    button1 = YES,
    button2 = NO,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

local function BuildGeneral()
    local p = AddPage("General")
    local c = Cursor(p, 8, -6)
    AddPresets(p, c)
    c.y = c.y - 6
    AddHeader(c, "Unit frames")
    AddCheck(c, "classColorHealth", "Class colored health bars")
    AddCheck(c, "classColorPlayer", "...also on your own player frame", 16)
    AddCheck(c, "colorPetAfterOwner", "...pets in their owner's class color", 16)
    AddCheck(c, "colorShamansBlue", "...shamans blue instead of pink", 16)
    AddCheck(c, "reactionColorNPC", "Reaction colored health for NPCs (tapped = grey)")
    AddCheck(c, "classColorNames", "Class colored names")
    AddCheck(c, "classColorNameBG", "Class colored name background (target/focus)")
    AddCheck(c, "classColorLevel", "Class colored level text")
    AddCheck(c, "hideRealm", "Hide realm names / (*) marker")
    AddCheck(c, "arenaNumbers", "Arena frames: 'Arena 1-5' instead of names")
    AddCheck(c, "arenaNumbersOnTarget", "...also on target / focus while in arena", 16)
    AddCheck(c, "classPortraits", "Class icons instead of portraits (players)")
    AddCheck(c, "classPortraitsIgnoreSelf", "...keep your own portrait", 16)
    AddCheck(c, "playerElite", "Elite (dragon) texture on the player frame")
    AddCheck(c, "miniFocus", "Mini focus frame (Blizzard's small style)")
    c.y = c.y - 6
    AddHeader(c, "Clickthrough (no mouse on the frame)")
    AddCheck(c, "clickthroughPlayer", "Player frame")
    AddCheck(c, "clickthroughTarget", "Target frame")
    AddCheck(c, "clickthroughFocus", "Focus frame")

    local c2 = Cursor(p, COL2, -6)
    AddHeader(c2, "Dark mode")
    AddCheck(c2, "darkMode", "Dark unit frame & castbar borders")
    AddSlider(c2, "darkValue", "Brightness", 0, 1, 0.05, "%.2f")
    AddCheck(c2, "darkModeBars", "Also darken action bar art")
    AddCheck(c2, "darkModeMinimap", "Also darken minimap border")
    c2.y = c2.y - 6
    AddHeader(c2, "Scale")
    AddSlider(c2, "scalePlayer", "Player frame", 0.5, 2, 0.05, "%.2f")
    AddSlider(c2, "scaleTarget", "Target frame", 0.5, 2, 0.05, "%.2f")
    AddSlider(c2, "scaleFocus", "Focus frame", 0.5, 2, 0.05, "%.2f")
    AddSlider(c2, "scalePet", "Pet frame", 0.5, 2, 0.05, "%.2f")
    AddSlider(c2, "scaleToT", "Target of target", 0.5, 2, 0.05, "%.2f")
    AddSlider(c2, "scaleFocusToT", "Focus target", 0.5, 2, 0.05, "%.2f")
    AddSlider(c2, "scaleParty", "Party frames", 0.5, 2, 0.05, "%.2f")
    c2.y = c2.y - 6
    AddHeader(c2, "Frame positions")
    local move = Button(p, "Move frames", 120, function()
        if window then window:Hide() end
        BBF:ToggleMove()
    end)
    move:SetPoint("TOPLEFT", p, "TOPLEFT", COL2 + 4, c2.y)
    local resetPos = Button(p, "Reset positions", 120, function() BBF:ResetPositions() end)
    resetPos:SetPoint("LEFT", move, "RIGHT", 6, 0)
    c2.y = c2.y - 28
    AddNote(c2, "Drag boxes appear over Player, Target, Focus, Pet, Party, Castbar, Buffs, Minimap, "
        .. "Boss, Arena frames, party castbars and the queue timer. Right-click a box to reset it. Also: /bbf move")
end

local function BuildFrames()
    local p = AddPage("Frame parts")
    local c = Cursor(p, 8, -6)
    AddHeader(c, "Hide mana bars")
    AddCheck(c, "hidePlayerMana", "Player", nil, ReloadHint)
    AddCheck(c, "hideTargetMana", "Target", nil, ReloadHint)
    AddCheck(c, "hideFocusMana", "Focus", nil, ReloadHint)
    c.y = c.y - 6
    AddHeader(c, "Hide names")
    AddCheck(c, "hidePlayerName", "Player", nil, ReloadHint)
    AddCheck(c, "hideTargetName", "Target", nil, ReloadHint)
    AddCheck(c, "hideFocusName", "Focus", nil, ReloadHint)
    AddCheck(c, "hidePetName", "Pet", nil, ReloadHint)
    AddCheck(c, "hideToTName", "Target of target", nil, ReloadHint)
    AddCheck(c, "hideFocusToTName", "Focus target", nil, ReloadHint)
    c.y = c.y - 6
    AddHeader(c, "Level text")
    AddCheck(c, "hideLevelText", "Hide level text at max level")
    AddCheck(c, "hideLevelTextAlways", "...hide it always", 16)

    local c2 = Cursor(p, COL2, -6)
    AddHeader(c2, "Target of target / focus target")
    AddCheck(c2, "hideTargetToT", "Hide target of target")
    AddCheck(c2, "hideFocusToT", "Hide focus target")
    AddCheck(c2, "hideToTDebuffs", "Hide ToT debuffs", nil, ReloadHint)
    AddSlider(c2, "totOffsetX", "ToT X offset", -150, 150, 1)
    AddSlider(c2, "totOffsetY", "ToT Y offset", -150, 150, 1)
    AddSlider(c2, "focusToTOffsetX", "Focus ToT X offset", -150, 150, 1)
    AddSlider(c2, "focusToTOffsetY", "Focus ToT Y offset", -150, 150, 1)
    c2.y = c2.y - 6
    AddHeader(c2, "Status text & bars")
    AddDropdown(c2, "textFormat", "Health / mana text format", {
        { value = "default", text = "Blizzard default" },
        { value = "short", text = "12.3k / 24.6k" },
        { value = "percent", text = "76%" },
        { value = "current", text = "12345 (current only)" },
        { value = "currentShort", text = "12.3k (current only)" },
        { value = "currentPercent", text = "12.3k  76%" },
        { value = "both", text = "12.3k / 24.6k (76%)" },
    })
    AddCheck(c2, "smoothBars", "Smooth health / mana bar animation")
    AddSlider(c2, "smoothSpeed", "Smoothing speed", 2, 20, 1)
end

local function BuildTextures()
    local p = AddPage("Textures & fonts")
    local c = Cursor(p, 8, -6)
    AddHeader(c, "Statusbar texture")
    local texOpts = {}
    for _, t in ipairs(BBF.textures) do texOpts[#texOpts + 1] = { value = t.key, text = t.name } end
    AddDropdown(c, "barTexture", "Texture", texOpts)
    AddEdit(c, "barTextureCustom", "Custom texture path (e.g. Interface\\AddOns\\MyAddon\\bar.tga)")
    AddCheck(c, "textureHealth", "Apply to health bars")
    AddCheck(c, "textureMana", "Apply to mana / power bars")
    AddCheck(c, "textureCastbar", "Apply to castbars (incl. party castbars)")
    AddCheck(c, "textureXP", "Apply to XP / reputation bar")
    AddNote(c, "Only textures shipped with the client or inside an addon folder can be used; "
        .. "a wrong path shows a green bar.")

    local c2 = Cursor(p, COL2, -6)
    AddHeader(c2, "Fonts")
    AddCheck(c2, "fontEnabled", "Change unit frame fonts")
    local fontOpts = {}
    for _, f in ipairs(BBF.fonts) do fontOpts[#fontOpts + 1] = { value = f.key, text = f.name } end
    AddDropdown(c2, "font", "Font", fontOpts)
    AddEdit(c2, "fontCustom", "Custom font path (e.g. Interface\\AddOns\\MyAddon\\font.ttf)")
    AddDropdown(c2, "fontOutline", "Outline", {
        { value = "NONE", text = "None" }, { value = "OUTLINE", text = "Outline" }, { value = "THICKOUTLINE", text = "Thick outline" },
    })
    AddSlider(c2, "fontSizeName", "Name / level size", 7, 18, 1)
    AddSlider(c2, "fontSizeValue", "Health / mana / cast text size", 7, 18, 1)
end

local function BuildAuras()
    local p = AddPage("Auras")
    local c = Cursor(p, 8, -6)
    AddHeader(c, "Target & focus auras")
    AddCheck(c, "aurasEnabled", "Enable filtering, sizing & glows")
    AddCheck(c, "targetBuffs", "Target: show buffs", 16)
    AddCheck(c, "targetDebuffs", "Target: show debuffs", 16)
    AddCheck(c, "focusBuffs", "Focus: show buffs", 16)
    AddCheck(c, "focusDebuffs", "Focus: show debuffs", 16)
    c.y = c.y - 6
    AddHeader(c, "Filters")
    AddCheck(c, "onlyMyDebuffs", "Only my debuffs on enemies (+important)")
    AddCheck(c, "onlyMyBuffs", "Only my buffs")
    AddCheck(c, "hidePermanentBuffs", "Hide buffs without duration")
    AddCheck(c, "underOneMinBuffs", "Only buffs with less than 1 minute left")
    AddCheck(c, "whitelistMode", "Whitelist mode: only whitelisted buffs")
    AddCheck(c, "clickthroughAuras", "Clickthrough auras (no tooltips)")
    AddCheck(c, "spellIdTooltip", "Show spell ID in aura tooltips")
    c.y = c.y - 6
    AddHeader(c, "Glows & borders")
    AddCheck(c, "purgeHighlight", "Blue glow: purgeable Magic buffs on enemies")
    AddCheck(c, "importantGlow", "Gold glow: auras on the Important list")
    AddCheck(c, "expireGlow", "Red glow: my auras about to expire (refresh)")
    AddSlider(c, "expireGlowPct", "Refresh glow at % left", 10, 50, 5)
    AddCheck(c, "dotBorder", "My debuffs: class colored border")

    local c2 = Cursor(p, COL2, -6)
    AddHeader(c2, "Layout")
    AddCheck(c2, "debuffsFirst", "Debuffs before buffs")
    AddSlider(c2, "ownAuraSize", "My / important aura size", 14, 40, 1)
    AddSlider(c2, "otherAuraSize", "Other aura size", 10, 36, 1)
    AddSlider(c2, "purgeSize", "Purgeable aura size (0 = normal)", 0, 40, 1)
    AddSlider(c2, "aurasPerRow", "Auras per row", 3, 12, 1)
    AddSlider(c2, "auraGapX", "Horizontal gap", 0, 12, 1)
    AddSlider(c2, "auraGapY", "Vertical gap", 0, 12, 1)
    AddSlider(c2, "auraOffsetX", "X offset", -100, 100, 1)
    AddSlider(c2, "auraOffsetY", "Y offset", -100, 100, 1)
    AddSlider(c2, "maxBuffs", "Max buffs", 0, 32, 1)
    AddSlider(c2, "maxDebuffs", "Max debuffs", 0, 16, 1)
    c2.y = c2.y - 6
    AddHeader(c2, "Sorting")
    AddCheck(c2, "sortImportantFirst", "Important auras first")
    AddCheck(c2, "sortPurgeFirst", "Purgeable buffs first")
    AddCheck(c2, "sortOwnFirst", "My auras first")
    AddNote(c2, "Shift+Alt+Click an aura on target/focus to blacklist it.\nCtrl+Alt+Click to toggle it as Important.")
end

local function BuildPlayerAuras()
    local p = AddPage("Player auras")
    local c = Cursor(p, 8, -6)
    AddHeader(c, "Buff bar filters")
    AddCheck(c, "playerBuffFilter", "Enable buff filtering")
    AddCheck(c, "playerBuffWhitelist", "Whitelist mode: only whitelisted buffs", 16)
    AddCheck(c, "playerBuffUnderOneMin", "Only buffs with less than 1 minute left", 16)
    AddCheck(c, "playerDebuffFilter", "Hide blacklisted debuffs")
    AddNote(c, "Blacklist / whitelist / important are shared with the target & focus lists (Aura lists tab). "
        .. "Important auras are never filtered.")
    c.y = c.y - 6
    AddHeader(c, "Extras")
    AddCheck(c, "playerAuraCooldown", "Cooldown spiral on buffs & debuffs")
    AddCheck(c, "playerAuraHideDuration", "Hide duration text")
    AddSlider(c, "playerAuraStackSize", "Stack count font size", 8, 20, 1)

    local c2 = Cursor(p, COL2, -6)
    AddHeader(c2, "Layout")
    AddCheck(c2, "playerAuraLayout", "Custom size & spacing")
    AddSlider(c2, "playerAuraSize", "Aura size", 16, 48, 1)
    AddSlider(c2, "playerAuraPerRow", "Auras per row", 4, 16, 1)
    AddSlider(c2, "playerAuraGapX", "Horizontal gap", 0, 16, 1)
    AddSlider(c2, "playerAuraGapY", "Vertical gap", 0, 24, 1)
    AddNote(c2, "Move the whole buff frame with /bbf move (box 'Buffs').")
end

local function BuildLists()
    local p = AddPage("Aura lists")
    local lists = {
        { key = "blacklist", label = "Blacklist", desc = "Never shown on target/focus (and your own bars if enabled)." },
        { key = "whitelist", label = "Whitelist", desc = "Always shown, ignores filters. In whitelist mode only these buffs show." },
        { key = "important", label = "Important", desc = "Always shown, bigger, gold glow, never filtered." },
    }
    local current = lists[1]

    local editing = Text(p, "", 8, -42, "GameFontNormal")
    local desc = Text(p, "", 8, -60, nil, PAGEW - 20)

    local sf = CreateFrame("ScrollFrame", uid(), p, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -120)
    sf:SetWidth(PAGEW - 60)
    sf:SetHeight(330)
    local bg = CreateFrame("Frame", nil, p)
    bg:SetPoint("TOPLEFT", sf, "TOPLEFT", -6, 6)
    bg:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 28, -6)
    bg:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    bg:SetBackdropColor(0, 0, 0, 0.5)
    bg:SetFrameLevel(math.max(sf:GetFrameLevel() - 1, 0))

    local child = CreateFrame("Frame", nil, sf)
    child:SetWidth(PAGEW - 70)
    child:SetHeight(100)
    sf:SetScrollChild(child)
    local listText = child:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    listText:SetPoint("TOPLEFT", child, "TOPLEFT", 2, -2)
    listText:SetWidth(PAGEW - 80)
    listText:SetJustifyH("LEFT")

    local function UpdateList()
        editing:SetText("Editing: |cffffffff" .. current.label .. "|r")
        desc:SetText(current.desc)
        local t = {}
        for _, v in pairs(db[current.key]) do t[#t + 1] = tostring(v) end
        table.sort(t, function(a, b) return strlower(a) < strlower(b) end)
        listText:SetText(#t > 0 and table.concat(t, "    ") or "|cff888888(empty)|r")
        child:SetHeight(math.max(listText:GetStringHeight() + 6, 10))
        sf:UpdateScrollChildRect()
    end

    local listButtons = {}
    for i, l in ipairs(lists) do
        local b = Button(p, l.label, 105, function()
            current = l
            for j, lb in ipairs(listButtons) do
                if j == i then lb:LockHighlight() else lb:UnlockHighlight() end
            end
            UpdateList()
        end)
        b:SetPoint("TOPLEFT", p, "TOPLEFT", 8 + (i - 1) * 110, -10)
        listButtons[i] = b
    end
    listButtons[1]:LockHighlight()

    local eb = CreateFrame("EditBox", uid(), p, "InputBoxTemplate")
    eb:SetWidth(220)
    eb:SetHeight(20)
    eb:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -86)
    eb:SetAutoFocus(false)

    local function DoAdd()
        local added = BBF:AddToList(current.key, eb:GetText())
        if added then eb:SetText(""); UpdateList(); BBF:ApplyAll() end
    end
    local function DoRemove()
        local removed = BBF:RemoveFromList(current.key, eb:GetText())
        if removed then eb:SetText(""); UpdateList(); BBF:ApplyAll()
        else BBF:Print("not found in " .. current.label) end
    end
    eb:SetScript("OnEnterPressed", function(self) DoAdd(); self:ClearFocus() end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local add = Button(p, "Add", 70, DoAdd)
    add:SetPoint("LEFT", eb, "RIGHT", 8, 0)
    local rem = Button(p, "Remove", 70, DoRemove)
    rem:SetPoint("LEFT", add, "RIGHT", 4, 0)
    local hint = Text(p, "Spell name or spell ID (IDs are converted to names, so all ranks match).", 8, -460)
    hint:ClearAllPoints()
    hint:SetPoint("TOPLEFT", sf, "BOTTOMLEFT", -6, -10)
    tinsert(p.bbfRefresh, UpdateList)
end

local function CastbarBlock(c, key, title, hasDetach, hasTimerCenter)
    AddHeader(c, title)
    AddCheck(c, "cb" .. key .. "Custom", "Customize this castbar")
    AddSlider(c, "cb" .. key .. "Width", "Width", 80, 400, 1)
    AddSlider(c, "cb" .. key .. "Height", "Height", 6, 40, 1)
    AddCheck(c, "cb" .. key .. "Icon", "Show spell icon")
    AddSlider(c, "cb" .. key .. "IconSize", "Icon size", 10, 48, 1)
    AddCheck(c, "cb" .. key .. "Border", "Show border")
    AddCheck(c, "cb" .. key .. "Text", "Show spell name")
    if hasTimerCenter then AddCheck(c, "cb" .. key .. "TimerCenter", "Timer centered on the bar") end
    if hasDetach then AddCheck(c, "cb" .. key .. "Detach", "Detach from the unit frame (position with /bbf move)") end
end

local function BuildCastbars()
    local p = AddPage("Castbars")
    local c = Cursor(p, 8, -6)
    AddHeader(c, "Party / self / pet castbars")
    AddCheck(c, "partyCastbars", "Show party castbars")
    AddCheck(c, "partyCastAttach", "Attach to default party frames when visible", 16)
    AddCheck(c, "partyCastSelf", "Add a bar for your own casts", 16)
    AddCheck(c, "partyCastIcon", "Show spell icon", 16)
    AddCheck(c, "partyCastTimer", "Show remaining time", 16)
    AddSlider(c, "partyCastWidth", "Width", 60, 300, 1)
    AddSlider(c, "partyCastHeight", "Height", 6, 30, 1)
    AddSlider(c, "partyCastX", "X offset (attached)", -200, 300, 1)
    AddSlider(c, "partyCastY", "Y offset (attached)", -100, 100, 1)
    AddCheck(c, "petCastbar", "Pet castbar next to the pet frame")
    AddSlider(c, "petCastWidth", "Pet bar width", 60, 300, 1)
    AddSlider(c, "petCastHeight", "Pet bar height", 6, 30, 1)
    AddSlider(c, "petCastX", "Pet bar X offset", -200, 300, 1)
    AddSlider(c, "petCastY", "Pet bar Y offset", -100, 100, 1)
    AddNote(c, "If the default party frames are hidden (solo, or another party frame addon) or 'attach' is off, "
        .. "the bars stack in a free container - place it with /bbf move ('Party castbars'). Grey bar = not interruptible.")

    local c2 = Cursor(p, COL2, -6)
    AddHeader(c2, "Default castbars")
    AddCheck(c2, "castTimers", "Remaining cast time on player/target/focus castbar")
    AddSlider(c2, "targetCastScale", "Target castbar scale", 0.5, 2, 0.05, "%.2f")
    AddSlider(c2, "focusCastScale", "Focus castbar scale", 0.5, 2, 0.05, "%.2f")
    c2.y = c2.y - 6
    CastbarBlock(c2, "Player", "Player castbar", false, true)
    c2.y = c2.y - 6
    CastbarBlock(c2, "Target", "Target castbar", true, false)
    c2.y = c2.y - 6
    CastbarBlock(c2, "Focus", "Focus castbar", true, false)
end

local function BuildInterrupt()
    local p = AddPage("Interrupts")
    local c = Cursor(p, 8, -6)
    AddHeader(c, "Interrupt window highlight")
    AddCheck(c, "interruptHighlight", "Mark the start / end of enemy casts on the target castbar")
    AddCheck(c, "interruptHighlightFocus", "...also on the focus castbar", 16)
    AddSlider(c, "interruptHighlightStart", "Start seconds (latency)", 0, 1, 0.05, "%.2f")
    AddSlider(c, "interruptHighlightEnd", "End seconds (too late)", 0, 1, 0.05, "%.2f")
    AddNote(c, "The red edges show where an interrupt won't land (cast just started: server lag; "
        .. "cast about to finish: too late). Kick inside the clear middle.")

    local c2 = Cursor(p, COL2, -6)
    AddHeader(c2, "Enemy interrupt cooldown")
    AddCheck(c2, "interruptIcon", "Show the enemy's interrupt next to their castbar")
    AddCheck(c2, "interruptIconTarget", "Target castbar", 16)
    AddCheck(c2, "interruptIconFocus", "Focus castbar", 16)
    AddCheck(c2, "interruptIconActiveOnly", "Only while their interrupt is on cooldown", 16)
    AddSlider(c2, "interruptIconSize", "Icon size", 14, 40, 1)
    AddSlider(c2, "interruptIconX", "X offset", -200, 200, 1)
    AddSlider(c2, "interruptIconY", "Y offset", -100, 100, 1)
    AddCheck(c2, "interruptRecolor", "Green castbar while the enemy's interrupt is on cooldown")
    AddNote(c2, "Tracked via combat log: Kick, Counterspell, Pummel, Shield Bash, Wind Shear, Spell Lock, "
        .. "Mind Freeze, Strangulate, Silencing Shot, Feral Charge, Silence, Arcane Torrent. "
        .. "Red ring = ready, green ring + timer = on cooldown (talent reductions not included).")
end

local function BuildIndicators()
    local p = AddPage("Indicators")
    local c = Cursor(p, 8, -6)
    AddHeader(c, "Combat indicator")
    AddCheck(c, "combatIndicator", "Show on target & focus")
    AddCheck(c, "combatShowIn", "Show while in combat (swords)", 16)
    AddCheck(c, "combatShowOut", "Show while out of combat (food)", 16)
    AddCheck(c, "combatParty", "Also on party portraits", 16)
    AddCheck(c, "combatEnemyOnly", "Enemies only", 16)
    AddCheck(c, "combatPlayersOnly", "Players only", 16)
    AddCheck(c, "combatArenaOnly", "Arena only", 16)
    c.y = c.y - 6
    AddHeader(c, "Absorb indicator")
    AddCheck(c, "absorbIndicator", "Show active shield on target & focus")
    AddCheck(c, "absorbPlayer", "Also on your player frame", 16)
    AddCheck(c, "absorbTimer", "Show remaining seconds", 16)
    AddCheck(c, "absorbAmount", "Show estimated remaining amount (~)", 16)
    AddNote(c, "Tracks PW:Shield, Divine Aegis, Ice Barrier, Mana Shield, Fire/Frost Ward, AMS, AMZ, Shadow Ward, "
        .. "Sacrifice, Sacred Shield, Savage Defense, Val'anyr. 3.3.5 has no absorb API: the amount is the spell's "
        .. "base value minus absorbed damage seen in the combat log (no spellpower) - treat it as a rough guide.")

    local c2 = Cursor(p, COL2, -6)
    AddHeader(c2, "Position / size")
    AddSlider(c2, "indSize", "Icon size", 12, 40, 1)
    AddSlider(c2, "indX", "X offset", -80, 80, 1)
    AddSlider(c2, "indY", "Y offset", -80, 80, 1)
    c2.y = c2.y - 6
    AddHeader(c2, "Racial indicator (above the portrait)")
    AddCheck(c2, "racialIndicator", "Show PvP relevant racial of enemy players")
    AddCheck(c2, "racialTarget", "Target", 16)
    AddCheck(c2, "racialFocus", "Focus", 16)
    AddCheck(c2, "racialHuman", "Human (Every Man for Himself)", 16)
    AddCheck(c2, "racialNelf", "Night Elf (Shadowmeld)", 16)
    AddCheck(c2, "racialOrc", "Orc (Hardiness)", 16)
    AddCheck(c2, "racialUndead", "Undead (Will of the Forsaken)", 16)
    AddSlider(c2, "racialSize", "Racial icon size", 12, 36, 1)
    c2.y = c2.y - 6
    AddHeader(c2, "Stealth")
    AddCheck(c2, "stealthIndicator", "Stealth icon next to your player frame")
end

local function BuildHide()
    local p = AddPage("Hide")
    local c = Cursor(p, 8, -6)
    AddHeader(c, "Unit frames")
    AddCheck(c, "hidePvPIcons", "PvP icons", nil, ReloadHint)
    AddCheck(c, "hideLeaderIcons", "Leader / master looter icons", nil, ReloadHint)
    AddCheck(c, "hideGroupIndicator", "Player group number", nil, ReloadHint)
    AddCheck(c, "hideHitIndicators", "Damage text on player/pet portrait", nil, ReloadHint)
    AddCheck(c, "hideRestGlow", "Resting glow & icon")
    AddCheck(c, "hideCombatGlow", "Combat glow & icon on player frame")
    AddCheck(c, "hidePetFrame", "Pet frame")
    AddCheck(c, "hideArenaFrames", "Default arena frames (use your own)")
    c.y = c.y - 6
    AddHeader(c, "Situational")
    AddCheck(c, "hideMinimapArena", "Minimap in arena")
    AddCheck(c, "hideTrackerArena", "Quest tracker in arena")
    AddCheck(c, "hidePartyArena", "Party frames in arena")
    AddCheck(c, "hideBossParty", "Boss frames while in a party")
    AddCheck(c, "hideBossRaid", "Boss frames while in a raid")

    local c2 = Cursor(p, COL2, -6)
    AddHeader(c2, "Interface")
    AddCheck(c2, "hideGryphons", "Action bar gryphons", nil, ReloadHint)
    AddCheck(c2, "hideMacroText", "Macro names on action buttons")
    AddCheck(c2, "hideHotkeyText", "Keybind text on action buttons")
    AddCheck(c2, "hideStanceBar", "Stance / shapeshift bar")
    AddCheck(c2, "hidePetActionBar", "Pet action bar")
    AddCheck(c2, "hideBagButtons", "Bag buttons", nil, ReloadHint)
    AddCheck(c2, "hideChatButtons", "Chat frame buttons", nil, ReloadHint)
    AddCheck(c2, "hideMinimapZoom", "Minimap zoom buttons", nil, ReloadHint)
    AddCheck(c2, "hideWorldMapButton", "Minimap world map button", nil, ReloadHint)
    AddCheck(c2, "hideMinimapToggle", "Minimap close (X) button", nil, ReloadHint)
    AddCheck(c2, "hideClock", "Minimap clock", nil, ReloadHint)
    AddCheck(c2, "hideUIErrors", "UI error messages (red text at the top)", nil, ReloadHint)
    AddNote(c2, "Elements marked with a reload hint need /reload to come back once unchecked. "
        .. "Glows, texts, bars and situational hides toggle live.")
end

local function BuildMisc()
    local p = AddPage("Misc")
    local c = Cursor(p, 8, -6)
    AddHeader(c, "Chat filters")
    AddCheck(c, "chatFilterEmotes", "Hide emotes (/e and /dance style)")
    AddCheck(c, "chatFilterSystem", "Hide friend online/offline & AFK/DND system lines")
    AddCheck(c, "chatFilterTalents", "Hide 'You have learned/unlearned ...' spam")
    AddCheck(c, "chatFilterArenaNpc", "Hide NPC yells / says while in arena")

    c.y = c.y - 6
    AddHeader(c, "Minimap button")
    AddCheck(c, "minimapButton", "Show the BetterFrames button on the minimap")
    AddNote(c, "Left-click: options  |  Right-click: move frames  |  Shift+click: castbar test  |  drag it around the minimap.")

    local c2 = Cursor(p, COL2, -6)
    AddHeader(c2, "Queue timer")
    AddCheck(c2, "queueTimer", "Show battleground / arena queue timer")
    AddCheck(c2, "queueTimerSound", "Play a sound when the queue pops", 16)
    AddNote(c2, "Shows waited and estimated time while queued and a READY countdown when the queue pops. "
        .. "Move it with /bbf move ('Queue timer').")
end

local function BuildProfiles()
    local p = AddPage("Profiles")
    local c = Cursor(p, 8, -6)
    AddHeader(c, "Profiles")
    local current = Text(p, "", c.x, c.y - 2)
    c.y = c.y - 24
    tinsert(p.bbfRefresh, function()
        current:SetText("Current profile: |cffffffff" .. BBF:CurrentProfile() .. "|r   (character: " .. BBF:CharKey() .. ")")
    end)

    -- switch
    local name = uid()
    Text(p, "Switch to profile (reloads the UI)", c.x + 4, c.y - 2, "GameFontNormalSmall")
    local dd = CreateFrame("Frame", name, p, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", p, "TOPLEFT", c.x - 14, c.y - 14)
    UIDropDownMenu_SetWidth(dd, 200)
    UIDropDownMenu_Initialize(dd, function()
        for _, n in ipairs(BBF:ProfileNames()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = n
            info.value = n
            info.checked = (n == BBF:CurrentProfile())
            info.func = function() if n ~= BBF:CurrentProfile() then BBF:SetProfile(n) end end
            UIDropDownMenu_AddButton(info)
        end
    end)
    tinsert(p.bbfRefresh, function()
        local t = _G[name .. "Text"]
        if t then t:SetText(BBF:CurrentProfile()) end
    end)
    c.y = c.y - 50

    -- create
    Text(p, "New profile (copy of the current settings)", c.x + 4, c.y - 2, "GameFontNormalSmall")
    local eb = CreateFrame("EditBox", uid(), p, "InputBoxTemplate")
    eb:SetWidth(200)
    eb:SetHeight(20)
    eb:SetPoint("TOPLEFT", p, "TOPLEFT", c.x + 10, c.y - 16)
    eb:SetAutoFocus(false)
    local function Create()
        local n = strtrim(eb:GetText() or "")
        if n ~= "" then BBF:SetProfile(n) end
    end
    eb:SetScript("OnEnterPressed", Create)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local cb = Button(p, "Create & switch", 120, Create)
    cb:SetPoint("LEFT", eb, "RIGHT", 8, 0)
    c.y = c.y - 50

    -- copy from
    local name2 = uid()
    Text(p, "Copy settings from another profile into the current one (reloads)", c.x + 4, c.y - 2, "GameFontNormalSmall")
    local dd2 = CreateFrame("Frame", name2, p, "UIDropDownMenuTemplate")
    dd2:SetPoint("TOPLEFT", p, "TOPLEFT", c.x - 14, c.y - 14)
    UIDropDownMenu_SetWidth(dd2, 200)
    UIDropDownMenu_Initialize(dd2, function()
        for _, n in ipairs(BBF:ProfileNames()) do
            if n ~= BBF:CurrentProfile() then
                local info = UIDropDownMenu_CreateInfo()
                info.text = n
                info.value = n
                info.func = function() BBF:CopyProfileFrom(n) end
                UIDropDownMenu_AddButton(info)
            end
        end
    end)
    tinsert(p.bbfRefresh, function()
        local t = _G[name2 .. "Text"]
        if t then t:SetText("choose...") end
    end)
    c.y = c.y - 50

    -- delete
    local del = Button(p, "Delete a profile...", 150, function()
        StaticPopup_Show("BBF335_DELETE_PROFILE")
    end)
    del:SetPoint("TOPLEFT", p, "TOPLEFT", c.x + 4, c.y - 4)
    c.y = c.y - 40
    AddNote(c, "'Default' can't be deleted. Characters using a deleted profile fall back to Default.")

    -- presets + export / import
    local c2 = Cursor(p, COL2, -6)
    AddPresets(p, c2)
    c2.y = c2.y - 6
    AddHeader(c2, "Export / import")
    local exportBox = CreateFrame("EditBox", uid(), p, "InputBoxTemplate")
    exportBox:SetWidth(COL2 - 70)
    exportBox:SetHeight(20)
    exportBox:SetAutoFocus(false)
    exportBox:SetFontObject("GameFontHighlightSmall")
    exportBox:SetPoint("TOPLEFT", p, "TOPLEFT", c2.x + 10, c2.y - 30)
    exportBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    exportBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    local exp = Button(p, "Export current profile", 170, function()
        exportBox:SetText(BBF:ExportProfile())
        exportBox:SetFocus()
        exportBox:HighlightText()
    end)
    exp:SetPoint("TOPLEFT", p, "TOPLEFT", c2.x + 4, c2.y - 2)
    c2.y = c2.y - 56
    AddNote(c2, "Click Export, then Ctrl+C the string. To import, paste a string below and click Import "
        .. "(replaces the current profile and reloads).")
    local importBox = CreateFrame("EditBox", uid(), p, "InputBoxTemplate")
    importBox:SetWidth(COL2 - 70)
    importBox:SetHeight(20)
    importBox:SetAutoFocus(false)
    importBox:SetFontObject("GameFontHighlightSmall")
    importBox:SetPoint("TOPLEFT", p, "TOPLEFT", c2.x + 10, c2.y - 4)
    importBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local imp = Button(p, "Import", 100, function()
        local ok, err = BBF:ImportProfile(importBox:GetText())
        if not ok then BBF:Print("import failed: " .. tostring(err)) end
    end)
    imp:SetPoint("TOPLEFT", importBox, "BOTTOMLEFT", -6, -6)
end

StaticPopupDialogs["BBF335_DELETE_PROFILE"] = {
    text = "Delete which profile? (type the exact name)",
    button1 = DELETE or "Delete",
    button2 = CANCEL,
    hasEditBox = 1,
    OnAccept = function(self)
        local eb = _G[self:GetName() .. "EditBox"]
        local n = eb and strtrim(eb:GetText() or "")
        if n and n ~= "" then
            if BBF:DeleteProfile(n) then BBF:Print("profile deleted: " .. n) else BBF:Print("can't delete '" .. n .. "'") end
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        StaticPopupDialogs["BBF335_DELETE_PROFILE"].OnAccept(parent)
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

----------------------------------------------------------------------
-- Interface > AddOns entry (launcher + donate). Everything is anchored to the panel's
-- left AND right edge so it wraps inside whatever width Blizzard's container has.
----------------------------------------------------------------------
local function WrapText(p, anchorTo, y, text, font)
    local fs = p:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall")
    -- TOPLEFT + TOPRIGHT: defines the width only, so the height grows with the wrapped text.
    fs:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, y)
    fs:SetPoint("TOPRIGHT", p, "TOPRIGHT", -24, 0)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetText(text)
    return fs
end

local function BuildBlizzardPanel()
    local p = CreateFrame("Frame", uid(), UIParent)
    p.name = "BetterFrames 335"
    p:Hide()

    local title = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -16)
    title:SetText("BetterFrames 335")

    local sub = WrapText(p, title, -4, "v" .. BBF.version .. "  -  better default Blizzard unit frames for 3.3.5a")
    local desc = WrapText(p, sub, -10,
        "All settings live in a separate, movable window. Open it with the button below or type /bbf.")

    local open = Button(p, "Open options window", 180, function()
        HideUIPanel(InterfaceOptionsFrame)
        BBF:OpenOptions()
    end)
    open:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -10)

    local cmdHead = WrapText(p, open, -14, "Commands", "GameFontNormal")
    local cmds = WrapText(p, cmdHead, -4,
        "/bbf  -  open the options window\n"
        .. "/bbf move  -  move frames\n"
        .. "/bbf test  -  castbar test mode\n"
        .. "/bbf bl|wl|imp add|del|list <name or spellID>  -  edit the aura lists\n"
        .. "/bbf profile <name>  -  switch / create a profile\n"
        .. "/bbf cpu  -  CPU usage per addon\n"
        .. "/bbf reset  -  reset everything")

    local line = p:CreateTexture(nil, "ARTWORK")
    line:SetTexture(1, 1, 1, 0.15)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", cmds, "BOTTOMLEFT", 0, -14)
    line:SetPoint("RIGHT", p, "RIGHT", -24, 0)

    local donHead = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    donHead:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -10)
    donHead:SetText("|TInterface\\Icons\\INV_Drink_05:14:14:0:0|t  Buy me a coffee")
    local donText = WrapText(p, donHead, -4, DONATE_TEXT
        .. "\nCopy the link (click it, then Ctrl+C), open it in your browser and use the coin transfer:")
    local box = CopyBox(p, DONATE_URL, 300)
    box:SetPoint("TOPLEFT", donText, "BOTTOMLEFT", 6, -8)
    local who = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    who:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -6, -6)
    who:SetText("Character: |cffffffff" .. DONATE_CHAR .. "|r     Realm: |cffffffff" .. DONATE_REALM .. "|r")

    InterfaceOptions_AddCategory(p)
    BBF.optionsPanel = p
end

----------------------------------------------------------------------
function BBF:OpenOptions()
    if not window then return end
    if window:IsShown() then
        window:Hide()
    else
        window:Show()
        SelectTab(db.lastTab or 1)
    end
end

function M:Init()
    db = BBF.db
    window = CreateWindow()
    BuildGeneral()
    BuildFrames()
    BuildTextures()
    BuildAuras()
    BuildPlayerAuras()
    BuildLists()
    BuildCastbars()
    BuildInterrupt()
    BuildIndicators()
    BuildHide()
    BuildMisc()
    BuildProfiles()
    SelectTab(db.lastTab or 1)
    BuildBlizzardPanel()
end
