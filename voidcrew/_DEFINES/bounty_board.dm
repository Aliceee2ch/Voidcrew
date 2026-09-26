// # Bounty hunting: board, placement and turn-in defines
//
// Owner: P5 board (voidcrew/modules/bounties/bounty_board.dm, bounty_posting.dm,
// bounty_placement.dm, bounty_turn_in.dm). Only P5 edits this file. The shared enums are in
// bounties.dm. Values marked BAL are the spec's placeholders (spec.md sections 1, 2, 6 and 10, and
// decision 14) until the balance fold-in replaces them.

/// Criminal bounties one ship may hunt at once
#define BOUNTY_MAX_HUNTS_PER_SHIP 1 // BAL: placeholder, set by the balance fold-in
/// Public bounties on the board at once, server-wide
#define BOUNTY_MAX_PUBLIC 4 // BAL: placeholder, set by the balance fold-in

/// Base value by tier in green space, before the zone multiplier
#define BOUNTY_VALUE_PETTY_MIN 700 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_VALUE_PETTY_MAX 1000 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_VALUE_WANTED_MIN 1400 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_VALUE_WANTED_MAX 2000 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_VALUE_MOST_WANTED_MIN 4000 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_VALUE_MOST_WANTED_MAX 6000 // BAL: placeholder, set by the balance fold-in

/// Percent of the value paid at the pad, by capture state (decision 14)
#define BOUNTY_SHARE_RESTRAINED 100 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_SHARE_STUNNED 100 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_SHARE_DOWNED 60 // BAL: placeholder, set by the balance fold-in
#define BOUNTY_SHARE_DEAD 25 // BAL: placeholder, set by the balance fold-in

/// How often the sighting marker moves to where the criminal is
#define BOUNTY_SIGHTING_INTERVAL (60 SECONDS) // BAL: placeholder, set by the balance fold-in
/// How far, in tiles, the sighting marker may land from the criminal
#define BOUNTY_SIGHTING_OFFSET 4 // BAL: placeholder, set by the balance fold-in
