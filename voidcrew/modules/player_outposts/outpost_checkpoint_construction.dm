/**
 * # Staged checkpoint reconstruction
 *
 * The saved ship is loaded once, through the ordinary template loader, into a hidden
 * reservation this job owns. Stock is scrubbed and parts are restored there, before any of
 * it can be reached. Its pieces then move into the permanent bay one tile visit at a time,
 * through the same per-atom shuttle move hooks a docking uses, so the finished hull is what
 * a normal landing would have left behind and departs the same way.
 *
 * Single pass: a visit is marked done before any of its pieces move, and nothing rescans
 * the bay. A piece that is removed, moved or damaged after placement stays that way. The
 * checkpoint is consumed inside the first visit, immediately before the first piece.
 */
/obj/structure/overmap/dynamic/player_outpost
	var/list/datum/checkpoint_construction/checkpoint_jobs = list()

/// One bay tile's share of one build stage.
/datum/checkpoint_visit
	var/stage
	/// Index into the paired source and bay turf lists.
	var/index
	/// This visit moves the tile's own deck or wall and its room.
	var/hull = FALSE
	var/list/datum/weakref/pieces = list()
	var/done = FALSE
	/// Distance band from the middle of the footprint; each stage grows outward.
	var/ring = 0
	var/obj/effect/checkpoint_build_drone/drone

/datum/checkpoint_construction
	var/state = CHECKPOINT_BUILD_PREPARING
	var/obj/structure/overmap/dynamic/player_outpost/home
	var/datum/outpost_berth/ship_bay/bay
	var/datum/ship_checkpoint/snapshot
	var/datum/weakref/panel_ref
	/// Only used to reapply console upgrade disks while the hidden copy is prepared.
	var/datum/weakref/operator_ref
	var/datum/weakref/original_ref
	var/captain_ckey
	var/ship_name
	var/datum/map_template/shuttle/voidcrew/commissioned/checkpoint/template
	/// The loaded copy. Its port joins the bay before the first piece does.
	var/obj/docking_port/mobile/voidcrew/port
	/// Holds every piece that has not been placed yet.
	var/datum/turf_reservation/source_reservation
	/// Paired by index, exactly as initiate_docking() pairs a move.
	var/list/turf/source_turfs
	var/list/turf/bay_turfs
	/// Indices of every tile belonging to the saved hull.
	var/list/hull_indices = list()
	var/rotation = 0
	var/source_dir
	var/move_dir
	var/list/movement_force = list("KNOCKDOWN" = 0, "THROW" = 0)
	/// Pending visits per stage, in build order.
	var/list/stage_visits
	/// Every visit that has run, in the order it ran.
	var/list/datum/checkpoint_visit/completed_visits = list()
	/// Bay tile -> the bay room it had, for every tile a visit gave to the ship.
	/// Removal reads this rather than the port, which may already be gone.
	var/list/placed_hull_tiles = list()
	/// The bay's own room under the landing rectangle, before any piece arrived.
	var/area/bay_area
	/// Where the docking port sits in the paired turf lists.
	var/port_index = 0
	/// The saving captain's own account: refunds, and funds for a hull nobody collected.
	var/datum/weakref/captain_account_ref
	/// Handover is irreversible and must never run twice.
	var/handover_started = FALSE
	var/stage = CHECKPOINT_STAGE_DECK
	var/visit_total = 0
	var/visits_done = 0
	var/committed = FALSE
	var/frame_done = FALSE
	/// Taken from the original's account at commitment, paid to the rebuilt ship.
	var/held_balance = 0
	var/obj/structure/overmap/ship/vessel
	var/list/markers = list()
	var/list/obj/effect/checkpoint_build_drone/drones = list()
	var/next_phase_at = 0
	var/last_progress_at = 0
	var/captain_wait_until = 0
	var/last_reported_percent = -1
	var/error
	/// Tests place visits directly instead of waiting for drones.
	var/manual = FALSE
	/// Set when drones stop making progress; remaining visits are then placed directly.
	var/direct_placement = FALSE
	/// Admin testing: direct placement with a larger per-tick budget.
	var/rushed = FALSE
	/// Ship room -> its own base lighting, list(colour, alpha), while floodlit for the build.
	var/list/lit_rooms = list()

/// leave_original: an admin copy of a hull that is still in service. It is not retired and
/// keeps its money; the checkpoint is still consumed.
/datum/checkpoint_construction/New(datum/ship_checkpoint_ui/terminal, datum/ship_checkpoint/blueprint, mob/living/user, manual_drive = FALSE, leave_original = FALSE)
	panel_ref = terminal ? WEAKREF(terminal) : null
	operator_ref = WEAKREF(user)
	snapshot = blueprint
	home = blueprint.outpost
	captain_ckey = blueprint.captain_ckey
	ship_name = blueprint.ship_name
	manual = manual_drive
	var/obj/structure/overmap/ship/original = leave_original ? null : blueprint.source_ship?.resolve()
	if(original)
		original_ref = WEAKREF(original)
	// Refunds follow the checkpoint's owner, who is the operator unless an admin started it.
	var/mob/living/owner = user?.ckey == captain_ckey ? user : get_mob_by_ckey(captain_ckey)
	var/datum/bank_account/personal = istype(owner) ? owner.get_bank_account() : null
	if(personal)
		captain_account_ref = WEAKREF(personal)
	// Claim the bay before any yield, so a second request cannot reserve it too.
	bay = home.reserve_rebuild_bay(src)
	if(!bay)
		// Nothing was locked, so there is nothing for cleanup to release.
		state = CHECKPOINT_BUILD_FAILED
		return
	home.checkpoint_jobs += src
	snapshot.busy = TRUE
	if(original)
		original.checkpoint_rebuilding = TRUE
	RegisterSignal(home, COMSIG_QDELETING, PROC_REF(on_site_deleted))
	RegisterSignal(bay, COMSIG_QDELETING, PROC_REF(on_site_deleted))
	RegisterSignal(snapshot, COMSIG_QDELETING, PROC_REF(on_checkpoint_deleted))

/// Once pieces exist, only a forced deletion may stop the job; it then removes them.
/datum/checkpoint_construction/Destroy(force)
	if(state != CHECKPOINT_BUILD_COMPLETE && state != CHECKPOINT_BUILD_FAILED)
		if(committed && !force)
			return QDEL_HINT_LETMELIVE
		abort("Reconstruction was cancelled.", delete_job = FALSE)
	STOP_PROCESSING(SSfastprocess, src)
	clear_site_effects()
	restore_room_lighting()
	if(home)
		home.checkpoint_jobs -= src
		UnregisterSignal(home, COMSIG_QDELETING)
	if(bay)
		UnregisterSignal(bay, COMSIG_QDELETING)
	if(snapshot)
		UnregisterSignal(snapshot, COMSIG_QDELETING)
	home = null
	bay = null
	snapshot = null
	port = null
	vessel = null
	source_reservation = null
	source_turfs = null
	bay_turfs = null
	stage_visits = null
	QDEL_NULL(template)
	return ..()

/datum/checkpoint_construction/proc/on_site_deleted(datum/source)
	SIGNAL_HANDLER
	// Releasing reservations can yield; the removal itself finishes before the bay goes.
	INVOKE_ASYNC(src, PROC_REF(abort), "The ship bay was removed.")

/datum/checkpoint_construction/proc/on_checkpoint_deleted(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(snapshot, COMSIG_QDELETING)
	snapshot = null
	if(!committed)
		INVOKE_ASYNC(src, PROC_REF(abort), "This checkpoint is no longer available.")

// ===== PREPARATION =====

/// Loads and plans the hidden copy. Returns TRUE once the survey markers are down.
/datum/checkpoint_construction/proc/prepare()
	if(!bay)
		error = "The ship bay is occupied or reserved."
		return FALSE
	// The shared loader is held only for the load itself, never for the build.
	var/loaded = SSshuttle.run_template_load(CALLBACK(src, PROC_REF(load_source)), wait_timeout = 30 SECONDS)
	if(QDELETED(src) || state != CHECKPOINT_BUILD_PREPARING)
		return FALSE
	if(!loaded || !plan())
		abort(error || "Rebuild failed. Your checkpoint is still available.")
		return FALSE
	begin_marking()
	return TRUE

/// Runs while this job owns SSshuttle's template load. Every reference is rechecked after it yields.
/datum/checkpoint_construction/proc/load_source(datum/shuttle_template_load/load_owner)
	if(QDELETED(src) || state != CHECKPOINT_BUILD_PREPARING)
		return FALSE
	error = build_denial()
	if(error)
		return FALSE
	template = new(snapshot)
	SSair.can_fire = FALSE
	var/loaded = SSshuttle.load_template(template, load_owner)
	var/obj/docking_port/mobile/voidcrew/loaded_port = SSshuttle.preview_shuttle
	var/datum/turf_reservation/loaded_space = SSshuttle.preview_reservation
	// Take the preview out of the shared loader so the next purchase cannot unload it.
	SSshuttle.preview_shuttle = null
	SSshuttle.preview_template = null
	SSshuttle.preview_reservation = null
	if(QDELETED(src) || state != CHECKPOINT_BUILD_PREPARING)
		discard_copy(loaded_port, loaded_space)
		return FALSE
	port = loaded_port
	source_reservation = loaded_space
	if(!loaded || !istype(port) || QDELETED(port) || QDELETED(source_reservation))
		error = "The saved hull could not be loaded. Your checkpoint is still available."
		return FALSE
	RegisterSignal(port, COMSIG_QDELETING, PROC_REF(on_port_deleted))
	error = build_denial()
	if(error)
		return FALSE
	// Initialization may stock lockers or engine tanks even though no items were saved.
	clear_stock(port)
	var/mob/living/operator = operator_ref?.resolve()
	for(var/turf/tile as anything in port.return_turfs())
		if(!(get_area(tile) in port.shuttle_areas))
			continue
		for(var/obj/machinery/machine in tile)
			restore_machine(machine, operator)
		// The copy loses its windows and doors long before its floors. Frozen, it cannot
		// vent, trip firelocks or blow unplaced fittings off their tiles.
		tile.blocks_air = TRUE
		tile.air_update_turf(TRUE, TRUE)
		// Player ships carry no door access. Clear it before anyone can reach a door.
		for(var/obj/machinery/door/door in tile)
			door.req_access = null
			door.req_one_access = null
	return TRUE

/// Shared checks before any piece exists.
/datum/checkpoint_construction/proc/build_denial()
	if(QDELETED(home) || QDELETED(bay) || !IS_WEAKREF_OF(src, bay.rebuild_owner) || QDELETED(bay.dock) || QDELETED(bay.reservation))
		return "The ship bay is no longer reserved."
	if(bay.ship || (bay.dock.get_docked() && (!port || bay.dock.get_docked() != port)))
		return "The ship bay is occupied."
	if(QDELETED(snapshot) || snapshot.outpost != home || !(snapshot in home.checkpoints))
		return "This checkpoint is no longer available."
	var/obj/structure/overmap/ship/original = original_ref?.resolve()
	if(original)
		if(original.retired_by_checkpoint)
			return "The original hull has already been replaced."
		if(!QDELETED(original.shuttle) && !original.abandoned)
			return "The original hull must be lost or abandoned."
	return null

/// Pairs every saved tile with its bay tile and queues the visits.
/datum/checkpoint_construction/proc/plan()
	error = build_denial()
	if(error || QDELETED(port) || QDELETED(source_reservation))
		error ||= "The saved hull could not be loaded. Your checkpoint is still available."
		return FALSE
	var/obj/docking_port/stationary/dock = bay.dock
	adjust_reserve_dock_to_shuttle(dock, port)
	if(!port_fits(dock))
		error = "This hull does not fit the ship bay. Your checkpoint is still available."
		return FALSE
	bay_area = get_area(dock)
	source_dir = port.dir
	move_dir = REVERSE_DIR(port.preferred_direction)
	if(dock.dir != port.dir)
		rotation = dir2angle(dock.dir) - dir2angle(port.dir)
		if((rotation % 90) != 0)
			rotation += (rotation % 90)
		rotation = SIMPLIFY_DEGREES(rotation)
	var/list/source_order = port.return_ordered_turfs(port.x, port.y, port.z, port.dir)
	var/list/bay_order = port.return_ordered_turfs(dock.x, dock.y, dock.z, dock.dir)
	source_turfs = list()
	bay_turfs = list()
	for(var/i in 1 to length(source_order))
		source_turfs += source_order[i]
		bay_turfs += bay_order[i]
	port_index = source_turfs.Find(get_turf(port))
	if(!port_index || bay_turfs[port_index] != get_turf(dock))
		error = "The saved hull could not be loaded. Your checkpoint is still available."
		return FALSE
	stage_visits = list()
	for(var/i in 1 to CHECKPOINT_STAGE_COUNT)
		stage_visits += list(list())
	var/list/by_tile_stage = list()
	var/center_x = 0
	var/center_y = 0
	for(var/i in 1 to length(source_turfs))
		var/turf/source = source_turfs[i]
		if(!source || !port.shuttle_areas[source.loc])
			continue
		var/turf/target = bay_turfs[i]
		if(!target || !bay.contains_service_turf(target))
			error = "This hull does not fit the ship bay. Your checkpoint is still available."
			return FALSE
		hull_indices += i
		center_x += target.x
		center_y += target.y
		var/hull_stage = isclosedturf(source) ? CHECKPOINT_STAGE_HULL : CHECKPOINT_STAGE_DECK
		var/datum/checkpoint_visit/hull_visit = add_visit(by_tile_stage, i, hull_stage)
		hull_visit.hull = TRUE
		// A real landing carries a tile's contents only when preflight would. Anything it
		// would leave behind stays with the hidden copy and is discarded.
		var/tile_mode = source.loc.beforeShuttleMove(port.shuttle_areas)
		for(var/atom/movable/thing as anything in source.contents)
			if(thing.loc == source)
				tile_mode = thing.hypotheticalShuttleMove(rotation, tile_mode, port)
		tile_mode = source.fromShuttleMove(target, tile_mode)
		if(!(tile_mode & MOVE_CONTENTS))
			continue
		// Machines land before cables: a cable only honours an SMES/terminal pairing when
		// that machine is already on its tile as it relinks.
		var/list/obj/machinery/machines_first = list()
		var/list/atom/movable/everything_else = list()
		// Pipe connectors a machine made for itself travel with it, not as pieces of their own.
		var/list/obj/machinery/atmospherics/riders = list()
		for(var/obj/machinery/machine in source.contents)
			riders |= machine.checkpoint_atmos_parts()
		for(var/atom/movable/thing as anything in source.contents)
			// Some fittings delete or replace themselves after loading; WEAKREF() of one is null.
			if(thing.loc != source || thing == port || QDELETED(thing) || (thing in riders))
				continue
			if(ismachinery(thing))
				machines_first += thing
			else
				everything_else += thing
		for(var/atom/movable/thing as anything in machines_first + everything_else)
			var/piece_stage = piece_stage(thing, hull_stage)
			if(!piece_stage)
				continue
			var/datum/checkpoint_visit/visit = add_visit(by_tile_stage, i, piece_stage)
			visit.pieces += WEAKREF(thing)
	if(!length(hull_indices))
		error = "The saved hull is empty. Your checkpoint is still available."
		return FALSE
	center_x = round(center_x / length(hull_indices))
	center_y = round(center_y / length(hull_indices))
	// Each stage grows outward from the middle of the footprint.
	for(var/stage_number in 1 to CHECKPOINT_STAGE_COUNT)
		var/list/by_ring = list()
		for(var/datum/checkpoint_visit/visit as anything in stage_visits[stage_number])
			var/turf/target = bay_turfs[visit.index]
			visit.ring = max(abs(target.x - center_x), abs(target.y - center_y)) + 1
			if(length(by_ring) < visit.ring)
				by_ring.len = visit.ring
			if(!by_ring[visit.ring])
				by_ring[visit.ring] = list()
			by_ring[visit.ring] += visit
		var/list/ordered = list()
		for(var/list/ring_visits in by_ring)
			ordered += ring_visits
		stage_visits[stage_number] = ordered
		visit_total += length(ordered)
	return TRUE

/datum/checkpoint_construction/proc/add_visit(list/by_tile_stage, index, visit_stage)
	var/key = "[index]:[visit_stage]"
	var/datum/checkpoint_visit/visit = by_tile_stage[key]
	if(visit)
		return visit
	visit = new
	visit.index = index
	visit.stage = visit_stage
	by_tile_stage[key] = visit
	var/list/queue = stage_visits[visit_stage]
	queue += visit
	return visit

/// The ordinary loader's fit test, without asking the dock, which is reserved for us.
/datum/checkpoint_construction/proc/port_fits(obj/docking_port/stationary/dock)
	if(port.dwidth > dock.dwidth || port.width - port.dwidth > dock.width - dock.dwidth)
		return FALSE
	if(port.dheight > dock.dheight || port.height - port.dheight > dock.height - dock.dheight)
		return FALSE
	return TRUE

/// Which stage places this atom, or null when it is discarded with the hidden copy.
/datum/checkpoint_construction/proc/piece_stage(atom/movable/thing, hull_stage)
	if(isitem(thing) || ismob(thing) || istype(thing, /obj/docking_port))
		return null
	if(iseffect(thing))
		return hull_stage
	if(istype(thing, /obj/structure/lattice))
		return CHECKPOINT_STAGE_DECK
	if(istype(thing, /obj/structure/grille) || istype(thing, /obj/structure/window) || istype(thing, /obj/structure/falsewall) || istype(thing, /obj/machinery/door))
		return CHECKPOINT_STAGE_HULL
	if(istype(thing, /obj/machinery/cryopod) || istype(thing, /obj/machinery/shower) || istype(thing, /obj/machinery/iv_drip) || istype(thing, /obj/machinery/defibrillator_mount))
		return CHECKPOINT_STAGE_MACHINERY
	if(istype(thing, /obj/structure/cable) || istype(thing, /obj/structure/disposalpipe) || istype(thing, /obj/machinery/power/smes) || is_type_in_typecache(thing, GLOB.outpost_checkpoint_infrastructure))
		return CHECKPOINT_STAGE_SYSTEMS
	if(ismachinery(thing))
		return CHECKPOINT_STAGE_MACHINERY
	return CHECKPOINT_STAGE_FITTINGS

/datum/checkpoint_construction/proc/begin_marking()
	state = CHECKPOINT_BUILD_MARKING
	for(var/index in hull_indices)
		var/turf/target = bay_turfs[index]
		markers[target] = new /obj/effect/checkpoint_build_marker(target)
	next_phase_at = world.time + CHECKPOINT_BUILD_SURVEY_TIME
	if(!manual)
		spawn_drones()
		START_PROCESSING(SSfastprocess, src)
	update_bay_status()
	log_game("Checkpoint reconstruction of [ship_name] for [captain_ckey] started at [home.name] ([visit_total] visits).")

// ===== CONTROLLER =====

/datum/checkpoint_construction/process(seconds_per_tick)
	SHOULD_NOT_SLEEP(TRUE)
	switch(state)
		if(CHECKPOINT_BUILD_MARKING)
			var/denial = build_denial()
			if(denial)
				abort(denial)
				return PROCESS_KILL
			if(world.time >= next_phase_at)
				begin_building()
		if(CHECKPOINT_BUILD_BUILDING)
			if(!committed)
				var/denial = build_denial()
				if(denial)
					abort(denial)
					return PROCESS_KILL
			if(direct_placement)
				fast_forward(rushed ? CHECKPOINT_BUILD_RUSH_BUDGET : CHECKPOINT_BUILD_VISIT_BUDGET)
				return
			run_drones()
			if(state == CHECKPOINT_BUILD_BUILDING && world.time - last_progress_at > CHECKPOINT_BUILD_STALL_TIME)
				// Never wait forever on a lost drone: place the rest of the queue directly, in order.
				log_game("Checkpoint reconstruction of [ship_name] stalled; placing its remaining pieces directly.")
				direct_placement = TRUE
		if(CHECKPOINT_BUILD_COMMISSIONING)
			try_commission()
		else
			return PROCESS_KILL

/datum/checkpoint_construction/proc/begin_building()
	if(state != CHECKPOINT_BUILD_MARKING)
		return
	state = CHECKPOINT_BUILD_BUILDING
	last_progress_at = world.time
	advance_stage()
	update_bay_status()

/// Drones launch from the bay's corner drone bays, shared out evenly, each keeping its own.
/datum/checkpoint_construction/proc/spawn_drones()
	var/list/obj/structure/checkpoint_drone_bay/cradles = list()
	var/turf/origin = bay.reservation.bottom_left_turfs[1]
	var/turf/far_corner = locate(origin.x + bay.reservation.width - 1, origin.y + bay.reservation.height - 1, origin.z)
	for(var/turf/tile as anything in block(origin, far_corner))
		for(var/obj/structure/checkpoint_drone_bay/cradle in tile)
			cradles += cradle
	// Maps without drone bays launch from the bay console instead.
	var/obj/machinery/computer/console = bay.console
	var/turf/fallback = console ? get_turf(console) : (length(bay.alcove_turfs) ? bay.alcove_turfs[1] : get_turf(bay.dock))
	var/count = clamp(CEILING(visit_total / CHECKPOINT_BUILD_VISITS_PER_DRONE, 1), CHECKPOINT_BUILD_MIN_DRONES, CHECKPOINT_BUILD_MAX_DRONES)
	for(var/i in 1 to count)
		var/obj/structure/checkpoint_drone_bay/cradle = length(cradles) ? cradles[(i - 1) % length(cradles) + 1] : null
		drones += new /obj/effect/checkpoint_build_drone(cradle ? get_turf(cradle) : fallback, cradle)
	for(var/obj/structure/checkpoint_drone_bay/cradle as anything in cradles)
		cradle.launch()

/// One bounded pass over the drones: travel, finish work, or take the next visit.
/datum/checkpoint_construction/proc/run_drones()
	var/budget = CHECKPOINT_BUILD_VISIT_BUDGET
	for(var/obj/effect/checkpoint_build_drone/drone as anything in drones.Copy())
		if(QDELETED(drone))
			drones -= drone
			var/datum/checkpoint_visit/lost_visit = drone?.visit
			if(drone)
				drone.visit = null
			requeue(lost_visit)
			continue
		var/datum/checkpoint_visit/visit = drone.visit
		if(visit?.done)
			drone.finish_work()
			visit = null
		if(visit)
			if(drone.work_until)
				if(world.time < drone.work_until || budget <= 0)
					continue
				budget--
				// Free the drone first, so a runtime while placing cannot strand it.
				drone.finish_work()
				execute_visit(visit)
				if(QDELETED(src) || state != CHECKPOINT_BUILD_BUILDING)
					return
				continue
			var/turf/target = bay_turfs[visit.index]
			if(drone.fly_towards(target))
				drone.start_work(target, visit_preview(visit))
			continue
		var/datum/checkpoint_visit/next = next_visit()
		if(next)
			next.drone = drone
			drone.visit = next
			drone.fly_towards(bay_turfs[next.index])
		// With nothing left in this stage, a drone waits where it is for the stragglers.
	advance_stage()

/datum/checkpoint_construction/proc/next_visit()
	if(stage > CHECKPOINT_STAGE_COUNT)
		return null
	var/list/queue = stage_visits[stage]
	while(length(queue))
		var/datum/checkpoint_visit/visit = queue[1]
		queue.Cut(1, 2)
		if(!visit.done)
			return visit
	return null

/// A lost drone's unfinished visit goes back to the front of its stage.
/datum/checkpoint_construction/proc/requeue(datum/checkpoint_visit/visit)
	if(!visit || visit.done)
		return
	visit.drone = null
	var/list/queue = stage_visits[visit.stage]
	queue.Insert(1, visit)

/datum/checkpoint_construction/proc/stage_finished()
	if(length(stage_visits[stage]))
		return FALSE
	for(var/obj/effect/checkpoint_build_drone/drone as anything in drones)
		if(drone?.visit?.stage == stage && !drone.visit.done)
			return FALSE
	return TRUE

/// Stages finish in order; the last one hands over to commissioning.
/datum/checkpoint_construction/proc/advance_stage()
	if(state != CHECKPOINT_BUILD_BUILDING)
		return
	while(stage <= CHECKPOINT_STAGE_COUNT && stage_finished())
		stage++
	if(stage > CHECKPOINT_STAGE_COUNT)
		begin_commissioning()

/// Places queued visits immediately and in order. Tests and stalled builds use this.
/datum/checkpoint_construction/proc/fast_forward(limit = INFINITY)
	if(state == CHECKPOINT_BUILD_MARKING)
		begin_building()
	for(var/obj/effect/checkpoint_build_drone/drone as anything in drones)
		if(drone?.visit)
			requeue(drone.visit)
			drone.finish_work()
	while(limit > 0 && state == CHECKPOINT_BUILD_BUILDING)
		var/datum/checkpoint_visit/visit = next_visit()
		if(!visit)
			var/stage_before = stage
			advance_stage()
			if(state != CHECKPOINT_BUILD_BUILDING || stage == stage_before)
				break
			continue
		limit--
		execute_visit(visit)
		// A finished stage hands over at once, before any piece of the next one.
		advance_stage()
	return visits_done

/// Admin testing: skips the survey and the drones. Visits still run once and in order, within a
/// per-tick budget, so a large hull cannot stall the server.
/datum/checkpoint_construction/proc/rush()
	if(manual)
		return FALSE
	if(state == CHECKPOINT_BUILD_MARKING)
		begin_building()
	if(state != CHECKPOINT_BUILD_BUILDING)
		return FALSE
	direct_placement = TRUE
	rushed = TRUE
	return TRUE

/// Admin testing: stops waiting for the captain. Hands over to them if they are here,
/// otherwise leaves the hull claimable, exactly as an expired wait does.
/datum/checkpoint_construction/proc/hand_over_now()
	if(state != CHECKPOINT_BUILD_COMMISSIONING)
		return FALSE
	captain_wait_until = world.time
	return try_commission()

// ===== PLACEMENT =====

/**
 * Runs one visit exactly once. The visit is recorded as done before anything moves: a
 * runtime part way through leaves the rest of that tile unbuilt rather than repeating it.
 */
/datum/checkpoint_construction/proc/execute_visit(datum/checkpoint_visit/visit)
	if(!visit || visit.done || QDELETED(src) || state != CHECKPOINT_BUILD_BUILDING)
		return FALSE
	if(!committed && !commit())
		return FALSE
	visit.done = TRUE
	visit.drone = null
	completed_visits += visit
	visits_done++
	last_progress_at = world.time
	var/turf/source = source_turfs[visit.index]
	var/turf/target = bay_turfs[visit.index]
	if(visit.hull)
		place_hull(source, target)
	for(var/datum/weakref/piece_ref as anything in visit.pieces)
		var/atom/movable/piece = piece_ref?.resolve()
		if(piece)
			place_piece(piece, source, target)
	report_progress()
	return TRUE

/**
 * Consumes the checkpoint immediately before the first piece. From here the job only moves
 * forward: partial output is never rolled back into a fresh checkpoint.
 */
/datum/checkpoint_construction/proc/commit()
	var/denial = build_denial()
	if(!denial && (QDELETED(port) || QDELETED(source_reservation)))
		denial = "The saved hull could not be loaded. Your checkpoint is still available."
	if(denial)
		abort(denial)
		return FALSE
	committed = TRUE
	UnregisterSignal(snapshot, COMSIG_QDELETING)
	var/datum/ship_checkpoint/consumed = snapshot
	snapshot = null
	template.blueprint = null
	qdel(consumed)
	var/obj/structure/overmap/ship/original = original_ref?.resolve()
	if(original)
		original.retired_by_checkpoint = TRUE
		original.checkpoint_rebuilding = FALSE
		var/balance = original.ship_account?.account_balance
		if(balance > 0 && original.ship_account.adjust_money(-balance, "Checkpoint recovery"))
			held_balance = balance
		if(QDELETED(original.shuttle))
			qdel(original)
	place_frame()
	log_game("Checkpoint for [ship_name] ([captain_ckey]) at [home.name] was consumed by its reconstruction.")
	return TRUE

/// Moves the port into the bay and registers it, as a landing would, before the first piece.
/datum/checkpoint_construction/proc/place_frame()
	if(frame_done || QDELETED(port) || QDELETED(bay?.dock))
		return frame_done
	var/turf/port_source = source_turfs[port_index]
	var/turf/port_target = bay_turfs[port_index]
	frame_done = TRUE
	port.checkpoint_construction = TRUE
	port.onShuttleMove(port_target, port_source, movement_force, move_dir, null, port)
	port.setDir(bay.dock.dir)
	port.unlink_from_z_level()
	port.link_to_z_level()
	port.recalculate_shuttle_areas()
	for(var/area/room as anything in port.shuttle_areas)
		room.afterShuttleMove(0)
	if(!port.registered)
		port.register()
		port.postregister()
	port.mode = SHUTTLE_IDLE
	port.timer = 0
	return TRUE

/// The deck or wall of one tile, and its room. The hidden source tile is left intact.
/datum/checkpoint_construction/proc/place_hull(turf/source, turf/target)
	var/area/room = source.loc
	if(QDELETED(port) || !port.shuttle_areas[room])
		return
	clear_marker(target)
	var/area/site_area = target.loc
	var/move_mode = room.beforeShuttleMove(port.shuttle_areas)
	move_mode = source.fromShuttleMove(target, move_mode)
	if(move_mode & MOVE_TURF)
		// Bay grime is under the new deck. Players and whatever they brought stay put.
		for(var/obj/effect/decal/cleanable/grime in target)
			qdel(grime)
		source.onShuttleMove(target, movement_force, move_dir, TRUE)
	if(site_area != room)
		target.change_area(site_area, room)
		port.underlying_areas_by_turf[target] = site_area
		placed_hull_tiles[target] = site_area
		floodlight_room(room, site_area)
	if(!(move_mode & MOVE_TURF))
		return
	source.TransferComponents(target)
	SSexplosions.wipe_turf(target)
	if(rotation)
		target.shuttleRotate(rotation)
	SEND_SIGNAL(target, COMSIG_TURF_AFTER_SHUTTLE_MOVE, source)
	target.lateShuttleMove(source)
	// lateShuttleMove() reopened the hidden tile; keep the copy sealed.
	source.blocks_air = TRUE
	source.air_update_turf(TRUE, TRUE)
	port.record_checkpoint_hull_turf(target)

/// Moves one initialized piece with the hooks a shuttle move uses, then tops it up.
/datum/checkpoint_construction/proc/place_piece(atom/movable/piece, turf/source, turf/target)
	if(QDELETED(piece) || piece.loc != source || QDELETED(port))
		return FALSE
	var/obj/machinery/power/power_machine = piece
	if(istype(power_machine))
		power_machine.disconnect_from_network()
	var/obj/machinery/duct/duct = piece
	if(istype(duct))
		detach_duct(duct)
	if(istype(piece, /obj/machinery/atmospherics))
		detach_atmos(piece)
	// A machine's own pipe connector (a cryo cell's) is carried by the machine when it moves.
	var/list/obj/machinery/atmospherics/riders = list()
	if(ismachinery(piece))
		var/obj/machinery/machine = piece
		riders = machine.checkpoint_atmos_parts()
	for(var/obj/machinery/atmospherics/rider as anything in riders)
		detach_atmos(rider)
		rider.beforeShuttleMove(target, rotation, MOVE_AREA | MOVE_TURF | MOVE_CONTENTS, port)
	piece.beforeShuttleMove(target, rotation, MOVE_AREA | MOVE_TURF | MOVE_CONTENTS, port)
	if(!piece.onShuttleMove(target, source, movement_force, move_dir, null, port) || piece.loc != target)
		return FALSE
	// Riders turn first: their machine's own after-move hook may then line them up with it.
	for(var/obj/machinery/atmospherics/rider as anything in riders)
		if(rider.loc != target)
			rider.abstract_move(target)
		rider.afterShuttleMove(source, movement_force, source_dir, port.preferred_direction, move_dir, rotation)
	piece.afterShuttleMove(source, movement_force, source_dir, port.preferred_direction, move_dir, rotation)
	if(istype(piece, /obj/machinery/atmospherics))
		attach_atmos(piece, source)
	else if(istype(duct))
		attach_duct(duct, source)
	else
		piece.lateShuttleMove(source, movement_force, move_dir)
	for(var/obj/machinery/atmospherics/rider as anything in riders)
		attach_atmos(rider, source)
	if(istype(power_machine))
		power_machine.connect_to_network()
	if(ismachinery(piece))
		provision_machine(piece)
	return TRUE

/**
 * A whole-ship move keeps every pipe beside its neighbours. One tile at a time does not, and
 * lateShuttleMove() would nullify each distant node, which for a component also deletes that
 * port's gas mix. Leave the hidden copy's network first; the move then reconnects in the bay.
 */
/datum/checkpoint_construction/proc/detach_atmos(obj/machinery/atmospherics/device)
	var/list/obj/machinery/atmospherics/left_behind = list()
	for(var/obj/machinery/atmospherics/node as anything in device.nodes)
		if(node)
			left_behind |= node
	// A neighbour can hold a link the device does not return (stacked or mismatched pipes in
	// the saved layout). Left alone it would reach into the bay once the device is there.
	var/list/turf/nearby_turfs = list(get_turf(device))
	for(var/direction in GLOB.cardinals)
		nearby_turfs += get_step(device, direction)
	for(var/turf/nearby as anything in nearby_turfs)
		for(var/obj/machinery/atmospherics/other in nearby)
			if(other != device && (device in other.nodes))
				left_behind |= other
	if(istype(device, /obj/machinery/atmospherics/components))
		var/obj/machinery/atmospherics/components/component = device
		component.disconnect_nodes()
	else
		// Not device_type: a layer manifold keeps a variable node list and has no fixed count.
		for(var/i in 1 to length(device.nodes))
			var/obj/machinery/atmospherics/node = device.nodes[i]
			if(!node)
				continue
			if(device in node.nodes)
				node.disconnect(device)
			device.nodes[i] = null
		device.destroy_network()
	for(var/obj/machinery/atmospherics/node as anything in left_behind)
		if(device in node.nodes)
			node.disconnect(device)
		SSair.add_to_rebuild_queue(node)

/**
 * Replaces the atmospherics lateShuttleMove() relink. That merges straight into the
 * neighbours' pipelines, which fails when a neighbour placed moments earlier is still
 * waiting for its own. Link both ways here and let SSair rebuild the joined network.
 */
/datum/checkpoint_construction/proc/attach_atmos(obj/machinery/atmospherics/device, turf/source)
	SEND_SIGNAL(device, COMSIG_ATOM_LATE_SHUTTLE_MOVE, source, movement_force, move_dir)
	if(device.pipe_vision_img)
		device.pipe_vision_img.loc = device.loc
	device.atmos_init()
	var/list/obj/machinery/atmospherics/neighbours = list()
	for(var/obj/machinery/atmospherics/node as anything in device.nodes)
		if(node)
			neighbours |= node
	for(var/obj/machinery/atmospherics/node as anything in neighbours)
		node.atmos_init()
		if(!(device in node.nodes))
			// The neighbour will not take the link back (its port is already used). A one-way
			// link makes the rebuild runtime and leaves this port without a gas mix.
			device.disconnect(node)
			continue
		if(istype(node, /obj/machinery/atmospherics/components))
			// The port facing us was built into a network of its own while it had nothing to
			// join. Release it, or the old network lingers once ours takes the port.
			var/obj/machinery/atmospherics/components/component = node
			var/port_index = component.nodes.Find(device)
			var/datum/pipeline/lonely = component.parents[port_index]
			if(lonely)
				component.nullify_pipenet(lonely)
		else
			node.destroy_network()
		SSair.add_to_rebuild_queue(node)
	SSair.add_to_rebuild_queue(device)

/**
 * Plumbing ducts remember their neighbours, and their lateShuttleMove() treats one that is
 * not beside them yet as lost. Tile by tile that is true of every neighbour until the last
 * arrives, so a duct whose neighbours all landed first never looks around again. Leave the
 * hidden copy's ductnet cleanly instead; attach_duct() connects to whatever is in the bay.
 */
/datum/checkpoint_construction/proc/detach_duct(obj/machinery/duct/duct)
	if(duct.duct)
		duct.duct.remove_duct(duct)
	for(var/obj/machinery/duct/other in duct.neighbours)
		other.neighbours -= duct
		other.generate_connects()
	duct.neighbours = list()

/// Joins the bay's ducts and plumbed machines, as a newly laid duct would.
/datum/checkpoint_construction/proc/attach_duct(obj/machinery/duct/duct, turf/source)
	SEND_SIGNAL(duct, COMSIG_ATOM_LATE_SHUTTLE_MOVE, source, movement_force, move_dir)
	// A dumb duct's connects are its saved, rotated shape; a smart one works them out again.
	if(!duct.dumb)
		duct.reset_connects()
	duct.attempt_connect()

/// New decks join the ship's unpowered rooms, so they would lose the hangar's ambient light.
/// Each room borrows it until the build ends.
/datum/checkpoint_construction/proc/floodlight_room(area/room, area/site_area)
	if(lit_rooms[room])
		return
	lit_rooms[room] = list(room.base_lighting_color, room.base_lighting_alpha)
	var/alpha = max(site_area.base_lighting_alpha, CHECKPOINT_BUILD_FLOODLIGHT_ALPHA)
	room.set_base_lighting(site_area.base_lighting_alpha ? site_area.base_lighting_color : CHECKPOINT_BUILD_FLOODLIGHT_COLOR, alpha)

/datum/checkpoint_construction/proc/restore_room_lighting()
	for(var/area/room as anything in lit_rooms)
		if(QDELETED(room))
			continue
		var/list/original = lit_rooms[room]
		room.set_base_lighting(original[1], original[2])
	lit_rooms.Cut()

/datum/checkpoint_construction/proc/visit_preview(datum/checkpoint_visit/visit)
	if(visit.hull)
		var/turf/source = source_turfs[visit.index]
		if(!isspaceturf(source))
			return source
	for(var/datum/weakref/piece_ref as anything in visit.pieces)
		var/atom/movable/piece = piece_ref?.resolve()
		if(piece && !iseffect(piece) && piece.invisibility < INVISIBILITY_ABSTRACT)
			return piece
	return null

// ===== COMMISSIONING =====

/datum/checkpoint_construction/proc/begin_commissioning()
	state = CHECKPOINT_BUILD_COMMISSIONING
	captain_wait_until = world.time + CHECKPOINT_BUILD_CAPTAIN_WAIT
	// Every visit has run; nothing more is needed from the hidden copy.
	discard_source()
	// The drones go home and the floodlights go off now, whenever the captain turns up.
	clear_site_effects()
	restore_room_lighting()
	update_bay_status()
	try_commission()

/// A living mob with the saving captain's key, wherever they are.
/datum/checkpoint_construction/proc/find_captain()
	var/mob/living/candidate = get_mob_by_ckey(captain_ckey)
	if(!istype(candidate) || candidate.stat == DEAD || !candidate.mind)
		return null
	return candidate

/// Waits a bounded time for the captain, then hands the finished hull over.
/datum/checkpoint_construction/proc/try_commission()
	if(state != CHECKPOINT_BUILD_COMMISSIONING)
		return FALSE
	var/mob/living/captain = find_captain()
	if(!captain && world.time < captain_wait_until)
		return FALSE
	return commission(captain)

/// Ownership exists only from here: nobody can join, claim or fly an unfinished hull.
/datum/checkpoint_construction/proc/commission(mob/living/captain)
	if(state != CHECKPOINT_BUILD_COMMISSIONING || handover_started || QDELETED(bay) || QDELETED(home))
		return FALSE
	handover_started = TRUE
	STOP_PROCESSING(SSfastprocess, src)
	place_frame()
	clear_site_effects()
	discard_source()
	if(QDELETED(port) || port.get_docked() != bay.dock || bay.ship || !IS_WEAKREF_OF(src, bay.rebuild_owner))
		stack_trace("Checkpoint reconstruction of [ship_name] finished without a docked hull it could hand over.")
		abort("The rebuilt hull could not be commissioned.")
		return FALSE
	vessel = new(get_turf(home))
	vessel.starting_credits = 0
	if(!vessel.setup_from_template(template))
		QDEL_NULL(vessel)
		stack_trace("Checkpoint reconstruction of [ship_name] could not create its ship record.")
		abort("The rebuilt hull could not be commissioned.")
		return FALSE
	// The ship record keeps its source template; the job must not delete it.
	template = null
	port.current_ship = vessel
	vessel.shuttle = port
	vessel.docked = home
	vessel.forceMove(home)
	vessel.state = OVERMAP_SHIP_IDLE
	vessel.name = ship_name
	vessel.display_name = ship_name
	port.name = ship_name
	vessel.ship_team.name = ship_name
	vessel.ship_account.account_holder = ship_name
	// Door access was cleared on the hidden copy, so doors reconfigured during the build keep it.
	vessel.calculate_mass()
	vessel.update_flight_parallax()
	port.checkpoint_construction = FALSE
	SEND_SIGNAL(port, COMSIG_VOIDCREW_SHIP_LOADED)
	// Registration linked the helms before a ship record existed.
	for(var/area/room as anything in port.shuttle_areas)
		for(var/obj/machinery/computer/helm/helm in room)
			helm.attempt_ship_connection()
	if(captain && vessel.enlist_crewmember(captain))
		vessel.claimed_captain = captain.mind
		grant_captain_management(captain, vessel)
		if(held_balance > 0)
			vessel.ship_account.adjust_money(held_balance, "Recovered ship account")
			held_balance = 0
	else
		// Nobody answered for it: the finished hull can be claimed at its helm, but the
		// old ship's money goes back to the captain rather than to whoever claims it.
		vessel.abandon_ship(crash = FALSE)
		return_held_balance(null)
	if(!bay.complete_rebuild(vessel, src))
		stack_trace("Checkpoint reconstruction of [ship_name] could not hand its bay to the rebuilt ship.")
		bay.finish_rebuild(src)
	state = CHECKPOINT_BUILD_COMPLETE
	SEND_SIGNAL(vessel, COMSIG_VOIDCREW_SHIP_DOCKED)
	home.refresh_elevator_uis()
	log_game("[captain ? key_name(captain) : captain_ckey] received [vessel.name], rebuilt at [home.name] from its checkpoint.")
	if(captain)
		to_chat(captain, span_notice("[vessel.name] has been rebuilt in Ship Bay [bay.bay_number]."))
	var/datum/ship_checkpoint_ui/panel = panel_ref?.resolve()
	if(panel)
		panel.notice = "[vessel.name] has been rebuilt."
		panel.error = null
	qdel(src)
	return TRUE

// ===== FAILURE AND TERMINATION =====

/**
 * Before the first piece: release everything and keep the checkpoint.
 * After it: remove what was placed and release the bay. The checkpoint stays consumed.
 */
/datum/checkpoint_construction/proc/abort(reason, delete_job = TRUE)
	if(state == CHECKPOINT_BUILD_COMPLETE || state == CHECKPOINT_BUILD_FAILED)
		return
	state = CHECKPOINT_BUILD_FAILED
	error = reason || "Rebuild failed. Your checkpoint is still available."
	STOP_PROCESSING(SSfastprocess, src)
	clear_site_effects()
	var/obj/structure/overmap/ship/original = original_ref?.resolve()
	if(committed)
		remove_partial_hull()
		discard_source()
		// Everything placed is gone with the bay, so the old hull is no longer replaced.
		if(original)
			original.retired_by_checkpoint = FALSE
			original.checkpoint_rebuilding = FALSE
		return_held_balance(original)
		log_game("Checkpoint reconstruction of [ship_name] for [captain_ckey] was terminated after its checkpoint was consumed: [error]")
	else
		discard_source()
		if(!QDELETED(snapshot))
			snapshot.busy = FALSE
		if(original)
			original.checkpoint_rebuilding = FALSE
		log_game("Checkpoint reconstruction of [ship_name] for [captain_ckey] stopped before its first piece: [error]")
	if(!QDELETED(bay))
		bay.finish_rebuild(src)
	report_failure()
	if(delete_job)
		qdel(src)

/// Discards whatever is still hidden; before the frame moves that is the whole copy.
/datum/checkpoint_construction/proc/discard_source()
	if(!frame_done && !QDELETED(port))
		var/obj/docking_port/mobile/voidcrew/discarded = port
		var/list/rooms = discarded.shuttle_areas?.Copy()
		UnregisterSignal(discarded, COMSIG_QDELETING)
		port = null
		discarded.jumpToNullSpace()
		for(var/area/room as anything in rooms)
			if(!QDELETED(room) && !room.has_contained_turfs())
				qdel(room)
	else
		clear_source_tiles()
	var/datum/turf_reservation/released = source_reservation
	source_reservation = null
	if(released)
		// Large reservations yield while releasing; never inside a processing tick.
		INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(qdel), released)

/// Used when the job is deleted during its own load, before it took the copy.
/datum/checkpoint_construction/proc/discard_copy(obj/docking_port/mobile/voidcrew/loaded_port, datum/turf_reservation/loaded_space)
	if(!QDELETED(loaded_port))
		var/list/rooms = loaded_port.shuttle_areas?.Copy()
		loaded_port.jumpToNullSpace()
		for(var/area/room as anything in rooms)
			if(!QDELETED(room) && !room.has_contained_turfs())
				qdel(room)
	if(loaded_space)
		INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(qdel), loaded_space)

/// Hands the hidden source tiles back from the ship's rooms once the port has left them.
/// Releasing the reservation then empties and resets them over later ticks.
/datum/checkpoint_construction/proc/clear_source_tiles()
	if(!source_turfs)
		return
	var/area/fallback = GLOB.areas_by_type[SHUTTLE_DEFAULT_UNDERLYING_AREA] || new SHUTTLE_DEFAULT_UNDERLYING_AREA(null)
	var/list/rooms = list()
	for(var/index in hull_indices)
		var/turf/source = source_turfs[index]
		if(!source || !istype(source.loc, /area/shuttle))
			continue
		evacuate(source)
		rooms |= source.loc
		source.change_area(source.loc, fallback)
	for(var/area/room as anything in rooms)
		if(!room.has_contained_turfs() && (QDELETED(port) || !port.shuttle_areas?[room]))
			qdel(room)

/// Removes placed pieces from a bay that is being released or deleted. Works from this
/// job's own records, so it still cleans up after the port has been deleted elsewhere.
/datum/checkpoint_construction/proc/remove_partial_hull()
	var/list/rooms = list()
	for(var/turf/target as anything in placed_hull_tiles)
		evacuate(target)
	for(var/datum/checkpoint_visit/visit as anything in completed_visits)
		remove_visit_pieces(visit)
	for(var/turf/target as anything in placed_hull_tiles)
		var/area/underlying = placed_hull_tiles[target]
		var/area/room = target.loc
		if(room != underlying && !QDELETED(underlying))
			rooms |= room
			target.change_area(room, underlying)
		if(!QDELETED(port))
			port.underlying_areas_by_turf -= target
		var/depth = target.depth_to_find_baseturf(/turf/baseturf_skipover/shuttle)
		if(!isnull(depth))
			target.ScrapeAway(depth)
	placed_hull_tiles.Cut()
	if(frame_done && !QDELETED(port))
		var/obj/docking_port/mobile/voidcrew/removed = port
		UnregisterSignal(removed, COMSIG_QDELETING)
		port = null
		qdel(removed, force = TRUE)
	for(var/area/room as anything in rooms)
		if(istype(room, /area/shuttle) && !room.has_contained_turfs())
			qdel(room)

/datum/checkpoint_construction/proc/remove_visit_pieces(datum/checkpoint_visit/visit)
	var/turf/target = bay_turfs[visit.index]
	for(var/datum/weakref/piece_ref as anything in visit.pieces)
		var/atom/movable/piece = piece_ref?.resolve()
		// Only what this job placed and is still standing where it was put.
		if(piece && get_turf(piece) == target)
			qdel(piece)

/// Moves living occupants off a tile before it is emptied, as bay teardown does.
/datum/checkpoint_construction/proc/evacuate(turf/location)
	var/list/turf/refuge = home?.get_floor_alcove(0) || bay?.alcove_turfs
	if(!length(refuge))
		return
	for(var/atom/movable/occupant as anything in location.contents.Copy())
		if(ismob(occupant))
			if(!isobserver(occupant))
				occupant.forceMove(pick(refuge))
			continue
		if(!length(occupant.contents) || !(locate(/mob/living) in occupant.get_all_contents()))
			continue
		if(!occupant.anchored)
			occupant.forceMove(pick(refuge))
			continue
		for(var/mob/living/rider in occupant.get_all_contents())
			rider.forceMove(pick(refuge))

/// Funds taken at commitment follow the old hull back, or its captain when it is gone.
/datum/checkpoint_construction/proc/return_held_balance(obj/structure/overmap/ship/original)
	if(held_balance <= 0)
		return
	var/datum/bank_account/account = original?.ship_account
	if(QDELETED(account))
		account = captain_account_ref?.resolve()
	if(QDELETED(account))
		var/mob/living/captain = get_mob_by_ckey(captain_ckey)
		account = istype(captain) ? captain.get_bank_account() : null
	if(account)
		account.adjust_money(held_balance, "Checkpoint recovery refund")
	else
		log_game("Checkpoint reconstruction of [ship_name] could not return [held_balance] credits: no account remains.")
	held_balance = 0

/datum/checkpoint_construction/proc/on_port_deleted(datum/source)
	SIGNAL_HANDLER
	if(source != port)
		return
	port = null
	if(state == CHECKPOINT_BUILD_COMPLETE || state == CHECKPOINT_BUILD_FAILED)
		return
	INVOKE_ASYNC(src, PROC_REF(abort), "The rebuilt hull was removed.")

// ===== STATUS =====

/datum/checkpoint_construction/proc/stage_name()
	switch(stage)
		if(CHECKPOINT_STAGE_DECK)
			return "Deck"
		if(CHECKPOINT_STAGE_HULL)
			return "Hull"
		if(CHECKPOINT_STAGE_SYSTEMS)
			return "Systems"
		if(CHECKPOINT_STAGE_MACHINERY)
			return "Machinery"
		if(CHECKPOINT_STAGE_FITTINGS)
			return "Fittings"
	return "Commissioning"

/datum/checkpoint_construction/proc/progress_percent()
	if(!visit_total)
		return 0
	return round(100 * visits_done / visit_total)

/datum/checkpoint_construction/proc/status_line()
	switch(state)
		if(CHECKPOINT_BUILD_PREPARING)
			return "Preparing"
		if(CHECKPOINT_BUILD_MARKING)
			return "Marking construction area"
		if(CHECKPOINT_BUILD_BUILDING)
			return "Stage [min(stage, CHECKPOINT_STAGE_COUNT)]/[CHECKPOINT_STAGE_COUNT]: [stage_name()]"
		if(CHECKPOINT_BUILD_COMMISSIONING)
			return find_captain() ? "Commissioning" : "Awaiting captain"
		if(CHECKPOINT_BUILD_COMPLETE)
			return "Complete"
	return error || "Stopped"

/// Short enough for the bay signs and elevator.
/datum/checkpoint_construction/proc/bay_status()
	if(state == CHECKPOINT_BUILD_BUILDING)
		return "Rebuilding [progress_percent()]%"
	if(state == CHECKPOINT_BUILD_COMMISSIONING)
		return "Commissioning"
	return "Rebuilding"

/datum/checkpoint_construction/proc/rebuild_ui_data()
	return list(
		"ref" = REF(src),
		"name" = ship_name,
		"status" = status_line(),
		"progress" = state == CHECKPOINT_BUILD_COMMISSIONING ? 100 : progress_percent(),
	)

/datum/checkpoint_construction/proc/report_progress()
	var/percent = progress_percent()
	if(percent - last_reported_percent < 5 && percent < 100)
		return
	last_reported_percent = percent
	update_bay_status()

/datum/checkpoint_construction/proc/update_bay_status()
	if(!QDELETED(bay))
		bay.update_status()

/datum/checkpoint_construction/proc/report_failure()
	var/datum/ship_checkpoint_ui/panel = panel_ref?.resolve()
	if(panel)
		panel.error = error
		panel.notice = null
	var/mob/living/captain = get_mob_by_ckey(captain_ckey)
	if(istype(captain) && state == CHECKPOINT_BUILD_FAILED)
		to_chat(captain, span_warning("Reconstruction of [ship_name] stopped: [error]"))

/datum/checkpoint_construction/proc/clear_marker(turf/target)
	var/obj/effect/checkpoint_build_marker/marker = markers[target]
	markers -= target
	if(marker)
		qdel(marker)

/// Removes the markers and lets the drones go. They fly back to their drone bays on their
/// own, unless the bay itself is going away.
/datum/checkpoint_construction/proc/clear_site_effects()
	for(var/turf/marked as anything in markers)
		qdel(markers[marked])
	markers.Cut()
	var/site_remains = !QDELETED(bay) && !QDELETED(home)
	for(var/obj/effect/checkpoint_build_drone/drone as anything in drones)
		if(drone?.visit)
			drone.visit.drone = null
			drone.visit = null
		if(QDELETED(drone))
			continue
		if(site_remains)
			drone.return_home()
		else
			qdel(drone)
	drones.Cut()

/obj/docking_port/mobile/voidcrew
	/// Set while a staged rebuild owns this port and its ship record does not exist yet.
	var/checkpoint_construction = FALSE

/// Keeps the landing census the next departure's pre-move audit reads.
/obj/docking_port/mobile/voidcrew/proc/record_checkpoint_hull_turf(turf/landed)
	LAZYSET(carried_hull_types, landed, landed.type)
