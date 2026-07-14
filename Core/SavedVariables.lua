local MB = Mangosbot

MB.SavedVariables = {}

local DEFAULTS = {
    schemaVersion = MB.SCHEMA_VERSION,
    knownHirelings = {},
    hideAlts = false,
    hirelingFilter = "",
    windows = {
        roster = { visible = true },
        selectedBot = { visible = false },
        hirelings = { visible = false },
        groupBar = { visible = true },
    },
    strategyFilters = {
        search = "",
        family = "ALL",
        mode = "ALL",
        kind = "ALL",
        role = "ALL",
        activeOnly = false,
        showIncompatible = false,
    },
}

local function fillDefaults(target, defaults)
    local key, value
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            fillDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function MB.SavedVariables:Initialize()
    if type(MangosbotDB) ~= "table" then
        MangosbotDB = {}
    end
    local priorVersion = tonumber(MangosbotDB.schemaVersion) or 0
    if priorVersion < 1 and type(MangosbotDB.knownHirelings) ~= "table" then MangosbotDB.knownHirelings = {} end
    if priorVersion < 2 and type(MangosbotDB.windows) ~= "table" then MangosbotDB.windows = {} end
    fillDefaults(MangosbotDB, DEFAULTS)
    MangosbotDB.schemaVersion = MB.SCHEMA_VERSION
    self.db = MangosbotDB
    return self.db
end

function MB.SavedVariables:SetWindowPosition(key, point, relativePoint, x, y)
    local window = self.db.windows[key] or {}; self.db.windows[key] = window
    window.point, window.relativePoint, window.x, window.y = point, relativePoint, x, y
end

function MB.SavedVariables:SetWindowVisible(key, visible)
    local window = self.db.windows[key] or {}; self.db.windows[key] = window
    window.visible = visible and true or false
end

function MB.SavedVariables:SetStrategyFilter(key, value)
    self.db.strategyFilters[key] = value
end

function MB.SavedVariables:SetHideAlts(hidden)
    self.db.hideAlts = hidden and true or false
end

function MB.SavedVariables:Get()
    return self.db
end
