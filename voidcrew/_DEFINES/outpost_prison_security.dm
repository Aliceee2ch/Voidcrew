// ===== OUTPOST PRISON: STUN TURRETS AND AMBIENCE (see outpost_prison_security.dm, outpost_prison_ambience.dm) =====
// Owner: XB. Values from extras-plan.md 4.2, 4.5 and 4.7. Turrets never raise pay and never
// touch a calm, threatening, wrecking or downed prisoner.

/// Credits per turret, charged before it spawns; refused if short, never debt
#define OUTPOST_PRISON_TURRET_COST 2000
/// Turrets a wing may have, counting every one it sold that still exists
#define OUTPOST_PRISON_TURRET_MAX 2
/// The laser line and beep before the first shot at a new target
#define OUTPOST_PRISON_TURRET_WARN_TIME (1.5 SECONDS)
