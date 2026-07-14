local MB = Mangosbot

MB.SelfTest = { tests = {}, failures = 0 }

function MB.SelfTest:Add(name, testFunction)
    table.insert(self.tests, { name = name, fn = testFunction })
end

function MB.SelfTest:Equal(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
    end
end

function MB.SelfTest:Run()
    self.failures = 0
    local i
    for i = 1, #self.tests do
        local test = self.tests[i]
        local ok, err = pcall(test.fn)
        if not ok then
            self.failures = self.failures + 1
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555FAIL " .. test.name .. ": " .. tostring(err) .. "|r")
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("Mangosbot self-tests: " .. (#self.tests - self.failures) .. " passed, " .. self.failures .. " failed")
    return self.failures
end

MB.SelfTest:Add("selected bot remains pinned", function()
    MB.BotState:Select("Fael")
    MB.SelfTest:Equal(MB.BotState:GetSelectedName(), "Fael")
end)

MB.SelfTest:Add("strategy lists are copied", function()
    local source = { "fire pve" }
    MB.BotState:SetStrategies("Fael", "co", source)
    source[1] = "changed"
    MB.SelfTest:Equal(MB.BotState:GetBot("Fael").strategies.co[1], "fire pve")
end)
