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

/// New ships built to order in the ship bay (outpost_ship_orders.dm). Credits replace parts:
/// every part a hull, theme or module would cost in the lobby shipyard is this many credits.
#define OUTPOST_SHIP_ORDER_PART_PRICE 2500
/// Charged on every order, on top of the hull's parts.
#define OUTPOST_SHIP_ORDER_FEE 10000

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
/// Tiles a drone crosses in one hop.
#define CHECKPOINT_DRONE_TILES_PER_TICK 3
/// How often a drone makes that hop. The glide between hops takes the same time.
#define CHECKPOINT_DRONE_FLIGHT_INTERVAL (0.4 SECONDS)
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

// ===== OUTPOST UPGRADES (see outpost_upgrades.dm) =====
/// Treasury price of the prison wing upgrade
#define OUTPOST_PRISON_COST 12000
/// A placed upgrade needs a tile within this many tiles (Chebyshev) of outpost ground
#define OUTPOST_UPGRADE_MAX_GAP 8
/// How long a placement-map survey is reused before it is taken again
#define OUTPOST_UPGRADE_SURVEY_LIFETIME (30 SECONDS)

// ===== OUTPOST PRISON (see outpost_prison_*.dm) =====
// Pay model. Every minute each prisoner in the wing pays the treasury
//   OUTPOST_PRISON_BASE_PAY x care x conditions
// where care = mean(fed, clean uniform, health) and conditions = mean(clean floor, lit, powered),
// both as fractions of 100%. Fed and clean count as 100% until the prisoner is hungry or their
// uniform is dirty, then fall in a straight line to 0% at empty or at full grime.
// A release pays OUTPOST_PRISON_RELEASE_BONUS x (care x conditions, averaged over the sentence).
// One cell turns over every ~13 minutes at perfect care: an 11.5 minute average sentence, then a
// 60-120 second refill. Four cells: 4 x 20 cr/min x 11.5 / 13 = ~4,250 cr/h in stipends, plus
// 4 x 60 / 13 = ~18.5 releases/h x 200 = ~3,700 cr/h in bonuses. Ceiling ~7,900 cr/h, so the
// 12,000 cr wing pays for itself in about 1.5 hours of perfect care.
/// Prisoners the wing holds at once: one per cell
#define OUTPOST_PRISON_CAPACITY 4
/// Treasury credits per minute per prisoner at perfect care and conditions
#define OUTPOST_PRISON_BASE_PAY 20
/// Treasury credits for a release at perfect care and conditions
#define OUTPOST_PRISON_RELEASE_BONUS 200
/// What the office ration dispenser charges the treasury per meal
#define OUTPOST_PRISON_RATION_COST 40
/// Sentence range, in seconds
#define OUTPOST_PRISON_SENTENCE_MIN (8 * 60)
#define OUTPOST_PRISON_SENTENCE_MAX (15 * 60)
/// Seconds from opening intake to the first arrival
#define OUTPOST_PRISON_FIRST_ARRIVAL 5
/// Seconds between arrivals while cells are free
#define OUTPOST_PRISON_ARRIVAL_GAP_MIN 20
#define OUTPOST_PRISON_ARRIVAL_GAP_MAX 40
/// Seconds before a freed cell is filled again
#define OUTPOST_PRISON_REFILL_MIN 60
#define OUTPOST_PRISON_REFILL_MAX 120
/// Seconds of sentence left when a prisoner heads back to their cell to be beamed out
#define OUTPOST_PRISON_RELEASE_WALK 30
/// How long a transporter beam takes to deliver or collect a prisoner (deciseconds)
#define OUTPOST_PRISON_BEAM_TIME (3 SECONDS)
/// Seconds a body lies in the wing before it is collected
#define OUTPOST_PRISON_CORPSE_PICKUP 120
/// Cleanliness lost per cleanable decal or piece of trash in the wing
#define OUTPOST_PRISON_MESS_PENALTY 5
/// Percent chance per minute that a prisoner drops some mess
#define OUTPOST_PRISON_MESS_CHANCE 10
/// Log entries the warden console keeps
#define OUTPOST_PRISON_LOG_LENGTH 8
/// Seconds bolted into a cell before a prisoner starts calling out about it
#define OUTPOST_PRISON_LOCKED_IN_COMPLAINT 120

// Prisoner needs, on 0-100 scales.
/// Hunger lost per minute: full to empty in 10 minutes, so an 8-15 minute stay needs a meal or two
#define PRISONER_HUNGER_DECAY 10
/// Hunger any one piece of food restores
#define PRISONER_FOOD_VALUE 50
/// Below this a prisoner goes looking for food
#define PRISONER_HUNGER_SEEK 50
/// At or above this a prisoner refuses food
#define PRISONER_HUNGER_FULL 90
#define PRISONER_HUNGER_HUNGRY 40
#define PRISONER_HUNGER_STARVING 15
/// Uniform grime gained per minute: clean to filthy-through in 12 minutes (dirty at 6), about one change a stay
#define PRISONER_GRIME_RATE (100 / 12)
#define PRISONER_GRIME_DIRTY 50
#define PRISONER_GRIME_FILTHY 80
/// Below this health percent a prisoner shows the hurt bubble and the roster calls them injured
#define PRISONER_INJURED_BELOW 90
/// Below this health percent an untreated prisoner leaves the odd drip of blood
#define PRISONER_BLEED_BELOW 50
/// How long stamina crit holds after the last stamina hit, long enough to drag one to a cell
#define PRISONER_STAMCRIT_TIME (20 SECONDS)

// Where a prisoner is in their stay (/mob/living/basic/outpost_prisoner/var/phase)
/// Being beamed into their cell
#define PRISONER_ARRIVING "arriving"
/// In the wing, serving their sentence
#define PRISONER_PRESENT "present"
/// Being beamed out, released or collected
#define PRISONER_LEAVING "leaving"

// What /mob/living/basic/outpost_prisoner/proc/try_reach() found
#define PRISONER_REACH_FAILED 0
#define PRISONER_REACH_OK 1
/// Their side of a serving hatch is opening
#define PRISONER_REACH_WAIT 2
/// Pause between spontaneous prisoner lines anywhere in one wing (deciseconds)
#define OUTPOST_PRISON_SPEECH_GAP (6 SECONDS)

// ===== PRISON TROUBLE (see outpost_prison_trouble.dm and outpost_prison_riot.dm) =====
// Mood runs 0-100 per prisoner. Each minute it drifts by the sum of the rates below that apply;
// personality scales the losses (grumpy x1.4, nervous x1.2, chatty x1, quiet x0.9, cheerful x0.7).
// Tension = 100 - the mean mood of the prisoners in the cell block, plus event spikes that decay.
/// Mood a prisoner arrives with, and the mood an admin calm resets everyone to
#define PRISONER_MOOD_START 70
/// Mood lost per minute while hungry, or instead while starving
#define PRISONER_MOOD_HUNGRY 3
#define PRISONER_MOOD_STARVING 8
/// Mood lost per minute in a dirty uniform, or instead a filthy one
#define PRISONER_MOOD_DIRTY 2
#define PRISONER_MOOD_FILTHY 5
/// Mood lost per minute with no health left, scaled by the missing fraction (4 x missing x 2)
#define PRISONER_MOOD_HURT 8
/// Mood lost per minute in a dark wing, a dirty wing and an unpowered wing
#define PRISONER_MOOD_DARK 4
#define PRISONER_MOOD_DIRTY_WING 3
#define PRISONER_MOOD_NO_POWER 5
/// The wing is dark below this lit score, and dirty below this clean score
#define PRISON_DARK_BELOW 50
#define PRISON_DIRTY_BELOW 60
/// Mood lost per minute bolted into a cell past OUTPOST_PRISON_LOCKED_IN_COMPLAINT, plus 1 per extra minute
#define PRISONER_MOOD_LOCKED_IN 6
/// Mood gained per minute while every condition score is at least PRISON_GOOD_CONDITIONS
#define PRISONER_MOOD_GOOD_WING 2
#define PRISON_GOOD_CONDITIONS 80
/// Mood gained per minute playing basketball, reading or chatting
#define PRISONER_MOOD_ACTIVITY 1
/// Mood gained per minute in the last PRISONER_RELEASE_SOON_TIME seconds of a sentence
#define PRISONER_MOOD_RELEASE_SOON 3
#define PRISONER_RELEASE_SOON_TIME 180
/// Mood gained at once from a meal, a clean uniform and treatment
#define PRISONER_MOOD_FED 10
#define PRISONER_MOOD_CLEAN_UNIFORM 8
#define PRISONER_MOOD_TREATED 8
/// Mood lost at once when staff hit them, when they see a fight start, and when staff beat them down
#define PRISONER_MOOD_HIT_BY_STAFF 15
#define PRISONER_MOOD_SAW_FIGHT 5
#define PRISONER_MOOD_BEATEN_BY_STAFF 10

// Stages of the wing's tension. Each one shows before anything hurts.
/// Complaints, pacing, banging on doors
#define PRISON_TENSION_GRUMBLING 40
/// Shouting at staff, gathering in the yard
#define PRISON_TENSION_RESTLESS 60
/// Held this high for PRISON_RIOT_HOLD seconds, the wing riots
#define PRISON_TENSION_RIOT 80
#define PRISON_RIOT_HOLD 30
/// Tension an event spike loses per second: a 30 point spike is gone in 2 minutes
#define PRISON_SPIKE_DECAY 0.25
/// Tension added by events. The last four are also sparks: while restless, any of them starts a riot.
#define PRISON_SPIKE_STAFF_HIT 5
#define PRISON_SPIKE_FIGHT 10
#define PRISON_SPIKE_POWER_CUT 10
#define PRISON_SPIKE_LIGHTS_OUT 10
#define PRISON_SPIKE_BEATEN 20
#define PRISON_SPIKE_KILLED 30

// Threats and swings at staff inside the cell block
/// Below this mood a prisoner squares up to staff within PRISONER_THREAT_RANGE tiles; at or above, never
#define PRISONER_THREAT_MOOD 35
/// Below this mood a threat turns into a swing more often
#define PRISONER_THREAT_ANGRY_MOOD 20
#define PRISONER_THREAT_RANGE 2
/// Seconds a threat lasts before they decide whether to swing
#define PRISONER_THREAT_TIME 4
/// Percent chance the threat ends in a swing, normally and when angry
#define PRISONER_SWING_CHANCE 30
#define PRISONER_SWING_CHANCE_ANGRY 60
/// Seconds before they threaten anyone again
#define PRISONER_THREAT_COOLDOWN 20
/// Seconds a decided swing waits for them to close in before it is dropped
#define PRISONER_SWING_TIMEOUT 6
/// Brute damage of a punch, and of a shiv
#define PRISONER_PUNCH_MIN 5
#define PRISONER_PUNCH_MAX 8
#define PRISONER_SHIV_MIN 10
#define PRISONER_SHIV_MAX 15

// Fights between prisoners
/// Two prisoners below this mood, within PRISONER_FIGHT_RANGE tiles, may fight
#define PRISONER_FIGHT_MOOD 30
#define PRISONER_FIGHT_RANGE 3
/// Every PRISONER_FIGHT_CHECK seconds each such pair has this percent chance to start one
#define PRISONER_FIGHT_CHECK 10
#define PRISONER_FIGHT_CHANCE 25
/// Seconds of arguing before the first punch
#define PRISONER_ARGUE_TIME 8
/// Seconds a fight can last before they give up on it
#define PRISONER_FIGHT_MAX_TIME 90
/// Seconds before a fighter will start another fight
#define PRISONER_FIGHT_COOLDOWN 180

// Beaten down
/// At or below this health percent a prisoner collapses
#define PRISONER_BEATEN_BELOW 15
/// Seconds they lie beaten, unless treated above PRISONER_RECOVER_ABOVE percent first
#define PRISONER_BEATEN_TIME 120
#define PRISONER_RECOVER_ABOVE 40

// Riots
/// Prisoners below this mood join a riot; if none is, the unhappiest one starts it alone
#define PRISON_RIOT_JOIN_MOOD 50
/// Seconds an unresolved riot lasts before the rioters go all out for the exits
#define PRISON_RIOT_BREAKOUT_TIME 180
/// Mood of a rioter who is stunned or beaten and calms down
#define PRISONER_RIOT_CALM_MOOD 40
/// Percent chance a rioter goes for an exit door instead of the wing's fixtures, before the breakout
#define PRISON_RIOT_DOOR_CHANCE 25
/// Damage a rioter does to a fixture or door per blow
#define PRISON_SMASH_DAMAGE 10
/// Blows that force a serving hatch's window doors open
#define PRISON_HATCH_FORCE_HITS 12
/// Blows a rioter spends on one fixture before moving on to another
#define PRISON_RIOT_TARGET_HITS 6
/// Seconds between riot alarms in the wing
#define PRISON_RIOT_ALARM_GAP 20
/// The red strobe: seconds per half cycle, and the light power of its dim half
#define PRISON_STROBE_INTERVAL (0.5 SECONDS)
#define PRISON_STROBE_DIM 0.25

// Escapes
/// Below this mood a prisoner climbs over a serving hatch left open on both sides
#define PRISONER_CLIMB_MOOD 50
/// Seconds the climb takes
#define PRISONER_CLIMB_TIME 3
/// Seconds an escaped prisoner stays loose before they are gone for good
#define OUTPOST_PRISON_LOOSE_TIME 300
/// What the treasury is fined for a prisoner gone for good (as much of it as the treasury holds)
#define OUTPOST_PRISON_ESCAPE_FINE 1000
/// Mood of a recaptured prisoner
#define PRISONER_RECAPTURED_MOOD 25
/// Damage a loose prisoner does to doors and machines per blow (normal airlocks shrug off under 21)
#define PRISONER_LOOSE_OBJ_DAMAGE 25

// What trouble a prisoner is in (/mob/living/basic/outpost_prisoner/var/trouble); null is none
#define PRISONER_TROUBLE_FIGHT "fight"
#define PRISONER_TROUBLE_RIOT "riot"
/// Rioting after the riot turned into a breakout: going for the exits
#define PRISONER_TROUBLE_BREAKOUT "breakout"
/// Out of the cell block, on the patrol AI
#define PRISONER_TROUBLE_LOOSE "loose"

// The wing's stage (/datum/outpost_prison/var/stage)
#define PRISON_STAGE_CALM "calm"
#define PRISON_STAGE_GRUMBLING "grumbling"
#define PRISON_STAGE_RESTLESS "restless"
#define PRISON_STAGE_RIOT "riot"
