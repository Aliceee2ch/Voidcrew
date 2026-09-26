// MARKET-OWNER: P1
/**
 * # Outpost service rooms
 *
 * Prefab rooms that sell a service to visitors (cloning bay, shop, medical lab, storage). They are
 * outpost upgrades (outpost_upgrades.dm) with three differences from the cargo dock:
 *
 * * The room joins the outpost's own area before its template loads, so every machine
 *   initializes on the outpost's power. Room maps use /area/template_noop and carry no APC
 *   and no light switch; an outage stops the services with the rest of the outpost.
 * * Everything fixed in the room (machines and structures, never items or mobs) becomes
 *   outpost property. Walls and floors are indestructible turfs in the map itself.
 * * Doors are service airlocks (outpost_service_doors.dm): members pass, visitors pass public
 *   doors while the room admits them, and every door opens from the inside.
 *
 * Deleting the outpost deletes the rooms and everything in them. Nothing is refunded.
 */

/// Abstract: no id, so it never enters the catalog.
/datum/outpost_upgrade/service
	area_type = /area/voidcrew/player_outpost
	entrance_side = SOUTH
	/// FALSE makes the room's public doors member-only. Exits stay open.
	var/visitors_allowed = TRUE
	/// Turf -> the area it had before prepare_ground() moved it into the outpost area
	var/list/prepared_areas
	/// The room's service airlocks, found at install
	var/list/datum/weakref/doors

/datum/outpost_upgrade/service/Destroy()
	doors = null
	prepared_areas = null
	return ..()

/// Moves the footprint into the outpost's area before the room loads (see the file comment)
/datum/outpost_upgrade/service/prepare_ground(list/footprint_turfs)
	var/area/home_area = outpost?.outpost_area
	if(!home_area)
		return
	prepared_areas = list()
	for(var/turf/tile as anything in footprint_turfs)
		var/area/old_area = get_area(tile)
		if(old_area == home_area)
			continue
		prepared_areas[tile] = old_area
		tile.change_area(old_area, home_area)

/// Puts the footprint back in its old areas after a load that built nothing
/datum/outpost_upgrade/service/release_ground(list/footprint_turfs)
	for(var/turf/tile as anything in prepared_areas)
		var/area/old_area = prepared_areas[tile]
		if(old_area && !QDELETED(old_area))
			tile.change_area(get_area(tile), old_area)
	prepared_areas = null

/datum/outpost_upgrade/service/on_installed(mob/user)
	protect_fixtures()
	adopt_doors()
	on_service_installed(user)

/// The placed room's turfs, or an empty list before placement
/datum/outpost_upgrade/service/proc/room_turfs()
	if(!footprint_bounds)
		return list()
	return block(footprint_bounds[1], footprint_bounds[2], footprint_bounds[5], footprint_bounds[3], footprint_bounds[4], footprint_bounds[5])

/**
 * Makes every machine and structure in the room outpost property. INDESTRUCTIBLE set after a
 * machine's Initialize() misses its own explosion guard (_machinery.dm), so the contents flag is
 * set here too, or an explosion could delete a part and the machine with it.
 */
/datum/outpost_upgrade/service/proc/protect_fixtures()
	for(var/turf/tile as anything in room_turfs())
		for(var/obj/fixture in tile)
			// The element refuses anything else, and a refused AddElement crashes
			if(!ismachinery(fixture) && !isstructure(fixture))
				continue
			fixture.AddElement(/datum/element/outpost_property)
			fixture.flags_1 |= PREVENT_CONTENTS_EXPLOSION_1

/// Records the room's service airlocks. A door out of the room whose map forgot its unrestricted-side helper gets one pointing inside.
/datum/outpost_upgrade/service/proc/adopt_doors()
	doors = list()
	var/list/room = room_turfs()
	var/list/inside = list()
	for(var/turf/tile as anything in room)
		inside[tile] = TRUE
	for(var/turf/tile as anything in room)
		for(var/obj/machinery/door/airlock/outpost/service/door in tile)
			doors += WEAKREF(door)
			if(door.unres_sides)
				continue
			for(var/direction in GLOB.cardinals)
				if(inside[get_step(tile, direction)])
					continue
				// This door's own inside: a side or back door does not face the way the entrance does
				var/inward = turn(direction, 180)
				door.unres_sides = inward
				door.update_appearance()
				log_mapping("OUTPOST SERVICE ROOM: [door] at [AREACOORD(door)] in the [name] had no unrestricted side; set to [dir2text(inward)]")
				break

/datum/outpost_upgrade/service/proc/is_inside(atom/thing)
	return contains_turf(get_turf(thing))

/// Management opens or closes the room's public doors to visitors. Null when set, else a refusal.
/datum/outpost_upgrade/service/proc/set_visitors_allowed(mob/living/user, allowed)
	if(QDELETED(outpost) || !outpost.is_current_management_user(user))
		return "Management access required."
	allowed = !!allowed
	if(allowed == visitors_allowed)
		return null
	visitors_allowed = allowed
	log_game("PLAYER OUTPOST: [key_name(user)] [allowed ? "opened" : "closed"] the [name] to visitors at '[outpost.name]'")
	return null

// ===== ROOM HOOKS (room packages override these) =====

/// Called once the room is placed, protected and its doors adopted. Wire the room here.
/datum/outpost_upgrade/service/proc/on_service_installed(mob/user)
	return

/// This room's detail for the management console's Services tab, or null
/datum/outpost_upgrade/service/proc/service_ui_data(mob/user)
	return null

/// A Services tab action for this room. TRUE when handled.
/datum/outpost_upgrade/service/proc/service_ui_act(mob/user, action, list/params)
	return FALSE

/// Rows for the admin Outpost Manipulator, or null
/datum/outpost_upgrade/service/proc/admin_ui_data()
	return null

/// An Outpost Manipulator action for this room. TRUE when handled.
/datum/outpost_upgrade/service/proc/admin_ui_act(mob/user, action, list/params)
	return FALSE

/// A summary for the Pricing tab (the shop's listing counts), or null
/datum/outpost_upgrade/service/proc/pricing_summary()
	return null

/// TRUE lets this visitor through the room's public door while the room is closed to visitors
/datum/outpost_upgrade/service/proc/admits_visitor_extra(mob/user)
	return FALSE

/// The outpost was abandoned: put per-room settings back to their defaults
/datum/outpost_upgrade/service/proc/on_outpost_abandoned()
	return
