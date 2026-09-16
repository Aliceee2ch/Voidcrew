
/datum/ship_theme/ship_nanobead_standard
	job_slots = list(list(name = "Commander", officer = TRUE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_4, category = "Command", slots = 1), list(name = "Crew", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_5, category = "Assistant", slots = 3))
	id = "standard"
	name = "Light"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	template_suffix = "nanobead"
	is_default = TRUE
	upgrade_slot_ids = list("Biomedical_North", "Services_North", "Biomedical_South", "Services_South")

/datum/ship_theme/ship_nanobead_dark
	part_cost = list()
	job_slots = list(list(name = "Commander", officer = TRUE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_6, category = "Command", slots = 1), list(name = "Crew", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_7, category = "Assistant", slots = 3))
	id = "dark"
	name = "Dark"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	template_suffix = "nanobead_dark"
	is_default = FALSE
	upgrade_slot_ids = list("Biomedical_North", "Services_North", "Biomedical_South", "Services_South")

/datum/ship_upgrade_module/ship_nanobead_med_sci_north_basic
	job_slots_add = list()
	id = "med_sci_north_basic"
	name = "Empty Biomedical North"
	slot = "Biomedical_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/empty_biomedical_north.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/ship_nanobead_xenobio
	part_cost = list()
	job_slots_add = list()
	id = "xenobio"
	name = "Xenobio North"
	slot = "Biomedical_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/xenobio_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_nanites
	part_cost = list()
	job_slots_add = list()
	id = "nanites"
	name = "Nanites North"
	slot = "Biomedical_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/nanites_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_robotics
	part_cost = list()
	id = "robotics"
	name = "Robotics North"
	slot = "Biomedical_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/robotics_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_chemistry
	part_cost = list()
	id = "chemistry"
	name = "Chemistry North"
	slot = "Biomedical_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/chemistry_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_cryo
	part_cost = list()
	id = "cryo"
	name = "Cryo Cells North"
	slot = "Biomedical_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/cryo_cells_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_sleeper_bay
	part_cost = list()
	id = "sleeper_bay"
	name = "Sleeper Bay North"
	slot = "Biomedical_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/sleeper_bay_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_surgery
	part_cost = list()
	id = "surgery"
	name = "Surgery North"
	slot = "Biomedical_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/surgery_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_services_north_basic
	id = "services_north_basic"
	name = "Empty Services North"
	slot = "Services_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/empty_services_north.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/ship_nanobead_bitrunning
	part_cost = list()
	id = "bitrunning"
	name = "Bitrunning North"
	slot = "Services_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/bitrunning_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_dining
	part_cost = list()
	id = "dining"
	name = "Dining North"
	slot = "Services_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/dining_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_botany
	part_cost = list()
	id = "botany"
	name = "Botany North"
	slot = "Services_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/botany_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_mining
	part_cost = list()
	id = "mining"
	name = "Mining North"
	slot = "Services_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/mining_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_cargo
	part_cost = list()
	id = "cargo"
	name = "Cargo North"
	slot = "Services_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/cargo_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_security
	part_cost = list()
	id = "security"
	name = "Security North"
	slot = "Services_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/security_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_eva
	part_cost = list()
	id = "eva"
	name = "Eva North"
	slot = "Services_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/eva_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_biomedical_south_basic
	id = "biomedical_south_basic"
	name = "Empty Biomedical South"
	slot = "Biomedical_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/empty_biomedical_south.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/ship_nanobead_xenobio_south
	part_cost = list()
	id = "xenobio_south"
	name = "Xenobio South"
	slot = "Biomedical_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/xenobio_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_nanites_south
	part_cost = list()
	id = "nanites_south"
	name = "Nanites South"
	slot = "Biomedical_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/nanites_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_robotics_south
	part_cost = list()
	id = "robotics_south"
	name = "Robotics South"
	slot = "Biomedical_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/robotics_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_chemistry_south
	part_cost = list()
	id = "chemistry_south"
	name = "Chemistry South"
	slot = "Biomedical_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/chemistry_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_cryo_cells_south
	part_cost = list()
	id = "cryo_cells_south"
	name = "Cryo Cells South"
	slot = "Biomedical_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/cryo_cells_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_sleeper_bay_south
	part_cost = list()
	id = "sleeper_bay_south"
	name = "Sleeper Bay South"
	slot = "Biomedical_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/sleeper_bay_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_surgery_south
	part_cost = list()
	id = "surgery_south"
	name = "Surgery South"
	slot = "Biomedical_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/surgery_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_services_south_basic
	id = "services_south_basic"
	name = "Empty Services South"
	slot = "Services_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/empty_services_south.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/ship_nanobead_bitrunning_south
	part_cost = list()
	id = "bitrunning_south"
	name = "Bitrunning South"
	slot = "Services_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/bitrunning_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_dining_south
	part_cost = list()
	id = "dining_south"
	name = "Dining South"
	slot = "Services_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/dining_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_botany_south
	part_cost = list()
	id = "botany_south"
	name = "Botany South"
	slot = "Services_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/botany_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_mining_south
	part_cost = list()
	id = "mining_south"
	name = "Mining South"
	slot = "Services_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/mining_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_cargo_south
	part_cost = list()
	id = "cargo_south"
	name = "Cargo South"
	slot = "Services_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/cargo_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_security_south
	part_cost = list()
	id = "security_south"
	name = "Security South"
	slot = "Services_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/security_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_eva_south
	part_cost = list()
	id = "eva_south"
	name = "Eva South"
	slot = "Services_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/eva_south.dmm"
	is_default = FALSE
