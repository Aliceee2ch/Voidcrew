// ===== OUTPOST PRISON: ECONOMY (see outpost_prison_economy.dm and outpost_prison_warden.dm) =====
// Pay, sentences, arrivals, releases, fines and the warden console's money.
//
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

/// Treasury price of the prison wing upgrade
#define OUTPOST_PRISON_COST 12000
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
/// Log entries the warden console keeps
#define OUTPOST_PRISON_LOG_LENGTH 8
/// What the treasury is fined for a prisoner gone for good (as much of it as the treasury holds)
#define OUTPOST_PRISON_ESCAPE_FINE 1000

/// Care percent at or below which a prisoner pays nothing
#define OUTPOST_PRISON_GRADE_FLOOR 70
/// Care percent from which a prisoner pays in full
#define OUTPOST_PRISON_GRADE_FULL 95
/// Seconds between stipend deposits
#define OUTPOST_PRISON_DEPOSIT_INTERVAL 300
/// What the office dispenser charges for a bruise pack and a prison uniform
#define OUTPOST_PRISON_BRUISE_PACK_COST 25
#define OUTPOST_PRISON_UNIFORM_COST 50
/// Rations in one "serve a round"
#define OUTPOST_PRISON_SERVE_ROUND 4
/// Items a resident may order from the dispenser per window
#define OUTPOST_PRISON_RESIDENT_ORDERS 8
#define OUTPOST_PRISON_RESIDENT_ORDER_WINDOW (10 MINUTES)
/// Dispenser cooldown for managers and treasurers
#define OUTPOST_PRISON_ORDER_COOLDOWN (2 SECONDS)
/// Fee per rioter transferred out after a sit-in nobody came back for
#define OUTPOST_PRISON_TRANSFER_FEE 750
/// Most one incident (a riot, its breakout, its escapes and transfers) can be fined in all
#define OUTPOST_PRISON_INCIDENT_FINE_CAP 2500
/// Fine for a death in custody blamed on staff
#define OUTPOST_PRISON_DEATH_FINE 1000
/// Prisoners lost (escaped or transferred) within OUTPOST_PRISON_LOST_WINDOW that suspend intake
#define OUTPOST_PRISON_LOST_TO_SUSPEND 2
#define OUTPOST_PRISON_LOST_WINDOW (30 MINUTES)
/// Seconds confined to a cell before a prisoner stops paying
#define OUTPOST_PRISON_CONFINED_PAY_AFTER 120
