-- WArena: minimap button + key bindings (target/focus arena1-5, options, test mode)
local _, ns = ...
local MM = ns:NewModule("Minimap")
ns.MinimapButton = MM

local cos, sin, rad, atan2, deg = math.cos, math.sin, math.rad, math.atan2, math.deg

---------------------------------------------------------------------------
-- minimap button
---------------------------------------------------------------------------
local button = CreateFrame("Button", "WArenaMinimapButton", Minimap)
button:SetWidth(32)
button:SetHeight(32)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local overlay = button:CreateTexture(nil, "OVERLAY")
overlay:SetWidth(53)
overlay:SetHeight(53)
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetPoint("TOPLEFT")

local icon = button:CreateTexture(nil, "BACKGROUND")
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetTexture("Interface\\Icons\\Achievement_Arena_2v2_7")
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
icon:SetPoint("TOPLEFT", 7, -6)

local function UpdatePosition()
	local angle = rad(ns.global and ns.global.minimap.angle or 220)
	local x, y = cos(angle) * 80, sin(angle) * 80
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function OnDragUpdate()
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	px, py = px / scale, py / scale
	ns.global.minimap.angle = deg(atan2(py - my, px - mx))
	UpdatePosition()
end

button:SetScript("OnDragStart", function(self)
	self:LockHighlight()
	self:SetScript("OnUpdate", OnDragUpdate)
end)
button:SetScript("OnDragStop", function(self)
	self:SetScript("OnUpdate", nil)
	self:UnlockHighlight()
end)
button:SetScript("OnClick", function(_, mouse)
	if mouse == "RightButton" then
		ns.ToggleTest()
	elseif IsShiftKeyDown() then
		ns.SetLocked(not ns.IsLocked())
	else
		if ns.OpenOptions then ns:OpenOptions() end
	end
end)
button:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText("WArena " .. ns.version, 0.2, 1, 0.6)
	GameTooltip:AddLine("Left click: options", 1, 1, 1)
	GameTooltip:AddLine("Right click: test frames", 1, 1, 1)
	GameTooltip:AddLine("Shift + left click: lock / unlock", 1, 1, 1)
	GameTooltip:AddLine("Drag: move this button", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end)
button:SetScript("OnLeave", function() GameTooltip:Hide() end)

function MM:Refresh()
	if ns.global.minimap.hide then button:Hide() else button:Show() end
	UpdatePosition()
end

function MM:OnInit()
	self:Refresh()
end

function MM:SetHidden(hidden)
	ns.global.minimap.hide = hidden and true or false
	self:Refresh()
end

ns:AddCommand("minimap", "show / hide the minimap button", function()
	MM:SetHidden(not ns.global.minimap.hide)
end)

---------------------------------------------------------------------------
-- key bindings
-- hidden secure buttons; bind them via Esc > Key Bindings > WArena
---------------------------------------------------------------------------
BINDING_HEADER_WARENA = "WArena"
for i = 1, ns.MAX_ARENA do
	local t = CreateFrame("Button", "WArenaBindTarget" .. i, UIParent, "SecureActionButtonTemplate")
	t:SetAttribute("type", "target")
	t:SetAttribute("unit", "arena" .. i)
	_G["BINDING_NAME_CLICK WArenaBindTarget" .. i .. ":LeftButton"] = "Target arena " .. i
	local f = CreateFrame("Button", "WArenaBindFocus" .. i, UIParent, "SecureActionButtonTemplate")
	f:SetAttribute("type", "focus")
	f:SetAttribute("unit", "arena" .. i)
	_G["BINDING_NAME_CLICK WArenaBindFocus" .. i .. ":LeftButton"] = "Focus arena " .. i
end
-- healer bindings follow the sorted healer slot (set when sorting changes, out of combat)
local healerTarget = CreateFrame("Button", "WArenaBindTargetHealer", UIParent, "SecureActionButtonTemplate")
healerTarget:SetAttribute("type", "target")
local healerFocus = CreateFrame("Button", "WArenaBindFocusHealer", UIParent, "SecureActionButtonTemplate")
healerFocus:SetAttribute("type", "focus")
_G["BINDING_NAME_CLICK WArenaBindTargetHealer:LeftButton"] = "Target enemy healer"
_G["BINDING_NAME_CLICK WArenaBindFocusHealer:LeftButton"] = "Focus enemy healer"
BINDING_NAME_WARENA_OPTIONS = "Toggle options window"
BINDING_NAME_WARENA_TEST = "Toggle test frames"
BINDING_NAME_WARENA_LOCK = "Lock / unlock frames"

local function UpdateHealerBinding()
	ns:Defer(function()
		local unit
		ns.Frames:Each(function(f) if f.isHealer and not unit then unit = f.unit end end)
		healerTarget:SetAttribute("unit", unit)
		healerFocus:SetAttribute("unit", unit)
	end)
end
ns:RegisterMessage("ENEMY_HEALER", UpdateHealerBinding)
ns:RegisterMessage("LAYOUT", UpdateHealerBinding)
ns:RegisterMessage("ARENA_LEAVE", UpdateHealerBinding)

function WArena_ToggleOptions() if ns.OpenOptions then ns:OpenOptions() end end
function WArena_ToggleTest() ns.ToggleTest() end
function WArena_ToggleLock() ns.SetLocked(not ns.IsLocked()) end
