/**
 * NPC guards (outpost_prison_guards.dm, outpost_prison_guard_routine.dm). Owner: XA.
 * X0 placeholder: XA adds the tests in extras-plan.md 4.1 here.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Prisons are driven with tick(seconds) with their own processing stopped;
 * fixtures are in voidcrew_outpost_prison_helpers.dm.
 */

/datum/unit_test/voidcrew_outpost_prison_guards_files

/datum/unit_test/voidcrew_outpost_prison_guards_files/Run()
	// The file is read the way outpost_prisoner_extra_dialogue() reads it (the strings directory is a define)
	load_strings_file("outpost_prison_guards.json", "voidcrew/modules/player_outposts/strings")
	var/list/contents = GLOB.string_cache["outpost_prison_guards.json"]
	TEST_ASSERT(islist(contents), "outpost_prison_guards.json did not load")
	TEST_ASSERT(islist(contents["lines"]), "outpost_prison_guards.json has no lines block")
	TEST_ASSERT(islist(contents["guard_lines"]), "outpost_prison_guards.json has no guard_lines block")
	TEST_ASSERT(islist(contents["guard_personalities"]), "outpost_prison_guards.json has no guard_personalities block")
	TEST_ASSERT(!is_outpost_prison_guard(null), "Nothing counted as a guard")
