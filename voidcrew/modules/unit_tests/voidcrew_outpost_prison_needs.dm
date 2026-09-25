/**
 * Outpost prison needs: hunger, uniforms and the serving hatch, eating, mess, blood and first aid,
 * the routine and dialogue, and what needs do to mood.
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
	prisoner.adjustBruteLoss(50)
	TEST_ASSERT(drift_is(prisoner, 2 - 4), "Half health drifts [prisoner.mood_drift_per_minute()], not -2") // 4 x missing x 2
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
