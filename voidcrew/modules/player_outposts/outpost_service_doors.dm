/**
 * # Outpost service doors
 *
 * The airlocks of outpost service rooms (outpost_service_rooms.dm). Outpost members (the owner,
 * residents and the owner's crews) always pass. Visitors pass a public door while its room admits
 * visitors, and never a staff door. Every door opens from its unrestricted side, which the room map
 * points inside, so nobody is ever locked in.
 *
 * Every route that opens an airlock is checked: bumps, clicks, telekinesis and bots all come
 * through allowed(); thrown items, janitor keys, prying tools, emags and Knock each get their own
 * override below. The parent makes the door indestructible, unhackable and closed to the AI.
 */
/obj/machinery/door/airlock/outpost/service
	name = "service airlock"
	desc = "A glass airlock on an outpost's service room. The frame is rated for a lot more than a crowbar."
	icon = 'icons/obj/doors/airlocks/public/glass.dmi'
	overlays_file = 'icons/obj/doors/airlocks/public/overlays.dmi'
	opacity = FALSE
	glass = TRUE
	opens_with_door_remote = FALSE
	// Never set: a door button with a matching id opens, bolts and shocks it. adopt_doors() clears map edits.
	id_tag = null
	/// OUTPOST_DOOR_PUBLIC or OUTPOST_DOOR_STAFF
	var/door_policy = OUTPOST_DOOR_PUBLIC

/obj/machinery/door/airlock/outpost/service/medical
	name = "medical service airlock"
	icon = 'icons/obj/doors/airlocks/station/medical.dmi'
	overlays_file = 'icons/obj/doors/airlocks/station/overlays.dmi'

/obj/machinery/door/airlock/outpost/service/vault
	name = "vault service door"
	desc = "A heavy vault door on an outpost's service room."
	icon = 'icons/obj/doors/airlocks/vault/vault.dmi'
	overlays_file = 'icons/obj/doors/airlocks/vault/overlays.dmi'
	opacity = TRUE
	glass = FALSE

/obj/machinery/door/airlock/outpost/service/staff
	name = "staff airlock"
	desc = "An outpost airlock marked for staff."
	icon = 'icons/obj/doors/airlocks/station/command.dmi'
	overlays_file = 'icons/obj/doors/airlocks/station/overlays.dmi'
	opacity = TRUE
	glass = FALSE
	door_policy = OUTPOST_DOOR_STAFF

/// Whether this door opens for `user`
/obj/machinery/door/airlock/outpost/service/proc/admits(mob/user)
	if(!user)
		return FALSE
	if(isAdminGhostAI(user))
		return TRUE
	// Exits always open
	if(unrestricted_side(user))
		return TRUE
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
	if(!home)
		return door_policy == OUTPOST_DOOR_PUBLIC
	if(home.is_outpost_member(user))
		return TRUE
	if(door_policy == OUTPOST_DOOR_STAFF)
		return FALSE
	var/datum/outpost_upgrade/service/room = home.upgrade_at_turf(get_turf(src))
	if(!istype(room))
		return TRUE
	return room.visitors_allowed || room.admits_visitor_extra(user)

/// The room this door belongs to, if it stands in one
/obj/machinery/door/airlock/outpost/service/proc/service_room()
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
	var/datum/outpost_upgrade/service/room = home?.upgrade_at_turf(get_turf(src))
	return istype(room) ? room : null

// Never ..(): that would add emergency access, the resident override and req_access
/obj/machinery/door/airlock/outpost/service/allowed(mob/M)
	return admits(M)

// A thrown item opens a door by the door's own access check, never allowed(). Judge its thrower.
/obj/machinery/door/airlock/outpost/service/Bumped(atom/movable/AM)
	if(isitem(AM) && density && !operating)
		var/obj/item/item = AM
		if((item.w_class >= WEIGHT_CLASS_NORMAL || LAZYLEN(item.GetAccess())) && !admits(item.throwing?.get_thrower()))
			run_animation(DOOR_DENY_ANIMATION)
			return
	return ..()

// The janitor's access key bypasses access; not here
/obj/machinery/door/airlock/outpost/service/try_to_activate_door(mob/living/user, access_bypass = FALSE)
	if(access_bypass && !admits(user))
		access_bypass = FALSE
	return ..()

// Jaws, fireaxes and mech clamps pry doors open by force
/obj/machinery/door/airlock/outpost/service/try_to_crowbar(obj/item/tool, mob/living/user, forced = FALSE)
	if(!admits(user))
		if(user)
			balloon_alert(user, "won't budge!")
		return
	return ..()

/obj/machinery/door/airlock/outpost/service/emag_act(mob/user, obj/item/card/emag/emag_card)
	if(user)
		balloon_alert(user, "no effect!")
	return FALSE

/obj/machinery/door/airlock/outpost/service/on_magic_unlock(datum/source, datum/action/cooldown/spell/aoe/knock/spell, mob/living/caster)
	SIGNAL_HANDLER
	return

// A singularity or reality tear deletes any obj whatever its resistance flags (obj_defense.dm)
/obj/machinery/door/airlock/outpost/service/singularity_act()
	return 0

/obj/machinery/door/airlock/outpost/service/singularity_pull(atom/singularity, current_size)
	return

/obj/machinery/door/airlock/outpost/service/examine(mob/user)
	. = ..()
	if(door_policy == OUTPOST_DOOR_STAFF)
		. += span_notice("Staff only.")
		return
	var/datum/outpost_upgrade/service/room = service_room()
	if(room && !room.visitors_allowed)
		. += span_notice("Members only.")
