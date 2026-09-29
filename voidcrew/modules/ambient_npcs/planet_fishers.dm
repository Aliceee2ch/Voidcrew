/**
 * # World population: fishers (owner items 9 and 10)
 *
 * Owner: PB (planet and field NPCs). P0 made this file as a stub; only PB edits it.
 *
 * PB builds here (spec 4.5, 4.6, 3.3): /datum/ambient_activity/fish, shared with PA's angler (the
 * water turf is its anchor: new /datum/ambient_activity/fish(npc, water_turf)), the lava fisher and
 * the boat fisher with their site kinds, and the boat prop. Catches are pictures, never items: the
 * lava fish table holds jackpots.
 */

/// Fishing into the water turf it is anchored to. PB fills it in; the stub never starts.
/datum/ambient_activity/fish
	name = "fishing"

/datum/ambient_activity/fish/setup()
	return FALSE
