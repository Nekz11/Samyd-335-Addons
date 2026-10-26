-- RetailPartyFrames - profiles: storage, migration, auto-switching, export / import

local _, ns = ...

local DEFAULT_PROFILE = "Default"

------------------------------------------------------------------------
-- Database loading and 1.x migration
------------------------------------------------------------------------
local function IsOldFlatDB(db)
    -- 1.x stored the settings directly in the saved variable
    return db.profiles == nil and (db.width ~= nil or db.cdCategories ~= nil or db.locked ~= nil)
end

local function PrepareProfile(p)
    -- 2.0.x -> 2.1: boolean filters became modes
    if p.debuffFilter == nil and p.onlyDispellable ~= nil then
        p.debuffFilter = p.onlyDispellable and "DISPELLABLE" or "IMPORTANT"
    end
    p.onlyDispellable = nil
    if p.buffFilter == nil and p.buffWhitelistOnly ~= nil then
        p.buffFilter = p.buffWhitelistOnly and "WHITELIST" or "IMPORTANT"
    end
    p.buffWhitelistOnly = nil
    ns.CopyDefaults(ns.defaults, p)
    if type(p.point) ~= "table" or #p.point < 4 then p.point = ns.DeepCopy(ns.defaults.point) end
    if type(p.raidPoint) ~= "table" or #p.raidPoint < 4 then p.raidPoint = ns.DeepCopy(ns.defaults.raidPoint) end
    if type(p.mtPoint) ~= "table" or #p.mtPoint < 4 then p.mtPoint = ns.DeepCopy(ns.defaults.mtPoint) end
    if type(p.healthCustom) ~= "table" or #p.healthCustom < 3 then p.healthCustom = ns.DeepCopy(ns.defaults.healthCustom) end
    if type(p.borderColor) ~= "table" or #p.borderColor < 3 then p.borderColor = ns.DeepCopy(ns.defaults.borderColor) end
    if type(p.clickCast.bindings) ~= "table" then p.clickCast.bindings = ns.DeepCopy(ns.defaults.clickCast.bindings) end
    return p
end
ns.PrepareProfile = PrepareProfile

function ns:LoadDatabase()
    if type(RetailPartyFramesDB) ~= "table" then RetailPartyFramesDB = {} end
    local db = RetailPartyFramesDB

    if IsOldFlatDB(db) then
        local old = {}
        for k, v in pairs(db) do
            old[k] = v
            db[k] = nil
        end
        db.profiles = { [DEFAULT_PROFILE] = old }
        self.migratedFrom1x = true
    end

    self.CopyDefaults(self.globalDefaults, db)
    db.version = self.DB_VERSION
    if not next(db.profiles) then db.profiles[DEFAULT_PROFILE] = {} end
    for _, p in pairs(db.profiles) do PrepareProfile(p) end

    self.global = db
    self:EnsurePresets()
    local key = self.PlayerKey()
    local name = db.profileKeys[key]
    if not name or not db.profiles[name] then
        name = db.profiles[DEFAULT_PROFILE] and DEFAULT_PROFILE or next(db.profiles)
        db.profileKeys[key] = name
    end
    self.db = db.profiles[name]
    self.activeProfile = name
end

------------------------------------------------------------------------
-- Profile management
------------------------------------------------------------------------
function ns:ActiveProfileName()
    return self.activeProfile or DEFAULT_PROFILE
end

function ns:ProfileNames()
    local list = {}
    for name in pairs(self.global.profiles) do list[#list + 1] = name end
    table.sort(list)
    return list
end

function ns:ProfileExists(name)
    return name and self.global.profiles[name] ~= nil
end

-- The profile the player picked himself (automatic switching returns to it)
function ns:ManualProfileName()
    local name = self.global.profileKeys[self.PlayerKey()]
    if name and self:ProfileExists(name) then return name end
    return self:ActiveProfileName()
end

-- Switch the active profile for this character (queued while in combat).
-- auto = true: temporary switch by group type, the manual choice is kept.
function ns:SetProfile(name, announce, auto)
    name = self.Trim(name)
    if not self:ProfileExists(name) then
        if announce then self:Print("No profile named '" .. name .. "'.") end
        return false
    end
    if not auto then self.global.profileKeys[self.PlayerKey()] = name end
    if name == self.activeProfile then return true end
    self:AfterCombat("profile", function()
        ns.activeProfile = name
        ns.db = ns.global.profiles[name]
        ns:ApplyProfile()
        if announce then
            if auto then
                ns:Print("Profile |cffffffff" .. name .. "|r activated automatically (" .. (ns.GroupTypeLabels[ns.groupType] or ns.groupType) .. ").")
            else
                ns:Print("Profile |cffffffff" .. name .. "|r activated.")
            end
        end
    end)
    return true
end

function ns:CreateProfile(name, copyFrom)
    name = self.Trim(name)
    if name == "" then return false, "Please enter a name." end
    if self:ProfileExists(name) then return false, "A profile with that name already exists." end
    local src = copyFrom and self.global.profiles[copyFrom]
    local p = src and self.DeepCopy(src) or {}
    self.global.profiles[name] = PrepareProfile(p)
    return true
end

function ns:CopyProfileInto(from)
    local src = self.global.profiles[from]
    if not src or from == self.activeProfile then return false end
    local dst = self.db
    for k in pairs(dst) do dst[k] = nil end
    for k, v in pairs(self.DeepCopy(src)) do dst[k] = v end
    PrepareProfile(dst)
    self:ApplyProfile()
    return true
end

function ns:DeleteProfile(name)
    if name == self.activeProfile or not self:ProfileExists(name) then return false end
    self.global.profiles[name] = nil
    for k, v in pairs(self.global.autoProfiles) do
        if v == name then self.global.autoProfiles[k] = "" end
    end
    if name == self.activeProfile then return false end
    -- characters that used it fall back to the default / first profile
    for key, pname in pairs(self.global.profileKeys) do
        if pname == name then
            self.global.profileKeys[key] = self.global.profiles[DEFAULT_PROFILE] and DEFAULT_PROFILE or next(self.global.profiles)
        end
    end
    return true
end

function ns:ResetProfile()
    local dst = self.db
    for k in pairs(dst) do dst[k] = nil end
    PrepareProfile(dst)
    self:ApplyProfile()
end

-- re-layout everything after the active profile table changed
function ns:ApplyProfile()
    if InCombatLockdown() then
        self:AfterCombat("applyprofile", function() ns:ApplyProfile() end)
        return
    end
    self:RebuildSpellIndex()
    self:Fire("PROFILE_CHANGED")
    if self.RefreshAll then self:RefreshAll() end
    if self.SyncMovers then self:SyncMovers() end
    if self.RefreshOptions then self:RefreshOptions(true) end
end

------------------------------------------------------------------------
-- Automatic profiles per group type
------------------------------------------------------------------------
function ns:AutoProfileFor(groupType)
    local auto = self.global.autoProfiles
    if not auto or not auto.enabled then return nil end
    local name = auto[groupType]
    if name and name ~= "" and self:ProfileExists(name) then return name end
    return nil
end

-- no mapping for a group type (or automatic switching off) = back to the manual profile
ns:RegisterCallback("GROUP_TYPE_CHANGED", function(groupType)
    local name = ns:AutoProfileFor(groupType) or ns:ManualProfileName()
    if name and name ~= ns.activeProfile then
        ns:SetProfile(name, true, true)
    end
end)

------------------------------------------------------------------------
-- Serialization (compact Lua literal, readable and safe to load in a sandbox)
------------------------------------------------------------------------
local function SerializeValue(v, out, indent)
    local t = type(v)
    if t == "string" then
        out[#out + 1] = string.format("%q", v)
    elseif t == "number" or t == "boolean" then
        out[#out + 1] = tostring(v)
    elseif t == "table" then
        out[#out + 1] = "{"
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b)
            local ta, tb = type(a), type(b)
            if ta ~= tb then return ta < tb end
            return a < b
        end)
        for _, k in ipairs(keys) do
            local kt = type(k)
            if kt == "string" and string.match(k, "^[%a_][%w_]*$") then
                out[#out + 1] = k .. "="
            elseif kt == "string" then
                out[#out + 1] = "[" .. string.format("%q", k) .. "]="
            else
                out[#out + 1] = "[" .. tostring(k) .. "]="
            end
            SerializeValue(v[k], out, indent)
            out[#out + 1] = ","
        end
        out[#out + 1] = "}"
    else
        out[#out + 1] = "nil"
    end
end

function ns:Serialize(tbl)
    local out = {}
    SerializeValue(tbl, out, 0)
    return table.concat(out)
end

-- Only tables, numbers, strings and booleans come back - never functions
function ns:Deserialize(text)
    text = self.Trim(text)
    if text == "" then return nil, "Nothing to import." end
    if string.find(text, "^RPF2:") then text = string.sub(text, 6) end
    local fn, err = loadstring("return " .. text)
    if not fn then return nil, "Invalid data: " .. tostring(err) end
    setfenv(fn, {})
    local ok, result = pcall(fn)
    if not ok then return nil, "Invalid data: " .. tostring(result) end
    if type(result) ~= "table" then return nil, "Invalid data (not a table)." end
    return result
end

function ns:ExportProfile(name)
    local p = self.global.profiles[name or self.activeProfile]
    if not p then return "" end
    local copy = self.DeepCopy(p)
    copy.locked = nil
    return "RPF2:" .. self:Serialize(copy)
end

function ns:ImportProfile(text, name)
    local data, err = self:Deserialize(text)
    if not data then return false, err end
    name = self.Trim(name or "")
    if name == "" then name = "Imported" end
    local base, n = name, 1
    while self:ProfileExists(name) do
        n = n + 1
        name = base .. " " .. n
    end
    self.global.profiles[name] = PrepareProfile(data)
    return true, name
end

function ns:ShowExport()
    if self.OpenOptions then
        self:OpenOptions("Profiles")
    end
end
