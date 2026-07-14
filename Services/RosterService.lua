local MB = Mangosbot

MB.RosterService = {}

local function validName(name)
    return name and name ~= ""
end

function MB.RosterService:Refresh()
    MB.Transport:Say(".bot list")
    MB.Transport:Say(".bot hirelings")
    return { ok = true }
end

function MB.RosterService:Hire(name)
    if not validName(name) then return { ok = false, code = "NO_BOT" } end
    MB.Transport:Say(".bot hire " .. name)
    return { ok = true, bot = name }
end

function MB.RosterService:Dismiss(name)
    if not validName(name) then return { ok = false, code = "NO_BOT" } end
    MB.Transport:Whisper(name, "leave")
    MB.Transport:Say(".bot dismiss " .. name, function()
        MB.RosterService:Refresh()
    end)
    return { ok = true, bot = name }
end

function MB.RosterService:Login(name)
    if not validName(name) then return { ok = false, code = "NO_BOT" } end
    MB.Transport:Say(".bot add " .. name)
    return { ok = true, bot = name }
end

function MB.RosterService:Logout(name)
    if not validName(name) then return { ok = false, code = "NO_BOT" } end
    MB.Transport:Say(".bot rm " .. name)
    return { ok = true, bot = name }
end

function MB.RosterService:Invite(name)
    if not validName(name) then return { ok = false, code = "NO_BOT" } end
    InviteUnit(name)
    return { ok = true, bot = name }
end

function MB.RosterService:Leave(name)
    if not validName(name) then return { ok = false, code = "NO_BOT" } end
    MB.Transport:Whisper(name, "leave", nil, nil)
    return { ok = true, bot = name }
end

function MB.RosterService:IsGrouped(name)
    local i, unitName
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            unitName = UnitName("raid" .. i)
            if unitName == name then return true end
        end
    elseif GetNumPartyMembers then
        for i = 1, GetNumPartyMembers() do
            unitName = UnitName("party" .. i)
            if unitName == name then return true end
        end
    end
    return false
end
