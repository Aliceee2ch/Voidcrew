/**
 * # Derelict outpost
 *
 * Owner: P1 (after the seams commit). One per round: an unclaimed player outpost that sits on the chart as an
 * unknown signal and builds the first time a ship docks (dark, dressed, with a prison wing and hostiles).
 * Claimed at its console like any unowned outpost; after that an ordinary player outpost.
 */
/obj/structure/overmap/dynamic/player_outpost/derelict
	name = "unknown signal"
	desc = "A faint signal of unknown origin. Survey to learn more."
	icon_state = "strange_event"
	sensor_category = "Ruins"
	/// DERELICT_STATE_*; only this file writes it
	var/derelict_state = DERELICT_STATE_DORMANT
	/// The name it answers to once found, from GLOB.derelict_outpost_names
	var/true_name
	/// DERELICT_THEME_*
	var/theme_id
	/// ZONE_YELLOW or ZONE_RED: the band it spawned in
	var/derelict_band = ZONE_YELLOW
	/// The shell it is built from
	var/datum/map_template/player_outpost/derelict_shell_type
	/// Weakrefs to every hostile the theme spawned (derelict_themes.dm writes; everyone else reads)
	var/list/datum/weakref/derelict_hostiles = list()
	/// Where the fuel was left (derelict_layout.dm writes)
	var/list/turf/derelict_fuel_spots = list()
	/// Weakref to the shell airlock the prison wing's door was joined to; null when it was not joined (derelict_layout.dm writes)
	var/datum/weakref/derelict_prison_airlock
	/// Tests set this to build without a theme
	var/derelict_skip_theme = FALSE

/obj/structure/overmap/dynamic/player_outpost/derelict/Initialize(mapload)
	. = ..()
	if(!GLOB.derelict_outpost)
		GLOB.derelict_outpost = src

/obj/structure/overmap/dynamic/player_outpost/derelict/Destroy()
	if(GLOB.derelict_outpost == src)
		GLOB.derelict_outpost = null
	derelict_hostiles.Cut()
	derelict_fuel_spots.Cut()
	derelict_prison_airlock = null
	return ..()

/// Picks what this derelict is: its shell, theme, band and the name it answers to once found
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/setup_derelict(shell_type, theme, band)
	derelict_shell_type = shell_type
	theme_id = theme
	derelict_band = band
	true_name = pick(GLOB.derelict_outpost_names)

/**
 * Builds the derelict now: the level and shell, the prison wing, dead power, the theme.
 * Returns TRUE when it stands built. P1 adds the load-finished signal, the watchdog and the capacity retry.
 */
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/build_derelict(obj/structure/overmap/ship/waiting_ship)
	if(derelict_state != DERELICT_STATE_DORMANT)
		return is_loaded()
	derelict_state = DERELICT_STATE_BUILDING
	name = true_name
	display_name = true_name
	shell_template = new derelict_shell_type
	founded_zone = derelict_band
	resident_mode = "closed"
	if(!load_level())
		shell_template = null
		name = initial(name)
		display_name = name
		derelict_state = DERELICT_STATE_DORMANT
		return FALSE
	place_derelict_prison()
	drain_derelict_power()
	if(!derelict_skip_theme)
		apply_derelict_theme()
	set_derelict_ambience(TRUE)
	derelict_state = DERELICT_STATE_READY
	return TRUE

/obj/structure/overmap/dynamic/player_outpost/derelict/is_loaded()
	return loaded && (derelict_state == DERELICT_STATE_READY || derelict_state == DERELICT_STATE_CLAIMED)

/obj/structure/overmap/dynamic/player_outpost/derelict/is_loading()
	return derelict_state == DERELICT_STATE_BUILDING

/// Called when the derelict is claimed for the first time (P1)
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/on_derelict_claimed(mob/living/new_owner, mob/user)
	derelict_state = DERELICT_STATE_CLAIMED

/// Places this round's derelict on an empty yellow or red tile, if there is none yet. Returns it, or null. (P1)
/datum/controller/subsystem/overmap/proc/spawn_derelict_outpost(theme, shell_type, band)
	return null
