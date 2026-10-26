-- RetailPartyFrames - error log: keeps the last Lua errors (any addon) in the saved variables,
-- so bugs can be diagnosed from WTF\...\RetailPartyFrames.lua without typing anything.

local _, ns = ...

local MAX_ERRORS = 30
local pending = {}   -- errors that happened before the database was loaded

local function Store(entry)
    local g = ns.global
    if not g then
        pending[#pending + 1] = entry
        return
    end
    g.errors = g.errors or {}
    local log = g.errors
    -- collapse repeats of the same message
    local last = log[#log]
    if last and last.msg == entry.msg then
        last.count = (last.count or 1) + 1
        last.time = entry.time
        return
    end
    log[#log + 1] = entry
    while #log > MAX_ERRORS do table.remove(log, 1) end
end

local function Record(msg)
    msg = tostring(msg)
    local ours = string.find(msg, "RetailPartyFrames", 1, true) and true or false
    local stack = debugstack and debugstack(4, 12, 0) or ""
    -- our own handler frames do not count
    local stripped = string.gsub(stack, "[^\n]*ErrorLog%.lua[^\n]*\n?", "")
    if not ours and string.find(stripped, "RetailPartyFrames", 1, true) then ours = true end
    stack = stripped
    Store({
        msg = msg,
        stack = stack,
        time = date and date("%Y-%m-%d %H:%M:%S") or tostring(GetTime()),
        version = ns.version,
        ours = ours,
        combat = InCombatLockdown() and true or false,
        group = ns.groupType,
        test = ns.testMode and tostring(ns.testMode) or nil,
        count = 1,
    })
    if ours and ns.db and not ns.errorNotified then
        ns.errorNotified = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff3fa9ffRetailPartyFrames|r: |cffff4040a Lua error occurred|r - /rpf errors shows it, /rpf errors clear removes the log.")
    end
end

-- chain into the existing error handler (Blizzard's or BugGrabber's).
-- Re-entrancy guard: when the error *display* itself throws (3.3.5's ScriptErrorsFrame does that with
-- "cursorOffset" errors), Blizzard's handler would call itself until the C stack overflows.
local original = geterrorhandler and geterrorhandler()
local inHandler = false
if seterrorhandler then
    seterrorhandler(function(msg)
        if inHandler then
            pcall(Record, msg)
            return
        end
        inHandler = true
        pcall(Record, msg)
        if original then pcall(original, msg) end
        inHandler = false
    end)
end

function ns:FlushPendingErrors()
    for _, e in ipairs(pending) do Store(e) end
    for i = #pending, 1, -1 do pending[i] = nil end
end

function ns:ShowErrors(arg)
    local g = self.global
    if arg == "clear" then
        if g then g.errors = {} end
        self:Print("Error log cleared.")
        return
    end
    local log = g and g.errors or {}
    if #log == 0 then
        self:Print("No Lua errors recorded.")
        return
    end
    self:Print(string.format("%d error(s) recorded (newest last):", #log))
    local first = math.max(1, #log - 4)
    for i = first, #log do
        local e = log[i]
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cff%s%d.|r [%s] %s%s", e.ours and "ff8080" or "aaaaaa", i, e.time or "?",
            e.msg or "?", (e.count or 1) > 1 and (" (x" .. e.count .. ")") or ""))
    end
    self:Print("The full log with stack traces is saved in WTF\\Account\\<account>\\SavedVariables\\RetailPartyFrames.lua after a /reload.")
end

-- also record the startup errors caught by Core
function ns:LogInitErrors()
    if not self.initErrors then return end
    for _, e in ipairs(self.initErrors) do
        Store({ msg = "startup: " .. e, stack = "", time = date and date("%Y-%m-%d %H:%M:%S") or "", version = self.version, ours = true, count = 1 })
    end
end
