/**
 * # Player Outpost Shells
 *
 * The pre-built starting structures a founder picks from when using their
 * deed. Each shell is a .dmm loaded onto the outpost's fresh z-level; the owner
 * expands outward from it via the construction console or by hand. There is one
 * shell per outpost style, and the founder's pick sets the style every room the
 * outpost buys later is drawn in (outpost_styles.dm).
 *
 * Shell requirements (linked by link_interior_machinery, checked for every
 * selectable shell by /datum/unit_test/voidcrew_outpost_shell_contract):
 * - exactly one /obj/machinery/computer/player_outpost_management
 * - exactly one /obj/machinery/computer/camera_advanced/base_construction/ship/outpost
 * - one /obj/machinery/ore_silo (feeds the construction console's internal tools)
 * - one ordinary cargo console, bank terminal and resident cryopod on accessible
 *   interior floors (install_home_bundle binds them without spawning stock)
 * - one /obj/effect/landmark/player_outpost_arrival
 * - a hangar elevator kit on the north side: 3x3 /obj/effect/landmark/outpost_elevator_alcove
 *   with one /obj/machinery/outpost_elevator/directional panel, so visiting ships
 *   get hangar berths from the moment of founding (see outpost_hangar.dm)
 * - external airlocks on at least two of the other sides (EVA walk-in stays possible)
 * - pressurized core, lights
 * - a starter power bay: APC + cable, charged SMES with input terminal, and an
 *   unanchored portable generator with fuel, the area requires power, so when
 *   the SMES buffer drains the owner keeps the generator fed or goes dark
 *
 * The bare-claim shell deliberately breaks all of these: it ships nothing but a
 * pad, the arrival landmark and a crate of console boards. Everything the
 * linker doesn't find is simply absent until the owner builds it (rebuilt
 * consoles relink themselves; see outpost_management.dm / outpost_construction.dm).
 */

/area/voidcrew/player_outpost
	name = "\improper Player Outpost"
	icon_state = "away"
	static_lighting = TRUE
	default_gravity = STANDARD_GRAVITY
	// No UNIQUE_AREA: every shell load must instantiate its own area so
	// multiple player outposts don't share one area datum
	area_flags = NOTELEPORT
	flags_1 = NONE
	ambience_index = AMBIENCE_AWAY
	repels_megafauna = TRUE // voidcrew/area/megafauna_ban.dm

/// The registry habitat's walls. They strip to iron: titanium walls would make every new habitat
/// a titanium claim worth several deeds on the stock market.
/turf/closed/wall/mineral/titanium/nodiagonal/habitat
	name = "habitat wall"
	desc = "Titanium panelling bolted over an iron frame."
	sheet_type = /obj/item/stack/sheet/iron

/// Marks where visitors and the construction drone arrive; consumed at load
/obj/effect/landmark/player_outpost_arrival
	name = "player outpost arrival"

// Base type is abstract: no mappath
/datum/map_template/player_outpost
	name = "Outpost Shell"
	outpost_style = OUTPOST_STYLE_DEFAULT
	/// One line on the founding catalog
	var/catalog_desc = ""
	/// Whether a founder can pick this shell. The founding catalog and the admin manipulator offer these.
	var/selectable = FALSE
	/// Position on the founding catalog, lowest first
	var/catalog_order = 0

/datum/map_template/player_outpost/rundown
	name = "Salvaged Waystation"
	catalog_desc = "An old roadhouse, patched up and sold as it stands."
	mappath = "voidcrew/_maps/map_files/outposts/player_outpost_shell_rundown.dmm"
	outpost_style = OUTPOST_STYLE_RUNDOWN
	selectable = TRUE
	catalog_order = 1

/datum/map_template/player_outpost/clean
	name = "Registry Habitat"
	catalog_desc = "A new habitat from the registry's catalogue."
	mappath = "voidcrew/_maps/map_files/outposts/player_outpost_shell_clean.dmm"
	outpost_style = OUTPOST_STYLE_CLEAN
	selectable = TRUE
	catalog_order = 2

/// Hidden: the founding catalog does not offer it. Its rooms load in the default style.
/datum/map_template/player_outpost/nothing
	name = "Bare Claim"
	catalog_desc = "No prefab at all: an empty sector, a survey pad, and a crate holding the registry console boards. Bring your own everything."
	mappath = "voidcrew/_maps/map_files/outposts/player_outpost_shell_nothing.dmm"

/// The shell templates a founder may pick, in catalog order
/proc/outpost_selectable_shells()
	var/static/list/shells
	if(shells)
		return shells
	shells = list()
	for(var/datum/map_template/player_outpost/shell_type as anything in subtypesof(/datum/map_template/player_outpost))
		if(!initial(shell_type.selectable))
			continue
		var/position = length(shells) + 1
		for(var/index in 1 to length(shells))
			var/datum/map_template/player_outpost/placed = shells[index]
			if(initial(shell_type.catalog_order) < initial(placed.catalog_order))
				position = index
				break
		shells.Insert(position, shell_type)
	return shells

/// The founding catalog's shell pictures, baked by tools/outpost_upgrade_previews
/datum/asset/simple/outpost_shell_previews

/datum/asset/simple/outpost_shell_previews/register()
	assets = list()
	for(var/shell_type in outpost_selectable_shells())
		var/asset_name = outpost_shell_preview_asset(shell_type)
		if(asset_name)
			assets[asset_name] = file("[OUTPOST_PREVIEW_DIR][asset_name]")
	return ..()

/// The shell's preview asset name, or null until the picture exists
/proc/outpost_shell_preview_asset(shell_type)
	var/preview = outpost_map_preview_name(shell_type)
	if(!preview || !fexists("[OUTPOST_PREVIEW_DIR][preview].png"))
		return null
	return "[preview].png"

/// The bare claim's entire inheritance: the outpost console boards.
/// Everything else (frames, materials, the silo, air) is the owner's problem.
/obj/structure/closet/crate/player_outpost_start
	name = "colonial registry claim crate"
	desc = "The colonial registry's idea of a starter kit: the circuit boards for an outpost's management, construction and shipyard consoles, and a packing slip wishing you luck."

/obj/structure/closet/crate/player_outpost_start/PopulateContents()
	. = ..()
	new /obj/item/circuitboard/computer/player_outpost_management(src)
	new /obj/item/circuitboard/computer/player_outpost_construction(src)
	new /obj/item/circuitboard/computer/ship_checkpoint(src)
	new /obj/item/paper/fluff/player_outpost_claim(src)

/obj/item/paper/fluff/player_outpost_claim
	name = "packing slip"
	default_raw_text = "CONTENTS: outpost management console board (1), outpost construction console board (1), shipyard console board (1). The Colonial Registry congratulates you on your new claim and reminds you that unimproved sectors carry no warranty, atmosphere, or floor. Good luck."
