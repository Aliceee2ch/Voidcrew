/**
 * The prison wing's map: what a placed wing holds at any rotation.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with
 * the define named beside them. Prisons are driven with tick(seconds) with their own processing
 * stopped, never by waiting in real time, except for beams, which run on timers. Fixtures are
 * in voidcrew_outpost_prison_helpers.dm.
 */

/// A turned wing comes with a tiny fan under its entrance, its yard bin and its office kit: the
/// baton instead of handcuffs, the recharger, a mixed box of lights, flashlights, the cleaning kit,
/// eight uniforms, a crowbar on the rack for the cell cisterns, and air scrubbers in the cells and
/// the yard.
/datum/unit_test/voidcrew_outpost_prison_map_kit
	parent_type = /datum/unit_test/voidcrew_outpost_management

/// Everything of `wanted_type` in the wing, including what is inside closets and boxes
/datum/unit_test/voidcrew_outpost_prison_map_kit/proc/wing_things(datum/outpost_prison/prison, wanted_type)
	var/list/found = list()
	for(var/turf/tile as anything in prison.wing_turfs())
		found += tile.get_all_contents_type(wanted_type)
	return found

/// Whether every one of `things` is out of the prisoners' side of the wing
/datum/unit_test/voidcrew_outpost_prison_map_kit/proc/all_in_office(datum/outpost_prison/prison, list/things)
	for(var/atom/thing as anything in things)
		if(prison.cell_block[get_turf(thing)])
			return FALSE
	return TRUE

/datum/unit_test/voidcrew_outpost_prison_map_kit/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("mapkitowner")
	TEST_ASSERT_NOTNULL(home, "The map kit test outpost did not load")
	var/datum/outpost_upgrade/prison/blueprint = new(home)
	home.outpost_upgrades["prison"] = blueprint
	// East of the shell, turned a quarter, as the placement test puts its 90 degree wing.
	var/turf/bottom_left = locate(home.template_bottom_left.x + home.shell_template.width + 3, home.template_bottom_left.y, home.upgrade_level_z())
	TEST_ASSERT_NULL(home.place_outpost_upgrade(blueprint, bottom_left, 90, null), "The prison wing was not placed turned 90 degrees")
	var/datum/outpost_prison/prison = blueprint.prison
	TEST_ASSERT_NOTNULL(prison, "The turned wing did not start a prison")
	STOP_PROCESSING(SSprocessing, prison)
	TEST_ASSERT(length(prison.cell_block), "The turned wing has no cell block")

	// The one door out, the entrance, has a tiny fan: it can open onto vacuum or a planet. The
	// cell, staff and hatch doors are all inside the wing and have none.
	var/list/footprint = blueprint.footprint_at(bottom_left, 90)
	var/list/doors_out = upgrade_exterior_doors(footprint["turfs"])
	var/list/exterior = doors_out[1]
	var/list/unfanned = doors_out[2]
	TEST_ASSERT_EQUAL(length(exterior), 1, "The wing should have one door out, not [length(exterior)]")
	TEST_ASSERT(get_turf(exterior[1]) in footprint["entrance"], "The wing's door out is not on its entrance edge")
	TEST_ASSERT(!length(unfanned), "The wing's entrance has no tiny fan")
	var/fans = 0
	for(var/turf/tile as anything in footprint["turfs"])
		for(var/obj/structure/fans/tiny/fan in tile)
			fans++
	TEST_ASSERT_EQUAL(fans, 1, "The wing should have one tiny fan, at its entrance, not [fans]")

	// The yard bin: one, empty, beside a mess table and on the prisoners' side, with ground to stand on.
	var/list/bins = wing_things(prison, /obj/structure/closet/crate/bin)
	TEST_ASSERT_EQUAL(length(bins), 1, "The wing should have one yard bin")
	var/obj/structure/closet/crate/bin/bin = bins[1]
	TEST_ASSERT(isturf(bin.loc) && prison.cell_block[bin.loc], "The yard bin is not in the cell block")
	TEST_ASSERT_EQUAL(length(bin.contents), 0, "The yard bin swallowed something at load")
	var/beside_table = FALSE
	var/standing_room = FALSE
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(bin, direction)
		var/obj/structure/table/table = locate() in beside
		if(table && !istype(table, /obj/structure/table/reinforced/prison_hatch))
			beside_table = TRUE
		if(prison.cell_block[beside] && prison.prisoner_can_stand(beside))
			standing_room = TRUE
	TEST_ASSERT(beside_table, "The yard bin is not beside a mess table")
	TEST_ASSERT(standing_room, "No prisoner can stand beside the yard bin")

	// The office rack holds a charged baton, not handcuffs.
	TEST_ASSERT_EQUAL(length(wing_things(prison, /obj/item/restraints/handcuffs)), 0, "The wing still has handcuffs")
	var/list/batons = wing_things(prison, /obj/item/melee/baton/security/loaded)
	TEST_ASSERT_EQUAL(length(batons), 1, "The wing should have one stun baton")
	var/obj/item/melee/baton/security/loaded/baton = batons[1]
	TEST_ASSERT(baton.cell?.charge > 0, "The office baton has no charge")
	TEST_ASSERT(locate(/obj/structure/rack) in get_turf(baton), "The office baton is not on the rack")

	// The recharger stands on an office table.
	var/list/rechargers = wing_things(prison, /obj/machinery/recharger)
	TEST_ASSERT_EQUAL(length(rechargers), 1, "The wing should have one recharger")
	TEST_ASSERT(locate(/obj/structure/table) in get_turf(rechargers[1]), "The recharger is not on a table")

	// Lights and the cleaning kit.
	// tg's mixed box, tubes and bulbs: the wing has both kinds of fixture.
	var/list/light_boxes = wing_things(prison, /obj/item/storage/box/lights/mixed)
	TEST_ASSERT_EQUAL(length(light_boxes), 1, "The wing should have one mixed box of lights")
	TEST_ASSERT_EQUAL(length(wing_things(prison, /obj/item/storage/box/lights/tubes)), 0, "The wing still has a tubes-only box, which can't replace its bulbs")
	var/flashlights = 0
	for(var/obj/item/flashlight/light as anything in wing_things(prison, /obj/item/flashlight))
		if(light.type == /obj/item/flashlight)
			flashlights++
	TEST_ASSERT_EQUAL(flashlights, 2, "The wing should have two flashlights")
	var/list/kit = batons + rechargers + light_boxes
	for(var/kit_type in list(/obj/item/mop, /obj/structure/mop_bucket, /obj/item/storage/bag/trash, /obj/item/reagent_containers/spray/cleaner, /obj/item/clothing/suit/caution, /obj/item/melee/flyswatter))
		var/list/pieces = wing_things(prison, kit_type)
		TEST_ASSERT(length(pieces), "The wing has no [kit_type]")
		kit += pieces
	TEST_ASSERT(all_in_office(prison, kit), "Some of the office kit is on the prisoners' side of the wing")

	// Eight clean uniforms, all in the office locker.
	var/list/uniforms = wing_things(prison, /obj/item/clothing/under/rank/prisoner/outpost)
	TEST_ASSERT_EQUAL(length(uniforms), 8, "The wing should have eight prison uniforms")
	for(var/obj/item/clothing/under/rank/prisoner/outpost/uniform as anything in uniforms)
		TEST_ASSERT(istype(uniform.loc, /obj/structure/closet) && !istype(uniform.loc, /obj/structure/closet/crate), "A prison uniform is not in the locker")
	TEST_ASSERT(all_in_office(prison, uniforms), "The uniform locker is on the prisoners' side of the wing")

	// A plain crowbar on the rack, for lifting the cell cistern lids.
	var/list/crowbars = list()
	for(var/obj/item/crowbar/bar as anything in wing_things(prison, /obj/item/crowbar))
		if(bar.type == /obj/item/crowbar)
			crowbars += bar
	TEST_ASSERT_EQUAL(length(crowbars), 1, "The wing should have one crowbar")
	TEST_ASSERT(locate(/obj/structure/rack) in get_turf(crowbars[1]), "The crowbar is not on the rack")
	TEST_ASSERT(all_in_office(prison, crowbars), "The crowbar is on the prisoners' side of the wing")

	// Air scrubbers for the scrubber overflow: one in each cell and three in the yard, all in the
	// cell block and none welded. The seven sealed Kessler vents are still there beside them.
	var/list/scrubbers = wing_things(prison, /obj/machinery/atmospherics/components/unary/vent_scrubber)
	TEST_ASSERT_EQUAL(length(scrubbers), 7, "The wing should have seven air scrubbers")
	for(var/obj/machinery/atmospherics/components/unary/vent_scrubber/scrubber as anything in scrubbers)
		TEST_ASSERT(prison.cell_block[get_turf(scrubber)], "An air scrubber is outside the cell block")
		TEST_ASSERT(!scrubber.welded, "An air scrubber came welded shut")
	TEST_ASSERT_EQUAL(length(prison.cells), 4, "The turned wing should have four cells")
	for(var/datum/outpost_prison_cell/cell as anything in prison.cells)
		var/in_cell = 0
		for(var/obj/machinery/atmospherics/components/unary/vent_scrubber/scrubber as anything in scrubbers)
			if(cell.turf_set[get_turf(scrubber)])
				in_cell++
		TEST_ASSERT_EQUAL(in_cell, 1, "Cell [cell.number] should have one air scrubber")
	TEST_ASSERT_EQUAL(length(wing_things(prison, /obj/structure/outpost_kessler_vent)), 7, "The wing should still have seven Kessler vents")

	settle_prison_air(home)
