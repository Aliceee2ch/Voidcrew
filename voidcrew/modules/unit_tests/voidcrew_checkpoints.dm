/// Confirmations exercise the real save transaction without a connected client.
/datum/ship_checkpoint_ui/registry_test
	var/datum/callback/during_confirmation
	var/accept_save = TRUE

/datum/ship_checkpoint_ui/registry_test/confirm_save(mob/user, prompt_text)
	during_confirmation?.Invoke()
	return accept_save

/// Refuse allocation after the real preview load to exercise transaction rollback.
/obj/structure/overmap/dynamic/player_outpost/registry_test
	var/refuse_bay = FALSE

/obj/structure/overmap/dynamic/player_outpost/registry_test/allocate_ship_bay(obj/structure/overmap/ship/visitor, datum/rebuild_owner)
	if(refuse_bay)
		return null
	return ..()

/datum/unit_test/voidcrew_checkpoints
	parent_type = /datum/unit_test/voidcrew_outpost_management
	var/list/obj/structure/overmap/ship/test_ships = list()
	var/destroy_original = FALSE
	var/delete_via_admin = FALSE
	var/escape_on_delete = FALSE
	var/orphaned_original = FALSE

/// Recovery must also work after the hull and the captain's original body are gone.
/datum/unit_test/voidcrew_checkpoints/lost
	destroy_original = TRUE

/// Use the same post-confirmation deletion path as Shuttle Manipulator.
/datum/unit_test/voidcrew_checkpoints/admin_deleted
	destroy_original = TRUE
	delete_via_admin = TRUE

/datum/unit_test/voidcrew_checkpoints/admin_deleted/escaped
	escape_on_delete = TRUE

/// Existing hull-less records must not require the captain to abandon a ghost ship.
/datum/unit_test/voidcrew_checkpoints/missing_hull
	orphaned_original = TRUE

/datum/unit_test/voidcrew_checkpoints/Destroy()
	// Dispose ships before their host reservations, just as normal departures do.
	for(var/obj/structure/overmap/ship/ship as anything in test_ships)
		if(!QDELETED(ship))
			qdel(ship)
	return ..()

/datum/unit_test/voidcrew_checkpoints/proc/drain_account(obj/structure/overmap/ship/ship)
	ship.ship_account.account_balance = 0

/datum/unit_test/voidcrew_checkpoints/proc/count_hull(obj/docking_port/mobile/port)
	var/list/counts = list()
	for(var/turf/tile as anything in port.return_turfs())
		if(!(get_area(tile) in port.shuttle_areas))
			continue
		counts["[tile.type]"]++
		for(var/obj/object in tile)
			if(ismachinery(object))
				var/obj/machinery/machine = object
				if(machine.checkpoint_type())
					counts["[machine.checkpoint_type()]"]++
			else if(is_type_in_typecache(object, GLOB.outpost_checkpoint_structures))
				// Storage shells intentionally omit the original loot-spawner subtype.
				counts[istype(object, /obj/structure/closet) ? "closet:[object.name]" : "[object.type]"]++
	return counts

/datum/unit_test/voidcrew_checkpoints/Run()
	var/obj/structure/overmap/dynamic/player_outpost/registry_test/home = allocate(__IMPLIED_TYPE__)
	home.shell_template = allocate(/datum/map_template/player_outpost/small)
	home.founder_ckey = "registrycaptain"
	TEST_ASSERT(home.load_level(), "The registry outpost did not load")
	TEST_ASSERT_NULL(home.enable_ship_bays(), "The permanent recovery bay did not load")
	var/obj/machinery/computer/ship_checkpoint/terminal
	for(var/obj/machinery/computer/ship_checkpoint/candidate as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/computer/ship_checkpoint))
		if(get_outpost_from_atom(candidate) == home)
			terminal = candidate
	TEST_ASSERT_NOTNULL(terminal, "The primary deck has no dedicated checkpoint console")
	var/turf/terminal_turf = get_turf(terminal)
	var/mob/living/carbon/human/captain = make_player(terminal_turf, "registrycaptain")
	var/mob/living/carbon/human/visitor = make_player(terminal_turf, "registryvisitor")
	var/obj/structure/overmap/ship/original = SSshuttle.create_ship(/datum/map_template/shuttle/voidcrew/box)
	TEST_ASSERT_NOTNULL(original, "Could not create the source hull")
	test_ships += original
	original.enlist_crewmember(captain)
	original.claimed_captain = captain.mind
	original.enlist_crewmember(visitor)
	original.ship_account.account_balance = 40000
	var/datum/outpost_berth/ship_bay/bay = home.allocate_ship_bay(original)
	TEST_ASSERT_NOTNULL(bay, "Could not allocate the source bay")
	adjust_reserve_dock_to_shuttle(bay.dock, original.shuttle)
	original.shuttle.mode = SHUTTLE_PREARRIVAL
	original.shuttle.initiate_docking(bay.dock)
	original.shuttle.mode = SHUTTLE_IDLE
	original.docked = home
	original.forceMove(home)
	original.state = "idle"
	bay.on_ship_docked(original)
	TEST_ASSERT(bay.is_ship_present(), "The real source hull did not land in the bay")
	var/obj/machinery/ore_silo/silo = home.ship_bay_silo()
	TEST_ASSERT_NOTNULL(silo, "The mapped outpost silo was not discovered without a construction link")
	// No selected silo, no materials and no grants may be required by checkpoints.
	bay.revoke_silo()
	bay.console.disconnect_materials()
	var/turf/fixture_turf
	for(var/turf/tile as anything in original.shuttle.return_turfs())
		if(isfloorturf(tile) && (get_area(tile) in original.shuttle.shuttle_areas))
			fixture_turf = tile
			break
	var/obj/machinery/autolathe/lathe = new(fixture_turf)
	lathe.name = "checkpoint upgrade fixture"
	for(var/datum/stock_part/matter_bin/part in lathe.component_parts.Copy())
		lathe.component_parts -= part
		lathe.component_parts += GLOB.stock_part_datums[/datum/stock_part/matter_bin/tier4]
	lathe.RefreshParts()
	var/expected_bin_rating = lathe.total_part_rating(/datum/stock_part/matter_bin)
	lathe.materials.insert_amount_mat(5000, /datum/material/iron)
	var/obj/machinery/computer/camera_advanced/base_construction/ship/builder = new(fixture_turf)
	for(var/disk_type in list(/obj/item/ship_construction_upgrade/rtd, /obj/item/ship_construction_upgrade/rpd, /obj/item/ship_construction_upgrade/rld, /obj/item/ship_construction_upgrade/decal, /obj/item/ship_construction_upgrade/servo/mk4))
		var/obj/item/disk = new disk_type(builder)
		builder.item_interaction(captain, disk)
	var/expected_construction_upgrades = builder.console_upgrades
	new /obj/machinery/power/shuttle_engine/ship/liquid/oil(fixture_turf)
	new /obj/machinery/vending/cola(fixture_turf)
	var/obj/machinery/ore_silo/ship_silo = new(fixture_turf)
	ship_silo.materials.insert_amount_mat(5000, /datum/material/iron)
	new /obj/item/stack/sheet/iron(fixture_turf, 50)
	var/removed_apc_cell = FALSE
	var/removed_smes_cells = FALSE
	for(var/turf/tile as anything in original.shuttle.return_turfs())
		for(var/obj/machinery/power/apc/controller in tile)
			if(!removed_apc_cell)
				QDEL_NULL(controller.cell)
				removed_apc_cell = TRUE
			else if(controller.cell)
				controller.cell.charge = 0
		for(var/obj/machinery/power/smes/bank in tile)
			for(var/obj/item/stock_parts/power_store/battery in bank.component_parts.Copy())
				if(!removed_smes_cells)
					bank.component_parts -= battery
					qdel(battery)
				else
					battery.charge = 0
			removed_smes_cells = TRUE
			bank.RefreshParts()
	var/datum/ship_checkpoint_ui/registry_test/panel = allocate(__IMPLIED_TYPE__, home, terminal, captain)
	TEST_ASSERT_NOTNULL(panel.save_denial(visitor, bay), "A non-captain could register the hull")
	TEST_ASSERT(panel.prepare_save(captain, bay), "Could not prepare a real hull: [panel.error]")
	TEST_ASSERT(!findtext(panel.quote.tgm, "/obj/item"), "The snapshot includes items")
	TEST_ASSERT(findtext(panel.quote.tgm, "/obj/machinery/computer/helm"), "Checkpoint omitted the helm")
	TEST_ASSERT(!findtext(panel.quote.tgm, "initial_gas_mix"), "The snapshot preserved room gases")
	var/datum/parsed_map/parsed = new(panel.quote.tgm)
	TEST_ASSERT_EQUAL(parsed.bounds[4], panel.quote.width, "Exported width does not parse correctly")
	TEST_ASSERT_EQUAL(parsed.bounds[5], panel.quote.height, "Exported height does not parse correctly")
	qdel(parsed)
	rustg_file_write(panel.quote.tgm, "data/registry-source-hull.dmm")
	var/list/before_counts = count_hull(original.shuttle)
	var/room_count = length(panel.quote.rooms)
	var/before_iron = silo.materials.get_material_amount(/datum/material/iron)
	var/before_money = original.ship_account.account_balance
	var/before_treasury = home.treasury.account_balance
	panel.accept_save = FALSE
	TEST_ASSERT(!panel.save_quote(captain), "Cancelling confirmation still saved a checkpoint")
	TEST_ASSERT_EQUAL(original.ship_account.account_balance, before_money, "Cancellation charged credits")
	panel.accept_save = TRUE
	panel.during_confirmation = CALLBACK(src, PROC_REF(drain_account), original)
	TEST_ASSERT(!panel.save_quote(captain), "Funds spent during confirmation were charged again")
	TEST_ASSERT_EQUAL(length(home.checkpoints), 0, "A declined save created a checkpoint")
	panel.during_confirmation = null
	original.ship_account.account_balance = before_money
	var/datum/ship_checkpoint_ui/registry_test/other_panel = allocate(__IMPLIED_TYPE__, home, terminal, captain)
	TEST_ASSERT(other_panel.prepare_save(captain, bay), "Could not prepare a concurrent save")
	TEST_ASSERT_EQUAL(panel.quoted_fee, 10000, "First checkpoint did not cost 10,000 credits")
	TEST_ASSERT(panel.save_quote(captain), "Could not save a checkpoint without silo access: [panel.error]")
	TEST_ASSERT_EQUAL(before_money - original.ship_account.account_balance, 10000, "Save charged the wrong amount")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, before_treasury, "Checkpoint fee was refunded through the outpost treasury")
	TEST_ASSERT(!other_panel.save_quote(captain), "A stale save overwrote the paid checkpoint")
	var/datum/ship_checkpoint/snapshot = home.checkpoints[1]
	TEST_ASSERT(!panel.save_quote(captain), "A repeated save reused the paid snapshot")
	// Updating must capture the newest design, charge 5k and preserve the old one on failure.
	lathe.name = "updated checkpoint fixture"
	TEST_ASSERT(panel.prepare_save(captain, bay), "Could not prepare an update")
	TEST_ASSERT_EQUAL(panel.quoted_fee, 5000, "Updating did not cost 5,000 credits")
	panel.accept_save = FALSE
	TEST_ASSERT(!panel.save_quote(captain) && home.checkpoints[1] == snapshot, "Cancelled update lost the old checkpoint")
	panel.accept_save = TRUE
	original.ship_account.account_balance = 4999
	TEST_ASSERT(!panel.save_quote(captain) && home.checkpoints[1] == snapshot, "Unaffordable update lost the old checkpoint")
	original.ship_account.account_balance = before_money - 10000
	TEST_ASSERT(panel.save_quote(captain), "Could not update a checkpoint")
	TEST_ASSERT(QDELETED(snapshot), "Update retained the old snapshot")
	TEST_ASSERT_EQUAL(length(home.checkpoints), 1, "Updating created a second checkpoint")
	TEST_ASSERT_EQUAL(before_money - original.ship_account.account_balance, 15000, "Save and update charged the wrong total")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, before_treasury, "Update fee was refunded through the outpost treasury")
	TEST_ASSERT_EQUAL(silo.materials.get_material_amount(/datum/material/iron), before_iron, "Checkpoint consumed silo materials")
	snapshot = home.checkpoints[1]
	TEST_ASSERT(findtext(snapshot.tgm, "updated checkpoint fixture"), "Update retained the older design")
	TEST_ASSERT_NOTNULL(panel.rebuild_denial(captain, snapshot), "A crewed original permitted a second hull")
	TEST_ASSERT_NOTNULL(panel.rebuild_denial(visitor, snapshot), "A non-captain could recover another captain's hull")
	// Move the original out of its construction bay, then abandon it.
	var/obj/docking_port/stationary/transit/source_transit = original.shuttle.assigned_transit || SSshuttle.generate_transit_dock(original.shuttle)
	original.shuttle.mode = SHUTTLE_PREARRIVAL
	TEST_ASSERT_EQUAL(original.shuttle.initiate_docking(source_transit), DOCKING_SUCCESS, "Source hull could not enter transit")
	original.shuttle.mode = SHUTTLE_IDLE
	original.docked = null
	original.forceMove(get_turf(home))
	original.state = "flying"
	home.on_ship_undock_complete(original)
	TEST_ASSERT_EQUAL(home.bay_berths[1], bay, "Departure replaced the permanent bay")
	TEST_ASSERT(bay.is_available(), "Departure retained the old ship reservation")
	var/old_balance = original.ship_account.account_balance
	if(orphaned_original)
		// Reproduce the old admin deletion's resulting state without its known
		// unexpected-port-deletion stack trace polluting this regression case.
		var/obj/docking_port/mobile/old_port = original.detach_shuttle()
		old_port.jumpToNullSpace()
		TEST_ASSERT(!QDELETED(original) && !original.abandoned && !original.shuttle, "The orphan fixture still has a hull or was abandoned")
		TEST_ASSERT_NULL(panel.rebuild_denial(captain, snapshot), "A hull-less overmap record blocks recovery")
		original.retired_by_checkpoint = TRUE
		TEST_ASSERT_NOTNULL(panel.rebuild_denial(captain, snapshot), "A retired hull-less record bypassed duplicate protection")
		original.retired_by_checkpoint = FALSE
		original.checkpoint_rebuilding = TRUE
		TEST_ASSERT_NOTNULL(panel.rebuild_denial(captain, snapshot), "A hull-less record bypassed concurrent recovery protection")
		original.checkpoint_rebuilding = FALSE
	else if(!destroy_original)
		original.abandon_ship(crash = FALSE)
		TEST_ASSERT_NULL(panel.rebuild_denial(captain, snapshot), "The registered captain cannot recover an abandoned hull")
	if(destroy_original)
		if(delete_via_admin)
			var/obj/docking_port/mobile/old_port = original.shuttle
			TEST_ASSERT(old_port.admin_delete_shuttle(escape = escape_on_delete), "The admin deletion was refused")
			TEST_ASSERT(QDELETED(old_port) && QDELETED(original), "Admin deletion left the hull or overmap ship alive")
			TEST_ASSERT(!(original in SSovermap.simulated_ships), "Admin deletion retained its fleet entry")
		else
			qdel(original)
		TEST_ASSERT(snapshot in home.checkpoints, "Deleting the original consumed its paid registration")
		old_balance = 0
		qdel(panel)
		captain.key = null
		captain = make_player(terminal_turf, "registrycaptain")
		panel = allocate(__IMPLIED_TYPE__, home, terminal, captain)
		TEST_ASSERT_NULL(panel.rebuild_denial(captain, snapshot), "A new body with the saved captain's key cannot recover a destroyed hull")
	var/list/recovery_data = panel.ui_data(captain)
	TEST_ASSERT_EQUAL(length(recovery_data["bays"]), 0, "An empty permanent bay was offered as a docked ship")
	TEST_ASSERT_EQUAL(length(recovery_data["blueprints"]), 1, "The terminal lost the captain's saved hull")
	var/list/saved_hull = recovery_data["blueprints"][1]
	TEST_ASSERT_NULL(saved_hull["denial"], "The recovery button remains disabled after losing the original")
	var/before_recovery_iron = silo.materials.get_material_amount(/datum/material/iron)
	if(!destroy_original)
		home.refuse_bay = TRUE
		TEST_ASSERT(!panel.rebuild(captain, snapshot), "A failed bay allocation reported a successful rebuild")
		TEST_ASSERT(snapshot in home.checkpoints, "A failed rebuild consumed the registration")
		TEST_ASSERT(!snapshot.busy && !original.checkpoint_rebuilding && !original.retired_by_checkpoint, "A failed rebuild left a recovery or retirement lock")
		TEST_ASSERT_NULL(SSshuttle.preview_shuttle, "A failed rebuild leaked its preview ship")
		TEST_ASSERT_NULL(SSshuttle.preview_reservation, "A failed rebuild leaked its preview reservation")
		TEST_ASSERT_NULL(SSshuttle.active_template_load, "A failed rebuild locked the shuttle loader")
		TEST_ASSERT_EQUAL(original.ship_account.account_balance, old_balance, "A failed rebuild changed the original balance")
		TEST_ASSERT(bay.is_available(), "Failed recovery retained the bay reservation")
		home.refuse_bay = FALSE
	TEST_ASSERT(panel.rebuild(captain, snapshot), "Rebuild failed: [panel.error]")
	TEST_ASSERT_EQUAL(silo.materials.get_material_amount(/datum/material/iron), before_recovery_iron, "Rebuilding charged materials a second time")
	var/datum/outpost_berth/ship_bay/rebuilt_bay = home.bay_berths[1]
	TEST_ASSERT_EQUAL(rebuilt_bay, bay, "Recovery replaced the permanent bay")
	TEST_ASSERT_NULL(bay.rebuild_owner, "Successful recovery retained the build reservation")
	var/obj/structure/overmap/ship/rebuilt = rebuilt_bay.ship
	test_ships += rebuilt
	TEST_ASSERT(rebuilt_bay.is_ship_present(), "Recovered ship is not physically docked")
	TEST_ASSERT(rebuilt.is_ship_captain(captain), "Recovered captain lacks command")
	TEST_ASSERT_EQUAL(rebuilt.ship_account.account_balance, old_balance, "Recovery minted money or lost the original account")
	if(orphaned_original)
		TEST_ASSERT(QDELETED(original), "Recovery retained the hull-less overmap record")
	else if(!destroy_original)
		TEST_ASSERT_EQUAL(original.ship_account.account_balance, 0, "The original kept its transferred balance")
		TEST_ASSERT(original.retired_by_checkpoint, "The original hull was not retired")
		TEST_ASSERT(!original.claim_abandoned_ship(visitor), "A retired hull can still be claimed")
	TEST_ASSERT_EQUAL(length(home.checkpoints), 0, "Successful recovery did not consume the registration")
	TEST_ASSERT(QDELETED(snapshot), "Consumed snapshot leaked")
	TEST_ASSERT(!panel.rebuild(captain, snapshot), "The consumed registration rebuilt twice")
	TEST_ASSERT_EQUAL(length(hull_owned_areas(rebuilt.shuttle)), room_count, "Recovery claimed padding or lost a room")
	var/list/after_counts = count_hull(rebuilt.shuttle)
	for(var/type_name in (before_counts | after_counts))
		if(after_counts[type_name] != before_counts[type_name])
			TEST_FAIL("Hull infrastructure changed for [type_name]: expected [before_counts[type_name]], got [after_counts[type_name]]")
	for(var/turf/tile as anything in rebuilt.shuttle.return_turfs())
		if(!(get_area(tile) in rebuilt.shuttle.shuttle_areas))
			continue
		for(var/obj/structure/closet/storage in tile)
			storage.dump_contents() // First use must not spawn fresh default stock.
		for(var/obj/item/item in tile.get_all_contents())
			if(ismachinery(item.loc))
				var/obj/machinery/machine = item.loc
				if(istype(machine, /obj/machinery/computer/camera_advanced/base_construction/ship) && (istype(item, /obj/item/construction) || istype(item, /obj/item/pipe_dispenser) || istype(item, /obj/item/airlock_painter)))
					continue
				if((item in machine.component_parts) || istype(item, /obj/item/radio))
					continue
				if(istype(machine, /obj/machinery/power/apc))
					var/obj/machinery/power/apc/controller = machine
					if(item == controller.cell)
						continue
				if(istype(machine, /obj/machinery/atmospherics/components/unary/shuttle/heater))
					var/obj/machinery/atmospherics/components/unary/shuttle/heater/heater = machine
					if(item == heater.fuel_tank)
						continue
			if(istype(item, /obj/item/encryptionkey) && istype(item.loc, /obj/item/radio))
				continue
			TEST_FAIL("Rebuilt checkpoint contains a free item: [item.type], loc=[item.loc?.type], deleted=[QDELETED(item)]")
		for(var/obj/machinery/power/apc/controller in tile)
			TEST_ASSERT(controller.cell?.charge > controller.cell?.maxcharge * 0.99, "APC did not recover with a charged battery")
		for(var/obj/machinery/power/smes/bank in tile)
			var/capacity = 0
			var/stored = 0
			for(var/obj/item/stock_parts/power_store/battery in bank.component_parts)
				capacity += battery.maxcharge
				stored += battery.charge
			TEST_ASSERT(capacity > 0 && stored > capacity * 0.99, "SMES did not recover charged batteries: [stored]/[capacity]")
		for(var/obj/machinery/autolathe/restored_lathe in tile)
			if(restored_lathe.name == "updated checkpoint fixture")
				TEST_ASSERT_EQUAL(restored_lathe.total_part_rating(/datum/stock_part/matter_bin), expected_bin_rating, "Recovery lost fitted upgrades")
			TEST_ASSERT_EQUAL(restored_lathe.materials.get_material_amount(/datum/material/iron), 0, "Recovery copied lathe stock")
		for(var/obj/machinery/computer/camera_advanced/base_construction/ship/restored_builder in tile)
			TEST_ASSERT_EQUAL(restored_builder.console_upgrades, expected_construction_upgrades, "Construction console lost its installed upgrades")
			TEST_ASSERT(!QDELETED(restored_builder.internal_rcd) && !QDELETED(restored_builder.internal_rtd) && !QDELETED(restored_builder.internal_rpd) && !QDELETED(restored_builder.internal_rld) && !QDELETED(restored_builder.internal_painter), "Construction console lost its internal tools")
			TEST_ASSERT_EQUAL(restored_builder.internal_rcd.matter, 0, "Construction console recovered free material charges")
			TEST_ASSERT_NULL(restored_builder.internal_painter.ink, "Construction console recovered a toner cartridge")
		for(var/obj/machinery/ore_silo/restored_silo in tile)
			TEST_ASSERT_EQUAL(restored_silo.materials.get_material_amount(/datum/material/iron), 0, "Recovery copied silo materials")
		for(var/obj/machinery/vending/vendor in tile)
			for(var/datum/data/vending_product/product as anything in vendor.product_records + vendor.hidden_records + vendor.coin_records)
				TEST_ASSERT_EQUAL(product.amount, 0, "Recovery restocked a vendor")
		for(var/obj/machinery/atmospherics/machine in tile)
			for(var/datum/pipeline/network as anything in machine.return_pipenets())
				TEST_ASSERT(!network?.air?.total_moles(), "Rebuilt pipe network contains free gas")
	TEST_ASSERT(length(rebuilt.helm_consoles), "Recovered ship has no connected helm")
	for(var/obj/machinery/computer/helm/helm as anything in rebuilt.helm_consoles)
		TEST_ASSERT_EQUAL(helm.current_ship, rebuilt, "Helm remained attached to the old ship")
		TEST_ASSERT(helm.powered(), "Recovered helm is unpowered")
	rebuilt.refresh_engines()
	var/thrust = 0
	for(var/obj/machinery/power/shuttle_engine/ship/engine in rebuilt.shuttle.engine_list)
		if(istype(engine, /obj/machinery/power/shuttle_engine/ship/liquid))
			TEST_ASSERT(engine.return_fuel() > 0, "Liquid engine has no fuel")
		if(istype(engine, /obj/machinery/power/shuttle_engine/ship/fueled))
			TEST_ASSERT(engine.return_fuel() > 0, "Gas engine has no fuel")
		thrust += engine.burn_engine(100, rebuilt.mass, 1)
	TEST_ASSERT(thrust > 0, "Recovered engines cannot produce thrust")
	var/obj/docking_port/stationary/transit/recovery_transit = SSshuttle.generate_transit_dock(rebuilt.shuttle)
	TEST_ASSERT_NOTNULL(recovery_transit, "Recovered hull has no transit destination")
	rebuilt.shuttle.mode = SHUTTLE_PREARRIVAL
	TEST_ASSERT_EQUAL(rebuilt.shuttle.initiate_docking(recovery_transit), DOCKING_SUCCESS, "Recovered hull cannot depart")
	rebuilt.shuttle.mode = SHUTTLE_IDLE
	rebuilt.docked = null
	rebuilt.forceMove(get_turf(home))
	rebuilt.state = "flying"
	home.on_ship_undock_complete(rebuilt)
	TEST_ASSERT_EQUAL(home.bay_berths[1], rebuilt_bay, "Recovered ship departure replaced the permanent bay")
	TEST_ASSERT(!QDELETED(rebuilt_bay.reservation) && rebuilt_bay.is_available(), "Recovered ship departure unloaded or retained its bay reservation")
	TEST_ASSERT_EQUAL(home.get_floor_alcove(rebuilt_bay.berth_number), rebuilt_bay.alcove_turfs, "Recovered ship departure removed elevator access")
