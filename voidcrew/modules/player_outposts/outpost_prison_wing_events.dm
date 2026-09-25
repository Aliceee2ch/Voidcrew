/**
 * # Prison wing events
 *
 * The wing's fixtures fail now and then, however well it is kept (owner, 2026-09-25):
 * - Blown lights: PRISON_WING_LIGHTS_MIN to _MAX working lights in the cell block burst, with tg's
 *   usual breaking glass and sparks. Lit falls until someone replaces the tubes, and a restless
 *   wing that goes dark gets the usual lights-out spark (outpost_prison_conditions.dm).
 * - A vent backs up: a Kessler vent (outpost_prison_vents.dm), or a tg vent or scrubber, in the
 *   cell block gurgles for PRISON_WING_GURGLE_TIME, then spews filth over the open floor around it.
 *   Clean falls until it is mopped. Welding a tg vent shut while it gurgles stops it.
 * - A cell toilet overflows: the same gurgle, then that cell's floor is wet for a while and a
 *   little dirty. The water only slips people who run, and prisoners never slip.
 * One comes every PRISON_WING_EVENT_GAP_MIN to _MAX seconds of crew-home time, while there are
 * prisoners in the wing and nothing else is going on (no riot, nobody loose, no experiment). Each is
 * logged on the warden console and shows in the wing, and prisoners who see it say something and
 * step out of the mess. None of them fines anyone. Numbers in
 * voidcrew/_DEFINES/outpost_prison_incidents.dm.
 *
 * Only fixtures in the cell block take part, so vents built in the office never soak up a backup,
 * and nothing outside the wing is touched.
 */

/// What a backed-up vent brings up, by weight: types the mess scan counts (outpost_prison_conditions.dm)
GLOBAL_LIST_INIT(outpost_prison_vent_filth, list(
	/obj/effect/decal/cleanable/dirt = 3,
	/obj/effect/decal/cleanable/vomit/outpost_sludge = 2,
))

/datum/outpost_prison
	/// Whether wing events happen at all; the tests' prison fixture turns them off
	var/wing_events_enabled = TRUE
	/// Seconds of crew-home time before the next wing event; set on the first tick
	var/wing_event_left
	/// "vent" or "toilet" while one gurgles, what is gurgling, and the seconds left
	var/wing_event_pending
	var/datum/weakref/wing_event_source_ref
	var/wing_event_gurgle_left = 0
	/// Tests only: the kind a random wing event takes
	var/wing_event_force_kind

// ===== THE CLOCK =====

/// Why the wing events' clock is not running now, in a few words for the admin panel, or null when it is
/datum/outpost_prison/proc/wing_event_clock_paused()
	if(!wing_events_enabled)
		return "off"
	if(!crew_home())
		return "nobody home"
	if(wing_event_pending)
		return "one under way"
	if(riot_active || breaking_out)
		return "riot"
	if(loose_count())
		return "someone loose"
	if(experiment_active())
		return "experiment"
	if(!wildcard_prisoner_count())
		return "no prisoners"
	return null

/// Advances a gurgle under way and the clock by `seconds`; the extras' tick calls it
/datum/outpost_prison/proc/wing_events_tick(seconds)
	if(wing_event_pending)
		gurgle_tick(seconds)
		return
	if(isnull(wing_event_left))
		wing_event_left = rand(PRISON_WING_EVENT_GAP_MIN, PRISON_WING_EVENT_GAP_MAX)
	if(wing_event_clock_paused())
		return
	wing_event_left -= seconds
	if(wing_event_left > 0)
		return
	wing_event_left = start_wing_event() ? rand(PRISON_WING_EVENT_GAP_MIN, PRISON_WING_EVENT_GAP_MAX) : PRISON_WING_EVENT_RETRY

/**
 * Starts a wing event of `kind` ("lights", "vent" or "toilet"), or one picked by weight among those
 * the wing has the fixtures for. A vent or toilet gurgles first. Returns the kind started, or null.
 */
/datum/outpost_prison/proc/start_wing_event(kind)
	if(wing_event_pending)
		return null
	kind = kind || wing_event_force_kind
	var/list/lights = blowable_lights()
	var/list/vents = backup_vents()
	var/list/toilets = cell_toilets()
	var/list/options = list()
	if(length(lights))
		options["lights"] = PRISON_WING_EVENT_WEIGHT_LIGHTS
	if(length(vents))
		options["vent"] = PRISON_WING_EVENT_WEIGHT_VENT
	if(length(toilets))
		options["toilet"] = PRISON_WING_EVENT_WEIGHT_TOILET
	if(kind)
		if(!options[kind])
			return null
		options = list((kind) = 1)
	switch(pick_weight(options))
		if("lights")
			return blow_lights(lights) ? "lights" : null
		if("vent")
			return begin_backup(pick(vents), "vent")
		if("toilet")
			return begin_backup(pick(toilets), "toilet")
	return null

/// Why an admin can't start a wing event of `kind` now, or null
/datum/outpost_prison/proc/wing_event_refusal(kind)
	if(wing_event_pending)
		return "Something is already backing up."
	switch(kind)
		if("lights")
			if(!length(blowable_lights()))
				return "No working light in the wing."
		if("vent")
			if(!length(backup_vents()))
				return "No vent in the cell block can back up."
		if("toilet")
			if(!length(cell_toilets()))
				return "No cell has a toilet."
	return null

/// An admin started one: the clock starts over, so the next does not follow straight after
/datum/outpost_prison/proc/wing_event_admin_started()
	wing_event_left = rand(PRISON_WING_EVENT_GAP_MIN, PRISON_WING_EVENT_GAP_MAX)

// ===== BLOWN LIGHTS =====

/// Working lights in the cell block, or failing that anywhere in the wing
/datum/outpost_prison/proc/blowable_lights()
	var/list/in_block = list()
	var/list/elsewhere = list()
	for(var/turf/tile as anything in wing_turfs())
		for(var/obj/machinery/light/fixture in tile)
			if(QDELETED(fixture) || fixture.status != LIGHT_OK)
				continue
			if(in_cell_block(fixture))
				in_block += fixture
			else
				elsewhere += fixture
	return length(in_block) ? in_block : elsewhere

/// PRISON_WING_LIGHTS_MIN to _MAX of `lights` burst, with glass and sparks. Returns how many.
/datum/outpost_prison/proc/blow_lights(list/lights)
	var/list/candidates = lights.Copy()
	var/count = min(rand(PRISON_WING_LIGHTS_MIN, PRISON_WING_LIGHTS_MAX), length(candidates))
	var/list/blown = list()
	for(var/i in 1 to count)
		var/obj/machinery/light/fixture = pick_n_take(candidates)
		fixture.break_light_tube()
		fixture.visible_message(span_warning("[fixture] pops and goes dark!"))
		blown += fixture
	if(!length(blown))
		return 0
	add_log(length(blown) == 1 ? "A light blew in the wing." : "[length(blown)] lights blew in the wing.")
	wing_event_react("wing_lights_blown", blown[1])
	return length(blown)

// ===== BACKED-UP VENTS AND TOILETS =====

/**
 * Vents in the cell block that can back up: the Kessler vents with their covers on and nothing in
 * the duct, and any tg vent or scrubber not welded shut
 */
/datum/outpost_prison/proc/backup_vents()
	var/list/found = list()
	for(var/turf/tile as anything in wing_turfs())
		if(!in_cell_block(tile))
			continue
		for(var/obj/thing in tile)
			if(!can_back_up(thing))
				continue
			if(istype(thing, /obj/structure/outpost_kessler_vent) || istype(thing, /obj/machinery/atmospherics/components/unary/vent_pump) || istype(thing, /obj/machinery/atmospherics/components/unary/vent_scrubber))
				found += thing
	return found

/// Whether a vent or toilet can back up now: not gone, not welded shut, not open, nothing in the duct
/datum/outpost_prison/proc/can_back_up(obj/thing)
	if(QDELETED(thing) || !isturf(thing.loc) || get_area(thing) != wing)
		return FALSE
	if(istype(thing, /obj/structure/outpost_kessler_vent))
		var/obj/structure/outpost_kessler_vent/kessler = thing
		return !kessler.open && !kessler.occupant && !kessler.wrenching
	if(istype(thing, /obj/machinery/atmospherics/components/unary))
		var/obj/machinery/atmospherics/components/unary/vent = thing
		return !vent.welded
	return TRUE

/// The toilets inside the cells
/datum/outpost_prison/proc/cell_toilets()
	var/list/found = list()
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		var/obj/structure/toilet/toilet = contraband_cistern(cell)
		if(toilet)
			found += toilet
	return found

/// `source` starts to gurgle; PRISON_WING_GURGLE_TIME later it backs up (finish_backup()). Returns `kind`.
/datum/outpost_prison/proc/begin_backup(obj/source, kind)
	wing_event_pending = kind
	wing_event_source_ref = WEAKREF(source)
	wing_event_gurgle_left = PRISON_WING_GURGLE_TIME
	playsound(source, 'sound/effects/bubbles/bubbles2.ogg', 50, TRUE)
	source.Shake(1, 0, 0.5 SECONDS)
	source.visible_message(span_warning(kind == "vent" ? "[source] gurgles and knocks." : "[source] gurgles. The water in the bowl is rising."))
	log_game("PLAYER OUTPOST PRISON: a [kind] started backing up in the prison wing at '[outpost?.name]'")
	return kind

/// The gurgle goes on, louder halfway, and then it backs up
/datum/outpost_prison/proc/gurgle_tick(seconds)
	var/before = wing_event_gurgle_left
	wing_event_gurgle_left -= seconds
	var/obj/source = wing_event_source_ref?.resolve()
	var/halfway = PRISON_WING_GURGLE_TIME / 2
	if(source && wing_event_gurgle_left > 0 && before > halfway && wing_event_gurgle_left <= halfway)
		playsound(source, 'sound/effects/bubbles/bubbles.ogg', 60, TRUE)
		source.Shake(1, 0, 0.5 SECONDS)
	if(wing_event_gurgle_left <= 0)
		finish_backup()

/// The gurgle is over: the vent spews or the toilet floods, unless it was welded shut or taken away meanwhile. Returns what it left.
/datum/outpost_prison/proc/finish_backup()
	var/obj/source = wing_event_source_ref?.resolve()
	var/kind = wing_event_pending
	wing_event_pending = null
	wing_event_source_ref = null
	wing_event_gurgle_left = 0
	if(!source || !can_back_up(source))
		if(source && !QDELETED(source))
			source.visible_message(span_notice("[source] goes quiet."))
		return 0
	return kind == "vent" ? vent_spew(source) : toilet_flood(source)

/**
 * Open floor of the cell block within `range` steps of `origin`, reached through open floor only:
 * never through walls, windows, shut doors or tables. `origin` itself always counts.
 */
/datum/outpost_prison/proc/backup_tiles(turf/origin, range)
	var/list/found = list()
	if(!isopenturf(origin))
		return found
	var/list/steps = list()
	steps[origin] = 0
	var/list/queue = list(origin)
	var/index = 1
	while(index <= length(queue))
		var/turf/current = queue[index++]
		if(current != origin && current.is_blocked_turf(exclude_mobs = TRUE))
			continue
		found += current
		if(steps[current] >= range)
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || !isnull(steps[next]) || next.loc != wing || !isopenturf(next) || !in_cell_block(next))
				continue
			steps[next] = steps[current] + 1
			queue += next
	return found

/**
 * A backed-up vent spews PRISON_VENT_MESS_MIN to _MAX pieces of filth over the open floor within
 * PRISON_VENT_MESS_RANGE steps, a tile each while there are tiles to spare, and it stinks. Returns
 * how many pieces were left.
 */
/datum/outpost_prison/proc/vent_spew(obj/vent)
	var/turf/origin = get_turf(vent)
	var/list/tiles = backup_tiles(origin, PRISON_VENT_MESS_RANGE)
	if(!length(tiles))
		return 0
	var/list/free = tiles.Copy()
	var/made = 0
	for(var/i in 1 to rand(PRISON_VENT_MESS_MIN, PRISON_VENT_MESS_MAX))
		if(!length(free))
			free = tiles.Copy()
		var/turf/tile = pick_n_take(free)
		var/filth_type = pick_weight(GLOB.outpost_prison_vent_filth)
		var/obj/effect/decal/cleanable/filth = new filth_type(tile)
		// The same filth twice on one tile merges into the first
		if(!QDELETED(filth))
			made++
	playsound(origin, 'sound/effects/splat.ogg', 60, TRUE)
	vent.visible_message(span_danger("[vent] backs up and spews filth across the floor!"))
	for(var/mob/living/nearby in view(PRISON_WING_EVENT_REACT_RANGE, origin))
		if(!HAS_TRAIT(nearby, TRAIT_ANOSMIA))
			to_chat(nearby, span_warning("A reek of sewage rolls out of [vent]."))
	add_log("A vent in the wing backed up and spewed filth.")
	wing_event_react("wing_vent_backup", vent, tiles)
	return made

/**
 * An overflowing cell toilet: the cell's floor goes wet for PRISON_TOILET_WET_TIME and gets a little
 * dirt. Only the cell floods. Returns how many tiles got wet.
 */
/datum/outpost_prison/proc/toilet_flood(obj/structure/toilet/toilet)
	var/datum/outpost_prison_cell/cell = cell_at(get_turf(toilet))
	var/list/floors = list()
	for(var/turf/open/floor in (cell ? cell.turfs : list(get_turf(toilet))))
		floors += floor
	for(var/turf/open/floor as anything in floors)
		floor.MakeSlippery(TURF_WET_WATER, min_wet_time = PRISON_TOILET_WET_TIME, wet_time_to_add = PRISON_TOILET_WET_TIME / 2)
	var/list/dirty = floors.Copy()
	for(var/i in 1 to rand(PRISON_TOILET_GRIME_MIN, PRISON_TOILET_GRIME_MAX))
		if(!length(dirty))
			break
		new /obj/effect/decal/cleanable/dirt(pick_n_take(dirty))
	playsound(toilet, 'sound/effects/splash.ogg', 50, TRUE)
	toilet.visible_message(span_warning("[toilet] overflows and floods the cell!"))
	add_log(cell ? "The toilet in cell [cell.number] overflowed." : "A toilet in the wing overflowed.")
	wing_event_react("wing_toilet_flood", toilet, floors)
	return length(floors)

// ===== THE YARD'S REACTION =====

/**
 * Prisoners who can see `source` react: up to PRISON_WING_EVENT_MAX_LINES of them say a `context`
 * line, and anyone standing in `tiles` (the filth or the water) leaves what they were idling at and
 * walks out of it.
 */
/datum/outpost_prison/proc/wing_event_react(context, atom/source, list/tiles)
	var/turf/origin = get_turf(source)
	if(!origin)
		return
	var/list/splashed = list()
	if(length(tiles))
		for(var/turf/tile as anything in tiles)
			splashed[tile] = TRUE
	var/lines = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in view(PRISON_WING_EVENT_REACT_RANGE, origin))
		if(prisoner.prison != src || prisoner.phase != PRISONER_PRESENT || prisoner.stat != CONSCIOUS || prisoner.in_trouble() || prisoner.activity?.sleeping)
			continue
		prisoner.face_atom(source)
		if(lines < PRISON_WING_EVENT_MAX_LINES && prisoner.say_context(context))
			lines++
		else if(length(splashed) && get_dist(prisoner, origin) <= 2)
			prisoner.manual_emote(pick("gags.", "covers [prisoner.p_their()] nose.", "backs off, grimacing."))
		if(splashed[get_turf(prisoner)])
			step_out_of_mess(prisoner, splashed)
	if(lines)
		note_speech()

/// Out of the mess: whatever idle thing they were doing there ends, and they walk to the nearest clean floor
/datum/outpost_prison/proc/step_out_of_mess(mob/living/basic/outpost_prisoner/prisoner, list/splashed)
	var/datum/prisoner_activity/current = prisoner.activity
	if(current && (!current.leisure || !current.interruptible))
		return FALSE
	if(!prisoner.routine_allowed())
		return FALSE
	if(!prisoner.walkable)
		refresh_prisoner_reach(prisoner)
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/tile in range(PRISON_VENT_MESS_RANGE + 1, prisoner))
		if(splashed[tile] || !prisoner.walkable?[tile] || prisoner.tile_taken(tile) || !prisoner.may_loiter(tile))
			continue
		var/distance = get_dist(prisoner, tile)
		if(distance < best_distance)
			best = tile
			best_distance = distance
	if(!best)
		return FALSE
	var/datum/prisoner_activity/wander/away = new(prisoner)
	away.spot = best
	prisoner.start_activity(away)
	return TRUE

// ===== CLEAN UP =====

/datum/outpost_prison/proc/wing_events_destroy()
	wing_event_pending = null
	wing_event_source_ref = null

// ===== THE FILTH =====

/// What a backed-up vent brings up. A kind of vomit to the mess scan: heavy mess.
/obj/effect/decal/cleanable/vomit/outpost_sludge
	name = "sludge"
	desc = "Thick grey-brown sludge that came up out of a vent. It smells exactly as bad as it looks."
	color = "#7a6a4f"
