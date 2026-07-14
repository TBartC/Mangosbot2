local MB = Mangosbot

MB.Transport = {
    SEND_INTERVAL = 0.35,
    QUERY_TIMEOUT = 2.0,
    MAX_RETRIES = 1,
    queue = {},
    active = nil,
    lastSend = -100,
    clock = GetTime,
}

local function defaultSender(text, channel, target)
    if channel == "WHISPER" then
        SendChatMessage(text, channel, nil, target)
    else
        SendChatMessage(text, channel)
    end
end

MB.Transport.sender = defaultSender

function MB.Transport:New(clock, sender)
    local instance = {
        queue = {},
        active = nil,
        lastSend = -100,
        clock = clock or GetTime,
        sender = sender or defaultSender,
    }
    setmetatable(instance, { __index = self })
    return instance
end

function MB.Transport:Whisper(bot, command, expectation, callback)
    if not bot or bot == "" or not command or command == "" then
        return false
    end
    table.insert(self.queue, {
        bot = bot,
        command = command,
        channel = "WHISPER",
        expectation = expectation,
        callback = callback,
        retries = 0,
        queuedAt = self.clock(),
    })
    MB:Emit("OPERATION_QUEUED", { bot = bot, command = command })
    return true
end

function MB.Transport:Say(command, callback)
    if not command or command == "" then
        return false
    end
    table.insert(self.queue, {
        command = command,
        channel = "SAY",
        callback = callback,
        retries = 0,
        queuedAt = self.clock(),
    })
    MB:Emit("OPERATION_QUEUED", { command = command, channel = "SAY" })
    return true
end

function MB.Transport:Group(command)
    if not command or command == "" then
        return false
    end
    local channel = "PARTY"
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        channel = "RAID"
    end
    table.insert(self.queue, {
        command = command,
        channel = channel,
        retries = 0,
        queuedAt = self.clock(),
    })
    MB:Emit("OPERATION_QUEUED", { command = command, channel = channel })
    return true
end

local function matchesExpectation(expectation, event)
    if not expectation or not event then
        return false
    end
    local key, value
    for key, value in pairs(expectation) do
        if event[key] ~= value then
            return false
        end
    end
    return true
end

function MB.Transport:HandleEvent(event)
    if not self.active or not matchesExpectation(self.active.expectation, event) then
        return false
    end
    local operation = self.active
    self.active = nil
    MB:Emit("OPERATION_CONFIRMED", {
        bot = operation.bot,
        command = operation.command,
        event = event,
    })
    if operation.callback then
        operation.callback(true, event)
    end
    return true
end

function MB.Transport:FailActive(code, message)
    local operation = self.active
    if not operation then
        return false
    end
    self.active = nil
    local failure = { code = code, message = message, bot = operation.bot, command = operation.command }
    MB:Emit("OPERATION_FAILED", failure)
    if operation.callback then
        operation.callback(false, failure)
    end
    return true
end

function MB.Transport:Tick()
    local now = self.clock()

    if self.active and now - self.active.sentAt >= self.QUERY_TIMEOUT then
        local operation = self.active
        self.active = nil
        if operation.retries < self.MAX_RETRIES then
            operation.retries = operation.retries + 1
            table.insert(self.queue, 1, operation)
            MB:Emit("OPERATION_RETRY", {
                bot = operation.bot,
                command = operation.command,
                retry = operation.retries,
            })
        else
            self.active = operation
            self:FailActive("TIMEOUT", "Timed out waiting for " .. operation.bot)
        end
    end

    if self.active or #self.queue == 0 or now - self.lastSend < self.SEND_INTERVAL then
        return
    end

    local operation = table.remove(self.queue, 1)
    self.sender(operation.command, operation.channel or "WHISPER", operation.bot)
    self.lastSend = now
    operation.sentAt = now
    MB:Emit("OPERATION_SENT", {
        bot = operation.bot,
        command = operation.command,
        retry = operation.retries,
    })
    if operation.expectation then
        self.active = operation
    elseif operation.callback then
        operation.callback(true, { kind = "sent", bot = operation.bot })
    end
end

if CreateFrame then
    MB.Transport.frame = CreateFrame("Frame")
    MB.Transport.frame:SetScript("OnUpdate", function()
        MB.Transport:Tick()
    end)
end
