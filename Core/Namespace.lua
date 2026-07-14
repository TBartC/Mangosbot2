Mangosbot = Mangosbot or {}

local MB = Mangosbot

MB.VERSION = "2.0.0-dev"
MB.SCHEMA_VERSION = 2
MB.listeners = MB.listeners or {}

function MB:On(eventName, handler)
    if type(handler) ~= "function" then
        return false
    end
    self.listeners[eventName] = self.listeners[eventName] or {}
    table.insert(self.listeners[eventName], handler)
    return true
end

function MB:Emit(eventName, payload)
    local listeners = self.listeners[eventName] or {}
    local i
    for i = 1, #listeners do
        listeners[i](payload)
    end
end

function MB:Trim(value)
    local result = string.gsub(value or "", "^%s+", "")
    result = string.gsub(result, "%s+$", "")
    return result
end

function MB:CopyArray(source)
    local copy = {}
    local i
    for i = 1, #(source or {}) do
        copy[i] = source[i]
    end
    return copy
end

function MB:CopyMap(source)
    local copy = {}
    local key, value
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end
