local MB = Mangosbot

MB.CommandTab = {
    buttons = {},
    ACTION_KEYS = {
        "stats", "follow", "stay", "flee", "guard", "grind", "passive",
        "loot", "set_guard", "release", "revive", "summon", "inventory",
        "bank", "spells", "mail", "formation_near", "formation_melee",
        "formation_arrow", "formation_chaos", "formation_line",
        "formation_queue", "formation_circle",
    },
}

function MB.CommandTab:Create(parent)
    if self.parent then return self.parent end
    self.parent = parent
    local i, key, definition, button, column, row
    for i = 1, #self.ACTION_KEYS do
        key = self.ACTION_KEYS[i]
        definition = MB.Actions.selected[key]
        column = (i - 1) % 8
        row = math.floor((i - 1) / 8)
        local actionKey = key
        button = MB.Widgets:CreateIconButton(
            "MangosbotCommandButton" .. i,
            parent,
            42,
            definition.icon,
            definition.label .. "\n" .. definition.tooltip,
            function() MB.SelectedBot:RunAction(actionKey) end
        )
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", 8 + (column * 58), -12 - (row * 64))
        button.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.label:SetPoint("TOP", button, "BOTTOM", 0, -2)
        button.label:SetText(definition.label)
        self.buttons[key] = button
    end
    return parent
end
