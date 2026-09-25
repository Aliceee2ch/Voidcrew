/**
 * Friends, games and birthdays (outpost_prison_life.dm, outpost_prison_pastimes.dm). Owner: XD.
 * X0 placeholder: XD adds the tests in extras-plan.md 4.4, 4.6, 4.9, 4.12 and 4.13 here.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Prisons are driven with tick(seconds) with their own processing stopped;
 * fixtures are in voidcrew_outpost_prison_helpers.dm.
 */

/datum/unit_test/voidcrew_outpost_prison_life_files

/datum/unit_test/voidcrew_outpost_prison_life_files/Run()
	// The file is read the way outpost_prisoner_extra_dialogue() reads it (the strings directory is a define)
	load_strings_file("outpost_prison_life.json", "voidcrew/modules/player_outposts/strings")
	var/list/contents = GLOB.string_cache["outpost_prison_life.json"]
	TEST_ASSERT(islist(contents), "outpost_prison_life.json did not load")
	TEST_ASSERT(islist(contents["lines"]), "outpost_prison_life.json has no lines block")
	TEST_ASSERT(islist(contents["conversations_friendly"]), "outpost_prison_life.json has no conversations_friendly block")
	TEST_ASSERT(islist(contents["conversations_hostile"]), "outpost_prison_life.json has no conversations_hostile block")
