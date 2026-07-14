local MB = Mangosbot

MB.Widgets = {}

MB.Widgets.CLASS_COLORS = {
    warrior = { 0.78, 0.61, 0.43 },
    paladin = { 0.96, 0.55, 0.73 },
    hunter = { 0.67, 0.83, 0.45 },
    rogue = { 1, 0.96, 0.41 },
    priest = { 1, 1, 1 },
    shaman = { 0, 0.44, 0.87 },
    mage = { 0.41, 0.8, 0.94 },
    warlock = { 0.58, 0.51, 0.79 },
    druid = { 1, 0.49, 0.04 },
}

function MB.Widgets:GetClassColor(className)
    return self.CLASS_COLORS[string.lower(className or "")] or { 0.8, 0.8, 0.8 }
end

local PANEL_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

function MB.Widgets:CreatePanel(name, parent, width, height)
    local frame = CreateFrame("Frame", name, parent or UIParent)
    frame:SetWidth(width)
    frame:SetHeight(height)
    frame:SetBackdrop(PANEL_BACKDROP)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    return frame
end

function MB.Widgets:CreateIconButton(name, parent, size, icon, tooltip, onClick)
    local button = CreateFrame("Button", name, parent)
    button:SetWidth(size)
    button:SetHeight(size)
    local texture = button:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints(button)
    texture:SetTexture(icon)
    button.icon = texture
    button.tooltip = tooltip
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function()
        if button.tooltip and button.tooltip ~= "" then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(button.tooltip, 1, 0.82, 0)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

function MB.Widgets:CreateTab(name, parent, label, onClick)
    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetWidth(82)
    button:SetHeight(22)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
end

function MB.Widgets:CreateScrollList(name, parent, width, height)
    local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    scroll:SetWidth(width)
    scroll:SetHeight(height)
    local content = CreateFrame("Frame", name .. "Content", scroll)
    content:SetWidth(width - 24)
    content:SetHeight(height)
    scroll:SetScrollChild(content)
    scroll.content = content
    scroll.rows = {}
    return scroll
end

function MB.Widgets:SetButtonState(button, state)
    button.state = state
    if state == "active" then
        button.icon:SetVertexColor(0.35, 1, 0.35)
    elseif state == "pending" then
        button.icon:SetVertexColor(1, 0.82, 0.2)
    elseif state == "failed" then
        button.icon:SetVertexColor(1, 0.3, 0.3)
    elseif state == "disabled" or state == "blocked" then
        button.icon:SetVertexColor(0.4, 0.4, 0.4)
    else
        button.icon:SetVertexColor(1, 1, 1)
    end
end

function MB.Widgets:RestorePosition(frame, key, defaultPoint, defaultX, defaultY)
    local db = MB.SavedVariables:Get()
    local saved = db and db.windows and db.windows[key]
    frame:ClearAllPoints()
    if saved and saved.point then
        frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
    else
        frame:SetPoint(defaultPoint, UIParent, defaultPoint, defaultX or 0, defaultY or 0)
    end
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = frame:GetPoint(1)
        MB.SavedVariables:SetWindowPosition(key, point, relativePoint, x, y)
    end)
end

function MB.Widgets:ClampOffset(offset, total, visible)
    local maximum = math.max(0, (total or 0) - (visible or 0))
    offset = math.floor(tonumber(offset) or 0)
    if offset < 0 then return 0 end
    if offset > maximum then return maximum end
    return offset
end

function MB.Widgets:CreateListScrollBar(parent, name, topOffset, bottomOffset, onOffset)
    local slider = CreateFrame("Slider", name, parent, "UIPanelScrollBarTemplate")
    slider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, topOffset or -40)
    slider:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, bottomOffset or 40)
    slider:SetValueStep(1)
    slider:SetScript("OnValueChanged", function()
        if not slider.updating then onOffset(math.floor(slider:GetValue() + 0.5)) end
    end)
    parent:EnableMouseWheel(true)
    parent:SetScript("OnMouseWheel", function()
        if slider:IsVisible() then slider:SetValue(slider:GetValue() - arg1) end
    end)
    return slider
end

function MB.Widgets:UpdateListScrollBar(slider, offset, total, visible)
    offset = self:ClampOffset(offset, total, visible)
    local maximum = math.max(0, total - visible)
    slider.updating = true
    slider:SetMinMaxValues(0, maximum)
    slider:SetValue(offset)
    slider.updating = false
    if maximum > 0 then slider:Show() else slider:Hide() end
    return offset
end

function MB.Widgets:AddCloseButton(frame, savedKey)
    local button = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    button:SetScript("OnClick", function()
        frame:Hide()
        MB.SavedVariables:SetWindowVisible(savedKey, false)
    end)
    frame.close = button
    return button
end
