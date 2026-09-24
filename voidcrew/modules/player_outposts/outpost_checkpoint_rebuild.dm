/datum/ship_checkpoint_ui/proc/rebuild_denial(mob/living/user, datum/ship_checkpoint/snapshot, allow_busy = FALSE)
	if(QDELETED(src) || ui_status(user, GLOB.always_state) != UI_INTERACTIVE)
		return "Checkpoint console unavailable."
	if(QDELETED(snapshot) || snapshot.outpost != outpost || !(snapshot in outpost.checkpoints))
		return "This checkpoint is no longer available."
	if(user.ckey != snapshot.captain_ckey)
		return "Only the captain who saved this hull can rebuild it."
	if(snapshot.busy && !allow_busy)
		return "This hull is already being rebuilt."
	var/obj/structure/overmap/ship/original = snapshot.source_ship?.resolve()
	if(original)
		if(original.retired_by_checkpoint)
			return "The original hull has already been replaced."
		if(original.checkpoint_rebuilding && !allow_busy)
			return "Recovery is already in progress."
		// A deleted physical hull can leave an overmap record behind. Its crew
		// roster alone must not prevent recovery of a ship that no longer exists.
		if(!QDELETED(original.shuttle) && !original.abandoned)
			return "The original hull must be lost or abandoned."
	if(!allow_busy)
		var/free_bay = FALSE
		for(var/i in 1 to length(outpost.bay_berths))
			if(!outpost.bay_berths[i])
				free_bay = TRUE
		if(!free_bay)
			return "Both ship bays are occupied."
	return null

/datum/ship_checkpoint_ui/proc/rebuild(mob/living/user, datum/ship_checkpoint/snapshot)
	error = rebuild_denial(user, snapshot)
	if(error || working)
		return FALSE
	// Claim both ends before waiting for the shared shuttle loader.
	notice = null
	working = TRUE
	snapshot.busy = TRUE
	var/obj/structure/overmap/ship/original = snapshot.source_ship?.resolve()
	if(original)
		original.checkpoint_rebuilding = TRUE
	var/datum/checkpoint_rebuild/operation = new(src, snapshot, user)
	var/success = SSshuttle.run_template_load(CALLBACK(operation, TYPE_PROC_REF(/datum/checkpoint_rebuild, execute)), wait_timeout = 30 SECONDS)
	if(!QDELETED(original))
		original.checkpoint_rebuilding = FALSE
	if(!QDELETED(snapshot))
		snapshot.busy = FALSE
	if(!QDELETED(src))
		working = FALSE
		error = success ? null : (operation.error || "Rebuild failed. Your checkpoint is still available.")
	qdel(operation)
	return success

/// Own partial results across yielding map loads and runtime-aborted callbacks.
/datum/checkpoint_rebuild
	var/datum/ship_checkpoint_ui/panel
	var/datum/ship_checkpoint/snapshot
	var/mob/living/captain
	var/obj/structure/overmap/dynamic/player_outpost/home
	var/obj/structure/overmap/ship/vessel
	var/datum/outpost_berth/ship_bay/bay
	var/datum/map_template/shuttle/voidcrew/commissioned/checkpoint/template
	var/error
	var/committed = FALSE

/datum/checkpoint_rebuild/New(datum/ship_checkpoint_ui/terminal, datum/ship_checkpoint/blueprint, mob/living/user)
	panel = terminal
	snapshot = blueprint
	captain = user
	home = blueprint.outpost

/datum/checkpoint_rebuild/Destroy()
	panel = null
	snapshot = null
	captain = null
	home = null
	vessel = null
	bay = null
	template = null
	return ..()

/datum/checkpoint_rebuild/proc/execute(datum/shuttle_template_load/load_owner)
	// An ordinary callback boundary preserves cleanup after a map runtime. Never
	// try/catch a template load: that unwinds the loader's own initialization stack.
	var/datum/callback/load = CALLBACK(src, PROC_REF(load_and_commit), load_owner)
	. = load.Invoke()
	if(!committed)
		if(!QDELETED(vessel))
			// Preview disposal is owned by SSshuttle, not the overmap ship.
			if(vessel.shuttle == SSshuttle.preview_shuttle)
				vessel.detach_shuttle()
			else
				// A player can enter a just-landed hull while the loader yields.
				// Move even occupants nested inside anchored machinery before rollback.
				if(!QDELETED(home))
					for(var/mob/living/person as anything in GLOB.mob_living_list)
						if(vessel.is_aboard(person))
							person.forceMove(home.arrival_turf)
				bay?.eject_occupants()
			qdel(vessel)
		if(!QDELETED(bay))
			bay.release(force = TRUE)
		SSshuttle.unload_preview(load_owner)
		QDEL_NULL(template)
	return committed

/datum/checkpoint_rebuild/proc/load_and_commit(datum/shuttle_template_load/load_owner)
	if(QDELETED(panel) || QDELETED(snapshot))
		return FALSE
	error = panel.rebuild_denial(captain, snapshot, allow_busy = TRUE)
	if(error)
		return FALSE
	template = new(snapshot)
	vessel = new(get_turf(home))
	vessel.starting_credits = 0
	if(!vessel.setup_from_template(template))
		return FALSE
	SSshuttle.loading_ship = vessel
	SSair.can_fire = FALSE
	if(!SSshuttle.load_template(template, load_owner))
		error = "The saved hull could not be loaded. Your checkpoint is still available."
		return FALSE
	SSshuttle.preview_template = template
	var/obj/docking_port/mobile/voidcrew/port = SSshuttle.preview_shuttle
	if(QDELETED(port) || !istype(port) || QDELETED(home) || QDELETED(snapshot))
		return FALSE
	port.current_ship = vessel
	vessel.shuttle = port
	// Initialization may stock lockers or engine tanks even though no items were
	// serialized. Scrub the isolated preview before it can touch an occupied bay.
	clear_stock(port)
	for(var/turf/tile as anything in port.return_turfs())
		if(!(get_area(tile) in port.shuttle_areas))
			continue
		for(var/obj/machinery/machine in tile)
			restore_machine(machine)
	bay = home.allocate_ship_bay(vessel)
	if(QDELETED(bay) || QDELETED(panel) || QDELETED(snapshot) || QDELETED(vessel))
		error = "A ship bay is no longer available."
		return FALSE
	error = panel.rebuild_denial(captain, snapshot, allow_busy = TRUE)
	if(error)
		return FALSE
	adjust_reserve_dock_to_shuttle(bay.dock, port)
	var/obj/docking_port/mobile/voidcrew/loaded = SSshuttle.action_load(template, bay.dock, load_owner = load_owner)
	if(loaded != port || QDELETED(home) || QDELETED(bay) || QDELETED(vessel) || bay.dock?.get_docked() != port)
		return FALSE
	if(QDELETED(panel) || QDELETED(snapshot))
		return FALSE
	error = panel.rebuild_denial(captain, snapshot, allow_busy = TRUE)
	if(error)
		return FALSE
	vessel.docked = home
	vessel.forceMove(home)
	vessel.state = OVERMAP_SHIP_IDLE
	vessel.name = snapshot.ship_name
	vessel.display_name = snapshot.ship_name
	port.name = snapshot.ship_name
	vessel.ship_team.name = snapshot.ship_name
	vessel.ship_account.account_holder = snapshot.ship_name
	vessel.clear_door_access()
	vessel.calculate_mass()
	vessel.update_flight_parallax()
	SEND_SIGNAL(port, COMSIG_VOIDCREW_SHIP_LOADED)
	if(!vessel.enlist_crewmember(captain))
		return FALSE
	vessel.claimed_captain = captain.mind
	grant_captain_management(captain, vessel)
	for(var/turf/tile as anything in port.return_turfs())
		if(!(get_area(tile) in port.shuttle_areas))
			continue
		for(var/obj/machinery/machine in tile)
			provision_machine(machine)
	var/obj/structure/overmap/ship/original = snapshot.source_ship?.resolve()
	if(original)
		original.retired_by_checkpoint = TRUE
		var/balance = original.ship_account?.account_balance
		if(balance > 0 && original.ship_account.adjust_money(-balance, "Checkpoint recovery"))
			vessel.ship_account.adjust_money(balance, "Recovered ship account")
		if(QDELETED(original.shuttle))
			qdel(original)
		else
			original.abandoned_at = world.time - SHIP_DERELICT_DESPAWN_TIME
	committed = TRUE
	// Consume the checkpoint only after a real, crew-owned hull occupies its bay.
	template.blueprint = null
	qdel(snapshot)
	SEND_SIGNAL(vessel, COMSIG_VOIDCREW_SHIP_DOCKED)
	home.refresh_elevator_uis()
	log_game("[key_name(captain)] rebuilt [vessel.name] at [home.name], consuming its checkpoint.")
	to_chat(captain, span_notice("[vessel.name] has been rebuilt in Ship Bay [bay.bay_number]. Installed machinery, charged batteries and engine fuel have been restored."))
	return TRUE

/datum/checkpoint_rebuild/proc/clear_stock(obj/docking_port/mobile/voidcrew/port)
	for(var/turf/tile as anything in port.return_turfs())
		if(!(get_area(tile) in port.shuttle_areas))
			continue
		for(var/atom/movable/object as anything in tile.get_all_contents())
			if(QDELETED(object))
				continue
			object.reagents?.clear_reagents()
			if(isitem(object) && is_machine_fitting(object))
				continue
			if(isitem(object) || ismob(object) || istype(object, /obj/structure/disposalholder))
				qdel(object)
				continue
			var/datum/component/material_container/materials = object.GetComponent(/datum/component/material_container)
			for(var/material in materials?.materials)
				materials.use_amount_mat(materials.materials[material], material)
			if(istype(object, /obj/machinery/atmospherics))
				var/obj/machinery/atmospherics/machine = object
				for(var/datum/pipeline/network as anything in machine.return_pipenets())
					network?.air?.gases.Cut()
				if(istype(machine, /obj/machinery/atmospherics/components))
					var/obj/machinery/atmospherics/components/component = machine
					for(var/datum/gas_mixture/mix as anything in component.airs)
						mix?.gases.Cut()
			if(istype(object, /obj/machinery/disposal))
				var/obj/machinery/disposal/disposal = object
				disposal.air_contents?.gases.Cut()
			if(istype(object, /obj/machinery/power/apc))
				var/obj/machinery/power/apc/controller = object
				controller.cell = null
			if(istype(object, /obj/machinery/atmospherics/components/unary/shuttle/heater))
				var/obj/machinery/atmospherics/components/unary/shuttle/heater/heater = object
				heater.fuel_tank = null
