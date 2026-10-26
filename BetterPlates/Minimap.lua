-- BetterPlates - Minimap-Button
-- Links: Einstellungen, Rechts: verbündete Plaketten umschalten,
-- Mitte: Stapeln umschalten. Ziehen mit gedrückter Maustaste bewegt ihn.

local ADDON, ns = ...
if type(ns) ~= "table" then BetterPlatesNS = BetterPlatesNS or {} ns = BetterPlatesNS ADDON = "BetterPlates" end
local L = ns.L or setmetatable({}, { __index = function(t, k) return k end })
local cos, sin, atan2, rad, deg, sqrt = math.cos, math.sin, math.atan2, math.rad, math.deg, math.sqrt

local M = {}
ns.Minimap = M

local function Settings()
	local root = BetterPlatesDB
	if type(root) ~= "table" then return { angle = 220 } end
	root.minimap = root.minimap or { angle = 220, hide = false }
	return root.minimap
end

local function Position(btn)
	local s = Settings()
	local angle = rad(s.angle or 220)
	local x, y = cos(angle) * 80, sin(angle) * 80
	btn:ClearAllPoints()
	btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function OnDrag(btn)
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	cx, cy = cx / scale, cy / scale
	local s = Settings()
	s.angle = deg(atan2(cy - my, cx - mx))
	Position(btn)
end

function M:Create()
	if self.button or not Minimap then return end
	local btn = CreateFrame("Button", "BetterPlatesMinimapButton", Minimap)
	btn:SetWidth(32)
	btn:SetHeight(32)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel(8)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
	btn:RegisterForDrag("LeftButton")
	btn:SetMovable(true)

	local overlay = btn:CreateTexture(nil, "OVERLAY")
	overlay:SetWidth(53)
	overlay:SetHeight(53)
	overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	overlay:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)

	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetWidth(20)
	bg:SetHeight(20)
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetPoint("TOPLEFT", btn, "TOPLEFT", 7, -5)

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetWidth(18)
	icon:SetHeight(18)
	icon:SetTexture("Interface\\Icons\\Ability_Hunter_SniperShot")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 7, -6)
	btn.icon = icon

	btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	btn:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			BetterPlates_ToggleFriends()
			local ok, v = pcall(GetCVar, "nameplateShowFriends")
			ns:Print(L["Friendly nameplates"] .. ": " .. ((ok and v == "1") and L["On"] or L["Off"]))
		elseif button == "MiddleButton" then
			BetterPlates_ToggleStacking()
		else
			if ns.ToggleOptions then ns:ToggleOptions() end
		end
	end)
	btn:SetScript("OnDragStart", function(self)
		self.dragging = true
		self:SetScript("OnUpdate", function(b) OnDrag(b) end)
	end)
	btn:SetScript("OnDragStop", function(self)
		self.dragging = nil
		self:SetScript("OnUpdate", nil)
	end)
	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("|cff33ccffBetter|rPlates " .. (ns.VERSION or ""))
		GameTooltip:AddLine(L["Left-click: settings"], 1, 1, 1)
		GameTooltip:AddLine(L["Right-click: toggle friendly nameplates"], 1, 1, 1)
		GameTooltip:AddLine(L["Middle-click: toggle stacking"], 1, 1, 1)
		GameTooltip:AddLine(L["Drag to move"], 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	Position(btn)
	self.button = btn
	self:Update()
end

function M:Update()
	if not self.button then return end
	local show = ns.db and ns.db.minimapButton
	if show then self.button:Show() else self.button:Hide() end
end
