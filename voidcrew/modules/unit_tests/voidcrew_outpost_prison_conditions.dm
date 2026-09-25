/**
 * Outpost prison conditions: the clean, lit and powered scores and what the wing's state does to
 * prisoners' moods.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with
 * the define named beside them. Prisons are driven with tick(seconds) with their own processing
 * stopped, never by waiting in real time, except for beams, which run on timers. Fixtures are
 * in voidcrew_outpost_prison_helpers.dm.
 */

// ===== SCORES =====

/datum/unit_test/voidcrew_outpost_prison_conditions_basic
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_conditions_basic/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("conditionsowner")
	TEST_ASSERT_NOTNULL(home, "The conditions test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)

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
	settle_prison_air(home)

// ===== WHAT THE WING DOES TO MOOD =====

/datum/unit_test/voidcrew_outpost_prison_mood_wing
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_mood_wing/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("moodwingowner")
	TEST_ASSERT_NOTNULL(home, "The wing mood test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = trouble_prisoner(prison, prison_spot(home, 8, 8))
	TEST_ASSERT(abs(prison.conditions_score() - 100) < 0.01, "The mood test wing is not in perfect condition")
	// Per minute: a well kept prisoner in a wing with every condition at 80+ gains 2.
	TEST_ASSERT(drift_is(prisoner, 2), "A well kept prisoner drifts [prisoner.mood_drift_per_minute()], not +2")

	// The wing: dirty below 60 clean, dark below 50 lit, unpowered. Each also loses the +2.
	var/list/mess = list()
	for(var/x in 3 to 11)
		mess += allocate(/obj/effect/decal/cleanable/dirt, prison_spot(home, x, 7))
	prison.refresh_conditions()
	TEST_ASSERT_EQUAL(prison.clean_score, 55, "Nine pieces of mess did not leave the wing at 55 clean")
	TEST_ASSERT(drift_is(prisoner, -3), "A dirty wing drifts [prisoner.mood_drift_per_minute()], not -3") // PRISONER_MOOD_DIRTY_WING
	QDEL_LIST(mess)
	var/list/lights = all_lights(prison)
	for(var/obj/machinery/light/fixture as anything in lights)
		fixture.break_light_tube()
	prison.refresh_conditions()
	TEST_ASSERT(drift_is(prisoner, -4), "A dark wing drifts [prisoner.mood_drift_per_minute()], not -4") // PRISONER_MOOD_DARK
	for(var/obj/machinery/light/fixture as anything in lights)
		fixture.fix()
	set_wing_power(prison, FALSE)
	TEST_ASSERT(drift_is(prisoner, -5 - 4), "An unpowered, dark wing drifts [prisoner.mood_drift_per_minute()], not -9") // PRISONER_MOOD_NO_POWER
	set_wing_power(prison, TRUE)
	TEST_ASSERT(drift_is(prisoner, 2), "The wing did not recover (drift [prisoner.mood_drift_per_minute()])")
	settle_prison_air(home)
