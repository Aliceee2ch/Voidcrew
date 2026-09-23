GLOBAL_DATUM(outpost_ship_bay_template, /datum/map_template/outpost_hangar/ship_bay)

/datum/map_template/outpost_hangar/ship_bay
	name = "Outpost Ship Bay"
	mappath = "voidcrew/_maps/map_files/outposts/outpost_ship_bay.dmm"

/obj/structure/overmap/dynamic/player_outpost
	var/ship_bay_installed = FALSE
	/// Separate from ordinary hangars; each visit owns its reservation and permissions.
	var/list/datum/outpost_berth/ship_bay/bay_berths = list()
	/// Never reuse an elevator destination while an old ride could still be pending.
	var/next_bay_floor_id = OUTPOST_MAX_BERTHS + 2
	var/list/pending_dock_variants = list()
	/// Service storage can be selected without connecting a construction tool.
	var/datum/weakref/service_silo

/obj/structure/overmap/dynamic/player_outpost/proc/ship_bay_material_cost()
	return list(/datum/material/iron = 100 * SHEET_MATERIAL_AMOUNT, /datum/material/glass = 50 * SHEET_MATERIAL_AMOUNT)

/// Prefer an explicit selection, then the existing construction link, then the only local silo.
/obj/structure/overmap/dynamic/player_outpost/proc/ship_bay_silo()
	var/obj/machinery/ore_silo/selected = service_silo?.resolve()
	if(!QDELETED(selected) && get_outpost_from_atom(selected) == src)
		return selected
	var/obj/machinery/ore_silo/silo = construction_console?.get_linked_silo()
	if(!QDELETED(silo) && get_outpost_from_atom(silo) == src)
		return silo
	var/list/available = service_silos()
	return length(available) == 1 ? available[1] : null

/obj/structure/overmap/dynamic/player_outpost/proc/service_silos()
	var/list/available = list()
	for(var/obj/machinery/ore_silo/silo as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/ore_silo))
		if(!QDELETED(silo) && get_outpost_from_atom(silo) == src)
			available += silo
	return available

/obj/structure/overmap/dynamic/player_outpost/proc/select_service_silo(mob/user, obj/machinery/ore_silo/silo)
	if(!is_current_treasury_user(user))
		return FALSE
	return link_service_silo(silo)

/// Permission is checked by the player panel or the admin manipulator before calling.
/obj/structure/overmap/dynamic/player_outpost/proc/link_service_silo(obj/machinery/ore_silo/silo)
	if(QDELETED(silo) || get_outpost_from_atom(silo) != src)
		return FALSE
	service_silo = WEAKREF(silo)
	for(var/datum/outpost_berth/ship_bay/bay as anything in bay_berths)
		bay?.reconcile_silo()
	return TRUE

/obj/structure/overmap/dynamic/player_outpost/proc/ship_bay_install_denial(mob/user)
	if(!is_current_management_user(user) || !can_spend(user))
		return "Management and treasury access required."
	var/denial = ship_bay_setup_denial()
	if(denial)
		return denial
	if(!treasury || treasury.account_balance < OUTPOST_SHIP_BAY_COST)
		return "Insufficient outpost funds."
	var/obj/machinery/ore_silo/silo = ship_bay_silo()
	if(!silo)
		return "Select an outpost material silo in Docking."
	if(!silo.materials?.has_materials(ship_bay_material_cost()))
		return "The outpost silo needs 100 iron sheets and 50 glass sheets."
	return null

/// Structural requirements shared by paid installation and administrative grants.
/obj/structure/overmap/dynamic/player_outpost/proc/ship_bay_setup_denial()
	if(ship_bay_installed)
		return "Ship bay already installed."
	if(loading || !loaded || !has_hangar_elevator())
		return "An operational outpost elevator is required."
	return null

/// Caller authorizes and, for normal installation, charges before enabling the slots.
/obj/structure/overmap/dynamic/player_outpost/proc/enable_ship_bays()
	var/denial = ship_bay_setup_denial()
	if(denial)
		return denial
	ship_bay_installed = TRUE
	bay_berths.len = OUTPOST_SHIP_BAY_SLOTS
	refresh_elevator_uis()
	return null

/// No prompts or map loading between validation and payment.
/obj/structure/overmap/dynamic/player_outpost/proc/install_ship_bay(mob/user)
	var/denial = ship_bay_install_denial(user)
	if(denial)
		return denial
	var/obj/machinery/ore_silo/silo = ship_bay_silo()
	if(!treasury.adjust_money(-OUTPOST_SHIP_BAY_COST, "Ship bay installation by [user.ckey]"))
		return "Insufficient outpost funds."
	silo.materials.use_materials(ship_bay_material_cost())
	enable_ship_bays()
	log_game("[key_name(user)] installed ship bays at [src].")
	return null

/obj/structure/overmap/dynamic/player_outpost/proc/allocate_ship_bay(obj/structure/overmap/ship/visitor)
	if(!ship_bay_installed || QDELETED(visitor) || QDELETED(visitor.shuttle))
		return null
	var/slot = 0
	for(var/i in 1 to length(bay_berths))
		if(bay_berths[i]?.ship == visitor)
			return null
		if(!bay_berths[i] && !slot)
			slot = i
	if(!slot)
		return null
	// Claim the slot before the reservation and template loader can yield.
	var/datum/outpost_berth/ship_bay/bay = new(src, next_bay_floor_id++, visitor)
	bay.bay_number = slot
	bay_berths[slot] = bay
	if(!GLOB.outpost_ship_bay_template)
		GLOB.outpost_ship_bay_template = new
	var/datum/map_template/outpost_hangar/ship_bay/template = GLOB.outpost_ship_bay_template
	var/datum/turf_reservation/reserved = SSmapping.request_turf_block_reservation(template.width, template.height, 1, requester = "ship bay for '[visitor.name]' at '[name]'")
	if(!reserved)
		qdel(bay)
		return null
	// Keep the reservation local through loading: deleting the host must not wipe
	// turfs underneath a suspended map loader. Transfer ownership after validation.
	var/turf/origin = reserved.bottom_left_turfs[1]
	var/loaded_bay = template.load(origin)
	if(!loaded_bay || QDELETED(src) || QDELETED(bay) || QDELETED(visitor) || QDELETED(visitor.shuttle))
		qdel(reserved)
		if(!QDELETED(bay))
			qdel(bay)
		return null
	bay.reservation = reserved
	bay.hangar_bottom_left = origin
	if(!bay.link_hangar_contents())
		qdel(bay)
		return null
	bay.setup_signals()
	refresh_elevator_uis()
	return bay

/obj/structure/overmap/dynamic/player_outpost/proc/revoke_bay_materials()
	for(var/datum/outpost_berth/ship_bay/bay as anything in bay_berths)
		bay?.revoke_silo()

/obj/structure/overmap/dynamic/player_outpost/refresh_elevator_uis()
	. = ..()
	for(var/datum/outpost_berth/ship_bay/bay as anything in bay_berths)
		if(bay?.panel)
			SStgui.update_uis(bay.panel)

/datum/outpost_berth/ship_bay
	var/bay_number
	var/obj/machinery/computer/camera_advanced/base_construction/ship/bay/console
	var/silo_requested_at
	var/datum/weakref/approved_silo
	var/silo_owner_ckey

/datum/outpost_berth/ship_bay/Destroy()
	var/obj/structure/overmap/dynamic/player_outpost/home = outpost
	if(home && bay_number && LAZYACCESS(home.bay_berths, bay_number) == src)
		home.bay_berths[bay_number] = null
	revoke_silo()
	if(console)
		console.disconnect_materials()
		console.current_ship = null
		console.berth = null
		qdel(console)
		console = null
	return ..()

/datum/outpost_berth/ship_bay/link_hangar_contents()
	if(!..())
		return FALSE
	for(var/turf/location as anything in reservation.reserved_turfs)
		console = locate(/obj/machinery/computer/camera_advanced/base_construction/ship/bay) in location
		if(console)
			break
	if(!console)
		log_mapping("OUTPOST SHIP BAY: missing construction console.")
		return FALSE
	console.berth = src
	console.attempt_ship_connection()
	dock.name = "[outpost.name] Ship Bay [bay_number]"
	for(var/obj/machinery/status_display/outpost_berth/sign as anything in status_signs)
		sign.set_messages("BAY [bay_number]", ship.name)
	return TRUE

/datum/outpost_berth/ship_bay/on_ship_docked(datum/source)
	SIGNAL_HANDLER
	if(QDELETED(ship) || dock?.get_docked() != ship.shuttle)
		return
	arrived = TRUE
	if(arrival_watchdog)
		deltimer(arrival_watchdog)
		arrival_watchdog = null
	if(!console?.use_outpost_silo())
		console?.use_ship_silo()
	ship.ship_notify("Docked at [outpost.name], Ship Bay [bay_number]. The construction console is beside the south elevator. Bay equipment connects automatically to your outpost's silo, or your ship's silo when visiting. Choose the material source at the console.", "SHIP BAY", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

/datum/outpost_berth/ship_bay/proc/is_ship_present()
	return !QDELETED(outpost) && !QDELETED(ship) && !QDELETED(ship.shuttle) && ship.docked == outpost && ship.state == OVERMAP_SHIP_IDLE && dock?.get_docked() == ship.shuttle

/datum/outpost_berth/ship_bay/proc/request_silo(mob/user)
	if(!is_ship_present() || !console?.is_crew_member(user))
		return FALSE
	var/obj/structure/overmap/dynamic/player_outpost/home = outpost
	if(!home.founder_ckey || !home.ship_bay_silo())
		return FALSE
	if(console.use_outpost_silo())
		silo_requested_at = null
		return TRUE
	if(!silo_requested_at)
		silo_requested_at = world.time || 1
		home.notify_owner("[ship.name] requests outpost materials in Ship Bay [bay_number]. Review the request in Docking.", "SHIP BAY")
	return TRUE

/datum/outpost_berth/ship_bay/proc/approve_silo(mob/user)
	reconcile_silo()
	var/obj/structure/overmap/dynamic/player_outpost/home = outpost
	if(!is_ship_present() || !home.is_current_management_user(user) || !home.can_spend(user) || !silo_requested_at)
		return FALSE
	return grant_silo(user)

/// Called after owner approval or an authenticated administrative override.
/datum/outpost_berth/ship_bay/proc/grant_silo(mob/user)
	var/obj/structure/overmap/dynamic/player_outpost/home = outpost
	if(!is_ship_present() || !home.founder_ckey || QDELETED(console))
		return FALSE
	var/obj/machinery/ore_silo/silo = home.ship_bay_silo()
	if(!silo)
		return FALSE
	approved_silo = WEAKREF(silo)
	silo_owner_ckey = home.founder_ckey
	silo_requested_at = null
	if(!console.link_materials(silo))
		revoke_silo()
		return FALSE
	log_game("[key_name(user)] approved outpost silo access for [ship] at [home] Ship Bay [bay_number].")
	return TRUE

/datum/outpost_berth/ship_bay/proc/revoke_silo()
	silo_requested_at = null
	approved_silo = null
	silo_owner_ckey = null
	if(console && !QDELETED(console.get_linked_silo()) && get_outpost_from_atom(console.get_linked_silo()) == outpost)
		console.disconnect_materials()
		console.use_ship_silo()

/datum/outpost_berth/ship_bay/proc/reconcile_silo()
	if(silo_requested_at && world.time - silo_requested_at >= OUTPOST_DOCK_REQUEST_TIMEOUT)
		silo_requested_at = null
	var/obj/structure/overmap/dynamic/player_outpost/home = outpost
	if(approved_silo && (!is_ship_present() || home.founder_ckey != silo_owner_ckey || home.ship_bay_silo() != approved_silo.resolve() || !console?.can_link_silo(approved_silo.resolve())))
		revoke_silo()
	// Automatic owner access is checked on every tool use too. Never retain a
	// stale connection after ownership, crew membership or the selected silo changes.
	var/obj/machinery/ore_silo/linked = console?.get_linked_silo()
	if(linked && !console.can_link_silo(linked))
		console.disconnect_materials()
		if(!console.use_outpost_silo())
			console.use_ship_silo()
	if(silo_requested_at && home?.is_owner_crew_ship(ship))
		silo_requested_at = null

/// A shore-side console exclusively bound to this visit, even before the ship lands.
/obj/machinery/computer/camera_advanced/base_construction/ship/bay
	name = "ship bay construction console"
	desc = "An outpost fabrication console for the ship in this bay. Includes construction, tiling, piping, lighting, paint, and repair controls."
	circuit = null
	console_upgrades = SHIP_CONSTRUCTION_ALL_UPGRADES
	var/datum/outpost_berth/ship_bay/berth

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/Initialize(mapload)
	. = ..()
	internal_rcd.construction_upgrades = RCD_ALL_UPGRADES
	internal_rcd.silo_link = TRUE
	internal_rtd = new(src)
	internal_rtd.ship_console = src
	internal_rtd.silo_mats = internal_rtd.AddComponent(/datum/component/remote_materials, FALSE, FALSE)
	internal_rtd.silo_link = TRUE
	internal_rtd.matter = 0
	internal_rpd = new(src)
	internal_rpd.ship_console = src
	internal_rpd.upgrade_flags |= RPD_UPGRADE_UNWRENCH
	internal_rpd.silo_mats = internal_rpd.AddComponent(/datum/component/remote_materials, FALSE, FALSE)
	internal_rpd.silo_link = TRUE
	internal_rld = new(src)
	internal_rld.ship_console = src
	internal_rld.construction_upgrades |= RCD_UPGRADE_SILO_LINK
	internal_rld.silo_mats = internal_rld.AddComponent(/datum/component/remote_materials, FALSE, FALSE)
	internal_rld.silo_link = TRUE
	internal_rld.matter = 0
	internal_painter = new(src)
	internal_painter.ship_console = src

/// A fresh reservation must not mint RCD charge on each docking visit.
/obj/machinery/computer/camera_advanced/base_construction/ship/bay/restock_materials()
	return

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/Destroy()
	var/list/closing_registry_panels = registry_panels
	registry_panels = list()
	QDEL_LIST(closing_registry_panels)
	disconnect_materials()
	if(berth?.console == src)
		berth.console = null
	berth = null
	current_ship = null
	return ..()

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/attempt_ship_connection()
	current_ship = berth?.ship
	return !QDELETED(current_ship)

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/connect_to_shuttle(mapload, obj/docking_port/mobile/voidcrew/port, obj/docking_port/stationary/dock)
	return FALSE

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/is_crew_member(mob/user)
	return current_ship?.ship_team && ..()

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/can_operate()
	return !QDELETED(berth) && berth.ship == current_ship && berth.contains_service_turf(get_turf(src)) && berth.is_ship_present() && ..()

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/can_link_silo(obj/machinery/ore_silo/silo)
	if(QDELETED(silo) || !can_operate())
		return FALSE
	if(get_ship_from_atom(silo) == current_ship)
		return TRUE
	var/obj/structure/overmap/dynamic/player_outpost/home = berth.outpost
	if(!home.founder_ckey || home.ship_bay_silo() != silo || get_outpost_from_atom(silo) != home)
		return FALSE
	return home.is_owner_crew_ship(current_ship) || (home.founder_ckey == berth.silo_owner_ckey && berth.approved_silo?.resolve() == silo)

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(!can_operate() || !is_crew_member(user))
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/proc/disconnect_materials()
	internal_rcd?.silo_mats?.disconnect()
	internal_rtd?.silo_mats?.disconnect()
	internal_rpd?.silo_mats?.disconnect()
	internal_rld?.silo_mats?.disconnect()

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/proc/link_materials(obj/machinery/ore_silo/silo)
	if(!can_link_silo(silo))
		return FALSE
	link_internal_device(internal_rcd, internal_rcd.silo_mats, silo)
	link_internal_device(internal_rtd, internal_rtd.silo_mats, silo)
	link_internal_device(internal_rpd, internal_rpd.silo_mats, silo)
	link_internal_device(internal_rld, internal_rld.silo_mats, silo)
	return TRUE

/// Owners use their selected outpost storage directly; visitors need a current grant.
/obj/machinery/computer/camera_advanced/base_construction/ship/bay/proc/use_outpost_silo()
	var/obj/structure/overmap/dynamic/player_outpost/home = berth?.outpost
	return link_materials(home?.ship_bay_silo())

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/proc/use_ship_silo()
	if(!can_operate())
		return FALSE
	disconnect_materials()
	for(var/obj/machinery/ore_silo/silo as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/ore_silo))
		if(get_ship_from_atom(silo) == current_ship)
			return link_materials(silo)
	return FALSE

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/ui_data(mob/user)
	berth?.reconcile_silo()
	. = ..()
	var/obj/machinery/ore_silo/silo = get_linked_silo()
	var/obj/structure/overmap/dynamic/player_outpost/home = berth?.outpost
	.["bay"] = list(
		"silo" = silo && can_link_silo(silo) ? silo.name : null,
		"outpost_materials" = !!silo && get_outpost_from_atom(silo) == home,
		"requested" = !!berth?.silo_requested_at,
		"available" = can_link_silo(home?.ship_bay_silo()),
	)

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(action == "hull_registry")
		if(ui.user == usr && ui.src_object == src && ui_status(usr, state) == UI_INTERACTIVE)
			open_hull_registry(usr)
		return TRUE
	if(action in list("bay_request_silo", "bay_ship_silo", "bay_outpost_silo"))
		if(ui.user != usr || ui.src_object != src || !is_crew_member(usr) || !can_operate() || ui_status(usr, state) != UI_INTERACTIVE)
			return TRUE
		switch(action)
			if("bay_request_silo")
				last_operation_success = berth.request_silo(usr)
				last_operation_message = last_operation_success ? (berth.silo_requested_at ? "Outpost materials requested." : "Using outpost materials.") : "No outpost silo is available."
			if("bay_ship_silo")
				last_operation_success = use_ship_silo()
				last_operation_message = last_operation_success ? "Using ship materials." : "No silo found aboard this ship."
			if("bay_outpost_silo")
				last_operation_success = use_outpost_silo()
				last_operation_message = last_operation_success ? "Using outpost materials." : "Outpost access unavailable."
		return TRUE
	return ..()
