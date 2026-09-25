/datum/map_template/shuttle/voidcrew/patrol_bee
	name = "Patrol Bee"
	catalog_desc = ""
	suffix = "patrol_bee_nanotrasen"
	short_name = "Patrol Bee"
	part_requirements = list(PART_CLASS_MISC = 0)
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list("Upper_Cargo", "closet", "cleanroom", "service")
	player_hidden = FALSE
	job_slots = list(
		list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/captain, category = JOB_CAT_COMMAND, slots = 1),
		list(name = "Crew", outfit = /datum/outfit/job/assistant, category = JOB_CAT_ASSISTANT, slots = 3),
	)
	available_themes = list("standard")

/obj/docking_port/mobile/voidcrew/patrol_bee
	name = "Patrol Bee"
	area_type = /area/shuttle/voidcrew/patrol_bee
	port_direction = 2
	preferred_direction = NORTH

/area/shuttle/voidcrew/patrol_bee
	name = "Patrol Bee"
	icon_state = "station"
