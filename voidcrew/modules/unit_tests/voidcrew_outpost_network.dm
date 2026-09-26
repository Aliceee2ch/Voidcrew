/**
 * The outpost teleporter network (outpost_network.dm, outpost_teleporter.dm). Two claims with
 * Teleporter rooms; trips are driven by calling start_trip() and finish_trip() directly.
 * Voidcrew defines are not visible here: prices, policies and ids are literals.
 */

/// Two claims with a Teleporter room each, and their pads, into `out`. Null, or an error.
/datum/unit_test/voidcrew_outpost_management/proc/network_test_pair(list/out)
	var/obj/structure/overmap/dynamic/player_outpost/home_a = market_test_claim("netownera")
	var/obj/structure/overmap/dynamic/player_outpost/home_b = market_test_claim("netownerb")
	if(!home_a || !home_b)
		return "A network test outpost did not load."
	var/datum/outpost_upgrade/service/teleporter/room_a = place_test_service_room(home_a, /datum/outpost_upgrade/service/teleporter)
	if(!istype(room_a))
		return "The first teleporter room was not placed: [room_a]"
	var/datum/outpost_upgrade/service/teleporter/room_b = place_test_service_room(home_b, /datum/outpost_upgrade/service/teleporter)
	if(!istype(room_b))
		return "The second teleporter room was not placed: [room_b]"
	out["home_a"] = home_a
	out["home_b"] = home_b
	out["room_a"] = room_a
	out["room_b"] = room_b
	// A breathable corridor outside each door, or the rooms report their exit to vacuum
	for(var/datum/outpost_upgrade/service/teleporter/room as anything in list(room_a, room_b))
		for(var/turf/exit as anything in room.exit_turfs())
			if(!isclosedturf(exit))
				exit.ChangeTurf(/turf/open/floor/iron)
	out["pad_a"] = room_a.pad_ref?.resolve()
	out["pad_b"] = room_b.pad_ref?.resolve()
	if(!out["pad_a"] || !out["pad_b"])
		return "A teleporter room has no pad."
	return null

/datum/unit_test/voidcrew_outpost_management/proc/network_test_cleanup(list/rig)
	GLOB.outpost_network_ready_at.Cut()
	for(var/key in list("room_a", "room_b"))
		var/datum/outpost_upgrade/service/teleporter/room = rig[key]
		if(room)
			settle_room_air(room.room_turfs())

// ===== REGISTRY, TRIP AND FARE =====

/datum/unit_test/voidcrew_outpost_network_trip
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_network_trip/Run()
	var/list/rig = list()
	var/error = network_test_pair(rig)
	TEST_ASSERT_NULL(error, error)
	var/obj/structure/overmap/dynamic/player_outpost/home_b = rig["home_b"]
	var/datum/outpost_upgrade/service/teleporter/room_b = rig["room_b"]
	var/obj/machinery/outpost_network_pad/pad_a = rig["pad_a"]
	var/obj/machinery/outpost_network_pad/pad_b = rig["pad_b"]
	TEST_ASSERT_EQUAL(pad_a.network_host(), rig["home_a"], "The first pad is not on the network")
	TEST_ASSERT_EQUAL(pad_b.network_host(), home_b, "The second pad is not on the network")
	TEST_ASSERT(pad_b.arrival_turf && room_b.is_inside(pad_b.arrival_turf), "The arrival spot is not inside the room")
	TEST_ASSERT(pad_b.arrival_turf != get_turf(pad_b), "Arrivals land on the departure pad")
	TEST_ASSERT_EQUAL(room_b.arrival_policy, "open", "Arrivals do not default to open")
	TEST_ASSERT(!istype(pad_a, /obj/machinery/quantumpad), "The network pad is a quantum pad")

	// A pad outside a Teleporter room is never on the network
	var/obj/machinery/outpost_network_pad/stray = allocate(/obj/machinery/outpost_network_pad, get_step(pad_a, NORTH))
	TEST_ASSERT(stray in GLOB.outpost_network_pads, "A new pad did not register")
	TEST_ASSERT_NULL(stray.network_host(), "A stray pad joined the network")

	var/mob/living/carbon/human/visitor = make_market_visitor(get_turf(pad_a), "netvisitor", 1000)
	var/datum/bank_account/account = visitor.get_idcard(TRUE)?.registered_account
	var/obj/item/toy/plush/carried = allocate(/obj/item/toy/plush)
	visitor.put_in_hands(carried)
	var/list/data = pad_a.ui_data(visitor)
	var/list/row
	for(var/list/entry as anything in data["destinations"])
		if(entry["id"] == pad_b.network_id)
			row = entry
		TEST_ASSERT(entry["id"] != stray.network_id, "A stray pad was listed as a destination")
	TEST_ASSERT_NOTNULL(row, "The second outpost was not listed")
	TEST_ASSERT_EQUAL(row["fee"], 200, "The default arrival fare is not 200 cr")
	TEST_ASSERT(row["available"], "The second outpost was not available: [row["reason"]]")

	// A wrong fare is refused, then a real trip moves the traveller and what they carry
	TEST_ASSERT_EQUAL(pad_a.start_trip(visitor, pad_b, 0), "Price changed to 200 cr.", "A trip started at the wrong fare")
	var/treasury_before = home_b.treasury.account_balance
	TEST_ASSERT_NULL(pad_a.start_trip(visitor, pad_b, 200), "The trip did not start")
	TEST_ASSERT(pad_a.is_charging() && pad_b.is_receiving(), "The pads did not claim the trip")
	var/mob/living/carbon/human/second = make_market_visitor(get_step(pad_a, SOUTH), null, 0)
	TEST_ASSERT_EQUAL(pad_b.arrival_denial(second, pad_a), "Busy", "A second trip could aim at a busy pad")
	TEST_ASSERT_NULL(pad_a.finish_trip(), "The trip did not finish")
	TEST_ASSERT_EQUAL(get_turf(visitor), pad_b.arrival_turf, "The traveller did not arrive on the arrival spot")
	TEST_ASSERT_EQUAL(get_turf(carried), pad_b.arrival_turf, "What the traveller carried did not travel")
	TEST_ASSERT_EQUAL(account.account_balance, 800, "The fare was not taken exactly once")
	TEST_ASSERT_EQUAL(home_b.treasury.account_balance, treasury_before + 200, "The fare did not reach the destination's treasury")
	TEST_ASSERT_EQUAL(room_b.trips_in, 1, "The arrival was not counted")
	TEST_ASSERT(!pad_a.is_charging() && !pad_b.is_receiving(), "The pads kept their claim after the trip")

	// Two minutes before the next trip
	visitor.forceMove(get_turf(pad_b))
	TEST_ASSERT(findtext(pad_b.departure_denial(visitor), "Recharging"), "The traveller could leave again at once")
	GLOB.outpost_network_ready_at.Cut()

	// Members travel free
	var/mob/living/carbon/human/owner_b = make_market_visitor(get_turf(pad_a), "netownerb", 0)
	TEST_ASSERT_EQUAL(pad_b.arrival_fee(owner_b), 0, "A member was charged a fare home")
	TEST_ASSERT_NULL(pad_a.start_trip(owner_b, pad_b, 0), "A member could not start a free trip")
	TEST_ASSERT_NULL(pad_a.finish_trip(), "A member's free trip did not finish")
	TEST_ASSERT_EQUAL(get_turf(owner_b), pad_b.arrival_turf, "The member did not arrive")
	network_test_cleanup(rig)

// ===== CANCELLING AND REFUSALS =====

/datum/unit_test/voidcrew_outpost_network_refusals
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_network_refusals/Run()
	var/list/rig = list()
	var/error = network_test_pair(rig)
	TEST_ASSERT_NULL(error, error)
	var/obj/structure/overmap/dynamic/player_outpost/home_b = rig["home_b"]
	var/obj/machinery/outpost_network_pad/pad_a = rig["pad_a"]
	var/obj/machinery/outpost_network_pad/pad_b = rig["pad_b"]
	var/turf/pad_turf = get_turf(pad_a)
	var/turf/beside = pad_a.pad_step_off_turf()
	TEST_ASSERT_NOTNULL(beside, "No free tile beside the pad")
	var/mob/living/carbon/human/visitor = make_market_visitor(pad_turf, "netrefused", 1000)
	var/datum/bank_account/account = visitor.get_idcard(TRUE)?.registered_account
	var/treasury_before = home_b.treasury.account_balance

	// Damage, stepping off and passing out each cancel with nothing charged
	TEST_ASSERT_NULL(pad_a.start_trip(visitor, pad_b, 200), "The trip did not start")
	visitor.apply_damage(10, BRUTE)
	TEST_ASSERT(!pad_a.is_charging(), "Damage did not cancel the charge")
	TEST_ASSERT_EQUAL(visitor.alpha, 255, "The traveller was left faded after a cancel")
	visitor.fully_heal()
	TEST_ASSERT_NULL(pad_a.start_trip(visitor, pad_b, 200), "The trip did not restart after damage")
	visitor.forceMove(beside)
	TEST_ASSERT(!pad_a.is_charging(), "Leaving the pad did not cancel the charge")
	visitor.forceMove(pad_turf)
	TEST_ASSERT_NULL(pad_a.start_trip(visitor, pad_b, 200), "The trip did not restart after stepping off")
	visitor.set_stat(UNCONSCIOUS)
	TEST_ASSERT(!pad_a.is_charging(), "Passing out did not cancel the charge")
	visitor.set_stat(CONSCIOUS)
	TEST_ASSERT_EQUAL(account.account_balance, 1000, "A cancelled trip charged the traveller")
	TEST_ASSERT_EQUAL(home_b.treasury.account_balance, treasury_before, "A cancelled trip paid the destination")

	// A fare raised during the charge refuses the trip
	TEST_ASSERT_NULL(pad_a.start_trip(visitor, pad_b, 200), "The trip did not restart after passing out")
	home_b.outpost_prices["teleport_arrival"] = 300
	TEST_ASSERT_EQUAL(pad_a.finish_trip(), "Price changed to 300 cr.", "A raised fare was charged without consent")
	TEST_ASSERT_EQUAL(get_turf(visitor), pad_turf, "The traveller moved on a refused trip")
	TEST_ASSERT_EQUAL(account.account_balance, 1000, "A refused trip charged the traveller")
	home_b.outpost_prices -= "teleport_arrival"

	// A combat stamp during the charge refuses completion (F-41)
	var/mob/living/carbon/human/attacker = make_market_visitor(beside, "netattacker", 0)
	TEST_ASSERT_NULL(pad_a.start_trip(visitor, pad_b, 200), "The trip did not restart before the fight")
	stamp_outpost_network_combat(visitor, attacker)
	TEST_ASSERT_EQUAL(pad_a.finish_trip(), "You were just in a fight.", "A fight during the charge did not stop the trip")
	visitor.mind.outpost_network_combat_until = 0
	attacker.mind.outpost_network_combat_until = 0

	// Shoves never stamp the combat lock; punches do (F-35)
	attacker.set_combat_mode(TRUE)
	GLOB.outpost_pvp_enforcement.on_outpost_pvp_unarmed_attack(visitor, attacker, list(RIGHT_CLICK = "1"))
	TEST_ASSERT_EQUAL(visitor.mind.outpost_network_combat_until, 0, "A shove locked the traveller out of the network")
	GLOB.outpost_pvp_enforcement.on_outpost_pvp_unarmed_attack(visitor, attacker, list())
	TEST_ASSERT(visitor.mind.outpost_network_combat_until > world.time, "A punch did not lock the traveller out of the network")
	visitor.mind.outpost_network_combat_until = 0

	// What cannot travel
	TEST_ASSERT_EQUAL(pad_a.departure_denial(attacker), "Stand on the pad.", "Someone off the pad could leave")
	var/obj/structure/closet/crate/crate = allocate(/obj/structure/closet/crate, beside)
	visitor.start_pulling(crate)
	TEST_ASSERT_EQUAL(pad_a.departure_denial(visitor), "Let go first.", "A traveller could pull a crate along")
	visitor.stop_pulling()
	var/obj/item/storage/box/box = allocate(/obj/item/storage/box)
	visitor.put_in_hands(box)
	var/mob/living/basic/mouse/mouse = allocate(/mob/living/basic/mouse, box)
	TEST_ASSERT(findtext(pad_a.departure_denial(visitor), "You are carrying"), "A mob in a box travelled")
	qdel(mouse)
	var/obj/item/ship_key/key = allocate(/obj/item/ship_key, box)
	TEST_ASSERT(findtext(pad_a.departure_denial(visitor), "The pad refuses"), "A ship key travelled")
	qdel(key)
	var/obj/item/mission_recovery/cargo = allocate(/obj/item/mission_recovery, box)
	TEST_ASSERT(findtext(pad_a.departure_denial(visitor), "The pad refuses"), "Contract cargo travelled")
	qdel(cargo)
	ADD_TRAIT(visitor, TRAIT_RESTRAINED, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_EQUAL(pad_a.departure_denial(visitor), "Restrained.", "A restrained traveller could leave")
	REMOVE_TRAIT(visitor, TRAIT_RESTRAINED, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(visitor, TRAIT_NO_TELEPORT, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_EQUAL(pad_a.departure_denial(visitor), "Something holds you in place.", "TRAIT_NO_TELEPORT was ignored")
	REMOVE_TRAIT(visitor, TRAIT_NO_TELEPORT, TRAIT_SOURCE_UNIT_TESTS)
	var/obj/structure/chair/chair = allocate(/obj/structure/chair, pad_turf)
	chair.buckle_mob(visitor, force = TRUE)
	TEST_ASSERT_EQUAL(pad_a.departure_denial(visitor), "Get up first.", "A buckled traveller could leave")
	chair.unbuckle_mob(visitor, force = TRUE)
	qdel(chair)
	var/leftover = pad_a.departure_denial(visitor)
	TEST_ASSERT_NULL(leftover, "The cleared traveller still could not leave: [leftover]")

	// A clientless body on the pad is stepped off for someone waiting (F-37). The traveller above
	// has no client either, so take them off first: the sleeper must be the only body on the pad.
	visitor.forceMove(beside)
	var/mob/living/carbon/human/sleeper = make_market_visitor(pad_turf, null, 0)
	var/list/on_pad = list()
	for(var/mob/living/occupant in pad_turf)
		on_pad += occupant
	TEST_ASSERT_EQUAL(length(on_pad), 1, "Someone besides the idle body is on the pad")
	var/turf/aside = pad_a.pad_step_off_turf()
	TEST_ASSERT_NOTNULL(aside, "No free tile to step the idle body onto")
	TEST_ASSERT_EQUAL(pad_a.clear_idle_occupant(attacker), sleeper, "An idle body was not cleared off the pad")
	TEST_ASSERT_EQUAL(get_turf(sleeper), aside, "The idle body was not stepped off beside the pad")
	network_test_cleanup(rig)

// ===== WHO MAY ARRIVE =====

/datum/unit_test/voidcrew_outpost_network_policies
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_network_policies/Run()
	var/list/rig = list()
	var/error = network_test_pair(rig)
	TEST_ASSERT_NULL(error, error)
	var/obj/structure/overmap/dynamic/player_outpost/home_b = rig["home_b"]
	var/datum/outpost_upgrade/service/teleporter/room_b = rig["room_b"]
	var/obj/machinery/outpost_network_pad/pad_a = rig["pad_a"]
	var/obj/machinery/outpost_network_pad/pad_b = rig["pad_b"]
	var/mob/living/carbon/human/visitor = make_market_visitor(get_turf(pad_a), "netpolicy", 1000)
	var/mob/living/carbon/human/owner_b = make_market_visitor(get_step(pad_a, SOUTH), "netownerb", 0)

	room_b.arrival_policy = "members"
	TEST_ASSERT_EQUAL(pad_b.arrival_denial(visitor, pad_a), "Members only", "A visitor passed a members-only pad")
	TEST_ASSERT_NULL(pad_b.arrival_denial(owner_b, pad_a), "A member was refused at home")
	room_b.arrival_policy = "allowlist"
	TEST_ASSERT_EQUAL(pad_b.arrival_denial(visitor, pad_a), "Not on the list", "An unlisted source passed the allow list")
	room_b.allowed_pads += pad_a.network_id
	TEST_ASSERT_NULL(pad_b.arrival_denial(visitor, pad_a), "A listed source was refused")
	room_b.arrival_policy = "closed"
	TEST_ASSERT_EQUAL(pad_b.arrival_denial(visitor, pad_a), "Closed", "A closed pad admitted a visitor")
	room_b.arrival_policy = "open"
	TEST_ASSERT_NULL(pad_b.arrival_denial(visitor, pad_a), "An open pad refused a visitor")

	// Docking modes apply to pad arrivals (R8, R9)
	home_b.dock_mode = "request"
	TEST_ASSERT_EQUAL(pad_b.arrival_denial(visitor, pad_a), "Approved crews only", "REQUEST mode left the pad open")
	home_b.dock_mode = "lockdown"
	TEST_ASSERT_EQUAL(pad_b.arrival_denial(visitor, pad_a), "Lockdown", "Lockdown admitted a visitor")
	TEST_ASSERT_NULL(pad_b.arrival_denial(owner_b, pad_a), "Lockdown refused a member")
	home_b.dock_mode = "open"

	// The raid lock closes arrivals to non-members, but neutral visitors may still leave (F-34)
	home_b.note_network_siege(null)
	TEST_ASSERT(home_b.outpost_raid_locked(), "A hostile impact did not start the raid lock")
	TEST_ASSERT_EQUAL(pad_b.arrival_denial(visitor, pad_a), "Under attack", "A visitor arrived during a raid")
	visitor.forceMove(get_turf(pad_b))
	var/raid_departure = pad_b.departure_denial(visitor)
	TEST_ASSERT_NULL(raid_departure, "A neutral visitor could not leave a raided outpost: [raid_departure]")
	visitor.forceMove(get_turf(pad_a))
	home_b.last_siege_time = null

	// The room door stays open to visitors; the arrival policy is the owner's lever (F-33)
	TEST_ASSERT_EQUAL(room_b.set_visitors_allowed(owner_b, FALSE), "Use the arrival policy.", "The teleporter room could be closed to visitors")
	TEST_ASSERT(room_b.visitors_allowed, "The teleporter room was closed to visitors")

	// A room that opens onto vacuum takes no arrivals (F-03)
	var/list/exits = room_b.exit_turfs()
	TEST_ASSERT(length(exits), "The teleporter room has no exit")
	var/turf/exit = exits[1]
	exit = exit.ChangeTurf(/turf/open/space/basic)
	TEST_ASSERT_EQUAL(pad_b.arrival_denial(visitor, pad_a), "Exit to vacuum", "A room opening onto vacuum took arrivals")
	exit.ChangeTurf(/turf/open/floor/iron)

	// A blocked arrival spot refuses arrivals
	var/obj/structure/closet/blocker = allocate(/obj/structure/closet, pad_b.arrival_turf)
	blocker.set_anchored(TRUE)
	TEST_ASSERT_EQUAL(pad_b.arrival_denial(visitor, pad_a), "Arrival blocked", "A walled-in arrival spot took arrivals")
	qdel(blocker)

	// Abandonment: arrivals close while unowned; the settings go back to defaults
	room_b.arrival_policy = "members"
	room_b.on_outpost_abandoned()
	TEST_ASSERT_EQUAL(room_b.arrival_policy, "open", "Abandonment did not reset the arrival policy")
	TEST_ASSERT(!length(room_b.allowed_pads), "Abandonment kept the allow list")
	home_b.founder_ckey = null
	TEST_ASSERT_EQUAL(pad_b.arrival_denial(visitor, pad_a), "Closed", "An unowned outpost took arrivals")
	home_b.founder_ckey = "netownerb"

	// Management actions need management access
	room_b.service_ui_act(visitor, "set_teleporter_arrivals", list("mode" = "closed"))
	TEST_ASSERT_EQUAL(room_b.arrival_policy, "open", "A visitor changed the arrival policy")
	room_b.service_ui_act(owner_b, "set_teleporter_arrivals", list("mode" = "closed"))
	TEST_ASSERT_EQUAL(room_b.arrival_policy, "closed", "The owner could not change the arrival policy")
	room_b.service_ui_act(owner_b, "teleporter_allow", list("target" = pad_a.network_id))
	TEST_ASSERT(pad_a.network_id in room_b.allowed_pads, "The owner could not allow a source pad")
	var/list/detail = room_b.service_ui_data(owner_b)
	for(var/key in list("kind", "installed", "padName", "arrivals", "allowlist", "candidates", "can_edit", "tripsIn", "tripsOut"))
		TEST_ASSERT(key in detail, "The management card is missing [key]")
	TEST_ASSERT(!("visitors_allowed" in detail), "The management card sends visitors_allowed")
	room_b.service_ui_act(owner_b, "teleporter_disallow", list("target" = pad_a.network_id))
	TEST_ASSERT(!(pad_a.network_id in room_b.allowed_pads), "The owner could not remove a source pad")
	network_test_cleanup(rig)

// ===== LIFECYCLE AND THE ZONE SEAM =====

/datum/unit_test/voidcrew_outpost_network_lifecycle
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_network_lifecycle/Run()
	var/list/rig = list()
	var/error = network_test_pair(rig)
	TEST_ASSERT_NULL(error, error)
	var/datum/outpost_upgrade/service/teleporter/room_b = rig["room_b"]
	var/obj/machinery/outpost_network_pad/pad_a = rig["pad_a"]
	var/obj/machinery/outpost_network_pad/pad_b = rig["pad_b"]
	var/mob/living/carbon/human/visitor = make_market_visitor(get_turf(pad_a), "netlife", 1000)
	var/datum/bank_account/account = visitor.get_idcard(TRUE)?.registered_account

	// Only the pad committing this traveller onto this arrival spot may cross zones
	TEST_ASSERT(!outpost_network_may_cross(visitor, pad_b.arrival_turf, "outpost_network"), "A traveller could cross with no trip")
	pad_a.committing_ref = WEAKREF(visitor)
	pad_a.committing_turf = pad_b.arrival_turf
	TEST_ASSERT(outpost_network_may_cross(visitor, pad_b.arrival_turf, "outpost_network"), "The committing trip could not cross")
	TEST_ASSERT(!outpost_network_may_cross(visitor, pad_b.arrival_turf, "quantum"), "Another channel could cross")
	TEST_ASSERT(!outpost_network_may_cross(visitor, get_turf(pad_b), "outpost_network"), "A trip could cross onto another tile")
	pad_a.committing_ref = null
	pad_a.committing_turf = null

	// A destination deleted mid-charge aborts with nothing charged
	TEST_ASSERT_NULL(pad_a.start_trip(visitor, pad_b, 200), "The trip did not start")
	qdel(pad_b)
	TEST_ASSERT(!(pad_b in GLOB.outpost_network_pads), "A deleted pad stayed registered")
	TEST_ASSERT(!pad_a.is_charging(), "A charge toward a deleted pad kept running")
	TEST_ASSERT_EQUAL(account.account_balance, 1000, "A trip to a deleted pad charged the traveller")
	TEST_ASSERT_NULL(room_b.pad_ref?.resolve(), "The room kept a deleted pad")

	// Trading outposts get a public pad at load, if the test world has any
	var/checked = 0
	for(var/obj/structure/overmap/trader_outpost/market as anything in GLOB.trader_outposts)
		if(!market.loaded)
			continue
		var/obj/machinery/outpost_network_pad/trader/public_pad = market.network_pad_ref?.resolve()
		TEST_ASSERT(istype(public_pad), "[market.name] has no network pad")
		TEST_ASSERT(istype(get_area(public_pad), /area/voidcrew/trader_outpost), "[market.name]'s pad is outside its concourse")
		TEST_ASSERT(!(get_turf(public_pad) in market.lobby_alcove_turfs), "[market.name]'s pad is in the elevator alcove")
		TEST_ASSERT_NULL(public_pad.arrival_tile_denial(), "[market.name]'s arrival spot is blocked")
		TEST_ASSERT_EQUAL(public_pad.arrival_denial(visitor, public_pad), "No route", "A trader pad routes to itself")
		checked++
	if(!checked)
		log_test("No trading outpost is loaded in this test world; trader pads were not checked.")
	network_test_cleanup(rig)
