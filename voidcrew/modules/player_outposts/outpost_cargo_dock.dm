/**
 * # Cargo dock
 *
 * The free outpost upgrade that outpost freight (outpost_freight.dm) lands on. The room holds a
 * landing pad sized to the cargo ferry (/datum/map_template/shuttle/cargo/box) with deck round
 * it. The ferry docks on the pad's stationary port with its doors toward the room's entrance.
 * Until a claim places one, its cargo console refuses to order.
 */

/// Each placement loads its own instance (the parent has no UNIQUE_AREA), with its own APC.
/area/voidcrew/player_outpost/cargo_dock
	name = "\improper Cargo Dock"
	icon = 'icons/area/areas_station.dmi'
	icon_state = "cargo_bay"

/**
 * The landing pad. The mapped values are the cargo ferry's own mobile port: the box ferry is
 * 7x12 with its port on an airlock in the middle of its long side, facing inboard. The map puts
 * this port on the pad's edge beside the apron, facing into the pad, so the ferry lands with that
 * airlock row on the apron side.
 */
/obj/docking_port/stationary/outpost_cargo_dock
	name = "cargo dock pad"
	shuttle_id = "outpost_cargo_dock"
	dir = NORTH
	width = 12
	height = 7
	dwidth = 5
	dheight = 0

/**
 * Docking ports ignore shuttleRotate(), so a rotated upgrade load would leave the pad facing the
 * way it was drawn. width, height, dwidth and dheight are all measured along dir, so turning dir
 * about the port tile turns the whole landing rectangle with the room.
 */
/obj/docking_port/stationary/outpost_cargo_dock/template_load_rotate(rotation)
	setDir(angle2dir(rotation + dir2angle(dir)))

/// Authored with its entrance on the south edge; placement rotates it.
/datum/map_template/outpost_upgrade/cargo_dock
	name = "Outpost Cargo Dock"
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_cargo_dock.dmm"

/datum/outpost_upgrade/cargo_dock
	id = "cargo_dock"
	name = "Cargo Dock"
	desc = "A landing pad for the cargo ferry. Cargo orders are delivered here."
	price = 0
	template_type = /datum/map_template/outpost_upgrade/cargo_dock
	area_type = /area/voidcrew/player_outpost/cargo_dock
	preview_name = "outpost_upgrade_cargo_dock"
	entrance_side = SOUTH
	/// The pad's docking port, once placement has finished
	var/obj/docking_port/stationary/outpost_cargo_dock/pad

/datum/outpost_upgrade/cargo_dock/Destroy()
	if(pad)
		UnregisterSignal(pad, COMSIG_QDELETING)
		qdel(pad, TRUE) // docking ports refuse a plain qdel
		pad = null
	return ..()

/datum/outpost_upgrade/cargo_dock/on_installed(mob/user)
	if(pad || !footprint_bounds)
		return
	var/z = footprint_bounds[5]
	for(var/turf/tile as anything in block(footprint_bounds[1], footprint_bounds[2], z, footprint_bounds[3], footprint_bounds[4], z))
		pad = locate() in tile
		if(pad)
			break
	if(!pad)
		log_mapping("PLAYER OUTPOST: the cargo dock at '[outpost]' loaded without its landing pad port.")
		return
	pad.name = "[outpost.name] Cargo Dock"
	RegisterSignal(pad, COMSIG_QDELETING, PROC_REF(on_pad_deleted))

/**
 * A level teardown force-deletes every port on it, ours included. Plain qdel() calls also send
 * this signal but leave the port standing (QDEL_HINT_LETMELIVE), and every ferry landing and
 * departure makes one on the pad's tile, so only a forced delete loses the pad.
 */
/datum/outpost_upgrade/cargo_dock/proc/on_pad_deleted(datum/source, force)
	SIGNAL_HANDLER
	if(force)
		pad = null

/// The placed cargo dock's landing pad, or null when the claim has none.
/obj/structure/overmap/dynamic/player_outpost/proc/cargo_dock_port()
	var/datum/outpost_upgrade/cargo_dock/dock = outpost_upgrades["cargo_dock"]
	if(!istype(dock) || !dock.installed || QDELETED(dock.pad))
		return null
	return dock.pad

/// Whether the cargo ferry is docked at this claim and covers the turf.
/obj/structure/overmap/dynamic/player_outpost/proc/cargo_ferry_covers(turf/tile)
	var/obj/docking_port/mobile/ferry = freight?.shuttle_port
	var/obj/docking_port/stationary/pad = cargo_dock_port()
	if(QDELETED(ferry) || !pad || ferry.get_docked() != pad)
		return FALSE
	return ferry.is_in_shuttle_bounds_geometric(tile)
