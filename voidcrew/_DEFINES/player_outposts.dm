// Player-built custom outposts

/// Credit cost of a first-time outpost deed at a trader outpost
#define OUTPOST_DEED_COST_CREDITS 10000
/// Trade voucher cost of a first-time outpost deed
#define OUTPOST_DEED_COST_VOUCHERS 3

/// Hard cap on shell template dimensions
#define PLAYER_OUTPOST_MAX_SHELL_SIZE 40
/// How often the outpost sweeps its build region to adopt hand-built
/// structures into its powered area (drone builds adopt instantly)
#define PLAYER_OUTPOST_AREA_SWEEP_INTERVAL (30 SECONDS)

/// Cooldown between outpost renames
#define PLAYER_OUTPOST_RENAME_COOLDOWN (5 MINUTES)
/// Maximum length of the outpost memo/description
#define PLAYER_OUTPOST_MEMO_MAX_LEN 256

/// Credit cost of one galaxy-wide advertisement
#define OUTPOST_ADVERT_COST 2500
/// How long a purchased advertisement stays live
#define OUTPOST_ADVERT_DURATION (20 MINUTES)
/// Minimum time between advertisement purchases per outpost
#define OUTPOST_ADVERT_COOLDOWN (10 MINUTES)

/// Anyone may dock without asking
#define OUTPOST_DOCK_MODE_OPEN "open"
/// Docking requires owner approval per ship
#define OUTPOST_DOCK_MODE_REQUEST "request"
/// Only the owner's crew may dock
#define OUTPOST_DOCK_MODE_LOCKDOWN "lockdown"
/// How long a pending docking request stays valid
#define OUTPOST_DOCK_REQUEST_TIMEOUT (2 MINUTES)

/// If defined, missile launchers may fire in the yellow zone when locked onto a raidable player outpost
#define PLAYER_OUTPOST_YELLOW_SIEGE_ENABLED

// ===== OUTPOST SHIELD GENERATOR (see outpost_shield.dm) =====
// A siege missile drains charge equal to its damage: light 200 / standard 400 / heavy 600.
// Base pool of 1000 therefore stops ~2 standard missiles before depleting.

/// Base shield charge pool of an outpost shield generator (before capacitor upgrades)
#define OUTPOST_SHIELD_BASE_CHARGE 1000
/// Capacitor: +50% max charge per tier above 1
#define OUTPOST_SHIELD_CAPACITOR_CHARGE_MULT 0.5
/// Charge drained per point of missile damage (1 = full damage value)
#define OUTPOST_SHIELD_MISSILE_DRAIN_MULT 1
/// Minimum charge drained per absorbed missile (chemical missiles list ~0 damage)
#define OUTPOST_SHIELD_MIN_DRAIN 100
/// Base recharge rate in charge per second (full base pool from empty in ~3m20s)
#define OUTPOST_SHIELD_BASE_RECHARGE 5
/// Micro-laser: +30% recharge rate per tier above 1
#define OUTPOST_SHIELD_LASER_RECHARGE_MULT 0.3
/// Recharging pauses for this long after every absorbed hit (shields don't heal under fire)
#define OUTPOST_SHIELD_RECHARGE_DELAY (10 SECONDS)
/// APC equipment-channel power draw while actively recharging (watts)
#define OUTPOST_SHIELD_CHARGE_POWER (10 KILO WATTS)
/// APC equipment-channel power draw while holding a charged/idle field (watts)
#define OUTPOST_SHIELD_IDLE_POWER (1 KILO WATTS)

/// One permanent construction bay per outpost.
#define OUTPOST_SHIP_BAY_SLOTS 1
#define OUTPOST_SHIP_BAY_COST 10000
#define OUTPOST_DOCK_VARIANT_BAY "ship_bay"

/// Round-local, prepaid hull recovery. A ship has at most one current registration.
#define OUTPOST_MAX_CHECKPOINTS 12
#define OUTPOST_CHECKPOINT_MAX_TEXT (1024 * 1024)
#define OUTPOST_CHECKPOINT_SAVE_COST 10000
#define OUTPOST_CHECKPOINT_UPDATE_COST 5000

// ===== STAGED CHECKPOINT RECONSTRUCTION (see outpost_checkpoint_construction.dm) =====
/// The saved ship is loaded and waiting for its survey markers.
#define CHECKPOINT_BUILD_PREPARING "preparing"
/// Warning markers are down; no recoverable piece exists yet.
#define CHECKPOINT_BUILD_MARKING "marking"
/// Pieces are being placed one visit at a time.
#define CHECKPOINT_BUILD_BUILDING "building"
/// Every visit has run; the hull is waiting for its captain and handover.
#define CHECKPOINT_BUILD_COMMISSIONING "commissioning"
#define CHECKPOINT_BUILD_COMPLETE "complete"
#define CHECKPOINT_BUILD_FAILED "failed"

/// Build stages, in order. Each stage finishes before the next begins.
#define CHECKPOINT_STAGE_DECK 1
#define CHECKPOINT_STAGE_HULL 2
#define CHECKPOINT_STAGE_SYSTEMS 3
#define CHECKPOINT_STAGE_MACHINERY 4
#define CHECKPOINT_STAGE_FITTINGS 5
#define CHECKPOINT_STAGE_COUNT 5

/// How long the survey markers show before the first drone starts work.
#define CHECKPOINT_BUILD_SURVEY_TIME (4 SECONDS)
/// Time a drone spends on one tile before its pieces appear.
#define CHECKPOINT_BUILD_WORK_TIME (0.4 SECONDS)
/// Played once to everyone in the bay when the drones leave, and when the last one docks.
#define CHECKPOINT_YARD_LAUNCH_SOUND 'voidcrew/sound/checkpoint/drone_launch.ogg'
#define CHECKPOINT_YARD_DOCK_SOUND 'voidcrew/sound/checkpoint/drone_dock.ogg'
#define CHECKPOINT_BUILD_MIN_DRONES 8
#define CHECKPOINT_BUILD_MAX_DRONES 16
/// Tiles a drone crosses per controller tick (SSfastprocess, 0.2 seconds).
#define CHECKPOINT_DRONE_TILES_PER_TICK 3
/// Roughly one extra drone per this many visits, between the limits above.
#define CHECKPOINT_BUILD_VISITS_PER_DRONE 100
/// Upper bound on tile visits completed in one controller tick, across all drones.
#define CHECKPOINT_BUILD_VISIT_BUDGET 8
/// Visits per tick when an admin rushes a build (a few seconds for a Box-class hull).
#define CHECKPOINT_BUILD_RUSH_BUDGET 40
/// Ambient light on a hull while it is built, matching the hangar floodlights.
#define CHECKPOINT_BUILD_FLOODLIGHT_ALPHA 110
#define CHECKPOINT_BUILD_FLOODLIGHT_COLOR "#d5e3ff"
/// A build that stops advancing for this long is finished with the pieces it has.
#define CHECKPOINT_BUILD_STALL_TIME (1 MINUTES)
/// How long a finished hull waits for its captain before being left claimable.
#define CHECKPOINT_BUILD_CAPTAIN_WAIT (10 MINUTES)
