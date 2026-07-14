local MB = Mangosbot

MB.Parser = {}

local function startsWith(value, prefix)
    return string.sub(value or "", 1, string.len(prefix)) == prefix
end

local function splitPlain(value, delimiter)
    local result = {}
    local startAt = 1
    local position
    while true do
        position = string.find(value, delimiter, startAt, true)
        if not position then
            table.insert(result, string.sub(value, startAt))
            break
        end
        table.insert(result, string.sub(value, startAt, position - 1))
        startAt = position + string.len(delimiter)
    end
    return result
end

local function splitStrategies(value, legacy)
    local result = {}
    local seen = {}
    local parts = splitPlain(value or "", ",")
    local family = legacy and "co" or nil
    local i, strategy
    for i = 1, #parts do
        strategy = MB:Trim(parts[i])
        if legacy and strategy == "nc" then
            family = "nc"
        elseif strategy ~= "" and not seen[strategy] then
            seen[strategy] = true
            table.insert(result, strategy)
        end
    end
    return result, family
end

local STATUS_PREFIXES = {
    { prefix = "Formation set to: ", field = "formation" },
    { prefix = "Formation: ", field = "formation" },
    { prefix = "Mana save level set: ", field = "savemana" },
    { prefix = "Mana save level: ", field = "savemana" },
    { prefix = "Loot strategy: ", field = "loot" },
    { prefix = "RTI: ", field = "rti" },
}

function MB.Parser:ParseWhisper(message, sender)
    if not sender or sender == "" then
        return nil
    end

    local prefix, family, legacy
    if startsWith(message, "Combat Strategies: ") then
        prefix, family = "Combat Strategies: ", "co"
    elseif startsWith(message, "Non Combat Strategies: ") then
        prefix, family = "Non Combat Strategies: ", "nc"
    elseif startsWith(message, "Strategies: ") then
        prefix, family, legacy = "Strategies: ", "co", true
    end

    if prefix then
        local strategies, legacyFamily = splitStrategies(
            string.sub(message, string.len(prefix) + 1),
            legacy
        )
        return {
            kind = "strategies",
            bot = sender,
            family = legacyFamily or family,
            strategies = strategies,
        }
    end

    local i, definition
    for i = 1, #STATUS_PREFIXES do
        definition = STATUS_PREFIXES[i]
        if startsWith(message, definition.prefix) then
            return {
                kind = "status",
                bot = sender,
                field = definition.field,
                value = MB:Trim(string.sub(message, string.len(definition.prefix) + 1)),
            }
        end
    end

    return nil
end

local ROSTER_CHANGE_PREFIXES = {
    "add: ",
    "Hired ",
    "Already hired ",
    "Hire failed: ",
    "Player is offline",
}

local function parseHirelings(message)
    local prefix = "Hireling roster: "
    local entries = {}
    local rows = splitPlain(string.sub(message, string.len(prefix) + 1), ";")
    local i, parts, name
    for i = 1, #rows do
        parts = splitPlain(rows[i], "|")
        name = MB:Trim(parts[1])
        if name ~= "" then
            table.insert(entries, {
                name = name,
                race = MB:Trim(parts[2]),
                class = MB:Trim(parts[3]),
                spec = MB:Trim(parts[4]),
                role = MB:Trim(parts[5]),
                strategy = MB:Trim(parts[6]),
            })
        end
    end
    return { kind = "hirelings", entries = entries }
end

local function parseRoster(message)
    local prefix = "Bot roster: "
    local entries = {}
    local rows = splitPlain(string.sub(message, string.len(prefix) + 1), ", ")
    local i, row, marker, spaceAt, name, class
    for i = 1, #rows do
        row = MB:Trim(rows[i])
        marker = string.sub(row, 1, 1)
        spaceAt = string.find(row, " ", 2, true)
        if (marker == "+" or marker == "-") and spaceAt then
            name = MB:Trim(string.sub(row, 2, spaceAt - 1))
            class = MB:Trim(string.sub(row, spaceAt + 1))
            if name ~= "" then
                table.insert(entries, {
                    name = name,
                    class = class,
                    online = marker == "+",
                })
            end
        end
    end
    return { kind = "roster", entries = entries }
end

function MB.Parser:ParseSystem(message)
    if startsWith(message, "Hireling roster: ") then
        return parseHirelings(message)
    end
    if startsWith(message, "Bot roster: ") then
        return parseRoster(message)
    end
    if startsWith(message, "Dismissed ") then
        return {
            kind = "bot_dismissed",
            bot = MB:Trim(string.sub(message, string.len("Dismissed ") + 1)),
            message = message,
        }
    end
    if startsWith(message, "Dismiss failed: ") then
        return { kind = "dismiss_failed", message = message }
    end
    local i
    for i = 1, #ROSTER_CHANGE_PREFIXES do
        if startsWith(message, ROSTER_CHANGE_PREFIXES[i]) then
            return { kind = "roster_changed", message = message }
        end
    end
    return nil
end
