/**
 * # World population: taking a stray aboard (spec 5.1)
 *
 * Owner: PC (strays). P0 made this file as a stub; only PC edits it.
 *
 * Owner decision D1: recruits are AI deckhands only. No ghost poll, no ghost role, no body swap.
 * PC builds here: the "Come with us" choice for a member of a ship crew (talked_to() on the stray),
 * following them aboard, and life aboard as a deckhand (chairs, the sink, a bunk, chatting with the
 * crew) under its own /datum/ambient_place subtype for the ship, within
 * AMBIENT_RECRUITS_PENDING_PER_SHIP and AMBIENT_RECRUITS_PER_SHIP_ROUND.
 */

/**
 * Lets a crew member ask `stray` to come with them, and runs the rest of the flow. PC fills it in;
 * until then it does nothing.
 */
/proc/ambient_offer_recruit(mob/living/basic/ambient_npc/stray)
	return
