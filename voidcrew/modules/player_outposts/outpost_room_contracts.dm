/**
 * # Room contracts
 *
 * What a placed upgrade room must hold for its code to work, as checks the style test runs on every
 * room map in every style and rotation (voidcrew_outpost_styles.dm). contract_problems() returns
 * one line per problem, and an empty list when the room works. It reads the room as placed, so it
 * catches what a map linter cannot: a machine that did not load, a gas loop that did not join, a
 * counter a customer can climb, a locker nobody can reach.
 */

/// Problems with this placed room (see the file comment)
/datum/outpost_upgrade/proc/contract_problems()
	. = list()
	if(!installed)
		. += "the room is not installed"

/// The placed room's turfs as a lookup, turf -> TRUE
/datum/outpost_upgrade/proc/room_lookup()
	. = list()
	if(!footprint_bounds)
		return
	for(var/turf/tile as anything in block(footprint_bounds[1], footprint_bounds[2], footprint_bounds[5], footprint_bounds[3], footprint_bounds[4], footprint_bounds[5]))
		.[tile] = TRUE

/datum/outpost_upgrade/service/contract_problems()
	. = ..()
	if(!installed)
		return
	var/list/inside = room_lookup()
	for(var/turf/tile as anything in inside)
		if(!istype(tile, /turf/open/indestructible) && !istype(tile, /turf/closed/indestructible))
			. += "a destructible [tile.type] at [tile.x],[tile.y]"
		if(tile.loc != outpost.outpost_area)
			. += "[tile.x],[tile.y] is outside the outpost's area"
		for(var/obj/thing in tile)
			if(istype(thing, /obj/machinery/power/apc) || istype(thing, /obj/machinery/light_switch) || istype(thing, /obj/structure/cable))
				. += "a [thing.type] at [tile.x],[tile.y]"
	var/list/routes = exit_routes()
	if(length(routes) != 1)
		. += "[length(routes)] ways out of the room, not 1"
	for(var/datum/weakref/door_ref as anything in doors)
		var/obj/machinery/door/airlock/outpost/service/door = door_ref.resolve()
		if(door && !door.unres_sides)
			. += "the [door.name] at [door.x],[door.y] has no side that always opens"
	if(exit_denial() == "Exit blocked")
		. += "the way out is blocked"
	var/turf/start = length(routes) ? routes[1][1] : null
	if(!start)
		. += "no floor inside the entrance"
		return
	var/list/reached = outpost_room_walk(start, inside)
	for(var/turf/open/tile in inside)
		if(!reached[tile] && !tile.is_blocked_turf(exclude_mobs = TRUE))
			. += "the floor at [tile.x],[tile.y] cannot be reached"
	for(var/turf/tile as anything in inside)
		for(var/obj/thing in tile)
			if(outpost_room_interactable(thing) && !outpost_room_can_reach(thing, reached))
				. += "nobody can reach the [thing.name] at [tile.x],[tile.y]"

/**
 * The room tiles someone can walk to from `start` without leaving the room (`inside`), as a turf
 * lookup. Doors are walked through; with `block_staff` staff doors are walls, which is where a
 * visitor can go. Tables are walls here: climbing is checked on its own.
 */
/proc/outpost_room_walk(turf/start, list/inside, block_staff = FALSE)
	var/list/reached = list()
	reached[start] = TRUE
	var/list/queue = list(start)
	while(length(queue))
		var/turf/current = queue[length(queue)]
		queue.len--
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || reached[next] || !inside[next] || next.density)
				continue
			var/obj/machinery/door/airlock/outpost/service/door = locate() in next
			if(door)
				if(block_staff && door.door_policy == OUTPOST_DOOR_STAFF)
					continue
			else if(outpost_room_step_blocked(current, next))
				continue
			reached[next] = TRUE
			queue += next
	return reached

/// Whether something dense stands between two neighbouring tiles or on the second one
/proc/outpost_room_step_blocked(turf/source, turf/target)
	if(outpost_room_edge_blocked(source, target))
		return TRUE
	for(var/atom/movable/thing as anything in target)
		if(thing.density && !(thing.flags_1 & ON_BORDER_1))
			return TRUE
	return FALSE

/// Whether a window, railing or other border object blocks the edge between two neighbouring tiles
/proc/outpost_room_edge_blocked(turf/source, turf/target)
	var/direction = get_dir(source, target)
	for(var/obj/border in source)
		if((border.flags_1 & ON_BORDER_1) && border.density && border.dir == direction)
			return TRUE
	for(var/obj/border in target)
		if((border.flags_1 & ON_BORDER_1) && border.density && border.dir == REVERSE_DIR(direction))
			return TRUE
	return FALSE

/// Machines and lockers someone has to stand beside to use. Wall mounts, lights, pipes and doors are not.
/proc/outpost_room_interactable(obj/thing)
	if(istype(thing, /obj/structure/closet))
		return TRUE
	if(!ismachinery(thing) || istype(thing, /obj/machinery/door) || istype(thing, /obj/machinery/light) || istype(thing, /obj/machinery/atmospherics))
		return FALSE
	return !findtext("[thing.type]", "/directional")

/// Whether someone standing on a `reached` tile can use `thing`: from its own tile or one beside it
/proc/outpost_room_can_reach(obj/thing, list/reached)
	var/turf/place = get_turf(thing)
	if(reached[place])
		return TRUE
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(place, direction)
		if(reached[beside] && !outpost_room_edge_blocked(beside, place))
			return TRUE
	return FALSE

// ===== ROOMS =====

/datum/outpost_upgrade/service/cloning_bay/contract_problems()
	. = ..()
	if(installed && length(room_vats()) != OUTPOST_CLONING_BAY_VATS)
		. += "[length(room_vats())] vats, not [OUTPOST_CLONING_BAY_VATS]"

/datum/outpost_upgrade/service/storage/contract_problems()
	. = ..()
	if(installed && length(live_lockers()) != OUTPOST_STORAGE_LOCKERS)
		. += "[length(live_lockers())] lockers, not [OUTPOST_STORAGE_LOCKERS]"

/datum/outpost_upgrade/service/teleporter/contract_problems()
	. = ..()
	if(!installed)
		return
	var/obj/machinery/outpost_network_pad/pad = pad_ref?.resolve()
	if(!pad)
		. += "no network pad"
		return
	if(pad.network_host() != outpost || !pad.arrival_turf)
		. += "the pad is not linked"
		return
	if(pad.arrival_turf == get_turf(pad) || get_dist(pad, pad.arrival_turf) > 2)
		. += "the arrival spot is not beside the pad"
	if(!pad.pad_step_off_turf())
		. += "the pad has no free tile beside it"

/datum/outpost_upgrade/service/medical_lab/contract_problems()
	. = ..()
	if(!installed)
		return
	var/list/found = list()
	var/obj/machinery/atmospherics/components/unary/thermomachine/freezer
	var/list/cells = list()
	var/list/connectors = list()
	var/obj/machinery/atmospherics/components/trinary/filter/lab_filter
	for(var/turf/tile as anything in room_lookup())
		for(var/obj/machinery/machine in tile)
			found[machine.type] = (found[machine.type] || 0) + 1
			if(istype(machine, /obj/machinery/atmospherics/components/unary/thermomachine))
				freezer = machine
			else if(istype(machine, /obj/machinery/cryo_cell))
				cells += machine
			else if(istype(machine, /obj/machinery/atmospherics/components/unary/portables_connector))
				connectors += machine
			else if(istype(machine, /obj/machinery/atmospherics/components/trinary/filter))
				lab_filter = machine
			else if(istype(machine, /obj/machinery/computer/outpost_autosurgeon))
				var/obj/machinery/computer/outpost_autosurgeon/console = machine
				if(!console.find_slab())
					. += "the auto-surgeon console has no slab beside it"
	var/static/list/wanted = list(
		/obj/machinery/outpost_autosurgeon = 1,
		/obj/machinery/computer/outpost_autosurgeon = 1,
		/obj/machinery/computer/outpost_medlab_terminal = 1,
		/obj/machinery/sleeper/outpost/medical_lab = 2,
		/obj/machinery/cryo_cell/outpost_lab = 2,
	)
	for(var/machine_type in wanted)
		if(found[machine_type] != wanted[machine_type])
			. += "[found[machine_type] || 0] [machine_type], not [wanted[machine_type]]"
	var/datum/pipeline/loop = freezer?.parents[1]
	if(!loop)
		. += "the freezer is not on a pipe loop"
		return
	for(var/obj/machinery/cryo_cell/cell as anything in cells)
		if(cell.internal_connector?.gas_connector?.parents[1] != loop)
			. += "the cryo cell at [cell.x],[cell.y] is not on the freezer's loop"
	if(length(connectors) != 2)
		. += "[length(connectors)] canister connectors, not 2"
	for(var/obj/machinery/atmospherics/components/unary/portables_connector/port as anything in connectors)
		if(port.parents[1] != loop)
			. += "the connector at [port.x],[port.y] is not on the freezer's loop"
		if(!port.connected_device)
			. += "the connector at [port.x],[port.y] has no canister"
	if(!lab_filter || !(loop in lab_filter.parents))
		. += "the filter is not on the freezer's loop"

/datum/outpost_upgrade/service/shop/contract_problems()
	. = ..()
	if(!installed)
		return
	var/obj/machinery/outpost_shop_stock/stock = get_stock()
	var/obj/machinery/computer/outpost_shop_register/register = register_ref?.resolve()
	var/mob/living/basic/outpost_shop_bot/bot = get_bot()
	if(!stock || !register || !bot)
		. += "missing its [!stock ? "stock cabinet" : (!register ? "register" : "shop bot")]"
		return
	var/list/routes = exit_routes()
	var/turf/start = length(routes) ? routes[1][1] : null
	if(!start)
		return
	var/list/inside = room_lookup()
	var/list/customer = outpost_room_walk(start, inside, block_staff = TRUE)
	var/list/staff = outpost_room_walk(start, inside)
	for(var/turf/near in range(1, stock))
		if(customer[near])
			. += "a customer can stand beside the stock cabinet, at [near.x],[near.y]"
	if(!outpost_room_can_reach(stock, staff))
		. += "staff cannot reach the stock cabinet"
	if(customer[get_turf(bot)])
		. += "customers can walk up to the shop bot"
	var/served = FALSE
	for(var/direction in GLOB.cardinals)
		var/turf/front = get_step(register, direction)
		if(customer[front] && !outpost_room_edge_blocked(front, get_turf(register)))
			served = TRUE
	if(!served)
		. += "no customer can step up to the register"
	var/seen = FALSE
	for(var/turf/near in range(OUTPOST_SHOP_COUNTER_RANGE, bot))
		if(customer[near] && can_see(near, bot, OUTPOST_SHOP_COUNTER_RANGE))
			seen = TRUE
			break
	if(!seen)
		. += "no customer can see the shop bot from the counter"
	for(var/turf/tile as anything in customer)
		for(var/direction in GLOB.cardinals)
			var/turf/counter = get_step(tile, direction)
			if(!counter || customer[counter] || !inside[counter] || !(locate(/obj/structure/table) in counter) || outpost_room_edge_blocked(tile, counter))
				continue
			for(var/beyond_direction in GLOB.cardinals)
				var/turf/beyond = get_step(counter, beyond_direction)
				if(staff[beyond] && !customer[beyond])
					. += "a customer can climb the counter at [counter.x],[counter.y]"
					break

/datum/outpost_upgrade/cargo_dock/contract_problems()
	. = ..()
	if(!installed)
		return
	if(QDELETED(pad))
		. += "no landing pad"
		return
	var/list/inside = room_lookup()
	for(var/turf/tile as anything in pad.return_turfs())
		if(!inside[tile])
			. += "the landing pad runs outside the room at [tile.x],[tile.y]"
			break
	var/atom/obstruction = pad.pad_obstruction()
	if(obstruction)
		. += "[obstruction] stands on the landing pad"
	if(!installed_area?.apc)
		. += "the dock has no APC"
