// Ship Workshop crew outfits. Edit these through the crew editor.

/datum/outfit/job/workshop_ship_nanobead_job_9
	parent_type = /datum/outfit/job/assistant
	name = "NanoBead — Chemist"
	uniform = /obj/item/clothing/under/rank/medical/chemist
	suit = /obj/item/clothing/suit/toggle/labcoat/chemist
	glasses = /obj/item/clothing/glasses/science
	ears = /obj/item/radio/headset/headset_med
	gloves = null
	shoes = /obj/item/clothing/shoes/sneakers/white
	back = /obj/item/storage/backpack/messenger/chem
	belt = /obj/item/modular_computer/pda/chemist
	accessory = /obj/item/clothing/accessory/armband/med

/datum/outfit/job/workshop_ship_nanobead_job_9/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/medical/chemist
	suit = /obj/item/clothing/suit/toggle/labcoat/chemist
	glasses = /obj/item/clothing/glasses/science
	ears = /obj/item/radio/headset/headset_med
	gloves = null
	shoes = /obj/item/clothing/shoes/sneakers/white
	back = /obj/item/storage/backpack/messenger/chem
	belt = /obj/item/modular_computer/pda/chemist
	accessory = /obj/item/clothing/accessory/armband/med

/datum/outfit/job/workshop_ship_nanobead_job_10
	parent_type = /datum/outfit/job/assistant
	name = "NanoBead — Cryogenicist"
	uniform = /obj/item/clothing/under/rank/medical/doctor
	suit = /obj/item/clothing/suit/toggle/labcoat
	head = null
	mask = null
	glasses = /obj/item/clothing/glasses/hud/health
	ears = /obj/item/radio/headset/headset_med
	neck = null
	gloves = null
	shoes = /obj/item/clothing/shoes/sneakers/white
	back = /obj/item/storage/backpack/messenger/med
	belt = /obj/item/modular_computer/pda/medical
	accessory = /obj/item/clothing/accessory/armband/medblue

/datum/outfit/job/workshop_ship_nanobead_job_10/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/medical/doctor
	suit = /obj/item/clothing/suit/toggle/labcoat
	head = null
	mask = null
	glasses = /obj/item/clothing/glasses/hud/health
	ears = /obj/item/radio/headset/headset_med
	neck = null
	gloves = null
	shoes = /obj/item/clothing/shoes/sneakers/white
	back = /obj/item/storage/backpack/messenger/med
	belt = /obj/item/modular_computer/pda/medical
	accessory = /obj/item/clothing/accessory/armband/medblue

/datum/outfit/job/workshop_ship_nanobead_job_1
	parent_type = /datum/outfit/job/assistant
	name = "NanoBead — Crew"
	uniform = /obj/item/clothing/under/rank/centcom/intern
	head = /obj/item/clothing/head/hats/intern
	gloves = /obj/item/clothing/gloves/fingerless
	back = /obj/item/storage/backpack/messenger

/datum/outfit/job/workshop_ship_nanobead_job_1/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/centcom/intern
	head = /obj/item/clothing/head/hats/intern
	gloves = /obj/item/clothing/gloves/fingerless
	back = /obj/item/storage/backpack/messenger

/datum/outfit/job/workshop_ship_nanobead_job_3
	parent_type = /datum/outfit/job/assistant
	name = "NanoBead — Nanotechnologist"
	uniform = /obj/item/clothing/under/rank/rnd/scientist
	suit = /obj/item/clothing/suit/toggle/labcoat/science
	mask = null
	glasses = /obj/item/clothing/glasses/science
	ears = /obj/item/radio/headset/headset_sci
	shoes = /obj/item/clothing/shoes/sneakers/purple
	back = /obj/item/storage/backpack/messenger/science
	belt = /obj/item/modular_computer/pda/science
	accessory = /obj/item/clothing/accessory/armband/science

/datum/outfit/job/workshop_ship_nanobead_job_3/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/rnd/scientist
	suit = /obj/item/clothing/suit/toggle/labcoat/science
	mask = null
	glasses = /obj/item/clothing/glasses/science
	ears = /obj/item/radio/headset/headset_sci
	shoes = /obj/item/clothing/shoes/sneakers/purple
	back = /obj/item/storage/backpack/messenger/science
	belt = /obj/item/modular_computer/pda/science
	accessory = /obj/item/clothing/accessory/armband/science

/datum/outfit/job/workshop_ship_nanobead_job_8
	parent_type = /datum/outfit/job/roboticist
	name = "NanoBead — Roboticist"
	ears = /obj/item/radio/headset/headset_sci
	shoes = /obj/item/clothing/shoes/sneakers/black
	back = /obj/item/storage/backpack/messenger/science
	belt = /obj/item/modular_computer/pda/science
	l_pocket = null
	accessory = /obj/item/clothing/accessory/armband/science

/datum/outfit/job/workshop_ship_nanobead_job_8/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	ears = /obj/item/radio/headset/headset_sci
	shoes = /obj/item/clothing/shoes/sneakers/black
	back = /obj/item/storage/backpack/messenger/science
	belt = /obj/item/modular_computer/pda/science
	l_pocket = null
	accessory = /obj/item/clothing/accessory/armband/science

/datum/outfit/job/workshop_ship_nanobead_job_12
	parent_type = /datum/outfit/job/assistant
	name = "NanoBead — Physician"
	uniform = /obj/item/clothing/under/rank/medical/doctor
	suit = /obj/item/clothing/suit/toggle/labcoat/cmo
	head = null
	mask = null
	glasses = /obj/item/clothing/glasses/hud/health
	ears = /obj/item/radio/headset/headset_med
	neck = /obj/item/clothing/neck/stethoscope
	gloves = /obj/item/clothing/gloves/latex/nitrile
	shoes = /obj/item/clothing/shoes/sneakers/white
	back = /obj/item/storage/backpack/messenger/med
	belt = /obj/item/modular_computer/pda/medical
	accessory = /obj/item/clothing/accessory/armband/medblue

/datum/outfit/job/workshop_ship_nanobead_job_12/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/medical/doctor
	suit = /obj/item/clothing/suit/toggle/labcoat/cmo
	head = null
	mask = null
	glasses = /obj/item/clothing/glasses/hud/health
	ears = /obj/item/radio/headset/headset_med
	neck = /obj/item/clothing/neck/stethoscope
	gloves = /obj/item/clothing/gloves/latex/nitrile
	shoes = /obj/item/clothing/shoes/sneakers/white
	back = /obj/item/storage/backpack/messenger/med
	belt = /obj/item/modular_computer/pda/medical
	accessory = /obj/item/clothing/accessory/armband/medblue

/datum/outfit/job/workshop_ship_nanobead_job_13
	parent_type = /datum/outfit/job/assistant
	name = "NanoBead — Surgeon"
	uniform = /obj/item/clothing/under/rank/medical/scrubs/green
	suit = /obj/item/clothing/suit/apron/surgical
	head = /obj/item/clothing/head/utility/surgerycap/green
	mask = /obj/item/clothing/mask/surgical
	glasses = /obj/item/clothing/glasses/hud/health
	ears = /obj/item/radio/headset/headset_med
	gloves = /obj/item/clothing/gloves/latex/nitrile
	shoes = /obj/item/clothing/shoes/sneakers/white
	back = /obj/item/storage/backpack/messenger/med
	belt = /obj/item/modular_computer/pda/medical
	accessory = null

/datum/outfit/job/workshop_ship_nanobead_job_13/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/medical/scrubs/green
	suit = /obj/item/clothing/suit/apron/surgical
	head = /obj/item/clothing/head/utility/surgerycap/green
	mask = /obj/item/clothing/mask/surgical
	glasses = /obj/item/clothing/glasses/hud/health
	ears = /obj/item/radio/headset/headset_med
	gloves = /obj/item/clothing/gloves/latex/nitrile
	shoes = /obj/item/clothing/shoes/sneakers/white
	back = /obj/item/storage/backpack/messenger/med
	belt = /obj/item/modular_computer/pda/medical
	accessory = null

/datum/outfit/job/workshop_ship_nanobead_job_2
	parent_type = /datum/outfit/job/assistant
	name = "NanoBead — Xenobiologist"
	uniform = /obj/item/clothing/under/rank/rnd/scientist
	suit = /obj/item/clothing/suit/toggle/labcoat/science
	head = null
	glasses = /obj/item/clothing/glasses/science
	ears = /obj/item/radio/headset/headset_sci
	gloves = null
	shoes = /obj/item/clothing/shoes/sneakers/purple
	back = /obj/item/storage/backpack/messenger/science
	belt = /obj/item/modular_computer/pda/science
	suit_store = null
	accessory = /obj/item/clothing/accessory/armband/science

/datum/outfit/job/workshop_ship_nanobead_job_2/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/rnd/scientist
	suit = /obj/item/clothing/suit/toggle/labcoat/science
	head = null
	glasses = /obj/item/clothing/glasses/science
	ears = /obj/item/radio/headset/headset_sci
	gloves = null
	shoes = /obj/item/clothing/shoes/sneakers/purple
	back = /obj/item/storage/backpack/messenger/science
	belt = /obj/item/modular_computer/pda/science
	suit_store = null
	accessory = /obj/item/clothing/accessory/armband/science

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
	name = "NanoBead — Assistant to the Regional Commander"
	uniform = /obj/item/clothing/under/rank/centcom/official
	suit = null
	head = /obj/item/clothing/head/hats/intern
	gloves = null
	shoes = /obj/item/clothing/shoes/laceup
	back = /obj/item/storage/backpack/messenger
	belt = /obj/item/modular_computer/pda/assistant
	accessory = null

/datum/outfit/job/workshop_ship_nanobead_job_5/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/centcom/official
	suit = null
	head = /obj/item/clothing/head/hats/intern
	gloves = null
	shoes = /obj/item/clothing/shoes/laceup
	back = /obj/item/storage/backpack/messenger
	belt = /obj/item/modular_computer/pda/assistant
	accessory = null

/datum/outfit/job/workshop_ship_nanobead_job_11
	parent_type = /datum/outfit/job/assistant
	name = "NanoBead — Engineer"
	uniform = /obj/item/clothing/under/rank/engineering/engineer
	head = /obj/item/clothing/head/utility/hardhat/welding
	glasses = /obj/item/clothing/glasses/meson/engine
	ears = /obj/item/radio/headset/headset_eng
	shoes = /obj/item/clothing/shoes/workboots
	back = /obj/item/storage/backpack/messenger/eng
	belt = /obj/item/modular_computer/pda/engineering
	accessory = /obj/item/clothing/accessory/armband/engine

/datum/outfit/job/workshop_ship_nanobead_job_11/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/engineering/engineer
	head = /obj/item/clothing/head/utility/hardhat/welding
	glasses = /obj/item/clothing/glasses/meson/engine
	ears = /obj/item/radio/headset/headset_eng
	shoes = /obj/item/clothing/shoes/workboots
	back = /obj/item/storage/backpack/messenger/eng
	belt = /obj/item/modular_computer/pda/engineering
	accessory = /obj/item/clothing/accessory/armband/engine
