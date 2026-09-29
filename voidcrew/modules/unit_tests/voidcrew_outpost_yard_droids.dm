/**
 * Working NPCs (outpost_ambient_work.dm): the ship bay droids (outpost_yard_droids.dm) and the
 * trader outposts' mechanics (outpost_amenities.dm).
 *
 * Voidcrew defines are not visible from test files: a worker's range is 6 tiles.
 */

/// Every droid in each ship bay keeps to its own room: never onto the landing pad, through a door,
/// onto the lift or out of its area. It walks, it finds work, and nothing moves it off its room.
/datum/unit_test/voidcrew_outpost_yard_droids
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_yard_droids/Run()
	for(var/datum/map_template/bay_type as anything in outpost_style_maps(/datum/map_template/outpost_hangar/ship_bay))
		var/style = initial(bay_type.outpost_style)
		var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("yarddroids[style]")
		TEST_ASSERT_NOTNULL(home, "The [style] droid test claim did not load")
		home.outpost_style = style
		TEST_ASSERT_NULL(home.enable_ship_bays(), "The [style] ship bay did not load")
		var/datum/outpost_berth/ship_bay/bay = LAZYACCESS(home.bay_berths, 1)
		TEST_ASSERT(bay?.dock, "The [style] ship bay has no dock")
		var/list/pad = list()
		for(var/turf/tile as anything in bay.dock.return_turfs())
			pad[tile] = TRUE
		var/list/droids = bay_droids(bay)
		// The Grease Pit's six are mapped; the clean bay's are up to its mapper
		if(bay_type == /datum/map_template/outpost_hangar/ship_bay/rundown)
			TEST_ASSERT(length(droids) >= 6, "The Grease Pit has [length(droids)] working droids, not 6")
		for(var/obj/structure/outpost_yard_droid/droid as anything in droids)
			check_droid(droid, pad, bay.alcove_turfs, style)

/// Droids in the bay around `bay`'s landing pad
/datum/unit_test/voidcrew_outpost_yard_droids/proc/bay_droids(datum/outpost_berth/ship_bay/bay)
	. = list()
	var/list/coords = bay.dock.return_coords()
	var/turf/low = locate(max(1, min(coords[1], coords[3]) - 12), max(1, min(coords[2], coords[4]) - 12), bay.dock.z)
	var/turf/high = locate(min(world.maxx, max(coords[1], coords[3]) + 12), min(world.maxy, max(coords[2], coords[4]) + 12), bay.dock.z)
	for(var/turf/tile as anything in block(low, high))
		for(var/obj/structure/outpost_yard_droid/droid in tile)
			. += droid

/datum/unit_test/voidcrew_outpost_yard_droids/proc/check_droid(obj/structure/outpost_yard_droid/droid, list/pad, list/lift, style)
	var/turf/home = get_turf(droid)
	var/label = "The [style] bay's [droid] at [home.x],[home.y]"
	TEST_ASSERT(droid.anchored && !droid.density, "[label] is not anchored and walk-through")
	TEST_ASSERT(droid.resistance_flags & INDESTRUCTIBLE, "[label] can be destroyed")
	TEST_ASSERT(!pad[home], "[label] is mapped on the landing pad")
	var/datum/component/outpost_ambient_worker/worker = droid.GetComponent(/datum/component/outpost_ambient_worker)
	TEST_ASSERT_NOTNULL(worker, "[label] does not work")
	var/area/home_area = get_area(home)
	var/list/room = worker.get_room()
	TEST_ASSERT(length(room) > 1, "[label] has nowhere to walk")
	for(var/turf/tile as anything in room)
		TEST_ASSERT_EQUAL(get_area(tile), home_area, "[label] can walk out of its area at [tile.x],[tile.y]")
		TEST_ASSERT(!pad[tile], "[label] can walk onto the landing pad at [tile.x],[tile.y]")
		TEST_ASSERT(!(tile in lift), "[label] can walk onto the lift at [tile.x],[tile.y]")
		TEST_ASSERT(!(locate(/obj/machinery/door) in tile), "[label] can walk through the door at [tile.x],[tile.y]")
		TEST_ASSERT(get_dist(tile, home) <= 6, "[label] can wander to [tile.x],[tile.y]")

	var/list/job = worker.find_work()
	TEST_ASSERT(length(job) == 3, "[label] finds nothing to work on")
	TEST_ASSERT(room[job[2]], "[label] would work from [job[2]], outside its room")

	// It walks about, and every step stays in its room
	var/list/visited = list()
	for(var/step in 1 to 200)
		worker.wander_step()
		var/turf/here = get_turf(droid)
		visited[here] = TRUE
		TEST_ASSERT(room[here], "[label] wandered out of its room to [here.x],[here.y]")
		TEST_ASSERT(!pad[here], "[label] wandered onto the landing pad at [here.x],[here.y]")
	TEST_ASSERT(length(visited) > 1, "[label] never moved")

	// A step off its room is refused, onto the pad above all
	for(var/turf/tile as anything in room)
		for(var/direction in GLOB.cardinals)
			var/turf/outside = get_step(tile, direction)
			if(!outside || room[outside] || !isopenturf(outside) || outside.is_blocked_turf())
				continue
			droid.forceMove(tile)
			TEST_ASSERT(!droid.Move(outside, direction), "[label] stepped out of its room to [outside.x],[outside.y]")
			TEST_ASSERT_EQUAL(get_turf(droid), tile, "[label] left its room")
	droid.forceMove(home)

	// Nothing carries it off, and if something did it would come back
	var/turf/far = pick(pad) || run_loc_floor_bottom_left
	TEST_ASSERT(!do_teleport(droid, far, forced = TRUE, no_effects = TRUE), "[label] was teleported")
	TEST_ASSERT_EQUAL(get_turf(droid), home, "[label] moved when teleported")
	var/mob/living/carbon/human/puller = allocate(/mob/living/carbon/human/consistent, home)
	puller.start_pulling(droid)
	TEST_ASSERT(puller.pulling != droid, "[label] can be pulled")
	droid.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(worker.check_leash(), "[label] stayed where it was dropped")
	TEST_ASSERT_EQUAL(get_turf(droid), home, "[label] did not go back to its room")

	// Working shows and stops cleanly, and hands nothing out
	var/turf/spot = job[2]
	var/items_before = 0
	for(var/obj/item/thing in spot)
		items_before++
	droid.forceMove(spot)
	worker.planned_work = job[3]
	TEST_ASSERT(worker.start_work(job[1]), "[label] could not start work")
	TEST_ASSERT(worker.continue_work(), "[label] stopped work at once")
	worker.stop_work()
	TEST_ASSERT_NULL(worker.work, "[label] kept working after stopping")
	TEST_ASSERT_NULL(worker.work_overlay, "[label] kept its work sparks")
	var/items_after = 0
	for(var/obj/item/thing in spot)
		items_after++
	TEST_ASSERT_EQUAL(items_after, items_before, "[label] left something behind at work")
	droid.forceMove(home)

/// Mechanics each wear one of several outfits, change looks to work, keep to their room and stay
/// out of doorways.
/datum/unit_test/voidcrew_outpost_mechanic_work

/datum/unit_test/voidcrew_outpost_mechanic_work/Run()
	// One person three ways: working looks differ from the idle one, the visor comes down to weld
	var/list/looks = get_outpost_worker_looks(/datum/outfit/outpost_mechanic, FEMALE, 1)
	TEST_ASSERT_EQUAL(length(looks), 3, "A mechanic has [length(looks)] looks, not 3")
	for(var/look_name in list("idle", "weld", "tool"))
		TEST_ASSERT_NOTNULL(looks[look_name], "A mechanic has no [look_name] look")
	TEST_ASSERT(signature(looks["idle"]) != signature(looks["weld"]), "A mechanic welds with empty hands")
	TEST_ASSERT(signature(looks["idle"]) != signature(looks["tool"]), "A mechanic works with empty hands")
	TEST_ASSERT(has_state(looks["weld"], "weldvisor"), "A mechanic welds with the visor up")
	TEST_ASSERT(!has_state(looks["idle"], "weldvisor"), "A mechanic walks about with the visor down")
	TEST_ASSERT(get_outpost_worker_looks(/datum/outfit/outpost_mechanic, FEMALE, 1) == looks, "Working looks are not cached")

	// A crew of mechanics is not all in one outfit
	var/list/outfits = list()
	for(var/i in 1 to 12)
		var/mob/living/basic/outpost_loiterer/mechanic/someone = allocate(/mob/living/basic/outpost_loiterer/mechanic, run_loc_floor_bottom_left)
		TEST_ASSERT(someone.outfit_path in someone.outfit_choices, "A mechanic wears [someone.outfit_path]")
		outfits |= someone.outfit_path
	TEST_ASSERT(length(outfits) >= 2, "Twelve mechanics all wear [outfits[1]]")

	// In a room with a door on its east wall: never through it, never stopping beside it
	var/turf/start = locate(run_loc_floor_bottom_left.x, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/turf/door_turf = locate(run_loc_floor_top_right.x, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	allocate(/obj/machinery/door/airlock, door_turf)
	var/mob/living/basic/outpost_loiterer/mechanic/mechanic = allocate(/mob/living/basic/outpost_loiterer/mechanic, start)
	var/datum/component/outpost_ambient_worker/worker = mechanic.GetComponent(/datum/component/outpost_ambient_worker)
	TEST_ASSERT_NOTNULL(worker, "A mechanic does not work")
	var/list/room = worker.get_room()
	TEST_ASSERT(!room[door_turf], "A mechanic's room runs through a door")
	var/list/visited = list()
	for(var/step in 1 to 150)
		worker.wander_step()
		var/turf/here = get_turf(mechanic)
		visited[here] = TRUE
		TEST_ASSERT(here != door_turf, "A mechanic walked into the doorway")
		var/beside_door = get_dist(here, door_turf) == 1 && (here.x == door_turf.x || here.y == door_turf.y)
		TEST_ASSERT(!beside_door, "A mechanic stopped beside the door at [here.x],[here.y]")
	TEST_ASSERT(length(visited) > 1, "A mechanic never moved")
	var/turf/before_teleport = get_turf(mechanic)
	TEST_ASSERT(!do_teleport(mechanic, run_loc_floor_top_right, forced = TRUE, no_effects = TRUE), "A mechanic was teleported")
	TEST_ASSERT_EQUAL(get_turf(mechanic), before_teleport, "A mechanic moved when teleported")

/// What a look is drawn from: every overlay's icon, state and colour, nested overlays included
/datum/unit_test/voidcrew_outpost_mechanic_work/proc/signature(mutable_appearance/look, depth = 0)
	var/list/parts = list()
	for(var/mutable_appearance/overlay as anything in look.overlays)
		parts += "[overlay.icon]:[overlay.icon_state]:[overlay.color]"
		if(depth < 2)
			parts += signature(overlay, depth + 1)
	return jointext(parts, "|")

/// Whether any overlay of `look`, nested ones included, has an icon state containing `fragment`
/datum/unit_test/voidcrew_outpost_mechanic_work/proc/has_state(mutable_appearance/look, fragment, depth = 0)
	for(var/mutable_appearance/overlay as anything in look.overlays)
		if(findtext(overlay.icon_state, fragment))
			return TRUE
		if(depth < 2 && has_state(overlay, fragment, depth + 1))
			return TRUE
	return FALSE
