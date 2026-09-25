/**
 * Outpost NPCs in one outfit are different people (outpost_npc_looks.dm). tg's cached human looks
 * put everyone in the same outfit on one bald, pale, male body; these must vary the person, give a
 * woman a woman's body, and dress the mob the way tg's looks do.
 *
 * Fork defines are included after the tests: each outfit has 8 looks per gender
 * (OUTPOST_NPC_LOOK_COUNT).
 */
/datum/unit_test/voidcrew_outpost_npc_looks

/datum/unit_test/voidcrew_outpost_npc_looks/Run()
	// Eight people in one outfit are not all the same person.
	var/list/signatures = list()
	for(var/look_number in 1 to 8)
		var/look = get_outpost_npc_look(/datum/outfit/outpost_prisoner, MALE, look_number)
		TEST_ASSERT_NOTNULL(look, "Look [look_number] of the prisoner outfit was not built")
		signatures |= look_signature(look)
	TEST_ASSERT(length(signatures) >= 2, "All eight looks of the prisoner outfit are the same person")
	TEST_ASSERT(get_outpost_npc_look(/datum/outfit/outpost_prisoner, MALE, 1) == GLOB.outpost_npc_looks[outpost_npc_look_key(/datum/outfit/outpost_prisoner, MALE, 1)], "A built look was not cached")
	TEST_ASSERT(has_state(get_outpost_npc_look(/datum/outfit/outpost_prisoner, MALE, 1), "_chest_m"), "A man's look has no male chest")
	TEST_ASSERT(has_state(get_outpost_npc_look(/datum/outfit/outpost_prisoner, FEMALE, 1), "_chest_f"), "A woman's look has no female chest")

	// A prisoner wears their own look, keyed by their gender.
	var/mob/living/basic/outpost_prisoner/prisoner = allocate(/mob/living/basic/outpost_prisoner)
	var/deadline = world.time + 5 SECONDS
	// Let the look Initialize() started finish first, so it cannot land on top of this one.
	UNTIL(prisoner.icon == 'icons/mob/human/human.dmi' || world.time > deadline)
	TEST_ASSERT(prisoner.look_number >= 1 && prisoner.look_number <= 8, "A prisoner got look number [prisoner.look_number]")
	prisoner.gender = FEMALE
	prisoner.look_number = 3
	prisoner.build_look()
	TEST_ASSERT_NOTNULL(GLOB.outpost_npc_looks[outpost_npc_look_key(prisoner.outfit_path, FEMALE, 3)], "A woman's look was not cached under her gender")
	TEST_ASSERT_EQUAL(prisoner.icon, 'icons/mob/human/human.dmi', "A prisoner's look did not set the human icon")
	TEST_ASSERT_EQUAL(prisoner.icon_state, "", "A prisoner's look left an icon state")
	TEST_ASSERT(prisoner.appearance_flags & KEEP_TOGETHER, "A prisoner's look did not keep its overlays together")
	TEST_ASSERT(has_state(prisoner, "_chest_f"), "A woman prisoner does not have a woman's body")

	// Anything that is not female gets a male body.
	TEST_ASSERT_EQUAL(outpost_npc_look_key(/datum/outfit/outpost_prisoner, NEUTER, 2), outpost_npc_look_key(/datum/outfit/outpost_prisoner, MALE, 2), "A neuter look is not the male one")

/// What a look is drawn from: every overlay's icon, state and colour
/datum/unit_test/voidcrew_outpost_npc_looks/proc/look_signature(mutable_appearance/look)
	var/list/parts = list()
	for(var/mutable_appearance/overlay as anything in look.overlays)
		parts += "[overlay.icon]:[overlay.icon_state]:[overlay.color]"
	return jointext(parts, "|")

/// Whether any overlay of `thing` (an atom or an appearance) has an icon state containing `fragment`
/datum/unit_test/voidcrew_outpost_npc_looks/proc/has_state(thing, fragment)
	var/mutable_appearance/look = thing
	for(var/mutable_appearance/overlay as anything in look.overlays)
		if(findtext(overlay.icon_state, fragment))
			return TRUE
	return FALSE
