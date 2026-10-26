-- BetterFrames335 - Indicators.lua
-- Combat indicator (target/focus/party), absorb-shield indicator (target/focus/player) with an
-- estimated remaining amount, racial indicator (target/focus) and a stealth indicator (player).
-- 3.3.5 has no absorb-amount API: the amount is the spell's base value minus absorbed damage
-- seen in the combat log, so it is an estimate (spellpower is not known for other players).

local BBF = BBF335
local M = BBF:NewModule("Indicators")
local db
local GetTime = GetTime

-- absorb effects (names resolved from IDs -> works on every client language & rank)
local absorbIDs = {
    17, 47753, 11426, 1463, 543, 6143, 48707, 6229, 7812, 53601, 58597, 62606, 50461, 64413,
}
local absorbNames = {}

-- base absorb values (3.3.5, max ranks, without spellpower) for the estimate
local absorbBase = {
    [48066] = 2230, [48065] = 1951, [25218] = 1286, [25217] = 1144, [10901] = 942,   -- Power Word: Shield
    [43039] = 1075, [43038] = 925,  [27134] = 818,                                   -- Ice Barrier
    [43010] = 1950, [43012] = 1950,                                                 -- Fire / Frost Ward
    [47891] = 1650, [47890] = 1200, [28610] = 920,                                  -- Shadow Ward
    [43020] = 1330, [43019] = 1030,                                                 -- Mana Shield
    [47986] = 7000, [47985] = 4800,                                                 -- Sacrifice
    [58597] = 500,                                                                  -- Sacred Shield (absorb)
}

local entries = {}

local function Portrait(frame)
    if not frame then return end
    return frame.portrait or (frame:GetName() and _G[frame:GetName() .. "Portrait"])
end

local function MakeIcon(parent, withCooldown)
    local f = CreateFrame("Frame", nil, parent)
    f:SetFrameLevel(parent:GetFrameLevel() + 10)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints(f)
    if withCooldown then
        f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
        f.cd:SetAllPoints(f)
        if f.cd.SetReverse then pcall(f.cd.SetReverse, f.cd, true) end
        local ov = CreateFrame("Frame", nil, f)
        ov:SetAllPoints(f)
        ov:SetFrameLevel(f:GetFrameLevel() + 3)
        f.time = ov:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        f.time:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        f.time:SetPoint("CENTER", f, "CENTER", 0, 0)
        f.amount = ov:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        f.amount:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        f.amount:SetPoint("TOP", f, "BOTTOM", 0, -1)
        f.amount:SetTextColor(0.6, 0.9, 1)
    end
    f:Hide()
    return f
end

local function Add(unit, kind, frame, side)
    local p = Portrait(frame)
    if not frame or not p then return end
    entries[#entries + 1] = {
        unit = unit, kind = kind, side = side, portrait = p,
        icon = MakeIcon(frame, kind == "absorb"),
    }
end

local function Position(e)
    local ic, p = e.icon, e.portrait
    local size = db.indSize
    if e.side == "party" then size = math.floor(size * 0.7) end
    if e.kind == "racial" then size = db.racialSize end
    ic:SetWidth(size)
    ic:SetHeight(size)
    ic:ClearAllPoints()
    if e.kind == "racial" then
        ic:SetPoint("BOTTOM", p, "TOP", 0, 2)
    elseif e.kind == "stealth" then
        ic:SetPoint("RIGHT", p, "LEFT", -4 - db.indX, 12 + db.indY)
    elseif e.side == "right" then
        local y = (e.kind == "combat") and 12 or -14
        ic:SetPoint("LEFT", p, "RIGHT", 4 + db.indX, y + db.indY)
    elseif e.side == "left" then
        ic:SetPoint("RIGHT", p, "LEFT", -4 - db.indX, -14 + db.indY)
    else
        ic:SetPoint("CENTER", p, "BOTTOMLEFT", 4, 4)
    end
end

local function FindAbsorb(unit)
    for i = 1, 40 do
        local name, _, icon, _, _, duration, expires = UnitBuff(unit, i)
        if not name then return end
        if absorbNames[name] then return icon, duration, expires end
    end
end

----------------------------------------------------------------------
-- absorb amount estimate (combat log)
----------------------------------------------------------------------
local shields = {}      -- destGUID -> { [spellId] = remaining }

local function ShieldTotal(guid)
    local t = guid and shields[guid]
    if not t then return end
    local sum, any = 0, false
    for _, v in pairs(t) do sum = sum + v; any = true end
    if any then return sum end
end

local function Absorbed(destGUID, amount)
    local t = shields[destGUID]
    if not t or not amount or amount <= 0 then return end
    -- take the damage from the shields in arbitrary order (the client can't tell which one absorbed)
    for id, v in pairs(t) do
        if amount <= 0 then break end
        local take = math.min(v, amount)
        t[id] = v - take
        amount = amount - take
    end
end

local function LogAbsorb(_, _, _, event, _, _, _, destGUID, _, _, a1, a2, a3, a4, a5, a6, a7, a8, a9)
    if not destGUID then return end
    if event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH" then
        local base = absorbBase[a1]
        if base then
            shields[destGUID] = shields[destGUID] or {}
            shields[destGUID][a1] = base
        end
    elseif event == "SPELL_AURA_REMOVED" then
        local t = shields[destGUID]
        if t and t[a1] then
            t[a1] = nil
            if not next(t) then shields[destGUID] = nil end
        end
    elseif shields[destGUID] then
        if event == "SWING_DAMAGE" then
            -- amount, overkill, school, resisted, blocked, absorbed
            Absorbed(destGUID, a6)
        elseif event == "SPELL_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" or event == "RANGE_DAMAGE" or event == "DAMAGE_SHIELD" then
            -- spellId, spellName, school, amount, overkill, school, resisted, blocked, absorbed
            Absorbed(destGUID, a9)
        elseif event == "SWING_MISSED" then
            -- missType, amount
            if a1 == "ABSORB" then Absorbed(destGUID, a2) end
        elseif event == "SPELL_MISSED" or event == "SPELL_PERIODIC_MISSED" or event == "RANGE_MISSED" then
            -- spellId, spellName, school, missType, amount
            if a4 == "ABSORB" then Absorbed(destGUID, a5) end
        end
    end
end

----------------------------------------------------------------------
-- updates (only touch textures / Show / Hide when the state actually changes)
----------------------------------------------------------------------
local function SetState(ic, state)
    if ic.bbfState == state then return end
    ic.bbfState = state
    if state == "in" then
        ic.tex:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
        ic.tex:SetTexCoord(0.5, 1, 0, 0.49)
        ic:Show()
    elseif state == "out" then
        ic.tex:SetTexture("Interface\\Icons\\INV_Misc_Fork&Knife")
        ic.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        ic:Show()
    else
        ic:Hide()
    end
end

local function UpdateCombat(e)
    local unit, ic = e.unit, e.icon
    if not db.combatIndicator or (e.side == "party" and not db.combatParty) or not UnitExists(unit)
        or (db.combatArenaOnly and not BBF:InArena())
        or (db.combatEnemyOnly and e.side ~= "party" and not UnitCanAttack("player", unit))
        or (db.combatPlayersOnly and not UnitIsPlayer(unit)) then
        SetState(ic, nil)
        return
    end
    local inCombat = UnitAffectingCombat(unit)
    if inCombat and db.combatShowIn then
        SetState(ic, "in")
    elseif not inCombat and db.combatShowOut then
        SetState(ic, "out")
    else
        SetState(ic, nil)
    end
end

local function UpdateAbsorbTimer(ic, unit)
    local txt = ""
    if ic.bbfExp and db.absorbTimer then
        local left = ic.bbfExp - GetTime()
        if left > 0 then txt = format("%d", left + 0.5) end
    end
    if txt ~= ic.bbfTimerText then
        ic.time:SetText(txt)
        ic.bbfTimerText = txt
    end
    local amt = ""
    if db.absorbAmount then
        local total = ShieldTotal(UnitGUID(unit))
        if total and total > 0 then amt = "~" .. BBF:ShortNumber(total) end
    end
    if amt ~= ic.bbfAmountText then
        ic.amount:SetText(amt)
        ic.bbfAmountText = amt
    end
end

local function UpdateAbsorb(e)
    local unit, ic = e.unit, e.icon
    if not db.absorbIndicator or (unit == "player" and not db.absorbPlayer) or not UnitExists(unit) then
        ic.bbfExp, ic.bbfIcon = nil, nil
        ic:Hide()
        return
    end
    local icon, duration, expires = FindAbsorb(unit)
    if not icon then
        ic.bbfExp, ic.bbfIcon = nil, nil
        ic:Hide()
        return
    end
    if ic.bbfIcon ~= icon then
        ic.tex:SetTexture(icon)
        ic.bbfIcon = icon
    end
    if duration and duration > 0 and expires then
        if ic.bbfExp ~= expires then
            CooldownFrame_SetTimer(ic.cd, expires - duration, duration, 1)
            ic.bbfExp = expires
        end
    elseif ic.bbfExp then
        CooldownFrame_SetTimer(ic.cd, 0, 0, 0)
        ic.bbfExp = nil
    end
    UpdateAbsorbTimer(ic, unit)
    ic:Show()
end

-- racial icons: spell IDs of the relevant racial per race (English race token from UnitRace)
local racialSpell = {
    Human = 59752,      -- Every Man for Himself
    NightElf = 58984,   -- Shadowmeld
    Orc = 20573,        -- Hardiness
    Scourge = 7744,     -- Will of the Forsaken
}
local racialOption = { Human = "racialHuman", NightElf = "racialNelf", Orc = "racialOrc", Scourge = "racialUndead" }

local function UpdateRacial(e)
    local unit, ic = e.unit, e.icon
    local enabled = db.racialIndicator and ((unit == "target" and db.racialTarget) or (unit == "focus" and db.racialFocus))
    if not enabled or not UnitExists(unit) or not UnitIsPlayer(unit) then ic:Hide(); ic.bbfRace = nil; return end
    local _, race = UnitRace(unit)
    local spell = race and racialSpell[race]
    if not spell or not db[racialOption[race]] then ic:Hide(); ic.bbfRace = nil; return end
    if ic.bbfRace ~= race then
        local _, _, tex = GetSpellInfo(spell)
        ic.tex:SetTexture(tex)
        ic.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        ic.bbfRace = race
    end
    ic:Show()
end

local function UpdateStealth(e)
    local ic = e.icon
    if not db.stealthIndicator or not IsStealthed() then ic:Hide(); return end
    if not ic.bbfSet then
        local _, _, tex = GetSpellInfo(1784)      -- Stealth
        ic.tex:SetTexture(tex or "Interface\\Icons\\Ability_Stealth")
        ic.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        ic.bbfSet = true
    end
    ic:Show()
end

local function UpdateEntry(e)
    if e.kind == "combat" then UpdateCombat(e)
    elseif e.kind == "absorb" then UpdateAbsorb(e)
    elseif e.kind == "racial" then UpdateRacial(e)
    elseif e.kind == "stealth" then UpdateStealth(e) end
end

local function UpdateUnit(unit)
    for i = 1, #entries do
        if entries[i].unit == unit then UpdateEntry(entries[i]) end
    end
end

local function UpdateAll()
    for i = 1, #entries do UpdateEntry(entries[i]) end
end

function M:Init()
    db = BBF.db
    for _, id in ipairs(absorbIDs) do
        local name = GetSpellInfo(id)
        if name then absorbNames[name] = true end
    end

    Add("target", "combat", TargetFrame, "right")
    Add("target", "absorb", TargetFrame, "right")
    Add("target", "racial", TargetFrame, "top")
    Add("focus", "combat", FocusFrame, "right")
    Add("focus", "absorb", FocusFrame, "right")
    Add("focus", "racial", FocusFrame, "top")
    Add("player", "absorb", PlayerFrame, "left")
    Add("player", "stealth", PlayerFrame, "left")
    for i = 1, 4 do
        Add("party" .. i, "combat", _G["PartyMemberFrame" .. i], "party")
    end

    -- events
    BBF:RegisterEvent("PLAYER_TARGET_CHANGED", function() UpdateUnit("target") end)
    BBF:RegisterEvent("PLAYER_FOCUS_CHANGED", function() UpdateUnit("focus") end)
    BBF:RegisterEvent("PARTY_MEMBERS_CHANGED", UpdateAll)
    BBF:RegisterEvent("ZONE_CHANGED_NEW_AREA", UpdateAll)
    BBF:RegisterEvent("UPDATE_STEALTH", function() UpdateUnit("player") end)
    BBF:RegisterEvent("UNIT_AURA", function(_, unit)
        if unit == "target" or unit == "focus" or unit == "player" then UpdateUnit(unit) end
    end)

    local log = CreateFrame("Frame")
    log:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    log:SetScript("OnEvent", BBF:Guard("AbsorbLog", LogAbsorb))

    -- light polling: combat state 4x/s, absorb timer/amount text 2x/s
    local driver = CreateFrame("Frame")
    local tCombat, tTimer = 0, 0
    driver:SetScript("OnUpdate", BBF:Guard("Indicators", function(_, elapsed)
        tCombat = tCombat + elapsed
        tTimer = tTimer + elapsed
        if tCombat >= 0.25 then
            tCombat = 0
            for i = 1, #entries do
                if entries[i].kind == "combat" then UpdateCombat(entries[i]) end
            end
        end
        if tTimer >= 0.5 then
            tTimer = 0
            for i = 1, #entries do
                local e = entries[i]
                if e.kind == "absorb" and e.icon:IsShown() then UpdateAbsorbTimer(e.icon, e.unit) end
            end
        end
    end))
end

function M:Apply()
    for i = 1, #entries do
        Position(entries[i])
        entries[i].icon.bbfState = "reset"    -- force redraw after option changes
    end
    UpdateAll()
end
