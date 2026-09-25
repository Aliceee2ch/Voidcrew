// ===== OUTPOST PRISON: TROUBLE (see outpost_prison_trouble.dm and outpost_prison_riot.dm) =====
// Mood runs 0-100 per prisoner. Each minute it drifts by the sum of the rates that apply (needs in
// outpost_prison_needs.dm, the wing in outpost_prison_conditions.dm, the rest below); personality
// scales the losses (grumpy x1.4, nervous x1.2, chatty x1, quiet x0.9, cheerful x0.7).
// Tension = 100 - the mean mood of the prisoners in the cell block, plus event spikes that decay.
// Trouble comes from neglect: a well kept wing sees no fights or riots, a sloppy one hears the odd
// argument, a neglected one riots. Every step shows before it hurts, and the clocks that decide
// how bad it gets (the riot's breakout, a wreck's sheared bolts) wait for the crew to be home.

/// Mood a prisoner arrives with in a content wing, and the mood an admin calm resets everyone to
#define PRISONER_MOOD_START 70
/// Share of the gap between the yard's mean mood and PRISONER_MOOD_START an arrival takes on
#define PRISONER_ARRIVAL_PULL 0.3
/// Seconds bolted into a cell before a prisoner starts calling out about it
#define OUTPOST_PRISON_LOCKED_IN_COMPLAINT 120
/// Mood lost per minute bolted into a cell past OUTPOST_PRISON_LOCKED_IN_COMPLAINT, plus 1 per extra minute
#define PRISONER_MOOD_LOCKED_IN 6
/// Seconds the confinement clock falls per second out of the cell, so a moment's unbolting does not reset it
#define PRISONER_LOCKED_IN_RECOVERY 2
/// Mood gained when let out after a lock-in of OUTPOST_PRISON_LOCKED_IN_COMPLAINT or more
#define PRISONER_MOOD_UNBOLTED 3
/// Mood gained per minute playing basketball, reading or chatting
#define PRISONER_MOOD_ACTIVITY 1
/// Mood gained per minute in the last PRISONER_RELEASE_SOON_TIME seconds of a sentence
#define PRISONER_MOOD_RELEASE_SOON 3
#define PRISONER_RELEASE_SOON_TIME 180
/// Mood lost at once when staff hit them unprovoked, when they see a fight start, and when staff beat them down
#define PRISONER_MOOD_HIT_BY_STAFF 15
#define PRISONER_MOOD_SAW_FIGHT 5
#define PRISONER_MOOD_BEATEN_BY_STAFF 10
/// One staff hit per this long counts: a subdual is one event, however many blows or shots it takes
#define PRISONER_STAFF_HIT_COOLDOWN (10 SECONDS)
/// Hitting back within this long after a prisoner struck you is justified, and costs no mood
#define PRISONER_PROVOKED_TIME (10 SECONDS)
/// Talking a prisoner down: mood gained, how often per prisoner, the least mood that listens, how long it takes
#define PRISONER_MOOD_TALK 8
#define PRISONER_TALK_COOLDOWN (3 MINUTES)
#define PRISONER_TALK_MIN_MOOD 10
#define PRISONER_TALK_TIME (3 SECONDS)
/// No threats at someone who fed, treated or clothed them this recently
#define PRISONER_HELPED_GRACE (20 SECONDS)

// Stages of the wing's tension. Each one shows before anything hurts.
/// Complaints, pacing, banging on doors
#define PRISON_TENSION_GRUMBLING 40
/// Shouting at staff, gathering in the yard; announced to the crew
#define PRISON_TENSION_RESTLESS 60
/// Held this high for PRISON_RIOT_HOLD seconds, the wing riots. The hold is announced as a riot brewing.
#define PRISON_TENSION_RIOT 75
#define PRISON_RIOT_HOLD 45
/// Tension a stage must fall below its line by before it drops, so stages do not flicker
#define PRISON_TENSION_HYSTERESIS 5
/// Least time between "restless" announcements
#define PRISON_RESTLESS_ANNOUNCE_GAP (5 MINUTES)
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
/// Brute damage of a punch at staff, and of a rioter's shiv (tg's shiv is force 8)
#define PRISONER_PUNCH_MIN 5
#define PRISONER_PUNCH_MAX 8
#define PRISONER_SHIV_MIN 7
#define PRISONER_SHIV_MAX 10

// Fights between prisoners: squabbles, not beatings
/// Two prisoners below this mood, within PRISONER_FIGHT_RANGE tiles, may fight
#define PRISONER_FIGHT_MOOD 40
#define PRISONER_FIGHT_RANGE 3
/// Every PRISONER_FIGHT_CHECK seconds one random pair of them has this percent chance to start one
#define PRISONER_FIGHT_CHECK 10
#define PRISONER_FIGHT_CHANCE 12
/// Chance multiplier when both are hungry or both were after the ball
#define PRISONER_FIGHT_CONTEST_MULT 2
/// Seconds of arguing before the first punch: time enough to walk over and talk them down
#define PRISONER_ARGUE_TIME 10
/// Seconds a fight can last before they give up on it
#define PRISONER_FIGHT_MAX_TIME 60
/// Seconds before a fighter will start another fight
#define PRISONER_FIGHT_COOLDOWN 300
/// Seconds between any two fights in the wing
#define PRISON_FIGHT_GAP 180
/// Brute of a blow in a fight between prisoners
#define PRISONER_FIGHT_HIT_MIN 3
#define PRISONER_FIGHT_HIT_MAX 6
/// Health percent at which a fighter yields, and seconds they stay down
#define PRISONER_FIGHT_YIELD 40
#define PRISONER_FIGHT_YIELD_TIME 20
/// Below this mood two prisoners near each other may argue without blows, at most once per PRISON_SPAT_GAP in the wing
#define PRISONER_SPAT_MOOD 75
#define PRISON_SPAT_GAP (4 MINUTES)
/// Percent chance per fight check that such a pair starts arguing
#define PRISON_SPAT_CHANCE 8

// Beaten down
/// At or below this health percent a prisoner collapses
#define PRISONER_BEATEN_BELOW 15
/// Seconds they lie beaten, unless treated above PRISONER_RECOVER_ABOVE percent first
#define PRISONER_BEATEN_TIME 120
#define PRISONER_RECOVER_ABOVE 40

// Riots
/// Below these moods each personality joins a riot; if nobody does, the unhappiest starts it alone.
/// Nervous and cheerful prisoners mostly sit it out in their cells.
#define PRISON_RIOT_JOIN_GRUMPY 55
#define PRISON_RIOT_JOIN_CHATTY 50
#define PRISON_RIOT_JOIN_QUIET 45
#define PRISON_RIOT_JOIN_CHEERFUL 40
#define PRISON_RIOT_JOIN_NERVOUS 30
/// Seconds of shivs out and shouting before a riot's first blow
#define PRISON_RIOT_WINDUP 5
/// Most rioters that go for one member of staff at once; the rest smash
#define PRISON_RIOT_MAX_ATTACKERS 2
/// A baton hit stops a rioter's blows for this long
#define PRISONER_BATON_STOP (2 SECONDS)
/// Seconds of riot, counted only while the crew is home, before the rioters go all out for the exits
#define PRISON_RIOT_BREAKOUT_TIME 180
/// Seconds of riot before the crew is told the rioters are at the doors
#define PRISON_RIOT_BREAKOUT_WARNING 120
/// Seconds of sit-in (no crew home, or no rioter free) before the corrections service transfers the rioters still at large
#define PRISON_RIOT_TRANSFER_TIME 600
/// Mood every rioter settles at when the riot is over: the riot vented it
#define PRISONER_RIOT_CALM_MOOD 50
/// After a riot: no riots or fights, no mood lost to the wing's state and half the rest, for this long
#define PRISON_SUBDUED_TIME (6 MINUTES)
/// Percent chance a rioter goes for an exit door instead of the wing's fixtures. Before the breakout doors are only banged on.
#define PRISON_RIOT_DOOR_CHANCE 25
/// Damage a rioter does to a fixture per blow, and to a door once breaking out
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
/// Seconds a breakout rioter or loose prisoner has before they are gone for good. Once started it
/// always runs, crew or no crew, walls or no walls.
#define OUTPOST_PRISON_LOOSE_TIME 300
/// Seconds left on that clock when the crew is told where they are
#define PRISON_LOOSE_PING_1 180
#define PRISON_LOOSE_PING_2 60
/// Mood of a recaptured prisoner
#define PRISONER_RECAPTURED_MOOD 35
/// Damage a loose prisoner does to doors and machines per blow (normal airlocks shrug off under 21)
#define PRISONER_LOOSE_OBJ_DAMAGE 25

// Lock-in
/// Confined this many seconds at mood PRISONER_WRECK_MOOD or less, a prisoner wrecks the cell; the bolts shear PRISONER_WRECK_TIME seconds later
#define PRISONER_WRECK_AFTER 360
#define PRISONER_WRECK_MOOD 10
#define PRISONER_WRECK_TIME 180

// Cuffs (outpost_prison_capture.dm)
/// Seconds cuffing takes: a prisoner who is down, and one on their feet and out of trouble
#define PRISONER_CUFF_TIME_DOWN (2 SECONDS)
#define PRISONER_CUFF_TIME_STANDING (4 SECONDS)
/// Seconds taking the cuffs off takes
#define PRISONER_UNCUFF_TIME (2 SECONDS)
/// Seconds cuffed without good reason before it starts to sour them and stop their pay
#define PRISONER_CUFFED_GRACE 90
/// Mood lost per minute cuffed past PRISONER_CUFFED_GRACE, plus 1 per extra minute
#define PRISONER_MOOD_CUFFED 6
/// Mood lost per minute for each prisoner's body lying in the cell block, up to PRISONER_MOOD_BODIES_MAX
#define PRISONER_MOOD_BODY 4
#define PRISONER_MOOD_BODIES_MAX 12

// Lockdown after a riot (outpost_prison_capture.dm)
/// Seconds a rioter shut in a cell, or a runner caught after a riot, must serve shut in a cell
#define PRISON_RIOT_LOCKDOWN_TIME 240
/// Seconds out of a cell, on their feet and uncuffed, before a prisoner who owes lockdown riots again
#define PRISON_LOCKDOWN_GRACE 30

// What trouble a prisoner is in (/mob/living/basic/outpost_prisoner/var/trouble); null is none
#define PRISONER_TROUBLE_FIGHT "fight"
#define PRISONER_TROUBLE_RIOT "riot"
/// Rioting after the riot turned into a breakout: going for the exits
#define PRISONER_TROUBLE_BREAKOUT "breakout"
/// Out of the cell block, on the patrol AI
#define PRISONER_TROUBLE_LOOSE "loose"
/// Bolted in too long: wrecking the cell
#define PRISONER_TROUBLE_WRECK "wreck"

// The wing's stage (/datum/outpost_prison/var/stage)
#define PRISON_STAGE_CALM "calm"
#define PRISON_STAGE_GRUMBLING "grumbling"
#define PRISON_STAGE_RESTLESS "restless"
#define PRISON_STAGE_RIOT "riot"
