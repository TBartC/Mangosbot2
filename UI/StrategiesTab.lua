local MB = Mangosbot

MB.StrategiesTab = { parent = nil, rows = {}, offset = 0, filtered = {} }

function MB.StrategiesTab:DefaultFilters()
    return { search = "", family = "ALL", mode = "ALL", kind = "ALL", role = "ALL", activeOnly = false, showIncompatible = false }
end

local function activeInEitherFamily(botName, name)
    return MB.BotState:HasStrategy(botName, "co", name) or MB.BotState:HasStrategy(botName, "nc", name)
end

function MB.StrategiesTab:Matches(botName, definition, filters)
    local bot = MB.BotState:GetBot(botName)
    local search = string.lower(filters.search or "")
    if search ~= "" and not string.find(string.lower(definition.name), search, 1, true) then return false end
    if filters.family ~= "ALL" and definition.family ~= filters.family then return false end
    if filters.mode ~= "ALL" and definition.mode ~= filters.mode and definition.mode ~= "General" then return false end
    if filters.kind ~= "ALL" and definition.kind ~= filters.kind then return false end
    if filters.role ~= "ALL" and definition.role ~= filters.role then return false end
    if filters.activeOnly and not activeInEitherFamily(botName, definition.name) then return false end
    if not filters.showIncompatible and not MB.StrategyService:IsClassCompatible(definition, bot and bot.class) then return false end
    return true
end

function MB.StrategiesTab:GetFiltered(botName, filters)
    local result = {}
    local i, definition
    filters = filters or self:DefaultFilters()
    for i = 1, #(MB.StrategyCatalog.all or {}) do
        definition = MB.StrategyCatalog.all[i]
        if self:Matches(botName, definition, filters) then table.insert(result, definition) end
    end
    table.sort(result, function(left, right) return string.lower(left.name) < string.lower(right.name) end)
    return result
end

function MB.StrategiesTab:GetToggleFamilies(definition)
    if not definition then return {} end
    return { "co", "nc" }
end

function MB.StrategiesTab:IsRecommendedFamily(definition, family)
    if not definition then return false end
    if definition.family == "BOTH" or definition.family == "REVIEW" then return true end
    return definition.family == string.upper(family)
end

function MB.StrategiesTab:IsSuspicious(strategyName, family)
    local definition = MB.StrategyCatalog.byName[strategyName]
    if not definition then return false end
    if definition.family == "CO" then return family ~= "co" end
    if definition.family == "NC" then return family ~= "nc" end
    return false
end

function MB.StrategiesTab:GetDisplayState(botName, definition, family)
    if definition.name == "default" and MB.BotState:HasStrategy(botName, family, definition.name) then return "protected" end
    local operation = MB.BotState:GetStrategyOperation(botName, family, definition.name)
    if operation and operation.status == "failed" then return "failed" end
    if operation and operation.status == "pending" then
        return operation.desiredActive and "pending-add" or "pending-remove"
    end
    return MB.BotState:HasStrategy(botName, family, definition.name) and "active" or "inactive"
end

local function createRow(parent, index)
    local row = CreateFrame("Frame", "MangosbotStrategyRow" .. index, parent)
    row:SetWidth(450); row:SetHeight(30)
    row:EnableMouse(true)
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -2); row.nameText:SetWidth(270); row.nameText:SetJustifyH("LEFT")
    row.metaText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.metaText:SetPoint("TOPLEFT", row.nameText, "BOTTOMLEFT", 0, -1); row.metaText:SetWidth(330); row.metaText:SetJustifyH("LEFT")
    row.co = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.co:SetPoint("RIGHT", row, "RIGHT", -42, 0); row.co:SetWidth(36); row.co:SetHeight(18)
    row.nc = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.nc:SetPoint("RIGHT", row, "RIGHT", -4, 0); row.nc:SetWidth(36); row.nc:SetHeight(18)
    row:SetScript("OnEnter", function()
        if row.tooltip then GameTooltip:SetOwner(row, "ANCHOR_RIGHT"); GameTooltip:SetText(row.tooltip, 1, 0.82, 0); GameTooltip:Show() end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function distinctValues(field)
    local seen, values = {}, { "ALL" }
    local i, value
    for i = 1, #(MB.StrategyCatalog.all or {}) do
        value = MB.StrategyCatalog.all[i][field]
        if value and value ~= "" and not seen[value] then seen[value] = true; table.insert(values, value) end
    end
    table.sort(values, function(left, right)
        if left == "ALL" then return true end
        if right == "ALL" then return false end
        return left < right
    end)
    return values
end

local function createCycleFilter(parent, label, x, values, field)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -36); button:SetWidth(108); button:SetHeight(20)
    button.valueIndex = 1
    local i
    for i = 1, #values do if values[i] == MB.StrategiesTab.filters[field] then button.valueIndex = i end end
    button:SetText(label .. ": " .. values[button.valueIndex])
    button:SetScript("OnClick", function()
        button.valueIndex = button.valueIndex + 1
        if button.valueIndex > #values then button.valueIndex = 1 end
        MB.StrategiesTab.filters[field] = values[button.valueIndex]
        MB.SavedVariables:SetStrategyFilter(field, values[button.valueIndex])
        button:SetText(label .. ": " .. values[button.valueIndex]); MB.StrategiesTab.offset = 0; MB.StrategiesTab:Render()
    end)
    return button
end


function MB.StrategiesTab:Create(parent)
    if self.parent then return self.parent end
    self.parent, self.filters = parent, self:DefaultFilters()
    local saved = MB.SavedVariables:Get() and MB.SavedVariables:Get().strategyFilters or {}
    local savedKey, savedValue
    for savedKey, savedValue in pairs(saved) do self.filters[savedKey] = savedValue end
    parent.search = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    parent.search:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8); parent.search:SetWidth(220); parent.search:SetHeight(22); parent.search:SetAutoFocus(false); parent.search:SetText(self.filters.search or "")
    parent.search:SetScript("OnTextChanged", function()
        MB.StrategiesTab.filters.search = parent.search:GetText() or ""; MB.StrategiesTab.offset = 0
        MB.SavedVariables:SetStrategyFilter("search", MB.StrategiesTab.filters.search); MB.StrategiesTab:Render()
    end)
    parent.activeOnly = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    parent.activeOnly:SetPoint("LEFT", parent.search, "RIGHT", 12, 0)
    parent.activeOnly:SetChecked(self.filters.activeOnly)
    parent.activeOnly:SetScript("OnClick", function()
        MB.StrategiesTab.filters.activeOnly = parent.activeOnly:GetChecked() and true or false
        MB.SavedVariables:SetStrategyFilter("activeOnly", MB.StrategiesTab.filters.activeOnly); MB.StrategiesTab:Render()
    end)
    parent.activeLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    parent.activeLabel:SetPoint("LEFT", parent.activeOnly, "RIGHT", 0, 0); parent.activeLabel:SetText("Active only")
    parent.showIncompatible = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    parent.showIncompatible:SetPoint("LEFT", parent.activeLabel, "RIGHT", 12, 0)
    parent.showIncompatible:SetChecked(self.filters.showIncompatible)
    parent.showIncompatible:SetScript("OnClick", function()
        self.filters.showIncompatible = parent.showIncompatible:GetChecked() and true or false
        MB.SavedVariables:SetStrategyFilter("showIncompatible", self.filters.showIncompatible); self:Render()
    end)
    parent.allLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    parent.allLabel:SetPoint("LEFT", parent.showIncompatible, "RIGHT", 0, 0); parent.allLabel:SetText("All classes")
    parent.familyFilter = createCycleFilter(parent, "Family", 8, { "ALL", "CO", "NC", "BOTH", "REVIEW", "BLOCKED" }, "family")
    parent.modeFilter = createCycleFilter(parent, "Mode", 120, { "ALL", "General", "PVE", "PVP", "RAID" }, "mode")
    parent.kindFilter = createCycleFilter(parent, "Kind", 232, distinctValues("kind"), "kind")
    parent.roleFilter = createCycleFilter(parent, "Role", 344, distinctValues("role"), "role")
    local i, row
    for i = 1, 10 do
        row = createRow(parent, i); row:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -62 - ((i - 1) * 32)); self.rows[i] = row
    end
    parent.scrollBar = MB.Widgets:CreateListScrollBar(parent, "MangosbotStrategiesScrollBar", -62, 34, function(offset)
        MB.StrategiesTab.offset = offset; MB.StrategiesTab:Render()
    end)
    parent.count = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); parent.count:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 8, 10)
    MB:On("BOT_STRATEGIES_CHANGED", function() MB.StrategiesTab:Render() end)
    MB:On("STRATEGY_OPERATION_CHANGED", function() MB.StrategiesTab:Render() end)
    return parent
end

function MB.StrategiesTab:SetToggle(button, botName, definition, family)
    if not family then button:Hide(); return end
    button:Show()
    local state = self:GetDisplayState(botName, definition, family)
    local active = MB.BotState:HasStrategy(botName, family, definition.name)
    if state == "pending-add" or state == "pending-remove" then button:SetText("..."); button:Disable()
    elseif state == "protected" then button:SetText("LOCK"); button:Disable()
    elseif state == "incompatible" or state == "blocked" then button:SetText("N/A"); button:Disable()
    elseif state == "failed" then button:SetText("ERR"); button:Enable()
    else
        local marker = self:IsRecommendedFamily(definition, family) and "" or "*"
        button:SetText(marker .. (active and "-" or "+") .. string.upper(family)); button:Enable()
    end
    button:SetScript("OnClick", function() MB.StrategyService:Toggle(botName, definition.name, family) end)
end

function MB.StrategiesTab:Render()
    if not self.parent then return end
    local botName = MB.SelectedBot and MB.SelectedBot.botName
    local bot = botName and MB.BotState:GetBot(botName)
    if not bot then return end
    self.filtered = self:GetFiltered(botName, self.filters)
    self.offset = MB.Widgets:UpdateListScrollBar(self.parent.scrollBar, self.offset, #self.filtered, #self.rows)
    local i, row, definition, families
    for i = 1, #self.rows do
        row, definition = self.rows[i], self.filtered[self.offset + i]
        if definition then
            families = self:GetToggleFamilies(definition)
            row.nameText:SetText(definition.name)
            row.metaText:SetText(definition.family .. " / " .. definition.mode .. " / " .. definition.kind .. (definition.family == "REVIEW" and " / choose family carefully" or ""))
            row.tooltip = definition.name .. "\nFamily: " .. definition.family .. "  Mode: " .. definition.mode
                .. "\nClasses: " .. table.concat(definition.classes or {}, ", ")
                .. (definition.base ~= "" and ("\nBase package: " .. definition.base) or "")
                .. "\n\n" .. definition.description .. "\nConfidence: " .. definition.confidence
                .. (definition.notes ~= "" and ("\n" .. definition.notes) or "")
            local coOperation = MB.BotState:GetStrategyOperation(botName, "co", definition.name)
            local ncOperation = MB.BotState:GetStrategyOperation(botName, "nc", definition.name)
            local failedOperation = coOperation and coOperation.status == "failed" and coOperation or ncOperation and ncOperation.status == "failed" and ncOperation
            if failedOperation then row.tooltip = row.tooltip .. "\n|cffff5555Last failure: " .. (failedOperation.message or failedOperation.code or "unknown") .. "|r" end
            self:SetToggle(row.co, botName, definition, families[1]); self:SetToggle(row.nc, botName, definition, families[2]); row:Show()
        else row:Hide() end
    end
    self.parent.count:SetText(tostring(#self.filtered) .. " strategies")
end
