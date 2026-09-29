/**
 * # World population: the dancer at the Undertow's pole (owner request)
 *
 * A woman who dances up on the suplexed rod's own platform (the Undertow's "strip pole", a
 * /obj/structure/festivus/anchored on a /obj/structure/platform near the kingpin's sofa), for the
 * crowd, on PA's outpost base (outpost_patrons.dm). Built on the same seams as outpost_workers.dm:
 * settle_in() finds her mid-dance, shift_times() covers her own activity's timers, and she costs
 * nothing while the outpost is frozen.
 *
 * The platform is dense and inside the kingpin's lounge-avoid radius, so PA's own standable() keeps
 * every other NPC off it; the dancer's own standable() override (below) spares her that one tile.
 * She still can't walk onto a dense tile like anyone else, so dance_pole gets her adjacent first,
 * then climbs her onto it with a short forceMove after a brief delay (settle_in() skips the climb
 * and finds her already up there, mid-dance). Up on the pole she orbits it, leans back against it,
 * sways and spins, all with small pixel_w/pixel_z offsets that keep her pressed against it; her
 * mob layer already draws over the platform and the rod (both BELOW_OBJ_LAYER). She steps back down
 * to a free adjacent tile whenever the dance ends, whether for a break or because she is running.
 *
 * She dances in a loop at the pole (turns, a spin now and then, small hops and sways, a word to the
 * crowd), and now and then takes a short break at the bar or a nearby seat before going back. If the
 * kingpin's crew starts shooting she screams and runs for the lounge's refuge, and comes back once it
 * is calm (take_cover, shootout_over()). If a fight breaks out right by his seat she screams and runs
 * out by the lift (leave); a replacement comes off the lift later. Any other fight at the outpost,
 * she ducks and leaves like the other patrons (the base reaction, inherited).
 *
 * Her lines are in strings/outpost_dancer.json, section "dancer".
 */

/// add_offsets()/remove_offsets() source key for the pixel_w/pixel_z hug against the pole
#define DANCE_POLE_OFFSET_SOURCE "dance_pole"

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

/// Dances on the pole for the crowd, and screams and runs if the kingpin's crew starts trouble
/mob/living/basic/ambient_npc/outpost/dancer
	desc = "Dances on the pole for the crowd."
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

/**
 * PA's outpost standable(), plus one exception: the pole's own tile, spared its platform's density
 * and the kingpin's lounge-avoid radius so she alone may dance on it. Still keeps her (and it) off
 * anyone already standing there, and everywhere else keeps every one of PA's own keep-clear rules.
 */
/mob/living/basic/ambient_npc/outpost/dancer/standable(turf/tile, list/avoid, ignore_floor = FALSE)
	if(..())
		return TRUE
	if(!tile || tile != get_turf(find_pole()))
		return FALSE
	if(LAZYACCESS(avoid, tile) || !isopenturf(tile) || isspaceturf(tile) || isgroundlessturf(tile) || islava(tile) || ischasm(tile))
		return FALSE
	if(locate(/mob/living) in tile)
		return FALSE
	return leash_ok(tile)

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
 * Dancing on the pole for the crowd: up on its own tile (climbing on if she is not there already),
 * orbiting it, leaning back against it, spins, small hops and sways, and a word to the crowd. Now
 * and then they take a break instead (routine picks /datum/ambient_activity/sit).
 */
/datum/ambient_activity/dance_pole
	name = "dancing"
	// On the job: nobody pulls her off the pole for a chat
	accepts_company = FALSE
	duration_low = 3 MINUTES
	duration_high = 6 MINUTES
	/// The pole she is dancing on
	var/datum/weakref/pole_ref
	/// world.time of her next dance move
	var/next_move = 0
	/// Whether she has climbed up onto the pole's own tile yet
	var/on_pole = FALSE
	/// world.time she climbs up, once she is beside the pole
	var/climb_at = 0
	/// The side of the pole she is currently pressed against, once on_pole
	var/orbit_dir = SOUTH

/datum/ambient_activity/dance_pole/setup()
	var/mob/living/basic/ambient_npc/outpost/dancer/dancer = doer
	if(!istype(dancer))
		return FALSE
	var/obj/structure/festivus/anchored/pole = dancer.find_pole()
	var/turf/pole_turf = get_turf(pole)
	// Her one exception to PA's keep-clear rules (dancer/standable()): checked here so a taken or
	// leashed-off pole is given up on at once, same as any other activity's spot
	if(!pole_turf || !dancer.standable(pole_turf, spots_to_avoid()))
		return FALSE
	pole_ref = WEAKREF(pole)
	// Gets her adjacent first: the platform is dense, so she climbs the rest of the way herself (act())
	go_to(pole_turf, 1)
	set_duration()
	return TRUE

/datum/ambient_activity/dance_pole/Destroy()
	pole_ref = null
	return ..()

/// Spots given up on, and the kingpin's goons' posts: they walk back to them, and she would be in the way while still climbing up
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
	var/turf/pole_turf = get_turf(pole)
	if(pole_turf && doer.loc == pole_turf)
		// Found already up there (settle_in()): straight into the dance, no climb
		climb_onto_pole(pole)
	else
		climb_at = world.time + rand(0.5 SECONDS, 1.5 SECONDS)
		if(pole && !doer.buckled)
			doer.face_atom(pole)
	next_move = world.time + rand(3 SECONDS, 6 SECONDS)
	next_line = world.time + rand(15 SECONDS, 35 SECONDS)

/datum/ambient_activity/dance_pole/act(seconds)
	var/atom/pole = pole()
	if(!pole)
		return AMBIENT_STEP_DONE
	if(!on_pole)
		if(world.time < climb_at)
			return AMBIENT_STEP_CONTINUE
		var/turf/pole_turf = get_turf(pole)
		if(!doer.standable(pole_turf, null))
			// Someone else got there first: try again shortly
			climb_at = world.time + rand(2 SECONDS, 4 SECONDS)
			return AMBIENT_STEP_CONTINUE
		climb_onto_pole(pole)
	if(world.time >= next_move)
		next_move = world.time + rand(3 SECONDS, 6 SECONDS)
		dance_step(pole)
	chatter("dance", 20 SECONDS, 45 SECONDS)
	return AMBIENT_STEP_CONTINUE

/// The short climb up: onto the pole's own tile (forceMove, the platform stays dense to everyone else) and hugging it
/datum/ambient_activity/dance_pole/proc/climb_onto_pole(atom/pole)
	var/turf/pole_turf = get_turf(pole)
	if(doer.loc != pole_turf)
		doer.forceMove(pole_turf)
	on_pole = TRUE
	if(!doer.dir)
		doer.setDir(SOUTH)
	orbit_dir = doer.dir
	apply_hug(orbit_dir)

/// A small pixel_w/pixel_z nudge toward `direction`'s side of the pole, close enough to still read as hugging it
/datum/ambient_activity/dance_pole/proc/pole_offset(direction)
	switch(direction)
		if(NORTH)
			return list(0, 5)
		if(SOUTH)
			return list(0, -5)
		if(EAST)
			return list(5, 0)
		if(WEST)
			return list(-5, 0)
	return list(0, 0)

/// Sets her pixel_w/pixel_z to hug the pole from `direction`'s side, further out if `lean` (leaning back against it)
/datum/ambient_activity/dance_pole/proc/apply_hug(direction, lean = FALSE)
	var/list/offset = pole_offset(direction)
	var/scale = lean ? 1.6 : 1
	doer.add_offsets(DANCE_POLE_OFFSET_SOURCE, w_add = offset[1] * scale, z_add = offset[2] * scale, animate = FALSE)

/// One dance move: a spin, a small hop, an orbit round the pole, leaning back against it, or a sway
/datum/ambient_activity/dance_pole/proc/dance_step(atom/pole)
	if(doer.buckled || !on_pole)
		return
	switch(rand(1, 10))
		if(1, 2)
			// A spin now and then, and back to the pole once it's done
			doer.SpinAnimation(speed = rand(6, 9), loops = 1)
		if(3, 4)
			// A small hop. The resting transform is kept first: animate() sets the var to each step's end at once, so reading it after would leave her floating higher with every hop.
			var/matrix/rest = matrix(doer.transform)
			var/matrix/up = matrix(doer.transform)
			up.Translate(0, 3)
			animate(doer, transform = up, time = 0.3 SECONDS, easing = SINE_EASING)
			animate(transform = rest, time = 0.3 SECONDS)
		if(5, 6)
			// A small orbit round the pole
			orbit_dir = turn(orbit_dir, pick(-90, 90))
			doer.setDir(orbit_dir)
			apply_hug(orbit_dir)
		if(7)
			// Leans back against it
			apply_hug(orbit_dir, lean = TRUE)
			doer.manual_emote("leans back against the pole.")
		if(8)
			// A sway, without losing her place on it
			var/list/offset = pole_offset(orbit_dir)
			doer.add_offsets(DANCE_POLE_OFFSET_SOURCE, w_add = offset[1] + pick(-2, 2), z_add = offset[2] + pick(-2, 2), animate = FALSE)
		else
			// Now and then, something the crowd would notice
			doer.manual_emote(pick("sways to the beat.", "gives a little twirl."))

/// Any spin or hop still running is cleared, however the dance ended; she steps back down to the floor
/datum/ambient_activity/dance_pole/finish()
	if(!QDELETED(doer))
		animate(doer)
		doer.remove_offsets(DANCE_POLE_OFFSET_SOURCE, animate = FALSE)
		if(on_pole)
			step_off_pole()
	return ..()

/// Down off the platform to a free adjacent tile, for a break or because she is running
/datum/ambient_activity/dance_pole/proc/step_off_pole()
	var/turf/pole_turf = get_turf(pole())
	if(!pole_turf || doer.loc != pole_turf)
		return
	var/turf/stand = doer.free_tile_beside(pole_turf, 1)
	if(stand)
		doer.forceMove(stand)

/datum/ambient_activity/dance_pole/spot_unreachable()
	. = ..()
	pole_ref = null

/datum/ambient_activity/dance_pole/shift_times(delay)
	. = ..()
	next_move = ambient_shifted(next_move, delay)
	climb_at = ambient_shifted(climb_at, delay)

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
