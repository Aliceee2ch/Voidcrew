/**
 * # Outpost prison
 *
 * The running side of a placed prison wing, created by the prison upgrade's on_installed().
 * The wing has one cell per prisoner. While intake is open, prisoners beam one at a time into
 * empty cells. Each prisoner in the wing earns the outpost treasury OUTPOST_PRISON_BASE_PAY a
 * minute, scaled by how well they are kept (care) and how well the wing is kept (conditions); see
 * the pay model in voidcrew/_DEFINES/player_outposts.dm. At the end of a sentence the prisoner
 * heads back to their cell, beams out and a release bonus is paid.
 *
 * Everything that advances with time goes through tick(seconds), which process() calls every
 * second, so tests can advance a prison by minutes in one call. The random mess prisoners leave,
 * drips of blood and what they say come from process() alone. Beams run on timers.
 */

GLOBAL_LIST_EMPTY(outpost_prisons)

/// How often the condition scores, the wing's furniture and the prisoners' reach are refreshed, in seconds
#define PRISON_REFRESH_SECONDS 5
/// The largest a cell's inside can be, in tiles
#define PRISON_CELL_MAX_TILES 16

/datum/outpost_prison
	var/datum/outpost_upgrade/prison/upgrade
	var/obj/structure/overmap/dynamic/player_outpost/outpost
	var/area/voidcrew/player_outpost/prison/wing
	var/list/mob/living/basic/outpost_prisoner/prisoners = list()
	/// The wing's cells, in number order
	var/list/datum/outpost_prison_cell/cells = list()
	var/capacity = OUTPOST_PRISON_CAPACITY
	var/intake_open = FALSE
	/// Seconds until the next prisoner beams in, or null while none is due
	var/arrival_countdown
	/// Seconds into the current pay minute
	var/pay_clock = 0
	/// Credits earned and not yet deposited; deposits are whole credits, once a minute
	var/pay_owed = 0
	/// Everything this prison has paid into the treasury
	var/paid_total = 0
	/// Warden console log, newest first: list(list("time", "text"))
	var/list/entries = list()
	/// Condition scores, 0 to 100
	var/clean_score = 100
	var/lit_score = 100
	var/powered_score = 100
	/// Seconds since the scores were refreshed
	var/refresh_clock = 0
	/// The wing's furniture by category ("bed", "stool", "hoop", ...), refreshed with the scores
	var/list/fixtures = list()
	/// REF() of anything a prisoner is using -> that prisoner
	var/list/claims = list()
	COOLDOWN_DECLARE(wing_speech_cooldown)

/datum/outpost_prison/New(datum/outpost_upgrade/prison/owner)
	. = ..()
	upgrade = owner
	outpost = owner.outpost
	wing = owner.installed_area
	wing.prison = src
	GLOB.outpost_prisons += src
	find_cells()
	refresh_cell_block()
	refresh_conditions()
	START_PROCESSING(SSprocessing, src)

/datum/outpost_prison/Destroy()
	STOP_PROCESSING(SSprocessing, src)
	GLOB.outpost_prisons -= src
	set_riot_lights(FALSE)
	QDEL_LIST(fights)
	if(wing?.prison == src)
		wing.prison = null
	var/list/leaving = prisoners
	prisoners = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in leaving)
		prisoner.prison = null
		prisoner.cell = null
	QDEL_LIST(leaving)
	QDEL_LIST(cells)
	claims.Cut()
	fixtures.Cut()
	cell_block.Cut()
	upgrade = null
	outpost = null
	wing = null
	return ..()

// ===== THE WING =====

/// Every tile of the placed wing
/datum/outpost_prison/proc/wing_turfs()
	var/list/bounds = upgrade?.footprint_bounds
	if(!bounds || !wing)
		return list()
	var/list/turfs = list()
	for(var/turf/tile as anything in block(bounds[1], bounds[2], bounds[5], bounds[3], bounds[4], bounds[5]))
		if(tile.loc == wing)
			turfs += tile
	return turfs

/// Whether the wing's APC gives its machines power
/datum/outpost_prison/proc/is_powered()
	return !!wing?.powered(AREA_USAGE_EQUIP)

/// Cells free for a new arrival
/datum/outpost_prison/proc/free_slots()
	var/free = 0
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(!cell.occupant)
			free++
	return min(free, max(0, capacity - length(prisoners)))

/// The furniture of one category, as of the last refresh
/datum/outpost_prison/proc/fixtures_of(category)
	var/list/found = fixtures[category]
	return found || list()

// ===== CELLS =====

/**
 * Finds the wing's cells from its numbered cell doors: the inside of a cell is the small room on
 * the side of its door that has a bed. Works at any rotation.
 */
/datum/outpost_prison/proc/find_cells()
	QDEL_LIST(cells)
	var/list/found = list()
	for(var/turf/tile as anything in wing_turfs())
		var/obj/machinery/door/airlock/security/glass/outpost_prison_cell/door = locate() in tile
		if(!door)
			continue
		var/list/inside = cell_inside(door)
		if(inside)
			found += new /datum/outpost_prison_cell(src, door, inside)
	// Number order; unnumbered or clashing doors take the next free number.
	var/list/taken = list()
	for(var/datum/outpost_prison_cell/cell as anything in found)
		if(cell.number < 1 || taken["[cell.number]"])
			cell.number = 0
		else
			taken["[cell.number]"] = TRUE
	var/next_number = 1
	for(var/datum/outpost_prison_cell/cell as anything in found)
		if(cell.number)
			continue
		while(taken["[next_number]"])
			next_number++
		cell.number = next_number
		taken["[next_number]"] = TRUE
	while(length(found))
		var/datum/outpost_prison_cell/lowest = found[1]
		for(var/datum/outpost_prison_cell/cell as anything in found)
			if(cell.number < lowest.number)
				lowest = cell
		found -= lowest
		cells += lowest

/// The tiles inside the cell `door` closes, or null
/datum/outpost_prison/proc/cell_inside(obj/machinery/door/door)
	var/turf/door_turf = get_turf(door)
	for(var/direction in GLOB.cardinals)
		var/turf/start = get_step(door_turf, direction)
		if(!start || start.loc != wing || !prisoner_can_stand(start) || (locate(/obj/machinery/door) in start))
			continue
		var/list/room = list(start)
		var/list/seen = list()
		seen[start] = TRUE
		seen[door_turf] = TRUE
		var/index = 1
		var/too_big = FALSE
		while(index <= length(room))
			var/turf/current = room[index++]
			for(var/step_dir in GLOB.cardinals)
				var/turf/next = get_step(current, step_dir)
				if(!next || seen[next])
					continue
				seen[next] = TRUE
				if(next.loc != wing || !prisoner_can_stand(next) || (locate(/obj/machinery/door) in next))
					continue
				room += next
				if(length(room) > PRISON_CELL_MAX_TILES)
					too_big = TRUE
					break
			if(too_big)
				break
		if(too_big)
			continue
		for(var/turf/tile as anything in room)
			if(locate(/obj/structure/bed) in tile)
				return room
	return null

/datum/outpost_prison/proc/cell_by_number(number)
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(cell.number == number)
			return cell
	return null

/// The cell a tile is inside, if any
/datum/outpost_prison/proc/cell_at(turf/tile)
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(cell.turf_set[tile])
			return cell
	return null

/// Who owns this bed, if it is a cell's bed with someone in the cell
/datum/outpost_prison/proc/bed_owner(obj/structure/bed/bed)
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(cell.bed() == bed)
			return cell.occupant
	return null

/**
 * Bolts or unbolts a cell's door. An open door is closed first, and only bolted once it shuts.
 * Returns FALSE if the cell has no door.
 */
/datum/outpost_prison/proc/toggle_cell_bolts(number, mob/user)
	var/datum/outpost_prison_cell/cell = cell_by_number(number)
	var/obj/machinery/door/airlock/door = cell?.door()
	if(!door)
		return FALSE
	if(door.locked)
		door.unbolt()
	else if(door.density)
		door.bolt()
	else
		INVOKE_ASYNC(src, PROC_REF(close_and_bolt), door)
	log_game("PLAYER OUTPOST PRISON: [key_name(user)] toggled the bolts of cell [number] at '[outpost?.name]'")
	refresh_reach()
	return TRUE

/datum/outpost_prison/proc/close_and_bolt(obj/machinery/door/airlock/door)
	if(!door.close())
		return
	door.bolt()
	refresh_reach()

// ===== CONDITIONS =====

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
	// A power cut or the lights going out puts the wing on edge (outpost_prison_riot.dm).
	note_condition_changes(old_lit, old_powered)

/// Whether a tile is on the outside edge of the wing, so a window there looks out
/datum/outpost_prison/proc/on_wing_edge(turf/tile)
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(tile, direction)
		if(!beside || beside.loc != wing)
			return TRUE
	return FALSE

/// Conditions, 0 to 100: the mean of the clean, lit and powered scores
/datum/outpost_prison/proc/conditions_score()
	return (clean_score + lit_score + powered_score) / 3

/**
 * Whether a prisoner could stand on this tile. Cell doors open for them unless bolted or
 * unpowered; staff doors never do.
 */
/datum/outpost_prison/proc/prisoner_can_stand(turf/tile)
	if(isclosedturf(tile))
		return FALSE
	for(var/atom/movable/thing as anything in tile)
		if(istype(thing, /obj/machinery/door/airlock/security/prison_staff))
			return FALSE
		if(istype(thing, /obj/machinery/door/airlock))
			var/obj/machinery/door/airlock/airlock = thing
			if(airlock.density && (airlock.locked || airlock.welded || !airlock.hasPower()))
				return FALSE
			continue
		if(istype(thing, /obj/machinery/door) || ismob(thing))
			continue
		if(thing.density)
			return FALSE
	return TRUE

/// Refreshes where every prisoner can walk and reach
/datum/outpost_prison/proc/refresh_reach()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		refresh_prisoner_reach(prisoner)

/**
 * Floods out from a prisoner to the ground they can walk on, then adds each tile beside it
 * (tables, the serving hatch). Items on those tiles are the ones they can go and pick up; food
 * seen through the office windows is not.
 */
/datum/outpost_prison/proc/refresh_prisoner_reach(mob/living/basic/outpost_prisoner/prisoner)
	var/list/walked = list()
	var/list/reach = list()
	var/turf/start = get_turf(prisoner)
	if(start?.loc == wing)
		var/list/queue = list(start)
		walked[start] = TRUE
		var/index = 1
		while(index <= length(queue))
			var/turf/current = queue[index++]
			for(var/direction in GLOB.cardinals)
				var/turf/next = get_step(current, direction)
				if(!next || walked[next] || next.loc != wing || !prisoner_can_stand(next))
					continue
				walked[next] = TRUE
				queue += next
		for(var/turf/standing as anything in walked)
			reach[standing] = TRUE
			for(var/direction in GLOB.cardinals)
				var/turf/beside = get_step(standing, direction)
				if(beside?.loc == wing)
					reach[beside] = TRUE
	prisoner.walkable = walked
	prisoner.reachable = reach

/**
 * The nearest thing a prisoner can reach that they want: food, or a cleaner uniform when
 * `want_uniform` is set. Things another prisoner is already fetching are left alone.
 */
/datum/outpost_prison/proc/find_supply(mob/living/basic/outpost_prisoner/prisoner, want_uniform = FALSE)
	if(!prisoner.reachable)
		refresh_prisoner_reach(prisoner)
	var/obj/item/best
	var/best_distance = INFINITY
	for(var/turf/spot as anything in prisoner.reachable)
		for(var/obj/item/thing in spot)
			if(want_uniform ? !prisoner.would_change_into(thing) : !istype(thing, /obj/item/food))
				continue
			if(claimed_by_other(thing, prisoner))
				continue
			var/distance = get_dist(prisoner, thing)
			if(distance < best_distance)
				best = thing
				best_distance = distance
	return best

/// A basketball the prisoner can get at: loose within reach, or in another player's hands
/datum/outpost_prison/proc/find_ball(mob/living/basic/outpost_prisoner/prisoner)
	if(!prisoner.reachable)
		refresh_prisoner_reach(prisoner)
	for(var/turf/spot as anything in prisoner.reachable)
		var/obj/item/toy/basketball/ball = locate() in spot
		if(ball)
			return ball
	for(var/mob/living/basic/outpost_prisoner/other in prisoners)
		if(istype(other.held_item, /obj/item/toy/basketball) && prisoner.walkable?[get_turf(other)])
			return other.held_item
	return null

/// The nearest book lying about within reach, not on a shelf
/datum/outpost_prison/proc/find_loose_book(mob/living/basic/outpost_prisoner/prisoner)
	if(!prisoner.reachable)
		refresh_prisoner_reach(prisoner)
	var/obj/item/book/best
	var/best_distance = INFINITY
	for(var/turf/spot as anything in prisoner.reachable)
		for(var/obj/item/book/book in spot)
			if(claimed_by_other(book, prisoner))
				continue
			var/distance = get_dist(prisoner, book)
			if(distance < best_distance)
				best = book
				best_distance = distance
	return best

/// The mess table a stool faces, or failing that any table beside it
/datum/outpost_prison/proc/table_beside(obj/structure/chair/stool)
	var/turf/ahead = get_step(stool, stool.dir)
	if(is_mess_table(ahead))
		return ahead
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(stool, direction)
		if(is_mess_table(beside))
			return beside
	return null

/datum/outpost_prison/proc/is_mess_table(turf/tile)
	if(!tile || tile.loc != wing)
		return FALSE
	for(var/obj/structure/table/table in tile)
		if(!istype(table, /obj/structure/table/reinforced/prison_hatch))
			return TRUE
	return FALSE

/// Whether a prisoner other than `except` is doing an activity of this type
/datum/outpost_prison/proc/anyone_doing(activity_type, mob/living/basic/outpost_prisoner/except)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner != except && istype(prisoner.activity, activity_type))
			return TRUE
	return FALSE

// ===== CLAIMS =====

/// Reserves `thing` for `prisoner`. FALSE if someone else is using it.
/datum/outpost_prison/proc/claim(atom/thing, mob/living/basic/outpost_prisoner/prisoner)
	if(claimed_by_other(thing, prisoner))
		return FALSE
	claims[REF(thing)] = prisoner
	return TRUE

/// The prisoner using `thing`, if any
/datum/outpost_prison/proc/claimant(atom/thing)
	var/mob/living/basic/outpost_prisoner/holder = claims[REF(thing)]
	if(QDELETED(holder) || !holder.activity)
		return null
	return holder

/datum/outpost_prison/proc/claimed_by_other(atom/thing, mob/living/basic/outpost_prisoner/prisoner)
	var/mob/living/basic/outpost_prisoner/holder = claimant(thing)
	return holder && holder != prisoner

// ===== SPEECH =====

/// Whether the wing is quiet enough for a new spontaneous line
/datum/outpost_prison/proc/wing_can_speak()
	return COOLDOWN_FINISHED(src, wing_speech_cooldown)

/datum/outpost_prison/proc/note_speech()
	COOLDOWN_START(src, wing_speech_cooldown, OUTPOST_PRISON_SPEECH_GAP)

// ===== TIME =====

/datum/outpost_prison/process(seconds_per_tick)
	if(QDELETED(outpost) || !wing)
		return
	tick(seconds_per_tick)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.phase != PRISONER_PRESENT)
			continue
		prisoner.maybe_drip(seconds_per_tick)
		if(prisoner.stat != CONSCIOUS)
			continue
		if(prisoner.trouble != PRISONER_TROUBLE_LOOSE && SPT_PROB(OUTPOST_PRISON_MESS_CHANCE / 60, seconds_per_tick))
			prisoner.make_mess()
		// Nobody on the level, nobody to hear it.
		if(prisoner.ai_controller?.ai_status == AI_STATUS_ON)
			prisoner.speech_tick()

/**
 * Advances the prison by `seconds`: pay and sentences first, on the state at the start of the
 * step, then needs, moods, releases, body collection, trouble (outpost_prison_riot.dm), arrivals
 * and the minute's deposit. Prisoners who are fighting earn nothing; rioting or loose, they earn
 * nothing and their sentence stops.
 */
/datum/outpost_prison/proc/tick(seconds)
	refresh_clock += seconds
	if(refresh_clock >= PRISON_REFRESH_SECONDS)
		refresh_clock = 0
		refresh_conditions()
		for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
			prisoner.fend_for_self()
	var/conditions = conditions_score() / 100
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners.Copy())
		if(QDELETED(prisoner) || prisoner.phase != PRISONER_PRESENT)
			continue
		if(prisoner.stat == DEAD)
			prisoner.body_pickup_left -= seconds
			if(prisoner.body_pickup_left <= 0)
				collect(prisoner)
			continue
		var/serving = prisoner.serving_sentence()
		if(serving)
			var/served = min(seconds, prisoner.sentence_left)
			var/care = prisoner.earning_pay() ? prisoner.care() / 100 : 0
			pay_owed += OUTPOST_PRISON_BASE_PAY * care * conditions * served / 60
			prisoner.served_seconds += served
			prisoner.kept_seconds += care * conditions * served
			prisoner.sentence_left -= served
		prisoner.adjust_needs(seconds)
		var/datum/outpost_prison_cell/holding = cell_at(get_turf(prisoner))
		if(holding?.is_bolted())
			prisoner.locked_in_seconds += seconds
		else
			prisoner.locked_in_seconds = 0
		prisoner.drift_mood(seconds)
		if(!serving)
			continue
		if(prisoner.sentence_left <= 0)
			release(prisoner)
		else if(prisoner.sentence_left <= OUTPOST_PRISON_RELEASE_WALK && !istype(prisoner.activity, /datum/prisoner_activity/go_home) && !prisoner.in_trouble())
			// Time to head back to the cell; the routine picks this up.
			prisoner.end_activity()

	trouble_tick(seconds)

	if(intake_open && free_slots())
		if(isnull(arrival_countdown))
			arrival_countdown = rand(OUTPOST_PRISON_REFILL_MIN, OUTPOST_PRISON_REFILL_MAX)
		arrival_countdown -= seconds
		while(arrival_countdown <= 0 && free_slots() && is_powered())
			if(!admit_next())
				break
			arrival_countdown += rand(OUTPOST_PRISON_ARRIVAL_GAP_MIN, OUTPOST_PRISON_ARRIVAL_GAP_MAX)
		arrival_countdown = free_slots() ? max(arrival_countdown, 0) : null
	else
		arrival_countdown = null

	pay_clock += seconds
	while(pay_clock >= 60)
		pay_clock -= 60
		deposit_pay()

// ===== MONEY =====

/// Pays the outpost treasury. Returns TRUE if it was paid.
/datum/outpost_prison/proc/pay_treasury(amount, reason)
	if(amount <= 0 || QDELETED(outpost))
		return FALSE
	outpost.ensure_home_services()
	if(!outpost.treasury?.adjust_money(amount, reason))
		return FALSE
	paid_total += amount
	return TRUE

/// Deposits the whole credits owed; the fraction waits for next minute
/datum/outpost_prison/proc/deposit_pay()
	// The epsilon keeps float error from turning 32 owed into 31.99999 and a credit short.
	var/whole = round(pay_owed + 0.001)
	if(whole >= 1 && pay_treasury(whole, "Prison wing stipend"))
		pay_owed -= whole
		return whole
	return 0

/// What a prisoner earns the treasury per minute right now
/datum/outpost_prison/proc/prisoner_pay_rate(mob/living/basic/outpost_prisoner/prisoner)
	if(prisoner.stat == DEAD || prisoner.phase != PRISONER_PRESENT || !prisoner.earning_pay())
		return 0
	return OUTPOST_PRISON_BASE_PAY * prisoner.care() / 100 * conditions_score() / 100

/// What every prisoner earns the treasury per minute right now
/datum/outpost_prison/proc/pay_rate()
	var/total = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		total += prisoner_pay_rate(prisoner)
	return total

// ===== COMINGS AND GOINGS =====

/datum/outpost_prison/proc/set_intake(open, mob/user)
	open = !!open
	if(open == intake_open)
		return
	intake_open = open
	arrival_countdown = (intake_open && free_slots()) ? OUTPOST_PRISON_FIRST_ARRIVAL : null
	if(user)
		log_game("PLAYER OUTPOST: [key_name(user)] [intake_open ? "opened" : "closed"] prison intake at '[outpost?.name]'")

/// Beams a new prisoner into the lowest-numbered empty cell. Returns them, or null.
/datum/outpost_prison/proc/admit_next()
	if(!free_slots())
		return null
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(cell.occupant)
			continue
		var/turf/spot = cell.arrival_turf()
		if(!spot)
			continue
		var/mob/living/basic/outpost_prisoner/prisoner = new(spot)
		admit(prisoner, cell)
		prisoner.beam_in()
		return prisoner
	return null

/// Books a prisoner into a cell (the first free one when none is given)
/datum/outpost_prison/proc/admit(mob/living/basic/outpost_prisoner/prisoner, datum/outpost_prison_cell/into)
	if(!into)
		for(var/datum/outpost_prison_cell/cell as anything in cells)
			if(!cell.occupant)
				into = cell
				break
	prisoner.prison = src
	prisoners |= prisoner
	if(into)
		into.occupant = prisoner
		prisoner.cell = into
	prisoner.sentence_left = rand(OUTPOST_PRISON_SENTENCE_MIN, OUTPOST_PRISON_SENTENCE_MAX)
	refresh_prisoner_reach(prisoner)
	add_log("[prisoner.real_name] arrived in cell [into ? into.number : "-"], [round(prisoner.sentence_left / 60)] min sentence.")

/// Sentence served: pays the release bonus and beams the prisoner out of wherever they stand
/datum/outpost_prison/proc/release(mob/living/basic/outpost_prisoner/prisoner)
	if(prisoner.phase != PRISONER_PRESENT || prisoner.stat == DEAD)
		return 0
	var/average = prisoner.served_seconds ? prisoner.kept_seconds / prisoner.served_seconds : 0
	var/bonus = round(OUTPOST_PRISON_RELEASE_BONUS * average)
	pay_treasury(bonus, "Prison release: [prisoner.real_name]")
	add_log("[prisoner.real_name] released, +[bonus] cr.")
	prisoner.say_context("release")
	prisoner.beam_out()
	return bonus

/datum/outpost_prison/proc/on_prisoner_death(mob/living/basic/outpost_prisoner/prisoner)
	prisoner.body_pickup_left = OUTPOST_PRISON_CORPSE_PICKUP
	add_log("[prisoner.real_name] died.")
	prisoner.died_at = world.time
	prisoner.clear_trouble()
	if(prisoner.staff_to_blame())
		blame_death(prisoner)
	if(!loose_count() && !riot_active)
		broke_out = FALSE
	update_riot_lights()

/// The corrections service takes a body away
/datum/outpost_prison/proc/collect(mob/living/basic/outpost_prisoner/prisoner)
	prisoner.beam_out()

/// Drops a prisoner from the roster and their cell, and starts refilling it
/datum/outpost_prison/proc/forget(mob/living/basic/outpost_prisoner/prisoner)
	if(!(prisoner in prisoners))
		return
	if(prisoner.fight)
		end_fight(prisoner.fight)
	if(prisoner.trouble == PRISONER_TROUBLE_LOOSE)
		clear_outpost_patrol(prisoner)
	prisoners -= prisoner
	if(!loose_count() && !riot_active)
		broke_out = FALSE
	update_riot_lights()
	if(prisoner.cell?.occupant == prisoner)
		prisoner.cell.occupant = null
	prisoner.cell = null
	prisoner.prison = null
	for(var/key in claims.Copy())
		if(claims[key] == prisoner)
			claims -= key
	if(intake_open && isnull(arrival_countdown))
		arrival_countdown = rand(OUTPOST_PRISON_REFILL_MIN, OUTPOST_PRISON_REFILL_MAX)

/datum/outpost_prison/proc/add_log(text)
	entries = list(list("time" = station_time_timestamp("hh:mm"), "text" = text)) + entries
	if(length(entries) > OUTPOST_PRISON_LOG_LENGTH)
		entries.Cut(OUTPOST_PRISON_LOG_LENGTH + 1)
	log_game("PLAYER OUTPOST PRISON: '[outpost?.name]': [text]")

// ===== WARDEN CONSOLE DATA =====

/// Prisoners in cell order, then any without a cell
/datum/outpost_prison/proc/roster_order()
	var/list/ordered = list()
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(cell.occupant && (cell.occupant in prisoners))
			ordered += cell.occupant
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		ordered |= prisoner
	return ordered

/datum/outpost_prison/proc/conditions_payload()
	return list(
		"clean" = clean_score,
		"lit" = lit_score,
		"powered" = powered_score,
		"score" = round(conditions_score()),
	)

/// The warden console's ui_data (OutpostPrison.tsx)
/datum/outpost_prison/proc/ui_payload(mob/user)
	var/list/roster = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in roster_order())
		roster += list(list(
			"ref" = REF(prisoner),
			"name" = prisoner.real_name,
			"cell" = prisoner.cell?.number || 0,
			"crime" = prisoner.crime,
			"sentence_left" = prisoner.stat == DEAD ? 0 : max(0, round(prisoner.sentence_left)),
			"status" = prisoner.console_status(),
		))
	var/list/alarm = alarm_state()
	return list(
		"linked" = TRUE,
		"powered" = is_powered(),
		"intake_open" = intake_open,
		"next_arrival" = (intake_open && !isnull(arrival_countdown)) ? round(arrival_countdown) : null,
		"capacity" = capacity,
		"pay_rate" = round(pay_rate(), 0.1),
		"paid_total" = paid_total,
		"can_manage" = !!outpost?.can_manage(user),
		"conditions" = conditions_payload(),
		"prisoners" = roster,
		"log" = entries.Copy(),
		"alarm" = alarm[1],
		"alarm_text" = alarm[2],
	)

// ===== CELL =====

/// One cell of a prison wing: its door, its bed, the tiles inside and who lives there
/datum/outpost_prison_cell
	var/number = 0
	var/datum/outpost_prison/prison
	var/datum/weakref/door_ref
	var/datum/weakref/bed_ref
	/// The tiles inside, and the same as a set (turf = TRUE)
	var/list/turfs
	var/list/turf_set
	/// The prisoner who owns it
	var/mob/living/basic/outpost_prisoner/occupant

/datum/outpost_prison_cell/New(datum/outpost_prison/owner, obj/machinery/door/airlock/security/glass/outpost_prison_cell/door, list/inside)
	. = ..()
	prison = owner
	number = door.cell_number
	door_ref = WEAKREF(door)
	turfs = inside
	turf_set = list()
	for(var/turf/tile as anything in inside)
		turf_set[tile] = TRUE
		var/obj/structure/bed/bed = locate() in tile
		if(bed && !bed_ref)
			bed_ref = WEAKREF(bed)

/datum/outpost_prison_cell/Destroy()
	if(occupant?.cell == src)
		occupant.cell = null
	occupant = null
	prison = null
	turfs = null
	turf_set = null
	return ..()

/datum/outpost_prison_cell/proc/door()
	return door_ref?.resolve()

/// The cell's bed, while it is still inside the cell
/datum/outpost_prison_cell/proc/bed()
	var/obj/structure/bed/bed = bed_ref?.resolve()
	return (bed && turf_set[get_turf(bed)]) ? bed : null

/datum/outpost_prison_cell/proc/contains(atom/thing)
	return !!turf_set[get_turf(thing)]

/datum/outpost_prison_cell/proc/is_bolted()
	var/obj/machinery/door/airlock/door = door()
	return !!door?.locked

/// Where a new prisoner materialises: beside their bed, or anywhere inside
/datum/outpost_prison_cell/proc/arrival_turf()
	var/obj/structure/bed/bed = bed()
	if(bed)
		return get_turf(bed)
	return length(turfs) ? turfs[1] : null

#undef PRISON_REFRESH_SECONDS
#undef PRISON_CELL_MAX_TILES
