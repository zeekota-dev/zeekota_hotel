Config = {}

Config.ResourceName = 'zeekota_hotel'
Config.Debug = false

Config.Database = {
    Rooms = 'zeekota_hotel_rooms',
    Furniture = 'zeekota_hotel_furniture',
    Stashes = 'zeekota_hotel_stashes'
}

Config.Branding = {
    Name = 'Wiwang Hotel',
    ShortName = 'WH',
    Accent = '#e50914',
    NotifyTitle = 'Wiwang Hotel',
    UiSubtitle = 'Guest Services'
}

Config.UI = {
    Colors = {
        Accent = '#e50914',
        AccentDark = '#7a050b',
        AccentSoft = 'rgba(229, 9, 20, 0.26)',
        Background = 'rgba(6, 7, 10, 0.78)',
        Panel = 'rgba(12, 13, 17, 0.98)',
        PanelAlt = 'rgba(31, 33, 39, 0.94)',
        Text = '#ffffff',
        Muted = '#b8bcc7',
        Border = 'rgba(255, 255, 255, 0.16)',
        Success = '#25d17f',
        Danger = '#ff4655',
        Shadow = 'rgba(0, 0, 0, 0.58)'
    },
    Gradients = {
        Prompt = 'linear-gradient(135deg, rgba(229, 9, 20, 0.98), rgba(10, 10, 14, 0.96) 46%, rgba(122, 5, 11, 0.95))',
        PromptKey = 'linear-gradient(180deg, #ffffff, #e9e9ec)',
        Panel = 'linear-gradient(145deg, rgba(7, 8, 12, 0.99), rgba(22, 23, 29, 0.98) 58%, rgba(80, 4, 10, 0.92))',
        Header = 'linear-gradient(135deg, rgba(229, 9, 20, 0.95), rgba(22, 23, 29, 0.92))',
        Item = 'linear-gradient(135deg, rgba(255, 255, 255, 0.08), rgba(255, 255, 255, 0.035))',
        ItemHover = 'linear-gradient(135deg, rgba(229, 9, 20, 0.32), rgba(255, 255, 255, 0.08))',
        Toast = 'linear-gradient(135deg, rgba(8, 9, 12, 0.98), rgba(22, 23, 29, 0.95))'
    }
}

-- auto, esx, qb, ox
Config.Framework = 'auto'

Config.FrameworkResources = {
    esx = 'es_extended',
    qb = 'qb-core',
    ox = 'ox_core'
}

Config.Map = {
    Name = 'Wiwang Hotel',
    Resource = 'map_wiwang_hotel',
    Required = true,
    Floors = 20,
    RoomsPerFloor = 19,
    TotalRooms = 380,
    Notes = 'Free Wiwang Hotel MLO by Floky. Ensure this map before zeekota_hotel.'
}

Config.Interaction = {
    -- textui, target, both
    Mode = 'textui',
    Key = 38, -- E
    KeyLabel = 'E',
    Distance = 2.0,
    DoorDistance = 1.25,
    StashDistance = 1.7,
    ElevatorDistance = 1.6
}

Config.Target = {
    Enabled = false,
    DrawSprite = true
}

Config.Lobby = {
    Coords = vector4(-819.82, -699.80, 28.07, 90.216),
    Interaction = {
        Coords = vector4(-823.5919, -702.0371, 28.0600, 1.8968),
        Distance = 2.0
    },
    Blip = {
        Enabled = true,
        Sprite = 475,
        Scale = 0.72,
        Color = 1,
        Label = 'Wiwang Hotel'
    },
    Ped = {
        Enabled = true,
        Model = 's_m_m_highsec_01',
        Coords = vector4(-823.5919, -702.0371, 28.0600, 1.8968),
        SpawnZOffset = 0.0,
        Scenario = 'WORLD_HUMAN_CLIPBOARD'
    }
}

Config.Elevator = {
    Enabled = true,
    Prompt = 'Use Elevator',
    Distance = 1.6,
    TeleportZOffset = -1.0,
    Fade = true,
    Lobby = {
        id = 'lobby',
        label = 'Lobby',
        floor = 0,
        coords = vector4(-819.82, -699.80, 28.07, 90.216)
    },
    Locations = {}
}

Config.RoomAssignment = {
    HotelId = 'wiwang',
    AssignOnJoin = true,
    UniqueRooms = true,
    ReuseWhenFull = true
}

Config.RoomMarker = {
    Enabled = true,
    Type = 1, -- cylinder
    DrawDistance = 18.0,
    DistanceFromDoor = 0.8,
    ZOffset = -0.95,
    VisibleFromRoomSide = false,
    Size = vector3(0.65, 0.65, 0.18),
    Color = { r = 229, g = 9, b = 20, a = 150 }
}

Config.DoorLock = {
    Enabled = true,
    Resource = 'ox_doorlock',
    AutoLockOnLeave = false
}

Config.Stash = {
    Enabled = true,
    Slots = 50,
    Weight = 2000000,
    LabelPrefix = 'Wiwang Room',
    OwnerMode = 'identifier', -- none or identifier
    DefaultMarker = {
        Type = 2,
        Size = vector3(0.28, 0.28, 0.28),
        Color = { r = 229, g = 9, b = 20, a = 180 }
    },
    Props = {
        { label = 'Hotel Safe', model = 'prop_ld_int_safe_01' },
        { label = 'Storage Crate', model = 'prop_box_wood02a_pu' },
        { label = 'Wardrobe Cabinet', model = 'prop_cabinet_01' },
        { label = 'Dresser', model = 'prop_cabinet_02b' }
    }
}

Config.Furniture = {
    Enabled = true,
    MaxPerRoom = 50,
    PlacementDistance = 2.4,
    PlacementRayDistance = 6.0,
    StalePreviewCleanup = true,
    StalePreviewCleanupDistance = 3.0,
    Controls = {
        MoveStep = 0.035,
        FastMultiplier = 3.0,
        HeightStep = 0.035,
        RotateStep = 2.0,
        SnapToGround = true
    },
    Preview = {
        Alpha = 190,
        Outline = true,
        OutlineColor = { r = 229, g = 9, b = 20, a = 255 }
    },
    Categories = {
        {
            label = 'Beds',
            icon = 'bed',
            items = {
                { label = 'Basic Bed', model = 'v_res_msonbed' },
                { label = 'Modern Bed', model = 'apa_mp_h_bed_double_08' },
                { label = 'Single Bed', model = 'v_res_tre_bed1' }
            }
        },
        {
            label = 'Dressers',
            icon = 'box',
            items = {
                { label = 'Wood Dresser', model = 'v_res_d_dressingtable' },
                { label = 'Cabinet', model = 'prop_cabinet_02b' },
                { label = 'Small Drawers', model = 'v_res_tre_storageunit' }
            }
        },
        {
            label = 'Nightstands',
            icon = 'table',
            items = {
                { label = 'Nightstand', model = 'v_res_msidetblemod' },
                { label = 'Bedside Table', model = 'v_res_tre_bedsidetable' },
                { label = 'Small Table', model = 'prop_table_02' }
            }
        },
        {
            label = 'Electronics',
            icon = 'tv',
            items = {
                { label = 'Flat TV', model = 'prop_tv_flat_01' },
                { label = 'Laptop', model = 'prop_laptop_lester2' },
                { label = 'Speaker', model = 'prop_speaker_05' }
            }
        },
        {
            label = 'Plants',
            icon = 'leaf',
            items = {
                { label = 'Tall Plant', model = 'prop_plant_int_01a' },
                { label = 'Potted Plant', model = 'prop_plant_int_03a' },
                { label = 'Decor Plant', model = 'prop_plant_int_04a' }
            }
        },
        {
            label = 'Drug Props',
            icon = 'flask',
            items = {
                { label = 'Weed Brick', model = 'prop_weed_block_01' },
                { label = 'Weed Plant', model = 'bkr_prop_weed_01_small_01c' },
                { label = 'Meth Tray', model = 'bkr_prop_meth_tray_01b' },
                { label = 'Cash Pile', model = 'bkr_prop_money_wrapped_01' }
            }
        },
        {
            label = 'Decor',
            icon = 'lamp',
            items = {
                { label = 'Floor Lamp', model = 'v_res_m_lampstand' },
                { label = 'Chair', model = 'v_res_tre_chair' },
                { label = 'Small Couch', model = 'v_res_tre_sofa' },
                { label = 'Trash Bin', model = 'prop_bin_07b' }
            }
        }
    }
}

Config.Text = {
    Assigned = 'Your room is Room %s on Floor %s.',
    AssignedNew = 'You have been assigned Room %s.',
    DoorNotYours = 'This is not your assigned room.',
    NoAssignment = 'Your room assignment is not ready yet.',
    StashUnavailable = 'Room storage is unavailable right now.',
    FrameworkMissing = 'No supported core framework was found.',
    DatabaseError = 'The hotel ledger could not be updated.',
    FurnitureSaved = 'Furniture placement saved.',
    FurnitureDeleted = 'Furniture removed.',
    StashMoved = 'Room stash location saved.',
    DoorUnlocked = 'Room door unlocked.',
    DoorLocked = 'Room door locked.',
    DoorLockMissing = 'Door lock is not available.'
}

Config.Wiwang = {
    HotelId = 'wiwang',
    Label = 'Wiwang Hotel',
    FloorBaseZ = 41.67480087280273,
    FloorStepZ = 3.8,
    Floors = {
        { floor = 1, elevator = vector4(-824.11, -717.47, 41.57, 223.66), ipl = 'floky_wiwang_hotel_01_milo_' },
        { floor = 2, elevator = vector4(-824.11, -717.47, 45.36, 221.24), ipl = 'floky_wiwang_hotel_02_milo_' },
        { floor = 3, elevator = vector4(-824.10, -717.47, 49.16, 221.29), ipl = 'floky_wiwang_hotel_03_milo_' },
        { floor = 4, elevator = vector4(-824.09, -717.47, 52.96, 221.34), ipl = 'floky_wiwang_hotel_04_milo_' },
        { floor = 5, elevator = vector4(-824.08, -717.47, 56.76, 221.75), ipl = 'floky_wiwang_hotel_05_milo_' },
        { floor = 6, elevator = vector4(-824.07, -717.48, 60.56, 220.95), ipl = 'floky_wiwang_hotel_06_milo_' },
        { floor = 7, elevator = vector4(-824.06, -717.48, 64.36, 221.71), ipl = 'floky_wiwang_hotel_07_milo_' },
        { floor = 8, elevator = vector4(-824.06, -717.48, 68.16, 221.38), ipl = 'floky_wiwang_hotel_08_milo_' },
        { floor = 9, elevator = vector4(-824.32, -717.23, 71.97, 223.36), ipl = 'floky_wiwang_hotel_09_milo_' },
        { floor = 10, elevator = vector4(-824.27, -717.32, 75.77, 221.08), ipl = 'floky_wiwang_hotel_10_milo_' },
        { floor = 11, elevator = vector4(-824.20, -717.39, 79.57, 220.42), ipl = 'floky_wiwang_hotel_11_milo_' },
        { floor = 12, elevator = vector4(-824.12, -717.46, 83.37, 223.31), ipl = 'floky_wiwang_hotel_12_milo_' },
        { floor = 13, elevator = vector4(-824.05, -717.53, 87.17, 219.96), ipl = 'floky_wiwang_hotel_13_milo_' },
        { floor = 14, elevator = vector4(-824.05, -717.54, 90.96, 219.93), ipl = 'floky_wiwang_hotel_14_milo_' },
        { floor = 15, elevator = vector4(-824.04, -717.54, 94.76, 220.04), ipl = 'floky_wiwang_hotel_15_milo_' },
        { floor = 16, elevator = vector4(-823.97, -717.61, 98.57, 219.73), ipl = 'floky_wiwang_hotel_16_milo_' },
        { floor = 17, elevator = vector4(-823.96, -717.62, 102.36, 219.90), ipl = 'floky_wiwang_hotel_17_milo_' },
        { floor = 18, elevator = vector4(-823.95, -717.62, 106.16, 220.07), ipl = 'floky_wiwang_hotel_18_milo_' },
        { floor = 19, elevator = vector4(-823.88, -717.69, 109.97, 219.83), ipl = 'floky_wiwang_hotel_19_milo_' },
        { floor = 20, elevator = vector4(-823.81, -717.77, 113.77, 218.50), ipl = 'floky_wiwang_hotel_20_milo_' }
    },
    DoorLayout = {
        { index = 1, x = -825.8661499023438, y = -724.6109619140625, heading = 0.0 },
        { index = 2, x = -831.46630859375, y = -724.6109619140625, heading = 0.0 },
        { index = 3, x = -837.0661010742188, y = -724.6109619140625, heading = 0.0 },
        { index = 4, x = -842.666259765625, y = -724.6109619140625, heading = 0.0 },
        { index = 5, x = -838.8197021484375, y = -721.3895874023438, heading = 180.0 },
        { index = 6, x = -833.2195434570312, y = -721.3895874023438, heading = 180.0 },
        { index = 7, x = -827.6195068359375, y = -721.3895874023438, heading = 180.0 },
        { index = 8, x = -819.983154296875, y = -704.988525390625, heading = 270.0 },
        { index = 9, x = -819.983154296875, y = -699.388671875, heading = 270.0 },
        { index = 10, x = -819.983154296875, y = -693.788818359375, heading = 270.0 },
        { index = 11, x = -819.983154296875, y = -688.1888427734375, heading = 270.0 },
        { index = 12, x = -819.983154296875, y = -682.5888671875, heading = 270.0 },
        { index = 13, x = -816.609619140625, y = -686.5262451171875, heading = 90.0 },
        { index = 14, x = -816.609619140625, y = -692.1262817382812, heading = 90.0 },
        { index = 15, x = -816.609619140625, y = -697.7262573242188, heading = 90.0 },
        { index = 16, x = -816.609619140625, y = -703.3262939453125, heading = 90.0 },
        { index = 17, x = -816.609619140625, y = -708.92626953125, heading = 90.0 },
        { index = 18, x = -816.609619140625, y = -714.5262451171875, heading = 90.0 },
        { index = 19, x = -816.569580078125, y = -720.1262817382812, heading = 90.0 }
    }
}

Config.Hotels = {
    [Config.Wiwang.HotelId] = {
        Label = Config.Wiwang.Label,
        Rooms = {}
    }
}

local hotel = Config.Hotels[Config.Wiwang.HotelId]

Config.Elevator.Locations[#Config.Elevator.Locations + 1] = Config.Elevator.Lobby

for floorIndex = 1, #Config.Wiwang.Floors do
    local floor = Config.Wiwang.Floors[floorIndex]

    Config.Elevator.Locations[#Config.Elevator.Locations + 1] = {
        id = ('floor_%s'):format(floor.floor),
        label = ('Floor %s'):format(floor.floor),
        floor = floor.floor,
        coords = floor.elevator
    }
end

local function headingOffset(heading, distance)
    local radians = math.rad(heading)

    return math.sin(radians) * distance, math.cos(radians) * distance
end

for floorIndex = 1, #Config.Wiwang.Floors do
    local floor = Config.Wiwang.Floors[floorIndex]
    local z = Config.Wiwang.FloorBaseZ + ((floor.floor - 1) * Config.Wiwang.FloorStepZ)

    for roomIndex = 1, #Config.Wiwang.DoorLayout do
        local layout = Config.Wiwang.DoorLayout[roomIndex]
        local roomNumber = (floor.floor * 100) + layout.index
        local roomId = tostring(roomNumber)
        local insideX, insideY = headingOffset(layout.heading, 1.15)
        local stashX, stashY = headingOffset(layout.heading, 2.35)
        local markerX, markerY = headingOffset(layout.heading, -(Config.RoomMarker.DistanceFromDoor or 0.8))

        hotel.Rooms[#hotel.Rooms + 1] = {
            id = roomId,
            label = ('Room %s'):format(roomId),
            floor = floor.floor,
            roomIndex = layout.index,
            ipl = floor.ipl,
            doorName = ('apartment_%s_floor_%s'):format(layout.index, floor.floor),
            door = vector4(layout.x, layout.y, z, layout.heading),
            inside = vector4(layout.x + insideX, layout.y + insideY, z, layout.heading),
            marker = vector3(layout.x + markerX, layout.y + markerY, z + (Config.RoomMarker.ZOffset or -0.95)),
            stash = vector3(layout.x + stashX, layout.y + stashY, z)
        }
    end
end
