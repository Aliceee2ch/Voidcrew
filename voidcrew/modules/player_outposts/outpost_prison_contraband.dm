/**
 * # Prison contraband: stashes and shakedowns
 *
 * Owner: XF (extras-plan.md 4.14). Sour prisoners sharpen a shiv and hide it under their
 * mattress, or brew pruno in their toilet's cistern, out of sight of staff. A stash stays with the
 * cell. A shiv stash makes the yard tenser and its owner quicker to riot, and is the shiv they
 * draw when they do (decision 8 unchanged: every rioter still has a shiv, and shivs only come out
 * in riots). Pruno cheers the drinker and makes them quarrelsome for a while. Members search a
 * cell's mattress by hand, lift the cistern lid with a crowbar, or pat a prisoner down from the
 * talk menu; searching costs the yard's goodwill either way. Numbers in
 * voidcrew/_DEFINES/outpost_prison_contraband.dm.
 *
 * X0 stubs: every proc below keeps the prison as it was until XF fills it in.
 */

/// Hooks up the prisoner's side of contraband and mail (the letter hand-over); called from setup_extras()
/mob/living/basic/outpost_prisoner/proc/setup_contraband()
	return

/// Sour clocks, shiv making, brewing and drinking, and the cells' beds and toilets
/datum/outpost_prison/proc/contraband_tick(seconds)
	return

/datum/outpost_prison/proc/contraband_destroy()
	return

/datum/outpost_prison/proc/contraband_prisoner_admitted(mob/living/basic/outpost_prisoner/prisoner)
	return

/datum/outpost_prison/proc/contraband_prisoner_leaving(mob/living/basic/outpost_prisoner/prisoner)
	return

/// Tension the wing's hidden shivs add, from 0 up
/datum/outpost_prison/proc/contraband_tension()
	return 0

/// A few words for the restless announcement when shivs are hidden in the wing, or null
/datum/outpost_prison/proc/contraband_cause()
	return null

/// How much higher `prisoner`'s riot line is (a shiv under their mattress)
/datum/outpost_prison/proc/riot_join_bonus(mob/living/basic/outpost_prisoner/prisoner)
	return 0

/// A rioter draws the shiv from their cell's stash instead of a new one; TRUE if they did
/datum/outpost_prison/proc/draw_stashed_shiv(mob/living/basic/outpost_prisoner/prisoner)
	return FALSE

/// Multiplier on the chance these two start a fight (pruno)
/datum/outpost_prison/proc/contraband_fight_mult(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	return 1

/// Multiplier on the wing's chance of a spat (pruno)
/datum/outpost_prison/proc/contraband_spat_mult()
	return 1

/// A drunk or caught-out line `prisoner` wants to say now, as list(context, other, values), or null
/datum/outpost_prison/proc/contraband_extra_speech(mob/living/basic/outpost_prisoner/prisoner)
	return null

/// A tell for examine ("Keeps a hand in his pocket."), or null
/datum/outpost_prison/proc/contraband_examine(mob/living/basic/outpost_prisoner/prisoner, mob/user)
	return null

/// The pat-down choice for the talk menu: name -> image
/datum/outpost_prison/proc/contraband_talk_choices(mob/living/basic/outpost_prisoner/prisoner, mob/living/user)
	return list()

/// Runs a talk menu choice of this package; TRUE if it was one. May sleep.
/datum/outpost_prison/proc/contraband_talk_act(mob/living/basic/outpost_prisoner/prisoner, mob/living/user, choice)
	return FALSE

/// The admin panel's contraband block: {cells: [{number, shiv, pruno}], drunk: [ref]}
/datum/outpost_prison/proc/contraband_admin_payload()
	return list()

/// prison_stash {cell, kind}: a log line, list("error" = text), or null
/datum/outpost_prison/proc/contraband_admin_act(action, list/params, mob/user)
	return null
