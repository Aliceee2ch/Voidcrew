/**
 * Outpost prison containment: the management panel's static pushes while placing the wing, and
 * dragging, stuns, bolt buttons and bolted-in prisoners.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with
 * the define named beside them. Prisons are driven with tick(seconds) with their own processing
 * stopped, never by waiting in real time, except for beams, which run on timers. Fixtures are
 * in voidcrew_outpost_prison_helpers.dm.
 */

/**
 * A second full update inside tgui's refresh cooldown makes the window remount, which lost the
 * placement map the first time a player pressed Place. The panel must push once per survey and
 * never twice inside the cooldown.
 */
/datum/unit_test/voidcrew_outpost_panel_refresh
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_panel_refresh/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("refreshowner")
	TEST_ASSERT_NOTNULL(home, "The refresh test outpost did not load")
	var/turf/console_turf = get_turf(home.management_console)
	var/mob/living/carbon/human/owner = make_player(console_turf, "refreshowner")
	var/obj/machinery/computer/player_outpost_management/console = allocate(__IMPLIED_TYPE__, console_turf)
	var/datum/player_outpost_management_ui/management_test/push_log/panel = allocate(__IMPLIED_TYPE__, home, owner, console)
	home.outpost_upgrades["prison"] = new /datum/outpost_upgrade/prison(home)
	home.upgrade_survey = null

	// First Place: the survey starts, runs, and is pushed exactly once when it lands.
	act(panel, owner, "open_upgrade_map", null, list("id" = "prison"))
	var/deadline = world.time + 20 SECONDS
	while(home.upgrade_surveying && world.time < deadline)
		sleep(1)
	TEST_ASSERT(!home.upgrade_surveying, "The survey never finished")
	TEST_ASSERT(wait_for_pushes(panel, 1), "The finished survey was never pushed")
	sleep(2)
	TEST_ASSERT_EQUAL(length(panel.push_times), 1, "Opening the placement map pushed static data more than once")
	TEST_ASSERT_NOTNULL(panel.ui_static_data(owner)["upgrade_survey"], "The pushed static data has no survey")

	// Back at once: the close waits out the cooldown instead of refreshing the window.
	act(panel, owner, "close_upgrade_map", null, list("id" = "prison"))
	TEST_ASSERT_EQUAL(length(panel.push_times), 1, "Closing the map pushed inside the refresh cooldown")
	TEST_ASSERT(wait_for_pushes(panel, 2), "Closing the map never pushed")
	TEST_ASSERT(panel.push_times[2] - panel.push_times[1] >= TGUI_REFRESH_FULL_UPDATE_COOLDOWN, "Two pushes came [panel.push_times[2] - panel.push_times[1]] ds apart")
	TEST_ASSERT_NULL(panel.ui_static_data(owner)["upgrade_survey"], "The survey was still sent after the map closed")

	// Place again with the survey cached: one push, again not inside the cooldown.
	act(panel, owner, "open_upgrade_map", null, list("id" = "prison"))
	TEST_ASSERT(wait_for_pushes(panel, 3), "Reopening the map with a cached survey never pushed")
	TEST_ASSERT(panel.push_times[3] - panel.push_times[2] >= TGUI_REFRESH_FULL_UPDATE_COOLDOWN, "The cached survey was pushed inside the cooldown")

	// Pushes that pile up while one waits collapse into a single push.
	panel.push_static_data()
	panel.push_static_data()
	panel.push_static_data()
	TEST_ASSERT(wait_for_pushes(panel, 4), "Queued pushes were never sent")
	sleep(TGUI_REFRESH_FULL_UPDATE_COOLDOWN + 2)
	TEST_ASSERT_EQUAL(length(panel.push_times), 4, "Three queued pushes were not collapsed into one")

	// A window's own cooldown, such as a client refresh the panel did not send, is waited out too.
	var/datum/tgui/window = allocate(/datum/tgui, owner, panel, "OutpostManagement")
	window.initialized = TRUE
	LAZYADD(panel.open_uis, window)
	COOLDOWN_START(window, refresh_cooldown, TGUI_REFRESH_FULL_UPDATE_COOLDOWN)
	var/started = world.time
	panel.push_static_data()
	TEST_ASSERT_EQUAL(length(panel.push_times), 4, "A push ignored the window's own refresh cooldown")
	TEST_ASSERT(wait_for_pushes(panel, 5), "A push waiting on the window's cooldown was never sent")
	TEST_ASSERT(panel.push_times[5] - started >= TGUI_REFRESH_FULL_UPDATE_COOLDOWN, "A push came before the window's cooldown ended")
	LAZYREMOVE(panel.open_uis, window)

// ===== DRAGGING, STUNS AND BOLTS =====

/datum/unit_test/voidcrew_outpost_prison_restraint
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_restraint/proc/in_stamcrit(mob/living/prisoner)
	return !!prisoner.has_status_effect(/datum/status_effect/incapacitating/stamcrit)

/datum/unit_test/voidcrew_outpost_prison_restraint/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("restraintowner")
	TEST_ASSERT_NOTNULL(home, "The restraint test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, prison_spot(home, 8, 8))
	REMOVE_TRAIT(prisoner, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 7, 8), "restraintowner")
	var/obj/structure/bed/bed = prison.cells[1].bed()

	// Awake: no pulling and no dragging onto things.
	TEST_ASSERT(!prisoner.can_be_dragged(), "An awake prisoner counts as draggable")
	warden.start_pulling(prisoner)
	TEST_ASSERT(warden.pulling != prisoner, "Someone pulled an awake prisoner")
	TEST_ASSERT(SEND_SIGNAL(prisoner, COMSIG_MOUSEDROP_ONTO, bed, warden) & COMPONENT_CANCEL_MOUSEDROP_ONTO, "An awake prisoner could be dragged onto a bed")

	// A security baton: 60 stamina and a knockdown a hit; two hits put them in stamina crit.
	var/obj/item/melee/baton/security/loaded/baton = allocate(__IMPLIED_TYPE__)
	warden.put_in_active_hand(baton)
	baton.attack_self(warden)
	TEST_ASSERT(baton.active, "The baton did not switch on")
	warden.set_combat_mode(TRUE)
	click_wrapper(warden, prisoner)
	TEST_ASSERT(prisoner.getStaminaLoss() >= 60, "A baton hit did [prisoner.getStaminaLoss()] stamina damage")
	// A security baton knocks down two seconds after the hit, as it does people.
	TEST_ASSERT(wait_until(CALLBACK(prisoner, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, can_be_dragged)), 4 SECONDS), "A knocked down prisoner could not be dragged")
	TEST_ASSERT(prisoner.has_status_effect(/datum/status_effect/incapacitating/knockdown), "The baton did not knock the prisoner down")
	COOLDOWN_RESET(baton, cooldown_check)
	REMOVE_TRAIT(prisoner, TRAIT_IWASBATONED, REF(warden))
	click_wrapper(warden, prisoner)
	warden.set_combat_mode(FALSE)
	TEST_ASSERT(in_stamcrit(prisoner), "Two baton hits did not put a prisoner in stamina crit")
	TEST_ASSERT_EQUAL(prisoner.body_position, LYING_DOWN, "A prisoner in stamina crit is still standing")
	TEST_ASSERT(!prisoner.routine_allowed(), "A prisoner in stamina crit kept up their routine")

	// Down, they can be pulled and dragged; stamina crit holds 20 seconds after the last hit
	// (PRISONER_STAMCRIT_TIME), twice tg's default.
	TEST_ASSERT_EQUAL(prisoner.stamina_regen_time, 200, "Prisoner stamina crit does not last 20 seconds")
	TEST_ASSERT(!(SEND_SIGNAL(prisoner, COMSIG_MOUSEDROP_ONTO, bed, warden) & COMPONENT_CANCEL_MOUSEDROP_ONTO), "A prisoner in stamina crit could not be dragged onto a bed")
	warden.start_pulling(prisoner)
	TEST_ASSERT_EQUAL(warden.pulling, prisoner, "A prisoner in stamina crit could not be pulled")
	sleep(11 SECONDS)
	TEST_ASSERT(in_stamcrit(prisoner), "Stamina crit ended within tg's default 10 seconds")
	// Once they are back on their feet, nobody holds them any more.
	prisoner.setStaminaLoss(0)
	TEST_ASSERT(!in_stamcrit(prisoner), "Clearing stamina did not end stamina crit")
	TEST_ASSERT(wait_until(CALLBACK(prisoner, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, routine_allowed)), 8 SECONDS) || !prisoner.can_be_dragged(), "The prisoner never recovered")
	TEST_ASSERT(warden.pulling != prisoner, "A recovered prisoner was still being pulled")

	// A disabler: 30 stamina a shot, four shots.
	var/mob/living/basic/outpost_prisoner/runner = test_prisoner(prison, prison_spot(home, 12, 8))
	REMOVE_TRAIT(runner, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	var/obj/item/gun/energy/disabler/disabler = allocate(__IMPLIED_TYPE__)
	warden.forceMove(prison_spot(home, 11, 8))
	warden.drop_all_held_items()
	warden.put_in_active_hand(disabler)
	for(var/i in 1 to 6)
		if(in_stamcrit(runner))
			break
		disabler.melee_attack_chain(warden, runner)
		sleep(1 SECONDS)
	TEST_ASSERT(in_stamcrit(runner), "A disabler did not put a prisoner in stamina crit (stamina [runner.getStaminaLoss()])")
	runner.setStaminaLoss(0)

	// Bolt buttons: each bolts its own cell's door and no other, and the link goes through its own wing.
	var/obj/machinery/button/outpost_prison_bolt/button = locate() in prison_spot(home, 8, 11)
	TEST_ASSERT_NOTNULL(button, "Cell 2's bolt button is not where the map puts it")
	TEST_ASSERT_EQUAL(button.cell_number, 2, "The button beside cell 2 is for cell [button.cell_number]")
	TEST_ASSERT_EQUAL(get_outpost_prison(button), prison, "The button does not belong to this prison")
	var/datum/outpost_prison_cell/cell_two = prison.cells[2]
	var/obj/machinery/door/airlock/cell_door = cell_two.door()
	TEST_ASSERT(get_dist(button, cell_door) <= 1, "Cell 2's button is not beside its door")
	TEST_ASSERT(button.attempt_press(warden), "The bolt button could not be pressed")
	TEST_ASSERT(cell_door.locked, "The bolt button did not bolt its cell")
	for(var/datum/outpost_prison_cell/other as anything in prison.cells)
		if(other != cell_two)
			TEST_ASSERT(!other.door().locked, "Cell 2's button bolted cell [other.number]")

	// Bolted in: they stay in the cell, and the time is counted.
	var/mob/living/basic/outpost_prisoner/inmate = runner
	inmate.forceMove(prison_spot(home, 7, 14))
	prison.refresh_prisoner_reach(inmate)
	TEST_ASSERT(!inmate.walkable[prison_spot(home, 7, 8)], "A bolted-in prisoner could still walk into the yard")
	for(var/turf/tile as anything in inmate.walkable)
		TEST_ASSERT(cell_two.turf_set[tile], "A bolted-in prisoner could walk to [tile.x],[tile.y] outside the cell")
	for(var/i in 1 to 10)
		var/datum/prisoner_activity/chosen = inmate.choose_activity()
		if(chosen?.spot)
			TEST_ASSERT(cell_two.turf_set[chosen.spot], "A bolted-in prisoner chose [chosen.type] outside the cell")
		inmate.end_activity(cancel_ai = FALSE)
	prison.tick(60)
	TEST_ASSERT_EQUAL(inmate.locked_in_seconds, 60, "A minute bolted in counted [inmate.locked_in_seconds] s")
	var/list/admin_data = prison.admin_payload()
	var/found_locked = FALSE
	for(var/list/row as anything in admin_data["prisoners"])
		if(row["ref"] == REF(inmate))
			found_locked = row["locked_in"]
	TEST_ASSERT(found_locked, "The admin panel does not show the prisoner as locked in")
	var/datum/prisoner_activity/call_out/calling = new(inmate)
	TEST_ASSERT_EQUAL(calling.get_weight(), 0, "A prisoner called out before two minutes bolted in")
	prison.tick(61)
	TEST_ASSERT(calling.get_weight() > 0, "A prisoner bolted in over two minutes would not call out")
	TEST_ASSERT(calling.setup(), "Calling out could not be set up")
	TEST_ASSERT(cell_two.turf_set[calling.spot] && get_dist(calling.spot, cell_door) == 1, "Calling out did not go to the cell door")
	qdel(calling)
	var/said_locked_in = FALSE
	for(var/i in 1 to 30)
		var/list/choice = inmate.pick_speech()
		if(choice && choice[1] == "locked_in")
			said_locked_in = TRUE
			break
	TEST_ASSERT(said_locked_in, "A prisoner bolted in over two minutes never complained about it")
	TEST_ASSERT(button.attempt_press(warden), "The bolt button could not be pressed again")
	TEST_ASSERT(!cell_door.locked, "The bolt button did not unbolt its cell")
	prison.tick(1)
	TEST_ASSERT_EQUAL(inmate.locked_in_seconds, 0, "Unbolting did not reset the locked-in time")
	prison.refresh_prisoner_reach(inmate)
	TEST_ASSERT(inmate.walkable[prison_spot(home, 7, 8)], "An unbolted prisoner still could not reach the yard")
	settle_prison_air(home)
