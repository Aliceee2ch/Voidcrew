/**
 * Interrogation and leads (outpost_prison_leads.dm). Owner: XG.
 * X0 placeholder: XG adds the tests in extras-plan.md 4.16 here.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Prisons are driven with tick(seconds) with their own processing stopped;
 * fixtures are in voidcrew_outpost_prison_helpers.dm.
 */

/datum/unit_test/voidcrew_outpost_prison_leads_files

/datum/unit_test/voidcrew_outpost_prison_leads_files/Run()
	// The file is read the way outpost_prisoner_extra_dialogue() reads it (the strings directory is a define)
	load_strings_file("outpost_prison_leads.json", "voidcrew/modules/player_outposts/strings")
	var/list/contents = GLOB.string_cache["outpost_prison_leads.json"]
	TEST_ASSERT(islist(contents), "outpost_prison_leads.json did not load")
	TEST_ASSERT(islist(contents["lines"]), "outpost_prison_leads.json has no lines block")
	TEST_ASSERT(islist(contents["tells"]), "outpost_prison_leads.json has no tells block")
	TEST_ASSERT(islist(contents["fake_names"]), "outpost_prison_leads.json has no fake_names block")
