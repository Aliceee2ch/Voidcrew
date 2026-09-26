// # Bounty hunting: criminal body defines
//
// Owner: P2 body (voidcrew/modules/bounties/bounty_criminal.dm, bounty_restraints.dm). Only P2 edits
// this file. The shared enums are in bounties.dm. Values marked BAL are the spec's placeholders
// (spec.md section 4) until the balance fold-in replaces them.

/// Health of a meek criminal
#define BOUNTY_MEEK_HEALTH 80 // BAL: placeholder, set by the balance fold-in
/// Health of a normal criminal
#define BOUNTY_NORMAL_HEALTH 120 // BAL: placeholder, set by the balance fold-in
/// damage_coeff[STAMINA] of a meek criminal (the spec gives no number yet)
#define BOUNTY_MEEK_STAMINA_COEFF 1 // BAL: placeholder, set by the balance fold-in
/// damage_coeff[STAMINA] of a normal criminal (the spec gives no number yet)
#define BOUNTY_NORMAL_STAMINA_COEFF 1 // BAL: placeholder, set by the balance fold-in
/// How long stamina crit lasts after the last stamina hit: a cuff window, not a free win
#define BOUNTY_STAMCRIT_TIME (5 SECONDS) // BAL: placeholder, set by the balance fold-in
/// Share of max health at or below which a criminal is downed
#define BOUNTY_DOWNED_FRACTION 0.25 // BAL: placeholder, set by the balance fold-in
/// How long a downed, uncuffed criminal stays down, by archetype
#define BOUNTY_RECOVER_TIME_MEEK (60 SECONDS) // BAL: placeholder, set by the balance fold-in
#define BOUNTY_RECOVER_TIME_NORMAL (90 SECONDS) // BAL: placeholder, set by the balance fold-in
#define BOUNTY_RECOVER_TIME_BOSS (45 SECONDS) // BAL: placeholder, set by the balance fold-in
