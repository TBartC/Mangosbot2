local MB = Mangosbot

BINDING_HEADER_MANGOSBOT = "Mangosbot"
BINDING_NAME_ROSTER = "Toggle Mangosbot roster"
BINDING_NAME_DEBUG = "Run Mangosbot self-tests"
BINDING_NAME_FOLLOW = "Bots follow"
BINDING_NAME_STAY = "Bots stay"
BINDING_NAME_PASSIVE = "Bots passive"
BINDING_NAME_FLEE = "Bots flee"
BINDING_NAME_LOOT = "Bots loot"
BINDING_NAME_ATTACK = "Bots attack target"
BINDING_NAME_PULL = "Tank pull"

function MB:HandleWhisper(message, sender)
    local parsed = self.Parser:ParseWhisper(message, sender)
    if not parsed then return false end
    if parsed.kind == "strategies" then
        self.BotState:SetStrategies(parsed.bot, parsed.family, parsed.strategies)
        self.Transport:HandleEvent(parsed)
    elseif parsed.kind == "status" then
        local fields = {}; fields[parsed.field] = parsed.value
        self.BotState:UpdateBot(parsed.bot, fields)
    end
    return true
end

function MB:HandleSystem(message)
    local parsed = self.Parser:ParseSystem(message)
    if not parsed then return false end
    if parsed.kind == "roster" then
        self.BotState:ApplyRoster(parsed.entries)
    elseif parsed.kind == "hirelings" then
        self.BotState:ApplyHirelings(parsed.entries)
    elseif parsed.kind == "bot_dismissed" then
        self.BotState:DismissBot(parsed.bot)
        if self.RosterService then self.RosterService:Refresh() end
    elseif parsed.kind == "dismiss_failed" and self.RosterService then
        self.RosterService:Refresh()
    elseif parsed.kind == "roster_changed" and self.RosterService then
        self.RosterService:Refresh()
    end
    return true
end

function MB:Initialize()
    local db = self.SavedVariables:Initialize()
    local i, name
    for i = 1, #(db.knownHirelings or {}) do
        name = db.knownHirelings[i]
        self.BotState.knownHirelings[name] = true
        self.BotState:EnsureBot(name)
    end
    self.Roster:Create()
    self.Hirelings:Create()
    self.SelectedBot:Create()
    self.GroupBar:Create()
    if db.windows.roster.visible then self.Roster.frame:Show() else self.Roster.frame:Hide() end
    if db.windows.groupBar.visible then self.GroupBar.frame:Show() else self.GroupBar.frame:Hide() end
    if db.windows.hirelings.visible then self.Hirelings.frame:Show(); self.Hirelings:Render() else self.Hirelings.frame:Hide() end
    if db.windows.selectedBot.visible and db.selectedBotName then
        self.BotState:EnsureBot(db.selectedBotName)
        self.SelectedBot:Open(db.selectedBotName)
    else
        self.SelectedBot.frame:Hide()
    end
    self.RosterService:Refresh()
    DEFAULT_CHAT_FRAME:AddMessage("|cff55ccffMangosbot " .. self.VERSION .. " loaded. Use /bot to toggle the roster.|r")
end

SLASH_MANGOSBOT1 = "/bot"
SlashCmdList = SlashCmdList or {}
SlashCmdList.MANGOSBOT = function(message)
    local command = MB:Trim(message or "")
    if command == "" or command == "roster" then
        MB.Roster:Toggle()
    elseif command == "group" then
        MB.GroupBar:Toggle()
    elseif command == "hirelings" then
        MB.Hirelings:Toggle()
    elseif command == "refresh" then
        MB.RosterService:Refresh()
    elseif command == "selftest" or command == "debug" then
        MB.SelfTest:Run()
    elseif command == "status" then
        if MB.SelectedBot.botName then MB.SelectedBot:Open(MB.SelectedBot.botName) end
    else
        DEFAULT_CHAT_FRAME:AddMessage("Mangosbot: /bot, /bot group, /bot hirelings, /bot refresh, /bot status, /bot selftest")
    end
end

local eventFrame = CreateFrame("Frame", "MangosbotEventFrame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
eventFrame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        MB:Initialize()
    elseif event == "CHAT_MSG_WHISPER" then
        MB:HandleWhisper(arg1, arg2)
    elseif event == "CHAT_MSG_SYSTEM" then
        MB:HandleSystem(arg1)
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        MB.RosterService:Refresh()
    end
end)
