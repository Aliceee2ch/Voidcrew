// ===== OUTPOST PRISON: STUN TURRETS AND AMBIENCE (see outpost_prison_security.dm, outpost_prison_ambience.dm) =====
// Owner: XB. Values from extras-plan.md 4.2, 4.5 and 4.7. Turrets never raise pay and never
// touch a calm, threatening, wrecking or downed prisoner.

/// Credits per turret, charged before it spawns; refused if short, never debt
#define OUTPOST_PRISON_TURRET_COST 2000
/// Turrets a wing may have, counting every one it sold that still exists
#define OUTPOST_PRISON_TURRET_MAX 2
/// The laser line and beep before the first shot at a new target
#define OUTPOST_PRISON_TURRET_WARN_TIME (1.5 SECONDS)
/// A target is warned again (line, beep, "Step away.") at most this often
#define OUTPOST_PRISON_TURRET_REWARN_TIME (20 SECONDS)
/// Tiles it sees from its muzzle
#define OUTPOST_PRISON_TURRET_SCAN_RANGE 5
/// Deciseconds between shots
#define OUTPOST_PRISON_TURRET_SHOT_DELAY 20
/// Stamina per shot: four put a prisoner down (100 stamina)
#define OUTPOST_PRISON_TURRET_STAMINA 30
/// Tiles a shot flies
#define OUTPOST_PRISON_TURRET_BEAM_RANGE 7
/// Health, the share of it left when it breaks, and creature swings that break it: 60 damage, six rioter smashes (PRISON_SMASH_DAMAGE)
#define OUTPOST_PRISON_TURRET_INTEGRITY 100
#define OUTPOST_PRISON_TURRET_FAILURE 0.4
#define OUTPOST_PRISON_TURRET_MOB_HITS 6
/// Idle draw on the wing APC's equipment channel
#define OUTPOST_PRISON_TURRET_IDLE_POWER (50 WATTS)
/// Percent chance someone watching comments on a hit, and the least time between those comments
#define OUTPOST_PRISON_TURRET_HIT_LINE_CHANCE 15
#define OUTPOST_PRISON_TURRET_HIT_LINE_GAP (20 SECONDS)
/// Least time between rioters shouting to go for a turret
#define OUTPOST_PRISON_TURRET_SMASH_LINE_GAP (10 SECONDS)

// ----- the yard notices you (4.5) -----

/// A member coming into the cell block turns heads at most this often
#define OUTPOST_PRISON_NOTICE_GAP (60 SECONDS)
/// Each prisoner reacts to a newcomer at most this often
#define OUTPOST_PRISONER_NOTICE_COOLDOWN (3 MINUTES)
/// How far a prisoner looks for the newcomer
#define OUTPOST_PRISONER_NOTICE_RANGE 7
/// At or above this mood (or for a "fair" member) they greet or nod; below the stare line (or for a "brute") they stare
#define OUTPOST_PRISONER_NOTICE_GREET_MOOD 75
#define OUTPOST_PRISONER_NOTICE_STARE_MOOD 40
/// Percent chance a content prisoner says hello rather than nodding
#define OUTPOST_PRISONER_NOTICE_GREET_CHANCE 40
/// A stare keeps them quiet this long
#define OUTPOST_PRISONER_NOTICE_STARE_HUSH (20 SECONDS)
/// A running chat pauses this long while they look over
#define OUTPOST_PRISONER_NOTICE_CHAT_PAUSE (5 SECONDS)
/// Per notice: one spoken line and this many nods, waves and stares; the rest only turn their heads
#define OUTPOST_PRISON_NOTICE_MAX_EMOTES 2

// ----- examining a prisoner (4.5) -----

/// Examine says they are due out with less than this many seconds of sentence left
#define OUTPOST_PRISONER_EXAMINE_DUE_OUT 90
/// examine_more() rounds the sentence left to this many minutes; under it, "a few minutes"
#define OUTPOST_PRISONER_EXAMINE_ROUND_MINUTES 5

// ----- sulking and humming (4.5) -----

/// Sulking: leisure weight, only below this mood
#define OUTPOST_PRISONER_SULK_WEIGHT 4
#define OUTPOST_PRISONER_SULK_MOOD 45
/// No other prisoner within this many tiles of the spot
#define OUTPOST_PRISONER_SULK_ALONE_RANGE 2
/// Humming: at or above this mood, about once a minute (chance per second is 1 in this), at most once per cooldown
#define OUTPOST_PRISONER_HUM_MOOD 75
#define OUTPOST_PRISONER_HUM_ONE_IN 60
#define OUTPOST_PRISONER_HUM_COOLDOWN (3 MINUTES)

// ----- a riot you hear coming (4.7) -----

/// Gathered prisoners whisper at most this often each, with this percent chance a second once free
#define OUTPOST_PRISONER_HUDDLE_GAP (20 SECONDS)
#define OUTPOST_PRISONER_HUDDLE_CHANCE 10
/// Seconds between chant beats; the last OUTPOST_PRISON_CHANT_LATE_WINDOW seconds of the riot hold beat every second
#define OUTPOST_PRISON_CHANT_GAP 2
#define OUTPOST_PRISON_CHANT_GAP_LATE 1
#define OUTPOST_PRISON_CHANT_LATE_WINDOW 10
/// Prisoners slamming a table or door on each beat, and every how many beats one of them shouts
#define OUTPOST_PRISON_CHANT_SLAMMERS 2
#define OUTPOST_PRISON_CHANT_LINE_EVERY 3
/// The slam: quiet and short range, so it is heard from the office but not across the outpost
#define OUTPOST_PRISON_CHANT_VOLUME 35
#define OUTPOST_PRISON_CHANT_RANGE -3
/// Rioters roaring when a riot starts, at most
#define OUTPOST_PRISON_ROAR_MAX 4
