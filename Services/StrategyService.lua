local MB = Mangosbot

MB.StrategyService = { activeBundles = {}, activeClears = {} }

local function contains(values, expected)
    local i
    for i = 1, #(values or {}) do
        if values[i] == expected then
            return true
        end
    end
    return false
end

function MB.StrategyService:IsClassCompatible(definition, className)
    if not definition then
        return false
    end
    local normalized = string.lower(className or "")
    if contains(definition.classes, "generic") then
        return true
    end
    return normalized ~= "" and contains(definition.classes, normalized)
end

function MB.StrategyService:Validate(botName, strategyName, family, removing)
    local definition = MB.StrategyCatalog.byName[strategyName]
    if not definition then
        return { ok = false, code = "UNKNOWN", message = "Unknown strategy: " .. tostring(strategyName) }
    end
    if family ~= "co" and family ~= "nc" then
        return { ok = false, code = "INVALID_FAMILY", message = "Choose Combat or Non-combat" }
    end
    local bot = MB.BotState:GetBot(botName)
    if not bot then
        return { ok = false, code = "UNKNOWN_BOT", message = "Unknown bot: " .. tostring(botName) }
    end
    if removing and strategyName == "default" then
        return { ok = false, code = "PROTECTED", message = "The exact default strategy cannot be removed" }
    end
    return { ok = true, definition = definition }
end

local function replyContains(event, strategyName)
    return contains(event and event.strategies or {}, strategyName)
end

function MB.StrategyService:Toggle(botName, strategyName, family, completion)
    local removing = MB.BotState:HasStrategy(botName, family, strategyName)
    local validation = self:Validate(botName, strategyName, family, removing)
    if not validation.ok then
        if completion then completion(false, validation) end
        return validation
    end

    local desiredActive = not removing
    local mutation = family .. " " .. (desiredActive and "+" or "-") .. strategyName
    local operation = {
        bot = botName,
        strategy = strategyName,
        family = family,
        desiredActive = desiredActive,
    }
    MB:Emit("STRATEGY_TOGGLE_PENDING", operation)

    MB.Transport:Whisper(botName, mutation, nil, function(mutationOk, mutationResult)
        if not mutationOk then
            operation.code = mutationResult.code
            operation.message = mutationResult.message
            MB:Emit("STRATEGY_TOGGLE_FAILED", operation)
            if completion then completion(false, operation) end
            return
        end

        MB.Transport:Whisper(
            botName,
            family .. " ?",
            { kind = "strategies", bot = botName, family = family },
            function(queryOk, event)
                if not queryOk then
                    operation.code = event.code
                    operation.message = event.message
                    MB:Emit("STRATEGY_TOGGLE_FAILED", operation)
                    if completion then completion(false, operation) end
                    return
                end

                MB.BotState:SetStrategies(botName, family, event.strategies)
                if replyContains(event, strategyName) ~= desiredActive then
                    operation.code = "VERIFY_FAILED"
                    operation.message = "Core did not confirm the requested strategy state"
                    MB:Emit("STRATEGY_TOGGLE_FAILED", operation)
                    if completion then completion(false, operation) end
                    return
                end
                MB:Emit("STRATEGY_TOGGLE_CONFIRMED", operation)
                if completion then completion(true, operation) end
            end
        )
    end)

    return {
        ok = true,
        bot = botName,
        strategy = strategyName,
        family = family,
        desiredActive = desiredActive,
    }
end

function MB.StrategyService:BuildClearList(strategies)
    local result, seen = {}, {}
    local i, name
    for i = 1, #(strategies or {}) do
        name = strategies[i]
        if type(name) == "string" and name ~= "" and name ~= "default" and not seen[name] then
            seen[name] = true
            table.insert(result, name)
        end
    end
    return result
end

function MB.StrategyService:IsClearing(botName)
    return self.activeClears[botName] ~= nil
end

function MB.StrategyService:ClearFamily(botName, family, completion)
    local rejection
    if not MB.BotState:GetBot(botName) then
        rejection = { ok = false, code = "UNKNOWN_BOT", message = "Unknown bot: " .. tostring(botName) }
    elseif family ~= "co" and family ~= "nc" then
        rejection = { ok = false, code = "INVALID_FAMILY", message = "Choose Combat or Non-combat" }
    elseif self.activeClears[botName] then
        rejection = { ok = false, code = "CLEAR_BUSY", message = "A strategy clear is already active for " .. tostring(botName) }
    end
    if rejection then
        if completion then completion(false, rejection) end
        return rejection
    end

    local job = { ok = true, bot = botName, family = family, stepIndex = 0 }
    self.activeClears[botName] = job

    local function finish(success, result)
        if result then
            job.code = result.code
            job.message = result.message
            job.survivors = result.survivors
        end
        MB.StrategyService.activeClears[botName] = nil
        MB:Emit(success and "STRATEGY_CLEAR_CONFIRMED" or "STRATEGY_CLEAR_FAILED", job)
        if completion then completion(success, job) end
    end

    local function fail(result, fallbackCode, fallbackMessage)
        finish(false, {
            code = result and result.code or fallbackCode,
            message = result and result.message or fallbackMessage,
            survivors = result and result.survivors,
        })
    end

    local function queryFinal()
        local queued = MB.Transport:Whisper(
            botName,
            family .. " ?",
            { kind = "strategies", bot = botName, family = family },
            function(queryOk, event)
                if not queryOk then
                    fail(event, "QUERY_FAILED", "Could not verify strategy clear")
                    return
                end
                MB.BotState:SetStrategies(botName, family, event.strategies)
                local survivors = MB.StrategyService:BuildClearList(event.strategies)
                if #survivors > 0 then
                    finish(false, {
                        code = "VERIFY_FAILED",
                        message = "Core still reports removable strategies",
                        survivors = survivors,
                    })
                    return
                end
                finish(true)
            end
        )
        if not queued then fail(nil, "SEND_FAILED", "Could not queue strategy verification") end
    end

    local function sendNext()
        job.stepIndex = job.stepIndex + 1
        local strategyName = job.clearList[job.stepIndex]
        if not strategyName then
            queryFinal()
            return
        end
        local queued = MB.Transport:Whisper(botName, family .. " -" .. strategyName, nil, function(sendOk, event)
            if not sendOk then
                fail(event, "SEND_FAILED", "Could not send strategy removal")
                return
            end
            sendNext()
        end)
        if not queued then fail(nil, "SEND_FAILED", "Could not queue strategy removal") end
    end

    MB:Emit("STRATEGY_CLEAR_PENDING", job)
    local queued = MB.Transport:Whisper(
        botName,
        family .. " ?",
        { kind = "strategies", bot = botName, family = family },
        function(queryOk, event)
            if not queryOk then
                fail(event, "QUERY_FAILED", "Could not query strategy state")
                return
            end
            MB.BotState:SetStrategies(botName, family, event.strategies)
            job.clearList = MB.StrategyService:BuildClearList(event.strategies)
            sendNext()
        end
    )
    if not queued then fail(nil, "SEND_FAILED", "Could not queue strategy query") end
    return job
end

function MB.StrategyService:PlanContains(entries, strategyName)
    local i
    for i = 1, #(entries or {}) do
        if entries[i].name == strategyName then return true end
    end
    return false
end

local function bundleSupportsClass(bundle, className)
    return contains(bundle.classes, string.lower(className or ""))
end

function MB.StrategyService:BuildBundlePlan(botName, bundleKey)
    local bundle = MB.PackageBundles and MB.PackageBundles[bundleKey]
    if not bundle then
        return { ok = false, code = "UNKNOWN_BUNDLE", message = "Unknown setup package" }
    end
    local bot = MB.BotState:GetBot(botName)
    if not bot then
        return { ok = false, code = "UNKNOWN_BOT", message = "Unknown bot" }
    end
    if not bundleSupportsClass(bundle, bot.class) then
        return { ok = false, code = "INCOMPATIBLE_CLASS", message = "Package does not match bot class" }
    end

    local plan = { ok = true, bot = botName, bundleKey = bundleKey, remove = {}, add = {} }
    local key, competing
    for key, competing in pairs(MB.PackageBundles) do
        if key ~= bundleKey and competing.mode == bundle.mode and bundleSupportsClass(competing, bot.class) then
            if MB.BotState:HasStrategy(botName, "co", competing.base) and not self:PlanContains(plan.remove, competing.base) then
                table.insert(plan.remove, { family = "co", name = competing.base })
            end
        end
    end
    table.sort(plan.remove, function(left, right) return left.name < right.name end)

    local i, name
    for i = 1, #(bundle.safe or {}) do
        name = bundle.safe[i]
        if not MB.BotState:HasStrategy(botName, "co", name) and not self:PlanContains(plan.add, name) then
            table.insert(plan.add, { family = "co", name = name })
        end
    end
    return plan
end

function MB.StrategyService:ApplyBundle(botName, bundleKey)
    if self.activeBundles[botName] then
        return { ok = false, code = "BUNDLE_BUSY", message = "A package is already being applied to " .. tostring(botName) }
    end
    local plan = self:BuildBundlePlan(botName, bundleKey)
    if not plan.ok then return plan end
    plan.steps = {}
    local i
    for i = 1, #plan.remove do table.insert(plan.steps, plan.remove[i]) end
    for i = 1, #plan.add do table.insert(plan.steps, plan.add[i]) end
    plan.stepIndex = 0
    self.activeBundles[botName] = plan
    MB:Emit("BUNDLE_APPLY_STARTED", plan)
    local function advance(success, result)
        if success == false then
            plan.code = result and result.code or "STEP_FAILED"
            plan.message = result and result.message or "Bundle step failed"
            MB:Emit("BUNDLE_APPLY_FAILED", plan)
            MB.StrategyService.activeBundles[botName] = nil
            return
        end
        plan.stepIndex = plan.stepIndex + 1
        local entry = plan.steps[plan.stepIndex]
        if not entry then
            MB:Emit("BUNDLE_APPLY_COMPLETED", plan)
            MB.StrategyService.activeBundles[botName] = nil
            return
        end
        MB.StrategyService:Toggle(botName, entry.name, entry.family, advance)
    end
    advance(true)
    return plan
end
