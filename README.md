zeekota_hotel is a public Wiwang Hotel room assignment resource. The resource folder keeps the ZeeKota file name, but all default in-game labels, notifications, blips, prompts, and menus use Wiwang Hotel.

Wiwang Hotel Map
This package is configured for the free Wiwang Hotel MLO:

wiwang_hotel-main/map_wiwang_hotel
Map details:

Map name: Wiwang Hotel
Author credit: Floky
Resource name: map_wiwang_hotel
Floors: 20
Rooms per floor: 19
Total rooms: 380
Rooms are unfurnished by default
The original MLO includes an ox_lib elevator helper. The bundled map disables that helper so zeekota_hotel can provide the custom Press E elevator UI.
Ensure map_wiwang_hotel before zeekota_hotel.

Default Flow
Player loads into the server.
Server assigns a room to the player's citizen ID, character ID, or framework identifier.
Player goes to the Wiwang Hotel lobby ped.
Player presses E at the lobby prompt to view their room number in the custom NUI.
Player presses E at an elevator and selects a floor in the custom floor picker.
Player sees a hallway-side cylinder marker in front of their assigned room door.
Player presses E within 1.25 units of the door for lock/unlock and furniture options.
Player opens storage only from the configured stash marker or stash prop.
There is no check-in payment flow. Rooms are persistent assignments.

Features
380 generated Wiwang rooms: 101-119 through 2001-2019.
Auto room assignment on join with ESX, QBCore, Ox Core, or standalone identifier fallback.
Default ZeeKota-style Press E NUI prompts with config-driven colors and gradients.
Small custom NUI for room assignment, room controls, furniture, storage placement, notifications, and elevator floor selection.
Optional ox_target support for lobby and assigned room door interactions.
Configurable lobby blip and lobby ped.
Assigned-room cylinder marker positioned in the hallway in front of the player's room door.
ox_doorlock support for locking and unlocking the assigned room door.
Personal ox_inventory room stashes that persist by character identifier.
Room stashes are only opened from their placed marker or prop, not from the room door menu.
Movable stash placement as either a marker or a selected storage prop.
Built-in furniture placement mode with rendered preview props, camera-relative movement, height controls, rotation, and save/cancel controls.
Free-floating top-left placement guide with bundled keyboard key SVG images for each movement/action.
Furniture persistence through oxmysql.
Dependencies
Required:

map_wiwang_hotel
oxmysql
ox_inventory
One framework: es_extended, qb-core, ox_core, or standalone identifier fallback
Map-only requirement:

ox_lib is still required by map_wiwang_hotel for IPL loading zones.
Optional:

ox_target if Config.Target.Enabled = true or Config.Interaction.Mode = 'target'/'both'
ox_doorlock if you want door lock/unlock integration
Install
Place the bundled map_wiwang_hotel in your resources folder. Its elevators.lua is intentionally inert because this resource owns elevator UI.
Place zeekota_hotel in your resources folder.
Import sql/schema.sql, or let the resource create the tables on first start.
If using ox_doorlock, import sql/ox_doorlock_wiwang.sql after ox_doorlock has created its table.
Ensure resources in this order:
ensure oxmysql
ensure ox_inventory
ensure es_extended     # or qb-core / ox_core
ensure ox_lib           # required by map_wiwang_hotel IPL loading
ensure ox_doorlock      # optional, only if using door locks
ensure ox_target        # optional, only if target mode is enabled
ensure map_wiwang_hotel
ensure zeekota_hotel
Doorlock SQL
sql/ox_doorlock_wiwang.sql inserts all 380 Wiwang room doors into ox_doorlock.

Door names use apartment_<room>_floor_<floor>.
Every inserted room door is locked by default with "state":1.
The script uses the same door names in Config.Wiwang when the player locks or unlocks their assigned room.
Configuration
Important config entries:

Config.Branding.Name = 'Wiwang Hotel' controls in-game labels.
Config.UI.Colors and Config.UI.Gradients control prompt, menu, notification, and accent styling.
Config.Interaction.Mode = 'textui' keeps Press E prompts as the default.
Config.Interaction.DoorDistance = 1.25 controls the room-door Press E radius.
Config.Target.Enabled = false keeps target optional.
Config.Lobby.Interaction.Coords controls the room-number prompt location.
Config.Lobby.Ped.Enabled, Config.Lobby.Ped.Model, and Config.Lobby.Ped.Coords control the lobby ped.
Config.Elevator controls elevator prompt distance, floor locations, fade behavior, and teleport offset.
Config.RoomAssignment.AssignOnJoin = true assigns rooms automatically.
Config.RoomMarker.Enabled = true draws the assigned-room cylinder marker.
Config.RoomMarker.DistanceFromDoor pushes the marker out into the hallway from the ox_doorlock SQL door coordinate.
Config.RoomMarker.VisibleFromRoomSide = false hides the marker from the room side of the door.
Config.Stash controls personal stash size, weight, marker, and prop options. The default weight is 2000000 grams, or 2000kg.
Config.Furniture.Categories controls which GTA props players can place.
Config.Furniture.Controls controls placement movement speed, height step, rotation step, and ground snapping.
Config.Furniture.StalePreviewCleanup = true removes orphaned placement preview props near the assigned door.
Furniture placement controls:

Arrow keys move the preview object relative to the camera.
Hold Shift for faster movement.
Page Up and Page Down raise or lower the object.
Q and E rotate the object.
Enter saves the placement.
Backspace cancels placement.
Exports
Client:

exports.zeekota_hotel:GetCurrentRoom()
exports.zeekota_hotel:IsInsideRoom()
Server:

exports.zeekota_hotel:GetPlayerRoom(source)
exports.zeekota_hotel:GetPlayerRental(source) -- compatibility alias
Notes
The included Wiwang MLO is unfurnished; this resource intentionally provides only a simple prop placement system rather than a full housing editor.
Furniture is spawned client-side for the assigned room and saved server-side.
Room stashes are registered through ox_inventory and owned by the assigned character identifier when Config.Stash.OwnerMode = 'identifier'.
