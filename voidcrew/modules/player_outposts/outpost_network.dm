// MARKET-OWNER: P8
/**
 * # Outpost teleporter network
 *
 * Pads, registry and trips (grounding-teleporter 7.2). Until the network is built the trader
 * outposts spawn no pad.
 */

/// Puts this trading outpost's network pad in its concourse. Called once the interior has loaded, outside the load's try block.
/obj/structure/overmap/trader_outpost/proc/spawn_network_pad()
	return
