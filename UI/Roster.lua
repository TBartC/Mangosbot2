local MB = Mangosbot

MB.Roster = { frame = nil, rows = {}, offset = 0, pendingDismiss = nil }

function MB.Roster:BeginDismissConfirmation(name)
    if type(name) ~= "string" or name == "" then return false end
    if self.pendingDismiss ~= nil then return false end
    self.pendingDismiss = name
    StaticPopup_Show("MANGOSBOT_CONFIRM_DISMISS", name)
    return true
end

function MB.Roster:CancelPendingDismiss()
    self.pendingDismiss = nil
end

function MB.Roster:AcceptPendingDismiss()
    local name = self.pendingDismiss
    self.pendingDismiss = nil
    if type(name) ~= "string" or name == "" then return false end
    DEFAULT_CHAT_FRAME:AddMessage("|cff55ccffMangosbot dismissing " .. name .. "...|r")
    MB.RosterService:Dismiss(name)
    return true
end

local function createRow(parent, index)
    local row = CreateFrame("Button", "MangosbotRosterRow" .. index, parent)
    row:SetWidth(282)
    row:SetHeight(28)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.nameText:SetWidth(88)
    row.nameText:SetJustifyH("LEFT")
    row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.statusText:SetPoint("LEFT", row.nameText, "RIGHT", 4, 0)
    row.statusText:SetWidth(52)
    row.statusText:SetJustifyH("LEFT")
    row.login = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.login:SetPoint("LEFT", row.statusText, "RIGHT", 2, 0)
    row.login:SetWidth(42)
    row.login:SetHeight(20)
    row.group = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.group:SetPoint("LEFT", row.login, "RIGHT", 2, 0)
    row.group:SetWidth(42); row.group:SetHeight(20)
    row.dismiss = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.dismiss:SetPoint("LEFT", row.group, "RIGHT", 2, 0)
    row.dismiss:SetWidth(24); row.dismiss:SetHeight(20); row.dismiss:SetText("X")
    return row
end

function MB.Roster:Create()
    if self.frame then return self.frame end
    local frame = MB.Widgets:CreatePanel("MangosbotRosterFrame", UIParent, 310, 370)
    MB.Widgets:RestorePosition(frame, "roster", "CENTER", -300, 0)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -16)
    frame.title:SetText("Mangosbot Team")
    frame.refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.refresh:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -42, -12)
    frame.refresh:SetWidth(65)
    frame.refresh:SetHeight(22)
    frame.refresh:SetText("Refresh")
    frame.refresh:SetScript("OnClick", function() MB.RosterService:Refresh() end)
    MB.Widgets:AddCloseButton(frame, "roster")
    frame.hirelings = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.hirelings:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 14)
    frame.hirelings:SetWidth(90)
    frame.hirelings:SetHeight(22)
    frame.hirelings:SetText("Hirelings")
    frame.hirelings:SetScript("OnClick", function() MB.Hirelings:Toggle() end)
    frame.hideAlts = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.hideAlts:SetPoint("LEFT", frame.hirelings, "RIGHT", 8, 0)
    frame.hideAlts:SetWidth(90)
    frame.hideAlts:SetHeight(22)
    frame.hideAlts:SetScript("OnClick", function()
        local db = MB.SavedVariables:Get()
        MB.SavedVariables:SetHideAlts(not db.hideAlts)
        MB.Roster.offset = 0
        MB.Roster:Render()
    end)
    StaticPopupDialogs["MANGOSBOT_CONFIRM_DISMISS"] = {
        text = "Dismiss %s as a hireling?",
        button1 = "Dismiss", button2 = "Cancel", timeout = 0, whileDead = 1, hideOnEscape = 1,
        OnAccept = function() MB.Roster:AcceptPendingDismiss() end,
        OnCancel = function() MB.Roster:CancelPendingDismiss() end,
        OnHide = function() MB.Roster:CancelPendingDismiss() end,
    }
    local i
    for i = 1, 10 do
        local row = createRow(frame, i)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -44 - ((i - 1) * 29))
        self.rows[i] = row
    end
    frame.scrollBar = MB.Widgets:CreateListScrollBar(frame, "MangosbotRosterScrollBar", -48, 48, function(offset)
        MB.Roster.offset = offset; MB.Roster:Render()
    end)
    self.frame = frame
    MB:On("ROSTER_CHANGED", function() MB.Roster:Render() end)
    return frame
end

function MB.Roster:Render()
    if not self.frame then return end
    local db = MB.SavedVariables:Get()
    local roster = MB.BotState:GetVisibleRoster(db and db.hideAlts)
    self.frame.hideAlts:SetText(db and db.hideAlts and "Show Alts" or "Hide Alts")
    self.offset = MB.Widgets:UpdateListScrollBar(self.frame.scrollBar, self.offset, #roster, #self.rows)
    local i, row, bot, color
    for i = 1, #self.rows do
        row = self.rows[i]
        bot = roster[self.offset + i]
        if bot then
            row.botName = bot.name
            color = MB.Widgets:GetClassColor(bot.class)
            row.nameText:SetText(bot.name)
            row.nameText:SetTextColor(color[1], color[2], color[3])
            row.statusText:SetText((bot.online and "Online" or "Offline") .. (bot.role and (" • " .. bot.role) or ""))
            local rowRef = row
            local online = bot.online
            row:SetScript("OnClick", function() MB.BotState:Select(rowRef.botName) end)
            row.login:SetText(bot.online and "Logout" or "Login")
            row.login:SetScript("OnClick", function()
                if online then MB.RosterService:Logout(rowRef.botName) else MB.RosterService:Login(rowRef.botName) end
            end)
            local grouped = MB.RosterService:IsGrouped(bot.name)
            row.group:SetText(grouped and "Leave" or "Invite")
            row.group:SetScript("OnClick", function()
                if grouped then MB.RosterService:Leave(rowRef.botName) else MB.RosterService:Invite(rowRef.botName) end
            end)
            row.dismiss:SetScript("OnClick", function()
                MB.Roster:BeginDismissConfirmation(rowRef.botName)
            end)
            row:Show()
        else
            row.botName = nil
            row:Hide()
        end
    end
end

function MB.Roster:Toggle()
    local frame = self:Create()
    if frame:IsVisible() then frame:Hide(); MB.SavedVariables:SetWindowVisible("roster", false)
    else frame:Show(); MB.SavedVariables:SetWindowVisible("roster", true); self:Render() end
end
