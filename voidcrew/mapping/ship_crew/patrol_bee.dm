// Ship Workshop crew outfits. Edit these through the crew editor.

/datum/outfit/job/workshop_patrol_bee_job_16
	parent_type = /datum/outfit/job/bitrunner
	name = "Patrol Bee — Bitrunner"
	uniform = /obj/item/clothing/under/syndicate/sniper
	id = /obj/item/card/id/advanced/black/syndicate_command

/datum/outfit/job/workshop_patrol_bee_job_16/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate/sniper
	id = /obj/item/card/id/advanced/black/syndicate_command

/datum/outfit/job/workshop_patrol_bee_job_5
	parent_type = /datum/outfit/outpost_mechanic
	name = "Patrol Bee — Cargo Mechanic"
	uniform = /obj/item/clothing/under/rank/cargo/miner
	head = /obj/item/clothing/head/utility/hardhat/welding/orange
	id = /obj/item/card/id/advanced

/datum/outfit/job/workshop_patrol_bee_job_5/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/cargo/miner
	head = /obj/item/clothing/head/utility/hardhat/welding/orange
	id = /obj/item/card/id/advanced

/datum/outfit/job/workshop_patrol_bee_job_17
	parent_type = /datum/outfit/outpost_mechanic
	name = "Patrol Bee — Cargo Mechanic"
	uniform = /obj/item/clothing/under/rank/cargo/miner
	head = /obj/item/clothing/head/utility/hardhat/welding/orange
	gloves = /obj/item/clothing/gloves/combat
	shoes = /obj/item/clothing/shoes/combat
	id = /obj/item/card/id/advanced/black/syndicate_command

/datum/outfit/job/workshop_patrol_bee_job_17/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/cargo/miner
	head = /obj/item/clothing/head/utility/hardhat/welding/orange
	gloves = /obj/item/clothing/gloves/combat
	shoes = /obj/item/clothing/shoes/combat
	id = /obj/item/card/id/advanced/black/syndicate_command

/datum/outfit/job/workshop_patrol_bee_job_6
	parent_type = /datum/outfit/deathmatch_loadout/battler/surgeon
	name = "Patrol Bee — Surgeon"
	glasses = null
	gloves = /obj/item/clothing/gloves/latex/nitrile
	belt = /obj/item/storage/belt/medical
	id = /obj/item/card/id/advanced
	l_pocket = null
	r_pocket = null
	l_hand = /obj/item/storage/medkit/surgery
	backpack_contents = list()

/datum/outfit/job/workshop_patrol_bee_job_6/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	glasses = null
	gloves = /obj/item/clothing/gloves/latex/nitrile
	belt = /obj/item/storage/belt/medical
	id = /obj/item/card/id/advanced
	l_pocket = null
	r_pocket = null
	l_hand = /obj/item/storage/medkit/surgery
	backpack_contents = list()

/datum/outfit/job/workshop_patrol_bee_job_18
	parent_type = /datum/outfit/deathmatch_loadout/battler/surgeon
	name = "Patrol Bee — Surgeon"
	uniform = /obj/item/clothing/under/rank/medical/scrubs/coroner
	head = /obj/item/clothing/head/utility/surgerycap/black
	mask = /obj/item/clothing/mask/bandana
	glasses = null
	gloves = /obj/item/clothing/gloves/latex/coroner
	belt = /obj/item/storage/belt/medical
	id = /obj/item/card/id/advanced/black/syndicate_command
	l_pocket = null
	r_pocket = null
	l_hand = /obj/item/storage/medkit/surgery
	backpack_contents = list()

/datum/outfit/job/workshop_patrol_bee_job_18/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/medical/scrubs/coroner
	head = /obj/item/clothing/head/utility/surgerycap/black
	mask = /obj/item/clothing/mask/bandana
	glasses = null
	gloves = /obj/item/clothing/gloves/latex/coroner
	belt = /obj/item/storage/belt/medical
	id = /obj/item/card/id/advanced/black/syndicate_command
	l_pocket = null
	r_pocket = null
	l_hand = /obj/item/storage/medkit/surgery
	backpack_contents = list()

/datum/outfit/job/workshop_patrol_bee_job_11
	parent_type = /datum/outfit/job/hop
	name = "Patrol Bee — Head of Personnel"
	backpack_contents = list(/obj/item/plant_analyzer = 1, /obj/item/sharpener = 1)

/datum/outfit/job/workshop_patrol_bee_job_11/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	backpack_contents = list(/obj/item/plant_analyzer = 1, /obj/item/sharpener = 1)

/datum/outfit/job/workshop_patrol_bee_job_23
	parent_type = /datum/outfit/job/hop
	name = "Patrol Bee — Head of Personnel"
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/armor/vest/marine
	head = /obj/item/clothing/head/hats/hos/cap/syndicate
	id = /obj/item/card/id/advanced/black/syndicate_command
	backpack_contents = list(/obj/item/plant_analyzer = 1, /obj/item/sharpener = 1)

/datum/outfit/job/workshop_patrol_bee_job_23/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/armor/vest/marine
	head = /obj/item/clothing/head/hats/hos/cap/syndicate
	id = /obj/item/card/id/advanced/black/syndicate_command
	backpack_contents = list(/obj/item/plant_analyzer = 1, /obj/item/sharpener = 1)

/datum/outfit/job/workshop_patrol_bee_job_15
	parent_type = /datum/outfit/job/miner
	name = "Patrol Bee — Miner"
	uniform = /obj/item/clothing/under/syndicate
	id = /obj/item/card/id/advanced/black/syndicate_command

/datum/outfit/job/workshop_patrol_bee_job_15/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate
	id = /obj/item/card/id/advanced/black/syndicate_command

/datum/outfit/job/workshop_patrol_bee_job_7
	parent_type = /datum/outfit/job/chemist
	name = "Patrol Bee — Chemist"
	backpack_contents = list(/obj/item/clothing/suit/hooded/wintercoat/medical/chemistry = 1)

/datum/outfit/job/workshop_patrol_bee_job_7/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	backpack_contents = list(/obj/item/clothing/suit/hooded/wintercoat/medical/chemistry = 1)

/datum/outfit/job/workshop_patrol_bee_job_19
	parent_type = /datum/outfit/job/chemist
	name = "Patrol Bee — Chemist"
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/toggle/labcoat/interdyne
	back = /obj/item/storage/backpack/coroner
	id = /obj/item/card/id/advanced/black/syndicate_command
	backpack_contents = list(/obj/item/clothing/suit/hooded/wintercoat/medical/chemistry = 1)

/datum/outfit/job/workshop_patrol_bee_job_19/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/toggle/labcoat/interdyne
	back = /obj/item/storage/backpack/coroner
	id = /obj/item/card/id/advanced/black/syndicate_command
	backpack_contents = list(/obj/item/clothing/suit/hooded/wintercoat/medical/chemistry = 1)

/datum/outfit/job/workshop_patrol_bee_job_20
	parent_type = /datum/outfit/job/scientist/consistent
	name = "Patrol Bee — Scientist"
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/toggle/labcoat/interdyne
	id = /obj/item/card/id/advanced/black/syndicate_command

/datum/outfit/job/workshop_patrol_bee_job_20/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/toggle/labcoat/interdyne
	id = /obj/item/card/id/advanced/black/syndicate_command

/datum/outfit/job/workshop_patrol_bee_job_13
	parent_type = /datum/outfit/spacepol
	name = "Patrol Bee — Patrolling Officer"
	mask = null
	glasses = /obj/item/clothing/glasses/hud/security/sunglasses
	ears = /obj/item/radio/headset/headset_sec/alt
	gloves = /obj/item/clothing/gloves/color/black/security/blu
	belt = null
	l_pocket = null

/datum/outfit/job/workshop_patrol_bee_job_13/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	mask = null
	glasses = /obj/item/clothing/glasses/hud/security/sunglasses
	ears = /obj/item/radio/headset/headset_sec/alt
	gloves = /obj/item/clothing/gloves/color/black/security/blu
	belt = null
	l_pocket = null

/datum/outfit/job/workshop_patrol_bee_job_25
	parent_type = /datum/outfit/spacepol
	name = "Patrol Bee — Patrolling Officer"
	uniform = /obj/item/clothing/under/syndicate
	head = /obj/item/clothing/head/hats/hos/cap/syndicate
	mask = null
	glasses = /obj/item/clothing/glasses/hud/security/sunglasses/eyepatch
	ears = /obj/item/radio/headset/headset_sec/alt
	gloves = /obj/item/clothing/gloves/color/black/security/blu
	belt = null
	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id
	l_pocket = null

/datum/outfit/job/workshop_patrol_bee_job_25/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate
	head = /obj/item/clothing/head/hats/hos/cap/syndicate
	mask = null
	glasses = /obj/item/clothing/glasses/hud/security/sunglasses/eyepatch
	ears = /obj/item/radio/headset/headset_sec/alt
	gloves = /obj/item/clothing/gloves/color/black/security/blu
	belt = null
	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id
	l_pocket = null

/datum/outfit/job/workshop_patrol_bee_job_12
	parent_type = /datum/outfit/spacepol
	name = "Patrol Bee — Patrolling Officer"
	mask = null
	glasses = /obj/item/clothing/glasses/hud/security/sunglasses
	ears = /obj/item/radio/headset/headset_sec/alt
	gloves = /obj/item/clothing/gloves/color/black/security/blu
	belt = null
	l_pocket = null

/datum/outfit/job/workshop_patrol_bee_job_12/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	mask = null
	glasses = /obj/item/clothing/glasses/hud/security/sunglasses
	ears = /obj/item/radio/headset/headset_sec/alt
	gloves = /obj/item/clothing/gloves/color/black/security/blu
	belt = null
	l_pocket = null

/datum/outfit/job/workshop_patrol_bee_job_24
	parent_type = /datum/outfit/spacepol
	name = "Patrol Bee — Patrolling Officer"
	uniform = /obj/item/clothing/under/syndicate
	head = /obj/item/clothing/head/hats/hos/cap/syndicate
	mask = null
	glasses = /obj/item/clothing/glasses/hud/security/sunglasses/eyepatch
	ears = /obj/item/radio/headset/headset_sec/alt
	gloves = /obj/item/clothing/gloves/color/black/security/blu
	belt = null
	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id
	l_pocket = null

/datum/outfit/job/workshop_patrol_bee_job_24/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate
	head = /obj/item/clothing/head/hats/hos/cap/syndicate
	mask = null
	glasses = /obj/item/clothing/glasses/hud/security/sunglasses/eyepatch
	ears = /obj/item/radio/headset/headset_sec/alt
	gloves = /obj/item/clothing/gloves/color/black/security/blu
	belt = null
	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id
	l_pocket = null

/datum/outfit/job/workshop_patrol_bee_job_9
	parent_type = /datum/outfit/deathmatch_loadout/chef/upgraded
	name = "Patrol Bee — Chef"
	belt = null
	id = /obj/item/card/id/advanced
	backpack_contents = list(/obj/item/holosign_creator/robot_seat/restaurant = 1, /obj/item/sharpener = 1)

/datum/outfit/job/workshop_patrol_bee_job_9/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	belt = null
	id = /obj/item/card/id/advanced
	backpack_contents = list(/obj/item/holosign_creator/robot_seat/restaurant = 1, /obj/item/sharpener = 1)

/datum/outfit/job/workshop_patrol_bee_job_21
	parent_type = /datum/outfit/deathmatch_loadout/chef/upgraded
	name = "Patrol Bee — Chef"
	uniform = /obj/item/clothing/under/syndicate/sniper
	belt = null
	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id
	backpack_contents = list(/obj/item/holosign_creator/robot_seat/restaurant = 1, /obj/item/sharpener = 1)

/datum/outfit/job/workshop_patrol_bee_job_21/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate/sniper
	belt = null
	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id
	backpack_contents = list(/obj/item/holosign_creator/robot_seat/restaurant = 1, /obj/item/sharpener = 1)

/datum/outfit/job/workshop_patrol_bee_job_2
	parent_type = /datum/outfit/job/quartermaster/corporate
	name = "Patrol Bee — Quartermaster"
	backpack_contents = list(/obj/item/clothing/accessory/medal/gold/ordom = 1, /obj/item/melee/baton = 1, /obj/item/paper_bin = 1, /obj/item/universal_scanner = 1)

/datum/outfit/job/workshop_patrol_bee_job_2/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	backpack_contents = list(/obj/item/clothing/accessory/medal/gold/ordom = 1, /obj/item/melee/baton = 1, /obj/item/paper_bin = 1, /obj/item/universal_scanner = 1)

/datum/outfit/job/workshop_patrol_bee_job_1
	parent_type = /datum/outfit/job/hos
	name = "Patrol Bee — Captain"
	id = /obj/item/card/id/advanced/gold
	backpack_contents = list(/obj/item/evidencebag = 1, /obj/item/gun/energy/e_gun/hos = 1, /obj/item/melee/baton/security/loaded/hos = 1, /obj/item/melee/baton/telescopic/gold = 1)

/datum/outfit/job/workshop_patrol_bee_job_1/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	id = /obj/item/card/id/advanced/gold
	backpack_contents = list(/obj/item/evidencebag = 1, /obj/item/gun/energy/e_gun/hos = 1, /obj/item/melee/baton/security/loaded/hos = 1, /obj/item/melee/baton/telescopic/gold = 1)
