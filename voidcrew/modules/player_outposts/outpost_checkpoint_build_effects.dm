/// Marks a tile the outpost drones are about to build on.
/obj/effect/checkpoint_build_marker
	name = "construction marker"
	desc = "A holographic marker projected by outpost construction drones."
	icon = 'icons/mob/telegraphing/telegraph_holographic.dmi'
	icon_state = "target_box"
	color = "#ffb13b"
	alpha = 200
	layer = BELOW_MOB_LAYER
	plane = GAME_PLANE
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/// Launch cradle in a ship bay corner. Yard drones leave from it and return to it.
/obj/structure/checkpoint_drone_bay
	name = "drone bay"
	desc = "A launch cradle for the outpost's construction drones."
	icon = 'icons/obj/machines/drone_dispenser.dmi'
	icon_state = "on"
	anchored = TRUE
	density = TRUE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/obj/structure/checkpoint_drone_bay/proc/launch()
	flick("make", src)

/obj/structure/checkpoint_drone_bay/proc/receive()
	flick("recharge", src)

/// What a working yard drone sounds like: welding, wrenching, screwing and cutting.
GLOBAL_LIST_INIT(checkpoint_drone_tool_sounds, list(
	'sound/items/tools/welder.ogg',
	'sound/items/tools/welder2.ogg',
	'sound/items/tools/ratchet.ogg',
	'sound/items/tools/ratchet_fast.ogg',
	'sound/items/tools/screwdriver.ogg',
	'sound/items/tools/screwdriver2.ogg',
	'sound/items/tools/screwdriver_operating.ogg',
	'sound/items/tools/wirecutter.ogg',
))

/// Cosmetic yard drone. The construction job decides what is placed and when.
/obj/effect/checkpoint_build_drone
	name = "yard drone"
	desc = "An outpost construction drone."
	icon = 'voidcrew/modules/shuttle/icons/repair_drone.dmi'
	icon_state = "complete"
	layer = ABOVE_ALL_MOB_LAYER
	plane = ABOVE_GAME_PLANE
	anchored = TRUE
	density = FALSE
	movement_type = FLYING
	// Flights are drawn with pixel slides, so several tiles per tick stay smooth.
	animate_movement = NO_STEPS
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	light_system = OVERLAY_LIGHT
	light_range = 2
	light_power = 0.8
	light_color = LIGHT_COLOR_CYAN
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	var/datum/checkpoint_visit/visit
	var/work_until = 0
	var/obj/effect/constructing_effect/checkpoint/work_effect
	var/datum/beam/work_beam
	/// The drone bay this drone launched from, and returns to.
	var/datum/weakref/cradle_ref
	/// Set once the job lets the drone go; it then flies home on its own and docks.
	var/returning_until = 0

/obj/effect/checkpoint_build_drone/Initialize(mapload, obj/structure/checkpoint_drone_bay/cradle)
	. = ..()
	if(cradle)
		cradle_ref = WEAKREF(cradle)
	animate(src, pixel_z = base_pixel_z + 3, time = 1.5 SECONDS, loop = -1, easing = SINE_EASING, flags = ANIMATION_PARALLEL)
	animate(pixel_z = base_pixel_z, time = 1.5 SECONDS, easing = SINE_EASING)

/// The visit stays referenced so the job can put it back in the queue.
/obj/effect/checkpoint_build_drone/Destroy()
	STOP_PROCESSING(SSfastprocess, src)
	QDEL_NULL(work_beam)
	QDEL_NULL(work_effect)
	return ..()

/obj/effect/checkpoint_build_drone/proc/home_turf()
	var/obj/structure/checkpoint_drone_bay/cradle = cradle_ref?.resolve()
	return cradle ? get_turf(cradle) : null

/// Released by the job: fly back to the drone bay and dock, or give up after a while.
/obj/effect/checkpoint_build_drone/proc/return_home()
	finish_work()
	returning_until = world.time + 30 SECONDS
	START_PROCESSING(SSfastprocess, src)

/obj/effect/checkpoint_build_drone/process(seconds_per_tick)
	var/turf/home = home_turf()
	if(!home || world.time > returning_until)
		qdel(src)
		return PROCESS_KILL
	if(!fly_towards(home))
		return
	var/obj/structure/checkpoint_drone_bay/cradle = cradle_ref.resolve()
	cradle.receive()
	qdel(src)
	return PROCESS_KILL

/// Glides a few tiles towards the destination. Returns TRUE once alongside it.
/obj/effect/checkpoint_build_drone/proc/fly_towards(turf/destination)
	var/turf/start = get_turf(src)
	if(!destination || !start)
		return FALSE
	if(start.z != destination.z)
		forceMove(destination)
		return TRUE
	if(get_dist(start, destination) <= 1)
		return TRUE
	var/turf/next = start
	for(var/i in 1 to CHECKPOINT_DRONE_TILES_PER_TICK)
		if(get_dist(next, destination) <= 1)
			break
		next = get_step_towards(next, destination)
	setDir(get_dir(start, next))
	forceMove(next)
	pixel_x = base_pixel_x + (start.x - next.x) * ICON_SIZE_X
	pixel_y = base_pixel_y + (start.y - next.y) * ICON_SIZE_Y
	animate(src, pixel_x = base_pixel_x, pixel_y = base_pixel_y, time = SSfastprocess.wait, flags = ANIMATION_PARALLEL)
	return get_dist(next, destination) <= 1

/// Projects the piece about to appear and points the work beam at it.
/obj/effect/checkpoint_build_drone/proc/start_work(turf/target, atom/preview)
	work_until = world.time + CHECKPOINT_BUILD_WORK_TIME
	setDir(get_dir(src, target) || dir)
	work_effect = new(target, CHECKPOINT_BUILD_WORK_TIME, preview)
	if(get_turf(src) != target)
		work_beam = Beam(work_effect, icon_state = "rped_upgrade", time = CHECKPOINT_BUILD_WORK_TIME + 1, maxdistance = 3)
	// Many drones work at once; a share of them is enough to fill the bay with noise.
	if(prob(40))
		playsound(target, pick(GLOB.checkpoint_drone_tool_sounds), 20, TRUE, pressure_affected = FALSE)

/// Clears the drone before its visit is placed, so a failed placement cannot strand it.
/obj/effect/checkpoint_build_drone/proc/finish_work()
	if(work_until && !QDELETED(work_effect) && prob(35))
		playsound(work_effect, 'sound/items/deconstruct.ogg', 25, TRUE, pressure_affected = FALSE)
	work_until = 0
	visit = null
	QDEL_NULL(work_beam)
	if(!QDELETED(work_effect))
		work_effect.end_animation()
	work_effect = null

/// The RCD construction animation over a translucent copy of the piece. Not interactive.
/obj/effect/constructing_effect/checkpoint
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	obj_flags = NONE

/obj/effect/constructing_effect/checkpoint/Initialize(mapload, work_time, atom/preview)
	. = ..(mapload, work_time, RCD_STRUCTURE, NONE)
	if(!preview)
		return
	var/mutable_appearance/hologram = new(preview)
	hologram.plane = FLOAT_PLANE
	hologram.layer = FLOAT_LAYER
	hologram.alpha = 110
	hologram.color = "#80dfff"
	underlays += hologram
