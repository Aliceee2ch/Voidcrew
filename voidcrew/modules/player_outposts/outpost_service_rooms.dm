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
	/// FALSE when the room must stay open to visitors, so the console offers no toggle
	var/visitors_toggleable = TRUE
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

/// Makes every machine and structure in the room outpost property (protect_fixture())
/datum/outpost_upgrade/service/proc/protect_fixtures()
	for(var/turf/tile as anything in room_turfs())
		for(var/obj/fixture in tile)
			protect_fixture(fixture)

/**
 * Makes one machine or structure outpost property. Rooms call it on everything they load; call it
 * again on anything a room spawns later. Anything that is not a machine or structure is ignored.
 *
 * * INDESTRUCTIBLE set after a machine's Initialize() misses its own explosion guard
 *   (_machinery.dm), so the contents flag is set here too, or an explosion could delete a part and
 *   the machine with it.
 * * A singularity or reality tear ignores it: /obj/singularity_act() deletes anything, whatever
 *   its resistance flags (see singularity_spares()).
 * * Structures are bolted down for good, so nobody drags the dressing out or parks it in a doorway.
 */
/datum/outpost_upgrade/service/proc/protect_fixture(obj/fixture)
	// The element refuses anything else, and a refused AddElement crashes
	if(QDELETED(fixture) || (!ismachinery(fixture) && !isstructure(fixture)))
		return
	fixture.AddElement(/datum/element/outpost_property)
	fixture.flags_1 |= PREVENT_CONTENTS_EXPLOSION_1
	ADD_TRAIT(fixture, TRAIT_SINGULARITY_IMMUNE, OUTPOST_SERVICE_TRAIT)
	if(!isstructure(fixture))
		return
	if(!fixture.anchored)
		fixture.set_anchored(TRUE)
	if(istype(fixture, /obj/structure/closet))
		var/obj/structure/closet/closet = fixture
		closet.anchorable = FALSE

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
			// A door button whose id matched would open, bolt and shock it (doorcontrol.dm)
			door.id_tag = null
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

/// The turfs just outside the room's exterior service doors, one per door and side off the room
/datum/outpost_upgrade/service/proc/exit_turfs()
	var/list/exits = list()
	for(var/datum/weakref/door_ref as anything in doors)
		var/obj/machinery/door/airlock/outpost/service/door = door_ref.resolve()
		var/turf/door_turf = get_turf(door)
		if(!door_turf || !contains_turf(door_turf))
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/beyond = get_step(door_turf, direction)
			if(beyond && !contains_turf(beyond))
				exits += beyond
	return exits

/**
 * Why nobody could walk out of the room right now, or null when some exterior door leads onto
 * open, breathable ground. "Exit blocked": every door's outside is a wall or something solid.
 * "Exit to vacuum": the way out has no safe air. The cloning chooser and the teleporter's
 * destination list show it as a warning; it never refuses a wake or an arrival by itself.
 */
/datum/outpost_upgrade/service/proc/exit_denial()
	var/open_exit = FALSE
	for(var/turf/exit as anything in exit_turfs())
		if(outpost_exit_blocked(exit))
			continue
		open_exit = TRUE
		if(outpost_exit_breathable(exit))
			return null
	return open_exit ? "Exit to vacuum" : "Exit blocked"

/**
 * Placement refusal for this room at `footprint` (footprint_at()), or null. A closed turf just
 * outside any exterior service door would seal the room for good, so it refuses. Space and open
 * ground pass: a corridor can be built later.
 */
/datum/outpost_upgrade/service/placement_denial(list/footprint, rotation)
	var/datum/map_template/template = get_template()
	var/turf/bottom_left = footprint?["bottom_left"]
	if(!template || !bottom_left)
		return null
	var/list/room = list()
	for(var/turf/tile as anything in footprint["turfs"])
		room[tile] = TRUE
	for(var/list/offset as anything in template_door_offsets())
		var/turf/door_turf = template.rotated_template_turf(bottom_left, offset[1], offset[2], rotation)
		if(!door_turf)
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/beyond = get_step(door_turf, direction)
			if(beyond && !room[beyond] && isclosedturf(beyond))
				return "Entrance blocked."
	return null

/**
 * Zero-based (column, row) offsets of the service airlocks in this room's map as drawn, read from
 * the map file once per map and cached. Room maps are small, so the one parse is cheap.
 */
/datum/outpost_upgrade/service/proc/template_door_offsets()
	var/static/list/offsets_by_map = list()
	var/datum/map_template/template = get_template()
	var/path = template?.mappath
	if(!path)
		return list()
	var/list/cached = offsets_by_map[path]
	if(cached)
		return cached
	cached = list()
	var/datum/parsed_map/parsed = new(file(path))
	var/list/door_keys = list()
	for(var/key in parsed.grid_models)
		if(findtext(parsed.grid_models[key], "/obj/machinery/door/airlock/outpost/service"))
			door_keys[key] = TRUE
	var/key_len = parsed.key_len
	if(length(door_keys) && key_len)
		for(var/datum/grid_set/grid as anything in parsed.gridSets)
			var/list/lines = grid.gridLines
			for(var/line_index in 1 to length(lines))
				var/line = lines[line_index]
				var/row = grid.ycrd - line_index // ycrd is the top line's y; rows are zero-based
				for(var/position in 1 to length(line) step key_len)
					if(!door_keys[copytext(line, position, position + key_len)])
						continue
					var/column = grid.xcrd - 1 + (position - 1) / key_len
					cached += list(list(column, row))
	qdel(parsed)
	offsets_by_map[path] = cached
	return cached

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

// ===== EXITS =====

/// A closed turf, or something dense and bolted down a person cannot open or climb. Doors open, so they never block.
/proc/outpost_exit_blocked(turf/exit)
	if(!exit || isclosedturf(exit))
		return TRUE
	for(var/obj/thing in exit)
		if(!thing.density || !thing.anchored || istype(thing, /obj/machinery/door))
			continue
		if((thing.flags_1 & ON_BORDER_1) || HAS_TRAIT(thing, TRAIT_CLIMBABLE))
			continue
		return TRUE
	return FALSE

/// Breathable by the teleport safety numbers (is_safe_turf() in teleport.dm, which refuses indestructible floors itself)
/proc/outpost_exit_breathable(turf/open/exit)
	if(!isopenturf(exit))
		return FALSE
	var/datum/gas_mixture/air = exit.air
	if(!air)
		return FALSE
	var/static/list/gases_to_check = list(
		/datum/gas/oxygen = list(16, 100),
		/datum/gas/nitrogen,
		/datum/gas/carbon_dioxide = list(0, 10),
	)
	if(!check_gases(air.gases, gases_to_check))
		return FALSE
	if(air.temperature <= 270 || air.temperature >= 360)
		return FALSE
	var/pressure = air.return_pressure()
	return pressure > 20 && pressure < 550

// ===== SINGULARITY IMMUNITY =====

/**
 * Whether a singularity or reality tear must leave `thing` alone: neither eat it nor pull it.
 * Called from the singularity's consume and pull paths (code/, which cannot see Voidcrew
 * defines). Service room fixtures get the trait from protect_fixture().
 */
/proc/singularity_spares(atom/thing)
	return HAS_TRAIT(thing, TRAIT_SINGULARITY_IMMUNE)

/// Whether `thing` stands inside an installed service room of a player outpost
/proc/is_outpost_service_tile(atom/thing)
	var/turf/location = get_turf(thing)
	if(!location)
		return FALSE
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(location)
	var/datum/outpost_upgrade/service/room = home?.upgrade_at_turf(location)
	return istype(room) && room.installed
