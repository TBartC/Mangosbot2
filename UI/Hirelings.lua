local MB = Mangosbot

MB.Hirelings = { frame = nil, rows = {}, filter = "", offset = 0 }

function MB.Hirelings:MatchesSearch(bot, search)
    search = string.lower(search or "")
    if search == "" then return true end
    local text = (bot.name or "") .. " " .. (bot.class or "") .. " " .. (bot.spec or "") .. " " .. (bot.role or "")
    return string.find(string.lower(text), search, 1, true) ~= nil
end

function MB.Hirelings:SetFilter(search)
    self.filter = search or ""
    MangosbotDB.hirelingFilter = self.filter
    self.offset = 0
    self:Render()
end

local function createRow(parent, index)
    local row = CreateFrame("Frame", "MangosbotHirelingRow" .. index, parent)
    row:SetWidth(390)
    row:SetHeight(24)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.text:SetWidth(300)
    row.text:SetJustifyH("LEFT")
    row.hire = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.hire:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.hire:SetWidth(65)
    row.hire:SetHeight(20)
    row.hire:SetText("Hire")
    return row
end

function MB.Hirelings:Create()
    if self.frame then return self.frame end
    local frame = MB.Widgets:CreatePanel("MangosbotHirelingsFrame", UIParent, 430, 360)
    MB.Widgets:RestorePosition(frame, "hirelings", "CENTER", 180, 0)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -16)
    frame.title:SetText("Public Hirelings")
    frame.refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.refresh:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -42, -12)
    frame.refresh:SetWidth(65)
    frame.refresh:SetHeight(22)
    frame.refresh:SetText("Refresh")
    frame.refresh:SetScript("OnClick", function() MB.RosterService:Refresh() end)
    MB.Widgets:AddCloseButton(frame, "hirelings")
    frame.search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.search:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -42); frame.search:SetWidth(200); frame.search:SetHeight(20); frame.search:SetAutoFocus(false)
    self.filter = (MB.SavedVariables:Get() and MB.SavedVariables:Get().hirelingFilter) or ""
    frame.search:SetText(self.filter)
    frame.search:SetScript("OnTextChanged", function()
        MB.Hirelings:SetFilter(frame.search:GetText())
    end)
    local i
    for i = 1, 11 do
        local row = createRow(frame, i)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -68 - ((i - 1) * 25))
        self.rows[i] = row
    end
    frame.scrollBar = MB.Widgets:CreateListScrollBar(frame, "MangosbotHirelingsScrollBar", -68, 36, function(offset)
        MB.Hirelings.offset = offset; MB.Hirelings:Render()
    end)
    self.frame = frame
    MB:On("HIRELINGS_CHANGED", function() MB.Hirelings:Render() end)
    return frame
end

function MB.Hirelings:Render()
    if not self.frame then return end
    local source = MB.BotState:GetHirelings()
    local visible = {}
    local i, bot
    for i = 1, #source do
        bot = source[i]
        if self:MatchesSearch(bot, self.filter) then
            table.insert(visible, bot)
        end
    end
    local row, color
    self.offset = MB.Widgets:UpdateListScrollBar(self.frame.scrollBar, self.offset, #visible, #self.rows)
    for i = 1, #self.rows do
        row = self.rows[i]
        bot = visible[self.offset + i]
        if bot then
            row.botName = bot.name
            row.text:SetText(bot.name .. "  " .. (bot.class or "") .. "  " .. (bot.spec or "") .. "  " .. (bot.role or ""))
            color = MB.Widgets:GetClassColor(bot.class)
            row.text:SetTextColor(color[1], color[2], color[3])
            local rowRef = row
            row.hire:SetScript("OnClick", function() MB.RosterService:Hire(rowRef.botName) end)
            row:Show()
        else
            row.botName = nil
            row:Hide()
        end
    end
end

function MB.Hirelings:Toggle()
    local frame = self:Create()
    if frame:IsVisible() then frame:Hide(); MB.SavedVariables:SetWindowVisible("hirelings", false)
    else frame:Show(); MB.SavedVariables:SetWindowVisible("hirelings", true); self:Render(); MB.RosterService:Refresh() end
end
