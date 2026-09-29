/**
 * One level per outpost (outpost_level_layout.dm): the layout keeps every zone and the build
 * region on the level, apart by a cordon gutter, and each zone holds what loads into it.
 *
 * Fork defines are included after the tests, so their values are written out here: four berth
 * zones of 66x59 (OUTPOST_LEVEL_BERTHS, OUTPOST_BERTH_ZONE_*), a 3-tile gutter, a 2-tile rim,
 * and the layout keys "berth1".."berth4", "bay", "yard", "pen" and "build".
 */
/datum/unit_test/voidcrew_outpost_level_layout

/datum/unit_test/voidcrew_outpost_level_layout/Run()
	var/list/layout = outpost_level_layout()
	TEST_ASSERT_EQUAL(length(layout), 4 + 4, "The layout has [length(layout)] rectangles")
	var/low = 2 + 1
	for(var/key in layout)
		var/list/rect = layout[key]
		TEST_ASSERT(rect[1] <= rect[3] && rect[2] <= rect[4], "[key] is an empty rectangle")
		TEST_ASSERT(rect[1] >= low && rect[2] >= low && rect[3] <= world.maxx - 2 && rect[4] <= world.maxy - 2, \
			"[key] ([rect.Join(",")]) reaches the level's cordon rim")
	var/list/keys = layout.Copy()
	for(var/first_index in 1 to length(keys))
		var/list/first = layout[keys[first_index]]
		for(var/second_index in (first_index + 1) to length(keys))
			var/list/second = layout[keys[second_index]]
			var/apart = first[3] + 3 < second[1] || second[3] + 3 < first[1] \
				|| first[4] + 3 < second[2] || second[4] + 3 < first[2]
			TEST_ASSERT(apart, "[keys[first_index]] and [keys[second_index]] are less than a gutter apart")

	for(var/number in 1 to 4)
		var/list/berth = layout["berth[number]"]
		TEST_ASSERT_NOTNULL(berth, "Berth zone [number] is missing")
		TEST_ASSERT_EQUAL(berth[3] - berth[1] + 1, 66, "Berth zone [number] has the wrong width")
		TEST_ASSERT_EQUAL(berth[4] - berth[2] + 1, 59, "Berth zone [number] has the wrong height")

	// The largest ship-sized berth fits a berth zone.
	var/datum/map_template/outpost_berth_strip/strip = get_outpost_berth_strip()
	var/datum/outpost_berth_layout/largest = new(56, 40, strip.width, strip.height)
	TEST_ASSERT(largest.width <= 66 && largest.height <= 59, \
		"The largest berth ([largest.width]x[largest.height]) does not fit a [66]x[59] berth zone")
	// Every ship bay map fits the bay zone.
	var/list/bay = layout["bay"]
	for(var/style in list("rundown", "clean"))
		var/datum/map_template/bay_map = outpost_ship_bay_template(style)
		TEST_ASSERT_NOTNULL(bay_map, "No ship bay map for the [style] style")
		TEST_ASSERT(bay_map.width <= bay[3] - bay[1] + 1 && bay_map.height <= bay[4] - bay[2] + 1, "The [style] ship bay does not fit the bay zone")
	// The cargo ferry fits its pen.
	var/list/pen = layout["pen"]
	var/datum/map_template/shuttle/cargo/box/ferry = new
	TEST_ASSERT(ferry.width < pen[3] - pen[1] + 1 && ferry.height < pen[4] - pen[2] + 1, "The cargo ferry does not fit its pen")
	qdel(ferry)
	// Every shell founders can pick fits the build region with room to grow.
	var/list/build = layout["build"]
	for(var/shell_type in outpost_selectable_shells())
		var/datum/map_template/player_outpost/shell = new shell_type
		TEST_ASSERT(shell.width * 3 < build[3] - build[1] + 1 && shell.height * 3 < build[4] - build[2] + 1, "[shell.name] crowds the build region")
		qdel(shell)

/// Founding carves the level: vacant zones nobody can teleport into, cordon round them, and
/// outpost notices heard only in the habitat.
/datum/unit_test/voidcrew_outpost_level_carve
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_level_carve/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("levelcarveowner")
	TEST_ASSERT_NOTNULL(home, "The layout test outpost did not load")
	var/z = home.upgrade_level_z()
	var/list/layout = outpost_level_layout()
	var/area/vacant = GLOB.areas_by_type[/area/voidcrew/outpost_vacant]
	TEST_ASSERT_NOTNULL(vacant, "Founding made no vacant area")
	TEST_ASSERT(vacant.area_flags & NOTELEPORT, "The vacant area allows teleports")

	var/list/build = layout["build"]
	var/turf/inside = locate(build[1] + 3, build[4] - 3, z)
	var/mob/living/carbon/human/habitat_player = make_player(inside, "levelcarvehabitat")
	for(var/key in layout)
		if(key == "build")
			continue
		var/datum/outpost_zone/zone = home.level_zone(key)
		TEST_ASSERT_NOTNULL(zone, "Founding made no [key] zone")
		TEST_ASSERT_EQUAL(zone.state, "vacant", "The [key] zone is not vacant after founding")
		var/list/rect = layout[key]
		TEST_ASSERT(zone.low_x == rect[1] && zone.low_y == rect[2] && zone.high_x == rect[3] && zone.high_y == rect[4] && zone.z_value == z, "The [key] zone is not where the layout puts it")
		for(var/turf/corner as anything in list(zone.get_bottom_left(), zone.get_top_right()))
			TEST_ASSERT(isspaceturf(corner), "The [key] zone's corner ([corner.x],[corner.y]) is [corner.type], not space")
			TEST_ASSERT_EQUAL(get_area(corner), vacant, "The [key] zone's corner ([corner.x],[corner.y]) is not in the vacant area")
			TEST_ASSERT_EQUAL(home.zone_at(corner), zone, "zone_at() misses the [key] zone's corner")
			TEST_ASSERT(!check_teleport_valid(habitat_player, corner), "A teleport into the vacant [key] zone is allowed")
		// A step past the zone's corner is gutter.
		var/turf/gutter = locate(zone.high_x + 1, zone.high_y + 1, z)
		TEST_ASSERT(istype(gutter, /turf/cordon), "Past the [key] zone at ([gutter.x],[gutter.y]) is [gutter.type], not cordon")
		TEST_ASSERT_EQUAL(get_area(gutter), vacant, "The gutter past the [key] zone is not in the vacant area")
	for(var/number in 1 to 4)
		var/datum/outpost_zone/berth_ground = home.berth_zone(number)
		TEST_ASSERT_EQUAL(berth_ground?.number, number, "Berth zone [number] reports berth [berth_ground?.number]")
		TEST_ASSERT_EQUAL(berth_ground?.kind, "berth", "Berth zone [number] is a [berth_ground?.kind] zone")
	TEST_ASSERT(istype(locate(1, 1, z), /turf/cordon) && istype(locate(world.maxx, world.maxy, z), /turf/cordon), "The level has no cordon rim")
	TEST_ASSERT_NULL(home.zone_at(inside), "The build region reads as a zone")
	TEST_ASSERT(!istype(inside, /turf/cordon), "The build region has cordon in it")
	TEST_ASSERT(check_teleport_valid(habitat_player, locate(build[1] + 4, build[4] - 3, z)), "A teleport inside the habitat was refused")

	// Notices reach the habitat, not somebody standing in a berth zone.
	var/datum/outpost_zone/far_berth = home.berth_zone(4)
	var/mob/living/carbon/human/berth_player = make_player(locate(far_berth.low_x + 5, far_berth.low_y + 5, z), "levelcarveberth")
	var/list/listeners = home.announcement_listeners()
	TEST_ASSERT(habitat_player in listeners, "A player in the habitat does not hear the outpost's notices")
	TEST_ASSERT(!(berth_player in listeners), "A player in a berth zone hears the outpost's notices")

/// What is wrong with a wiped zone, or null when every tile is bare space in the vacant area.
/proc/outpost_zone_leftovers(datum/outpost_zone/zone)
	var/area/vacant = GLOB.areas_by_type[/area/voidcrew/outpost_vacant]
	var/leftovers = 0
	var/wrong_turfs = 0
	var/wrong_areas = 0
	var/first_problem
	for(var/turf/tile as anything in zone.get_block())
		if(!isspaceturf(tile))
			wrong_turfs++
			first_problem ||= "([tile.x],[tile.y]) is [tile.type]"
		if(tile.loc != vacant)
			wrong_areas++
			first_problem ||= "([tile.x],[tile.y]) is in [tile.loc?.type]"
		for(var/atom/movable/thing as anything in tile)
			if(thing == tile.lighting_object || isobserver(thing))
				continue
			leftovers++
			first_problem ||= "[thing.type] left at ([tile.x],[tile.y])"
	if(!wrong_turfs && !wrong_areas && !leftovers)
		return null
	return "[wrong_turfs] non-space tiles, [wrong_areas] tiles outside the vacant area, [leftovers] leftovers; first: [first_problem]"

/// Waits (bounded) for a zone's wipe to finish. Returns whether it is vacant.
/proc/outpost_zone_wait_vacant(datum/outpost_zone/zone, timeout = 60 SECONDS)
	var/deadline = world.time + timeout
	while(world.time < deadline && !zone.is_vacant())
		sleep(world.tick_lag)
	return zone.is_vacant()

/**
 * The ship bay loads into the bay zone and keeps it through visits. Removing it wipes the zone,
 * and it can be installed again at once. Nothing reserves turfs.
 */
/datum/unit_test/voidcrew_outpost_ship_bay_zone
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_ship_bay_zone/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("bayzoneowner")
	TEST_ASSERT_NOTNULL(home, "The bay zone test outpost did not load")
	var/list/reservations_before = SSmapping.turf_reservations?.Copy() || list()
	var/datum/outpost_zone/bay_zone = home.level_zone("bay")
	TEST_ASSERT_NOTNULL(bay_zone, "The claim has no bay zone")

	for(var/install in 1 to 3)
		// The second install follows a removal straight away, while the zone may still be wiping.
		TEST_ASSERT_NULL(home.enable_ship_bays(), "Install [install]: the ship bay did not load")
		var/datum/outpost_berth/ship_bay/bay = LAZYACCESS(home.bay_berths, 1)
		TEST_ASSERT_NOTNULL(bay, "Install [install]: no ship bay")
		TEST_ASSERT_EQUAL(bay.zone, bay_zone, "Install [install]: the bay is not in the bay zone")
		TEST_ASSERT_EQUAL(bay_zone.state, "in use", "Install [install]: the bay zone is [bay_zone.state]")
		TEST_ASSERT(bay_zone.is_held_by(bay), "Install [install]: the bay zone is held by something else")
		TEST_ASSERT_NULL(bay.reservation, "Install [install]: the bay reserved turfs")
		TEST_ASSERT_EQUAL(bay.get_bottom_left(), bay_zone.get_bottom_left(), "Install [install]: the bay does not start at the zone's corner")
		TEST_ASSERT(bay_zone.contains_turf(bay.get_top_right()), "Install [install]: the bay spills out of its zone")
		var/area/bay_area = get_area(bay.alcove_turfs[1])
		TEST_ASSERT(bay_area.area_flags & NOTELEPORT, "Install [install]: the bay can be teleported into")
		var/turf/low = bay.get_bottom_left()
		var/turf/high = bay.get_top_right()
		TEST_ASSERT_EQUAL(bay.dock.site_rect?.Join(","), "[low.x],[low.y],[high.x],[high.y]", "Install [install]: the bay dock does not keep to the bay")
		// The manipulator's removal: the bay goes and its zone is wiped.
		home.ship_bay_installed = FALSE
		qdel(bay)
		home.bay_berths.Cut()
		TEST_ASSERT(bay_zone.state == "wiping" || bay_zone.state == "vacant", "Install [install]: removing the bay left its zone [bay_zone.state]")
		if(install != 1)
			continue
		TEST_ASSERT(outpost_zone_wait_vacant(bay_zone), "Install [install]: the removed bay's zone was never wiped")
		var/problem = outpost_zone_leftovers(bay_zone)
		TEST_ASSERT_NULL(problem, "Install [install]: the removed bay left its zone dirty: [problem]")

	var/list/new_reservations = (SSmapping.turf_reservations || list()) - reservations_before
	TEST_ASSERT(!length(new_reservations), "Ship bay installs reserved [length(new_reservations)] turf block\s")
