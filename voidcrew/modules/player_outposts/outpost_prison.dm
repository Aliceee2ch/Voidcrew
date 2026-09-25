/// The prison wing an outpost buys from its upgrades catalog. Each placement
/// loads its own instance (the parent has no UNIQUE_AREA), with its own APC,
/// so a power failure in the wing stays in the wing.
/area/voidcrew/player_outpost/prison
	name = "\improper Prison Wing"
	icon = 'icons/area/areas_station.dmi'
	icon_state = "sec_prison"
	/// The prison this wing houses, once placement has finished
	var/datum/outpost_prison/prison

/// The prison whose wing holds this atom, if any
/proc/get_outpost_prison(atom/thing)
	var/area/voidcrew/player_outpost/prison/wing = get_area(thing)
	return istype(wing) ? wing.prison : null

/// Authored with its entrance on the south edge; placement rotates it.
/datum/map_template/outpost_upgrade/prison
	name = "Outpost Prison Wing"
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_prison.dmm"

/datum/outpost_upgrade/prison
	id = "prison"
	name = "Prison Wing"
	desc = "Four cells, a yard and a warden's office on its own power."
	price = OUTPOST_PRISON_COST
	template_type = /datum/map_template/outpost_upgrade/prison
	area_type = /area/voidcrew/player_outpost/prison
	preview_name = "outpost_upgrade_prison"
	entrance_side = SOUTH
	/// The running prison, created once the wing is placed
	var/datum/outpost_prison/prison

/datum/outpost_upgrade/prison/Destroy()
	QDEL_NULL(prison)
	return ..()

/datum/outpost_upgrade/prison/on_installed(mob/user)
	if(prison || !istype(installed_area, /area/voidcrew/player_outpost/prison))
		return
	prison = new(src)
