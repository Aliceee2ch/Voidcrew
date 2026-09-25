/**
 * The Outpost Manipulator's Prison section: its data and every admin action, for the quiet side of
 * the prison and for trouble.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with
 * the define named beside them. Prisons are driven with tick(seconds) with their own processing
 * stopped, never by waiting in real time, except for beams, which run on timers. Fixtures are
 * in voidcrew_outpost_prison_helpers.dm.
 */

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

// ===== TROUBLE ADMIN TOOLS =====

/datum/unit_test/voidcrew_outpost_prison_trouble_admin
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_trouble_admin/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("troubleadminowner")
	TEST_ASSERT_NOTNULL(home, "The trouble admin test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/operator = make_player(prison_spot(home, 8, 4), "troubleadmin")
	var/datum/outpost_manipulator/unit_test/prison/panel = allocate(__IMPLIED_TYPE__, operator)
	panel.selected = home
	var/mob/living/basic/outpost_prisoner/first = trouble_prisoner(prison, prison_spot(home, 7, 8))
	var/mob/living/basic/outpost_prisoner/second = trouble_prisoner(prison, prison_spot(home, 9, 8))
	var/mob/living/basic/outpost_prisoner/third = trouble_prisoner(prison, prison_spot(home, 12, 8))

	// The section carries tension, stage and the breakout countdown; each row mood, state and loose time.
	var/list/section = panel.ui_data(operator)["selected"]["prison"]
	for(var/key in list("tension", "stage", "breakout_in"))
		TEST_ASSERT(key in section, "The prison section sends no [key]")
	TEST_ASSERT_EQUAL(section["stage"], "calm", "A calm wing's stage is [section["stage"]]")
	TEST_ASSERT_NULL(section["breakout_in"], "A calm wing has a breakout countdown")
	var/list/row = section["prisoners"][1]
	for(var/key in list("mood", "state", "loose_left"))
		TEST_ASSERT(key in row, "A prisoner row sends no [key]")
	TEST_ASSERT_EQUAL(row["state"], "normal", "A calm prisoner's state is [row["state"]]")
	TEST_ASSERT_NULL(row["loose_left"], "A prisoner in the yard has a loose countdown")

	// Mood, one and all.
	panel.manage_outpost(home, operator, "prison_set", list("ref" = REF(first), "field" = "mood", "value" = 20))
	TEST_ASSERT(abs(first.mood - 20) < 0.01, "Setting mood left it at [first.mood]")
	panel.manage_outpost(home, operator, "prison_set", list("ref" = REF(first), "field" = "mood", "value" = "lots"))
	TEST_ASSERT(panel.error && abs(first.mood - 20) < 0.01, "A non-number mood was accepted")
	panel.manage_outpost(home, operator, "prison_all", list("what" = "enrage"))
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in list(first, second, third))
		TEST_ASSERT(prisoner.mood < 20, "Enrage left [prisoner] at [prisoner.mood]")
	panel.manage_outpost(home, operator, "prison_all", list("what" = "calm"))
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in list(first, second, third))
		TEST_ASSERT(prisoner.mood > 99, "Calm all left [prisoner] at [prisoner.mood]")

	// A fight with the nearest other; refused with nobody free to fight.
	panel.manage_outpost(home, operator, "prison_fight", list("ref" = REF(first)))
	TEST_ASSERT(first.fight && first.fight == second.fight, "The admin fight did not pair the nearest prisoner")
	TEST_ASSERT_EQUAL(panel.ui_data(operator)["selected"]["prison"]["prisoners"][1]["state"], "fighting", "A fighter's state is not fighting")
	panel.manage_outpost(home, operator, "prison_fight", list("ref" = REF(third)))
	TEST_ASSERT(panel.error, "A fight with nobody free to fight was accepted")
	TEST_ASSERT(isnull(third.trouble) && !third.fight, "A refused fight changed the prisoner")
	panel.manage_outpost(home, operator, "prison_calm", list())
	TEST_ASSERT(!first.fight && isnull(first.trouble), "Calm did not end the fight")
	TEST_ASSERT(abs(first.mood - 70) < 0.01, "Calm set mood to [first.mood], not 70")

	// A riot everyone joins; a second is refused.
	panel.manage_outpost(home, operator, "prison_riot", list())
	TEST_ASSERT(prison.riot_active, "The admin riot did not start")
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in list(first, second, third))
		TEST_ASSERT_EQUAL(prisoner.trouble, "riot", "[prisoner] stayed out of the admin riot")
	section = panel.ui_data(operator)["selected"]["prison"]
	TEST_ASSERT_EQUAL(section["breakout_in"], 180, "The riot's breakout is due in [section["breakout_in"]]")
	TEST_ASSERT_EQUAL(section["prisoners"][1]["state"], "rioting", "A rioter's state is [section["prisoners"][1]["state"]]")
	panel.manage_outpost(home, operator, "prison_riot", list())
	TEST_ASSERT(panel.error, "A second riot was accepted")
	panel.manage_outpost(home, operator, "prison_calm", list())
	TEST_ASSERT(!prison.riot_active, "Calm did not end the riot")
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in list(first, second, third))
		TEST_ASSERT(isnull(prisoner.trouble) && !istype(prisoner.held_item, /obj/item/knife/shiv), "[prisoner] kept rioting after the calm")

	// A breakout: out of the cell block and loose; refused for someone already loose.
	panel.manage_outpost(home, operator, "prison_breakout", list("ref" = REF(second)))
	TEST_ASSERT_EQUAL(second.trouble, "loose", "The admin breakout did not set the prisoner loose")
	TEST_ASSERT(!prison.in_cell_block(second), "The admin breakout left the prisoner in the cell block")
	TEST_ASSERT_EQUAL(prison.alarm_state()[1], "breakout", "An admin breakout shows the [prison.alarm_state()[1]] alarm")
	var/list/loose_row
	for(var/list/prisoner_row as anything in panel.ui_data(operator)["selected"]["prison"]["prisoners"])
		if(prisoner_row["ref"] == REF(second))
			loose_row = prisoner_row
	TEST_ASSERT_EQUAL(loose_row["state"], "loose", "A loose prisoner's state is [loose_row["state"]]")
	TEST_ASSERT_EQUAL(loose_row["loose_left"], 300, "A loose prisoner shows [loose_row["loose_left"]] s left")
	var/turf/breakout_spot = get_turf(second)
	panel.manage_outpost(home, operator, "prison_breakout", list("ref" = REF(second)))
	TEST_ASSERT(panel.error, "Breaking out a loose prisoner was accepted")
	TEST_ASSERT_EQUAL(get_turf(second), breakout_spot, "A refused breakout moved the prisoner")
	panel.manage_outpost(home, operator, "prison_breakout", list("ref" = "not a ref"))
	TEST_ASSERT(panel.error, "A breakout for a bad reference was accepted")
	panel.manage_outpost(home, operator, "prison_all", list("what" = "riot"))
	TEST_ASSERT(panel.error, "An unknown prisoner-wide action was accepted")

	// Every successful action was logged once: set, enrage, calm all, fight, calm, riot, calm, breakout.
	TEST_ASSERT_EQUAL(length(panel.operations), 8, "The manipulator logged [length(panel.operations)] trouble actions: [jointext(panel.operations, "; ")]")
	settle_prison_air(home)
