/**
 * # Prison wing fixtures
 *
 * The pieces the prison wing's map places: uniforms that get dirty, the serving hatches, the
 * supply dispenser, the wing's first aid kit, bookcases, and a quieter basketball hoop and ball.
 * The machines have no circuit boards or designs and are protected outpost property, so they only
 * exist in a placed prison wing and never end up on a ship. The wing's doors and bolt buttons are
 * in outpost_prison_doors.dm.
 */

/// Whether this is an outpost prisoner
/proc/is_outpost_prisoner(atom/thing)
	return istype(thing, /mob/living/basic/outpost_prisoner)

// ===== UNIFORM =====

/// A prison jumpsuit that records how dirty it is. Only a washing machine gets it clean again.
/obj/item/clothing/under/rank/prisoner/outpost
	desc = "Standard issue for outpost prisoners, in an orange that shows every stain."
	has_sensor = NO_SENSORS
	sensor_mode = SENSOR_OFF
	random_sensor = FALSE
	// Dyeing would turn it into a different jumpsuit and lose the grime record.
	undyeable = TRUE
	flags_1 = parent_type::flags_1 | NO_NEW_GAGS_PREVIEW_1
	/// How dirty it is, from 0 (fresh) to 100
	var/grime = 0

/obj/item/clothing/under/rank/prisoner/outpost/proc/set_grime(amount)
	grime = clamp(amount, 0, 100)
	remove_atom_colour(FIXED_COLOUR_PRIORITY)
	if(grime >= PRISONER_GRIME_FILTHY)
		add_atom_colour("#9c8a6a", FIXED_COLOUR_PRIORITY)
	else if(grime >= PRISONER_GRIME_DIRTY)
		add_atom_colour("#c8b898", FIXED_COLOUR_PRIORITY)

/obj/item/clothing/under/rank/prisoner/outpost/examine(mob/user)
	. = ..()
	if(grime >= PRISONER_GRIME_FILTHY)
		. += span_warning("It's filthy.")
	else if(grime >= PRISONER_GRIME_DIRTY)
		. += span_notice("It's grimy.")
	else
		. += span_notice("It looks clean.")

/obj/item/clothing/under/rank/prisoner/outpost/machine_wash(obj/machinery/washing_machine/washer)
	. = ..()
	set_grime(0)

// ===== SERVING HATCH =====

/**
 * A reinforced counter set into the wall between the office and the yard, with a window door on
 * each side like a security front desk. Staff open their side, leave meals and clean clothes on
 * the counter and close it; prisoners open theirs and take them. Nobody climbs over it.
 *
 * It holds OUTPOST_PRISON_HATCH_CAPACITY items. Staff can't put more on it by hand or from a tray,
 * and anything dumped or thrown onto a full counter slides back off. A prisoner swapping a clean
 * uniform for their dirty one never counts against it.
 */
/obj/structure/table/reinforced/prison_hatch
	name = "serving hatch"
	desc = "A reinforced counter built into the wall, with a window door on each side. Meals and clean clothes go across it. People don't."
	pass_flags_self = LETPASSTHROW
	COOLDOWN_DECLARE(full_message_cooldown)

/obj/structure/table/reinforced/prison_hatch/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)
	// Notes which way the yard is, for when rioters smash a window door out (outpost_prison_breakout.dm)
	yard_windoor()
	staff_windoor()
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_counter_entered),
	)
	AddElement(/datum/element/connect_loc, loc_connections)

/obj/structure/table/reinforced/prison_hatch/examine(mob/user)
	. = ..()
	. += span_notice("It holds [stock_count()] of [OUTPOST_PRISON_HATCH_CAPACITY] items.")
	. += windoor_examine()

/// Items on the counter
/obj/structure/table/reinforced/prison_hatch/proc/stock_count()
	var/count = 0
	for(var/obj/item/thing in loc)
		if(!(thing.item_flags & ABSTRACT))
			count++
	return count

/// How many more items fit on the counter
/obj/structure/table/reinforced/prison_hatch/proc/room_left()
	return max(0, OUTPOST_PRISON_HATCH_CAPACITY - stock_count())

/obj/structure/table/reinforced/prison_hatch/table_place_act(mob/living/user, obj/item/tool, list/modifiers)
	if(!(tool.item_flags & ABSTRACT) && room_left() <= 0)
		balloon_alert(user, "the counter is full")
		return ITEM_INTERACT_BLOCKING
	. = ..()
	if(. == ITEM_INTERACT_SUCCESS && tool.loc == loc)
		get_outpost_prison(src)?.on_hatch_stocked(src, list(tool), user)

/obj/structure/table/reinforced/prison_hatch/tray_act(mob/living/user, obj/item/storage/bag/tray/used_tray)
	if(!length(used_tray.contents))
		return NONE
	var/room = room_left()
	if(room <= 0)
		balloon_alert(user, "the counter is full")
		return ITEM_INTERACT_BLOCKING
	var/list/moved = list()
	for(var/obj/item/thing in used_tray.contents)
		if(length(moved) >= room)
			break
		used_tray.atom_storage.attempt_remove(thing, loc)
		moved += thing
	used_tray.update_appearance()
	user.visible_message(span_notice("[user] empties [length(moved) < room ? "" : "some of "][used_tray] on [src]."))
	if(length(used_tray.contents))
		balloon_alert(user, "the counter is full")
	get_outpost_prison(src)?.on_hatch_stocked(src, moved, user)
	return ITEM_INTERACT_SUCCESS

/// Something landed on the counter: dumped, thrown or dropped there. Over capacity, it slides back off.
/obj/structure/table/reinforced/prison_hatch/proc/on_counter_entered(datum/source, atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	SIGNAL_HANDLER
	if(!isitem(arrived) || stock_count() <= OUTPOST_PRISON_HATCH_CAPACITY)
		return
	var/turf/back = get_turf(old_loc)
	if(!back || back == loc || isclosedturf(back))
		back = staff_side_turf()
	if(!back)
		return
	INVOKE_ASYNC(src, PROC_REF(push_off), arrived, back)

/obj/structure/table/reinforced/prison_hatch/proc/push_off(obj/item/thing, turf/back)
	if(QDELETED(thing) || thing.loc != loc || stock_count() <= OUTPOST_PRISON_HATCH_CAPACITY)
		return
	thing.forceMove(back)
	if(COOLDOWN_FINISHED(src, full_message_cooldown))
		COOLDOWN_START(src, full_message_cooldown, 1 SECONDS)
		visible_message(span_notice("[thing] slides off [src]. The counter is full."))

/obj/structure/table/reinforced/prison_hatch/make_climbable()
	return

/// The window door on the prisoners' side, if it is still there. Notes which way it faces (yard_dir).
/obj/structure/table/reinforced/prison_hatch/proc/yard_windoor()
	var/obj/machinery/door/window/yard_door = locate(/obj/machinery/door/window/outpost_prison_yard) in loc
	if(yard_door)
		yard_dir = yard_door.dir
	return yard_door

/// The window door on the staff side, if it is still there. Notes which way the yard is, if the yard side has not.
/obj/structure/table/reinforced/prison_hatch/proc/staff_windoor()
	var/obj/machinery/door/window/staff_door = locate(/obj/machinery/door/window/brigdoor/outpost_prison_staff) in loc
	if(staff_door && !yard_dir)
		yard_dir = REVERSE_DIR(staff_door.dir)
	return staff_door

/// Where a prisoner stands to reach across: the tile beyond the yard-side window door, or where it stood
/obj/structure/table/reinforced/prison_hatch/proc/yard_side_turf()
	var/obj/machinery/door/window/yard_door = yard_windoor()
	var/facing = yard_door ? yard_door.dir : yard_dir
	return facing ? get_step(src, facing) : null

/**
 * Whether both sides are open (or broken off), leaving a way over the counter. Nothing uses this
 * yet; step 3 has prisoners try to climb out when it is true.
 */
/obj/structure/table/reinforced/prison_hatch/proc/both_sides_open()
	var/obj/machinery/door/window/yard_door = yard_windoor()
	var/obj/machinery/door/window/staff_door = staff_windoor()
	return (!yard_door || !yard_door.density) && (!staff_door || !staff_door.density)

/**
 * A prisoner reaching for the counter: opens the yard side if it is shut. Returns TRUE once it is
 * all the way open (or missing), FALSE while it is opening or closing, or when it cannot open (no
 * power). A window door stops blocking partway through its opening animation; nothing is taken
 * across the counter until the animation has finished.
 */
/obj/structure/table/reinforced/prison_hatch/proc/open_for_prisoner(mob/living/prisoner)
	var/obj/machinery/door/window/yard_door = yard_windoor()
	if(!yard_door)
		return TRUE
	if(!yard_door.density)
		return !yard_door.operating
	if(!yard_door.operating && yard_door.hasPower() && yard_door.allowed(prisoner))
		// Opens, then shuts itself a few seconds later.
		INVOKE_ASYNC(yard_door, TYPE_PROC_REF(/obj/machinery/door/window, open_and_close))
	return FALSE

// ===== SUPPLY DISPENSER =====

/obj/item/food/prison_ration
	name = "prison ration"
	desc = "A dense protein bar in a plain wrapper. Filling, and that's all anyone says about it."
	icon = 'icons/obj/food/moth.dmi'
	icon_state = "sustenance_bar"
	trash_type = /obj/item/trash/fleet_ration
	food_reagents = list(/datum/reagent/consumable/nutriment = 10)
	tastes = list("cardboard" = 1)
	foodtypes = GRAIN
	w_class = WEIGHT_CLASS_SMALL

/**
 * The prison office's supplies, each billed to the outpost treasury: a ration into your hand, a
 * round of OUTPOST_PRISON_SERVE_ROUND rations straight onto the nearest serving hatch with room
 * (billed per ration placed), a bruise pack, or a prison uniform. The owner, stewards and
 * treasurers order freely; residents may order OUTPOST_PRISON_RESIDENT_ORDERS items per
 * OUTPOST_PRISON_RESIDENT_ORDER_WINDOW between them.
 */
/obj/machinery/outpost_ration_dispenser
	name = "supply dispenser"
	desc = "Prints rations, dressings and prison uniforms for the wing, billed to the outpost treasury. It can also put a round of rations straight onto a serving hatch."
	icon = 'icons/obj/machines/vending.dmi'
	icon_state = "sustenance"
	density = TRUE
	circuit = null
	use_power = IDLE_POWER_USE
	COOLDOWN_DECLARE(dispense_cooldown)

/obj/machinery/outpost_ration_dispenser/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/machinery/outpost_ration_dispenser/update_icon_state()
	if(machine_stat & BROKEN)
		icon_state = "sustenance-broken"
	else if(machine_stat & NOPOWER)
		icon_state = "sustenance-off"
	else
		icon_state = "sustenance"
	return ..()

/obj/machinery/outpost_ration_dispenser/examine(mob/user)
	. = ..()
	. += span_notice("A ration is [OUTPOST_PRISON_RATION_COST] cr, a bruise pack [OUTPOST_PRISON_BRUISE_PACK_COST] cr and a prison uniform [OUTPOST_PRISON_UNIFORM_COST] cr, from the outpost treasury.")

/obj/machinery/outpost_ration_dispenser/interact(mob/user)
	. = ..()
	if(!isliving(user))
		return
	var/list/choices = list()
	for(var/key in list("ration", "round", "bruise_pack", "uniform"))
		var/datum/radial_menu_choice/choice = new
		choice.name = "[order_name(key)] ([price_of(key)] cr[key == "round" ? " each" : ""])"
		choice.image = order_image(key)
		choices[key] = choice
	var/picked = show_radial_menu(user, src, choices, require_near = TRUE, tooltips = TRUE)
	if(!picked || QDELETED(src) || !user.Adjacent(src))
		return
	var/denial = order(user, picked)
	if(denial)
		balloon_alert(user, denial)
		playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 30, TRUE)

/// What an order is called
/obj/machinery/outpost_ration_dispenser/proc/order_name(key)
	switch(key)
		if("ration")
			return "Ration"
		if("round")
			return "Serve a round"
		if("bruise_pack")
			return "Bruise pack"
		if("uniform")
			return "Prison uniform"
	return null

/// What an order reads as on the treasury's history
/obj/machinery/outpost_ration_dispenser/proc/bill_text(key, count)
	switch(key)
		if("ration")
			return "Prison ration"
		if("round")
			return "Prison rations x[count], served to the hatch"
		if("bruise_pack")
			return "Prison bruise pack"
		if("uniform")
			return "Prison uniform"
	return "Prison supplies"

/// What an order costs, per item
/obj/machinery/outpost_ration_dispenser/proc/price_of(key)
	switch(key)
		if("ration", "round")
			return OUTPOST_PRISON_RATION_COST
		if("bruise_pack")
			return OUTPOST_PRISON_BRUISE_PACK_COST
		if("uniform")
			return OUTPOST_PRISON_UNIFORM_COST
	return 0

/// The radial menu picture of an order
/obj/machinery/outpost_ration_dispenser/proc/order_image(key)
	switch(key)
		if("ration")
			return image(icon = /obj/item/food/prison_ration::icon, icon_state = /obj/item/food/prison_ration::icon_state)
		if("round")
			return image(icon = /obj/item/storage/bag/tray::icon, icon_state = /obj/item/storage/bag/tray::icon_state)
		if("bruise_pack")
			return image(icon = /obj/item/stack/medical/bruise_pack::icon, icon_state = /obj/item/stack/medical/bruise_pack::icon_state)
		if("uniform")
			return outpost_prisoner_bubble_item("dirty")
	return null

/// Who may bill supplies to the treasury: the owner, stewards, treasurers and residents
/obj/machinery/outpost_ration_dispenser/proc/may_order(mob/living/user, obj/structure/overmap/dynamic/player_outpost/home)
	return home.can_manage(user) || home.can_spend(user) || (user.mind && (user.mind in home.residents))

/// Prints one ration into the user's hand. Returns null on success, else why not.
/obj/machinery/outpost_ration_dispenser/proc/dispense(mob/living/user)
	return order(user, "ration")

/**
 * Bills and prints one order ("ration", "round", "bruise_pack" or "uniform") for the user.
 * Everything is checked and paid before anything is made, with nothing in between that can wait.
 * Returns null on success, else why not.
 */
/obj/machinery/outpost_ration_dispenser/proc/order(mob/living/user, key)
	var/price = price_of(key)
	if(!price)
		return "no such order"
	if(!is_operational)
		return "no power"
	if(!COOLDOWN_FINISHED(src, dispense_cooldown))
		return "busy"
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
	if(!home)
		return "no outpost link"
	if(!may_order(user, home))
		return "residents only"
	var/datum/outpost_prison/prison = get_outpost_prison(src)
	var/count = key == "round" ? OUTPOST_PRISON_SERVE_ROUND : 1
	var/resident = !home.can_manage(user) && !home.can_spend(user)
	if(resident)
		count = min(count, prison ? prison.resident_orders_left() : 0)
		if(count <= 0)
			return "restocking"
	// A round goes onto the hatches, as far as they have room.
	var/list/obj/structure/table/reinforced/prison_hatch/hatches = key == "round" ? hatches_by_distance(prison) : null
	if(key == "round")
		var/room = 0
		for(var/obj/structure/table/reinforced/prison_hatch/hatch as anything in hatches)
			room += hatch.room_left()
		if(!length(hatches))
			return "no serving hatch"
		if(!room)
			return "the hatches are full"
		count = min(count, room)
	home.ensure_home_services()
	var/datum/bank_account/treasury = home.treasury
	if(!treasury)
		return "insufficient funds"
	count = min(count, round(treasury.account_balance / price))
	var/bill = bill_text(key, count)
	if(count <= 0 || !treasury.adjust_money(-price * count, "[bill], ordered by [user.ckey || user.name]"))
		return "insufficient funds"
	COOLDOWN_START(src, dispense_cooldown, OUTPOST_PRISON_ORDER_COOLDOWN)
	if(resident)
		prison.note_resident_orders(count)
	prison?.note_spending(price * count, bill)
	playsound(src, 'sound/machines/machine_vend.ogg', 40, TRUE)
	use_energy(active_power_usage)
	if(key == "round")
		serve_round(prison, hatches, count, user)
		return null
	var/obj/item/made
	switch(key)
		if("ration")
			made = new /obj/item/food/prison_ration(drop_location())
		if("bruise_pack")
			made = new /obj/item/stack/medical/bruise_pack(drop_location(), 1, FALSE)
		if("uniform")
			made = new /obj/item/clothing/under/rank/prisoner/outpost(drop_location())
	user.put_in_hands(made)
	return null

/// The prison's serving hatches, nearest this dispenser first
/obj/machinery/outpost_ration_dispenser/proc/hatches_by_distance(datum/outpost_prison/prison)
	var/list/unsorted = prison ? prison.hatches() : list()
	var/list/sorted = list()
	while(length(unsorted))
		var/obj/structure/table/reinforced/prison_hatch/nearest = unsorted[1]
		for(var/obj/structure/table/reinforced/prison_hatch/hatch as anything in unsorted)
			if(get_dist(src, hatch) < get_dist(src, nearest))
				nearest = hatch
		unsorted -= nearest
		sorted += nearest
	return sorted

/// Puts `count` paid-for rations on the hatches, nearest with room first, and lets the yard know
/obj/machinery/outpost_ration_dispenser/proc/serve_round(datum/outpost_prison/prison, list/hatches, count, mob/living/user)
	for(var/obj/structure/table/reinforced/prison_hatch/hatch as anything in hatches)
		if(count <= 0)
			break
		var/list/served = list()
		while(count > 0 && hatch.room_left() > 0)
			served += new /obj/item/food/prison_ration(hatch.loc)
			count--
		if(length(served))
			playsound(hatch, 'sound/machines/machine_vend.ogg', 30, TRUE)
			prison?.on_hatch_stocked(hatch, served, user)

/// Items residents may still order from the supply dispenser in the current window
/datum/outpost_prison/proc/resident_orders_left()
	for(var/ordered_at in resident_orders.Copy())
		if(world.time - ordered_at >= OUTPOST_PRISON_RESIDENT_ORDER_WINDOW)
			resident_orders -= ordered_at
	return max(0, OUTPOST_PRISON_RESIDENT_ORDERS - length(resident_orders))

/datum/outpost_prison/proc/note_resident_orders(count)
	for(var/i in 1 to count)
		resident_orders += world.time

// ===== FIRST AID =====

/// The wing's first aid kit: dressings only. Prisoners are treated without chemicals.
/obj/item/storage/medkit/brute/outpost_prison
	name = "prison first aid kit"
	desc = "Bruise packs, sutures and gauze for the prison wing."

/obj/item/storage/medkit/brute/outpost_prison/PopulateContents()
	if(empty)
		return
	var/static/items_inside = list(
		/obj/item/stack/medical/bruise_pack = 2,
		/obj/item/stack/medical/suture = 2,
		/obj/item/stack/medical/gauze = 1,
		/obj/item/healthanalyzer/simple = 1,
	)
	generate_items_inside(items_inside, src)

// ===== BOOKCASE =====

/**
 * A shelf of library books for the yard. With no library database to draw on, it makes up the
 * numbers with random manuals, so there is always something to read.
 */
/obj/structure/bookcase/random/outpost_prison
	name = "bookcase"
	books_to_load = 5
	/// Fewest books the shelf holds once it has loaded
	var/min_books = 4

/obj/structure/bookcase/random/outpost_prison/after_random_load()
	var/count = 0
	for(var/obj/item/book/book in src)
		count++
	for(var/i in count + 1 to min_books)
		new /obj/item/book/manual/random(src)
	update_appearance()

// ===== BASKETBALL =====

/// The yard's hoop. Prisoners shoot at it all day, so its buzzer is half as loud as tg's.
/obj/structure/hoop/outpost_prison
	buzzer_volume = 50

/// The yard's ball, bouncing half as loud as tg's
/obj/item/toy/basketball/outpost_prison
	bounce_volume = 37

// ===== MESS =====

/// What a meal leaves on the floor
/obj/effect/decal/cleanable/food/crumbs
	name = "crumbs"
	desc = "Someone ate here and didn't clean up after themselves."
	icon_state = "flour"
	color = "#a47a4a"
