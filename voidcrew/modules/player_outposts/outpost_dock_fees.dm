// MARKET-OWNER: P2
/**
 * # Ship bay docking fee
 *
 * Seams called from ship_act(), Destroy() (player_outpost.dm) and on_ship_undock_complete()
 * (outpost_services.dm). Until the docking fee is built they charge nothing and change nothing.
 */

/// A refusal to show the helm while a docking fee waits for the captain's approval, or null to go on docking
/obj/structure/overmap/dynamic/player_outpost/proc/dock_fee_denial(obj/structure/overmap/ship/ship, dock_variant)
	return null

/// Escrows the approved fee just before dock(). Null when nothing is owed or it was taken, else a refusal.
/obj/structure/overmap/dynamic/player_outpost/proc/take_dock_fee(obj/structure/overmap/ship/ship, dock_variant)
	return null

/// Returns the ship's escrowed fee to its account (a dock that never arrived)
/obj/structure/overmap/dynamic/player_outpost/proc/refund_dock_fee_hold(obj/structure/overmap/ship/ship, reason)
	return

/// A ship finished undocking: refund any unresolved hold and clear quotes and approvals naming this outpost
/obj/structure/overmap/dynamic/player_outpost/proc/release_dock_fee_state(obj/structure/overmap/ship/ship)
	return

/// The outpost is being deleted: refund every escrowed fee
/obj/structure/overmap/dynamic/player_outpost/proc/refund_all_dock_fee_holds()
	return

/// Eviction state of a ship bay for the Docking tab
/obj/structure/overmap/dynamic/player_outpost/proc/bay_eviction_row(datum/outpost_berth/ship_bay/bay, mob/user)
	return list()

/// Orders the ship in `bay` out. Null when started, else a refusal.
/obj/structure/overmap/dynamic/player_outpost/proc/request_bay_eviction(mob/living/user, datum/outpost_berth/ship_bay/bay)
	return "Not available."

/// Stops a running eviction of the ship in `bay`
/obj/structure/overmap/dynamic/player_outpost/proc/cancel_bay_eviction(mob/living/user, datum/outpost_berth/ship_bay/bay)
	return
