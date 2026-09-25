/**
 * The Outpost Manipulator's Prison section: everything about a prison wing an admin needs to
 * test it without waiting, from spawning prisoners to breaking the lights. R_ADMIN only, through
 * the manipulator's own authorization, and every action is logged.
 */

/// Admin actions handled here; every one names its params in the comment beside it
GLOBAL_LIST_INIT(outpost_admin_prison_actions, list(
	"prison_intake", // {open}
	"prison_spawn", // {}
	"prison_fill", // {}
	"prison_release", // {ref}
	"prison_kill", // {ref}
	"prison_remove", // {ref}
	"prison_set", // {ref, field: hunger|grime|health|sentence|mood, value}
	"prison_all", // {what: starve|feed|dirty|clean|hurt|heal|enrage|calm}
	"prison_advance", // {minutes}
	"prison_pay_now", // {}
	"prison_mess", // {}
	"prison_break_lights", // {}
	"prison_power", // {on}
	"prison_fight", // {ref}: that prisoner and the nearest other who can
	"prison_riot", // {}: everyone able joins
	"prison_calm", // {}: ends riots and fights, moods back to PRISONER_MOOD_START
	"prison_breakout", // {ref}: out of the cell block and loose
))

/// The running prison of an outpost, if it has one
/obj/structure/overmap/dynamic/player_outpost/proc/running_prison()
	var/datum/outpost_upgrade/prison/wing = outpost_upgrades["prison"]
	return istype(wing) && !QDELETED(wing.prison) ? wing.prison : null

/// The selected outpost's `prison` entry for OutpostManipulator.tsx, or null without a prison
/datum/outpost_manipulator/proc/prison_admin_data(obj/structure/overmap/dynamic/player_outpost/home)
	var/datum/outpost_prison/prison = home.running_prison()
	return prison?.admin_payload()

/datum/outpost_manipulator/proc/manage_prison(obj/structure/overmap/dynamic/player_outpost/home, mob/user, action, list/params)
	if(!valid_selection(home, user))
		return
	error = null
	var/datum/outpost_prison/prison = home.running_prison()
	if(!prison)
		error = "This outpost has no prison wing."
		return
	switch(action)
		if("prison_intake")
			var/open = admin_bool(params["open"])
			if(isnull(open))
				error = "Invalid intake setting."
				return
			prison.set_intake(open, user)
			record(user, home, "[open ? "open" : "close"] prison intake")
		if("prison_spawn")
			var/mob/living/basic/outpost_prisoner/arrival = prison.admit_next()
			if(!arrival)
				error = "No free cell."
				return
			record(user, home, "beam prisoner [arrival.real_name] into cell [arrival.cell?.number]")
		if("prison_fill")
			var/count = 0
			while(prison.admit_next())
				count++
			if(!count)
				error = "No free cell."
				return
			record(user, home, "fill [count] prison cell\s")
		if("prison_release", "prison_kill", "prison_remove", "prison_set", "prison_fight", "prison_breakout")
			var/mob/living/basic/outpost_prisoner/prisoner = locate(params["ref"]) in prison.prisoners
			if(QDELETED(prisoner))
				error = "That prisoner is gone."
				return
			switch(action)
				if("prison_fight")
					if(!prisoner.can_join_riot() || prisoner.trouble)
						error = "That prisoner can't fight now."
						return
					var/mob/living/basic/outpost_prisoner/partner = prison.nearest_fight_partner(prisoner)
					if(!partner)
						error = "No other prisoner can fight."
						return
					if(!prison.start_fight(prisoner, partner))
						error = "The fight did not start."
						return
					record(user, home, "start a prison fight between [prisoner.real_name] and [partner.real_name]")
				if("prison_breakout")
					if(prisoner.trouble == PRISONER_TROUBLE_LOOSE)
						error = "That prisoner is already loose."
						return
					if(prisoner.stat == DEAD || prisoner.phase != PRISONER_PRESENT)
						error = "Only a living prisoner in the wing can break out."
						return
					var/turf/outside = prison.outside_spot_near(prisoner)
					if(!outside)
						error = "There is nowhere outside the cell block to put them."
						return
					prisoner.pulledby?.stop_pulling()
					prisoner.forceMove(outside)
					prison.prisoner_escaped(prisoner, breakout = TRUE)
					record(user, home, "break prisoner [prisoner.real_name] out of the cell block")
				if("prison_release")
					if(prisoner.phase != PRISONER_PRESENT || prisoner.stat == DEAD)
						error = "Only a living prisoner in the wing can be released."
						return
					var/bonus = prison.release(prisoner)
					record(user, home, "release prisoner [prisoner.real_name] (+[bonus] cr)")
				if("prison_kill")
					if(prisoner.stat == DEAD)
						error = "Already dead."
						return
					prisoner.death()
					record(user, home, "kill prisoner [prisoner.real_name]")
				if("prison_remove")
					var/removed_name = prisoner.real_name
					prison.forget(prisoner)
					qdel(prisoner)
					record(user, home, "remove prisoner [removed_name] without a bonus")
				if("prison_set")
					var/field = params["field"]
					var/value = admin_number(params["value"])
					if(!(field in list("hunger", "grime", "health", "sentence", "mood")) || isnull(value))
						error = "Invalid prisoner setting."
						return
					if(!prison.admin_set(prisoner, field, value))
						error = "That prisoner can't take that setting."
						return
					record(user, home, "set prisoner [prisoner.real_name]'s [field] to [value]")
		if("prison_all")
			var/what = params["what"]
			if(!(what in list("starve", "feed", "dirty", "clean", "hurt", "heal", "enrage", "calm")))
				error = "Invalid prisoner-wide action."
				return
			var/count = prison.admin_all(what)
			record(user, home, "[what] all prisoners ([count])")
		if("prison_riot")
			if(prison.riot_active)
				error = "A riot is already on."
				return
			if(!prison.start_riot("started by an admin", everyone = TRUE))
				error = "Nobody in the cell block can riot."
				return
			record(user, home, "start a prison riot")
		if("prison_calm")
			var/calmed = prison.admin_calm()
			record(user, home, "calm the prison wing ([calmed] prisoner\s)")
		if("prison_advance")
			var/minutes = admin_number(params["minutes"])
			if(isnull(minutes) || minutes != round(minutes) || minutes < 1 || minutes > 60)
				error = "Advance by 1 to 60 whole minutes."
				return
			prison.admin_advance(minutes)
			record(user, home, "advance the prison by [minutes] min")
		if("prison_pay_now")
			var/paid = prison.admin_pay_now()
			record(user, home, "pay a prison minute now ([paid] cr)")
		if("prison_mess")
			var/made = prison.admin_mess()
			record(user, home, "make [made] piece\s of prison mess")
		if("prison_break_lights")
			var/broken = prison.admin_break_lights()
			record(user, home, "break [broken] prison light\s")
		if("prison_power")
			var/on = admin_bool(params["on"])
			if(isnull(on))
				error = "Invalid power setting."
				return
			if(!prison.admin_set_power(on))
				error = "The prison wing has no APC."
				return
			record(user, home, "[on ? "restore" : "cut"] prison power")

/// TRUE, FALSE or null for a tgui boolean param (0/1, "0"/"1", true/false)
/datum/outpost_manipulator/proc/admin_bool(value)
	if(istext(value))
		value = text2num(value)
	if(value == 0 || value == 1)
		return value
	return null

/// A finite number from a tgui param, or null
/datum/outpost_manipulator/proc/admin_number(value)
	if(istext(value))
		value = text2num(value)
	if(!isnum(value) || value != value || value == INFINITY || value == -INFINITY)
		return null
	return value

// ===== PRISON SIDE =====

/// The Prison section's data: everything about the wing and each prisoner
/datum/outpost_prison/proc/admin_payload()
	var/list/cell_rows = list()
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		cell_rows += list(list("number" = cell.number, "occupant_ref" = cell.occupant ? REF(cell.occupant) : null))
	var/list/prisoner_rows = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in roster_order())
		prisoner_rows += list(list(
			"ref" = REF(prisoner),
			"name" = prisoner.real_name,
			"cell" = prisoner.cell?.number || 0,
			"personality" = prisoner.personality,
			"crime" = prisoner.crime,
			"activity" = prisoner.admin_activity_text(),
			"hunger" = round(prisoner.hunger),
			"grime" = round(prisoner.uniform_grime),
			"health" = round(prisoner.health_factor()),
			"care" = round(prisoner.care()),
			"sentence_left" = max(0, round(prisoner.sentence_left)),
			"dead" = prisoner.stat == DEAD,
			"locked_in" = prisoner.locked_in_seconds > 0,
			"mood" = round(prisoner.mood),
			"state" = prisoner.trouble_state(),
			"loose_left" = prisoner.loose_seconds_shown(),
		))
	return list(
		"tension" = round(tension),
		"stage" = stage,
		"breakout_in" = (riot_active && !breaking_out) ? max(0, round(PRISON_RIOT_BREAKOUT_TIME - riot_elapsed)) : null,
		"intake_open" = intake_open,
		"next_arrival" = (intake_open && !isnull(arrival_countdown)) ? round(arrival_countdown) : null,
		"pay_rate" = round(pay_rate(), 0.1),
		"paid_total" = paid_total,
		"powered" = is_powered(),
		"conditions" = conditions_payload(),
		"cells" = cell_rows,
		"prisoners" = prisoner_rows,
	)

/// What they are up to, in a few words
/mob/living/basic/outpost_prisoner/proc/admin_activity_text()
	if(stat == DEAD)
		return "dead"
	if(phase == PRISONER_ARRIVING)
		return "beaming in"
	if(phase == PRISONER_LEAVING)
		return "beaming out"
	if(pulledby)
		return "being dragged"
	if(beaten_left > 0)
		return "beaten ([round(beaten_left)] s)"
	if(can_be_dragged())
		return "down"
	if(trouble == PRISONER_TROUBLE_LOOSE)
		return prison?.in_cell_block(src) ? "loose, back in the cell block" : "loose"
	if(climb_ref)
		return "climbing over a hatch"
	if(is_rioting())
		var/atom/target = riot_target_ref?.resolve()
		return trouble == PRISONER_TROUBLE_BREAKOUT ? "breaking out" : (target ? "rioting: [target.name]" : "rioting")
	if(fight)
		var/mob/living/opponent = fight.opponent_of(src)
		return "[fight.fighting ? "fighting" : "arguing with"] [opponent?.real_name]"
	var/mob/living/threatened = threat_ref?.resolve() || swing_ref?.resolve()
	if(threatened)
		return "threatening [threatened.name]"
	var/text = activity?.name || "idle"
	if(ai_controller?.ai_status != AI_STATUS_ON)
		text += " (AI asleep)"
	return text

/// Sets one of a prisoner's values. Returns FALSE if it can't take it.
/datum/outpost_prison/proc/admin_set(mob/living/basic/outpost_prisoner/prisoner, field, value)
	switch(field)
		if("hunger")
			prisoner.set_hunger(clamp(value, 0, 100))
		if("grime")
			prisoner.set_uniform_grime(clamp(value, 0, 100))
		if("health")
			// 1 to 100 percent; killing has its own button.
			if(prisoner.stat == DEAD)
				return FALSE
			var/target_loss = prisoner.maxHealth * (100 - clamp(value, 1, 100)) / 100
			prisoner.adjustBruteLoss(target_loss - prisoner.getBruteLoss(), forced = TRUE)
		if("sentence")
			if(prisoner.stat == DEAD || prisoner.phase != PRISONER_PRESENT)
				return FALSE
			prisoner.sentence_left = clamp(round(value), 0, 24 * 60 * 60)
			prisoner.said_release_soon = prisoner.sentence_left <= 90
		if("mood")
			if(prisoner.stat == DEAD)
				return FALSE
			prisoner.set_mood(value)
		else
			return FALSE
	return TRUE

/// Applies one change to every living prisoner. Returns how many.
/datum/outpost_prison/proc/admin_all(what)
	var/count = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.stat == DEAD || prisoner.phase == PRISONER_LEAVING)
			continue
		count++
		switch(what)
			if("starve")
				prisoner.set_hunger(0)
			if("feed")
				prisoner.set_hunger(100)
			if("dirty")
				prisoner.set_uniform_grime(100)
			if("clean")
				prisoner.set_uniform_grime(0)
			if("hurt")
				// A real hit, so they bleed, never a killing one.
				var/damage = min(30, prisoner.health - 1)
				if(damage > 0)
					prisoner.apply_damage(damage, BRUTE)
			if("heal")
				prisoner.adjustBruteLoss(-prisoner.getBruteLoss(), forced = TRUE)
				prisoner.setStaminaLoss(0)
			if("enrage")
				// Low enough to threaten staff, fight, and riot once it has held for half a minute.
				prisoner.set_mood(10)
			if("calm")
				prisoner.set_mood(100)
	return count

/// Ends every riot and fight and puts every mood back to PRISONER_MOOD_START. Loose prisoners stay loose.
/datum/outpost_prison/proc/admin_calm()
	var/count = 0
	for(var/datum/outpost_prison_fight/brawl as anything in fights.Copy())
		end_fight(brawl)
	if(riot_active)
		end_riot()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.stat == DEAD || prisoner.phase == PRISONER_LEAVING)
			continue
		prisoner.cancel_threat()
		prisoner.calm_down()
		prisoner.set_mood(PRISONER_MOOD_START)
		count++
	tension_spike = 0
	riot_hold = 0
	update_stage(0)
	return count

/// The nearest other prisoner who could fight, for the admin fight button
/datum/outpost_prison/proc/nearest_fight_partner(mob/living/basic/outpost_prisoner/prisoner)
	var/mob/living/basic/outpost_prisoner/nearest
	var/nearest_distance = INFINITY
	for(var/mob/living/basic/outpost_prisoner/other in prisoners)
		if(other == prisoner || !other.can_join_riot() || other.trouble)
			continue
		var/distance = get_dist(prisoner, other)
		if(distance < nearest_distance)
			nearest = other
			nearest_distance = distance
	return nearest

/// What the admin panel shows as their state
/mob/living/basic/outpost_prisoner/proc/trouble_state()
	if(trouble == PRISONER_TROUBLE_LOOSE)
		return "loose"
	if(beaten_left > 0)
		return "beaten"
	if(is_rioting())
		return "rioting"
	if(trouble == PRISONER_TROUBLE_FIGHT)
		return "fighting"
	return "normal"

/// Seconds left loose, shown only while they are out of the cell block
/mob/living/basic/outpost_prisoner/proc/loose_seconds_shown()
	if(trouble != PRISONER_TROUBLE_LOOSE || stat == DEAD || prison?.in_cell_block(src))
		return null
	return max(0, round(loose_left))

/// Runs the prison forward, in half-minute steps so arrivals and releases keep their order
/datum/outpost_prison/proc/admin_advance(minutes)
	var/left = minutes * 60
	while(left > 0)
		var/step = min(30, left)
		tick(step)
		left -= step
		CHECK_TICK

/// Pays a minute at the current rate straight away. Returns what was deposited.
/datum/outpost_prison/proc/admin_pay_now()
	pay_owed += pay_rate()
	return deposit_pay()

/// Leaves dirt, crumbs, blood and wrappers about the wing. Returns how many.
/datum/outpost_prison/proc/admin_mess()
	var/list/floors = list()
	for(var/turf/open/tile in wing_turfs())
		if(prisoner_can_stand(tile) && !cell_at(tile))
			floors += tile
	var/made = 0
	for(var/i in 1 to 5)
		if(!length(floors))
			break
		var/turf/open/tile = pick_n_take(floors)
		var/mess_type = pick(
			/obj/effect/decal/cleanable/dirt,
			/obj/effect/decal/cleanable/food/crumbs,
			/obj/effect/decal/cleanable/blood,
			/obj/item/trash/candy,
			/obj/item/trash/tray,
		)
		new mess_type(tile)
		made++
	refresh_conditions()
	return made

/// Breaks every working light in the wing. Returns how many.
/datum/outpost_prison/proc/admin_break_lights()
	var/broken = 0
	for(var/turf/tile as anything in wing_turfs())
		for(var/obj/machinery/light/fixture in tile)
			if(fixture.status == LIGHT_OK)
				fixture.break_light_tube()
				broken++
	refresh_conditions()
	return broken

/// Switches the wing's APC off or on. FALSE if it has none.
/datum/outpost_prison/proc/admin_set_power(on)
	var/obj/machinery/power/apc/apc = wing?.apc
	if(!apc)
		return FALSE
	apc.operating = !!on
	apc.update()
	apc.update_appearance()
	refresh_conditions()
	return TRUE
