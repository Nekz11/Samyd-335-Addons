-- BetterFrames335 - Auras.lua
-- Target/focus aura filtering, sorting, own layout & sizes, important / refresh / purge glows,
-- DoT border, Alt-click list editing, spell IDs in tooltips, clickthrough,
-- and the player's own buff/debuff bar (filters, layout, cooldown spiral, duration text).

local BBF = BBF335
local M = BBF:NewModule("Auras")
local db
local GetTime = GetTime

local frameLists = {}   -- frame -> { buffs = {}, debuffs = {}, timed = bool }

local function IsMine(caster)
    return caster == "player" or caster == "pet" or caster == "vehicle"
end

-- returns allowed, isImportant
local function Allowed(unit, name, spellId, caster, duration, expires, isDebuff, hostile)
    if BBF:InList("important", name, spellId) then return true, true end
    if BBF:InList("blacklist", name, spellId) then return false end
    if BBF:InList("whitelist", name, spellId) then return true end
    if isDebuff then
        if db.onlyMyDebuffs and hostile and not IsMine(caster) then return false end
    else
        if db.whitelistMode then return false end
        if db.onlyMyBuffs and not IsMine(caster) then return false end
        if db.hidePermanentBuffs and (not duration or duration == 0) then return false end
        if db.underOneMinBuffs then
            if not duration or duration == 0 then return false end
            if expires and expires - GetTime() > 60 then return false end
        end
    end
    return true
end

----------------------------------------------------------------------
-- glow
----------------------------------------------------------------------
-- The glow lives on its own child frame so it draws above the cooldown swipe.
local function GetGlow(btn)
    local g = btn.bbfGlow
    if not g then
        g = CreateFrame("Frame", nil, btn)
        g:SetFrameLevel(btn:GetFrameLevel() + 5)
        g:SetPoint("CENTER", btn, "CENTER", 0, 0)
        g.tex = g:CreateTexture(nil, "OVERLAY")
        g.tex:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        g.tex:SetBlendMode("ADD")
        g.tex:SetAllPoints(g)
        btn.bbfGlow = g
    end
    return g
end

local function UpdateGlow(btn)
    local info = btn.bbfInfo
    if not info or not btn:IsShown() or not db.aurasEnabled then
        if btn.bbfGlow then btn.bbfGlow:Hide() end
        return
    end
    local r, g, b
    if info.important and db.importantGlow then
        r, g, b = 1, 0.82, 0
    elseif info.own and db.expireGlow and info.duration and info.duration > 0 and info.expires then
        local left = info.expires - GetTime()
        if left > 0 and left <= info.duration * db.expireGlowPct / 100 then
            r, g, b = 1, 0.15, 0.15
        end
    end
    if not r and info.purge and db.purgeHighlight then
        r, g, b = 0.25, 0.6, 1
    end
    if r then
        local glow = GetGlow(btn)
        local s = (btn.bbfSize or btn:GetWidth()) * 1.75
        glow:SetWidth(s)
        glow:SetHeight(s)
        glow.tex:SetVertexColor(r, g, b)
        glow:Show()
    elseif btn.bbfGlow then
        btn.bbfGlow:Hide()
    end
end

----------------------------------------------------------------------
-- Alt-click: Shift+Alt = blacklist, Ctrl+Alt = toggle important
----------------------------------------------------------------------
local function OnAuraMouseUp(btn, mouse)
    if mouse ~= "LeftButton" or not IsAltKeyDown() then return end
    local info = btn.bbfInfo
    if not info or not info.name then return end
    if IsShiftKeyDown() then
        BBF:AddToList("blacklist", info.name)
        BBF:Print("blacklisted |cffffffff" .. info.name .. "|r  (undo: /bbf bl del " .. info.name .. ")")
    elseif IsControlKeyDown() then
        if BBF:InList("important", info.name) then
            BBF:RemoveFromList("important", info.name)
            BBF:Print("removed from important: |cffffffff" .. info.name .. "|r")
        else
            BBF:AddToList("important", info.name)
            BBF:Print("marked important: |cffffffff" .. info.name .. "|r")
        end
    else
        return
    end
    M:Refresh()
end

local function HookButton(btn)
    if btn.bbfHooked then return end
    btn.bbfHooked = true
    -- chain manually: HookScript without an existing handler is unreliable on old clients
    local old = btn:GetScript("OnMouseUp")
    btn:SetScript("OnMouseUp", function(self, ...)
        if old then old(self, ...) end
        OnAuraMouseUp(self, ...)
    end)
end

----------------------------------------------------------------------
-- collect, sort & layout (target / focus)
----------------------------------------------------------------------
local function Collect(frame, kind, isDebuff, out, enabled, maxCount)
    local fname = frame:GetName()
    local unit = frame.unit
    local query = isDebuff and UnitDebuff or UnitBuff
    local hostile = UnitCanAttack("player", unit)
    local kept = 0
    for i = 1, 40 do
        local btn = _G[fname .. kind .. i]
        if not btn then break end
        if btn:IsShown() then
            local idx = btn:GetID()
            if not idx or idx == 0 then idx = i end
            local name, _, _, _, dtype, duration, expires, caster, _, _, spellId = query(unit, idx)
            local ok, important = false, false
            if name and enabled and kept < maxCount then
                ok, important = Allowed(unit, name, spellId, caster, duration, expires, isDebuff, hostile)
            end
            if ok then
                kept = kept + 1
                local info = btn.bbfInfo
                if not info then info = {}; btn.bbfInfo = info end
                info.name = name
                info.own = IsMine(caster)
                info.important = important
                info.duration = duration
                info.expires = expires
                info.purge = (not isDebuff) and dtype == "Magic" and hostile
                info.debuff = isDebuff
                out[#out + 1] = btn
                HookButton(btn)
                btn:EnableMouse(not db.clickthroughAuras)
            else
                btn:Hide()
            end
        end
    end
end

local function Rank(info)
    local r = 0
    if db.sortImportantFirst and info.important then r = r - 100 end
    if db.sortPurgeFirst and info.purge then r = r - 10 end
    if db.sortOwnFirst and info.own then r = r - 1 end
    return r
end

local function SortList(list)
    if not (db.sortImportantFirst or db.sortPurgeFirst or db.sortOwnFirst) then return end
    for i, b in ipairs(list) do b.bbfInfo.order = i end       -- keep Blizzard's order inside a rank
    table.sort(list, function(a, b)
        local ra, rb = Rank(a.bbfInfo), Rank(b.bbfInfo)
        if ra ~= rb then return ra < rb end
        return a.bbfInfo.order < b.bbfInfo.order
    end)
end

local function SizeButton(btn, size)
    btn.bbfSize = size
    btn:SetWidth(size)
    btn:SetHeight(size)
    local n = btn:GetName()
    if not btn.bbfAnchored then
        btn.bbfAnchored = true
        local icon = _G[n .. "Icon"]
        if icon then icon:ClearAllPoints(); icon:SetAllPoints(btn) end
        local cd = _G[n .. "Cooldown"]
        if cd then cd:ClearAllPoints(); cd:SetAllPoints(btn) end
    end
    local border = _G[n .. "Border"]
    if border then
        border:SetWidth(size + 2); border:SetHeight(size + 2)
        local info = btn.bbfInfo
        if db.dotBorder and info and info.debuff and info.own then
            border:SetVertexColor(BBF:ClassColor("player"))
            btn.bbfDotBorder = true
        elseif btn.bbfDotBorder then
            btn.bbfDotBorder = nil
            -- Blizzard recolors the border on its next update; use neutral until then
            local c = DebuffTypeColor and DebuffTypeColor["none"]
            if c then border:SetVertexColor(c.r, c.g, c.b) end
        end
    end
    local steal = _G[n .. "Stealable"]
    if steal then steal:SetWidth(size + 3); steal:SetHeight(size + 3) end
end

local state = {}

local function NewRow()
    if state.col > 0 then
        state.y = state.y + state.rowMax + db.auraGapY
        state.x, state.rowMax, state.col = 0, 0, 0
    end
end

local function Place(frame, list)
    local perRow = db.aurasPerRow
    local up = frame.buffsOnTop
    local x0 = (AURA_START_X or 5) + db.auraOffsetX
    local y0 = (AURA_START_Y or 32) + db.auraOffsetY
    for _, btn in ipairs(list) do
        if state.col >= perRow then NewRow() end
        if state.col == 0 then
            state.rows = state.rows + 1
            state.rowFirst = btn
        end
        local info = btn.bbfInfo
        local size = (info.own or info.important) and db.ownAuraSize or db.otherAuraSize
        if info.purge and db.purgeSize and db.purgeSize > 0 then size = db.purgeSize end
        SizeButton(btn, size)
        btn:ClearAllPoints()
        if up then
            btn:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", x0 + state.x, -15 - db.auraOffsetY * 2 + state.y)
        else
            btn:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", x0 + state.x, y0 - state.y)
        end
        state.x = state.x + size + db.auraGapX
        state.col = state.col + 1
        if size > state.rowMax then state.rowMax = size end
    end
end

local function Process(frame)
    if not db or not db.aurasEnabled then return end
    if frame ~= TargetFrame and frame ~= FocusFrame then return end
    local unit = frame.unit
    if type(unit) ~= "string" or not UnitExists(unit) then return end

    local lists = frameLists[frame]
    if not lists then
        lists = { buffs = {}, debuffs = {} }
        frameLists[frame] = lists
    end
    local buffs, debuffs = lists.buffs, lists.debuffs
    wipe(buffs)
    wipe(debuffs)
    local isTarget = frame == TargetFrame
    Collect(frame, "Buff", false, buffs, isTarget and db.targetBuffs or (not isTarget and db.focusBuffs), db.maxBuffs)
    Collect(frame, "Debuff", true, debuffs, isTarget and db.targetDebuffs or (not isTarget and db.focusDebuffs), db.maxDebuffs)
    SortList(buffs)
    SortList(debuffs)

    state.x, state.y, state.rowMax, state.col, state.rows, state.rowFirst = 0, 0, 0, 0, 0, nil
    local first, second = buffs, debuffs
    if db.debuffsFirst then first, second = debuffs, buffs end
    Place(frame, first)
    NewRow()
    Place(frame, second)

    -- keep Blizzard's castbar positioning consistent with our rows
    frame.auraRows = state.rows
    frame.spellbarAnchor = state.rowFirst
    if frame.spellbar and Target_Spellbar_AdjustPosition then
        pcall(Target_Spellbar_AdjustPosition, frame.spellbar)
    end

    lists.timed = false
    for _, b in ipairs(buffs) do
        UpdateGlow(b)
        if b.bbfInfo.own and b.bbfInfo.duration and b.bbfInfo.duration > 0 then lists.timed = true end
    end
    for _, b in ipairs(debuffs) do
        UpdateGlow(b)
        if b.bbfInfo.own and b.bbfInfo.duration and b.bbfInfo.duration > 0 then lists.timed = true end
    end
end

----------------------------------------------------------------------
-- player buff / debuff bar
----------------------------------------------------------------------
local PLAYER_DEFAULT_SIZE = 30

local function PlayerAllowed(name, spellId, duration, expires, isDebuff)
    if BBF:InList("important", name, spellId) then return true end
    if isDebuff then
        if not db.playerDebuffFilter then return true end
        return not BBF:InList("blacklist", name, spellId)
    end
    if not db.playerBuffFilter then return true end
    if BBF:InList("blacklist", name, spellId) then return false end
    if BBF:InList("whitelist", name, spellId) then return true end
    if db.playerBuffWhitelist then return false end
    if db.playerBuffUnderOneMin then
        if not duration or duration == 0 then return false end
        if expires and expires - GetTime() > 60 then return false end
    end
    return true
end

local function PlayerCooldown(b, duration, expires)
    if not db.playerAuraCooldown then
        if b.bbfCD then b.bbfCD:Hide() end
        return
    end
    local cd = b.bbfCD
    if not cd then
        cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
        cd:SetAllPoints(b)
        if cd.SetReverse then pcall(cd.SetReverse, cd, true) end
        b.bbfCD = cd
    end
    if duration and duration > 0 and expires and expires > 0 then
        if b.bbfCDExp ~= expires then
            CooldownFrame_SetTimer(cd, expires - duration, duration, 1)
            b.bbfCDExp = expires
        end
        cd:Show()
    else
        b.bbfCDExp = nil
        cd:Hide()
    end
end

local function StyleButton(b)
    local size = db.playerAuraLayout and db.playerAuraSize or PLAYER_DEFAULT_SIZE
    if b.bbfPSize ~= size then
        b:SetWidth(size)
        b:SetHeight(size)
        b.bbfPSize = size
    end
    local n = b:GetName()
    local dur = _G[n .. "Duration"]
    if dur then dur:SetAlpha(db.playerAuraHideDuration and 0 or 1) end
    local count = _G[n .. "Count"]
    if count and b.bbfCountSize ~= db.playerAuraStackSize then
        local path, _, flags = count:GetFont()
        count:SetFont(path or STANDARD_TEXT_FONT, db.playerAuraStackSize, flags or "OUTLINE")
        b.bbfCountSize = db.playerAuraStackSize
    end
end

local function PlayerAuraUpdate(buttonName, index, filter)
    if buttonName ~= "BuffButton" and buttonName ~= "DebuffButton" then return end
    local b = _G[buttonName .. index]
    if not b then return end
    b.bbfHidden = nil
    if not b:IsShown() then return end
    local unit = (PlayerFrame and PlayerFrame.unit) or "player"
    local name, _, _, _, _, duration, expires, _, _, _, spellId = UnitAura(unit, index, filter)
    if not name then return end
    local isDebuff = buttonName == "DebuffButton"
    StyleButton(b)
    PlayerCooldown(b, duration, expires)
    if not PlayerAllowed(name, spellId, duration, expires, isDebuff) then
        b:Hide()
        b.bbfHidden = true
    end
end

local function CustomPlayerLayout()
    return db.playerAuraLayout or db.playerBuffFilter or db.playerDebuffFilter
end

local function RelayoutPlayerBuffs()
    if not CustomPlayerLayout() or not BUFF_ACTUAL_DISPLAY then return end
    local anyHidden = false
    for i = 1, BUFF_ACTUAL_DISPLAY do
        local b = _G["BuffButton" .. i]
        if b and b.bbfHidden then anyHidden = true break end
    end
    if not anyHidden and not db.playerAuraLayout then return end

    local perRow = db.playerAuraLayout and db.playerAuraPerRow or (BUFFS_PER_ROW or 8)
    local gapX = db.playerAuraLayout and db.playerAuraGapX or 5
    local gapY = db.playerAuraLayout and db.playerAuraGapY or (BUFF_ROW_SPACING or 0)
    local enchants = BuffFrame.numEnchants or 0
    local slack = enchants
    if BuffFrame.numConsolidated and BuffFrame.numConsolidated > 0 then slack = slack + 1 end
    local topAnchor = ConsolidatedBuffs or TemporaryEnchantFrame

    local n, prev, above = 0, nil, nil
    for i = 1, BUFF_ACTUAL_DISPLAY do
        local b = _G["BuffButton" .. i]
        if b and not b.consolidated and not b.bbfHidden then
            n = n + 1
            local idx = n + slack
            b:ClearAllPoints()
            if idx > 1 and idx % perRow == 1 then
                if idx == perRow + 1 or not above then
                    b:SetPoint("TOP", topAnchor, "BOTTOM", 0, -gapY)
                else
                    b:SetPoint("TOP", above, "BOTTOM", 0, -gapY)
                end
                above = b
            elseif idx == 1 then
                b:SetPoint("TOPRIGHT", BuffFrame, "TOPRIGHT", 0, 0)
                above = b
            elseif n == 1 then
                if enchants > 0 then
                    b:SetPoint("TOPRIGHT", TemporaryEnchantFrame, "TOPLEFT", -gapX, 0)
                else
                    b:SetPoint("TOPRIGHT", topAnchor, "TOPLEFT", -gapX, 0)
                end
            else
                b:SetPoint("RIGHT", prev, "LEFT", -gapX, 0)
            end
            prev = b
        end
    end
    M.playerBuffRows = math.max(1, math.ceil((n + slack) / perRow))
end

local function RelayoutPlayerDebuffs()
    if not CustomPlayerLayout() or not DEBUFF_ACTUAL_DISPLAY then return end
    local anyHidden = false
    for i = 1, DEBUFF_ACTUAL_DISPLAY do
        local b = _G["DebuffButton" .. i]
        if b and b.bbfHidden then anyHidden = true break end
    end
    if not anyHidden and not db.playerAuraLayout then return end

    local perRow = db.playerAuraLayout and db.playerAuraPerRow or (BUFFS_PER_ROW or 8)
    local gapX = db.playerAuraLayout and db.playerAuraGapX or 5
    local gapY = db.playerAuraLayout and db.playerAuraGapY or (BUFF_ROW_SPACING or 0)
    local size = db.playerAuraLayout and db.playerAuraSize or PLAYER_DEFAULT_SIZE
    local rows = M.playerBuffRows or 1
    local anchor = ConsolidatedBuffs or TemporaryEnchantFrame or BuffFrame

    local n, prev, above = 0, nil, nil
    for i = 1, DEBUFF_ACTUAL_DISPLAY do
        local b = _G["DebuffButton" .. i]
        if b and not b.bbfHidden then
            n = n + 1
            b:ClearAllPoints()
            if n == 1 then
                b:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -(rows * (size + gapY)) - gapY)
                above = b
            elseif n % perRow == 1 then
                b:SetPoint("TOP", above, "BOTTOM", 0, -gapY)
                above = b
            else
                b:SetPoint("RIGHT", prev, "LEFT", -gapX, 0)
            end
            prev = b
        end
    end
end

----------------------------------------------------------------------
-- spell ID in tooltips
----------------------------------------------------------------------
local function AddSpellId(tt, unit, index, filter)
    if not db or not db.spellIdTooltip or not unit then return end
    local _, _, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, index, filter)
    if spellId then
        tt:AddLine("Spell ID: " .. spellId, 0.5, 0.8, 1)
        tt:Show()
    end
end

----------------------------------------------------------------------
function M:Refresh()
    if TargetFrame_UpdateAuras then
        for _, f in ipairs({ TargetFrame, FocusFrame }) do
            if f and type(f.unit) == "string" and UnitExists(f.unit) then TargetFrame_UpdateAuras(f) end
        end
    end
    if BuffFrame_Update then BuffFrame_Update() end
end

function M:Init()
    db = BBF.db
    if TargetFrame_UpdateAuras then
        hooksecurefunc("TargetFrame_UpdateAuras", Process)
    else
        BBF:Print("TargetFrame_UpdateAuras not found - aura features disabled.")
    end
    if AuraButton_Update then hooksecurefunc("AuraButton_Update", PlayerAuraUpdate) end
    -- BuffFrame_UpdateAllBuffAnchors runs once at the end of BuffFrame_Update (after buffs AND debuffs)
    if BuffFrame_UpdateAllBuffAnchors then
        hooksecurefunc("BuffFrame_UpdateAllBuffAnchors", function()
            RelayoutPlayerBuffs()
            RelayoutPlayerDebuffs()
        end)
    end

    -- spell IDs in aura tooltips
    if GameTooltip then
        hooksecurefunc(GameTooltip, "SetUnitBuff", function(tt, unit, index, filter) AddSpellId(tt, unit, index, filter or "HELPFUL") end)
        hooksecurefunc(GameTooltip, "SetUnitDebuff", function(tt, unit, index, filter) AddSpellId(tt, unit, index, filter or "HARMFUL") end)
        hooksecurefunc(GameTooltip, "SetUnitAura", function(tt, unit, index, filter) AddSpellId(tt, unit, index, filter) end)
    end

    -- refresh time-based (refresh) glows - only while there is something timed to watch
    local ticker = CreateFrame("Frame")
    local tGlow, tFilter = 0, 0
    ticker:SetScript("OnUpdate", BBF:Guard("Auras", function(_, elapsed)
        tGlow = tGlow + elapsed
        tFilter = tFilter + elapsed
        if tGlow >= 0.25 then
            tGlow = 0
            if db.aurasEnabled and db.expireGlow then
                for _, lists in pairs(frameLists) do
                    if lists.timed then
                        for _, b in ipairs(lists.buffs) do if b.bbfInfo and b.bbfInfo.own then UpdateGlow(b) end end
                        for _, b in ipairs(lists.debuffs) do if b.bbfInfo and b.bbfInfo.own then UpdateGlow(b) end end
                    end
                end
            end
        end
        -- "under one minute" filters need periodic re-evaluation (every 2 s)
        if tFilter >= 2 then
            tFilter = 0
            if db.underOneMinBuffs or (db.playerBuffFilter and db.playerBuffUnderOneMin) then
                M:Refresh()
            end
        end
    end))
end

function M:Apply()
    if not db.aurasEnabled then
        for _, lists in pairs(frameLists) do
            for _, b in ipairs(lists.buffs) do if b.bbfGlow then b.bbfGlow:Hide() end; b:EnableMouse(true) end
            for _, b in ipairs(lists.debuffs) do if b.bbfGlow then b.bbfGlow:Hide() end; b:EnableMouse(true) end
            wipe(lists.buffs)
            wipe(lists.debuffs)
        end
    end
    -- restore default player aura sizes when the custom layout is switched off
    for _, prefix in ipairs({ "BuffButton", "DebuffButton" }) do
        for i = 1, 40 do
            local b = _G[prefix .. i]
            if not b then break end
            StyleButton(b)
        end
    end
    self:Refresh()
end
