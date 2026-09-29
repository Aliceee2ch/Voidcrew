/**
 * # Derelict leash
 *
 * Owner: P4. Keeps a derelict's hostile inside that derelict's habitat.
 */
/datum/component/derelict_leash
	/// Weakref to the derelict this hostile belongs to
	var/datum/weakref/home

/datum/component/derelict_leash/Initialize(obj/structure/overmap/dynamic/player_outpost/derelict/home_site)
	if(!isliving(parent) || !istype(home_site))
		return COMPONENT_INCOMPATIBLE
	home = WEAKREF(home_site)
