/**
 * Outpost prison needs: hunger, uniforms and the serving hatch, eating, mess, blood and first aid,
 * the routine and dialogue, and what needs do to mood; arrivals, food by quality, sport, the
 * hatch as the only stockpile, the supply dispenser, and the prisoners' small routines (binning,
 * tidying, shared meals, sick calls, basketball with staff, the cycling thought bubble).
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with
 * the define named beside them. Prisons are driven with tick(seconds) with their own processing
 * stopped, never by waiting in real time, except for beams, which run on timers. Fixtures are
 * in voidcrew_outpost_prison_helpers.dm.
 */

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
	// full to empty hunger in 20 minutes (PRISONER_HUNGER_DECAY 5 a minute), grime 2.5 a minute at rest.
	prison.tick(60)
	var/hunger_rate = 100 - prisoner.hunger
	var/grime_rate = prisoner.uniform_grime
	TEST_ASSERT(abs(hunger_rate - 5) < 0.01, "A minute took [hunger_rate] hunger, not 5")
	TEST_ASSERT(abs(grime_rate - 2.5) < 0.01, "A minute added [grime_rate] grime, not 2.5")
	prisoner.adjust_needs(19 * 60)
	TEST_ASSERT(prisoner.hunger < 0.01, "Twenty minutes did not empty hunger ([prisoner.hunger])")
	prisoner.set_uniform_grime(0)
	prisoner.adjust_needs(40 * 60)
	TEST_ASSERT(prisoner.uniform_grime > 99.99, "Forty minutes did not ruin the uniform ([prisoner.uniform_grime])")

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
	// Staff can throw onto the counter through the shut office window; a prisoner's throw and an item
	// that isn't flying can't get through.
	var/obj/item/food/prison_ration/tossed = allocate(__IMPLIED_TYPE__, prison_spot(home, 5, 4))
	tossed.throwing = new /datum/thrownthing(tossed, hatch, get_dir(tossed, hatch), 5, 1, warden)
	TEST_ASSERT(staff_door.CanAllowThrough(tossed, staff_door.dir), "A member's throw did not get through the shut office window")
	tossed.throwing.thrower = WEAKREF(prisoner)
	TEST_ASSERT(!staff_door.CanAllowThrough(tossed, staff_door.dir), "A prisoner's throw got through the office window")
	QDEL_NULL(tossed.throwing)
	TEST_ASSERT(!staff_door.CanAllowThrough(tossed, staff_door.dir), "An item that was not thrown got through the office window")
	qdel(tossed)

	// Food they can reach: on the hatch, yes, through their own window door; on the office floor, no.
	prisoner.set_hunger(30)
	prisoner.set_uniform_grime(0)
	// Rations at 60 (PRISONER_FOOD_RATION). At mood 40 (50 after the meal's +10) wrappers stay on the
	// table, neither binned (PRISONER_BIN_MOOD 60) nor dropped (PRISONER_LITTER_MOOD 40).
	prisoner.set_mood(40)
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
	TEST_ASSERT(abs(prisoner.hunger - 90) < 0.01, "Eating a ration did not add 60 hunger (now [prisoner.hunger])") // PRISONER_FOOD_RATION
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
	TEST_ASSERT(prisoner.hunger > 89, "Eating unwatched did not add 60 hunger (now [prisoner.hunger])")
	TEST_ASSERT(locate(/obj/effect/decal/cleanable/food/crumbs) in yard_by_hatch, "Eating standing up left no crumbs")

	// Handing food over: eaten when hungry, refused when full.
	prisoner.set_hunger(20)
	var/obj/item/food/prison_ration/handed = allocate(__IMPLIED_TYPE__)
	warden.forceMove(prison_spot(home, 6, 7))
	warden.put_in_active_hand(handed)
	click_wrapper(warden, prisoner)
	TEST_ASSERT(QDELETED(handed), "The prisoner did not eat food handed to them")
	TEST_ASSERT(abs(prisoner.hunger - 80) < 0.01, "Hand feeding a ration did not add 60 hunger (now [prisoner.hunger])")
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

	// Thought bubbles: only when something needs attention; several needs take turns, every 4
	// seconds (PRISONER_BUBBLE_CYCLE), starting from the most urgent whenever the set changes.
	for(var/need in list("hungry", "dirty", "hurt", "riot", "experiment"))
		TEST_ASSERT_NOTNULL(outpost_prisoner_bubble_item(need), "The thought bubble has no item look for [need]")
	prisoner.set_hunger(10)
	prisoner.set_uniform_grime(90)
	prisoner.adjustBruteLoss(20)
	TEST_ASSERT_EQUAL(prisoner.bubble, "hungry", "Hunger did not come first among the needs")
	for(var/expected in list("hurt", "dirty", "hungry"))
		prisoner.bubble_clock += 4
		prisoner.update_bubble()
		TEST_ASSERT_EQUAL(prisoner.bubble, expected, "Four seconds on, the bubble showed [prisoner.bubble], not [expected]")
	prisoner.bubble_clock += 2
	prisoner.update_bubble()
	TEST_ASSERT_EQUAL(prisoner.bubble, "hungry", "The bubble changed before its 4 seconds were up")
	prisoner.experiment_subject = TRUE
	prisoner.update_bubble()
	TEST_ASSERT_EQUAL(prisoner.bubble, "experiment", "An experiment's subject did not show the syringe over their needs")
	prisoner.experiment_subject = FALSE
	prisoner.set_hunger(100)
	TEST_ASSERT_EQUAL(prisoner.bubble, "hurt", "The bubble did not start again at the injury when hunger was dealt with")
	prisoner.adjustBruteLoss(-20)
	TEST_ASSERT_EQUAL(prisoner.bubble, "dirty", "The bubble did not fall back to the dirty uniform")
	prisoner.set_uniform_grime(0)
	TEST_ASSERT_NULL(prisoner.bubble, "A well kept prisoner showed a bubble")
	prisoner.set_hunger(45)
	prisoner.set_uniform_grime(45)
	TEST_ASSERT_NULL(prisoner.bubble, "A prisoner above every threshold showed a bubble")

	// The bubble pops up now and then rather than staying: a need that has just come up pops it within
	// 3 seconds (PRISONER_BUBBLE_FRESH_DELAY), the next pop is 20 seconds or more away
	// (PRISONER_BUBBLE_GAP_MIN), and a need dealt with fades its bubble at once.
	prisoner.set_hunger(10)
	if(!prisoner.popped_bubble)
		TEST_ASSERT(prisoner.bubble_next_pop <= world.time + 3 SECONDS, "A new need did not bring the bubble forward")
		prisoner.bubble_next_pop = world.time
		prisoner.update_bubble()
	TEST_ASSERT_EQUAL(prisoner.popped_bubble, "hungry", "The bubble did not pop up when it was due")
	TEST_ASSERT(prisoner.thought in prisoner.vis_contents, "The popped bubble is not drawn")
	TEST_ASSERT(prisoner.bubble_next_pop >= world.time + 20 SECONDS, "The next pop is under 20 seconds away")
	prisoner.update_bubble()
	TEST_ASSERT_EQUAL(prisoner.popped_bubble, "hungry", "The bubble popped again while it was up")
	prisoner.set_hunger(100)
	TEST_ASSERT_NULL(prisoner.popped_bubble, "The bubble stayed up after the need was dealt with")
	prisoner.end_bubble()
	TEST_ASSERT(!(prisoner.thought in prisoner.vis_contents), "The faded bubble was not taken down")
	prisoner.set_hunger(45)

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
	var/mess_before = prison.mess_load
	var/obj/item/storage/toolbox/toolbox = allocate(__IMPLIED_TYPE__)
	warden.put_in_active_hand(toolbox)
	warden.set_combat_mode(TRUE)
	click_wrapper(warden, prisoner)
	warden.set_combat_mode(FALSE)
	TEST_ASSERT(prisoner.health < 100, "The toolbox did not hurt the prisoner")
	TEST_ASSERT(locate(/obj/effect/decal/cleanable/blood) in prison_spot(home, 10, 8), "A brute hit left no blood on the floor")
	prison.refresh_conditions()
	// Counted in the mess load; Clean itself only drops past PRISON_MESS_FREE units per 100 floor tiles.
	TEST_ASSERT(prison.mess_load > mess_before, "Blood on the floor did not count as mess")
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
		// The extras' pastimes keep their lines in their own dialogue files (outpost_prison_extras.dm).
		if(context)
			TEST_ASSERT(islist(outpost_prisoner_context_lines(context)), "[activity_type] speaks in a context no dialogue file has: [context]")

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

// ===== WHAT NEEDS DO TO MOOD =====

/datum/unit_test/voidcrew_outpost_prison_mood_needs
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_mood_needs/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("moodneedsowner")
	TEST_ASSERT_NOTNULL(home, "The needs mood test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = trouble_prisoner(prison, prison_spot(home, 8, 8))
	TEST_ASSERT(abs(prison.conditions_score() - 100) < 0.01, "The mood test wing is not in perfect condition")

	// Per minute: a well kept prisoner in a wing with every condition at 80+ gains 2.
	TEST_ASSERT(drift_is(prisoner, 2), "A well kept prisoner drifts [prisoner.mood_drift_per_minute()], not +2")
	prisoner.set_hunger(30)
	TEST_ASSERT(drift_is(prisoner, 2 - 3), "Hungry drifts [prisoner.mood_drift_per_minute()], not -1") // PRISONER_MOOD_HUNGRY
	prisoner.set_hunger(10)
	TEST_ASSERT(drift_is(prisoner, 2 - 8), "Starving drifts [prisoner.mood_drift_per_minute()], not -6") // PRISONER_MOOD_STARVING
	prisoner.set_hunger(100)
	prisoner.set_uniform_grime(60)
	TEST_ASSERT(drift_is(prisoner, 2 - 2), "A dirty uniform drifts [prisoner.mood_drift_per_minute()], not 0") // PRISONER_MOOD_DIRTY
	prisoner.set_uniform_grime(90)
	TEST_ASSERT(drift_is(prisoner, 2 - 5), "A filthy uniform drifts [prisoner.mood_drift_per_minute()], not -3") // PRISONER_MOOD_FILTHY
	prisoner.set_uniform_grime(0)
	// Injuries cost mood only below 75% health (PRISONER_HURT_MOOD_BELOW): 8 x (75 - health) / 75.
	prisoner.adjustBruteLoss(20)
	TEST_ASSERT(drift_is(prisoner, 2), "80% health drifts [prisoner.mood_drift_per_minute()], not +2")
	prisoner.adjustBruteLoss(30)
	TEST_ASSERT(drift_is(prisoner, 2 - 8 * 25 / 75), "Half health drifts [prisoner.mood_drift_per_minute()], not [2 - 8 * 25 / 75]") // PRISONER_MOOD_HURT
	prisoner.adjustBruteLoss(-50)

	// Instant changes: a meal +10, a clean uniform +8, treatment +8.
	prisoner.set_mood(40)
	prisoner.set_hunger(20)
	var/obj/item/food/prison_ration/meal = new(prison_spot(home, 8, 8))
	prisoner.finish_meal(meal, prison_spot(home, 8, 8), null)
	TEST_ASSERT(abs(prisoner.mood - 50) < 0.01, "A meal left mood at [prisoner.mood], not 50") // PRISONER_MOOD_FED
	prisoner.set_uniform_grime(80)
	var/obj/item/clothing/under/rank/prisoner/outpost/fresh = new(prison_spot(home, 8, 8))
	prisoner.swap_uniform(fresh, prison_spot(home, 8, 8))
	TEST_ASSERT(abs(prisoner.mood - 58) < 0.01, "A clean uniform left mood at [prisoner.mood], not 58") // PRISONER_MOOD_CLEAN_UNIFORM
	prisoner.adjustBruteLoss(30)
	COOLDOWN_START(prisoner, treatment_window, 20 SECONDS)
	prisoner.adjustBruteLoss(-30)
	TEST_ASSERT(abs(prisoner.mood - 66) < 0.01, "Treatment left mood at [prisoner.mood], not 66") // PRISONER_MOOD_TREATED
	settle_prison_air(home)

// ===== HELPERS FOR THE TESTS BELOW =====

/// Clears everything off a serving hatch and returns how many items it holds when empty
/datum/unit_test/voidcrew_outpost_management/proc/clear_hatch(obj/structure/table/reinforced/prison_hatch/hatch)
	for(var/obj/item/thing in hatch.loc)
		qdel(thing)
	return hatch.room_left()

/// Puts `count` rations on a serving hatch, bypassing its capacity check
/datum/unit_test/voidcrew_outpost_management/proc/stock_hatch(obj/structure/table/reinforced/prison_hatch/hatch, count)
	for(var/i in 1 to count)
		new /obj/item/food/prison_ration(hatch.loc)

/datum/unit_test/voidcrew_outpost_management/proc/count_on(turf/tile, item_type)
	var/count = 0
	for(var/obj/item/thing in tile)
		if(istype(thing, item_type))
			count++
	return count

// ===== ARRIVALS, HUNGER, GRIME, SPORT AND FOOD =====

/datum/unit_test/voidcrew_outpost_prison_arrivals_food
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_arrivals_food/proc/present(mob/living/basic/outpost_prisoner/prisoner)
	return prisoner.phase == "present"

/datum/unit_test/voidcrew_outpost_prison_arrivals_food/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("arrivalowner")
	TEST_ASSERT_NOTNULL(home, "The arrivals test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, prison_spot(home, 8, 8))

	// Arrivals, 200 of them: hunger 35-75, a third in a stained uniform (55-70 grime, else 0-15), and a
	// fifth roughed up to 60-85% health (PRISONER_ARRIVAL_*, _STAINED_*, _HURT_ARRIVAL_*).
	var/stained = 0
	var/hurt = 0
	for(var/i in 1 to 200)
		prisoner.roll_arrival()
		TEST_ASSERT(prisoner.hunger >= 35 && prisoner.hunger <= 75, "An arrival came in at [prisoner.hunger] hunger")
		if(prisoner.arrived_stained)
			stained++
			TEST_ASSERT(prisoner.uniform_grime >= 55 && prisoner.uniform_grime <= 70, "A stained arrival had [prisoner.uniform_grime] grime")
		else
			TEST_ASSERT(prisoner.uniform_grime >= 0 && prisoner.uniform_grime <= 15, "An ordinary arrival had [prisoner.uniform_grime] grime")
		if(prisoner.arrival_brute)
			hurt++
			TEST_ASSERT(prisoner.arrival_brute >= 15 && prisoner.arrival_brute <= 40, "A roughed-up arrival carried [prisoner.arrival_brute] brute")
	TEST_ASSERT(stained >= 45 && stained <= 95, "[stained] of 200 arrivals came in stained, not about 70")
	TEST_ASSERT(hurt >= 20 && hurt <= 60, "[hurt] of 200 arrivals came in hurt, not about 40")
	// The injury lands as they beam in, with no attacker: no blood, and a hurt bubble.
	prisoner.roll_arrival()
	prisoner.arrival_brute = 25
	prisoner.beam_in()
	TEST_ASSERT_EQUAL(prisoner.health, 75, "Beaming in roughed up left [prisoner.health] health, not 75")
	TEST_ASSERT(prisoner.arrived_hurt, "A roughed-up arrival was not marked hurt")
	TEST_ASSERT_NULL(locate(/obj/effect/decal/cleanable/blood) in get_turf(prisoner), "A transfer injury bled on the floor")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(present), prisoner), 6 SECONDS), "The arrival never finished beaming in")
	prisoner.set_hunger(100)
	prisoner.set_uniform_grime(0)
	TEST_ASSERT_EQUAL(prisoner.bubble, "hurt", "A roughed-up arrival did not show the hurt bubble")
	prisoner.adjustBruteLoss(-25)

	// Hunger 5 a minute (PRISONER_HUNGER_DECAY), paused while well fed.
	prisoner.adjust_needs(60)
	TEST_ASSERT(abs(prisoner.hunger - 95) < 0.01, "A minute took [100 - prisoner.hunger] hunger, not 5")
	prisoner.well_fed_left = 30
	prisoner.adjust_needs(60)
	TEST_ASSERT(abs(prisoner.hunger - 92.5) < 0.01, "Thirty seconds well fed still took hunger (now [prisoner.hunger])")
	TEST_ASSERT_EQUAL(prisoner.well_fed_left, 0, "Well fed did not run out")

	// Fed and clean fall to nothing at starving (15) and filthy (80).
	var/list/fed_points = list("40" = 100, "27.5" = 50, "15" = 0, "5" = 0, "90" = 100)
	for(var/point in fed_points)
		prisoner.set_hunger(text2num(point))
		TEST_ASSERT(abs(prisoner.fed_factor() - fed_points[point]) < 0.01, "Hunger [point] gave fed [prisoner.fed_factor()], not [fed_points[point]]")
	var/list/clean_points = list("49" = 100, "65" = 50, "80" = 0, "95" = 0)
	for(var/point in clean_points)
		prisoner.set_uniform_grime(text2num(point))
		TEST_ASSERT(abs(prisoner.clean_factor() - clean_points[point]) < 0.01, "Grime [point] gave clean [prisoner.clean_factor()], not [clean_points[point]]")
	prisoner.set_hunger(100)
	prisoner.set_uniform_grime(0)

	// Sport: three times the grime (PRISONER_GRIME_SPORT_MULT) at basketball or a workout, not pacing.
	// At 45% health they play carefully, so no injury gets in the way here (PRISONER_SPORT_INJURY_ABOVE).
	prisoner.adjustBruteLoss(55)
	var/datum/prisoner_activity/basketball/game = new(prisoner)
	game.started = TRUE
	prisoner.activity = game
	prisoner.adjust_needs(60)
	TEST_ASSERT(abs(prisoner.uniform_grime - 7.5) < 0.01, "A minute of basketball added [prisoner.uniform_grime] grime, not 7.5")
	prisoner.end_activity(cancel_ai = FALSE)
	var/datum/prisoner_activity/pace/walk = new(prisoner)
	walk.started = TRUE
	prisoner.activity = walk
	prisoner.set_uniform_grime(0)
	prisoner.adjust_needs(60)
	TEST_ASSERT(abs(prisoner.uniform_grime - 2.5) < 0.01, "A minute of pacing added [prisoner.uniform_grime] grime, not 2.5")
	walk.exercising = TRUE
	prisoner.set_uniform_grime(0)
	prisoner.adjust_needs(60)
	TEST_ASSERT(abs(prisoner.uniform_grime - 7.5) < 0.01, "A minute of working out added [prisoner.uniform_grime] grime, not 7.5")
	TEST_ASSERT(!prisoner.sport_injury(), "A badly hurt prisoner was injured at sport")
	// A sport injury: 8-15 brute (PRISONER_SPORT_INJURY_MIN/_MAX), no blood, and they stop.
	prisoner.adjustBruteLoss(-55)
	TEST_ASSERT(prisoner.sport_injury(), "A healthy prisoner working out could not be injured")
	TEST_ASSERT(prisoner.health >= 85 && prisoner.health <= 92, "A sport injury left [prisoner.health] health")
	TEST_ASSERT_NULL(prisoner.activity, "The injured prisoner kept working out")
	TEST_ASSERT_NULL(locate(/obj/effect/decal/cleanable/blood) in get_turf(prisoner), "A sport injury bled on the floor")
	prisoner.adjustBruteLoss(-prisoner.getBruteLoss())
	prisoner.set_uniform_grime(0)

	// Food by quality: the prison ration, cooked food, snacks and junk food, and poor food.
	var/list/tiers = list(
		/obj/item/food/prison_ration = "ration",
		/obj/item/food/burger/plain = "cooked",
		/obj/item/food/donkpocket = "cooked",
		/obj/item/food/chips = "snack",
		/obj/item/food/candy = "snack",
		/obj/item/food/breadslice/plain = "snack",
		/obj/item/food/meat/slab = "poor",
		/obj/item/food/grown/potato = "poor",
		/obj/item/food/badrecipe = "poor",
	)
	var/turf/table = prison_spot(home, 5, 9)
	for(var/food_type in tiers)
		var/obj/item/food/sample = allocate(food_type, table)
		TEST_ASSERT_EQUAL(outpost_prisoner_food_tier(sample), tiers[food_type], "[food_type] counted as [outpost_prisoner_food_tier(sample)] food")
		qdel(sample)
	// Hunger and mood: ration 60/+10, cooked 60/+15 and 8 minutes well fed, snack 35/+5, poor 20/+0.
	var/list/values = list(
		/obj/item/food/prison_ration = list(60, 10, 0),
		/obj/item/food/burger/plain = list(60, 15, 480),
		/obj/item/food/chips = list(35, 5, 0),
		/obj/item/food/meat/slab = list(20, 0, 0),
	)
	prisoner.set_mood(40)
	for(var/food_type in values)
		var/list/expected = values[food_type]
		prisoner.set_hunger(10)
		prisoner.set_mood(40)
		prisoner.well_fed_left = 0
		var/obj/item/food/meal = allocate(food_type, get_turf(prisoner))
		prisoner.finish_meal(meal, get_turf(prisoner), null)
		TEST_ASSERT(abs(prisoner.hunger - (10 + expected[1])) < 0.01, "[food_type] left hunger at [prisoner.hunger], not [10 + expected[1]]")
		TEST_ASSERT(abs(prisoner.mood - (40 + expected[2])) < 0.01, "[food_type] left mood at [prisoner.mood], not [40 + expected[2]]")
		TEST_ASSERT_EQUAL(prisoner.well_fed_left, expected[3], "[food_type] left them well fed for [prisoner.well_fed_left] seconds")
	// Well fed after cooked food: they don't go looking for food, and refuse it by hand.
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 9, 8), "arrivalowner")
	prisoner.set_hunger(20)
	prisoner.well_fed_left = 480
	TEST_ASSERT(!prisoner.wants_food(), "A well fed prisoner went looking for food")
	var/obj/item/food/prison_ration/refused = allocate(__IMPLIED_TYPE__)
	warden.put_in_active_hand(refused)
	click_wrapper(warden, prisoner)
	TEST_ASSERT(!QDELETED(refused) && warden.is_holding(refused), "A well fed prisoner ate a ration by hand")
	// By hand the tiers hold too: a cooked meal fed by hand keeps them full.
	prisoner.well_fed_left = 0
	warden.drop_all_held_items()
	var/obj/item/food/burger/plain/burger = allocate(__IMPLIED_TYPE__)
	warden.put_in_active_hand(burger)
	click_wrapper(warden, prisoner)
	TEST_ASSERT(QDELETED(burger), "The prisoner did not eat a burger handed to them")
	TEST_ASSERT(abs(prisoner.hunger - 80) < 0.01, "A burger by hand left hunger at [prisoner.hunger], not 80")
	TEST_ASSERT_EQUAL(prisoner.well_fed_left, 480, "A burger by hand did not keep them full")
	TEST_ASSERT_EQUAL(prisoner.last_carer_ref?.resolve(), warden, "Feeding by hand was not noted")
	settle_prison_air(home)

// ===== THE SERVING HATCH: THE ONLY STOCKPILE =====

/datum/unit_test/voidcrew_outpost_prison_hatch
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_hatch/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("hatchowner")
	TEST_ASSERT_NOTNULL(home, "The hatch test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/turf/hatch_turf = prison_spot(home, 5, 6)
	var/turf/office_side = prison_spot(home, 5, 5)
	var/turf/yard_side = prison_spot(home, 5, 7)
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in hatch_turf
	var/obj/structure/table/reinforced/prison_hatch/east_hatch = locate() in prison_spot(home, 13, 6)
	TEST_ASSERT(hatch && east_hatch, "The serving hatches are not where the map puts them")
	var/capacity = clear_hatch(hatch)
	clear_hatch(east_hatch)
	// OUTPOST_PRISON_HATCH_CAPACITY, read off an empty hatch so a retune does not break the tests.
	TEST_ASSERT(capacity >= 6, "An empty hatch holds only [capacity] items")
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, yard_side)
	var/mob/living/carbon/human/warden = make_player(office_side, "hatchowner")

	// Supplies anywhere but a hatch are left alone, by the AI's eating (setup) and by an unwatched
	// prisoner helping themself (fend_for_self), food and uniforms alike.
	prisoner.set_hunger(30)
	prisoner.set_uniform_grime(90)
	var/obj/item/food/prison_ration/floor_food = allocate(__IMPLIED_TYPE__, prison_spot(home, 6, 7))
	var/obj/item/food/prison_ration/table_food = allocate(__IMPLIED_TYPE__, prison_spot(home, 5, 9))
	var/obj/item/clothing/under/rank/prisoner/outpost/floor_suit = allocate(__IMPLIED_TYPE__, prison_spot(home, 6, 7))
	prison.refresh_reach()
	TEST_ASSERT(prisoner.reachable[get_turf(floor_food)] && prisoner.reachable[get_turf(table_food)], "The test food is out of the prisoner's reach anyway")
	TEST_ASSERT_NULL(prison.find_supply(prisoner), "A prisoner went for food on the floor or a mess table")
	TEST_ASSERT_NULL(prison.find_supply(prisoner, TRUE), "A prisoner went for a uniform on the floor")
	var/datum/prisoner_activity/eat/meal = new(prisoner)
	TEST_ASSERT(!meal.setup(), "The AI set off to eat food that was not on a hatch")
	qdel(meal)
	var/datum/prisoner_activity/change/change = new(prisoner)
	TEST_ASSERT(!change.setup(), "The AI set off to change into a uniform that was not on a hatch")
	qdel(change)
	TEST_ASSERT_NOTEQUAL(prisoner.ai_controller.ai_status, AI_STATUS_ON, "The prisoner's AI runs in a world with no players")
	prison.tick(5)
	TEST_ASSERT(!QDELETED(floor_food) && !QDELETED(table_food), "An unwatched prisoner ate food off the floor or a table")
	TEST_ASSERT(abs(prisoner.uniform_grime - 90) < 1, "An unwatched prisoner changed into a uniform off the floor")
	// On the hatch it is theirs, for the AI and unwatched.
	var/obj/item/food/prison_ration/hatch_food = allocate(__IMPLIED_TYPE__, hatch_turf)
	meal = new(prisoner)
	TEST_ASSERT(meal.setup(), "The AI would not go for food on the hatch")
	qdel(meal)
	prison.tick(5)
	TEST_ASSERT(QDELETED(hatch_food), "An unwatched prisoner did not eat food on the hatch")
	qdel(floor_food)
	qdel(table_food)
	qdel(floor_suit)
	clear_hatch(hatch)

	// Capacity: by hand, the eleventh item is refused and stays in the hand.
	stock_hatch(hatch, capacity - 1)
	var/obj/item/clothing/under/rank/prisoner/outpost/fresh = new(hatch_turf)
	TEST_ASSERT_EQUAL(hatch.room_left(), 0, "A full hatch still had room")
	var/obj/item/food/prison_ration/extra = allocate(__IMPLIED_TYPE__)
	warden.put_in_active_hand(extra)
	TEST_ASSERT_EQUAL(hatch.table_place_act(warden, extra, list()), ITEM_INTERACT_BLOCKING, "A full hatch took another item")
	TEST_ASSERT(warden.is_holding(extra), "The refused item left the warden's hand")
	TEST_ASSERT_EQUAL(hatch.stock_count(), capacity, "The hatch holds [hatch.stock_count()] items after a refusal")
	// Dumped or thrown on, it slides back off where it came from.
	warden.dropItemToGround(extra)
	TEST_ASSERT_EQUAL(extra.loc, office_side, "The refused item was not dropped at the warden's feet")
	extra.forceMove(hatch_turf)
	TEST_ASSERT_EQUAL(extra.loc, office_side, "An item pushed onto a full hatch stayed on it")
	// A prisoner's swap on a full hatch goes through, one for one.
	prisoner.set_uniform_grime(90)
	prison.refresh_reach()
	TEST_ASSERT_EQUAL(prison.find_supply(prisoner, TRUE), fresh, "A dirty prisoner did not find the clean uniform on the full hatch")
	TEST_ASSERT(reach_until_ok(prisoner, fresh), "The prisoner could not reach the full hatch")
	TEST_ASSERT(prisoner.take_uniform(fresh), "A swap on a full hatch was refused")
	TEST_ASSERT(prisoner.uniform_grime < 0.01, "The swap did not leave the prisoner clean")
	var/obj/item/clothing/under/rank/prisoner/outpost/left = locate() in hatch_turf
	TEST_ASSERT(left && left.grime > 89, "The dirty uniform was not left on the hatch")
	TEST_ASSERT_EQUAL(hatch.stock_count(), capacity, "The swap changed the hatch's count to [hatch.stock_count()]")
	// A tray: as much as fits goes on, the rest stays on the tray.
	qdel(left)
	qdel(extra)
	var/obj/item/storage/bag/tray/tray = allocate(__IMPLIED_TYPE__)
	for(var/i in 1 to 3)
		new /obj/item/food/prison_ration(tray)
	warden.put_in_active_hand(tray)
	TEST_ASSERT_EQUAL(hatch.room_left(), 1, "The tray test hatch has the wrong room")
	TEST_ASSERT_EQUAL(hatch.tray_act(warden, tray), ITEM_INTERACT_SUCCESS, "A tray could not put anything on a hatch with room")
	TEST_ASSERT_EQUAL(hatch.stock_count(), capacity, "A tray overfilled or underfilled the hatch ([hatch.stock_count()])")
	TEST_ASSERT_EQUAL(length(tray.contents), 2, "The tray kept [length(tray.contents)] items, not the 2 that did not fit")
	clear_hatch(hatch)

	// Stock: meals, clean and dirty suits, capacity, and how long it lasts at 0.11 meals and 0.045
	// suits a prisoner-minute (OUTPOST_PRISON_MEAL_RATE / _SUIT_RATE).
	stock_hatch(hatch, 3)
	new /obj/item/clothing/under/rank/prisoner/outpost(hatch_turf)
	new /obj/item/clothing/under/rank/prisoner/outpost(prison_spot(home, 13, 6))
	var/obj/item/clothing/under/rank/prisoner/outpost/dirty = new(hatch_turf)
	dirty.set_grime(70)
	var/list/stock = prison.hatch_stock()
	TEST_ASSERT_EQUAL(stock["meals"], 3, "The stock counted [stock["meals"]] meals")
	TEST_ASSERT_EQUAL(stock["clean_suits"], 2, "The stock counted [stock["clean_suits"]] clean suits")
	TEST_ASSERT_EQUAL(stock["dirty_suits"], 1, "The stock counted [stock["dirty_suits"]] dirty suits")
	TEST_ASSERT_EQUAL(stock["capacity"], capacity * 2, "The stock capacity was [stock["capacity"]]")
	TEST_ASSERT_EQUAL(stock["lasts_minutes"], round(min(3 / 0.11, 2 / 0.045)), "One prisoner's stock lasts [stock["lasts_minutes"]] minutes")
	clear_hatch(hatch)
	clear_hatch(east_hatch)

	// Shortage: hungry with nothing on the hatches is a shortage, and the radio hears about it once.
	prisoner.set_hunger(30)
	prisoner.set_uniform_grime(0)
	prison.hatch_warning_left = 0
	prison.tick(5)
	TEST_ASSERT(prison.hatch_shortage(), "A hungry prisoner at empty hatches was not a shortage")
	TEST_ASSERT_EQUAL(prison.waiting_for_food, 1, "[prison.waiting_for_food] prisoners were counted waiting for food")
	TEST_ASSERT_EQUAL(prison.hatch_warning_text(), "Prison wing: the hatch is out of food and 1 prisoner is waiting.", "The warning read: [prison.hatch_warning_text()]")
	TEST_ASSERT(prison.hatch_warning_left > 590, "The empty hatch was not reported (or the next report is due in [prison.hatch_warning_left] s)")
	prison.tick(5)
	TEST_ASSERT(prison.hatch_warning_left > 580 && prison.hatch_warning_left < 600, "The radio report did not wait out its 10 minutes")
	prisoner.set_uniform_grime(90)
	prison.tick(5)
	TEST_ASSERT_EQUAL(prison.hatch_warning_text(), "Prison wing: the hatch is out of food and clean uniforms and 1 prisoner is waiting.", "The warning read: [prison.hatch_warning_text()]")
	stock_hatch(east_hatch, 1)
	new /obj/item/clothing/under/rank/prisoner/outpost(prison_spot(home, 13, 6))
	prison.refresh_reach()
	prison.tick(5)
	TEST_ASSERT(!prison.hatch_shortage(), "Food and a suit on the other hatch still read as a shortage")
	// Bolted in, they can't reach a hatch, so they are not waiting at one.
	clear_hatch(east_hatch)
	prisoner.set_hunger(30)
	prisoner.forceMove(prisoner.cell.arrival_turf())
	prison.toggle_cell_bolts(prisoner.cell.number, warden)
	prison.tick(5)
	TEST_ASSERT(!prison.hatch_shortage(), "A prisoner bolted in their cell counted as waiting at the hatch")
	prison.toggle_cell_bolts(prisoner.cell.number, warden)
	prisoner.forceMove(yard_side)
	prison.refresh_reach()

	// Stocking gets a call-out from a prisoner who wants it, and thanks from one waiting at the hatch.
	var/mob/living/basic/outpost_prisoner/waiting = prisoner
	var/mob/living/basic/outpost_prisoner/watcher = test_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/full = test_prisoner(prison, prison_spot(home, 7, 8))
	waiting.set_hunger(30)
	waiting.set_uniform_grime(0)
	watcher.set_hunger(30)
	full.set_hunger(100)
	var/datum/prisoner_activity/hatch_wait/wait = waiting.start_activity(new /datum/prisoner_activity/hatch_wait(waiting))
	wait.hatch_ref = WEAKREF(hatch)
	waiting.last_line = null
	COOLDOWN_RESET(waiting, thanks_cooldown)
	COOLDOWN_RESET(prison, hatch_call_cooldown)
	var/obj/item/food/prison_ration/stocked = new(hatch_turf)
	var/mob/living/basic/outpost_prisoner/crier = prison.on_hatch_stocked(hatch, list(stocked), warden)
	TEST_ASSERT_EQUAL(crier, watcher, "The call-out came from [crier || "nobody"], not the hungry prisoner watching")
	TEST_ASSERT(is_line_for(waiting.last_line, "thanks_food"), "The prisoner waiting at the hatch did not say thanks: [waiting.last_line]")
	TEST_ASSERT_EQUAL(waiting.last_carer_ref?.resolve(), warden, "The waiting prisoner did not note who stocked the hatch")
	TEST_ASSERT_NULL(prison.on_hatch_stocked(hatch, list(stocked), warden), "A second call-out came within 20 seconds") // OUTPOST_PRISON_HATCH_CALL_GAP
	// By hand, through the table: the call-out fires (its cooldown starts).
	COOLDOWN_RESET(prison, hatch_call_cooldown)
	var/obj/item/food/prison_ration/by_hand = allocate(__IMPLIED_TYPE__)
	warden.drop_all_held_items()
	warden.put_in_active_hand(by_hand)
	TEST_ASSERT_EQUAL(hatch.table_place_act(warden, by_hand, list()), ITEM_INTERACT_SUCCESS, "Putting a ration on a hatch with room failed")
	TEST_ASSERT(!COOLDOWN_FINISHED(prison, hatch_call_cooldown), "Stocking the hatch by hand drew no call-out")
	// A dirty uniform on the hatch is nothing to call about.
	COOLDOWN_RESET(prison, hatch_call_cooldown)
	var/obj/item/clothing/under/rank/prisoner/outpost/grubby = new(hatch_turf)
	grubby.set_grime(90)
	TEST_ASSERT_NULL(prison.on_hatch_stocked(hatch, list(grubby), warden), "A dirty uniform drew a call-out")
	waiting.end_activity(cancel_ai = FALSE)
	clear_hatch(hatch)

	// The admin fill: every hatch to capacity, mostly meals (OUTPOST_PRISON_FILL_MEAL_SHARE 0.7).
	prison.fill_hatches()
	stock = prison.hatch_stock()
	TEST_ASSERT_EQUAL(hatch.stock_count(), capacity, "The fill left the west hatch at [hatch.stock_count()]")
	TEST_ASSERT_EQUAL(east_hatch.stock_count(), capacity, "The fill left the east hatch at [east_hatch.stock_count()]")
	TEST_ASSERT_EQUAL(stock["meals"], 2 * round(capacity * 0.7, 1), "The fill put out [stock["meals"]] meals")
	TEST_ASSERT_EQUAL(stock["clean_suits"], 2 * (capacity - round(capacity * 0.7, 1)), "The fill put out [stock["clean_suits"]] clean suits")
	TEST_ASSERT_EQUAL(prison.fill_hatches(), 0, "Filling full hatches added more")
	clear_hatch(hatch)
	clear_hatch(east_hatch)
	settle_prison_air(home)

// ===== THE SUPPLY DISPENSER =====

/datum/unit_test/voidcrew_outpost_prison_dispenser
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_dispenser/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("dispenseowner")
	TEST_ASSERT_NOTNULL(home, "The dispenser test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/datum/bank_account/treasury = home.treasury
	var/obj/machinery/outpost_ration_dispenser/dispenser = locate() in prison_spot(home, 4, 5)
	TEST_ASSERT_NOTNULL(dispenser, "The supply dispenser is not where the map puts it")
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in prison_spot(home, 5, 6)
	var/obj/structure/table/reinforced/prison_hatch/east_hatch = locate() in prison_spot(home, 13, 6)
	var/capacity = clear_hatch(hatch)
	clear_hatch(east_hatch)
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 4, 4), "dispenseowner")
	var/mob/living/carbon/human/resident = make_player(prison_spot(home, 5, 4), "dispenseresident")
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 3, 4), "dispensevisitor")
	home.residents += resident.mind
	treasury.adjust_money(5000, "Prison test")
	var/ration_price = dispenser.price_of("ration")
	TEST_ASSERT_EQUAL(dispenser.price_of("round"), ration_price, "A served ration costs more than one from the hand")

	// Serve a round: four rations (OUTPOST_PRISON_SERVE_ROUND) onto the nearest hatch, billed per ration.
	var/start = treasury.account_balance
	TEST_ASSERT_NULL(dispenser.order(owner, "round"), "The owner could not serve a round")
	TEST_ASSERT_EQUAL(count_on(hatch.loc, /obj/item/food/prison_ration), 4, "A round put [count_on(hatch.loc, /obj/item/food/prison_ration)] rations on the nearest hatch")
	TEST_ASSERT_EQUAL(start - treasury.account_balance, 4 * ration_price, "A round of 4 cost [start - treasury.account_balance]")
	TEST_ASSERT_EQUAL(dispenser.order(owner, "round"), "busy", "The dispenser took an order inside its cooldown")
	// Past the nearest hatch's capacity, the rest go on the next.
	COOLDOWN_RESET(dispenser, dispense_cooldown)
	stock_hatch(hatch, capacity - 2 - 4)
	start = treasury.account_balance
	TEST_ASSERT_NULL(dispenser.order(owner, "round"), "A round onto a nearly full hatch failed")
	TEST_ASSERT_EQUAL(hatch.stock_count(), capacity, "The nearest hatch was not filled to capacity")
	TEST_ASSERT_EQUAL(count_on(east_hatch.loc, /obj/item/food/prison_ration), 2, "The rest of the round did not go on the other hatch")
	TEST_ASSERT_EQUAL(start - treasury.account_balance, 4 * ration_price, "The split round cost [start - treasury.account_balance]")
	// Full hatches: nothing served, nothing billed.
	COOLDOWN_RESET(dispenser, dispense_cooldown)
	stock_hatch(east_hatch, capacity - 2)
	start = treasury.account_balance
	TEST_ASSERT_EQUAL(dispenser.order(owner, "round"), "the hatches are full", "A round was served onto full hatches")
	TEST_ASSERT_EQUAL(treasury.account_balance, start, "Full hatches were billed")
	// Short of money: as many as it can pay for.
	clear_hatch(hatch)
	clear_hatch(east_hatch)
	COOLDOWN_RESET(dispenser, dispense_cooldown)
	treasury.adjust_money(-treasury.account_balance, "Prison test")
	treasury.adjust_money(round(2.5 * ration_price), "Prison test")
	TEST_ASSERT_NULL(dispenser.order(owner, "round"), "A round the treasury could half pay for failed")
	TEST_ASSERT_EQUAL(count_on(hatch.loc, /obj/item/food/prison_ration), 2, "A treasury with 2.5 rations' worth served [count_on(hatch.loc, /obj/item/food/prison_ration)]")
	TEST_ASSERT_EQUAL(treasury.account_balance, round(2.5 * ration_price) - 2 * ration_price, "The half-paid round billed the wrong amount")
	COOLDOWN_RESET(dispenser, dispense_cooldown)
	TEST_ASSERT_EQUAL(dispenser.order(owner, "bruise_pack"), "insufficient funds", "A bruise pack came out of an empty treasury")
	treasury.adjust_money(5000, "Prison test")
	clear_hatch(hatch)

	// A bruise pack (one use) and a clean uniform, into the hand.
	start = treasury.account_balance
	TEST_ASSERT_NULL(dispenser.order(owner, "bruise_pack"), "The owner could not order a bruise pack")
	var/obj/item/stack/medical/bruise_pack/pack = owner.is_holding_item_of_type(/obj/item/stack/medical/bruise_pack)
	TEST_ASSERT(pack && pack.amount == 1, "The bruise pack was not handed over as a single pack")
	TEST_ASSERT_EQUAL(start - treasury.account_balance, dispenser.price_of("bruise_pack"), "A bruise pack was billed wrong")
	owner.drop_all_held_items()
	COOLDOWN_RESET(dispenser, dispense_cooldown)
	start = treasury.account_balance
	TEST_ASSERT_NULL(dispenser.order(owner, "uniform"), "The owner could not order a uniform")
	var/obj/item/clothing/under/rank/prisoner/outpost/suit = owner.is_holding_item_of_type(/obj/item/clothing/under/rank/prisoner/outpost)
	TEST_ASSERT(suit && suit.grime < 0.01, "A clean prison uniform was not handed over")
	TEST_ASSERT_EQUAL(start - treasury.account_balance, dispenser.price_of("uniform"), "A uniform was billed wrong")
	TEST_ASSERT(dispenser.price_of("bruise_pack") > 0 && dispenser.price_of("uniform") > dispenser.price_of("bruise_pack"), "The dispenser's prices are off")
	owner.drop_all_held_items()

	// Who may order: never a visitor; residents up to 8 items per 10 minutes between them
	// (OUTPOST_PRISON_RESIDENT_ORDERS / _WINDOW); managers as often as the cooldown allows.
	COOLDOWN_RESET(dispenser, dispense_cooldown)
	TEST_ASSERT_EQUAL(dispenser.order(visitor, "ration"), "residents only", "A visitor billed the treasury")
	TEST_ASSERT_NULL(dispenser.order(resident, "round"), "A resident could not serve a round")
	COOLDOWN_RESET(dispenser, dispense_cooldown)
	TEST_ASSERT_NULL(dispenser.order(resident, "round"), "A resident could not serve a second round")
	TEST_ASSERT_EQUAL(count_on(hatch.loc, /obj/item/food/prison_ration), 8, "Two resident rounds put out [count_on(hatch.loc, /obj/item/food/prison_ration)] rations")
	COOLDOWN_RESET(dispenser, dispense_cooldown)
	TEST_ASSERT_EQUAL(dispenser.order(resident, "ration"), "restocking", "A resident ordered a ninth item inside ten minutes")
	TEST_ASSERT_NULL(dispenser.order(owner, "ration"), "The owner was held to the residents' limit")
	COOLDOWN_RESET(dispenser, dispense_cooldown)
	for(var/i in 1 to length(prison.resident_orders))
		prison.resident_orders[i] -= 6000 // OUTPOST_PRISON_RESIDENT_ORDER_WINDOW
	TEST_ASSERT_NULL(dispenser.order(resident, "ration"), "A resident could not order once the window had passed")
	TEST_ASSERT_EQUAL(prison.resident_orders_left(), 7, "The window did not start again after it passed")
	// Unpowered, nothing.
	COOLDOWN_RESET(dispenser, dispense_cooldown)
	dispenser.set_machine_stat(dispenser.machine_stat | NOPOWER)
	TEST_ASSERT_EQUAL(dispenser.order(owner, "ration"), "no power", "An unpowered dispenser took an order")
	dispenser.set_machine_stat(dispenser.machine_stat & ~NOPOWER)
	clear_hatch(hatch)
	settle_prison_air(home)

// ===== THE PRISONERS' SMALL ROUTINES =====

/datum/unit_test/voidcrew_outpost_prison_liveliness
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_liveliness/proc/holds(mob/living/basic/outpost_prisoner/prisoner, obj/item/thing)
	return thing.loc == prisoner

/datum/unit_test/voidcrew_outpost_prison_liveliness/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("livelyowner")
	TEST_ASSERT_NOTNULL(home, "The liveliness test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/turf/table = prison_spot(home, 5, 9)
	var/turf/seat = prison_spot(home, 5, 10)
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, prison_spot(home, 8, 8))
	// The map's own bin (if any) moves aside for a known one.
	for(var/turf/tile as anything in prison.wing_turfs())
		for(var/obj/structure/closet/crate/bin/map_bin in tile)
			qdel(map_bin)
	var/obj/structure/closet/crate/bin/bin = allocate(/obj/structure/closet/crate/bin, prison_spot(home, 8, 10))
	prison.refresh_reach()
	TEST_ASSERT_EQUAL(prison.find_bin(prisoner), bin, "The prisoner cannot find the yard bin")

	// Binning: at mood 60+ (PRISONER_BIN_MOOD) a wrapper is often meant for the bin (70%,
	// PRISONER_BIN_CHANCE); below it never; below 40 (PRISONER_LITTER_MOOD) it goes on the floor.
	var/meant_for_bin = 0
	var/crumbs = 0
	prisoner.set_mood(80)
	for(var/obj/effect/decal/cleanable/food/crumbs/old_crumb in seat)
		qdel(old_crumb)
	for(var/i in 1 to 40)
		var/obj/item/food/prison_ration/sample = new(null)
		var/obj/item/trash = prisoner.leave_meal_mess(sample, seat, table)
		qdel(sample)
		if(trash)
			meant_for_bin++
			TEST_ASSERT_EQUAL(trash.loc, table, "A wrapper meant for the bin was not left on the table first")
		// Crumbs on one tile merge into one decal, so count them meal by meal.
		var/obj/effect/decal/cleanable/food/crumbs/crumb = locate() in seat
		if(crumb)
			crumbs++
			qdel(crumb)
	TEST_ASSERT(meant_for_bin >= 10 && meant_for_bin <= 36, "A content prisoner meant [meant_for_bin] of 40 wrappers for the bin, not about 24")
	TEST_ASSERT(crumbs >= 5 && crumbs <= 35, "Forty meals at a table left crumbs [crumbs] times, not about 20") // PRISONER_TABLE_CRUMB_CHANCE 50
	prisoner.set_mood(59)
	for(var/i in 1 to 20)
		var/obj/item/food/prison_ration/sample = new(null)
		TEST_ASSERT_NULL(prisoner.leave_meal_mess(sample, seat, table), "A prisoner at mood 59 meant a wrapper for the bin")
		qdel(sample)
	for(var/obj/item/trash/left_out in table)
		qdel(left_out)
	prisoner.set_mood(30)
	var/on_floor = 0
	for(var/i in 1 to 20)
		var/obj/item/food/prison_ration/sample = new(null)
		prisoner.leave_meal_mess(sample, seat, table)
		qdel(sample)
	TEST_ASSERT_NULL(locate(/obj/item/trash) in table, "An unhappy prisoner left a wrapper on the table")
	for(var/obj/item/trash/dropped in seat)
		on_floor++
		qdel(dropped)
	TEST_ASSERT(on_floor >= 5, "An unhappy prisoner dropped [on_floor] of 20 wrappers on the floor")
	for(var/obj/effect/decal/cleanable/food/crumbs/crumb in seat)
		qdel(crumb)
	// A full bin: they say so and leave it.
	bin.storage_capacity = length(bin.contents)
	prisoner.set_mood(80)
	for(var/i in 1 to 20)
		var/obj/item/food/prison_ration/sample = new(null)
		TEST_ASSERT_NULL(prisoner.leave_meal_mess(sample, seat, table), "A prisoner meant a wrapper for a full bin")
		qdel(sample)
	bin.storage_capacity = initial(bin.storage_capacity)
	for(var/obj/item/trash/left_out in table)
		qdel(left_out)
	for(var/obj/effect/decal/cleanable/food/crumbs/crumb in seat)
		qdel(crumb)
	// After a meal: the wrapper carried to the bin and put in.
	var/datum/prisoner_activity/eat/meal = prisoner.start_activity(new /datum/prisoner_activity/eat(prisoner))
	var/obj/item/trash/wrapper = new /obj/item/trash/fleet_ration(table)
	TEST_ASSERT_EQUAL(meal.carry_to_bin(wrapper), 2, "The prisoner did not set off for the bin") // ACTIVITY_MOVE
	TEST_ASSERT_EQUAL(prisoner.held_item, wrapper, "The prisoner is not carrying the wrapper")
	TEST_ASSERT(get_dist(meal.spot, bin) <= 1 && prisoner.walkable[meal.spot], "The prisoner is not headed to the bin")
	prisoner.forceMove(meal.spot)
	meal.arrive()
	TEST_ASSERT_EQUAL(wrapper.loc, bin, "The wrapper did not go in the bin")
	TEST_ASSERT_EQUAL(meal.tick(1), 1, "The meal did not end after binning") // ACTIVITY_DONE
	prisoner.end_activity(cancel_ai = FALSE)
	// Unwatched, straight in.
	var/obj/item/trash/raisins/unwatched = new(prisoner.loc)
	TEST_ASSERT(prisoner.bin_litter(unwatched), "An unwatched prisoner could not bin a wrapper")
	TEST_ASSERT_EQUAL(unwatched.loc, bin, "The unwatched wrapper did not go in the bin")

	// Tidying: at mood 75+ (PRISONER_TIDY_MOOD), one piece of litter to the bin, then not again for 5 minutes.
	prisoner.forceMove(prison_spot(home, 8, 8))
	prison.refresh_reach()
	var/obj/item/trash/chips/litter = new(prison_spot(home, 11, 7))
	prisoner.set_mood(74)
	var/datum/prisoner_activity/tidy/tidy = new(prisoner)
	TEST_ASSERT_EQUAL(tidy.get_weight(), 0, "A prisoner at mood 74 felt like tidying")
	prisoner.set_mood(80)
	TEST_ASSERT(tidy.get_weight() > 0, "A prisoner at mood 80 did not feel like tidying")
	TEST_ASSERT(tidy.setup(), "Tidying could not be set up with litter and a bin in the yard")
	TEST_ASSERT_EQUAL(tidy.spot, get_turf(litter), "Tidying did not go for the litter")
	prisoner.start_activity(tidy)
	TEST_ASSERT_EQUAL(drive_activity(prisoner, tidy), 1, "Tidying never finished")
	TEST_ASSERT_EQUAL(litter.loc, bin, "The litter did not end up in the bin")
	TEST_ASSERT_NULL(prisoner.held_item, "The prisoner kept hold of something after tidying")
	var/datum/prisoner_activity/tidy/again = new(prisoner)
	TEST_ASSERT_EQUAL(again.get_weight(), 0, "A prisoner felt like tidying again straight away")
	qdel(again)

	// Shared meals: three at the tables within a minute each cheer up by 3, once (PRISONER_MOOD_SHARED_MEAL).
	var/mob/living/basic/outpost_prisoner/second = test_prisoner(prison, prison_spot(home, 4, 10))
	var/mob/living/basic/outpost_prisoner/third = test_prisoner(prison, prison_spot(home, 6, 10))
	var/mob/living/basic/outpost_prisoner/fourth = test_prisoner(prison, prison_spot(home, 4, 8))
	set_moods(list(prisoner, second, third, fourth), 50)
	TEST_ASSERT_EQUAL(length(prison.note_table_meal(prisoner)), 0, "One prisoner eating alone made a shared meal")
	TEST_ASSERT_EQUAL(length(prison.note_table_meal(second)), 0, "Two prisoners eating made a shared meal")
	var/list/lifted = prison.note_table_meal(third)
	TEST_ASSERT_EQUAL(length(lifted), 3, "Three prisoners at the tables lifted [length(lifted)]")
	for(var/mob/living/basic/outpost_prisoner/diner as anything in list(prisoner, second, third))
		TEST_ASSERT(abs(diner.mood - 53) < 0.01, "A shared meal left [diner] at [diner.mood], not 53")
	lifted = prison.note_table_meal(fourth)
	TEST_ASSERT(length(lifted) == 1 && lifted[1] == fourth, "The fourth at the table did not get the lift alone")
	TEST_ASSERT(abs(prisoner.mood - 53) < 0.01, "A shared meal lifted the same prisoner twice")

	// Sick call: a hurt prisoner goes over to a member of staff holding dressings in the yard, asks,
	// and waits until treated.
	var/mob/living/carbon/human/medic = make_player(prison_spot(home, 12, 8), "livelyowner")
	prisoner.forceMove(prison_spot(home, 8, 8))
	prison.refresh_reach()
	prisoner.adjustBruteLoss(30)
	TEST_ASSERT(!prisoner.start_sick_call(), "A hurt prisoner asked for treatment from someone holding no dressings")
	var/obj/item/stack/medical/bruise_pack/dressing = allocate(__IMPLIED_TYPE__)
	medic.put_in_active_hand(dressing)
	TEST_ASSERT(prisoner.start_sick_call(), "A hurt prisoner did not go to someone holding a bruise pack")
	var/datum/prisoner_activity/sick_call/asking = prisoner.activity
	TEST_ASSERT(istype(asking), "The sick call is not their activity")
	TEST_ASSERT(get_dist(asking.spot, medic) <= 1, "The sick call did not head for the medic")
	prisoner.forceMove(asking.spot)
	asking.arrive()
	TEST_ASSERT_EQUAL(asking.tick(1), 0, "The sick call ended before treatment") // ACTIVITY_CONTINUE
	TEST_ASSERT(asking.asked, "The prisoner did not ask for treatment")
	TEST_ASSERT_EQUAL(prisoner.dir, get_dir(prisoner, medic), "The prisoner is not facing the medic")
	prisoner.adjustBruteLoss(-30)
	TEST_ASSERT_EQUAL(asking.tick(1), 1, "The sick call went on after treatment") // ACTIVITY_DONE
	prisoner.end_activity(cancel_ai = FALSE)
	// Not again straight away, not for a scrape, and not for staff out of the cell block.
	prisoner.adjustBruteLoss(30)
	TEST_ASSERT(!prisoner.start_sick_call(), "A prisoner asked for the medic again straight away")
	COOLDOWN_RESET(prisoner, sick_call_cooldown)
	medic.forceMove(prison_spot(home, 12, 4))
	TEST_ASSERT(!prisoner.start_sick_call(), "A prisoner asked staff in the office for treatment")
	medic.forceMove(prison_spot(home, 12, 8))
	prisoner.adjustBruteLoss(-25)
	TEST_ASSERT(!prisoner.start_sick_call(), "A prisoner at 95% health asked for treatment")
	prisoner.adjustBruteLoss(-prisoner.getBruteLoss())
	medic.drop_all_held_items()

	// Basketball with staff: a member sinking a shot while two play cheers them up by 10, once per
	// 5 minutes (PRISONER_MOOD_STAFF_BASKET, OUTPOST_PRISON_STAFF_BASKET_GAP).
	var/obj/structure/hoop/hoop = locate() in prison_spot(home, 9, 11)
	TEST_ASSERT_NOTNULL(hoop, "The hoop is not where the map puts it")
	set_moods(list(prisoner, second), 50)
	prisoner.start_activity(new /datum/prisoner_activity/basketball(prisoner))
	TEST_ASSERT(!prison.staff_basket(medic, hoop), "A basket with one prisoner playing cheered them")
	second.start_activity(new /datum/prisoner_activity/basketball(second))
	TEST_ASSERT(!prison.staff_basket(third, hoop), "A prisoner's own basket counted as staff's")
	TEST_ASSERT(prison.staff_basket(medic, hoop), "A staff basket with two playing did not count")
	TEST_ASSERT(abs(prisoner.mood - 60) < 0.01 && abs(second.mood - 60) < 0.01, "A staff basket left the players at [prisoner.mood] and [second.mood], not 60")
	TEST_ASSERT(!prison.staff_basket(medic, hoop), "A second staff basket inside 5 minutes counted")
	second.end_activity(cancel_ai = FALSE)
	prisoner.end_activity(cancel_ai = FALSE)
	// A ball thrown to a playing prisoner is caught and the game goes on.
	var/obj/item/toy/basketball/ball = locate() in prison_spot(home, 9, 9)
	TEST_ASSERT_NOTNULL(ball, "The ball is not where the map puts it")
	prisoner.forceMove(prison_spot(home, 9, 8))
	prison.refresh_prisoner_reach(prisoner)
	var/datum/prisoner_activity/basketball/game = prisoner.start_activity(new /datum/prisoner_activity/basketball(prisoner))
	TEST_ASSERT(game.setup(), "Basketball could not be set up for the catch")
	game.arrive()
	medic.forceMove(prison_spot(home, 12, 8))
	medic.put_in_active_hand(ball)
	TEST_ASSERT(game.tick(1) != 1, "The game ended as soon as staff picked up the ball") // ACTIVITY_DONE
	medic.dropItemToGround(ball)
	ball.throw_at(prisoner, 5, 1, medic)
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(holds), prisoner, ball), 5 SECONDS), "The playing prisoner did not catch the ball")
	TEST_ASSERT_EQUAL(prisoner.held_item, ball, "The caught ball is not in the prisoner's hands")
	TEST_ASSERT_EQUAL(prisoner.activity, game, "Catching the ball ended the game")
	prisoner.end_activity(cancel_ai = FALSE)
	TEST_ASSERT(isturf(ball.loc), "The ball stayed with the prisoner after the game")
	settle_prison_air(home)
