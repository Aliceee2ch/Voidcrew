/**
 * # Prison wing economy
 *
 * Money and the comings and goings that make it: the stipend each prisoner earns the treasury,
 * its deposits, release bonuses, fines, intake and arrivals, releases, deaths and the collection
 * of bodies. The pay model is in voidcrew/_DEFINES/outpost_prison_economy.dm. The warden console
 * that shows it all is outpost_prison_warden.dm.
 */

/datum/outpost_prison
	var/intake_open = FALSE
	/// Seconds until the next prisoner beams in, or null while none is due
	var/arrival_countdown
	/// Seconds into the current pay minute
	var/pay_clock = 0
	/// Credits earned and not yet deposited; deposits are whole credits, once a minute
	var/pay_owed = 0
	/// Everything this prison has paid into the treasury
	var/paid_total = 0

// ===== PAY =====

/// The share of full pay a prisoner earns the treasury right now, 0 to 1: care x conditions, or nothing while they are not earning
/datum/outpost_prison/proc/pay_factor(mob/living/basic/outpost_prisoner/prisoner)
	if(!prisoner.earning_pay())
		return 0
	return prisoner.care() / 100 * conditions_pay_factor()

/// A prisoner served `served` seconds of their sentence: their stipend for it, and the seconds served and kept for the release bonus
/datum/outpost_prison/proc/accrue_pay(mob/living/basic/outpost_prisoner/prisoner, served)
	var/factor = pay_factor(prisoner)
	pay_owed += OUTPOST_PRISON_BASE_PAY * factor * served / 60
	prisoner.served_seconds += served
	prisoner.kept_seconds += factor * served

/// Advances the pay clock by `seconds`, depositing what is owed once a minute
/datum/outpost_prison/proc/pay_tick(seconds)
	pay_clock += seconds
	while(pay_clock >= 60)
		pay_clock -= 60
		deposit_pay()

/// Pays the outpost treasury. Returns TRUE if it was paid.
/datum/outpost_prison/proc/pay_treasury(amount, reason)
	if(amount <= 0 || QDELETED(outpost))
		return FALSE
	outpost.ensure_home_services()
	if(!outpost.treasury?.adjust_money(amount, reason))
		return FALSE
	paid_total += amount
	return TRUE

/// Deposits the whole credits owed; the fraction waits for next minute
/datum/outpost_prison/proc/deposit_pay()
	// The epsilon keeps float error from turning 32 owed into 31.99999 and a credit short.
	var/whole = round(pay_owed + 0.001)
	if(whole >= 1 && pay_treasury(whole, "Prison wing stipend"))
		pay_owed -= whole
		return whole
	return 0

/// What a prisoner earns the treasury per minute right now
/datum/outpost_prison/proc/prisoner_pay_rate(mob/living/basic/outpost_prisoner/prisoner)
	if(prisoner.stat == DEAD || prisoner.phase != PRISONER_PRESENT || !prisoner.earning_pay())
		return 0
	return OUTPOST_PRISON_BASE_PAY * prisoner.care() / 100 * conditions_score() / 100

/// What every prisoner earns the treasury per minute right now
/datum/outpost_prison/proc/pay_rate()
	var/total = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		total += prisoner_pay_rate(prisoner)
	return total

/// Money the wing spent from the treasury (rations, supplies), for the console's totals
/datum/outpost_prison/proc/note_spending(amount, reason)
	return

// ===== FINES =====

/**
 * Takes up to `amount` from the outpost treasury. Returns what was taken. `incident` marks a fine
 * that belongs to the current incident (a riot, its breakout and its escapes).
 */
/datum/outpost_prison/proc/charge_fine(amount, reason, incident = FALSE)
	if(QDELETED(outpost))
		return 0
	outpost.ensure_home_services()
	var/datum/bank_account/treasury = outpost.treasury
	var/fine = min(amount, treasury?.account_balance)
	if(fine <= 0 || !treasury.adjust_money(-fine, reason))
		return 0
	return fine

/// A riot starts an incident: its fines are counted together from here
/datum/outpost_prison/proc/begin_incident()
	return

/// The incident is over: nobody is rioting, breaking out or loose any more
/datum/outpost_prison/proc/end_incident()
	return

/// A prisoner is lost to the wing for good (escaped or transferred out)
/datum/outpost_prison/proc/note_prisoner_lost(mob/living/basic/outpost_prisoner/prisoner, reason)
	return

// ===== COMINGS AND GOINGS =====

/datum/outpost_prison/proc/set_intake(open, mob/user)
	open = !!open
	if(open == intake_open)
		return
	intake_open = open
	arrival_countdown = (intake_open && free_slots()) ? OUTPOST_PRISON_FIRST_ARRIVAL : null
	if(user)
		log_game("PLAYER OUTPOST: [key_name(user)] [intake_open ? "opened" : "closed"] prison intake at '[outpost?.name]'")

/// Advances arrivals by `seconds`: while intake is open and a cell is free, the next prisoner beams in when due
/datum/outpost_prison/proc/intake_tick(seconds)
	if(intake_open && free_slots())
		if(isnull(arrival_countdown))
			arrival_countdown = rand(OUTPOST_PRISON_REFILL_MIN, OUTPOST_PRISON_REFILL_MAX)
		arrival_countdown -= seconds
		while(arrival_countdown <= 0 && free_slots() && is_powered())
			if(!admit_next())
				break
			arrival_countdown += rand(OUTPOST_PRISON_ARRIVAL_GAP_MIN, OUTPOST_PRISON_ARRIVAL_GAP_MAX)
		arrival_countdown = free_slots() ? max(arrival_countdown, 0) : null
	else
		arrival_countdown = null

/// Beams a new prisoner into the lowest-numbered empty cell. Returns them, or null.
/datum/outpost_prison/proc/admit_next()
	if(!free_slots())
		return null
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(cell.occupant)
			continue
		var/turf/spot = cell.arrival_turf()
		if(!spot)
			continue
		var/mob/living/basic/outpost_prisoner/prisoner = new(spot)
		admit(prisoner, cell)
		prisoner.beam_in()
		return prisoner
	return null

/// Books a prisoner into a cell (the first free one when none is given)
/datum/outpost_prison/proc/admit(mob/living/basic/outpost_prisoner/prisoner, datum/outpost_prison_cell/into)
	if(!into)
		for(var/datum/outpost_prison_cell/cell as anything in cells)
			if(!cell.occupant)
				into = cell
				break
	prisoner.prison = src
	prisoners |= prisoner
	if(into)
		into.occupant = prisoner
		prisoner.cell = into
	prisoner.sentence_left = rand(OUTPOST_PRISON_SENTENCE_MIN, OUTPOST_PRISON_SENTENCE_MAX)
	refresh_prisoner_reach(prisoner)
	add_log("[prisoner.real_name] arrived in cell [into ? into.number : "-"], [round(prisoner.sentence_left / 60)] min sentence.")

/**
 * After a tick of a prisoner's sentence: released once it has run out, and sent back to their
 * cell in its last OUTPOST_PRISON_RELEASE_WALK seconds.
 */
/datum/outpost_prison/proc/check_release(mob/living/basic/outpost_prisoner/prisoner)
	if(prisoner.sentence_left <= 0)
		release(prisoner)
	else if(prisoner.sentence_left <= OUTPOST_PRISON_RELEASE_WALK && !istype(prisoner.activity, /datum/prisoner_activity/go_home) && !prisoner.in_trouble())
		// Time to head back to the cell; the routine picks this up.
		prisoner.end_activity()

/// Sentence served: pays the release bonus and beams the prisoner out of wherever they stand
/datum/outpost_prison/proc/release(mob/living/basic/outpost_prisoner/prisoner)
	if(prisoner.phase != PRISONER_PRESENT || prisoner.stat == DEAD)
		return 0
	var/average = prisoner.served_seconds ? prisoner.kept_seconds / prisoner.served_seconds : 0
	var/bonus = round(OUTPOST_PRISON_RELEASE_BONUS * average)
	pay_treasury(bonus, "Prison release: [prisoner.real_name]")
	add_log("[prisoner.real_name] released, +[bonus] cr.")
	prisoner.say_context("release")
	prisoner.beam_out()
	return bonus

/datum/outpost_prison/proc/on_prisoner_death(mob/living/basic/outpost_prisoner/prisoner)
	prisoner.body_pickup_left = OUTPOST_PRISON_CORPSE_PICKUP
	add_log("[prisoner.real_name] died.")
	prisoner.died_at = world.time
	prisoner.clear_trouble()
	if(prisoner.staff_to_blame())
		blame_death(prisoner)
	if(!loose_count() && !riot_active)
		broke_out = FALSE
	update_riot_lights()

/// The corrections service takes a body away
/datum/outpost_prison/proc/collect(mob/living/basic/outpost_prisoner/prisoner)
	prisoner.beam_out()

/**
 * A prisoner has left the roster (released, collected, escaped or deleted) and their cell is free.
 * `cell` is the cell they had, or null; `died` is TRUE when they left as a body.
 */
/datum/outpost_prison/proc/on_cell_emptied(datum/outpost_prison_cell/cell, died = FALSE)
	if(intake_open && isnull(arrival_countdown))
		arrival_countdown = rand(OUTPOST_PRISON_REFILL_MIN, OUTPOST_PRISON_REFILL_MAX)

/// The outpost was abandoned: intake closes and everyone is transferred out
/datum/outpost_prison/proc/on_outpost_abandoned()
	return
