// # Bounty lairs: numbers
//
// Owner: P10 lairs (framework and lich) and P12 mafia mobs, each in its own marked section.
// Placeholders until balance/lairs.md lands.

// ===== P10 =====
// Kill-only postings, lair sites, the lair clock and the lich kill bounty
// (voidcrew/modules/bounties/bounty_lair.dm). Spec 14.1-14.3, balance/lairs.md sections 8 and 10.
// Unit tests compile before this file: a test uses the literal value with the define named beside it.

/// close() reason (beside the shared BOUNTY_CLOSE_*): the lair or the event a kill-only bounty pointed at went away before the kill was turned in
#define BOUNTY_CLOSE_LAIR_GONE "lair_gone"
/// The id a lair's gate poddoors are mapped with. They open when the lair's last gatekeeper dies.
#define BOUNTY_LAIR_GATE_ID "bounty_lair_gate"
/// Sent on the lich lair (/obj/structure/overmap/space_ruin/lich_lair) when Ilthuun dies: (mob/living/slain)
#define COMSIG_BOUNTY_LICH_SLAIN "bounty_lich_slain"

// ----- When lairs are posted -----

/// How often the lair clock (SSbounty_lairs) looks at the board
#define BOUNTY_LAIR_TICK (1 MINUTES)
/// The first lair of a kind comes this long into the round, plus up to BOUNTY_LAIR_FIRST_SPREAD
#define BOUNTY_LAIR_FIRST_AFTER (45 MINUTES)
#define BOUNTY_LAIR_FIRST_SPREAD (15 MINUTES)
/// Active crewed player ships needed before a lair is posted
#define BOUNTY_LAIR_MIN_SHIPS 3
/// After a lair's bounty closes, the next of that kind waits this long (a random time between the two)
#define BOUNTY_LAIR_GAP_MIN (60 MINUTES)
#define BOUNTY_LAIR_GAP_MAX (90 MINUTES)
/// When a lair could not be placed, how soon the clock tries again
#define BOUNTY_LAIR_RETRY (5 MINUTES)
/// How long a lair's bounty stays up. The clock waits while any ship hunts it or anyone is inside the lair.
#define BOUNTY_LAIR_EXPIRY (60 MINUTES)
/// Tries at a free overmap square in the lair's zone band (the red band is small)
#define BOUNTY_LAIR_OVERMAP_TRIES 80
/// Zone band weights for a lair: always yellow or red (spec 14.4)
#define BOUNTY_LAIR_WEIGHT_YELLOW 2
#define BOUNTY_LAIR_WEIGHT_RED 1

// ----- Pay (balance/lairs.md section 8) -----

/// The mafia club's base credits, before the zone multiplier; all of it is paid on the trophy
#define BOUNTY_PAY_LAIR_MIN 4800
#define BOUNTY_PAY_LAIR_MAX 5600
/// The mafia club's trade vouchers; red space adds BOUNTY_RED_VOUCHER_BONUS
#define BOUNTY_VOUCHERS_LAIR 3
/// The lich pays the Most Wanted band times this (spec 14.3), plus the Most Wanted vouchers
#define BOUNTY_LICH_PAY_MULT 1.5
/// The lich's bounty clock holds while he lives; once he is dead it runs this long
#define BOUNTY_LICH_EXPIRY_AFTER_KILL (45 MINUTES)

// ----- Inside a lair -----

/// After a lair boss falls, how long to wait for its next phase (the don out of his mech) before the trophy drops
#define BOUNTY_LAIR_TROPHY_GRACE (5 SECONDS)
/// A second pass that keeps the goons in their rooms, once every zone_mobs marker has had time to spawn (its resolver retries for up to a minute)
#define BOUNTY_LAIR_GOON_LEASH_DELAY (65 SECONDS)
