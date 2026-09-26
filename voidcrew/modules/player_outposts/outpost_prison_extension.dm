/**
 * # Cell block extension
 *
 * Three more cells, a bit more yard and a bit more office, bought from the upgrades catalog and snapped
 * onto a side wall of an outpost's prison wing (owner, 2026-09-25): up to OUTPOST_PRISON_MAX_EXTENSIONS,
 * on either side, for up to ten prisoners. Plan: data/outpost-resources/extension-plan.md.
 *
 * The extension's maps are authored with a seam column of template_noop over the wing's side wall, so
 * loading never touches the wing. Once loaded, its tiles join the wing's own area, its cells join the
 * prison and three declared seam tiles open into the wing.
 */

/// An extension's area while it loads. Its tiles then move into the wing's own area and this one is
/// deleted. A sibling of the prison wing's area, not a subtype, so nothing takes it for a wing meanwhile.
/area/voidcrew/player_outpost/prison_extension
	name = "\improper Prison Wing Extension"
	icon = 'icons/area/areas_station.dmi'
	icon_state = "sec_prison"
	sound_environment = SOUND_AREA_LARGE_ENCLOSED

/// Marks the bottom end of a wall that an extension may join, on the wall tile itself. The upgrade that
/// owns the wall reads these at install and deletes them.
/obj/effect/landmark/outpost_upgrade_snap
	name = "upgrade joint"
	/// Which upgrades may join here
	var/snap_group = "prison_cells"
	/// "right" or "left", the side of the room this wall is on as the room is authored
	var/side
	/// The rows along the wall, counted from this landmark's row as 1, that open once an extension joins
	var/list/seam_openings = list(3, 8, 10)

/// The room's east wall, as authored
/obj/effect/landmark/outpost_upgrade_snap/right
	side = "right"
	dir = EAST

/// The room's west wall, as authored
/obj/effect/landmark/outpost_upgrade_snap/left
	side = "left"
	dir = WEST

/obj/machinery/door/airlock/security/glass/outpost_prison_cell
	/// On an extension's map, which of its cells this is (1-3). It becomes a cell number once the extension joins.
	var/extension_slot = 0

/obj/machinery/button/outpost_prison_bolt
	/// On an extension's map, which of its cells this bolts (1-3). It becomes a cell number once the extension joins.
	var/extension_slot = 0
