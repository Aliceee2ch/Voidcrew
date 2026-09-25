/**
 * Stun turrets and the yard's feel (outpost_prison_security.dm, outpost_prison_ambience.dm). Owner: XB.
 * The turrets: who they answer, the crew-home gate, who may work them, where they mount, buying
 * them, rioters going for them and the beam that spares everyone else. The yard: heads turning at
 * a member coming in, moods read on examine, sulking and humming, the hush, the chant and the roar.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Prisons are driven by calling their procs with their own processing
 * stopped; nobody is on the level, so tests that need an AI running use trouble_awake_prisoner()
 * (voidcrew_outpost_prison_trouble.dm). Fixtures are in voidcrew_outpost_prison_helpers.dm; the
 * wing's authored layout has the cell block's south wall on row 6, the yard on rows 7 to 11 and
 * the warden's office on rows 2 to 5.
 */

/// A stun turret of `prison`, bolted into `wall` looking out `mount_dir`, as dragging it there does
/datum/unit_test/voidcrew_outpost_management/proc/security_mounted_turret(datum/outpost_prison/prison, turf/wall, mount_dir)
	var/obj/machinery/porta_turret/ship_defense/outpost_prison/turret = prison.make_stun_turret(get_step(wall, REVERSE_DIR(mount_dir)))
	turret.forceMove(wall)
	turret.setDir(mount_dir)
	turret.wall_turret_direction = mount_dir
	turret.set_anchored(TRUE)
	turret.RemoveInvisibility(id = turret.type)
	turret.update_appearance()
	return turret

/// Clears what the targets test gave `prisoner` to do
/datum/unit_test/voidcrew_outpost_management/proc/security_calm(mob/living/basic/outpost_prisoner/prisoner)
	prisoner.trouble = null
	prisoner.swing_ref = null
	prisoner.climb_ref = null
	prisoner.threat_ref = null

// ===== THE STRINGS FILE =====

/datum/unit_test/voidcrew_outpost_prison_security_files

/datum/unit_test/voidcrew_outpost_prison_security_files/Run()
	// The file is read the way outpost_prisoner_extra_dialogue() reads it (the strings directory is a define)
	load_strings_file("outpost_prison_security.json", "voidcrew/modules/player_outposts/strings")
	var/list/contents = GLOB.string_cache["outpost_prison_security.json"]
	TEST_ASSERT(islist(contents), "outpost_prison_security.json did not load")
	TEST_ASSERT(islist(contents["lines"]), "outpost_prison_security.json has no lines block")
	TEST_ASSERT(islist(contents["examine"]), "outpost_prison_security.json has no examine block")
	TEST_ASSERT(!is_outpost_prison_stun_turret(null), "Nothing counted as a stun turret")

	// Every context the turrets and the yard say (the X0 dialogue test holds the lines to the house rules)
	var/list/lines = contents["lines"]
	for(var/context in list("turret_warned", "turret_hit", "turret_smash", "greet_staff", "staff_enters_restless", "huddle", "riot_chant", "riot_roar"))
		TEST_ASSERT(islist(lines[context]), "outpost_prison_security.json has no lines for [context]")

	// The examine moods: every band has shared lines and lines for every personality, never a number,
	// and only the pronoun placeholders fill_examine_line() knows
	var/list/personalities = outpost_prisoner_dialogue("personalities")
	var/list/examine = contents["examine"]
	var/regex/digit = regex("\[0-9\]")
	for(var/band in list("mood_0", "mood_20", "mood_35", "mood_50", "mood_75"))
		var/list/entry = examine[band]
		TEST_ASSERT(islist(entry), "The examine block has no [band]")
		if(!islist(entry))
			continue
		for(var/pool in list("any") + personalities)
			TEST_ASSERT(length(entry[pool]), "The examine block's [band] has no lines for [pool]")
		for(var/pool in entry)
			TEST_ASSERT(pool == "any" || (pool in personalities), "The examine block's [band] has lines for [pool], which is not a personality")
			for(var/line in entry[pool])
				TEST_ASSERT(istext(line) && length(line), "The examine block's [band]/[pool] has an empty line")
				if(!istext(line))
					continue
				TEST_ASSERT_EQUAL(length(line), length_char(line), "An examine line is not plain ASCII: [line]")
				TEST_ASSERT(length(splittext(line, " ")) <= 20, "An examine line is over 20 words: [line]")
				TEST_ASSERT(!digit.Find(line), "An examine line has a number in it: [line]")
				var/bare = line
				for(var/placeholder in GLOB.outpost_prisoner_examine_placeholders)
					bare = replacetext(bare, placeholder, "")
				TEST_ASSERT(!findtext(bare, "{") && !findtext(bare, "}"), "An examine line has an unknown placeholder: [line]")

// ===== TURRETS: WHO THEY ANSWER =====

/datum/unit_test/voidcrew_outpost_prison_security_targets
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_security_targets/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("xbtargetowner")
	TEST_ASSERT_NOTNULL(home, "The turret targets test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.crew_home_override = TRUE
	var/obj/machinery/porta_turret/ship_defense/outpost_prison/turret = security_mounted_turret(prison, prison_spot(home, 4, 6), NORTH)
	TEST_ASSERT(is_outpost_prison_stun_turret(turret), "A wing stun turret did not count as one")
	TEST_ASSERT(turret.mounted(), "The turret bolted into the cell block wall is not mounted")
	TEST_ASSERT_EQUAL(turret.muzzle(prison), prison_spot(home, 4, 7), "The turret does not look over the yard tile in front of it")

	var/mob/living/basic/outpost_prisoner/subject = trouble_awake_prisoner(prison, prison_spot(home, 4, 8))
	var/mob/living/basic/outpost_prisoner/first = trouble_awake_prisoner(prison, prison_spot(home, 6, 8))
	var/mob/living/basic/outpost_prisoner/second = trouble_awake_prisoner(prison, prison_spot(home, 7, 8))
	var/mob/living/carbon/human/stranger = make_player(prison_spot(home, 4, 7), "xbtargetstranger")
	var/mob/living/basic/mouse/creature = allocate(/mob/living/basic/mouse, prison_spot(home, 5, 8))
	var/obj/structure/table/reinforced/prison_hatch/hatch
	for(var/turf/tile as anything in prison.wing_turfs())
		hatch = locate() in tile
		if(hatch)
			break
	TEST_ASSERT_NOTNULL(hatch, "The wing has no serving hatch")
	prison.refresh_reach()
	TEST_ASSERT(subject.reachable?[get_turf(turret)], "A prisoner in the yard cannot reach the turret over the yard")

	// Calm: nothing to answer
	TEST_ASSERT(!turret.warn_target(subject), "The turret answered a calm prisoner")

	// Rioting: warned during the wind-up, fired on after it
	subject.trouble = "riot" // PRISONER_TROUBLE_RIOT
	prison.riot_windup_left = 5 // PRISON_RIOT_WINDUP
	TEST_ASSERT(turret.warn_target(subject), "The turret did not warn a rioter during the wind-up")
	TEST_ASSERT(!turret.valid_target(subject), "The turret would fire on a rioter during the wind-up")
	prison.riot_windup_left = 0
	TEST_ASSERT(turret.valid_target(subject), "The turret would not fire on a rioter after the wind-up")
	subject.trouble = "breakout" // PRISONER_TROUBLE_BREAKOUT
	TEST_ASSERT(turret.valid_target(subject), "The turret would not fire on a prisoner breaking out")

	// Only a prisoner who could walk up to it and smash it
	subject.trouble = "riot" // PRISONER_TROUBLE_RIOT
	subject.reachable = list()
	TEST_ASSERT(!turret.valid_target(subject), "The turret would fire on a rioter who cannot reach it")
	prison.refresh_prisoner_reach(subject)
	TEST_ASSERT(turret.valid_target(subject), "The turret stopped answering a rioter after their reach came back")

	// Nobody from the wing home: a sit-in stays a sit-in
	prison.crew_home_override = FALSE
	TEST_ASSERT(!turret.warn_target(subject), "The turret answered a rioter with nobody home")
	prison.crew_home_override = TRUE

	// Down: never
	ADD_TRAIT(subject, TRAIT_INCAPACITATED, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(subject.can_be_dragged(), "An incapacitated prisoner is not down")
	TEST_ASSERT(!turret.warn_target(subject), "The turret answered a downed prisoner")
	REMOVE_TRAIT(subject, TRAIT_INCAPACITATED, TRAIT_SOURCE_UNIT_TESTS)
	security_calm(subject)

	// Swinging at staff, and climbing a hatch
	subject.swing_ref = WEAKREF(stranger)
	TEST_ASSERT(turret.valid_target(subject), "The turret would not fire on a prisoner swinging at staff")
	security_calm(subject)
	subject.climb_ref = WEAKREF(hatch)
	TEST_ASSERT(turret.valid_target(subject), "The turret would not fire on a prisoner climbing a hatch")
	security_calm(subject)

	// Threatening only, and wrecking a cell: never (the escalation against lock-in stays)
	subject.threat_ref = WEAKREF(stranger)
	TEST_ASSERT(!turret.warn_target(subject), "The turret answered a prisoner who was only threatening")
	security_calm(subject)
	subject.trouble = "wreck" // PRISONER_TROUBLE_WRECK
	TEST_ASSERT(!turret.warn_target(subject), "The turret answered a prisoner wrecking a cell")
	security_calm(subject)

	// A fight: not while it is words, only once blows are thrown
	var/datum/outpost_prison_fight/brawl = prison.start_fight(first, second)
	TEST_ASSERT_NOTNULL(brawl, "The two prisoners did not get into a fight")
	if(brawl)
		brawl.fighting = FALSE
		TEST_ASSERT(!turret.warn_target(first), "The turret answered an argument")
		brawl.fighting = TRUE
		TEST_ASSERT(turret.valid_target(first), "The turret would not fire on a prisoner throwing blows")
		prison.end_fight(brawl)

	// Loose in the wing: in the office, beside the turret's wall
	subject.forceMove(prison_spot(home, 4, 5))
	prison.refresh_prisoner_reach(subject)
	subject.trouble = "loose" // PRISONER_TROUBLE_LOOSE
	TEST_ASSERT(turret.valid_target(subject), "The turret would not fire on a prisoner loose in the wing")
	security_calm(subject)
	subject.forceMove(prison_spot(home, 4, 8))
	prison.refresh_prisoner_reach(subject)

	// Never a player or another creature (a guard, the researcher, an experiment)
	TEST_ASSERT(!turret.warn_target(stranger), "The turret answered a player")
	TEST_ASSERT(!turret.warn_target(creature), "The turret answered a creature that is not its prisoner")

	// A turret with no wing answers nobody
	var/datum/weakref/home_ref = turret.prison_ref
	turret.prison_ref = null
	subject.trouble = "riot" // PRISONER_TROUBLE_RIOT
	TEST_ASSERT(!turret.warn_target(subject), "A turret with no wing answered a rioter")
	turret.prison_ref = home_ref

	// The beam: it spares a player standing in the line, and lands on a rioter
	var/obj/projectile/beam/disabler/outpost_prison/shot = allocate(/obj/projectile/beam/disabler/outpost_prison, prison_spot(home, 4, 7))
	shot.firer = turret
	TEST_ASSERT(!shot.can_hit_target(stranger, TRUE, TRUE), "The turret's beam could hit a player in the line")
	TEST_ASSERT(shot.can_hit_target(subject, TRUE, TRUE), "The turret's beam could not hit the rioter it was fired at")

	// One look over the yard: a warning with somebody home, nothing with nobody home
	turret.on = TRUE
	// The wing's power is not what this test is about.
	turret.set_machine_stat(turret.machine_stat & ~NOPOWER)
	TEST_ASSERT(turret.think(), "A switched-on turret did not warn a rioter in front of it")
	TEST_ASSERT(LAZYACCESS(turret.warned_at, REF(subject)), "The turret warned somebody other than the rioter")
	prison.crew_home_override = FALSE
	TEST_ASSERT(!turret.think(), "The turret acted with nobody from the wing home")
	// Off again, so the warning's shot never goes out while the rest of the test runs
	turret.on = FALSE
	prison.crew_home_override = TRUE

	// Rioters go for it before any fixture, and six blows break it (PRISON_SMASH_DAMAGE 10, 60 to break)
	TEST_ASSERT_EQUAL(prison.priority_smash_target(subject), turret, "A rioter beside the turret did not go for it first")
	TEST_ASSERT_EQUAL(prison.pick_smash_target(subject), turret, "pick_smash_target() did not start with the turret")
	LAZYSET(subject.riot_skips, REF(turret), world.time + 100)
	TEST_ASSERT_NULL(prison.priority_smash_target(subject), "A rioter went back to a turret they had given up on")
	LAZYREMOVE(subject.riot_skips, REF(turret))
	for(var/blow in 1 to 5)
		subject.smash(turret)
	TEST_ASSERT(!(turret.machine_stat & BROKEN), "The turret broke in five blows")
	subject.smash(turret)
	TEST_ASSERT(turret.machine_stat & BROKEN, "The turret did not break in six blows")
	TEST_ASSERT_NULL(prison.priority_smash_target(subject), "A rioter went for a broken turret")
	TEST_ASSERT(!prison.still_smashable(turret, subject), "A broken turret was still worth smashing")
	TEST_ASSERT_EQUAL(turret.console_state(), "broken", "The console does not show the turret as broken")
	security_calm(subject)
	settle_prison_air(home)

// ===== TURRETS: WHO WORKS THEM, AND WHERE THEY MOUNT =====

/datum/unit_test/voidcrew_outpost_prison_security_controls
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_security_controls/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("xbcontrolowner")
	TEST_ASSERT_NOTNULL(home, "The turret controls test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 3, 5), "xbcontrolowner")
	var/mob/living/carbon/human/stranger = make_player(prison_spot(home, 2, 5), "xbcontrolstranger")
	TEST_ASSERT(prison.is_member(owner) && !prison.is_member(stranger), "The owner and the stranger are the wrong way round")

	// The mount rule: a cell block wall, looking into the cell block
	var/obj/machinery/porta_turret/ship_defense/outpost_prison/loose = prison.make_stun_turret(prison_spot(home, 4, 7))
	TEST_ASSERT(loose.mount_spot_ok(prison, prison_spot(home, 4, 6), NORTH), "The yard's south wall, facing the yard, was refused")
	TEST_ASSERT(!loose.mount_spot_ok(prison, prison_spot(home, 4, 6), SOUTH), "A turret facing out of the cell block into the office was allowed")
	TEST_ASSERT(!loose.mount_spot_ok(prison, prison_spot(home, 1, 7), WEST), "A turret facing out of the wing was allowed")
	TEST_ASSERT(!loose.mount_spot_ok(prison, prison_spot(home, 1, 3), EAST), "A turret in an office wall was allowed")
	TEST_ASSERT_EQUAL(loose.console_state(), "loose", "A loose turret does not read as loose")

	// Dragging it into a wall: refused for a stranger, and refused facing out, before any bolting
	loose.mouse_drop_dragged(prison_spot(home, 4, 6), stranger)
	TEST_ASSERT(!loose.anchored, "A stranger mounted the wing's turret")
	loose.mouse_drop_dragged(prison_spot(home, 4, 6), owner)
	TEST_ASSERT(!loose.anchored && loose.loc == prison_spot(home, 4, 7), "The turret was mounted facing out of the cell block")
	// From the office side it goes in facing the yard (the parent's five-second bolting)
	loose.forceMove(prison_spot(home, 4, 5))
	loose.mouse_drop_dragged(prison_spot(home, 4, 6), owner)
	TEST_ASSERT(loose.anchored && loose.loc == prison_spot(home, 4, 6), "The owner could not mount the turret in the yard's south wall")
	TEST_ASSERT_EQUAL(loose.muzzle(prison), prison_spot(home, 4, 7), "The mounted turret does not look over the yard")

	// The switch: members only
	var/obj/machinery/porta_turret/ship_defense/outpost_prison/turret = security_mounted_turret(prison, prison_spot(home, 3, 6), NORTH)
	turret.interact(stranger)
	TEST_ASSERT(!turret.on, "A stranger switched the turret on")
	turret.interact(owner)
	TEST_ASSERT(turret.on, "The owner could not switch the turret on")
	turret.interact(owner)
	TEST_ASSERT(!turret.on, "The owner could not switch the turret off")

	// The wrench: members only, and it comes out on the owner's side of the wall
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench)
	turret.attackby(wrench, stranger)
	TEST_ASSERT(turret.anchored, "A stranger unbolted the turret")
	turret.attackby(wrench, owner)
	TEST_ASSERT(!turret.anchored, "The owner could not unbolt the turret")
	TEST_ASSERT_EQUAL(turret.loc, owner.loc, "The unbolted turret did not come out on the owner's side")
	// A loose turret is never bolted to a floor, which would get round the mount rule
	turret.attackby(wrench, owner)
	TEST_ASSERT(!turret.anchored, "The wrench bolted the turret to the floor")

	// The crowbar: salvaging a broken turret is for members only
	turret.take_damage(70, BRUTE, "", FALSE)
	TEST_ASSERT(turret.machine_stat & BROKEN, "The turret did not break")
	var/obj/item/crowbar/crowbar = allocate(/obj/item/crowbar)
	turret.attackby(crowbar, stranger)
	TEST_ASSERT(!QDELETED(turret), "A stranger salvaged the turret")
	turret.attackby(crowbar, owner)
	TEST_ASSERT(QDELETED(turret), "The owner could not salvage the broken turret")
	settle_prison_air(home)

// ===== TURRETS: BUYING THEM =====

/datum/unit_test/voidcrew_outpost_prison_security_purchase
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_security_purchase/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("xbbuyowner")
	TEST_ASSERT_NOTNULL(home, "The turret purchase test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 4, 4), "xbbuyowner")
	var/mob/living/carbon/human/stranger = make_player(prison_spot(home, 5, 4), "xbbuystranger")
	var/datum/bank_account/treasury = trouble_fund(home, 4000)

	TEST_ASSERT(istext(prison.buy_stun_turret(stranger)), "A stranger bought a turret")
	TEST_ASSERT_EQUAL(treasury.account_balance, 4000, "A refused purchase took money")

	// Two at 2000 each (OUTPOST_PRISON_TURRET_COST, OUTPOST_PRISON_TURRET_MAX), loose at the warden's console
	TEST_ASSERT(prison.security_act("turret_buy", list(), owner), "The console did not take turret_buy")
	TEST_ASSERT_EQUAL(treasury.account_balance, 2000, "The first turret did not cost 2000")
	var/obj/machinery/porta_turret/ship_defense/outpost_prison/second = prison.buy_stun_turret(owner)
	TEST_ASSERT(istype(second), "The owner could not buy a second turret")
	TEST_ASSERT_EQUAL(treasury.account_balance, 0, "The second turret did not cost 2000")
	if(istype(second))
		TEST_ASSERT_EQUAL(get_turf(second), prison.alarm_turf(), "The turret was not delivered to the warden's console")
		TEST_ASSERT(!second.anchored && !second.on, "The turret was not delivered loose and switched off")
	var/list/payload = prison.security_payload(owner)
	TEST_ASSERT_EQUAL(length(payload["turrets"]), 2, "The console does not list both turrets")
	TEST_ASSERT(!payload["can_buy"], "The console offers a third turret")

	// A third is refused at the cap, and nothing is charged
	trouble_fund(home, 4000)
	TEST_ASSERT(istext(prison.buy_stun_turret(owner)), "A third turret was sold")
	TEST_ASSERT_EQUAL(treasury.account_balance, 4000, "The refused third turret took money")

	// Under the cap with an empty treasury: refused, never debt
	qdel(second)
	TEST_ASSERT_EQUAL(length(prison.live_stun_turrets()), 1, "A deleted turret still counts against the cap")
	trouble_fund(home, 0)
	TEST_ASSERT(istext(prison.buy_stun_turret(owner)), "A turret was sold on an empty treasury")
	TEST_ASSERT(treasury.account_balance == 0 && prison.treasury_debt() == 0, "A refused purchase left the treasury in debt")

	// The admin spawn: free, ignoring the cap, and anything else is not the security package's
	TEST_ASSERT(istext(prison.security_admin_act("prison_turret_spawn", list(), null)), "The admin spawn did not report what it did")
	TEST_ASSERT_EQUAL(length(prison.live_stun_turrets()), 2, "The admin spawn made no turret")
	TEST_ASSERT_NULL(prison.security_admin_act("prison_no_such_thing", list(), null), "The security package took an action that is not its own")
	var/list/rows = prison.security_admin_payload()
	TEST_ASSERT_EQUAL(length(rows), 2, "The admin panel does not list both turrets")
	for(var/list/row as anything in rows)
		for(var/key in list("ref", "state", "mounted"))
			TEST_ASSERT(key in row, "An admin turret row has no [key]")

	// Carried off the outpost, a turret stops answering to the wing and frees its slot; one still at home stays
	var/list/live = prison.live_stun_turrets()
	var/obj/machinery/porta_turret/ship_defense/outpost_prison/taken = live[1]
	var/obj/machinery/porta_turret/ship_defense/outpost_prison/kept = live[2]
	taken.forceMove(run_loc_floor_bottom_left)
	prison.security_tick(10) // PRISON_TURRET_CHECK_SECONDS
	TEST_ASSERT_NULL(taken.home_prison(), "A turret carried off the outpost still answers to the wing")
	TEST_ASSERT_EQUAL(kept.home_prison(), prison, "A turret left on the outpost stopped answering to the wing")
	TEST_ASSERT_EQUAL(length(prison.live_stun_turrets()), 1, "A turret carried off the outpost still counts against the cap")
	qdel(taken)
	settle_prison_air(home)

// ===== THE YARD NOTICES YOU, AND MOODS YOU CAN READ =====

/datum/unit_test/voidcrew_outpost_prison_ambience_yard
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_ambience_yard/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("xbyardowner")
	TEST_ASSERT_NOTNULL(home, "The yard test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/member = make_player(prison_spot(home, 9, 8), "xbyardowner")
	var/mob/living/carbon/human/stranger = make_player(prison_spot(home, 10, 8), "xbyardstranger")
	var/mob/living/basic/outpost_prisoner/content = trouble_awake_prisoner(prison, prison_spot(home, 8, 10), "cheerful")
	var/mob/living/basic/outpost_prisoner/sour = trouble_awake_prisoner(prison, prison_spot(home, 10, 10), "grumpy")

	// A member walks in: the content one looks over, the sour one stares and goes quiet
	content.set_mood(60)
	sour.set_mood(30)
	content.setDir(NORTH)
	sour.setDir(NORTH)
	sour.speech_cooldown = 0
	TEST_ASSERT_EQUAL(prison.note_people_inside(list(member)), 2, "Both prisoners did not react to a member coming in")
	TEST_ASSERT_EQUAL(content.dir, SOUTH, "The content prisoner did not look at the member")
	TEST_ASSERT_EQUAL(sour.dir, SOUTH, "The sour prisoner did not look at the member")
	TEST_ASSERT(sour.speech_cooldown > world.time + 15 SECONDS, "The sour prisoner did not go quiet while staring") // OUTPOST_PRISONER_NOTICE_STARE_HUSH 20 s

	// Out and in again within a minute: nothing, even with the prisoners' own cooldowns cleared
	TEST_ASSERT_EQUAL(prison.note_people_inside(list()), 0, "Leaving the cell block turned heads")
	content.ambience_notice_cooldown = 0
	sour.ambience_notice_cooldown = 0
	TEST_ASSERT_EQUAL(prison.note_people_inside(list(member)), 0, "Coming back in within a minute turned heads again") // OUTPOST_PRISON_NOTICE_GAP 60 s

	// A stranger coming in turns no heads
	prison.ambience_notice_cooldown = 0
	prison.note_people_inside(list())
	TEST_ASSERT_EQUAL(prison.note_people_inside(list(stranger)), 0, "A stranger coming in turned heads")
	TEST_ASSERT(prison.note_people_inside(list(member)) > 0, "A member coming in once the cooldowns ran out turned no heads")

	// Examine: one mood line by band and personality, filled in, never a number
	var/regex/digit = regex("\[0-9\]")
	var/list/bands = list("10" = "mood_0", "25" = "mood_20", "40" = "mood_35", "60" = "mood_50", "80" = "mood_75")
	for(var/personality in outpost_prisoner_dialogue("personalities"))
		content.personality = personality
		for(var/mood_text in bands)
			content.set_mood(text2num(mood_text))
			TEST_ASSERT_EQUAL(content.mood_examine_band(), bands[mood_text], "Mood [mood_text] reads as the wrong band")
			var/line = content.mood_examine_line()
			TEST_ASSERT(istext(line) && length(line), "A [personality] prisoner at mood [mood_text] has no examine line")
			if(!istext(line))
				continue
			TEST_ASSERT(!findtext(line, "{") && !findtext(line, "}"), "An examine line was left unfilled: [line]")
			TEST_ASSERT(!digit.Find(line), "An examine line has a number in it: [line]")
	var/list/examined = content.examine(member)
	TEST_ASSERT(findtext(jointext(examined, " "), content.mood_examine_line()), "Examining a prisoner does not show their mood")

	// A closer look: the crime and roughly the time left, rounded to five minutes
	var/list/closer = content.examine_more(member)
	TEST_ASSERT(findtext(jointext(closer, " "), "In for"), "A closer look does not show the crime")
	content.sentence_left = 100
	TEST_ASSERT_EQUAL(content.sentence_examine_text(), "a few minutes", "A short sentence does not read as a few minutes")
	content.sentence_left = 1500
	TEST_ASSERT_EQUAL(content.sentence_examine_text(), "about 25 minutes", "Twenty-five minutes did not round to 25")

	// Sulking is for sour prisoners only (OUTPOST_PRISONER_SULK_MOOD 45)
	var/datum/prisoner_activity/sulk/sulk = new(sour)
	sour.set_mood(45)
	TEST_ASSERT_EQUAL(sulk.get_weight(), 0, "A prisoner at mood 45 wants to sulk")
	sour.set_mood(30)
	TEST_ASSERT(sulk.get_weight() > 0, "A sour prisoner never sulks")
	qdel(sulk)

	// Humming: content cheerful, chatty or quiet prisoners, once per cooldown (OUTPOST_PRISONER_HUM_COOLDOWN 3 min)
	content.personality = "cheerful"
	content.set_mood(80)
	sour.set_mood(80)
	TEST_ASSERT(prison.try_hum(content), "A content cheerful prisoner did not hum")
	TEST_ASSERT(!prison.try_hum(content), "A prisoner hummed again inside the cooldown")
	TEST_ASSERT(!prison.try_hum(sour), "A grumpy prisoner hummed")
	settle_prison_air(home)

// ===== A RIOT YOU HEAR COMING =====

/datum/unit_test/voidcrew_outpost_prison_ambience_riot
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_ambience_riot/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("xbriotowner")
	TEST_ASSERT_NOTNULL(home, "The riot sounds test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	TEST_ASSERT_EQUAL(prison.wing.sound_environment, SOUND_AREA_LARGE_ENCLOSED, "The prison wing does not echo like a large hard room")

	// Beside the mess table on row 9, gathered in the yard
	var/mob/living/basic/outpost_prisoner/gathered = trouble_awake_prisoner(prison, prison_spot(home, 4, 8))
	var/datum/prisoner_activity/gather/huddle = new(gathered)
	huddle.started = TRUE
	gathered.start_activity(huddle)

	// The hush: small talk and chat go quiet in a restless wing, complaints do not
	prison.stage = "restless" // PRISON_STAGE_RESTLESS
	TEST_ASSERT(prison.speech_hushed(gathered, "idle"), "Small talk was not hushed in a restless wing")
	TEST_ASSERT(prison.speech_hushed(gathered, "conversation"), "Conversation was not hushed in a restless wing")
	TEST_ASSERT(!prison.speech_hushed(gathered, "restless"), "Restless complaints were hushed")
	TEST_ASSERT(prison.try_huddle(gathered), "A gathered prisoner did not whisper in a restless wing")
	TEST_ASSERT(!prison.try_huddle(gathered), "A gathered prisoner whispered again inside the gap") // OUTPOST_PRISONER_HUDDLE_GAP 20 s
	prison.stage = "calm" // PRISON_STAGE_CALM
	TEST_ASSERT(!prison.speech_hushed(gathered, "idle"), "Small talk was hushed in a calm wing")

	// The chant: only while a riot brews, every 2 s, every second near the end of the hold, and never after
	prison.stage = "restless" // PRISON_STAGE_RESTLESS
	TEST_ASSERT(!prison.chant_tick(1), "The yard chanted with no riot brewing")
	prison.riot_imminent = TRUE
	prison.riot_hold = 0
	TEST_ASSERT(!prison.chant_tick(1), "The chant beat after one second") // OUTPOST_PRISON_CHANT_GAP 2
	TEST_ASSERT(prison.chant_tick(1), "The chant did not beat after two seconds")
	prison.riot_hold = 40 // past PRISON_RIOT_HOLD 45 - OUTPOST_PRISON_CHANT_LATE_WINDOW 10
	TEST_ASSERT(prison.chant_tick(1), "The chant did not beat every second near the end of the hold")
	var/list/slammers = prison.chant_beat()
	TEST_ASSERT(gathered in slammers, "A gathered prisoner beside a mess table did not slam it")
	prison.riot_imminent = FALSE
	TEST_ASSERT(!prison.chant_tick(1), "The chant carried on once the riot stopped brewing")
	TEST_ASSERT_EQUAL(prison.ambience_chant_clock, 0, "The chant's clock did not reset once the riot stopped brewing")

	// The roar: every rioter on their feet, once per riot
	gathered.end_activity(cancel_ai = FALSE)
	var/mob/living/basic/outpost_prisoner/rioter = trouble_awake_prisoner(prison, prison_spot(home, 8, 8))
	rioter.trouble = "riot" // PRISONER_TROUBLE_RIOT
	prison.riot_active = TRUE
	TEST_ASSERT_EQUAL(prison.roar_tick(), 1, "The rioter did not roar as the riot started")
	TEST_ASSERT_EQUAL(prison.roar_tick(), 0, "The rioters roared twice in one riot")
	prison.riot_active = FALSE
	TEST_ASSERT_EQUAL(prison.roar_tick(), 0, "Somebody roared with no riot on")
	prison.riot_active = TRUE
	TEST_ASSERT_EQUAL(prison.roar_tick(), 1, "The rioter did not roar at the next riot")
	prison.riot_active = FALSE
	rioter.trouble = null
	prison.stage = "calm" // PRISON_STAGE_CALM
	settle_prison_air(home)
