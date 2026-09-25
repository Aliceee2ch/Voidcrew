/**
 * # Outpost prison
 *
 * The running side of a placed prison wing, created by the prison upgrade's on_installed().
 * The wing has one cell per prisoner. While intake is open, prisoners beam one at a time into
 * empty cells. Each prisoner in the wing earns the outpost treasury OUTPOST_PRISON_BASE_PAY a
 * minute, scaled by how well they are kept (care) and how well the wing is kept (conditions); see
 * the pay model in voidcrew/_DEFINES/outpost_prison_economy.dm. At the end of a sentence the
 * prisoner heads back to their cell, beams out and a release bonus is paid.
 *
 * This file holds the wing itself, its cells, supplies and furniture, claims, speech and the
 * clock. The rest of the prison lives beside it:
 * - outpost_prison_economy.dm: pay, fines, intake, arrivals, releases, deaths;
 * - outpost_prison_warden.dm: the warden's console and its data;
 * - outpost_prison_conditions.dm: the clean, lit and powered scores and the riot strobe;
 * - outpost_prison_containment.dm: reach, the cell block, confinement and wing members;
 * - outpost_prison_doors.dm: the wing's doors and bolt buttons;
 * - outpost_prison_prisoner.dm and outpost_prison_routine.dm: the prisoners, their needs and days;
 * - outpost_prison_trouble.dm and outpost_prison_riot.dm: mood, fights, riots and escapes;
 * - outpost_prison_experiments.dm: the researcher's experiments.
 *
 * Everything that advances with time goes through tick(seconds), which process() calls every
 * second, so tests can advance a prison by minutes in one call. The random mess prisoners leave,
 * drips of blood and what they say come from process() alone. Beams run on timers.
 */

GLOBAL_LIST_EMPTY(outpost_prisons)

/// How often prisoners whose AI is asleep help themselves to supplies, in seconds
#define PRISON_SUPPLY_REFRESH_SECONDS 5
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
	/// Warden console log, newest first: list(list("time", "text"))
	var/list/entries = list()
	/// Seconds since prisoners whose AI is asleep last helped themselves to supplies
	var/supply_clock = 0
	/// The wing's furniture by category ("bed", "stool", "hoop", ...), refreshed with the condition scores
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
	if(upgrade?.prison == src)
		upgrade.prison = null
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

// ===== SUPPLIES AND FURNITURE =====

/// Advances supplies by `seconds`: every PRISON_SUPPLY_REFRESH_SECONDS, prisoners whose AI is asleep help themselves
/datum/outpost_prison/proc/supply_tick(seconds)
	supply_clock += seconds
	if(supply_clock < PRISON_SUPPLY_REFRESH_SECONDS)
		return
	supply_clock = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		prisoner.fend_for_self()

/// What the serving hatches hold: list("meals", "clean_suits", "dirty_suits", "capacity", "lasts_minutes")
/datum/outpost_prison/proc/hatch_stock()
	return list(
		"meals" = 0,
		"clean_suits" = 0,
		"dirty_suits" = 0,
		"capacity" = 0,
		"lasts_minutes" = null,
	)

/// Whether someone is waiting at a serving hatch that has nothing they need
/datum/outpost_prison/proc/hatch_shortage()
	return FALSE

/// Fills every serving hatch, meals first, then clean uniforms. For the admin panel.
/datum/outpost_prison/proc/fill_hatches()
	return

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
 * Advances the prison by `seconds`, in a fixed order: who is home, the condition scores, reach,
 * supplies; then for each prisoner body collection, pay and sentence, needs, confinement, mood,
 * and release; then trouble (outpost_prison_riot.dm), experiments, arrivals and deposits.
 * Prisoners who are fighting earn nothing; rioting or loose, they earn nothing and their sentence
 * stops. Each part keeps its own cadence inside its own tick proc; keep this order as it is.
 */
/datum/outpost_prison/proc/tick(seconds)
	presence_tick(seconds)
	conditions_tick(seconds)
	containment_tick(seconds)
	supply_tick(seconds)
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
			accrue_pay(prisoner, served)
			prisoner.sentence_left -= served
		prisoner.adjust_needs(seconds)
		update_locked_in(prisoner, seconds)
		prisoner.drift_mood(seconds)
		if(serving)
			check_release(prisoner)
	trouble_tick(seconds)
	experiments_tick(seconds)
	intake_tick(seconds)
	pay_tick(seconds)

// ===== COMINGS AND GOINGS =====

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
	var/datum/outpost_prison_cell/emptied = prisoner.cell
	if(emptied?.occupant == prisoner)
		emptied.occupant = null
	prisoner.cell = null
	prisoner.prison = null
	for(var/key in claims.Copy())
		if(claims[key] == prisoner)
			claims -= key
	on_cell_emptied(emptied, prisoner.stat == DEAD)

/datum/outpost_prison/proc/add_log(text)
	entries = list(list("time" = station_time_timestamp("hh:mm"), "text" = text)) + entries
	if(length(entries) > OUTPOST_PRISON_LOG_LENGTH)
		entries.Cut(OUTPOST_PRISON_LOG_LENGTH + 1)
	log_game("PLAYER OUTPOST PRISON: '[outpost?.name]': [text]")

// ===== CELL =====

/// One cell of a prison wing: its door, its bed, the tiles inside and who lives there
/datum/outpost_prison_cell
	var/number = 0
	var/datum/outpost_prison/prison
	var/datum/weakref/door_ref
	/// Where the door stood, so a door rebuilt there is still the cell's
	var/turf/door_turf
	var/datum/weakref/bed_ref
	/// The tiles inside, and the same as a set (turf = TRUE)
	var/list/turfs
	var/list/turf_set
	/// The prisoner who owns it
	var/mob/living/basic/outpost_prisoner/occupant
	/// world.time from which the cell may take a new arrival
	var/ready_at = 0

/datum/outpost_prison_cell/New(datum/outpost_prison/owner, obj/machinery/door/airlock/security/glass/outpost_prison_cell/door, list/inside)
	. = ..()
	prison = owner
	number = door.cell_number
	door_ref = WEAKREF(door)
	door_turf = get_turf(door)
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
	door_turf = null
	turfs = null
	turf_set = null
	return ..()

/// The cell's door: the one it was found with, or any airlock since built where it stood
/datum/outpost_prison_cell/proc/door()
	var/obj/machinery/door/airlock/door = door_ref?.resolve()
	if(door)
		return door
	for(var/obj/machinery/door/airlock/rebuilt in door_turf)
		if(!QDELETED(rebuilt))
			return rebuilt
	return null

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

#undef PRISON_SUPPLY_REFRESH_SECONDS
#undef PRISON_CELL_MAX_TILES
