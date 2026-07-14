local MB = Mangosbot

MB.SelectedBot = {
    frame = nil,
    botName = nil,
    activeTab = "command",
    tabs = {},
    panels = {},
}

local TAB_ORDER = {
    { key = "command", label = "Command" },
    { key = "setup", label = "Setup" },
    { key = "strategies", label = "Strategies" },
    { key = "status", label = "Status" },
}

function MB.SelectedBot:SetBot(name)
    self.botName = name
    if MangosbotDB then MangosbotDB.selectedBotName = name end
    if self.frame and self.frame.title then
        self.frame.title:SetText(name and ("Bot: " .. name) or "No bot selected")
    end
    MB:Emit("PINNED_BOT_CHANGED", { bot = name })
    return name
end

function MB.SelectedBot:Refresh()
    local bot = self.botName
    if not bot then return { ok = false, code = "NO_BOT" } end
    MB.Transport:Whisper(bot, "co ?", { kind = "strategies", bot = bot, family = "co" }, nil)
    MB.Transport:Whisper(bot, "nc ?", { kind = "strategies", bot = bot, family = "nc" }, nil)
    return { ok = true, bot = bot }
end

function MB.SelectedBot:RunAction(key)
    return MB.ActionService:RunForBot(self.botName, key)
end

function MB.SelectedBot:ShowTab(key)
    local panelKey, panel
    for panelKey, panel in pairs(self.panels) do
        if panelKey == key then panel:Show() else panel:Hide() end
    end
    self.activeTab = key
    MB:Emit("SELECTED_TAB_CHANGED", { tab = key, bot = self.botName })
end

function MB.SelectedBot:Create()
    if self.frame then return self.frame end
    local frame = MB.Widgets:CreatePanel("MangosbotSelectedBotFrame", UIParent, 520, 500)
    MB.Widgets:RestorePosition(frame, "selectedBot", "CENTER", 120, 0)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -16)
    frame.title:SetText("No bot selected")
    frame.refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.refresh:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -42, -12)
    frame.refresh:SetWidth(65)
    frame.refresh:SetHeight(22)
    frame.refresh:SetText("Refresh")
    frame.refresh:SetScript("OnClick", function() MB.SelectedBot:Refresh() end)
    MB.Widgets:AddCloseButton(frame, "selectedBot")

    local i, definition, tab, panel
    for i = 1, #TAB_ORDER do
        definition = TAB_ORDER[i]
        local tabKey = definition.key
        tab = MB.Widgets:CreateTab("MangosbotSelectedTab" .. i, frame, definition.label, function()
            MB.SelectedBot:ShowTab(tabKey)
        end)
        tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + ((i - 1) * 86), -42)
        self.tabs[tabKey] = tab
        panel = CreateFrame("Frame", nil, frame)
        panel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -70)
        panel:SetWidth(488)
        panel:SetHeight(410)
        panel:Hide()
        self.panels[tabKey] = panel
    end

    self.frame = frame
    MB.CommandTab:Create(self.panels.command)
    if MB.SetupTab then MB.SetupTab:Create(self.panels.setup) end
    if MB.StrategiesTab then MB.StrategiesTab:Create(self.panels.strategies) end
    if MB.StatusTab then MB.StatusTab:Create(self.panels.status) end
    self:ShowTab("command")
    frame:Hide()
    return frame
end

function MB.SelectedBot:Open(name)
    local frame = self:Create()
    self:SetBot(name)
    frame:Show()
    MB.SavedVariables:SetWindowVisible("selectedBot", true)
    self:Refresh()
end

MB:On("SELECTED_BOT_CHANGED", function(event)
    if event and event.bot then
        MB.SelectedBot:Open(event.bot)
    else
        MB.SelectedBot:SetBot(nil)
        if MB.SelectedBot.frame then MB.SelectedBot.frame:Hide() end
        if MB.SavedVariables and MB.SavedVariables.db then
            MB.SavedVariables:SetWindowVisible("selectedBot", false)
        end
    end
end)
