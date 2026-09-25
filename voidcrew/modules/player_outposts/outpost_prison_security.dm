/**
 * # Prison security: wing stun turrets
 *
 * Owner: XB (extras-plan.md 4.2). Up to two stun turrets bought at the warden's console and
 * mounted on cell-block walls facing in. They warn, then fire disabler beams only at violence
 * already under way, hatch climbers and prisoners loose in the wing, and only while a member is
 * home. Rioters go for them first. Numbers in voidcrew/_DEFINES/outpost_prison_security.dm.
 *
 * X0 stubs: every proc below keeps the prison as it was until XB fills it in.
 */

/// Whether `thing` is a wing stun turret a prison sold
/proc/is_outpost_prison_stun_turret(atom/thing)
	return FALSE

/datum/outpost_prison/proc/security_tick(seconds)
	return

/datum/outpost_prison/proc/security_destroy()
	return

/// The warden console's "security" block (build plan section 8)
/datum/outpost_prison/proc/security_payload(mob/user)
	return list(
		"turret_max" = OUTPOST_PRISON_TURRET_MAX,
		"turret_cost" = OUTPOST_PRISON_TURRET_COST,
		"can_buy" = FALSE,
		"turrets" = list(),
	)

/// turret_buy {}; TRUE if handled
/datum/outpost_prison/proc/security_act(action, list/params, mob/user)
	return FALSE

/// What a rioter goes for before any fixture: the nearest unbroken stun turret they can reach, or null
/datum/outpost_prison/proc/priority_smash_target(mob/living/basic/outpost_prisoner/rioter)
	return null

/// The admin panel's turrets: list of {ref, state, mounted}
/datum/outpost_prison/proc/security_admin_payload()
	return list()

/// prison_turret_spawn {}: a log line, list("error" = text), or null
/datum/outpost_prison/proc/security_admin_act(action, list/params, mob/user)
	return null
