/**
 * # Warden tools: the talk menu
 *
 * Owner: XC (extras-plan.md 4.8). A member of the wing (is_member()), not in combat mode, right
 * clicks an awake prisoner with an empty hand: a radial menu opens with three choices, then any
 * other package's (talk_menu_extra_choices(): XF's pat-down, XG's questions), whose picks go to
 * talk_menu_extra_act(). Visitors get no menu.
 *
 * Each of the three is a short talk face to face (PRISON_TALK_MENU_TIME), which holds their
 * routine and any threat as a talk-down does, and nobody in trouble or below
 * PRISONER_TALK_MIN_MOOD will have it:
 * - "How are you doing?": their biggest complaint, or that they're fine. No mood change.
 * - "What are you in for?": their crime, and a small lift the first time in a stay.
 * - "Back to your cell": a request, not an order they must obey. At or above their line (by
 *   personality, lower for a fair member, higher for a brute) they go and sit on their bed for a
 *   minute or so; below it they refuse. Asking a third time inside PRISON_TALK_ORDER_SPAM_WINDOW
 *   costs mood and is refused. Forcing someone back is still the baton, the drag and the bolts.
 * Numbers in voidcrew/_DEFINES/outpost_prison_social.dm.
 */

// What an activity's tick() wants when it is over, as in outpost_prison_routine.dm (which undefines its own)
#define ACTIVITY_DONE 1

/mob/living/basic/outpost_prisoner
	/// Between answers to "How are you doing?" and "What are you in for?"
	COOLDOWN_DECLARE(ask_how_cooldown)
	COOLDOWN_DECLARE(ask_crime_cooldown)
	/// Between orders back to the cell
	COOLDOWN_DECLARE(order_cooldown)
	/// Whether they've been asked what they're in for this stay; the lift from it comes once
	var/asked_crime = FALSE
	/// world.time of each recent order back to the cell, for PRISON_TALK_ORDER_SPAM_COUNT
	var/list/order_times

/// Registers the talk menu on the prisoner; called from setup_extras()
/mob/living/basic/outpost_prisoner/proc/setup_warden_tools()
	RegisterSignal(src, COMSIG_ATOM_ATTACK_HAND_SECONDARY, PROC_REF(on_talk_menu_click))

/// A right click with an empty hand: members get the menu, everyone else nothing
/mob/living/basic/outpost_prisoner/proc/on_talk_menu_click(datum/source, mob/living/user, list/modifiers)
	SIGNAL_HANDLER
	if(!istype(user) || user.combat_mode || is_outpost_prisoner(user) || !prison?.is_member(user))
		return NONE
	if(stat == DEAD || phase != PRISONER_PRESENT)
		return NONE
	if(activity?.sleeping)
		balloon_alert(user, "asleep")
		return COMPONENT_CANCEL_ATTACK_CHAIN
	if(!talk_menu_allowed(user))
		balloon_alert(user, "can't talk now")
		return COMPONENT_CANCEL_ATTACK_CHAIN
	// The radial menu sleeps until a pick.
	INVOKE_ASYNC(src, PROC_REF(talk_menu_open), user)
	return COMPONENT_CANCEL_ATTACK_CHAIN

/// Whether `user` may use the talk menu on them now: a member out of combat mode, and them awake, present and on their feet
/mob/living/basic/outpost_prisoner/proc/talk_menu_allowed(mob/living/user)
	if(!istype(user) || QDELETED(user) || user.stat != CONSCIOUS || user.combat_mode || is_outpost_prisoner(user))
		return FALSE
	if(QDELETED(src) || stat != CONSCIOUS || phase != PRISONER_PRESENT || can_be_dragged() || activity?.sleeping)
		return FALSE
	return !!prison?.is_member(user)

/// Shows the radial and runs the pick. Sleeps.
/mob/living/basic/outpost_prisoner/proc/talk_menu_open(mob/living/user)
	// Nothing to show a menu on.
	if(!user?.client)
		return
	var/list/choices = talk_menu_choices(user)
	var/choice = show_radial_menu(user, src, choices, custom_check = CALLBACK(src, PROC_REF(talk_menu_allowed), user), require_near = TRUE, tooltips = TRUE)
	if(!choice || QDELETED(src) || QDELETED(user))
		return
	talk_menu_act(user, choice)

/// The menu's choices, name -> image: its own three first, then other packages'
/mob/living/basic/outpost_prisoner/proc/talk_menu_choices(mob/living/user)
	var/static/list/own_choices
	if(!own_choices)
		own_choices = list(
			(PRISON_TALK_HOW) = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_talk"),
			(PRISON_TALK_CRIME) = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_lore"),
			(PRISON_TALK_CELL) = image(icon = /obj/structure/bed::icon, icon_state = /obj/structure/bed::icon_state),
		)
	var/list/choices = own_choices.Copy()
	var/list/extra = talk_menu_other_choices(user)
	for(var/choice in extra)
		if(!(choice in choices))
			choices[choice] = extra[choice]
	return choices

/// Other packages' choices for this prisoner and `user` (outpost_prison_extras.dm)
/mob/living/basic/outpost_prisoner/proc/talk_menu_other_choices(mob/living/user)
	var/list/extra = prison?.talk_menu_extra_choices(src, user)
	return islist(extra) ? extra : list()

/// Runs another package's choice; TRUE if one took it. May sleep.
/mob/living/basic/outpost_prisoner/proc/talk_menu_other_act(mob/living/user, choice)
	return prison ? prison.talk_menu_extra_act(src, user, choice) : FALSE

/// Runs a pick from the menu, checked again now that the menu is closed. May sleep.
/mob/living/basic/outpost_prisoner/proc/talk_menu_act(mob/living/user, choice)
	if(!talk_menu_allowed(user) || !user.Adjacent(src))
		return FALSE
	switch(choice)
		if(PRISON_TALK_HOW)
			return talk_menu_ask_how(user)
		if(PRISON_TALK_CRIME)
			return talk_menu_ask_crime(user)
		if(PRISON_TALK_CELL)
			return talk_menu_order(user)
	return talk_menu_other_act(user, choice)

/**
 * A moment face to face with `user`, as a talk-down has, holding their routine and any threat.
 * Anyone in trouble (fighting, rioting, loose, wrecking) or below PRISONER_TALK_MIN_MOOD won't
 * have it. Returns TRUE once the talk is done and they're still listening. Sleeps.
 */
/mob/living/basic/outpost_prisoner/proc/talk_menu_chat(mob/living/user)
	if(QDELETED(user))
		return FALSE
	if(talking)
		balloon_alert(user, "already talking")
		return FALSE
	if(!will_listen() || trouble)
		face_atom(user)
		say_context("talk_refuse")
		balloon_alert(user, "not listening")
		return FALSE
	talking = TRUE
	ai_controller?.CancelActions()
	face_atom(user)
	user.face_atom(src)
	var/finished = do_after(user, PRISON_TALK_MENU_TIME, target = src)
	talking = FALSE
	if(!finished || QDELETED(src) || stat != CONSCIOUS || phase != PRISONER_PRESENT)
		return FALSE
	if(!will_listen() || trouble)
		say_context("talk_refuse")
		return FALSE
	face_atom(user)
	return TRUE

// ===== "HOW ARE YOU DOING?" =====

/mob/living/basic/outpost_prisoner/proc/talk_menu_ask_how(mob/living/user)
	if(!COOLDOWN_FINISHED(src, ask_how_cooldown))
		balloon_alert(user, "just asked")
		return FALSE
	if(!talk_menu_chat(user))
		return FALSE
	COOLDOWN_START(src, ask_how_cooldown, PRISON_TALK_ASK_GAP)
	var/list/answer = talk_menu_complaint()
	say_context(answer[1], answer[2])
	return TRUE

/**
 * Their biggest complaint, as list(context, other): starving, hungry, filthy, dirty, hurt, locked
 * in, a dark cell, a dark wing, a dirty floor, no power, a rival (named when they can be), else fine.
 */
/mob/living/basic/outpost_prisoner/proc/talk_menu_complaint()
	var/list/needs = bubble_needs()
	if(hunger < PRISONER_HUNGER_STARVING)
		return list("ask_how_starving", null)
	if("hungry" in needs)
		return list("ask_how_hungry", null)
	if(uniform_grime >= PRISONER_GRIME_FILTHY)
		return list("ask_how_filthy", null)
	if("dirty" in needs)
		return list("ask_how_dirty", null)
	if("hurt" in needs)
		return list("ask_how_hurt", null)
	if(locked_in_seconds > OUTPOST_PRISON_LOCKED_IN_COMPLAINT)
		return list("ask_how_locked", null)
	if(prison)
		var/list/conditions = prison.conditions_payload()
		var/list/dark_cells = conditions["dark_cells"]
		if(cell && (cell.number in dark_cells))
			return list("ask_how_dark_cell", null)
		if(conditions["lit"] < PRISON_WING_MOOD_LINE)
			return list("ask_how_dark", null)
		if(conditions["clean"] < PRISON_WING_MOOD_LINE)
			return list("ask_how_dirty_floor", null)
		if(conditions["powered"] < 100)
			return list("ask_how_no_power", null)
		// Friends and rivals are outpost_prison_life.dm's.
		var/rival_name = prison.worst_rival_name(src)
		if(rival_name)
			return list("ask_how_rival", talk_menu_prisoner_named(rival_name))
	return list("ask_how_fine", null)

/// Another prisoner of theirs who goes by `first`, for naming them in a line, or null
/mob/living/basic/outpost_prisoner/proc/talk_menu_prisoner_named(first)
	for(var/mob/living/basic/outpost_prisoner/other in prison?.prisoners)
		if(other != src && other.speech_name() == first)
			return other
	return null

// ===== "WHAT ARE YOU IN FOR?" =====

/mob/living/basic/outpost_prisoner/proc/talk_menu_ask_crime(mob/living/user)
	if(!COOLDOWN_FINISHED(src, ask_crime_cooldown))
		balloon_alert(user, "just asked")
		return FALSE
	if(!talk_menu_chat(user))
		return FALSE
	COOLDOWN_START(src, ask_crime_cooldown, PRISON_TALK_ASK_GAP)
	say_context("ask_crime")
	if(!asked_crime)
		asked_crime = TRUE
		adjust_mood(PRISON_TALK_CRIME_MOOD)
	return TRUE

// ===== "BACK TO YOUR CELL" =====

/**
 * Asks them back to their cell. At or above their line they go (sent_to_cell); below it they
 * refuse. The PRISON_TALK_ORDER_SPAM_COUNT-th ask inside PRISON_TALK_ORDER_SPAM_WINDOW costs
 * PRISON_TALK_ORDER_SPAM_MOOD and is refused. Returns TRUE if they went.
 */
/mob/living/basic/outpost_prisoner/proc/talk_menu_order(mob/living/user)
	if(!COOLDOWN_FINISHED(src, order_cooldown))
		balloon_alert(user, "just asked them")
		return FALSE
	if(!talk_menu_chat(user))
		return FALSE
	COOLDOWN_START(src, order_cooldown, PRISON_TALK_ORDER_GAP)
	var/list/recent = list()
	for(var/when in order_times)
		if(world.time - when < PRISON_TALK_ORDER_SPAM_WINDOW)
			recent += when
	recent += world.time
	order_times = recent
	if(length(order_times) >= PRISON_TALK_ORDER_SPAM_COUNT)
		adjust_mood(-PRISON_TALK_ORDER_SPAM_MOOD)
		say_context("order_again")
		return FALSE
	if(mood < talk_menu_order_line(user))
		say_context("order_refuse")
		return FALSE
	var/datum/prisoner_activity/sent_to_cell/going = new(src)
	if(!going.setup())
		qdel(going)
		balloon_alert(user, "can't get to the cell")
		return FALSE
	say_context("order_comply")
	start_activity(going)
	prison?.add_log("[user.name] sent [real_name] back to cell [cell?.number || "-"].")
	return TRUE

/// The mood at or above which they go back when `user` asks: by personality, then by how the yard sees `user`
/mob/living/basic/outpost_prisoner/proc/talk_menu_order_line(mob/living/user)
	var/line = PRISON_TALK_ORDER_LINE
	switch(personality)
		if("grumpy")
			line = PRISON_TALK_ORDER_LINE_GRUMPY
		if("chatty")
			line = PRISON_TALK_ORDER_LINE_CHATTY
		if("quiet")
			line = PRISON_TALK_ORDER_LINE_QUIET
		if("cheerful")
			line = PRISON_TALK_ORDER_LINE_CHEERFUL
		if("nervous")
			line = PRISON_TALK_ORDER_LINE_NERVOUS
	switch(prison?.staff_label(user))
		if("fair")
			line += PRISON_TALK_ORDER_FAIR_SHIFT
		if("brute")
			line += PRISON_TALK_ORDER_BRUTE_SHIFT
	return line

/// Asked back to their cell: to their own bed, to sit on its edge for a minute or so
/datum/prisoner_activity/sent_to_cell
	name = "sent back to their cell"
	context = "sent_to_cell"
	weight = 0
	interruptible = FALSE
	min_duration = PRISON_SENT_TO_CELL_MIN
	max_duration = PRISON_SENT_TO_CELL_MAX
	var/datum/weakref/bed_ref

/datum/prisoner_activity/sent_to_cell/setup()
	var/datum/outpost_prison_cell/home = prisoner.cell
	if(!home)
		return FALSE
	if(!prisoner.walkable)
		prisoner.prison?.refresh_prisoner_reach(prisoner)
	if(!prisoner.walkable)
		return FALSE
	var/obj/structure/bed/bed = home.bed()
	var/turf/bed_turf = bed ? get_turf(bed) : null
	if(bed_turf && prisoner.walkable[bed_turf] && (bed_turf == prisoner.loc || !prisoner.tile_taken(bed_turf)) && claim(bed))
		bed_ref = WEAKREF(bed)
		spot = bed_turf
		return TRUE
	for(var/turf/tile as anything in home.turfs)
		if(prisoner.walkable[tile] && (tile == prisoner.loc || !prisoner.tile_taken(tile)))
			spot = tile
			return TRUE
	return FALSE

/datum/prisoner_activity/sent_to_cell/begin()
	. = ..()
	var/obj/structure/bed/bed = bed_ref?.resolve()
	if(bed && prisoner.loc == bed.loc)
		var/obj/machinery/door/door = prisoner.cell?.door()
		prisoner.sit_on_edge(door ? get_cardinal_dir(prisoner, door) : SOUTH)

/datum/prisoner_activity/sent_to_cell/tick(seconds)
	if(!prisoner.cell?.contains(prisoner))
		return ACTIVITY_DONE
	return ..()

#undef ACTIVITY_DONE
