// ===== OUTPOST PRISON: NPC GUARDS (see outpost_prison_guards.dm) =====
// Owner: XA. Values from extras-plan.md 4.1. Guards are security only: they never feed, clothe,
// treat, clean or light anything, so they cannot raise pay.

/// Guards a wing can hire: one on the door, one in the yard
#define OUTPOST_GUARD_MAX 2
/// Credits charged from the treasury before a hired guard beams in; refused if short, never debt
#define OUTPOST_GUARD_HIRE_COST 1000
/// Credits per minute per guard, only for time a wing member was home
#define OUTPOST_GUARD_WAGE 2
/// Wages skipped in a row (the treasury could not cover them) before the guards walk off
#define OUTPOST_GUARD_UNPAID_LEAVE 2
#define OUTPOST_GUARD_HEALTH 120
/// Health at which a guard goes down (godmode, lying) instead of taking more damage
#define OUTPOST_GUARD_DOWN_AT 30
/// From going down to beaming out
#define OUTPOST_GUARD_RECALL_DELAY (10 SECONDS)
/// A downed or recalled guard comes back free after this, if still hired and a member is home
#define OUTPOST_GUARD_RETURN_TIME (10 MINUTES)
/// Stamina damage per baton strike: prisoners crit at 100, so three strikes
#define OUTPOST_GUARD_BATON_STAMINA 35
#define OUTPOST_GUARD_BATON_COOLDOWN (2 SECONDS)
/// Percent chance a guard arriving at an argument ends it with words
#define OUTPOST_GUARD_TALKDOWN_CHANCE 60
/// Below this health a guard in a riot falls back to the office
#define OUTPOST_GUARD_FALLBACK_BELOW 60
/// Mood each prisoner who sees a baton strike loses, once per 60 s each
#define OUTPOST_GUARD_ONLOOKER_MOOD 2
/// A response the guard cannot reach in this long is dropped
#define OUTPOST_GUARD_RESPONSE_TIMEOUT (30 SECONDS)
/// Per member: between reports of the wing's top problem, and between greetings
#define OUTPOST_GUARD_REPORT_GAP (3 MINUTES)
#define OUTPOST_GUARD_GREET_GAP (10 MINUTES)
/// Between rounds of the cell block
#define OUTPOST_GUARD_ROUNDS_GAP_MIN (8 MINUTES)
#define OUTPOST_GUARD_ROUNDS_GAP_MAX (12 MINUTES)
