/**
 * Staff reputation and the talk menu (outpost_prison_social.dm, outpost_prison_warden_tools.dm). Owner: XC.
 * What moves a member's score and how far; the labels and what a mask does; the cap and decay;
 * blows, beatings and deaths; what the labels change (threats, talk-downs, rioters, the order back
 * to the cell); greetings and word on arrival; the talk menu, its answers and other packages'
 * choices in it; and the admin panel's records.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Prisons are driven with tick(seconds) with their own processing stopped;
 * fixtures are in voidcrew_outpost_prison_helpers.dm. The claim's owner is a member of the wing;
 * any other key is a visitor. Nothing here waits on the AI: the procs the menu and the speech
 * tick call are called directly.
 */

/// A prisoner whose talk menu has one more choice, standing in for other packages' (XF's pat-down, XG's questions)
/mob/living/basic/outpost_prisoner/talk_menu_stub
	/// The last extra choice that reached this prisoner
	var/stub_picked

/mob/living/basic/outpost_prisoner/talk_menu_stub/talk_menu_other_choices(mob/living/user)
	var/list/choices = ..()
	choices = choices.Copy()
	choices["Stub choice"] = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_use")
	return choices

/mob/living/basic/outpost_prisoner/talk_menu_stub/talk_menu_other_act(mob/living/user, choice)
	if(choice == "Stub choice")
		stub_picked = choice
		return TRUE
	return ..()

/// Whether a record's score is `expected`, give or take rounding
/datum/unit_test/voidcrew_outpost_management/proc/rep_score_is(datum/prison_staff_record/record, expected)
	return record && abs(record.score - expected) < 0.01

/// The owner's record, made if need be, with enough dealings behind it that the score alone sets the label
/datum/unit_test/voidcrew_outpost_management/proc/rep_known_record(datum/outpost_prison/prison, mob/person, score)
	var/datum/prison_staff_record/record = prison.rep_record(prison.rep_key(person), TRUE)
	record.interactions = max(record.interactions, 3) // PRISON_REP_KNOWN_INTERACTIONS
	record.score = score
	return record

// ===== THE FILE =====

/datum/unit_test/voidcrew_outpost_prison_social_files

/datum/unit_test/voidcrew_outpost_prison_social_files/Run()
	// The file is read the way outpost_prisoner_extra_dialogue() reads it (the strings directory is a define)
	load_strings_file("outpost_prison_social.json", "voidcrew/modules/player_outposts/strings")
	var/list/contents = GLOB.string_cache["outpost_prison_social.json"]
	TEST_ASSERT(islist(contents), "outpost_prison_social.json did not load")
	TEST_ASSERT(islist(contents["lines"]), "outpost_prison_social.json has no lines block")
	var/list/lines = contents["lines"]
	var/list/contexts = list(
		"greet_stranger", "greet_regular", "greet_fair", "greet_hard", "greet_brute", "greet_masked",
		"wing_word_fair", "wing_word_brute", "talk_refuse_brute",
		"ask_how_starving", "ask_how_hungry", "ask_how_filthy", "ask_how_dirty", "ask_how_hurt", "ask_how_locked",
		"ask_how_dark_cell", "ask_how_dark", "ask_how_dirty_floor", "ask_how_no_power", "ask_how_rival", "ask_how_fine",
		"ask_crime", "order_comply", "order_refuse", "order_again", "sent_to_cell",
	)
	for(var/context in contexts)
		TEST_ASSERT(islist(lines[context]), "outpost_prison_social.json has no [context] lines")
	// A masked face has no name to call, so its greeting never needs one.
	var/list/masked = lines["greet_masked"]
	for(var/pool in masked)
		var/list/pool_lines = masked[pool]
		for(var/line in pool_lines)
			TEST_ASSERT(!findtext(line, "{staff}"), "A greet_masked line needs a name: [line]")
	// A rival who can't be found is still complained about, without a name.
	var/list/rival = lines["ask_how_rival"]
	var/list/rival_shared = rival["any"]
	var/unnamed = FALSE
	for(var/line in rival_shared)
		if(!findtext(line, "{other}"))
			unnamed = TRUE
	TEST_ASSERT(unnamed, "ask_how_rival has no shared line that works without the rival's name")

// ===== WHAT MOVES THE SCORE =====

/datum/unit_test/voidcrew_outpost_prison_social_sources
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_social_sources/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("repowner")
	TEST_ASSERT_NOTNULL(home, "The reputation test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/first = test_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/second = test_prisoner(prison, prison_spot(home, 10, 8))
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 9, 8), "repowner")
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 9, 9), "repvisitor")
	TEST_ASSERT(prison.is_member(owner), "The claim's owner is not a member of the wing")
	TEST_ASSERT(!prison.is_member(visitor), "A visitor is a member of the wing")

	// Nobody on record yet: a stranger.
	TEST_ASSERT_NULL(prison.rep_record_for(owner), "The owner had a record before doing anything")
	TEST_ASSERT_EQUAL(prison.staff_label(owner), "stranger", "Someone with no record was not a stranger")

	// A hand-over: +1 (PRISON_REP_CARE), once per prisoner per 5 minutes (PRISON_REP_CARE_GAP).
	TEST_ASSERT(prison.note_staff_care(owner, first), "A hand-over did not count")
	var/datum/prison_staff_record/record = prison.rep_record_for(owner)
	TEST_ASSERT_NOTNULL(record, "A hand-over made no record")
	TEST_ASSERT(rep_score_is(record, 1), "A hand-over left the score at [record.score], not 1")
	TEST_ASSERT(!prison.note_staff_care(owner, first), "A second hand-over to the same prisoner inside 5 minutes counted")
	TEST_ASSERT(rep_score_is(record, 1), "A second hand-over to the same prisoner moved the score to [record.score]")
	TEST_ASSERT(prison.note_staff_care(owner, second), "A hand-over to another prisoner did not count")
	TEST_ASSERT(rep_score_is(record, 2), "Hand-overs to two prisoners left the score at [record.score], not 2")
	record.care_times[REF(first)] -= 5 MINUTES
	TEST_ASSERT(prison.note_staff_care(owner, first), "A hand-over 5 minutes after the last did not count")
	TEST_ASSERT(rep_score_is(record, 3), "The third hand-over left the score at [record.score], not 3")
	// Through the prisoner's own hook, as feeding by hand calls it.
	record.care_times = null
	first.note_carer(owner)
	TEST_ASSERT(rep_score_is(record, 4), "note_carer() did not reach the record: [record.score], not 4")

	// Stocking a hatch: +0.5, once per 5 minutes (PRISON_REP_STOCK, PRISON_REP_STOCK_GAP).
	record.score = 0
	TEST_ASSERT(prison.note_staff_stock(owner), "Stocking a hatch did not count")
	TEST_ASSERT(rep_score_is(record, 0.5), "Stocking a hatch left the score at [record.score], not 0.5")
	TEST_ASSERT(!prison.note_staff_stock(owner), "Stocking again inside 5 minutes counted")
	record.stocked_at -= 5 MINUTES
	TEST_ASSERT(prison.note_staff_stock(owner), "Stocking 5 minutes later did not count")
	TEST_ASSERT(rep_score_is(record, 1), "Two stockings left the score at [record.score], not 1")
	// A talk-down that worked and a basket with the players: +1 each (PRISON_REP_TALK, PRISON_REP_BASKET).
	prison.note_staff_talk(owner, first)
	TEST_ASSERT(rep_score_is(record, 2), "A talk-down left the score at [record.score], not 2")
	prison.note_staff_basket(owner)
	TEST_ASSERT(rep_score_is(record, 3), "A basket left the score at [record.score], not 3")
	// Kindness from other packages, at most 2 at a time (PRISON_REP_KINDNESS_MAX), and never a loss.
	prison.note_staff_kindness(owner, 0.5)
	TEST_ASSERT(rep_score_is(record, 3.5), "A card game left the score at [record.score], not 3.5")
	prison.note_staff_kindness(owner, 5)
	TEST_ASSERT(rep_score_is(record, 5.5), "A big kindness was not held to 2: [record.score], not 5.5")
	TEST_ASSERT(!prison.note_staff_kindness(owner, -3), "A negative kindness counted")
	TEST_ASSERT(!prison.note_staff_kindness(owner, "lots"), "A kindness that is not a number counted")
	TEST_ASSERT(rep_score_is(record, 5.5), "Bad kindnesses moved the score to [record.score]")
	// Never past 10 (PRISON_REP_MAX).
	for(var/i in 1 to 10)
		prison.note_staff_talk(owner, first)
	TEST_ASSERT(rep_score_is(record, 10), "The score went to [record.score], past 10")

	// XF's events (note_staff_event()): mail +0.5 once per prisoner per stay, an opened letter -1,
	// a search that found something 0, an empty one -1, a pat-down that found something 0, an empty one -0.5.
	record.score = 0
	TEST_ASSERT(prison.note_staff_event(owner, first, "mail_delivered"), "Delivering mail did not count")
	TEST_ASSERT(!prison.note_staff_event(owner, first, "mail_delivered"), "Mail to the same prisoner counted twice in one stay")
	TEST_ASSERT(prison.note_staff_event(owner, second, "mail_delivered"), "Mail to another prisoner did not count")
	TEST_ASSERT(rep_score_is(record, 1), "Two deliveries left the score at [record.score], not 1")
	prison.note_staff_event(owner, first, "mail_opened")
	TEST_ASSERT(rep_score_is(record, 0), "An opened letter left the score at [record.score], not 0")
	var/interactions = record.interactions
	TEST_ASSERT(prison.note_staff_event(owner, first, "search_found"), "A search that found something did not count")
	TEST_ASSERT(rep_score_is(record, 0) && record.interactions == interactions + 1, "A search that found something moved the score to [record.score] or was not counted")
	prison.note_staff_event(owner, first, "search_empty")
	TEST_ASSERT(rep_score_is(record, -1), "An empty search left the score at [record.score], not -1")
	prison.note_staff_event(owner, first, "patdown_found")
	TEST_ASSERT(rep_score_is(record, -1), "A pat-down that found something left the score at [record.score], not -1")
	prison.note_staff_event(owner, first, "patdown_empty")
	TEST_ASSERT(rep_score_is(record, -1.5), "An empty pat-down left the score at [record.score], not -1.5")
	interactions = record.interactions
	TEST_ASSERT(!prison.note_staff_event(owner, first, "no_such_event"), "An unknown event counted")
	TEST_ASSERT(rep_score_is(record, -1.5) && record.interactions == interactions, "An unknown event changed the record")

	// Visitors have no record, whatever they do.
	TEST_ASSERT(!prison.note_staff_care(visitor, first), "A visitor's hand-over counted")
	TEST_ASSERT(!prison.note_staff_stock(visitor), "A visitor's stocking counted")
	TEST_ASSERT(!prison.note_staff_talk(visitor, first), "A visitor's talk counted")
	TEST_ASSERT(!prison.note_staff_event(visitor, second, "search_empty"), "A visitor's search counted")
	TEST_ASSERT_NULL(prison.rep_record(prison.rep_key(visitor)), "A visitor got a record")
	TEST_ASSERT_EQUAL(length(prison.staff_records), 1, "The wing keeps [length(prison.staff_records)] records, not the owner's alone")
	settle_prison_air(home)

// ===== LABELS, MASKS, THE CAP AND DECAY =====

/datum/unit_test/voidcrew_outpost_prison_social_labels
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_social_labels/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("labelowner")
	TEST_ASSERT_NOTNULL(home, "The label test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.rep_word_chance = 0
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 9, 8), "labelowner")
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 9, 9), "labelvisitor")
	var/datum/prison_staff_record/record = prison.rep_record(prison.rep_key(owner), TRUE)

	// Too little to go on (under 3 interactions and within 1 of 0: PRISON_REP_KNOWN_*): a stranger.
	record.interactions = 2
	record.score = 0.5
	TEST_ASSERT_EQUAL(prison.staff_label(owner), "stranger", "Two small dealings made someone known")
	record.score = -1
	TEST_ASSERT_EQUAL(prison.staff_label(owner), "hard", "A hit's worth of score on a first meeting did not count")
	// Known: regular from 0, fair from 5 (PRISON_REP_FAIR), hard below 0, brute from -5 (PRISON_REP_BRUTE).
	record.interactions = 3
	var/list/cases = list(list(0, "regular"), list(4.9, "regular"), list(5, "fair"), list(10, "fair"), list(-0.1, "hard"), list(-4.9, "hard"), list(-5, "brute"), list(-10, "brute"))
	for(var/list/case as anything in cases)
		record.score = case[1]
		TEST_ASSERT_EQUAL(prison.staff_label(owner), case[2], "A score of [case[1]] was labelled [prison.staff_label(owner)], not [case[2]]")

	// A masked member is a stranger to the yard, whatever their record.
	record.score = -8
	ADD_TRAIT(owner, TRAIT_UNKNOWN, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_NULL(prison.staff_greeting_name(owner), "A masked member still had a name")
	TEST_ASSERT_EQUAL(prison.staff_label(owner), "stranger", "A masked brute was not a stranger")
	TEST_ASSERT_EQUAL(prison.threat_mood_for(null, owner), 35, "A masked brute kept a brute's threat line") // PRISONER_THREAT_MOOD
	REMOVE_TRAIT(owner, TRAIT_UNKNOWN, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_EQUAL(prison.staff_label(owner), "brute", "Taking the mask off did not bring the record back")
	// A visitor is always a stranger.
	TEST_ASSERT_EQUAL(prison.staff_label(visitor), "stranger", "A visitor was not a stranger")
	TEST_ASSERT_EQUAL(prison.staff_label(null), "stranger", "Nobody was not a stranger")

	// At most 20 records (PRISON_REP_RECORDS): the least recently seen is forgotten.
	QDEL_LIST_ASSOC_VAL(prison.staff_records)
	for(var/i in 1 to 21)
		var/datum/prison_staff_record/made = prison.rep_record("test_key_[i]", TRUE)
		made.last_seen = world.time + i
	TEST_ASSERT_EQUAL(length(prison.staff_records), 20, "The wing keeps [length(prison.staff_records)] records, not 20")
	TEST_ASSERT(!("test_key_1" in prison.staff_records), "The least recently seen record was kept")
	TEST_ASSERT("test_key_2" in prison.staff_records, "A newer record was dropped")
	TEST_ASSERT("test_key_21" in prison.staff_records, "The newest record was dropped")

	// Scores move 1 toward 0 every 10 minutes (PRISON_REP_DECAY, PRISON_REP_DECAY_SECONDS), never past it.
	QDEL_LIST_ASSOC_VAL(prison.staff_records)
	var/datum/prison_staff_record/high = prison.rep_record("test_high", TRUE)
	var/datum/prison_staff_record/low = prison.rep_record("test_low", TRUE)
	var/datum/prison_staff_record/small = prison.rep_record("test_small", TRUE)
	high.score = 3
	low.score = -2.5
	small.score = 0.5
	prison.rep_decay_clock = 0
	prison.social_tick(600)
	TEST_ASSERT(rep_score_is(high, 2) && rep_score_is(low, -1.5) && rep_score_is(small, 0), "Ten minutes left the scores at [high.score], [low.score], [small.score], not 2, -1.5, 0")
	prison.social_tick(599)
	TEST_ASSERT(rep_score_is(high, 2) && rep_score_is(low, -1.5), "Scores decayed before ten minutes were up")
	prison.social_tick(1)
	TEST_ASSERT(rep_score_is(high, 1) && rep_score_is(low, -0.5) && rep_score_is(small, 0), "Twenty minutes left the scores at [high.score], [low.score], [small.score], not 1, -0.5, 0")
	// An old hand-over is forgotten along the way, so the list does not grow forever.
	LAZYSET(high.care_times, "old_prisoner", world.time - 6 MINUTES)
	LAZYSET(high.care_times, "new_prisoner", world.time)
	prison.social_tick(600)
	TEST_ASSERT(!LAZYACCESS(high.care_times, "old_prisoner") && LAZYACCESS(high.care_times, "new_prisoner"), "Decay did not forget old hand-overs only")

	// The prison going takes its records with it.
	prison.social_destroy()
	TEST_ASSERT(!length(prison.staff_records), "social_destroy() left [length(prison.staff_records)] records")
	settle_prison_air(home)

// ===== BLOWS =====

/datum/unit_test/voidcrew_outpost_prison_social_blows
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_social_blows/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("blowowner")
	TEST_ASSERT_NOTNULL(home, "The blows test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/plain = test_prisoner(prison, prison_spot(home, 8, 8))
	plain.personality = "chatty"
	plain.set_mood(70)
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 9, 8), "blowowner")
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 8, 9), "blowvisitor")

	// An unprovoked hit that cost mood: -3 (PRISON_REP_HIT).
	TEST_ASSERT(plain.hit_by_staff(owner), "An unprovoked hit cost no mood")
	var/datum/prison_staff_record/record = prison.rep_record_for(owner)
	TEST_ASSERT_NOTNULL(record, "An unprovoked hit made no record")
	TEST_ASSERT(rep_score_is(record, -3), "An unprovoked hit left the score at [record?.score], not -3")
	// A deserved one does not count: a rioter, and one a moment after they calmed down.
	plain.staff_hit_cooldown = 0
	plain.start_rioting(FALSE)
	TEST_ASSERT(!plain.hit_by_staff(owner), "Hitting a rioter cost mood")
	TEST_ASSERT(rep_score_is(record, -3), "Hitting a rioter moved the score to [record.score]")
	plain.calm_down()
	plain.staff_hit_cooldown = 0
	TEST_ASSERT(!plain.hit_by_staff(owner), "Finishing a subdual cost mood")
	TEST_ASSERT(rep_score_is(record, -3), "Finishing a subdual moved the score to [record.score]")
	// Nor does hitting back at someone who just swung at you.
	plain.trouble_ended_at = 0
	plain.staff_hit_cooldown = 0
	plain.strike(owner)
	TEST_ASSERT(!plain.hit_by_staff(owner), "Hitting back cost mood")
	TEST_ASSERT(rep_score_is(record, -3), "Hitting back moved the score to [record.score]")
	// A visitor's blow is on nobody's record, and not on the owner's.
	plain.struck_ref = null
	plain.staff_hit_cooldown = 0
	TEST_ASSERT(plain.hit_by_staff(visitor), "A visitor's unprovoked hit cost no mood")
	TEST_ASSERT(rep_score_is(record, -3), "A visitor's hit moved the owner's score to [record.score]")
	TEST_ASSERT_NULL(prison.rep_record(prison.rep_key(visitor)), "A visitor's hit made them a record")

	// Beaten down unprovoked: -3 more (PRISON_REP_BEATEN), on whoever hit last.
	plain.staff_hit_cooldown = 0
	TEST_ASSERT(plain.hit_by_staff(owner), "The second unprovoked hit cost no mood")
	TEST_ASSERT(rep_score_is(record, -6), "Two unprovoked hits left the score at [record.score], not -6")
	plain.collapse()
	TEST_ASSERT(plain.beaten_by_staff, "The collapse was not put down to staff")
	TEST_ASSERT(rep_score_is(record, -9), "An unprovoked beating left the score at [record.score], not -9")
	plain.recover()

	// A death put down to staff: straight to -10 (PRISON_REP_MIN).
	trouble_fund(home, 5000)
	record.score = 4
	prison.blame_death(plain)
	TEST_ASSERT(rep_score_is(record, -10), "A death put down to staff left the score at [record.score], not -10")
	settle_prison_air(home)

// ===== WHAT THE LABELS CHANGE =====

/datum/unit_test/voidcrew_outpost_prison_social_effects
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_social_effects/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("effectowner")
	TEST_ASSERT_NOTNULL(home, "The reputation effects test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, prison_spot(home, 8, 8))
	prisoner.personality = "chatty"
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 9, 8), "effectowner")
	owner.drop_all_held_items()
	owner.set_combat_mode(FALSE)
	var/datum/prison_staff_record/record = rep_known_record(prison, owner, 2)

	// A regular: the usual lines (PRISONER_THREAT_MOOD 35, PRISONER_MOOD_TALK 8).
	TEST_ASSERT_EQUAL(prison.threat_mood_for(prisoner, owner), 35, "A regular's threat line is not 35")
	TEST_ASSERT_EQUAL(prison.talk_mood_for(prisoner, owner), 8, "A regular's talk-down is not 8")
	TEST_ASSERT_EQUAL(prison.riot_victim_distance(prisoner, owner, 4), 4, "Rioters saw a regular somewhere else")
	// A fair member: squared up to only below 25, talks give 12, rioters see them 2 tiles farther
	// (PRISON_REP_THREAT_FAIR, PRISON_REP_TALK_MOOD_FAIR, PRISON_REP_RIOT_FAIR_FARTHER).
	record.score = 6
	TEST_ASSERT_EQUAL(prison.threat_mood_for(prisoner, owner), 25, "A fair member's threat line is not 25")
	TEST_ASSERT_EQUAL(prison.talk_mood_for(prisoner, owner), 12, "A fair member's talk-down is not 12")
	TEST_ASSERT_EQUAL(prison.riot_victim_distance(prisoner, owner, 4), 6, "Rioters did not see a fair member 2 tiles farther")
	// A brute: squared up to below 45, rioters see them 3 tiles nearer (PRISON_REP_THREAT_BRUTE, PRISON_REP_RIOT_BRUTE_NEARER).
	record.score = -6
	TEST_ASSERT_EQUAL(prison.threat_mood_for(prisoner, owner), 45, "A brute's threat line is not 45")
	TEST_ASSERT_EQUAL(prison.talk_mood_for(prisoner, owner), 8, "A brute's talk-down is not 8")
	TEST_ASSERT_EQUAL(prison.riot_victim_distance(prisoner, owner, 4), 1, "Rioters did not see a brute 3 tiles nearer")
	TEST_ASSERT(prison.riot_victim_distance(prisoner, owner, 4) < prison.riot_victim_distance(prisoner, null, 2), "Rioters went for a nearer stranger over a brute 4 tiles off")
	TEST_ASSERT_EQUAL(prison.threat_mood_ceiling(), 45, "The threat ceiling is not the brute's line")

	// A brute is turned away below mood 50 (PRISON_REP_REFUSE_BRUTE_BELOW) and heard from 50.
	prisoner.set_mood(49)
	TEST_ASSERT(prison.refuses_talk_from(prisoner, owner), "A prisoner at 49 heard out a brute")
	prisoner.set_mood(50)
	TEST_ASSERT(!prison.refuses_talk_from(prisoner, owner), "A prisoner at 50 turned a brute away")
	// Through a real talk-down: the brute gets nowhere...
	prisoner.set_mood(30)
	TEST_ASSERT(!prisoner.talk_down(owner), "A brute talked a prisoner at 30 down")
	TEST_ASSERT(abs(prisoner.mood - 30) < 0.01, "A brute's refused talk changed mood to [prisoner.mood]")
	// ...and a fair member calms them by 12, and gets the credit for it (PRISON_REP_TALK).
	record.score = 6
	TEST_ASSERT(!prison.refuses_talk_from(prisoner, owner), "A prisoner turned a fair member away")
	TEST_ASSERT(prisoner.talk_down(owner), "A fair member's talk-down did nothing")
	TEST_ASSERT(abs(prisoner.mood - 42) < 0.01, "A fair member's talk-down left mood at [prisoner.mood], not 42")
	TEST_ASSERT(rep_score_is(record, 7), "A talk-down that worked left the score at [record.score], not 7")
	settle_prison_air(home)

// ===== GREETINGS AND WORD ON ARRIVAL =====

/datum/unit_test/voidcrew_outpost_prison_social_greetings
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_social_greetings/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("greetowner")
	TEST_ASSERT_NOTNULL(home, "The greetings test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.rep_greet_chance = 100
	prison.rep_word_chance = 0
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, prison_spot(home, 8, 8))
	prisoner.personality = "chatty"
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 9, 8), "greetowner")
	owner.fully_replace_character_name(owner.real_name, "Isaac Newton")
	var/datum/prison_staff_record/record = rep_known_record(prison, owner, 6)

	// Someone in view gets greet_<label>, with {staff} their first name.
	var/list/greeting = prison.social_extra_speech(prisoner)
	TEST_ASSERT(islist(greeting), "Nobody was greeted with the owner beside them")
	TEST_ASSERT_EQUAL(greeting[1], "greet_fair", "A fair member got [greeting[1]]")
	TEST_ASSERT(length(greeting) >= 3 && islist(greeting[3]), "A greeting came with no name to fill")
	var/list/values = greeting[3]
	TEST_ASSERT_EQUAL(values["{staff}"], "Isaac", "The greeting would call the owner [values["{staff}"]], not Isaac")
	// The line itself names them, or nobody.
	for(var/i in 1 to 10)
		prisoner.extra_line_values = values
		var/line = prisoner.pick_line(greeting[1])
		prisoner.extra_line_values = null
		TEST_ASSERT(line && !findtext(line, "{"), "A greeting was said with a placeholder left in: [line]")
	// Once per person per 3 minutes (PRISON_REP_GREET_GAP).
	TEST_ASSERT_NULL(prison.social_extra_speech(prisoner), "The same person was greeted twice inside 3 minutes")
	prisoner.rep_greeted[prison.rep_key(owner)] -= 3 MINUTES
	TEST_ASSERT(islist(prison.social_extra_speech(prisoner)), "The owner was not greeted 3 minutes later")

	// Each label has its greeting.
	var/list/cases = list(list(2, "greet_regular"), list(-2, "greet_hard"), list(-6, "greet_brute"))
	for(var/list/case as anything in cases)
		record.score = case[1]
		prisoner.rep_greeted = null
		greeting = prison.social_extra_speech(prisoner)
		TEST_ASSERT(islist(greeting) && greeting[1] == case[2], "A score of [case[1]] was greeted with [islist(greeting) ? greeting[1] : "nothing"], not [case[2]]")
	// Without a name, no line that needs one is ever said.
	for(var/context in list("greet_stranger", "greet_regular", "greet_fair", "greet_hard", "greet_brute", "wing_word_fair", "wing_word_brute", "talk_refuse_brute"))
		for(var/i in 1 to 15)
			var/line = prisoner.pick_line(context)
			TEST_ASSERT(!line || !findtext(line, "{staff}"), "[context] was said without a name: [line]")

	// A masked face: greet_masked, and no name.
	ADD_TRAIT(owner, TRAIT_UNKNOWN, TRAIT_SOURCE_UNIT_TESTS)
	prisoner.rep_greeted = null
	greeting = prison.social_extra_speech(prisoner)
	TEST_ASSERT(islist(greeting) && greeting[1] == "greet_masked", "A masked member was not greeted as masked")
	TEST_ASSERT(length(greeting) < 3 || !greeting[3], "A masked member's greeting came with a name")
	for(var/i in 1 to 10)
		var/line = prisoner.pick_line("greet_masked")
		TEST_ASSERT(line && !findtext(line, "{") && !findtext(line, "Unknown"), "A masked greeting came out as: [line]")
	REMOVE_TRAIT(owner, TRAIT_UNKNOWN, TRAIT_SOURCE_UNIT_TESTS)

	// A visitor let in is greeted as a stranger.
	owner.forceMove(prison_spot(home, 1, 1))
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 9, 8), "greetvisitor")
	prisoner.rep_greeted = null
	greeting = prison.social_extra_speech(prisoner)
	TEST_ASSERT(islist(greeting) && greeting[1] == "greet_stranger", "A visitor was greeted with [islist(greeting) ? greeting[1] : "nothing"], not as a stranger")
	// Nobody greets anyone while in trouble.
	prisoner.rep_greeted = null
	prisoner.talking = TRUE
	TEST_ASSERT_NULL(prison.social_extra_speech(prisoner), "A prisoner in the middle of a talk greeted someone")
	prisoner.talking = FALSE
	// And not at all when the roll fails.
	prison.rep_greet_chance = 0
	prisoner.rep_greeted = null
	TEST_ASSERT_NULL(prison.social_extra_speech(prisoner), "A greeting came at a 0% chance")
	qdel(visitor)

	// Word on arrival: what they heard about a fair member or a brute, by name; nothing about anyone else.
	record.score = 6
	TEST_ASSERT(prison.rep_say_word(prisoner, record), "A newcomer said nothing about a fair member")
	record.score = -6
	TEST_ASSERT(prison.rep_say_word(prisoner, record), "A newcomer said nothing about a brute")
	record.score = 2
	TEST_ASSERT(!prison.rep_say_word(prisoner, record), "A newcomer had word about a regular")
	// Arrivals roll for it once (PRISON_REP_WORD_CHANCE, pinned), and wait 10 seconds (PRISON_REP_WORD_DELAY).
	prison.rep_word_chance = 100
	var/mob/living/basic/outpost_prisoner/newcomer = test_prisoner(prison, prison_spot(home, 10, 8))
	prison.social_tick(1)
	TEST_ASSERT(newcomer.rep_noticed && newcomer.rep_word_left == 10, "An arrival at a 100% chance has [newcomer.rep_word_left] seconds to their word, not 10")
	prison.social_tick(4)
	TEST_ASSERT_EQUAL(newcomer.rep_word_left, 6, "The word's delay did not count down")
	prison.rep_word_chance = 0
	var/mob/living/basic/outpost_prisoner/quiet_one = test_prisoner(prison, prison_spot(home, 11, 8))
	prison.social_tick(1)
	TEST_ASSERT(quiet_one.rep_noticed && isnull(quiet_one.rep_word_left), "An arrival at a 0% chance still has word to give")
	// With nobody notable at home, the word is let go once the wait is over (PRISON_REP_WORD_WAIT).
	prison.social_tick(10)
	prison.social_tick(61)
	TEST_ASSERT_NULL(newcomer.rep_word_left, "Word nobody was home to hear was kept after the wait")
	settle_prison_air(home)

// ===== THE TALK MENU =====

/datum/unit_test/voidcrew_outpost_prison_social_talk_menu
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_social_talk_menu/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("menuowner")
	TEST_ASSERT_NOTNULL(home, "The talk menu test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, prison_spot(home, 8, 8))
	prisoner.personality = "chatty"
	prisoner.set_mood(70)
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 9, 8), "menuowner")
	owner.drop_all_held_items()
	owner.set_combat_mode(FALSE)
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 8, 9), "menuvisitor")
	visitor.drop_all_held_items()
	visitor.set_combat_mode(FALSE)

	// A visitor gets no menu: the right click passes through, and a pick does nothing.
	TEST_ASSERT(!(SEND_SIGNAL(prisoner, COMSIG_ATOM_ATTACK_HAND_SECONDARY, visitor, list()) & COMPONENT_CANCEL_ATTACK_CHAIN), "A visitor's right click was taken as the talk menu")
	TEST_ASSERT(!prisoner.talk_menu_allowed(visitor), "A visitor may use the talk menu")
	TEST_ASSERT(!prisoner.talk_menu_act(visitor, "What are you in for?"), "A visitor's pick did something") // PRISON_TALK_CRIME
	TEST_ASSERT(!prisoner.asked_crime && abs(prisoner.mood - 70) < 0.01, "A visitor's pick changed the prisoner")
	// A member's right click is the menu (the radial itself needs a client); in combat mode it is not.
	TEST_ASSERT(SEND_SIGNAL(prisoner, COMSIG_ATOM_ATTACK_HAND_SECONDARY, owner, list()) & COMPONENT_CANCEL_ATTACK_CHAIN, "A member's right click did not open the talk menu")
	owner.set_combat_mode(TRUE)
	TEST_ASSERT(!(SEND_SIGNAL(prisoner, COMSIG_ATOM_ATTACK_HAND_SECONDARY, owner, list()) & COMPONENT_CANCEL_ATTACK_CHAIN), "A right click in combat mode opened the talk menu")
	owner.set_combat_mode(FALSE)

	// Its own three choices first, then other packages', and a pick of theirs reaches them.
	var/mob/living/basic/outpost_prisoner/talk_menu_stub/stubbed = new(prison_spot(home, 10, 8))
	prison.admit(stubbed)
	stubbed.sentence_left = 3600
	stubbed.set_hunger(100)
	stubbed.set_uniform_grime(0)
	ADD_TRAIT(stubbed, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	var/list/choices = stubbed.talk_menu_choices(owner)
	TEST_ASSERT(length(choices) >= 4, "The menu has [length(choices)] choices, not the three and the extra")
	TEST_ASSERT_EQUAL(choices[1], "How are you doing?", "The menu's first choice is [choices[1]]") // PRISON_TALK_HOW
	TEST_ASSERT_EQUAL(choices[2], "What are you in for?", "The menu's second choice is [choices[2]]") // PRISON_TALK_CRIME
	TEST_ASSERT_EQUAL(choices[3], "Back to your cell", "The menu's third choice is [choices[3]]") // PRISON_TALK_CELL
	TEST_ASSERT(choices.Find("Stub choice") > 3, "Another package's choice is missing or ahead of the menu's own")
	TEST_ASSERT(stubbed.talk_menu_act(owner, "Stub choice"), "Another package's choice was not run")
	TEST_ASSERT_EQUAL(stubbed.stub_picked, "Stub choice", "Another package's choice did not reach it")
	TEST_ASSERT(!stubbed.talk_menu_act(owner, "Nobody's choice"), "A choice nobody has was taken")
	TEST_ASSERT(!prisoner.talk_menu_choices(owner).Find("Stub choice"), "One prisoner's extra choice showed up on another")

	// "How are you doing?": the biggest complaint, in order.
	prisoner.set_hunger(5)
	prisoner.set_uniform_grime(90)
	var/list/answer = prisoner.talk_menu_complaint()
	TEST_ASSERT_EQUAL(answer[1], "ask_how_starving", "A starving, filthy prisoner answered [answer[1]]")
	prisoner.set_hunger(30)
	answer = prisoner.talk_menu_complaint()
	TEST_ASSERT_EQUAL(answer[1], "ask_how_hungry", "A hungry, filthy prisoner answered [answer[1]]")
	prisoner.set_hunger(100)
	answer = prisoner.talk_menu_complaint()
	TEST_ASSERT_EQUAL(answer[1], "ask_how_filthy", "A fed, filthy prisoner answered [answer[1]]")
	prisoner.set_uniform_grime(60)
	answer = prisoner.talk_menu_complaint()
	TEST_ASSERT_EQUAL(answer[1], "ask_how_dirty", "A fed prisoner in a dirty uniform answered [answer[1]]")
	prisoner.set_uniform_grime(0)
	prisoner.adjustBruteLoss(20)
	answer = prisoner.talk_menu_complaint()
	TEST_ASSERT_EQUAL(answer[1], "ask_how_hurt", "A hurt prisoner answered [answer[1]]")
	prisoner.adjustBruteLoss(-20)
	prisoner.locked_in_seconds = 130
	answer = prisoner.talk_menu_complaint()
	TEST_ASSERT_EQUAL(answer[1], "ask_how_locked", "A prisoner locked in over 2 minutes answered [answer[1]]")
	prisoner.locked_in_seconds = 0
	prison.lit_score = 100
	prison.clean_score = 100
	prison.powered_score = 100
	prison.cell_lit = list("[prisoner.cell.number]" = 10)
	answer = prisoner.talk_menu_complaint()
	TEST_ASSERT_EQUAL(answer[1], "ask_how_dark_cell", "A prisoner with a dark cell answered [answer[1]]")
	prison.cell_lit = list()
	prison.lit_score = 40
	answer = prisoner.talk_menu_complaint()
	TEST_ASSERT_EQUAL(answer[1], "ask_how_dark", "A prisoner in a dark wing answered [answer[1]]")
	prison.lit_score = 100
	prison.clean_score = 40
	answer = prisoner.talk_menu_complaint()
	TEST_ASSERT_EQUAL(answer[1], "ask_how_dirty_floor", "A prisoner in a dirty wing answered [answer[1]]")
	prison.clean_score = 100
	prison.powered_score = 50
	answer = prisoner.talk_menu_complaint()
	TEST_ASSERT_EQUAL(answer[1], "ask_how_no_power", "A prisoner in an unpowered wing answered [answer[1]]")
	prison.powered_score = 100
	answer = prisoner.talk_menu_complaint()
	TEST_ASSERT_EQUAL(answer[1], "ask_how_fine", "A prisoner with nothing wrong answered [answer[1]]")
	// Through the menu: an answer, then nothing for 30 seconds (PRISON_TALK_ASK_GAP). No mood change.
	TEST_ASSERT(prisoner.talk_menu_ask_how(owner), "Asking how they were did nothing")
	TEST_ASSERT(!prisoner.talk_menu_ask_how(owner), "Asking again inside 30 seconds got an answer")
	TEST_ASSERT(abs(prisoner.mood - 70) < 0.01, "Asking how they were changed mood to [prisoner.mood]")

	// "What are you in for?": +3 the first time in a stay (PRISON_TALK_CRIME_MOOD), not after.
	TEST_ASSERT(prisoner.talk_menu_ask_crime(owner), "Asking what they were in for did nothing")
	TEST_ASSERT(abs(prisoner.mood - 73) < 0.01, "Asking what they were in for left mood at [prisoner.mood], not 73")
	prisoner.ask_crime_cooldown = 0
	TEST_ASSERT(prisoner.talk_menu_ask_crime(owner), "Asking again after the wait did nothing")
	TEST_ASSERT(abs(prisoner.mood - 73) < 0.01, "Asking twice in a stay lifted mood again, to [prisoner.mood]")

	// "Back to your cell": the line by personality (PRISON_TALK_ORDER_LINE_*), moved by who asks.
	var/datum/prison_staff_record/record = rep_known_record(prison, owner, 2)
	var/list/lines = list("grumpy" = 55, "chatty" = 45, "quiet" = 40, "cheerful" = 35, "nervous" = 30)
	for(var/personality in lines)
		prisoner.personality = personality
		TEST_ASSERT_EQUAL(prisoner.talk_menu_order_line(owner), lines[personality], "A [personality] prisoner's line for a regular is [prisoner.talk_menu_order_line(owner)], not [lines[personality]]")
	prisoner.personality = "chatty"
	record.score = 6
	TEST_ASSERT_EQUAL(prisoner.talk_menu_order_line(owner), 35, "A fair member did not lower the line by 10") // PRISON_TALK_ORDER_FAIR_SHIFT
	record.score = -6
	TEST_ASSERT_EQUAL(prisoner.talk_menu_order_line(owner), 60, "A brute did not raise the line by 15") // PRISON_TALK_ORDER_BRUTE_SHIFT
	ADD_TRAIT(owner, TRAIT_UNKNOWN, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_EQUAL(prisoner.talk_menu_order_line(owner), 45, "A masked brute kept a brute's line")
	REMOVE_TRAIT(owner, TRAIT_UNKNOWN, TRAIT_SOURCE_UNIT_TESTS)
	record.score = 2

	// Below the line they refuse; at it they go back and sit on their bed.
	prisoner.set_mood(44)
	TEST_ASSERT(!prisoner.talk_menu_order(owner), "A chatty prisoner at 44 went back to the cell")
	TEST_ASSERT(!istype(prisoner.activity, /datum/prisoner_activity/sent_to_cell), "A refusal still sent them back")
	// Inside the minute between asks (PRISON_TALK_ORDER_GAP), nothing happens.
	prisoner.set_mood(45)
	TEST_ASSERT(!prisoner.talk_menu_order(owner), "A second ask inside a minute did something")
	TEST_ASSERT_EQUAL(length(prisoner.order_times), 1, "An ask inside the minute was counted")
	prisoner.order_cooldown = 0
	TEST_ASSERT(prisoner.talk_menu_order(owner), "A chatty prisoner at 45 did not go back to the cell")
	var/datum/prisoner_activity/sent_to_cell/going = prisoner.activity
	TEST_ASSERT(istype(going), "Going back to the cell is not what they're doing")
	TEST_ASSERT(going.spot && prisoner.cell.contains(going.spot), "They're not headed into their own cell")
	TEST_ASSERT(!going.leisure && !going.interruptible, "Being sent back is leisure or can be interrupted")
	// The third ask inside five minutes costs 2 mood and is refused (PRISON_TALK_ORDER_SPAM_*).
	prisoner.end_activity(cancel_ai = FALSE)
	prisoner.order_cooldown = 0
	prisoner.set_mood(70)
	TEST_ASSERT(!prisoner.talk_menu_order(owner), "A third ask inside five minutes was obeyed")
	TEST_ASSERT(abs(prisoner.mood - 68) < 0.01, "A third ask left mood at [prisoner.mood], not 68")
	TEST_ASSERT(!istype(prisoner.activity, /datum/prisoner_activity/sent_to_cell), "A third ask sent them back")
	// Five minutes on, the count starts again.
	prisoner.order_cooldown = 0
	prisoner.order_times = list(world.time - 6 MINUTES, world.time - 6 MINUTES)
	TEST_ASSERT(prisoner.talk_menu_order(owner), "An ask after five quiet minutes was refused")
	prisoner.end_activity(cancel_ai = FALSE)

	// Rioters (anyone in trouble) won't hear any of it.
	prisoner.order_cooldown = 0
	prisoner.order_times = null
	prisoner.ask_how_cooldown = 0
	prisoner.start_rioting(FALSE)
	TEST_ASSERT(!prisoner.talk_menu_order(owner), "A rioter went back to the cell")
	TEST_ASSERT(!prisoner.talk_menu_ask_how(owner), "A rioter answered how they were")
	TEST_ASSERT(!istype(prisoner.activity, /datum/prisoner_activity/sent_to_cell), "A rioter was sent back")
	TEST_ASSERT(!length(prisoner.order_times), "A rioter's refusal counted as an ask")
	prisoner.calm_down()
	// Nor anyone below mood 10 (PRISONER_TALK_MIN_MOOD).
	prisoner.set_mood(5)
	TEST_ASSERT(!prisoner.talk_menu_order(owner), "A prisoner at mood 5 went back to the cell")
	qdel(visitor)
	settle_prison_air(home)

// ===== AN ORDER DURING A LOCK-IN =====

/datum/unit_test/voidcrew_outpost_prison_social_order_lockin
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_social_order_lockin/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("lockinowner")
	TEST_ASSERT_NOTNULL(home, "The lock-in test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.rep_word_chance = 0
	prison.crew_home_override = FALSE
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, prison_spot(home, 8, 8))
	prisoner.personality = "chatty"
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 9, 8), "lockinowner")
	var/datum/outpost_prison_cell/home_cell = prisoner.cell
	TEST_ASSERT_NOTNULL(home_cell, "The test prisoner has no cell")
	prisoner.forceMove(home_cell.arrival_turf())
	var/obj/machinery/door/airlock/door = home_cell.door()
	TEST_ASSERT_NOTNULL(door, "The test cell has no door")
	if(!door.density)
		door.close()
	door.bolt()
	prison.refresh_prisoner_reach(prisoner)
	TEST_ASSERT(prisoner.is_confined(), "The prisoner is not shut in the bolted cell")

	// Asked back to the cell they're bolted into: they go to the bed, and the lock-in clock keeps its count.
	prison.tick(60)
	TEST_ASSERT_EQUAL(prisoner.locked_in_seconds, 60, "A minute bolted in counted [prisoner.locked_in_seconds] s")
	prisoner.set_mood(70)
	TEST_ASSERT(prisoner.talk_menu_order(owner), "A bolted-in prisoner at 70 would not go to their bed")
	TEST_ASSERT(istype(prisoner.activity, /datum/prisoner_activity/sent_to_cell), "The order did not send them to their bed")
	TEST_ASSERT_EQUAL(prisoner.locked_in_seconds, 60, "The order reset the lock-in clock to [prisoner.locked_in_seconds]")
	// And a lock-in still stops pay after 120 seconds (OUTPOST_PRISON_CONFINED_PAY_AFTER).
	prison.tick(61)
	TEST_ASSERT_EQUAL(prisoner.locked_in_seconds, 121, "Two minutes bolted in counted [prisoner.locked_in_seconds] s")
	TEST_ASSERT_EQUAL(prison.pay_factor(prisoner), 0, "A prisoner bolted in 121 seconds still paid [prison.pay_factor(prisoner)]")
	door.unbolt()
	settle_prison_air(home)

// ===== THE ADMIN PANEL =====

/datum/unit_test/voidcrew_outpost_prison_social_admin
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_social_admin/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("repadminowner")
	TEST_ASSERT_NOTNULL(home, "The reputation admin test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 9, 8), "repadminowner")
	owner.fully_replace_character_name(owner.real_name, "Isaac Newton")
	prison.note_staff_talk(owner, null)
	var/datum/prison_staff_record/record = prison.rep_record_for(owner)
	TEST_ASSERT_NOTNULL(record, "A talk made no record")

	// The panel's rows: {key, name, score, label}.
	var/list/rows = prison.social_admin_payload()
	TEST_ASSERT_EQUAL(length(rows), 1, "The panel shows [length(rows)] records, not 1")
	var/list/row = rows[1]
	for(var/key in list("key", "name", "score", "label"))
		TEST_ASSERT(key in row, "A reputation row has no [key]")
	TEST_ASSERT_EQUAL(row["key"], record.key, "The row's key is not the record's")
	TEST_ASSERT_EQUAL(row["name"], "Isaac Newton", "The row names [row["name"]], not Isaac Newton")
	TEST_ASSERT(islist(prison.extras_admin_payload()["social"]), "The admin extras block has no social list")

	// prison_rep {key, score}: -10 to 10, through the fan-out the admin panel calls.
	var/result = prison.extras_admin_act("prison_rep", list("key" = record.key, "score" = "7"), owner)
	TEST_ASSERT(istext(result), "Setting a reputation gave no log line")
	TEST_ASSERT(rep_score_is(record, 7), "Setting a reputation to 7 left it at [record.score]")
	TEST_ASSERT_EQUAL(prison.staff_label(owner), "fair", "A reputation of 7 is not fair")
	TEST_ASSERT(islist(prison.social_admin_act("prison_rep", list("key" = record.key, "score" = 11), owner)), "A reputation of 11 was taken")
	TEST_ASSERT(islist(prison.social_admin_act("prison_rep", list("key" = record.key, "score" = -11), owner)), "A reputation of -11 was taken")
	TEST_ASSERT(islist(prison.social_admin_act("prison_rep", list("key" = record.key, "score" = "lots"), owner)), "A reputation that is not a number was taken")
	TEST_ASSERT(islist(prison.social_admin_act("prison_rep", list("key" = "nobody", "score" = 1), owner)), "A reputation for nobody was taken")
	TEST_ASSERT(islist(prison.social_admin_act("prison_rep", list("key" = 1, "score" = 1), owner)), "A number as a key was taken")
	TEST_ASSERT(islist(prison.social_admin_act("prison_rep", null, owner)), "A reputation with no params was taken")
	TEST_ASSERT(rep_score_is(record, 7), "A refused setting moved the score to [record.score]")
	TEST_ASSERT_NULL(prison.social_admin_act("prison_not_rep", list(), owner), "Another action was taken as a reputation setting")
	settle_prison_air(home)
