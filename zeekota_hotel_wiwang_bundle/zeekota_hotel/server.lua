local Framework = {
    name = nil,
    object = nil
}

local ServerCallbacks = {}
local unpack = table.unpack or unpack

local function resourceStarted(name)
    return name and (GetResourceState(name) == 'started' or GetResourceState(name) == 'starting')
end

local function printf(message, ...)
    if Config.Debug then
        print(('[%s] ' .. message):format(Config.ResourceName, ...))
    end
end

local function detectFramework()
    if Config.Framework ~= 'auto' then
        return Config.Framework
    end

    if resourceStarted(Config.FrameworkResources.ox) then return 'ox' end
    if resourceStarted(Config.FrameworkResources.qb) then return 'qb' end
    if resourceStarted(Config.FrameworkResources.esx) then return 'esx' end

    return nil
end

local function loadFramework()
    Framework.name = detectFramework()
    Framework.object = nil

    if Framework.name == 'esx' then
        local ok, object = pcall(function()
            return exports[Config.FrameworkResources.esx]:getSharedObject()
        end)
        Framework.object = ok and object or nil
    elseif Framework.name == 'qb' then
        local ok, object = pcall(function()
            return exports[Config.FrameworkResources.qb]:GetCoreObject()
        end)
        Framework.object = ok and object or nil
    elseif Framework.name == 'ox' then
        Framework.object = exports[Config.FrameworkResources.ox]
    end

    print(('[%s] Framework: %s'):format(Config.ResourceName, Framework.name or 'standalone'))
end

local function getIdentifierFallback(src)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local identifier = GetPlayerIdentifier(src, i)
        if identifier and identifier:find('license:', 1, true) then
            return identifier
        end
    end

    return GetPlayerIdentifier(src, 0)
end

local function callPlayerMethod(player, method, ...)
    if not player or type(player[method]) ~= 'function' then return nil end

    local ok, result = pcall(player[method], player, ...)
    if ok then return result end

    ok, result = pcall(player[method], ...)
    if ok then return result end

    return nil
end

local function getOxPlayer(src)
    if rawget(_G, 'Ox') and type(Ox.GetPlayer) == 'function' then
        local ok, player = pcall(Ox.GetPlayer, src)
        if ok and player then return player end
    end

    if not Framework.object then return nil end

    local ok, player = pcall(function()
        return Framework.object:GetPlayer(src)
    end)
    if ok and player then return player end

    ok, player = pcall(function()
        return Framework.object.GetPlayer(src)
    end)
    if ok and player then return player end

    ok, player = pcall(function()
        return Framework.object:getPlayer(src)
    end)

    return ok and player or nil
end

local function getPlayerData(src)
    if Framework.name == 'esx' and Framework.object then
        local player = Framework.object.GetPlayerFromId(src)
        if not player then return nil end

        return {
            source = src,
            player = player,
            identifier = player.identifier or callPlayerMethod(player, 'getIdentifier') or getIdentifierFallback(src),
            name = callPlayerMethod(player, 'getName') or GetPlayerName(src),
            framework = 'esx'
        }
    end

    if Framework.name == 'qb' and Framework.object then
        local player = Framework.object.Functions.GetPlayer(src)
        if not player then return nil end

        local data = player.PlayerData or {}
        local charinfo = data.charinfo or {}
        local displayName = (charinfo.firstname and charinfo.lastname) and (charinfo.firstname .. ' ' .. charinfo.lastname) or GetPlayerName(src)

        return {
            source = src,
            player = player,
            identifier = data.citizenid or getIdentifierFallback(src),
            name = displayName,
            framework = 'qb'
        }
    end

    if Framework.name == 'ox' then
        local player = getOxPlayer(src)
        local identifier = nil
        local displayName = GetPlayerName(src)

        if player then
            identifier = player.charId or player.charid or player.citizenid or player.identifier
            displayName = player.name or displayName

            if type(player.get) == 'function' then
                identifier = identifier or callPlayerMethod(player, 'get', 'charId') or callPlayerMethod(player, 'get', 'identifier') or callPlayerMethod(player, 'get', 'citizenid')
                displayName = callPlayerMethod(player, 'get', 'name') or displayName
            end
        end

        return {
            source = src,
            player = player,
            identifier = identifier and ('ox:%s'):format(identifier) or getIdentifierFallback(src),
            name = displayName,
            framework = 'ox'
        }
    end

    local identifier = getIdentifierFallback(src)
    if identifier then
        return {
            source = src,
            identifier = identifier,
            name = GetPlayerName(src),
            framework = 'standalone'
        }
    end

    return nil
end

local function sanitize(value)
    return tostring(value or ''):gsub('[^%w_%-]', '_')
end

local function hashIdentifier(identifier, max)
    local hash = 0
    identifier = tostring(identifier or '')

    for i = 1, #identifier do
        hash = ((hash * 31) + identifier:byte(i)) % 2147483647
    end

    return (hash % max) + 1
end

local function makeStashId(identifier, hotelId, roomId)
    return ('%s_%s_%s_%s'):format(Config.ResourceName, sanitize(hotelId), sanitize(roomId), sanitize(identifier)):sub(1, 96)
end

local function getRoomConfig(hotelId, roomId)
    local hotel = Config.Hotels[hotelId]
    if not hotel then return nil, nil end

    roomId = tostring(roomId)
    for i = 1, #hotel.Rooms do
        if hotel.Rooms[i].id == roomId then
            return hotel.Rooms[i], hotel, i
        end
    end
end

local function assignmentFromRow(row)
    if not row then return nil end

    local room, hotel = getRoomConfig(row.hotel, row.room_id)
    if not room then return nil end

    return {
        identifier = row.identifier,
        framework = row.framework,
        playerName = row.player_name,
        hotelId = row.hotel,
        hotelLabel = hotel.Label,
        roomId = row.room_id,
        roomLabel = room.label,
        floor = room.floor,
        roomIndex = room.roomIndex,
        stashId = row.stash_id,
        assignedAt = row.assigned_at or row.rented_at,
        lastSeen = row.last_seen
    }
end

local function fetchAssignment(identifier)
    return MySQL.single.await(('SELECT * FROM `%s` WHERE identifier = ? LIMIT 1'):format(Config.Database.Rooms), { identifier })
end

local function ensureColumn(tableName, column, definition)
    local exists = MySQL.single.await(('SHOW COLUMNS FROM `%s` LIKE ?'):format(tableName), { column })
    if not exists then
        MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(tableName, column, definition))
    end
end

local function ensureDatabase()
    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(120) NOT NULL,
            `framework` VARCHAR(20) NOT NULL DEFAULT 'standalone',
            `player_name` VARCHAR(100) NULL,
            `hotel` VARCHAR(64) NOT NULL,
            `room_id` VARCHAR(32) NOT NULL,
            `stash_id` VARCHAR(96) NOT NULL,
            `assigned_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `last_seen` TIMESTAMP NULL DEFAULT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `identifier_unique` (`identifier`),
            KEY `hotel_index` (`hotel`),
            KEY `room_index` (`hotel`, `room_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]):format(Config.Database.Rooms))

    ensureColumn(Config.Database.Rooms, 'assigned_at', 'TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP')
    ensureColumn(Config.Database.Rooms, 'last_seen', 'TIMESTAMP NULL DEFAULT NULL')

    local roomUnique = MySQL.single.await(('SHOW INDEX FROM `%s` WHERE Key_name = ?'):format(Config.Database.Rooms), { 'hotel_room_unique' })
    if roomUnique and Config.RoomAssignment.ReuseWhenFull then
        MySQL.query.await(('ALTER TABLE `%s` DROP INDEX `hotel_room_unique`'):format(Config.Database.Rooms))
    end

    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(120) NOT NULL,
            `hotel` VARCHAR(64) NOT NULL,
            `room_id` VARCHAR(32) NOT NULL,
            `label` VARCHAR(80) NOT NULL,
            `model` VARCHAR(80) NOT NULL,
            `x` DOUBLE NOT NULL,
            `y` DOUBLE NOT NULL,
            `z` DOUBLE NOT NULL,
            `heading` DOUBLE NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `owner_room_index` (`identifier`, `hotel`, `room_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]):format(Config.Database.Furniture))

    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(120) NOT NULL,
            `hotel` VARCHAR(64) NOT NULL,
            `room_id` VARCHAR(32) NOT NULL,
            `mode` VARCHAR(20) NOT NULL DEFAULT 'marker',
            `model` VARCHAR(80) NULL,
            `x` DOUBLE NOT NULL,
            `y` DOUBLE NOT NULL,
            `z` DOUBLE NOT NULL,
            `heading` DOUBLE NOT NULL DEFAULT 0,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `owner_unique` (`identifier`, `hotel`, `room_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]):format(Config.Database.Stashes))
end

local function getAssignableRoom(identifier)
    local hotelId = Config.RoomAssignment.HotelId
    local hotel = Config.Hotels[hotelId]
    if not hotel or #hotel.Rooms == 0 then return nil end

    if not Config.RoomAssignment.UniqueRooms then
        return hotel.Rooms[hashIdentifier(identifier, #hotel.Rooms)], hotelId
    end

    local rows = MySQL.query.await(('SELECT room_id FROM `%s` WHERE hotel = ?'):format(Config.Database.Rooms), { hotelId }) or {}
    local occupied = {}

    for i = 1, #rows do
        occupied[tostring(rows[i].room_id)] = true
    end

    for i = 1, #hotel.Rooms do
        local room = hotel.Rooms[i]
        if not occupied[room.id] then
            return room, hotelId
        end
    end

    if Config.RoomAssignment.ReuseWhenFull then
        return hotel.Rooms[hashIdentifier(identifier, #hotel.Rooms)], hotelId
    end
end

local function registerStash(assignment)
    if not Config.Stash.Enabled or not assignment or not resourceStarted('ox_inventory') then return end

    local owner = false
    if Config.Stash.OwnerMode == 'identifier' then
        owner = assignment.identifier
    end

    exports.ox_inventory:RegisterStash(
        assignment.stashId,
        ('%s %s'):format(Config.Stash.LabelPrefix, assignment.roomId),
        Config.Stash.Slots,
        Config.Stash.Weight,
        owner
    )
end

local function createAssignment(data)
    local room, hotelId = getAssignableRoom(data.identifier)
    if not room then
        return nil, 'No Wiwang Hotel rooms are configured or available.'
    end

    local stashId = makeStashId(data.identifier, hotelId, room.id)
    local inserted = MySQL.insert.await(([[
        INSERT INTO `%s` (identifier, framework, player_name, hotel, room_id, stash_id, last_seen)
        VALUES (?, ?, ?, ?, ?, ?, NOW())
    ]]):format(Config.Database.Rooms), {
        data.identifier,
        data.framework,
        data.name,
        hotelId,
        room.id,
        stashId
    })

    if not inserted then
        local existing = fetchAssignment(data.identifier)
        return assignmentFromRow(existing), Config.Text.DatabaseError
    end

    local assignment = assignmentFromRow(fetchAssignment(data.identifier))
    if assignment then
        registerStash(assignment)
        printf('%s assigned %s/%s', data.identifier, assignment.hotelId, assignment.roomId)
    end

    return assignment, Config.Text.AssignedNew:format(room.id), true
end

local function ensureAssignment(src)
    local data = getPlayerData(src)
    if not data then
        return nil, Config.Text.FrameworkMissing
    end

    local row = fetchAssignment(data.identifier)
    local assignment = assignmentFromRow(row)

    if row and not assignment then
        MySQL.update.await(('DELETE FROM `%s` WHERE identifier = ?'):format(Config.Database.Rooms), { data.identifier })
    elseif assignment then
        MySQL.update.await(('UPDATE `%s` SET framework = ?, player_name = ?, last_seen = NOW() WHERE identifier = ?'):format(Config.Database.Rooms), {
            data.framework,
            data.name,
            data.identifier
        })
        registerStash(assignment)
        return assignment
    end

    return createAssignment(data)
end

local function canAccessRoom(src, hotelId, roomId)
    local assignment, message = ensureAssignment(src)
    if not assignment then return nil, message end

    if assignment.hotelId ~= hotelId or assignment.roomId ~= tostring(roomId) then
        return nil, Config.Text.DoorNotYours
    end

    return assignment
end

local function furnitureAllowed(model)
    model = tostring(model or '')

    for i = 1, #Config.Furniture.Categories do
        local category = Config.Furniture.Categories[i]
        for j = 1, #category.items do
            if category.items[j].model == model then
                return true
            end
        end
    end

    return false
end

local function stashPropAllowed(model)
    if not model then return true end
    model = tostring(model)

    for i = 1, #Config.Stash.Props do
        if Config.Stash.Props[i].model == model then
            return true
        end
    end

    return false
end

local function normalizePlacement(placement)
    placement = placement or {}

    local x = tonumber(placement.x)
    local y = tonumber(placement.y)
    local z = tonumber(placement.z)
    local heading = tonumber(placement.heading) or 0.0

    if not x or not y or not z then
        return nil
    end

    return {
        x = x,
        y = y,
        z = z,
        heading = heading,
        model = placement.model and tostring(placement.model) or nil,
        label = placement.label and tostring(placement.label) or nil,
        mode = placement.mode
    }
end

local function getFurnitureRows(assignment)
    return MySQL.query.await(([[
        SELECT id, label, model, x, y, z, heading
        FROM `%s`
        WHERE identifier = ? AND hotel = ? AND room_id = ?
        ORDER BY id ASC
    ]]):format(Config.Database.Furniture), {
        assignment.identifier,
        assignment.hotelId,
        assignment.roomId
    }) or {}
end

local function getStashPlacement(assignment)
    local row = MySQL.single.await(([[
        SELECT mode, model, x, y, z, heading
        FROM `%s`
        WHERE identifier = ? AND hotel = ? AND room_id = ?
        LIMIT 1
    ]]):format(Config.Database.Stashes), {
        assignment.identifier,
        assignment.hotelId,
        assignment.roomId
    })

    if row then
        return row
    end

    local room = getRoomConfig(assignment.hotelId, assignment.roomId)
    local heading = room and room.door and room.door.w or 0.0
    local stash = room and room.stash or vector3(0.0, 0.0, 0.0)

    return {
        mode = 'marker',
        model = nil,
        x = stash.x,
        y = stash.y,
        z = stash.z,
        heading = heading
    }
end

local function setDoorState(room, state)
    if not Config.DoorLock.Enabled then
        return false, Config.Text.DoorLockMissing
    end

    local resource = Config.DoorLock.Resource
    if not resourceStarted(resource) then
        return false, Config.Text.DoorLockMissing
    end

    local ok, door = pcall(function()
        return exports[resource]:getDoorFromName(room.doorName)
    end)

    if not ok or not door or not door.id then
        return false, Config.Text.DoorLockMissing
    end

    local doorState = state and 1 or 0
    local setOk = pcall(function()
        return exports[resource]:setDoorState(door.id, doorState)
    end)

    if not setOk then
        TriggerEvent('ox_doorlock:setState', door.id, doorState)
    end

    return true, state and Config.Text.DoorLocked or Config.Text.DoorUnlocked
end

local function registerServerCallback(name, fn)
    ServerCallbacks[name] = fn
end

RegisterNetEvent('zeekota_hotel:server:callback', function(name, requestId, ...)
    local src = source
    local callback = ServerCallbacks[name]

    if not callback then
        TriggerClientEvent('zeekota_hotel:client:callback', src, requestId, false, 'Unknown hotel request.')
        return
    end

    local results = table.pack(pcall(callback, src, ...))
    if not results[1] then
        print(('[%s] Callback "%s" failed: %s'):format(Config.ResourceName, tostring(name), tostring(results[2])))
        TriggerClientEvent('zeekota_hotel:client:callback', src, requestId, false, Config.Text.DatabaseError)
        return
    end

    TriggerClientEvent('zeekota_hotel:client:callback', src, requestId, unpack(results, 2, results.n))
end)

registerServerCallback('getMyRoom', function(src)
    local assignment, message, created = ensureAssignment(src)
    if not assignment then
        return false, message or Config.Text.NoAssignment
    end

    return true, created and message or nil, assignment, getStashPlacement(assignment), getFurnitureRows(assignment)
end)

registerServerCallback('getRoomContent', function(src, hotelId, roomId)
    local assignment, message = canAccessRoom(src, hotelId, roomId)
    if not assignment then
        return false, message
    end

    return true, nil, getFurnitureRows(assignment), getStashPlacement(assignment)
end)

registerServerCallback('getStash', function(src, hotelId, roomId)
    local assignment, message = canAccessRoom(src, hotelId, roomId)
    if not assignment then
        return false, message
    end

    registerStash(assignment)
    return true, nil, assignment.stashId
end)

registerServerCallback('setDoorState', function(src, hotelId, roomId, locked)
    local assignment, message = canAccessRoom(src, hotelId, roomId)
    if not assignment then
        return false, message
    end

    local room = getRoomConfig(hotelId, roomId)
    if not room then
        return false, Config.Text.DatabaseError
    end

    return setDoorState(room, locked == true)
end)

registerServerCallback('saveFurniture', function(src, hotelId, roomId, placement)
    local assignment, message = canAccessRoom(src, hotelId, roomId)
    if not assignment then
        return false, message
    end

    if not Config.Furniture.Enabled then
        return false, 'Furniture is disabled.'
    end

    placement = normalizePlacement(placement)
    if not placement then
        return false, 'Invalid furniture placement.'
    end

    if not furnitureAllowed(placement.model) then
        return false, 'That furniture prop is not configured.'
    end

    local count = MySQL.scalar.await(('SELECT COUNT(*) FROM `%s` WHERE identifier = ? AND hotel = ? AND room_id = ?'):format(Config.Database.Furniture), {
        assignment.identifier,
        assignment.hotelId,
        assignment.roomId
    }) or 0

    if tonumber(count) >= Config.Furniture.MaxPerRoom then
        return false, ('Room furniture limit reached (%s).'):format(Config.Furniture.MaxPerRoom)
    end

    MySQL.insert.await(([[
        INSERT INTO `%s` (identifier, hotel, room_id, label, model, x, y, z, heading)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]):format(Config.Database.Furniture), {
        assignment.identifier,
        assignment.hotelId,
        assignment.roomId,
        tostring(placement.label or placement.model),
        tostring(placement.model),
        placement.x,
        placement.y,
        placement.z,
        placement.heading
    })

    return true, Config.Text.FurnitureSaved, getFurnitureRows(assignment)
end)

registerServerCallback('deleteFurniture', function(src, hotelId, roomId, furnitureId)
    local assignment, message = canAccessRoom(src, hotelId, roomId)
    if not assignment then
        return false, message
    end

    local removed = MySQL.update.await(([[
        DELETE FROM `%s`
        WHERE id = ? AND identifier = ? AND hotel = ? AND room_id = ?
    ]]):format(Config.Database.Furniture), {
        tonumber(furnitureId),
        assignment.identifier,
        assignment.hotelId,
        assignment.roomId
    })

    if not removed or removed < 1 then
        return false, 'No furniture item was close enough to remove.'
    end

    return true, Config.Text.FurnitureDeleted, getFurnitureRows(assignment)
end)

registerServerCallback('clearFurniture', function(src, hotelId, roomId)
    local assignment, message = canAccessRoom(src, hotelId, roomId)
    if not assignment then
        return false, message
    end

    MySQL.update.await(('DELETE FROM `%s` WHERE identifier = ? AND hotel = ? AND room_id = ?'):format(Config.Database.Furniture), {
        assignment.identifier,
        assignment.hotelId,
        assignment.roomId
    })

    return true, Config.Text.FurnitureDeleted, {}
end)

registerServerCallback('saveStashPlacement', function(src, hotelId, roomId, placement)
    local assignment, message = canAccessRoom(src, hotelId, roomId)
    if not assignment then
        return false, message
    end

    placement = normalizePlacement(placement)
    if not placement then
        return false, 'Invalid storage placement.'
    end

    local mode = placement.mode == 'prop' and 'prop' or 'marker'
    local model = mode == 'prop' and placement.model or nil

    if mode == 'prop' and not stashPropAllowed(model) then
        return false, 'That stash prop is not configured.'
    end

    MySQL.insert.await(([[
        INSERT INTO `%s` (identifier, hotel, room_id, mode, model, x, y, z, heading)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            mode = VALUES(mode),
            model = VALUES(model),
            x = VALUES(x),
            y = VALUES(y),
            z = VALUES(z),
            heading = VALUES(heading),
            updated_at = CURRENT_TIMESTAMP
    ]]):format(Config.Database.Stashes), {
        assignment.identifier,
        assignment.hotelId,
        assignment.roomId,
        mode,
        model,
        placement.x,
        placement.y,
        placement.z,
        placement.heading
    })

    return true, Config.Text.StashMoved, getStashPlacement(assignment)
end)

local function assignLater(src)
    if not Config.RoomAssignment.AssignOnJoin then return end

    SetTimeout(1500, function()
        if GetPlayerName(src) then
            ensureAssignment(src)
        end
    end)
end

RegisterNetEvent('esx:playerLoaded', function(playerId)
    assignLater(playerId or source)
end)

RegisterNetEvent('QBCore:Server:PlayerLoaded', function()
    assignLater(source)
end)

RegisterNetEvent('ox:playerLoaded', function(playerId)
    assignLater(playerId or source)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    loadFramework()

    if Config.Map and Config.Map.Required and not resourceStarted(Config.Map.Resource) then
        print(('[%s] Warning: required map resource "%s" is not started. Ensure it before %s.'):format(Config.ResourceName, Config.Map.Resource, Config.ResourceName))
    end

    ensureDatabase()

    CreateThread(function()
        Wait(2500)
        for _, playerId in ipairs(GetPlayers()) do
            assignLater(tonumber(playerId))
        end
    end)
end)

exports('GetPlayerRoom', function(src)
    local data = getPlayerData(src)
    if not data then return nil end

    return assignmentFromRow(fetchAssignment(data.identifier))
end)

exports('GetPlayerRental', function(src)
    local data = getPlayerData(src)
    if not data then return nil end

    return assignmentFromRow(fetchAssignment(data.identifier))
end)
