/**
 * # Prison pastimes: cards, dice, birthdays, the courtside crowd, marks on the wall
 *
 * Owner: XD (extras-plan.md 4.6, 4.9, 4.12 and 4.13). Card and dice games at the mess tables with
 * the crew dealt in; a birthday cake party; watchers and a score at the hoop; initials and tallies
 * on cell walls.
 *
 * X0 stubs: every proc below keeps the prison as it was until XD fills it in.
 */

/// Hooks up the prisoner's side of the pastimes; called from setup_extras()
/mob/living/basic/outpost_prisoner/proc/setup_pastimes()
	return

/datum/outpost_prison/proc/pastimes_tick(seconds)
	return

/// `prisoner` is about to eat `food` fed by `feeder`; TRUE cancels the eat. Runs in a signal handler: never sleeps.
/datum/outpost_prison/proc/pastime_pre_eat(mob/living/basic/outpost_prisoner/prisoner, atom/food, mob/living/feeder)
	return FALSE

/// Something went on a serving hatch; TRUE if a pastime took the event (a birthday cake)
/datum/outpost_prison/proc/pastime_hatch_stocked(obj/structure/table/reinforced/prison_hatch/hatch, list/stocked, mob/user)
	return FALSE

/// Whether `thing` is held back from being eaten as a meal by `prisoner` (a party cake)
/datum/outpost_prison/proc/reserved_supply(obj/item/thing, mob/living/basic/outpost_prisoner/prisoner)
	return FALSE

/// A shot at the hoop by `shooter` (a prisoner, or anyone else while prisoners play) came down
/datum/outpost_prison/proc/on_basket(mob/living/shooter, obj/structure/hoop/hoop, scored)
	return
