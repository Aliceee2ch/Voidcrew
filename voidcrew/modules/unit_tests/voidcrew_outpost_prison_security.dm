/**
 * Stun turrets and the yard's feel (outpost_prison_security.dm, outpost_prison_ambience.dm). Owner: XB.
 * X0 placeholder: XB adds the tests in extras-plan.md 4.2, 4.5 and 4.7 here.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Prisons are driven with tick(seconds) with their own processing stopped;
 * fixtures are in voidcrew_outpost_prison_helpers.dm.
 */

/datum/unit_test/voidcrew_outpost_prison_security_files

/datum/unit_test/voidcrew_outpost_prison_security_files/Run()
	// The file is read the way outpost_prisoner_extra_dialogue() reads it (the strings directory is a define)
	load_strings_file("outpost_prison_security.json", "voidcrew/modules/player_outposts/strings")
	var/list/contents = GLOB.string_cache["outpost_prison_security.json"]
	TEST_ASSERT(islist(contents), "outpost_prison_security.json did not load")
	TEST_ASSERT(islist(contents["lines"]), "outpost_prison_security.json has no lines block")
	TEST_ASSERT(islist(contents["examine"]), "outpost_prison_security.json has no examine block")
	TEST_ASSERT(!is_outpost_prison_stun_turret(null), "Nothing counted as a stun turret")
