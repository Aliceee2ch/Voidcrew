/**
 * # Outpost upgrades
 *
 * Prefab rooms an outpost buys from the management console's Upgrades tab. Buying one pays the
 * treasury and leaves an unplaced blueprint on the outpost; cancelling the purchase refunds it.
 * The same tab opens a schematic placement map (OutpostManagement.tsx) that stamps the blueprint
 * onto the main level at any of four rotations, within OUTPOST_UPGRADE_MAX_GAP tiles of the rest
 * of the outpost. Placement is permanent: no relocation, no refund. One of each per outpost.
 *
 * The map is drawn from a survey the server takes once per view (and caches briefly): one
 * character per tile, made by the same rules placement enforces, so the client's green and red
 * agree with the server. Mobs are left out of the survey; the server re-checks them at Build.
 *
 * Subtypes set the catalog fields and a map template. The prison wing is the first
 * (outpost_prison.dm).
 */

#define OUTPOST_UPGRADE_PREVIEW_DIR "voidcrew/modules/player_outposts/previews/"

// Survey cell classes. The first three are ground an upgrade may cover.
#define UPGRADE_CELL_SPACE "s"
#define UPGRADE_CELL_LATTICE "l"
#define UPGRADE_CELL_FLOOR "f"
#define UPGRADE_CELL_WALL "w"
#define UPGRADE_CELL_WINDOW "g"
#define UPGRADE_CELL_DOOR "d"
#define UPGRADE_CELL_OBJECT "m"
/// Docking pads, berths, the elevator, the arrival point and other upgrades
#define UPGRADE_CELL_RESERVED "x"
/// The placement survey never covers more than this many tiles a side, centred on the outpost's core
#define UPGRADE_SURVEY_WINDOW 128

/// Base for upgrade rooms. Loaded with load_rotated(), never centered or cached.
/datum/map_template/outpost_upgrade
	name = "Outpost Upgrade"

/// Upgrade prototypes by id, in catalog order. They carry no outpost state; buying copies one.
GLOBAL_LIST_INIT(outpost_upgrade_catalog, init_outpost_upgrade_catalog())

/proc/init_outpost_upgrade_catalog()
	var/list/catalog = list()
	for(var/datum/outpost_upgrade/upgrade_type as anything in subtypesof(/datum/outpost_upgrade))
		var/upgrade_id = initial(upgrade_type.id)
		if(!upgrade_id)
			continue
		catalog[upgrade_id] = new upgrade_type
	return catalog

/datum/outpost_upgrade
	/// Catalog key. Also the purchase limit: one of each per outpost.
	var/id
	var/name = "Outpost Upgrade"
	var/desc = ""
	var/price = 0
	/// The room this upgrade stamps
	var/datum/map_template/template_type
	/// Area type the template uses; the installed instance is found by it
	var/area_type
	/// Base name of the baked preview under OUTPOST_UPGRADE_PREVIEW_DIR (png and .preview.json)
	var/preview_name
	/// Edge of the template as authored that holds the entrance
	var/entrance_side = SOUTH

	// Per-outpost state. Catalog prototypes leave these empty.
	var/obj/structure/overmap/dynamic/player_outpost/outpost
	/// What the treasury paid, and what cancelling the purchase refunds
	var/paid = 0
	/// Claimed by a placement whose map load is still running
	var/placing = FALSE
	var/installed = FALSE
	/// Degrees clockwise the template was placed at
	var/rotation = 0
	/// list(min_x, min_y, max_x, max_y, z) of the placed footprint, set as soon as placement starts
	var/list/footprint_bounds
	/// The area instance the placement created
	var/area/installed_area

/datum/outpost_upgrade/New(obj/structure/overmap/dynamic/player_outpost/owner)
	. = ..()
	outpost = owner

/datum/outpost_upgrade/Destroy()
	// Deleted on its own (by an admin), it leaves the outpost's list, so it can be bought again.
	if(id && !QDELETED(outpost) && outpost.outpost_upgrades[id] == src)
		outpost.outpost_upgrades -= id
	outpost = null
	installed_area = null
	return ..()

/// Called once the room is stamped and initialized. Upgrades wire their own systems in here.
/datum/outpost_upgrade/proc/on_installed(mob/user)
	return

/// One shared, uncached template per upgrade type. Null when the map file is missing.
/datum/outpost_upgrade/proc/get_template()
	var/static/list/templates = list()
	if(!template_type)
		return null
	if(!(template_type in templates))
		var/map_path = initial(template_type.mappath)
		templates[template_type] = (map_path && fexists(map_path)) ? new template_type : null
	var/datum/map_template/template = templates[template_type]
	return template?.width ? template : null

/// The baked preview's asset name, or null until it exists
/datum/outpost_upgrade/proc/preview_asset()
	if(!preview_name || !fexists("[OUTPOST_UPGRADE_PREVIEW_DIR][preview_name].png"))
		return null
	return "[preview_name].png"

/// Which edge of the placed footprint the entrance faces for a clockwise rotation
/datum/outpost_upgrade/proc/rotated_entrance(rotation)
	return angle2dir(rotation + dir2angle(entrance_side))

/**
 * The footprint for a placement with its bottom-left on `bottom_left`:
 * list("bottom_left", "top_right", "turfs", "entrance" = edge turfs, "entrance_dir").
 * Null when the template is missing or the footprint runs off the map.
 */
/datum/outpost_upgrade/proc/footprint_at(turf/bottom_left, rotation)
	var/datum/map_template/template = get_template()
	if(!bottom_left || !template)
		return null
	var/turned = (rotation == 90 || rotation == 270)
	var/turf/top_right = locate(bottom_left.x + (turned ? template.height : template.width) - 1, bottom_left.y + (turned ? template.width : template.height) - 1, bottom_left.z)
	if(!top_right)
		return null
	var/entrance_dir = rotated_entrance(rotation)
	var/list/entrance
	switch(entrance_dir)
		if(NORTH)
			entrance = block(bottom_left.x, top_right.y, bottom_left.z, top_right.x, top_right.y, bottom_left.z)
		if(SOUTH)
			entrance = block(bottom_left.x, bottom_left.y, bottom_left.z, top_right.x, bottom_left.y, bottom_left.z)
		if(EAST)
			entrance = block(top_right.x, bottom_left.y, bottom_left.z, top_right.x, top_right.y, bottom_left.z)
		else
			entrance = block(bottom_left.x, bottom_left.y, bottom_left.z, bottom_left.x, top_right.y, bottom_left.z)
	return list(
		"bottom_left" = bottom_left,
		"top_right" = top_right,
		"turfs" = block(bottom_left, top_right),
		"entrance" = entrance,
		"entrance_dir" = entrance_dir,
	)

/datum/outpost_upgrade/proc/contains_turf(turf/tile)
	return footprint_bounds && tile && tile.z == footprint_bounds[5] \
		&& tile.x >= footprint_bounds[1] && tile.y >= footprint_bounds[2] \
		&& tile.x <= footprint_bounds[3] && tile.y <= footprint_bounds[4]

/datum/outpost_upgrade/proc/state_text()
	if(installed)
		return "installed"
	if(outpost)
		return "ready"
	return "available"

// ===== OUTPOST STATE =====

/obj/structure/overmap/dynamic/player_outpost
	/// Bought upgrades by id, unplaced blueprints and installed rooms alike
	var/list/datum/outpost_upgrade/outpost_upgrades = list()
	/// The latest placement-map survey (see build_upgrade_survey())
	var/list/upgrade_survey
	var/upgrade_survey_time = 0
	var/upgrade_surveying = FALSE
	/// Weakrefs to management panels waiting for the running survey
	var/list/upgrade_survey_waiters

/// The claim's main level, or null before it loads
/obj/structure/overmap/dynamic/player_outpost/proc/upgrade_level_z()
	if(!mapzone || !length(mapzone.z_levels))
		return null
	var/datum/space_level/level = mapzone.z_levels[1]
	return level?.z_value

/// Blueprints bought but not yet placed, in catalog order
/obj/structure/overmap/dynamic/player_outpost/proc/upgrade_blueprints()
	var/list/blueprints = list()
	for(var/upgrade_id in GLOB.outpost_upgrade_catalog)
		var/datum/outpost_upgrade/upgrade = outpost_upgrades[upgrade_id]
		if(upgrade && !upgrade.installed && !upgrade.placing)
			blueprints += upgrade
	return blueprints

/// The placed (or currently placing) upgrade covering a turf, if any
/obj/structure/overmap/dynamic/player_outpost/proc/upgrade_at_turf(turf/tile)
	for(var/upgrade_id in outpost_upgrades)
		var/datum/outpost_upgrade/upgrade = outpost_upgrades[upgrade_id]
		if(upgrade?.contains_turf(tile))
			return upgrade
	return null

/// The blueprint a UI action names, when it is bought and not yet placed
/obj/structure/overmap/dynamic/player_outpost/proc/unplaced_upgrade(upgrade_id)
	// UI params are decoded JSON: a number here would index the list by position
	if(!istext(upgrade_id))
		return null
	var/datum/outpost_upgrade/blueprint = outpost_upgrades[upgrade_id]
	if(!blueprint || blueprint.installed || blueprint.placing)
		return null
	return blueprint

/// Buying, placing and cancelling all need management and treasury access.
/obj/structure/overmap/dynamic/player_outpost/proc/upgrade_access_denial(mob/user)
	if(!is_current_management_user(user) || !can_spend(user))
		return "Management and treasury access required."
	if(!loaded || loading)
		return "Outpost not ready."
	if(!treasury)
		return "Outpost bank unavailable."
	return null

/// Shared by the Buy button and the purchase itself. Null when the user may buy it now.
/obj/structure/overmap/dynamic/player_outpost/proc/upgrade_purchase_denial(mob/user, upgrade_id)
	if(!istext(upgrade_id))
		return "Unknown upgrade."
	var/datum/outpost_upgrade/prototype = GLOB.outpost_upgrade_catalog[upgrade_id]
	if(!prototype)
		return "Unknown upgrade."
	var/datum/outpost_upgrade/owned = outpost_upgrades[upgrade_id]
	if(owned)
		return owned.installed ? "Already installed." : "Blueprint already bought."
	var/denial = upgrade_access_denial(user)
	if(denial)
		return denial
	if(!prototype.get_template())
		return "Upgrade unavailable."
	if(prototype.price && !treasury.has_money(prototype.price))
		return "Insufficient outpost funds."
	return null

/// Pays the treasury and leaves an unplaced blueprint. Returns null on success, else the reason.
/obj/structure/overmap/dynamic/player_outpost/proc/buy_outpost_upgrade(mob/user, upgrade_id)
	var/denial = upgrade_purchase_denial(user, upgrade_id)
	if(denial)
		return denial
	var/datum/outpost_upgrade/prototype = GLOB.outpost_upgrade_catalog[upgrade_id]
	// adjust_money() refuses a zero amount, so a free upgrade skips the treasury.
	if(prototype.price && !treasury.adjust_money(-prototype.price, "Outpost upgrade: [prototype.name], bought by [user.ckey]"))
		return "Insufficient outpost funds."
	var/datum/outpost_upgrade/blueprint = new prototype.type(src)
	blueprint.paid = prototype.price
	outpost_upgrades[upgrade_id] = blueprint
	log_game("PLAYER OUTPOST: [key_name(user)] bought the [prototype.name] upgrade for [prototype.price] cr at '[name]'")
	return null

/// Whether the user may place or cancel this blueprint now. Null when they may.
/obj/structure/overmap/dynamic/player_outpost/proc/upgrade_blueprint_denial(mob/user, upgrade_id)
	var/datum/outpost_upgrade/owned = istext(upgrade_id) ? outpost_upgrades[upgrade_id] : null
	if(!owned)
		return "No blueprint bought."
	if(owned.installed)
		return "Already installed."
	if(owned.placing)
		return "Placement in progress."
	return upgrade_access_denial(user)

/// Refunds exactly what was paid and removes the unplaced blueprint. Null on success.
/obj/structure/overmap/dynamic/player_outpost/proc/cancel_outpost_upgrade(mob/user, upgrade_id)
	var/denial = upgrade_blueprint_denial(user, upgrade_id)
	if(denial)
		return denial
	var/datum/outpost_upgrade/blueprint = outpost_upgrades[upgrade_id]
	outpost_upgrades -= upgrade_id
	if(blueprint.paid)
		treasury.adjust_money(blueprint.paid, "Outpost upgrade refund: [blueprint.name], cancelled by [user.ckey]")
	log_game("PLAYER OUTPOST: [key_name(user)] cancelled the [blueprint.name] upgrade at '[name]', refunding [blueprint.paid] cr")
	qdel(blueprint)
	return null

// ===== GROUND RULES =====

/**
 * Ground no upgrade may cover on level `z`, as list(x0, y0, x1, y1) corners in any order:
 * every docking port's footprint (the reserve berths, docked hulls) and the reserve berths'
 * original layout, since they move to fit each visitor and move back.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/upgrade_protected_rects(z)
	var/list/rects = list()
	for(var/obj/docking_port/stationary/dock in SSshuttle.stationary_docking_ports)
		if(dock.z == z)
			rects += list(dock.return_coords())
	for(var/obj/docking_port/mobile/port in SSshuttle.mobile_docking_ports)
		if(port.z == z)
			rects += list(port.return_coords())
	for(var/obj/docking_port/stationary/dock in list(reserve_dock, reserve_dock_secondary))
		if(dock.reserve_home_z == z)
			rects += list(list(dock.reserve_home_x, dock.reserve_home_y, dock.reserve_home_x + RESERVE_DOCK_MAX_SIZE_LONG - 1, dock.reserve_home_y + RESERVE_DOCK_MAX_SIZE_SHORT - 1))
	return rects

/// Outpost ground kept free whatever stands on it: docking, berths, the elevator, arrivals, other upgrades.
/obj/structure/overmap/dynamic/player_outpost/proc/is_upgrade_ground_reserved(turf/tile, list/protected_rects)
	if(tile == arrival_turf || (tile in lobby_alcove_turfs) || (tile in lobby_wall_turfs))
		return TRUE
	if(upgrade_at_turf(tile))
		return TRUE
	if(isnull(protected_rects))
		protected_rects = upgrade_protected_rects(tile.z)
	for(var/list/rect as anything in protected_rects)
		if(tile.x >= min(rect[1], rect[3]) && tile.x <= max(rect[1], rect[3]) && tile.y >= min(rect[2], rect[4]) && tile.y <= max(rect[2], rect[4]))
			return TRUE
	for(var/datum/outpost_berth/berth in berths)
		if(berth.contains_service_turf(tile))
			return TRUE
	for(var/datum/outpost_berth/ship_bay/bay in bay_berths)
		if(bay.contains_service_turf(tile))
			return TRUE
	return FALSE

/**
 * Whether an upgrade may be stamped over this tile. Pass `protected_rects` from
 * upgrade_protected_rects() when checking many tiles. Lattices and catwalks are cleared by the
 * placement and loose items are moved out of the way (sweep_upgrade_footprint()); decals stay.
 * The survey passes `ignore_mobs`: mobs move, so the server only checks them when the room is
 * actually built. Landmarks never block: a level's teardown keeps them, so a recycled level can
 * carry invisible ones left by deleted hulls.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/is_upgrade_turf_clear(turf/tile, list/protected_rects, ignore_mobs = FALSE)
	if(!is_turf_buildable(tile) || isclosedturf(tile))
		return FALSE
	if(is_upgrade_ground_reserved(tile, protected_rects))
		return FALSE
	for(var/atom/movable/thing as anything in tile)
		if(ismob(thing))
			if(isliving(thing) && !ignore_mobs)
				return FALSE
			continue // camera eyes and observers
		if(istype(thing, /obj/docking_port))
			return FALSE
		if(istype(thing, /obj/structure/lattice) || istype(thing, /obj/effect/decal) || istype(thing, /obj/effect/landmark))
			continue
		if(thing.density || thing.anchored)
			return FALSE
	return TRUE

/**
 * Turfs that count as the outpost for the distance rule: the outpost's own area and every
 * installed upgrade's area on the main level. A claim that never got an outpost area falls back
 * to its arrival point and its shell's footprint.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/outpost_owned_turfs()
	var/list/owned = list()
	var/z = upgrade_level_z()
	if(!z)
		return owned
	if(outpost_area)
		owned += outpost_area.get_turfs_by_zlevel(z)
	for(var/upgrade_id in outpost_upgrades)
		var/datum/outpost_upgrade/upgrade = outpost_upgrades[upgrade_id]
		if(upgrade?.installed && upgrade.installed_area)
			owned += upgrade.installed_area.get_turfs_by_zlevel(z)
	if(length(owned))
		return owned
	if(arrival_turf)
		owned += arrival_turf
	if(template_bottom_left && shell_template?.width)
		owned += block(template_bottom_left.x, template_bottom_left.y, template_bottom_left.z, template_bottom_left.x + shell_template.width - 1, template_bottom_left.y + shell_template.height - 1, template_bottom_left.z)
	return owned

/// Whether a footprint has a tile within OUTPOST_UPGRADE_MAX_GAP tiles of outpost ground
/obj/structure/overmap/dynamic/player_outpost/proc/upgrade_footprint_near_outpost(turf/bottom_left, turf/top_right)
	var/list/owned = list()
	for(var/turf/owned_turf as anything in outpost_owned_turfs())
		owned[owned_turf] = TRUE
	var/gap = OUTPOST_UPGRADE_MAX_GAP
	for(var/turf/near as anything in block(max(1, bottom_left.x - gap), max(1, bottom_left.y - gap), bottom_left.z, min(world.maxx, top_right.x + gap), min(world.maxy, top_right.y + gap), bottom_left.z))
		if(owned[near])
			return TRUE
	return FALSE

/**
 * Stamps a bought blueprint with its footprint's bottom-left on `bottom_left`, turned `rotation`
 * degrees clockwise. Returns null on success, else the reason. Permanent.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/place_outpost_upgrade(datum/outpost_upgrade/blueprint, turf/bottom_left, rotation, mob/user)
	if(QDELETED(blueprint) || outpost_upgrades[blueprint.id] != blueprint || blueprint.installed || blueprint.placing)
		return "No upgrade blueprint to place."
	rotation = SIMPLIFY_DEGREES(rotation)
	if(rotation % 90)
		return "Invalid rotation."
	var/datum/map_template/template = blueprint.get_template()
	if(!template)
		return "Upgrade unavailable."
	var/list/footprint = blueprint.footprint_at(bottom_left, rotation)
	if(!footprint)
		return "Invalid position."
	var/list/footprint_turfs = footprint["turfs"]
	var/list/protected_rects = upgrade_protected_rects(bottom_left.z)
	for(var/turf/tile as anything in footprint_turfs)
		if(!is_upgrade_turf_clear(tile, protected_rects))
			return "Position obstructed."
	var/turf/top_right = footprint["top_right"]
	if(!upgrade_footprint_near_outpost(bottom_left, top_right))
		return "Too far from the outpost."
	// Claim the blueprint and its ground before the load can yield, so a second Build or an
	// elevator placement finds nothing to work with.
	blueprint.placing = TRUE
	blueprint.rotation = rotation
	blueprint.footprint_bounds = list(bottom_left.x, bottom_left.y, top_right.x, top_right.y, bottom_left.z)
	for(var/turf/tile as anything in footprint_turfs)
		for(var/obj/structure/lattice/lattice in tile) // catwalks included
			qdel(lattice)
	sweep_upgrade_footprint(footprint)
	var/list/loaded_bounds = template.load_rotated(bottom_left, rotation)
	if(QDELETED(blueprint))
		return "The upgrade could not be built."
	blueprint.placing = FALSE
	if(!loaded_bounds || QDELETED(src))
		// Nothing was built: the blueprint goes back on the shelf.
		blueprint.footprint_bounds = null
		blueprint.rotation = 0
		return "The upgrade could not be built."
	blueprint.installed = TRUE
	for(var/turf/tile as anything in footprint_turfs)
		if(istype(tile.loc, blueprint.area_type))
			blueprint.installed_area = tile.loc
			break
	// The ground changed under the placement map.
	upgrade_survey = null
	blueprint.on_installed(user)
	var/list/entrance = footprint["entrance"]
	playsound(entrance[CEILING(length(entrance) / 2, 1)], 'sound/machines/ding.ogg', 60, TRUE)
	log_game("PLAYER OUTPOST: [key_name(user)] placed the [blueprint.name] upgrade at '[name]' ([bottom_left.x],[bottom_left.y],[bottom_left.z], rotated [rotation])")
	return null

/**
 * Moves loose things off a footprint that is about to be built over, onto the ground outside its
 * entrance, so nothing ends up inside the new walls. Anchored things, effects and decals stay.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/sweep_upgrade_footprint(list/footprint)
	var/list/entrance = footprint["entrance"]
	var/entrance_dir = footprint["entrance_dir"]
	if(!length(entrance))
		return
	var/turf/outside = get_step(entrance[CEILING(length(entrance) / 2, 1)], entrance_dir)
	if(!outside || isclosedturf(outside))
		outside = null
		for(var/turf/edge as anything in entrance)
			var/turf/beyond = get_step(edge, entrance_dir)
			if(beyond && !isclosedturf(beyond))
				outside = beyond
				break
	if(!outside)
		return
	for(var/turf/tile as anything in footprint["turfs"])
		for(var/atom/movable/thing as anything in tile)
			if(thing.anchored || iseffect(thing) || !(isobj(thing) || isliving(thing)))
				continue
			thing.forceMove(outside)

// ===== PLACEMENT MAP SURVEY =====

/// What the placement map draws for one tile. Open classes are exactly the tiles is_upgrade_turf_clear() accepts, mobs aside.
/obj/structure/overmap/dynamic/player_outpost/proc/upgrade_survey_class(turf/tile, list/protected_rects)
	if(is_upgrade_turf_clear(tile, protected_rects, ignore_mobs = TRUE))
		if(locate(/obj/structure/lattice) in tile)
			return UPGRADE_CELL_LATTICE
		return isspaceturf(tile) ? UPGRADE_CELL_SPACE : UPGRADE_CELL_FLOOR
	if(!is_turf_buildable(tile) || is_upgrade_ground_reserved(tile, protected_rects))
		return UPGRADE_CELL_RESERVED
	if(isclosedturf(tile))
		return UPGRADE_CELL_WALL
	if(locate(/obj/machinery/door) in tile)
		return UPGRADE_CELL_DOOR
	if((locate(/obj/structure/window) in tile) || (locate(/obj/structure/grille) in tile))
		return UPGRADE_CELL_WINDOW
	return UPGRADE_CELL_OBJECT

/// The largest side of any catalog room, so the map reaches every legal spot
/proc/largest_outpost_upgrade_side()
	var/largest = 1
	for(var/upgrade_id in GLOB.outpost_upgrade_catalog)
		var/datum/outpost_upgrade/upgrade = GLOB.outpost_upgrade_catalog[upgrade_id]
		var/datum/map_template/template = upgrade.get_template()
		if(template)
			largest = max(largest, template.width, template.height)
	return largest

/// The middle of the outpost's shell, or its arrival point, which the placement survey is centred on
/obj/structure/overmap/dynamic/player_outpost/proc/upgrade_survey_center()
	if(template_bottom_left && shell_template?.width)
		return locate(template_bottom_left.x + round(shell_template.width / 2), template_bottom_left.y + round(shell_template.height / 2), template_bottom_left.z)
	return arrival_turf

/**
 * Surveys the ground around the outpost for the placement map. Yields. Returns
 * list("x", "y", "z", "width", "height", "cells", "near") or null, where `cells` has one
 * UPGRADE_CELL_* character per tile and `near` has "1" where a tile is within
 * OUTPOST_UPGRADE_MAX_GAP of outpost ground. Both run row by row from the bottom-left corner.
 * The region is the outpost ground's bounding box widened by the gap plus the largest room,
 * clamped to the claim and to UPGRADE_SURVEY_WINDOW tiles a side around the outpost's core, so an
 * outpost sprawled across the claim does not survey all of it.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/build_upgrade_survey()
	var/z = upgrade_level_z()
	var/list/owned = outpost_owned_turfs()
	if(!z || !build_bounds || !length(owned))
		return null
	var/low_x = world.maxx
	var/low_y = world.maxy
	var/high_x = 1
	var/high_y = 1
	for(var/turf/owned_turf as anything in owned)
		low_x = min(low_x, owned_turf.x)
		low_y = min(low_y, owned_turf.y)
		high_x = max(high_x, owned_turf.x)
		high_y = max(high_y, owned_turf.y)
	var/margin = OUTPOST_UPGRADE_MAX_GAP + largest_outpost_upgrade_side()
	low_x = max(build_bounds[1], low_x - margin)
	low_y = max(build_bounds[2], low_y - margin)
	high_x = min(build_bounds[3], high_x + margin)
	high_y = min(build_bounds[4], high_y + margin)
	var/turf/center = upgrade_survey_center()
	if(center)
		var/half = round(UPGRADE_SURVEY_WINDOW / 2)
		low_x = max(low_x, center.x - half)
		low_y = max(low_y, center.y - half)
		high_x = min(high_x, center.x - half + UPGRADE_SURVEY_WINDOW - 1)
		high_y = min(high_y, center.y - half + UPGRADE_SURVEY_WINDOW - 1)
	var/width = high_x - low_x + 1
	var/height = high_y - low_y + 1
	if(width < 1 || height < 1)
		return null

	// Near mask: mark outpost ground, then widen by the gap along rows, then along columns.
	var/gap = OUTPOST_UPGRADE_MAX_GAP
	var/list/marks = new /list(width * height)
	for(var/turf/owned_turf as anything in owned)
		if(owned_turf.x >= low_x && owned_turf.x <= high_x && owned_turf.y >= low_y && owned_turf.y <= high_y)
			marks[(owned_turf.y - low_y) * width + (owned_turf.x - low_x) + 1] = TRUE
	var/list/row_near = new /list(width * height)
	var/list/prefix = new /list(max(width, height) + 1)
	for(var/row in 0 to height - 1)
		prefix[1] = 0
		for(var/column in 1 to width)
			prefix[column + 1] = prefix[column] + (marks[row * width + column] ? 1 : 0)
		for(var/column in 1 to width)
			if(prefix[min(width, column + gap) + 1] - prefix[max(1, column - gap)] > 0)
				row_near[row * width + column] = TRUE
		CHECK_TICK
	var/list/near = new /list(width * height)
	for(var/column in 1 to width)
		prefix[1] = 0
		for(var/row in 1 to height)
			prefix[row + 1] = prefix[row] + (row_near[(row - 1) * width + column] ? 1 : 0)
		for(var/row in 1 to height)
			near[(row - 1) * width + column] = (prefix[min(height, row + gap) + 1] - prefix[max(1, row - gap)] > 0) ? "1" : "0"
		CHECK_TICK

	var/list/protected_rects = upgrade_protected_rects(z)
	var/list/cells = new /list(width * height)
	var/index = 0
	for(var/y in low_y to high_y)
		for(var/x in low_x to high_x)
			cells[++index] = upgrade_survey_class(locate(x, y, z), protected_rects)
		CHECK_TICK
	if(QDELETED(src))
		return null
	return list(
		"x" = low_x,
		"y" = low_y,
		"z" = z,
		"width" = width,
		"height" = height,
		"cells" = jointext(cells, ""),
		"near" = jointext(near, ""),
	)

/**
 * Gets a survey to the panel: the cached one while fresh, else a new one in the background.
 * Nothing is pushed when a survey starts: ui_data's `upgrade_surveying` already shows
 * "Surveying", and a second static push inside tgui's refresh cooldown remounts the window.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/request_upgrade_survey(datum/player_outpost_management_ui/panel, force = FALSE)
	LAZYOR(upgrade_survey_waiters, WEAKREF(panel))
	if(upgrade_surveying)
		return
	if(!force && upgrade_survey && world.time < upgrade_survey_time + OUTPOST_UPGRADE_SURVEY_LIFETIME)
		notify_upgrade_survey()
		return
	upgrade_surveying = TRUE
	INVOKE_ASYNC(src, PROC_REF(run_upgrade_survey))

/obj/structure/overmap/dynamic/player_outpost/proc/run_upgrade_survey()
	var/list/survey = build_upgrade_survey()
	if(QDELETED(src))
		return
	upgrade_surveying = FALSE
	upgrade_survey = survey
	upgrade_survey_time = world.time
	notify_upgrade_survey()

/obj/structure/overmap/dynamic/player_outpost/proc/notify_upgrade_survey()
	for(var/datum/weakref/panel_ref as anything in upgrade_survey_waiters)
		var/datum/player_outpost_management_ui/panel = panel_ref.resolve()
		if(!QDELETED(panel))
			panel.push_static_data()
	upgrade_survey_waiters = null

// ===== MANAGEMENT CONSOLE =====

/datum/asset/simple/outpost_upgrade_previews

/datum/asset/simple/outpost_upgrade_previews/register()
	assets = list()
	for(var/upgrade_id in GLOB.outpost_upgrade_catalog)
		var/datum/outpost_upgrade/upgrade = GLOB.outpost_upgrade_catalog[upgrade_id]
		var/asset_name = upgrade.preview_asset()
		if(asset_name)
			assets[asset_name] = file("[OUTPOST_UPGRADE_PREVIEW_DIR][asset_name]")
		else if(upgrade.preview_name)
			log_asset("outpost_upgrade_previews: missing preview image for [upgrade.id]")
	return ..()

/datum/player_outpost_management_ui
	var/upgrade_error
	/// Whether this panel has its placement map open and wants the survey in its static data
	var/wants_upgrade_survey = FALSE
	/// world.time of this panel's last static data push (see push_static_data())
	var/last_static_push = 0

/**
 * The only way this panel pushes static data. A second full update inside tgui's
 * TGUI_REFRESH_FULL_UPDATE_COOLDOWN makes the window show its "refreshing" screen and
 * remount the interface, which throws away the tab and placement map the player had open.
 * So a push that comes too soon after the last one waits out the remainder, and pushes that
 * pile up while it waits collapse into one, sent with whatever the data is by then.
 */
/datum/player_outpost_management_ui/proc/push_static_data()
	if(QDELETED(src))
		return
	var/wait = last_static_push ? last_static_push + TGUI_REFRESH_FULL_UPDATE_COOLDOWN - world.time : 0
	for(var/datum/tgui/window as anything in open_uis)
		// Covers full updates this panel did not send, such as the client's own refresh.
		wait = max(wait, COOLDOWN_TIMELEFT(window, refresh_cooldown))
		// A window that has not finished opening drops full updates, and it is about to get
		// this data with its first one anyway.
		if(!window.initialized)
			wait = max(wait, 1)
	if(wait > 0)
		addtimer(CALLBACK(src, PROC_REF(push_static_data)), wait, TIMER_UNIQUE)
		return
	last_static_push = world.time
	update_static_data_for_all_viewers()

/datum/player_outpost_management_ui/ui_static_data(mob/user)
	var/list/catalog = list()
	for(var/upgrade_id in GLOB.outpost_upgrade_catalog)
		var/datum/outpost_upgrade/upgrade = GLOB.outpost_upgrade_catalog[upgrade_id]
		var/datum/map_template/template = upgrade.get_template()
		catalog += list(list(
			"id" = upgrade_id,
			"name" = upgrade.name,
			"desc" = upgrade.desc,
			"price" = upgrade.price,
			"width" = template?.width || 0,
			"height" = template?.height || 0,
			"entrance" = upgrade.entrance_side,
			"preview" = upgrade.preview_asset(),
		))
	// The survey can be tens of kilobytes: static data only, and only while a map is open. The key
	// is always sent, because tgui merges static data into the old state and would keep a stale one.
	var/show_survey = wants_upgrade_survey && !QDELETED(outpost) && !outpost.upgrade_surveying
	return list(
		"upgrade_catalog" = catalog,
		"upgrade_survey" = show_survey ? outpost.upgrade_survey : null,
	)

/// Per-outpost state for each catalog entry: list("id", "state", "denial", "manage_denial")
/datum/player_outpost_management_ui/proc/upgrade_ui_data(mob/user)
	var/list/states = list()
	for(var/upgrade_id in GLOB.outpost_upgrade_catalog)
		var/datum/outpost_upgrade/owned = outpost.outpost_upgrades[upgrade_id]
		states += list(list(
			"id" = upgrade_id,
			"state" = owned ? owned.state_text() : "available",
			"denial" = outpost.upgrade_purchase_denial(user, upgrade_id),
			"manage_denial" = owned ? outpost.upgrade_blueprint_denial(user, upgrade_id) : null,
		))
	return states

/// Upgrades tab and placement map actions. The caller has already checked management access.
/datum/player_outpost_management_ui/proc/upgrade_action(action, list/params, mob/living/user)
	switch(action)
		if("buy_upgrade")
			upgrade_error = outpost.buy_outpost_upgrade(user, params["id"])
		if("cancel_upgrade")
			upgrade_error = outpost.cancel_outpost_upgrade(user, params["id"])
			if(!upgrade_error)
				close_upgrade_map()
		if("open_upgrade_map", "refresh_upgrade_map")
			upgrade_error = outpost.upgrade_blueprint_denial(user, params["id"])
			if(upgrade_error)
				return TRUE
			wants_upgrade_survey = TRUE
			outpost.request_upgrade_survey(src, force = (action == "refresh_upgrade_map"))
		if("close_upgrade_map")
			upgrade_error = null
			close_upgrade_map()
		if("place_upgrade")
			upgrade_error = place_upgrade_from_map(user, params)
			if(!upgrade_error)
				close_upgrade_map()
	return TRUE

/datum/player_outpost_management_ui/proc/close_upgrade_map()
	if(!wants_upgrade_survey)
		return
	wants_upgrade_survey = FALSE
	push_static_data()

/// Build from the placement map: world coordinates of the footprint's bottom-left and a rotation.
/datum/player_outpost_management_ui/proc/place_upgrade_from_map(mob/living/user, list/params)
	var/upgrade_id = params["id"]
	var/denial = outpost.upgrade_blueprint_denial(user, upgrade_id)
	if(denial)
		return denial
	var/x = params["x"]
	var/y = params["y"]
	var/rotation = params["rotation"]
	if(!isnum(x) || !isnum(y) || !(rotation in list(0, 90, 180, 270)))
		return "Invalid position."
	var/z = outpost.upgrade_level_z()
	var/turf/bottom_left = z && locate(round(x), round(y), z)
	if(!bottom_left)
		return "Invalid position."
	var/datum/outpost_upgrade/blueprint = outpost.outpost_upgrades[upgrade_id]
	var/error = outpost.place_outpost_upgrade(blueprint, bottom_left, rotation, user)
	if(!error)
		to_chat(user, span_notice("[blueprint.name] installed."))
	return error

#undef UPGRADE_CELL_SPACE
#undef UPGRADE_CELL_LATTICE
#undef UPGRADE_CELL_FLOOR
#undef UPGRADE_CELL_WALL
#undef UPGRADE_CELL_WINDOW
#undef UPGRADE_CELL_DOOR
#undef UPGRADE_CELL_OBJECT
#undef UPGRADE_CELL_RESERVED
#undef UPGRADE_SURVEY_WINDOW
#undef OUTPOST_UPGRADE_PREVIEW_DIR
