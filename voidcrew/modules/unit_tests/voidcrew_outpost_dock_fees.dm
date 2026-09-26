// MARKET-OWNER: P2
/**
 * Ship bay docking fee and bay eviction (outpost_dock_fees.dm).
 *
 * Fork defines are included after the tests, so keys, variants, states and signals are literals:
 * "dock_bay" (price key), "ship_bay" (dock variant), "voidcrew_ship_docked" (the docked signal),
 * ship states "flying", "idle", "docking", "undocking", dock modes "lockdown" and "open".
 *
 * Money is conserved on every path: the sum of the ship accounts, the treasury and the escrow is
 * checked across refunds, captures and evictions.
 */
/datum/unit_test/voidcrew_outpost_dock_fees
	parent_type = /datum/unit_test/voidcrew_outpost_management
	/// Bare mobile ports standing in for hulls; unhooked and force-deleted in Destroy()
	var/list/obj/docking_port/mobile/voidcrew/fee_ports = list()

/datum/unit_test/voidcrew_outpost_dock_fees/Destroy()
	for(var/obj/docking_port/mobile/voidcrew/port as anything in fee_ports)
		if(QDELETED(port))
			continue
		var/obj/structure/overmap/ship/ship = port.current_ship
		if(ship)
			if(ship.undock_warmup_timer)
				deltimer(ship.undock_warmup_timer)
				ship.undock_warmup_timer = null
			ship.shuttle = null
		port.current_ship = null
		qdel(port, force = TRUE)
	fee_ports.Cut()
	return ..()

/// A claim owned by `owner_key` with its ship bay installed
/datum/unit_test/voidcrew_outpost_dock_fees/proc/fee_claim(owner_key)
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim(owner_key)
	if(!home || home.enable_ship_bays())
		return null
	return home

/// A bare visiting ship with a crew team, a ship account holding `balance`, and a 1x1 port
/datum/unit_test/voidcrew_outpost_dock_fees/proc/fee_ship(ship_name, balance)
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship, run_loc_floor_top_right)
	ship.name = ship_name
	var/obj/docking_port/mobile/voidcrew/port = new(run_loc_floor_top_right)
	fee_ports += port
	port.width = 1
	port.height = 1
	port.dwidth = 0
	port.dheight = 0
	port.shuttle_areas = list()
	port.current_ship = ship
	ship.shuttle = port
	ship.ship_team = new /datum/team/voidcrew
	ship.ship_account = new /datum/bank_account/ship("[ship_name] account", null, 1, FALSE)
	ship.ship_account.account_balance = balance
	return ship

/// Hands `ship` an approval for `fee` at `home`'s bay
/datum/unit_test/voidcrew_outpost_dock_fees/proc/give_consent(obj/structure/overmap/dynamic/player_outpost/home, obj/structure/overmap/ship/ship, fee)
	ship.dock_fee_consent = list("outpost" = WEAKREF(home), "variant" = "ship_bay", "amount" = fee, "expires" = world.time + 1200, "approver" = "unit test")

/// Allocates the bay and escrows the approved fee, exactly as ship_act() does before dock()
/datum/unit_test/voidcrew_outpost_dock_fees/proc/escrow(obj/structure/overmap/dynamic/player_outpost/home, obj/structure/overmap/ship/ship, fee)
	give_consent(home, ship, fee)
	var/datum/outpost_berth/ship_bay/bay = home.allocate_ship_bay(ship)
	TEST_ASSERT_NOTNULL(bay, "The bay could not be allocated for [ship.name]")
	var/refusal = home.take_dock_fee(ship, "ship_bay")
	TEST_ASSERT_NULL(refusal, "An approved, funded fee was refused: [refusal]")
	return bay

/// Puts the ship's port on the bay's dock with the ship docked there and settled
/datum/unit_test/voidcrew_outpost_dock_fees/proc/settle_in_bay(obj/structure/overmap/dynamic/player_outpost/home, obj/structure/overmap/ship/ship, datum/outpost_berth/ship_bay/bay)
	ship.shuttle.forceMove(get_turf(bay.dock))
	ship.forceMove(home)
	ship.docked = home
	ship.state = "idle"

/// Takes the ship back out into flight and runs the outpost's undock hook
/datum/unit_test/voidcrew_outpost_dock_fees/proc/leave_bay(obj/structure/overmap/dynamic/player_outpost/home, obj/structure/overmap/ship/ship)
	ship.shuttle.forceMove(run_loc_floor_top_right)
	ship.forceMove(run_loc_floor_top_right)
	ship.docked = null
	ship.state = "flying"
	home.on_ship_undock_complete(ship)

/// Treasury plus every ship account plus every escrow: constant on every path
/datum/unit_test/voidcrew_outpost_dock_fees/proc/balance_of(obj/structure/overmap/dynamic/player_outpost/home, list/obj/structure/overmap/ship/ships)
	var/total = home.treasury.account_balance
	for(var/obj/structure/overmap/ship/ship as anything in ships)
		total += ship.ship_account.account_balance
		if(ship.dock_fee_hold)
			total += ship.dock_fee_hold.amount
	return total

// ===== QUOTES, APPROVAL, EXEMPTIONS, ESCROW REFUSAL (spec 3.1.6 items 9, 12-15) =====

/datum/unit_test/voidcrew_outpost_dock_fees/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = fee_claim("feeowner")
	TEST_ASSERT_NOTNULL(home, "The dock fee claim did not load with a ship bay")
	var/datum/outpost_berth/ship_bay/bay = home.bay_berths[1]
	home.outpost_prices["dock_bay"] = 500
	var/turf/shore = get_turf(home.management_console)
	var/mob/living/carbon/human/owner = make_player(shore, "feeowner")
	var/mob/living/carbon/human/pilot = make_player(shore, "feepilot")
	var/mob/living/carbon/human/deckhand = make_player(shore, "feedeckhand")
	var/mob/living/carbon/human/stranger = make_player(shore, "feestranger")
	var/obj/structure/overmap/ship/ship = fee_ship("Fee Test Ship", 1000)
	ship.ship_team.add_member(pilot.mind)
	ship.ship_team.add_member(deckhand.mind)
	ship.claimed_captain = pilot.mind
	var/treasury_start = home.treasury.account_balance
	var/total = balance_of(home, list(ship))

	// Item 13: exemptions
	TEST_ASSERT_EQUAL(home.dock_fee_for(ship, null), 0, "A hangar dock was charged")
	TEST_ASSERT_EQUAL(home.dock_fee_for(ship, "ship_bay"), 500, "The bay fee was not quoted at the set price")
	var/obj/structure/overmap/ship/crew_ship = fee_ship("Owner Crew Ship", 1000)
	home.founder_mind = WEAKREF(owner.mind)
	crew_ship.ship_team.add_member(owner.mind)
	TEST_ASSERT_EQUAL(home.dock_fee_for(crew_ship, "ship_bay"), 0, "The owner's own crew was charged the bay fee")
	TEST_ASSERT_NULL(home.dock_fee_denial(crew_ship, "ship_bay"), "The owner's own crew was quoted")
	TEST_ASSERT_NULL(crew_ship.dock_fee_quote, "The owner's own crew got a quote")
	home.playtest_visitor_ckey = "feeowner"
	TEST_ASSERT_EQUAL(home.dock_fee_for(crew_ship, "ship_bay"), 500, "Bill me as a visitor did not bill the owner's ship")
	home.playtest_visitor_ckey = null
	home.founder_ckey = null
	TEST_ASSERT_EQUAL(home.dock_fee_for(ship, "ship_bay"), 0, "An ownerless outpost charged a docking fee")
	TEST_ASSERT_NULL(home.dock_fee_denial(ship, "ship_bay"), "An ownerless outpost quoted a docking fee")
	home.founder_ckey = "feeowner"

	// Item 9: no approval, so the ship holds with a quote and nothing leaks
	var/previous_state = ship.state
	home.ship_act(pilot, ship, dock_variant = "ship_bay")
	TEST_ASSERT_NOTNULL(ship.dock_fee_quote, "An unapproved bay dock stored no quote")
	TEST_ASSERT_EQUAL(ship.dock_fee_quote["amount"], 500, "The quote named the wrong fee")
	TEST_ASSERT(bay.is_available(), "An unapproved dock took the bay")
	TEST_ASSERT(!home.first_dock_taken && !home.second_dock_taken, "An unapproved dock claimed a reserve pad")
	TEST_ASSERT_EQUAL(ship.dock_index, 0, "An unapproved dock left a pad index")
	TEST_ASSERT_EQUAL(ship.state, previous_state, "An unapproved dock changed the ship's state")
	TEST_ASSERT(!home.concerned, "An unapproved dock left the outpost busy")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 1000, "An unapproved dock debited the ship")
	TEST_ASSERT_NULL(ship.dock_fee_hold, "An unapproved dock escrowed a fee")
	var/list/card = ship.dock_fee_quote_data(pilot)
	TEST_ASSERT_EQUAL(card["amount"], 500, "The helm card shows the wrong fee")
	TEST_ASSERT_EQUAL(card["ref"], REF(home), "The helm card names the wrong outpost")
	TEST_ASSERT_EQUAL(card["balance"], 1000, "The helm card shows the wrong ship balance")
	TEST_ASSERT(card["expiresIn"] > 0 && card["expiresIn"] <= 120, "The helm card's expiry is not in seconds")
	TEST_ASSERT(card["canApprove"], "The captain cannot approve on the helm card")

	// Item 15: helm approval
	TEST_ASSERT_NOTNULL(ship.approve_dock_fee(stranger, REF(home), "ship_bay", 500), "Someone off the crew approved a docking fee")
	TEST_ASSERT_NOTNULL(ship.approve_dock_fee(pilot, REF(home), "ship_bay", 400), "An approval with the wrong amount was accepted")
	TEST_ASSERT_NOTNULL(ship.approve_dock_fee(pilot, REF(ship), "ship_bay", 500), "An approval naming another outpost was accepted")
	TEST_ASSERT_NOTNULL(ship.approve_dock_fee(pilot, REF(home), 5, 500), "An approval with a non-text variant was accepted")
	TEST_ASSERT_NULL(ship.dock_fee_consent, "A refused approval stored consent")
	// No captain is connected in a test world, so the rename rule lets other crew approve
	TEST_ASSERT(ship.can_approve_dock_fee(deckhand), "Crew could not approve while no captain was connected")
	TEST_ASSERT(!ship.can_approve_dock_fee(stranger), "Someone off the crew may approve")
	ship.dock_fee_quote["expires"] = world.time - 1
	TEST_ASSERT_NOTNULL(ship.approve_dock_fee(pilot, REF(home), "ship_bay", 500), "An expired quote was approved")
	TEST_ASSERT_NULL(ship.dock_fee_quote, "An expired quote was not dropped")
	TEST_ASSERT_NOTNULL(home.dock_fee_denial(ship, "ship_bay"), "A new dock attempt was not quoted again")
	TEST_ASSERT_NULL(ship.approve_dock_fee(pilot, REF(home), "ship_bay", 500), "The captain could not approve the quote")
	TEST_ASSERT_NOTNULL(ship.dock_fee_consent, "An approval stored no consent")
	TEST_ASSERT_NULL(ship.dock_fee_quote, "An approval left the quote open")
	TEST_ASSERT_NOTNULL(ship.approve_dock_fee(deckhand, REF(home), "ship_bay", 500), "A second helm approved the same quote twice")
	TEST_ASSERT_NULL(home.dock_fee_denial(ship, "ship_bay"), "An approved fee still held the ship")

	// Item 12: a raised fee is quoted again and charges nothing
	home.outpost_prices["dock_bay"] = 900
	home.ship_act(pilot, ship, dock_variant = "ship_bay")
	TEST_ASSERT_EQUAL(ship.dock_fee_quote?["amount"], 900, "A raised fee was not quoted again")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 1000, "A fee raised after approval was charged")
	TEST_ASSERT(bay.is_available(), "A re-quoted dock took the bay")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_start, "A re-quoted dock paid the treasury")
	// A lowered fee charges the lower fee under the old approval
	home.outpost_prices["dock_bay"] = 300
	TEST_ASSERT_NULL(home.dock_fee_denial(ship, "ship_bay"), "A lowered fee was not covered by the approval")
	TEST_ASSERT_NOTNULL(home.allocate_ship_bay(ship), "The bay could not be allocated")
	TEST_ASSERT_NULL(home.take_dock_fee(ship, "ship_bay"), "A lowered fee was refused at escrow")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 700, "A lowered fee charged the approved amount instead")
	TEST_ASSERT_EQUAL(ship.dock_fee_hold?.amount, 300, "The escrow holds the wrong amount")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_start, "Escrow paid the treasury before arrival")
	TEST_ASSERT_EQUAL(balance_of(home, list(ship)), total, "Escrow created or destroyed money")
	home.refund_dock_fee_hold(ship, "unit test")
	bay.release(force = TRUE)
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 1000, "The escrow refund was not exact")
	TEST_ASSERT(bay.is_available(), "The test bay stayed reserved")

	// Item 14: a short ship account at escrow releases everything
	home.outpost_prices["dock_bay"] = 500
	ship.ship_account.account_balance = 100
	give_consent(home, ship, 500)
	previous_state = ship.state
	home.ship_act(pilot, ship, dock_variant = "ship_bay")
	TEST_ASSERT(bay.is_available(), "A refused escrow left the bay reserved")
	TEST_ASSERT_NULL(bay.ship, "A refused escrow left the ship assigned to the bay")
	TEST_ASSERT_EQUAL(ship.dock_index, 0, "A refused escrow left a pad index")
	TEST_ASSERT_EQUAL(ship.state, previous_state, "A refused escrow did not restore the ship's state")
	TEST_ASSERT(!home.concerned, "A refused escrow left the outpost busy")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 100, "A refused escrow moved money")
	TEST_ASSERT_NULL(ship.dock_fee_hold, "A refused escrow created a hold")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_start, "A refused escrow paid the treasury")

	// A siphon-locked account cannot pay either
	ship.ship_account.account_balance = 1000
	ship.ship_account.mark_siphoned()
	home.allocate_ship_bay(ship)
	TEST_ASSERT_NOTNULL(home.take_dock_fee(ship, "ship_bay"), "A siphon-locked ship account paid a docking fee")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 1000, "A siphon-locked account was debited")
	bay.release(force = TRUE)
	ship.ship_account.siphon_lock_until = 0

	// Declining clears the quote
	ship.dock_fee_consent = null
	TEST_ASSERT_NOTNULL(home.dock_fee_denial(ship, "ship_bay"), "No quote to decline")
	TEST_ASSERT_NULL(ship.decline_dock_fee(pilot, REF(home)), "The crew could not decline the quote")
	TEST_ASSERT_NULL(ship.dock_fee_quote, "Declining left the quote open")

// ===== ESCROW: CAPTURE ONCE, REFUND ON EVERY OTHER EXIT (items 10, 11) =====

/datum/unit_test/voidcrew_outpost_dock_fee_escrow
	parent_type = /datum/unit_test/voidcrew_outpost_dock_fees

/datum/unit_test/voidcrew_outpost_dock_fee_escrow/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = fee_claim("escrowowner")
	TEST_ASSERT_NOTNULL(home, "The escrow claim did not load with a ship bay")
	home.outpost_prices["dock_bay"] = 500
	var/treasury_start = home.treasury.account_balance
	var/obj/structure/overmap/ship/ship = fee_ship("Escrow Ship", 1000)
	var/total = balance_of(home, list(ship))

	// Item 10: arrival captures exactly once
	var/datum/outpost_berth/ship_bay/bay = escrow(home, ship, 500)
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 500, "Escrow did not debit the ship")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_start, "The treasury was paid before arrival")
	TEST_ASSERT_EQUAL(length(home.dock_fee_holds), 1, "The outpost does not track the escrow")
	ship.docked = home
	ship.state = "idle"
	SEND_SIGNAL(ship, "voidcrew_ship_docked")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_start + 500, "Arrival did not pay the treasury")
	TEST_ASSERT_NULL(ship.dock_fee_hold, "Arrival left the escrow open")
	TEST_ASSERT_EQUAL(length(home.dock_fee_holds), 0, "Arrival left the escrow tracked")
	var/list/totals = home.service_totals["dock_bay"]
	TEST_ASSERT_EQUAL(totals?["count"], 1, "The dock fee was not written to the income totals")
	SEND_SIGNAL(ship, "voidcrew_ship_docked")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_start + 500, "A second docked signal paid again")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 500, "A second docked signal charged again")
	TEST_ASSERT_EQUAL(balance_of(home, list(ship)), total, "Capture created or destroyed money")
	TEST_ASSERT_NOTNULL(home.bay_visit_fees[WEAKREF(ship)], "Arrival did not record the fee for an eviction refund")
	leave_bay(home, ship)
	TEST_ASSERT_NULL(home.bay_visit_fees[WEAKREF(ship)], "Undocking kept the visit fee record")
	TEST_ASSERT(bay.is_available(), "Undocking kept the bay")
	ship.ship_account.account_balance = 1000
	home.treasury.account_balance = treasury_start
	total = balance_of(home, list(ship))

	// Item 11: dock() refused
	bay = escrow(home, ship, 500)
	home.refund_dock_fee_hold(ship, "dock refused")
	bay.release(force = TRUE)
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 1000, "A refused dock() kept the fee")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_start, "A refused dock() paid the treasury")

	// Warmup denial (owner lockdown during the 10 s warmup)
	bay = escrow(home, ship, 500)
	ship.docked = home
	ship.state = "docking"
	home.dock_mode = "lockdown"
	ship.complete_dock_warmup(bay.dock, WEAKREF(home))
	home.dock_mode = "open"
	TEST_ASSERT_EQUAL(ship.state, "flying", "The warmup denial did not return the ship to flight")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 1000, "A warmup denial kept the fee")
	TEST_ASSERT_NULL(ship.dock_fee_hold, "A warmup denial left the escrow open")
	TEST_ASSERT(bay.is_available(), "A warmup denial kept the bay")

	// A stalled dock: no refund while still docking, a refund once the dock is abandoned
	bay = escrow(home, ship, 500)
	var/datum/outpost_dock_fee_hold/hold = ship.dock_fee_hold
	ship.docked = home
	ship.state = "docking"
	hold.check_stall()
	TEST_ASSERT_EQUAL(ship.dock_fee_hold, hold, "A dock still under way was refunded, so a late arrival would dock free")
	ship.abort_stalled_dock(home)
	hold.check_stall()
	TEST_ASSERT_NULL(ship.dock_fee_hold, "A stalled dock kept its escrow")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 1000, "A stalled dock kept the fee")
	bay.release(force = TRUE)

	// The cap: a dock still unresolved after 10 minutes is refunded, and never charged later
	bay = escrow(home, ship, 500)
	hold = ship.dock_fee_hold
	ship.docked = home
	ship.state = "docking"
	hold.created_at = world.time - 6001
	hold.check_stall()
	TEST_ASSERT_NULL(ship.dock_fee_hold, "A stuck dock kept its escrow past the cap")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 1000, "A stuck dock kept the fee")
	ship.state = "idle"
	SEND_SIGNAL(ship, "voidcrew_ship_docked")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_start, "A refunded stuck dock was charged on arrival")
	leave_bay(home, ship)

	// A second escrow while the first dock is still under way is refused; the first stays
	bay = escrow(home, ship, 500)
	hold = ship.dock_fee_hold
	ship.docked = home
	give_consent(home, ship, 500)
	TEST_ASSERT_NOTNULL(home.take_dock_fee(ship, "ship_bay"), "A second escrow started during a dock")
	TEST_ASSERT_EQUAL(ship.dock_fee_hold, hold, "A second escrow replaced the first")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 500, "A second escrow charged twice")
	// Once that dock is gone, any new dock refunds the dead escrow first
	ship.docked = null
	ship.dock_fee_consent = null
	home.take_dock_fee(ship, null)
	TEST_ASSERT_NULL(ship.dock_fee_hold, "A new dock kept a dead escrow")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 1000, "A dead escrow was not refunded")
	bay.release(force = TRUE)

	// Owner change before arrival refunds
	bay = escrow(home, ship, 500)
	home.founder_ckey = "escrowbuyer"
	ship.docked = home
	ship.state = "idle"
	SEND_SIGNAL(ship, "voidcrew_ship_docked")
	home.founder_ckey = "escrowowner"
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 1000, "An owner change before arrival kept the fee")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_start, "An owner change paid the new owner")
	leave_bay(home, ship)
	TEST_ASSERT_EQUAL(balance_of(home, list(ship)), total, "The refund paths created or destroyed money")

	// Ship deleted before arrival: refunded while its account still exists
	var/obj/structure/overmap/ship/lost_ship = fee_ship("Lost Ship", 1000)
	var/datum/bank_account/lost_account = lost_ship.ship_account
	bay = escrow(home, lost_ship, 500)
	lost_ship.shuttle.current_ship = null
	lost_ship.shuttle = null
	qdel(lost_ship)
	TEST_ASSERT_EQUAL(lost_account.account_balance, 1000, "A deleted ship's escrow was not refunded before its account went")
	TEST_ASSERT_EQUAL(length(home.dock_fee_holds), 0, "A deleted ship's escrow stayed tracked")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_start, "A deleted ship paid the treasury")

	// A docked ship deleted after paying leaves no record behind
	var/obj/structure/overmap/ship/paid_ship = fee_ship("Paid Ship", 1000)
	bay = escrow(home, paid_ship, 500)
	paid_ship.docked = home
	paid_ship.state = "idle"
	SEND_SIGNAL(paid_ship, "voidcrew_ship_docked")
	TEST_ASSERT_EQUAL(length(home.bay_visit_fees), 1, "The paid visit was not recorded")
	paid_ship.shuttle.current_ship = null
	paid_ship.shuttle = null
	qdel(paid_ship)
	TEST_ASSERT_EQUAL(length(home.bay_visit_fees), 0, "A deleted ship's visit fee record outlived it")
	home.treasury.account_balance = treasury_start

	// Outpost deleted before arrival: refunded
	escrow(home, ship, 500)
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 500, "The last escrow did not debit the ship")
	qdel(home)
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 1000, "Deleting the outpost kept a visiting ship's escrow")
	TEST_ASSERT_NULL(ship.dock_fee_hold, "Deleting the outpost left the escrow open")

// ===== BAY EVICTION (item 16, abuse review F-14, F-15, F-16) =====

/datum/unit_test/voidcrew_outpost_bay_eviction
	parent_type = /datum/unit_test/voidcrew_outpost_dock_fees

/datum/unit_test/voidcrew_outpost_bay_eviction/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = fee_claim("evictowner")
	TEST_ASSERT_NOTNULL(home, "The eviction claim did not load with a ship bay")
	home.outpost_prices["dock_bay"] = 500
	var/turf/shore = get_turf(home.management_console)
	var/mob/living/carbon/human/owner = make_player(shore, "evictowner")
	var/mob/living/carbon/human/stranger = make_player(shore, "evictstranger")
	var/obj/structure/overmap/ship/ship = fee_ship("Squatter", 1000)
	var/treasury_start = home.treasury.account_balance
	var/datum/outpost_berth/ship_bay/bay = escrow(home, ship, 500)
	settle_in_bay(home, ship, bay)
	SEND_SIGNAL(ship, "voidcrew_ship_docked")
	TEST_ASSERT(bay.is_ship_present(), "The test ship is not settled in the bay")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_start + 500, "The squatter's fee was not paid")
	var/total = balance_of(home, list(ship))

	// Refusals
	TEST_ASSERT_NOTNULL(home.request_bay_eviction(stranger, bay), "Someone without management evicted a ship")
	bay.rebuild_owner = WEAKREF(src)
	TEST_ASSERT_NOTNULL(home.request_bay_eviction(owner, bay), "An eviction started during a rebuild")
	bay.rebuild_owner = null
	var/list/row = home.bay_eviction_row(bay, owner)
	TEST_ASSERT_NULL(row["evict_denial"], "The owner was refused an eviction: [row["evict_denial"]]")
	TEST_ASSERT_EQUAL(row["evict_refund"], 500, "The row does not show the refund due")
	TEST_ASSERT(!row["evicting"], "The row shows an eviction before one started")

	// F-15: evict, cancel, evict inside the window refunds once
	TEST_ASSERT_NULL(home.request_bay_eviction(owner, bay), "The owner could not evict a paid ship")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 1000, "An eviction inside the window did not refund the fee")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_start, "An eviction refund did not come from the treasury")
	row = home.bay_eviction_row(bay, owner)
	TEST_ASSERT(row["evicting"], "The row does not show the running eviction")
	TEST_ASSERT(row["evict_eta"] > 0 && row["evict_eta"] <= 180, "The eviction countdown is not in seconds")
	TEST_ASSERT_EQUAL(row["evict_refund"], 0, "The row still offers a paid refund")
	TEST_ASSERT_NOTNULL(home.request_bay_eviction(owner, bay), "A second eviction started while one runs")
	TEST_ASSERT_NULL(home.cancel_bay_eviction(owner, bay), "The owner could not cancel the eviction")
	row = home.bay_eviction_row(bay, owner)
	TEST_ASSERT(!row["evicting"], "Cancelling left the eviction running")
	TEST_ASSERT_NULL(home.request_bay_eviction(owner, bay), "The owner could not evict again")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 1000, "Evict, cancel, evict refunded twice")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_start, "Evict, cancel, evict paid out of the treasury twice")
	TEST_ASSERT_EQUAL(balance_of(home, list(ship)), total, "Eviction created or destroyed money")
	home.cancel_bay_eviction(owner, bay)

	// No refund outside the window
	home.record_bay_visit_fee(ship, 500)
	var/list/visit = home.bay_visit_fees[WEAKREF(ship)]
	visit["time"] = world.time - 18001
	TEST_ASSERT_EQUAL(home.bay_eviction_refund(ship), 0, "A ship docked over 30 minutes offered a refund")
	TEST_ASSERT_NULL(home.request_bay_eviction(owner, bay), "The owner could not evict a long-docked ship")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 1000, "A late eviction refunded the fee")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_start, "A late eviction paid out of the treasury")

	// Item 16: with nobody ashore, the timer proc undocks the ship
	home.enforce_bay_eviction(WEAKREF(ship))
	TEST_ASSERT_EQUAL(ship.state, "undocking", "The eviction timer did not undock the ship")
	TEST_ASSERT_NOTNULL(home.bay_evictions[WEAKREF(ship)], "The eviction stopped watching an undock that has not completed")
	deltimer(ship.undock_warmup_timer)
	ship.undock_warmup_timer = null
	ship.state = "idle"
	home.cancel_bay_eviction(owner, bay)

	// F-14: an empty hull whose crew is ashore is never launched; with no berth free it waits
	var/mob/living/carbon/human/crew_ashore = make_player(shore, "evictcrew")
	ship.ship_team.add_member(crew_ashore.mind)
	var/list/placeholders = new /list(6)
	for(var/i in 1 to 6)
		placeholders[i] = allocate(/datum/outpost_berth, home, i, null)
	home.berths = placeholders
	TEST_ASSERT(home.evicted_crew_ashore(ship), "Crew ashore with nobody aboard was not recognised")
	TEST_ASSERT_NULL(home.request_bay_eviction(owner, bay), "The owner could not evict a ship with crew ashore")
	home.enforce_bay_eviction(WEAKREF(ship))
	TEST_ASSERT_EQUAL(ship.state, "idle", "An empty hull was launched while its crew was ashore")
	TEST_ASSERT_EQUAL(ship.docked, home, "An empty hull left the outpost while its crew was ashore")
	var/list/eviction = home.bay_evictions[WEAKREF(ship)]
	TEST_ASSERT_NOTNULL(eviction, "The eviction gave up at once with no berth free")
	TEST_ASSERT(!eviction["relocating"] && eviction["retries"] == 1 && eviction["timer"], "The eviction is not retrying with no berth free")

	// F-16: undock completion forgets every record of the ship
	home.record_bay_visit_fee(ship, 500)
	ship.dock_fee_quote = list("outpost" = WEAKREF(home), "variant" = "ship_bay", "amount" = 500, "expires" = world.time + 1200)
	leave_bay(home, ship)
	TEST_ASSERT_EQUAL(length(home.bay_evictions), 0, "Undocking kept the eviction")
	TEST_ASSERT_EQUAL(length(home.bay_visit_fees), 0, "Undocking kept the visit fee")
	TEST_ASSERT_NULL(ship.dock_fee_quote, "Undocking kept a quote from this outpost")

	// F-16: deleting an evicted ship forgets it too
	home.berths = null
	QDEL_LIST(placeholders)
	var/obj/structure/overmap/ship/doomed = fee_ship("Doomed", 1000)
	bay = escrow(home, doomed, 500)
	settle_in_bay(home, doomed, bay)
	SEND_SIGNAL(doomed, "voidcrew_ship_docked")
	TEST_ASSERT_NULL(home.request_bay_eviction(owner, bay), "The owner could not evict the second ship")
	doomed.shuttle.forceMove(run_loc_floor_top_right)
	doomed.shuttle.current_ship = null
	doomed.shuttle = null
	qdel(doomed)
	TEST_ASSERT_EQUAL(length(home.bay_evictions), 0, "A deleted ship's eviction outlived it")
	TEST_ASSERT_EQUAL(length(home.bay_visit_fees), 0, "A deleted ship's visit fee outlived it")
