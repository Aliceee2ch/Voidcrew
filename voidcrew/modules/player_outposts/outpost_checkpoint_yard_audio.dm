/// Ship bay audio. Everyone inside a bay, docked ships included, hears the yard as their ambience.
/// Drone launch and dock sounds play once to the whole bay, at the same volume wherever they stand.

#define CHECKPOINT_YARD_LOOP 'voidcrew/sound/checkpoint/construction_yard_loop.ogg'
#define CHECKPOINT_YARD_LOOP_VOLUME 45
#define CHECKPOINT_YARD_ONESHOT_VOLUME 50

/// Whether this tile is inside a ship bay.
/proc/checkpoint_yard_noise_at(turf/tile)
	if(!tile)
		return FALSE
	for(var/obj/structure/overmap/dynamic/player_outpost/outpost as anything in GLOB.player_outposts)
		for(var/datum/outpost_berth/ship_bay/bay as anything in outpost.bay_berths)
			if(!QDELETED(bay?.reservation) && bay.reservation.contains_turf(tile))
				return TRUE
	return FALSE

/proc/checkpoint_yard_listeners(datum/turf_reservation/yard)
	. = list()
	if(QDELETED(yard))
		return
	for(var/mob/listener as anything in GLOB.player_list)
		if(listener.client && yard.contains_turf(get_turf(listener)))
			. += listener

/proc/play_to_checkpoint_yard(datum/turf_reservation/yard, sound_file)
	for(var/mob/listener as anything in checkpoint_yard_listeners(yard))
		listener.playsound_local(null, sound_file, CHECKPOINT_YARD_ONESHOT_VOLUME)

/// Inside a ship bay the yard replaces the area's hum. The client repeats it, so the loop is seamless.
/mob/refresh_looping_ambience()
	if(!client || isobserver(client.mob) || !can_hear() || !checkpoint_yard_noise_at(get_turf(src)))
		return ..()
	var/volume_modifier = client.prefs.read_preference(/datum/preference/numeric/volume/sound_ship_ambience_volume)
	if(!volume_modifier)
		return ..()
	if(client.current_ambient_sound == CHECKPOINT_YARD_LOOP)
		return
	client.current_ambient_sound = CHECKPOINT_YARD_LOOP
	stop_sound_channel(CHANNEL_AMBIENCE)
	SEND_SOUND(src, sound(CHECKPOINT_YARD_LOOP, repeat = 1, wait = 0, volume = CHECKPOINT_YARD_LOOP_VOLUME * (volume_modifier / 100), channel = CHANNEL_BUZZ))

/// Docking or leaving moves the crew without changing their area, so check the ambience again.
/mob/afterShuttleMove(turf/oldT, list/movement_force, shuttle_dir, shuttle_preferred_direction, move_dir, rotation)
	. = ..()
	if(client)
		refresh_looping_ambience()

/// No other ambience plays over the yard.
/area/play_ambience(mob/M, sound/override_sound, volume = 27)
	if(checkpoint_yard_noise_at(get_turf(M)))
		return 10 SECONDS
	return ..()

#undef CHECKPOINT_YARD_LOOP
#undef CHECKPOINT_YARD_LOOP_VOLUME
#undef CHECKPOINT_YARD_ONESHOT_VOLUME
