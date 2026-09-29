/**
 * # World population: the miner (owner item 1)
 *
 * Owner: PB (planet and field NPCs). P0 made this file as a stub; only PB edits it.
 *
 * PB builds here (spec 4.2): the miner NPC and its site kind (rocky planets, asteroid fields), the
 * camp, the ore barter, and /datum/ambient_activity/mine: dig one ore-bearing rock face for real
 * (gets_drilled(), the zone ore scaling applies) and scoop the ore into the satchel. The lava fisher
 * (planet_fishers.dm) digs with it too.
 */

/// Digs one ore wall for real. PB fills it in; the stub never starts.
/datum/ambient_activity/mine
	name = "mining"

/datum/ambient_activity/mine/setup()
	return FALSE
