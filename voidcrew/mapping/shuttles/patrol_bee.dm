/datum/map_template/shuttle/voidcrew/patrol_bee
	name = "Patrol Bee"
	catalog_desc = ""
	suffix = "patrol_bee_nanotrasen"
	short_name = "Patrol Bee"
	part_requirements = list(PART_CLASS_MISC = 0)
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list("Upper_Cargo", "closet", "cleanroom", "service", "security_bay")
	player_hidden = FALSE
	job_slots = list(list(name = "Quartermaster", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_2, category = "Cargo", slots = 1))
	available_themes = list("standard", "syndicate_black")

/obj/docking_port/mobile/voidcrew/patrol_bee
	name = "Patrol Bee"
	area_type = /area/shuttle/voidcrew/patrol_bee
	port_direction = 2
	preferred_direction = NORTH

/area/shuttle/voidcrew/patrol_bee
	name = "Patrol Bee"
	icon_state = "station"
