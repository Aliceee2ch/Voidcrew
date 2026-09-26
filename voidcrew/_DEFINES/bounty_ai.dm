// # Bounty hunting: criminal AI defines
//
// Owner: P3 AI (voidcrew/modules/bounties/bounty_ai.dm, bounty_ai_meek.dm, bounty_ai_normal.dm,
// bounty_activities.dm, bounty_companions.dm). Only P3 edits this file. The shared enums are in
// bounties.dm. Values marked BAL are the spec's placeholders (spec.md section 3) until the balance
// fold-in replaces them.

/// A meek criminal's speed while sprinting: faster than a running person (RUN_DELAY 1.5)
#define BOUNTY_MEEK_SPRINT_SPEED 1.2 // BAL: placeholder, set by the balance fold-in
/// A meek criminal's speed while winded: slower than walking (WALK_DELAY 4)
#define BOUNTY_MEEK_WINDED_SPEED 4.5 // BAL: placeholder, set by the balance fold-in
/// How long a meek criminal sprints before it is winded
#define BOUNTY_MEEK_SPRINT_TIME (10 SECONDS) // BAL: placeholder, set by the balance fold-in
/// How long a winded meek criminal rests before it can sprint again
#define BOUNTY_MEEK_REST_TIME (8 SECONDS) // BAL: placeholder, set by the balance fold-in
/// A meek criminal's alpha while it stands still on a dark tile
#define BOUNTY_MEEK_DARK_ALPHA 180 // BAL: placeholder, set by the balance fold-in
/// Shots in a cornered meek criminal's burst
#define BOUNTY_MEEK_BURST_SHOTS 3 // BAL: placeholder, set by the balance fold-in
/// Companions a normal criminal has with it
#define BOUNTY_COMPANIONS_MIN 0 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_COMPANIONS_MAX 2 // BAL: placeholder, set by the balance fold-in
/// Percent chance per hit that a badly hurt normal criminal surrenders (once)
#define BOUNTY_SURRENDER_CHANCE 25 // BAL: placeholder, set by the balance fold-in
