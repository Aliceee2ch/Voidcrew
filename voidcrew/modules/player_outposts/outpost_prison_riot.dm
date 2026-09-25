/**
 * # Prison trouble, the wing's side
 *
 * Tension is 100 minus the mean mood of the prisoners in the cell block, plus spikes from events
 * (staff hitting someone, a fight, a power cut, the lights going out, someone beaten or killed by
 * staff) that decay over a couple of minutes. It sets the wing's stage:
 * - calm, below PRISON_TENSION_GRUMBLING;
 * - grumbling: complaints, pacing, banging on doors;
 * - restless: shouting at staff, gathering in the yard, threats;
 * - riot: tension held at PRISON_TENSION_RIOT for PRISON_RIOT_HOLD seconds, or a spark while
 *   restless (power cut, lights out, a prisoner beaten down or killed by staff).
 *
 * In a riot the wing's lights strobe red (driven here, not by the fire alarm, so no firelocks
 * drop), an alarm sounds and the outpost is told. Rioters pull shivs, go for staff, smash the
 * wing's fixtures and now and then the doors out. A rioter who is stunned or beaten drops the
 * shiv and calms down. The riot is over when no rioter is on their feet outside a bolted cell.
 * Left for PRISON_RIOT_BREAKOUT_TIME it turns into a breakout: the rioters go all out for the
 * exits.
 *
 * The cell block is everything prisoners can reach from the cells without passing a staff door or
 * a serving hatch, worked out once when the wing is placed. A prisoner outside it on their own
 * feet has escaped: they go loose on the outpost patrol AI and have OUTPOST_PRISON_LOOSE_TIME
 * seconds outside it before they are gone for good, which fines the treasury. Dragged back into
 * the cell block while down, they are recaptured.
 *
 * Tests turn trouble_enabled off to test the quiet side of the prison on its own.
 */

/// Minimum time between escape announcements, so a mass breakout is one message
#define PRISON_ESCAPE_ANNOUNCE_GAP (20 SECONDS)

/datum/outpost_prison
	/// Whether moods turn into trouble: threats, fights, riots, escapes, collapses
	var/trouble_enabled = TRUE
	/// 0 to 100, as of the last tick
	var/tension = 0
	/// Tension from recent events, decaying
	var/tension_spike = 0
	/// PRISON_STAGE_CALM, _GRUMBLING, _RESTLESS or _RIOT
	var/stage = PRISON_STAGE_CALM
	/// Seconds tension has been at riot level
	var/riot_hold = 0
	/// A riot is on
	var/riot_active = FALSE
	/// The riot has turned into a breakout
	var/breaking_out = FALSE
	/// Seconds the riot has lasted
	var/riot_elapsed = 0
	/// Rioters got out: an escape alarm reads as a breakout until they are dealt with
	var/broke_out = FALSE
	/// Seconds to the next riot alarm
	var/alarm_left = 0
	/// Fights going on, /datum/outpost_prison_fight
	var/list/fights = list()
	/// Seconds to the next look for a fight
	var/fight_check_left = PRISONER_FIGHT_CHECK
	/// The cell block: turf = TRUE, for every tile inside it and the fixtures along its edge
	var/list/cell_block = list()
	/// Red strobe state
	var/riot_lights_on = FALSE
	var/strobe_bright = TRUE
	var/strobe_timer
	/// Weakrefs to the lights the strobe drives
	var/list/riot_lights
	COOLDOWN_DECLARE(escape_announce_cooldown)

// ===== THE CELL BLOCK =====

/**
 * Floods out from the cells across everything prisoners could walk, whatever the bolts, stopping
 * at staff doors and at anything solid. Solid tiles along the edge (windows, the serving hatches,
 * doors) are part of it; the tiles past them are not.
 */
/datum/outpost_prison/proc/refresh_cell_block()
	var/list/found = list()
	var/list/queue = list()
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		for(var/turf/tile as anything in cell.turfs)
			if(!found[tile])
				found[tile] = TRUE
				queue += tile
	var/index = 1
	while(index <= length(queue))
		var/turf/current = queue[index++]
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || found[next] || next.loc != wing || isclosedturf(next))
				continue
			found[next] = TRUE
			if(cell_block_passable(next))
				queue += next
	cell_block = found

/// Whether the cell block flood carries on through a tile
/datum/outpost_prison/proc/cell_block_passable(turf/tile)
	for(var/atom/movable/thing as anything in tile)
		if(istype(thing, /obj/machinery/door/airlock/security/prison_staff))
			return FALSE
		if(istype(thing, /obj/machinery/door) || ismob(thing))
			continue
		if(thing.density)
			return FALSE
	return TRUE

/// Whether something is in the cell block. A wing without cells has no cell block to leave.
/datum/outpost_prison/proc/in_cell_block(atom/thing)
	var/turf/tile = get_turf(thing)
	if(!tile)
		return FALSE
	return !length(cell_block) || cell_block[tile]

/// Whether a tile on the cell block's edge has the outside of the cell block beyond it
/datum/outpost_prison/proc/leads_out_of_cell_block(turf/tile)
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(tile, direction)
		if(beside && beside.loc == wing && !isclosedturf(beside) && !cell_block[beside])
			return TRUE
	return FALSE

/// The nearest free tile of the wing outside the cell block, for an admin breakout
/datum/outpost_prison/proc/outside_spot_near(atom/from)
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/open/tile in wing_turfs())
		if(cell_block[tile] || tile.is_blocked_turf(TRUE) || (locate(/obj/machinery/door) in tile))
			continue
		var/distance = get_dist(from, tile)
		if(distance < best_distance)
			best = tile
			best_distance = distance
	return best

// ===== TENSION AND STAGES =====

/datum/outpost_prison/proc/add_tension_spike(amount)
	tension_spike = clamp(tension_spike + amount, 0, 100)

/**
 * Something happened that sets the wing on edge. While the wing is restless it is also a spark,
 * and the riot starts.
 */
/datum/outpost_prison/proc/trouble_event(spike, reason)
	if(!length(prisoners))
		return FALSE
	add_tension_spike(spike)
	if(trouble_enabled && !riot_active && stage == PRISON_STAGE_RESTLESS)
		return start_riot(reason)
	return FALSE

/// Staff killed a prisoner: the worst spark there is
/datum/outpost_prison/proc/blame_death(mob/living/basic/outpost_prisoner/prisoner)
	if(prisoner.death_blamed)
		return FALSE
	prisoner.death_blamed = TRUE
	return trouble_event(PRISON_SPIKE_KILLED, "[prisoner.real_name] was killed by staff")

/// Power cuts and the lights going out, noticed when the condition scores are refreshed
/datum/outpost_prison/proc/note_condition_changes(old_lit, old_powered)
	if(old_powered && !powered_score)
		trouble_event(PRISON_SPIKE_POWER_CUT, "the power went out")
	else if(old_lit >= PRISON_DARK_BELOW && lit_score < PRISON_DARK_BELOW)
		trouble_event(PRISON_SPIKE_LIGHTS_OUT, "the lights went out")

/// 100 minus the mean mood of the prisoners in the cell block, plus the spike
/datum/outpost_prison/proc/compute_tension()
	var/total = 0
	var/count = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.phase != PRISONER_PRESENT || prisoner.stat == DEAD || prisoner.trouble == PRISONER_TROUBLE_LOOSE)
			continue
		total += prisoner.mood
		count++
	if(!count)
		return 0
	return clamp(100 - total / count + tension_spike, 0, 100)

/proc/outpost_prison_stage_for(tension)
	if(tension >= PRISON_TENSION_RESTLESS)
		return PRISON_STAGE_RESTLESS
	if(tension >= PRISON_TENSION_GRUMBLING)
		return PRISON_STAGE_GRUMBLING
	return PRISON_STAGE_CALM

/// Works out tension and the stage; tension held at riot level long enough starts a riot
/datum/outpost_prison/proc/update_stage(seconds)
	tension = compute_tension()
	if(riot_active)
		stage = PRISON_STAGE_RIOT
		riot_hold = 0
		return
	stage = outpost_prison_stage_for(tension)
	if(!trouble_enabled || tension < PRISON_TENSION_RIOT)
		riot_hold = 0
		return
	riot_hold += seconds
	if(riot_hold >= PRISON_RIOT_HOLD)
		start_riot("tension boiled over")

/**
 * Advances trouble by `seconds`, after the prison's tick has moved needs and moods on: timers,
 * escapes and recaptures, the stage, the riot, fights and threats.
 */
/datum/outpost_prison/proc/trouble_tick(seconds)
	tension_spike = max(0, tension_spike - PRISON_SPIKE_DECAY * seconds)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners.Copy())
		if(QDELETED(prisoner) || prisoner.phase != PRISONER_PRESENT || prisoner.stat == DEAD)
			continue
		prisoner.trouble_counters(seconds)
	if(trouble_enabled)
		check_escapes(seconds)
	update_stage(seconds)
	if(!trouble_enabled)
		return
	riot_tick(seconds)
	fights_tick(seconds)
	threats_tick(seconds)

/// A prisoner's own trouble timers
/mob/living/basic/outpost_prisoner/proc/trouble_counters(seconds)
	threat_cooldown = max(0, threat_cooldown - seconds)
	fight_cooldown = max(0, fight_cooldown - seconds)
	if(swing_ref)
		swing_left -= seconds
		var/mob/living/target = swing_ref.resolve()
		if(swing_left <= 0 || !target || target.stat == DEAD)
			swing_ref = null
			swing_left = 0
	if(beaten_left > 0)
		beaten_left -= seconds
		if(beaten_left <= 0 || health_factor() > PRISONER_RECOVER_ABOVE)
			recover()
	if(climb_ref)
		climb_tick(seconds)

// ===== THREATS =====

/// Unhappy prisoners square up to staff near them in the cell block, then maybe swing
/datum/outpost_prison/proc/threats_tick(seconds)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.phase != PRISONER_PRESENT || prisoner.trouble || !prisoner.trouble_can_act() || !in_cell_block(prisoner))
			prisoner.cancel_threat()
			continue
		if(prisoner.threat_ref)
			var/mob/living/person = prisoner.threat_ref.resolve()
			if(!is_outpost_prison_staff(person) || get_dist(prisoner, person) > PRISONER_THREAT_RANGE || !in_cell_block(person) || prisoner.mood >= PRISONER_THREAT_MOOD)
				prisoner.cancel_threat()
				continue
			prisoner.face_atom(person)
			prisoner.threat_left -= seconds
			if(prisoner.threat_left <= 0)
				prisoner.decide_swing(person)
			continue
		if(prisoner.swing_ref || prisoner.threat_cooldown > 0 || prisoner.mood >= PRISONER_THREAT_MOOD)
			continue
		var/mob/living/nearby = prisoner.staff_nearby(PRISONER_THREAT_RANGE)
		if(nearby)
			prisoner.threaten(nearby)

// ===== FIGHTS =====

/// Two prisoners squaring off: an argument, then blows
/datum/outpost_prison_fight
	var/datum/outpost_prison/prison
	var/mob/living/basic/outpost_prisoner/first
	var/mob/living/basic/outpost_prisoner/second
	/// Past the argument: blows are being thrown
	var/fighting = FALSE
	/// Seconds of arguing left, and to the next line
	var/argue_left = PRISONER_ARGUE_TIME
	var/line_left = 0
	var/first_speaks = TRUE
	/// Seconds it has lasted
	var/elapsed = 0

/datum/outpost_prison_fight/New(datum/outpost_prison/owner, mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	. = ..()
	prison = owner
	first = one
	second = two

/datum/outpost_prison_fight/Destroy()
	if(first?.fight == src)
		first.fight = null
	if(second?.fight == src)
		second.fight = null
	first = null
	second = null
	prison = null
	return ..()

/datum/outpost_prison_fight/proc/opponent_of(mob/living/basic/outpost_prisoner/fighter)
	if(fighter == first)
		return second
	if(fighter == second)
		return first
	return null

/// Still up for it: awake, on their feet, in this fight
/datum/outpost_prison_fight/proc/fighter_ok(mob/living/basic/outpost_prisoner/fighter)
	return !QDELETED(fighter) && fighter.stat == CONSCIOUS && fighter.phase == PRISONER_PRESENT && fighter.fight == src && fighter.trouble == PRISONER_TROUBLE_FIGHT && !fighter.can_be_dragged()

/// The argument, then the fight. FALSE once it is over.
/datum/outpost_prison_fight/proc/tick(seconds)
	if(!fighter_ok(first) || !fighter_ok(second))
		return FALSE
	elapsed += seconds
	if(elapsed >= PRISONER_FIGHT_MAX_TIME)
		return FALSE
	if(fighting)
		return TRUE
	argue_left -= seconds
	line_left -= seconds
	if(line_left <= 0)
		line_left = 3
		var/mob/living/basic/outpost_prisoner/speaker = first_speaks ? first : second
		var/mob/living/basic/outpost_prisoner/listener = opponent_of(speaker)
		first_speaks = !first_speaks
		speaker.face_atom(listener)
		speaker.say_context("fight_argue", listener)
	if(argue_left <= 0)
		fighting = TRUE
		first.manual_emote("goes for [second]!")
	return TRUE

/// Starts a fight between two prisoners, telling everyone in sight. Returns the fight, or null.
/datum/outpost_prison/proc/start_fight(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	if(!trouble_enabled || one == two || one.fight || two.fight || riot_active)
		return null
	var/datum/outpost_prison_fight/brawl = new(src, one, two)
	fights += brawl
	for(var/mob/living/basic/outpost_prisoner/fighter as anything in list(one, two))
		fighter.cancel_threat()
		fighter.end_activity()
		fighter.stand_up()
		fighter.trouble = PRISONER_TROUBLE_FIGHT
		fighter.fight = brawl
	one.face_atom(two)
	two.face_atom(one)
	add_tension_spike(PRISON_SPIKE_FIGHT)
	for(var/mob/living/basic/outpost_prisoner/onlooker in prisoners)
		if(onlooker == one || onlooker == two || onlooker.stat != CONSCIOUS || onlooker.phase != PRISONER_PRESENT)
			continue
		if((onlooker in view(7, one)) || (onlooker in view(7, two)))
			onlooker.adjust_mood(-PRISONER_MOOD_SAW_FIGHT)
	add_log("[one.real_name] and [two.real_name] got into a fight.")
	return brawl

/datum/outpost_prison/proc/end_fight(datum/outpost_prison_fight/brawl)
	if(QDELETED(brawl))
		return
	fights -= brawl
	for(var/mob/living/basic/outpost_prisoner/fighter as anything in list(brawl.first, brawl.second))
		if(QDELETED(fighter))
			continue
		if(fighter.fight == brawl)
			fighter.fight = null
		if(fighter.trouble == PRISONER_TROUBLE_FIGHT)
			fighter.trouble = null
		fighter.fight_cooldown = PRISONER_FIGHT_COOLDOWN
		fighter.update_bubble()
	qdel(brawl)

/// Whether they are angry enough, free and able to start a fight
/mob/living/basic/outpost_prisoner/proc/can_start_fight()
	return prison && mood < PRISONER_FIGHT_MOOD && !in_trouble() && fight_cooldown <= 0 && trouble_can_act() && prison.in_cell_block(src)

/datum/outpost_prison/proc/fights_tick(seconds)
	for(var/datum/outpost_prison_fight/brawl as anything in fights.Copy())
		if(!brawl.tick(seconds))
			end_fight(brawl)
	if(riot_active)
		return
	fight_check_left -= seconds
	if(fight_check_left > 0)
		return
	fight_check_left = PRISONER_FIGHT_CHECK
	try_start_fight()

/// Two angry prisoners close enough to each other may start one. At most one new fight per look.
/datum/outpost_prison/proc/try_start_fight()
	var/list/angry = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.phase == PRISONER_PRESENT && prisoner.can_start_fight())
			angry += prisoner
	for(var/i in 1 to length(angry) - 1)
		var/mob/living/basic/outpost_prisoner/one = angry[i]
		for(var/j in i + 1 to length(angry))
			var/mob/living/basic/outpost_prisoner/two = angry[j]
			if(get_dist(one, two) > PRISONER_FIGHT_RANGE || !one.walkable?[get_turf(two)])
				continue
			if(prob(PRISONER_FIGHT_CHANCE))
				return start_fight(one, two)
	return null

// ===== RIOTS =====

/// Whether they are shut in a cell with its door bolted
/mob/living/basic/outpost_prisoner/proc/in_bolted_cell()
	var/datum/outpost_prison_cell/holding = prison?.cell_at(get_turf(src))
	return holding?.is_bolted()

/**
 * Whether they can join a riot now. Not from a bolted cell: a riot that nobody can take out of a
 * cell would be over as soon as it began, so they bang on the door and shout instead.
 */
/mob/living/basic/outpost_prisoner/proc/can_join_riot()
	return prison && stat == CONSCIOUS && phase == PRISONER_PRESENT && !can_be_dragged() && beaten_left <= 0 && !climb_ref && (!trouble || trouble == PRISONER_TROUBLE_FIGHT) && prison.in_cell_block(src) && !in_bolted_cell()

/// Who joins a riot: everyone below PRISON_RIOT_JOIN_MOOD (or everyone able, for an admin riot), else the unhappiest alone
/datum/outpost_prison/proc/riot_candidates(everyone = FALSE)
	var/list/joining = list()
	var/mob/living/basic/outpost_prisoner/unhappiest
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(!prisoner.can_join_riot())
			continue
		if(everyone || prisoner.mood < PRISON_RIOT_JOIN_MOOD)
			joining += prisoner
		if(!unhappiest || prisoner.mood < unhappiest.mood)
			unhappiest = prisoner
	if(!length(joining) && unhappiest)
		joining += unhappiest
	return joining

/// Starts a riot. `everyone` pulls in every prisoner able to riot, as the admin button does.
/datum/outpost_prison/proc/start_riot(reason, everyone = FALSE)
	if(!trouble_enabled || riot_active)
		return FALSE
	var/list/joining = riot_candidates(everyone)
	if(!length(joining))
		return FALSE
	for(var/datum/outpost_prison_fight/brawl as anything in fights.Copy())
		end_fight(brawl)
	riot_active = TRUE
	breaking_out = FALSE
	riot_elapsed = 0
	riot_hold = 0
	stage = PRISON_STAGE_RIOT
	var/shouts = 0
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in joining)
		rioter.start_rioting(shouts++ < 2)
	add_log("Riot in the yard: [length(joining)] prisoner\s.")
	log_game("PLAYER OUTPOST PRISON: riot at '[outpost?.name]' ([reason])")
	play_alarm()
	announce("Riot in the prison wing!", SHIP_NOTIFY_DANGER)
	update_riot_lights()
	return TRUE

/// Joins the riot: a shiv out, everything else dropped
/mob/living/basic/outpost_prisoner/proc/start_rioting(shout = TRUE)
	cancel_threat()
	end_activity()
	stand_up()
	trouble = PRISONER_TROUBLE_RIOT
	riot_target_ref = null
	riot_target_hits = 0
	draw_shiv()
	update_bubble()
	if(shout)
		say_context("riot")

/datum/outpost_prison/proc/riot_tick(seconds)
	if(!riot_active)
		return
	riot_elapsed += seconds
	var/standing = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(!prisoner.is_rioting())
			continue
		if(prisoner.phase != PRISONER_PRESENT || prisoner.stat != CONSCIOUS || prisoner.can_be_dragged() || prisoner.in_bolted_cell())
			continue
		standing++
	if(!standing)
		end_riot()
		return
	if(!breaking_out && riot_elapsed >= PRISON_RIOT_BREAKOUT_TIME)
		begin_breakout()
	alarm_left -= seconds
	if(alarm_left <= 0)
		play_alarm()

/// Nobody is left rioting on their feet: anyone still holding out in a bolted cell gives up
/datum/outpost_prison/proc/end_riot()
	if(!riot_active)
		return
	riot_active = FALSE
	breaking_out = FALSE
	riot_elapsed = 0
	riot_hold = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.is_rioting())
			prisoner.calm_down()
	stage = outpost_prison_stage_for(compute_tension())
	if(loose_count())
		add_log("The rioters are out of the cell block.")
	else
		add_log("The riot is over.")
		announce("The riot in the prison wing is over.", SHIP_NOTIFY_NOTICE)
	update_riot_lights()

/// The riot went on too long: the rioters go all out for the exits
/datum/outpost_prison/proc/begin_breakout()
	breaking_out = TRUE
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.trouble != PRISONER_TROUBLE_RIOT)
			continue
		prisoner.trouble = PRISONER_TROUBLE_BREAKOUT
		prisoner.riot_target_ref = null
		prisoner.riot_target_hits = 0
	add_log("The riot is turning into a breakout.")
	announce("The prison riot is turning into a breakout!", SHIP_NOTIFY_DANGER)

/// A serving hatch left open on both sides that this prisoner can reach from the yard side
/datum/outpost_prison/proc/open_hatch_for(mob/living/basic/outpost_prisoner/prisoner)
	for(var/obj/structure/table/reinforced/prison_hatch/hatch in fixtures_of("hatch"))
		if(QDELETED(hatch) || !hatch.both_sides_open())
			continue
		var/turf/yard_side = hatch.yard_side_turf()
		if(yard_side && prisoner.walkable?[yard_side])
			return hatch
	return null

/**
 * What a rioter goes for: staff they can get to, then an open hatch to climb, then the fixture or
 * door they were already smashing, then a new one.
 */
/mob/living/basic/outpost_prisoner/proc/riot_target()
	if(!prison)
		return null
	if(!reachable)
		prison.refresh_prisoner_reach(src)
	var/mob/living/person = staff_in_reach()
	if(person)
		return person
	var/obj/structure/table/reinforced/prison_hatch/open_hatch = prison.open_hatch_for(src)
	if(open_hatch)
		return open_hatch
	var/atom/current = riot_target_ref?.resolve()
	if(current && prison.still_smashable(current, src) && (trouble == PRISONER_TROUBLE_BREAKOUT || riot_target_hits < PRISON_RIOT_TARGET_HITS))
		return current
	var/atom/next = prison.pick_smash_target(src)
	riot_target_ref = next ? WEAKREF(next) : null
	riot_target_hits = 0
	return next

/// The nearest member of staff in sight that they can get to
/mob/living/basic/outpost_prisoner/proc/staff_in_reach()
	var/mob/living/nearest
	var/nearest_distance = INFINITY
	for(var/mob/living/person in view(7, src))
		if(!is_outpost_prison_staff(person) || !reachable?[get_turf(person)])
			continue
		var/distance = get_dist(src, person)
		if(distance < nearest_distance)
			nearest = person
			nearest_distance = distance
	return nearest

/// Whether a rioter's target is still worth hitting
/datum/outpost_prison/proc/still_smashable(atom/target, mob/living/basic/outpost_prisoner/rioter)
	if(QDELETED(target) || !rioter.reachable?[get_turf(target)] || LAZYACCESS(rioter.riot_skips, REF(target)) > world.time)
		return FALSE
	if(istype(target, /obj/machinery/light))
		var/obj/machinery/light/fixture = target
		return fixture.status != LIGHT_BROKEN
	if(istype(target, /obj/structure/table/reinforced/prison_hatch))
		var/obj/structure/table/reinforced/prison_hatch/hatch = target
		return !hatch.both_sides_open()
	if(istype(target, /obj/machinery/door))
		var/obj/machinery/door/door = target
		return door.density
	return TRUE

/**
 * A new fixture or door for a rioter. Fixtures: lights, tables, and windows inside the cell block.
 * Exits: doors they cannot open, and, once breaking out, serving hatches and the windows that lead
 * out of the cell block. Windows in the wing's outer wall are left alone.
 */
/datum/outpost_prison/proc/pick_smash_target(mob/living/basic/outpost_prisoner/rioter)
	var/breakout = rioter.trouble == PRISONER_TROUBLE_BREAKOUT
	var/list/exits = list()
	var/list/fixture_list = list()
	for(var/turf/tile as anything in rioter.reachable)
		var/walkable = rioter.walkable?[tile]
		for(var/obj/thing in tile)
			if(QDELETED(thing) || LAZYACCESS(rioter.riot_skips, REF(thing)) > world.time)
				continue
			if(istype(thing, /obj/machinery/door/airlock))
				if(thing.density && !walkable)
					exits += thing
			else if(istype(thing, /obj/structure/table/reinforced/prison_hatch))
				if(breakout)
					exits += thing
			else if(istype(thing, /obj/machinery/light))
				var/obj/machinery/light/fixture = thing
				if(fixture.status != LIGHT_BROKEN)
					fixture_list += fixture
			else if(istype(thing, /obj/structure/table))
				fixture_list += thing
			else if(istype(thing, /obj/structure/window) || istype(thing, /obj/structure/grille))
				if(on_wing_edge(tile))
					continue
				if(leads_out_of_cell_block(tile))
					if(breakout)
						exits += thing
				else
					fixture_list += thing
	if(breakout)
		if(length(exits))
			var/atom/nearest
			var/nearest_distance = INFINITY
			for(var/atom/exit as anything in exits)
				var/distance = get_dist(rioter, exit)
				if(distance < nearest_distance)
					nearest = exit
					nearest_distance = distance
			return nearest
		return length(fixture_list) ? pick(fixture_list) : null
	if(length(exits) && (!length(fixture_list) || prob(PRISON_RIOT_DOOR_CHANCE)))
		return pick(exits)
	return length(fixture_list) ? pick(fixture_list) : null

// ===== LIGHTS, ALARM, ANNOUNCEMENTS =====

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

/// Where the wing's alarm sounds from: the warden's console, or the middle of the wing
/datum/outpost_prison/proc/alarm_turf()
	var/list/turfs = wing_turfs()
	for(var/turf/tile as anything in turfs)
		if(locate(/obj/machinery/computer/outpost_prison_warden) in tile)
			return tile
	return length(turfs) ? turfs[round(length(turfs) / 2) + 1] : null

/datum/outpost_prison/proc/play_alarm()
	alarm_left = PRISON_RIOT_ALARM_GAP
	var/turf/source = alarm_turf()
	if(source)
		playsound(source, 'sound/announcer/alarm/bloblarm.ogg', 50, FALSE, 8)

/// Tells everyone on the outpost and the owner's crew
/datum/outpost_prison/proc/announce(message, level = SHIP_NOTIFY_WARNING)
	if(QDELETED(outpost))
		return
	outpost.ship_notify(message, "PRISON", level, 'voidcrew/sound/notify.ogg', 50)

/// Prisoners on the patrol AI, still in the wing's custody
/datum/outpost_prison/proc/loose_count()
	var/count = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.trouble == PRISONER_TROUBLE_LOOSE && prisoner.phase == PRISONER_PRESENT && prisoner.stat != DEAD)
			count++
	return count

/// The warden console's alarm banner: list(alarm, text). Someone loose beats a riot.
/datum/outpost_prison/proc/alarm_state()
	var/loose = loose_count()
	if(loose)
		return list(broke_out ? "breakout" : "escape", "[loose] prisoner[loose == 1 ? "" : "s"] loose")
	if(riot_active)
		return breaking_out ? list("breakout", "Prisoners breaking out") : list("riot", "Riot in the yard")
	return list(null, null)

// ===== ESCAPES =====

/**
 * Anyone outside the cell block on their own feet has escaped. The loose count down outside it;
 * one who is down inside it again is recaptured.
 */
/datum/outpost_prison/proc/check_escapes(seconds)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners.Copy())
		if(QDELETED(prisoner) || prisoner.phase != PRISONER_PRESENT || prisoner.stat == DEAD)
			continue
		var/inside = in_cell_block(prisoner)
		if(prisoner.trouble == PRISONER_TROUBLE_LOOSE)
			if(inside)
				if(prisoner.can_be_dragged())
					recapture(prisoner)
				continue
			prisoner.loose_left -= seconds
			if(prisoner.loose_left <= 0)
				escaped_for_good(prisoner)
			continue
		if(inside || prisoner.climb_ref || prisoner.stat != CONSCIOUS || prisoner.can_be_dragged() || prisoner.pulledby)
			continue
		prisoner_escaped(prisoner)

/**
 * Out of the cell block: loose on the outpost patrol AI, with the clock running. `breakout` marks
 * it as part of a breakout even if they were not rioting (the admin button).
 */
/datum/outpost_prison/proc/prisoner_escaped(mob/living/basic/outpost_prisoner/prisoner, breakout = FALSE)
	if(prisoner.trouble == PRISONER_TROUBLE_LOOSE)
		return FALSE
	var/from_riot = breakout || prisoner.is_rioting()
	if(prisoner.fight)
		end_fight(prisoner.fight)
	if(from_riot)
		broke_out = TRUE
	prisoner.go_loose()
	add_log("[prisoner.real_name] escaped the cell block.")
	prisoner.say_context(from_riot ? "breakout" : "escape")
	if(COOLDOWN_FINISHED(src, escape_announce_cooldown))
		COOLDOWN_START(src, escape_announce_cooldown, PRISON_ESCAPE_ANNOUNCE_GAP)
		announce(from_riot ? "Prisoners are breaking out of the prison wing!" : "A prisoner has escaped the prison wing's cell block!", SHIP_NOTIFY_DANGER)
		var/turf/source = alarm_turf()
		if(source)
			playsound(source, 'sound/machines/warning-buzzer.ogg', 60, FALSE, 6)
	update_riot_lights()
	return TRUE

/// Goes loose: the outpost patrol AI takes over, and the clock starts
/mob/living/basic/outpost_prisoner/proc/go_loose()
	end_activity()
	stand_up()
	stop_climb()
	cancel_threat()
	riot_target_ref = null
	riot_target_hits = 0
	if(held_item && !has_shiv())
		drop_held_item()
	trouble = PRISONER_TROUBLE_LOOSE
	loose_left = OUTPOST_PRISON_LOOSE_TIME
	obj_damage = PRISONER_LOOSE_OBJ_DAMAGE
	update_melee()
	update_bubble()
	// The outpost patrol AI (voidcrew/modules/npc_ships/code/outpost_patrol.dm)
	swap_basic_ai_controller(src, /datum/ai_controller/basic_controller/outpost_breakout)
	assign_mob_to_outpost_patrol(src, prison?.outpost)

/// Back in the cell block, down: in custody again, in a foul mood
/datum/outpost_prison/proc/recapture(mob/living/basic/outpost_prisoner/prisoner)
	if(prisoner.trouble != PRISONER_TROUBLE_LOOSE)
		return FALSE
	prisoner.back_in_custody()
	add_log("[prisoner.real_name] was recaptured.")
	if(!loose_count() && !riot_active)
		broke_out = FALSE
	update_riot_lights()
	return TRUE

/mob/living/basic/outpost_prisoner/proc/back_in_custody()
	clear_outpost_patrol(src)
	trouble = null
	loose_left = 0
	obj_damage = initial(obj_damage)
	drop_shiv()
	set_mood(PRISONER_RECAPTURED_MOOD)
	swap_basic_ai_controller(src, /datum/ai_controller/basic_controller/outpost_prisoner)
	prison?.refresh_prisoner_reach(src)
	update_melee()
	update_bubble()
	say_context("recaptured")

/// Loose too long: gone for good. No bonus, and the treasury pays a fine, as much of it as it holds.
/datum/outpost_prison/proc/escaped_for_good(mob/living/basic/outpost_prisoner/prisoner)
	var/fine = charge_fine(OUTPOST_PRISON_ESCAPE_FINE, "Prison escape fine: [prisoner.real_name]")
	add_log("[prisoner.real_name] got away. Fined [fine] cr.")
	announce("[prisoner.real_name] has escaped custody. The outpost was fined [fine] cr.", SHIP_NOTIFY_WARNING)
	if(prisoner.has_shiv())
		qdel(prisoner.held_item)
	prisoner.beam_out()
	if(!loose_count() && !riot_active)
		broke_out = FALSE
	update_riot_lights()
	return fine

/// Takes up to `amount` from the outpost treasury. Returns what was taken.
/datum/outpost_prison/proc/charge_fine(amount, reason)
	if(QDELETED(outpost))
		return 0
	outpost.ensure_home_services()
	var/datum/bank_account/treasury = outpost.treasury
	var/fine = min(amount, treasury?.account_balance)
	if(fine <= 0 || !treasury.adjust_money(-fine, reason))
		return 0
	return fine

// ===== TURRETS =====

/**
 * Interim rule until guards and turrets are designed: outpost turrets leave prisoners in their
 * wing alone, rioting or not, and treat a loose prisoner outside the wing as fair game.
 */
/mob/living/basic/outpost_prisoner/proc/turret_target()
	if(stat == DEAD || trouble != PRISONER_TROUBLE_LOOSE || phase != PRISONER_PRESENT)
		return FALSE
	return !prison || get_area(src) != prison.wing

/proc/is_loose_outpost_prisoner(mob/living/creature)
	var/mob/living/basic/outpost_prisoner/prisoner = creature
	return istype(prisoner) && prisoner.turret_target()

// ===== SERVING HATCH =====

/obj/structure/table/reinforced/prison_hatch
	/// Blows rioters have landed on it since it last gave
	var/forcing = 0

/// Where someone climbing over from the yard comes down: the tile beyond the staff side
/obj/structure/table/reinforced/prison_hatch/proc/staff_side_turf()
	var/obj/machinery/door/window/staff_door = staff_windoor()
	if(staff_door)
		return get_step(src, staff_door.dir)
	var/obj/machinery/door/window/yard_door = yard_windoor()
	return yard_door ? get_step(src, REVERSE_DIR(yard_door.dir)) : null

/// A rioter working at it. After PRISON_HATCH_FORCE_HITS blows both window doors give and stay open.
/obj/structure/table/reinforced/prison_hatch/proc/take_forcing()
	playsound(src, 'sound/effects/glass/glassbash.ogg', 50, TRUE)
	for(var/obj/machinery/door/window/windoor in loc)
		windoor.Shake(1, 1, 0.3 SECONDS)
	if(++forcing < PRISON_HATCH_FORCE_HITS)
		return FALSE
	forcing = 0
	force_open()
	return TRUE

/// Both window doors open, and they stay open until someone shuts them
/obj/structure/table/reinforced/prison_hatch/proc/force_open()
	visible_message(span_danger("The window doors of [src] are forced open!"))
	for(var/obj/machinery/door/window/windoor in loc)
		windoor.autoclose = FALSE
		if(windoor.density)
			INVOKE_ASYNC(windoor, TYPE_PROC_REF(/obj/machinery/door/window, open), BYPASS_DOOR_CHECKS)

#undef PRISON_ESCAPE_ANNOUNCE_GAP
