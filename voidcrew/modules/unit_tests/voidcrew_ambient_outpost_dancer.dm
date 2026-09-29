/**
 * World population: tests for outpost_dancer.dm in voidcrew/modules/ambient_npcs/.
 *
 * The dancer settles at a festivus pole (the Undertow's "strip pole"), her dance keeps her on or
 * beside it, a shootout call sends her running and screaming off it, and she is killable like any
 * other ambient outpost NPC. SSambient_npcs does nothing on its own in tests (`ambient_auto`); see
 * voidcrew_ambient_core.dm for the harness (ambient_test_outpost(), pa_tile()) and
 * voidcrew_ambient_outposts.dm for the same pattern used on PA's other outpost NPCs.
 */

/// The dancer settles at the pole mid-dance, and stays on or beside it while she dances
/datum/unit_test/voidcrew_ambient_outpost_dancer_settle

/datum/unit_test/voidcrew_ambient_outpost_dancer_settle/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/obj/structure/festivus/anchored/pole = allocate(/obj/structure/festivus/anchored, pa_tile(2, 2))
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/mob/living/basic/ambient_npc/outpost/dancer/dancer = pa_npc(/mob/living/basic/ambient_npc/outpost/dancer, pa_tile(0, 0), place)

	TEST_ASSERT_EQUAL(dancer.gender, FEMALE, "The dancer is not a woman")
	TEST_ASSERT(dancer.settle_in(), "The dancer could not be found already at the pole")
	var/datum/ambient_activity/dance_pole/dance = dancer.activity
	TEST_ASSERT(istype(dance), "The dancer found at the outpost is [dancer.activity?.name || "doing nothing"], not dancing")
	TEST_ASSERT(get_dist(dancer, pole) <= 1, "The dancer was not found on or beside the pole")
	TEST_ASSERT(HAS_TRAIT(dancer, TRAIT_AI_PAUSED), "The dancer at an empty outpost is not holding still")

	// The dance keeps her there: a dance step never sends her walking off
	for(var/step in 1 to 5)
		dance.next_move = world.time
		dancer.activity_step(1)
		TEST_ASSERT(get_dist(dancer, pole) <= 1, "A dance step moved the dancer away from the pole")
	dancer.end_activity()

	// No pole in reach: she does not pretend to dance
	var/obj/structure/overmap/trader_outpost/empty_outpost = allocate(/obj/structure/overmap/trader_outpost)
	var/datum/ambient_place/outpost/empty_place = pa_place(empty_outpost)
	var/mob/living/basic/ambient_npc/outpost/dancer/stray = pa_npc(/mob/living/basic/ambient_npc/outpost/dancer, pa_tile(4, 4), empty_place)
	TEST_ASSERT(!stray.start_activity(new /datum/ambient_activity/dance_pole(stray)), "The dancer found a pole that is not there")

/// The kingpin's shootout sends her running, screaming, off the pole; she comes back once it is calm
/datum/unit_test/voidcrew_ambient_outpost_dancer_shootout

/datum/unit_test/voidcrew_ambient_outpost_dancer_shootout/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/obj/structure/festivus/anchored/pole = allocate(/obj/structure/festivus/anchored, pa_tile(2, 2))
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/mob/living/basic/ambient_npc/outpost/dancer/dancer = pa_npc(/mob/living/basic/ambient_npc/outpost/dancer, pa_tile(2, 3), place)
	var/datum/ambient_activity/dance_pole/dance = dancer.start_activity(new /datum/ambient_activity/dance_pole(dancer))
	TEST_ASSERT_NOTNULL(dance, "The dancer found no pole to dance at")
	dancer.forceMove(dance.spot)
	dancer.activity_step(1)

	var/turf/refuge = pa_tile(4, 0)
	dancer.react_shootout(refuge)
	var/datum/ambient_activity/take_cover/cover = dancer.activity
	TEST_ASSERT(istype(cover), "A shootout did not send the dancer running for cover")
	TEST_ASSERT(get_dist(cover.spot, pole) > 1, "A shootout sent the dancer for cover without leaving the pole")
	dancer.forceMove(refuge)
	dancer.activity_step(1)
	TEST_ASSERT(dancer.crouching, "The dancer taking cover from a shootout is not down")

	// It's over: back to what she was doing
	dancer.shootout_over()
	TEST_ASSERT(!istype(dancer.activity, /datum/ambient_activity/take_cover), "The dancer stayed in cover once the shootout was over")

	// Violence right by the kingpin's seat scares her the same way, even without a shootout
	allocate(/obj/effect/landmark/bounty_kingpin/seat, pa_tile(0, 0))
	var/mob/living/carbon/human/consistent/brawler = allocate(/mob/living/carbon/human/consistent, pa_tile(2, 1))
	var/mob/living/basic/ambient_npc/outpost/dancer/second = pa_npc(/mob/living/basic/ambient_npc/outpost/dancer, pa_tile(1, 1), place)
	second.react_violence(brawler)
	TEST_ASSERT(istype(second.activity, /datum/ambient_activity/take_cover), "Violence by the kingpin's seat did not send the dancer running for cover")

	// Violence well clear of the kingpin: she ducks and leaves like any other patron (base react_violence)
	var/mob/living/basic/ambient_npc/outpost/dancer/third = pa_npc(/mob/living/basic/ambient_npc/outpost/dancer, pa_tile(4, 4), place)
	var/mob/living/carbon/human/consistent/other_brawler = allocate(/mob/living/carbon/human/consistent, pa_tile(4, 4))
	third.react_violence(other_brawler)
	TEST_ASSERT(istype(third.activity, /datum/ambient_activity/leave), "A fight away from the kingpin did not send the dancer off like the other patrons")

/// The dancer is killable like any other ambient outpost NPC, and drops a little cash once
/datum/unit_test/voidcrew_ambient_outpost_dancer_death

/datum/unit_test/voidcrew_ambient_outpost_dancer_death/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/turf/spot = pa_tile(1, 1)
	var/cash_before = ambient_test_cash_on(spot)
	var/mob/living/basic/ambient_npc/outpost/dancer/dancer = pa_npc(/mob/living/basic/ambient_npc/outpost/dancer, spot, place)
	TEST_ASSERT(!HAS_TRAIT(dancer, TRAIT_GODMODE), "The dancer cannot be hurt")

	dancer.apply_damage(dancer.maxHealth * 2, BRUTE)
	TEST_ASSERT_EQUAL(dancer.stat, DEAD, "The dancer did not die of her wounds")
	var/dropped = ambient_test_cash_on(spot) - cash_before
	TEST_ASSERT(dropped >= 5 && dropped <= 30, "The dancer dropped [dropped] cr, not 5 to 30") // AMBIENT_DEATH_CASH_LOW/HIGH

	dancer.revive(ADMIN_HEAL_ALL)
	dancer.death()
	TEST_ASSERT_EQUAL(ambient_test_cash_on(spot) - cash_before, dropped, "The dancer dropped cash again after a revive")
