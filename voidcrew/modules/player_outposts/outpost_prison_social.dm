/**
 * # Prison social memory: the yard remembers staff
 *
 * Owner: XC (extras-plan.md 4.3). The wing keeps a hidden score for each member who deals with
 * it, moved by care, talk, games and kindness up, and by unprovoked blows down. It shows only in
 * how prisoners greet, threaten, listen to and riot against that person. Numbers in
 * voidcrew/_DEFINES/outpost_prison_social.dm.
 *
 * X0 stubs: every proc below keeps the prison as it was until XC fills it in.
 */

/// "stranger", "regular", "fair", "hard" or "brute": how the yard sees `person`
/datum/outpost_prison/proc/staff_label(mob/person)
	return "stranger"

/// The name prisoners call `person` by: the first name of their visible name, or null when masked
/datum/outpost_prison/proc/staff_greeting_name(mob/person)
	if(!ismob(person))
		return null
	var/visible = person.get_visible_name()
	if(!istext(visible) || !length(visible) || visible == "Unknown")
		return null
	return first_name(visible)

/// `person` fed, clothed or treated `prisoner` by hand
/datum/outpost_prison/proc/note_staff_care(mob/person, mob/living/basic/outpost_prisoner/prisoner)
	return

/// `person` stocked a serving hatch with food or clean uniforms
/datum/outpost_prison/proc/note_staff_stock(mob/person)
	return

/// `person` talked `prisoner` down
/datum/outpost_prison/proc/note_staff_talk(mob/person, mob/living/basic/outpost_prisoner/prisoner)
	return

/// `person` sank a shot while prisoners played
/datum/outpost_prison/proc/note_staff_basket(mob/person)
	return

/// A kindness another package noticed (a card game, a birthday cake): `amount` of score
/datum/outpost_prison/proc/note_staff_kindness(mob/person, amount)
	return

/// An unprovoked hit on `prisoner` that cost them mood
/datum/outpost_prison/proc/note_staff_hit(atom/attacker, mob/living/basic/outpost_prisoner/prisoner)
	return

/// Staff got the blame for `prisoner`: `event` is "beaten" or "killed"
/datum/outpost_prison/proc/note_staff_blamed(mob/living/basic/outpost_prisoner/prisoner, event)
	return

/**
 * Something else `person` did that the yard remembers, from XF and XG: "mail_delivered",
 * "mail_opened", "search_found", "search_empty", "patdown_found", "patdown_empty". XC sets the
 * amounts (4.3) and ignores events it does not know.
 */
/datum/outpost_prison/proc/note_staff_event(mob/person, mob/living/basic/outpost_prisoner/prisoner, event)
	return

/// Below this mood `prisoner` squares up to `person`
/datum/outpost_prison/proc/threat_mood_for(mob/living/basic/outpost_prisoner/prisoner, mob/person)
	return PRISONER_THREAT_MOOD

/// The highest line threat_mood_for() can return, so a prisoner above it looks for nobody
/datum/outpost_prison/proc/threat_mood_ceiling()
	return PRISONER_THREAT_MOOD

/// The mood a talk-down from `person` gives `prisoner`
/datum/outpost_prison/proc/talk_mood_for(mob/living/basic/outpost_prisoner/prisoner, mob/person)
	return PRISONER_MOOD_TALK

/// Whether `prisoner` refuses to be talked down by `person`; if so it says so itself (async)
/datum/outpost_prison/proc/refuses_talk_from(mob/living/basic/outpost_prisoner/prisoner, mob/person)
	return FALSE

/// How far `person` seems to a rioter picking whom to go for: `distance`, adjusted by reputation
/datum/outpost_prison/proc/riot_victim_distance(mob/living/basic/outpost_prisoner/prisoner, mob/person, distance)
	return distance

/// A greeting or other reputation line `prisoner` wants to say now, as list(context, other, values), or null
/datum/outpost_prison/proc/social_extra_speech(mob/living/basic/outpost_prisoner/prisoner)
	return null

/// Decay and the word new arrivals hear about staff
/datum/outpost_prison/proc/social_tick(seconds)
	return

/datum/outpost_prison/proc/social_destroy()
	return

/// The admin panel's records: list of {key, name, score, label}
/datum/outpost_prison/proc/social_admin_payload()
	return list()

/// prison_rep {key, score}: a log line, list("error" = text), or null
/datum/outpost_prison/proc/social_admin_act(action, list/params, mob/user)
	return null
