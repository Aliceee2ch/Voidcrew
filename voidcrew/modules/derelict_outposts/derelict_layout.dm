/**
 * # Derelict outpost: layout and dead power
 *
 * Owner: P2. The prison wing joined to the shell, every cell drained, the fuel hidden, dark berths and the ambience.
 */

/// Places the prison wing, joined to an outer airlock of the shell when it can be. Returns the wing's upgrade, or null.
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/place_derelict_prison()
	return null

/// Drains every APC, SMES and light emergency cell, empties the generator and hides its fuel
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/drain_derelict_power()
	return

/// Makes a berth dark (lights off, no floodlight, blank signs, spooky ambience) or lights it again
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/set_berth_dark(datum/outpost_berth/berth, dark)
	return

/// Lights every berth again
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/relight_berths()
	return

/// Spooky ambience and no ship hum in the derelict's areas, or their own sounds back
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/set_derelict_ambience(spooky)
	return
