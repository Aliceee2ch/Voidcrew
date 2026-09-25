/**
 * The outpost prison: the management panel's static pushes, prisoner needs and the serving hatch,
 * pay, cells and beams, the routine and dialogue, dragging and bolts, and the admin tools.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with
 * the define named beside them. Prisons are driven with tick(seconds) with their own processing
 * stopped, never by waiting in real time, except for beams, which run on timers.
 */

/// Records every static data push, since a test world has no client to show the refresh screen
/datum/player_outpost_management_ui/management_test/push_log
	var/list/push_times = list()

/datum/player_outpost_management_ui/management_test/push_log/update_static_data_for_all_viewers()
	push_times += world.time
	return ..()

/// Sleeps until `panel` has made `count` pushes or `timeout` passes
/datum/unit_test/voidcrew_outpost_management/proc/wait_for_pushes(datum/player_outpost_management_ui/management_test/push_log/panel, count, timeout = 3 SECONDS)
	var/deadline = world.time + timeout
	while(length(panel.push_times) < count && world.time < deadline)
		sleep(1)
	return length(panel.push_times) >= count

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

// ===== PRISON FIXTURE =====

/// A loaded claim with a running prison wing placed north of its shell, unrotated, so authored
/// map coordinates apply. The prison's own clock is stopped; tests drive it with tick(). Trouble
/// (threats, fights, riots, escapes) is off, so these tests see the quiet side on its own;
/// voidcrew_outpost_prison_trouble.dm turns it back on.
/datum/unit_test/voidcrew_outpost_management/proc/prison_test_claim(owner_key)
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim(owner_key)
	if(!home)
		return null
	var/datum/outpost_upgrade/prison/blueprint = new(home)
	home.outpost_upgrades["prison"] = blueprint
	var/turf/bottom_left = locate(home.template_bottom_left.x, home.template_bottom_left.y + home.shell_template.height + 3, home.upgrade_level_z())
	if(home.place_outpost_upgrade(blueprint, bottom_left, 0, null) || !blueprint.prison)
		return null
	STOP_PROCESSING(SSprocessing, blueprint.prison)
	blueprint.prison.pay_clock = 0
	blueprint.prison.pay_owed = 0
	blueprint.prison.trouble_enabled = FALSE
	home.ensure_home_services()
	return home

/datum/unit_test/voidcrew_outpost_management/proc/test_prison(obj/structure/overmap/dynamic/player_outpost/home)
	var/datum/outpost_upgrade/prison/blueprint = home.outpost_upgrades["prison"]
	return blueprint.prison

/// A tile of the unrotated wing by its authored map coordinates (1,1 is the south-west corner)
/datum/unit_test/voidcrew_outpost_management/proc/prison_spot(obj/structure/overmap/dynamic/player_outpost/home, x, y)
	var/datum/outpost_upgrade/prison/blueprint = home.outpost_upgrades["prison"]
	var/list/bounds = blueprint.footprint_bounds
	return locate(bounds[1] + x - 1, bounds[2] + y - 1, bounds[5])

/// A prisoner booked into the first free cell by hand, standing still at `spot`, fed and in a clean uniform
/datum/unit_test/voidcrew_outpost_management/proc/test_prisoner(datum/outpost_prison/prison, turf/spot)
	var/mob/living/basic/outpost_prisoner/prisoner = new(spot)
	prison.admit(prisoner)
	prisoner.sentence_left = 3600
	prisoner.set_hunger(100)
	prisoner.set_uniform_grime(0)
	ADD_TRAIT(prisoner, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	return prisoner

/// Lets a freshly placed wing's air go idle before the claim is torn down
/datum/unit_test/voidcrew_outpost_management/proc/settle_prison_air(obj/structure/overmap/dynamic/player_outpost/home)
	var/datum/outpost_upgrade/prison/blueprint = home.outpost_upgrades["prison"]
	var/list/bounds = blueprint?.footprint_bounds
	if(!bounds)
		return
	var/settle_until = world.time + 30 SECONDS
	while(world.time < settle_until)
		var/busy = FALSE
		for(var/turf/open/room_turf in block(bounds[1] - 1, bounds[2] - 1, bounds[5], bounds[3] + 1, bounds[4] + 1, bounds[5]))
			if(room_turf.excited)
				busy = TRUE
				break
		if(!busy)
			break
		sleep(1 SECONDS)

/// Sleeps until `condition` holds or `timeout` passes; returns whether it held
/datum/unit_test/voidcrew_outpost_management/proc/wait_until(datum/callback/condition, timeout = 5 SECONDS)
	var/deadline = world.time + timeout
	while(!condition.Invoke() && world.time < deadline)
		sleep(1)
	return condition.Invoke()

/datum/unit_test/voidcrew_outpost_management/proc/windoor_open(obj/machinery/door/window/windoor)
	return windoor && !windoor.density && !windoor.operating

/// Keeps a prisoner reaching for `thing` (opening a hatch as needed) until they can, or 12 seconds pass
/datum/unit_test/voidcrew_outpost_management/proc/reach_until_ok(mob/living/basic/outpost_prisoner/prisoner, obj/item/thing)
	var/deadline = world.time + 12 SECONDS
	while(world.time < deadline)
		if(prisoner.try_reach(thing) == 1) // PRISONER_REACH_OK
			return TRUE
		sleep(2)
	return prisoner.try_reach(thing) == 1

/**
 * Plays one activity to its end as the AI would, with walks done by teleport. Returns what the
 * last tick returned (1 done), or 0 if it ran out of steps.
 */
/datum/unit_test/voidcrew_outpost_management/proc/drive_activity(mob/living/basic/outpost_prisoner/prisoner, datum/prisoner_activity/activity, steps = 40, list/walked)
	for(var/i in 1 to steps)
		if(QDELETED(activity) || prisoner.activity != activity)
			return 1
		if(activity.spot && prisoner.loc != activity.spot)
			walked?.Add(activity.spot)
			prisoner.stand_up()
			prisoner.forceMove(activity.spot)
		if(activity.spot || !activity.started)
			if(!activity.arrive())
				prisoner.end_activity(cancel_ai = FALSE)
				return 1
			continue
		var/result = activity.tick(1)
		if(result == 1) // ACTIVITY_DONE
			prisoner.end_activity(cancel_ai = FALSE)
			return 1
		if(result == 0) // ACTIVITY_CONTINUE
			sleep(1)
	return 0

// ===== NEEDS, THE HATCH, MESS, BLOOD AND FIRST AID =====

/datum/unit_test/voidcrew_outpost_prison_needs
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_needs/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("needsowner")
	TEST_ASSERT_NOTNULL(home, "The needs test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/turf/yard_by_hatch = prison_spot(home, 5, 7)
	var/turf/hatch_turf = prison_spot(home, 5, 6)
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in hatch_turf
	TEST_ASSERT_NOTNULL(hatch, "The serving hatch is not where the map puts it")
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, yard_by_hatch)
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 5, 5), "needsowner")

	// Unit tests are parsed before voidcrew/_DEFINES, so the rates are read off one minute of play:
	// full to empty hunger in 10 minutes (10 a minute), clean to filthy in 12 (100/12 a minute).
	prison.tick(60)
	var/hunger_rate = 100 - prisoner.hunger
	var/grime_rate = prisoner.uniform_grime
	TEST_ASSERT(abs(hunger_rate - 10) < 0.01, "A minute took [hunger_rate] hunger, not 10")
	TEST_ASSERT(abs(grime_rate - 100 / 12) < 0.01, "A minute added [grime_rate] grime, not [100 / 12]")
	prisoner.adjust_needs(9 * 60)
	TEST_ASSERT(prisoner.hunger < 0.01, "Ten minutes did not empty hunger ([prisoner.hunger])")
	prisoner.set_uniform_grime(0)
	prisoner.adjust_needs(12 * 60)
	TEST_ASSERT(prisoner.uniform_grime > 99.99, "Twelve minutes did not ruin the uniform ([prisoner.uniform_grime])")

	// The hatch is a security desk: a window door on each side of the counter.
	var/obj/machinery/door/window/yard_door = hatch.yard_windoor()
	var/obj/machinery/door/window/staff_door = hatch.staff_windoor()
	TEST_ASSERT(yard_door && staff_door, "The serving hatch is missing a window door")
	TEST_ASSERT_EQUAL(get_step(hatch, yard_door.dir), yard_by_hatch, "The yard-side window door does not face the yard")
	TEST_ASSERT_EQUAL(get_step(hatch, staff_door.dir), prison_spot(home, 5, 5), "The staff-side window door does not face the office")
	TEST_ASSERT_EQUAL(hatch.yard_side_turf(), yard_by_hatch, "The hatch does not know where prisoners reach in from")
	TEST_ASSERT(yard_door.allowed(prisoner), "The yard side refuses prisoners")
	TEST_ASSERT(!staff_door.allowed(prisoner), "The staff side opens for prisoners")
	TEST_ASSERT(staff_door.allowed(warden), "The staff side wants an ID")
	TEST_ASSERT(!hatch.both_sides_open(), "A shut hatch reads as open")

	// Food they can reach: on the hatch, yes, through their own window door; on the office floor, no.
	prisoner.set_hunger(30)
	prisoner.set_uniform_grime(0)
	var/obj/item/food/prison_ration/office_food = allocate(__IMPLIED_TYPE__, prison_spot(home, 8, 5))
	prison.refresh_reach()
	TEST_ASSERT(prisoner.wants_food(), "A prisoner at 30 hunger did not want food")
	TEST_ASSERT_NULL(prison.find_supply(prisoner), "A prisoner went for food in the office, out of reach")
	var/obj/item/food/prison_ration/hatch_food = allocate(__IMPLIED_TYPE__, hatch_turf)
	TEST_ASSERT_EQUAL(prison.find_supply(prisoner), hatch_food, "A prisoner did not find food on the serving hatch")
	TEST_ASSERT(!prisoner.Adjacent(hatch_food), "Food behind the shut window door was within reach")
	TEST_ASSERT_EQUAL(prisoner.try_reach(hatch_food), 2, "Reaching for the hatch did not open the prisoner's side") // PRISONER_REACH_WAIT
	TEST_ASSERT(wait_until(CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/voidcrew_outpost_management, windoor_open), yard_door)), "The yard-side window door never opened")
	TEST_ASSERT(staff_door.density, "Reaching in opened the staff side too")
	TEST_ASSERT_EQUAL(prisoner.try_reach(hatch_food), 1, "The prisoner could not reach through their open side") // PRISONER_REACH_OK
	staff_door.open()
	TEST_ASSERT(hatch.both_sides_open(), "Both sides open did not read as open")
	staff_door.close()
	qdel(office_food)

	// Eating: food carried from the hatch to a stool at a mess table, eaten there, crumbs left.
	var/datum/prisoner_activity/eat/meal = prisoner.start_activity(new /datum/prisoner_activity/eat(prisoner))
	TEST_ASSERT(meal.setup(), "A hungry prisoner would not go for food on the hatch")
	TEST_ASSERT_EQUAL(meal.spot, yard_by_hatch, "A prisoner went somewhere other than the hatch for food")
	var/list/walked = list()
	REMOVE_TRAIT(prisoner, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	meal.arrive()
	for(var/i in 1 to 20)
		var/result = meal.tick(1)
		if(result == 2) // ACTIVITY_MOVE
			break
		TEST_ASSERT_NOTEQUAL(result, 1, "The meal ended before the food was taken")
		// The AI ticks activities once a second; the hatch takes about that long to open.
		sleep(1 SECONDS)
	TEST_ASSERT_EQUAL(prisoner.held_item, hatch_food, "The prisoner did not take the food off the hatch")
	var/obj/structure/chair/stool/seat = locate() in meal.spot
	TEST_ASSERT_NOTNULL(seat, "The prisoner did not head for a stool")
	TEST_ASSERT_NOTNULL(prison.table_beside(seat), "The chosen stool is not at a mess table")
	walked += meal.spot
	prisoner.forceMove(meal.spot)
	meal.arrive()
	TEST_ASSERT_EQUAL(prisoner.buckled, seat, "The prisoner did not sit on the stool to eat")
	TEST_ASSERT_EQUAL(hatch_food.loc, meal.table_turf, "The meal was not put on the table")
	meal.eat_until = world.time
	TEST_ASSERT_EQUAL(meal.tick(1), 1, "The meal did not finish")
	prisoner.end_activity(cancel_ai = FALSE)
	TEST_ASSERT(QDELETED(hatch_food), "The meal was not eaten")
	TEST_ASSERT(abs(prisoner.hunger - 80) < 0.01, "Eating did not add 50 hunger (now [prisoner.hunger])") // PRISONER_FOOD_VALUE
	TEST_ASSERT(locate(/obj/effect/decal/cleanable/food/crumbs) in get_turf(seat), "Eating left no crumbs where they sat")
	TEST_ASSERT_NULL(prisoner.buckled, "The prisoner stayed sat after the meal")
	// Wrappers are left often, not always.
	var/wrappers = 0
	for(var/i in 1 to 10)
		var/obj/item/food/prison_ration/sample = new(prison_spot(home, 8, 8))
		prisoner.leave_meal_mess(sample, prison_spot(home, 8, 8), prison_spot(home, 4, 9))
		qdel(sample)
	for(var/obj/item/trash/wrapper in prison_spot(home, 4, 9))
		wrappers++
		qdel(wrapper)
	TEST_ASSERT(wrappers >= 1, "Ten meals left no wrapper or tray on the table")
	for(var/obj/effect/decal/cleanable/food/crumbs/crumbs in prison_spot(home, 8, 8))
		qdel(crumbs)
	ADD_TRAIT(prisoner, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	prisoner.forceMove(yard_by_hatch)

	// With nobody on the level the AI sleeps, and the prison lets them help themselves instead.
	prisoner.set_hunger(30)
	prison.refresh_reach()
	var/obj/item/food/prison_ration/unwatched_food = allocate(__IMPLIED_TYPE__, hatch_turf)
	TEST_ASSERT_NOTEQUAL(prisoner.ai_controller.ai_status, AI_STATUS_ON, "The prisoner's AI runs in a world with no players")
	prison.tick(5)
	TEST_ASSERT(QDELETED(unwatched_food), "An unwatched prisoner did not eat reachable food")
	TEST_ASSERT(prisoner.hunger > 79, "Eating unwatched did not add 50 hunger (now [prisoner.hunger])")
	TEST_ASSERT(locate(/obj/effect/decal/cleanable/food/crumbs) in yard_by_hatch, "Eating unwatched left no crumbs")

	// Handing food over: eaten when hungry, refused when full.
	prisoner.set_hunger(20)
	var/obj/item/food/prison_ration/handed = allocate(__IMPLIED_TYPE__)
	warden.forceMove(prison_spot(home, 6, 7))
	warden.put_in_active_hand(handed)
	click_wrapper(warden, prisoner)
	TEST_ASSERT(QDELETED(handed), "The prisoner did not eat food handed to them")
	TEST_ASSERT(abs(prisoner.hunger - 70) < 0.01, "Hand feeding did not add 50 hunger (now [prisoner.hunger])")
	prisoner.set_hunger(95)
	var/obj/item/food/prison_ration/refused = allocate(__IMPLIED_TYPE__)
	warden.put_in_active_hand(refused)
	click_wrapper(warden, prisoner)
	TEST_ASSERT(!QDELETED(refused) && warden.is_holding(refused), "A full prisoner ate anyway")
	TEST_ASSERT(abs(prisoner.hunger - 95) < 0.01, "Refused food changed hunger")
	qdel(refused)

	// Uniforms: a clean one on the hatch is found and swapped, and the grimy one left in its place.
	prisoner.set_hunger(100)
	prisoner.set_uniform_grime(90)
	var/obj/item/clothing/under/rank/prisoner/outpost/fresh = allocate(__IMPLIED_TYPE__, hatch_turf)
	prison.refresh_reach()
	TEST_ASSERT_EQUAL(prison.find_supply(prisoner, TRUE), fresh, "A filthy prisoner did not find the clean uniform on the hatch")
	TEST_ASSERT(reach_until_ok(prisoner, fresh), "The prisoner could not reach the uniform through the hatch")
	TEST_ASSERT(prisoner.take_uniform(fresh), "The prisoner did not change at the hatch")
	TEST_ASSERT(QDELETED(fresh), "The clean uniform was not taken")
	TEST_ASSERT(prisoner.uniform_grime < 0.01, "Changing did not leave the prisoner clean ([prisoner.uniform_grime])")
	var/obj/item/clothing/under/rank/prisoner/outpost/left_behind = locate() in hatch_turf
	TEST_ASSERT_NOTNULL(left_behind, "The old uniform was not left on the hatch")
	TEST_ASSERT(abs(left_behind.grime - 90) < 0.01, "The uniform left behind has [left_behind.grime] grime, not 90")
	TEST_ASSERT_NULL(prison.find_supply(prisoner, TRUE), "A clean prisoner went looking for another uniform")

	// By hand: a cleaner one is taken and the old one handed back; a dirtier one is refused.
	prisoner.set_uniform_grime(70)
	var/obj/item/clothing/under/rank/prisoner/outpost/offered = allocate(__IMPLIED_TYPE__)
	offered.set_grime(10)
	warden.put_in_active_hand(offered)
	click_wrapper(warden, prisoner)
	TEST_ASSERT(abs(prisoner.uniform_grime - 10) < 0.01, "A handed-over uniform was not worn (grime [prisoner.uniform_grime])")
	var/obj/item/clothing/under/rank/prisoner/outpost/handed_back = warden.get_active_held_item()
	TEST_ASSERT(istype(handed_back), "The old uniform was not handed back")
	TEST_ASSERT(abs(handed_back.grime - 70) < 0.01, "The handed-back uniform has [handed_back.grime] grime, not 70")
	click_wrapper(warden, prisoner)
	TEST_ASSERT_EQUAL(warden.get_active_held_item(), handed_back, "A dirtier uniform was taken")

	// The wing's washing machine gets it clean.
	var/obj/machinery/washing_machine/washer = locate() in prison_spot(home, 3, 2)
	TEST_ASSERT_NOTNULL(washer, "The washing machine is not where the map puts it")
	warden.temporarilyRemoveItemFromInventory(handed_back)
	handed_back.forceMove(washer)
	washer.wash_cycle(warden)
	TEST_ASSERT(handed_back.grime < 0.01, "Washing left [handed_back.grime] grime")
	handed_back.forceMove(hatch_turf)
	qdel(handed_back)
	qdel(left_behind)

	// Thought bubbles: one at a time, hungry over hurt over dirty, only when it needs attention.
	for(var/need in list("hungry", "dirty", "hurt", "riot", "experiment"))
		TEST_ASSERT_NOTNULL(outpost_prisoner_bubble_item(need), "The thought bubble has no item look for [need]")
	prisoner.set_hunger(10)
	prisoner.set_uniform_grime(90)
	prisoner.adjustBruteLoss(20)
	TEST_ASSERT_EQUAL(prisoner.bubble, "hungry", "Hunger did not outrank the other needs")
	prisoner.set_hunger(100)
	TEST_ASSERT_EQUAL(prisoner.bubble, "hurt", "The bubble did not fall back to the injury")
	prisoner.adjustBruteLoss(-20)
	TEST_ASSERT_EQUAL(prisoner.bubble, "dirty", "The bubble did not fall back to the dirty uniform")
	prisoner.set_uniform_grime(0)
	TEST_ASSERT_NULL(prisoner.bubble, "A well kept prisoner showed a bubble")
	prisoner.set_hunger(45)
	prisoner.set_uniform_grime(45)
	TEST_ASSERT_NULL(prisoner.bubble, "A prisoner above every threshold showed a bubble")

	// Medical: the advanced med HUD tracks their health bar, and a bruise pack treats them.
	var/datum/atom_hud/medhud = GLOB.huds[DATA_HUD_MEDICAL_ADVANCED]
	TEST_ASSERT(medhud.hud_atoms_all_z_levels[prisoner], "The prisoner is not on the medical HUD")
	prisoner.adjustBruteLoss(40)
	var/image/health_bar = prisoner.hud_list[HEALTH_HUD]
	TEST_ASSERT_EQUAL(health_bar.icon_state, "hud[RoundHealth(prisoner)]", "The health bar did not follow the injury")
	TEST_ASSERT(abs(prisoner.care() - (200 + 60) / 3) < 0.01, "Care with 60 health was [prisoner.care()], not 86.7")
	prison.tick(10 * 60)
	TEST_ASSERT_EQUAL(prisoner.health, 60, "Health came back on its own")
	var/obj/item/stack/medical/bruise_pack/pack = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(pack.try_heal_checks(prisoner, warden, BODY_ZONE_CHEST, TRUE), "A bruise pack could not treat the prisoner")
	pack.heal_simplemob(prisoner, warden)
	TEST_ASSERT_EQUAL(prisoner.health, 100, "A bruise pack did not treat the prisoner")
	TEST_ASSERT_EQUAL(health_bar.icon_state, "hudhealth100", "The health bar did not recover")

	// Blood: a real brute hit leaves blood on the floor, and the wing counts it as mess.
	prisoner.forceMove(prison_spot(home, 10, 8))
	warden.forceMove(prison_spot(home, 10, 9))
	prison.refresh_conditions()
	var/clean_before = prison.clean_score
	var/obj/item/storage/toolbox/toolbox = allocate(__IMPLIED_TYPE__)
	warden.put_in_active_hand(toolbox)
	warden.set_combat_mode(TRUE)
	click_wrapper(warden, prisoner)
	warden.set_combat_mode(FALSE)
	TEST_ASSERT(prisoner.health < 100, "The toolbox did not hurt the prisoner")
	TEST_ASSERT(locate(/obj/effect/decal/cleanable/blood) in prison_spot(home, 10, 8), "A brute hit left no blood on the floor")
	prison.refresh_conditions()
	TEST_ASSERT(prison.clean_score < clean_before, "Blood on the floor did not count as mess")
	// Badly hurt and untreated, they drip; treated, they stop.
	prisoner.forceMove(prison_spot(home, 11, 8))
	prisoner.adjustBruteLoss(60 - prisoner.getBruteLoss())
	TEST_ASSERT(prisoner.maybe_drip(1000), "A prisoner at 40% health never dripped")
	TEST_ASSERT(locate(/obj/effect/decal/cleanable/blood) in prison_spot(home, 11, 8), "The drip left nothing on the floor")
	prisoner.adjustBruteLoss(-prisoner.getBruteLoss())
	TEST_ASSERT(!prisoner.maybe_drip(1000), "A treated prisoner still dripped")

	// The wing's first aid kit holds dressings and a scanner, nothing that goes in a mouth or vein.
	var/obj/item/storage/medkit/brute/outpost_prison/kit = locate() in prison_spot(home, 16, 2)
	TEST_ASSERT_NOTNULL(kit, "The prison first aid kit is not on the office table")
	TEST_ASSERT(locate(/obj/item/stack/medical/bruise_pack) in kit, "The prison kit has no bruise packs")
	TEST_ASSERT(locate(/obj/item/stack/medical/suture) in kit, "The prison kit has no sutures")
	for(var/obj/item/thing in kit)
		TEST_ASSERT(!istype(thing, /obj/item/reagent_containers) && !thing.reagents, "The prison kit holds [thing], which carries chemicals")
	settle_prison_air(home)

// ===== ECONOMY =====

/datum/unit_test/voidcrew_outpost_prison_economy
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_economy/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("payowner")
	TEST_ASSERT_NOTNULL(home, "The economy test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/datum/bank_account/treasury = home.treasury

	// A fresh wing is clean, lit and powered, once any bulb that came broken (tg breaks 2-5% of
	// lights at load) is replaced.
	var/list/lights = list()
	for(var/turf/tile as anything in prison.wing_turfs())
		for(var/obj/machinery/light/fixture in tile)
			lights += fixture
			if(fixture.status != LIGHT_OK)
				fixture.fix()
	TEST_ASSERT_EQUAL(length(lights), 10, "The wing should have 10 lights")
	prison.refresh_conditions()
	TEST_ASSERT_EQUAL(prison.clean_score, 100, "A fresh wing is not clean")
	TEST_ASSERT_EQUAL(prison.lit_score, 100, "A fresh wing is not fully lit")
	TEST_ASSERT_EQUAL(prison.powered_score, 100, "A fresh wing has no power")

	// Conditions: 5 per piece of mess (OUTPOST_PRISON_MESS_PENALTY), the share of working
	// lights, and all or nothing for power.
	var/list/mess = list()
	for(var/x in 3 to 6)
		mess += allocate(/obj/effect/decal/cleanable/dirt, prison_spot(home, x, 7))
	mess += allocate(/obj/item/trash/candy, prison_spot(home, 8, 7))
	var/obj/machinery/light/broken = lights[1]
	broken.break_light_tube()
	prison.refresh_conditions()
	TEST_ASSERT_EQUAL(prison.clean_score, 75, "Five pieces of mess did not cost 25 cleanliness")
	TEST_ASSERT_EQUAL(prison.lit_score, round(100 * (length(lights) - 1) / length(lights)), "One broken light was not counted")
	var/obj/machinery/power/apc/apc = prison.wing.apc
	TEST_ASSERT_NOTNULL(apc, "The wing has no APC")
	apc.operating = FALSE
	apc.update()
	prison.refresh_conditions()
	TEST_ASSERT_EQUAL(prison.powered_score, 0, "The wing counted as powered with its breaker off")
	TEST_ASSERT_EQUAL(prison.lit_score, 0, "Lights counted as working with no power")
	TEST_ASSERT(abs(prison.conditions_score() - 25) < 0.01, "Conditions were [prison.conditions_score()], not 25")
	apc.operating = TRUE
	apc.update()
	broken.fix()
	QDEL_LIST(mess)
	prison.refresh_conditions()
	TEST_ASSERT(abs(prison.conditions_score() - 100) < 0.01, "Conditions did not recover ([prison.clean_score]/[prison.lit_score]/[prison.powered_score])")

	// Pay: base 20 cr/min (OUTPOST_PRISON_BASE_PAY) x care x conditions, deposited once a minute.
	var/mob/living/basic/outpost_prisoner/kept = test_prisoner(prison, prison_spot(home, 3, 8))
	var/mob/living/basic/outpost_prisoner/neglected = test_prisoner(prison, prison_spot(home, 12, 8))
	// Fed 50 (hunger 20 of 40), clean 40 (grime 80), health 90: care 60.
	neglected.set_hunger(20)
	neglected.set_uniform_grime(80)
	neglected.adjustBruteLoss(10)
	TEST_ASSERT(abs(neglected.care() - 60) < 0.01, "Care came to [neglected.care()], not 60")
	TEST_ASSERT(abs(kept.care() - 100) < 0.01, "A well kept prisoner's care was [kept.care()]")
	var/start = treasury.account_balance
	prison.tick(60)
	TEST_ASSERT_EQUAL(treasury.account_balance - start, 32, "A minute at care 100 and 60 in perfect conditions paid [treasury.account_balance - start], not 20 + 12")
	TEST_ASSERT_EQUAL(prison.paid_total, 32, "The prison's paid total did not count the stipend")
	neglected.set_hunger(20)
	neglected.set_uniform_grime(80)
	var/list/data = prison.ui_payload(null)
	TEST_ASSERT(abs(data["pay_rate"] - 32) < 0.2, "The console pay rate was [data["pay_rate"]], not about 32")

	// With 6 pieces of mess conditions are 90: 28.8 cr a minute, deposited in whole credits.
	for(var/x in 3 to 8)
		mess += allocate(/obj/effect/decal/cleanable/dirt, prison_spot(home, x, 10))
	for(var/i in 1 to 2)
		kept.set_hunger(100)
		kept.set_uniform_grime(0)
		neglected.set_hunger(20)
		neglected.set_uniform_grime(80)
		prison.tick(60)
	TEST_ASSERT(abs(prison.conditions_score() - 90) < 0.01, "Six pieces of mess left conditions at [prison.conditions_score()], not 90")
	TEST_ASSERT_EQUAL(treasury.account_balance - start, 32 + 28 + 29, "Two minutes at 28.8 cr did not deposit 28 then 29")
	TEST_ASSERT(abs(prison.pay_owed - 0.6) < 0.01, "The unpaid fraction was [prison.pay_owed], not 0.6")
	QDEL_LIST(mess)
	prison.refresh_conditions()

	// Release: the last 30 seconds are paid, then 200 (OUTPOST_PRISON_RELEASE_BONUS) x the
	// average of care x conditions over the sentence.
	qdel(neglected)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 1, "Deleting a prisoner left them on the roster")
	prison.pay_owed = 0
	kept.set_hunger(100)
	kept.set_uniform_grime(0)
	kept.sentence_left = 30
	kept.served_seconds = 0
	kept.kept_seconds = 0
	start = treasury.account_balance
	var/paid_before = prison.paid_total
	var/kept_name = kept.real_name
	prison.tick(60)
	TEST_ASSERT_EQUAL(kept.phase, "leaving", "A prisoner whose sentence ended was not being beamed out") // PRISONER_LEAVING
	TEST_ASSERT_EQUAL(treasury.account_balance - start, 200 + 10, "A perfect release paid [treasury.account_balance - start], not 200 bonus + 10 stipend")
	TEST_ASSERT_EQUAL(prison.paid_total - paid_before, 210, "The paid total missed the release")
	var/list/newest = prison.entries[1]
	TEST_ASSERT(findtext(newest["text"], kept_name) && findtext(newest["text"], "released"), "The release was not logged first: [newest["text"]]")
	// Half care over the sentence halves the bonus.
	var/mob/living/basic/outpost_prisoner/half = test_prisoner(prison, prison_spot(home, 12, 8))
	half.served_seconds = 600
	half.kept_seconds = 300
	start = treasury.account_balance
	TEST_ASSERT_EQUAL(prison.release(half), 100, "Half care over the sentence did not halve the bonus")
	TEST_ASSERT_EQUAL(treasury.account_balance - start, 100, "The half bonus was not paid")
	TEST_ASSERT(wait_until(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(is_qdeleted_ref), WEAKREF(kept)), 6 SECONDS), "The released prisoner was never beamed out")
	TEST_ASSERT_EQUAL(length(prison.prisoners) <= 1, TRUE, "A beamed-out prisoner stayed on the roster")

	// The ration dispenser bills the treasury 40 cr (OUTPOST_PRISON_RATION_COST) per ration.
	var/obj/machinery/outpost_ration_dispenser/dispenser = locate() in prison_spot(home, 4, 5)
	TEST_ASSERT_NOTNULL(dispenser, "The ration dispenser is not where the map puts it")
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 4, 4), "payowner")
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 5, 4), "payvisitor")
	start = treasury.account_balance
	TEST_ASSERT_NULL(dispenser.dispense(owner), "The owner could not order a ration")
	TEST_ASSERT_EQUAL(start - treasury.account_balance, 40, "A ration did not cost 40 cr")
	TEST_ASSERT(locate(/obj/item/food/prison_ration) in owner.held_items, "The ration was not handed over")
	COOLDOWN_RESET(dispenser, dispense_cooldown)
	TEST_ASSERT_EQUAL(dispenser.dispense(visitor), "residents only", "A visitor billed the treasury")
	treasury.adjust_money(-treasury.account_balance, "Prison test")
	TEST_ASSERT_EQUAL(dispenser.dispense(owner), "insufficient funds", "An empty treasury paid for a ration")
	TEST_ASSERT_EQUAL(treasury.account_balance, 0, "A refused ration charged the treasury")
	settle_prison_air(home)

/// Whether the datum behind a weakref is gone
/proc/is_qdeleted_ref(datum/weakref/ref)
	var/datum/thing = ref?.resolve()
	return QDELETED(thing)

// ===== CELLS, ARRIVALS, RELEASES AND THE CONSOLE =====

/datum/unit_test/voidcrew_outpost_prison_cells
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_cells/proc/console_act(obj/machinery/computer/outpost_prison_warden/console, mob/user, action)
	var/datum/tgui/ui = allocate(/datum/tgui, user, console, "OutpostPrison")
	return console.ui_act(action, list(), ui, GLOB.always_state)

/datum/unit_test/voidcrew_outpost_prison_cells/proc/all_present(datum/outpost_prison/prison)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prison.prisoners)
		if(prisoner.phase != "present")
			return FALSE
	return TRUE

/datum/unit_test/voidcrew_outpost_prison_cells/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("cellsowner")
	TEST_ASSERT_NOTNULL(home, "The cells test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/obj/machinery/computer/outpost_prison_warden/console = locate() in prison_spot(home, 7, 5)
	TEST_ASSERT_NOTNULL(console, "The warden's console is not where the map puts it")
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 7, 4), "cellsowner")
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 8, 4), "cellsvisitor")

	// Four cells, numbered by their doors, each with a bed and nine tiles inside.
	TEST_ASSERT_EQUAL(length(prison.cells), 4, "The wing does not have four cells")
	for(var/number in 1 to 4)
		var/datum/outpost_prison_cell/cell = prison.cells[number]
		TEST_ASSERT_EQUAL(cell.number, number, "Cell [number] is numbered [cell.number]")
		var/obj/machinery/door/airlock/door = cell.door()
		TEST_ASSERT_EQUAL(get_turf(door), prison_spot(home, 4 * number - 1, 12), "Cell [number]'s door is not where the map puts it")
		TEST_ASSERT_EQUAL(door.name, "Cell [number]", "Cell [number]'s door is called [door.name]")
		TEST_ASSERT_NOTNULL(cell.bed(), "Cell [number] has no bed")
		TEST_ASSERT_EQUAL(get_turf(cell.bed()), prison_spot(home, 4 * number - 2, 15), "Cell [number]'s bed is not the one in the cell")
		TEST_ASSERT_EQUAL(length(cell.turfs), 9, "Cell [number] has [length(cell.turfs)] tiles inside, not 9")
		TEST_ASSERT_EQUAL(cell.arrival_turf(), get_turf(cell.bed()), "Cell [number] does not deliver to its bed")
	TEST_ASSERT_NOTNULL(locate(/obj/item/toy/basketball) in prison_spot(home, 9, 9), "The ball is not where the intake pad was")

	// The console sends exactly the keys OutpostPrison.tsx reads.
	var/list/data = console.ui_data(visitor)
	for(var/key in list("linked", "powered", "intake_open", "next_arrival", "capacity", "pay_rate", "paid_total", "can_manage", "conditions", "prisoners", "log"))
		TEST_ASSERT(key in data, "The warden console sends no [key]")
	TEST_ASSERT(data["linked"], "The warden console is not linked to its prison")
	TEST_ASSERT(!data["can_manage"], "A visitor could manage the prison")
	TEST_ASSERT_EQUAL(data["capacity"], 4, "The prison does not hold 4") // OUTPOST_PRISON_CAPACITY
	TEST_ASSERT_NULL(data["next_arrival"], "An arrival was due with intake closed")
	for(var/key in list("clean", "lit", "powered", "score"))
		TEST_ASSERT(key in data["conditions"], "The console's conditions have no [key]")

	// Only managers open intake; the first prisoner is due in 5 seconds (OUTPOST_PRISON_FIRST_ARRIVAL).
	console_act(console, visitor, "toggle_intake")
	TEST_ASSERT(!prison.intake_open, "A visitor opened intake")
	console_act(console, owner, "toggle_intake")
	TEST_ASSERT(prison.intake_open, "The owner could not open intake")
	TEST_ASSERT_EQUAL(console.ui_data(owner)["next_arrival"], 5, "The first prisoner is not due in 5 seconds")

	// One at a time, each into their own cell, 20 to 40 seconds apart (OUTPOST_PRISON_ARRIVAL_GAP_*).
	prison.tick(4)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 0, "A prisoner arrived early")
	prison.tick(1)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 1, "Only one prisoner should arrive at a time")
	var/mob/living/basic/outpost_prisoner/first = prison.prisoners[1]
	TEST_ASSERT_EQUAL(first.console_status(), "arriving", "A prisoner in the beam was not arriving")
	TEST_ASSERT(HAS_TRAIT(first, TRAIT_IMMOBILIZED), "A prisoner could move inside the beam")
	var/list/seen_cells = list()
	for(var/i in 1 to 3)
		var/gap = prison.arrival_countdown
		TEST_ASSERT(gap >= 20 && gap <= 40, "The next arrival is [gap] s away, not 20-40")
		prison.tick(gap - 1)
		TEST_ASSERT_EQUAL(length(prison.prisoners), i, "A prisoner arrived before the gap was up")
		prison.tick(1)
		TEST_ASSERT_EQUAL(length(prison.prisoners), i + 1, "No prisoner arrived when the gap was up")
	for(var/mob/living/basic/outpost_prisoner/arrival as anything in prison.prisoners)
		TEST_ASSERT_NOTNULL(arrival.cell, "[arrival] has no cell")
		TEST_ASSERT(!(arrival.cell in seen_cells), "Two prisoners share cell [arrival.cell.number]")
		seen_cells += arrival.cell
		TEST_ASSERT_EQUAL(arrival.cell.occupant, arrival, "Cell [arrival.cell.number] does not know its prisoner")
		TEST_ASSERT_EQUAL(arrival.loc, arrival.cell.arrival_turf(), "[arrival] did not beam into their own cell")
		TEST_ASSERT_EQUAL(arrival.prison, prison, "[arrival] does not know their prison")
		TEST_ASSERT(arrival.sentence_left >= 480 && arrival.sentence_left <= 900, "[arrival] got a [arrival.sentence_left] s sentence, not 8-15 min")
		TEST_ASSERT(arrival.personality && arrival.crime, "[arrival] has no personality or crime")
	TEST_ASSERT_NULL(prison.arrival_countdown, "An arrival was still due with every cell full")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(all_present), prison), 8 SECONDS), "The arrivals never finished beaming in")
	for(var/mob/living/basic/outpost_prisoner/arrival as anything in prison.prisoners)
		TEST_ASSERT(!HAS_TRAIT(arrival, TRAIT_IMMOBILIZED), "[arrival] was still held after beaming in")
		ADD_TRAIT(arrival, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
		// Long enough that the rest of the test releases nobody by accident.
		arrival.sentence_left = 3600
	TEST_ASSERT_EQUAL(length(prison.entries), 4, "The arrivals were not logged")

	// The roster: name, cell, crime and time left, in cell order, and nothing about their needs.
	var/list/roster = console.ui_data(owner)["prisoners"]
	TEST_ASSERT_EQUAL(length(roster), 4, "The console roster does not list every prisoner")
	for(var/i in 1 to 4)
		var/list/row = roster[i]
		TEST_ASSERT_EQUAL(length(row), 6, "A roster row sends [length(row)] fields, not 6")
		for(var/key in list("ref", "name", "cell", "crime", "sentence_left", "status"))
			TEST_ASSERT(key in row, "The console roster sends no [key]")
		TEST_ASSERT_EQUAL(row["cell"], i, "The roster is not in cell order")
		TEST_ASSERT_EQUAL(row["status"], "present", "A settled prisoner is listed as [row["status"]]")
	TEST_ASSERT_NULL(console.ui_data(owner)["next_arrival"], "An arrival was due with the prison full")

	// Staff doors: shut to prisoners whether open or closed, free to everyone else.
	var/mob/living/basic/outpost_prisoner/tester = prison.prisoners[1]
	var/obj/machinery/door/airlock/security/prison_staff/staff_door = locate() in prison_spot(home, 9, 6)
	TEST_ASSERT_NOTNULL(staff_door, "The office door is not a staff airlock")
	TEST_ASSERT(!staff_door.allowed(tester), "A prisoner may open the office door")
	TEST_ASSERT(staff_door.allowed(visitor), "The office door wants an ID from a visitor")
	TEST_ASSERT(!staff_door.CanAStarPass(SOUTH, new /datum/can_pass_info(tester)), "Prisoners path through the office door")
	TEST_ASSERT(staff_door.CanAStarPass(SOUTH, new /datum/can_pass_info(visitor)), "People cannot path through the office door")
	staff_door.open()
	TEST_ASSERT(!staff_door.density, "The office door did not open")
	var/turf/tester_home = tester.loc
	tester.forceMove(prison_spot(home, 9, 7))
	REMOVE_TRAIT(tester, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	tester.Move(get_turf(staff_door), SOUTH)
	TEST_ASSERT_EQUAL(tester.loc, prison_spot(home, 9, 7), "A prisoner walked through the open office door")
	ADD_TRAIT(tester, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	tester.forceMove(tester_home)
	var/obj/machinery/door/airlock/entrance = locate() in prison_spot(home, 9, 1)
	TEST_ASSERT(istype(entrance, /obj/machinery/door/airlock/security/prison_staff), "The entrance is not a staff airlock")
	var/datum/outpost_prison_cell/first_cell = prison.cells[1]
	TEST_ASSERT(first_cell.door().allowed(tester), "A cell door refused a prisoner")

	// Release: in the last 30 seconds they head back to their cell (OUTPOST_PRISON_RELEASE_WALK)...
	var/mob/living/basic/outpost_prisoner/leaver = prison.prisoners[2]
	var/datum/outpost_prison_cell/leaver_cell = leaver.cell
	leaver.forceMove(prison_spot(home, 10, 8))
	prison.refresh_prisoner_reach(leaver)
	leaver.sentence_left = 25
	TEST_ASSERT_EQUAL(leaver.console_status(), "leaving", "A prisoner in their last 30 seconds is not listed as leaving")
	var/datum/prisoner_activity/walk_home = leaver.choose_activity()
	TEST_ASSERT(istype(walk_home, /datum/prisoner_activity/go_home), "A prisoner due out chose [walk_home?.type] instead of heading home")
	TEST_ASSERT_EQUAL(walk_home.spot, leaver_cell.arrival_turf(), "A prisoner due out did not head for their own cell")
	leaver.end_activity(cancel_ai = FALSE)
	// ...and beam out when it ends, from wherever they stand if they did not get there.
	var/datum/weakref/leaver_ref = WEAKREF(leaver)
	prison.tick(25)
	TEST_ASSERT_EQUAL(leaver.phase, "leaving", "A released prisoner was not beamed out")
	TEST_ASSERT(HAS_TRAIT(leaver, TRAIT_IMMOBILIZED), "A prisoner could walk out of the beam")
	TEST_ASSERT(wait_until(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(is_qdeleted_ref), leaver_ref), 6 SECONDS), "The beam never took the released prisoner")
	TEST_ASSERT_NULL(leaver_cell.occupant, "The released prisoner's cell was not freed")
	TEST_ASSERT_EQUAL(length(prison.prisoners), 3, "The released prisoner stayed on the roster")
	var/refill = prison.arrival_countdown
	TEST_ASSERT(refill >= 60 && refill <= 120, "The freed cell refills in [refill] s, not 60-120") // OUTPOST_PRISON_REFILL_MIN/MAX
	prison.tick(refill)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 4, "The freed cell was not refilled")
	TEST_ASSERT(leaver_cell.occupant, "The new arrival did not take the free cell")
	TEST_ASSERT_EQUAL(leaver_cell.occupant.loc, leaver_cell.arrival_turf(), "The new arrival did not beam into the free cell")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(all_present), prison), 8 SECONDS), "The replacement never finished beaming in")
	leaver_cell.occupant.sentence_left = 3600

	// Closing intake stops arrivals; a freed cell stays empty until it reopens.
	console_act(console, owner, "toggle_intake")
	TEST_ASSERT(!prison.intake_open, "The owner could not close intake")
	var/mob/living/basic/outpost_prisoner/removed = prison.prisoners[4]
	qdel(removed)
	prison.tick(10 * 60)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 3, "A prisoner arrived with intake closed")
	TEST_ASSERT_NULL(console.ui_data(owner)["next_arrival"], "An arrival was due with intake closed")
	console_act(console, owner, "toggle_intake")
	prison.tick(5)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 4, "Reopening intake did not refill the free cell")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(all_present), prison), 8 SECONDS), "The reopened intake's arrival never finished beaming in")
	for(var/mob/living/basic/outpost_prisoner/arrival as anything in prison.prisoners)
		arrival.sentence_left = max(arrival.sentence_left, 3600)

	// A death is logged, the body holds its cell until collected two minutes later
	// (OUTPOST_PRISON_CORPSE_PICKUP), and the corrections service beams it out.
	var/mob/living/basic/outpost_prisoner/victim = prison.prisoners[1]
	victim.death()
	TEST_ASSERT_EQUAL(victim.console_status(), "dead", "A dead prisoner was not listed as dead")
	TEST_ASSERT_EQUAL(victim.body_position, LYING_DOWN, "A dead prisoner did not fall down")
	var/list/newest = prison.entries[1]
	TEST_ASSERT(findtext(newest["text"], "died"), "The death was not logged first: [newest["text"]]")
	TEST_ASSERT_EQUAL(prison.prisoner_pay_rate(victim), 0, "A body earned a stipend")
	prison.tick(119)
	TEST_ASSERT(victim.phase == "present" && (victim in prison.prisoners), "The body was collected early")
	var/datum/weakref/victim_ref = WEAKREF(victim)
	prison.tick(1)
	TEST_ASSERT(wait_until(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(is_qdeleted_ref), victim_ref), 6 SECONDS), "The body was never collected")
	TEST_ASSERT_EQUAL(length(prison.prisoners), 3, "The collected body kept its cell")
	settle_prison_air(home)

// ===== ROUTINE AND DIALOGUE =====

/datum/unit_test/voidcrew_outpost_prison_routine
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_routine/proc/has_activity(mob/living/basic/outpost_prisoner/prisoner)
	return prisoner.activity?.started

/datum/unit_test/voidcrew_outpost_prison_routine/proc/in_flight(datum/prisoner_activity/basketball/game)
	return QDELETED(game) || !game.in_flight

/datum/unit_test/voidcrew_outpost_prison_routine/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("routineowner")
	TEST_ASSERT_NOTNULL(home, "The routine test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/list/personalities = outpost_prisoner_dialogue("personalities")
	var/list/crimes = outpost_prisoner_dialogue("crimes")
	var/list/lines = outpost_prisoner_dialogue("lines")
	var/list/conversations = outpost_prisoner_dialogue("conversations")

	// The dialogue file loads, with every context the prisoners use.
	TEST_ASSERT(length(personalities) >= 5, "The dialogue file has [length(personalities)] personalities")
	TEST_ASSERT(length(crimes), "The dialogue file has no crimes")
	TEST_ASSERT(length(conversations), "The dialogue file has no conversations")
	var/list/contexts = list("idle", "arrival", "release_soon", "release", "hungry", "starving", "filthy", "hurt", "dark", "dirty_prison", "no_power", "staff_near", "thanks_food", "thanks_uniform", "thanks_treatment", "eating", "basketball", "basketball_score", "basketball_miss", "reading", "resting", "sleeping", "water", "window", "pacing", "hatch_wait", "locked_in")
	for(var/context in contexts)
		var/list/entry = lines[context]
		TEST_ASSERT(islist(entry) && length(entry["any"]), "The dialogue file has no shared lines for [context]")
	for(var/datum/prisoner_activity/activity_type as anything in GLOB.outpost_prisoner_leisure + list(/datum/prisoner_activity/eat, /datum/prisoner_activity/hatch_wait))
		var/context = initial(activity_type.context)
		if(context)
			TEST_ASSERT(context in lines, "[activity_type] speaks in a context the dialogue file lacks: [context]")

	var/mob/living/basic/outpost_prisoner/talker = test_prisoner(prison, prison_spot(home, 7, 8))
	var/mob/living/basic/outpost_prisoner/listener = test_prisoner(prison, prison_spot(home, 9, 8))
	TEST_ASSERT(talker.personality in personalities, "A prisoner got the personality [talker.personality]")
	TEST_ASSERT(talker.crime in crimes, "A prisoner got the crime [talker.crime]")
	TEST_ASSERT_EQUAL(talker.cell, prison.cells[1], "The first booked prisoner is not in cell 1")
	TEST_ASSERT_EQUAL(listener.cell, prison.cells[2], "The second booked prisoner is not in cell 2")

	// Placeholders: their own first name and crime, the other's first name, the time left.
	talker.sentence_left = 600
	var/filled = talker.fill_line("{name}|{other}|{crime}|{time_left}", listener)
	TEST_ASSERT_EQUAL(filled, "[first_name(talker.real_name)]|[first_name(listener.real_name)]|[talker.crime]|10 minutes", "Placeholders were filled as [filled]")
	talker.sentence_left = 50
	TEST_ASSERT_EQUAL(talker.time_left_text(), "a minute", "50 seconds read as [talker.time_left_text()]")
	talker.sentence_left = 20
	TEST_ASSERT_EQUAL(talker.time_left_text(), "20 seconds", "20 seconds read as [talker.time_left_text()]")
	talker.sentence_left = 3600
	for(var/i in 1 to 40)
		var/alone = talker.pick_line("idle", null)
		TEST_ASSERT(alone && !findtext(alone, "{") && !findtext(alone, "}"), "An idle line came out unfilled or empty: [alone]")
		var/together = talker.pick_line("idle", listener)
		TEST_ASSERT(together && !findtext(together, "{"), "An idle line to another came out unfilled: [together]")
		var/reply = talker.pick_line("release_soon", null)
		TEST_ASSERT(reply && !findtext(reply, "{"), "A release_soon line came out unfilled: [reply]")
	TEST_ASSERT_NULL(talker.pick_line("no_such_context", null), "A missing context produced a line")

	// Two-person conversations: an opener, and a reply from the other a few seconds later.
	listener.last_line = null
	TEST_ASSERT(talker.start_conversation(listener), "A conversation did not start")
	TEST_ASSERT_NOTNULL(talker.last_line, "The opener was not said")
	TEST_ASSERT(!prison.wing_can_speak(), "A conversation did not start the wing's speech cooldown")
	sleep(6 SECONDS)
	TEST_ASSERT_NOTNULL(listener.last_line, "Nobody replied to the opener")
	var/replied = FALSE
	for(var/list/conversation as anything in conversations)
		if(listener.last_line in conversation["replies"])
			replied = TRUE
			break
	TEST_ASSERT(replied, "The reply was not one of the file's replies: [listener.last_line]")

	// Cooldowns: nothing spontaneous while the prisoner's or the wing's cooldown runs.
	COOLDOWN_START(talker, speech_cooldown, 1 MINUTES)
	talker.said_release_soon = TRUE
	for(var/i in 1 to 50)
		TEST_ASSERT(!talker.speech_tick(), "A prisoner spoke inside their own cooldown")
	COOLDOWN_RESET(talker, speech_cooldown)
	prison.note_speech()
	for(var/i in 1 to 50)
		TEST_ASSERT(!talker.speech_tick(), "A prisoner spoke inside the wing's cooldown")
	COOLDOWN_RESET(prison, wing_speech_cooldown)
	var/spoke = FALSE
	for(var/i in 1 to 200)
		if(talker.speech_tick())
			spoke = TRUE
			break
	TEST_ASSERT(spoke, "A prisoner with no cooldown never spoke")
	TEST_ASSERT(!COOLDOWN_FINISHED(talker, speech_cooldown), "Speaking did not start the prisoner's cooldown")
	// Needs and the wing come first.
	talker.set_hunger(5)
	var/list/said = list()
	for(var/i in 1 to 40)
		var/list/choice = talker.pick_speech()
		if(choice)
			said |= choice[1]
	TEST_ASSERT("starving" in said, "A starving prisoner never talked about food ([jointext(said, ", ")])")
	for(var/context in said)
		TEST_ASSERT(context in lines, "A prisoner picked the missing context [context]")
	talker.set_hunger(100)

	// The routine: every leisure activity that can be set up goes somewhere they can walk, in the wing.
	REMOVE_TRAIT(talker, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	prison.refresh_conditions()
	var/list/set_up = list()
	for(var/activity_type in GLOB.outpost_prisoner_leisure)
		var/datum/prisoner_activity/activity = new activity_type(talker)
		if(activity.setup())
			set_up += activity_type
			if(activity.spot)
				TEST_ASSERT(talker.walkable[activity.spot], "[activity_type] sent them somewhere they cannot walk")
				TEST_ASSERT_EQUAL(activity.spot.loc, prison.wing, "[activity_type] sent them out of the wing")
		qdel(activity)
	TEST_ASSERT_EQUAL(length(prison.claims), 0, "Activities that were set up and dropped left claims behind")
	for(var/activity_type in list(/datum/prisoner_activity/rest, /datum/prisoner_activity/rest/sleep, /datum/prisoner_activity/sit_bed, /datum/prisoner_activity/toilet, /datum/prisoner_activity/sink, /datum/prisoner_activity/basketball, /datum/prisoner_activity/read, /datum/prisoner_activity/water, /datum/prisoner_activity/chat, /datum/prisoner_activity/pace, /datum/prisoner_activity/window, /datum/prisoner_activity/wander))
		TEST_ASSERT(activity_type in set_up, "[activity_type] could not be set up in a fresh wing")
	// Picking by needs, personality and what is free always gives something valid.
	for(var/i in 1 to 30)
		var/datum/prisoner_activity/chosen = talker.choose_activity()
		TEST_ASSERT_NOTNULL(chosen, "The routine found nothing to do")
		if(chosen.spot)
			TEST_ASSERT(talker.walkable[chosen.spot] && chosen.spot.loc == prison.wing, "[chosen.type] was chosen with a spot out of reach")
		talker.end_activity(cancel_ai = FALSE)

	// Resting: on their own bed, lying down; getting up afterwards.
	var/datum/prisoner_activity/rest/nap = talker.start_activity(new /datum/prisoner_activity/rest(talker))
	TEST_ASSERT(nap.setup(), "Resting could not be set up")
	TEST_ASSERT_EQUAL(nap.spot, get_turf(talker.cell.bed()), "Resting did not go to their own bed")
	talker.forceMove(nap.spot)
	nap.arrive()
	TEST_ASSERT_EQUAL(talker.buckled, talker.cell.bed(), "Resting did not put them in bed")
	TEST_ASSERT_EQUAL(talker.body_position, LYING_DOWN, "Resting in bed was not lying down")
	TEST_ASSERT_EQUAL(nap.tick(1), 0, "Resting ended at once") // ACTIVITY_CONTINUE
	talker.end_activity(cancel_ai = FALSE)
	TEST_ASSERT_NULL(talker.buckled, "Getting up left them in bed")

	// Reading: a book off the shelf, read in the chair by the bookcase.
	talker.forceMove(prison_spot(home, 4, 8))
	prison.refresh_prisoner_reach(talker)
	var/obj/structure/bookcase/shelf = locate() in prison_spot(home, 2, 7)
	TEST_ASSERT_NOTNULL(shelf, "The bookcase is not where the map puts it")
	TEST_ASSERT(locate(/obj/item/book) in shelf, "The bookcase has no books")
	var/datum/prisoner_activity/read/reading = talker.start_activity(new /datum/prisoner_activity/read(talker))
	TEST_ASSERT(reading.setup(), "Reading could not be set up")
	for(var/i in 1 to 20)
		if(reading.stage == "reading")
			break
		if(reading.spot && talker.loc != reading.spot)
			talker.stand_up()
			talker.forceMove(reading.spot)
		if(reading.spot || !reading.started)
			reading.arrive()
			continue
		reading.tick(1)
	TEST_ASSERT_EQUAL(reading.stage, "reading", "The prisoner never sat down to read")
	TEST_ASSERT(istype(talker.held_item, /obj/item/book), "The prisoner is reading without a book")
	TEST_ASSERT(istype(talker.buckled, /obj/structure/chair/comfy), "The prisoner is not reading in the chair")
	reading.ends_at = world.time
	drive_activity(talker, reading)
	TEST_ASSERT_NULL(talker.activity, "Reading never ended")
	TEST_ASSERT_NULL(talker.held_item, "The book stayed in their hands after reading")

	// Basketball: the ball, a shot at the hoop, the rebound.
	talker.forceMove(prison_spot(home, 9, 8))
	prison.refresh_prisoner_reach(talker)
	var/obj/structure/hoop/hoop = locate() in prison_spot(home, 9, 11)
	TEST_ASSERT_NOTNULL(hoop, "The hoop is not where the map puts it")
	TEST_ASSERT_NOTNULL(locate(/obj/item/toy/basketball) in prison_spot(home, 9, 9), "The ball is not where the map puts it")
	var/datum/prisoner_activity/basketball/game = talker.start_activity(new /datum/prisoner_activity/basketball(talker))
	TEST_ASSERT(game.setup(), "Basketball could not be set up")
	game.arrive()
	var/shots = 0
	for(var/i in 1 to 40)
		if(game.in_flight)
			shots++
			TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(in_flight), game), 5 SECONDS), "A shot never landed")
			if(shots >= 2)
				break
		if(game.spot && talker.loc != game.spot)
			talker.forceMove(game.spot)
			game.arrive()
			continue
		game.tick(1)
	TEST_ASSERT(shots >= 2, "The prisoner took [shots] shot\s in 40 steps")
	talker.end_activity(cancel_ai = FALSE)
	TEST_ASSERT(!istype(talker.held_item, /obj/item/toy/basketball), "The ball stayed in their hands after the game")

	// Chatting: walks up to another prisoner, who stops to listen, and they face each other.
	listener.forceMove(prison_spot(home, 11, 8))
	talker.forceMove(prison_spot(home, 7, 8))
	REMOVE_TRAIT(listener, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	prison.refresh_reach()
	var/datum/prisoner_activity/chat/chat = talker.start_activity(new /datum/prisoner_activity/chat(talker))
	TEST_ASSERT(chat.setup(), "A chat could not be set up with another prisoner in the yard")
	TEST_ASSERT(get_dist(chat.spot, listener) <= 1, "The chat did not go up to the other prisoner")
	talker.forceMove(chat.spot)
	COOLDOWN_RESET(prison, wing_speech_cooldown)
	TEST_ASSERT(chat.arrive(), "The chat did not start on arrival")
	TEST_ASSERT(istype(listener.activity, /datum/prisoner_activity/chat/listen), "The other prisoner did not stop to listen")
	TEST_ASSERT_EQUAL(listener.activity.chat_partner(), talker, "The listener is not listening to the talker")
	TEST_ASSERT_EQUAL(chat.tick(1), 0, "The chat ended at once") // ACTIVITY_CONTINUE
	TEST_ASSERT_EQUAL(talker.dir, get_dir(talker, listener), "The talker does not face the listener")
	talker.end_activity(cancel_ai = FALSE)
	TEST_ASSERT_NULL(listener.activity, "The listener kept listening after the chat")

	// The live AI: with someone on the level, a prisoner picks something and walks to it.
	var/mob/living/carbon/human/watcher = make_player(prison_spot(home, 9, 4), "routineowner")
	var/z = talker.z
	SSmobs.clients_by_zlevel[z] |= watcher
	talker.end_activity(cancel_ai = FALSE)
	talker.ai_controller.reset_ai_status()
	TEST_ASSERT_EQUAL(talker.ai_controller.ai_status, AI_STATUS_ON, "The prisoner's AI did not wake with someone on the level")
	var/turf/start_turf = talker.loc
	var/woke = wait_until(CALLBACK(src, PROC_REF(has_activity), talker), 20 SECONDS)
	SSmobs.clients_by_zlevel[z] -= watcher
	talker.ai_controller.reset_ai_status()
	TEST_ASSERT(woke, "The awake prisoner never started an activity (now [talker.activity?.name], at [talker.x],[talker.y])")
	TEST_ASSERT(talker.loc != start_turf || !talker.activity.spot, "The awake prisoner never walked anywhere")
	TEST_ASSERT_EQUAL(get_area(talker), prison.wing, "The awake prisoner left the wing")
	talker.end_activity()
	settle_prison_air(home)

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

// ===== ADMIN TOOLS =====

/// Counts what the manipulator logs, without an admin client
/datum/outpost_manipulator/unit_test/prison
	var/list/operations = list()

/datum/outpost_manipulator/unit_test/prison/record(mob/user, obj/structure/overmap/dynamic/player_outpost/home, operation)
	operations += operation
	return ..()

/datum/unit_test/voidcrew_outpost_prison_admin
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_admin/proc/all_present(datum/outpost_prison/prison)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prison.prisoners)
		if(prisoner.phase != "present")
			return FALSE
	return TRUE

/datum/unit_test/voidcrew_outpost_prison_admin/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("prisonadminowner")
	TEST_ASSERT_NOTNULL(home, "The admin test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/operator = make_player(prison_spot(home, 8, 4), "prisonadmin")
	var/datum/outpost_manipulator/unit_test/prison/panel = allocate(__IMPLIED_TYPE__, operator)
	panel.selected = home

	// The Prison section rides on the selected outpost; null without a prison.
	var/list/data = panel.ui_data(operator)
	var/list/section = data["selected"]["prison"]
	TEST_ASSERT(islist(section), "The selected outpost sends no prison section")
	for(var/key in list("intake_open", "next_arrival", "pay_rate", "paid_total", "powered", "conditions", "cells", "prisoners"))
		TEST_ASSERT(key in section, "The prison section sends no [key]")
	TEST_ASSERT_EQUAL(length(section["cells"]), 4, "The prison section lists [length(section["cells"])] cells")
	for(var/list/cell_row as anything in section["cells"])
		TEST_ASSERT(("number" in cell_row) && ("occupant_ref" in cell_row), "A cell row lacks its number or occupant")
	var/obj/structure/overmap/dynamic/player_outpost/bare = allocate(/obj/structure/overmap/dynamic/player_outpost)
	TEST_ASSERT_NULL(panel.prison_admin_data(bare), "An outpost without a prison sent a prison section")

	// Only admins: a manipulator without R_ADMIN does nothing.
	var/datum/outpost_manipulator/unauthorized = allocate(/datum/outpost_manipulator, operator)
	unauthorized.selected = home
	unauthorized.manage_outpost(home, operator, "prison_spawn", list())
	unauthorized.manage_outpost(home, operator, "prison_intake", list("open" = 1))
	TEST_ASSERT_EQUAL(length(prison.prisoners), 0, "A non-admin spawned a prisoner")
	TEST_ASSERT(!prison.intake_open, "A non-admin opened intake")
	panel.allow_actions = FALSE
	panel.manage_outpost(home, operator, "prison_spawn", list())
	TEST_ASSERT_EQUAL(length(prison.prisoners), 0, "A revoked admin panel spawned a prisoner")
	panel.allow_actions = TRUE

	// Intake, validated.
	panel.manage_outpost(home, operator, "prison_intake", list("open" = "yes"))
	TEST_ASSERT(!prison.intake_open && panel.error, "A bad intake setting was accepted")
	panel.manage_outpost(home, operator, "prison_intake", list("open" = 1))
	TEST_ASSERT(prison.intake_open, "The admin could not open intake")
	panel.manage_outpost(home, operator, "prison_intake", list("open" = 0))
	TEST_ASSERT(!prison.intake_open, "The admin could not close intake")

	// Spawn one now, then fill the rest; nothing when full.
	panel.manage_outpost(home, operator, "prison_spawn", list())
	TEST_ASSERT_EQUAL(length(prison.prisoners), 1, "Spawn did not beam in one prisoner")
	var/mob/living/basic/outpost_prisoner/first = prison.prisoners[1]
	TEST_ASSERT_EQUAL(first.cell, prison.cells[1], "The spawned prisoner is not in a free cell")
	panel.manage_outpost(home, operator, "prison_fill", list())
	TEST_ASSERT_EQUAL(length(prison.prisoners), 4, "Fill did not fill every cell")
	panel.manage_outpost(home, operator, "prison_spawn", list())
	TEST_ASSERT(length(prison.prisoners) == 4 && panel.error, "Spawn into a full prison did not refuse")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(all_present), prison), 8 SECONDS), "The spawned prisoners never finished beaming in")
	for(var/mob/living/basic/outpost_prisoner/arrival as anything in prison.prisoners)
		ADD_TRAIT(arrival, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	section = panel.ui_data(operator)["selected"]["prison"]
	TEST_ASSERT_EQUAL(length(section["prisoners"]), 4, "The prison section lists [length(section["prisoners"])] prisoners")
	var/list/first_row = section["prisoners"][1]
	for(var/key in list("ref", "name", "cell", "personality", "crime", "activity", "hunger", "grime", "health", "care", "sentence_left", "dead", "locked_in"))
		TEST_ASSERT(key in first_row, "A prisoner row sends no [key]")
	TEST_ASSERT(istext(first_row["activity"]) && length(first_row["activity"]), "A prisoner row has no activity text")
	var/list/first_cell_row = section["cells"][1]
	TEST_ASSERT_EQUAL(first_cell_row["occupant_ref"], REF(first), "Cell 1's row does not name its prisoner")

	// Per-prisoner settings, validated.
	var/ref = REF(first)
	panel.manage_outpost(home, operator, "prison_set", list("ref" = ref, "field" = "hunger", "value" = 20))
	TEST_ASSERT(abs(first.hunger - 20) < 0.01, "Setting hunger left it at [first.hunger]")
	panel.manage_outpost(home, operator, "prison_set", list("ref" = ref, "field" = "grime", "value" = "70"))
	TEST_ASSERT(abs(first.uniform_grime - 70) < 0.01, "Setting grime left it at [first.uniform_grime]")
	panel.manage_outpost(home, operator, "prison_set", list("ref" = ref, "field" = "health", "value" = 50))
	TEST_ASSERT(abs(first.health_factor() - 50) < 0.01, "Setting health left it at [first.health_factor()]")
	panel.manage_outpost(home, operator, "prison_set", list("ref" = ref, "field" = "sentence", "value" = 1000))
	TEST_ASSERT_EQUAL(first.sentence_left, 1000, "Setting the sentence left it at [first.sentence_left]")
	panel.manage_outpost(home, operator, "prison_set", list("ref" = ref, "field" = "hunger", "value" = "lots"))
	TEST_ASSERT(abs(first.hunger - 20) < 0.01 && panel.error, "A non-number setting was accepted")
	panel.manage_outpost(home, operator, "prison_set", list("ref" = ref, "field" = "happiness", "value" = 5))
	TEST_ASSERT(panel.error, "An unknown field was accepted")
	panel.manage_outpost(home, operator, "prison_set", list("ref" = "not a ref", "field" = "hunger", "value" = 5))
	TEST_ASSERT(panel.error, "A bad prisoner reference was accepted")
	panel.manage_outpost(home, operator, "prison_set", list("ref" = REF(operator), "field" = "hunger", "value" = 5))
	TEST_ASSERT(panel.error, "A non-prisoner reference was accepted")

	// Everyone at once.
	panel.manage_outpost(home, operator, "prison_all", list("what" = "starve"))
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in prison.prisoners)
		TEST_ASSERT(prisoner.hunger < 0.01, "Starve all left [prisoner] at [prisoner.hunger]")
	panel.manage_outpost(home, operator, "prison_all", list("what" = "feed"))
	panel.manage_outpost(home, operator, "prison_all", list("what" = "dirty"))
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in prison.prisoners)
		TEST_ASSERT(prisoner.hunger > 99.99 && prisoner.uniform_grime > 99.99, "Feed and dirty all missed [prisoner]")
	panel.manage_outpost(home, operator, "prison_all", list("what" = "clean"))
	panel.manage_outpost(home, operator, "prison_all", list("what" = "hurt"))
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in prison.prisoners)
		TEST_ASSERT(prisoner.uniform_grime < 0.01 && prisoner.health < prisoner.maxHealth && prisoner.stat != DEAD, "Clean and hurt all missed [prisoner] or killed them")
	panel.manage_outpost(home, operator, "prison_all", list("what" = "heal"))
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in prison.prisoners)
		TEST_ASSERT_EQUAL(prisoner.health, prisoner.maxHealth, "Heal all missed [prisoner]")
	panel.manage_outpost(home, operator, "prison_all", list("what" = "riot"))
	TEST_ASSERT(panel.error, "An unknown prisoner-wide action was accepted")

	// Time, money, mess, lights and power.
	var/mob/living/basic/outpost_prisoner/second = prison.prisoners[2]
	var/sentence_before = second.sentence_left
	panel.manage_outpost(home, operator, "prison_advance", list("minutes" = 2))
	TEST_ASSERT_EQUAL(sentence_before - second.sentence_left, 120, "Advancing 2 minutes took [sentence_before - second.sentence_left] s off a sentence")
	for(var/bad_minutes in list(0, 61, 1.5, "soon"))
		panel.manage_outpost(home, operator, "prison_advance", list("minutes" = bad_minutes))
		TEST_ASSERT(panel.error, "Advancing by [bad_minutes] minutes was accepted")
	var/balance = home.treasury.account_balance
	panel.manage_outpost(home, operator, "prison_pay_now", list())
	TEST_ASSERT(home.treasury.account_balance > balance, "Pay now paid nothing")
	prison.refresh_conditions()
	var/clean_before = prison.clean_score
	panel.manage_outpost(home, operator, "prison_mess", list())
	TEST_ASSERT(prison.clean_score < clean_before, "Spawning mess did not dirty the wing")
	panel.manage_outpost(home, operator, "prison_break_lights", list())
	TEST_ASSERT_EQUAL(prison.lit_score, 0, "Breaking the lights left the wing [prison.lit_score]% lit")
	panel.manage_outpost(home, operator, "prison_power", list("on" = 0))
	TEST_ASSERT_EQUAL(prison.powered_score, 0, "Cutting power left the wing powered")
	panel.manage_outpost(home, operator, "prison_power", list("on" = 2))
	TEST_ASSERT(panel.error && !prison.powered_score, "A bad power setting was accepted")
	panel.manage_outpost(home, operator, "prison_power", list("on" = 1))
	TEST_ASSERT_EQUAL(prison.powered_score, 100, "Restoring power left the wing unpowered")

	// Release, kill, remove.
	var/mob/living/basic/outpost_prisoner/third = prison.prisoners[3]
	var/mob/living/basic/outpost_prisoner/fourth = prison.prisoners[4]
	balance = home.treasury.account_balance
	panel.manage_outpost(home, operator, "prison_release", list("ref" = REF(first)))
	TEST_ASSERT_EQUAL(first.phase, "leaving", "Release did not beam the prisoner out")
	TEST_ASSERT(home.treasury.account_balance >= balance, "Release took money")
	panel.manage_outpost(home, operator, "prison_kill", list("ref" = REF(third)))
	TEST_ASSERT_EQUAL(third.stat, DEAD, "Kill did not kill the prisoner")
	panel.manage_outpost(home, operator, "prison_kill", list("ref" = REF(third)))
	TEST_ASSERT(panel.error, "Killing a body again was accepted")
	var/datum/outpost_prison_cell/fourth_cell = fourth.cell
	panel.manage_outpost(home, operator, "prison_remove", list("ref" = REF(fourth)))
	TEST_ASSERT(QDELETED(fourth), "Remove did not delete the prisoner")
	TEST_ASSERT_NULL(fourth_cell.occupant, "Remove did not free the cell")
	panel.manage_outpost(home, operator, "prison_release", list("ref" = REF(third)))
	TEST_ASSERT(panel.error, "Releasing a body was accepted")

	// Every successful action was logged once; failed ones were not.
	TEST_ASSERT_EQUAL(length(panel.operations), 23, "The manipulator logged [length(panel.operations)] prison actions: [jointext(panel.operations, "; ")]")
	settle_prison_air(home)
