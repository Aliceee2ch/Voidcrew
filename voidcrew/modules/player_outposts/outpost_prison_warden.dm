/**
 * # Warden's console
 *
 * The prison wing's roster and intake switch (OutpostPrison.tsx). Anyone may look; only the
 * outpost's managers may open or close intake. It has no circuit board, so it only exists where a
 * prison wing was placed.
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
