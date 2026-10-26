-- WArena: arena HUD – preparation countdown, match timer, Shadow Sight timer
local _, ns = ...
local L = ns.L
local HUD = ns:NewModule("HUD")
ns.HUD = HUD

local format, floor = string.format, math.floor
local GetTime = GetTime
local SHADOW_SIGHT_DELAY = 90

ns:AddDefaults({
	hud = true, hudScale = 1, hudPoint = { "TOP", "UIParent", "TOP", 0, -120 }, hudFontSize = 18,
	hudPrep = true, hudMatch = true, hudShadowSight = true, hudWarnSS = 10, hudAlpha = 0.9,
	hudColor = { r = 1, g = 1, b = 1, a = 1 }, hudBackground = true,
})

local hud = CreateFrame("Frame", "WArenaHUD", UIParent)
hud:SetWidth(220)
hud:SetHeight(54)
hud:SetFrameStrata("MEDIUM")
hud:SetBackdrop({ bgFile = ns.WHITE, edgeFile = ns.WHITE, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
hud:SetBackdropColor(0, 0, 0, 0.5)
hud:SetBackdropBorderColor(0, 0, 0, 0.9)
hud.line1 = hud:CreateFontString(nil, "OVERLAY")
hud.line1:SetFont(ns.FONTS[1][2], 18, "OUTLINE")
hud.line1:SetPoint("TOP", hud, "TOP", 0, -6)
hud.line1:SetText("")
hud.line2 = hud:CreateFontString(nil, "OVERLAY")
hud.line2:SetFont(ns.FONTS[1][2], 13, "OUTLINE")
hud.line2:SetPoint("TOP", hud.line1, "BOTTOM", 0, -4)
hud.line2:SetText("")
hud:Hide()

local state = { prepEnd = nil, gatesAt = nil, ssAnnounced = {}, demoUntil = nil }
HUD.state = state

local function Active()
	return ns.state.inArena or state.demoUntil
end

local function Render(now)
	local db = ns.db
	if not db.hud or not Active() then hud:Hide() return end
	local l1, l2 = "", ""
	local r, g, b = ns:Color("hudColor")
	if state.prepEnd and now < state.prepEnd and db.hudPrep then
		local left = state.prepEnd - now
		l1 = format("%s %s", L["Preparation"], ns:FormatClock(left))
		if left <= 5 then r, g, b = 1, 0.3, 0.3 elseif left <= 15 then r, g, b = 1, 0.8, 0.2 end
	elseif state.gatesAt then
		if db.hudMatch then l1 = format("%s %s", L["Match"], ns:FormatClock(now - state.gatesAt)) end
		if db.hudShadowSight then
			local ssLeft = state.gatesAt + SHADOW_SIGHT_DELAY - now
			if ssLeft > 0 then
				l2 = format("%s %s", L["Shadow Sight"], ns:FormatClock(ssLeft))
			elseif ssLeft > -30 then
				l2 = L["ANN_SHADOWSIGHT_UP"]
			end
		end
	end
	if l1 == "" and l2 == "" then hud:Hide() return end
	hud.line1:SetText(l1)
	hud.line1:SetTextColor(r, g, b)
	hud.line2:SetText(l2)
	hud.line2:SetTextColor(0.8, 0.6, 1)
	hud:Show()
end

local function CheckShadowSight(now)
	local db = ns.db
	if not state.gatesAt or not db.hudShadowSight then return end
	local ssLeft = state.gatesAt + SHADOW_SIGHT_DELAY - now
	local warn = db.hudWarnSS or 10
	if warn > 0 and ssLeft <= warn and ssLeft > warn - 1 and not state.ssAnnounced.warn then
		state.ssAnnounced.warn = true
		ns.Announce:Send("shadowsight", format(L["ANN_SHADOWSIGHT"], warn), "ss", 0.8, 0.6, 1)
	end
	if ssLeft <= 0 and not state.ssAnnounced.up then
		state.ssAnnounced.up = true
		ns.Announce:Send("shadowsight", L["ANN_SHADOWSIGHT_UP"], "ssup", 0.8, 0.6, 1)
	end
end

ns:AddTicker(0.2, function(now)
	if not ns.db then return end
	if state.demoUntil and now > state.demoUntil then
		state.demoUntil, state.prepEnd, state.gatesAt = nil, nil, nil
		state.ssAnnounced = {}
	end
	if Active() then
		CheckShadowSight(now)
		Render(now)
	elseif hud:IsShown() then
		hud:Hide()
	end
end)

---------------------------------------------------------------------------
-- arena system messages
---------------------------------------------------------------------------
local function ParseCountdown(msg)
	local lower = msg:lower()
	if lower:find("begun") or lower:find("has started") then return 0 end
	if lower:find("one minute") or lower:find("1 minute") then return 60 end
	if lower:find("thirty") or lower:find("30 sec") then return 30 end
	if lower:find("fifteen") or lower:find("15 sec") then return 15 end
	local n = lower:match("(%d+) sec")
	if n then return tonumber(n) end
	return nil
end

function HUD:SetCountdown(seconds)
	local now = GetTime()
	if seconds == 0 then
		state.prepEnd = nil
		if not state.gatesAt then
			state.gatesAt = now
			state.ssAnnounced = {}
			ns:Fire("ARENA_GATES")
			ns.Announce:Send("gates", L["ANN_GATES"], "gates", 0.4, 1, 0.4)
		end
	else
		state.prepEnd = now + seconds
	end
	Render(now)
end

ns:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL", function(_, msg)
	if not ns.state.inArena or not msg then return end
	local sec = ParseCountdown(msg)
	if sec then HUD:SetCountdown(sec) end
end)

ns:RegisterMessage("ARENA_ENTER", function()
	state.prepEnd, state.gatesAt, state.demoUntil = nil, nil, nil
	state.ssAnnounced = {}
	Render(GetTime())
end)
ns:RegisterMessage("ARENA_LEAVE", function()
	state.prepEnd, state.gatesAt = nil, nil
	hud:Hide()
end)

function HUD:MatchTime()
	if state.gatesAt then return GetTime() - state.gatesAt end
end

---------------------------------------------------------------------------
-- layout / demo
---------------------------------------------------------------------------
function HUD:OnLayout()
	local db = ns.db
	hud:SetScale(db.hudScale)
	hud:SetAlpha(db.hudAlpha)
	ns:SetPointFromTable(hud, db.hudPoint)
	ns:SetFont(hud.line1, db.hudFontSize, "OUTLINE")
	ns:SetFont(hud.line2, math.max(8, db.hudFontSize - 5), "OUTLINE")
	hud:SetHeight(db.hudFontSize * 2.6 + 8)
	if db.hudBackground then
		hud:SetBackdropColor(0, 0, 0, 0.5)
		hud:SetBackdropBorderColor(0, 0, 0, 0.9)
	else
		hud:SetBackdropColor(0, 0, 0, 0)
		hud:SetBackdropBorderColor(0, 0, 0, 0)
	end
end

function HUD:OnInit()
	ns:MakeMovable(hud, "WArena HUD", function(p) ns.db.hudPoint = p end)
	ns:RegisterMessage("LOCK_CHANGED", function(_, locked)
		ns:Show(hud.mover, not locked)
		if not locked then HUD:Demo(600) elseif not ns.state.inArena then state.demoUntil = GetTime() end
	end)
	ns:RegisterMessage("TEST_MODE", function(_, on)
		if on then HUD:Demo(600) elseif not ns.state.inArena then state.demoUntil = GetTime() end
	end)
	if not ns.db.locked then hud.mover:Show() end
end

function HUD:Demo(duration)
	local now = GetTime()
	state.demoUntil = now + (duration or 20)
	state.prepEnd = now + 8
	state.gatesAt = nil
	state.ssAnnounced = {}
	ns:After(8.1, function()
		if state.demoUntil then state.gatesAt = GetTime() - 10 end
	end)
	Render(now)
end

ns:AddCommand("hud", "preview the arena HUD for 20 seconds", function() HUD:Demo(20) end)
