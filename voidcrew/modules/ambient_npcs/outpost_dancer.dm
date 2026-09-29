/**
 * # World population: the dancer at the Undertow's pole (owner request)
 *
 * A woman who dances round the suplexed rod (the Undertow's "strip pole", a
 * /obj/structure/festivus/anchored on a platform near the kingpin's sofa) for the crowd, on PA's
 * outpost base (outpost_patrons.dm). Built on the same seams as outpost_workers.dm: settle_in()
 * finds her mid-dance, shift_times() covers her own activity's timers, and she costs nothing while
 * the outpost is frozen.
 *
 * She dances in a loop at the pole (turns, a spin now and then, small hops and sways, a word to the
 * crowd), and now and then takes a short break at the bar or a nearby seat before going back. If the
 * kingpin's crew starts shooting, or a fight breaks out near him, she screams and runs, to the given
 * refuge or out by the lift, and only comes back once it is calm. Any other fight at the outpost, she
 * ducks and leaves like the other patrons (the base reaction, inherited).
 *
 * Her lines are in strings/outpost_dancer.json, section "dancer".
 */

/// How near the kingpin's seat counts as "near him" for her scream-and-run reaction
#define DANCER_KINGPIN_ALARM_RADIUS 3

// =========================================================================
// OUTFIT
// =========================================================================

/// A performer's outfit and boots, blue
/datum/outfit/ambient_dancer
	name = "Outpost dancer (blue)"
	uniform = /obj/item/clothing/under/costume/singer/blue
	shoes = /obj/item/clothing/shoes/singerb

/// A performer's outfit and boots, yellow
/datum/outfit/ambient_dancer/yellow
	name = "Outpost dancer (yellow)"
	uniform = /obj/item/clothing/under/costume/singer/yellow
	shoes = /obj/item/clothing/shoes/singery

// =========================================================================
// THE DANCER
// =========================================================================

/// Dances round the pole for the crowd, and screams and runs if the kingpin's crew starts trouble
/mob/living/basic/ambient_npc/outpost/dancer
	desc = "Dances round the pole for the crowd."
	dialogue_file = "outpost_dancer.json"
	dialogue_section = "dancer"
	gender = FEMALE
	random_gender = FALSE
	outfit_choices = list(
		/datum/outfit/ambient_dancer,
		/datum/outfit/ambient_dancer/yellow,
	)
	routine = list(
		/datum/ambient_activity/dance_pole = 6,
		/datum/ambient_activity/sit = 1,
	)

/// Dances at the pole, with the odd break at the bar or a nearby seat
/mob/living/basic/ambient_npc/outpost/dancer/pick_activity()
	var/list/bar = ambient_outpost_bar(place)
	var/atom/bar_spot = length(bar) ? bar[1] : null
	return pick_anchored(routine, bar_spot, list(/datum/ambient_activity/sit))

/// Found mid-dance, at the pole
/mob/living/basic/ambient_npc/outpost/dancer/settle_in()
	if(settle_at(/datum/ambient_activity/dance_pole))
		return TRUE
	return ..()

/// The Undertow's suplexed rod, if there is one
/mob/living/basic/ambient_npc/outpost/dancer/proc/find_pole()
	return ambient_outpost_find(get_outpost(), /obj/structure/festivus/anchored)

/// Fights near the kingpin scare her into running; anything else, she ducks and leaves like the others (base react_violence)
/mob/living/basic/ambient_npc/outpost/dancer/react_violence(mob/living/offender)
	if(ambient_in_kingpin_lounge(offender, DANCER_KINGPIN_ALARM_RADIUS) || ambient_in_kingpin_lounge(src, DANCER_KINGPIN_ALARM_RADIUS))
		if(stat != CONSCIOUS || fading || !reaction_ready("violence"))
			return
		flee_kingpin_trouble(null)
		return
	return ..()

/// The kingpin's crew is shooting: she screams and runs for cover, and comes back once it is calm (shootout_over(), inherited)
/mob/living/basic/ambient_npc/outpost/dancer/react_shootout(turf/refuge)
	if(stat != CONSCIOUS || fading || istype(activity, /datum/ambient_activity/leave))
		return
	flee_kingpin_trouble(refuge)

/// A scream, and off to `refuge` (or out by the lift when there is none) until it is calm
/mob/living/basic/ambient_npc/outpost/dancer/proc/flee_kingpin_trouble(turf/refuge)
	if(istype(activity, /datum/ambient_activity/take_cover))
		return
	var/turf/target = refuge || place?.exit_turf(src)
	if(!target)
		return
	emote("scream", intentional = TRUE)
	start_activity(new /datum/ambient_activity/take_cover(src, target))

// =========================================================================
// THE DANCE
// =========================================================================

/**
 * Dancing round the pole for the crowd: turns, a spin now and then, small hops and sways, and a word
 * to the crowd. Now and then they take a break instead (routine picks /datum/ambient_activity/sit).
 */
/datum/ambient_activity/dance_pole
	name = "dancing"
	accepts_company = TRUE
	duration_low = 3 MINUTES
	duration_high = 6 MINUTES
	/// The pole she is dancing round
	var/datum/weakref/pole_ref
	/// world.time of her next dance move
	var/next_move = 0

/datum/ambient_activity/dance_pole/setup()
	var/mob/living/basic/ambient_npc/outpost/dancer/dancer = doer
	if(!istype(dancer))
		return FALSE
	var/obj/structure/festivus/anchored/pole = dancer.find_pole()
	if(!pole)
		return FALSE
	var/turf/spot = ambient_use_spot(dancer, pole, failed_spots)
	if(!spot)
		return FALSE
	pole_ref = WEAKREF(pole)
	go_to(spot)
	set_duration()
	return TRUE

/datum/ambient_activity/dance_pole/Destroy()
	pole_ref = null
	return ..()

/// The pole, if it is still there
/datum/ambient_activity/dance_pole/proc/pole()
	var/obj/structure/festivus/anchored/pole = pole_ref?.resolve()
	return QDELETED(pole) ? null : pole

/datum/ambient_activity/dance_pole/arrive()
	var/atom/pole = pole()
	if(pole && !doer.buckled)
		doer.face_atom(pole)
	next_move = world.time + rand(3 SECONDS, 6 SECONDS)
	next_line = world.time + rand(15 SECONDS, 35 SECONDS)

/datum/ambient_activity/dance_pole/act(seconds)
	var/atom/pole = pole()
	if(!pole)
		return AMBIENT_STEP_DONE
	if(world.time >= next_move)
		next_move = world.time + rand(3 SECONDS, 6 SECONDS)
		dance_step(pole)
	chatter("dance", 20 SECONDS, 45 SECONDS)
	return AMBIENT_STEP_CONTINUE

/// One dance move: a turn, a spin, a small hop, or a sway
/datum/ambient_activity/dance_pole/proc/dance_step(atom/pole)
	if(doer.buckled)
		return
	switch(rand(1, 10))
		if(1, 2)
			// A spin now and then
			doer.SpinAnimation(speed = rand(6, 9), loops = 1)
		if(3, 4)
			// A small hop
			var/matrix/up = matrix(doer.transform)
			up.Translate(0, 3)
			animate(doer, transform = up, time = 0.3 SECONDS, easing = SINE_EASING)
			animate(transform = matrix(doer.transform), time = 0.3 SECONDS)
		if(5, 6, 7)
			// A turn round the pole
			doer.setDir(turn(get_dir(doer, pole) || doer.dir, pick(-90, 90, 180)))
		else
			// A sway
			doer.manual_emote(pick("sways to the beat.", "gives a little twirl.", "runs a hand up the pole."))

/// Any spin or hop still running is cleared, however the dance ended
/datum/ambient_activity/dance_pole/finish()
	if(!QDELETED(doer))
		animate(doer)
	return ..()

/datum/ambient_activity/dance_pole/spot_unreachable()
	. = ..()
	pole_ref = null

/datum/ambient_activity/dance_pole/shift_times(delay)
	. = ..()
	next_move = ambient_shifted(next_move, delay)

// =========================================================================
// WHO COMES WHERE
// =========================================================================

/// One dancer at the Undertow
/datum/ambient_outpost_role/dancer
	name = "dancer"
	npc_type = /mob/living/basic/ambient_npc/outpost/dancer
	outpost_types = list(/obj/structure/overmap/trader_outpost/black_market)
	max_count = 1
	weight = 3
	gap_low = 1 MINUTES
	gap_high = 2 MINUTES

#undef DANCER_KINGPIN_ALARM_RADIUS
