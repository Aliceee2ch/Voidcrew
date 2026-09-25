/**
 * # Prison life: friends, rivals and farewells
 *
 * Owner: XD (extras-plan.md 4.4, and the scene gate of 4.9). Pairs of prisoners grow friendly or
 * hostile through chats, shared meals, games, spats and fights. Friends seek each other out, break
 * up each other's arguments and say goodbye at release; rivals argue over grudges. Numbers in
 * voidcrew/_DEFINES/outpost_prison_life.dm.
 *
 * X0 stubs: every proc below keeps the prison as it was until XD fills it in.
 */

/// How two prisoners get on, -100 (rivals) to 100 (friends)
/datum/outpost_prison/proc/affinity(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	return 0

/// Picks, removes from `options` and returns the prisoner `prisoner` goes to chat with
/datum/outpost_prison/proc/take_chat_partner(mob/living/basic/outpost_prisoner/prisoner, list/options)
	return pick_n_take(options)

/// A chat between two prisoners finished
/datum/outpost_prison/proc/note_chat(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	return

/// Prisoners who shared a meal and got its lift
/datum/outpost_prison/proc/note_shared_meal(list/diners)
	return

/datum/outpost_prison/proc/note_spat(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	return

/datum/outpost_prison/proc/note_fight(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	return

/// Multiplier on the chance these two start a fight
/datum/outpost_prison/proc/fight_chance_mult(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	return 1

/// A fight cause beyond food, ball and bed ("grudge"), or null
/datum/outpost_prison/proc/fight_cause_extra(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	return null

/// Which pair of `pairs` (each list(one, two)) has a spat
/datum/outpost_prison/proc/pick_spat_pair(list/pairs)
	return pick(pairs)

/// The two-person conversation `speaker` opens with `partner` ({"opener", "replies"}), or null for the usual pick
/datum/outpost_prison/proc/pick_conversation(mob/living/basic/outpost_prisoner/speaker, mob/living/basic/outpost_prisoner/partner)
	return null

/// "Seems to get on with Rosa." for examine, or null
/datum/outpost_prison/proc/relationship_examine(mob/living/basic/outpost_prisoner/prisoner)
	return null

/// The first name of `prisoner`'s worst rival in the wing, or null
/datum/outpost_prison/proc/worst_rival_name(mob/living/basic/outpost_prisoner/prisoner)
	return null

/// A prisoner was booked in: crew friends and rivals, birthdays
/datum/outpost_prison/proc/on_prisoner_admitted(mob/living/basic/outpost_prisoner/prisoner)
	return

/// A prisoner is leaving the roster: their pairs go
/datum/outpost_prison/proc/on_prisoner_leaving(mob/living/basic/outpost_prisoner/prisoner)
	return

/// A prisoner is being released with this stay `average`; TRUE if a farewell was said instead of the release line
/datum/outpost_prison/proc/on_prisoner_releasing(mob/living/basic/outpost_prisoner/prisoner, average)
	return FALSE

/// Whether a set piece (a birthday party) has the floor, so idle chatter waits
/datum/outpost_prison/proc/scene_active()
	return FALSE

/datum/outpost_prison/proc/life_tick(seconds)
	return

/datum/outpost_prison/proc/life_destroy()
	return

/// The admin panel's life block: {pairs, birthdays, scene}
/datum/outpost_prison/proc/life_admin_payload()
	return list()

/// prison_affinity, prison_birthday, prison_party, prison_cards: a log line, list("error" = text), or null
/datum/outpost_prison/proc/life_admin_act(action, list/params, mob/user)
	return null
