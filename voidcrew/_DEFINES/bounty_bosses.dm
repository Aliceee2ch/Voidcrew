// # Bounty hunting: mini-boss defines
//
// Owner: P4 bosses (voidcrew/modules/bounties/bounty_boss.dm, bounty_boss_kits.dm). Only P4 edits
// this file. The shared enums are in bounties.dm. Values marked BAL are the spec's placeholders
// (spec.md section 5) until the balance fold-in replaces them.

/// Health by kit, before scaling for extra hunters
#define BOUNTY_JUGGERNAUT_HEALTH 450 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_PYROMANIAC_HEALTH 300 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_DEMOLITIONIST_HEALTH 280 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_GHOST_HEALTH 220 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_HEAVY_HEALTH 380 // BAL: placeholder, set by the balance fold-in

/// Armour by kit, as damage_coeff multipliers
#define BOUNTY_JUGGERNAUT_BRUTE_MOD 0.6 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_JUGGERNAUT_BURN_MOD 0.8 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_PYROMANIAC_BRUTE_MOD 0.9 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_PYROMANIAC_BURN_MOD 0.3 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_DEMOLITIONIST_BRUTE_MOD 0.8 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_DEMOLITIONIST_EXPLOSIVE_MOD 0.5 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_GHOST_DAMAGE_MOD 0.9 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_HEAVY_BRUTE_MOD 0.7 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_HEAVY_BURN_MOD 0.8 // BAL: placeholder, set by the balance fold-in

/// Extra health for each hunter on the site beyond the first, as a share of the kit's health (the spec gives no number yet)
#define BOUNTY_BOSS_HEALTH_PER_EXTRA_HUNTER 0.25 // BAL: placeholder, set by the balance fold-in
/// Extra hunters that count toward that scaling
#define BOUNTY_BOSS_EXTRA_HUNTERS_MAX 3 // BAL: placeholder, set by the balance fold-in
/// Walls and windows one ability use may break aboard a player ship (the spec gives no number yet)
#define BOUNTY_BOSS_SHIP_DAMAGE_CAP 2 // BAL: placeholder, set by the balance fold-in
