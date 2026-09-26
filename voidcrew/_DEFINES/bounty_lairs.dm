// # Bounty lairs: numbers
//
// Owner: P10 lairs (framework and lich) and P12 mafia mobs, each in its own marked section.
// Placeholders until balance/lairs.md lands.

// ===== P12 =====
// The mafia club's people (bounty_lair_mafia.dm): balance/lairs.md sections 3-5 and 10, spec section 15.
// Unit tests can't see these; they use the literal values with the define named in a comment.

/// The faction every club mob shares: goons, lieutenants, the mech and the don
#define BOUNTY_MAFIA_FACTION "bounty_mafia"
/// The club's dialogue, loaded from BOUNTY_MAFIA_STRINGS_DIR
#define BOUNTY_MAFIA_STRINGS_FILE "bounty_lair_mafia.json"
#define BOUNTY_MAFIA_STRINGS_DIR "voidcrew/modules/bounties/strings"
/// Shortest gap between two lines from one mob, unless a line is forced
#define BOUNTY_MAFIA_BARK_COOLDOWN (12 SECONDS)
/// Chance a second, per mob, that an idle goon says something while players are about
#define BOUNTY_MAFIA_IDLE_BARK_CHANCE 1

/// Sent on the mech as the don climbs out, before the mech's death: (mob/living/basic/bounty_lair_boss/mafia_don/don)
#define COMSIG_BOUNTY_MAFIA_DON_EJECTED "bounty_mafia_don_ejected"
/// Sent on the don when his trophy drops: (obj/item/bounty_proof/trophy/mafia_don/trophy)
#define COMSIG_BOUNTY_MAFIA_TROPHY_DROPPED "bounty_mafia_trophy_dropped"

/// Blackboard key: a turf a club mob is walking to (its room, or cover behind the wreck)
#define BB_BOUNTY_MAFIA_MOVE_TO "BB_bounty_mafia_move_to"

// ----- mobsters -----

#define BOUNTY_MOBSTER_KNIFE_HEALTH 70
#define BOUNTY_MOBSTER_KNIFE_DAMAGE_MIN 8
#define BOUNTY_MOBSTER_KNIFE_DAMAGE_MAX 12
#define BOUNTY_MOBSTER_KNIFE_COOLDOWN (1.2 SECONDS)
#define BOUNTY_MOBSTER_KNIFE_SPEED 1.6

#define BOUNTY_MOBSTER_PISTOL_HEALTH 75
#define BOUNTY_MOBSTER_PISTOL_DAMAGE_MIN 12
#define BOUNTY_MOBSTER_PISTOL_DAMAGE_MAX 14
#define BOUNTY_MOBSTER_PISTOL_COOLDOWN (1.5 SECONDS)
#define BOUNTY_MOBSTER_PISTOL_ROUNDS 6
#define BOUNTY_MOBSTER_PISTOL_RELOAD (3 SECONDS)
#define BOUNTY_MOBSTER_PISTOL_SPEED 1.8

#define BOUNTY_MOBSTER_SMG_HEALTH 90
#define BOUNTY_MOBSTER_SMG_DAMAGE_MIN 7
#define BOUNTY_MOBSTER_SMG_DAMAGE_MAX 9
#define BOUNTY_MOBSTER_SMG_BURST 3
#define BOUNTY_MOBSTER_SMG_WINDUP (0.8 SECONDS)
#define BOUNTY_MOBSTER_SMG_COOLDOWN (3.5 SECONDS)
#define BOUNTY_MOBSTER_SMG_BURSTS 4
#define BOUNTY_MOBSTER_SMG_RELOAD (3 SECONDS)
#define BOUNTY_MOBSTER_SMG_SPEED 1.8

/// The shout before a room's first shot
#define BOUNTY_MOBSTER_ALERT (1 SECONDS)
/// The rest of the room's first shots spread over this after the shout
#define BOUNTY_MOBSTER_FIRST_SHOT_SPREAD (1 SECONDS)
/// A goon hit while bringing a spun-up gun to bear loses this long
#define BOUNTY_MOBSTER_FUMBLE (1 SECONDS)
/// Goons of one room that may go after one hunter standing in a doorway
#define BOUNTY_MOBSTER_MAX_ON_ONE 2
/// How far a goon sees and shoots
#define BOUNTY_MOBSTER_SIGHT 9
/// How far a goon keeps after a hunter it can't see any more (inside its own room)
#define BOUNTY_MOBSTER_CHASE 12

// ----- lieutenants -----

#define BOUNTY_LIEUTENANT_TOMMY_HEALTH 220
#define BOUNTY_LIEUTENANT_TOMMY_DAMAGE_MIN 8
#define BOUNTY_LIEUTENANT_TOMMY_DAMAGE_MAX 10
#define BOUNTY_LIEUTENANT_TOMMY_BURST 4
#define BOUNTY_LIEUTENANT_TOMMY_WINDUP (0.8 SECONDS)
#define BOUNTY_LIEUTENANT_TOMMY_COOLDOWN (3 SECONDS)
#define BOUNTY_LIEUTENANT_TOMMY_BURSTS 12
#define BOUNTY_LIEUTENANT_TOMMY_RELOAD (4 SECONDS)
#define BOUNTY_LIEUTENANT_TOMMY_SPEED 1.8

#define BOUNTY_LIEUTENANT_BRUTE_HEALTH 240
#define BOUNTY_LIEUTENANT_BRUTE_DAMAGE_MIN 18
#define BOUNTY_LIEUTENANT_BRUTE_DAMAGE_MAX 24
#define BOUNTY_LIEUTENANT_BRUTE_COOLDOWN (1.4 SECONDS)
/// Percent chance a blow knocks the hunter down
#define BOUNTY_LIEUTENANT_BRUTE_KNOCKDOWN_CHANCE 25
#define BOUNTY_LIEUTENANT_BRUTE_KNOCKDOWN (1 SECONDS)
#define BOUNTY_LIEUTENANT_BRUTE_SPEED 1.5

/// Both lieutenants take this much of any brute or burn damage
#define BOUNTY_LIEUTENANT_DAMAGE_MOD 0.8

/// The lieutenants' names for the role var
#define BOUNTY_LIEUTENANT_TOMMY "tommy"
#define BOUNTY_LIEUTENANT_BRUTE "brute"

// ----- the don's mech -----

#define BOUNTY_MECH_HEALTH_1 350
#define BOUNTY_MECH_HEALTH_2 700
#define BOUNTY_MECH_HEALTH_3 1050
#define BOUNTY_MECH_HEALTH_4 1400
#define BOUNTY_MECH_BRUTE_MOD 0.6
#define BOUNTY_MECH_BURN_MOD 0.8
#define BOUNTY_MECH_SPEED 2.5
/// How far it sees hunters and aims its guns
#define BOUNTY_MECH_SIGHT 12

#define BOUNTY_MECH_STOMP_DAMAGE_MIN 20
#define BOUNTY_MECH_STOMP_DAMAGE_MAX 26
#define BOUNTY_MECH_STOMP_AP 10
#define BOUNTY_MECH_STOMP_COOLDOWN (1.8 SECONDS)

/// The lock-on: a marker under each hunter it can see, then one rocket per marker
#define BOUNTY_MECH_ROCKET_LOCK (1.5 SECONDS)
#define BOUNTY_MECH_ROCKET_DAMAGE 60
#define BOUNTY_MECH_ROCKET_KNOCKDOWN (1 SECONDS)
#define BOUNTY_MECH_ROCKET_COOLDOWN (14 SECONDS)
/// Damage a rocket does to a table, window or door it hits in the arena, as a multiple of its damage
#define BOUNTY_MECH_ROCKET_DEMOLITION 8

#define BOUNTY_MECH_LMG_WINDUP (1.2 SECONDS)
#define BOUNTY_MECH_LMG_ROUNDS 12
#define BOUNTY_MECH_LMG_DAMAGE 8
/// The 12 rounds go out over this long
#define BOUNTY_MECH_LMG_FIRE_TIME (2 SECONDS)
#define BOUNTY_MECH_LMG_COOLDOWN (8 SECONDS)
/// Full width of the red cone, in degrees; the rounds spread over it
#define BOUNTY_MECH_LMG_ARC 30
/// How far the cone is marked
#define BOUNTY_MECH_LMG_RANGE 8
#define BOUNTY_MECH_LMG_DEMOLITION 0.25

/// Between the end of one ability and the start of the next
#define BOUNTY_MECH_ABILITY_GAP (3 SECONDS)

/// An EMP stalls it this long and takes this percent of its max health; never tg's full-health hit on a robot
#define BOUNTY_MECH_EMP_STALL (2 SECONDS)
#define BOUNTY_MECH_EMP_DAMAGE_PERCENT 5
/// After a stall it shrugs off further EMPs this long, so an ion gun can't hold it still
#define BOUNTY_MECH_EMP_IMMUNITY (3 SECONDS)

/// With no hunter in the arena, seen, or shooting at it this long, it resets to full health and a fresh posse
#define BOUNTY_MECH_RESET_AFTER (60 SECONDS)

// ----- the don on foot -----

#define BOUNTY_DON_HEALTH 150
#define BOUNTY_DON_DAMAGE_MIN 14
#define BOUNTY_DON_DAMAGE_MAX 17
#define BOUNTY_DON_COOLDOWN (1.4 SECONDS)
#define BOUNTY_DON_ROUNDS 6
#define BOUNTY_DON_RELOAD (3 SECONDS)
/// He raises the pistol this long before each string of shots
#define BOUNTY_DON_RAISE (0.4 SECONDS)
#define BOUNTY_DON_SPEED 1.8
#define BOUNTY_DON_EJECT_STAGGER (2 SECONDS)
