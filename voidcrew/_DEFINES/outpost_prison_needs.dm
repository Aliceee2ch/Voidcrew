// ===== OUTPOST PRISON: NEEDS (see outpost_prison_prisoner.dm, outpost_prison_routine.dm, outpost_prison_core.dm, outpost_prison_fixtures.dm) =====
// Hunger, uniforms, injuries, supplies and the routine, on 0-100 scales.

/// Hunger lost per minute: full to empty in 10 minutes, so an 8-15 minute stay needs a meal or two
#define PRISONER_HUNGER_DECAY 10
/// Hunger any one piece of food restores
#define PRISONER_FOOD_VALUE 50
/// Below this a prisoner goes looking for food
#define PRISONER_HUNGER_SEEK 50
/// At or above this a prisoner refuses food
#define PRISONER_HUNGER_FULL 90
#define PRISONER_HUNGER_HUNGRY 40
#define PRISONER_HUNGER_STARVING 15
/// Uniform grime gained per minute: clean to filthy-through in 12 minutes (dirty at 6), about one change a stay
#define PRISONER_GRIME_RATE (100 / 12)
#define PRISONER_GRIME_DIRTY 50
#define PRISONER_GRIME_FILTHY 80
/// Below this health percent a prisoner shows the hurt bubble and the roster calls them injured
#define PRISONER_INJURED_BELOW 90
/// Below this health percent an untreated prisoner leaves the odd drip of blood
#define PRISONER_BLEED_BELOW 50
/// How long stamina crit holds after the last stamina hit, long enough to drag one to a cell
#define PRISONER_STAMCRIT_TIME (20 SECONDS)
/// Percent chance per minute that a prisoner drops some mess
#define OUTPOST_PRISON_MESS_CHANCE 10
/// Pause between spontaneous prisoner lines anywhere in one wing (deciseconds)
#define OUTPOST_PRISON_SPEECH_GAP (6 SECONDS)

/// Mood lost per minute while hungry, or instead while starving
#define PRISONER_MOOD_HUNGRY 3
#define PRISONER_MOOD_STARVING 8
/// Mood lost per minute in a dirty uniform, or instead a filthy one
#define PRISONER_MOOD_DIRTY 2
#define PRISONER_MOOD_FILTHY 5
/// Mood lost per minute with no health left, scaled by the missing fraction (4 x missing x 2)
#define PRISONER_MOOD_HURT 8
/// Mood gained at once from a meal, a clean uniform and treatment
#define PRISONER_MOOD_FED 10
#define PRISONER_MOOD_CLEAN_UNIFORM 8
#define PRISONER_MOOD_TREATED 8

// Where a prisoner is in their stay (/mob/living/basic/outpost_prisoner/var/phase)
/// Being beamed into their cell
#define PRISONER_ARRIVING "arriving"
/// In the wing, serving their sentence
#define PRISONER_PRESENT "present"
/// Being beamed out, released or collected
#define PRISONER_LEAVING "leaving"

// What /mob/living/basic/outpost_prisoner/proc/try_reach() found
#define PRISONER_REACH_FAILED 0
#define PRISONER_REACH_OK 1
/// Their side of a serving hatch is opening
#define PRISONER_REACH_WAIT 2

/// Hunger range of a new arrival
#define PRISONER_ARRIVAL_HUNGER_MIN 35
#define PRISONER_ARRIVAL_HUNGER_MAX 75
/// Hunger restored by a prison ration, cooked food, a snack and poor food
#define PRISONER_FOOD_RATION 60
#define PRISONER_FOOD_COOKED 60
#define PRISONER_FOOD_SNACK 35
#define PRISONER_FOOD_POOR 20
/// How long cooked food stops hunger falling
#define PRISONER_WELL_FED_TIME (8 MINUTES)
/// Mood gained at once from cooked food and from a snack
#define PRISONER_MOOD_FED_COOKED 15
#define PRISONER_MOOD_FED_SNACK 5
/// Grime gained this many times faster during basketball and exercise
#define PRISONER_GRIME_SPORT_MULT 3
/// Most grime an ordinary arrival's uniform has
#define PRISONER_ARRIVAL_GRIME_MAX 15
/// Percent chance an arrival comes in a stained uniform, and its grime range
#define PRISONER_STAINED_CHANCE 35
#define PRISONER_STAINED_GRIME_MIN 55
#define PRISONER_STAINED_GRIME_MAX 70
/// Grime each fighter gains per fight
#define PRISONER_FIGHT_GRIME 20
/// Percent chance an arrival comes in roughed up, and their health percent range
#define PRISONER_HURT_ARRIVAL_CHANCE 20
#define PRISONER_HURT_ARRIVAL_MIN 60
#define PRISONER_HURT_ARRIVAL_MAX 85
/// Percent chance per minute of basketball or exercise of an injury, and its brute range
#define PRISONER_SPORT_INJURY_CHANCE 4
#define PRISONER_SPORT_INJURY_MIN 8
#define PRISONER_SPORT_INJURY_MAX 15
/// Injuries cost mood only below this health percent
#define PRISONER_HURT_MOOD_BELOW 75
/// Items one serving hatch holds
#define OUTPOST_PRISON_HATCH_CAPACITY 10
/// Percent chance a meal at a table leaves crumbs
#define PRISONER_TABLE_CRUMB_CHANCE 50
/// Percent chance a content prisoner (mood PRISONER_BIN_MOOD or more) bins their wrapper
#define PRISONER_BIN_CHANCE 70
#define PRISONER_BIN_MOOD 60
/// Mood from which an idle prisoner tidies one piece of litter, and how often
#define PRISONER_TIDY_MOOD 75
#define PRISONER_TIDY_COOLDOWN (5 MINUTES)
/// Mood gained by each of three or more prisoners eating together within the window
#define PRISONER_MOOD_SHARED_MEAL 3
#define PRISONER_SHARED_MEAL_WINDOW (60 SECONDS)
/// Time each need's thought bubble shows before the next
#define PRISONER_BUBBLE_CYCLE (4 SECONDS)
/// Meals and uniforms used per prisoner-minute, for the console's "lasts about N min"
#define OUTPOST_PRISON_MEAL_RATE 0.11
#define OUTPOST_PRISON_SUIT_RATE 0.045
/// Least time between radio lines about prisoners waiting at an empty hatch
#define OUTPOST_PRISON_HATCH_WARNING_GAP (10 MINUTES)
