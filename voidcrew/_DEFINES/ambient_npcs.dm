// # World population: ambient NPCs (voidcrew/modules/ambient_npcs/)
//
// Owner: P0 seams (frozen). Every package (PA outposts, PB planets, PC strays, PD recruiters) reads
// these; none redefines them. Change this file only through the integration lead. A package keeps
// its own local numbers as #defines at the top of its own file, #undef'd at the bottom.
//
// Unit tests compile before voidcrew/_DEFINES and cannot see these: use the literal value in a
// test, with a comment naming the define.

/// Other code can test for the ambient NPC core with #ifdef. Keep it defined.
#define AMBIENT_NPCS_API

/// Trait source for everything the core puts on an ambient NPC
#define AMBIENT_NPC_TRAIT "ambient_npc"

// ===== SUBSYSTEM =====

/// SSambient_npcs ticks this often
#define AMBIENT_SUBSYSTEM_WAIT (10 SECONDS)

// ===== TRADER OUTPOSTS (2.4) =====

/// Most transient NPCs at one trader outpost at once
#define AMBIENT_OUTPOST_TRANSIENT_CAP 10
/// The first arrivals step off the lift this long after the first player reaches the concourse
#define AMBIENT_OUTPOST_ARRIVAL_DELAY_LOW (30 SECONDS)
#define AMBIENT_OUTPOST_ARRIVAL_DELAY_HIGH (60 SECONDS)
/// Once nobody has been on the concourse this long, every transient NPC there is deleted
#define AMBIENT_OUTPOST_GRACE (3 MINUTES)
/// An outpost's public floor is worked out again this often while it is occupied
#define AMBIENT_OUTPOST_FLOOR_REFRESH (10 MINUTES)
/// NPCs this far from a fight at an outpost duck and leave
#define AMBIENT_VIOLENCE_RANGE 9

// ===== PLANETS AND FIELDS (2.4, 4.1) =====

/// Most NPC sites rolled on one planet
#define AMBIENT_PLANET_SITES_MAX 2
/// Most ambient NPCs alive on one planet at once (inside its fauna cap)
#define AMBIENT_PLANET_NPCS_MAX 6
/// Most NPC sites on one asteroid field
#define AMBIENT_FIELD_SITES_MAX 1
/// Rows a site keeps above the planet's dock strip (which already clears the berths by 10)
#define AMBIENT_SITE_DOCK_CLEARANCE 10
/// Tiles between two sites on one planet
#define AMBIENT_SITE_SPACING 15
/// Tiles a site keeps from the planet's edge
#define AMBIENT_SITE_EDGE_MARGIN 5
/// Random turfs tried when looking for a site's spot
#define AMBIENT_SITE_SPOT_TRIES 60
/// A planet NPC's health is scaled by band at the spawn site, never on the type
#define AMBIENT_HEALTH_MULT_YELLOW 1.25
#define AMBIENT_HEALTH_MULT_RED 1.5

/// A site whose NPCs are not out right now; they come back on the next visit
#define AMBIENT_SITE_DORMANT "dormant"
/// A site whose NPCs are out
#define AMBIENT_SITE_ACTIVE "active"
/// A site whose NPCs were all killed: it stays empty for the rest of the round
#define AMBIENT_SITE_SPENT "spent"

// ===== STRAYS (5.1 to 5.4) =====

/// Drifting lifeboats alive at once
#define AMBIENT_LIFEBOATS_MAX 1
/// One escaped convict per this many active ships...
#define AMBIENT_CONVICT_SHIPS_PER 3
/// ...and never more than this many alive
#define AMBIENT_CONVICTS_MAX 3
/// Strays waiting to be taken aboard one ship at once
#define AMBIENT_RECRUITS_PENDING_PER_SHIP 1
/// Strays one ship may take aboard in a round
#define AMBIENT_RECRUITS_PER_SHIP_ROUND 2

// ===== DIALOGUE (2.3) =====

/// Where every ambient dialogue file lives
#define AMBIENT_STRINGS_DIR "voidcrew/modules/ambient_npcs/strings"
/// The core's own lines: fallbacks for every context an NPC's own file leaves out (P0)
#define AMBIENT_STRINGS_CORE "ambient_core.json"
/// Customers, drinkers and the outpost crowd (PA)
#define AMBIENT_STRINGS_PATRONS "outpost_patrons.json"
/// Janitors, gardeners, barbacks, dock workers and the angler (PA)
#define AMBIENT_STRINGS_WORKERS "outpost_workers.json"
/// Miners, fishers, the jungle, peddlers (PB)
#define AMBIENT_STRINGS_PLANETS "planet_npcs.json"
/// Stranded people, lifeboats and convicts (PC)
#define AMBIENT_STRINGS_STRAYS "strays.json"
/// Nanotrasen and Syndicate recruiters (PD)
#define AMBIENT_STRINGS_RECRUITERS "faction_recruiters.json"

/// An NPC's own pause between spontaneous lines
#define AMBIENT_SPEECH_COOLDOWN_LOW (45 SECONDS)
#define AMBIENT_SPEECH_COOLDOWN_HIGH (90 SECONDS)
/// Pause shared by everyone at one place (an outpost, a planet site), so a full room never talks over itself
#define AMBIENT_PLACE_SPEECH_COOLDOWN (8 SECONDS)
/// A reply comes this long after the line it answers
#define AMBIENT_REPLY_DELAY_LOW (1 SECONDS)
#define AMBIENT_REPLY_DELAY_HIGH (2.5 SECONDS)
/// A player who talked to an NPC gets another answer after this
#define AMBIENT_TALK_COOLDOWN (4 SECONDS)

// Contexts every NPC can be asked for. A package adds its own as plain strings in its own file.
/// Nothing in particular: said now and then while idle
#define AMBIENT_LINE_IDLE "idle"
/// A player clicked them with an empty hand
#define AMBIENT_LINE_TALK "talk"
/// Someone took a swing at them
#define AMBIENT_LINE_ATTACKED "attacked"
/// A fight broke out near them
#define AMBIENT_LINE_VIOLENCE "violence"
/// A storm is coming
#define AMBIENT_LINE_STORM "storm"
/// Opening a chat with another NPC
#define AMBIENT_LINE_CHAT "chat"
/// Answering another NPC
#define AMBIENT_LINE_REPLY "reply"
/// Heading off
#define AMBIENT_LINE_LEAVE "leave"
/// Busy with some work
#define AMBIENT_LINE_WORK "work"
/// Their camp or home is overrun, or guns are out: running for cover
#define AMBIENT_LINE_COVER "cover"

// ===== ACTIVITIES (2.1) =====

/// What /datum/ambient_activity/proc/act() returns: carry on here
#define AMBIENT_STEP_CONTINUE 0
/// ...walk to the activity's new spot first
#define AMBIENT_STEP_MOVE 1
/// ...the activity is over; another one is picked
#define AMBIENT_STEP_DONE 2

/// An ordinary activity, replaced by any reaction
#define AMBIENT_PRIORITY_ROUTINE 0
/// A reaction (taking cover, sheltering from a storm): replaced only by another reaction or by leaving
#define AMBIENT_PRIORITY_REACTION 50
/// Leaving: nothing replaces it
#define AMBIENT_PRIORITY_LEAVE 100

/// How far around an NPC an activity looks for what it uses
#define AMBIENT_ACTIVITY_RANGE 7
/// After nothing could be set up, the NPC stands about this long before trying again
#define AMBIENT_ACTIVITY_RETRY (15 SECONDS)
/// Walks that end stuck before an activity gives up on its spot
#define AMBIENT_TRAVEL_FAILURES_MAX 3
/// Spots remembered as unreachable, per activity
#define AMBIENT_FAILED_SPOTS_MAX 6
/// Longest path an ambient NPC walks
#define AMBIENT_PATH_LENGTH 60
/// Glasses one NPC leaves on tables in a visit (the bounty rule, BOUNTY_BAR_GLASSES_MAX)
#define AMBIENT_GLASSES_MAX 2
/// A walk to the lift that takes longer than this ends in a fade where they stand
#define AMBIENT_LEAVE_TIMEOUT (90 SECONDS)
/// Fading in at the lift, fading out on leaving
#define AMBIENT_FADE_TIME (1 SECONDS)
/// How long a ducking NPC stays down before heading off
#define AMBIENT_DUCK_TIME (3 SECONDS)
/// Least time between two reactions of one NPC to the same kind of thing
#define AMBIENT_REACTION_COOLDOWN (6 SECONDS)
/// An NPC off its leash for this long with its AI on, and not walking back, fades (or is put home)
#define AMBIENT_LEASH_GIVE_UP (30 SECONDS)
/// Glasses on one table past which an NPC's empty glass just goes
#define AMBIENT_TABLE_GLASSES_MAX 3

/// Blackboard key: the turf an ambient NPC is walking to for its activity
#define BB_AMBIENT_DESTINATION "ambient_destination"

// ===== SIGNALS =====

/// From /obj/structure/overmap/trader_outpost/register_aggression(), on the outpost: (mob/living/offender)
#define COMSIG_TRADER_OUTPOST_VIOLENCE "trader_outpost_violence"
/// From /obj/structure/overmap/trader_outpost/convoy_restock(), on the outpost, after the shelves refill: ()
#define COMSIG_TRADER_OUTPOST_CONVOY "trader_outpost_convoy"
/// From an ambient NPC as it dies, before its loot drops: (datum/ambient_place/place)
#define COMSIG_AMBIENT_NPC_DIED "ambient_npc_died"
/// From an ambient NPC when a new activity starts: (datum/ambient_activity/activity)
#define COMSIG_AMBIENT_NPC_ACTIVITY_STARTED "ambient_npc_activity_started"
/// From SSambient_npcs on a trader outpost when its first ambient NPC is due: (datum/ambient_place/outpost/place)
#define COMSIG_AMBIENT_OUTPOST_OCCUPIED "ambient_outpost_occupied"
/// From SSambient_npcs on a trader outpost after its ambient NPCs were cleared: (datum/ambient_place/outpost/place)
#define COMSIG_AMBIENT_OUTPOST_EMPTIED "ambient_outpost_emptied"
