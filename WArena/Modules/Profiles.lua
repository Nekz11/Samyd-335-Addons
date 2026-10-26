-- WArena: profiles – create/copy/delete, and import/export of a profile as a text string
local _, ns = ...
local Profiles = ns:NewModule("Profiles")
ns.Profiles = Profiles

local format, floor, tconcat, tinsert = string.format, math.floor, table.concat, table.insert
local type, pairs, ipairs, tonumber, tostring = type, pairs, ipairs, tonumber, tostring

---------------------------------------------------------------------------
-- profile management
---------------------------------------------------------------------------
function Profiles:List() return ns:ProfileNames() end
function Profiles:Current() return ns:CurrentProfileName() end

function Profiles:Exists(name)
	return WArenaDB.profiles[name] ~= nil
end

function Profiles:Create(name, copyFrom)
	name = ns:Trim(name)
	if name == "" then return false, "Empty name." end
	if self:Exists(name) then return false, "A profile with that name already exists." end
	WArenaDB.profiles[name] = copyFrom and ns:CopyTable(WArenaDB.profiles[copyFrom] or {}) or {}
	ns:ActivateProfile(name)
	return true
end

function Profiles:CopyFrom(source)
	if not self:Exists(source) then return false, "Unknown profile." end
	local name = self:Current()
	if source == name then return false, "That is the active profile." end
	WArenaDB.profiles[name] = ns:CopyTable(WArenaDB.profiles[source])
	ns:ActivateProfile(name)
	return true
end

function Profiles:Delete(name)
	if not self:Exists(name) then return false, "Unknown profile." end
	if name == self:Current() then return false, "The active profile cannot be deleted." end
	WArenaDB.profiles[name] = nil
	for char, p in pairs(WArenaDB.chars) do
		if p == name then WArenaDB.chars[char] = nil end
	end
	return true
end

function Profiles:Rename(newName)
	newName = ns:Trim(newName)
	if newName == "" then return false, "Empty name." end
	if self:Exists(newName) then return false, "A profile with that name already exists." end
	local old = self:Current()
	WArenaDB.profiles[newName] = WArenaDB.profiles[old]
	WArenaDB.profiles[old] = nil
	for char, p in pairs(WArenaDB.chars) do
		if p == old then WArenaDB.chars[char] = newName end
	end
	ns:ActivateProfile(newName, true)
	return true
end

function Profiles:UseForAllCharacters()
	local name = self:Current()
	for char in pairs(WArenaDB.chars) do WArenaDB.chars[char] = name end
	return true
end

function Profiles:CharactersUsing(name)
	local out = {}
	for char, p in pairs(WArenaDB.chars) do
		if p == name then out[#out + 1] = char end
	end
	table.sort(out)
	return out
end

---------------------------------------------------------------------------
-- serialization (compact, chat-safe)
-- format: WA2!<base64(payload)>!<checksum>
-- payload: key=value;key=value  with values b1 b0 n<number> s<escaped string> t{...}
---------------------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64R = {}
for i = 1, 64 do B64R[B64:sub(i, i)] = i - 1 end

local function b64encode(data)
	local out = {}
	local len = #data
	for i = 1, len, 3 do
		local a, b, c = data:byte(i, i + 2)
		b = b or 0; c = c or 0
		local n = a * 65536 + b * 256 + c
		local c1 = floor(n / 262144) % 64
		local c2 = floor(n / 4096) % 64
		local c3 = floor(n / 64) % 64
		local c4 = n % 64
		out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
			.. ((i + 1 <= len) and B64:sub(c3 + 1, c3 + 1) or "=")
			.. ((i + 2 <= len) and B64:sub(c4 + 1, c4 + 1) or "=")
	end
	return tconcat(out)
end

local function b64decode(data)
	data = data:gsub("[^%w%+/=]", "")
	local out = {}
	for i = 1, #data, 4 do
		local c1, c2, c3, c4 = data:sub(i, i), data:sub(i + 1, i + 1), data:sub(i + 2, i + 2), data:sub(i + 3, i + 3)
		local n1, n2 = B64R[c1], B64R[c2]
		if not n1 or not n2 then return nil end
		local n3 = (c3 ~= "=" and B64R[c3]) or 0
		local n4 = (c4 ~= "=" and B64R[c4]) or 0
		local n = n1 * 262144 + n2 * 4096 + n3 * 64 + n4
		local a = floor(n / 65536) % 256
		local b = floor(n / 256) % 256
		local c = n % 256
		out[#out + 1] = string.char(a)
		if c3 ~= "=" then out[#out + 1] = string.char(b) end
		if c4 ~= "=" then out[#out + 1] = string.char(c) end
	end
	return tconcat(out)
end

local function checksum(s)
	local sum = 0
	for i = 1, #s do sum = (sum * 31 + s:byte(i)) % 1000003 end
	return sum
end

local function escape(s)
	return (s:gsub("\\", "\\\\"):gsub(";", "\\;"):gsub("=", "\\="):gsub("{", "\\{"):gsub("}", "\\}"):gsub(",", "\\,"))
end

local Serialize
local function SerializeValue(v)
	local t = type(v)
	if t == "boolean" then return v and "b1" or "b0" end
	if t == "number" then return "n" .. tostring(v) end
	if t == "string" then return "s" .. escape(v) end
	if t == "table" then
		local parts = {}
		for k, x in pairs(v) do
			parts[#parts + 1] = escape(tostring(k)) .. "=" .. SerializeValue(x)
		end
		table.sort(parts)
		return "t{" .. tconcat(parts, ",") .. "}"
	end
	return "s"
end

Serialize = function(tbl)
	local keys = {}
	for k in pairs(tbl) do keys[#keys + 1] = k end
	table.sort(keys)
	local parts = {}
	for _, k in ipairs(keys) do
		local v = tbl[k]
		if type(v) ~= "function" then parts[#parts + 1] = escape(k) .. "=" .. SerializeValue(v) end
	end
	return tconcat(parts, ";")
end

-- tokenizer that respects backslash escapes
local function Split(s, sep)
	local out, cur, i = {}, {}, 1
	local depth = 0
	while i <= #s do
		local c = s:sub(i, i)
		if c == "\\" then
			cur[#cur + 1] = s:sub(i + 1, i + 1)
			i = i + 2
		else
			if c == "{" then depth = depth + 1 elseif c == "}" then depth = depth - 1 end
			if c == sep and depth == 0 then
				out[#out + 1] = tconcat(cur)
				cur = {}
			else
				cur[#cur + 1] = c
			end
			i = i + 1
		end
	end
	out[#out + 1] = tconcat(cur)
	return out
end

local function SplitKV(s)
	-- first unescaped '=' at depth 0
	local i, depth = 1, 0
	while i <= #s do
		local c = s:sub(i, i)
		if c == "\\" then i = i + 2
		else
			if c == "{" then depth = depth + 1 elseif c == "}" then depth = depth - 1 end
			if c == "=" and depth == 0 then return s:sub(1, i - 1), s:sub(i + 1) end
			i = i + 1
		end
	end
end

local function Unescape(s)
	return (s:gsub("\\(.)", "%1"))
end

local DeserializeValue
DeserializeValue = function(v)
	local tag = v:sub(1, 1)
	local body = v:sub(2)
	if tag == "b" then return body == "1" end
	if tag == "n" then return tonumber(body) end
	if tag == "s" then return Unescape(body) end
	if tag == "t" then
		local inner = body:match("^{(.*)}$")
		if not inner then return nil end
		local out = {}
		if inner ~= "" then
			for _, part in ipairs(Split(inner, ",")) do
				local k, x = SplitKV(part)
				if k then
					k = Unescape(k)
					local nk = tonumber(k)
					out[nk or k] = DeserializeValue(x)
				end
			end
		end
		return out
	end
	return nil
end

local function Deserialize(payload)
	local out = {}
	for _, part in ipairs(Split(payload, ";")) do
		if part ~= "" then
			local k, v = SplitKV(part)
			if k then out[Unescape(k)] = DeserializeValue(v) end
		end
	end
	return out
end

Profiles.Serialize, Profiles.Deserialize = Serialize, Deserialize

function Profiles:Export()
	local payload = Serialize(ns.db)
	return "WA2!" .. b64encode(payload) .. "!" .. checksum(payload)
end

function Profiles:Preview(str)
	local tbl, err = self:Decode(str)
	if not tbl then return nil, err end
	local n = 0
	for _ in pairs(tbl) do n = n + 1 end
	return n
end

function Profiles:Decode(str)
	str = ns:Trim(str or "")
	local body, sum = str:match("^WA2!([%w%+/=]+)!(%d+)$")
	if not body then return nil, "Not a WArena export string." end
	local payload = b64decode(body)
	if not payload then return nil, "The string is damaged (base64)." end
	if tostring(checksum(payload)) ~= sum then return nil, "Checksum mismatch – the string was altered." end
	local tbl = Deserialize(payload)
	local known = 0
	for k in pairs(tbl) do if ns.defaults[k] ~= nil then known = known + 1 end end
	if known == 0 then return nil, "No known settings in this string." end
	return tbl
end

function Profiles:Import(str, intoNewProfile)
	local tbl, err = self:Decode(str)
	if not tbl then return false, err end
	local target = ns.db
	if intoNewProfile and intoNewProfile ~= "" then
		local ok, e = self:Create(intoNewProfile)
		if not ok then return false, e end
		target = ns.db
	end
	for k in pairs(target) do target[k] = nil end
	for k, v in pairs(tbl) do
		if ns.defaults[k] ~= nil then target[k] = v end
	end
	ns:ActivateProfile(self:Current(), true)
	ns:Fire("PROFILE_IMPORTED")
	return true
end

---------------------------------------------------------------------------
-- commands
---------------------------------------------------------------------------
ns:AddCommand("profile", "switch profile: /warena profile <name>", function(arg)
	arg = ns:Trim(arg)
	if arg == "" then
		ns:Print("Active profile: %s. Available: %s", Profiles:Current(), table.concat(Profiles:List(), ", "))
		return
	end
	ns:ActivateProfile(arg)
end)
