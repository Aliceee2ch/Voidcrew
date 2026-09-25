/**
 * Outpost prison economy: pay and its deposits, release bonuses, the ration dispenser's bill, the
 * cells, arrivals, releases, deaths and the warden console.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with
 * the define named beside them. Prisons are driven with tick(seconds) with their own processing
 * stopped, never by waiting in real time, except for beams, which run on timers. Fixtures are
 * in voidcrew_outpost_prison_helpers.dm.
 */

// ===== ECONOMY =====

/datum/unit_test/voidcrew_outpost_prison_economy
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_economy/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("payowner")
	TEST_ASSERT_NOTNULL(home, "The economy test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/datum/bank_account/treasury = home.treasury

	// Pay is tested in a wing in perfect condition, once any bulb that came broken (tg breaks 2-5% of
	// lights at load) is replaced. voidcrew_outpost_prison_conditions_basic tests the scores themselves.
	for(var/turf/tile as anything in prison.wing_turfs())
		for(var/obj/machinery/light/fixture in tile)
			if(fixture.status != LIGHT_OK)
				fixture.fix()
	prison.refresh_conditions()
	TEST_ASSERT(abs(prison.conditions_score() - 100) < 0.01, "The economy test wing is not in perfect condition ([prison.clean_score]/[prison.lit_score]/[prison.powered_score])")
	var/list/mess = list()

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
