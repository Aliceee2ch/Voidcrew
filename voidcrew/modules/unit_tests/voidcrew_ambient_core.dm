/**
 * World population: tests for the P0 core in voidcrew/modules/ambient_npcs/ (ambient_npc.dm,
 * ambient_activity.dm, ambient_subsystem.dm) and its hooks in planet_mobs.dm.
 *
 * Owner: P0 seams. Fork defines are included after the tests, so a test uses the literal value
 * with a comment naming the define. The tests drive the subsystem, the places and the activities
 * by hand: nothing here needs a client, a real outpost map or a real planet.
 */

/// A plain ambient NPC for the core tests, who only stands about
/mob/living/basic/ambient_npc/core_test
	routine = list(/datum/ambient_activity/idle = 1)

/// One who can be killed, with something to drop
/mob/living/basic/ambient_npc/core_test/killable
	invulnerable = FALSE
	death_loot = list(/obj/item/pickaxe)

/// One who only ever sits down
/mob/living/basic/ambient_npc/core_test/sitter
	routine = list(/datum/ambient_activity/sit = 1)

/// A site kind the tests hand to the subsystem. No planet types and no npc_type, so the shared instance never rolls or spawns.
/datum/ambient_site_kind/core_test
	name = "core test camp"
	min_npcs = 2
	max_npcs = 2
	spot_room = 0

/// Any free test-room tile nobody took, ignoring the spacing a real planet needs
/datum/ambient_site_kind/core_test/find_spot(datum/ambient_planet/record, list/taken)
	var/list/bounds = record.bounds
	for(var/turf/tile as anything in block(locate(bounds[1], bounds[2], bounds[5]), locate(bounds[3], bounds[4], bounds[5])))
		if(!(tile in taken))
			return tile
	return null

/// An outpost role the tests hand to the subsystem. No npc_type, so the shared instance never arrives.
/datum/ambient_outpost_role/core_test
	name = "core test visitor"
	max_count = 3
	gap_low = 0
	gap_high = 0

/// The test room as a place: its bounds, list(min x, min y, max x, max y, z)
/datum/unit_test/proc/ambient_test_room_bounds()
	return list(run_loc_floor_bottom_left.x, run_loc_floor_bottom_left.y, run_loc_floor_top_right.x, run_loc_floor_top_right.y, run_loc_floor_bottom_left.z)

/// A trader outpost whose concourse is the test room, with its hangar lift in the top right corner
/datum/unit_test/proc/ambient_test_outpost()
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost)
	outpost.outpost_template = allocate(/datum/map_template/trader_outpost)
	outpost.outpost_template.width = run_loc_floor_top_right.x - run_loc_floor_bottom_left.x + 1
	outpost.outpost_template.height = run_loc_floor_top_right.y - run_loc_floor_bottom_left.y + 1
	outpost.template_bottom_left = run_loc_floor_bottom_left
	outpost.lobby_alcove_turfs = list(run_loc_floor_top_right)
	return outpost

// =========================================================================
// THE BASE NPC
// =========================================================================

/// Nobody drags, boxes, teleports, polymorphs or hurts an outpost NPC; turrets read it as harmless; a killable one drops its loot once
/datum/unit_test/voidcrew_ambient_npc_protections

/datum/unit_test/voidcrew_ambient_npc_protections/Run()
	var/mob/living/basic/ambient_npc/core_test/npc = allocate(/mob/living/basic/ambient_npc/core_test, run_loc_floor_bottom_left)
	TEST_ASSERT(npc in GLOB.ambient_npcs, "An ambient NPC is not on the list")
	TEST_ASSERT_EQUAL(npc.sentience_type, SENTIENCE_HUMANOID, "Sentience or transference potions would work on an ambient NPC")
	TEST_ASSERT(HAS_TRAIT(npc, TRAIT_GODMODE), "An outpost NPC can be hurt")
	TEST_ASSERT(HAS_TRAIT(npc, "no_containment"), "An ambient NPC can be shut in a closet") // TRAIT_NO_CONTAINMENT
	TEST_ASSERT(HAS_TRAIT(npc, TRAIT_NO_STORAGE_INSERT), "An ambient NPC can be put in a bag")
	TEST_ASSERT(HAS_TRAIT(npc, TRAIT_WEATHER_IMMUNE), "Weather hurts an ambient NPC")
	TEST_ASSERT(!npc.unsuitable_atmos_damage && !npc.unsuitable_cold_damage && !npc.unsuitable_heat_damage, "An ambient NPC dies in vacuum or cold")
	TEST_ASSERT(FACTION_TURRET in npc.faction, "Outpost turrets do not count an outpost NPC as their own")
	TEST_ASSERT(!is_hostile_creature(npc), "Outpost turrets would shoot an ambient NPC as a wild hostile")
	TEST_ASSERT(npc.name != initial(npc.name), "An ambient NPC has no name of their own")

	// Godmode: a heavy blow does nothing
	var/health_before = npc.health
	npc.apply_damage(50, BRUTE)
	TEST_ASSERT_EQUAL(npc.health, health_before, "A blow hurt an outpost NPC")

	// Teleports of any kind leave them where they are
	var/turf/start = get_turf(npc)
	TEST_ASSERT(!do_teleport(npc, run_loc_floor_top_right, forced = TRUE, no_effects = TRUE), "An ambient NPC was teleported")
	TEST_ASSERT_EQUAL(get_turf(npc), start, "An ambient NPC moved when teleported")

	// No polymorph, no mob type change
	TEST_ASSERT(SEND_SIGNAL(npc, COMSIG_LIVING_PRE_WABBAJACKED, "animal") & STOP_WABBAJACK, "An ambient NPC can be polymorphed")
	TEST_ASSERT(SEND_SIGNAL(npc, COMSIG_PRE_MOB_CHANGED_TYPE) & COMPONENT_BLOCK_MOB_CHANGE, "An ambient NPC can be turned into another mob")

	// No pulling, no drag-dropping onto a bed or into a crate, no closet
	var/mob/living/carbon/human/player = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	player.start_pulling(npc)
	TEST_ASSERT(player.pulling != npc, "An ambient NPC can be pulled")
	TEST_ASSERT(SEND_SIGNAL(npc, COMSIG_MOUSEDROP_ONTO, run_loc_floor_top_right, player) & COMPONENT_CANCEL_MOUSEDROP_ONTO, "An ambient NPC can be drag-dropped")
	var/obj/structure/closet/closet = allocate(/obj/structure/closet, get_turf(npc))
	TEST_ASSERT(!closet.insertion_allowed(npc), "A closet takes an ambient NPC")

	// Talking to them with an empty hand is not an attack
	npc.attack_hand(player, list())
	TEST_ASSERT_EQUAL(npc.health, health_before, "Talking to an ambient NPC hurt them")

	// The leash: never a step off it by themselves; off it, a step back is allowed
	var/turf/corner = run_loc_floor_bottom_left
	var/mob/living/basic/ambient_npc/core_test/leashed = allocate(/mob/living/basic/ambient_npc/core_test, corner)
	leashed.leash_bounds = list(corner.x, corner.y, corner.x + 1, corner.y + 1, corner.z)
	var/turf/edge = locate(corner.x + 1, corner.y, corner.z)
	var/turf/outside = locate(corner.x + 2, corner.y, corner.z)
	var/turf/far_outside = locate(corner.x + 3, corner.y, corner.z)
	leashed.forceMove(edge)
	TEST_ASSERT(!leashed.leash_ok(outside), "A turf off the leash counts as on it")
	TEST_ASSERT(!leashed.Move(outside, EAST), "An ambient NPC walked off their leash")
	TEST_ASSERT_EQUAL(get_turf(leashed), edge, "An ambient NPC left their leash")
	leashed.forceMove(far_outside)
	TEST_ASSERT(leashed.own_step_allowed(outside), "An ambient NPC off their leash may not step back towards it")

	// A killable one dies, drops its loot once, and a revived one killed again drops nothing more
	var/turf/loot_turf = run_loc_floor_top_right
	var/mob/living/basic/ambient_npc/core_test/killable/victim = allocate(/mob/living/basic/ambient_npc/core_test/killable, loot_turf)
	TEST_ASSERT(!HAS_TRAIT(victim, TRAIT_GODMODE), "A killable NPC is in godmode")
	victim.death()
	TEST_ASSERT_EQUAL(victim.stat, DEAD, "A killable NPC did not die")
	TEST_ASSERT_EQUAL(count_pickaxes(loot_turf), 1, "A killable NPC dropped [count_pickaxes(loot_turf)] of its loot, not one")
	victim.revive(ADMIN_HEAL_ALL)
	victim.death()
	TEST_ASSERT_EQUAL(count_pickaxes(loot_turf), 1, "A revived NPC dropped its loot again")

/datum/unit_test/voidcrew_ambient_npc_protections/proc/count_pickaxes(turf/where)
	. = 0
	for(var/obj/item/pickaxe/pick in where)
		.++

/// Dialogue: lines come from the file with the core's as a fallback, placeholders fill, and cooldowns hold
/datum/unit_test/voidcrew_ambient_npc_dialogue

/datum/unit_test/voidcrew_ambient_npc_dialogue/Run()
	var/mob/living/basic/ambient_npc/core_test/npc = allocate(/mob/living/basic/ambient_npc/core_test, run_loc_floor_bottom_left)
	TEST_ASSERT(length(npc.get_lines("attacked")), "The core file has no line for being attacked") // AMBIENT_LINE_ATTACKED
	TEST_ASSERT(length(npc.get_lines("talk")), "The core file has no line for being talked to") // AMBIENT_LINE_TALK
	TEST_ASSERT_EQUAL(length(ambient_dialogue_lines("no_such_file.json", "default", "talk")), 0, "A missing dialogue file gave lines")
	TEST_ASSERT_EQUAL(length(npc.get_lines("no_such_context")), 0, "A missing context gave lines")
	TEST_ASSERT(length(npc.pick_conversation()) == 2, "The core file has no two-person conversation")
	var/filled = npc.fill_line("{name} and {other} at {place}", npc)
	TEST_ASSERT(!findtext(filled, "{"), "A line kept a placeholder: [filled]")
	// A spontaneous line waits out their pause; a forced one does not, and starts it
	npc.next_line_at = world.time + 100
	TEST_ASSERT(!npc.speak_context("idle"), "A spontaneous line ignored their pause") // AMBIENT_LINE_IDLE
	TEST_ASSERT(npc.speak_context("talk", null, force = TRUE), "A forced line did not come")
	TEST_ASSERT(npc.next_line_at > world.time, "Speaking did not start their pause")

// =========================================================================
// PRESENCE AT A TRADER OUTPOST
// =========================================================================

/// Nobody arrives while the concourse is empty; the first arrivals step off the lift after 30 to 60 seconds, one at a time, up to the cap; three minutes after the last player everyone goes
/datum/unit_test/voidcrew_ambient_outpost_presence

/datum/unit_test/voidcrew_ambient_outpost_presence/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	TEST_ASSERT_NOTNULL(place, "A trader outpost got no place")
	TEST_ASSERT_EQUAL(SSambient_npcs.outpost_place(outpost), place, "A trader outpost got a second place")
	TEST_ASSERT_EQUAL(length(SSambient_npcs.outpost_players(outpost)), 0, "Someone with a client is on a test concourse")
	var/datum/ambient_outpost_role/core_test/role = allocate(/datum/ambient_outpost_role/core_test)
	role.npc_type = /mob/living/basic/ambient_npc/core_test
	var/list/roles = list(role)

	// Nobody there: nobody comes
	SSambient_npcs.update_outpost(place, 0, roles)
	TEST_ASSERT(!place.occupied, "An empty concourse counts as occupied")
	TEST_ASSERT_EQUAL(length(place.npcs), 0, "Someone arrived at an empty concourse")

	// A player arrives: nobody steps off the lift for 30 to 60 seconds
	SSambient_npcs.update_outpost(place, 1, roles)
	TEST_ASSERT(place.occupied, "A concourse with a player on it is not occupied")
	TEST_ASSERT(place.arrivals_at >= world.time + 300 && place.arrivals_at <= world.time + 600, "The first arrival is due in [(place.arrivals_at - world.time) / 10] seconds") // AMBIENT_OUTPOST_ARRIVAL_DELAY_LOW/HIGH
	TEST_ASSERT_EQUAL(length(place.npcs), 0, "Someone arrived the moment a player did")

	// Once it is time: one at a time, off the lift, and never onto a lift someone stands on
	place.arrivals_at = world.time
	var/list/arrived = list()
	for(var/i in 1 to 3)
		SSambient_npcs.update_outpost(place, 1, roles)
		TEST_ASSERT_EQUAL(length(place.npcs), i, "[length(place.npcs)] people have arrived after [i] ticks")
		var/mob/living/basic/ambient_npc/newcomer = place.npcs[i]
		TEST_ASSERT_EQUAL(get_turf(newcomer), run_loc_floor_top_right, "Someone arrived somewhere other than the lift")
		TEST_ASSERT_EQUAL(newcomer.place, place, "An arrival does not belong to the outpost")
		TEST_ASSERT_EQUAL(newcomer.role, role.type, "An arrival does not know their role")
		TEST_ASSERT(newcomer.leash_ok(run_loc_floor_bottom_left), "An arrival is leashed off the concourse")
		SSambient_npcs.update_outpost(place, 1, roles)
		TEST_ASSERT_EQUAL(length(place.npcs), i, "Someone stepped off the lift onto someone else")
		newcomer.forceMove(run_loc_floor_bottom_left)
		arrived += newcomer
	// The role is full
	SSambient_npcs.update_outpost(place, 1, roles)
	TEST_ASSERT_EQUAL(length(place.npcs), 3, "A role brought more than its count")

	// Never more than the outpost's cap, whatever the roles want
	role.max_count = 50
	for(var/i in 1 to 15)
		SSambient_npcs.update_outpost(place, 1, roles)
		for(var/mob/living/basic/ambient_npc/newcomer in run_loc_floor_top_right)
			newcomer.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(length(place.living_npcs()), 10, "A trader outpost has [length(place.living_npcs())] transient NPCs, not the cap of 10") // AMBIENT_OUTPOST_TRANSIENT_CAP

	// A fight near them: they duck and head off
	var/mob/living/basic/ambient_npc/witness = arrived[1]
	var/mob/living/carbon/human/brawler = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	SEND_SIGNAL(outpost, "trader_outpost_violence", brawler) // COMSIG_TRADER_OUTPOST_VIOLENCE
	TEST_ASSERT(istype(witness.activity, /datum/ambient_activity/leave), "A witness to a fight did not head for the lift")
	TEST_ASSERT(witness.crouching, "A witness to a fight did not duck")
	TEST_ASSERT_EQUAL(witness.activity.spot, run_loc_floor_top_right, "A witness is leaving somewhere other than the lift")

	// The players leave: everyone stays through the grace, then goes at once
	SSambient_npcs.update_outpost(place, 0, roles)
	TEST_ASSERT(place.occupied, "The concourse emptied the moment the players left")
	TEST_ASSERT(length(place.living_npcs()), "The crowd left the moment the players did")
	place.last_player_at = world.time - 1801 // AMBIENT_OUTPOST_GRACE
	var/list/everyone = place.npcs.Copy()
	SSambient_npcs.update_outpost(place, 0, roles)
	TEST_ASSERT(!place.occupied, "The concourse is still occupied three minutes after the last player")
	TEST_ASSERT_EQUAL(length(place.npcs), 0, "[length(place.npcs)] NPCs are still at an outpost nobody has visited for three minutes")
	for(var/mob/living/basic/ambient_npc/gone as anything in everyone)
		TEST_ASSERT(QDELETED(gone), "[gone] is still in the world after the concourse emptied")

	// The next player starts it all again
	SSambient_npcs.update_outpost(place, 1, roles)
	TEST_ASSERT(place.occupied && place.arrivals_at > world.time, "A returning player did not start the arrivals again")

// =========================================================================
// PLANET SITES
// =========================================================================

/// A planet rolls at most two sites and six NPCs; a site comes out whole within the budget; one despawned alive comes back; one killed does not, and once all are killed the site is spent; the planet's fauna budget pays for them and forgets them when it unloads
/datum/unit_test/voidcrew_ambient_planet_sites

/datum/unit_test/voidcrew_ambient_planet_sites/Run()
	var/datum/ambient_site_kind/core_test/kind = allocate(/datum/ambient_site_kind/core_test)
	kind.npc_type = /mob/living/basic/ambient_npc/core_test/killable
	kind.planet_types = list(/datum/overmap/planet/jungle)
	kind.chance = 100
	var/datum/ambient_planet/record = allocate(/datum/ambient_planet)
	record.key = "ambient core test planet"
	record.planet_type = /datum/overmap/planet/jungle
	record.band = 1 // ZONE_GREEN
	record.bounds = ambient_test_room_bounds()

	// Its chance is for its own planet types and bands only
	var/datum/ambient_planet/elsewhere = allocate(/datum/ambient_planet)
	elsewhere.planet_type = /datum/overmap/planet/lava
	elsewhere.band = 1 // ZONE_GREEN
	TEST_ASSERT_EQUAL(kind.chance_on(elsewhere), 0, "A site kind rolls on a planet type it does not list")
	TEST_ASSERT_EQUAL(kind.chance_on(record), 100, "A site kind does not roll on its own planet type")

	// Rolling: at most two sites, however many kinds come up
	SSambient_npcs.roll_planet_sites(record, list(kind, kind, kind, kind))
	TEST_ASSERT(record.rolled, "A rolled planet does not know it was rolled")
	TEST_ASSERT_EQUAL(length(record.sites), 2, "A planet rolled [length(record.sites)] sites, not the cap of 2") // AMBIENT_PLANET_SITES_MAX
	QDEL_LIST(record.sites)

	// ...and at most six NPCs: a second four-NPC site does not fit
	kind.min_npcs = 4
	kind.max_npcs = 4
	record.rolled = FALSE
	SSambient_npcs.roll_planet_sites(record, list(kind, kind))
	TEST_ASSERT_EQUAL(length(record.sites), 1, "A planet rolled sites for more than six NPCs") // AMBIENT_PLANET_NPCS_MAX
	QDEL_LIST(record.sites)
	kind.min_npcs = 2
	kind.max_npcs = 2

	// One two-NPC site
	var/datum/ambient_place/site/site = new(kind, run_loc_floor_bottom_left, record)
	site.npc_total = 2
	record.sites += site
	TEST_ASSERT_EQUAL(site.state, "dormant", "A new site is not dormant") // AMBIENT_SITE_DORMANT

	// It comes out whole or not at all
	TEST_ASSERT_EQUAL(SSambient_npcs.realize_planet(record, 1), 0, "Half a site came out on a budget of one")
	TEST_ASSERT_EQUAL(SSambient_npcs.realize_planet(record, 6), 2, "A two-NPC site did not come out")
	TEST_ASSERT_EQUAL(site.state, "active", "A site with its NPCs out is not active") // AMBIENT_SITE_ACTIVE
	TEST_ASSERT_EQUAL(SSambient_npcs.realize_planet(record, 6), 0, "A site came out twice")
	for(var/mob/living/basic/ambient_npc/npc as anything in site.living_npcs())
		TEST_ASSERT_EQUAL(npc.place, site, "A site's NPC does not belong to it")
		TEST_ASSERT(!HAS_TRAIT(npc, TRAIT_GODMODE), "A planet NPC is in godmode")

	// Despawned alive (the planet sweep): they come back on the next visit
	var/list/npcs = site.living_npcs()
	qdel(npcs[1])
	TEST_ASSERT_EQUAL(site.npcs_missing(), 1, "A despawned NPC is not missed")
	TEST_ASSERT_EQUAL(SSambient_npcs.realize_planet(record, 6), 1, "A despawned NPC did not come back")

	// Killed: that one never comes back, the other still does
	npcs = site.living_npcs()
	var/mob/living/basic/ambient_npc/first_victim = npcs[1]
	first_victim.death()
	TEST_ASSERT_EQUAL(site.dead, 1, "A killed NPC was not counted")
	TEST_ASSERT(site.state != "spent", "A site was spent with one of its two NPCs still alive") // AMBIENT_SITE_SPENT
	for(var/mob/living/basic/ambient_npc/npc as anything in site.npcs.Copy())
		qdel(npc)
	TEST_ASSERT_EQUAL(SSambient_npcs.realize_planet(record, 6), 1, "A site came back with [length(site.living_npcs())] NPCs after losing one of two")

	// Both killed: spent for the round, however often the crew leaves and lands again
	npcs = site.living_npcs()
	var/mob/living/basic/ambient_npc/second_victim = npcs[1]
	second_victim.death()
	TEST_ASSERT_EQUAL(site.state, "spent", "A site whose NPCs were all killed is not spent") // AMBIENT_SITE_SPENT
	for(var/mob/living/basic/ambient_npc/npc as anything in site.npcs.Copy())
		qdel(npc)
	for(var/visit in 1 to 3)
		TEST_ASSERT_EQUAL(SSambient_npcs.realize_planet(record, 6), 0, "A spent site came back on visit [visit]")
	TEST_ASSERT_EQUAL(site.npcs_missing(), 0, "A spent site misses NPCs")

	// Through SSplanet_mobs: the planet's people are charged to its fauna budget, and forgotten when it unloads
	var/datum/planet_mob_tracker/tracker = SSplanet_mobs.register_planet("ambient core test tracker", run_loc_floor_bottom_left.z, null, 1) // ZONE_GREEN
	var/datum/ambient_planet/hooked = new
	hooked.key = tracker.name
	hooked.planet_type = /datum/overmap/planet/jungle
	hooked.band = 1 // ZONE_GREEN
	hooked.bounds = ambient_test_room_bounds()
	hooked.rolled = TRUE
	var/datum/ambient_place/site/hooked_site = new(kind, run_loc_floor_top_right, hooked)
	hooked_site.npc_total = 2
	hooked.sites += hooked_site
	SSambient_npcs.planets[tracker.name] = hooked
	var/total_before = SSplanet_mobs.total_managed_mobs
	SSplanet_mobs.spawn_planet_mobs(tracker)
	TEST_ASSERT_EQUAL(tracker.spawned_count, 2, "The planet's budget was charged [tracker.spawned_count] for two NPCs")
	TEST_ASSERT_EQUAL(SSplanet_mobs.total_managed_mobs, total_before + 2, "The galaxy's budget was not charged for a planet's NPCs")
	TEST_ASSERT_EQUAL(length(hooked_site.living_npcs()), 2, "The planet's site did not come out with its fauna")
	SSplanet_mobs.unregister_planet(tracker.name)
	TEST_ASSERT(!(tracker.name in SSambient_npcs.planets), "An unloaded planet's sites were not forgotten")
	TEST_ASSERT(QDELETED(hooked), "An unloaded planet's record was not deleted")
	TEST_ASSERT_EQUAL(SSplanet_mobs.total_managed_mobs, total_before, "An unloaded planet kept its NPCs' budget")

// =========================================================================
// THE ROUTINE RUNNER
// =========================================================================

/// The planner picks from the routine and walks to it; the activity runs where it happens and puts everything back; reactions outrank routines and nothing outranks leaving; chat, drink and work run
/datum/unit_test/voidcrew_ambient_activities

/datum/unit_test/voidcrew_ambient_activities/Run()
	var/turf/corner = run_loc_floor_bottom_left
	var/turf/chair_turf = run_loc_floor_top_right

	// The planner: a routine of sitting, a chair across the room
	var/obj/structure/chair/chair = allocate(/obj/structure/chair, chair_turf)
	var/mob/living/basic/ambient_npc/core_test/sitter/sitter = allocate(/mob/living/basic/ambient_npc/core_test/sitter, corner)
	var/datum/ai_controller/controller = sitter.ai_controller
	TEST_ASSERT(istype(controller, /datum/ai_controller/basic_controller/ambient_npc), "An ambient NPC has no ambient AI")
	controller.set_ai_status(AI_STATUS_ON)
	controller.SelectBehaviors(1)
	TEST_ASSERT(istype(sitter.activity, /datum/ambient_activity/sit), "The planner did not start the routine's activity")
	TEST_ASSERT_EQUAL(controller.blackboard["ambient_destination"], chair_turf, "The planner is not walking to the chair") // BB_AMBIENT_DESTINATION
	// The walk, then the next plan runs the activity where it happens
	sitter.forceMove(chair_turf)
	controller.SelectBehaviors(1)
	var/datum/ai_behavior/ambient_activity/runner = GET_AI_BEHAVIOR(/datum/ai_behavior/ambient_activity)
	TEST_ASSERT(controller.planned_behaviors[runner], "The planner did not run the activity at the chair")
	runner.perform(1, controller)
	TEST_ASSERT_EQUAL(sitter.buckled, chair, "The runner did not sit them down")
	controller.set_ai_status(AI_STATUS_OFF)
	sitter.end_activity()
	TEST_ASSERT_NULL(sitter.buckled, "Ending the activity did not stand them up")
	TEST_ASSERT_NULL(sitter.activity, "An ended activity is still running")

	// Priorities: a reaction replaces a routine, and nothing replaces leaving
	var/mob/living/basic/ambient_npc/core_test/npc = allocate(/mob/living/basic/ambient_npc/core_test, corner)
	TEST_ASSERT_NOTNULL(npc.start_activity(new /datum/ambient_activity/idle(npc)), "Standing about could not start")
	TEST_ASSERT_NOTNULL(npc.start_activity(new /datum/ambient_activity/shelter(npc, null, 100)), "Sheltering did not replace standing about")
	TEST_ASSERT_NULL(npc.start_activity(new /datum/ambient_activity/idle(npc)), "Standing about replaced sheltering")
	TEST_ASSERT_NOTNULL(npc.start_activity(new /datum/ambient_activity/leave(npc, chair_turf)), "Leaving did not replace sheltering")
	TEST_ASSERT_NULL(npc.start_activity(new /datum/ambient_activity/shelter(npc, null, 100)), "Sheltering replaced leaving")
	// Leaving: at the exit they fade out, and nothing starts after
	npc.forceMove(chair_turf)
	npc.activity_step(1)
	TEST_ASSERT(npc.fading, "Someone at the exit did not leave")
	TEST_ASSERT_NULL(npc.start_activity(new /datum/ambient_activity/idle(npc)), "Someone fading out started something new")

	// Drinking: a real glass in hand, sipped, set down on the table at the end
	var/obj/structure/table/table = allocate(/obj/structure/table, locate(corner.x + 2, corner.y, corner.z))
	var/mob/living/basic/ambient_npc/core_test/drinker = allocate(/mob/living/basic/ambient_npc/core_test, corner)
	var/datum/ambient_activity/drink/drink = drinker.start_activity(new /datum/ambient_activity/drink(drinker, table))
	TEST_ASSERT_NOTNULL(drink, "A drink at a table could not start")
	drinker.forceMove(drink.spot)
	TEST_ASSERT_EQUAL(drinker.activity_step(1), 0, "Drinking stopped at once") // AMBIENT_STEP_CONTINUE
	var/obj/item/glass = drinker.held_item
	TEST_ASSERT(istype(glass, /obj/item/reagent_containers/cup/glass/drinkingglass), "A drinker has no glass")
	TEST_ASSERT(drinker.sip(), "A drinker could not sip")
	drinker.end_activity()
	TEST_ASSERT_NULL(drinker.held_item, "A drinker kept their glass after drinking")
	TEST_ASSERT_EQUAL(glass.loc, table.loc, "A finished glass was not set down on the table")

	// Chat: the partner drops what it was doing and answers until the starter is done
	var/mob/living/basic/ambient_npc/core_test/talker = allocate(/mob/living/basic/ambient_npc/core_test, corner)
	var/mob/living/basic/ambient_npc/core_test/listener = allocate(/mob/living/basic/ambient_npc/core_test, locate(corner.x, corner.y + 1, corner.z))
	listener.start_activity(new /datum/ambient_activity/idle(listener))
	var/datum/ambient_activity/chat/chat = talker.start_activity(new /datum/ambient_activity/chat(talker, listener))
	TEST_ASSERT_NOTNULL(chat, "A chat with someone right there could not start")
	var/datum/ambient_activity/chat/answer = listener.activity
	TEST_ASSERT(istype(answer) && answer.responding, "The partner did not stop to answer")
	TEST_ASSERT(chat.at_spot(), "The talker wants to walk to someone right beside them")
	TEST_ASSERT_EQUAL(talker.activity_step(1), 0, "The chat ended at once") // AMBIENT_STEP_CONTINUE
	TEST_ASSERT_EQUAL(listener.activity_step(1), 0, "The answer ended at once") // AMBIENT_STEP_CONTINUE
	talker.end_activity()
	TEST_ASSERT_EQUAL(listener.activity_step(1), 2, "The partner kept answering after the talker left") // AMBIENT_STEP_DONE

	// Work at an object: the mechanics' work loop, on them for the job and off them after
	allocate(/obj/structure/rack, locate(corner.x + 2, corner.y + 3, corner.z))
	var/mob/living/basic/ambient_npc/core_test/worker = allocate(/mob/living/basic/ambient_npc/core_test, locate(corner.x + 1, corner.y + 3, corner.z))
	worker.work_weights = list(/datum/outpost_ambient_work/wrench = 1)
	var/datum/ambient_activity/work/work = worker.start_activity(new /datum/ambient_activity/work(worker))
	TEST_ASSERT_NOTNULL(work, "Work at a rack could not start")
	TEST_ASSERT_NOTNULL(worker.GetComponent(/datum/component/outpost_ambient_worker), "Working did not use the work loop")
	worker.forceMove(work.spot)
	TEST_ASSERT_EQUAL(worker.activity_step(1), 0, "Work stopped at once") // AMBIENT_STEP_CONTINUE
	TEST_ASSERT_NOTNULL(work.worker?.work, "No job was started at the rack")
	worker.end_activity()
	TEST_ASSERT_NULL(worker.GetComponent(/datum/component/outpost_ambient_worker), "The work loop stayed on after the job")
