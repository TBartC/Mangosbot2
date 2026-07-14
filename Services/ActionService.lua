local MB = Mangosbot

MB.Actions = { selected = {}, group = {} }
MB.ActionService = {}

local IMAGE_ROOT = "Interface\\AddOns\\Mangosbot2\\Images\\"

local function action(label, icon, commands, scope, tooltip)
    return {
        label = label,
        icon = IMAGE_ROOT .. icon .. ".tga",
        commands = commands,
        scope = scope,
        tooltip = tooltip,
    }
end

MB.Actions.selected = {
    stats = action("Stats", "stats", { "stats" }, "selected", "Show experience, money, and bot statistics."),
    follow = action("Follow", "follow_master", { "#a follow" }, "selected", "Follow the master."),
    stay = action("Stay", "stay", { "#a stay" }, "selected", "Stay at the current position."),
    flee = action("Flee", "flee_passive", { "#a flee" }, "selected", "Flee from danger."),
    guard = action("Guard", "guard", { "#a nc +guard" }, "selected", "Guard the configured position."),
    grind = action("Grind", "grind", { "#a nc ~grind" }, "selected", "Toggle aggressive grinding behavior."),
    passive = action("Passive", "passive", { "#a nc ~passive", "#a co ~passive" }, "selected", "Toggle passive behavior in both contexts."),
    loot = action("Loot", "loot", { "d add all loot", "d loot" }, "selected", "Loot all permitted nearby objects."),
    set_guard = action("Set Guard", "set_guard", { "position guard set" }, "selected", "Set this bot's guard position."),
    release = action("Release", "release", { "release" }, "selected", "Release the bot's spirit."),
    revive = action("Revive", "revive", { "revive" }, "selected", "Revive at the spirit healer."),
    summon = action("Summon", "summon", { "summon" }, "selected", "Summon at a meeting stone."),
    inventory = action("Inventory", "count", { "c" }, "selected", "Show inventory."),
    bank = action("Bank", "bank", { "bank" }, "selected", "Show bank contents."),
    spells = action("Spells", "spells", { "spells" }, "selected", "Show spells and tradeskills."),
    mail = action("Mail", "mail", { "mail ?" }, "selected", "Show mail."),
    formation_near = action("Near", "formation_near", { "formation near" }, "selected", "Use near formation."),
    formation_melee = action("Melee", "formation_melee", { "formation melee" }, "selected", "Use melee formation."),
    formation_arrow = action("Arrow", "formation_arrow", { "formation arrow" }, "selected", "Tank first, damage last."),
    formation_chaos = action("Chaos", "formation_chaos", { "formation chaos" }, "selected", "Move freely."),
    formation_line = action("Line", "formation_line", { "formation line" }, "selected", "Form a line."),
    formation_queue = action("Queue", "formation_queue", { "formation queue" }, "selected", "Form a queue."),
    formation_circle = action("Circle", "formation_circle", { "formation circle" }, "selected", "Form a circle."),
}

MB.Actions.group = {
    follow = action("Follow", "follow_master", { "#a follow" }, "group", "Tell the entire group to follow."),
    stay = action("Stay", "stay", { "#a stay" }, "group", "Tell the entire group to stay."),
    flee = action("Flee", "flee_passive", { "#a flee" }, "group", "Tell the entire group to flee."),
    passive = action("Passive", "passive", { "#a nc +passive", "#a co +passive" }, "group", "Set the entire group passive."),
    loot = action("Loot", "loot", { "d add all loot", "d loot" }, "group", "Tell the group to loot."),
    attack = action("Attack", "dps", { "d attack my target" }, "group", "Attack the master's target."),
    pull = action("Pull", "tank_assist", { "#a @dps flee", "#a @heal flee", "#a @tank d attack my target" }, "group", "Tank pulls while damage and healers hold."),
    summon = action("Summon", "summon", { "summon" }, "group", "Summon the group at a meeting stone."),
    formation_near = action("Near", "formation_near", { "formation near" }, "group", "Use near formation."),
    formation_melee = action("Melee", "formation_melee", { "formation melee" }, "group", "Use melee formation."),
    formation_arrow = action("Arrow", "formation_arrow", { "formation arrow" }, "group", "Use arrow formation."),
    formation_chaos = action("Chaos", "formation_chaos", { "formation chaos" }, "group", "Use chaos formation."),
    formation_line = action("Line", "formation_line", { "formation line" }, "group", "Use line formation."),
    formation_queue = action("Queue", "formation_queue", { "formation queue" }, "group", "Use queue formation."),
    formation_circle = action("Circle", "formation_circle", { "formation circle" }, "group", "Use circle formation."),
}

function MB.ActionService:RunForBot(bot, key)
    if not bot then
        return { ok = false, code = "NO_BOT", message = "Select a bot first" }
    end
    local definition = MB.Actions.selected[key]
    if not definition then
        return { ok = false, code = "UNKNOWN_ACTION", message = "Unknown action: " .. tostring(key) }
    end
    local i
    for i = 1, #definition.commands do
        MB.Transport:Whisper(bot, definition.commands[i], nil, nil)
    end
    return { ok = true, bot = bot, action = key }
end

function MB.ActionService:RunSelected(key)
    return self:RunForBot(MB.BotState:GetSelectedName(), key)
end

function MB.ActionService:RunGroup(key)
    local definition = MB.Actions.group[key]
    if not definition then
        return { ok = false, code = "UNKNOWN_ACTION", message = "Unknown group action: " .. tostring(key) }
    end
    local i
    for i = 1, #definition.commands do
        MB.Transport:Group(definition.commands[i])
    end
    return { ok = true, action = key }
end
