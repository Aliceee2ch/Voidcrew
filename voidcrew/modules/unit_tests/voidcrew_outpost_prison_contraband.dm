/**
 * Contraband, shakedowns and mail call (outpost_prison_contraband.dm, outpost_prison_mail.dm). Owner: XF.
 * X0 placeholder: XF adds the tests in extras-plan.md 4.14 and 4.15 here.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Prisons are driven with tick(seconds) with their own processing stopped;
 * fixtures are in voidcrew_outpost_prison_helpers.dm.
 */

/datum/unit_test/voidcrew_outpost_prison_contraband_files

/datum/unit_test/voidcrew_outpost_prison_contraband_files/Run()
	// The file is read the way outpost_prisoner_extra_dialogue() reads it (the strings directory is a define)
	load_strings_file("outpost_prison_contraband.json", "voidcrew/modules/player_outposts/strings")
	var/list/contents = GLOB.string_cache["outpost_prison_contraband.json"]
	TEST_ASSERT(islist(contents), "outpost_prison_contraband.json did not load")
	TEST_ASSERT(islist(contents["lines"]), "outpost_prison_contraband.json has no lines block")
	TEST_ASSERT(islist(contents["letters"]), "outpost_prison_contraband.json has no letters block")
	TEST_ASSERT(islist(contents["senders"]), "outpost_prison_contraband.json has no senders block")
