// Ship Workshop crew outfits. Edit these through the crew editor.

/datum/outfit/job/workshop_ship_nanobead_job_6
	parent_type = /datum/outfit/job/captain
	name = "NanoBead — Commander"
	uniform = /obj/item/clothing/under/costume/dutch/syndicate
	suit = /obj/item/clothing/suit/armor/vest/capcarapace/syndicate
	head = /obj/item/clothing/head/hats/hos/cap/syndicate
	mask = null
	neck = null
	gloves = null
	shoes = /obj/item/clothing/shoes/workboots/black
	back = /obj/item/storage/backpack/satchel/leather
	belt = /obj/item/modular_computer/pda/nukeops
	id = /obj/item/card/id/advanced/gold
	l_pocket = /obj/item/gun/ballistic/revolver
	accessory = /obj/item/clothing/accessory/medal/gold/captain

/datum/outfit/job/workshop_ship_nanobead_job_6/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/costume/dutch/syndicate
	suit = /obj/item/clothing/suit/armor/vest/capcarapace/syndicate
	head = /obj/item/clothing/head/hats/hos/cap/syndicate
	mask = null
	neck = null
	gloves = null
	shoes = /obj/item/clothing/shoes/workboots/black
	back = /obj/item/storage/backpack/satchel/leather
	belt = /obj/item/modular_computer/pda/nukeops
	id = /obj/item/card/id/advanced/gold
	l_pocket = /obj/item/gun/ballistic/revolver
	accessory = /obj/item/clothing/accessory/medal/gold/captain

/datum/outfit/job/workshop_ship_nanobead_job_7
	parent_type = /datum/outfit/job/assistant
	name = "NanoBead — Crew"
	uniform = /obj/item/clothing/under/syndicate/tacticool
	suit = null
	head = /obj/item/clothing/head/hats/hos/beret/syndicate
	gloves = null
	shoes = /obj/item/clothing/shoes/workboots/black
	back = /obj/item/storage/backpack/messenger
	belt = /obj/item/modular_computer/pda/assistant
	accessory = null

/datum/outfit/job/workshop_ship_nanobead_job_7/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate/tacticool
	suit = null
	head = /obj/item/clothing/head/hats/hos/beret/syndicate
	gloves = null
	shoes = /obj/item/clothing/shoes/workboots/black
	back = /obj/item/storage/backpack/messenger
	belt = /obj/item/modular_computer/pda/assistant
	accessory = null

/datum/outfit/job/workshop_ship_nanobead_job_4
	parent_type = /datum/outfit/job/captain
	name = "NanoBead — Commander"
	uniform = /obj/item/clothing/under/rank/centcom/commander
	suit = /obj/item/clothing/suit/armor/centcom_formal
	head = /obj/item/clothing/head/hats/centcom_cap
	mask = null
	neck = null
	gloves = null
	back = /obj/item/storage/backpack/satchel/leather
	belt = /obj/item/modular_computer/pda/heads
	id = /obj/item/card/id/advanced/gold
	l_pocket = /obj/item/gun/ballistic/revolver
	accessory = /obj/item/clothing/accessory/medal/gold/captain

/datum/outfit/job/workshop_ship_nanobead_job_4/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/centcom/commander
	suit = /obj/item/clothing/suit/armor/centcom_formal
	head = /obj/item/clothing/head/hats/centcom_cap
	mask = null
	neck = null
	gloves = null
	back = /obj/item/storage/backpack/satchel/leather
	belt = /obj/item/modular_computer/pda/heads
	id = /obj/item/card/id/advanced/gold
	l_pocket = /obj/item/gun/ballistic/revolver
	accessory = /obj/item/clothing/accessory/medal/gold/captain

/datum/outfit/job/workshop_ship_nanobead_job_5
	parent_type = /datum/outfit/job/assistant
	name = "NanoBead — Crew"
	uniform = /obj/item/clothing/under/rank/centcom/intern
	suit = null
	head = /obj/item/clothing/head/hats/intern
	gloves = /obj/item/clothing/gloves/fingerless
	back = /obj/item/storage/backpack/messenger
	belt = /obj/item/modular_computer/pda/assistant
	accessory = null

/datum/outfit/job/workshop_ship_nanobead_job_5/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/centcom/intern
	suit = null
	head = /obj/item/clothing/head/hats/intern
	gloves = /obj/item/clothing/gloves/fingerless
	back = /obj/item/storage/backpack/messenger
	belt = /obj/item/modular_computer/pda/assistant
	accessory = null
