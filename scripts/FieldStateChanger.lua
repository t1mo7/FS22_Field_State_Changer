-- FieldStateChanger for Farming Simulator 22
-- Instantly set the ground state of a field (plowed, cultivated, ...).
-- Hotkey: ALT + F while standing on a field (on foot).
-- Console: fscSetField <fieldNumber|here> <state>, fscStates

FieldStateChanger = {}
FieldStateChanger.modName = g_currentModName
FieldStateChanger.modDirectory = g_currentModDirectory

-- Only change fields owned by your own farm when using the hotkey
FieldStateChanger.ONLY_OWNED_FIELDS = true

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function log(fmt, ...)
    print(string.format("[FieldStateChanger] " .. fmt, ...))
end

local function notify(text, isError)
    log("%s", text)
    if g_currentMission == nil then
        return
    end
    if g_currentMission.addIngameNotification ~= nil then
        local notificationType = isError and FSBaseMission.INGAME_NOTIFICATION_CRITICAL or FSBaseMission.INGAME_NOTIFICATION_OK
        g_currentMission:addIngameNotification(notificationType, text)
    elseif g_currentMission.showBlinkingWarning ~= nil then
        g_currentMission:showBlinkingWarning(text, 3000)
    end
end

local function getSprayTypeIndex(name)
    if g_sprayTypeManager == nil then
        return nil
    end
    if g_sprayTypeManager.getSprayTypeIndexByName ~= nil then
        local index = g_sprayTypeManager:getSprayTypeIndexByName(name)
        if index ~= nil then
            return index
        end
    end
    if g_sprayTypeManager.getSprayTypeByName ~= nil then
        local sprayType = g_sprayTypeManager:getSprayTypeByName(name)
        if sprayType ~= nil then
            return sprayType.index
        end
    end
    return nil
end

-- Calls FSDensityMapUtil.<funcName> for one parallelogram area.
-- Returns true on success, false if the function is missing or failed.
local function applyDensity(funcName, area, ...)
    local func = FSDensityMapUtil[funcName]
    if func == nil then
        log("FSDensityMapUtil.%s not available in this game version", funcName)
        return false
    end
    local ok, err = pcall(func, area.x0, area.z0, area.x1, area.z1, area.x2, area.z2, ...)
    if not ok then
        log("Error in FSDensityMapUtil.%s: %s", funcName, tostring(err))
    end
    return ok
end

local function applySpray(area, sprayName, times)
    local index = getSprayTypeIndex(sprayName)
    if index == nil then
        log("Spray type %s not found", sprayName)
        return false
    end
    local ok = true
    for _ = 1, times or 1 do
        ok = applyDensity("updateSprayArea", area, index, 1) and ok
    end
    return ok
end

----------------------------------------------------------------------
-- Field states
----------------------------------------------------------------------

-- Each state has a name (for the console), a display text and an apply
-- function that is called once for every area of the field.
FieldStateChanger.STATES = {
    {
        name = "plowed", text = "Plowed",
        apply = function(area)
            return applyDensity("updatePlowArea", area, true, true, 0)
        end
    },
    {
        name = "cultivated", text = "Cultivated",
        apply = function(area)
            return applyDensity("updateCultivatorArea", area, true, true, 0, nil)
        end
    },
    {
        name = "stubbletillage", text = "Stubble tillage",
        apply = function(area)
            if FSDensityMapUtil.updateDiscHarrowArea ~= nil then
                return applyDensity("updateDiscHarrowArea", area, true, true, 0, nil)
            end
            return applyDensity("updateCultivatorArea", area, true, true, 0, nil)
        end
    },
    {
        name = "rolled", text = "Rolled",
        apply = function(area)
            return applyDensity("updateRollerArea", area, 0)
        end
    },
    {
        name = "mulched", text = "Mulched (stubble shredded)",
        apply = function(area)
            return applyDensity("updateMulcherArea", area)
        end
    },
    {
        name = "limed", text = "Limed",
        apply = function(area)
            return applySpray(area, "LIME", 1)
        end
    },
    {
        name = "fertilized", text = "Fertilized (max)",
        apply = function(area)
            return applySpray(area, "FERTILIZER", 2)
        end
    },
    {
        name = "noweeds", text = "Remove weeds",
        apply = function(area)
            if FSDensityMapUtil.updateHerbicideArea ~= nil then
                return applyDensity("updateHerbicideArea", area)
            end
            return applySpray(area, "HERBICIDE", 1)
        end
    },
    {
        name = "ready", text = "Ready to sow (plow + lime + fertilize + cultivate + weeds)",
        apply = function(area)
            local ok = applyDensity("updatePlowArea", area, true, true, 0)
            applySpray(area, "LIME", 1)
            applySpray(area, "FERTILIZER", 2)
            ok = applyDensity("updateCultivatorArea", area, true, true, 0, nil) and ok
            if FSDensityMapUtil.updateHerbicideArea ~= nil then
                applyDensity("updateHerbicideArea", area)
            else
                applySpray(area, "HERBICIDE", 1)
            end
            return ok
        end
    }
}

function FieldStateChanger:getStateByName(name)
    if name == nil then
        return nil
    end
    name = string.lower(name)
    for _, state in ipairs(FieldStateChanger.STATES) do
        if state.name == name then
            return state
        end
    end
    return nil
end

----------------------------------------------------------------------
-- Field geometry
----------------------------------------------------------------------

-- Returns a list of parallelogram areas {x0,z0,x1,z1,x2,z2} covering the field.
function FieldStateChanger:getFieldAreas(field)
    local areas = {}

    local dimensions = field.fieldDimensions
    if dimensions ~= nil and dimensions ~= 0 then
        for i = 0, getNumOfChildren(dimensions) - 1 do
            local dimWidth = getChildAt(dimensions, i)
            local dimStart = getChildAt(dimWidth, 0)
            local dimHeight = getChildAt(dimWidth, 1)
            local x0, _, z0 = getWorldTranslation(dimStart)
            local x1, _, z1 = getWorldTranslation(dimWidth)
            local x2, _, z2 = getWorldTranslation(dimHeight)
            table.insert(areas, {x0 = x0, z0 = z0, x1 = x1, z1 = z1, x2 = x2, z2 = z2})
        end
    end

    if #areas == 0 and field.maxFieldStatusPartitions ~= nil then
        for _, p in ipairs(field.maxFieldStatusPartitions) do
            table.insert(areas, {x0 = p.x0, z0 = p.z0, x1 = p.widthX, z1 = p.widthZ, x2 = p.heightX, z2 = p.heightZ})
        end
    end

    return areas
end

local function isPointInArea(area, px, pz)
    local ux, uz = area.x1 - area.x0, area.z1 - area.z0
    local vx, vz = area.x2 - area.x0, area.z2 - area.z0
    local det = ux * vz - uz * vx
    if math.abs(det) < 0.0001 then
        return false
    end
    local dx, dz = px - area.x0, pz - area.z0
    local a = (dx * vz - dz * vx) / det
    local b = (ux * dz - uz * dx) / det
    return a >= 0 and a <= 1 and b >= 0 and b <= 1
end

function FieldStateChanger:getFields()
    if g_fieldManager == nil then
        return {}
    end
    if g_fieldManager.getFields ~= nil then
        return g_fieldManager:getFields()
    end
    return g_fieldManager.fields or {}
end

function FieldStateChanger:getFieldNumber(field)
    return field.fieldId or field.index or 0
end

function FieldStateChanger:getFieldById(fieldId)
    for _, field in ipairs(self:getFields()) do
        if self:getFieldNumber(field) == fieldId then
            return field
        end
    end
    return nil
end

function FieldStateChanger:getFieldAtPosition(x, z)
    for _, field in ipairs(self:getFields()) do
        for _, area in ipairs(self:getFieldAreas(field)) do
            if isPointInArea(area, x, z) then
                return field
            end
        end
    end
    return nil
end

function FieldStateChanger:getPlayerPosition()
    local mission = g_currentMission
    if mission == nil then
        return nil
    end
    local vehicle = mission.controlledVehicle
    if vehicle ~= nil and vehicle.rootNode ~= nil then
        local x, _, z = getWorldTranslation(vehicle.rootNode)
        return x, z
    end
    local player = mission.player
    if player ~= nil and player.rootNode ~= nil then
        local x, _, z = getWorldTranslation(player.rootNode)
        return x, z
    end
    return nil
end

function FieldStateChanger:isFieldOwnedByPlayer(field)
    if field.farmland == nil or g_farmlandManager == nil then
        return false
    end
    local ownerId = g_farmlandManager:getFarmlandOwner(field.farmland.id)
    return ownerId ~= nil and ownerId == g_currentMission:getFarmId()
end

----------------------------------------------------------------------
-- Apply
----------------------------------------------------------------------

function FieldStateChanger:applyState(field, state)
    if g_currentMission == nil or not g_currentMission:getIsServer() then
        notify("Field State Changer only works for the host / single player.", true)
        return false
    end

    local areas = self:getFieldAreas(field)
    if #areas == 0 then
        notify(string.format("Field %d has no field dimensions.", self:getFieldNumber(field)), true)
        return false
    end

    local okCount = 0
    for _, area in ipairs(areas) do
        if state.apply(area) then
            okCount = okCount + 1
        end
    end

    if okCount == 0 then
        notify(string.format("Could not set field %d to '%s' (see log.txt).", self:getFieldNumber(field), state.text), true)
        return false
    end

    notify(string.format("Field %d set to: %s", self:getFieldNumber(field), state.text), false)
    return true
end

----------------------------------------------------------------------
-- Hotkey + menu
----------------------------------------------------------------------

function FieldStateChanger:onMenuAction(actionName, inputValue, callbackState, isAnalog)
    local x, z = self:getPlayerPosition()
    if x == nil then
        return
    end

    local field = self:getFieldAtPosition(x, z)
    if field == nil then
        notify("You are not standing on a field.", true)
        return
    end

    if FieldStateChanger.ONLY_OWNED_FIELDS and not self:isFieldOwnedByPlayer(field) then
        notify(string.format("You don't own field %d.", self:getFieldNumber(field)), true)
        return
    end

    if g_gui == nil or g_gui.showOptionDialog == nil then
        notify("Menu not available, use the console: fscSetField here <state>", true)
        return
    end

    local options = {}
    for _, state in ipairs(FieldStateChanger.STATES) do
        table.insert(options, state.text)
    end

    self.pendingField = field
    g_gui:showOptionDialog({
        title = "Field State Changer",
        text = string.format("Choose the new state for field %d:", self:getFieldNumber(field)),
        options = options,
        callback = FieldStateChanger.onMenuSelected,
        target = self
    })
end

function FieldStateChanger:onMenuSelected(selectedIndex)
    local field = self.pendingField
    self.pendingField = nil

    if field == nil or type(selectedIndex) ~= "number" or selectedIndex < 1 then
        return
    end

    local state = FieldStateChanger.STATES[selectedIndex]
    if state ~= nil then
        self:applyState(field, state)
    end
end

function FieldStateChanger.registerPlayerActionEvents(player)
    if InputAction.FSC_MENU == nil then
        return
    end
    local _, eventId = g_inputBinding:registerActionEvent(InputAction.FSC_MENU, FieldStateChanger, FieldStateChanger.onMenuAction, false, true, false, true)
    if eventId ~= nil then
        g_inputBinding:setActionEventTextVisibility(eventId, true)
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_LOW)
    end
end

if Player ~= nil and Player.registerActionEvents ~= nil then
    Player.registerActionEvents = Utils.appendedFunction(Player.registerActionEvents, FieldStateChanger.registerPlayerActionEvents)
end

----------------------------------------------------------------------
-- Console commands
----------------------------------------------------------------------

function FieldStateChanger:consoleStates()
    local lines = {"Available states:"}
    for _, state in ipairs(FieldStateChanger.STATES) do
        table.insert(lines, string.format("  %-15s %s", state.name, state.text))
    end
    return table.concat(lines, "\n")
end

function FieldStateChanger:consoleSetField(fieldArg, stateArg)
    local usage = "Usage: fscSetField <fieldNumber|here|all> <state>   (fscStates for the list)"
    if fieldArg == nil or stateArg == nil then
        return usage
    end

    local state = self:getStateByName(stateArg)
    if state == nil then
        return "Unknown state '" .. tostring(stateArg) .. "'.\n" .. self:consoleStates()
    end

    local fields = {}
    fieldArg = string.lower(fieldArg)
    if fieldArg == "here" then
        local x, z = self:getPlayerPosition()
        local field = x ~= nil and self:getFieldAtPosition(x, z) or nil
        if field == nil then
            return "You are not standing on a field."
        end
        table.insert(fields, field)
    elseif fieldArg == "all" or fieldArg == "owned" then
        for _, field in ipairs(self:getFields()) do
            if fieldArg == "all" or self:isFieldOwnedByPlayer(field) then
                table.insert(fields, field)
            end
        end
    else
        local field = self:getFieldById(tonumber(fieldArg))
        if field == nil then
            return "Field '" .. fieldArg .. "' not found."
        end
        table.insert(fields, field)
    end

    local count = 0
    for _, field in ipairs(fields) do
        if self:applyState(field, state) then
            count = count + 1
        end
    end
    return string.format("Set %d field(s) to '%s'.", count, state.text)
end

----------------------------------------------------------------------
-- Mod event listener
----------------------------------------------------------------------

function FieldStateChanger:loadMap(name)
    addConsoleCommand("fscSetField", "Set field state: fscSetField <fieldNumber|here|owned|all> <state>", "consoleSetField", self)
    addConsoleCommand("fscStates", "List states for fscSetField", "consoleStates", self)
    log("loaded (press ALT + F on a field)")
end

function FieldStateChanger:deleteMap()
    removeConsoleCommand("fscSetField")
    removeConsoleCommand("fscStates")
end

addModEventListener(FieldStateChanger)
