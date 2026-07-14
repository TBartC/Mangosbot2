local MB = Mangosbot

MB.StatusTab = { parent = nil, pendingClear = nil }

function MB.StatusTab:GetWarnings(botName)
    local warnings = {}
    local bot = MB.BotState:GetBot(botName)
    if not bot then return warnings end
    local families = { "co", "nc" }
    local i, family, j, strategyName
    for i = 1, #families do
        family = families[i]
        for j = 1, #(bot.strategies[family] or {}) do
            strategyName = bot.strategies[family][j]
            if MB.StrategiesTab:IsSuspicious(strategyName, family) then
                table.insert(warnings, {
                    strategy = strategyName,
                    family = family,
                    severity = "info",
                    message = strategyName .. " is active in " .. string.upper(family) .. " (catalog recommendation differs)",
                })
            end
        end
    end
    return warnings
end

function MB.StatusTab:ClearSelectedFamily(family)
    local botName = MB.SelectedBot and MB.SelectedBot.botName
    if not botName or botName == "" then
        return { ok = false, code = "NO_BOT", message = "Select a bot first" }
    end
    return MB.StrategyService:ClearFamily(botName, family)
end

function MB.StatusTab:BeginClearConfirmation(family)
    local botName = MB.SelectedBot and MB.SelectedBot.botName
    if type(botName) ~= "string" or botName == "" then return false end
    if family ~= "co" and family ~= "nc" then return false end
    if self.pendingClear ~= nil then return false end
    self.pendingClear = { bot = botName, family = family }
    StaticPopup_Show(
        family == "co" and "MANGOSBOT_CONFIRM_CLEAR_CO" or "MANGOSBOT_CONFIRM_CLEAR_NC",
        botName
    )
    return true
end

function MB.StatusTab:CancelPendingClear()
    self.pendingClear = nil
end

function MB.StatusTab:AcceptPendingClear()
    local action = self.pendingClear
    self.pendingClear = nil
    if type(action) ~= "table" or type(action.bot) ~= "string" or action.bot == "" then return false end
    if action.family ~= "co" and action.family ~= "nc" then return false end
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff55ccffMangosbot clearing " .. string.upper(action.family) ..
        " strategies for " .. action.bot .. "...|r"
    )
    MB.StrategyService:ClearFamily(action.bot, action.family)
    return true
end

local function setClearControlsEnabled(parent, enabled)
    if not parent then return end
    local controls = { parent.clearCO, parent.clearNC }
    local i
    for i = 1, #controls do
        if enabled then controls[i]:Enable() else controls[i]:Disable() end
    end
end

local function makeSection(parent, title, x, y, width, height)
    local heading = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); heading:SetText(title)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4); text:SetWidth(width); text:SetHeight(height)
    text:SetJustifyH("LEFT"); text:SetJustifyV("TOP"); text:SetText("")
    return text
end

function MB.StatusTab:Create(parent)
    if self.parent then return self.parent end
    self.parent = parent
    parent.scroll = CreateFrame("ScrollFrame", "MangosbotStatusScroll", parent, "UIPanelScrollFrameTemplate")
    parent.scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8); parent.scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -30, 36)
    parent.content = CreateFrame("Frame", nil, parent.scroll); parent.content:SetWidth(438); parent.content:SetHeight(600)
    parent.scroll:SetScrollChild(parent.content)
    parent.detail = parent.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    parent.detail:SetPoint("TOPLEFT", parent.content, "TOPLEFT", 0, 0); parent.detail:SetWidth(430); parent.detail:SetJustifyH("LEFT"); parent.detail:SetJustifyV("TOP")
    parent.scroll:EnableMouseWheel(true)
    parent.scroll:SetScript("OnMouseWheel", function() parent.scroll:SetVerticalScroll(math.max(0, parent.scroll:GetVerticalScroll() - (arg1 * 30))) end)
    parent.refresh = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    parent.refresh:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 8); parent.refresh:SetWidth(70); parent.refresh:SetHeight(20); parent.refresh:SetText("Refresh")
    parent.refresh:SetScript("OnClick", function() MB.SelectedBot:Refresh() end)
    parent.clearCO = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    parent.clearCO:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 8, 8); parent.clearCO:SetWidth(70); parent.clearCO:SetHeight(20); parent.clearCO:SetText("Clear CO")
    parent.clearNC = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    parent.clearNC:SetPoint("LEFT", parent.clearCO, "RIGHT", 6, 0); parent.clearNC:SetWidth(70); parent.clearNC:SetHeight(20); parent.clearNC:SetText("Clear NC")
    StaticPopupDialogs["MANGOSBOT_CONFIRM_CLEAR_CO"] = {
        text = "Clear all removable Combat strategies from %s?",
        button1 = "Clear CO", button2 = "Cancel", timeout = 0, whileDead = 1, hideOnEscape = 1,
        OnAccept = function() MB.StatusTab:AcceptPendingClear() end,
        OnCancel = function() MB.StatusTab:CancelPendingClear() end,
        OnHide = function() MB.StatusTab:CancelPendingClear() end,
    }
    StaticPopupDialogs["MANGOSBOT_CONFIRM_CLEAR_NC"] = {
        text = "Clear all removable Non-combat strategies from %s? Exact default is preserved.",
        button1 = "Clear NC", button2 = "Cancel", timeout = 0, whileDead = 1, hideOnEscape = 1,
        OnAccept = function() MB.StatusTab:AcceptPendingClear() end,
        OnCancel = function() MB.StatusTab:CancelPendingClear() end,
        OnHide = function() MB.StatusTab:CancelPendingClear() end,
    }
    parent.clearCO:SetScript("OnClick", function()
        MB.StatusTab:BeginClearConfirmation("co")
    end)
    parent.clearNC:SetScript("OnClick", function()
        MB.StatusTab:BeginClearConfirmation("nc")
    end)
    MB:On("BOT_STRATEGIES_CHANGED", function() MB.StatusTab:Render() end)
    MB:On("OPERATION_HISTORY_CHANGED", function() MB.StatusTab:Render() end)
    MB:On("PINNED_BOT_CHANGED", function() MB.StatusTab:Render() end)
    MB:On("STRATEGY_CLEAR_PENDING", function(event)
        local botName = MB.SelectedBot and MB.SelectedBot.botName
        if event and event.bot == botName then setClearControlsEnabled(MB.StatusTab.parent, false) end
    end)
    local function clearFinished()
        setClearControlsEnabled(MB.StatusTab.parent, true)
        MB.StatusTab:Render()
    end
    MB:On("STRATEGY_CLEAR_CONFIRMED", clearFinished)
    MB:On("STRATEGY_CLEAR_FAILED", clearFinished)
    return parent
end

function MB.StatusTab:Render()
    if not self.parent then return end
    local botName = MB.SelectedBot and MB.SelectedBot.botName
    setClearControlsEnabled(self.parent, botName ~= nil and not MB.StrategyService:IsClearing(botName))
    local bot = botName and MB.BotState:GetBot(botName)
    if not bot then return end
    local lines = { "|cffffcc00Combat strategies|r", table.concat(bot.strategies.co or {}, "\n"), "", "|cffffcc00Non-combat strategies|r", table.concat(bot.strategies.nc or {}, "\n"), "", "|cffffcc00Recommendation notices|r" }
    local warnings, warningLines = self:GetWarnings(botName), {}
    local i
    for i = 1, #warnings do table.insert(warningLines, "|cffffcc33" .. warnings[i].message .. "|r") end
    table.insert(lines, #warningLines > 0 and table.concat(warningLines, "\n") or "All active strategies match catalog recommendations.")
    table.insert(lines, ""); table.insert(lines, "|cffffcc00Recent operations|r")
    local history, historyLines = MB.BotState:GetOperationHistory(botName), {}
    local startAt = math.max(1, #history - 7)
    for i = startAt, #history do
        local operation = history[i]
        local line = (operation.status or "") .. ": " .. (operation.command or operation.strategy or "")
        if operation.message and operation.message ~= "" then line = line .. " - " .. operation.message end
        if operation.survivors and #operation.survivors > 0 then
            line = line .. " (survivors: " .. table.concat(operation.survivors, ", ") .. ")"
        end
        table.insert(historyLines, line)
    end
    if bot.lastError then table.insert(historyLines, "|cffff5555Last error: " .. bot.lastError .. "|r") end
    table.insert(lines, table.concat(historyLines, "\n"))
    local text = table.concat(lines, "\n")
    self.parent.detail:SetText(text)
    self.parent.content:SetHeight(math.max(360, 16 * (#lines + #(bot.strategies.co or {}) + #(bot.strategies.nc or {}) + #warningLines + #historyLines)))
end
