
/datum/ship_theme/patrol_bee_standard
	id = "standard"
	name = "NanoTrasen"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	template_suffix = "patrol_bee_nanotrasen"
	is_default = TRUE
	upgrade_slot_ids = list("Upper_Cargo", "closet", "cleanroom", "service")

/datum/ship_upgrade_module/patrol_bee_mining_bay_basic
	id = "mining_bay_basic"
	name = "Mining Bay"
	slot = "Upper_Cargo"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard")
	map_file = "patrol_bee/mining_bay_basic.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/patrol_bee_bitrunning_den
	part_cost = list()
	id = "bitrunning_den"
	name = "Bitrunning Den"
	slot = "Upper_Cargo"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard")
	map_file = "patrol_bee/bitrunning_den.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/patrol_bee_cargo_mech_bay
	part_cost = list()
	id = "cargo_mech_bay"
	name = "Cargo Mech Bay"
	slot = "Upper_Cargo"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard")
	map_file = "patrol_bee/cargo_mech_bay.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/patrol_bee_closet_basic
	id = "closet_basic"
	name = "Toilet"
	slot = "closet"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard")
	map_file = "patrol_bee/toilet.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/patrol_bee_custodial_closet
	part_cost = list()
	id = "custodial_closet"
	name = "Custodial Closet"
	slot = "closet"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard")
	map_file = "patrol_bee/custodial_closet.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/patrol_bee_cleanroom_basic
	id = "cleanroom_basic"
	name = "Surgery Theater"
	slot = "cleanroom"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard")
	map_file = "patrol_bee/surgery_theater.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/patrol_bee_pharmacy_lab
	part_cost = list()
	id = "pharmacy_lab"
	name = "Pharmacy Lab"
	slot = "cleanroom"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard")
	map_file = "patrol_bee/pharmacy_lab.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/patrol_bee_research_lab
	part_cost = list()
	id = "research_lab"
	name = "Research Lab"
	slot = "cleanroom"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard")
	map_file = "patrol_bee/research_lab.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/patrol_bee_service_basic
	id = "service_basic"
	name = "Full Kitchen"
	slot = "service"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard")
	map_file = "patrol_bee/full_kitchen.dmm"
	is_default = TRUE
