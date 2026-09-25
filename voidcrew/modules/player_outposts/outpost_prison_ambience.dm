/**
 * # Prison ambience: the yard notices you, readable moods, a riot you hear coming
 *
 * Owner: XB (extras-plan.md 4.5 and 4.7). Heads turn when a member walks into the cell block;
 * examining a prisoner describes their mood in words (with every package's extra lines from
 * examine_extra_lines()); sour prisoners sulk and content ones hum; a restless yard hushes, a
 * brewing riot slams the tables and chants, and the riot starts with a roar.
 *
 * X0 stubs: every proc below keeps the prison as it was until XB fills it in.
 */

/// Hooks up the prisoner's side of the ambience; called from setup_extras()
/mob/living/basic/outpost_prisoner/proc/setup_ambience()
	return

/// Notices, hums and the brewing riot's chant, once a second
/datum/outpost_prison/proc/ambience_tick(seconds)
	return

/datum/outpost_prison/proc/ambience_destroy()
	return

/// Whether `speaker`'s line for `context` is dropped because the yard has gone quiet (a restless wing); TRUE drops it
/datum/outpost_prison/proc/speech_hushed(mob/living/basic/outpost_prisoner/speaker, context)
	return FALSE
