/obj/structure/overmap/dynamic/player_outpost
	var/list/datum/hull_blueprint/hull_registry = list()
	var/hull_registry_fee = OUTPOST_REGISTRY_DEFAULT_FEE
	var/hull_registry_price_revision = 0

/obj/structure/overmap/dynamic/player_outpost/proc/set_hull_registry_fee(mob/user, amount)
	if(!is_current_treasury_user(user) || !isnum(amount) || amount < 0 || amount > OUTPOST_REGISTRY_MAX_FEE || amount != round(amount))
		return FALSE
	if(hull_registry_fee != amount)
		hull_registry_fee = amount
		hull_registry_price_revision++
		log_game("[key_name(user)] set [name]'s hull registry fee to [amount] credits.")
	return TRUE

/obj/structure/overmap/ship
	var/datum/weakref/hull_registration
	/// Prevent claiming the old hull while its paid replacement is loading.
	var/registry_rebuilding = FALSE
	var/retired_by_registry = FALSE

/obj/machinery/computer/player_outpost_management
	var/list/datum/hull_registry_ui/registry_panels = list()

/obj/machinery/computer/camera_advanced/base_construction/ship/bay
	var/list/datum/hull_registry_ui/registry_panels = list()

/// Rebuilding remains accessible here when every ephemeral bay is empty.
/obj/machinery/computer/player_outpost_management/proc/open_hull_registry(mob/user)
	if(!outpost?.ship_bay_installed)
		return
	for(var/datum/hull_registry_ui/panel as anything in registry_panels)
		if(panel.user_ref.resolve() == user)
			panel.ui_interact(user)
			return
	var/datum/hull_registry_ui/panel = new(outpost, src, user)
	registry_panels += panel
	panel.ui_interact(user)

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/proc/open_hull_registry(mob/user)
	if(!can_operate() || !is_crew_member(user))
		return
	for(var/datum/hull_registry_ui/panel as anything in registry_panels)
		if(panel.user_ref.resolve() == user)
			panel.ui_interact(user)
			return
	var/datum/hull_registry_ui/panel = new(berth.outpost, src, user)
	registry_panels += panel
	panel.ui_interact(user)

/datum/hull_registry_ui
	var/obj/structure/overmap/dynamic/player_outpost/outpost
	var/datum/weakref/host_ref
	var/datum/weakref/user_ref
	var/turf/host_turf
	var/datum/hull_blueprint/quote
	var/datum/weakref/quoted_silo
	var/datum/weakref/quoted_bay
	var/datum/weakref/quoted_account
	var/datum/weakref/quoted_treasury
	var/datum/weakref/quoted_registration
	var/quoted_owner
	var/quoted_fee
	var/quoted_price_revision
	var/error
	var/notice
	var/working = FALSE

/datum/hull_registry_ui/New(obj/structure/overmap/dynamic/player_outpost/home, obj/machinery/computer/host, mob/user)
	outpost = home
	host_ref = WEAKREF(host)
	user_ref = WEAKREF(user)
	host_turf = get_turf(host)
	RegisterSignal(home, COMSIG_QDELETING, PROC_REF(on_outpost_deleted))

/datum/hull_registry_ui/Destroy()
	SStgui.close_uis(src)
	var/obj/machinery/computer/host = host_ref?.resolve()
	if(istype(host, /obj/machinery/computer/player_outpost_management))
		var/obj/machinery/computer/player_outpost_management/console = host
		console.registry_panels -= src
	else if(istype(host, /obj/machinery/computer/camera_advanced/base_construction/ship/bay))
		var/obj/machinery/computer/camera_advanced/base_construction/ship/bay/console = host
		console.registry_panels -= src
	if(outpost)
		UnregisterSignal(outpost, COMSIG_QDELETING)
	outpost = null
	QDEL_NULL(quote)
	return ..()

/datum/hull_registry_ui/proc/on_outpost_deleted()
	SIGNAL_HANDLER
	qdel(src)

/datum/hull_registry_ui/ui_host(mob/user)
	return host_ref?.resolve()

/datum/hull_registry_ui/ui_state(mob/user)
	return GLOB.always_state

/datum/hull_registry_ui/ui_status(mob/user, datum/ui_state/state)
	var/obj/machinery/computer/host = host_ref?.resolve()
	if(QDELETED(outpost) || !outpost.ship_bay_installed || QDELETED(host) || get_turf(host) != host_turf || user_ref.resolve() != user || !isliving(user) || !user.ckey)
		return UI_CLOSE
	if(istype(host, /obj/machinery/computer/camera_advanced/base_construction/ship/bay))
		var/obj/machinery/computer/camera_advanced/base_construction/ship/bay/console = host
		if(console.berth?.outpost != outpost || !console.can_operate() || !console.is_crew_member(user))
			return UI_CLOSE
	else if(get_outpost_from_atom(host) != outpost)
		return UI_CLOSE
	return host.ui_status(user, host.ui_state(user))

/datum/hull_registry_ui/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "HullRegistry", "[outpost.name] Hull Registry")
		ui.open()

/datum/hull_registry_ui/ui_close(mob/user)
	qdel(src)

/// Only a physically present, captain-owned bay can supply a snapshot or payment.
/datum/hull_registry_ui/proc/save_denial(mob/living/user, datum/outpost_berth/ship_bay/bay)
	if(QDELETED(src) || ui_status(user, GLOB.always_state) != UI_INTERACTIVE)
		return "Registry terminal unavailable."
	if(QDELETED(bay) || bay.outpost != outpost || !(bay in outpost.bay_berths) || !bay.is_ship_present())
		return "Dock your ship in a ship bay first."
	var/obj/structure/overmap/ship/ship = bay.ship
	if(!ship.is_ship_captain(user) || ship.abandoned || ship.retired_by_registry)
		return "Only the ship's current captain can save it."
	if(ship.registry_rebuilding)
		return "Recovery is already in progress."
	var/datum/hull_blueprint/previous = ship.hull_registration?.resolve()
	if(length(outpost.hull_registry) >= OUTPOST_MAX_BLUEPRINTS && previous?.outpost != outpost)
		return "This outpost's hull registry is full."
	var/obj/machinery/ore_silo/silo = bay.console?.get_linked_silo()
	if(!silo || !bay.console.can_link_silo(silo))
		return "Select ship materials or request outpost materials."
	if(bay.console.internal_rcd.silo_mats.on_hold())
		return "The selected silo has suspended bay material access."
	if(QDELETED(ship.ship_account) || QDELETED(outpost.treasury))
		return "The ship or outpost bank account is unavailable."
	return null

/datum/hull_registry_ui/proc/prepare_save(mob/living/user, datum/outpost_berth/ship_bay/bay)
	error = save_denial(user, bay)
	if(error || working)
		return FALSE
	working = TRUE
	notice = null
	QDEL_NULL(quote)
	var/datum/hull_blueprint/snapshot = new
	error = snapshot.capture(bay.ship, user)
	if(!error)
		error = save_denial(user, bay)
	if(error || QDELETED(src))
		qdel(snapshot)
		working = FALSE
		return FALSE
	quote = snapshot
	quoted_silo = WEAKREF(bay.console.get_linked_silo())
	quoted_bay = WEAKREF(bay)
	quoted_account = WEAKREF(bay.ship.ship_account)
	quoted_treasury = WEAKREF(outpost.treasury)
	quoted_registration = bay.ship.hull_registration
	quoted_owner = outpost.founder_ckey
	quoted_fee = outpost.hull_registry_fee
	quoted_price_revision = outpost.hull_registry_price_revision
	working = FALSE
	return TRUE

/// Shared by the invoice and transaction; rechecked after captain confirmation.
/datum/hull_registry_ui/proc/quote_denial(mob/living/user)
	if(QDELETED(quote))
		return "Prepare a quote first."
	var/datum/outpost_berth/ship_bay/bay = quoted_bay?.resolve()
	var/denial = save_denial(user, bay)
	if(denial)
		return denial
	var/obj/structure/overmap/ship/ship = quote.source_ship.resolve()
	var/obj/machinery/ore_silo/silo = quoted_silo?.resolve()
	if(bay.ship != ship || quote.captain_ckey != user.ckey || silo != bay.console.get_linked_silo() || !bay.console.can_link_silo(silo))
		return "The ship or material source changed. Prepare a new quote."
	if(quoted_owner != outpost.founder_ckey || quoted_price_revision != outpost.hull_registry_price_revision || quoted_fee != outpost.hull_registry_fee || quoted_account?.resolve() != ship.ship_account || quoted_treasury?.resolve() != outpost.treasury)
		return "The price or payment account changed. Prepare a new quote."
	if(quoted_registration != ship.hull_registration)
		return "The ship's registration changed. Prepare a new quote."
	if(!silo.materials?.has_materials(quote.material_cost))
		return "The selected silo has insufficient materials."
	if(!ship.ship_account.has_money(quoted_fee))
		return "The ship account has insufficient credits."
	return null

/datum/hull_registry_ui/proc/confirm_save(mob/user, prompt_text)
	return tgui_alert(user, prompt_text, "Save hull", list("Save", "Cancel")) == "Save"

/datum/hull_registry_ui/proc/save_quote(mob/living/user)
	if(working || !quote)
		return FALSE
	error = quote_denial(user)
	if(error)
		return FALSE
	var/datum/hull_blueprint/snapshot = quote
	working = TRUE
	var/list/prices = registry_material_data(snapshot.material_cost)
	var/list/price_text = list()
	for(var/list/material as anything in prices)
		price_text += "[material["sheets"]] [material["name"]] sheets"
	var/accepted = confirm_save(user, "Pay [quoted_fee] credits from the ship account to [outpost.name], plus [price_text.Join(", ")] from the selected silo? This saves [snapshot.ship_name]'s hull and replaces its previous registration. One prepaid rebuild; no helm, other machinery, supplies or fuel.")
	if(QDELETED(src))
		return FALSE
	working = FALSE
	if(!accepted || quote != snapshot || QDELETED(snapshot))
		return FALSE
	error = quote_denial(user)
	if(error)
		return FALSE
	var/obj/structure/overmap/ship/ship = snapshot.source_ship.resolve()
	var/obj/machinery/ore_silo/silo = quoted_silo?.resolve()
	var/datum/outpost_berth/ship_bay/bay = quoted_bay.resolve()
	// No yields between the final checks, payment and replacing the registration.
	if(quoted_fee && !ship.ship_account.adjust_money(-quoted_fee, "Hull registration at [outpost.name], approved by [user.ckey]"))
		error = "The ship account payment was declined."
		return FALSE
	silo.materials.use_materials(snapshot.material_cost)
	silo.silo_log(bay.console, "register", -1, snapshot.ship_name, snapshot.material_cost, ID_DATA(user))
	if(quoted_fee)
		outpost.treasury.adjust_money(quoted_fee, "Hull registration: [ship.name], approved by [user.ckey]")
	var/datum/hull_blueprint/previous = ship.hull_registration?.resolve()
	if(previous)
		qdel(previous)
	snapshot.outpost = outpost
	outpost.hull_registry += snapshot
	ship.hull_registration = WEAKREF(snapshot)
	quote = null
	notice = "[snapshot.ship_name] registered. One prepaid rebuild available."
	log_game("[key_name(user)] registered the hull of [ship.name] at [outpost.name] for [quoted_fee] credits and [json_encode(snapshot.material_cost)].")
	return TRUE

/proc/registry_material_data(list/cost, obj/machinery/ore_silo/silo)
	var/list/result = list()
	for(var/material_type in cost)
		var/datum/material/material = GET_MATERIAL_REF(material_type)
		result += list(list("name" = material.name, "sheets" = cost[material_type] / SHEET_MATERIAL_AMOUNT, "available" = (silo?.materials?.get_material_amount(material_type) || 0) / SHEET_MATERIAL_AMOUNT))
	return result

/datum/hull_registry_ui/ui_data(mob/user)
	var/list/bays = list()
	for(var/datum/outpost_berth/ship_bay/bay as anything in outpost.bay_berths)
		if(!bay?.ship?.is_ship_captain(user))
			continue
		bay.reconcile_silo()
		var/obj/machinery/ore_silo/silo = bay.console?.get_linked_silo()
		bays += list(list("ref" = REF(bay), "name" = bay.ship.name, "number" = bay.bay_number, "denial" = save_denial(user, bay), "silo" = silo && bay.console.can_link_silo(silo) ? silo.name : null, "outpost_materials" = !!silo && get_outpost_from_atom(silo) == outpost, "requested" = !!bay.silo_requested_at, "available" = bay.console?.can_link_silo(outpost.ship_bay_silo())))
	var/list/blueprints = list()
	for(var/datum/hull_blueprint/snapshot as anything in outpost.hull_registry)
		if(snapshot.captain_ckey != user.ckey)
			continue
		blueprints += list(list("ref" = REF(snapshot), "name" = snapshot.ship_name, "width" = snapshot.width, "height" = snapshot.height, "denial" = rebuild_denial(user, snapshot)))
	return list(
		"outpost" = outpost.name,
		"bays" = bays,
		"blueprints" = blueprints,
		"working" = working,
		"error" = error,
		"notice" = notice,
		"fee" = outpost.hull_registry_fee,
		"quote" = quote_data(user),
	)

/datum/hull_registry_ui/proc/quote_data(mob/user)
	if(!quote)
		return null
	var/obj/machinery/ore_silo/silo = quoted_silo?.resolve()
	var/datum/bank_account/account = quoted_account?.resolve()
	return list("name" = quote.ship_name, "cost" = registry_material_data(quote.material_cost, silo), "silo" = silo?.name, "outpost_materials" = !!silo && get_outpost_from_atom(silo) == outpost, "fee" = quoted_fee, "balance" = account?.account_balance || 0, "denial" = quote_denial(user), "replaces" = !!quoted_registration?.resolve())

/datum/hull_registry_ui/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/living/user = usr
	if(working || !istype(user) || ui.user != user || ui.src_object != src || ui_status(user, state) != UI_INTERACTIVE)
		return
	switch(action)
		if("ship_materials", "outpost_materials")
			var/datum/outpost_berth/ship_bay/bay = locate(params["ref"]) in outpost.bay_berths
			if(!bay?.is_ship_present() || !bay.ship.is_ship_captain(user))
				return FALSE
			bay.reconcile_silo()
			QDEL_NULL(quote)
			error = null
			notice = null
			if(action == "ship_materials")
				if(!bay.console.use_ship_silo())
					error = "No material silo found aboard this ship."
			else if(bay.console.use_outpost_silo())
				notice = "Using outpost materials."
			else if(bay.request_silo(user))
				// An owner with treasury access can approve their own request here.
				if(!bay.approve_silo(user))
					notice = "Outpost materials requested. Awaiting treasury approval."
			else
				error = "No outpost silo selected. Check Outpost Management > Docking."
		if("quote")
			var/datum/outpost_berth/ship_bay/bay = locate(params["ref"]) in outpost.bay_berths
			prepare_save(user, bay)
		if("save")
			save_quote(user)
		if("rebuild")
			var/datum/hull_blueprint/snapshot = locate(params["ref"]) in outpost.hull_registry
			rebuild(user, snapshot)
	return TRUE
