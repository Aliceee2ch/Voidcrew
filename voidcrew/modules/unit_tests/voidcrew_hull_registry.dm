/// Confirmations exercise the real save transaction without a connected client.
/datum/hull_registry_ui/registry_test
	var/datum/callback/during_confirmation

/datum/hull_registry_ui/registry_test/confirm_save(mob/user, prompt_text)
	during_confirmation?.Invoke()
	return TRUE

/// Refuse allocation after the real preview load to exercise transaction rollback.
/obj/structure/overmap/dynamic/player_outpost/registry_test
	var/refuse_bay = FALSE

/obj/structure/overmap/dynamic/player_outpost/registry_test/allocate_ship_bay(obj/structure/overmap/ship/visitor)
	if(refuse_bay)
		return null
	return ..()

/datum/unit_test/voidcrew_hull_registry
	parent_type = /datum/unit_test/voidcrew_outpost_management
	var/list/obj/structure/overmap/ship/test_ships = list()
	var/destroy_original = FALSE

/// Recovery must also work after the hull and the captain's original body are gone.
/datum/unit_test/voidcrew_hull_registry/lost
	destroy_original = TRUE

/datum/unit_test/voidcrew_hull_registry/Destroy()
	// Dispose ships before their host reservations, just as normal departures do.
	for(var/obj/structure/overmap/ship/ship as anything in test_ships)
		if(!QDELETED(ship))
			qdel(ship)
	return ..()

/datum/unit_test/voidcrew_hull_registry/proc/revoke(datum/outpost_berth/ship_bay/bay)
	bay.revoke_silo()

/datum/unit_test/voidcrew_hull_registry/proc/count_hull(obj/docking_port/mobile/port)
	var/list/counts = list()
	for(var/turf/tile as anything in port.return_turfs())
		if(!(get_area(tile) in port.shuttle_areas))
			continue
		counts["[tile.type]"]++
		for(var/obj/object in tile)
			if(is_type_in_typecache(object, GLOB.outpost_registry_structures) || is_type_in_typecache(object, GLOB.outpost_registry_infrastructure))
				// Storage shells intentionally omit the original loot-spawner subtype.
				counts[istype(object, /obj/structure/closet) ? "closet:[object.name]" : "[object.type]"]++
	return counts

/datum/unit_test/voidcrew_hull_registry/Run()
	var/obj/structure/overmap/dynamic/player_outpost/registry_test/home = allocate(__IMPLIED_TYPE__)
	home.shell_template = allocate(/datum/map_template/player_outpost/small)
	home.founder_ckey = "registrycaptain"
	TEST_ASSERT(home.load_level(), "The registry outpost did not load")
	home.ship_bay_installed = TRUE
	home.bay_berths.len = 2
	var/turf/terminal_turf = get_turf(home.management_console)
	var/mob/living/carbon/human/captain = make_player(terminal_turf, "registrycaptain")
	var/mob/living/carbon/human/visitor = make_player(terminal_turf, "registryvisitor")
	var/obj/structure/overmap/ship/original = SSshuttle.create_ship(/datum/map_template/shuttle/voidcrew/box)
	TEST_ASSERT_NOTNULL(original, "Could not create the source hull")
	test_ships += original
	original.enlist_crewmember(captain)
	original.claimed_captain = captain.mind
	original.enlist_crewmember(visitor)
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
	var/obj/machinery/ore_silo/silo = allocate(__IMPLIED_TYPE__, get_turf(home.construction_console))
	home.construction_console.link_internal_device(home.construction_console.internal_rcd, home.construction_console.internal_rcd.silo_mats, silo)
	silo.materials.insert_amount_mat(1000000, /datum/material/iron)
	silo.materials.insert_amount_mat(1000000, /datum/material/glass)
	TEST_ASSERT(bay.request_silo(captain) && bay.approve_silo(captain), "Could not approve the test materials")
	var/datum/hull_registry_ui/registry_test/panel = allocate(__IMPLIED_TYPE__, home, home.management_console, captain)
	TEST_ASSERT_NOTNULL(panel.save_denial(visitor, bay), "A non-captain could register the hull")
	TEST_ASSERT(panel.prepare_save(captain, bay), "Could not prepare a real hull: [panel.error]")
	TEST_ASSERT(!findtext(panel.quote.tgm, "/obj/item"), "The snapshot includes items")
	TEST_ASSERT(!findtext(panel.quote.tgm, "/obj/machinery/computer/helm"), "Hull tier includes non-infrastructure machinery")
	TEST_ASSERT(!findtext(panel.quote.tgm, "initial_gas_mix"), "The snapshot preserved room gases")
	TEST_ASSERT(length(panel.quote.material_cost) > 0, "The snapshot has no material cost")
	var/datum/parsed_map/parsed = new(panel.quote.tgm)
	TEST_ASSERT_EQUAL(parsed.bounds[4], panel.quote.width, "Exported width does not parse correctly")
	TEST_ASSERT_EQUAL(parsed.bounds[5], panel.quote.height, "Exported height does not parse correctly")
	qdel(parsed)
	rustg_file_write(panel.quote.tgm, "data/registry-source-hull.dmm")
	var/list/before_counts = count_hull(original.shuttle)
	var/room_count = length(panel.quote.rooms)
	var/list/cost = panel.quote.material_cost.Copy()
	var/before_iron = silo.materials.get_material_amount(/datum/material/iron)
	panel.during_confirmation = CALLBACK(src, PROC_REF(revoke), bay)
	TEST_ASSERT(!panel.save_quote(captain), "Revocation during confirmation still charged the silo")
	TEST_ASSERT_EQUAL(silo.materials.get_material_amount(/datum/material/iron), before_iron, "A refused save consumed material")
	TEST_ASSERT_EQUAL(length(home.hull_registry), 0, "A refused save created a registration")
	panel.during_confirmation = null
	TEST_ASSERT(bay.request_silo(captain) && bay.approve_silo(captain), "Could not reapprove materials")
	TEST_ASSERT(panel.prepare_save(captain, bay), "Could not refresh the quote")
	silo.materials.use_amount_mat(before_iron, /datum/material/iron)
	TEST_ASSERT(!panel.save_quote(captain), "An unaffordable save was accepted")
	TEST_ASSERT_EQUAL(length(home.hull_registry), 0, "An unaffordable save created a registration")
	silo.materials.insert_amount_mat(before_iron, /datum/material/iron)
	TEST_ASSERT(panel.save_quote(captain), "Could not save the paid hull: [panel.error]")
	TEST_ASSERT_EQUAL(before_iron - silo.materials.get_material_amount(/datum/material/iron), cost[/datum/material/iron], "Save charged the wrong material amount")
	var/datum/hull_blueprint/snapshot = home.hull_registry[1]
	TEST_ASSERT(!panel.save_quote(captain), "A repeated Save reused the paid quote")
	TEST_ASSERT(panel.prepare_save(captain, bay) && panel.save_quote(captain), "Could not replace a registration")
	TEST_ASSERT_EQUAL(length(home.hull_registry), 1, "Replacing a registration created a second recovery")
	TEST_ASSERT(QDELETED(snapshot), "Replaced registration was not deleted")
	snapshot = home.hull_registry[1]
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
	original.abandon_ship(crash = FALSE)
	TEST_ASSERT_NULL(panel.rebuild_denial(captain, snapshot), "The registered captain cannot recover an abandoned hull")
	var/old_balance = original.ship_account.account_balance
	if(destroy_original)
		qdel(original)
		old_balance = 0
		qdel(panel)
		captain.key = null
		captain = make_player(terminal_turf, "registrycaptain")
		panel = allocate(__IMPLIED_TYPE__, home, home.management_console, captain)
		TEST_ASSERT_NULL(panel.rebuild_denial(captain, snapshot), "A new body with the saved captain's key cannot recover a destroyed hull")
	var/before_recovery_iron = silo.materials.get_material_amount(/datum/material/iron)
	if(!destroy_original)
		home.refuse_bay = TRUE
		TEST_ASSERT(!panel.rebuild(captain, snapshot), "A failed bay allocation reported a successful rebuild")
		TEST_ASSERT(snapshot in home.hull_registry, "A failed rebuild consumed the registration")
		TEST_ASSERT(!snapshot.busy && !original.registry_rebuilding && !original.retired_by_registry, "A failed rebuild left a recovery or retirement lock")
		TEST_ASSERT_NULL(SSshuttle.preview_shuttle, "A failed rebuild leaked its preview ship")
		TEST_ASSERT_NULL(SSshuttle.preview_reservation, "A failed rebuild leaked its preview reservation")
		TEST_ASSERT_NULL(SSshuttle.active_template_load, "A failed rebuild locked the shuttle loader")
		TEST_ASSERT_EQUAL(original.ship_account.account_balance, old_balance, "A failed rebuild changed the original balance")
		home.refuse_bay = FALSE
	TEST_ASSERT(panel.rebuild(captain, snapshot), "Rebuild failed: [panel.error]")
	TEST_ASSERT_EQUAL(silo.materials.get_material_amount(/datum/material/iron), before_recovery_iron, "Rebuilding charged materials a second time")
	var/datum/outpost_berth/ship_bay/rebuilt_bay = home.bay_berths[1]
	TEST_ASSERT_NOTNULL(rebuilt_bay, "Recovery did not allocate a bay")
	var/obj/structure/overmap/ship/rebuilt = rebuilt_bay.ship
	test_ships += rebuilt
	TEST_ASSERT(rebuilt_bay.is_ship_present(), "Recovered ship is not physically docked")
	TEST_ASSERT(rebuilt.is_ship_captain(captain), "Recovered captain lacks command")
	TEST_ASSERT_EQUAL(rebuilt.ship_account.account_balance, old_balance, "Recovery minted money or lost the original account")
	if(!destroy_original)
		TEST_ASSERT_EQUAL(original.ship_account.account_balance, 0, "The original kept its transferred balance")
		TEST_ASSERT(original.retired_by_registry, "The original hull was not retired")
		TEST_ASSERT(!original.claim_abandoned_ship(visitor), "A retired hull can still be claimed")
	TEST_ASSERT_EQUAL(length(home.hull_registry), 0, "Successful recovery did not consume the registration")
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
			TEST_ASSERT(!istype(item, /obj/item/stock_parts/power_store/cell) && !istype(item, /obj/item/tank), "Recovered hull contains [item.type] inside [item.loc.type]")
			if(ismachinery(item.loc))
				var/obj/machinery/machine = item.loc
				if(item in machine.component_parts)
					continue // Fresh stock construction parts, never copied inventory/upgrades.
			TEST_FAIL("Rebuilt hull contains a free item: [item.type]")
		for(var/obj/machinery/atmospherics/machine in tile)
			for(var/datum/pipeline/network as anything in machine.return_pipenets())
				TEST_ASSERT(!network?.air?.total_moles(), "Rebuilt pipe network contains free gas")
	var/obj/docking_port/stationary/transit/recovery_transit = SSshuttle.generate_transit_dock(rebuilt.shuttle)
	TEST_ASSERT_NOTNULL(recovery_transit, "Recovered hull has no transit destination")
	rebuilt.shuttle.mode = SHUTTLE_PREARRIVAL
	TEST_ASSERT_EQUAL(rebuilt.shuttle.initiate_docking(recovery_transit), DOCKING_SUCCESS, "Recovered hull cannot depart")
	rebuilt.shuttle.mode = SHUTTLE_IDLE
	rebuilt.docked = null
	rebuilt.forceMove(get_turf(home))
	rebuilt.state = "flying"
	home.on_ship_undock_complete(rebuilt)
	TEST_ASSERT(QDELETED(rebuilt_bay), "Recovered ship departure leaked its bay")
