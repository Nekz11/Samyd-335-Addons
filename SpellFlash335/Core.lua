-- SpellFlash 335 - key press feedback for action buttons (WotLK 3.3.5a)
--
-- Every time an action button is triggered by its keybind (or a mouse click,
-- if enabled) the button flashes. Works with:
--   * Blizzard bars (ActionButtonDown / MultiActionButtonDown / pet / stance)
--   * SnowfallKeyPress (cast on key down -> flash on key down)
--   * Bartender4, Dominos, ElvUI and other bars using CLICK bindings
-- Nothing is cast or changed by this addon; it only hooks and draws.

local ADDON, ns = ...
ns.title = "SpellFlash 335"
ns.version = GetAddOnMetadata(ADDON, "Version") or "2.3"

local defaults = {
	enabled      = true,
	onlyCombat   = false,
	mouse        = true,     -- also flash on mouse clicks
	skipCooldown = false,    -- don't flash actions that are on cooldown
	pushed       = true,     -- show pressed state for keybind clicks
	effects      = {
		flash = true, ring = true, pop = false, square = false,
		shockwave = false, starburst = false, sparkles = false, shine = false,
	},
	mode         = "ALL",    -- ALL = all selected together, RANDOM, CYCLE
	color        = { r = 1, g = 1, b = 1 },
	randomColor  = false,
	duration     = 0.35,
	size         = 1.6,
	intensity    = 0.9,
	minimap      = { hide = false, angle = 200 },
}

local function CopyDefaults(src, dst)
	if type(dst) ~= "table" then dst = {} end
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = CopyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

-- settings from v2.0 - v2.2 had flash / ring / pop as single switches
local function Migrate(sv)
	if type(sv) ~= "table" or sv.effects ~= nil then return end
	if sv.flash == nil and sv.ring == nil and sv.pop == nil then return end
	sv.effects = {
		flash = sv.flash ~= false,
		ring  = sv.ring ~= false,
		pop   = sv.pop and true or false,
	}
	sv.flash, sv.ring, sv.pop = nil, nil, nil
end

function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSpellFlash|r: " .. tostring(msg))
end

------------------------------------------------------------------------
-- Button helpers
------------------------------------------------------------------------
local function ActionOf(b)
	local a
	if b._state_type then
		if b._state_type ~= "action" then return nil end
		a = b._state_action
	end
	if not a then a = b.action end
	if (not a or a == 0) and b.GetAttribute then a = b:GetAttribute("action") end
	if type(a) ~= "number" or a <= 0 then return nil end
	return a
end
ns.ActionOf = ActionOf

function ns.IconOf(b)
	local a = ActionOf(b)
	if a then
		local t = GetActionTexture(a)
		if t then return t end
	end
	local name = b:GetName()
	local icon = b.icon or (name and (_G[name .. "Icon"] or _G[name .. "IconTexture"]))
	if icon and icon.GetTexture then return icon:GetTexture() end
end

function ns.Allowed(b)
	local db = ns.db
	if not b:IsVisible() then return false end
	if ns.testing then return true end
	if not db.enabled then return false end
	if db.onlyCombat and not UnitAffectingCombat("player") then return false end
	if db.skipCooldown then
		local a = ActionOf(b)
		if a then
			if not HasAction(a) then return false end
			local st, d = GetActionCooldown(a)
			if st and st > 0 and d and d > 1.5 then return false end
		end
	end
	return true
end

------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------
local hooked = {}
local list = {}

local function OnMouseDown(self)
	self.sfMouseAt = GetTime()
	if ns.db.mouse then ns.Press(self) end
end

local function OnClick(self)
	-- a real mouse click was already handled in OnMouseDown
	if self.sfMouseAt and GetTime() - self.sfMouseAt < 2 and MouseIsOver(self) then
		self.sfMouseAt = nil
		return
	end
	self.sfMouseAt = nil
	ns.Press(self, true)
end

local function IsCandidate(f)
	if hooked[f] then return false end
	if not f.IsObjectType or not f:IsObjectType("CheckButton") then return false end
	if f.action ~= nil or f._state_action ~= nil then return true end
	if f:GetAttribute("type") == "action" or f:GetAttribute("action") then return true end
	local n = f:GetName()
	if n and (n:match("^PetActionButton%d+$") or n:match("^ShapeshiftButton%d+$")) then return true end
	return false
end

function ns.HookButtons()
	if InCombatLockdown() then return end
	local f = EnumerateFrames()
	while f do
		local ok, yes = pcall(IsCandidate, f)
		if ok and yes then
			hooked[f] = true
			list[#list + 1] = f
			f:HookScript("OnMouseDown", OnMouseDown)
			f:HookScript("OnClick", OnClick)
		end
		f = EnumerateFrames(f)
	end
	ns.lastScan = GetTime()
end

function ns.ButtonCount() return #list end

-- Blizzard bindings fire on key down through these functions (the actual
-- click happens on key up and bypasses OnClick), so hook them directly.
local function HookBlizzardBindings()
	if ActionButtonDown then
		hooksecurefunc("ActionButtonDown", function(id)
			local b
			if BonusActionBarFrame and BonusActionBarFrame:IsShown() then b = _G["BonusActionButton" .. id] end
			b = b or _G["ActionButton" .. id]
			if b then ns.Press(b) end
		end)
	end
	if MultiActionButtonDown then
		hooksecurefunc("MultiActionButtonDown", function(bar, id)
			local b = _G[bar .. "Button" .. id]
			if b then ns.Press(b) end
		end)
	end
	if PetActionButtonDown then
		hooksecurefunc("PetActionButtonDown", function(id)
			local b = _G["PetActionButton" .. id]
			if b then ns.Press(b) end
		end)
	end
	if ShapeshiftBar_ChangeForm then
		hooksecurefunc("ShapeshiftBar_ChangeForm", function(id)
			local b = _G["ShapeshiftButton" .. id]
			if b then ns.Press(b) end
		end)
	end
end

------------------------------------------------------------------------
-- Test / preview: runs over all visible buttons
------------------------------------------------------------------------
local queue = {}
function ns.Test(only)
	wipe(queue)
	local now, n = GetTime(), 0
	for _, b in ipairs(list) do
		if b:IsVisible() then
			local a = ActionOf(b)
			if not a or HasAction(a) then
				n = n + 1
				queue[#queue + 1] = { b = b, at = now + n * 0.07, only = only }
			end
		end
	end
	if n == 0 then ns.Print("no visible action buttons found - try /sf rescan") end
end

------------------------------------------------------------------------
-- Driver & events
------------------------------------------------------------------------
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function()
	local now = GetTime()
	ns.AnimateAll(now)
	if #queue > 0 then
		for i = #queue, 1, -1 do
			local q = queue[i]
			if now >= q.at then
				table.remove(queue, i)
				q.b.sfLast = nil
				ns.testing = true
				ns.Press(q.b, true, q.only)
				ns.testing = nil
			end
		end
	end
	if now - (ns.lastScan or 0) > 20 then ns.HookButtons() end
end)
driver:Hide()

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		Migrate(SpellFlash335Settings)
		SpellFlash335Settings = CopyDefaults(defaults, SpellFlash335Settings)
		ns.db = SpellFlash335Settings
	elseif event == "PLAYER_LOGIN" then
		HookBlizzardBindings()
		ns.HookButtons()
		ns.CreateInterfacePanel()
		ns.CreateMinimapButton()
		driver:Show()
		ns.Print("v" .. ns.version .. " loaded - /sf for options")
	else
		ns.HookButtons()
	end
end)

------------------------------------------------------------------------
-- Slash
------------------------------------------------------------------------
local MODES = { ALL = "RANDOM", RANDOM = "CYCLE", CYCLE = "ALL" }
local MODE_NAMES = { ALL = "all selected together", RANDOM = "random effect", CYCLE = "cycle through effects" }

SLASH_SPELLFLASH3351 = "/sf"
SLASH_SPELLFLASH3352 = "/spellflash"
SlashCmdList.SPELLFLASH335 = function(msg)
	msg = strtrim(string.lower(msg or ""))
	if msg == "" or msg == "options" or msg == "config" then
		ns.ToggleOptions()
	elseif msg == "toggle" then
		ns.db.enabled = not ns.db.enabled
		ns.Print(ns.db.enabled and "enabled" or "disabled")
	elseif msg == "minimap" then
		ns.db.minimap.hide = not ns.db.minimap.hide
		ns.Print(ns.db.minimap.hide and "minimap button hidden" or "minimap button shown")
	elseif msg == "mode" then
		ns.db.mode = MODES[ns.db.mode] or "ALL"
		ns.Print("play: " .. MODE_NAMES[ns.db.mode])
	elseif msg == "test" then
		ns.Test()
	elseif msg == "rescan" then
		ns.HookButtons()
		ns.Print(ns.ButtonCount() .. " action buttons hooked")
	else
		ns.Print("/sf - options | toggle | mode | minimap | test | rescan")
	end
	if ns.RefreshOptions then ns.RefreshOptions() end
	if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
end

-- SpellFlash 335 - flash effects
--
-- Each effect: key, label, tip, init(f) -> part, start(part, f) (return false to skip),
-- step(part, f, t)  with t = 0..1 over the configured duration.
-- f.btn = button, f.w / f.h = button size, f.c = colour, f.size / f.int = settings.

local E = {}
ns.Effects = E

local WHITE  = "Interface\\Buttons\\WHITE8X8"
local STAR   = "Interface\\Cooldown\\star4"
local BORDER = "Interface\\Buttons\\UI-ActionButton-Border"
local SQUARE = "Interface\\Buttons\\CheckButtonHilight"

local min, sin, cos, pi, random = math.min, math.sin, math.cos, math.pi, math.random

local function Add(d) E[#E + 1] = d end

local function Tex(f, path, blend)
	local t = f:CreateTexture(nil, "OVERLAY")
	if path then t:SetTexture(path) end
	t:SetBlendMode(blend or "ADD")
	t:Hide()
	return t
end

local function Center(t, f, x, y)
	t:ClearAllPoints()
	t:SetPoint("CENTER", f.btn, "CENTER", x or 0, y or 0)
end

local function Color(t, c) t:SetVertexColor(c.r, c.g, c.b) end

local function Ease(t)
	local fade = 1 - t
	return fade, 1 - fade * fade     -- fade out, ease-out growth
end

------------------------------------------------------------------------
Add({ key = "flash", label = "Flash", tip = "Bright fill over the button that fades out.",
	init = function(f) local t = Tex(f, WHITE) t:SetAllPoints(f.btn) return t end,
	start = function(p, f) Color(p, f.c) p:Show() end,
	step = function(p, f, t)
		local fade = 1 - t
		p:SetAlpha(min(1, 0.85 * f.int * fade * fade))
	end,
})

Add({ key = "ring", label = "Glow ring", tip = "Glowing border that expands outwards.",
	init = function(f) local t = Tex(f, BORDER) Center(t, f) return t end,
	start = function(p, f) Color(p, f.c) p:Show() end,
	step = function(p, f, t)
		local fade, grow = Ease(t)
		local s = 1 + (f.size - 1) * grow
		p:SetWidth(f.w * 1.75 * s) p:SetHeight(f.h * 1.75 * s)
		p:SetAlpha(min(1, f.int * fade))
	end,
})

Add({ key = "pop", label = "Icon pop", tip = "A copy of the spell icon grows and fades.",
	init = function(f)
		local t = Tex(f, nil, "BLEND")
		t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		Center(t, f)
		return t
	end,
	start = function(p, f)
		local tex = ns.IconOf(f.btn)
		if not tex then return false end
		p:SetTexture(tex)
		p:Show()
	end,
	step = function(p, f, t)
		local fade, grow = Ease(t)
		local s = 1 + (f.size - 1) * grow
		p:SetWidth(f.w * s) p:SetHeight(f.h * s)
		p:SetAlpha(min(1, 0.9 * f.int * fade))
	end,
})

Add({ key = "square", label = "Square glow", tip = "Short, sharp highlight on the button edge.",
	init = function(f) local t = Tex(f, SQUARE) Center(t, f) return t end,
	start = function(p, f) Color(p, f.c) p:SetWidth(f.w * 1.12) p:SetHeight(f.h * 1.12) p:Show() end,
	step = function(p, f, t)
		local a = t < 0.15 and t / 0.15 or (1 - t) / 0.85
		p:SetAlpha(min(1, f.int * a))
	end,
})

Add({ key = "shockwave", label = "Shockwave", tip = "Two rings, one after the other.",
	init = function(f)
		local a, b = Tex(f, BORDER), Tex(f, BORDER)
		Center(a, f) Center(b, f)
		return { a, b }
	end,
	start = function(p, f) Color(p[1], f.c) Color(p[2], f.c) end,
	step = function(p, f, t)
		for k = 1, 2 do
			local r, delay = p[k], (k - 1) * 0.3
			local tt = (t - delay) / (1 - delay)
			if tt < 0 then
				r:Hide()
			else
				local fade, grow = Ease(tt)
				local s = 1 + (f.size * 1.25 - 1) * grow
				r:SetWidth(f.w * 1.75 * s) r:SetHeight(f.h * 1.75 * s)
				r:SetAlpha(min(1, 0.9 * f.int * fade))
				r:Show()
			end
		end
	end,
})

Add({ key = "starburst", label = "Starburst", tip = "Spinning star that bursts out of the button.",
	init = function(f) local t = Tex(f, STAR) Center(t, f) return t end,
	start = function(p, f) Color(p, f.c) p:Show() end,
	step = function(p, f, t)
		local fade, grow = Ease(t)
		local s = 0.6 + f.size * grow
		p:SetWidth(f.w * s) p:SetHeight(f.h * s)
		if p.SetRotation then p:SetRotation(t * 2) end
		p:SetAlpha(min(1, f.int * fade))
	end,
})

local SPARKS = 8
Add({ key = "sparkles", label = "Sparkles", tip = "Little stars fly out in all directions.",
	init = function(f)
		local p = { dir = {} }
		for k = 1, SPARKS do p[k] = Tex(f, STAR) end
		return p
	end,
	start = function(p, f)
		for k = 1, SPARKS do
			local a = (k - 1 + random() * 0.7) * 2 * pi / SPARKS
			local v = 0.7 + random() * 0.6
			p.dir[k] = { cos(a) * v, sin(a) * v }
			Color(p[k], f.c)
			p[k]:Show()
		end
	end,
	step = function(p, f, t)
		local fade, grow = Ease(t)
		local dist = f.w * 0.6 * f.size * grow
		local sz = f.w * 0.45 * (1 - 0.5 * t)
		for k = 1, SPARKS do
			local s, d = p[k], p.dir[k]
			Center(s, f, d[1] * dist, d[2] * dist)
			s:SetWidth(sz) s:SetHeight(sz)
			s:SetAlpha(min(1, f.int * fade))
		end
	end,
})

-- light bar sweeping left to right, kept inside the button
local function Segment(tex, f, x1, x2, cx, half, peak)
	if x1 < 0 then x1 = 0 end
	if x2 > f.w then x2 = f.w end
	if x2 - x1 < 0.5 then tex:Hide() return end
	local function A(x) return peak * math.max(0, 1 - math.abs(x - cx) / half) end
	local c = f.c
	tex:ClearAllPoints()
	tex:SetPoint("TOPLEFT", f.btn, "TOPLEFT", x1, 0)
	tex:SetWidth(x2 - x1)
	tex:SetHeight(f.h)
	tex:SetGradientAlpha("HORIZONTAL", c.r, c.g, c.b, A(x1), c.r, c.g, c.b, A(x2))
	tex:Show()
end

Add({ key = "shine", label = "Shine sweep", tip = "A light bar sweeps across the icon.",
	init = function(f) return { Tex(f, WHITE), Tex(f, WHITE) } end,
	start = function() end,
	step = function(p, f, t)
		local half = f.w * 0.22
		local cx = -half + (f.w + 2 * half) * t
		local peak = min(1, 0.8 * f.int)
		Segment(p[1], f, cx - half, cx, cx, half, peak)
		Segment(p[2], f, cx, cx + half, cx, half, peak)
	end,
})

------------------------------------------------------------------------
-- Playback
------------------------------------------------------------------------
local fx, active = {}, {}
local lastRandom, cycle = nil, 0

local function HidePart(p)
	if p.Hide then p:Hide() return end
	for i = 1, #p do p[i]:Hide() end
end

local function StopParts(f)
	if not f.playing then return end
	for _, d in ipairs(f.playing) do HidePart(f.parts[d.key]) end
	wipe(f.playing)
end

-- intensity above 1 stacks extra additive layers of the same effects
local MAX_LAYERS = 3

local function Fx(b, k)
	local layers = fx[b]
	if not layers then layers = {} fx[b] = layers end
	local f = layers[k]
	if f then return f end
	f = CreateFrame("Frame", nil, b)
	f:SetAllPoints(b)
	f.btn, f.parts, f.playing = b, {}, {}
	f:Hide()
	layers[k] = f
	return f
end

function ns.EffectByKey(key)
	for _, d in ipairs(E) do if d.key == key then return d end end
end

local pick = {}
local function Pick()
	local db = ns.db
	wipe(pick)
	for _, d in ipairs(E) do
		if db.effects[d.key] then pick[#pick + 1] = d end
	end
	local n = #pick
	if n <= 1 or db.mode == "ALL" then return pick end
	local i
	if db.mode == "CYCLE" then
		cycle = cycle % n + 1
		i = cycle
	else
		repeat i = random(n) until pick[i] ~= lastRandom
		lastRandom = pick[i]
	end
	local one = pick[i]
	wipe(pick)
	pick[1] = one
	return pick
end

local function HSV(h)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local q, t = 1 - f, f
	i = i % 6
	if i == 0 then return 1, t, 0 elseif i == 1 then return q, 1, 0
	elseif i == 2 then return 0, 1, t elseif i == 3 then return 0, q, 1
	elseif i == 4 then return t, 0, 1 else return 1, 0, q end
end

local rc = { r = 1, g = 1, b = 1 }

-- push = simulate the pressed look; only = play just this effect (preview)
function ns.Press(b, push, only)
	local now = GetTime()
	if b.sfLast and now - b.sfLast < 0.05 then return end
	if not ns.Allowed(b) then return end
	b.sfLast = now

	local db = ns.db
	local c = db.color
	if db.randomColor then
		rc.r, rc.g, rc.b = HSV(random())
		c = rc
	end
	local list = only and { ns.EffectByKey(only) } or Pick()
	local int = db.intensity
	local n = math.min(MAX_LAYERS, math.max(1, math.ceil(int - 0.001)))
	local w, h = b:GetWidth(), b:GetHeight()

	for k = 1, MAX_LAYERS do
		local f = (k <= n or (fx[b] and fx[b][k])) and Fx(b, k)
		if f then
			StopParts(f)
			if k > n then
				f:Hide()
				active[f] = nil
			else
				f.w, f.h, f.c = w, h, c
				f.size, f.int = db.size, math.min(1, int - (k - 1))
				f:SetFrameLevel(b:GetFrameLevel() + 7 + k)
				for _, d in ipairs(list) do
					local p = f.parts[d.key]
					if not p then p = d.init(f) f.parts[d.key] = p end
					if d.start(p, f) ~= false then f.playing[#f.playing + 1] = d end
				end
				if k == 1 and push and db.pushed and b:GetButtonState() ~= "PUSHED" then
					b:SetButtonState("PUSHED")
					f.pushUntil = now + 0.12
				end
				if #f.playing > 0 or f.pushUntil then
					f.start = now
					f:Show()
					active[f] = true
					ns.AnimateOne(f, now)
				end
			end
		end
	end
end

function ns.AnimateOne(f, now)
	local t = (now - f.start) / ns.db.duration
	if f.pushUntil and now >= f.pushUntil then
		f.pushUntil = nil
		if f.btn:GetButtonState() == "PUSHED" then f.btn:SetButtonState("NORMAL") end
	end
	if t >= 1 then
		StopParts(f)
		if not f.pushUntil then
			f:Hide()
			active[f] = nil
		end
		return
	end
	for _, d in ipairs(f.playing) do d.step(f.parts[d.key], f, t) end
end

function ns.AnimateAll(now)
	for f in pairs(active) do ns.AnimateOne(f, now) end
end
