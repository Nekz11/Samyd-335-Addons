-- RetailPartyFrames - built-in click casting (secure attributes on every unit button)

local _, ns = ...

ns.ClickButtons = { { 1, "Left" }, { 2, "Right" }, { 3, "Middle" }, { 4, "Button 4" }, { 5, "Button 5" } }
ns.ClickModifiers = { { "", "None" }, { "shift", "Shift" }, { "ctrl", "Ctrl" }, { "alt", "Alt" },
                      { "ctrl-shift", "Ctrl + Shift" }, { "alt-shift", "Alt + Shift" }, { "alt-ctrl", "Alt + Ctrl" } }
ns.ClickTypes = { { "target", "Target" }, { "menu", "Unit menu" }, { "focus", "Set focus" }, { "assist", "Assist" },
                  { "spell", "Cast spell" }, { "macro", "Run macro text" } }

-- secure prefix order is alt-ctrl-shift
local function Prefix(mod)
    if not mod or mod == "" then return "" end
    local alt = string.find(mod, "alt") and "alt-" or ""
    local ctrl = string.find(mod, "ctrl") and "ctrl-" or ""
    local shift = string.find(mod, "shift") and "shift-" or ""
    return alt .. ctrl .. shift
end

function ns:CliqueActive()
    return self.db.clickCast.respectClique and IsAddOnLoaded and IsAddOnLoaded("Clique")
end

-- Returns the bindings that are actually applied (defaults when disabled)
function ns:EffectiveClickBindings()
    local cc = self.db.clickCast
    if cc.enabled and not self:CliqueActive() then return cc.bindings end
    return { { button = 1, mod = "", type = "target" }, { button = 2, mod = "", type = "menu" } }
end

function ns:ApplyClickBindings(b)
    if InCombatLockdown() then return end
    -- clear what we applied last time
    if b.rpfClickAttrs then
        for _, attr in ipairs(b.rpfClickAttrs) do b:SetAttribute(attr, nil) end
    end
    local applied = {}
    if self:CliqueActive() and self.db.clickCast.enabled then
        -- Clique owns the clicks; keep nothing of ours
        b.rpfClickAttrs = applied
        return
    end
    for _, bind in ipairs(self:EffectiveClickBindings()) do
        local btn = tonumber(bind.button) or 1
        local prefix = Prefix(bind.mod)
        -- unmodified bindings use the wildcard so they also catch modifier combos without a binding
        if prefix == "" then prefix = "*" end
        local suffix = tostring(btn)
        local typeAttr = prefix .. "type" .. suffix
        local kind = bind.type or "target"
        if kind == "spell" and bind.value and bind.value ~= "" then
            b:SetAttribute(typeAttr, "spell")
            b:SetAttribute(prefix .. "spell" .. suffix, bind.value)
            applied[#applied + 1] = prefix .. "spell" .. suffix
        elseif kind == "macro" and bind.value and bind.value ~= "" then
            b:SetAttribute(typeAttr, "macro")
            b:SetAttribute(prefix .. "macrotext" .. suffix, bind.value)
            applied[#applied + 1] = prefix .. "macrotext" .. suffix
        elseif kind == "target" or kind == "menu" or kind == "focus" or kind == "assist" then
            b:SetAttribute(typeAttr, kind)
        else
            typeAttr = nil
        end
        if typeAttr then applied[#applied + 1] = typeAttr end
    end
    b.rpfClickAttrs = applied
end

function ns:ApplyAllClickBindings()
    if InCombatLockdown() then
        self:AfterCombat("clickcast", function() ns:ApplyAllClickBindings() end)
        return
    end
    for _, b in ipairs(self.allButtons) do self:ApplyClickBindings(b) end
end

-- helpers for the options page
function ns:AddClickBinding()
    local list = self.db.clickCast.bindings
    list[#list + 1] = { button = 1, mod = "shift", type = "spell", value = "" }
    return #list
end

function ns:RemoveClickBinding(index)
    table.remove(self.db.clickCast.bindings, index)
    self:ApplyAllClickBindings()
end

function ns:ClickBindingConflict(index)
    local list = self.db.clickCast.bindings
    local me = list[index]
    if not me then return false end
    for i, other in ipairs(list) do
        if i ~= index and tonumber(other.button) == tonumber(me.button) and Prefix(other.mod) == Prefix(me.mod) then
            return true
        end
    end
    return false
end

ns:RegisterCallback("LAYOUT", function()
    if ns.allButtons and #ns.allButtons > 0 then ns:ApplyAllClickBindings() end
end)
