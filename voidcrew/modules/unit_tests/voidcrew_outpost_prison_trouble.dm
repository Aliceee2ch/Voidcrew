/**
 * Prison trouble (step 3): mood, the wing's stages and sparks, threats and swings at staff,
 * fights, the beaten state, riots with their lights and shivs, the serving hatch climb, escapes,
 * the loose clock and its fine, recapture, the turret rule and the admin buttons.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Prisons are driven with tick() (or the trouble procs it calls) with
 * their own processing stopped; nobody is on the level, so the AI sleeps and the tests call the
 * blows (confront()) themselves. Fixtures come from voidcrew_outpost_prison.dm.
 */

/// A prison claim with trouble switched on and every bulb working
/datum/unit_test/voidcrew_outpost_management/proc/trouble_test_claim(owner_key)
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim(owner_key)
	if(!home)
		return null
	var/datum/outpost_prison/prison = test_prison(home)
	prison.trouble_enabled = TRUE
	for(var/turf/tile as anything in prison.wing_turfs())
		for(var/obj/machinery/light/fixture in tile)
			if(fixture.status != LIGHT_OK)
				fixture.fix()
	prison.refresh_conditions()
	return home

/// A prisoner with a known personality at mood 70, booked in and standing still at `spot`
/datum/unit_test/voidcrew_outpost_management/proc/trouble_prisoner(datum/outpost_prison/prison, turf/spot, personality = "chatty")
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, spot)
	prisoner.personality = personality
	prisoner.set_mood(70)
	return prisoner

/datum/unit_test/voidcrew_outpost_management/proc/drift_is(mob/living/basic/outpost_prisoner/prisoner, expected)
	return abs(prisoner.mood_drift_per_minute() - expected) < 0.01

/datum/unit_test/voidcrew_outpost_management/proc/set_moods(list/prisoners, mood)
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in prisoners)
		prisoner.set_mood(mood)

/datum/unit_test/voidcrew_outpost_management/proc/all_lights(datum/outpost_prison/prison)
	var/list/lights = list()
	for(var/turf/tile as anything in prison.wing_turfs())
		for(var/obj/machinery/light/fixture in tile)
			lights += fixture
	return lights

/datum/unit_test/voidcrew_outpost_management/proc/set_wing_power(datum/outpost_prison/prison, on)
	var/obj/machinery/power/apc/apc = prison.wing.apc
	apc.operating = on
	apc.update()
	prison.refresh_conditions()

/datum/unit_test/voidcrew_outpost_management/proc/hit_with_toolbox(mob/living/carbon/human/attacker, mob/living/target)
	var/obj/item/storage/toolbox/toolbox = attacker.get_active_held_item()
	if(!istype(toolbox))
		attacker.drop_all_held_items()
		toolbox = allocate(/obj/item/storage/toolbox)
		attacker.put_in_active_hand(toolbox)
	attacker.set_combat_mode(TRUE)
	click_wrapper(attacker, target)
	attacker.set_combat_mode(FALSE)

/// Whether `line` is one of the dialogue file's lines for `context`, for any personality
/datum/unit_test/voidcrew_outpost_management/proc/is_line_for(line, context)
	var/list/lines = outpost_prisoner_dialogue("lines")
	var/list/entry = lines[context]
	if(!islist(entry) || !line)
		return FALSE
	for(var/pool_key in entry)
		for(var/candidate in entry[pool_key])
			if(findtext(candidate, "{"))
				// A line with placeholders: compare what is left of it around them.
				var/list/parts = splittext(candidate, regex("\\{\[a-z_\]+\\}"))
				var/all_found = TRUE
				for(var/part in parts)
					if(length(part) && !findtext(line, part))
						all_found = FALSE
						break
				if(all_found)
					return TRUE
			else if(candidate == line)
				return TRUE
	return FALSE

// ===== MOOD =====

/datum/unit_test/voidcrew_outpost_prison_mood
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_mood/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("moodowner")
	TEST_ASSERT_NOTNULL(home, "The mood test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = trouble_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/buddy = trouble_prisoner(prison, prison_spot(home, 7, 8))
	var/mob/living/basic/outpost_prisoner/fresh_arrival = allocate(/mob/living/basic/outpost_prisoner, prison_spot(home, 12, 8))
	TEST_ASSERT_EQUAL(fresh_arrival.mood, 70, "A prisoner does not start at 70 mood") // PRISONER_MOOD_START
	qdel(fresh_arrival)
	TEST_ASSERT(abs(prison.conditions_score() - 100) < 0.01, "The mood test wing is not in perfect condition")

	// Per minute: a well kept prisoner in a wing with every condition at 80+ gains 2.
	TEST_ASSERT(drift_is(prisoner, 2), "A well kept prisoner drifts [prisoner.mood_drift_per_minute()], not +2")
	prisoner.set_hunger(30)
	TEST_ASSERT(drift_is(prisoner, 2 - 3), "Hungry drifts [prisoner.mood_drift_per_minute()], not -1") // PRISONER_MOOD_HUNGRY
	prisoner.set_hunger(10)
	TEST_ASSERT(drift_is(prisoner, 2 - 8), "Starving drifts [prisoner.mood_drift_per_minute()], not -6") // PRISONER_MOOD_STARVING
	prisoner.set_hunger(100)
	prisoner.set_uniform_grime(60)
	TEST_ASSERT(drift_is(prisoner, 2 - 2), "A dirty uniform drifts [prisoner.mood_drift_per_minute()], not 0") // PRISONER_MOOD_DIRTY
	prisoner.set_uniform_grime(90)
	TEST_ASSERT(drift_is(prisoner, 2 - 5), "A filthy uniform drifts [prisoner.mood_drift_per_minute()], not -3") // PRISONER_MOOD_FILTHY
	prisoner.set_uniform_grime(0)
	prisoner.adjustBruteLoss(50)
	TEST_ASSERT(drift_is(prisoner, 2 - 4), "Half health drifts [prisoner.mood_drift_per_minute()], not -2") // 4 x missing x 2
	prisoner.adjustBruteLoss(-50)
	prisoner.activity = new /datum/prisoner_activity/chat(prisoner)
	TEST_ASSERT(drift_is(prisoner, 2 + 1), "Chatting drifts [prisoner.mood_drift_per_minute()], not +3") // PRISONER_MOOD_ACTIVITY
	prisoner.end_activity(cancel_ai = FALSE)
	prisoner.sentence_left = 120
	TEST_ASSERT(drift_is(prisoner, 2 + 3), "Nearly out drifts [prisoner.mood_drift_per_minute()], not +5") // PRISONER_MOOD_RELEASE_SOON
	prisoner.sentence_left = 3600
	// Bolted in past two minutes: 6, and one more for each minute after.
	prisoner.locked_in_seconds = 150
	TEST_ASSERT(drift_is(prisoner, 2 - 6), "Bolted in 2.5 minutes drifts [prisoner.mood_drift_per_minute()], not -4") // PRISONER_MOOD_LOCKED_IN
	prisoner.locked_in_seconds = 200
	TEST_ASSERT(drift_is(prisoner, 2 - 7), "Bolted in 3.3 minutes drifts [prisoner.mood_drift_per_minute()], not -5")
	prisoner.locked_in_seconds = 0

	// The wing: dirty below 60 clean, dark below 50 lit, unpowered. Each also loses the +2.
	var/list/mess = list()
	for(var/x in 3 to 11)
		mess += allocate(/obj/effect/decal/cleanable/dirt, prison_spot(home, x, 7))
	prison.refresh_conditions()
	TEST_ASSERT_EQUAL(prison.clean_score, 55, "Nine pieces of mess did not leave the wing at 55 clean")
	TEST_ASSERT(drift_is(prisoner, -3), "A dirty wing drifts [prisoner.mood_drift_per_minute()], not -3") // PRISONER_MOOD_DIRTY_WING
	QDEL_LIST(mess)
	var/list/lights = all_lights(prison)
	for(var/obj/machinery/light/fixture as anything in lights)
		fixture.break_light_tube()
	prison.refresh_conditions()
	TEST_ASSERT(drift_is(prisoner, -4), "A dark wing drifts [prisoner.mood_drift_per_minute()], not -4") // PRISONER_MOOD_DARK
	for(var/obj/machinery/light/fixture as anything in lights)
		fixture.fix()
	set_wing_power(prison, FALSE)
	TEST_ASSERT(drift_is(prisoner, -5 - 4), "An unpowered, dark wing drifts [prisoner.mood_drift_per_minute()], not -9") // PRISONER_MOOD_NO_POWER
	set_wing_power(prison, TRUE)
	TEST_ASSERT(drift_is(prisoner, 2), "The wing did not recover (drift [prisoner.mood_drift_per_minute()])")

	// Personality scales the losses: grumpy 1.4, nervous 1.2, chatty 1, quiet 0.9, cheerful 0.7.
	prisoner.set_hunger(10)
	var/list/scales = list("grumpy" = 1.4, "nervous" = 1.2, "chatty" = 1, "quiet" = 0.9, "cheerful" = 0.7)
	for(var/personality in scales)
		prisoner.personality = personality
		TEST_ASSERT(drift_is(prisoner, 2 - 8 * scales[personality]), "A starving [personality] prisoner drifts [prisoner.mood_drift_per_minute()], not [2 - 8 * scales[personality]]")
	prisoner.personality = "grumpy"
	prisoner.set_mood(50)
	prisoner.adjust_mood(-10)
	TEST_ASSERT(abs(prisoner.mood - 36) < 0.01, "A grumpy prisoner's -10 came to [50 - prisoner.mood], not 14")
	prisoner.adjust_mood(10)
	TEST_ASSERT(abs(prisoner.mood - 46) < 0.01, "Personality scaled a gain")
	prisoner.personality = "chatty"
	prisoner.set_hunger(100)
	prisoner.set_mood(5)
	prisoner.adjust_mood(-50)
	TEST_ASSERT_EQUAL(prisoner.mood, 0, "Mood went below 0")
	prisoner.adjust_mood(500)
	TEST_ASSERT_EQUAL(prisoner.mood, 100, "Mood went above 100")

	// A minute of the prison's own clock applies the drift.
	prisoner.set_mood(70)
	prison.tick(60)
	TEST_ASSERT(abs(prisoner.mood - 72) < 0.01, "A minute well kept left mood at [prisoner.mood], not 72")

	// Instant changes: a meal +10, a clean uniform +8, treatment +8, a hit by staff -15.
	prisoner.set_mood(40)
	prisoner.set_hunger(20)
	var/obj/item/food/prison_ration/meal = new(prison_spot(home, 8, 8))
	prisoner.finish_meal(meal, prison_spot(home, 8, 8), null)
	TEST_ASSERT(abs(prisoner.mood - 50) < 0.01, "A meal left mood at [prisoner.mood], not 50") // PRISONER_MOOD_FED
	prisoner.set_uniform_grime(80)
	var/obj/item/clothing/under/rank/prisoner/outpost/fresh = new(prison_spot(home, 8, 8))
	prisoner.swap_uniform(fresh, prison_spot(home, 8, 8))
	TEST_ASSERT(abs(prisoner.mood - 58) < 0.01, "A clean uniform left mood at [prisoner.mood], not 58") // PRISONER_MOOD_CLEAN_UNIFORM
	prisoner.adjustBruteLoss(30)
	COOLDOWN_START(prisoner, treatment_window, 20 SECONDS)
	prisoner.adjustBruteLoss(-30)
	TEST_ASSERT(abs(prisoner.mood - 66) < 0.01, "Treatment left mood at [prisoner.mood], not 66") // PRISONER_MOOD_TREATED
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 9, 8), "moodowner")
	var/spike_before = prison.tension_spike
	hit_with_toolbox(warden, prisoner)
	TEST_ASSERT(prisoner.health < 100, "The toolbox missed")
	TEST_ASSERT(abs(prisoner.mood - 51) < 0.01, "A hit by staff left mood at [prisoner.mood], not 51") // PRISONER_MOOD_HIT_BY_STAFF
	TEST_ASSERT(prison.tension_spike >= spike_before + 5, "A hit by staff did not raise tension") // PRISON_SPIKE_STAFF_HIT
	// Another prisoner's punch is not staff.
	var/mood_before = prisoner.mood
	buddy.strike(prisoner)
	TEST_ASSERT(abs(prisoner.mood - mood_before) < 0.01, "A punch from another prisoner counted as staff")
	settle_prison_air(home)

// ===== STAGES AND SPARKS =====

/datum/unit_test/voidcrew_outpost_prison_stages
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_stages/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("stageowner")
	TEST_ASSERT_NOTNULL(home, "The stage test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/first = trouble_prisoner(prison, prison_spot(home, 7, 8))
	var/mob/living/basic/outpost_prisoner/second = trouble_prisoner(prison, prison_spot(home, 11, 8))
	var/list/both = list(first, second)
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 7, 7), "stageowner")

	// Tension is 100 minus the mean mood; calm below 40, grumbling from 40, restless from 60.
	first.set_mood(80)
	second.set_mood(60)
	prison.update_stage(1)
	TEST_ASSERT(abs(prison.tension - 30) < 0.01, "Moods 80 and 60 gave tension [prison.tension], not 30")
	TEST_ASSERT_EQUAL(prison.stage, "calm", "Tension 30 is [prison.stage]")
	set_moods(both, 60)
	prison.update_stage(1)
	TEST_ASSERT_EQUAL(prison.stage, "grumbling", "Tension 40 is [prison.stage]") // PRISON_TENSION_GRUMBLING
	set_moods(both, 40)
	prison.update_stage(1)
	TEST_ASSERT_EQUAL(prison.stage, "restless", "Tension 60 is [prison.stage]") // PRISON_TENSION_RESTLESS
	// Event spikes add to it and decay by 0.25 a second (PRISON_SPIKE_DECAY).
	set_moods(both, 70)
	prison.tension_spike = 25
	prison.update_stage(1)
	TEST_ASSERT(abs(prison.tension - 55) < 0.01, "A 25 spike on tension 30 gave [prison.tension]")
	TEST_ASSERT_EQUAL(prison.stage, "grumbling", "Tension 55 is [prison.stage]")
	prison.trouble_tick(40)
	TEST_ASSERT(abs(prison.tension_spike - 15) < 0.01, "The spike was [prison.tension_spike] after 40 seconds, not 15")
	prison.tension_spike = 0

	// A riot needs tension 80 or more held for 30 seconds (PRISON_TENSION_RIOT, PRISON_RIOT_HOLD).
	set_moods(both, 10)
	prison.update_stage(29)
	TEST_ASSERT(!prison.riot_active, "A riot started before tension held for 30 seconds")
	TEST_ASSERT_EQUAL(prison.stage, "restless", "Tension 90 before the hold is [prison.stage]")
	set_moods(both, 50)
	prison.update_stage(1)
	set_moods(both, 10)
	prison.update_stage(20)
	TEST_ASSERT(!prison.riot_active, "Dropping below 80 did not reset the hold")
	prison.update_stage(10)
	TEST_ASSERT(prison.riot_active, "Thirty seconds at tension 90 started no riot")
	TEST_ASSERT_EQUAL(prison.stage, "riot", "A riot's stage is [prison.stage]")
	prison.admin_calm()
	TEST_ASSERT(!prison.riot_active, "Calming the wing left the riot on")

	// Sparks start one at once, but only while restless.
	set_moods(both, 80)
	prison.tension_spike = 0
	prison.update_stage(0)
	set_wing_power(prison, FALSE)
	TEST_ASSERT(!prison.riot_active, "A power cut in a calm wing started a riot")
	TEST_ASSERT(prison.tension_spike >= 10, "A power cut did not raise tension") // PRISON_SPIKE_POWER_CUT
	set_wing_power(prison, TRUE)
	prison.tension_spike = 0
	set_moods(both, 35)
	prison.update_stage(0)
	TEST_ASSERT_EQUAL(prison.stage, "restless", "Tension 65 is [prison.stage]")
	set_wing_power(prison, FALSE)
	TEST_ASSERT(prison.riot_active, "A power cut in a restless wing started no riot")
	prison.admin_calm()
	set_wing_power(prison, TRUE)

	prison.tension_spike = 0
	set_moods(both, 35)
	prison.update_stage(0)
	var/list/lights = all_lights(prison)
	for(var/obj/machinery/light/fixture as anything in lights)
		fixture.break_light_tube()
	prison.refresh_conditions()
	TEST_ASSERT(prison.riot_active, "The lights going out in a restless wing started no riot")
	prison.admin_calm()
	for(var/obj/machinery/light/fixture as anything in lights)
		fixture.fix()
	prison.refresh_conditions()

	// Staff beating a prisoner down while restless: the other one riots.
	prison.tension_spike = 0
	set_moods(both, 35)
	prison.update_stage(0)
	first.adjustBruteLoss(80)
	hit_with_toolbox(warden, first)
	TEST_ASSERT(first.beaten_left > 0, "A prisoner at 20 health hit with a toolbox did not collapse")
	TEST_ASSERT(first.beaten_by_staff, "The collapse was not put down to staff")
	TEST_ASSERT(prison.riot_active, "A prisoner beaten down by staff in a restless wing started no riot")
	TEST_ASSERT_EQUAL(second.trouble, "riot", "The other prisoner did not riot")
	TEST_ASSERT_NULL(first.trouble, "A beaten prisoner joined the riot")
	prison.admin_calm()
	first.adjustBruteLoss(-100)
	first.recover()

	// Staff killing one while restless: the same.
	prison.tension_spike = 0
	set_moods(both, 35)
	prison.update_stage(0)
	warden.forceMove(prison_spot(home, 11, 7))
	second.adjustBruteLoss(95)
	hit_with_toolbox(warden, second)
	TEST_ASSERT_EQUAL(second.stat, DEAD, "A prisoner at 5 health survived a toolbox")
	TEST_ASSERT(second.death_blamed, "The death was not put down to staff")
	TEST_ASSERT(prison.riot_active, "Staff killing a prisoner in a restless wing started no riot")
	TEST_ASSERT_EQUAL(first.trouble, "riot", "The surviving prisoner did not riot")
	prison.admin_calm()
	settle_prison_air(home)

// ===== THREATS =====

/datum/unit_test/voidcrew_outpost_prison_threats
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_threats/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("threatowner")
	TEST_ASSERT_NOTNULL(home, "The threat test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = trouble_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 10, 8), "threatowner")

	// 35 or more: never.
	prisoner.set_mood(40)
	for(var/i in 1 to 5)
		prison.tick(1)
	TEST_ASSERT_NULL(prisoner.threat_ref, "A prisoner at mood 40 threatened staff") // PRISONER_THREAT_MOOD

	// Below 35, staff within two tiles in the cell block get a threat first.
	prisoner.set_mood(25)
	prison.tick(1)
	TEST_ASSERT_EQUAL(prisoner.threat_ref?.resolve(), warden, "A prisoner at mood 25 did not threaten staff two tiles away")
	TEST_ASSERT_EQUAL(prisoner.dir, get_dir(prisoner, warden), "The prisoner did not face who they threatened")
	TEST_ASSERT(is_line_for(prisoner.last_line, "threaten_staff"), "The threat was not a threaten_staff line: [prisoner.last_line]")
	TEST_ASSERT_EQUAL(warden.getBruteLoss(), 0, "The threat itself hurt someone")
	// Staff stepping away ends it.
	warden.forceMove(prison_spot(home, 13, 8))
	prison.tick(1)
	TEST_ASSERT_NULL(prisoner.threat_ref, "The threat went on with staff five tiles away")

	// Staff outside the cell block, even two tiles off through a window, are left alone.
	prisoner.threat_cooldown = 0
	prisoner.forceMove(prison_spot(home, 8, 7))
	warden.forceMove(prison_spot(home, 8, 5))
	prison.tick(1)
	TEST_ASSERT_NULL(prisoner.threat_ref, "A prisoner threatened staff in the office")

	// Four seconds on (PRISONER_THREAT_TIME) the threat may become a swing: 5-8 brute when next to them.
	prisoner.forceMove(prison_spot(home, 8, 8))
	warden.forceMove(prison_spot(home, 9, 8))
	var/swung = FALSE
	for(var/attempt in 1 to 30)
		prisoner.cancel_threat()
		prisoner.threat_cooldown = 0
		prisoner.set_mood(10)
		prison.tick(1)
		TEST_ASSERT_NOTNULL(prisoner.threat_ref, "An angry prisoner beside staff did not threaten them")
		var/before = warden.getBruteLoss()
		prison.tick(4)
		TEST_ASSERT_NULL(prisoner.threat_ref, "The threat did not end after four seconds")
		if(warden.getBruteLoss() > before)
			var/dealt = warden.getBruteLoss() - before
			TEST_ASSERT(dealt >= 5 && dealt <= 8, "A punch did [dealt] brute, not 5-8") // PRISONER_PUNCH_MIN/MAX
			TEST_ASSERT(prisoner.threat_cooldown > 0, "A swing started no cooldown")
			swung = TRUE
			break
	TEST_ASSERT(swung, "An angry prisoner never swung in 30 threats")

	// The mood gate holds all the way to the swing.
	prisoner.cancel_threat()
	prisoner.threat_cooldown = 0
	prisoner.set_mood(20)
	prison.tick(1)
	TEST_ASSERT_NOTNULL(prisoner.threat_ref, "A prisoner at mood 20 did not threaten")
	prisoner.set_mood(40)
	var/before_gate = warden.getBruteLoss()
	prison.tick(4)
	TEST_ASSERT_NULL(prisoner.threat_ref, "A threat went on after mood rose to 40")
	TEST_ASSERT_EQUAL(warden.getBruteLoss(), before_gate, "A prisoner at mood 40 swung")
	for(var/i in 1 to 20)
		TEST_ASSERT(!prisoner.decide_swing(warden), "A prisoner at mood 40 decided to swing")
	settle_prison_air(home)

// ===== FIGHTS AND THE BEATEN STATE =====

/datum/unit_test/voidcrew_outpost_prison_fights
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_fights/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("fightowner")
	TEST_ASSERT_NOTNULL(home, "The fight test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/first = trouble_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/second = trouble_prisoner(prison, prison_spot(home, 10, 8))
	var/mob/living/basic/outpost_prisoner/onlooker = trouble_prisoner(prison, prison_spot(home, 12, 7))
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 8, 4), "fightowner")

	// Two prisoners below 30 within three tiles may start one; content ones never do.
	first.set_mood(50)
	second.set_mood(50)
	for(var/i in 1 to 20)
		TEST_ASSERT_NULL(prison.try_start_fight(), "Two prisoners at mood 50 started a fight") // PRISONER_FIGHT_MOOD
	first.set_mood(20)
	second.set_mood(20)
	var/datum/outpost_prison_fight/brawl
	for(var/i in 1 to 60)
		brawl = prison.try_start_fight()
		if(brawl)
			break
	TEST_ASSERT_NOTNULL(brawl, "Two prisoners at mood 20 two tiles apart never started a fight")
	TEST_ASSERT(first.fight == brawl && second.fight == brawl, "The fighters do not know their fight")
	TEST_ASSERT(first.trouble == "fight" && second.trouble == "fight", "The fighters are not in fight trouble")
	TEST_ASSERT(abs(onlooker.mood - 65) < 0.01, "Seeing a fight left the onlooker at [onlooker.mood], not 65") // PRISONER_MOOD_SAW_FIGHT
	TEST_ASSERT(prison.tension_spike >= 10, "A fight did not raise tension") // PRISON_SPIKE_FIGHT
	TEST_ASSERT_EQUAL(prison.prisoner_pay_rate(first), 0, "A fighter earned a stipend")

	// They argue for eight seconds (PRISONER_ARGUE_TIME) before anyone swings.
	second.forceMove(prison_spot(home, 9, 8))
	TEST_ASSERT(!first.confront(second), "A blow landed during the argument")
	TEST_ASSERT_EQUAL(second.health, 100, "The argument hurt someone")
	prison.tick(8)
	TEST_ASSERT(brawl.fighting, "Eight seconds of arguing did not turn into a fight")
	TEST_ASSERT(is_line_for(first.last_line, "fight_argue") || is_line_for(second.last_line, "fight_argue"), "Nobody said a fight_argue line")

	// Blows until one is beaten at 15% (PRISONER_BEATEN_BELOW); a prisoner never kills another.
	for(var/i in 1 to 40)
		if(second.beaten_left > 0)
			break
		TEST_ASSERT(first.confront(second), "A fighter could not land a blow")
		TEST_ASSERT(second.stat != DEAD && second.health >= 1, "A prisoner's blows killed another")
	TEST_ASSERT(second.beaten_left > 0, "A fight never beat anyone down")
	TEST_ASSERT(second.health_factor() <= 15, "The beaten prisoner is at [second.health_factor()]%")
	TEST_ASSERT_EQUAL(second.body_position, LYING_DOWN, "A beaten prisoner is standing")
	TEST_ASSERT(second.can_be_dragged(), "A beaten prisoner cannot be dragged")
	TEST_ASSERT(!second.routine_allowed(), "A beaten prisoner kept up their routine")
	TEST_ASSERT(is_line_for(second.last_line, "beaten"), "The beaten prisoner said no beaten line: [second.last_line]")
	TEST_ASSERT_NULL(first.fight, "The fight went on after one was beaten")
	TEST_ASSERT(!(brawl in prison.fights), "The finished fight stayed on the list")
	TEST_ASSERT(isnull(first.trouble) && isnull(second.trouble), "The fighters are still in fight trouble")
	TEST_ASSERT(first.fight_cooldown > 0, "A finished fight left no cooldown")
	// Nobody puts the boot in on a prisoner who is down.
	var/health_down = second.health
	TEST_ASSERT(!first.strike(second), "A prisoner hit another who was down")
	TEST_ASSERT_EQUAL(second.health, health_down, "A downed prisoner took a prisoner's blow")
	// Even a standing prisoner at 3 health is left alive by a punch.
	onlooker.adjustBruteLoss(97)
	onlooker.forceMove(prison_spot(home, 7, 8))
	first.strike(onlooker)
	TEST_ASSERT(onlooker.stat != DEAD && onlooker.health >= 1, "A punch killed a prisoner at 3 health")
	TEST_ASSERT(onlooker.beaten_left > 0, "A prisoner at 1-3 health did not collapse")

	// Treated above 40% they get up; untreated, after two minutes (PRISONER_BEATEN_TIME).
	second.adjustBruteLoss(-(second.getBruteLoss() - 50))
	prison.tick(1)
	TEST_ASSERT_EQUAL(second.beaten_left, 0, "Treatment to 50% did not get a beaten prisoner up")
	TEST_ASSERT(!second.can_be_dragged(), "A recovered prisoner is still down")
	TEST_ASSERT(is_line_for(second.last_line, "recovered"), "The recovered prisoner said no recovered line: [second.last_line]")
	// The onlooker went down one second before that tick.
	prison.tick(118)
	TEST_ASSERT(onlooker.beaten_left > 0, "An untreated prisoner got up early")
	prison.tick(1)
	TEST_ASSERT_EQUAL(onlooker.beaten_left, 0, "An untreated prisoner was still down after two minutes")

	// Only staff can kill a prisoner who is down.
	onlooker.adjustBruteLoss(-onlooker.getBruteLoss())
	onlooker.apply_damage(95, BRUTE)
	TEST_ASSERT(onlooker.beaten_left > 0, "A prisoner at 5 health did not collapse")
	warden.forceMove(prison_spot(home, 7, 7))
	for(var/i in 1 to 5)
		if(onlooker.stat == DEAD)
			break
		hit_with_toolbox(warden, onlooker)
	TEST_ASSERT_EQUAL(onlooker.stat, DEAD, "Staff could not finish off a downed prisoner")
	// Killing one sets the wing on edge; start the rematch from calm.
	prison.admin_calm()

	// Staff stunning one ends a fight.
	first.fight_cooldown = 0
	second.fight_cooldown = 0
	second.forceMove(prison_spot(home, 9, 8))
	var/datum/outpost_prison_fight/rematch = prison.start_fight(first, second)
	TEST_ASSERT_NOTNULL(rematch, "The rematch did not start")
	prison.tick(8)
	TEST_ASSERT(rematch.fighting, "The rematch never got past arguing")
	second.adjustStaminaLoss(200)
	TEST_ASSERT_NULL(first.fight, "A fight went on after staff stunned one fighter")
	TEST_ASSERT(isnull(first.trouble) && isnull(second.trouble), "Fight trouble outlasted the stun")
	second.setStaminaLoss(0)
	settle_prison_air(home)

// ===== RIOTS =====

/datum/unit_test/voidcrew_outpost_prison_riot
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_riot/proc/strobe_values(obj/machinery/light/fixture)
	var/list/seen = list()
	for(var/i in 1 to 8)
		seen |= fixture.light_power
		sleep(3)
	return seen

/datum/unit_test/voidcrew_outpost_prison_riot/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("riotowner")
	TEST_ASSERT_NOTNULL(home, "The riot test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/obj/machinery/computer/outpost_prison_warden/console = locate() in prison_spot(home, 7, 5)
	var/mob/living/basic/outpost_prisoner/first = trouble_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/second = trouble_prisoner(prison, prison_spot(home, 10, 8))
	var/mob/living/basic/outpost_prisoner/third = trouble_prisoner(prison, prison_spot(home, 12, 7))
	var/list/everyone = list(first, second, third)
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 8, 4), "riotowner")
	var/list/calm_data = console.ui_data(warden)
	TEST_ASSERT(("alarm" in calm_data) && ("alarm_text" in calm_data), "The warden console sends no alarm keys")
	TEST_ASSERT_NULL(calm_data["alarm"], "A calm wing has an alarm")

	set_moods(everyone, 10)
	prison.update_stage(30)
	TEST_ASSERT(prison.riot_active, "Thirty seconds at tension 90 started no riot")
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in everyone)
		TEST_ASSERT_EQUAL(rioter.trouble, "riot", "[rioter] did not join the riot")
		TEST_ASSERT(istype(rioter.held_item, /obj/item/knife/shiv), "[rioter] has no shiv out")
		TEST_ASSERT_EQUAL(rioter.bubble, "riot", "[rioter] shows the [rioter.bubble] bubble, not the shiv")
		TEST_ASSERT_EQUAL(rioter.melee_damage_lower, 10, "A shiv does not hit harder") // PRISONER_SHIV_MIN
		TEST_ASSERT_EQUAL(prison.prisoner_pay_rate(rioter), 0, "A rioter earned a stipend")
	var/list/riot_data = console.ui_data(warden)
	TEST_ASSERT_EQUAL(riot_data["alarm"], "riot", "The console alarm is [riot_data["alarm"]]")
	TEST_ASSERT_EQUAL(riot_data["alarm_text"], "Riot in the yard", "The console alarm reads [riot_data["alarm_text"]]")
	var/list/admin_data = prison.admin_payload()
	TEST_ASSERT_EQUAL(admin_data["stage"], "riot", "The admin stage is [admin_data["stage"]]")
	TEST_ASSERT_EQUAL(admin_data["breakout_in"], 180, "The breakout is due in [admin_data["breakout_in"]] s, not 180") // PRISON_RIOT_BREAKOUT_TIME

	// The lights go emergency red and strobe; the fire alarm is left alone.
	TEST_ASSERT(prison.riot_lights_on, "The riot lights did not come on")
	TEST_ASSERT(!prison.wing.fire, "The riot set off the fire alarm")
	for(var/obj/machinery/light/fixture as anything in all_lights(prison))
		TEST_ASSERT(fixture.major_emergency, "[fixture] at [fixture.x],[fixture.y] is not in emergency mode")
	var/obj/machinery/light/lamp = locate() in prison_spot(home, 2, 9)
	TEST_ASSERT(lamp?.on && lamp.status == LIGHT_OK, "The yard's west light is not on")
	TEST_ASSERT_EQUAL(lamp.light_color, lamp.bulb_emergency_colour, "A riot light is [lamp.light_color], not red")
	var/list/strobe = strobe_values(lamp)
	TEST_ASSERT(length(strobe) >= 2, "The riot light did not strobe ([jointext(strobe, ", ")])")

	// Rioters go for staff they can reach first, then the wing's fixtures, not the ways out yet.
	warden.forceMove(prison_spot(home, 8, 10))
	TEST_ASSERT_EQUAL(first.riot_target(), warden, "A rioter ignored staff in the yard")
	warden.forceMove(prison_spot(home, 8, 4))
	for(var/i in 1 to 40)
		first.riot_target_ref = null
		var/atom/target = first.riot_target()
		TEST_ASSERT_NOTNULL(target, "A rioter found nothing to smash")
		TEST_ASSERT(first.reachable[get_turf(target)], "A rioter went for [target] out of reach")
		TEST_ASSERT(!istype(target, /obj/structure/table/reinforced/prison_hatch), "A rioter went for a serving hatch before the breakout")
		if(istype(target, /obj/structure/window) || istype(target, /obj/structure/grille))
			TEST_ASSERT(!prison.on_wing_edge(get_turf(target)), "A rioter went for a window in the outer wall")
			TEST_ASSERT(!prison.leads_out_of_cell_block(get_turf(target)), "A rioter went for a window out of the cell block before the breakout")
	// Smashing: a light breaks, a table takes damage, staff get the shiv (10-15).
	var/obj/machinery/light/yard_light = locate() in prison_spot(home, 5, 11)
	TEST_ASSERT_NOTNULL(yard_light, "The yard light is not where the map puts it")
	first.forceMove(prison_spot(home, 5, 10))
	TEST_ASSERT(first.confront(yard_light), "A rioter could not hit a light")
	TEST_ASSERT_EQUAL(yard_light.status, LIGHT_BROKEN, "A rioter's blow did not break the light")
	var/obj/structure/table/table = locate() in prison_spot(home, 4, 9)
	TEST_ASSERT_NOTNULL(table, "The mess table is not where the map puts it")
	var/table_before = table.get_integrity()
	first.forceMove(prison_spot(home, 4, 8))
	first.confront(table)
	TEST_ASSERT_EQUAL(table_before - table.get_integrity(), 10, "A rioter's blow did [table_before - table.get_integrity()] to a table, not 10") // PRISON_SMASH_DAMAGE
	warden.forceMove(prison_spot(home, 5, 8))
	var/brute_before = warden.getBruteLoss()
	first.confront(warden)
	var/stabbed = warden.getBruteLoss() - brute_before
	TEST_ASSERT(stabbed >= 10 && stabbed <= 15, "A shiv did [stabbed] brute, not 10-15") // PRISONER_SHIV_MIN/MAX
	warden.forceMove(prison_spot(home, 8, 4))
	warden.fully_heal()

	// Stunned or beaten, a rioter drops a real shiv and calms to 40 (PRISONER_RIOT_CALM_MOOD).
	first.adjustStaminaLoss(200)
	TEST_ASSERT(isnull(first.trouble), "A stunned rioter kept rioting")
	TEST_ASSERT(!istype(first.held_item, /obj/item/knife/shiv), "A stunned rioter kept the shiv")
	TEST_ASSERT_NOTNULL(locate(/obj/item/knife/shiv) in first.loc, "A stunned rioter dropped no shiv")
	TEST_ASSERT(abs(first.mood - 40) < 0.01, "A stunned rioter calmed to [first.mood], not 40")
	second.apply_damage(90, BRUTE)
	TEST_ASSERT(second.beaten_left > 0, "A rioter at 10 health did not collapse")
	TEST_ASSERT(isnull(second.trouble), "A beaten rioter kept rioting")
	TEST_ASSERT_NOTNULL(locate(/obj/item/knife/shiv) in second.loc, "A beaten rioter dropped no shiv")

	// The riot is over once no rioter is standing and free: bolted in a cell does not count.
	TEST_ASSERT(prison.riot_active, "The riot ended with a rioter still going")
	var/datum/outpost_prison_cell/cell_three = prison.cells[3]
	var/obj/machinery/door/airlock/cell_door = cell_three.door()
	third.forceMove(prison_spot(home, 11, 14))
	if(!cell_door.density)
		cell_door.close()
	cell_door.bolt()
	prison.tick(1)
	TEST_ASSERT(!prison.riot_active, "The riot went on with its last rioter bolted in a cell")
	TEST_ASSERT(isnull(third.trouble), "The bolted-in rioter kept rioting after the riot")
	TEST_ASSERT(!prison.riot_lights_on, "The riot lights stayed on")
	for(var/obj/machinery/light/fixture as anything in all_lights(prison))
		TEST_ASSERT(!fixture.major_emergency, "[fixture] stayed in emergency mode")
	TEST_ASSERT(lamp.light_color != lamp.bulb_emergency_colour, "A light stayed red after the riot")
	TEST_ASSERT_NULL(console.ui_data(warden)["alarm"], "The alarm outlasted the riot")
	cell_door.unbolt()
	third.forceMove(prison_spot(home, 12, 7))

	// Left three minutes, a riot becomes a breakout: every rioter goes for the ways out.
	first.setStaminaLoss(0)
	second.adjustBruteLoss(-100)
	second.recover()
	prison.admin_calm()
	TEST_ASSERT(prison.start_riot("test", everyone = TRUE), "The second riot did not start")
	prison.tick(179)
	TEST_ASSERT(!prison.breaking_out, "The riot broke out early")
	TEST_ASSERT_EQUAL(prison.admin_payload()["breakout_in"], 1, "The breakout countdown is off")
	prison.tick(1)
	TEST_ASSERT(prison.breaking_out, "Three minutes of riot did not become a breakout")
	TEST_ASSERT_NULL(prison.admin_payload()["breakout_in"], "The breakout countdown outlived the breakout")
	var/list/breakout_data = console.ui_data(warden)
	TEST_ASSERT_EQUAL(breakout_data["alarm"], "breakout", "The breakout alarm is [breakout_data["alarm"]]")
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in everyone)
		TEST_ASSERT_EQUAL(rioter.trouble, "breakout", "[rioter] is [rioter.trouble] in the breakout")
	var/atom/exit = first.riot_target()
	TEST_ASSERT_NOTNULL(exit, "A rioter breaking out found no way out to hit")
	TEST_ASSERT(prison.leads_out_of_cell_block(get_turf(exit)), "A rioter breaking out went for [exit] at [exit.x],[exit.y], which leads nowhere")

	// A serving hatch gives after twelve blows (PRISON_HATCH_FORCE_HITS) and is then climbed.
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in prison_spot(home, 5, 6)
	first.forceMove(prison_spot(home, 5, 7))
	for(var/i in 1 to 11)
		TEST_ASSERT(first.confront(hatch), "A rioter could not work at the hatch")
	TEST_ASSERT(!hatch.both_sides_open(), "The hatch gave early")
	first.confront(hatch)
	TEST_ASSERT(wait_until(CALLBACK(hatch, TYPE_PROC_REF(/obj/structure/table/reinforced/prison_hatch, both_sides_open)), 5 SECONDS), "Twelve blows did not force the hatch open")
	TEST_ASSERT_EQUAL(first.riot_target(), hatch, "A rioter did not go for the forced hatch")
	TEST_ASSERT(first.confront(hatch), "A rioter did not start over the forced hatch")
	prison.tick(3)
	TEST_ASSERT_EQUAL(first.loc, prison_spot(home, 5, 5), "The rioter did not come down in the office")
	TEST_ASSERT_EQUAL(first.trouble, "loose", "A rioter out of the cell block is not loose")
	TEST_ASSERT(prison.broke_out, "A rioter getting out did not count as a breakout")
	TEST_ASSERT_EQUAL(console.ui_data(warden)["alarm_text"], "1 prisoner loose", "The console reads [console.ui_data(warden)["alarm_text"]]")
	TEST_ASSERT(prison.riot_lights_on, "The lights stopped strobing with a rioter loose")
	prison.admin_calm()
	settle_prison_air(home)

// ===== THE HATCH, ESCAPES, THE LOOSE CLOCK AND TURRETS =====

/datum/unit_test/voidcrew_outpost_prison_escape
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_escape/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("escapeowner")
	TEST_ASSERT_NOTNULL(home, "The escape test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/datum/bank_account/treasury = home.treasury
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in prison_spot(home, 5, 6)
	var/obj/machinery/door/window/yard_door = hatch.yard_windoor()
	var/obj/machinery/door/window/staff_door = hatch.staff_windoor()
	var/mob/living/basic/outpost_prisoner/runner = trouble_prisoner(prison, prison_spot(home, 5, 7))
	runner.set_mood(30)

	// The climb needs both window doors open (PRISONER_CLIMB_MOOD 50 and below 50 mood).
	var/datum/prisoner_activity/climb_hatch/climb = new(runner)
	TEST_ASSERT(!climb.setup(), "A prisoner set out to climb a shut hatch")
	TEST_ASSERT(!runner.start_climb(hatch), "A prisoner climbed a shut hatch")
	staff_door.open()
	TEST_ASSERT(!climb.setup(), "A prisoner set out to climb a hatch open on the staff side only")
	TEST_ASSERT(!runner.start_climb(hatch), "A prisoner climbed a hatch open on one side")
	yard_door.open()
	TEST_ASSERT(hatch.both_sides_open(), "Both window doors open did not read as open")
	runner.set_mood(60)
	TEST_ASSERT(!climb.setup(), "A prisoner at mood 60 set out to climb")
	runner.set_mood(30)
	TEST_ASSERT(climb.setup(), "An unhappy prisoner did not go for an open hatch")
	TEST_ASSERT_EQUAL(climb.spot, prison_spot(home, 5, 7), "The climb does not start in front of the hatch")
	qdel(climb)
	// Shutting a side mid-climb brings them back down.
	TEST_ASSERT(runner.start_climb(hatch), "An unhappy prisoner did not start over an open hatch")
	TEST_ASSERT(runner.in_trouble() && !runner.routine_allowed(), "A climbing prisoner kept up their routine")
	yard_door.close()
	prison.tick(1)
	TEST_ASSERT_NULL(runner.climb_ref, "The climb went on after a window door shut")
	TEST_ASSERT_EQUAL(runner.loc, prison_spot(home, 5, 7), "The prisoner went over a shut hatch")
	// Three seconds (PRISONER_CLIMB_TIME) over an open one, and they are out of the cell block.
	yard_door.open()
	TEST_ASSERT(runner.start_climb(hatch), "The prisoner did not start over the reopened hatch")
	prison.tick(2)
	TEST_ASSERT_EQUAL(runner.loc, prison_spot(home, 5, 7), "The climb finished early")
	TEST_ASSERT(isnull(runner.trouble), "The climber counted as loose while still in the yard")
	prison.tick(1)
	TEST_ASSERT_EQUAL(runner.loc, prison_spot(home, 5, 5), "The climb did not end in the office")
	yard_door.close()
	staff_door.close()

	// Escaped: loose on the outpost patrol AI, five minutes on the clock (OUTPOST_PRISON_LOOSE_TIME).
	TEST_ASSERT(!prison.in_cell_block(runner), "The office counts as the cell block")
	TEST_ASSERT_EQUAL(runner.trouble, "loose", "An escaped prisoner is not loose")
	TEST_ASSERT(istype(runner.ai_controller, /datum/ai_controller/basic_controller/outpost_breakout), "A loose prisoner is not on the patrol AI ([runner.ai_controller?.type])")
	TEST_ASSERT_EQUAL(runner.bubble, "riot", "A loose prisoner shows the [runner.bubble] bubble")
	TEST_ASSERT(is_line_for(runner.last_line, "escape"), "The escaped prisoner said no escape line: [runner.last_line]")
	var/list/alarm = prison.alarm_state()
	TEST_ASSERT_EQUAL(alarm[1], "escape", "A single escape shows the [alarm[1]] alarm")
	TEST_ASSERT_EQUAL(alarm[2], "1 prisoner loose", "The escape alarm reads [alarm[2]]")
	TEST_ASSERT(!prison.riot_lights_on, "A lone escape set the riot lights off")
	TEST_ASSERT_EQUAL(runner.loose_seconds_shown(), 300, "The loose clock shows [runner.loose_seconds_shown()]")
	TEST_ASSERT_EQUAL(prison.prisoner_pay_rate(runner), 0, "A loose prisoner earned a stipend")
	var/sentence_before = runner.sentence_left
	prison.tick(100)
	TEST_ASSERT_EQUAL(runner.loose_left, 200, "100 seconds out left [runner.loose_left] on the clock")
	TEST_ASSERT_EQUAL(runner.sentence_left, sentence_before, "A loose prisoner's sentence ran")
	// Back in the cell block on their feet, the clock stops and shows nothing.
	runner.forceMove(prison_spot(home, 8, 8))
	prison.tick(50)
	TEST_ASSERT_EQUAL(runner.loose_left, 200, "The loose clock ran inside the cell block")
	TEST_ASSERT_NULL(runner.loose_seconds_shown(), "The loose clock shows inside the cell block")
	TEST_ASSERT_EQUAL(runner.trouble, "loose", "Walking back in on their own was a recapture")

	// Recaptured: down inside the cell block. Back on the prisoner AI, in a foul mood (25).
	runner.forceMove(prison_spot(home, 8, 4))
	runner.adjustStaminaLoss(200)
	runner.forceMove(prison_spot(home, 8, 8))
	prison.tick(1)
	TEST_ASSERT(isnull(runner.trouble), "A downed prisoner dragged back was not recaptured")
	TEST_ASSERT(abs(runner.mood - 25) < 0.01, "A recaptured prisoner is at mood [runner.mood], not 25") // PRISONER_RECAPTURED_MOOD
	TEST_ASSERT(istype(runner.ai_controller, /datum/ai_controller/basic_controller/outpost_prisoner), "A recaptured prisoner is not back on the prisoner AI")
	TEST_ASSERT_NULL(prison.alarm_state()[1], "The alarm outlasted the recapture")
	runner.setStaminaLoss(0)

	// Dragged out while down is not an escape; waking up out there is.
	runner.adjustStaminaLoss(200)
	runner.forceMove(prison_spot(home, 8, 4))
	prison.tick(1)
	TEST_ASSERT(isnull(runner.trouble), "A downed prisoner dragged out counted as escaped")
	runner.setStaminaLoss(0)
	prison.tick(1)
	TEST_ASSERT_EQUAL(runner.trouble, "loose", "A prisoner on their feet in the office did not escape")

	// Five minutes out: gone for good, no bonus, and a 1000 cr fine (OUTPOST_PRISON_ESCAPE_FINE),
	// as much of it as the treasury holds. Nobody else is earning, so nothing else is paid in.
	prison.pay_owed = 0
	treasury.adjust_money(-treasury.account_balance, "Prison test")
	treasury.adjust_money(600, "Prison test")
	var/paid_before = prison.paid_total
	var/runner_name = runner.real_name
	prison.tick(299)
	TEST_ASSERT_EQUAL(runner.phase, "present", "A loose prisoner left early")
	prison.tick(1)
	TEST_ASSERT_EQUAL(runner.phase, "leaving", "A prisoner loose five minutes was not beamed away")
	TEST_ASSERT_EQUAL(treasury.account_balance, 0, "A 600 cr treasury was left with [treasury.account_balance] after the fine")
	TEST_ASSERT_EQUAL(prison.paid_total, paid_before, "An escape paid a bonus")
	var/list/newest = prison.entries[1]
	TEST_ASSERT(findtext(newest["text"], runner_name) && findtext(newest["text"], "600"), "The escape was not logged with its fine: [newest["text"]]")
	var/mob/living/basic/outpost_prisoner/second_runner = trouble_prisoner(prison, prison_spot(home, 8, 4))
	treasury.adjust_money(5000, "Prison test")
	prison.tick(1)
	TEST_ASSERT_EQUAL(second_runner.trouble, "loose", "The second runner did not escape")
	prison.tick(300)
	TEST_ASSERT_EQUAL(treasury.account_balance, 4000, "A full fine took [5000 - treasury.account_balance], not 1000")

	// Turrets (interim rule): prisoners in the wing are left alone, rioting or loose; outside it, fair game.
	var/mob/living/basic/outpost_prisoner/target = trouble_prisoner(prison, prison_spot(home, 10, 8))
	TEST_ASSERT(!is_hostile_creature(target), "A turret would shoot a prisoner in the yard")
	target.start_rioting()
	TEST_ASSERT(!is_hostile_creature(target), "A turret would shoot a rioter in the wing")
	target.calm_down()
	target.forceMove(prison_spot(home, 10, 4))
	prison.tick(1)
	TEST_ASSERT_EQUAL(target.trouble, "loose", "The turret target did not escape")
	TEST_ASSERT(!is_hostile_creature(target), "A turret would shoot a loose prisoner still inside the wing")
	var/list/bounds = prison.upgrade.footprint_bounds
	var/turf/outside = locate(bounds[1] + 8, bounds[2] - 2, bounds[5])
	target.forceMove(outside)
	TEST_ASSERT(get_area(target) != prison.wing, "The spot outside the wing is in the wing")
	TEST_ASSERT(is_hostile_creature(target), "A turret would not shoot a loose prisoner outside the wing")
	TEST_ASSERT(is_loose_outpost_prisoner(target), "A loose prisoner outside the wing is not a turret target")
	target.forceMove(prison_spot(home, 10, 4))
	settle_prison_air(home)

// ===== ADMIN TOOLS =====

/datum/unit_test/voidcrew_outpost_prison_trouble_admin
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_trouble_admin/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("troubleadminowner")
	TEST_ASSERT_NOTNULL(home, "The trouble admin test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/operator = make_player(prison_spot(home, 8, 4), "troubleadmin")
	var/datum/outpost_manipulator/unit_test/prison/panel = allocate(__IMPLIED_TYPE__, operator)
	panel.selected = home
	var/mob/living/basic/outpost_prisoner/first = trouble_prisoner(prison, prison_spot(home, 7, 8))
	var/mob/living/basic/outpost_prisoner/second = trouble_prisoner(prison, prison_spot(home, 9, 8))
	var/mob/living/basic/outpost_prisoner/third = trouble_prisoner(prison, prison_spot(home, 12, 8))

	// The section carries tension, stage and the breakout countdown; each row mood, state and loose time.
	var/list/section = panel.ui_data(operator)["selected"]["prison"]
	for(var/key in list("tension", "stage", "breakout_in"))
		TEST_ASSERT(key in section, "The prison section sends no [key]")
	TEST_ASSERT_EQUAL(section["stage"], "calm", "A calm wing's stage is [section["stage"]]")
	TEST_ASSERT_NULL(section["breakout_in"], "A calm wing has a breakout countdown")
	var/list/row = section["prisoners"][1]
	for(var/key in list("mood", "state", "loose_left"))
		TEST_ASSERT(key in row, "A prisoner row sends no [key]")
	TEST_ASSERT_EQUAL(row["state"], "normal", "A calm prisoner's state is [row["state"]]")
	TEST_ASSERT_NULL(row["loose_left"], "A prisoner in the yard has a loose countdown")

	// Mood, one and all.
	panel.manage_outpost(home, operator, "prison_set", list("ref" = REF(first), "field" = "mood", "value" = 20))
	TEST_ASSERT(abs(first.mood - 20) < 0.01, "Setting mood left it at [first.mood]")
	panel.manage_outpost(home, operator, "prison_set", list("ref" = REF(first), "field" = "mood", "value" = "lots"))
	TEST_ASSERT(panel.error && abs(first.mood - 20) < 0.01, "A non-number mood was accepted")
	panel.manage_outpost(home, operator, "prison_all", list("what" = "enrage"))
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in list(first, second, third))
		TEST_ASSERT(prisoner.mood < 20, "Enrage left [prisoner] at [prisoner.mood]")
	panel.manage_outpost(home, operator, "prison_all", list("what" = "calm"))
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in list(first, second, third))
		TEST_ASSERT(prisoner.mood > 99, "Calm all left [prisoner] at [prisoner.mood]")

	// A fight with the nearest other; refused with nobody free to fight.
	panel.manage_outpost(home, operator, "prison_fight", list("ref" = REF(first)))
	TEST_ASSERT(first.fight && first.fight == second.fight, "The admin fight did not pair the nearest prisoner")
	TEST_ASSERT_EQUAL(panel.ui_data(operator)["selected"]["prison"]["prisoners"][1]["state"], "fighting", "A fighter's state is not fighting")
	panel.manage_outpost(home, operator, "prison_fight", list("ref" = REF(third)))
	TEST_ASSERT(panel.error, "A fight with nobody free to fight was accepted")
	TEST_ASSERT(isnull(third.trouble) && !third.fight, "A refused fight changed the prisoner")
	panel.manage_outpost(home, operator, "prison_calm", list())
	TEST_ASSERT(!first.fight && isnull(first.trouble), "Calm did not end the fight")
	TEST_ASSERT(abs(first.mood - 70) < 0.01, "Calm set mood to [first.mood], not 70")

	// A riot everyone joins; a second is refused.
	panel.manage_outpost(home, operator, "prison_riot", list())
	TEST_ASSERT(prison.riot_active, "The admin riot did not start")
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in list(first, second, third))
		TEST_ASSERT_EQUAL(prisoner.trouble, "riot", "[prisoner] stayed out of the admin riot")
	section = panel.ui_data(operator)["selected"]["prison"]
	TEST_ASSERT_EQUAL(section["breakout_in"], 180, "The riot's breakout is due in [section["breakout_in"]]")
	TEST_ASSERT_EQUAL(section["prisoners"][1]["state"], "rioting", "A rioter's state is [section["prisoners"][1]["state"]]")
	panel.manage_outpost(home, operator, "prison_riot", list())
	TEST_ASSERT(panel.error, "A second riot was accepted")
	panel.manage_outpost(home, operator, "prison_calm", list())
	TEST_ASSERT(!prison.riot_active, "Calm did not end the riot")
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in list(first, second, third))
		TEST_ASSERT(isnull(prisoner.trouble) && !istype(prisoner.held_item, /obj/item/knife/shiv), "[prisoner] kept rioting after the calm")

	// A breakout: out of the cell block and loose; refused for someone already loose.
	panel.manage_outpost(home, operator, "prison_breakout", list("ref" = REF(second)))
	TEST_ASSERT_EQUAL(second.trouble, "loose", "The admin breakout did not set the prisoner loose")
	TEST_ASSERT(!prison.in_cell_block(second), "The admin breakout left the prisoner in the cell block")
	TEST_ASSERT_EQUAL(prison.alarm_state()[1], "breakout", "An admin breakout shows the [prison.alarm_state()[1]] alarm")
	var/list/loose_row
	for(var/list/prisoner_row as anything in panel.ui_data(operator)["selected"]["prison"]["prisoners"])
		if(prisoner_row["ref"] == REF(second))
			loose_row = prisoner_row
	TEST_ASSERT_EQUAL(loose_row["state"], "loose", "A loose prisoner's state is [loose_row["state"]]")
	TEST_ASSERT_EQUAL(loose_row["loose_left"], 300, "A loose prisoner shows [loose_row["loose_left"]] s left")
	var/turf/breakout_spot = get_turf(second)
	panel.manage_outpost(home, operator, "prison_breakout", list("ref" = REF(second)))
	TEST_ASSERT(panel.error, "Breaking out a loose prisoner was accepted")
	TEST_ASSERT_EQUAL(get_turf(second), breakout_spot, "A refused breakout moved the prisoner")
	panel.manage_outpost(home, operator, "prison_breakout", list("ref" = "not a ref"))
	TEST_ASSERT(panel.error, "A breakout for a bad reference was accepted")
	panel.manage_outpost(home, operator, "prison_all", list("what" = "riot"))
	TEST_ASSERT(panel.error, "An unknown prisoner-wide action was accepted")

	// Every successful action was logged once: set, enrage, calm all, fight, calm, riot, calm, breakout.
	TEST_ASSERT_EQUAL(length(panel.operations), 8, "The manipulator logged [length(panel.operations)] trouble actions: [jointext(panel.operations, "; ")]")
	settle_prison_air(home)
