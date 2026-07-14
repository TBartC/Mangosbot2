local MB = Mangosbot

MB.SetupTab = {
    parent = nil,
    mode = "PVE",
    buttons = {},
    helperButtons = {},
    modeButtons = {},
}

function MB.SetupTab:GetHelpers(bundle)
    local result, seen = {}, {}
    local fields = {
        { key = "buff", label = "Buff/Form" }, { key = "aoe", label = "AOE" },
        { key = "boost", label = "Boost" }, { key = "cure", label = "Cure" },
        { key = "offheal", label = "Off-heal" }, { key = "offdps", label = "Off-DPS" },
        { key = "stealth", label = "Stealth" }, { key = "cc", label = "CC / Fear", dangerous = true },
    }
    local i, definition, name
    for i = 1, #fields do
        definition = fields[i]; name = bundle and bundle[definition.key]
        if name and name ~= "" and not seen[name] then
            seen[name] = true
            table.insert(result, { name = name, label = definition.label, dangerous = definition.dangerous and true or false })
        end
    end
    return result
end

function MB.SetupTab:GetBundles(className, mode)
    local result = {}
    local key, bundle, i
    className = string.lower(className or "")
    for key, bundle in pairs(MB.PackageBundles or {}) do
        if bundle.mode == mode then
            for i = 1, #(bundle.classes or {}) do
                if bundle.classes[i] == className then
                    bundle.key = key
                    table.insert(result, bundle)
                    break
                end
            end
        end
    end
    table.sort(result, function(left, right) return left.base < right.base end)
    return result
end

function MB.SetupTab:SetMode(mode)
    if mode ~= "PVE" and mode ~= "PVP" and mode ~= "RAID" then return false end
    self.mode = mode
    self:Render()
    return true
end

function MB.SetupTab:Create(parent)
    if self.parent then return self.parent end
    self.parent = parent
    local modes = { "PVE", "PVP", "RAID" }
    local i, mode, button
    for i = 1, #modes do
        mode = modes[i]
        local selectedMode = mode
        button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", 8 + ((i - 1) * 84), -8)
        button:SetWidth(76)
        button:SetHeight(22)
        button:SetText(mode)
        button:SetScript("OnClick", function() MB.SetupTab:SetMode(selectedMode) end)
        self.modeButtons[mode] = button
    end
    parent.help = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    parent.help:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -38)
    parent.help:SetWidth(450)
    parent.help:SetJustifyH("LEFT")
    parent.help:SetText("Choose a safe package. CC and fear helpers remain optional and are not enabled automatically.")
    for i = 1, 9 do
        button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -64 - ((i - 1) * 34))
        button:SetWidth(285)
        button:SetHeight(28)
        button:Hide()
        self.buttons[i] = button
    end
    for i = 1, 8 do
        button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", 305, -64 - ((i - 1) * 34))
        button:SetWidth(170); button:SetHeight(28); button:Hide(); self.helperButtons[i] = button
    end
    parent.progress = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    parent.progress:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 8, 10); parent.progress:SetWidth(450); parent.progress:SetJustifyH("LEFT")
    MB:On("BUNDLE_APPLY_STARTED", function(plan) parent.progress:SetText("Applying package: 0 / " .. tostring(#plan.steps)) end)
    MB:On("STRATEGY_TOGGLE_CONFIRMED", function() parent.progress:SetText("Package step confirmed...") end)
    MB:On("BUNDLE_APPLY_COMPLETED", function(plan) parent.progress:SetText("|cff55ff55Package applied and verified: " .. plan.bundleKey .. "|r") end)
    MB:On("BUNDLE_APPLY_FAILED", function(plan) parent.progress:SetText("|cffff5555Package stopped: " .. (plan.message or plan.code or "failed") .. "|r") end)
    MB:On("BUNDLE_APPLY_STARTED", function() for _, value in pairs(MB.SetupTab.buttons) do value:Disable() end end)
    MB:On("BUNDLE_APPLY_COMPLETED", function() for _, value in pairs(MB.SetupTab.buttons) do value:Enable() end end)
    MB:On("BUNDLE_APPLY_FAILED", function() for _, value in pairs(MB.SetupTab.buttons) do value:Enable() end end)
    MB:On("PINNED_BOT_CHANGED", function() MB.SetupTab:Render() end)
    return parent
end

function MB.SetupTab:Render()
    if not self.parent then return end
    local botName = MB.SelectedBot and MB.SelectedBot.botName
    local bot = botName and MB.BotState:GetBot(botName)
    local bundles = bot and self:GetBundles(bot.class, self.mode) or {}
    local i, button, bundle
    for i = 1, #self.buttons do
        button = self.buttons[i]
        bundle = bundles[i]
        if bundle then
            local key = bundle.key
            button:SetText(bundle.base .. "  (" .. (bundle.role or "") .. ")")
            button:SetScript("OnClick", function()
                MB.SetupTab.selectedBundleKey = key
                MB.StrategyService:ApplyBundle(MB.SelectedBot.botName, key)
                MB.SetupTab:Render()
            end)
            button:Show()
        else
            button:Hide()
        end
    end
    local selected = self.selectedBundleKey and MB.PackageBundles[self.selectedBundleKey]
    if not selected or not bot or not self.selectedBundleKey or not string.find(self.selectedBundleKey, string.lower(bot.class or ""), 1, true) then
        selected = bundles[1]; self.selectedBundleKey = selected and selected.key or nil
    end
    local helpers = self:GetHelpers(selected)
    local helper, definition, family
    for i = 1, #self.helperButtons do
        button, helper = self.helperButtons[i], helpers[i]
        if helper then
            definition = MB.StrategyCatalog.byName[helper.name]
            family = definition and definition.family == "NC" and "nc" or "co"
            local helperName, helperFamily = helper.name, family
            button:SetText((helper.dangerous and "! " or "") .. helper.label)
            button:SetScript("OnClick", function() MB.StrategyService:Toggle(MB.SelectedBot.botName, helperName, helperFamily) end)
            button:Show()
        else button:Hide() end
    end
    if selected then
        self.parent.help:SetText("Safe bundle: " .. table.concat(selected.safe or {}, ", ") .. ". ! controls are optional CC/fear and may be dangerous in dungeons.")
    end
end
