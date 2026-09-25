/**
 * # Outpost prisoner
 *
 * An inmate of a player outpost's prison wing (outpost_prison_core.dm). Each prisoner owns one
 * cell, beams into it on arrival and out of it on release, and fills the time in between with the
 * routine in outpost_prison_routine.dm. They talk (outpost_prison_dialogue.dm), and when unhappy
 * they threaten, fight, riot and escape (outpost_prison_trouble.dm, outpost_prison_riot.dm).
 *
 * Needs, on 0-100 scales: `hunger` falls over time and food restores it; `uniform_grime` rises
 * over time and a cleaner prison uniform resets it. Health does not come back on its own; brute
 * medical stacks treat it. A thought bubble with the item they need shows when one needs
 * attention. They bleed when hit, and drip while badly hurt.
 *
 * Awake, they cannot be pulled, dragged onto things or boxed. Knocked down, in stamina crit or
 * dead, staff can drag them; stamina crit lasts PRISONER_STAMCRIT_TIME after the last hit.
 */

/// Trait source for the beam holding a prisoner still
#define PRISONER_BEAM_TRAIT "outpost_prisoner_beam"
/// Offset source for sitting on a bed edge
#define PRISONER_SITTING_OFFSET "outpost_prisoner_sitting"

/mob/living/basic/outpost_prisoner
	name = "prisoner"
	desc = "An inmate of the outpost's prison wing."
	icon = 'icons/mob/simple/simple_human.dmi'
	unique_name = FALSE
	combat_mode = FALSE
	mob_biotypes = MOB_ORGANIC | MOB_HUMANOID
	sentience_type = SENTIENCE_HUMANOID
	maxHealth = 100
	health = 100
	speed = 2
	// Awake they cannot be pulled; see update_drag_resistance().
	move_resist = MOVE_FORCE_VERY_STRONG
	density = TRUE
	basic_mob_flags = NONE
	// They lie down on beds, when knocked down and when dead.
	mobility_flags = MOBILITY_FLAGS_REST_CAPABLE_DEFAULT
	rotate_on_lying = TRUE
	blood_volume = BLOOD_VOLUME_NORMAL
	// Batons knock them down, as they do people.
	status_flags = CANPUSH | CANSTUN | CANKNOCKDOWN
	stamina_regen_time = PRISONER_STAMCRIT_TIME
	// No air needs yet: a breach must not kill the inmates.
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	response_help_continuous = "pats"
	response_help_simple = "pat"
	ai_controller = /datum/ai_controller/basic_controller/outpost_prisoner

	/// The prison holding them
	var/datum/outpost_prison/prison
	/// The cell they own
	var/datum/outpost_prison_cell/cell
	/// PRISONER_ARRIVING, PRISONER_PRESENT or PRISONER_LEAVING
	var/phase = PRISONER_PRESENT
	/// A personality from the dialogue file; shapes what they do and say
	var/personality
	/// What they are in for
	var/crime
	/// 100 is full, 0 is empty
	var/hunger = 100
	/// How dirty the uniform they are wearing is, 0 to 100
	var/uniform_grime = 0
	/// Seconds of sentence left
	var/sentence_left = 0
	/// Seconds served, and the same seconds weighted by care x conditions, for the release bonus
	var/served_seconds = 0
	var/kept_seconds = 0
	/// Seconds until a body is collected
	var/body_pickup_left = 0
	/// Seconds spent bolted into a cell, without a break; step 3's mood will read this
	var/locked_in_seconds = 0
	/// Outfit whose look they wear
	var/outfit_path
	/// Which thought bubble shows, if any
	var/bubble
	/// Which grime overlay they show: 0 none, 1 dirty, 2 filthy
	var/grime_stage = 0
	/// What they are carrying, held in their contents
	var/obj/item/held_item
	/// What they are doing now
	var/datum/prisoner_activity/activity
	/// The type of the last thing they did, so they vary it
	var/last_activity_type
	/// Activity types they gave up on, until world.time
	var/list/activity_cooldowns
	/// Tiles they can walk to (turf = TRUE), refreshed by the prison
	var/list/walkable
	/// Tiles they can walk to or reach into from one (turf = TRUE)
	var/list/reachable
	/// The last thing they said, so they don't repeat it at once
	var/last_line
	/// Whether they have said they are nearly out
	var/said_release_soon = FALSE
	/// Health at the last update, to notice treatment
	var/last_health = 100
	COOLDOWN_DECLARE(speech_cooldown)
	COOLDOWN_DECLARE(thanks_cooldown)
	/// Running while someone is putting a dressing on them
	COOLDOWN_DECLARE(treatment_window)

/mob/living/basic/outpost_prisoner/Initialize(mapload)
	gender = pick(MALE, FEMALE)
	. = ..()
	real_name = generate_random_name_species_based(gender, TRUE, /datum/species/human)
	name = real_name
	hunger = rand(70, 100)
	uniform_grime = rand(0, 20)
	var/list/personalities = outpost_prisoner_dialogue("personalities")
	personality = length(personalities) ? pick(personalities) : "quiet"
	var/list/crimes = outpost_prisoner_dialogue("crimes")
	crime = length(crimes) ? pick(crimes) : "unpaid docking fees"
	outfit_path = pick(/datum/outfit/outpost_prisoner, /datum/outfit/outpost_prisoner/glasses, /datum/outfit/outpost_prisoner/beanie)
	INVOKE_ASYNC(src, PROC_REF(build_look))
	// One shared list: element arguments are keyed by list reference.
	var/static/list/edible_types = list(/obj/item/food)
	AddElement(/datum/element/basic_eating, food_types = edible_types)
	RegisterSignal(src, COMSIG_MOB_PRE_EAT, PROC_REF(on_pre_eat))
	RegisterSignal(src, COMSIG_MOB_ATE, PROC_REF(on_ate))
	RegisterSignal(src, COMSIG_ATOM_ITEM_INTERACTION, PROC_REF(on_item_interaction))
	RegisterSignal(src, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_damaged))
	RegisterSignal(src, COMSIG_LIVING_HEALTH_UPDATE, PROC_REF(on_health_update))
	// Dragging and pulling only while they are down; see can_be_dragged().
	RegisterSignal(src, COMSIG_MOUSEDROP_ONTO, PROC_REF(block_being_dragged))
	RegisterSignal(src, COMSIG_ATOM_CAN_BE_PULLED, PROC_REF(check_pullable))
	// Changes to being down reach update_drag_resistance() through the living trait handlers
	// overridden below; registering those trait signals here would replace living's own.
	ADD_TRAIT(src, TRAIT_NO_CONTAINMENT, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_NO_STORAGE_INSERT, INNATE_TRAIT)
	setup_trouble()
	setup_containment()
	last_health = health

/mob/living/basic/outpost_prisoner/Destroy()
	end_activity(cancel_ai = FALSE)
	clear_trouble()
	if(held_item)
		held_item.forceMove(drop_location())
	prison?.forget(src)
	prison = null
	cell = null
	walkable = null
	reachable = null
	return ..()

/mob/living/basic/outpost_prisoner/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == held_item)
		held_item = null
		update_appearance(UPDATE_OVERLAYS)

/mob/living/basic/outpost_prisoner/proc/build_look()
	set_dynamic_human_appearance(list(src, outfit_path))
	update_appearance(UPDATE_OVERLAYS)

/// Their first name, for dialogue. (Not called first_name(): inside it, that would call itself.)
/mob/living/basic/outpost_prisoner/proc/speech_name()
	return first_name(real_name)

// ===== BEAMING IN AND OUT =====

/// Materialises them where they stand, with the transporter's column, sounds and knit-together
/mob/living/basic/outpost_prisoner/proc/beam_in()
	phase = PRISONER_ARRIVING
	alpha = 0
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, PRISONER_BEAM_TRAIT)
	update_bubble()
	var/turf/spot = get_turf(src)
	if(spot)
		playsound(spot, 'sound/effects/magic/teleport_diss.ogg', 40, TRUE)
		new /obj/effect/temp_visual/transporter_beam(spot, OUTPOST_PRISON_BEAM_TIME + 1.7 SECONDS)
	addtimer(CALLBACK(src, PROC_REF(finish_beam_in)), OUTPOST_PRISON_BEAM_TIME)

/mob/living/basic/outpost_prisoner/proc/finish_beam_in()
	if(phase != PRISONER_ARRIVING)
		return
	phase = PRISONER_PRESENT
	REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, PRISONER_BEAM_TRAIT)
	var/turf/spot = get_turf(src)
	if(spot)
		new /obj/effect/temp_visual/transporter_flash(spot)
		transporter_sparks(spot)
		playsound(spot, 'sound/effects/magic/teleport_app.ogg', 50, TRUE)
	transporter_materialise(src, 255)
	update_bubble()
	say_context("arrival")

/// Dematerialises them where they stand and deletes them at the end of the beam
/mob/living/basic/outpost_prisoner/proc/beam_out()
	if(phase == PRISONER_LEAVING)
		return
	phase = PRISONER_LEAVING
	end_activity()
	clear_trouble()
	drop_held_item()
	stand_up()
	pulledby?.stop_pulling()
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, PRISONER_BEAM_TRAIT)
	update_bubble()
	var/turf/spot = get_turf(src)
	if(spot)
		playsound(spot, 'sound/effects/magic/teleport_diss.ogg', 40, TRUE)
		new /obj/effect/temp_visual/transporter_beam(spot, OUTPOST_PRISON_BEAM_TIME + 0.5 SECONDS)
	new /obj/effect/abstract/particle_holder(src, /particles/transporter_motes, PARTICLE_ATTACH_MOB)
	transporter_dematerialise(src, OUTPOST_PRISON_BEAM_TIME)
	addtimer(CALLBACK(src, PROC_REF(finish_beam_out)), OUTPOST_PRISON_BEAM_TIME)

/mob/living/basic/outpost_prisoner/proc/finish_beam_out()
	var/turf/spot = get_turf(src)
	if(spot)
		new /obj/effect/temp_visual/transporter_flash/departure(spot)
		transporter_sparks(spot)
		playsound(spot, 'sound/effects/magic/teleport_app.ogg', 50, TRUE)
	qdel(src)

/// What the warden's roster calls them: present, arriving, leaving or dead
/mob/living/basic/outpost_prisoner/proc/console_status()
	if(stat == DEAD)
		return "dead"
	if(phase == PRISONER_ARRIVING)
		return "arriving"
	if(phase == PRISONER_LEAVING || sentence_left <= OUTPOST_PRISON_RELEASE_WALK)
		return "leaving"
	return "present"

// ===== DRAGGING =====

/// Staff may drag them only while they are down: knocked down, in stamina crit, out or dead
/mob/living/basic/outpost_prisoner/proc/can_be_dragged()
	// Floored but not buckled is on the floor; a bed floors them too, and that doesn't count.
	return stat != CONSCIOUS || HAS_TRAIT(src, TRAIT_INCAPACITATED) || (HAS_TRAIT(src, TRAIT_FLOORED) && !buckled)

/mob/living/basic/outpost_prisoner/proc/check_pullable(datum/source, mob/living/puller)
	SIGNAL_HANDLER
	return can_be_dragged() ? NONE : COMSIG_ATOM_CANT_PULL

/mob/living/basic/outpost_prisoner/proc/block_being_dragged(atom/over, mob/user)
	SIGNAL_HANDLER
	return can_be_dragged() ? NONE : COMPONENT_CANCEL_MOUSEDROP_ONTO

/mob/living/basic/outpost_prisoner/on_floored_trait_gain(datum/source)
	. = ..()
	update_drag_resistance()

/mob/living/basic/outpost_prisoner/on_floored_trait_loss(datum/source)
	. = ..()
	update_drag_resistance()

/mob/living/basic/outpost_prisoner/on_incapacitated_trait_gain(datum/source)
	. = ..()
	update_drag_resistance()

/mob/living/basic/outpost_prisoner/on_incapacitated_trait_loss(datum/source)
	. = ..()
	update_drag_resistance()

/mob/living/basic/outpost_prisoner/set_stat(new_stat)
	. = ..()
	update_drag_resistance()

/// Heavy while awake, so nobody shoves or pulls them about; ordinary while they are down
/mob/living/basic/outpost_prisoner/proc/update_drag_resistance()
	var/draggable = can_be_dragged()
	move_resist = draggable ? MOVE_RESIST_DEFAULT : MOVE_FORCE_VERY_STRONG
	if(!draggable)
		pulledby?.stop_pulling()
		return
	if(stat != DEAD && activity)
		// Knocked down mid-activity: whatever they were doing is over.
		INVOKE_ASYNC(src, PROC_REF(end_activity))
	if(in_trouble())
		// Stunned, beaten or dead: threats, climbs, fights and rioting stop too.
		INVOKE_ASYNC(src, PROC_REF(on_downed))

// ===== NEEDS =====

/// Time passing: hunger falls and the uniform gets dirtier
/mob/living/basic/outpost_prisoner/proc/adjust_needs(seconds)
	if(stat == DEAD)
		return
	hunger = clamp(hunger - PRISONER_HUNGER_DECAY * seconds / 60, 0, 100)
	uniform_grime = clamp(uniform_grime + PRISONER_GRIME_RATE * seconds / 60, 0, 100)
	update_bubble()

/mob/living/basic/outpost_prisoner/proc/set_hunger(amount)
	hunger = clamp(amount, 0, 100)
	update_bubble()

/mob/living/basic/outpost_prisoner/proc/set_uniform_grime(amount)
	uniform_grime = clamp(amount, 0, 100)
	update_bubble()

/// Fed, 0-100: full marks until they are hungry, then down to nothing when empty
/mob/living/basic/outpost_prisoner/proc/fed_factor()
	return hunger >= PRISONER_HUNGER_HUNGRY ? 100 : 100 * hunger / PRISONER_HUNGER_HUNGRY

/// Clean, 0-100: full marks until the uniform is dirty, then down to nothing at full grime
/mob/living/basic/outpost_prisoner/proc/clean_factor()
	return uniform_grime < PRISONER_GRIME_DIRTY ? 100 : 100 * (100 - uniform_grime) / (100 - PRISONER_GRIME_DIRTY)

/mob/living/basic/outpost_prisoner/proc/health_factor()
	return stat == DEAD ? 0 : clamp(100 * health / maxHealth, 0, 100)

/// Care, 0-100: the mean of fed, clean and health
/mob/living/basic/outpost_prisoner/proc/care()
	return (fed_factor() + clean_factor() + health_factor()) / 3

/// What their needs do to their mood per minute: list(gain, loss), before personality
/mob/living/basic/outpost_prisoner/proc/needs_mood_per_minute()
	var/loss = 0
	if(hunger < PRISONER_HUNGER_STARVING)
		loss += PRISONER_MOOD_STARVING
	else if(hunger < PRISONER_HUNGER_HUNGRY)
		loss += PRISONER_MOOD_HUNGRY
	if(uniform_grime >= PRISONER_GRIME_FILTHY)
		loss += PRISONER_MOOD_FILTHY
	else if(uniform_grime >= PRISONER_GRIME_DIRTY)
		loss += PRISONER_MOOD_DIRTY
	var/missing = 1 - health_factor() / 100
	if(missing > 0)
		loss += PRISONER_MOOD_HURT * missing
	return list(0, loss)

/mob/living/basic/outpost_prisoner/proc/wants_food()
	return stat == CONSCIOUS && hunger < PRISONER_HUNGER_SEEK

/mob/living/basic/outpost_prisoner/proc/wants_clean_uniform()
	return stat == CONSCIOUS && uniform_grime >= PRISONER_GRIME_DIRTY

/// Whether they would take this off the floor or the hatch and change into it
/mob/living/basic/outpost_prisoner/proc/would_change_into(obj/item/thing)
	var/obj/item/clothing/under/rank/prisoner/outpost/fresh = thing
	return istype(fresh) && wants_clean_uniform() && fresh.grime < PRISONER_GRIME_DIRTY && fresh.grime < uniform_grime

// ===== THOUGHT BUBBLE =====

/**
 * The need their thought bubble shows, if any. One at a time, most urgent first, and only when
 * something needs attention: rioting or loose (a shiv), then hungry, hurt and dirty. Step 4's
 * experiments ("experiment", a syringe) go between the shiv and hunger.
 */
/mob/living/basic/outpost_prisoner/proc/wanted_bubble()
	if(stat == DEAD || phase != PRISONER_PRESENT)
		return null
	if(is_rioting() || trouble == PRISONER_TROUBLE_LOOSE)
		return "riot"
	if(hunger < PRISONER_HUNGER_HUNGRY)
		return "hungry"
	if(health_factor() < PRISONER_INJURED_BELOW)
		return "hurt"
	if(uniform_grime >= PRISONER_GRIME_DIRTY)
		return "dirty"
	return null

/// Redraws only when the bubble or the grime stage changes
/mob/living/basic/outpost_prisoner/proc/update_bubble()
	var/new_bubble = wanted_bubble()
	var/new_stage = 0
	if(stat != DEAD)
		if(uniform_grime >= PRISONER_GRIME_FILTHY)
			new_stage = 2
		else if(uniform_grime >= PRISONER_GRIME_DIRTY)
			new_stage = 1
	if(new_bubble == bubble && new_stage == grime_stage)
		return
	bubble = new_bubble
	grime_stage = new_stage
	update_appearance(UPDATE_OVERLAYS)

/mob/living/basic/outpost_prisoner/update_overlays()
	. = ..()
	if(grime_stage)
		var/mutable_appearance/grime = mutable_appearance('icons/effects/blood.dmi', "uniformblood")
		grime.color = "#5a4630"
		grime.alpha = grime_stage == 2 ? 200 : 130
		. += grime
	if(grime_stage == 2)
		. += mutable_appearance('icons/effects/effects.dmi', "fly-surrounding", ABOVE_MOB_LAYER)
	if(held_item)
		var/mutable_appearance/carried = new(held_item.appearance)
		carried.plane = FLOAT_PLANE
		carried.layer = FLOAT_LAYER
		carried.dir = SOUTH
		carried.pixel_x = 0
		carried.pixel_y = 0
		carried.pixel_w = 7
		carried.pixel_z = -4
		carried.transform = matrix().Scale(0.6)
		. += carried
	if(bubble)
		. += thought_bubble(bubble)

/// tg's thought bubble, as a point uses, with the needed item's own sprite inset
/mob/living/basic/outpost_prisoner/proc/thought_bubble(need)
	var/mutable_appearance/bubble_look = mutable_appearance(
		'icons/effects/effects.dmi',
		"thought_bubble",
		offset_spokesman = src,
		plane = POINT_PLANE,
		appearance_flags = KEEP_APART | RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM,
	)
	var/mutable_appearance/item_look = outpost_prisoner_bubble_item(need)
	if(item_look)
		var/mutable_appearance/inset = new(item_look)
		inset.blend_mode = BLEND_INSET_OVERLAY
		inset.plane = FLOAT_PLANE
		inset.layer = FLOAT_LAYER
		inset.dir = SOUTH
		inset.pixel_x = 0
		inset.pixel_y = 0
		inset.pixel_w = 0
		inset.pixel_z = 0
		bubble_look.overlays += inset
	bubble_look.pixel_w = 14
	bubble_look.pixel_z = 22
	bubble_look.alpha = 220
	return bubble_look

/// The item a thought bubble shows for a need
/proc/outpost_prisoner_bubble_item_type(need)
	switch(need)
		if("hungry")
			return /obj/item/food/burger/plain
		if("dirty")
			return /obj/item/clothing/under/rank/prisoner
		if("hurt")
			return /obj/item/stack/medical/bruise_pack
		if("riot")
			return /obj/item/knife/shiv
		if("experiment")
			return /obj/item/reagent_containers/syringe
	return null

/// The look of a need's item, copied once from a real one so greyscale items come out right
/proc/outpost_prisoner_bubble_item(need)
	var/static/list/looks = list()
	if(looks[need])
		return looks[need]
	var/item_type = outpost_prisoner_bubble_item_type(need)
	if(!item_type)
		return null
	var/obj/item/sample = new item_type(null)
	var/mutable_appearance/look = new(sample.appearance)
	qdel(sample)
	looks[need] = look
	return look

// ===== HANDS =====

/// Picks up an item within reach and carries it
/mob/living/basic/outpost_prisoner/proc/take_item(obj/item/thing)
	if(held_item || QDELETED(thing))
		return FALSE
	thing.forceMove(src)
	if(thing.loc != src)
		return FALSE
	held_item = thing
	update_appearance(UPDATE_OVERLAYS)
	return TRUE

/// Puts down whatever they carry, on `where` or their own tile
/mob/living/basic/outpost_prisoner/proc/drop_held_item(atom/where)
	if(!held_item)
		return null
	var/obj/item/dropped = held_item
	dropped.forceMove(where || drop_location())
	return dropped

/**
 * Whether they can reach `thing` from where they stand. At a serving hatch they open their side
 * first: PRISONER_REACH_WAIT means it is opening.
 */
/mob/living/basic/outpost_prisoner/proc/try_reach(obj/item/thing)
	if(QDELETED(thing) || !isturf(thing.loc))
		return PRISONER_REACH_FAILED
	if(thing.loc == loc)
		return PRISONER_REACH_OK
	if(get_dist(src, thing) > 1)
		return PRISONER_REACH_FAILED
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in thing.loc
	if(hatch && !hatch.open_for_prisoner(src))
		var/obj/machinery/door/window/yard_door = hatch.yard_windoor()
		return (yard_door?.operating || yard_door?.hasPower()) ? PRISONER_REACH_WAIT : PRISONER_REACH_FAILED
	return Adjacent(thing) ? PRISONER_REACH_OK : PRISONER_REACH_FAILED

/// Sits on a chair, stool or toilet, facing `facing` if given
/mob/living/basic/outpost_prisoner/proc/sit_on(obj/structure/seat, facing)
	if(buckled != seat)
		if(loc != seat.loc)
			return FALSE
		stand_up()
		if(!seat.buckle_mob(src, force = TRUE))
			return FALSE
	if(facing)
		setDir(facing)
	return TRUE

/// Gets up from whatever they sit or lie on
/mob/living/basic/outpost_prisoner/proc/stand_up()
	remove_offsets(PRISONER_SITTING_OFFSET)
	buckled?.unbuckle_mob(src, force = TRUE)

/// Perches on the edge of the bed under them
/mob/living/basic/outpost_prisoner/proc/sit_on_edge(facing)
	add_offsets(PRISONER_SITTING_OFFSET, y_add = -4)
	if(facing)
		setDir(facing)

// ===== FOOD =====

/mob/living/basic/outpost_prisoner/proc/on_pre_eat(datum/source, atom/food, mob/living/feeder)
	SIGNAL_HANDLER
	if(stat != CONSCIOUS || phase != PRISONER_PRESENT || hunger >= PRISONER_HUNGER_FULL)
		if(feeder)
			balloon_alert(feeder, "not hungry")
		return COMSIG_MOB_CANCEL_EAT
	return NONE

/// Fed by hand
/mob/living/basic/outpost_prisoner/proc/on_ate(datum/source, atom/food, mob/living/feeder)
	SIGNAL_HANDLER
	set_hunger(hunger + PRISONER_FOOD_VALUE)
	adjust_mood(PRISONER_MOOD_FED)
	if(isturf(loc) && prob(50))
		new /obj/effect/decal/cleanable/food/crumbs(loc)
	if(feeder)
		INVOKE_ASYNC(src, PROC_REF(thank), "thanks_food")

/**
 * Finishes a meal: crumbs where they sat and, often, the wrapper or a tray left on the table.
 * `table_turf` is null when they ate standing up.
 */
/mob/living/basic/outpost_prisoner/proc/finish_meal(obj/item/food/meal, turf/seat_turf, turf/table_turf)
	if(QDELETED(meal))
		return FALSE
	set_hunger(hunger + PRISONER_FOOD_VALUE)
	adjust_mood(PRISONER_MOOD_FED)
	playsound(src, 'sound/items/eatfood.ogg', 30, TRUE)
	visible_message(span_notice("[src] finishes [meal]."))
	leave_meal_mess(meal, seat_turf || get_turf(src), table_turf || seat_turf || get_turf(src))
	qdel(meal)
	return TRUE

/// Crumbs on the floor, and often the food's wrapper or a tray where they ate
/mob/living/basic/outpost_prisoner/proc/leave_meal_mess(obj/item/food/meal, turf/floor, turf/table_turf)
	if(isopenturf(floor))
		new /obj/effect/decal/cleanable/food/crumbs(floor)
	if(!table_turf)
		return
	if(meal?.trash_type && prob(75))
		new meal.trash_type(table_turf)
	else if(prob(40))
		new /obj/item/trash/tray(table_turf)

// ===== UNIFORMS =====

/// Handing them a cleaner prison uniform: they change and hand the old one back
/mob/living/basic/outpost_prisoner/proc/on_item_interaction(datum/source, mob/living/user, obj/item/tool, list/modifiers)
	SIGNAL_HANDLER
	if(istype(tool, /obj/item/stack/medical))
		// Treatment only shows as health coming back once the dressing is on.
		COOLDOWN_START(src, treatment_window, 20 SECONDS)
		return NONE
	var/obj/item/clothing/under/rank/prisoner/outpost/offered = tool
	if(!istype(offered) || user.combat_mode || stat != CONSCIOUS)
		return NONE
	if(offered.grime >= uniform_grime)
		balloon_alert(user, "no cleaner than theirs")
		return ITEM_INTERACT_BLOCKING
	if(!user.temporarilyRemoveItemFromInventory(offered))
		return ITEM_INTERACT_BLOCKING
	var/obj/item/clothing/under/rank/prisoner/outpost/old = swap_uniform(offered, drop_location())
	// put_in_hands() can sleep (stack merging), which a signal handler must not.
	INVOKE_ASYNC(user, TYPE_PROC_REF(/mob, put_in_hands), old)
	visible_message(span_notice("[src] changes into the clean jumpsuit and hands [user] the old one."))
	INVOKE_ASYNC(src, PROC_REF(thank), "thanks_uniform")
	return ITEM_INTERACT_SUCCESS

/// Picks up a cleaner uniform within reach and changes, leaving the old one in its place
/mob/living/basic/outpost_prisoner/proc/take_uniform(obj/item/clothing/under/rank/prisoner/outpost/fresh)
	if(!would_change_into(fresh) || !isturf(fresh.loc) || !(fresh.loc == loc || Adjacent(fresh)))
		return FALSE
	var/turf/spot = fresh.loc
	swap_uniform(fresh, spot)
	visible_message(span_notice("[src] changes into a clean jumpsuit and leaves the old one behind."))
	return TRUE

/// Changes into `fresh` and returns their old uniform, created at `drop_spot`
/mob/living/basic/outpost_prisoner/proc/swap_uniform(obj/item/clothing/under/rank/prisoner/outpost/fresh, atom/drop_spot)
	var/obj/item/clothing/under/rank/prisoner/outpost/old = new(drop_spot)
	old.set_grime(uniform_grime)
	set_uniform_grime(fresh.grime)
	adjust_mood(PRISONER_MOOD_CLEAN_UNIFORM)
	qdel(fresh)
	return old

// ===== HURT AND TREATED =====

/// Blood on the floor from any real brute hit
/mob/living/basic/outpost_prisoner/proc/on_damaged(datum/source, damage_dealt, damagetype)
	SIGNAL_HANDLER
	if((damagetype == BRUTE || damagetype == BURN) && damage_dealt > 0)
		// Low enough and they collapse (outpost_prison_trouble.dm).
		INVOKE_ASYNC(src, PROC_REF(check_beaten))
	if(damagetype != BRUTE || damage_dealt < 3 || !isturf(loc))
		return
	add_splatter_floor(loc, damage_dealt < 10)

/mob/living/basic/outpost_prisoner/proc/on_health_update(datum/source)
	SIGNAL_HANDLER
	var/was = last_health
	last_health = health
	update_bubble()
	if(health > was && stat == CONSCIOUS && !COOLDOWN_FINISHED(src, treatment_window))
		COOLDOWN_RESET(src, treatment_window)
		adjust_mood(PRISONER_MOOD_TREATED)
		INVOKE_ASYNC(src, PROC_REF(thank), "thanks_treatment")

/// Badly hurt and untreated: now and then a drop of blood
/mob/living/basic/outpost_prisoner/proc/maybe_drip(seconds)
	if(stat == DEAD || !isturf(loc) || health_factor() >= PRISONER_BLEED_BELOW)
		return FALSE
	if(!SPT_PROB(3, seconds))
		return FALSE
	add_splatter_floor(loc, small_drip = TRUE)
	return TRUE

// ===== LEFT ALONE =====

/**
 * tg AI sleeps while no player is on the level, but hunger and grime keep ticking. So while
 * their AI is not running, a prisoner helps themself to food and clean uniforms within reach
 * without the walk. Called every few seconds by the prison.
 */
/mob/living/basic/outpost_prisoner/proc/fend_for_self()
	if(stat != CONSCIOUS || phase != PRISONER_PRESENT || !prison || ai_controller?.ai_status == AI_STATUS_ON || in_trouble())
		return
	if(wants_food())
		var/obj/item/food/meal = istype(held_item, /obj/item/food) ? held_item : prison.find_supply(src)
		if(meal)
			finish_meal(meal, get_turf(src), null)
	if(wants_clean_uniform())
		var/obj/item/clothing/under/rank/prisoner/outpost/fresh = prison.find_supply(src, TRUE)
		if(fresh && isturf(fresh.loc))
			swap_uniform(fresh, fresh.loc)

/// Leaves some dirt or a wrapper where they stand
/mob/living/basic/outpost_prisoner/proc/make_mess()
	var/turf/open/floor = loc
	if(!istype(floor))
		return
	if(prob(75))
		new /obj/effect/decal/cleanable/dirt(floor)
	else
		var/trash_type = pick(/obj/item/trash/candy, /obj/item/trash/chips, /obj/item/trash/raisins)
		new trash_type(floor)

/mob/living/basic/outpost_prisoner/death(gibbed)
	var/was_alive = stat != DEAD
	. = ..()
	if(was_alive && stat == DEAD)
		end_activity()
		drop_held_item()
		prison?.on_prisoner_death(src)
		update_bubble()

// ===== LOOK =====

/datum/outfit/outpost_prisoner
	name = "Outpost prisoner"
	uniform = /obj/item/clothing/under/rank/prisoner
	shoes = /obj/item/clothing/shoes/sneakers/orange

/datum/outfit/outpost_prisoner/glasses
	name = "Outpost prisoner (glasses)"
	glasses = /obj/item/clothing/glasses/regular

/datum/outfit/outpost_prisoner/beanie
	name = "Outpost prisoner (beanie)"
	head = /obj/item/clothing/head/beanie/orange

#undef PRISONER_BEAM_TRAIT
#undef PRISONER_SITTING_OFFSET
