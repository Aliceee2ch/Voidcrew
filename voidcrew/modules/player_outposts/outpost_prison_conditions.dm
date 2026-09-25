/**
 * # Prison wing conditions
 *
 * How well the wing is kept: the clean, lit and powered scores, refreshed every few seconds along
 * with the wing's furniture; what they do to prisoners' moods; the sparks a power cut or the
 * lights going out give the wing; and the red riot strobe, which drives the wing's lights
 * directly so no firelocks close. The pay model is in voidcrew/_DEFINES/outpost_prison_economy.dm.
 */

/// How often the condition scores and the wing's furniture are refreshed, in seconds
#define PRISON_CONDITIONS_REFRESH_SECONDS 5

/datum/outpost_prison
	/// Condition scores, 0 to 100
	var/clean_score = 100
	var/lit_score = 100
	var/powered_score = 100
	/// Seconds since the scores were refreshed
	var/conditions_clock = 0
	/// Seconds of power cut the wing has built up (see PRISON_POWER_GRACE)
	var/outage_debt = 0
	/// Red strobe state
	var/riot_lights_on = FALSE
	var/strobe_bright = TRUE
	var/strobe_timer
	/// Weakrefs to the lights the strobe drives
	var/list/riot_lights

// ===== REFRESH =====

/// Advances the condition scores by `seconds`: a refresh every PRISON_CONDITIONS_REFRESH_SECONDS
/datum/outpost_prison/proc/conditions_tick(seconds)
	conditions_clock += seconds
	if(conditions_clock < PRISON_CONDITIONS_REFRESH_SECONDS)
		return
	conditions_clock = 0
	refresh_conditions()

/// Whether the wing's APC gives its machines power
/datum/outpost_prison/proc/is_powered()
	return !!wing?.powered(AREA_USAGE_EQUIP)

/// Recounts mess, lights and furniture, checks power, and refreshes where prisoners can reach
/datum/outpost_prison/proc/refresh_conditions()
	var/old_lit = lit_score
	var/old_powered = powered_score
	var/mess = 0
	var/lights = 0
	var/working = 0
	var/list/found = list(
		"bed" = list(),
		"stool" = list(),
		"reading_chair" = list(),
		"table" = list(),
		"hatch" = list(),
		"toilet" = list(),
		"sink" = list(),
		"hoop" = list(),
		"bookcase" = list(),
		"cooler" = list(),
		"window" = list(),
	)
	for(var/turf/tile as anything in wing_turfs())
		for(var/atom/movable/thing as anything in tile)
			if(istype(thing, /obj/effect/decal/cleanable) || istype(thing, /obj/item/trash))
				mess++
			else if(istype(thing, /obj/machinery/light))
				var/obj/machinery/light/fixture = thing
				lights++
				if(fixture.status == LIGHT_OK && fixture.has_power())
					working++
			else if(istype(thing, /obj/structure/bed))
				found["bed"] += thing
			else if(istype(thing, /obj/structure/chair/stool))
				found["stool"] += thing
			else if(istype(thing, /obj/structure/chair/comfy))
				found["reading_chair"] += thing
			else if(istype(thing, /obj/structure/table/reinforced/prison_hatch))
				found["hatch"] += thing
			else if(istype(thing, /obj/structure/table))
				found["table"] += thing
			else if(istype(thing, /obj/structure/toilet))
				found["toilet"] += thing
			else if(istype(thing, /obj/structure/sink))
				found["sink"] += thing
			else if(istype(thing, /obj/structure/hoop))
				found["hoop"] += thing
			else if(istype(thing, /obj/structure/bookcase))
				found["bookcase"] += thing
			else if(istype(thing, /obj/structure/reagent_dispensers/water_cooler))
				found["cooler"] += thing
			else if(istype(thing, /obj/structure/window) && on_wing_edge(tile))
				found["window"] += thing
	fixtures = found
	clean_score = max(0, 100 - mess * OUTPOST_PRISON_MESS_PENALTY)
	lit_score = lights ? round(100 * working / lights) : 0
	powered_score = is_powered() ? 100 : 0
	refresh_reach()
	// A power cut or the lights going out puts the wing on edge.
	note_condition_changes(old_lit, old_powered)

/// Whether a tile is on the outside edge of the wing, so a window there looks out
/datum/outpost_prison/proc/on_wing_edge(turf/tile)
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(tile, direction)
		if(!beside || beside.loc != wing)
			return TRUE
	return FALSE

// ===== SCORES =====

/// Conditions, 0 to 100: the mean of the clean, lit and powered scores
/datum/outpost_prison/proc/conditions_score()
	return (clean_score + lit_score + powered_score) / 3

/// How much of full pay the wing's conditions allow, 0 to 1
/datum/outpost_prison/proc/conditions_pay_factor()
	return conditions_score() / 100

/// The warden console's and the admin panel's conditions block
/datum/outpost_prison/proc/conditions_payload()
	return list(
		"clean" = clean_score,
		"lit" = lit_score,
		"powered" = powered_score,
		"score" = round(conditions_score()),
	)

/// Power cuts and the lights going out, noticed when the condition scores are refreshed
/datum/outpost_prison/proc/note_condition_changes(old_lit, old_powered)
	if(old_powered && !powered_score)
		trouble_event(PRISON_SPIKE_POWER_CUT, "the power went out")
	else if(old_lit >= PRISON_DARK_BELOW && lit_score < PRISON_DARK_BELOW)
		trouble_event(PRISON_SPIKE_LIGHTS_OUT, "the lights went out")

// ===== MOOD =====

/// What the state of the wing does to a prisoner's mood per minute: list(gain, loss), before personality
/mob/living/basic/outpost_prisoner/proc/wing_mood_per_minute()
	var/loss = 0
	var/gain = 0
	if(prison && trouble != PRISONER_TROUBLE_LOOSE)
		if(prison.lit_score < PRISON_DARK_BELOW)
			loss += PRISONER_MOOD_DARK
		if(prison.clean_score < PRISON_DIRTY_BELOW)
			loss += PRISONER_MOOD_DIRTY_WING
		if(!prison.powered_score)
			loss += PRISONER_MOOD_NO_POWER
		if(prison.clean_score >= PRISON_GOOD_CONDITIONS && prison.lit_score >= PRISON_GOOD_CONDITIONS && prison.powered_score >= PRISON_GOOD_CONDITIONS)
			gain += PRISONER_MOOD_GOOD_WING
	return list(gain, loss)

// ===== RIOT LIGHTS =====

/// The strobe runs through a riot, and through a breakout until the rioters who got out are dealt with
/datum/outpost_prison/proc/update_riot_lights()
	set_riot_lights(riot_active || (broke_out && loose_count()))

/**
 * Puts the wing's lights in emergency red and strobes them, or puts them back. Driven directly
 * rather than through the fire alarm, so no firelocks close. The lights' switch counts are put
 * back afterwards, so a riot does not make them burn out sooner.
 */
/datum/outpost_prison/proc/set_riot_lights(on)
	on = !!on
	if(on == riot_lights_on)
		return
	riot_lights_on = on
	if(on)
		riot_lights = list()
		for(var/turf/tile as anything in wing_turfs())
			for(var/obj/machinery/light/fixture in tile)
				var/switches = fixture.switchcount
				fixture.major_emergency = TRUE
				fixture.update(FALSE)
				fixture.switchcount = switches
				riot_lights += WEAKREF(fixture)
		strobe_bright = TRUE
		strobe_timer = addtimer(CALLBACK(src, PROC_REF(strobe_step)), PRISON_STROBE_INTERVAL, TIMER_STOPPABLE | TIMER_DELETE_ME)
		return
	if(strobe_timer)
		deltimer(strobe_timer)
		strobe_timer = null
	for(var/datum/weakref/light_ref as anything in riot_lights)
		var/obj/machinery/light/fixture = light_ref.resolve()
		if(!fixture)
			continue
		var/switches = fixture.switchcount
		fixture.major_emergency = FALSE
		fixture.update(FALSE)
		fixture.switchcount = switches
	riot_lights = null

/// One half of the strobe: bright red, then dim red
/datum/outpost_prison/proc/strobe_step()
	strobe_timer = null
	if(QDELETED(src) || !riot_lights_on)
		return
	strobe_bright = !strobe_bright
	for(var/datum/weakref/light_ref as anything in riot_lights)
		var/obj/machinery/light/fixture = light_ref.resolve()
		if(!fixture || !fixture.on || fixture.status != LIGHT_OK || !fixture.major_emergency)
			continue
		fixture.set_light(l_power = strobe_bright ? fixture.bulb_power : PRISON_STROBE_DIM)
	strobe_timer = addtimer(CALLBACK(src, PROC_REF(strobe_step)), PRISON_STROBE_INTERVAL, TIMER_STOPPABLE | TIMER_DELETE_ME)

// ===== ADMIN HOOKS =====

/// A rat on a cell block floor, for the admin panel. Returns the rat, or null.
/datum/outpost_prison/proc/spawn_rat()
	return null

#undef PRISON_CONDITIONS_REFRESH_SECONDS
