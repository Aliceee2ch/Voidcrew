// ===== OUTPOST PRISON: INTERROGATION AND LEADS (see outpost_prison_leads.dm) =====
// Owner: XG. Values from extras-plan.md 4.16. A lead is a Rumors waypoint on the asker's ship: an
// uncharted ruin that already exists, never new loot and never credits. Lies are the owner's
// approved exception to "deceptions are atmosphere": only unhappy prisoners lie, and every lie can
// be caught before or during the flight.

/// Percent of arrivals who carry a lead
#define OUTPOST_PRISON_LEAD_CHANCE 30
/// A wing gives at most one lead (true or not) per this, stored as a ready time never shortened
#define OUTPOST_PRISON_LEAD_GAP (40 MINUTES)
/// Face to face for this long to ask
#define OUTPOST_PRISON_LEAD_ASK_TIME (3 SECONDS)
/// Between questions to one prisoner
#define OUTPOST_PRISON_LEAD_ASK_COOLDOWN (2 MINUTES)
/// At or above this mood a prisoner never lies
#define OUTPOST_PRISON_LEAD_TRUE_MOOD 70
/// Below this mood the lie chance is OUTPOST_PRISON_LEAD_LIE_HOSTILE, else OUTPOST_PRISON_LEAD_LIE_UNEASY
#define OUTPOST_PRISON_LEAD_HOSTILE_MOOD 40
#define OUTPOST_PRISON_LEAD_LIE_UNEASY 15
#define OUTPOST_PRISON_LEAD_LIE_HOSTILE 50
/// Below this mood they refuse, and keep the lead
#define OUTPOST_PRISON_LEAD_REFUSE_MOOD 25
/// Percentage points added to the lie chance for a "brute" asker, and taken off for a "fair" one
#define OUTPOST_PRISON_LEAD_BRUTE_LIE 20
#define OUTPOST_PRISON_LEAD_FAIR_LIE 10
/// A prisoner the asker hit unprovoked within this refuses
#define OUTPOST_PRISON_LEAD_HIT_MEMORY (10 MINUTES)
/// Percent chance a liar shows a tell when answering, and that someone telling the truth shows the same tell
#define OUTPOST_PRISON_LEAD_TELL_LIE 60
#define OUTPOST_PRISON_LEAD_TELL_TRUTH 10
/// Percent chance a prisoner who saw a lead given chips in about it, and the mood they need to
#define OUTPOST_PRISON_LEAD_GOSSIP_CHANCE 50
#define OUTPOST_PRISON_LEAD_GOSSIP_MOOD 50
/// After a lead, other prisoners can be asked about it for this long; at OUTPOST_PRISON_LEAD_GOSSIP_MOOD or more they answer truly
#define OUTPOST_PRISON_LEAD_VOUCH_TIME (20 MINUTES)
/// Seconds between checks of open lies against the asking ships' positions
#define OUTPOST_PRISON_LEAD_CHECK_INTERVAL 10
/// Open leads a wing keeps track of, and for how long
#define OUTPOST_PRISON_LEAD_OPEN_MAX 5
#define OUTPOST_PRISON_LEAD_TRACK_TIME (60 MINUTES)
/// Tries at an empty overmap tile for a lie; failing that, they tell the truth
#define OUTPOST_PRISON_LEAD_LIE_TRIES 30
