/**
 * # World population: people who work at the trader outposts (owner item 4)
 *
 * Owner: PA (trader outpost life). P0 made this file as a stub; only PA edits it.
 *
 * PA builds here (spec 3.4): the janitor, gardener, barback and dock worker, as
 * /mob/living/basic/ambient_npc subtypes with /datum/ambient_outpost_role subtypes, and their
 * activities (mopping real mess with a wet floor sign, watering the outpost's own trays, collecting
 * empty glasses, carrying prop crates on the convoy). Their lines go in strings/outpost_workers.json
 * (AMBIENT_STRINGS_WORKERS).
 *
 * The trader outposts' mechanics (/mob/living/basic/outpost_loiterer/mechanic,
 * voidcrew/modules/trade/outpost_amenities.dm) are the engineers already and stay as they are.
 * /datum/ambient_activity/work runs the same work loop (outpost_ambient_work.dm) for any ambient NPC
 * with `work_weights`: a worker subtype sets those and gets welding, wrenches, panels, pipes,
 * hauling, wiping, pouring and mopping with their looks and sounds for free.
 *
 * Seams (P0, frozen): see outpost_patrons.dm, plus react_convoy() for the dock workers.
 */
