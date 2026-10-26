-- RetailPartyFrames - cast bars inside the unit frames

local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local GetTime = GetTime

local COLOR_CAST = { 1.0, 0.7, 0.0 }
local COLOR_CHANNEL = { 0.0, 0.75, 0.25 }
local COLOR_LOCKED = { 0.6, 0.6, 0.6 }
local COLOR_INTERRUPTED = { 0.9, 0.15, 0.15 }
local FADE_TIME = 0.6

local function SetBarColor(cb, c)
    cb.bar:SetStatusBarColor(c[1], c[2], c[3])
end

local function OnUpdate(self, elapsed)
    if self.fading then
        self.fadeLeft = self.fadeLeft - elapsed
        if self.fadeLeft <= 0 then
            self.fading = nil
            self:Hide()
            self:SetAlpha(1)
        else
            self:SetAlpha(self.fadeLeft / FADE_TIME)
        end
        return
    end
    local now = GetTime()
    if now >= self.endTime then
        if self.test then
            ns:StartTestCast(self.owner)
        else
            self:Hide()
        end
        return
    end
    if self.channel then
        self.bar:SetValue(self.endTime - now)
    else
        self.bar:SetValue(now - self.startTime)
    end
    if self.showTimer then
        self.time:SetFormattedText("%.1f", self.endTime - now)
    end
end

function ns:CreateCastbar(b)
    local cb = CreateFrame("Frame", nil, b)
    cb:SetFrameLevel(b:GetFrameLevel() + 2)
    cb.owner = b

    cb.bg = cb:CreateTexture(nil, "BACKGROUND")
    cb.bg:SetAllPoints(cb)
    cb.bg:SetTexture(WHITE)
    cb.bg:SetVertexColor(0, 0, 0, 0.7)

    cb.icon = cb:CreateTexture(nil, "ARTWORK")
    cb.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    cb.bar = CreateFrame("StatusBar", nil, cb)
    cb.bar:SetFrameLevel(cb:GetFrameLevel() + 1)
    cb.bar.bg = cb.bar:CreateTexture(nil, "BACKGROUND")
    cb.bar.bg:SetAllPoints(cb.bar)
    cb.bar.bg:SetTexture(WHITE)
    cb.bar.bg:SetVertexColor(0.15, 0.15, 0.15, 0.8)

    cb.text = cb.bar:CreateFontString(nil, "OVERLAY")
    cb.text:SetJustifyH("LEFT")
    cb.time = cb.bar:CreateFontString(nil, "OVERLAY")
    cb.time:SetJustifyH("RIGHT")

    cb:SetScript("OnUpdate", OnUpdate)
    cb:Hide()
    b.castbar = cb
    return cb
end

function ns:LayoutCastbar(b)
    local db = self.db
    local cb = b.castbar
    local h = db.castbarHeight
    cb.bar:SetStatusBarTexture(self:Fetch("statusbar", db.texture))
    cb.icon:ClearAllPoints()
    cb.bar:ClearAllPoints()
    if db.castbarIcon then
        cb.icon:SetPoint("TOPLEFT", cb, "TOPLEFT", 0, 0)
        cb.icon:SetWidth(h)
        cb.icon:SetHeight(h)
        cb.icon:Show()
        cb.bar:SetPoint("TOPLEFT", cb.icon, "TOPRIGHT", 1, 0)
    else
        cb.icon:Hide()
        cb.bar:SetPoint("TOPLEFT", cb, "TOPLEFT", 0, 0)
    end
    cb.bar:SetPoint("BOTTOMRIGHT", cb, "BOTTOMRIGHT", 0, 0)

    local fs = math.max(7, math.min(h, self:Cfg(b, "fontSize")) - 1)
    ns.StyleFont(cb.text, fs, true)
    ns.StyleFont(cb.time, fs, true)
    cb.time:ClearAllPoints()
    cb.time:SetPoint("RIGHT", cb.bar, "RIGHT", -2, 0)
    cb.text:ClearAllPoints()
    cb.text:SetPoint("LEFT", cb.bar, "LEFT", 2, 0)
    cb.text:SetPoint("RIGHT", db.castbarTimer and cb.time or cb.bar, db.castbarTimer and "LEFT" or "RIGHT", -2, 0)
    cb.text:SetHeight(fs + 2)
    if db.castbarText and h >= 7 then cb.text:Show() else cb.text:Hide() end
    cb.showTimer = db.castbarTimer and h >= 7
    if cb.showTimer then cb.time:Show() else cb.time:Hide() end
    if not self:Cfg(b, "castbar") then cb:Hide() end
end

local function Begin(cb, name, texture, startTime, endTime, channel, notInterruptible)
    cb.fading = nil
    cb:SetAlpha(1)
    cb.startTime = startTime
    cb.endTime = endTime
    cb.channel = channel
    cb.notInterruptible = notInterruptible
    cb.bar:SetMinMaxValues(0, math.max(endTime - startTime, 0.01))
    cb.icon:SetTexture(texture)
    cb.text:SetText(name or "")
    cb.time:SetText("")
    if notInterruptible then
        SetBarColor(cb, COLOR_LOCKED)
    else
        SetBarColor(cb, channel and COLOR_CHANNEL or COLOR_CAST)
    end
    cb:Show()
end

function ns:CastStart(b, channel)
    if not self:Cfg(b, "castbar") or b.testData or not b.unit then return end
    local cb = b.castbar
    local unit = b.unit
    local name, texture, startTime, endTime, castID, notInterruptible, _
    if channel then
        name, _, _, texture, startTime, endTime, _, notInterruptible = UnitChannelInfo(unit)
    else
        name, _, _, texture, startTime, endTime, _, castID, notInterruptible = UnitCastingInfo(unit)
    end
    if not name then
        if not cb.fading then cb:Hide() end
        return
    end
    cb.castID = castID
    Begin(cb, name, texture, startTime / 1000, endTime / 1000, channel, notInterruptible)
end

function ns:CastStop(b, channel)
    local cb = b.castbar
    if cb.fading or not cb:IsShown() then return end
    if (channel and cb.channel) or (not channel and not cb.channel) then cb:Hide() end
end

function ns:CastInterrupted(b, castID)
    local cb = b.castbar
    if not self:Cfg(b, "castbar") then return end
    if castID and cb.castID and castID ~= cb.castID then return end
    if not cb:IsShown() and not (castID and castID == cb.castID) then return end
    cb.castID = nil
    SetBarColor(cb, COLOR_INTERRUPTED)
    local mn, mx = cb.bar:GetMinMaxValues()
    cb.bar:SetValue(mx or 1)
    cb.text:SetText(INTERRUPTED or "Interrupted")
    cb.time:SetText("")
    cb.fading = true
    cb.fadeLeft = FADE_TIME
    cb:Show()
end

function ns:CastInterruptible(b, interruptible)
    local cb = b.castbar
    if not cb:IsShown() or cb.fading then return end
    cb.notInterruptible = not interruptible
    if cb.notInterruptible then
        SetBarColor(cb, COLOR_LOCKED)
    else
        SetBarColor(cb, cb.channel and COLOR_CHANNEL or COLOR_CAST)
    end
end

function ns:UpdateCastbar(b)
    local cb = b.castbar
    cb.test = nil
    if not self:Cfg(b, "castbar") then
        cb:Hide()
        return
    end
    if b.testData then
        if b.testData.cast then
            self:StartTestCast(b)
        else
            cb:Hide()
        end
        return
    end
    if not b.unit then cb:Hide() return end
    if UnitCastingInfo(b.unit) then
        self:CastStart(b, false)
    elseif UnitChannelInfo(b.unit) then
        self:CastStart(b, true)
    elseif not cb.fading then
        cb:Hide()
    end
end

function ns:StartTestCast(b)
    local c = b.testData and b.testData.cast
    local cb = b.castbar
    if not c or not self:Cfg(b, "castbar") then cb:Hide() return end
    local now = GetTime()
    Begin(cb, c.name, c.icon, now, now + c.time, c.channel, false)
    cb.test = true
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local function castStart(_, unit) ns.ForUnit(unit, function(self, b) self:CastStart(b, false) end) end
local function channelStart(_, unit) ns.ForUnit(unit, function(self, b) self:CastStart(b, true) end) end

ns:On("UNIT_SPELLCAST_START", castStart)
ns:On("UNIT_SPELLCAST_DELAYED", castStart)
ns:On("UNIT_SPELLCAST_CHANNEL_START", channelStart)
ns:On("UNIT_SPELLCAST_CHANNEL_UPDATE", channelStart)

ns:On("UNIT_SPELLCAST_STOP", function(_, unit)
    ns.ForUnit(unit, function(self, b) self:CastStop(b, false) end)
end)
ns:On("UNIT_SPELLCAST_CHANNEL_STOP", function(_, unit)
    ns.ForUnit(unit, function(self, b) self:CastStop(b, true) end)
end)
ns:On("UNIT_SPELLCAST_FAILED", function(_, unit, _, _, castID)
    ns.ForUnit(unit, function(self, b)
        local cb = b.castbar
        if cb:IsShown() and not cb.channel and not cb.fading and castID and castID == cb.castID then cb:Hide() end
    end)
end)
ns:On("UNIT_SPELLCAST_INTERRUPTED", function(_, unit, _, _, castID)
    ns.ForUnit(unit, function(self, b) self:CastInterrupted(b, castID) end)
end)
ns:On("UNIT_SPELLCAST_INTERRUPTIBLE", function(_, unit)
    ns.ForUnit(unit, function(self, b) self:CastInterruptible(b, true) end)
end)
ns:On("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", function(_, unit)
    ns.ForUnit(unit, function(self, b) self:CastInterruptible(b, false) end)
end)
