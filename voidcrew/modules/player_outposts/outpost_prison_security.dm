/**
 * # Prison security: wing stun turrets
 *
 * Owner: XB (extras-plan.md 4.2). Up to two stun turrets bought at the warden's console and
 * mounted on cell-block walls facing in. They warn, then fire disabler beams only at violence
 * already under way, hatch climbers and prisoners loose in the wing, and only while a member is
 * home. Rioters go for them first. Numbers in voidcrew/_DEFINES/outpost_prison_security.dm.
 *
 * A turret belongs to the prison that sold it and does nothing for any other. It arrives loose and
 * switched off on the warden console's tile, and is dragged into a wall of the cell block from the
 * far side, so its muzzle looks into the cell block. Whether it may fire is checked again at every
 * look: the tile in front of it must still be cell-block floor a prisoner could stand on, and it
 * only answers a prisoner who could walk up to it, so nobody can wall it, table it or window it off
 * from the rioters it shoots. Carried off the outpost, it forgets the wing, so a stolen turret
 * frees its slot and one taken away and brought back never works again.
 *
 * What a turret answers: a prisoner of its own wing, on their feet in the wing, rioting (warned
 * during the riot's wind-up, fired on after), in a fight past the argument, swinging at staff,
 * climbing over a hatch, or loose in the wing. Never a calm, threatening, wrecking, downed or
 * confined prisoner, a player, a guard, the researcher or a creature. Its beams pass through
 * everyone else.
 */

/// portable_turret.dm #undefs its own TURRET_STUN, so the value is restated here
#define PRISON_TURRET_STUN 0
/// How often the prison checks its turrets are still on the outpost, in seconds
#define PRISON_TURRET_CHECK_SECONDS 10

/// Whether `thing` is a wing stun turret a prison sold
/proc/is_outpost_prison_stun_turret(atom/thing)
	return istype(thing, /obj/machinery/porta_turret/ship_defense/outpost_prison)

// ===== THE PRISON'S SIDE =====

/datum/outpost_prison
	/// Weakrefs to the stun turrets this wing sold that still answer to it: mounted, loose or broken
	var/list/stun_turrets = list()
	/// Seconds since the turrets were last checked for being carried off the outpost
	var/turret_check_clock = 0
	/// Between onlookers remarking on a turret hit, and between rioters shouting to go for one
	COOLDOWN_DECLARE(turret_hit_line_cooldown)
	COOLDOWN_DECLARE(turret_smash_line_cooldown)

/// Every few seconds: a turret carried off the outpost stops answering to the wing. The turrets' own looking and firing runs on the machine clock.
/datum/outpost_prison/proc/security_tick(seconds)
	turret_check_clock += seconds
	if(turret_check_clock < PRISON_TURRET_CHECK_SECONDS)
		return
	turret_check_clock = 0
	for(var/obj/machinery/porta_turret/ship_defense/outpost_prison/turret as anything in live_stun_turrets())
		if(get_outpost_from_atom(turret) == outpost)
			continue
		release_stun_turret(turret)
		add_log("A stun turret was taken off the outpost. It no longer answers to the wing.")

/// The turrets hold only a weakref to the prison, which dies with it; they are left guarding nothing.
/datum/outpost_prison/proc/security_destroy()
	stun_turrets.Cut()

/// The stun turrets this wing sold that still exist and still answer to it; the rest are dropped from the list
/datum/outpost_prison/proc/live_stun_turrets()
	var/list/live = list()
	for(var/datum/weakref/turret_ref as anything in stun_turrets.Copy())
		var/obj/machinery/porta_turret/ship_defense/outpost_prison/turret = turret_ref?.resolve()
		if(QDELETED(turret) || turret.prison_ref?.resolve() != src)
			stun_turrets -= turret_ref
			continue
		live += turret
	return live

/// A new turret for this wing, loose and switched off on `where`
/datum/outpost_prison/proc/make_stun_turret(turf/where)
	var/obj/machinery/porta_turret/ship_defense/outpost_prison/turret = new(where)
	turret.prison_ref = WEAKREF(src)
	stun_turrets += WEAKREF(turret)
	return turret

/// A turret stops answering to this wing and frees its slot
/datum/outpost_prison/proc/release_stun_turret(obj/machinery/porta_turret/ship_defense/outpost_prison/turret)
	for(var/datum/weakref/turret_ref as anything in stun_turrets.Copy())
		if(turret_ref?.resolve() == turret)
			stun_turrets -= turret_ref
	turret.forget_prison()

/**
 * A manager buys a turret from the treasury. The price is taken before the turret is made, and
 * a treasury that cannot cover it is refused, never put in debt. Returns the turret, or the
 * reason it was refused.
 */
/datum/outpost_prison/proc/buy_stun_turret(mob/user)
	if(!ismob(user) || QDELETED(outpost) || !outpost.can_manage(user))
		return "managers only"
	if(length(live_stun_turrets()) >= OUTPOST_PRISON_TURRET_MAX)
		return "no room for another turret"
	// The warden's console, or the middle of the wing
	var/turf/drop = alarm_turf()
	if(!drop)
		return "nowhere to put it"
	outpost.ensure_home_services()
	var/datum/bank_account/treasury = outpost.treasury
	if(!treasury?.adjust_money(-OUTPOST_PRISON_TURRET_COST, "Wing stun turret, bought by [user.ckey || user.name]"))
		return "insufficient funds"
	note_spending(OUTPOST_PRISON_TURRET_COST, "Wing stun turret")
	var/obj/machinery/porta_turret/ship_defense/outpost_prison/turret = make_stun_turret(drop)
	add_log("[user.name] bought a stun turret for [OUTPOST_PRISON_TURRET_COST] cr.")
	log_game("PLAYER OUTPOST PRISON: [key_name(user)] bought a stun turret for [OUTPOST_PRISON_TURRET_COST] cr at '[outpost?.name]'")
	playsound(drop, 'sound/machines/ping.ogg', 40, TRUE)
	return turret

/// The warden console's "security" block (build plan section 8)
/datum/outpost_prison/proc/security_payload(mob/user)
	var/list/turrets = list()
	for(var/obj/machinery/porta_turret/ship_defense/outpost_prison/turret as anything in live_stun_turrets())
		turrets += list(list("ref" = REF(turret), "state" = turret.console_state()))
	var/manager = ismob(user) && !QDELETED(outpost) && outpost.can_manage(user)
	var/datum/bank_account/treasury = outpost?.treasury
	return list(
		"turret_max" = OUTPOST_PRISON_TURRET_MAX,
		"turret_cost" = OUTPOST_PRISON_TURRET_COST,
		"can_buy" = !!(manager && length(turrets) < OUTPOST_PRISON_TURRET_MAX && treasury?.has_money(OUTPOST_PRISON_TURRET_COST)),
		"turrets" = turrets,
	)

/// turret_buy {}; TRUE if handled
/datum/outpost_prison/proc/security_act(action, list/params, mob/user)
	if(action != "turret_buy")
		return FALSE
	var/result = buy_stun_turret(user)
	if(!user)
		return TRUE
	// The answer shows over the warden's console, as its own buttons' answers do.
	var/turf/console_turf = alarm_turf()
	var/atom/speaker = (console_turf && (locate(/obj/machinery/computer/outpost_prison_warden) in console_turf)) || user
	if(istext(result))
		speaker.balloon_alert(user, result)
		playsound(speaker, 'sound/machines/buzz/buzz-sigh.ogg', 30, TRUE)
	else
		speaker.balloon_alert(user, "turret delivered")
	return TRUE

/**
 * What a rioter goes for before any fixture: the nearest unbroken stun turret of this wing they
 * can reach and have not given up on, or null. A rioter newly going for one may shout about it.
 */
/datum/outpost_prison/proc/priority_smash_target(mob/living/basic/outpost_prisoner/rioter)
	if(!rioter?.reachable)
		return null
	var/obj/machinery/porta_turret/ship_defense/outpost_prison/nearest
	var/nearest_distance = INFINITY
	for(var/obj/machinery/porta_turret/ship_defense/outpost_prison/turret as anything in live_stun_turrets())
		if(turret.machine_stat & BROKEN)
			continue
		if(!rioter.reachable[get_turf(turret)] || LAZYACCESS(rioter.riot_skips, REF(turret)) > world.time)
			continue
		var/distance = get_dist(rioter, turret)
		if(distance < nearest_distance)
			nearest = turret
			nearest_distance = distance
	if(nearest && rioter.riot_target_ref?.resolve() != nearest && COOLDOWN_FINISHED(src, turret_smash_line_cooldown))
		COOLDOWN_START(src, turret_smash_line_cooldown, OUTPOST_PRISON_TURRET_SMASH_LINE_GAP)
		INVOKE_ASYNC(rioter, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context), "turret_smash")
	return nearest

/// The admin panel's turrets: list of {ref, state, mounted}
/datum/outpost_prison/proc/security_admin_payload()
	var/list/rows = list()
	for(var/obj/machinery/porta_turret/ship_defense/outpost_prison/turret as anything in live_stun_turrets())
		rows += list(list(
			"ref" = REF(turret),
			"state" = turret.console_state(),
			"mounted" = turret.mounted(),
		))
	return rows

/// prison_turret_spawn {}: a free turret, loose and off, at the warden's console. A log line, list("error" = text), or null.
/datum/outpost_prison/proc/security_admin_act(action, list/params, mob/user)
	if(action != "prison_turret_spawn")
		return null
	var/turf/drop = alarm_turf()
	if(!drop)
		return list("error" = "The prison wing has nowhere to put a turret.")
	make_stun_turret(drop)
	add_log("A stun turret was delivered.")
	return "spawned a wing stun turret at the prison wing's warden console"

// ===== THE TURRET =====

/obj/machinery/porta_turret/ship_defense/outpost_prison
	name = "wing stun turret"
	desc = "A stubby disabler mount for a prison wing's cell block. Its targeting computer knows the wing's own inmates and nobody else, and only fires on the ones already fighting, rioting, climbing out or loose."
	icon_state = "turretCover"
	// It arrives loose, in plain sight and switched off; mounting and switching on are the crew's job.
	anchored = FALSE
	invisibility = INVISIBILITY_NONE
	on = FALSE
	mode = PRISON_TURRET_STUN
	use_power = IDLE_POWER_USE
	idle_power_usage = OUTPOST_PRISON_TURRET_IDLE_POWER
	scan_range = OUTPOST_PRISON_TURRET_SCAN_RANGE
	shot_delay = OUTPOST_PRISON_TURRET_SHOT_DELAY
	stun_projectile = /obj/projectile/beam/disabler/outpost_prison
	stun_projectile_sound = 'sound/items/weapons/taser2.ogg'
	lethal_projectile = /obj/projectile/beam/disabler/outpost_prison
	lethal_projectile_sound = 'sound/items/weapons/taser2.ogg'
	max_integrity = OUTPOST_PRISON_TURRET_INTEGRITY
	integrity_failure = OUTPOST_PRISON_TURRET_FAILURE
	mob_hits_to_disable = OUTPOST_PRISON_TURRET_MOB_HITS
	target_wildlife = FALSE
	// No multitool buffer and no turret control panel: either would get round allowed_operator().
	locked = TRUE
	controllock = TRUE
	/// The prison that sold it; it does nothing for any other
	var/datum/weakref/prison_ref
	/// The prisoner it is dealing with, so it does not flit between two
	var/datum/weakref/engaged_ref
	/// REF() of prisoners it warned -> world.time of the warning
	var/list/warned_at

/// The prison it answers to, if that prison still exists
/obj/machinery/porta_turret/ship_defense/outpost_prison/proc/home_prison()
	var/datum/outpost_prison/prison = prison_ref?.resolve()
	return QDELETED(prison) ? null : prison

/// It stops answering to any wing: it will not mount, and does nothing mounted
/obj/machinery/porta_turret/ship_defense/outpost_prison/proc/forget_prison()
	prison_ref = null
	engaged_ref = null
	warned_at = null

/// Bolted into a wall
/obj/machinery/porta_turret/ship_defense/outpost_prison/proc/mounted()
	return !!(anchored && isclosedturf(loc))

/// "loose", "broken", "no_power", "on" or "off", for the warden's console
/obj/machinery/porta_turret/ship_defense/outpost_prison/proc/console_state()
	if(!anchored)
		return "loose"
	if(machine_stat & BROKEN)
		return "broken"
	if(machine_stat & NOPOWER)
		return "no_power"
	return on ? "on" : "off"

// ----- the mount rule -----

/// Whether `front` is open cell-block floor of `prison` a prisoner could stand on, so a rioter can always get at a turret looking over it
/obj/machinery/porta_turret/ship_defense/outpost_prison/proc/muzzle_ok(datum/outpost_prison/prison, turf/front)
	if(!prison || !front || isclosedturf(front) || front.loc != prison.wing)
		return FALSE
	return prison.in_cell_block(front) && prison.prisoner_can_stand(front)

/// Whether a turret bolted into `wall`, looking out in `mount_dir`, would sit in a cell-block wall of `prison` facing into the cell block
/obj/machinery/porta_turret/ship_defense/outpost_prison/proc/mount_spot_ok(datum/outpost_prison/prison, turf/wall, mount_dir)
	if(!prison || !isclosedturf(wall) || !(mount_dir in GLOB.cardinals))
		return FALSE
	if(wall.loc != prison.wing || !prison.in_cell_block(wall))
		return FALSE
	return muzzle_ok(prison, get_step(wall, mount_dir))

/// The cell-block tile it looks and fires over, while it is mounted where it may be and nothing blocks that tile; else null
/obj/machinery/porta_turret/ship_defense/outpost_prison/proc/muzzle(datum/outpost_prison/prison)
	if(!prison || !anchored || !isclosedturf(loc) || !wall_turret_direction)
		return null
	if(!mount_spot_ok(prison, loc, wall_turret_direction))
		return null
	return get_step(loc, wall_turret_direction)

/**
 * Dragged onto a wall: only a member may mount it, only for its own wing, and only in a cell-block
 * wall with open cell-block floor on the far side. The rule is checked again once the parent's
 * bolting is done, since the wall or the floor may have changed meanwhile.
 */
/obj/machinery/porta_turret/ship_defense/outpost_prison/mouse_drop_dragged(atom/over, mob/user, src_location, over_location, params)
	var/turf/wall = over
	if(!isclosedturf(wall) || anchored)
		return ..()
	if(!allowed_operator(user))
		balloon_alert(user, "members only!")
		return
	var/datum/outpost_prison/prison = home_prison()
	if(!prison)
		balloon_alert(user, "it has no wing to guard")
		return
	var/mount_dir = get_dir(src, wall)
	if((mount_dir in GLOB.cardinals) && !mount_spot_ok(prison, wall, mount_dir))
		balloon_alert(user, "mount it on a cell block wall, facing in")
		return
	var/turf/from = loc
	..()
	if(!anchored || loc != wall)
		return
	if(!mount_spot_ok(prison, wall, mount_dir))
		set_anchored(FALSE)
		forceMove(from)
		update_appearance()
		balloon_alert(user, "mount it on a cell block wall, facing in")
		return
	prison.add_log("A stun turret was mounted.")
	check_should_process()

// ----- controls -----

/// Its controls answer to the members of the wing that bought it. A turret with no wing guards nothing, so it is nobody's lock.
/obj/machinery/porta_turret/ship_defense/outpost_prison/allowed_operator(mob/user)
	if(isAdminGhostAI(user))
		return TRUE
	var/datum/outpost_prison/prison = home_prison() || get_outpost_prison(src)
	if(!prison)
		return TRUE
	return prison.is_member(user)

/obj/machinery/porta_turret/ship_defense/outpost_prison/interact(mob/user)
	if(!allowed_operator(user))
		update_last_used(user)
		balloon_alert(user, "members only!")
		return TRUE
	return ..()

/// Nothing to set: it has one rule
/obj/machinery/porta_turret/ship_defense/outpost_prison/click_alt(mob/user)
	balloon_alert(user, "no settings")
	return CLICK_ACTION_BLOCKING

/**
 * The parent's wrench (bolts, while it is off) and crowbar (salvage, once it is broken) answer to
 * members only, and the wrench never bolts it to a floor, which would get round the mount rule.
 * Unbolted out of a wall, it comes out on the unbolter's side.
 */
/obj/machinery/porta_turret/ship_defense/outpost_prison/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	var/tool = attacking_item.tool_behaviour
	var/broken = machine_stat & BROKEN
	var/wrenching = tool == TOOL_WRENCH && !broken && !on
	if(wrenching || (tool == TOOL_CROWBAR && broken))
		if(!allowed_operator(user))
			balloon_alert(user, "members only!")
			return TRUE
		if(wrenching && !anchored)
			balloon_alert(user, "mount it on a cell block wall, facing in")
			return TRUE
	var/turf/was_in = loc
	. = ..()
	if(wrenching && !QDELETED(src) && !anchored && isclosedturf(was_in) && loc == was_in && isturf(user.loc) && user.Adjacent(src))
		forceMove(user.loc)

/obj/machinery/porta_turret/ship_defense/outpost_prison/atom_break(damage_flag)
	. = ..()
	if(.)
		home_prison()?.add_log("A stun turret was smashed.")

/obj/machinery/porta_turret/ship_defense/outpost_prison/examine(mob/user)
	. = ..()
	// The hull turret's own lines are about wildlife, boarders and ship crews; this one has none of those.
	var/list/lines = .
	for(var/line in lines.Copy())
		if(findtext(line, "wildlife") || findtext(line, "boarding") || findtext(line, "the hull"))
			lines -= line
	var/datum/outpost_prison/prison = home_prison()
	if(prison)
		. += span_notice("It answers to the members of the outpost that bought it.")
	else
		. += span_notice("Its targeting computer has no wing to guard.")
	if(!(machine_stat & BROKEN))
		. += span_notice("It is switched [on ? "on" : "off"].")
	if(!anchored)
		. += span_notice("It is loose.")
	else if(prison && !muzzle(prison))
		. += span_warning("It can't see into the cell block from where it is.")

// ----- targets -----

/**
 * Whether it would warn `creature`: a prisoner of its own wing, on their feet in the wing and not
 * shut in a cell, who is rioting, fighting past the argument, swinging at staff, climbing a hatch
 * or loose, while a member of the wing is home. Only a prisoner who could walk up to it and smash
 * it: a turret boxed in behind windows, or looking out of a bolted cell, shoots nobody.
 */
/obj/machinery/porta_turret/ship_defense/outpost_prison/proc/warn_target(mob/living/creature)
	var/mob/living/basic/outpost_prisoner/prisoner = creature
	if(!istype(prisoner))
		return FALSE
	var/datum/outpost_prison/prison = home_prison()
	if(!prison || prisoner.prison != prison || !prison.crew_home())
		return FALSE
	if(prisoner.phase != PRISONER_PRESENT || prisoner.stat != CONSCIOUS || prisoner.can_be_dragged() || get_area(prisoner) != prison.wing)
		return FALSE
	var/answers = prisoner.is_rioting() || prisoner.swing_ref || prisoner.climb_ref || prisoner.trouble == PRISONER_TROUBLE_LOOSE
	if(!answers && prisoner.trouble == PRISONER_TROUBLE_FIGHT)
		answers = prisoner.fight?.fighting
	if(!answers)
		return FALSE
	if(!prisoner.reachable?[get_turf(src)])
		return FALSE
	return !prisoner.is_confined()

/// Whether it would fire on `creature`: as warn_target(), except that a rioter during the riot's wind-up is only warned
/obj/machinery/porta_turret/ship_defense/outpost_prison/valid_target(mob/living/creature)
	if(!warn_target(creature))
		return FALSE
	var/mob/living/basic/outpost_prisoner/prisoner = creature
	return !(prisoner.is_rioting() && prisoner.prison.riot_windup_left > 0)

// ----- looking, warning and firing -----

/obj/machinery/porta_turret/ship_defense/outpost_prison/process()
	if(!on || (machine_stat & (NOPOWER|BROKEN)))
		return PROCESS_KILL
	think()

/**
 * One look over the cell block: warns or fires at the prisoner it is dealing with, or the nearest
 * one making the kind of trouble it answers. Nothing while nobody from the wing is home. Returns
 * TRUE if it warned or fired.
 */
/obj/machinery/porta_turret/ship_defense/outpost_prison/proc/think()
	if(!on || (machine_stat & (NOPOWER|BROKEN)))
		return FALSE
	var/datum/outpost_prison/prison = home_prison()
	if(!prison || !prison.crew_home())
		return FALSE
	var/turf/front = muzzle(prison)
	if(!front)
		return FALSE
	if(!raised && !raising)
		INVOKE_ASYNC(src, PROC_REF(raise))
	// The cheap checks first: most of the time nobody in the wing is making that kind of trouble.
	var/list/candidates = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prison.prisoners)
		if(get_dist(front, prisoner) <= scan_range && warn_target(prisoner))
			candidates += prisoner
	if(!length(candidates))
		engaged_ref = null
		return FALSE
	var/list/seen = view(scan_range, front)
	var/mob/living/basic/outpost_prisoner/engaged = engaged_ref?.resolve()
	if(engaged && (engaged in candidates) && (engaged in seen))
		return engage(engaged)
	var/mob/living/basic/outpost_prisoner/nearest
	var/nearest_distance = INFINITY
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in candidates)
		if(!(prisoner in seen))
			continue
		var/distance = get_dist(front, prisoner)
		if(distance < nearest_distance)
			nearest = prisoner
			nearest_distance = distance
	if(!nearest)
		engaged_ref = null
		return FALSE
	return engage(nearest)

/// Deals with `target`: a warning if they have not had one lately, else a shot once the warning's time is up
/obj/machinery/porta_turret/ship_defense/outpost_prison/proc/engage(mob/living/basic/outpost_prisoner/target)
	engaged_ref = WEAKREF(target)
	setDir(get_dir(src, target))
	var/warned = LAZYACCESS(warned_at, REF(target))
	if(!warned || world.time - warned >= OUTPOST_PRISON_TURRET_REWARN_TIME)
		warn(target)
		return TRUE
	if(world.time - warned < OUTPOST_PRISON_TURRET_WARN_TIME)
		return FALSE
	return fire_at(target)

/**
 * The warning: a red line on them, a triple beep and "Step away.", at most once per target per
 * OUTPOST_PRISON_TURRET_REWARN_TIME. The first shot follows OUTPOST_PRISON_TURRET_WARN_TIME later
 * if they are still at it.
 */
/obj/machinery/porta_turret/ship_defense/outpost_prison/proc/warn(mob/living/basic/outpost_prisoner/target)
	if(warned_at)
		for(var/key in warned_at.Copy())
			if(world.time - warned_at[key] >= OUTPOST_PRISON_TURRET_REWARN_TIME)
				LAZYREMOVE(warned_at, key)
	LAZYSET(warned_at, REF(target), world.time)
	if(!raised && !raising)
		INVOKE_ASYNC(src, PROC_REF(raise))
	Beam(target, icon_state = "r_beam", time = OUTPOST_PRISON_TURRET_WARN_TIME)
	playsound(src, 'sound/machines/beep/triple_beep.ogg', 40, FALSE)
	say("Step away.")
	target.face_atom(src)
	INVOKE_ASYNC(target, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context), "turret_warned")
	addtimer(CALLBACK(src, PROC_REF(warning_over), WEAKREF(target)), OUTPOST_PRISON_TURRET_WARN_TIME)

/// The warning's time is up: the first shot, if they are still at it
/obj/machinery/porta_turret/ship_defense/outpost_prison/proc/warning_over(datum/weakref/target_ref)
	var/mob/living/basic/outpost_prisoner/target = target_ref?.resolve()
	if(!target || !on || (machine_stat & (NOPOWER|BROKEN)))
		return FALSE
	return fire_at(target)

/// One shot at `target`, if it may fire at them now and can see them. Returns TRUE if it fired.
/obj/machinery/porta_turret/ship_defense/outpost_prison/proc/fire_at(mob/living/basic/outpost_prisoner/target)
	if(!valid_target(target))
		return FALSE
	var/turf/front = muzzle(home_prison())
	if(!front || get_dist(front, target) > scan_range || !(target in view(scan_range, front)))
		return FALSE
	if(!raised)
		if(!raising)
			INVOKE_ASYNC(src, PROC_REF(raise))
		return FALSE
	setDir(get_dir(src, target))
	return !!shootAt(target)

/// Comes up out of its housing and shows it
/obj/machinery/porta_turret/ship_defense/outpost_prison/proc/raise()
	popUp()
	update_appearance()

/// One of its shots landed on `target`: now and then someone watching says something
/obj/machinery/porta_turret/ship_defense/outpost_prison/proc/note_hit(mob/living/basic/outpost_prisoner/target)
	var/datum/outpost_prison/prison = home_prison()
	if(!prison || !COOLDOWN_FINISHED(prison, turret_hit_line_cooldown) || !prob(OUTPOST_PRISON_TURRET_HIT_LINE_CHANCE))
		return FALSE
	for(var/mob/living/basic/outpost_prisoner/onlooker in shuffle(prison.prisoners))
		if(onlooker == target || onlooker.stat != CONSCIOUS || onlooker.phase != PRISONER_PRESENT || !onlooker.ai_running() || onlooker.in_trouble())
			continue
		if(get_dist(onlooker, target) > 7 || !(target in view(7, onlooker)))
			continue
		COOLDOWN_START(prison, turret_hit_line_cooldown, OUTPOST_PRISON_TURRET_HIT_LINE_GAP)
		onlooker.face_atom(target)
		INVOKE_ASYNC(onlooker, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context), "turret_hit")
		return TRUE
	return FALSE

// ===== THE BEAM =====

/**
 * The turret's disabler beam. It passes through anyone the firing turret would not fire on, so
 * staff, visitors and guards can stand in the line safely, and through the wing's tables, windows
 * and doors, as the hull turret's beam does. No ricochets and no reflections.
 */
/obj/projectile/beam/disabler/outpost_prison
	damage = OUTPOST_PRISON_TURRET_STAMINA
	range = OUTPOST_PRISON_TURRET_BEAM_RANGE
	ricochets_max = 0
	ricochet_chance = 0
	reflectable = FALSE
	projectile_phasing = PASSTABLE | PASSGLASS | PASSGRILLE | PASSCLOSEDTURF | PASSMACHINE | PASSSTRUCTURE | PASSDOORS

/obj/projectile/beam/disabler/outpost_prison/can_hit_target(atom/target, direct_target = FALSE, ignore_loc = FALSE, cross_failed = FALSE)
	// Not even the aimed-at target is spared the check: someone who stopped being a target mid-flight is missed.
	if(isliving(target))
		var/obj/machinery/porta_turret/ship_defense/outpost_prison/turret = firer
		if(!istype(turret) || !turret.valid_target(target))
			return FALSE
	return ..()

/obj/projectile/beam/disabler/outpost_prison/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	var/obj/machinery/porta_turret/ship_defense/outpost_prison/turret = firer
	if(istype(turret) && is_outpost_prisoner(target))
		turret.note_hit(target)

#undef PRISON_TURRET_STUN
#undef PRISON_TURRET_CHECK_SECONDS
