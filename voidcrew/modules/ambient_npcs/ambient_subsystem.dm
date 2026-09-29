/**
 * # World population: SSambient_npcs
 *
 * Owner: P0 seams (frozen).
 *
 * Ambient NPCs exist only while players are near (spec 2.4):
 * - Trader outposts. Every tick it counts living players with a client on each loaded outpost's
 *   concourse. The first arrivals step off the hangar lift 30 to 60 seconds after the first player,
 *   one at a time, by /datum/ambient_outpost_role (PA, PD); nobody on the concourse for three
 *   minutes and every transient NPC there is deleted (nobody is there to see them walk out).
 *   Outposts never unload, so this is the only thing keeping them cheap.
 * - Planets. SSplanet_mobs asks it for a planet's people when it populates the planet for arriving
 *   players, before the fauna, and charges them to the same budget; its grace sweep deletes them
 *   with the fauna. At the first arrival the planet's sites are rolled for the round
 *   (/datum/ambient_site_kind, PB and PC); a site whose NPCs were all killed stays empty (spent).
 *   The records are forgotten when the planet unloads: its next build is a new planet.
 * - Asteroid fields. Once per field per round, from the field's one-time population.
 *
 * It also relays what NPCs react to: a fight or the convoy at an outpost (the outpost's signals),
 * the kingpin's shootout (read from his crew), and storms on planets (the weather telegraph).
 */
SUBSYSTEM_DEF(ambient_npcs)
	name = "Ambient NPCs"
	wait = AMBIENT_SUBSYSTEM_WAIT
	// Nothing to set up while the world loads. If an Initialize() is ever added, drop SS_NO_INIT and
	// list the subsystems it needs in `dependencies`.
	flags = SS_BACKGROUND | SS_NO_INIT | SS_POST_FIRE_TIMING
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME
	/// Trader outpost -> /datum/ambient_place/outpost, made when a player is first seen there
	var/list/outposts = list()
	/// SSplanet_mobs tracker key -> /datum/ambient_planet
	var/list/planets = list()
	/// Sites on asteroid fields (/datum/ambient_place/site), until their NPCs are gone
	var/list/field_sites = list()
	/// Sites an admin made by hand
	var/list/admin_sites = list()
	/// Shared /datum/ambient_site_kind instances, built on first use
	var/list/site_kinds
	/// Shared /datum/ambient_outpost_role instances, built on first use
	var/list/outpost_roles
	/// It listens for storms
	var/weather_hooked = FALSE
#ifdef UNIT_TESTS
	/// Whether it runs outposts on its own clock. Off in tests, which drive it by hand.
	var/ambient_auto = FALSE
#else
	/// Whether it runs outposts on its own clock. Off in tests, which drive it by hand.
	var/ambient_auto = TRUE
#endif

/datum/controller/subsystem/ambient_npcs/fire(resumed)
	if(!ambient_auto)
		return
	hook_weather()
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		if(QDELETED(outpost) || !outpost.loaded)
			continue
		var/list/players = outpost_players(outpost)
		var/datum/ambient_place/outpost/place = outposts[outpost]
		if(!place)
			if(!length(players))
				continue
			place = outpost_place(outpost)
		update_outpost(place, length(players))
		check_shootout(place)
	prune_field_sites()

/datum/controller/subsystem/ambient_npcs/stat_entry(msg)
	var/occupied = 0
	for(var/outpost in outposts)
		var/datum/ambient_place/outpost/place = outposts[outpost]
		if(place.occupied)
			occupied++
	msg = "NPC:[length(GLOB.ambient_npcs)]|O:[occupied]/[length(outposts)]|P:[length(planets)]|F:[length(field_sites)]"
	return ..()

// =========================================================================
// KINDS AND ROLES
// =========================================================================

/// Every site kind, one shared instance each
/datum/controller/subsystem/ambient_npcs/proc/get_site_kinds()
	if(isnull(site_kinds))
		site_kinds = list()
		for(var/kind_type in subtypesof(/datum/ambient_site_kind))
			site_kinds += new kind_type
	return site_kinds

/// The shared instance of site kind `kind_type`, or null
/datum/controller/subsystem/ambient_npcs/proc/get_site_kind(kind_type)
	for(var/datum/ambient_site_kind/kind as anything in get_site_kinds())
		if(kind.type == kind_type)
			return kind
	return null

/// Every outpost role, one shared instance each
/datum/controller/subsystem/ambient_npcs/proc/get_outpost_roles()
	if(isnull(outpost_roles))
		outpost_roles = list()
		for(var/role_type in subtypesof(/datum/ambient_outpost_role))
			outpost_roles += new role_type
	return outpost_roles

// =========================================================================
// TRADER OUTPOSTS
// =========================================================================

/// Living players with a client on `outpost`'s concourse (the hangars do not count)
/datum/controller/subsystem/ambient_npcs/proc/outpost_players(obj/structure/overmap/trader_outpost/outpost)
	. = list()
	var/list/bounds = bounty_outpost_bounds(outpost)
	if(!bounds || !islist(SSmobs.clients_by_zlevel) || bounds[5] > length(SSmobs.clients_by_zlevel))
		return
	for(var/mob/living/player in SSmobs.clients_by_zlevel[bounds[5]])
		if(player.stat == DEAD || !player.client)
			continue
		if(ambient_in_bounds(get_turf(player), bounds))
			. += player

/// A free tile of `outpost`'s hangar lift alcove, where someone arriving steps off, or null
/datum/controller/subsystem/ambient_npcs/proc/lift_arrival_turf(obj/structure/overmap/trader_outpost/outpost)
	if(!length(outpost?.lobby_alcove_turfs))
		return null
	for(var/turf/alcove as anything in shuffle(outpost.lobby_alcove_turfs.Copy()))
		if(!alcove.is_blocked_turf(exclude_mobs = FALSE))
			return alcove
	return null

/// `outpost`'s place, made if it has none
/datum/controller/subsystem/ambient_npcs/proc/outpost_place(obj/structure/overmap/trader_outpost/outpost)
	if(QDELETED(outpost))
		return null
	var/datum/ambient_place/outpost/place = outposts[outpost]
	if(!place)
		place = new(outpost)
		outposts[outpost] = place
	return place

/**
 * One tick of `place`'s presence, with `players` on its concourse now. `roles` overrides the roles
 * that may arrive (tests); null for all of them.
 */
/datum/controller/subsystem/ambient_npcs/proc/update_outpost(datum/ambient_place/outpost/place, players, list/roles)
	var/obj/structure/overmap/trader_outpost/outpost = place?.outpost()
	if(!outpost)
		return
	if(players > 0)
		if(!place.occupied)
			place.occupied = TRUE
			place.arrivals_at = world.time + rand(AMBIENT_OUTPOST_ARRIVAL_DELAY_LOW, AMBIENT_OUTPOST_ARRIVAL_DELAY_HIGH)
			SEND_SIGNAL(outpost, COMSIG_AMBIENT_OUTPOST_OCCUPIED, place)
		place.players = players
		place.last_player_at = world.time
		if(world.time >= place.arrivals_at)
			arrive_next(place, roles)
		return
	place.players = 0
	if(place.occupied && world.time - place.last_player_at >= AMBIENT_OUTPOST_GRACE)
		clear_outpost(place)

/**
 * The next person off the lift at `place`: one role that is due (under its count and past its
 * gap), weighted, while the outpost is under AMBIENT_OUTPOST_TRANSIENT_CAP and the lift has room.
 * Returns the NPC, or null.
 */
/datum/controller/subsystem/ambient_npcs/proc/arrive_next(datum/ambient_place/outpost/place, list/roles)
	var/obj/structure/overmap/trader_outpost/outpost = place?.outpost()
	if(!outpost || length(place.living_npcs()) >= AMBIENT_OUTPOST_TRANSIENT_CAP)
		return null
	var/list/due = list()
	for(var/datum/ambient_outpost_role/role as anything in (roles || get_outpost_roles()))
		if(!role.npc_type || !role.applies_to(outpost))
			continue
		if(place.role_next_at[role.type] > world.time)
			continue
		if(place.count_role(role.type) >= role.wanted(place))
			continue
		due[role] = max(1, role.weight)
	if(!length(due))
		return null
	var/turf/arrival = lift_arrival_turf(outpost)
	if(!arrival)
		return null
	var/datum/ambient_outpost_role/chosen = pick_weight(due)
	place.role_next_at[chosen.type] = world.time + rand(chosen.gap_low, chosen.gap_high)
	return chosen.arrive(place, arrival)

/// Nobody has been on `place`'s concourse for the grace: every transient NPC there goes at once
/datum/controller/subsystem/ambient_npcs/proc/clear_outpost(datum/ambient_place/outpost/place)
	for(var/mob/living/basic/ambient_npc/npc as anything in place.npcs.Copy())
		// Never someone an admin is driving
		if(!QDELETED(npc) && !npc.ckey)
			npc.fade_out(instant = TRUE)
	place.occupied = FALSE
	place.players = 0
	place.last_player_at = 0
	place.arrivals_at = 0
	place.role_next_at.Cut()
	place.shootout_refuge = null
	var/obj/structure/overmap/trader_outpost/outpost = place.outpost()
	if(outpost)
		SEND_SIGNAL(outpost, COMSIG_AMBIENT_OUTPOST_EMPTIED, place)

/// Sends everyone at `place` for cover while the kingpin's crew fights there, and back when it is over
/datum/controller/subsystem/ambient_npcs/proc/check_shootout(datum/ambient_place/outpost/place)
	if(!place.occupied)
		return
	var/turf/refuge = ambient_kingpin_refuge(place.outpost())
	if(refuge && !place.shootout_refuge)
		place.shootout_refuge = refuge
		for(var/mob/living/basic/ambient_npc/npc as anything in place.living_npcs())
			npc.react_shootout(refuge)
	else if(!refuge && place.shootout_refuge)
		place.shootout_refuge = null
		for(var/mob/living/basic/ambient_npc/npc as anything in place.living_npcs())
			npc.shootout_over()

/**
 * Where bystanders go while the kingpin's crew fights at `outpost`: his lounge's refuge, or null
 * when his crew is calm or somewhere else. Read only (bounty_kingpin.dm).
 */
/proc/ambient_kingpin_refuge(obj/structure/overmap/trader_outpost/outpost)
	if(!outpost)
		return null
	for(var/datum/bounty_kingpin_crew/crew in GLOB.bounty_kingpin_crews)
		if(crew.crew_state == BOUNTY_KINGPIN_CALM)
			continue
		var/turf/refuge = crew.crew_refuge
		if(refuge && get_trader_outpost_for_turf(refuge) == outpost)
			return refuge
	return null

// =========================================================================
// PLANETS
// =========================================================================

/**
 * `tracker`'s planet record, made from its overmap planet if it has none and `create`. Null for
 * anything that is not a terrain planet with a planet datum.
 */
/datum/controller/subsystem/ambient_npcs/proc/planet_record(datum/planet_mob_tracker/tracker, create = TRUE)
	if(!tracker?.name)
		return null
	var/datum/ambient_planet/record = planets[tracker.name]
	if(record || !create)
		return record
	var/obj/structure/overmap/planet/planet = locate(tracker.name)
	if(!istype(planet) || !planet.planet || !planet.is_terrain_planet())
		return null
	record = new
	record.key = tracker.name
	record.planet_ref = WEAKREF(planet)
	record.planet_type = planet.planet
	record.band = isnull(tracker.zone_band) ? planet.get_effective_zone_band() : tracker.zone_band
	var/datum/map_footprint/footprint = tracker.footprint
	if(footprint && !QDELETED(footprint) && footprint.z_value && !isnull(footprint.low_x))
		record.bounds = list(footprint.low_x, footprint.low_y, footprint.high_x, footprint.high_y, footprint.z_value)
	else
		record.bounds = list(1, 1, world.maxx, world.maxy, tracker.surface_z)
	record.dock_top_y = planet.get_dock_strip_top_y(SSmapping.get_level(tracker.surface_z))
	planets[tracker.name] = record
	return record

/**
 * Called by SSplanet_mobs.spawn_planet_mobs() before the fauna: rolls the planet's sites the first
 * time, then brings out every site's missing NPCs that fit its budget (AMBIENT_PLANET_NPCS_MAX, its
 * fauna cap, the galaxy's cap). Returns how many NPCs it spawned, which the caller charges to the
 * planet's budget.
 */
/datum/controller/subsystem/ambient_npcs/proc/populate_planet(datum/planet_mob_tracker/tracker)
	var/datum/ambient_planet/record = planet_record(tracker)
	if(!record)
		return 0
	if(!record.rolled)
		roll_planet_sites(record)
	var/planet_cap = tracker.mob_cap || SSplanet_mobs.per_planet_mob_cap
	var/budget = min(AMBIENT_PLANET_NPCS_MAX, planet_cap, SSplanet_mobs.global_mob_cap - SSplanet_mobs.total_managed_mobs)
	return realize_planet(record, budget)

/**
 * Rolls `record`'s sites for the round: each kind in random order, by its chance on this planet,
 * until AMBIENT_PLANET_SITES_MAX sites or AMBIENT_PLANET_NPCS_MAX NPCs. `kinds` overrides the kinds
 * (tests); null for all of them. Returns the sites.
 */
/datum/controller/subsystem/ambient_npcs/proc/roll_planet_sites(datum/ambient_planet/record, list/kinds)
	record.rolled = TRUE
	var/list/candidates = kinds || get_site_kinds()
	candidates = shuffle(candidates.Copy())
	var/list/taken = list()
	var/npcs = 0
	for(var/datum/ambient_place/site/existing as anything in record.sites)
		taken += existing.center
		npcs += existing.npc_total
	for(var/datum/ambient_site_kind/kind as anything in candidates)
		if(length(record.sites) >= AMBIENT_PLANET_SITES_MAX)
			break
		var/chance = kind.chance_on(record)
		if(chance <= 0 || !prob(chance))
			continue
		var/count = clamp(kind.npc_count(record.band), 1, AMBIENT_PLANET_NPCS_MAX)
		if(npcs + count > AMBIENT_PLANET_NPCS_MAX)
			continue
		var/turf/spot = kind.find_spot(record, taken)
		if(!spot)
			continue
		var/datum/ambient_place/site/site = new(kind, spot, record)
		site.npc_total = count
		record.sites += site
		taken += spot
		npcs += count
	return record.sites

/**
 * Brings out every site on `record` that is not spent and whose missing NPCs fit in what is left of
 * `budget`. A site comes out whole or not at all. Returns how many NPCs were spawned.
 */
/datum/controller/subsystem/ambient_npcs/proc/realize_planet(datum/ambient_planet/record, budget)
	var/spawned = 0
	for(var/datum/ambient_place/site/site as anything in record.sites)
		if(site.state == AMBIENT_SITE_SPENT)
			continue
		var/missing = site.npcs_missing()
		if(!missing || missing > budget - spawned)
			continue
		var/before = length(site.living_npcs())
		if(!site.kind.realize(site))
			continue
		spawned += max(0, length(site.living_npcs()) - before)
	return spawned

/// Called by SSplanet_mobs.despawn_planet_mobs() after its sweep: the planet's NPCs are gone until the next visit
/datum/controller/subsystem/ambient_npcs/proc/planet_depopulated(datum/planet_mob_tracker/tracker)
	var/datum/ambient_planet/record = planet_record(tracker, create = FALSE)
	if(!record)
		return
	for(var/datum/ambient_place/site/site as anything in record.sites)
		if(site.state == AMBIENT_SITE_ACTIVE && !length(site.living_npcs()))
			site.state = AMBIENT_SITE_DORMANT
		site.kind.on_depopulated(site)

/// Called by SSplanet_mobs.unregister_planet(): the planet unloads, and its next build is a new planet
/datum/controller/subsystem/ambient_npcs/proc/forget_planet(planet_key)
	var/datum/ambient_planet/record = planets[planet_key]
	if(!record)
		return
	planets -= planet_key
	qdel(record)

// =========================================================================
// ASTEROID FIELDS
// =========================================================================

/**
 * Called once per field per round from the field's one-time population
 * (/obj/structure/overmap/event/meteor/populate_field_extras()): maybe a site on the carved rock,
 * by the kinds' `field_chance`. `open_turfs` are free open tiles of the field. Returns how many NPCs
 * it spawned. `kinds` overrides the kinds (tests).
 */
/datum/controller/subsystem/ambient_npcs/proc/populate_field(obj/structure/overmap/field, list/open_turfs, list/kinds)
	if(!length(open_turfs))
		return 0
	var/band = SSovermap.get_zone_band_for_turf(get_turf(field)) || ZONE_GREEN
	var/list/taken = list()
	var/spawned = 0
	var/list/candidates = kinds || get_site_kinds()
	for(var/datum/ambient_site_kind/kind as anything in shuffle(candidates.Copy()))
		if(length(taken) >= AMBIENT_FIELD_SITES_MAX)
			break
		if(kind.field_chance <= 0 || !(band in kind.bands) || !prob(kind.field_chance))
			continue
		var/turf/spot = kind.find_field_spot(open_turfs, taken)
		if(!spot)
			continue
		var/datum/ambient_place/site/site = new(kind, spot, null)
		site.field_ref = WEAKREF(field)
		site.band = band
		site.npc_total = clamp(kind.npc_count(band), 1, AMBIENT_PLANET_NPCS_MAX)
		field_sites += site
		taken += spot
		if(kind.realize(site))
			spawned += length(site.living_npcs())
	return spawned

/// Field sites whose NPCs are all gone (the field unloaded, or they were killed) are done: fields populate once a round
/datum/controller/subsystem/ambient_npcs/proc/prune_field_sites()
	for(var/datum/ambient_place/site/site as anything in field_sites.Copy())
		if(length(site.npcs))
			continue
		field_sites -= site
		qdel(site)

// =========================================================================
// STORMS
// =========================================================================

/// Listens for every storm's telegraph, once
/datum/controller/subsystem/ambient_npcs/proc/hook_weather()
	if(weather_hooked)
		return
	weather_hooked = TRUE
	for(var/weather_type in subtypesof(/datum/weather))
		RegisterSignal(SSdcs, COMSIG_WEATHER_TELEGRAPH(weather_type), PROC_REF(on_weather_telegraph))

/// A storm is coming somewhere: everyone at a site it falls on reacts
/datum/controller/subsystem/ambient_npcs/proc/on_weather_telegraph(datum/source, datum/weather/storm)
	SIGNAL_HANDLER
	for(var/key in planets)
		var/datum/ambient_planet/record = planets[key]
		if(!storm_hits(record, storm))
			continue
		for(var/datum/ambient_place/site/site as anything in record.sites)
			for(var/mob/living/basic/ambient_npc/npc as anything in site.living_npcs())
				npc.react_storm(storm)

/// Whether `storm` falls on `record`'s planet: its weather site when it came from one, its level otherwise
/datum/controller/subsystem/ambient_npcs/proc/storm_hits(datum/ambient_planet/record, datum/weather/storm)
	if(!istype(storm) || !length(record?.bounds))
		return FALSE
	if(storm.weather_site)
		var/obj/structure/overmap/planet/planet = record.planet()
		return planet?.weather_site == storm.weather_site
	return (record.bounds[5] in storm.impacted_z_levels)

// =========================================================================
// PLACES
// =========================================================================

/datum/ambient_place/Destroy()
	for(var/mob/living/basic/ambient_npc/npc as anything in npcs.Copy())
		if(npc.place == src)
			npc.place = null
	npcs.Cut()
	return ..()

/// `npc` belongs here now. Use /mob/living/basic/ambient_npc/proc/set_place(), which calls this.
/datum/ambient_place/proc/add_npc(mob/living/basic/ambient_npc/npc)
	npcs |= npc

/// `npc` is gone from here (deleted, or moved elsewhere)
/datum/ambient_place/proc/remove_npc(mob/living/basic/ambient_npc/npc)
	npcs -= npc

/// `npc` died here
/datum/ambient_place/proc/npc_died(mob/living/basic/ambient_npc/npc)
	return

/// Its NPCs who are alive and not leaving
/datum/ambient_place/proc/living_npcs()
	. = list()
	for(var/mob/living/basic/ambient_npc/npc as anything in npcs)
		if(!QDELETED(npc) && npc.stat != DEAD && !npc.fading)
			. += npc

/// Whether its NPCs may be on `tile` by their own steps (their leash). Override.
/datum/ambient_place/proc/leash_ok(turf/tile, mob/living/basic/ambient_npc/npc)
	return TRUE

/// Whether an activity may send `npc` to `tile` (an outpost's public floor). Override.
/datum/ambient_place/proc/spot_allowed(turf/tile, mob/living/basic/ambient_npc/npc)
	return TRUE

/// Where `npc` leaves from (a lift), or null to fade where they stand. Override.
/datum/ambient_place/proc/exit_turf(mob/living/basic/ambient_npc/npc)
	return null

/// The band's health multiplier for a killable NPC here
/datum/ambient_place/proc/health_multiplier()
	switch(band)
		if(ZONE_YELLOW)
			return AMBIENT_HEALTH_MULT_YELLOW
		if(ZONE_RED)
			return AMBIENT_HEALTH_MULT_RED
	return 1

/// One line for the admin verb
/datum/ambient_place/proc/describe()
	return "[name]: [length(living_npcs())] out"

// ----- trader outposts -----

/datum/ambient_place/outpost/New(obj/structure/overmap/trader_outpost/outpost)
	. = ..()
	outpost_ref = WEAKREF(outpost)
	name = outpost.name
	band = SSovermap.get_zone_band_for_turf(get_turf(outpost))
	RegisterSignal(outpost, COMSIG_TRADER_OUTPOST_VIOLENCE, PROC_REF(on_violence))
	RegisterSignal(outpost, COMSIG_TRADER_OUTPOST_CONVOY, PROC_REF(on_convoy))
	RegisterSignal(outpost, COMSIG_QDELETING, PROC_REF(on_outpost_deleted))

/datum/ambient_place/outpost/Destroy()
	var/obj/structure/overmap/trader_outpost/outpost = outpost()
	if(outpost)
		UnregisterSignal(outpost, list(COMSIG_TRADER_OUTPOST_VIOLENCE, COMSIG_TRADER_OUTPOST_CONVOY, COMSIG_QDELETING))
	for(var/mob/living/basic/ambient_npc/npc as anything in npcs.Copy())
		if(!QDELETED(npc))
			qdel(npc)
	public_floor = null
	shootout_refuge = null
	concourse = null
	role_next_at = null
	return ..()

/// The outpost, if it is still there
/datum/ambient_place/outpost/proc/outpost()
	var/obj/structure/overmap/trader_outpost/outpost = outpost_ref?.resolve()
	return QDELETED(outpost) ? null : outpost

/datum/ambient_place/outpost/proc/on_outpost_deleted(datum/source)
	SIGNAL_HANDLER
	SSambient_npcs.outposts -= source
	qdel(src)

/// A fight at the outpost: everyone near it ducks and heads off
/datum/ambient_place/outpost/proc/on_violence(datum/source, mob/living/offender)
	SIGNAL_HANDLER
	for(var/mob/living/basic/ambient_npc/npc as anything in living_npcs())
		if(get_dist(npc, offender) <= AMBIENT_VIOLENCE_RANGE)
			npc.react_violence(offender)

/datum/ambient_place/outpost/proc/on_convoy(datum/source)
	SIGNAL_HANDLER
	var/obj/structure/overmap/trader_outpost/outpost = outpost()
	for(var/mob/living/basic/ambient_npc/npc as anything in living_npcs())
		npc.react_convoy(outpost)

/// How many of its living NPCs came as role `role_type`
/datum/ambient_place/outpost/proc/count_role(role_type)
	. = 0
	for(var/mob/living/basic/ambient_npc/npc as anything in living_npcs())
		if(npc.role == role_type)
			.++

/// The concourse, as list(min x, min y, max x, max y, z), or null before the outpost has loaded. Outposts never move.
/datum/ambient_place/outpost/proc/concourse_bounds()
	if(!concourse)
		concourse = bounty_outpost_bounds(outpost())
	return concourse

/// The concourse floor customers can walk from the lift (turf = TRUE), worked out now and then
/datum/ambient_place/outpost/proc/get_public_floor()
	if(public_floor && world.time < floor_built_at + AMBIENT_OUTPOST_FLOOR_REFRESH)
		return public_floor
	floor_built_at = world.time
	public_floor = list()
	var/obj/structure/overmap/trader_outpost/outpost = outpost()
	if(outpost)
		for(var/turf/tile as anything in bounty_outpost_public_floor(outpost))
			public_floor[tile] = TRUE
	return public_floor

// On the concourse: the lift alcove included, so someone just off the lift is not off their leash
/datum/ambient_place/outpost/leash_ok(turf/tile, mob/living/basic/ambient_npc/npc)
	return ambient_in_bounds(tile, concourse_bounds())

// The public floor, never the lift itself (it carries off whoever stands on it)
/datum/ambient_place/outpost/spot_allowed(turf/tile, mob/living/basic/ambient_npc/npc)
	var/obj/structure/overmap/trader_outpost/outpost = outpost()
	if(!outpost || (tile in outpost.lobby_alcove_turfs))
		return FALSE
	var/list/floor = get_public_floor()
	return !!floor[tile]

/datum/ambient_place/outpost/exit_turf(mob/living/basic/ambient_npc/npc)
	return bounty_outpost_exit_turf(npc, outpost())

/datum/ambient_place/outpost/describe()
	return "[name]: [occupied ? "occupied" : "empty"], [players] player\s, [length(living_npcs())] NPC\s"

// ----- planet and field sites -----

/datum/ambient_place/site/New(datum/ambient_site_kind/kind, turf/center, datum/ambient_planet/planet)
	. = ..()
	src.kind = kind
	src.center = center
	src.planet = planet
	name = kind?.name || "site"
	band = planet?.band

/datum/ambient_place/site/Destroy()
	kind = null
	center = null
	shelter = null
	planet = null
	props.Cut()
	data.Cut()
	return ..()

/datum/ambient_place/site/remove_npc(mob/living/basic/ambient_npc/npc)
	. = ..()
	if(state == AMBIENT_SITE_ACTIVE && !length(living_npcs()))
		state = AMBIENT_SITE_DORMANT

/// One of its NPCs was killed: once they all are, it is spent for the round
/datum/ambient_place/site/npc_died(mob/living/basic/ambient_npc/npc)
	dead++
	if(dead >= npc_total)
		state = AMBIENT_SITE_SPENT
	kind?.on_npc_died(src, npc)

/// How many of its NPCs should be out but are not: never the dead ones
/datum/ambient_place/site/proc/npcs_missing()
	if(state == AMBIENT_SITE_SPENT)
		return 0
	return max(0, npc_total - dead - length(living_npcs()))

/// Makes one of its NPCs, of `npc_type`, at `where`: theirs, leashed here, health scaled by band when killable
/datum/ambient_place/site/proc/spawn_npc(npc_type, turf/where)
	where = get_turf(where) || center
	if(!where || !ispath(npc_type, /mob/living/basic/ambient_npc))
		return null
	var/mob/living/basic/ambient_npc/npc = new npc_type(where)
	npc.set_place(src)
	if(!npc.invulnerable)
		npc.scale_health(health_multiplier())
	state = AMBIENT_SITE_ACTIVE
	return npc

/// Remembers `thing` as part of the site (a camp's fire, a boat): it stays when the NPCs go
/datum/ambient_place/site/proc/add_prop(atom/thing)
	if(thing)
		props += WEAKREF(thing)
	return thing

/// Its prop of `prop_type`, if it is still there
/datum/ambient_place/site/proc/get_prop(prop_type)
	for(var/datum/weakref/ref as anything in props)
		var/atom/thing = ref?.resolve()
		if(!QDELETED(thing) && istype(thing, prop_type))
			return thing
	return null

// On its planet's ground above the dock strip and off any ship; on a field, on the field
/datum/ambient_place/site/leash_ok(turf/tile, mob/living/basic/ambient_npc/npc)
	if(!tile || istype(get_area(tile), /area/shuttle))
		return FALSE
	if(planet)
		if(!ambient_in_bounds(tile, planet.bounds))
			return FALSE
		return isnull(planet.dock_top_y) || tile.y > planet.dock_top_y
	var/obj/structure/overmap/event/meteor/field = field_ref?.resolve()
	if(istype(field) && field.footprint)
		return field.footprint.contains_turf(tile)
	return !center || tile.z == center.z

/datum/ambient_place/site/describe()
	var/where = center ? "[center.x],[center.y],[center.z]" : "nowhere"
	return "[name] at [where]: [state], [length(living_npcs())]/[npc_total] out, [dead] dead"

// ----- planet records -----

/datum/ambient_planet/Destroy()
	QDEL_LIST(sites)
	planet_ref = null
	bounds = null
	return ..()

/// The overmap planet, if it is still there
/datum/ambient_planet/proc/planet()
	var/obj/structure/overmap/planet/planet = planet_ref?.resolve()
	return QDELETED(planet) ? null : planet

// =========================================================================
// SITE KINDS (PB and PC subtype these)
// =========================================================================

/// Percent chance it rolls on `record`'s planet. Override for a table per planet type.
/datum/ambient_site_kind/proc/chance_on(datum/ambient_planet/record)
	if(!(record.planet_type in planet_types) || !(record.band in bands))
		return 0
	return chance

/// How many NPCs a new site of this kind has, in `band`. Override (a bigger band in the red).
/datum/ambient_site_kind/proc/npc_count(band)
	return rand(min_npcs, max(min_npcs, max_npcs))

/// Whether `tile` could hold a site's middle: open ground (water only if `spot_on_water`), on the planet's own ground, with `spot_room` clear around it. Override.
/datum/ambient_site_kind/proc/spot_ok(turf/tile)
	if(!ambient_ground_ok(tile, spot_on_water) || !istype(get_area(tile), /area/overmap_encounter))
		return FALSE
	for(var/turf/around as anything in RANGE_TURFS(spot_room, tile))
		if(around != tile && !ambient_ground_ok(around, spot_on_water))
			return FALSE
	return TRUE

/**
 * A spot for a new site on `record`'s planet, sampled: inside its ground less AMBIENT_SITE_EDGE_MARGIN,
 * AMBIENT_SITE_DOCK_CLEARANCE rows above the dock strip, AMBIENT_SITE_SPACING from the spots in
 * `taken`. Null when none turns up. Override for a spot of another kind (a river bank, open water).
 */
/datum/ambient_site_kind/proc/find_spot(datum/ambient_planet/record, list/taken)
	var/list/bounds = record.bounds
	if(length(bounds) < 5)
		return null
	var/low_x = bounds[1] + AMBIENT_SITE_EDGE_MARGIN
	var/high_x = bounds[3] - AMBIENT_SITE_EDGE_MARGIN
	var/low_y = bounds[2] + AMBIENT_SITE_EDGE_MARGIN
	if(!isnull(record.dock_top_y))
		low_y = max(low_y, record.dock_top_y + AMBIENT_SITE_DOCK_CLEARANCE)
	var/high_y = bounds[4] - AMBIENT_SITE_EDGE_MARGIN
	if(low_x > high_x || low_y > high_y)
		return null
	for(var/attempt in 1 to AMBIENT_SITE_SPOT_TRIES)
		var/turf/tile = locate(rand(low_x, high_x), rand(low_y, high_y), bounds[5])
		if(!spot_ok(tile) || ambient_too_close(tile, taken, AMBIENT_SITE_SPACING))
			continue
		return tile
	return null

/// A spot for a new site among an asteroid field's free tiles, or null. Override.
/datum/ambient_site_kind/proc/find_field_spot(list/open_turfs, list/taken)
	for(var/attempt in 1 to min(AMBIENT_SITE_SPOT_TRIES, length(open_turfs)))
		var/turf/tile = pick(open_turfs)
		if(!ambient_ground_ok(tile) || ambient_too_close(tile, taken, AMBIENT_SITE_SPACING))
			continue
		return tile
	return null

/**
 * Brings `site` out: its missing NPCs (site.npcs_missing()) and anything it builds (site.add_prop(),
 * reusing site.get_prop() on a later visit). Returns TRUE if anything came out. The default makes
 * `npc_type` NPCs at and around its middle; a kind with no `npc_type` does nothing. Override.
 */
/datum/ambient_site_kind/proc/realize(datum/ambient_place/site/site)
	if(!npc_type)
		return FALSE
	var/missing = site.npcs_missing()
	if(!missing)
		return FALSE
	for(var/i in 1 to missing)
		var/turf/where = site.center
		if(i > 1 || where.is_blocked_turf(exclude_mobs = FALSE))
			where = ambient_free_turf_near(site.center, 2) || site.center
		site.spawn_npc(npc_type, where)
	return TRUE

/// One of `site`'s NPCs was killed. Override.
/datum/ambient_site_kind/proc/on_npc_died(datum/ambient_place/site/site, mob/living/basic/ambient_npc/npc)
	return

/// The planet was swept: `site`'s NPCs are gone until the next visit (a fire burns down). Override.
/datum/ambient_site_kind/proc/on_depopulated(datum/ambient_place/site/site)
	return

// =========================================================================
// OUTPOST ROLES (PA and PD subtype these)
// =========================================================================

/// Whether it comes to `outpost`
/datum/ambient_outpost_role/proc/applies_to(obj/structure/overmap/trader_outpost/outpost)
	return !length(outpost_types) || is_type_in_list(outpost, outpost_types)

/// How many of it `place` should have right now. Override (none at night, more in a crowd).
/datum/ambient_outpost_role/proc/wanted(datum/ambient_place/outpost/place)
	return max_count

/// One of it steps off the lift at `where`. Returns the NPC. Override to dress or brief them.
/datum/ambient_outpost_role/proc/arrive(datum/ambient_place/outpost/place, turf/where)
	if(!npc_type)
		return null
	var/mob/living/basic/ambient_npc/npc = new npc_type(where)
	npc.role = type
	npc.set_place(place)
	npc.fade_in()
	return npc

// =========================================================================
// HELPERS
// =========================================================================

/// Whether `tile` is within `distance` of any turf in `others`
/proc/ambient_too_close(turf/tile, list/others, distance)
	for(var/turf/other as anything in others)
		if(other.z == tile.z && get_dist(other, tile) < distance)
			return TRUE
	return FALSE

/// A free open tile within `radius` of `center` (not `center` itself), or null
/proc/ambient_free_turf_near(turf/center, radius)
	if(!center)
		return null
	var/list/options = list()
	for(var/turf/tile as anything in RANGE_TURFS(radius, center))
		if(tile != center && ambient_ground_ok(tile) && !tile.is_blocked_turf(exclude_mobs = FALSE))
			options += tile
	return length(options) ? pick(options) : null
