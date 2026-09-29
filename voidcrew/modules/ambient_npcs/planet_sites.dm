/**
 * # World population: planet and field sites (owner items 1, 7 to 11)
 *
 * Owner: PB (planet and field NPCs). P0 made this file as a stub; only PB edits it.
 *
 * PB builds here (spec 4.1): its /datum/ambient_site_kind subtypes (planet_types, bands, chance,
 * field_chance, min_npcs/max_npcs, npc_type) with the chance table per planet type (override
 * chance_on() for a table), and any spot finders the defaults do not cover (find_spot(),
 * find_field_spot(), spot_ok(): a river bank, open water, a cave mouth).
 *
 * Seams (P0, frozen): SSambient_npcs rolls a planet's sites at the first arrival
 * (roll_planet_sites(): at most AMBIENT_PLANET_SITES_MAX sites and AMBIENT_PLANET_NPCS_MAX NPCs),
 * brings out the missing NPCs of every site that is not spent on each visit (realize_planet(),
 * charged to the planet's fauna budget, a site whole or not at all) and runs an asteroid field's
 * one-time population (populate_field()). A kind's realize(site) spawns with site.spawn_npc() and
 * builds with site.add_prop() / site.get_prop(); on_npc_died() and on_depopulated() are its hooks.
 * A site whose NPCs were all killed is spent for the round; the planet sweep takes the rest and
 * they come back next visit. Planet NPCs set `invulnerable = FALSE` and `death_loot`; spawn_npc()
 * scales their health by band. Storms reach them through react_storm() (site.shelter).
 */
