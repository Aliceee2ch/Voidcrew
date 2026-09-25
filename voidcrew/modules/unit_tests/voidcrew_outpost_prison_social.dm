/**
 * Staff reputation and the talk menu (outpost_prison_social.dm, outpost_prison_warden_tools.dm). Owner: XC.
 * X0 placeholder: XC adds the tests in extras-plan.md 4.3 and 4.8 here.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Prisons are driven with tick(seconds) with their own processing stopped;
 * fixtures are in voidcrew_outpost_prison_helpers.dm.
 */

/datum/unit_test/voidcrew_outpost_prison_social_files

/datum/unit_test/voidcrew_outpost_prison_social_files/Run()
	// The file is read the way outpost_prisoner_extra_dialogue() reads it (the strings directory is a define)
	load_strings_file("outpost_prison_social.json", "voidcrew/modules/player_outposts/strings")
	var/list/contents = GLOB.string_cache["outpost_prison_social.json"]
	TEST_ASSERT(islist(contents), "outpost_prison_social.json did not load")
	TEST_ASSERT(islist(contents["lines"]), "outpost_prison_social.json has no lines block")
