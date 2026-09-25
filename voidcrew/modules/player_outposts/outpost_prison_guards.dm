/**
 * # Prison guards
 *
 * Owner: XA (extras-plan.md 4.1). NPC guards the wing's managers hire at the warden's console:
 * named people on the payroll who keep a peaceful routine, step in on spats, arguments, fights,
 * threats and hatch climbs, hold the staff doors in a riot, go down instead of dying and come
 * back free. Paid per minute while a member is home. Their routine and activities are in
 * outpost_prison_guard_routine.dm; numbers in voidcrew/_DEFINES/outpost_prison_guards.dm.
 *
 * X0 stubs: every proc below keeps the prison as it was until XA fills it in.
 */

/// Whether `thing` is one of a prison's NPC guards; with `on_duty`, only one present, arrived and not down
/proc/is_outpost_prison_guard(atom/thing, on_duty = FALSE)
	return FALSE

/// Wages, returns of downed guards, the response dispatcher and the leash
/datum/outpost_prison/proc/guards_tick(seconds)
	return

/datum/outpost_prison/proc/guards_destroy()
	return

/// The outpost was abandoned: every guard is dismissed, no refund
/datum/outpost_prison/proc/guards_abandon()
	return

/// The warden console's "guards" block (build plan section 8)
/datum/outpost_prison/proc/guards_payload(mob/user)
	return list(
		"max" = OUTPOST_GUARD_MAX,
		"hire_cost" = OUTPOST_GUARD_HIRE_COST,
		"wage" = OUTPOST_GUARD_WAGE,
		"can_manage" = FALSE,
		"can_hire" = FALSE,
		"unpaid" = 0,
		"list" = list(),
	)

/// guard_hire {} and guard_dismiss {ref}; TRUE if handled
/datum/outpost_prison/proc/guards_act(action, list/params, mob/user)
	return FALSE

/// The admin panel's guards: list of {ref, name, health, status, activity, response}
/datum/outpost_prison/proc/guards_admin_payload()
	return list()

/// prison_guard_spawn, prison_guard_remove {ref}, prison_guard_down {ref}: a log line, list("error" = text), or null
/datum/outpost_prison/proc/guards_admin_act(action, list/params, mob/user)
	return null
