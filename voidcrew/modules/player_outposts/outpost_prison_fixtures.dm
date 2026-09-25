/**
 * # Prison wing fixtures
 *
 * The pieces the prison wing's map places: uniforms that get dirty, the serving hatches, the
 * ration dispenser, the wing's first aid kit and bookcases. The machines have no circuit boards or
 * designs and are protected outpost property, so they only exist in a placed prison wing and never
 * end up on a ship. The wing's doors and bolt buttons are in outpost_prison_doors.dm.
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
 */
/obj/structure/table/reinforced/prison_hatch
	name = "serving hatch"
	desc = "A reinforced counter built into the wall, with a window door on each side. Meals and clean clothes go across it. People don't."
	pass_flags_self = LETPASSTHROW

/obj/structure/table/reinforced/prison_hatch/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/structure/table/reinforced/prison_hatch/make_climbable()
	return

/// The window door on the prisoners' side, if it is still there
/obj/structure/table/reinforced/prison_hatch/proc/yard_windoor()
	return locate(/obj/machinery/door/window/outpost_prison_yard) in loc

/// The window door on the staff side, if it is still there
/obj/structure/table/reinforced/prison_hatch/proc/staff_windoor()
	return locate(/obj/machinery/door/window/brigdoor/outpost_prison_staff) in loc

/// Where a prisoner stands to reach across: the tile beyond the yard-side window door
/obj/structure/table/reinforced/prison_hatch/proc/yard_side_turf()
	var/obj/machinery/door/window/yard_door = yard_windoor()
	return yard_door ? get_step(src, yard_door.dir) : null

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
 * open (or missing), FALSE while it is opening or when it cannot open (no power).
 */
/obj/structure/table/reinforced/prison_hatch/proc/open_for_prisoner(mob/living/prisoner)
	var/obj/machinery/door/window/yard_door = yard_windoor()
	if(!yard_door || !yard_door.density)
		return TRUE
	if(!yard_door.operating && yard_door.hasPower() && yard_door.allowed(prisoner))
		// Opens, then shuts itself a few seconds later.
		INVOKE_ASYNC(yard_door, TYPE_PROC_REF(/obj/machinery/door/window, open_and_close))
	return FALSE

// ===== RATION DISPENSER =====

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

/// Prints rations for the prison office. Each one is billed to the outpost treasury.
/obj/machinery/outpost_ration_dispenser
	name = "ration dispenser"
	desc = "Prints plain prison rations, billed to the outpost treasury."
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
	. += span_notice("Each ration costs [OUTPOST_PRISON_RATION_COST] cr from the outpost treasury.")

/obj/machinery/outpost_ration_dispenser/interact(mob/user)
	. = ..()
	if(!isliving(user))
		return
	var/denial = dispense(user)
	if(denial)
		balloon_alert(user, denial)
		playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 30, TRUE)

/// Who may bill rations to the treasury: the owner, stewards, treasurers and residents
/obj/machinery/outpost_ration_dispenser/proc/may_order(mob/living/user, obj/structure/overmap/dynamic/player_outpost/home)
	return home.can_manage(user) || home.can_spend(user) || (user.mind && (user.mind in home.residents))

/// Prints one ration for the user. Returns null on success, else why not.
/obj/machinery/outpost_ration_dispenser/proc/dispense(mob/living/user)
	if(!is_operational)
		return "no power"
	if(!COOLDOWN_FINISHED(src, dispense_cooldown))
		return "busy"
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
	if(!home)
		return "no outpost link"
	if(!may_order(user, home))
		return "residents only"
	home.ensure_home_services()
	if(!home.treasury?.adjust_money(-OUTPOST_PRISON_RATION_COST, "Prison ration, ordered by [user.ckey || user.name]"))
		return "insufficient funds"
	COOLDOWN_START(src, dispense_cooldown, 1 SECONDS)
	var/obj/item/food/prison_ration/ration = new(drop_location())
	user.put_in_hands(ration)
	playsound(src, 'sound/machines/machine_vend.ogg', 40, TRUE)
	use_energy(active_power_usage)
	return null

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

// ===== MESS =====

/// What a meal leaves on the floor
/obj/effect/decal/cleanable/food/crumbs
	name = "crumbs"
	desc = "Someone ate here and didn't clean up after themselves."
	icon_state = "flour"
	color = "#a47a4a"
