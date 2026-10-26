-- WArena: arena numbers (and spec) on enemy nameplates
local _, ns = ...
local NP = ns:NewModule("Nameplates")
ns.Nameplates = NP

local select, pairs = select, pairs
local WorldFrame = WorldFrame

ns:AddDefaults({ plates = true, plateSize = 16, plateSpec = true, plateOffsetY = 4, plateClassColor = true })

local plates = {}      -- plate frame -> info
local numChildren = -1
local labelFont = ns.FONTS[1][2]

local function IsNameplate(frame)
	if frame._waPlateChecked then return frame._waPlate end
	frame._waPlateChecked = true
	if frame:GetName() then return false end
	local region = select(2, frame:GetRegions())
	if region and region.GetTexture then
		local tex = region:GetTexture()
		if type(tex) == "string" and tex:find("Nameplate%-Border") then
			frame._waPlate = true
			return true
		end
	end
	return false
end

local function Setup(plate)
	local regions = { plate:GetRegions() }
	local nameRegion
	for _, r in ipairs(regions) do
		if r.GetText and r.GetObjectType and r:GetObjectType() == "FontString" and not nameRegion then nameRegion = r end
	end
	-- the 7th region is the name in 3.3.5; fall back to the first font string
	if regions[7] and regions[7].GetText then nameRegion = regions[7] end
	local label = plate:CreateFontString(nil, "OVERLAY")
	label:SetFont(labelFont, 16, "OUTLINE")
	label:SetPoint("BOTTOM", plate, "TOP", 0, 4)
	label:SetText("")
	label:Hide()
	plates[plate] = { name = nameRegion, label = label }
end

local function Scan()
	local n = WorldFrame:GetNumChildren()
	if n ~= numChildren then
		numChildren = n
		for i = 1, n do
			local child = select(i, WorldFrame:GetChildren())
			if child and not plates[child] and IsNameplate(child) then Setup(child) end
		end
	end
end

local function Update()
	local db = ns.db
	local active = db.plates and (ns.state.inArena or ns.state.testMode)
	for plate, info in pairs(plates) do
		local label = info.label
		if active and plate:IsShown() and info.name then
			local name = info.name:GetText()
			local f = name and ns.Frames:ByName(name)
			if f and f.kind == "arena" then
				local txt = tostring(f.id)
				if db.plateSpec and f.spec then txt = txt .. " " .. f.spec:sub(1, 4) end
				label:SetText(txt)
				if db.plateClassColor and f.class then label:SetTextColor(ns:ClassColor(f.class)) else label:SetTextColor(1, 1, 1) end
				label:Show()
			else
				label:Hide()
			end
		else
			label:Hide()
		end
	end
end

function NP:OnLayout()
	local db = ns.db
	labelFont = ns:Media("font", db.font)
	for _, info in pairs(plates) do
		ns:SetFont(info.label, db.plateSize, "OUTLINE")
		info.label:ClearAllPoints()
		info.label:SetPoint("BOTTOM", info.label:GetParent(), "TOP", 0, db.plateOffsetY)
	end
end

ns:AddTicker(0.25, function()
	if not ns.db or not ns.db.plates then return end
	if not ns.state.inArena and not ns.state.testMode then return end
	Scan()
	Update()
end)

ns:RegisterMessage("ARENA_LEAVE", function() for _, info in pairs(plates) do info.label:Hide() end end)
ns:RegisterMessage("TEST_MODE", function(_, on) if not on then for _, info in pairs(plates) do info.label:Hide() end end end)

function NP:OnSettingChanged(key, value)
	if key == "plates" and not value then for _, info in pairs(plates) do info.label:Hide() end end
end
