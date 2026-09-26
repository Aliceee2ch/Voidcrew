/**
 * A ship landing on a claim never reaches an upgrade. adjust_reserve_dock_to_shuttle() turns a
 * reserve dock and moves its corner to fit each arriving ship, while upgrade placement protects the
 * reserve docks' home rectangles, unturned (upgrade_protected_rects()). A landing gibs whoever stands
 * under the hull and deletes the fixtures there, so every tile a docked hull can cover must be ground
 * placement refuses: for a hull at either dock, with its port on any side and anywhere along it,
 * including the longest hulls with the port on the side, which turn the dock.
 *
 * Fork defines are included after the tests: reserve docks are 56x40
 * (RESERVE_DOCK_MAX_SIZE_LONG x RESERVE_DOCK_MAX_SIZE_SHORT).
 */
/datum/unit_test/voidcrew_outpost_dock_clearance
	parent_type = /datum/unit_test/voidcrew_outpost_management
	/// Bare mobile ports standing in for hulls; docking ports only delete when forced.
	var/list/obj/docking_port/mobile/fake_ports = list()

/datum/unit_test/voidcrew_outpost_dock_clearance/Destroy()
	for(var/obj/docking_port/mobile/port as anything in fake_ports)
		if(!QDELETED(port))
			qdel(port, force = TRUE)
	fake_ports.Cut()
	return ..()

/datum/unit_test/voidcrew_outpost_dock_clearance/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("dockclearanceowner")
	TEST_ASSERT_NOTNULL(home, "The dock clearance outpost did not load")
	var/level_z = home.upgrade_level_z()
	// width, height, dwidth, dheight, port_direction: where the port sits on the hull and which side it faces
	var/static/list/hulls = list(
		list(56, 40, 28, 0, NORTH),
		list(56, 40, 0, 20, WEST),
		list(40, 56, 20, 0, EAST),
		list(40, 56, 39, 55, WEST),
		list(40, 56, 0, 28, SOUTH),
		list(9, 55, 4, 0, EAST),
		list(9, 55, 8, 54, WEST),
		list(55, 9, 0, 4, EAST),
		list(21, 9, 20, 8, SOUTH),
		list(5, 5, 2, 2, NORTH),
	)
	var/landings = 0
	for(var/obj/docking_port/stationary/dock as anything in list(home.reserve_dock, home.reserve_dock_secondary))
		TEST_ASSERT(dock?.reserve_home_z == level_z, "A reserve dock is not on the claim's level")
		var/list/home_rect = list(dock.reserve_home_x, dock.reserve_home_y, dock.reserve_home_x + 55, dock.reserve_home_y + 39)
		for(var/list/hull in hulls)
			var/label = "a [hull[1]]x[hull[2]] hull with its port at [hull[3]],[hull[4]] facing [dir2text(hull[5])]"
			var/obj/docking_port/mobile/voidcrew/port = new(run_loc_floor_bottom_left)
			fake_ports += port
			port.width = hull[1]
			port.height = hull[2]
			port.dwidth = hull[3]
			port.dheight = hull[4]
			port.port_direction = hull[5]
			reset_reserve_dock_to_home(dock)
			adjust_reserve_dock_to_shuttle(dock, port)
			// The outpost refuses a hull that does not fit the turned dock; that one never lands.
			if(port.width > dock.width || port.height > dock.height || port.canDock(dock) != SHUTTLE_CAN_DOCK)
				continue
			landings++
			var/list/coords = port.return_coords(dock.x, dock.y, dock.dir)
			var/low_x = min(coords[1], coords[3])
			var/low_y = min(coords[2], coords[4])
			var/high_x = max(coords[1], coords[3])
			var/high_y = max(coords[2], coords[4])
			TEST_ASSERT(low_x >= home_rect[1] && low_y >= home_rect[2] && high_x <= home_rect[3] && high_y <= home_rect[4], \
				"[label] lands on ([low_x],[low_y])-([high_x],[high_y]), outside its dock's protected ground ([home_rect.Join(",")])")
			// An upgrade is placed between arrivals, with the dock back home or left where the last
			// visitor had it; either way the landing's corners must be refused.
			reset_reserve_dock_to_home(dock)
			for(var/turf/corner as anything in list(locate(low_x, low_y, level_z), locate(high_x, high_y, level_z), locate(low_x, high_y, level_z), locate(high_x, low_y, level_z)))
				TEST_ASSERT(home.is_upgrade_ground_reserved(corner), "[label] lands on ([corner.x],[corner.y]), where an upgrade may be placed")
		reset_reserve_dock_to_home(dock)
	TEST_ASSERT_EQUAL(landings, 20, "Not every test hull could land at the claim's two docks")

/// A dock the outpost refuses after claiming a reserve pad hands the pad back.
/datum/unit_test/voidcrew_outpost_reserve_pad_release
	parent_type = /datum/unit_test/voidcrew_outpost_dock_clearance
	/// The bare ship fixture, unhooked from its fake port before cleanup
	var/obj/structure/overmap/ship/visitor_ship
	/// The pad this test shrank, and the home level it hid from reset_reserve_dock_to_home()
	var/obj/docking_port/stationary/shrunk_dock
	var/saved_home_z
	/// The claim whose hangar elevator this test hid, and its elevator panels
	var/obj/structure/overmap/dynamic/player_outpost/test_home
	var/list/saved_elevator_panels

/datum/unit_test/voidcrew_outpost_reserve_pad_release/Destroy()
	if(test_home && saved_elevator_panels)
		test_home.lobby_panels = saved_elevator_panels
	test_home = null
	saved_elevator_panels = null
	if(visitor_ship)
		visitor_ship.shuttle = null
		visitor_ship.dock_index = 0
	if(shrunk_dock && !QDELETED(shrunk_dock))
		shrunk_dock.reserve_home_z = saved_home_z
		reset_reserve_dock_to_home(shrunk_dock)
	return ..()

/datum/unit_test/voidcrew_outpost_reserve_pad_release/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("reservepadowner")
	TEST_ASSERT_NOTNULL(home, "The reserve pad outpost did not load")
	// The small shell loads with a working hangar elevator, which would send the ship to a hangar
	// berth. Hide its panels so the dock falls back to the reserve pads under test.
	test_home = home
	saved_elevator_panels = home.lobby_panels
	home.lobby_panels = list()
	TEST_ASSERT(!home.has_hangar_elevator(), "The claim still has a working hangar elevator; the reserve pads are not in use")
	shrunk_dock = home.reserve_dock
	TEST_ASSERT_NOTNULL(shrunk_dock, "The claim has no reserve dock")
	saved_home_z = shrunk_dock.reserve_home_z
	// Too small for the hull, and kept that way: the outpost resets free pads before choosing one.
	shrunk_dock.reserve_home_z = 0
	shrunk_dock.width = 3
	shrunk_dock.height = 3

	var/obj/docking_port/mobile/voidcrew/port = new(run_loc_floor_bottom_left)
	fake_ports += port
	port.width = 5
	port.height = 5
	port.dwidth = 2
	port.dheight = 2
	port.port_direction = NORTH
	visitor_ship = allocate(/obj/structure/overmap/ship)
	visitor_ship.shuttle = port
	var/previous_state = visitor_ship.state
	var/mob/living/carbon/human/pilot = make_player(run_loc_floor_bottom_left, "reservepadpilot")

	home.ship_act(pilot, visitor_ship)
	TEST_ASSERT(!home.first_dock_taken, "A refused dock left its reserve pad claimed")
	TEST_ASSERT_EQUAL(visitor_ship.dock_index, 0, "A refused dock left the ship holding a pad index")
	TEST_ASSERT_EQUAL(visitor_ship.state, previous_state, "A refused dock did not restore the ship's state")
	TEST_ASSERT(!home.concerned, "A refused dock left the outpost busy")
