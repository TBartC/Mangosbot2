local MB = Mangosbot

MB.BotState = {
    bots = {},
    selectedName = nil,
    knownHirelings = {},
    operationHistory = {},
    strategyOperations = {},
}

local function createBot(name)
    return {
        name = name,
        class = nil,
        role = nil,
        spec = nil,
        online = nil,
        grouped = nil,
        strategies = { co = {}, nc = {} },
        pending = {},
        lastError = nil,
    }
end

local function strategyOperationKey(bot, family, strategy)
    return tostring(bot) .. "\031" .. tostring(family) .. "\031" .. tostring(strategy)
end

function MB.BotState:SetStrategyOperation(event, status)
    if not event or not event.bot or not event.family or not event.strategy then return end
    local key = strategyOperationKey(event.bot, event.family, event.strategy)
    if status == nil then self.strategyOperations[key] = nil
    else
        local copy = MB:CopyMap(event); copy.status = status; self.strategyOperations[key] = copy
    end
    MB:Emit("STRATEGY_OPERATION_CHANGED", event)
end

function MB.BotState:GetStrategyOperation(bot, family, strategy)
    return self.strategyOperations[strategyOperationKey(bot, family, strategy)]
end

MB:On("STRATEGY_TOGGLE_PENDING", function(event) MB.BotState:SetStrategyOperation(event, "pending") end)
MB:On("STRATEGY_TOGGLE_FAILED", function(event) MB.BotState:SetStrategyOperation(event, "failed") end)
MB:On("STRATEGY_TOGGLE_CONFIRMED", function(event) MB.BotState:SetStrategyOperation(event, nil) end)

function MB.BotState:EnsureBot(name)
    if not name or name == "" then
        return nil
    end
    if not self.bots[name] then
        self.bots[name] = createBot(name)
    end
    return self.bots[name]
end

function MB.BotState:GetBot(name)
    return self.bots[name]
end

function MB.BotState:GetBots()
    return self.bots
end

function MB.BotState:Select(name)
    if name and name ~= "" then
        self:EnsureBot(name)
        self.selectedName = name
    else
        self.selectedName = nil
    end
    MB:Emit("SELECTED_BOT_CHANGED", { bot = self.selectedName })
end

function MB.BotState:GetSelectedName()
    return self.selectedName
end

function MB.BotState:GetSelectedBot()
    if not self.selectedName then
        return nil
    end
    return self.bots[self.selectedName]
end

function MB.BotState:SetStrategies(name, family, strategies)
    if family ~= "co" and family ~= "nc" then
        return false, "invalid strategy family"
    end
    local bot = self:EnsureBot(name)
    if not bot then
        return false, "missing bot name"
    end
    bot.strategies[family] = MB:CopyArray(strategies)
    MB:Emit("BOT_STRATEGIES_CHANGED", {
        bot = name,
        family = family,
        strategies = MB:CopyArray(bot.strategies[family]),
    })
    return true
end

function MB.BotState:HasStrategy(name, family, strategyName)
    local bot = self.bots[name]
    local strategies = bot and bot.strategies and bot.strategies[family] or {}
    local i
    for i = 1, #strategies do
        if strategies[i] == strategyName then
            return true
        end
    end
    return false
end

function MB.BotState:UpdateBot(name, fields)
    local bot = self:EnsureBot(name)
    if not bot then
        return false
    end
    local key, value
    for key, value in pairs(fields or {}) do
        if key ~= "name" and key ~= "strategies" then
            bot[key] = value
        end
    end
    MB:Emit("BOT_UPDATED", { bot = name })
    return true
end

function MB.BotState:RememberHireling(name)
    if not name or name == "" or self.knownHirelings[name] then
        return false
    end
    self.knownHirelings[name] = true
    if MangosbotDB and MangosbotDB.knownHirelings then
        table.insert(MangosbotDB.knownHirelings, name)
    end
    MB:Emit("HIRELINGS_CHANGED", { bot = name })
    return true
end

function MB.BotState:DismissBot(name)
    local bot = name and self.bots[name]
    if not bot then return false end

    bot.inRoster = false
    self.knownHirelings[name] = nil
    if MangosbotDB and MangosbotDB.knownHirelings then
        local i
        for i = #MangosbotDB.knownHirelings, 1, -1 do
            if MangosbotDB.knownHirelings[i] == name then
                table.remove(MangosbotDB.knownHirelings, i)
            end
        end
    end
    if self.selectedName == name then self:Select(nil) end
    MB:Emit("ROSTER_CHANGED", { roster = self:GetRoster() })
    MB:Emit("HIRELINGS_CHANGED", { hirelings = self:GetHirelings() })
    return true
end

function MB.BotState:ApplyRoster(entries)
    local name, bot
    for name, bot in pairs(self.bots) do
        bot.inRoster = false
    end
    local i, entry
    for i = 1, #(entries or {}) do
        entry = entries[i]
        bot = self:EnsureBot(entry.name)
        if bot then
            bot.class = entry.class or bot.class
            bot.online = entry.online
            bot.grouped = entry.grouped
            bot.inRoster = true
        end
    end
    MB:Emit("ROSTER_CHANGED", { roster = self:GetRoster() })
end

function MB.BotState:GetRoster()
    local roster = {}
    local name, bot
    for name, bot in pairs(self.bots) do
        if bot.inRoster then
            table.insert(roster, bot)
        end
    end
    table.sort(roster, function(left, right)
        return string.lower(left.name) < string.lower(right.name)
    end)
    return roster
end

function MB.BotState:GetVisibleRoster(hideAlts)
    local roster = self:GetRoster()
    if not hideAlts then return roster end
    local visible = {}
    local i, bot
    for i = 1, #roster do
        bot = roster[i]
        if self.knownHirelings[bot.name] then table.insert(visible, bot) end
    end
    return visible
end

function MB.BotState:ApplyHirelings(entries)
    local i, entry, bot
    for i = 1, #(entries or {}) do
        entry = entries[i]
        self:RememberHireling(entry.name)
        bot = self:EnsureBot(entry.name)
        if bot then
            bot.race = entry.race or bot.race
            bot.class = entry.class or bot.class
            bot.spec = entry.spec or bot.spec
            bot.role = entry.role or bot.role
            bot.reportedStrategy = entry.strategy or bot.reportedStrategy
        end
    end
    MB:Emit("HIRELINGS_CHANGED", { hirelings = self:GetHirelings() })
end

function MB.BotState:GetHirelings()
    local hirelings = {}
    local name
    for name in pairs(self.knownHirelings) do
        table.insert(hirelings, self:EnsureBot(name))
    end
    table.sort(hirelings, function(left, right)
        return string.lower(left.name) < string.lower(right.name)
    end)
    return hirelings
end

function MB.BotState:AddOperation(operation)
    local copy = MB:CopyMap(operation or {})
    table.insert(self.operationHistory, copy)
    while #self.operationHistory > 50 do table.remove(self.operationHistory, 1) end
    if copy.bot and copy.status == "failed" then
        local bot = self:EnsureBot(copy.bot)
        bot.lastError = copy.message or copy.code
    end
    MB:Emit("OPERATION_HISTORY_CHANGED", { bot = copy.bot })
end

function MB.BotState:GetOperationHistory(botName)
    local result = {}
    local i, operation
    for i = 1, #self.operationHistory do
        operation = self.operationHistory[i]
        if not botName or operation.bot == botName then table.insert(result, MB:CopyMap(operation)) end
    end
    return result
end

local OPERATION_STATUSES = {
    OPERATION_QUEUED = "queued",
    OPERATION_SENT = "sent",
    OPERATION_RETRY = "retry",
    OPERATION_CONFIRMED = "confirmed",
    OPERATION_FAILED = "failed",
}

local eventName, status
for eventName, status in pairs(OPERATION_STATUSES) do
    local capturedStatus = status
    MB:On(eventName, function(event)
        local operation = MB:CopyMap(event or {})
        operation.status = capturedStatus
        MB.BotState:AddOperation(operation)
    end)
end

local CLEAR_STATUSES = {
    STRATEGY_CLEAR_PENDING = "pending",
    STRATEGY_CLEAR_CONFIRMED = "confirmed",
    STRATEGY_CLEAR_FAILED = "failed",
}

for eventName, status in pairs(CLEAR_STATUSES) do
    local capturedStatus = status
    MB:On(eventName, function(event)
        local operation = MB:CopyMap(event or {})
        operation.status = capturedStatus
        operation.command = "clear " .. string.upper(operation.family or "strategies")
        MB.BotState:AddOperation(operation)
    end)
end
