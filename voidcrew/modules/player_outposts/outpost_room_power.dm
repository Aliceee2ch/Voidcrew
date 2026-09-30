/**
 * # Outpost room power
 *
 * Every upgrade room with its own area (the service rooms, the cargo dock, the prison wing) has one
 * room APC, and protected cable runs from it to under the room's exterior door. A room whose door lands
 * on the tile outside a habitat airlock (or another room's door) joins the habitat's grid when it
 * loads: the cables link and the template's powernet pass merges the nets. A room placed away from the
 * habitat joins once the owner builds a floor path to it: the feeder lays protected cable along it,
 * once per room. Until then a room runs on its APC's cell, and an outage in a room stays in that room.
 *
 * The shells run a protected trunk from the power room to under every outer airlock, so a room docked
 * at any of them meets the grid.
 */

// ===== AREAS =====

/// A service room's own area, one instance per installed room (no UNIQUE_AREA). Named for the room, so its APC is too.
/area/voidcrew/player_outpost/service_room
	name = "\improper Service Room"

/area/voidcrew/player_outpost/service_room/cloning_bay
	name = "\improper Cloning Bay"

/area/voidcrew/player_outpost/service_room/medical_lab
	name = "\improper Medical Lab"

/area/voidcrew/player_outpost/service_room/shop
	name = "\improper Shop"

/area/voidcrew/player_outpost/service_room/storage
	name = "\improper Safe Storage"

/area/voidcrew/player_outpost/service_room/teleporter
	name = "\improper Teleporter"

// ===== THE ROOM APC =====

/// A room's APC: outpost property, run only by the outpost's owner and stewards
/obj/machinery/power/apc/outpost
	auto_name = TRUE
	aidisabled = TRUE
	start_charge = 100

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/power/apc/outpost, APC_PIXEL_OFFSET)

/// Whether `user` may run this APC: an admin ghost, or the outpost's owner or a steward
/obj/machinery/power/apc/outpost/proc/outpost_admits(mob/user)
	return FALSE

// ===== THE PROTECTED CABLE =====

/// Outpost wiring: only the outpost's builders can cut it, and bombs, fire, acid and rats can't
/obj/structure/cable/outpost

/// Whether `user` may cut this cable
/obj/structure/cable/outpost/proc/outpost_cut_allowed(mob/user)
	return TRUE

// ===== JOINING THE GRID =====

/datum/outpost_upgrade
	/// The feeder has joined this room to the grid, or found it already joined: it is never laid again
	var/feeder_laid = FALSE

/// The habitat's grid: the powernet on the habitat APC's terminal, or null
/obj/structure/overmap/dynamic/player_outpost/proc/main_grid()
	return null

/// Lays feeder cable to every installed room that is not on the grid and has not been fed yet
/obj/structure/overmap/dynamic/player_outpost/proc/join_rooms_to_grid()
	return

/// join_rooms_to_grid() shortly, once, however many turfs join the outpost meanwhile
/obj/structure/overmap/dynamic/player_outpost/proc/queue_room_power_join()
	return

/// This room's own APC, or null (prison extensions run off the wing's)
/datum/outpost_upgrade/proc/room_apc()
	return null

/// Footprint tiles holding an airlock with a neighbour outside the footprint
/datum/outpost_upgrade/proc/exterior_door_turfs()
	return list()

/// Whether this room's APC is on the habitat's grid
/datum/outpost_upgrade/proc/on_grid()
	return FALSE

/// Lays protected cable from this room's door along outpost floor to `grid`. TRUE if it joined.
/datum/outpost_upgrade/proc/lay_feeder(datum/powernet/grid)
	return FALSE

/// What is wrong with this room's area, APC and wiring, one line each; empty when fine (outpost_room_contracts.dm)
/datum/outpost_upgrade/proc/power_problems()
	return list()
