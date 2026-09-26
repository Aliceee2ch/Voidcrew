// # Outpost prison: bounty prisoner defines
//
// Owner: P7 prison (voidcrew/modules/player_outposts/outpost_prison_bounty.dm). Only P7 edits this
// file. The shared enums are in bounties.dm. Values marked BAL are the spec's placeholders
// (spec.md section 8) until the balance fold-in replaces them. Where the spec names a knob but no
// number yet, the placeholder is the neutral value: 1 for a multiplier, 0 for a bonus.

/// Records the prisoner pool holds; at the cap the oldest unreserved one is dropped
#define BOUNTY_POOL_CAP 20 // BAL: placeholder, set by the balance fold-in
/// How long a record waits for its preferred prison before any prison may take it
#define BOUNTY_POOL_RESERVE_TIME (10 MINUTES) // BAL: placeholder, set by the balance fold-in

/// A bounty prisoner's health, by tier
#define BOUNTY_PRISONER_HEALTH_PETTY 100 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_PRISONER_HEALTH_WANTED 130 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_PRISONER_HEALTH_MOST_WANTED 180 // BAL: placeholder, set by the balance fold-in

/// What a bounty prisoner earns the outpost (stipend, pay rate and release bonus) as a multiple of a normal prisoner's, by tier
#define BOUNTY_PRISON_PAY_MULT_PETTY 1.5 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_PRISON_PAY_MULT_WANTED 2 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_PRISON_PAY_MULT_MOST_WANTED 3 // BAL: placeholder, set by the balance fold-in

/// Danger by tier: multiplier on punch and shiv damage
#define BOUNTY_PRISON_DAMAGE_MULT_PETTY 1 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_PRISON_DAMAGE_MULT_WANTED 1 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_PRISON_DAMAGE_MULT_MOST_WANTED 1 // BAL: placeholder, set by the balance fold-in
/// Danger by tier: multiplier on mood losses
#define BOUNTY_PRISON_MOOD_SCALE_PETTY 1 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_PRISON_MOOD_SCALE_WANTED 1 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_PRISON_MOOD_SCALE_MOST_WANTED 1 // BAL: placeholder, set by the balance fold-in
/// Danger by tier: mood points added to the line below which they square up to staff
#define BOUNTY_PRISON_THREAT_BONUS_PETTY 0 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_PRISON_THREAT_BONUS_WANTED 0 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_PRISON_THREAT_BONUS_MOST_WANTED 0 // BAL: placeholder, set by the balance fold-in
/// Danger by tier: mood points added to the line below which they join a riot
#define BOUNTY_PRISON_RIOT_BONUS_PETTY 0 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_PRISON_RIOT_BONUS_WANTED 0 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_PRISON_RIOT_BONUS_MOST_WANTED 0 // BAL: placeholder, set by the balance fold-in
/// Tension a Most Wanted prisoner in the cell block adds as a ringleader
#define BOUNTY_PRISON_RINGLEADER_TENSION 0 // BAL: placeholder, set by the balance fold-in
/// Danger by tier: multiplier on the damage their blows do to the wing's ways out in a breakout
#define BOUNTY_PRISON_BREAKOUT_MULT_PETTY 1 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_PRISON_BREAKOUT_MULT_WANTED 1 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_PRISON_BREAKOUT_MULT_MOST_WANTED 1 // BAL: placeholder, set by the balance fold-in
/// Danger by tier: multiplier on how long cuffing them takes
#define BOUNTY_PRISON_CUFF_MULT_PETTY 1 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_PRISON_CUFF_MULT_WANTED 1 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_PRISON_CUFF_MULT_MOST_WANTED 1 // BAL: placeholder, set by the balance fold-in
