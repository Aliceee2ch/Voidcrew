/// A registry snapshot deliberately serializes a small set of construction data.
/// It never calls admin-export hooks (silos emit stock) or turf get_save_vars (air).
GLOBAL_LIST_INIT(outpost_registry_infrastructure, typecacheof(list(
	/obj/machinery/door,
	/obj/machinery/atmospherics,
	/obj/machinery/disposal,
	/obj/machinery/power/apc,
	/obj/machinery/power/terminal,
	/obj/machinery/airalarm,
	/obj/machinery/firealarm,
	/obj/machinery/light,
	/obj/machinery/button,
	/obj/machinery/camera,
	/obj/machinery/power/shuttle_engine,
)))

/// Furniture and hull fittings, rather than biological/event/resource spawners.
GLOBAL_LIST_INIT(outpost_registry_structures, typecacheof(list(
	/obj/structure/window,
	/obj/structure/grille,
	/obj/structure/table,
	/obj/structure/rack,
	/obj/structure/closet,
	/obj/structure/chair,
	/obj/structure/bed,
	/obj/structure/cable,
	/obj/structure/disposalpipe,
	/obj/structure/lattice,
	/obj/structure/railing,
	/obj/structure/falsewall,
	/obj/structure/sign,
	/obj/structure/fans,
)))

/datum/hull_blueprint
	var/obj/structure/overmap/dynamic/player_outpost/outpost
	var/datum/weakref/source_ship
	var/captain_ckey
	var/ship_name
	var/saved_at
	var/tgm
	var/width
	var/height
	var/port_x
	var/port_y
	var/list/rooms = list()
	var/list/material_cost = list()
	var/busy = FALSE
	var/error

/datum/hull_blueprint/Destroy()
	if(outpost)
		outpost.hull_registry -= src
	var/obj/structure/overmap/ship/original = source_ship?.resolve()
	if(original?.hull_registration?.resolve() == src)
		original.hull_registration = null
	outpost = null
	source_ship = null
	tgm = null
	rooms = null
	return ..()

/// Hull-tier eligibility. Ports are handled separately and cannot carry NPC types.
/datum/hull_blueprint/proc/includes_object(obj/object)
	if(istype(object, /obj/structure/disposalholder) || object.flags_1 & HOLOGRAM_1)
		return FALSE
	return is_type_in_typecache(object, GLOB.outpost_registry_structures) || is_type_in_typecache(object, GLOB.outpost_registry_infrastructure)

/// Preserve placement, wiring and access data; never inventory, gases or upgrades.
/datum/hull_blueprint/proc/atom_text(atom/object)
	var/list/properties = list()
	var/list/keys = list("dir", "color", "pixel_x", "pixel_y", "name")
	var/saved_type = object.type
	if(istype(object, /obj/structure/closet))
		// Restore storage shells without loot/spawner subtype initialization (some
		// emergency closets randomly delete or replace themselves even on reload).
		saved_type = /obj/structure/closet
		if(istype(object, /obj/structure/closet/crate))
			saved_type = /obj/structure/closet/crate
			keys += list("lid_icon", "lid_icon_state")
		else if(istype(object, /obj/structure/closet/secure_closet))
			saved_type = /obj/structure/closet/secure_closet
		keys += list("icon", "icon_door", "base_icon_state", "enable_door_overlay", "has_opened_overlay", "has_closed_overlay", "wall_mounted", "horizontal", "locked", "req_one_access")
		// Closet stock is otherwise generated lazily on first opening.
		properties += "contents_initialized = 1"
	if(istype(object, /obj/machinery/light))
		// Lights otherwise materialize a charged mock battery after map loading.
		properties += "start_with_cell = 0"
	if(!object.smoothing_flags)
		keys += "icon_state"
	if(isobj(object))
		keys += list("anchored", "req_access", "id_tag")
	if(istype(object, /obj/machinery/atmospherics))
		keys += list("piping_layer", "pipe_color")
	for(var/key in keys)
		var/value = object.vars[key]
		// Always encode direction: an oriented source must survive a round trip.
		if(saved_type == object.type && key != "dir" && value == initial(object.vars[key]))
			continue
		if(istext(value))
			value = replacetext(value, "\\", "")
		var/encoded = tgm_encode(value)
		if(encoded)
			properties += "[key] = [encoded]"
	return "[saved_type]{\n\t[properties.Join(";\n\t")]\n\t}"

/// Conservative, stable Hull-tier build estimates in sheets, paid at 25%.
/// Kept with serialization so excluded machinery/items never increase the quote.
/datum/hull_blueprint/proc/add_build_cost(atom/object)
	var/iron = 1
	var/glass = 0
	if(isclosedturf(object))
		iron = 4
	else if(istype(object, /obj/structure/window))
		iron = 0
		glass = 2
	else if(istype(object, /obj/machinery/door))
		iron = 4
	else if(ismachinery(object))
		iron = 5
	else if(isspaceturf(object))
		iron = 0
	material_cost[/datum/material/iron] += iron * SHEET_MATERIAL_AMOUNT
	material_cost[/datum/material/glass] += glass * SHEET_MATERIAL_AMOUNT

/// Capture only this port's owned tiles, including its docking tile and hull holes.
/datum/hull_blueprint/proc/capture(obj/structure/overmap/ship/ship, mob/living/captain)
	var/obj/docking_port/mobile/voidcrew/port = ship?.shuttle
	if(QDELETED(port) || !ship.is_ship_captain(captain) || !captain.ckey)
		return "The ship's captain must register its hull."
	if(port.z_levels_above || port.z_levels_below)
		return "The registry currently supports single-level hulls only."
	var/list/bounds = port.return_coords()
	var/min_x = min(bounds[1], bounds[3])
	var/min_y = min(bounds[2], bounds[4])
	width = abs(bounds[3] - bounds[1]) + 1
	height = abs(bounds[4] - bounds[2]) + 1
	if(max(width, height) > RESERVE_DOCK_MAX_SIZE_LONG || min(width, height) > RESERVE_DOCK_MAX_SIZE_SHORT)
		return "This hull is too large for a ship bay."
	port_x = port.x - min_x + 1
	port_y = port.y - min_y + 1
	var/list/owned_areas = hull_owned_areas(port)
	var/list/area_ids = list()
	var/list/headers = list()
	var/list/header_keys = list()
	var/list/columns = list()
	var/ports_found = 0
	for(var/local_x in 1 to width)
		var/list/column = list()
		for(var/local_y in height to 1 step -1)
			CHECK_TICK
			var/turf/tile = locate(min_x + local_x - 1, min_y + local_y - 1, port.z)
			var/area/room = get_area(tile)
			var/list/atoms = list()
			if(!(room in owned_areas))
				atoms = list("/turf/template_noop", "/area/template_noop")
			else
				if(!isfloorturf(tile) && !iswallturf(tile) && !isspaceturf(tile))
					return "Replace the hull's [tile.name] terrain with constructed flooring before registration."
				var/room_id = area_ids[room]
				if(!room_id)
					rooms += list(list("name" = room.name, "type" = room.type, "tiles" = list()))
					room_id = length(rooms)
					area_ids[room] = room_id
				var/list/room_data = rooms[room_id]
				var/list/room_tiles = room_data["tiles"]
				room_tiles += list(list(local_x, local_y))
				for(var/obj/object in tile)
					if(istype(object, /obj/docking_port/mobile))
						if(object != port)
							return "Another mobile docking port overlaps this hull."
						ports_found++
						// Rebuild a player port, never an NPC/event-specific port subtype.
						atoms += "/obj/docking_port/mobile/voidcrew{\n\tdir = [port.dir];\n\tarea_type = [port.area_type];\n\tpreferred_direction = [port.preferred_direction];\n\tport_direction = [port.port_direction]\n\t}"
					else if(includes_object(object))
						atoms += atom_text(object)
						add_build_cost(object)
				atoms += atom_text(tile)
				atoms += "[room.type]"
				add_build_cost(tile)
			var/header = "(\n[atoms.Join(",\n")])\n"
			var/map_key = header_keys[header]
			if(!map_key)
				map_key = calculate_tgm_header_index(length(headers) + 1, 3)
				header_keys[header] = map_key
				headers += "\"[map_key]\" = [header]"
			column += map_key
		columns += "\n([local_x],1,1) = {\"\n[column.Join("\n")]\n\"}"
	if(ports_found != 1)
		return "The ship's mobile docking port is outside its hull."
	if(QDELETED(ship) || QDELETED(port))
		return "The source hull is no longer available."
	tgm = "//[DMM2TGM_MESSAGE]\n[headers.Join()][columns.Join()]"
	if(length(tgm) > OUTPOST_REGISTRY_MAX_TEXT)
		return "The hull design exceeds registry capacity."
	var/datum/parsed_map/validated = new(tgm)
	var/valid = validated.bounds?[MAP_MAXX] == width && validated.bounds?[MAP_MAXY] == height
	qdel(validated)
	if(!valid)
		return "The hull design could not be read back. No payment was taken."
	for(var/material in material_cost.Copy())
		var/sheets = CEILING(material_cost[material] * OUTPOST_REGISTRY_MATERIAL_FRACTION / SHEET_MATERIAL_AMOUNT, 1)
		if(sheets)
			material_cost[material] = sheets * SHEET_MATERIAL_AMOUNT
		else
			material_cost -= material
	if(!length(material_cost))
		return "There is no recoverable hull to register."
	source_ship = WEAKREF(ship)
	captain_ckey = captain.ckey
	ship_name = ship.name
	saved_at = world.time
	return null

/// The commissioned template supplies ship ownership without a disk-backed map.
/datum/map_template/shuttle/voidcrew/commissioned/registry
	name = "Recovered Hull"
	abstract = /datum/map_template/shuttle/voidcrew/commissioned/registry
	var/datum/hull_blueprint/blueprint

/datum/map_template/shuttle/voidcrew/commissioned/registry/New(datum/hull_blueprint/snapshot)
	..()
	blueprint = snapshot
	if(!snapshot)
		return
	name = snapshot.ship_name
	shuttle_id = "registry_[REF(snapshot)]"
	cached_map = new /datum/parsed_map(snapshot.tgm)
	width = snapshot.width
	height = snapshot.height
	port_x_offset = snapshot.port_x
	port_y_offset = snapshot.port_y

/// Restore distinct player-built rooms before machines initialize their APC links.
/// A plain TGM load otherwise merges rooms sharing one /area type.
/datum/map_template/shuttle/voidcrew/commissioned/registry/initTemplateBounds(list/bounds)
	var/list/replaced_areas = list()
	for(var/list/room_data as anything in blueprint.rooms)
		var/area/room_type = room_data["type"]
		var/area/room = new room_type
		room.setup(room_data["name"])
		room.requires_power = TRUE
		for(var/list/coords as anything in room_data["tiles"])
			var/turf/tile = locate(bounds[MAP_MINX] + coords[1] - 1, bounds[MAP_MINY] + coords[2] - 1, bounds[MAP_MINZ])
			replaced_areas |= get_area(tile)
			tile.change_area(get_area(tile), room)
	for(var/area/old_room as anything in replaced_areas)
		if(!old_room.has_contained_turfs())
			qdel(old_room)
	return ..()
