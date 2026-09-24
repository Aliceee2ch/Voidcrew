/// Saves, deletes and rebuilds every purchasable ship class in a real bay. A class that loses
/// fittings or rebuilds with free supplies fails here; engine fuel is reported, not enforced.
/datum/unit_test/voidcrew_checkpoints/every_ship

/datum/unit_test/voidcrew_checkpoints/every_ship/Run()
	var/obj/structure/overmap/dynamic/player_outpost/registry_test/home = allocate(__IMPLIED_TYPE__)
	home.shell_template = allocate(/datum/map_template/player_outpost/small)
	home.founder_ckey = "everyshipfounder"
	TEST_ASSERT(home.load_level(), "The outpost did not load")
	TEST_ASSERT_NULL(home.enable_ship_bays(), "The ship bay did not load")
	var/mob/living/carbon/human/captain = make_player(run_loc_floor_bottom_left, "everyshipcaptain")
	var/list/report = list()
	for(var/label in SSmapping.ship_purchase_list)
		var/template_type = SSmapping.ship_purchase_list[label]
		var/datum/map_template/shuttle/voidcrew/template_path = template_type
		if(initial(template_path.abstract) == template_type || ispath(template_type, /datum/map_template/shuttle/voidcrew/commissioned))
			continue
		log_world("EVERY_SHIP begin [template_type]")
		report += "[template_type]: [check_ship(home, captain, template_type)]"
		log_world("EVERY_SHIP end [template_type]")
	log_test("Checkpoint round trip of every ship class:\n[report.Join("\n")]")

/// Returns a one-line summary; problems that break the no-free-supplies rule fail the test.
/datum/unit_test/voidcrew_checkpoints/every_ship/proc/check_ship(obj/structure/overmap/dynamic/player_outpost/registry_test/home, mob/living/carbon/human/captain, template_type)
	var/obj/structure/overmap/ship/original = SSshuttle.create_ship(template_type)
	if(!original)
		TEST_FAIL("[template_type] could not be spawned")
		return "could not spawn"
	test_ships += original
	original.enlist_crewmember(captain)
	original.claimed_captain = captain.mind
	var/datum/outpost_berth/ship_bay/bay = home.allocate_ship_bay(original)
	if(!bay)
		qdel(original)
		return "skipped: no bay could take it"
	adjust_reserve_dock_to_shuttle(bay.dock, original.shuttle)
	original.shuttle.mode = SHUTTLE_PREARRIVAL
	var/docked = original.shuttle.initiate_docking(bay.dock)
	original.shuttle.mode = SHUTTLE_IDLE
	if(docked != DOCKING_SUCCESS)
		home.on_ship_undock_complete(original)
		qdel(original)
		return "skipped: does not fit the bay ([docked])"
	original.docked = home
	original.forceMove(home)
	original.state = "idle"
	bay.on_ship_docked(original)
	var/datum/ship_checkpoint/snapshot = new
	var/denial = snapshot.capture(original, captain)
	if(denial)
		qdel(snapshot)
		original.shuttle.admin_delete_shuttle()
		return "not saved: [denial]"
	snapshot.outpost = home
	home.checkpoints += snapshot
	original.checkpoint_ref = WEAKREF(snapshot)
	var/list/before_counts = count_hull(original.shuttle)
	var/list/dropped = list()
	var/list/without_board = list()
	for(var/turf/tile as anything in original.shuttle.return_turfs())
		if(!(get_area(tile) in original.shuttle.shuttle_areas))
			continue
		for(var/obj/object in tile)
			if(!outpost_checkpoint_saves(object))
				if(ismachinery(object) || isstructure(object))
					dropped["[object.type]"]++
			else if(ismachinery(object))
				var/obj/machinery/machine = object
				if(machine.checkpoint_type() == machine.type && !istype(machine.circuit) && !is_type_in_typecache(machine, GLOB.outpost_checkpoint_infrastructure))
					without_board["[machine.type]"] = TRUE
	// Lose the original away from the bay, as a real one is. Deleting it on the pad would leave
	// what its fittings drop on deletion (duct stacks, crate tanks) under the rebuilt hull.
	var/obj/docking_port/stationary/transit/transit = original.shuttle.assigned_transit || SSshuttle.generate_transit_dock(original.shuttle)
	original.shuttle.mode = SHUTTLE_PREARRIVAL
	TEST_ASSERT_EQUAL(original.shuttle.initiate_docking(transit), DOCKING_SUCCESS, "[template_type]: the original could not leave the bay")
	original.shuttle.mode = SHUTTLE_IDLE
	original.docked = null
	original.forceMove(get_turf(home))
	original.state = "flying"
	home.on_ship_undock_complete(original)
	TEST_ASSERT(original.shuttle.admin_delete_shuttle(), "[template_type]: the original could not be removed")
	log_world("EVERY_SHIP rebuild [template_type]")
	var/datum/checkpoint_construction/job = new(null, snapshot, captain, TRUE)
	if(!job.prepare())
		TEST_FAIL("[template_type]: the rebuild did not start: [job.error]")
		return "rebuild failed: [job.error]"
	job.fast_forward()
	if(!QDELETED(job))
		job.hand_over_now()
	var/obj/structure/overmap/ship/rebuilt = bay.ship
	if(!QDELETED(job) || !rebuilt)
		TEST_FAIL("[template_type]: the rebuild was not handed over")
		return "not handed over"
	test_ships += rebuilt
	var/list/after_counts = count_hull(rebuilt.shuttle)
	for(var/type_name in (before_counts | after_counts))
		if(before_counts[type_name] != after_counts[type_name])
			TEST_FAIL("[template_type]: [type_name] expected [before_counts[type_name]], rebuilt [after_counts[type_name]]")
	log_world("EVERY_SHIP check [template_type]")
	for(var/problem in stock_problems(rebuilt.shuttle))
		TEST_FAIL("[template_type]: [problem]")
	var/engines = 0
	var/list/unfuelled = list()
	for(var/obj/machinery/power/shuttle_engine/ship/engine in rebuilt.shuttle.engine_list)
		engines++
		if((istype(engine, /obj/machinery/power/shuttle_engine/ship/fueled) || istype(engine, /obj/machinery/power/shuttle_engine/ship/liquid)) && engine.return_fuel() <= 0)
			unfuelled["[engine.type]"]++
	var/list/summary = list("rebuilt, [engines] engine(s)")
	if(length(unfuelled))
		summary += "NO FUEL: [list_counts(unfuelled)]"
	if(length(dropped))
		summary += "left out: [list_counts(dropped)]"
	if(length(without_board))
		var/list/names = list()
		for(var/type_name in without_board)
			names += type_name
		summary += "saved without a board: [names.Join(", ")]"
	rebuilt.shuttle.admin_delete_shuttle()
	return summary.Join("; ")

/datum/unit_test/voidcrew_checkpoints/every_ship/proc/list_counts(list/counts)
	var/list/parts = list()
	for(var/key in counts)
		parts += "[key] x[counts[key]]"
	return parts.Join(", ")

/// Everything a rebuild must not hand out for free.
/datum/unit_test/voidcrew_checkpoints/every_ship/proc/stock_problems(obj/docking_port/mobile/port)
	. = list()
	for(var/turf/tile as anything in port.return_turfs())
		if(!(get_area(tile) in port.shuttle_areas))
			continue
		for(var/obj/item/item in tile.get_all_contents())
			if(ismachinery(item.loc))
				var/obj/machinery/machine = item.loc
				if((item in machine.component_parts) || item == machine.circuit || istype(item, /obj/item/radio))
					continue
				if(istype(machine, /obj/machinery/power/apc))
					var/obj/machinery/power/apc/controller = machine
					if(item == controller.cell)
						continue
				if(istype(machine, /obj/machinery/atmospherics/components/unary/shuttle/heater))
					var/obj/machinery/atmospherics/components/unary/shuttle/heater/heater = machine
					if(item == heater.fuel_tank)
						continue
				if(istype(machine, /obj/machinery/computer/camera_advanced/base_construction/ship))
					continue
			if(istype(item, /obj/item/encryptionkey) && istype(item.loc, /obj/item/radio))
				continue
			. += "free item [item.type] in [item.loc?.type]"
		for(var/obj/object in tile)
			// Engine fuel is restocked on purpose; plumbing keeps its water.
			if(object.reagents?.total_volume && !istype(object, /obj/machinery/shower) && !istype(object, /obj/structure/sink) && !istype(object, /obj/machinery/power/shuttle_engine))
				. += "[object.type] holds [object.reagents.total_volume] units of reagents"
			var/datum/component/material_container/materials = object.GetComponent(/datum/component/material_container)
			if(materials?.total_amount())
				. += "[object.type] holds [materials.total_amount()] units of materials"
			if(istype(object, /obj/machinery/atmospherics/components/tank))
				var/obj/machinery/atmospherics/components/tank/stored = object
				if(stored.air_contents?.total_moles())
					. += "[object.type] holds [stored.air_contents.total_moles()] moles"
			if(istype(object, /obj/machinery/atmospherics))
				var/obj/machinery/atmospherics/machine = object
				for(var/datum/pipeline/network as anything in machine.return_pipenets())
					if(network?.air?.total_moles())
						. += "pipe network at [object.type] holds [network.air.total_moles()] moles"
			if(istype(object, /obj/machinery/vending))
				var/obj/machinery/vending/vendor = object
				for(var/datum/data/vending_product/product as anything in vendor.product_records + vendor.hidden_records + vendor.coin_records)
					if(product.amount)
						. += "[object.type] stocks [product.amount] [product.name]"
						break
