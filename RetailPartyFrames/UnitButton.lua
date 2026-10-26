-- RetailPartyFrames - unit button factory and element updates
-- One factory for party, pet, raid, main tank and preview buttons.

local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local floor, max, min = math.floor, math.max, math.min

ns.allButtons = {}      -- every button ever created
ns.unitButtons = {}     -- unit token -> list of visible buttons showing it
local allButtons, unitButtons = ns.allButtons, ns.unitButtons

local HealComm
local ROLE_TEX = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local ROLE_COORDS = {
    TANK = { 0, 19 / 64, 22 / 64, 41 / 64 },
    HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
    DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}
local READY_TEX = {
    ready = READY_CHECK_READY_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-Ready",
    notready = READY_CHECK_NOT_READY_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-NotReady",
    waiting = READY_CHECK_WAITING_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-Waiting",
}
local HEALER_CLASSES = { PRIEST = true, PALADIN = true, DRUID = true, SHAMAN = true }
local RANGE_SPELLS = { PRIEST = 2061, DRUID = 774, PALADIN = 635, SHAMAN = 331, WARLOCK = 5697, MAGE = 1459 }

------------------------------------------------------------------------
-- Per-kind configuration: raid frames and pets have their own sizes
------------------------------------------------------------------------
local RAID_KEYS = {
    width = "raidWidth", height = "raidHeight", powerBar = "raidPowerBar", fontSize = "raidFontSize",
    castbar = "raidCastbar", cooldowns = "raidCooldowns", maxDebuffs = "raidMaxDebuffs",
    debuffSize = "raidDebuffSize", maxBuffs = "raidMaxBuffs", buffSize = "raidBuffSize",
    healthText = "raidHealthText",
}
local PET_FIXED = { powerBar = "NONE", castbar = false, cooldowns = false, maxBuffs = 0, roleIcon = false,
                    leaderIcon = false, readyCheck = false, healPrediction = false, resIncoming = false }
local PET_KEYS = { width = "petWidth", height = "petHeight", maxDebuffs = "petMaxDebuffs", fontSize = "raidFontSize" }

function ns:Cfg(b, key)
    local db = self.db
    local kind = b.kind
    if kind == "raid" or kind == "mt" then
        local k = RAID_KEYS[key]
        if k then return db[k] end
    elseif kind == "pet" then
        local v = PET_FIXED[key]
        if v ~= nil then return v end
        local k = PET_KEYS[key]
        if k then return db[k] end
    end
    return db[key]
end

------------------------------------------------------------------------
-- Test data
------------------------------------------------------------------------
ns.testUnits = {
    { name = "Brakka", class = "WARRIOR", race = "Orc", role = "TANK", hp = 0.62, power = 0.4, powerType = 1, aggro = 3, leader = true },
    { name = "Selwyn", class = "PRIEST", race = "Human", role = "HEALER", hp = 0.88, power = 0.71, powerType = 0, debuffType = "Magic", selected = true,
      cast = { name = "Flash Heal", icon = "Interface\\Icons\\Spell_Holy_FlashHeal", time = 1.5 } },
    { name = "Morvane", class = "MAGE", race = "Gnome", role = "DAMAGER", hp = 0.35, power = 0.55, powerType = 0, debuffType = "Curse",
      cast = { name = "Arcane Missiles", icon = "Interface\\Icons\\Spell_Nature_StarFall", time = 5, channel = true } },
    { name = "Kethis", class = "ROGUE", race = "BloodElf", role = "DAMAGER", hp = 0.15, power = 0.9, powerType = 3, debuffType = "Poison", oor = true, arenaTargets = 2 },
    { name = "Thalgor", class = "DRUID", race = "Tauren", role = "HEALER", hp = 0, dead = true, power = 0, powerType = 0, res = true },
}

local TEST_NAMES = { "Aldric", "Brynn", "Caelum", "Dorne", "Eryx", "Fiora", "Galen", "Hesta", "Ilyan", "Jorah", "Kaela", "Lorcan",
    "Maeve", "Nyx", "Orin", "Perrin", "Quill", "Rhoswen", "Sable", "Torvin", "Ula", "Varek", "Wren", "Xandra", "Yorick",
    "Zephyr", "Ansel", "Brielle", "Corvin", "Daria", "Elowen", "Fenwick", "Gwyn", "Hollis", "Isolde", "Jareth", "Kestrel",
    "Lysander", "Mirela", "Nolan" }

function ns:TestUnit(i)
    if i <= #self.testUnits then return self.testUnits[i] end
    local classes = self.ClassTokens
    local roles = { "DAMAGER", "DAMAGER", "DAMAGER", "HEALER", "TANK" }
    local d = {
        name = TEST_NAMES[((i - 1) % #TEST_NAMES) + 1],
        class = classes[((i * 7) % #classes) + 1],
        race = "Human",
        role = roles[((i * 3) % #roles) + 1],
        hp = ((i * 37) % 100) / 100,
        power = ((i * 53) % 100) / 100,
        powerType = (i % 4 == 0) and 1 or 0,
        group = floor((i - 1) / 5) + 1,
    }
    if i % 9 == 0 then d.debuffType = "Disease" end
    if i % 11 == 0 then d.oor = true end
    if i % 13 == 0 then d.dead = true d.hp = 0 end
    return d
end

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
function ns.GetRole(unit)
    if not unit or not UnitGroupRolesAssigned then return nil end
    local a, b, c = UnitGroupRolesAssigned(unit)
    if type(a) == "string" then
        if a == "NONE" then return nil end
        return a
    end
    if a then return "TANK" elseif b then return "HEALER" elseif c then return "DAMAGER" end
    return nil
end

local Border = {}
Border.__index = Border

local function NewBorder(parent, layer)
    local o = setmetatable({ parent = parent, t = {} }, Border)
    for i = 1, 4 do
        local tex = parent:CreateTexture(nil, layer or "OVERLAY")
        tex:SetTexture(WHITE)
        o.t[i] = tex
    end
    return o
end
ns.NewBorder = NewBorder

function Border:SetThickness(px, inset)
    inset = inset or 0
    local p = self.parent
    local top, bottom, left, right = self.t[1], self.t[2], self.t[3], self.t[4]
    for i = 1, 4 do self.t[i]:ClearAllPoints() end
    top:SetPoint("TOPLEFT", p, "TOPLEFT", inset, -inset)
    top:SetPoint("TOPRIGHT", p, "TOPRIGHT", -inset, -inset)
    top:SetHeight(px)
    bottom:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", inset, inset)
    bottom:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -inset, inset)
    bottom:SetHeight(px)
    left:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
    left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT")
    left:SetWidth(px)
    right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT")
    right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")
    right:SetWidth(px)
end

function Border:SetColor(r, g, b, a)
    for i = 1, 4 do self.t[i]:SetVertexColor(r, g, b, a or 1) end
end

function Border:Show()
    for i = 1, 4 do self.t[i]:Show() end
end

function Border:Hide()
    for i = 1, 4 do self.t[i]:Hide() end
end

local function StyleFont(fs, size, outline)
    local flags = ""
    if outline == true or outline == "OUTLINE" then flags = "OUTLINE" end
    if outline == nil and ns.db.fontOutline == "OUTLINE" then flags = "OUTLINE" end
    fs:SetFont(ns:Fetch("font", ns.db.font), size, flags)
    if flags ~= "" then
        fs:SetShadowOffset(0, 0)
    else
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    end
end
ns.StyleFont = StyleFont

function ns:ForEachButton(fn)
    for i = 1, #allButtons do
        local b = allButtons[i]
        if b:IsShown() and (b.unit or b.testData) then fn(b) end
    end
end

-- Calls method(ns, button) for every visible frame showing `unit`
local function ForUnit(unit, method)
    local list = unit and unitButtons[unit]
    if not list then return end
    for i = 1, #list do
        local b = list[i]
        if b:IsShown() and not b.testData then method(ns, b) end
    end
end
ns.ForUnit = ForUnit

function ns:RebuildUnitMap()
    for k in pairs(unitButtons) do unitButtons[k] = nil end
    for i = 1, #allButtons do
        local b = allButtons[i]
        if b.unit and not b.testData then
            local list = unitButtons[b.unit]
            if not list then
                list = {}
                unitButtons[b.unit] = list
            end
            list[#list + 1] = b
            -- while in a vehicle the bar follows the vehicle unit's events as well
            local disp = b.dispUnit
            if disp and disp ~= b.unit then
                local dl = unitButtons[disp]
                if not dl then
                    dl = {}
                    unitButtons[disp] = dl
                end
                dl[#dl + 1] = b
            end
        end
    end
end

-- Shorten the name with "..." until it fits (no word wrap control in 3.3.5)
local function FitName(fs, name, width)
    fs:SetText(name)
    if width <= 0 or fs:GetStringWidth() <= width then return end
    local len = string.len(name)
    while len > 1 do
        len = len - 1
        fs:SetText(string.sub(name, 1, len) .. "...")
        if fs:GetStringWidth() <= width then return end
    end
end

------------------------------------------------------------------------
-- Menu / tooltip
------------------------------------------------------------------------
local menuFrame = CreateFrame("Frame", "RetailPartyFramesDropDown", UIParent, "UIDropDownMenuTemplate")
UIDropDownMenu_Initialize(menuFrame, function(self)
    local unit = self.unit
    if not unit or not UnitExists(unit) then return end
    local which
    if UnitIsUnit(unit, "player") then
        which = "SELF"
    elseif UnitIsUnit(unit, "pet") then
        which = "PET"
    elseif string.find(unit, "pet") then
        which = "PARTY" -- someone else's pet: generic menu
    elseif UnitInRaid(unit) then
        which = "RAID_PLAYER"
    elseif UnitInParty(unit) then
        which = "PARTY"
    else
        which = "PLAYER"
    end
    UnitPopup_ShowMenu(self, which, unit)
end, "MENU")

local function ShowMenu(self)
    if self.testData or not self.unit then return end
    -- UnitPopup reads unit, name and id from the dropdown frame (uninvite works by name)
    menuFrame.unit = self.unit
    menuFrame.name = UnitName(self.unit)
    menuFrame.id = tonumber(string.match(self.unit, "^party(%d)$")) or tonumber(string.match(self.unit, "^raid(%d+)$"))
    ToggleDropDownMenu(1, nil, menuFrame, "cursor", 0, 0)
end
ns.ShowUnitMenu = ShowMenu

local function TooltipAllowed()
    local mode = ns.db.tooltips
    if mode == "NEVER" then return false end
    if mode == "OOC" and InCombatLockdown() then return false end
    return true
end

local function OnEnter(self)
    self.hover:Show()
    if not TooltipAllowed() then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    if self.testData then
        GameTooltip:SetText(self.testData.name)
        GameTooltip:AddLine("RetailPartyFrames test mode", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    elseif self.unit then
        GameTooltip:SetUnit(self.unit)
        GameTooltip:Show()
    end
end

local function OnLeave(self)
    self.hover:Hide()
    GameTooltip:Hide()
end

------------------------------------------------------------------------
-- Button creation
------------------------------------------------------------------------
local function OnAttributeChanged(self, attr, value)
    if attr == "unit" then
        if not self.testData then self.unit = value end
        ns:RebuildUnitMap()
        -- a shown button that got a new occupant (re-sort, group move) must redraw everything,
        -- otherwise the previous player's health/auras/cooldowns stay until an event fires
        if value and self.rpfSetup and not self.testData and self:IsShown() then
            ns:UpdateButton(self)
        end
    end
end

local function OnShow(self)
    self.cdHolder:Show()
    ns:UpdateButton(self)
end

local function OnHide(self)
    self.cdHolder:Hide()
    self.castbar:Hide()
end

-- Adds every element to a bare SecureUnitButtonTemplate button
function ns:SetupUnitButton(b, kind)
    if b.rpfSetup then return b end
    b.rpfSetup = true
    b.kind = kind or "party"
    b:RegisterForClicks("AnyUp")
    b.menu = ShowMenu
    b:SetScript("OnEnter", OnEnter)
    b:SetScript("OnLeave", OnLeave)

    -- Clique registration is handled by ClickCast.lua (ApplyClickBindings), depending on the option

    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetTexture(WHITE)

    local health = CreateFrame("StatusBar", nil, b)
    health:SetFrameLevel(b:GetFrameLevel() + 1)
    health.bg = health:CreateTexture(nil, "BACKGROUND")
    health.bg:SetAllPoints(health)
    b.health = health

    b.healPred = health:CreateTexture(nil, "ARTWORK")
    b.healPred:SetTexture(WHITE)
    b.healPred:SetVertexColor(0.1, 0.9, 0.3, 0.45)
    b.healPred:Hide()

    b.dispelGlow = health:CreateTexture(nil, "OVERLAY")
    b.dispelGlow:SetAllPoints(health)
    b.dispelGlow:SetTexture(WHITE)
    b.dispelGlow:Hide()

    local power = CreateFrame("StatusBar", nil, b)
    power:SetFrameLevel(b:GetFrameLevel() + 1)
    power.bg = power:CreateTexture(nil, "BACKGROUND")
    power.bg:SetAllPoints(power)
    b.power = power

    self:CreateCastbar(b)

    local overlay = CreateFrame("Frame", nil, b)
    overlay:SetAllPoints(b)
    overlay:SetFrameLevel(b:GetFrameLevel() + 4)
    b.overlay = overlay

    b.hover = overlay:CreateTexture(nil, "BACKGROUND")
    b.hover:SetTexture(WHITE)
    b.hover:SetVertexColor(1, 1, 1, 0.08)
    b.hover:Hide()

    b.roleIcon = overlay:CreateTexture(nil, "OVERLAY")
    b.roleIcon:SetTexture(ROLE_TEX)
    b.roleIcon:SetWidth(12)
    b.roleIcon:SetHeight(12)

    b.nameText = overlay:CreateFontString(nil, "OVERLAY")
    b.nameText:SetJustifyH("LEFT")
    b.nameText:SetNonSpaceWrap(false)

    b.statusText = overlay:CreateFontString(nil, "OVERLAY")
    b.statusText:SetJustifyH("CENTER")

    b.leaderIcon = overlay:CreateTexture(nil, "OVERLAY")
    b.leaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    b.leaderIcon:SetWidth(12)
    b.leaderIcon:SetHeight(12)
    b.leaderIcon:Hide()

    b.raidIcon = overlay:CreateTexture(nil, "OVERLAY")
    b.raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    b.raidIcon:SetWidth(14)
    b.raidIcon:SetHeight(14)
    b.raidIcon:Hide()

    b.readyIcon = overlay:CreateTexture(nil, "OVERLAY")
    b.readyIcon:SetWidth(18)
    b.readyIcon:SetHeight(18)
    b.readyIcon:Hide()

    b.flagIcon = overlay:CreateTexture(nil, "OVERLAY")
    b.flagIcon:SetWidth(14)
    b.flagIcon:SetHeight(14)
    b.flagIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.flagIcon:Hide()

    b.arenaText = overlay:CreateFontString(nil, "OVERLAY")
    b.arenaText:SetJustifyH("RIGHT")
    b.arenaText:Hide()

    local top = CreateFrame("Frame", nil, b)
    top:SetAllPoints(b)
    top:SetFrameLevel(b:GetFrameLevel() + 8)
    b.borderFrame = top

    b.border = NewBorder(top, "BORDER")
    b.border:SetThickness(1, 0)
    b.border:SetColor(0, 0, 0, 1)

    b.selectBorder = NewBorder(top, "ARTWORK")
    b.selectBorder:SetThickness(1, 1)
    b.selectBorder:SetColor(1, 1, 1, 0.9)
    b.selectBorder:Hide()

    b.focusBorder = NewBorder(top, "ARTWORK")
    b.focusBorder:SetThickness(1, 1)
    b.focusBorder:SetColor(0.3, 0.9, 1, 0.9)
    b.focusBorder:Hide()

    b.dispelBorder = NewBorder(top, "ARTWORK")
    b.dispelBorder:SetThickness(2, 2)
    b.dispelBorder:Hide()

    b.aggroBorder = NewBorder(top, "OVERLAY")
    b.aggroBorder:SetThickness(2, -1)
    b.aggroBorder:Hide()

    self:CreateAuraWidgets(b)
    self:CreateIndicatorWidgets(b)
    self:CreateReminderWidgets(b)
    self:CreateCooldownWidgets(b)

    -- SecureUnitButtonTemplate defines no OnShow/OnHide/OnAttributeChanged, so SetScript is safe here
    b:SetScript("OnShow", OnShow)
    b:SetScript("OnHide", OnHide)
    b:SetScript("OnAttributeChanged", OnAttributeChanged)
    if not InCombatLockdown() then
        b:SetAttribute("toggleForVehicle", self.db.vehicleSwap and true or false)
        self:ApplyClickBindings(b)
    end

    allButtons[#allButtons + 1] = b
    return b
end

function ns:CreateUnitButton(parent, name, kind)
    local b = CreateFrame("Button", name, parent, "SecureUnitButtonTemplate")
    b:Hide()
    return self:SetupUnitButton(b, kind)
end

------------------------------------------------------------------------
-- Layout of a single button (sizes come from the kind-specific config)
------------------------------------------------------------------------
function ns:LayoutButton(b)
    local db = self.db
    local tex = self:Fetch("statusbar", db.texture)
    local inset = 1
    local ph = b.showPower and db.powerHeight or 0
    local ch = self:Cfg(b, "castbar") and db.castbarHeight or 0
    local fontSize = self:Cfg(b, "fontSize")

    b.bg:SetVertexColor(0.06, 0.06, 0.06, db.bgAlpha)

    local p = b.power
    p:ClearAllPoints()
    p:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", inset, inset)
    p:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -inset, inset)
    p:SetHeight(max(ph, 1))
    p:SetStatusBarTexture(tex)
    p.bg:SetTexture(tex)
    if ph > 0 then p:Show() else p:Hide() end

    local cb = b.castbar
    cb:ClearAllPoints()
    cb:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", inset, inset + ph)
    cb:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -inset, inset + ph)
    cb:SetHeight(max(ch, 1))
    self:LayoutCastbar(b)

    local h = b.health
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", b, "TOPLEFT", inset, -inset)
    h:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -inset, inset + ph + ch)
    h:SetStatusBarTexture(tex)
    h.bg:SetTexture(tex)

    b.hover:ClearAllPoints()
    b.hover:SetAllPoints(h)

    b.roleIcon:ClearAllPoints()
    b.roleIcon:SetPoint("TOPLEFT", h, "TOPLEFT", 2, -2)

    StyleFont(b.nameText, fontSize)
    b.nameText:SetHeight(fontSize + 3)
    StyleFont(b.statusText, max(min(db.statusTextSize, fontSize + 2), 7))
    b.statusText:ClearAllPoints()
    b.statusText:SetPoint("CENTER", h, "CENTER", 0, 2)

    StyleFont(b.arenaText, max(fontSize + 1, 9), "OUTLINE")
    b.arenaText:ClearAllPoints()
    b.arenaText:SetPoint("TOPRIGHT", h, "TOPRIGHT", -2, -1)

    b.leaderIcon:ClearAllPoints()
    b.leaderIcon:SetPoint("CENTER", b, "TOPLEFT", 6, 1)

    b.raidIcon:ClearAllPoints()
    b.raidIcon:SetPoint("TOP", h, "TOP", 0, -1)

    b.readyIcon:ClearAllPoints()
    b.readyIcon:SetPoint("CENTER", h, "CENTER", 0, 0)

    b.flagIcon:ClearAllPoints()
    b.flagIcon:SetPoint("TOPLEFT", h, "TOPLEFT", 2, -2)

    local bc = db.borderColor
    b.border:SetColor(bc[1], bc[2], bc[3], 1)
    if db.showBorder then b.border:Show() else b.border:Hide() end

    self:UpdateRole(b)
    self:LayoutAuras(b)
    self:LayoutIndicators(b)
    self:LayoutReminder(b)
    self:LayoutCooldowns(b)
end

------------------------------------------------------------------------
-- Element updates
------------------------------------------------------------------------
function ns:ShouldShowPower(b)
    local mode = self:Cfg(b, "powerBar")
    if mode == "NONE" then return false end
    if mode == "ALL" then return true end
    local role, class, ptype
    if b.testData then
        role, class, ptype = b.testData.role, b.testData.class, b.testData.powerType or 0
    elseif b.unit then
        role = self.GetRole(b.unit)
        local _
        _, class = UnitClass(b.unit)
        ptype = UnitPowerType(b.unit)
    else
        return false
    end
    if mode == "MANA" then return ptype == 0 end
    if role then return role == "HEALER" end
    return (HEALER_CLASSES[class] and ptype == 0) and true or false
end

function ns:UpdatePowerVisibility(b)
    local show = self:ShouldShowPower(b) and true or false
    if show ~= b.showPower then
        b.showPower = show
        self:LayoutButton(b)
    end
end

function ns:UpdateName(b)
    local db = self.db
    local name, class, level
    if b.testData then
        name, class, level = b.testData.name, b.testData.class, 80
    else
        name = UnitName(b.unit)
        local _
        _, class = UnitClass(b.unit)
        level = UnitLevel(b.unit)
    end
    name = name or ""
    if db.nameLength > 0 and string.len(name) > db.nameLength then
        name = string.sub(name, 1, db.nameLength)
    end
    if db.showLevel and level and level > 0 then name = level .. " " .. name end
    local avail = self:Cfg(b, "width") - 2 - 6 - (b.roleIcon:IsShown() and 14 or 0)
    FitName(b.nameText, name, avail)
    if db.nameClassColor and class then
        b.nameText:SetTextColor(self.ClassColor(class))
    else
        b.nameText:SetTextColor(1, 1, 1)
    end
end

local function GradientColor(pct)
    -- green (100 %) -> yellow (50 %) -> red (0 %)
    if pct >= 0.5 then
        local t = (pct - 0.5) * 2
        return 1 - t, 1, 0
    end
    local t = pct * 2
    return 1, t, 0
end

function ns:HealthColor(b, class, pct)
    local db = self.db
    local mode = db.healthColor
    if mode == "GRADIENT" then
        return GradientColor(pct)
    elseif mode == "CUSTOM" then
        local c = db.healthCustom
        return c[1], c[2], c[3]
    end
    if db.classColors and class then
        return self.ClassColor(class)
    end
    return 0.1, 0.8, 0.1
end

function ns:UpdateHealth(b)
    local db = self.db
    local cur, mx, dead, ghost, offline, class
    if b.testData then
        local d = b.testData
        mx = 20000
        cur = floor(mx * d.hp)
        dead, ghost, offline, class = d.dead, false, d.offline, d.class
    else
        local unit = b.unit
        local disp = b.dispUnit or unit
        cur, mx = UnitHealth(disp), UnitHealthMax(disp)
        dead, ghost = UnitIsDead(disp), UnitIsGhost(disp)
        offline = not UnitIsConnected(unit)
        local _
        if b.kind == "pet" then
            -- pets take their owner's class color
            local owner = (unit == "pet") and "player" or string.gsub(unit, "pet", "")
            _, class = UnitClass(owner)
        else
            _, class = UnitClass(unit)
        end
    end
    if not mx or mx <= 0 then mx = 1 end
    cur = cur or 0
    local pct = cur / mx

    local h = b.health
    h:SetMinMaxValues(0, mx)
    local r, g, bl
    if offline then
        r, g, bl = 0.45, 0.45, 0.45
        h:SetValue(mx)
    elseif dead or ghost then
        r, g, bl = 0.3, 0.3, 0.3
        h:SetValue(0)
    else
        h:SetValue(cur)
        r, g, bl = self:HealthColor(b, class, pct)
    end
    h:SetStatusBarColor(r, g, bl)
    local low = db.lowHealthHighlight and not (dead or ghost or offline) and pct * 100 <= db.lowHealthPercent
    b.lowHealth = low
    if dead or ghost or offline then
        h.bg:SetVertexColor(0.2, 0.2, 0.2, 1)
    elseif low then
        h.bg:SetVertexColor(0.55, 0.05, 0.05, 1)
    else
        h.bg:SetVertexColor(r * 0.22, g * 0.22, bl * 0.22, 1)
    end
    b.healthState = { cur = cur, mx = mx, dead = dead, ghost = ghost, offline = offline }
    self:UpdateStatusText(b)
    self:UpdateHealPrediction(b)
end

-- Offline > Dead/Ghost > Res incoming > AFK/DND > health text
function ns:UpdateStatusText(b)
    local db = self.db
    local st = b.healthState
    if not st then return end
    local text
    local tr, tg, tb = 1, 1, 1
    local mode = self:Cfg(b, "healthText")
    if st.offline then
        text = PLAYER_OFFLINE or "Offline"
        tr, tg, tb = 0.7, 0.7, 0.7
    elseif st.ghost then
        text = "Ghost"
        tr, tg, tb = 0.7, 0.7, 0.7
    elseif st.dead then
        if self:Cfg(b, "resIncoming") and self:HasResIncoming(b) then
            text = "Res"
            tr, tg, tb = 0.3, 1, 0.3
        else
            text = DEAD or "Dead"
            tr, tg, tb = 0.85, 0.2, 0.2
        end
    elseif db.afkText and b.unit and not b.testData and UnitIsAFK(b.unit) then
        text = "AFK"
        tr, tg, tb = 0.7, 0.7, 0.7
    elseif db.afkText and b.unit and not b.testData and UnitIsDND(b.unit) then
        text = "DND"
        tr, tg, tb = 0.7, 0.7, 0.7
    elseif mode == "HEALTH" then
        text = self.ShortValue(st.cur)
    elseif mode == "LOST" then
        local lost = st.mx - st.cur
        if lost > 0 then
            text = "-" .. self.ShortValue(lost)
            tr, tg, tb = 1, 0.35, 0.35
        end
    elseif mode == "PERCENT" then
        text = floor(st.cur / st.mx * 100 + 0.5) .. "%"
    elseif b.lowHealth and mode == "NONE" then
        text = floor(st.cur / st.mx * 100 + 0.5) .. "%"
        tr, tg, tb = 1, 0.3, 0.3
    end
    if b.lowHealth and text and mode ~= "NONE" then tr, tg, tb = 1, 0.3, 0.3 end
    b.statusText:SetText(text or "")
    b.statusText:SetTextColor(tr, tg, tb)
end

function ns:UpdatePower(b)
    if not b.showPower then return end
    local cur, mx, ptype
    if b.testData then
        mx = 100
        cur = floor(100 * (b.testData.power or 1))
        ptype = b.testData.powerType or 0
    else
        local disp = b.dispUnit or b.unit
        cur, mx, ptype = UnitPower(disp), UnitPowerMax(disp), UnitPowerType(disp)
    end
    if not mx or mx <= 0 then mx = 1 end
    b.power:SetMinMaxValues(0, mx)
    b.power:SetValue(cur or 0)
    local c = (PowerBarColor and (PowerBarColor[ptype] or PowerBarColor["MANA"])) or { r = 0, g = 0.5, b = 1 }
    b.power:SetStatusBarColor(c.r, c.g, c.b)
    b.power.bg:SetVertexColor(c.r * 0.25, c.g * 0.25, c.b * 0.25, 1)
end

function ns:UpdateRole(b)
    local role
    if b.testData then
        role = b.testData.role
    elseif b.unit then
        role = self.GetRole(b.unit)
    end
    local c = self:Cfg(b, "roleIcon") and role and ROLE_COORDS[role]
    b.nameText:ClearAllPoints()
    if c then
        b.roleIcon:SetTexCoord(c[1], c[2], c[3], c[4])
        b.roleIcon:Show()
        b.nameText:SetPoint("TOPLEFT", b.roleIcon, "TOPRIGHT", 2, 0)
        b.nameText:SetPoint("TOPRIGHT", b.health, "TOPRIGHT", -3, -2)
    else
        b.roleIcon:Hide()
        b.nameText:SetPoint("TOPLEFT", b.health, "TOPLEFT", 3, -3)
        b.nameText:SetPoint("TOPRIGHT", b.health, "TOPRIGHT", -3, -3)
    end
end

function ns:UpdateLeader(b)
    local leader, assist
    if b.testData then
        leader = b.testData.leader
    elseif b.unit then
        if UnitInRaid(b.unit) then
            local idx = tonumber(string.match(b.unit, "^raid(%d+)$"))
            if not idx then
                for i = 1, GetNumRaidMembers() do
                    if UnitIsUnit("raid" .. i, b.unit) then idx = i break end
                end
            end
            if idx then
                local _, rank = GetRaidRosterInfo(idx)
                leader = rank == 2
                assist = rank == 1
            end
        elseif UnitIsPartyLeader then
            leader = UnitIsPartyLeader(b.unit)
        end
    end
    if self:Cfg(b, "leaderIcon") and (leader or assist) then
        b.leaderIcon:SetTexture(leader and "Interface\\GroupFrame\\UI-Group-LeaderIcon" or "Interface\\GroupFrame\\UI-Group-AssistantIcon")
        b.leaderIcon:Show()
    else
        b.leaderIcon:Hide()
    end
end

function ns:UpdateRaidIcon(b)
    local idx
    if b.testData then
        idx = (b.index == 1 and b.kind == "party") and 8 or nil
    elseif b.unit then
        idx = GetRaidTargetIndex(b.unit)
    end
    if self.db.raidIcon and idx then
        SetRaidTargetIconTexture(b.raidIcon, idx)
        b.raidIcon:Show()
    else
        b.raidIcon:Hide()
    end
end

function ns:UpdateThreat(b)
    local status
    if b.testData then
        status = b.testData.aggro
    elseif b.unit and UnitThreatSituation then
        status = UnitThreatSituation(b.unit)
    end
    if self.db.aggro and status and status >= 2 then
        local r, g, bl = GetThreatStatusColor(status)
        b.aggroBorder:SetColor(r, g, bl, 1)
        b.aggroBorder:Show()
    else
        b.aggroBorder:Hide()
    end
end

function ns:UpdateTarget(b)
    local selected, focused
    if b.testData then
        selected = b.testData.selected
    elseif b.unit then
        selected = UnitIsUnit(b.unit, "target")
        focused = UnitExists("focus") and UnitIsUnit(b.unit, "focus")
    end
    if self.db.targetHighlight and selected then b.selectBorder:Show() else b.selectBorder:Hide() end
    if self.db.focusHighlight and focused and not selected then b.focusBorder:Show() else b.focusBorder:Hide() end
end

function ns:UpdateReadyCheck(b)
    if not self:Cfg(b, "readyCheck") or b.testData or not b.unit then
        b.readyIcon:Hide()
        return
    end
    if self.readyCheckActive then
        local status = GetReadyCheckStatus(b.unit)
        if status and READY_TEX[status] then
            b.readyIcon:SetTexture(READY_TEX[status])
            b.readyIcon.status = status
            b.readyIcon:Show()
        else
            b.readyIcon:Hide()
        end
    elseif not self.readyCheckFading then
        b.readyIcon:Hide()
    end
end

local rangeSpellName
function ns:RangeSpell()
    local db = self.db
    if db.rangeSpell and db.rangeSpell ~= "" then return db.rangeSpell end
    if rangeSpellName == nil then
        local _, class = UnitClass("player")
        local id = RANGE_SPELLS[class]
        rangeSpellName = (id and GetSpellInfo(id)) or false
    end
    return rangeSpellName or nil
end

function ns:InRange(unit)
    if self.db.rangeCheck == "SPELL" then
        local spell = self:RangeSpell()
        if spell then
            local r = IsSpellInRange(spell, unit)
            if r ~= nil then return r == 1 end
        end
    end
    if UnitInRange then return UnitInRange(unit) and true or false end
    return true
end

function ns:UpdateRange(b)
    local alpha = self.db.frameAlpha
    local db = self.db
    if b.testData then
        if b.testData.oor then alpha = alpha * db.rangeAlpha end
    elseif b.unit and not UnitIsUnit(b.unit, "player") then
        if not UnitIsConnected(b.unit) then
            alpha = alpha * db.rangeAlpha
        elseif not self:InRange(b.unit) then
            alpha = alpha * db.rangeAlpha
        end
    end
    if b.lastAlpha ~= alpha then
        b.lastAlpha = alpha
        b:SetAlpha(alpha)
    end
end

function ns:UpdateHealPrediction(b)
    local pred = b.healPred
    if not (HealComm and self:Cfg(b, "healPrediction")) or b.testData or not b.unit then
        pred:Hide()
        return
    end
    local unit = b.dispUnit or b.unit
    local guid = UnitGUID(unit)
    if not guid or UnitIsDeadOrGhost(unit) then pred:Hide() return end
    local amount = HealComm:GetHealAmount(guid, HealComm.ALL_HEALS) or 0
    if amount <= 0 then pred:Hide() return end
    amount = amount * (HealComm:GetHealModifier(guid) or 1)
    local cur, mx = UnitHealth(unit), UnitHealthMax(unit)
    if mx <= 0 then pred:Hide() return end
    amount = min(amount, mx - cur)
    if amount <= 0 then pred:Hide() return end
    local fill = b.health:GetStatusBarTexture()
    pred:ClearAllPoints()
    pred:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
    pred:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", 0, 0)
    pred:SetWidth(max(b.health:GetWidth() * amount / mx, 1))
    pred:Show()
end

-- battleground flag carrier
function ns:UpdateFlag(b)
    local icon
    if not b.testData and b.unit and self.inBattleground and self.db.bgFlags then
        for i = 1, 40 do
            local name, _, _, _, _, _, _, _, _, _, spellId = UnitAura(b.unit, i, "HELPFUL")
            if not name then break end
            if spellId and self.FlagAuras[spellId] then
                icon = self.FlagAuras[spellId]
                break
            end
        end
    end
    if icon then
        b.flagIcon:SetTexture(icon)
        b.flagIcon:Show()
        b.roleIcon:Hide()
    else
        b.flagIcon:Hide()
    end
end

-- arena: how many enemies target this unit
function ns:UpdateArenaTargets(b)
    local n = 0
    if b.testData then
        n = b.testData.arenaTargets or 0
    elseif b.unit and self.inArena and self.db.arenaTargets then
        for i = 1, 5 do
            local enemy = "arena" .. i
            if UnitExists(enemy) and UnitIsUnit(enemy .. "target", b.unit) then n = n + 1 end
        end
    end
    if n > 0 then
        b.arenaText:SetText(n)
        if n >= 2 then b.arenaText:SetTextColor(1, 0.2, 0.2) else b.arenaText:SetTextColor(1, 0.85, 0.2) end
        b.arenaText:Show()
    else
        b.arenaText:Hide()
    end
end

-- Unit whose health/power the bar shows: the vehicle while the member sits in one (vehicleSwap),
-- otherwise the member itself. Name, class, role, auras and cooldowns always belong to the member.
function ns:DisplayUnit(b)
    local unit = b.unit
    if not unit or b.testData or b.kind == "pet" then return unit end
    if self.db.vehicleSwap and UnitHasVehicleUI and UnitHasVehicleUI(unit) then
        local veh
        if unit == "player" then
            veh = "pet"
        else
            veh = string.gsub(unit, "^(%a+)(%d+)$", "%1pet%2")
        end
        if UnitExists(veh) then return veh end
    end
    return unit
end

function ns:UpdateButton(b)
    if not (b.unit or b.testData) then return end
    if b.unit and not b.testData and not UnitExists(b.unit) then return end
    local disp = self:DisplayUnit(b)
    if disp ~= b.dispUnit then
        b.dispUnit = disp
        self:RebuildUnitMap()
    end
    self:UpdatePowerVisibility(b)
    self:UpdateRole(b)
    self:UpdateName(b)
    self:UpdateHealth(b)
    self:UpdatePower(b)
    self:UpdateLeader(b)
    self:UpdateRaidIcon(b)
    self:UpdateThreat(b)
    self:UpdateTarget(b)
    self:UpdateReadyCheck(b)
    self:UpdateRange(b)
    self:UpdateAuras(b)
    self:UpdateIndicators(b)
    self:UpdateReminder(b)
    self:UpdateFlag(b)
    self:UpdateArenaTargets(b)
    self:UpdateCastbar(b)
    self:UpdateCooldownIcons(b)
end

function ns:UpdateAllButtons()
    for i = 1, #allButtons do
        local b = allButtons[i]
        if b:IsShown() and (b.unit or b.testData) then self:UpdateButton(b) end
    end
end

function ns:LayoutAllButtons()
    for i = 1, #allButtons do self:LayoutButton(allButtons[i]) end
end

------------------------------------------------------------------------
-- Resurrection tracking ("Res" on the dead target's frame)
------------------------------------------------------------------------
local resByCaster = {}   -- caster guid -> target guid
local resTargets = {}    -- target guid -> count
local resNames

local function ResNames()
    if resNames then return resNames end
    resNames = {}
    for id in pairs(ns.ResurrectSpells) do
        local name = GetSpellInfo(id)
        if name then resNames[name] = true end
    end
    return resNames
end

function ns:HasResIncoming(b)
    if b.testData then return b.testData.res end
    local guid = b.unit and UnitGUID(b.unit)
    return guid and resTargets[guid] and resTargets[guid] > 0
end

local function RefreshStatusByGUID(guid)
    ns:ForEachButton(function(b)
        if not b.testData and b.unit and UnitGUID(b.unit) == guid then ns:UpdateStatusText(b) end
    end)
end

local function ResStart(unit, spell)
    if not spell or not ResNames()[spell] then return end
    local caster = UnitGUID(unit)
    local target = UnitGUID(unit .. "target")
    if not caster or not target then return end
    if resByCaster[caster] then
        local old = resByCaster[caster]
        resTargets[old] = (resTargets[old] or 1) - 1
    end
    resByCaster[caster] = target
    resTargets[target] = (resTargets[target] or 0) + 1
    RefreshStatusByGUID(target)
end

local function ResStop(unit)
    local caster = UnitGUID(unit)
    local target = caster and resByCaster[caster]
    if not target then return end
    resByCaster[caster] = nil
    resTargets[target] = (resTargets[target] or 1) - 1
    if resTargets[target] <= 0 then resTargets[target] = nil end
    RefreshStatusByGUID(target)
end

local function IsGroupUnit(unit)
    return unit == "player" or string.find(unit, "^party%d$") or string.find(unit, "^raid%d+$")
end

ns:On("UNIT_SPELLCAST_START", function(_, unit, spell)
    if unit and ns.db and ns.db.resIncoming and IsGroupUnit(unit) then ResStart(unit, spell) end
end)
for _, ev in ipairs({ "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED" }) do
    ns:On(ev, function(_, unit)
        if unit and IsGroupUnit(unit) then ResStop(unit) end
    end)
end

------------------------------------------------------------------------
-- Movers (shared by party / raid / main tank containers)
------------------------------------------------------------------------
function ns:CreateMover(container, label, pointKey)
    local mover = CreateFrame("Frame", nil, UIParent)
    mover:SetFrameStrata("HIGH")
    mover:SetAllPoints(container)
    mover:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    mover:SetBackdropColor(0.1, 0.5, 1, 0.3)
    mover:SetBackdropBorderColor(0.1, 0.5, 1, 0.9)
    mover.text = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mover.text:SetPoint("BOTTOM", mover, "TOP", 0, 4)
    mover.text:SetText(label .. "\n|cffffffffdrag to move, right-click to lock|r")
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function()
        if not InCombatLockdown() then container:StartMoving() end
    end)
    mover:SetScript("OnDragStop", function()
        container:StopMovingOrSizing()
        local p, _, rp, x, y = container:GetPoint(1)
        ns.db[pointKey] = { p, rp, x, y }
        -- the raid preview container is anchored separately from the mover: re-anchor it
        if ns.testMode and ns.RefreshAll then ns:RefreshAll() end
    end)
    mover:SetScript("OnMouseUp", function(_, btn)
        if btn == "RightButton" then ns:ToggleLock(true) end
    end)
    mover:Hide()
    container:SetMovable(true)
    container:SetClampedToScreen(true)
    self.movers = self.movers or {}
    self.movers[#self.movers + 1] = mover
    return mover
end

function ns:PlaceContainer(container, pointKey, scaleKey)
    local pt = self.db[pointKey]
    container:SetScale(scaleKey and self.db[scaleKey] or 1)
    container:ClearAllPoints()
    container:SetPoint(pt[1] or "TOPLEFT", UIParent, pt[2] or "TOPLEFT", pt[3] or 0, pt[4] or 0)
end

function ns:ToggleLock(force)
    if InCombatLockdown() then
        self:Print("Cannot move frames in combat.")
        return
    end
    if force ~= nil then
        self.db.locked = force
    else
        self.db.locked = not self.db.locked
    end
    self:SyncMovers()
    if self.RefreshOptions then self:RefreshOptions() end
end

-- movers follow the active profile's `locked` flag (also after profile switch / reset / import)
function ns:SyncMovers()
    for _, m in ipairs(self.movers or {}) do
        if self.db.locked then m:Hide() else m:Show() end
    end
end

function ns:ResetPosition()
    self.db.point = self.DeepCopy(self.defaults.point)
    self.db.raidPoint = self.DeepCopy(self.defaults.raidPoint)
    self.db.mtPoint = self.DeepCopy(self.defaults.mtPoint)
    self:RefreshAll()
end

------------------------------------------------------------------------
-- Test mode: nil / "party" / "raid"
------------------------------------------------------------------------
function ns:SetTestMode(mode)
    if mode and InCombatLockdown() then
        self:Print("Test mode is not available in combat.")
        return
    end
    if mode == self.testMode then return end
    self.testMode = mode
    if mode then self:SeedTestCooldowns() end
    self:RefreshAll()
    if self.RefreshOptions then self:RefreshOptions() end
    if mode == "party" then
        self:Print("Test mode: |cff00ff00party preview|r (type /rpf test again for the raid preview).")
    elseif mode == "raid" then
        self:Print("Test mode: |cff00ff00raid preview|r (type /rpf test again to turn it off).")
    else
        self:Print("Test mode |cffff0000off|r.")
    end
end

function ns:CycleTestMode(which)
    if which == "party" or which == "raid" then
        self:SetTestMode(self.testMode == which and nil or which)
    elseif which == "off" then
        self:SetTestMode(nil)
    elseif not self.testMode then
        self:SetTestMode("party")
    elseif self.testMode == "party" then
        self:SetTestMode("raid")
    else
        self:SetTestMode(nil)
    end
end

function ns:ToggleTestMode()
    self:SetTestMode(self.testMode and nil or "party")
end

------------------------------------------------------------------------
-- Full refresh (profile change, option change, group change)
------------------------------------------------------------------------
function ns:RefreshAll()
    if InCombatLockdown() then
        self:AfterCombat("refreshall", function() ns:RefreshAll() end)
        self:LayoutAllButtons()
        self:UpdateAllButtons()
        return
    end
    rangeSpellName = nil
    self:Fire("LAYOUT")          -- Party / Raid / ClickCast / Extras rebuild their parts
    self:RebuildUnitMap()
    self:UpdateAllButtons()
end

------------------------------------------------------------------------
-- Tickers: range (0.2 s) and arena target counter (0.25 s)
------------------------------------------------------------------------
local ticker = CreateFrame("Frame")
local rangeAcc, arenaAcc = 0, 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    if not ns.db then return end
    rangeAcc = rangeAcc + elapsed
    arenaAcc = arenaAcc + elapsed
    local doRange = rangeAcc >= 0.2
    local doArena = arenaAcc >= 0.25 and (ns.inArena or ns.testMode)
    if not doRange and not doArena then return end
    if doRange then rangeAcc = 0 end
    if doArena then arenaAcc = 0 end
    for i = 1, #allButtons do
        local b = allButtons[i]
        if b:IsShown() and (b.unit or b.testData) then
            if doRange then ns:UpdateRange(b) end
            if doArena then ns:UpdateArenaTargets(b) end
        end
    end
end)

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local function all(method)
    return function()
        for i = 1, #allButtons do
            local b = allButtons[i]
            if b:IsShown() and (b.unit or b.testData) then method(ns, b) end
        end
    end
end

ns:On("UNIT_HEALTH", function(_, unit) ForUnit(unit, ns.UpdateHealth) end)
ns:On("UNIT_MAXHEALTH", function(_, unit) ForUnit(unit, ns.UpdateHealth) end)

for _, ev in ipairs({ "UNIT_MANA", "UNIT_RAGE", "UNIT_ENERGY", "UNIT_FOCUS", "UNIT_RUNIC_POWER",
                      "UNIT_MAXMANA", "UNIT_MAXRAGE", "UNIT_MAXENERGY", "UNIT_MAXFOCUS", "UNIT_MAXRUNIC_POWER" }) do
    ns:On(ev, function(_, unit) ForUnit(unit, ns.UpdatePower) end)
end

ns:On("UNIT_DISPLAYPOWER", function(_, unit)
    ForUnit(unit, function(self, b)
        self:UpdatePowerVisibility(b)
        self:UpdatePower(b)
    end)
end)

ns:On("UNIT_NAME_UPDATE", function(_, unit) ForUnit(unit, ns.UpdateButton) end)
ns:On("UNIT_LEVEL", function(_, unit) ForUnit(unit, ns.UpdateName) end)
ns:On("UNIT_THREAT_SITUATION_UPDATE", function(_, unit) ForUnit(unit, ns.UpdateThreat) end)
ns:On("UNIT_FLAGS", function(_, unit) ForUnit(unit, ns.UpdateStatusText) end)
ns:On("PLAYER_FLAGS_CHANGED", function(_, unit) ForUnit(unit, ns.UpdateStatusText) end)
ns:On("PLAYER_TARGET_CHANGED", all(ns.UpdateTarget))
ns:On("PLAYER_FOCUS_CHANGED", all(ns.UpdateTarget))
ns:On("RAID_TARGET_UPDATE", all(ns.UpdateRaidIcon))
ns:On("PARTY_LEADER_CHANGED", all(ns.UpdateLeader))
ns:On("PARTY_MEMBER_ENABLE", all(ns.UpdateButton))
ns:On("PARTY_MEMBER_DISABLE", all(ns.UpdateButton))
-- UpdateButton re-evaluates the display unit (vehicle <-> member) and rebuilds the unit map
ns:On("UNIT_ENTERED_VEHICLE", function(_, unit) ForUnit(unit, ns.UpdateButton) end)
ns:On("UNIT_EXITED_VEHICLE", function(_, unit) ForUnit(unit, ns.UpdateButton) end)
ns:On("UNIT_PET", function(_, unit) ForUnit(unit, ns.UpdateButton) end)

ns:On("PLAYER_ROLES_ASSIGNED", function()
    ns:Fire("ROLES_CHANGED")
    for i = 1, #allButtons do
        local b = allButtons[i]
        if b:IsShown() and b.unit then
            ns:UpdatePowerVisibility(b)
            ns:UpdateRole(b)
            ns:UpdateName(b)
            ns:UpdatePower(b)
        end
    end
end)

ns:On("READY_CHECK", function()
    ns.readyCheckActive = true
    ns.readyCheckFading = false
    all(ns.UpdateReadyCheck)()
end)
ns:On("READY_CHECK_CONFIRM", all(ns.UpdateReadyCheck))
ns:On("READY_CHECK_FINISHED", function()
    ns.readyCheckActive = false
    ns.readyCheckFading = true
    for i = 1, #allButtons do
        local icon = allButtons[i].readyIcon
        if icon:IsShown() and icon.status == "waiting" then icon:SetTexture(READY_TEX.notready) end
    end
    ns:After(6, function()
        if ns.readyCheckActive then return end
        ns.readyCheckFading = false
        for i = 1, #allButtons do allButtons[i].readyIcon:Hide() end
    end)
end)

ns:On("PLAYER_REGEN_DISABLED", function()
    -- this fires right before combat lockdown, secure changes are still allowed
    if ns.testMode then ns:SetTestMode(nil) end
    if ns.db and not ns.db.locked then ns:ToggleLock(true) end
end)

ns:RegisterCallback("GROUP_CHANGED", function()
    if ns.container then
        ns:RefreshAll()
        ns:RefreshGroupGUIDs()
    end
end)

ns:RegisterInit(function()
    -- optional incoming heals
    HealComm = LibStub and LibStub("LibHealComm-4.0", true)
    if HealComm then
        local function refresh()
            ns:ForEachButton(function(b) ns:UpdateHealPrediction(b) end)
        end
        for _, ev in ipairs({ "HealComm_HealStarted", "HealComm_HealUpdated", "HealComm_HealDelayed",
                              "HealComm_HealStopped", "HealComm_ModifierChanged", "HealComm_GUIDDisappeared" }) do
            HealComm.RegisterCallback(ns, ev, refresh)
        end
    end
end, "unitbutton")

------------------------------------------------------------------------
-- /rpf debug
------------------------------------------------------------------------
local function yn(v) return v and "yes" or "no" end

function ns:Debug()
    local db = self.db
    self:Print(string.format("v%s profile=%s  group=%s size=%d party=%d raid=%d  combat=%s  test=%s",
        self.version, self:ActiveProfileName(), self.groupType, self.groupSize, GetNumPartyMembers(), GetNumRaidMembers(),
        yn(InCombatLockdown()), tostring(self.testMode)))
    local queued = {}
    for k in pairs(self.combatQueue) do queued[#queued + 1] = k end
    local inst, itype = IsInInstance()
    self:Print(string.format("instance=%s/%s arena=%s bg=%s  wantParty=%s wantRaid=%s raidMode=%s  queued=[%s]  errors=%d",
        yn(inst), tostring(itype), yn(self.inArena), yn(self.inBattleground), yn(self:WantPartyFrames()), yn(self:WantRaidFrames()),
        db.raidMode, table.concat(queued, ","), self.initErrors and #self.initErrors or 0))
    local function dump(label, c)
        if not c then return end
        local p, _, rp, x, y = c:GetPoint(1)
        self:Print(string.format("%s shown=%s visible=%s alpha=%.2f scale=%.2f size=%.0fx%.0f anchor=%s/%s %.0f,%.0f",
            label, yn(c:IsShown()), yn(c:IsVisible()), c:GetAlpha(), c:GetScale(), c:GetWidth(), c:GetHeight(),
            tostring(p), tostring(rp), x or 0, y or 0))
    end
    dump("party container", self.container)
    dump("raid container", self.raidContainer)
    local shown = 0
    for i = 1, #allButtons do
        local b = allButtons[i]
        if b:IsShown() then shown = shown + 1 end
    end
    self:Print(string.format("buttons: %d created, %d shown", #allButtons, shown))
    for i = 1, #allButtons do
        local b = allButtons[i]
        if b.kind == "party" or (b:IsShown() and i <= 12) then
            self:Print(string.format("  %s%d unit=%s attr=%s exists=%s shown=%s visible=%s alpha=%.2f",
                b.kind, b.index or 0, tostring(b.unit), tostring(b:GetAttribute("unit")), yn(b.unit and UnitExists(b.unit)),
                yn(b:IsShown()), yn(b:IsVisible()), b:GetAlpha()))
        end
    end
end
