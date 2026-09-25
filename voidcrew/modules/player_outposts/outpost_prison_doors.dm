/**
 * # Prison wing doors
 *
 * The doors the prison wing's map places: the window doors on each side of a serving hatch, the
 * staff doors prisoners cannot use, the numbered cell doors and their bolt buttons. The window
 * doors and bolt buttons are protected outpost property; the airlocks can be broken. Where
 * prisoners can stand and what counts as their cell is in outpost_prison_containment.dm.
 */

// ===== SERVING HATCH WINDOW DOORS =====

/// The yard side of a serving hatch. Anyone may open it, prisoners included.
/obj/machinery/door/window/outpost_prison_yard
	name = "hatch window"
	desc = "The yard side of a serving hatch."

/obj/machinery/door/window/outpost_prison_yard/Initialize(mapload, set_dir, unres_sides)
	. = ..()
	AddElement(/datum/element/outpost_property)

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/door/window/outpost_prison_yard, 0)

/// The office side of a serving hatch. It opens for anyone but a prisoner; no ID needed.
/obj/machinery/door/window/brigdoor/outpost_prison_staff
	name = "hatch window"
	desc = "The office side of a serving hatch. It won't open for prisoners."

/obj/machinery/door/window/brigdoor/outpost_prison_staff/Initialize(mapload, set_dir, unres_sides)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/machinery/door/window/brigdoor/outpost_prison_staff/allowed(mob/accessor)
	if(is_outpost_prisoner(accessor))
		return FALSE
	return ..()

/obj/machinery/door/window/brigdoor/outpost_prison_staff/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	if(is_outpost_prisoner(pass_info.requester_ref?.resolve()))
		return FALSE
	return ..()

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/door/window/brigdoor/outpost_prison_staff, 0)

// ===== STAFF DOORS =====

/// The prison's office and entrance doors. Anyone may use them except the prisoners.
/obj/machinery/door/airlock/security/prison_staff
	name = "prison staff airlock"

/obj/machinery/door/airlock/security/prison_staff/allowed(mob/accessor)
	if(is_outpost_prisoner(accessor))
		return FALSE
	return ..()

// Open or closed, a prisoner cannot walk through, even dragged.
/obj/machinery/door/airlock/security/prison_staff/CanAllowThrough(atom/movable/mover, border_dir)
	if(is_outpost_prisoner(mover))
		return FALSE
	return ..()

/obj/machinery/door/airlock/security/prison_staff/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	if(is_outpost_prisoner(pass_info.requester_ref?.resolve()))
		return FALSE
	return ..()

/obj/machinery/door/airlock/security/prison_staff/glass
	opacity = FALSE
	glass = TRUE
	normal_integrity = 400

// ===== CELLS =====

/// A cell's front door. Prisoners come and go through it unless its bolt button bolts it.
/obj/machinery/door/airlock/security/glass/outpost_prison_cell
	name = "cell door"
	/// Which cell this door closes, set on the map
	var/cell_number = 0

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/Initialize(mapload)
	. = ..()
	if(cell_number)
		name = "Cell [cell_number]"

/// Bolts or unbolts the door of one cell of its own prison wing, found through the wing's prison.
/obj/machinery/button/outpost_prison_bolt
	name = "cell bolt button"
	desc = "Bolts or unbolts the door of the cell beside it."
	skin = "-warning"
	can_alter_skin = FALSE
	/// The cell whose door this button bolts, set on the map
	var/cell_number = 0

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/button/outpost_prison_bolt, 24)

/obj/machinery/button/outpost_prison_bolt/Initialize(mapload, ndir = 0, built = 0)
	. = ..()
	AddElement(/datum/element/outpost_property)
	if(cell_number)
		name = "cell [cell_number] bolt button"

/obj/machinery/button/outpost_prison_bolt/attempt_press(mob/user)
	. = ..()
	if(!.)
		return
	var/datum/outpost_prison/prison = get_outpost_prison(src)
	if(!prison?.toggle_cell_bolts(cell_number, user))
		balloon_alert(user, "no cell door")
		return FALSE
