// ===== OUTPOST PRISON: ECONOMY (see outpost_prison_economy.dm and outpost_prison_warden.dm) =====
// Pay, sentences, arrivals, releases, fines, debt and the warden console's money.
//
// Pay model. Each prisoner serving their sentence earns the treasury, per minute,
//   OUTPOST_PRISON_BASE_PAY x G(care) x F(conditions)
// - care = mean(fed, clean uniform, health), 0 to 100 (the prisoner's care());
// - G(care) = (care - OUTPOST_PRISON_GRADE_FLOOR) / (OUTPOST_PRISON_GRADE_FULL - OUTPOST_PRISON_GRADE_FLOOR),
//   clamped to 0-1: nothing at or below 70% care, full pay from 95%;
// - F(conditions) = conditions_pay_factor(), 0.5 + 0.5 x conditions / 100: a filthy, dark, unpowered
//   wing costs at most half the pay.
// Nothing while they fight, riot, break out, are loose or wreck their cell, and nothing once they
// have been confined to their cell for more than OUTPOST_PRISON_CONFINED_PAY_AFTER seconds, unless
// it is for their own safety (protective custody: a riot, a loose prisoner or an experiment).
// Stipends are deposited every OUTPOST_PRISON_DEPOSIT_INTERVAL seconds. A release pays
// OUTPOST_PRISON_RELEASE_BONUS x (G x F averaged over the stay).
// One cell turns over every ~13 minutes: an 11.5 minute average sentence and a 60-120 second
// refill. Four cells at full pay: 4 x 12 cr/min x 60 x 11.5 / 13 = ~2,550 cr/h in stipends, plus
// 4 x 60 / 13 = ~18.5 releases/h x 200 = ~3,700 cr/h in bonuses. Ceiling ~6,250 cr/h before
// supplies; a well-kept wing nets 5,300-5,400 cr/h and pays back its 10,000 cr in about 2 hours.
//
// Fines: 1,000 for an escape, 750 per rioter transferred out after a sit-in nobody came back to,
// at most 2,500 for one incident (a riot, its breakout, its escapes and transfers) in all, and
// 1,000 for a death in custody blamed on staff, never capped. What the treasury cannot pay becomes
// its debt (tg's account_debt: 75% of every later deposit pays it off), and no prisoner arrives
// while it is owed. Two prisoners lost within 30 minutes suspend transfers until a manager reopens
// intake.

/// Treasury price of the prison wing upgrade
#define OUTPOST_PRISON_COST 10000
/// Prisoners the wing holds at once: one per cell
#define OUTPOST_PRISON_CAPACITY 4
/// Treasury credits per minute per prisoner at full care and conditions
#define OUTPOST_PRISON_BASE_PAY 12
/// Treasury credits for a release at full care and conditions
#define OUTPOST_PRISON_RELEASE_BONUS 200
/// What the office supply dispenser charges the treasury per ration
#define OUTPOST_PRISON_RATION_COST 25
/// Sentence range, in seconds
#define OUTPOST_PRISON_SENTENCE_MIN (8 * 60)
#define OUTPOST_PRISON_SENTENCE_MAX (15 * 60)
/// Seconds from opening intake to the first arrival
#define OUTPOST_PRISON_FIRST_ARRIVAL 5
/// Seconds between arrivals while cells are free
#define OUTPOST_PRISON_ARRIVAL_GAP_MIN 20
#define OUTPOST_PRISON_ARRIVAL_GAP_MAX 40
/// Seconds before a freed cell takes a new arrival
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
/// Fine for a prisoner gone for good; what the treasury cannot pay becomes debt
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
