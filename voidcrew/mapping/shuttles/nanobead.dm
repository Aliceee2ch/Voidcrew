/datum/map_template/shuttle/voidcrew/ship_nanobead
	name = "NanoBead"
	catalog_desc = ""
	suffix = "nanobead"
	short_name = "NanoBead"
	part_requirements = list()
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list("Biomedical_North", "Services_North", "Biomedical_South", "Services_South")
	player_hidden = TRUE
	job_slots = list()
	available_themes = list("standard", "dark")

/obj/docking_port/mobile/voidcrew/ship_nanobead
	name = "NanoBead"
	area_type = /area/shuttle/voidcrew/ship_nanobead
	port_direction = 2
	preferred_direction = NORTH

/area/shuttle/voidcrew/ship_nanobead
	name = "NanoBead"
	icon_state = "station"
