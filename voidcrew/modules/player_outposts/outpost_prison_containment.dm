/**
 * # Prison wing containment
 *
 * What keeps prisoners in and who may deal with them: where a prisoner can stand, walk and reach,
 * the cell block, whether a prisoner is confined to their cell, and who counts as a member of the
 * wing. The wing's doors and bolt buttons are in outpost_prison_doors.dm.
 *
 * The cell block is everything prisoners can reach from the cells without passing a staff door or
 * a serving hatch, worked out once when the wing is placed. A prisoner outside it on their own
 * feet has escaped (outpost_prison_riot.dm).
 */

/// How often every prisoner's reach is refreshed, in seconds
#define PRISON_REACH_REFRESH_SECONDS 5

/datum/outpost_prison
	/// The cell block: turf = TRUE, for every tile inside it and the fixtures along its edge
	var/list/cell_block = list()
	/// Seconds since every prisoner's reach was refreshed
	var/containment_clock = 0
	/// Whether people who are not members of the wing may use its staff doors
	var/visitors_allowed = TRUE

/// Advances containment by `seconds`: every prisoner's reach is refreshed every PRISON_REACH_REFRESH_SECONDS
/datum/outpost_prison/proc/containment_tick(seconds)
	containment_clock += seconds
	if(containment_clock < PRISON_REACH_REFRESH_SECONDS)
		return
	containment_clock = 0
	refresh_reach()

// ===== MEMBERS AND VISITORS =====

/// Whether `user` is a member of the wing, who may deal with its prisoners and doors
/datum/outpost_prison/proc/is_member(mob/user)
	return ismob(user) && !is_outpost_prisoner(user)

/// Lets visitors use the staff doors, or stops them
/datum/outpost_prison/proc/set_visitors_allowed(on, mob/user)
	visitors_allowed = !!on

// ===== REACH =====

/**
 * Whether a prisoner could stand on this tile. Cell doors open for them unless bolted or
 * unpowered; staff doors never do.
 */
/datum/outpost_prison/proc/prisoner_can_stand(turf/tile)
	if(isclosedturf(tile))
		return FALSE
	for(var/atom/movable/thing as anything in tile)
		if(istype(thing, /obj/machinery/door/airlock/security/prison_staff))
			return FALSE
		if(istype(thing, /obj/machinery/door/airlock))
			var/obj/machinery/door/airlock/airlock = thing
			if(airlock.density && (airlock.locked || airlock.welded || !airlock.hasPower()))
				return FALSE
			continue
		if(istype(thing, /obj/machinery/door) || ismob(thing))
			continue
		if(thing.density)
			return FALSE
	return TRUE

/// Refreshes where every prisoner can walk and reach
/datum/outpost_prison/proc/refresh_reach()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		refresh_prisoner_reach(prisoner)

/**
 * Floods out from a prisoner to the ground they can walk on, then adds each tile beside it
 * (tables, the serving hatch). Items on those tiles are the ones they can go and pick up; food
 * seen through the office windows is not.
 */
/datum/outpost_prison/proc/refresh_prisoner_reach(mob/living/basic/outpost_prisoner/prisoner)
	var/list/walked = list()
	var/list/reach = list()
	var/turf/start = get_turf(prisoner)
	if(start?.loc == wing)
		var/list/queue = list(start)
		walked[start] = TRUE
		var/index = 1
		while(index <= length(queue))
			var/turf/current = queue[index++]
			for(var/direction in GLOB.cardinals)
				var/turf/next = get_step(current, direction)
				if(!next || walked[next] || next.loc != wing || !prisoner_can_stand(next))
					continue
				walked[next] = TRUE
				queue += next
		for(var/turf/standing as anything in walked)
			reach[standing] = TRUE
			for(var/direction in GLOB.cardinals)
				var/turf/beside = get_step(standing, direction)
				if(beside?.loc == wing)
					reach[beside] = TRUE
	prisoner.walkable = walked
	prisoner.reachable = reach

// ===== THE CELL BLOCK =====

/**
 * Floods out from the cells across everything prisoners could walk, whatever the bolts, stopping
 * at staff doors and at anything solid. Solid tiles along the edge (windows, the serving hatches,
 * doors) are part of it; the tiles past them are not.
 */
/datum/outpost_prison/proc/refresh_cell_block()
	var/list/found = list()
	var/list/queue = list()
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		for(var/turf/tile as anything in cell.turfs)
			if(!found[tile])
				found[tile] = TRUE
				queue += tile
	var/index = 1
	while(index <= length(queue))
		var/turf/current = queue[index++]
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || found[next] || next.loc != wing || isclosedturf(next))
				continue
			found[next] = TRUE
			if(cell_block_passable(next))
				queue += next
	cell_block = found

/// Whether the cell block flood carries on through a tile
/datum/outpost_prison/proc/cell_block_passable(turf/tile)
	for(var/atom/movable/thing as anything in tile)
		if(istype(thing, /obj/machinery/door/airlock/security/prison_staff))
			return FALSE
		if(istype(thing, /obj/machinery/door) || ismob(thing))
			continue
		if(thing.density)
			return FALSE
	return TRUE

/// Whether something is in the cell block. A wing without cells has no cell block to leave.
/datum/outpost_prison/proc/in_cell_block(atom/thing)
	var/turf/tile = get_turf(thing)
	if(!tile)
		return FALSE
	return !length(cell_block) || cell_block[tile]

/// Whether a tile on the cell block's edge has the outside of the cell block beyond it
/datum/outpost_prison/proc/leads_out_of_cell_block(turf/tile)
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(tile, direction)
		if(beside && beside.loc == wing && !isclosedturf(beside) && !cell_block[beside])
			return TRUE
	return FALSE

/// The nearest free tile of the wing outside the cell block, for an admin breakout
/datum/outpost_prison/proc/outside_spot_near(atom/from)
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/open/tile in wing_turfs())
		if(cell_block[tile] || tile.is_blocked_turf(TRUE) || (locate(/obj/machinery/door) in tile))
			continue
		var/distance = get_dist(from, tile)
		if(distance < best_distance)
			best = tile
			best_distance = distance
	return best

// ===== THE PRISONER =====

/// Hooks up what keeps a prisoner contained; called from Initialize()
/mob/living/basic/outpost_prisoner/proc/setup_containment()
	return

/// Whether they are shut in their cell: standing in a cell whose door is bolted
/mob/living/basic/outpost_prisoner/proc/is_confined()
	var/datum/outpost_prison_cell/holding = prison?.cell_at(get_turf(src))
	return !!holding?.is_bolted()

#undef PRISON_REACH_REFRESH_SECONDS
