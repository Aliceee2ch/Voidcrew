/**
 * # Prison mail call
 *
 * Owner: XF (extras-plan.md 4.15). While the crew is home, letters for the prisoners turn up in
 * the office mailbag. A member carries each one to its prisoner, by hand or on a serving hatch,
 * and the prisoner reads it on the spot: good news, bad news, a drawing from a kid. Opening a
 * letter first shows what it says and anything packed in it, at the cost of that prisoner's
 * trust. Letters never lie. Numbers in voidcrew/_DEFINES/outpost_prison_contraband.dm.
 *
 * X0 declares the mailbag (the map places it) and stubs every proc below, keeping the prison as it
 * was until XF fills it in.
 */

/// Where the wing's letters turn up. The prison map puts one on the office table by the first serving hatch.
/obj/structure/outpost_prison_mailbag
	name = "mailbag"
	desc = "A canvas sack by the warden's desk. The prison wing's post turns up in it."
	icon = 'icons/obj/service/bureaucracy.dmi'
	icon_state = "mailbag"
	anchored = TRUE
	density = FALSE

/obj/structure/outpost_prison_mailbag/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

/// Arrivals, expiry, letters carried off the level and prisoners fetching mail from the hatches
/datum/outpost_prison/proc/mail_tick(seconds)
	return

/datum/outpost_prison/proc/mail_destroy()
	return

/// A prisoner is leaving: their undelivered letters go
/datum/outpost_prison/proc/mail_prisoner_leaving(mob/living/basic/outpost_prisoner/prisoner)
	return

/// Something went on a serving hatch; TRUE if it was only mail and the usual call-out should not follow
/datum/outpost_prison/proc/mail_hatch_stocked(obj/structure/table/reinforced/prison_hatch/hatch, list/stocked, mob/user)
	return FALSE

/// "Any mail for me?" and the like, as list(context, other, values), or null
/datum/outpost_prison/proc/mail_extra_speech(mob/living/basic/outpost_prisoner/prisoner)
	return null

/// The warden console's "mail" block: {waiting}
/datum/outpost_prison/proc/mail_payload(mob/user)
	return list("waiting" = 0)

/// The admin panel's mail block: {letters: [{ref, to_ref, to_name, kind, opened, contraband, age}]}
/datum/outpost_prison/proc/mail_admin_payload()
	return list()

/// prison_mail {ref, kind}: a log line, list("error" = text), or null
/datum/outpost_prison/proc/mail_admin_act(action, list/params, mob/user)
	return null
