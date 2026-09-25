/**
 * # Prison wing experiments
 *
 * The researcher who visits the wing with serums and specimens, and what comes of them. Numbers
 * are in voidcrew/_DEFINES/outpost_prison_experiments.dm.
 */

/mob/living/basic/outpost_prisoner
	/// Dosed or carrying a specimen: their death is the experiment's, not staff's
	var/experiment_subject = FALSE

/// Advances the researcher's visits and any live experiment by `seconds`
/datum/outpost_prison/proc/experiments_tick(seconds)
	return

/// Whether an experiment is under way in the wing
/datum/outpost_prison/proc/experiment_active()
	return FALSE
