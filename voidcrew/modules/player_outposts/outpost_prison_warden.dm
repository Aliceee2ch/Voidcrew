/**
 * # Warden's console
 *
 * The prison wing's roster and intake switch (OutpostPrison.tsx). Anyone may look; only the
 * outpost's managers may open or close intake. It has no circuit board, so it only exists where a
 * prison wing was placed. What it shows comes from the prison's ui_payload(), below.
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
		"next_arrival" = null,
		"capacity" = 0,
		"pay_rate" = 0,
		"paid_total" = 0,
		"can_manage" = FALSE,
		"conditions" = list("clean" = 0, "lit" = 0, "powered" = 0, "score" = 0),
		"prisoners" = list(),
		"log" = list(),
		"alarm" = null,
		"alarm_text" = null,
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
			prison.set_intake(!prison.intake_open, user)
			return TRUE

// ===== THE PRISON'S SIDE =====

/// Prisoners in cell order, then any without a cell
/datum/outpost_prison/proc/roster_order()
	var/list/ordered = list()
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(cell.occupant && (cell.occupant in prisoners))
			ordered += cell.occupant
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		ordered |= prisoner
	return ordered

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
