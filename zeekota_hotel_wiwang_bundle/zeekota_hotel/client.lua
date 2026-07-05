local currentAssignment
local currentRoom
local currentStash
local spawnedFurniture = {}
local spawnedStashProp
local placementGhost
local lobbyPed
local activePrompt
local placementActive = false
local registeredTargets = false
local menuActions = {}
local actionSequence = 0
local callbackSequence = 0
local pendingCallbacks = {}
local unpack = table.unpack or unpack

local openLobbyMenu
local openRoomMenu
local openFurnitureMenu
local openElevatorMenu
local startPlacement

local function resourceStarted(name)
    return name and (GetResourceState(name) == 'started' or GetResourceState(name) == 'starting')
end

local function nuiTheme()
    local ui = Config.UI or {}
    local colors = ui.Colors or {}
    local gradients = ui.Gradients or {}

    return {
        brand = Config.Branding.Name,
        shortName = Config.Branding.ShortName,
        subtitle = Config.Branding.UiSubtitle,
        accent = colors.Accent or Config.Branding.Accent,
        colors = colors,
        gradients = gradients
    }
end

local function sendTheme()
    SendNUIMessage({
        type = 'theme',
        theme = nuiTheme()
    })
end

local function notify(kind, description)
    SendNUIMessage({
        type = 'toast',
        kind = kind or 'inform',
        title = Config.Branding.NotifyTitle,
        message = description or ''
    })
end

RegisterNetEvent('zeekota_hotel:client:notify', notify)

local function showPrompt(label, key)
    local promptKey = key or Config.Interaction.KeyLabel
    local text = promptKey .. ':' .. label

    if activePrompt == text then return end

    SendNUIMessage({
        type = 'prompt',
        show = true,
        key = promptKey,
        label = label
    })

    activePrompt = text
end

local function showPlacementGuide()
    if activePrompt == 'placement-guide' then return end

    SendNUIMessage({
        type = 'prompt',
        show = true,
        key = 'EDIT',
        label = 'Placement Controls',
        guide = {
            { key = 'Enter', action = 'Save', image = 'assets/keys/enter.svg' },
            { key = 'Backspace', action = 'Cancel', image = 'assets/keys/backspace.svg' },
            { key = 'Arrows', action = 'Move', image = 'assets/keys/arrows.svg' },
            { key = 'Shift', action = 'Faster', image = 'assets/keys/shift.svg' },
            { key = 'Q / E', action = 'Rotate', image = 'assets/keys/qe.svg' },
            { key = 'PgUp / PgDn', action = 'Height', image = 'assets/keys/page.svg' }
        }
    })

    activePrompt = 'placement-guide'
end

local function hidePrompt()
    if not activePrompt then return end

    SendNUIMessage({
        type = 'prompt',
        show = false
    })

    activePrompt = nil
end

local function closeMenu()
    menuActions = {}
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = 'menu',
        show = false
    })
end

local function menuItem(item)
    local copy = {}

    for key, value in pairs(item) do
        if key ~= 'onSelect' then
            copy[key] = value
        end
    end

    if item.onSelect and not item.disabled then
        actionSequence = actionSequence + 1
        local actionId = tostring(actionSequence)
        menuActions[actionId] = item.onSelect
        copy.action = actionId
    end

    return copy
end

local function showMenu(title, subtitle, items)
    menuActions = {}

    local mapped = {}
    for i = 1, #items do
        mapped[#mapped + 1] = menuItem(items[i])
    end

    SendNUIMessage({
        type = 'menu',
        show = true,
        title = title,
        subtitle = subtitle,
        items = mapped
    })

    SetNuiFocus(true, true)
end

RegisterNUICallback('ready', function(_, cb)
    sendTheme()
    cb({})
end)

RegisterNUICallback('closeMenu', function(_, cb)
    closeMenu()
    cb({})
end)

RegisterNUICallback('menuSelect', function(data, cb)
    cb({})

    local actionId = data and data.action
    local action = actionId and menuActions[actionId]
    if not action then return end

    closeMenu()
    CreateThread(action)
end)

RegisterNetEvent('zeekota_hotel:client:callback', function(requestId, ...)
    local pending = pendingCallbacks[requestId]
    if not pending then return end

    pendingCallbacks[requestId] = nil
    pending:resolve({ ... })
end)

local function callServer(name, ...)
    callbackSequence = callbackSequence + 1
    local requestId = callbackSequence
    local pending = promise.new()

    pendingCallbacks[requestId] = pending
    TriggerServerEvent('zeekota_hotel:server:callback', name, requestId, ...)

    SetTimeout(15000, function()
        if pendingCallbacks[requestId] then
            pendingCallbacks[requestId] = nil
            pending:resolve({ false, 'Request timed out.' })
        end
    end)

    local result = Citizen.Await(pending)
    return unpack(result)
end

local function useTarget()
    return (Config.Target.Enabled or Config.Interaction.Mode == 'target' or Config.Interaction.Mode == 'both') and resourceStarted('ox_target')
end

local function useTextUI()
    return Config.Interaction.Mode == 'textui' or Config.Interaction.Mode == 'both' or not useTarget()
end

local function findRoom(hotelId, roomId)
    local hotel = Config.Hotels[hotelId]
    if not hotel then return nil end

    roomId = tostring(roomId)
    for i = 1, #hotel.Rooms do
        if hotel.Rooms[i].id == roomId then
            return hotel.Rooms[i], hotel
        end
    end
end

local function vectorFromPlacement(placement)
    return vector3(tonumber(placement.x) or 0.0, tonumber(placement.y) or 0.0, tonumber(placement.z) or 0.0)
end

local function vectorFromCoords(coords)
    return vector3(coords.x, coords.y, coords.z)
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        return nil
    end

    RequestModel(hash)

    local expires = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < expires do
        Wait(10)
    end

    if not HasModelLoaded(hash) then
        return nil
    end

    return hash
end

local function deleteEntity(entity)
    if entity and DoesEntityExist(entity) then
        SetEntityDrawOutline(entity, false)
        DeleteEntity(entity)
    end
end

local function clearPlacementPreview()
    deleteEntity(placementGhost)
    placementGhost = nil
end

local function spawnPlacedObject(model, coords, heading, options)
    local hash = loadModel(model)
    if not hash then return nil end

    local object = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)
    SetEntityAsMissionEntity(object, true, true)
    SetEntityHeading(object, heading or 0.0)
    FreezeEntityPosition(object, true)
    SetEntityCollision(object, not (options and options.ghost), true)
    SetEntityCompletelyDisableCollision(object, options and options.ghost or false, false)
    SetEntityDynamic(object, false)
    SetEntityVisible(object, true, false)
    SetEntityLoadCollisionFlag(object, true)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    if options and options.alpha then
        SetEntityAlpha(object, options.alpha, false)
    else
        ResetEntityAlpha(object)
    end

    if options and options.outline then
        local color = options.outlineColor or { r = 229, g = 9, b = 20, a = 255 }
        SetEntityDrawOutlineColor(color.r or 229, color.g or 9, color.b or 20, color.a or 255)
        SetEntityDrawOutline(object, true)
    end

    SetModelAsNoLongerNeeded(hash)
    return object
end

local function clearFurnitureObjects()
    for _, object in pairs(spawnedFurniture) do
        deleteEntity(object)
    end

    spawnedFurniture = {}
end

local function isTrackedRoomObject(object)
    if object == placementGhost or object == spawnedStashProp then return true end

    for _, spawnedObject in pairs(spawnedFurniture) do
        if object == spawnedObject then
            return true
        end
    end

    return false
end

local function getPlacementModelHashes()
    local hashes = {}

    for i = 1, #Config.Furniture.Categories do
        local category = Config.Furniture.Categories[i]
        for j = 1, #category.items do
            hashes[joaat(category.items[j].model)] = true
        end
    end

    for i = 1, #Config.Stash.Props do
        hashes[joaat(Config.Stash.Props[i].model)] = true
    end

    return hashes
end

local function cleanupStalePlacementPreviews()
    if not currentRoom or not Config.Furniture.StalePreviewCleanup then return end

    local doorCoords = vector3(currentRoom.door.x, currentRoom.door.y, currentRoom.door.z)
    local maxDistance = Config.Furniture.StalePreviewCleanupDistance or 3.0
    local placementModels = getPlacementModelHashes()

    for _, object in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(object)
            and not isTrackedRoomObject(object)
            and placementModels[GetEntityModel(object)]
            and #(GetEntityCoords(object) - doorCoords) <= maxDistance
        then
            deleteEntity(object)
        end
    end
end

local function spawnFurniture(items)
    clearFurnitureObjects()

    for i = 1, #(items or {}) do
        local item = items[i]
        local object = spawnPlacedObject(item.model, vectorFromPlacement(item), tonumber(item.heading) or 0.0)
        if object then
            spawnedFurniture[tonumber(item.id)] = object
        end
    end
end

local function spawnStash(placement)
    currentStash = placement
    deleteEntity(spawnedStashProp)
    spawnedStashProp = nil

    if not placement or placement.mode ~= 'prop' or not placement.model then return end

    spawnedStashProp = spawnPlacedObject(placement.model, vectorFromPlacement(placement), tonumber(placement.heading) or 0.0)
end

local function refreshRoomContent()
    if not currentAssignment then return end

    local ok, message, furniture, stash = callServer('getRoomContent', currentAssignment.hotelId, currentAssignment.roomId)
    if not ok then
        notify('error', message or Config.Text.DatabaseError)
        return
    end

    spawnFurniture(furniture)
    spawnStash(stash)
    cleanupStalePlacementPreviews()
end

local function getLobbyInteractionPoint()
    return (Config.Lobby.Interaction and Config.Lobby.Interaction.Coords)
        or (Config.Lobby.Ped and Config.Lobby.Ped.Coords)
        or Config.Lobby.Coords
end

local function registerTargets()
    if registeredTargets or not useTarget() or not currentAssignment or not currentRoom then return end
    registeredTargets = true

    local lobbyPoint = getLobbyInteractionPoint()

    exports.ox_target:addBoxZone({
        name = 'zeekota_hotel_lobby_assignment',
        coords = vector3(lobbyPoint.x, lobbyPoint.y, lobbyPoint.z),
        size = vector3(1.4, 1.4, 1.5),
        rotation = lobbyPoint.w or 0.0,
        debug = Config.Debug,
        drawSprite = Config.Target.DrawSprite,
        options = {
            {
                name = 'zeekota_hotel_lobby_assignment_option',
                icon = 'fa-solid fa-hotel',
                label = 'View Room Number',
                distance = Config.Interaction.Distance,
                onSelect = function()
                    openLobbyMenu()
                end
            }
        }
    })

    exports.ox_target:addBoxZone({
        name = ('zeekota_hotel_room_%s_%s'):format(currentAssignment.hotelId, currentAssignment.roomId),
        coords = vector3(currentRoom.door.x, currentRoom.door.y, currentRoom.door.z),
        size = vector3(1.0, 1.0, 1.8),
        rotation = currentRoom.door.w or 0.0,
        debug = Config.Debug,
        drawSprite = Config.Target.DrawSprite,
        options = {
            {
                name = ('zeekota_hotel_room_option_%s_%s'):format(currentAssignment.hotelId, currentAssignment.roomId),
                icon = 'fa-solid fa-door-closed',
                label = currentRoom.label,
                distance = Config.Interaction.DoorDistance,
                onSelect = function()
                    openRoomMenu()
                end
            }
        }
    })
end

local function loadAssignment(showCreatedMessage)
    local ok, message, assignment, stash, furniture = callServer('getMyRoom')
    if not ok then
        notify('error', message or Config.Text.NoAssignment)
        return false
    end

    currentAssignment = assignment
    currentRoom = findRoom(assignment.hotelId, assignment.roomId)

    if not currentRoom then
        notify('error', Config.Text.NoAssignment)
        return false
    end

    spawnFurniture(furniture)
    spawnStash(stash)
    cleanupStalePlacementPreviews()
    registerTargets()

    if showCreatedMessage and message then
        notify('success', message)
    end

    return true
end

local function setDoorLocked(locked)
    if not currentAssignment then return end

    local ok, message = callServer('setDoorState', currentAssignment.hotelId, currentAssignment.roomId, locked)
    notify(ok and 'success' or 'error', message or Config.Text.DoorLockMissing)
end

local function openStash()
    if not currentAssignment then return end
    if not Config.Stash.Enabled or not resourceStarted('ox_inventory') then
        notify('error', Config.Text.StashUnavailable)
        return
    end

    local ok, message, stashId = callServer('getStash', currentAssignment.hotelId, currentAssignment.roomId)
    if not ok or not stashId then
        notify('error', message or Config.Text.StashUnavailable)
        return
    end

    exports.ox_inventory:openInventory('stash', { id = stashId })
end

local function getNearestFurnitureId()
    local coords = GetEntityCoords(PlayerPedId())
    local nearestId
    local nearestDistance = 2.5

    for id, object in pairs(spawnedFurniture) do
        if DoesEntityExist(object) then
            local distance = #(coords - GetEntityCoords(object))
            if distance < nearestDistance then
                nearestDistance = distance
                nearestId = id
            end
        end
    end

    return nearestId
end

local function removeNearestFurniture()
    if not currentAssignment then return end

    local furnitureId = getNearestFurnitureId()
    if not furnitureId then
        notify('error', 'No furniture item was close enough to remove.')
        return
    end

    local ok, message, furniture = callServer('deleteFurniture', currentAssignment.hotelId, currentAssignment.roomId, furnitureId)
    if ok then
        spawnFurniture(furniture)
    end

    notify(ok and 'success' or 'error', message or Config.Text.DatabaseError)
end

local function clearAllFurniture()
    if not currentAssignment then return end

    showMenu('Clear Furniture', 'Remove every saved furniture object in this room?', {
        {
            title = 'Confirm Clear',
            description = 'This only affects your assigned room.',
            tone = 'danger',
            onSelect = function()
                local ok, message, furniture = callServer('clearFurniture', currentAssignment.hotelId, currentAssignment.roomId)
                if ok then
                    spawnFurniture(furniture)
                    cleanupStalePlacementPreviews()
                end

                notify(ok and 'success' or 'error', message or Config.Text.DatabaseError)
            end
        },
        {
            title = 'Cancel',
            description = 'Leave furniture as-is.',
            onSelect = openFurnitureMenu
        }
    })
end

local function openFurnitureCategory(category)
    local options = {}

    for i = 1, #category.items do
        local item = category.items[i]
        options[#options + 1] = {
            title = item.label,
            description = item.model,
            onSelect = function()
                startPlacement({
                    type = 'furniture',
                    label = item.label,
                    model = item.model
                })
            end
        }
    end

    options[#options + 1] = {
        title = 'Back',
        description = 'Return to furniture categories.',
        onSelect = openFurnitureMenu
    }

    showMenu(category.label, 'Choose a prop to place', options)
end

local function openFurniturePlacementMenu()
    local options = {}

    for i = 1, #Config.Furniture.Categories do
        local category = Config.Furniture.Categories[i]
        options[#options + 1] = {
            title = category.label,
            description = ('%s item(s)'):format(#category.items),
            onSelect = function()
                openFurnitureCategory(category)
            end
        }
    end

    options[#options + 1] = {
        title = 'Back',
        description = 'Return to room furniture tools.',
        onSelect = openFurnitureMenu
    }

    showMenu('Place Furniture', 'Select a category', options)
end

local function openStashPlacementMenu()
    local options = {
        {
            title = 'Move Stash Marker',
            description = 'Use a floor marker instead of a prop.',
            onSelect = function()
                startPlacement({
                    type = 'stash',
                    mode = 'marker',
                    label = 'Room Storage'
                })
            end
        }
    }

    for i = 1, #Config.Stash.Props do
        local item = Config.Stash.Props[i]
        options[#options + 1] = {
            title = item.label,
            description = item.model,
            onSelect = function()
                startPlacement({
                    type = 'stash',
                    mode = 'prop',
                    label = item.label,
                    model = item.model
                })
            end
        }
    end

    options[#options + 1] = {
        title = 'Back',
        description = 'Return to furniture tools.',
        onSelect = openFurnitureMenu
    }

    showMenu('Move Room Storage', 'Choose marker or storage prop', options)
end

openFurnitureMenu = function()
    if not currentAssignment then return end

    showMenu('Furniture', ('Room %s'):format(currentAssignment.roomId), {
        {
            title = 'Place Furniture',
            description = 'Beds, dressers, electronics, plants, decor, and more.',
            onSelect = openFurniturePlacementMenu
        },
        {
            title = 'Move Room Storage',
            description = 'Place the stash marker or use a storage prop.',
            onSelect = openStashPlacementMenu
        },
        {
            title = 'Remove Nearest Furniture',
            description = 'Deletes the closest saved object near you.',
            onSelect = removeNearestFurniture
        },
        {
            title = 'Clear Room Furniture',
            description = 'Remove every saved furniture object.',
            tone = 'danger',
            onSelect = clearAllFurniture
        },
        {
            title = 'Back',
            description = 'Return to room controls.',
            onSelect = openRoomMenu
        }
    })
end

openRoomMenu = function()
    if not currentAssignment and not loadAssignment(false) then return end

    showMenu(('Room %s'):format(currentAssignment.roomId), ('%s - Floor %s'):format(Config.Branding.Name, currentAssignment.floor), {
        {
            title = 'Unlock Door',
            description = 'Unlock your assigned room door.',
            onSelect = function()
                setDoorLocked(false)
            end
        },
        {
            title = 'Lock Door',
            description = 'Lock your assigned room door.',
            onSelect = function()
                setDoorLocked(true)
            end
        },
        {
            title = 'Furniture',
            description = 'Place objects or move your stash.',
            onSelect = openFurnitureMenu
        }
    })
end

openLobbyMenu = function()
    if not currentAssignment and not loadAssignment(false) then return end

    showMenu(Config.Branding.Name, 'Room Assignment', {
        {
            title = ('Room %s'):format(currentAssignment.roomId),
            description = ('Floor %s - assigned to this character.'):format(currentAssignment.floor),
            disabled = true
        }
    })
end

local function getElevatorLocationCoords(location)
    return vectorFromCoords(location.coords)
end

local function getNearestElevator(coords)
    if not Config.Elevator.Enabled then return nil end

    local nearest
    local nearestDistance = Config.Elevator.Distance or Config.Interaction.ElevatorDistance or 1.6

    for i = 1, #Config.Elevator.Locations do
        local location = Config.Elevator.Locations[i]
        local distance = #(coords - getElevatorLocationCoords(location))

        if distance <= nearestDistance then
            nearest = location
            nearestDistance = distance
        end
    end

    return nearest, nearestDistance
end

local function requestFloorIpl(location)
    if not location or not location.floor or location.floor <= 0 then return end

    local floorData = Config.Wiwang.Floors[location.floor]
    if floorData and floorData.ipl then
        RequestIpl(floorData.ipl)
    end
end

local function teleportToElevator(location)
    if not location or not location.coords then return end

    local ped = PlayerPedId()
    local coords = location.coords
    local z = coords.z + (Config.Elevator.TeleportZOffset or -1.0)

    requestFloorIpl(location)

    if Config.Elevator.Fade then
        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do Wait(0) end
    end

    SetEntityCoords(ped, coords.x, coords.y, z, false, false, false, false)
    SetEntityHeading(ped, coords.w or 0.0)

    if Config.Elevator.Fade then
        Wait(350)
        DoScreenFadeIn(500)
    end
end

openElevatorMenu = function(currentLocation)
    if not Config.Elevator.Enabled then return end

    local pedCoords = GetEntityCoords(PlayerPedId())
    currentLocation = currentLocation or getNearestElevator(pedCoords)

    local options = {}
    for i = 1, #Config.Elevator.Locations do
        local location = Config.Elevator.Locations[i]
        local isCurrent = currentLocation and currentLocation.id == location.id
        local isAssigned = currentAssignment and location.floor == currentAssignment.floor
        local description = isCurrent and 'You are here.' or 'Travel to this floor.'

        if isAssigned then
            description = description .. ' Your room is on this floor.'
        end

        options[#options + 1] = {
            title = location.label,
            description = description,
            disabled = isCurrent,
            onSelect = function()
                teleportToElevator(location)
            end
        }
    end

    showMenu('Elevator', 'Select a floor', options)
end

local function rotationToDirection(rotation)
    local x = math.rad(rotation.x)
    local z = math.rad(rotation.z)
    local cosine = math.abs(math.cos(x))

    return vector3(-math.sin(z) * cosine, math.cos(z) * cosine, math.sin(x))
end

local function normalized2D(vector)
    local flat = vector3(vector.x, vector.y, 0.0)
    local length = #flat

    if length < 0.001 then
        return vector3(0.0, 1.0, 0.0)
    end

    return vector3(flat.x / length, flat.y / length, 0.0)
end

local function getCameraAxes()
    local forward = normalized2D(rotationToDirection(GetGameplayCamRot(2)))
    local right = vector3(forward.y, -forward.x, 0.0)

    return forward, right
end

local function getCameraPlacementCoords()
    local camCoords = GetGameplayCamCoord()
    local direction = rotationToDirection(GetGameplayCamRot(2))
    local distance = Config.Furniture.PlacementRayDistance or 6.0
    local target = camCoords + (direction * distance)
    local ray = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, target.x, target.y, target.z, -1, PlayerPedId(), 0)
    local _, hit, endCoords = GetShapeTestResult(ray)

    if hit == 1 then
        return endCoords
    end

    local ped = PlayerPedId()
    local forward = GetEntityForwardVector(ped)
    local base = GetEntityCoords(ped) + (forward * (Config.Furniture.PlacementDistance or 2.4))

    return vector3(base.x, base.y, base.z)
end

local function updatePreviewObject(object, coords, heading, snapToGround)
    if not object or not DoesEntityExist(object) then return coords end

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    SetEntityCoordsNoOffset(object, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(object, heading)

    if snapToGround then
        PlaceObjectOnGroundProperly(object)
        local snapped = GetEntityCoords(object)
        coords = vector3(snapped.x, snapped.y, snapped.z)
    end

    return coords
end

local function drawPlacementMarker(coords)
    local marker = Config.Stash.DefaultMarker
    DrawMarker(marker.Type, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, marker.Size.x, marker.Size.y, marker.Size.z, marker.Color.r, marker.Color.g, marker.Color.b, marker.Color.a, false, false, 2, false, nil, nil, false)
end

startPlacement = function(data)
    if placementActive or not currentAssignment then return end
    clearPlacementPreview()
    cleanupStalePlacementPreviews()
    placementActive = true

    local controls = Config.Furniture.Controls
    local preview = Config.Furniture.Preview or {}
    local coords = getCameraPlacementCoords()
    local heading = GetEntityHeading(PlayerPedId())
    local ghost

    if data.model then
        ghost = spawnPlacedObject(data.model, coords, heading, {
            ghost = true,
            alpha = preview.Alpha or 190,
            outline = preview.Outline,
            outlineColor = preview.OutlineColor
        })

        if not ghost then
            placementActive = false
            clearPlacementPreview()
            notify('error', 'That GTA prop could not be loaded.')
            return
        end

        placementGhost = ghost
        coords = updatePreviewObject(ghost, coords, heading, controls.SnapToGround)
    end

    showPlacementGuide()

    CreateThread(function()
        while placementActive do
            Wait(0)

            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)

            local step = controls.MoveStep or 0.035
            if IsControlPressed(0, 21) then
                step = step * (controls.FastMultiplier or 3.0)
            end

            local forward, right = getCameraAxes()

            if IsControlPressed(0, 172) then coords = coords + (forward * step) end
            if IsControlPressed(0, 173) then coords = coords - (forward * step) end
            if IsControlPressed(0, 175) then coords = coords + (right * step) end
            if IsControlPressed(0, 174) then coords = coords - (right * step) end
            if IsControlPressed(0, 10) then coords = vector3(coords.x, coords.y, coords.z + (controls.HeightStep or 0.035)) end
            if IsControlPressed(0, 11) then coords = vector3(coords.x, coords.y, coords.z - (controls.HeightStep or 0.035)) end
            if IsControlPressed(0, 44) then heading = heading - (controls.RotateStep or 2.0) end
            if IsControlPressed(0, 38) then heading = heading + (controls.RotateStep or 2.0) end

            if ghost and DoesEntityExist(ghost) then
                coords = updatePreviewObject(ghost, coords, heading, controls.SnapToGround)
            else
                drawPlacementMarker(coords)
            end

            if IsControlJustReleased(0, 191) then
                placementActive = false
                hidePrompt()

                if ghost and DoesEntityExist(ghost) then
                    local finalCoords = GetEntityCoords(ghost)
                    coords = vector3(finalCoords.x, finalCoords.y, finalCoords.z)
                end

                clearPlacementPreview()

                if data.type == 'furniture' then
                    local ok, message, furniture = callServer('saveFurniture', currentAssignment.hotelId, currentAssignment.roomId, {
                        label = data.label,
                        model = data.model,
                        x = coords.x,
                        y = coords.y,
                        z = coords.z,
                        heading = heading
                    })

                    if ok then
                        spawnFurniture(furniture)
                    end
                    notify(ok and 'success' or 'error', message or Config.Text.DatabaseError)
                else
                    local ok, message, stash = callServer('saveStashPlacement', currentAssignment.hotelId, currentAssignment.roomId, {
                        mode = data.mode,
                        model = data.model,
                        x = coords.x,
                        y = coords.y,
                        z = coords.z,
                        heading = heading
                    })

                    if ok then
                        spawnStash(stash)
                    end
                    notify(ok and 'success' or 'error', message or Config.Text.DatabaseError)
                end
            elseif IsControlJustReleased(0, 177) then
                placementActive = false
                hidePrompt()
                clearPlacementPreview()
                notify('inform', 'Placement cancelled.')
            end
        end
    end)
end

local function createLobbyBlip()
    local blipConfig = Config.Lobby.Blip
    if not blipConfig or not blipConfig.Enabled then return end

    local coords = Config.Lobby.Coords
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, blipConfig.Sprite or 475)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, blipConfig.Scale or 0.72)
    SetBlipColour(blip, blipConfig.Color or 1)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(blipConfig.Label or Config.Branding.Name)
    EndTextCommandSetBlipName(blip)
end

local function createLobbyPed()
    local pedConfig = Config.Lobby.Ped
    if not pedConfig or not pedConfig.Enabled then return end

    local hash = loadModel(pedConfig.Model)
    if not hash then return end

    local coords = pedConfig.Coords
    lobbyPed = CreatePed(0, hash, coords.x, coords.y, coords.z + (pedConfig.SpawnZOffset or 0.0), coords.w or 0.0, false, false)
    FreezeEntityPosition(lobbyPed, true)
    SetEntityInvincible(lobbyPed, true)
    SetBlockingOfNonTemporaryEvents(lobbyPed, true)

    if pedConfig.Scenario then
        TaskStartScenarioInPlace(lobbyPed, pedConfig.Scenario, 0, true)
    end

    SetModelAsNoLongerNeeded(hash)
end

local function getRoomDoorCoords(room)
    return vector3(room.door.x, room.door.y, room.door.z)
end

local function getRoomMarkerCoords(room)
    if room.marker then
        return room.marker
    end

    return vector3(room.door.x, room.door.y, room.door.z + (Config.RoomMarker.ZOffset or -0.95))
end

local function isOnMarkerSide(playerCoords, room)
    if Config.RoomMarker.VisibleFromRoomSide then return true end
    if not room.marker then return true end

    local door = getRoomDoorCoords(room)
    local marker = getRoomMarkerCoords(room)
    local markerVector = vector3(marker.x - door.x, marker.y - door.y, 0.0)
    local playerVector = vector3(playerCoords.x - door.x, playerCoords.y - door.y, 0.0)

    return ((markerVector.x * playerVector.x) + (markerVector.y * playerVector.y)) >= -0.02
end

CreateThread(function()
    SetNuiFocus(false, false)
    sendTheme()
    createLobbyBlip()
    createLobbyPed()

    Wait(1500)
    loadAssignment(true)
end)

CreateThread(function()
    while true do
        local sleep = 750

        if not placementActive then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local promptHandled = false

            if currentRoom and Config.RoomMarker.Enabled then
                local doorCoords = getRoomDoorCoords(currentRoom)
                local markerCoords = getRoomMarkerCoords(currentRoom)
                local doorDistance = #(coords - doorCoords)
                local markerDistance = #(coords - markerCoords)

                if markerDistance <= Config.RoomMarker.DrawDistance and isOnMarkerSide(coords, currentRoom) then
                    sleep = 0
                    DrawMarker(Config.RoomMarker.Type, markerCoords.x, markerCoords.y, markerCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Config.RoomMarker.Size.x, Config.RoomMarker.Size.y, Config.RoomMarker.Size.z, Config.RoomMarker.Color.r, Config.RoomMarker.Color.g, Config.RoomMarker.Color.b, Config.RoomMarker.Color.a, false, false, 2, false, nil, nil, false)
                end

                if useTextUI() and doorDistance <= Config.Interaction.DoorDistance then
                    sleep = 0
                    promptHandled = true
                    showPrompt(('Room %s'):format(currentAssignment.roomId))

                    if IsControlJustReleased(0, Config.Interaction.Key) then
                        openRoomMenu()
                    end
                end
            end

            if currentStash then
                local stashCoords = vectorFromPlacement(currentStash)
                local distance = #(coords - stashCoords)

                if currentStash.mode == 'marker' and distance <= 12.0 then
                    sleep = 0
                    DrawMarker(Config.Stash.DefaultMarker.Type, stashCoords.x, stashCoords.y, stashCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Config.Stash.DefaultMarker.Size.x, Config.Stash.DefaultMarker.Size.y, Config.Stash.DefaultMarker.Size.z, Config.Stash.DefaultMarker.Color.r, Config.Stash.DefaultMarker.Color.g, Config.Stash.DefaultMarker.Color.b, Config.Stash.DefaultMarker.Color.a, false, false, 2, false, nil, nil, false)
                end

                if useTextUI() and not promptHandled and distance <= Config.Interaction.StashDistance then
                    sleep = 0
                    promptHandled = true
                    showPrompt('Open Room Storage')

                    if IsControlJustReleased(0, Config.Interaction.Key) then
                        openStash()
                    end
                end
            end

            local lobbyPoint = getLobbyInteractionPoint()
            local lobbyCoords = vector3(lobbyPoint.x, lobbyPoint.y, lobbyPoint.z)
            local lobbyDistance = #(coords - lobbyCoords)
            local lobbyDistanceLimit = (Config.Lobby.Interaction and Config.Lobby.Interaction.Distance) or Config.Interaction.Distance
            if useTextUI() and not promptHandled and lobbyDistance <= lobbyDistanceLimit then
                sleep = 0
                promptHandled = true
                showPrompt('View Room Number')

                if IsControlJustReleased(0, Config.Interaction.Key) then
                    openLobbyMenu()
                end
            end

            local elevatorLocation = getNearestElevator(coords)
            if useTextUI() and not promptHandled and elevatorLocation then
                sleep = 0
                promptHandled = true
                showPrompt(Config.Elevator.Prompt or 'Use Elevator')

                if IsControlJustReleased(0, Config.Interaction.Key) then
                    openElevatorMenu(elevatorLocation)
                end
            end

            if useTextUI() and not promptHandled then
                hidePrompt()
            end
        end

        Wait(sleep)
    end
end)

RegisterNetEvent('zeekota_hotel:client:refreshRoom', refreshRoomContent)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    hidePrompt()
    closeMenu()
    clearPlacementPreview()
    clearFurnitureObjects()
    deleteEntity(spawnedStashProp)
    deleteEntity(lobbyPed)
end)

exports('GetCurrentRoom', function()
    return currentAssignment
end)

exports('IsInsideRoom', function()
    return currentAssignment ~= nil
end)
