local MB = Mangosbot

MB.GroupBar = {
    frame = nil,
    buttons = {},
    ACTION_KEYS = {
        "follow", "stay", "attack", "pull", "flee", "passive", "loot",
        "summon", "formation_near", "formation_arrow", "formation_chaos",
    },
}

function MB.GroupBar:Create()
    if self.frame then return self.frame end
    local frame = MB.Widgets:CreatePanel("MangosbotGroupBarFrame", UIParent, 500, 58)
    MB.Widgets:RestorePosition(frame, "groupBar", "BOTTOM", 0, 120)
    MB.Widgets:AddCloseButton(frame, "groupBar")
    local i, key, definition, button
    for i = 1, #self.ACTION_KEYS do
        key = self.ACTION_KEYS[i]
        definition = MB.Actions.group[key]
        local actionKey = key
        button = MB.Widgets:CreateIconButton(
            "MangosbotGroupButton" .. i,
            frame,
            34,
            definition.icon,
            "Group: " .. definition.label .. "\n" .. definition.tooltip,
            function() MB.ActionService:RunGroup(actionKey) end
        )
        button:SetPoint("LEFT", frame, "LEFT", 12 + ((i - 1) * 41), 0)
        self.buttons[key] = button
    end
    self.frame = frame
    return frame
end

function MB.GroupBar:Toggle()
    local frame = self:Create()
    if frame:IsVisible() then frame:Hide(); MB.SavedVariables:SetWindowVisible("groupBar", false)
    else frame:Show(); MB.SavedVariables:SetWindowVisible("groupBar", true) end
end
