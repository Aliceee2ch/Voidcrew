/**
 * # Prison interrogation: leads
 *
 * Owner: XG (extras-plan.md 4.16). Some prisoners know where an uncharted wreck sits. A member can
 * ask from the talk menu; the answer lands on the asker's ship helm as a Rumors waypoint. A content
 * prisoner tells the truth. An unhappy one may lie, and a lie can be caught: a tell when they
 * answer, the yard's gossip, another prisoner vouching or not, a star chart or survey of the spot,
 * and the ship's own sensors when it gets there. At most one lead per wing per
 * OUTPOST_PRISON_LEAD_GAP. Numbers in voidcrew/_DEFINES/outpost_prison_leads.dm.
 *
 * X0 stubs: every proc below keeps the prison as it was until XG fills it in.
 */

/// Checks open lies against the asking ships' positions
/datum/outpost_prison/proc/leads_tick(seconds)
	return

/datum/outpost_prison/proc/leads_destroy()
	return

/// A prisoner was booked in: some carry a lead
/datum/outpost_prison/proc/leads_prisoner_admitted(mob/living/basic/outpost_prisoner/prisoner)
	return

/datum/outpost_prison/proc/leads_prisoner_leaving(mob/living/basic/outpost_prisoner/prisoner)
	return

/// A hint that `prisoner` knows something, or a caught liar's line, as list(context, other, values), or null
/datum/outpost_prison/proc/leads_extra_speech(mob/living/basic/outpost_prisoner/prisoner)
	return null

/// An examine sentence, or null
/datum/outpost_prison/proc/leads_examine(mob/living/basic/outpost_prisoner/prisoner, mob/user)
	return null

/// The talk menu's questions: name -> image
/datum/outpost_prison/proc/leads_talk_choices(mob/living/basic/outpost_prisoner/prisoner, mob/living/user)
	return list()

/// Runs a talk menu choice of this package; TRUE if it was one. May sleep.
/datum/outpost_prison/proc/leads_talk_act(mob/living/basic/outpost_prisoner/prisoner, mob/living/user, choice)
	return FALSE

/// The admin panel's leads block: {ready_in, carriers: [ref], open: [{teller, ship, name, lie, exposed}]}
/datum/outpost_prison/proc/leads_admin_payload()
	return list()

/// prison_lead {ref}: a log line, list("error" = text), or null
/datum/outpost_prison/proc/leads_admin_act(action, list/params, mob/user)
	return null
