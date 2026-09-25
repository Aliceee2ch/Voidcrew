/**
 * # Warden's console
 *
 * The prison wing's roster, money and switches (OutpostPrison.tsx). Anyone may look. The outpost's
 * managers open and close intake and let visitors through the staff doors; managers and treasurers
 * pay the treasury's debt. It has no circuit board, so it only exists where a prison wing was
 * placed. What it shows comes from the prison's ui_payload(), below.
 */
/obj/machinery/computer/outpost_prison_warden
	name = "warden's console"
	desc = "Keeps the prison wing's roster: who is in which cell, for what, and for how long."
	icon_screen = "security"
	icon_keyboard = "security_key"
	circuit = null
	light_color = LIGHT_COLOR_ORANGE

/obj/machinery/computer/outpost_prison_warden/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/machinery/computer/outpost_prison_warden/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "OutpostPrison", name)
		ui.open()

/obj/machinery/computer/outpost_prison_warden/ui_data(mob/user)
	var/datum/outpost_prison/prison = get_outpost_prison(src)
	if(prison)
		return prison.ui_payload(user)
	return list(
		"linked" = FALSE,
		"powered" = FALSE,
		"intake_open" = FALSE,
		"intake_state" = "closed",
		"intake_note" = null,
		"next_arrival" = null,
		"capacity" = 0,
		"pay_rate" = 0,
		"pay_percent" = 0,
		"paid_total" = 0,
		"money" = list("paid" = 0, "spent" = 0, "fined" = 0, "net" = 0),
		"debt" = 0,
		"visitors_allowed" = FALSE,
		"can_manage" = FALSE,
		"can_pay_debt" = FALSE,
		"conditions" = list("clean" = 0, "lit" = 0, "powered" = 0, "score" = 0, "mess_spots" = 0, "dark_cells" = list(), "battery" = null),
		"hatch" = list("meals" = 0, "clean_suits" = 0, "dirty_suits" = 0, "capacity" = 0, "lasts_minutes" = null),
		"trouble" = list("stage" = PRISON_STAGE_CALM, "tension" = 0, "subdued_left" = null, "riot_imminent" = FALSE, "breakout_in" = null, "loose" = list()),
		"prisoners" = list(),
		"log" = list(),
		"alarm" = null,
		"alarm_text" = null,
		"extras" = null,
	)

/obj/machinery/computer/outpost_prison_warden/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/living/user = ui.user
	var/datum/outpost_prison/prison = get_outpost_prison(src)
	if(!prison || !istype(user))
		return
	switch(action)
		if("toggle_intake")
			if(!prison.outpost?.can_manage(user))
				balloon_alert(user, "managers only")
				return TRUE
			if(!prison.set_intake(!prison.intake_open, user))
				balloon_alert(user, "treasury owes [prison.treasury_debt()] cr")
				playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 30, TRUE)
			return TRUE
		if("pay_debt")
			if(!prison.may_pay_debt(user))
				balloon_alert(user, "managers and treasurers only")
				return TRUE
			if(prison.treasury_debt() <= 0)
				balloon_alert(user, "no debt")
				return TRUE
			var/paid = prison.pay_treasury_debt(user)
			if(paid)
				balloon_alert(user, "paid [paid] cr")
			else
				balloon_alert(user, "treasury is empty")
			return TRUE
		if("toggle_visitors")
			if(!prison.outpost?.can_manage(user))
				balloon_alert(user, "managers only")
				return TRUE
			prison.set_visitors_allowed(!prison.visitors_allowed, user)
			return TRUE
	// Guards (outpost_prison_extras.dm)
	if(prison.extras_act(action, params, user))
		return TRUE

// ===== THE PRISON'S SIDE =====

/// Whether `user` may pay the treasury's debt from the warden's console: managers and treasurers
/datum/outpost_prison/proc/may_pay_debt(mob/user)
	return !!(outpost?.can_manage(user) || outpost?.can_spend(user))

/// Prisoners in cell order, then any without a cell
/datum/outpost_prison/proc/roster_order()
	var/list/ordered = list()
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(cell.occupant && (cell.occupant in prisoners))
			ordered += cell.occupant
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		ordered |= prisoner
	return ordered

/**
 * What the roster calls a prisoner: dead, arriving or beaming out first, then loose, rioting, an
 * experiment's subject or confined to their cell without pay, and otherwise present or leaving.
 */
/datum/outpost_prison/proc/roster_status(mob/living/basic/outpost_prisoner/prisoner)
	var/status = prisoner.console_status()
	if(status == "dead" || status == "arriving" || prisoner.phase == PRISONER_LEAVING)
		return status
	if(prisoner.trouble == PRISONER_TROUBLE_LOOSE)
		return "loose"
	if(prisoner.is_rioting())
		return "rioting"
	if(prisoner.experiment_subject)
		return "subject"
	if(confined_unpaid(prisoner))
		return "confined"
	return status

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
			"status" = roster_status(prisoner),
		))
	var/list/alarm = alarm_state()
	var/list/conditions = conditions_payload()
	// Every key the console reads, whether or not the conditions block sends it yet.
	if(!("mess_spots" in conditions))
		conditions["mess_spots"] = 0
	if(!("dark_cells" in conditions))
		conditions["dark_cells"] = list()
	if(!("battery" in conditions))
		conditions["battery"] = null
	var/next_arrival = next_arrival_in()
	return list(
		"linked" = TRUE,
		"powered" = is_powered(),
		"intake_open" = intake_open,
		"intake_state" = intake_state(),
		"intake_note" = intake_note(),
		"next_arrival" = isnull(next_arrival) ? null : round(next_arrival),
		"capacity" = capacity,
		"pay_rate" = round(pay_rate(), 0.1),
		"pay_percent" = pay_percent(),
		"paid_total" = paid_total,
		"money" = list("paid" = paid_total, "spent" = spent_total, "fined" = fined_total, "net" = paid_total - spent_total - fined_total),
		"debt" = treasury_debt(),
		"visitors_allowed" = !!visitors_allowed,
		"can_manage" = !!outpost?.can_manage(user),
		"can_pay_debt" = treasury_debt() > 0 && may_pay_debt(user),
		"conditions" = conditions,
		"hatch" = hatch_stock(),
		"trouble" = trouble_payload(),
		"prisoners" = roster,
		"log" = entries.Copy(),
		"alarm" = alarm[1],
		"alarm_text" = alarm[2],
		"extras" = extras_payload(user),
		"experiment" = experiment_block(),
	)
