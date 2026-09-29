/**
 * # World population: customers and drinkers at the trader outposts (owner items 2 and 3)
 *
 * Owner: PA (trader outpost life). P0 made this file as a stub; only PA edits it.
 *
 * PA builds here (spec 3.1, 3.2): the customers who visit every trader counter and the drinkers at
 * the Dregs, the Chowder Pot and Quartermain's crew room, as /mob/living/basic/ambient_npc
 * subtypes; the /datum/ambient_outpost_role subtypes that bring them to each outpost and set how
 * many and how often (the outpost population rules); their activities (a stall visit with a line
 * and a trader reply, the bar with drunk stages); their lines in strings/outpost_patrons.json
 * (AMBIENT_STRINGS_PATRONS).
 *
 * Seams (P0, frozen): /mob/living/basic/ambient_npc (speak_context(), reply_to(), talked_to(),
 * react_violence(), react_shootout(), react_convoy(), pick_activity(), `routine`), the activities
 * in ambient_activity.dm (idle, wander, sit, drink, chat, work, leave), /datum/ambient_outpost_role
 * (npc_type, outpost_types, max_count, weight, gap_low/gap_high, wanted(), arrive()),
 * SSambient_npcs.outpost_players(), SSambient_npcs.lift_arrival_turf(),
 * /datum/ambient_place/outpost (get_public_floor(), shootout_refuge), COMSIG_TRADER_OUTPOST_VIOLENCE
 * and COMSIG_TRADER_OUTPOST_CONVOY. Traders answer through their own say(); no shop file is edited.
 */
