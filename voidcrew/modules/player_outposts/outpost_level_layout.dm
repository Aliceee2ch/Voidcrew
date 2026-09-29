/**
 * # One level per outpost
 *
 * A player outpost owns exactly one z-level and never asks the reservation allocator for
 * ground elsewhere. Everything it needs besides the habitat is a fixed zone on that level,
 * carved at founding:
 *
 *   y 253 +--------+---------------------------------------------+
 *         | berth4 |                                             |
 *         +--------+                                             |
 *         | berth3 |             build region (habitat)          |
 *         +--------+                                             |
 *         | berth2 |                                             |
 *         +--------+------+--------+----+--------------------------+
 *         | berth1 | bay  |  yard  |pen |                          |
 *   y 3   +--------+------+--------+----+--------------------------+
 *         x 3                                                  x 253
 *
 * Zones are separated from each other and from the build region by OUTPOST_LEVEL_GUTTER tiles
 * of /turf/cordon, and the level has an OUTPOST_LEVEL_EDGE-tile cordon rim. Everything outside
 * the build region sits in /area/voidcrew/outpost_vacant, which is NOTELEPORT: an empty zone
 * cannot be teleported into, so nobody is standing there when a berth loads over it.
 *
 * Sizes are defines in voidcrew/_DEFINES/player_outposts.dm; the coordinates come from
 * outpost_level_layout() so they can be retuned in one place.
 */

/// The ground round and between an outpost's zones: cordon gutters and empty zones.
/area/voidcrew/outpost_vacant
	name = "\improper Restricted Space"
	icon_state = "space"
	requires_power = TRUE
	always_unpowered = TRUE
	static_lighting = FALSE
	base_lighting_alpha = 255
	base_lighting_color = COLOR_STARLIGHT
	power_light = FALSE
	power_equip = FALSE
	power_environ = FALSE
	area_flags = UNIQUE_AREA | NO_GRAVITY | NOTELEPORT | HIDDEN_AREA
	outdoors = TRUE
	ambience_index = AMBIENCE_SPACE
	sound_environment = SOUND_AREA_SPACE
	ambient_buzz = null

/// The one shared instance of the vacant area
/proc/outpost_vacant_area()
	return GLOB.areas_by_type[/area/voidcrew/outpost_vacant] || new /area/voidcrew/outpost_vacant

/**
 * Where everything goes on an outpost's level, as key -> list(low_x, low_y, high_x, high_y).
 * Keys: "berth1".."berthN", OUTPOST_ZONE_BAY, OUTPOST_ZONE_YARD, OUTPOST_ZONE_PEN and
 * OUTPOST_LEVEL_BUILD_REGION. The berths stack up the west edge; the bay, the shipyard and the
 * ferry pen sit in a row along the south edge; the build region is the rest.
 */
/proc/outpost_level_layout()
	var/static/list/layout
	if(layout)
		return layout
	layout = list()
	var/low = OUTPOST_LEVEL_EDGE + 1
	var/high_x = world.maxx - OUTPOST_LEVEL_EDGE
	var/high_y = world.maxy - OUTPOST_LEVEL_EDGE

	var/berth_high_x = low + OUTPOST_BERTH_ZONE_WIDTH - 1
	for(var/number in 1 to OUTPOST_LEVEL_BERTHS)
		var/berth_low_y = low + (number - 1) * (OUTPOST_BERTH_ZONE_HEIGHT + OUTPOST_LEVEL_GUTTER)
		layout["[OUTPOST_ZONE_BERTH][number]"] = list(low, berth_low_y, berth_high_x, berth_low_y + OUTPOST_BERTH_ZONE_HEIGHT - 1)

	var/row_x = berth_high_x + OUTPOST_LEVEL_GUTTER + 1
	var/build_low_x = row_x
	layout[OUTPOST_ZONE_BAY] = list(row_x, low, row_x + OUTPOST_BAY_ZONE_WIDTH - 1, low + OUTPOST_BAY_ZONE_HEIGHT - 1)
	row_x += OUTPOST_BAY_ZONE_WIDTH + OUTPOST_LEVEL_GUTTER
	layout[OUTPOST_ZONE_YARD] = list(row_x, low, row_x + OUTPOST_YARD_ZONE_SIZE - 1, low + OUTPOST_YARD_ZONE_SIZE - 1)
	row_x += OUTPOST_YARD_ZONE_SIZE + OUTPOST_LEVEL_GUTTER
	layout[OUTPOST_ZONE_PEN] = list(row_x, low, row_x + OUTPOST_PEN_ZONE_WIDTH - 1, low + OUTPOST_PEN_ZONE_HEIGHT - 1)

	var/row_top = low + max(OUTPOST_BAY_ZONE_HEIGHT, OUTPOST_YARD_ZONE_SIZE, OUTPOST_PEN_ZONE_HEIGHT) - 1
	layout[OUTPOST_LEVEL_BUILD_REGION] = list(build_low_x, row_top + OUTPOST_LEVEL_GUTTER + 1, high_x, high_y)
	return layout

/**
 * One fixed rectangle of an outpost's level, reserved for a berth, the ship bay, the hidden
 * shipyard or the ferry pen. Vacant zones are empty space in the vacant area.
 */
/datum/outpost_zone
	/// Layout key: "berth1", "bay", "yard" or "pen"
	var/key
	/// OUTPOST_ZONE_BERTH, _BAY, _YARD or _PEN
	var/kind
	/// The berth number for a berth zone, else 1
	var/number = 1
	var/low_x
	var/low_y
	var/high_x
	var/high_y
	var/z_value
	/// OUTPOST_ZONE_VACANT, _BUILDING, _IN_USE or _WIPING
	var/state = OUTPOST_ZONE_VACANT

/datum/outpost_zone/New(key, kind, number, list/rect, z_value)
	src.key = key
	src.kind = kind
	src.number = number
	low_x = rect[1]
	low_y = rect[2]
	high_x = rect[3]
	high_y = rect[4]
	src.z_value = z_value

/datum/outpost_zone/proc/get_bottom_left()
	return locate(low_x, low_y, z_value)

/datum/outpost_zone/proc/get_top_right()
	return locate(high_x, high_y, z_value)

/datum/outpost_zone/proc/get_width()
	return high_x - low_x + 1

/datum/outpost_zone/proc/get_height()
	return high_y - low_y + 1

/datum/outpost_zone/proc/contains_turf(turf/location)
	if(!location || location.z != z_value)
		return FALSE
	return location.x >= low_x && location.x <= high_x && location.y >= low_y && location.y <= high_y

/datum/outpost_zone/proc/get_block()
	return block(low_x, low_y, z_value, high_x, high_y, z_value)

/datum/outpost_zone/proc/is_vacant()
	return state == OUTPOST_ZONE_VACANT

/obj/structure/overmap/dynamic/player_outpost
	/// The fixed zones on the outpost's level, layout key -> /datum/outpost_zone
	var/list/datum/outpost_zone/level_zones = list()

/// The zone stored under a layout key ("berth2", OUTPOST_ZONE_BAY, ...), or null
/obj/structure/overmap/dynamic/player_outpost/proc/level_zone(key)
	return level_zones[key]

/// The zone a berth number loads into, or null
/obj/structure/overmap/dynamic/player_outpost/proc/berth_zone(number)
	return level_zones["[OUTPOST_ZONE_BERTH][number]"]

/// The zone containing `location`, or null (the build region and the gutters are no zone)
/obj/structure/overmap/dynamic/player_outpost/proc/zone_at(turf/location)
	for(var/key in level_zones)
		var/datum/outpost_zone/zone = level_zones[key]
		if(zone.contains_turf(location))
			return zone
	return null

/// The habitat: the build region, where the outpost's own announcements are heard.
/obj/structure/overmap/dynamic/player_outpost/proc/is_habitat_turf(turf/location)
	return is_turf_buildable(location)

/**
 * Carves the outpost's level at founding: the build region, the zones in the vacant area and
 * cordon everywhere else. Sets build_bounds. The level is fresh space when this runs.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/carve_level(datum/space_level/zlevel)
	var/z = zlevel.z_value
	var/list/layout = outpost_level_layout()
	var/list/build = layout[OUTPOST_LEVEL_BUILD_REGION]
	build_bounds = build.Copy()

	level_zones = list()
	for(var/key in layout)
		if(key == OUTPOST_LEVEL_BUILD_REGION)
			continue
		var/kind = key
		var/number = 1
		if(findtext(key, OUTPOST_ZONE_BERTH) == 1)
			kind = OUTPOST_ZONE_BERTH
			number = text2num(copytext(key, length(OUTPOST_ZONE_BERTH) + 1))
		level_zones[key] = new /datum/outpost_zone(key, kind, number, layout[key], z)

	var/area/vacant = outpost_vacant_area()
	for(var/turf/tile as anything in block(1, 1, z, world.maxx, world.maxy, z))
		if(tile.x >= build[1] && tile.x <= build[3] && tile.y >= build[2] && tile.y <= build[4])
			continue
		var/area/old_area = tile.loc
		if(old_area != vacant)
			tile.change_area(old_area, vacant)
		if(!zone_at(tile))
			zlevel.place_cordon_turf(tile)
		CHECK_TICK

	// The cordon went down as raw turf swaps, which recalculate nobody's atmos adjacency; the
	// cordon tiles hugging live ground strip themselves out of their neighbours' lists (see
	// place_cordon()).
	var/list/live_rects = list(build)
	for(var/key in level_zones)
		var/datum/outpost_zone/zone = level_zones[key]
		live_rects += list(list(zone.low_x, zone.low_y, zone.high_x, zone.high_y))
	for(var/list/rect as anything in live_rects)
		for(var/turf/edge_turf as anything in map_boundary_ring(rect[1], rect[2], rect[3], rect[4], z))
			if(istype(edge_turf, /turf/cordon))
				edge_turf.air_update_turf(TRUE, TRUE)
		CHECK_TICK
