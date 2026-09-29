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
 * crowd), and now and then takes a short break at the bar or a nearby seat before going back. She
 * stands beside the pole, never on a kingpin goon's post (they walk back to them). If the kingpin's
 * crew starts shooting she screams and runs for the lounge's refuge, and comes back once it is calm
 * (take_cover, shootout_over()). If a fight breaks out right by his seat she screams and runs out by
 * the lift (leave); a replacement comes off the lift later. Any other fight at the outpost, she ducks
 * and leaves like the other patrons (the base reaction, inherited).
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

/// A fight right by the kingpin: she screams and runs out by the lift, no ducking. Anything else, she ducks and leaves like the others (base react_violence).
/mob/living/basic/ambient_npc/outpost/dancer/react_violence(mob/living/offender)
	if(!ambient_in_kingpin_lounge(offender, DANCER_KINGPIN_ALARM_RADIUS))
		return ..()
	// Already running, or keeping her head down in a shootout: she stays where she is
	if(stat != CONSCIOUS || fading || istype(activity, /datum/ambient_activity/leave) || istype(activity, /datum/ambient_activity/take_cover) || !reaction_ready("violence"))
		return
	if(start_activity(new /datum/ambient_activity/leave(src)))
		scream()

/// The kingpin's crew is shooting: she screams and runs for cover, and comes back once it is calm (shootout_over(), inherited)
/mob/living/basic/ambient_npc/outpost/dancer/react_shootout(turf/refuge)
	if(stat != CONSCIOUS || fading || istype(activity, /datum/ambient_activity/leave) || istype(activity, /datum/ambient_activity/take_cover))
		return
	if(start_activity(new /datum/ambient_activity/take_cover(src, refuge)))
		scream()

/// A woman's scream. Never sleeps.
/mob/living/basic/ambient_npc/outpost/dancer/proc/scream()
	var/static/list/screams = list(
		'sound/mobs/humanoids/human/scream/femalescream_1.ogg',
		'sound/mobs/humanoids/human/scream/femalescream_2.ogg',
		'sound/mobs/humanoids/human/scream/femalescream_3.ogg',
		'sound/mobs/humanoids/human/scream/femalescream_4.ogg',
		'sound/mobs/humanoids/human/scream/femalescream_5.ogg',
	)
	manual_emote("screams!")
	playsound(src, pick(screams), 50, TRUE)

// =========================================================================
// THE DANCE
// =========================================================================

/**
 * Dancing round the pole for the crowd: turns, a spin now and then, small hops and sways, and a word
 * to the crowd. Now and then they take a break instead (routine picks /datum/ambient_activity/sit).
 */
/datum/ambient_activity/dance_pole
	name = "dancing"
	// On the job: nobody pulls her off the pole for a chat
	accepts_company = FALSE
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
	var/turf/spot = ambient_use_spot(dancer, pole, spots_to_avoid())
	if(!spot)
		return FALSE
	pole_ref = WEAKREF(pole)
	go_to(spot)
	set_duration()
	return TRUE

/datum/ambient_activity/dance_pole/Destroy()
	pole_ref = null
	return ..()

/// Spots given up on, and the kingpin's goons' posts: they walk back to them, and she would be in the way
/datum/ambient_activity/dance_pole/proc/spots_to_avoid()
	var/list/avoid = failed_spots ? failed_spots.Copy() : list()
	for(var/obj/effect/landmark/bounty_kingpin/goon/post in GLOB.bounty_kingpin_marks)
		var/turf/post_turf = get_turf(post)
		if(post_turf)
			avoid[post_turf] = TRUE
	return avoid

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
			// A small hop. The resting transform is kept first: animate() sets the var to each step's end at once, so reading it after would leave her floating higher with every hop.
			var/matrix/rest = matrix(doer.transform)
			var/matrix/up = matrix(doer.transform)
			up.Translate(0, 3)
			animate(doer, transform = up, time = 0.3 SECONDS, easing = SINE_EASING)
			animate(transform = rest, time = 0.3 SECONDS)
		if(5, 6, 7, 8, 9)
			// A turn round the pole
			doer.setDir(turn(get_dir(doer, pole) || doer.dir, pick(-90, 90, 180)))
		else
			// Now and then, something the crowd would notice
			doer.manual_emote(pick("sways to the beat.", "gives a little twirl.", "leans back against the pole."))

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
