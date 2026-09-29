/**
 * World population: tests for outpost_dancer.dm in voidcrew/modules/ambient_npcs/.
 *
 * The dancer settles right on the festivus pole's own tile (the Undertow's "strip pole"), mid-dance,
 * her dance keeps her there and leaves her no higher than she started, and ending the dance (a break,
 * a shootout, or death) steps her back down to a free adjacent tile with her pole-hugging pixel
 * offsets reset. A shootout call sends her running for cover, a fight by the kingpin's seat sends
 * her straight out by the lift, and she is killable like any other ambient outpost NPC.
 * SSambient_npcs does nothing on its own in tests (`ambient_auto`); see voidcrew_ambient_core.dm for
 * the harness (ambient_test_outpost(), pa_tile()) and voidcrew_ambient_outposts.dm for the same
 * pattern used on PA's other outpost NPCs.
 */

/// The dancer settles right on the pole, and stays there while she dances; ending the dance steps her off it
/datum/unit_test/voidcrew_ambient_outpost_dancer_settle

/datum/unit_test/voidcrew_ambient_outpost_dancer_settle/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/obj/structure/festivus/anchored/pole = allocate(/obj/structure/festivus/anchored, pa_tile(2, 2))
	var/turf/pole_turf = get_turf(pole)
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/mob/living/basic/ambient_npc/outpost/dancer/dancer = pa_npc(/mob/living/basic/ambient_npc/outpost/dancer, pa_tile(0, 0), place)
	var/base_w = dancer.base_pixel_w
	var/base_z = dancer.base_pixel_z

	TEST_ASSERT_EQUAL(dancer.gender, FEMALE, "The dancer is not a woman")
	TEST_ASSERT(dancer.settle_in(), "The dancer could not be found already at the pole")
	var/datum/ambient_activity/dance_pole/dance = dancer.activity
	TEST_ASSERT(istype(dance), "The dancer found at the outpost is [dancer.activity?.name || "doing nothing"], not dancing")
	TEST_ASSERT_EQUAL(get_turf(dancer), pole_turf, "The dancer was not found right on the pole")
	TEST_ASSERT(dance.on_pole, "The dancer settled at the pole without climbing onto it")
	TEST_ASSERT(HAS_TRAIT(dancer, TRAIT_AI_PAUSED), "The dancer at an empty outpost is not holding still")

	// The dance keeps her right there: a dance step never sends her off the pole's own tile
	for(var/step in 1 to 5)
		dance.next_move = world.time
		dancer.activity_step(1)
		TEST_ASSERT_EQUAL(get_turf(dancer), pole_turf, "A dance step moved the dancer off the pole")
	// Hops and spins end where they started: she never drifts up off the floor
	var/matrix/rest = matrix(dancer.transform)
	for(var/step in 1 to 40)
		dance.dance_step(pole)
	var/matrix/after = matrix(dancer.transform)
	TEST_ASSERT(after.c == rest.c && after.f == rest.f, "The dance left the dancer [after.f - rest.f] pixels higher than she started")

	// Ending the dance steps her back down, beside the pole, with her hugging offsets reset
	dancer.end_activity()
	TEST_ASSERT(get_turf(dancer) != pole_turf, "The dancer stayed on the pole once her dance ended")
	TEST_ASSERT_EQUAL(get_dist(dancer, pole), 1, "The dancer did not step down to a tile beside the pole")
	TEST_ASSERT(dancer.pixel_w == base_w && dancer.pixel_z == base_z, "The dancer kept her pole-hugging offsets after stepping off it")

	// No pole in reach: she does not pretend to dance
	var/obj/structure/overmap/trader_outpost/empty_outpost = allocate(/obj/structure/overmap/trader_outpost)
	var/datum/ambient_place/outpost/empty_place = pa_place(empty_outpost)
	var/mob/living/basic/ambient_npc/outpost/dancer/stray = pa_npc(/mob/living/basic/ambient_npc/outpost/dancer, pa_tile(4, 4), empty_place)
	TEST_ASSERT(!stray.start_activity(new /datum/ambient_activity/dance_pole(stray)), "The dancer found a pole that is not there")

/// The kingpin's shootout sends her off the pole for cover and she comes back once it is calm; a fight by his seat sends her out by the lift
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
	TEST_ASSERT(dance.on_pole, "The dancer did not climb onto the pole")
	var/base_w = dancer.base_pixel_w
	var/base_z = dancer.base_pixel_z

	var/turf/refuge = pa_tile(4, 0)
	dancer.react_shootout(refuge)
	var/datum/ambient_activity/take_cover/cover = dancer.activity
	TEST_ASSERT(istype(cover), "A shootout did not send the dancer running for cover")
	TEST_ASSERT(get_dist(cover.spot, pole) > 1, "A shootout sent the dancer for cover without leaving the pole")
	TEST_ASSERT(get_turf(dancer) != get_turf(pole), "The shootout left the dancer standing on the pole")
	TEST_ASSERT(dancer.pixel_w == base_w && dancer.pixel_z == base_z, "The shootout left the dancer's pole-hugging offsets on her")
	dancer.forceMove(refuge)
	dancer.activity_step(1)
	TEST_ASSERT(dancer.crouching, "The dancer taking cover from a shootout is not down")

	// It's over: back to what she was doing
	dancer.shootout_over()
	TEST_ASSERT(!istype(dancer.activity, /datum/ambient_activity/take_cover), "The dancer stayed in cover once the shootout was over")

	// A fight right by the kingpin's seat, no shootout: she runs straight out by the lift, without ducking first
	allocate(/obj/effect/landmark/bounty_kingpin/seat, pa_tile(0, 0))
	var/mob/living/carbon/human/consistent/brawler = allocate(/mob/living/carbon/human/consistent, pa_tile(2, 1))
	var/mob/living/basic/ambient_npc/outpost/dancer/second = pa_npc(/mob/living/basic/ambient_npc/outpost/dancer, pa_tile(1, 1), place)
	second.react_violence(brawler)
	var/datum/ambient_activity/leave/running = second.activity
	TEST_ASSERT(istype(running), "A fight by the kingpin's seat did not send the dancer running")
	TEST_ASSERT(!second.crouching, "The dancer ducked instead of running from a fight by the kingpin")
	TEST_ASSERT_EQUAL(running.spot, pa_tile(4, 4), "The dancer is not running for the lift")

	// A fight well clear of the kingpin: she ducks and leaves like any other patron (base react_violence)
	var/mob/living/basic/ambient_npc/outpost/dancer/third = pa_npc(/mob/living/basic/ambient_npc/outpost/dancer, pa_tile(4, 4), place)
	var/mob/living/carbon/human/consistent/other_brawler = allocate(/mob/living/carbon/human/consistent, pa_tile(4, 4))
	third.react_violence(other_brawler)
	TEST_ASSERT(istype(third.activity, /datum/ambient_activity/leave), "A fight away from the kingpin did not send the dancer off like the other patrons")
	TEST_ASSERT(third.crouching, "A fight away from the kingpin did not make the dancer duck like the other patrons")

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
