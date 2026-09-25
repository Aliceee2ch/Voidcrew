// ===== OUTPOST PRISON: CONTRABAND AND MAIL (see outpost_prison_contraband.dm, outpost_prison_mail.dm) =====
// Owner: XF. Values from extras-plan.md 4.14 and 4.15. Neither pays or costs credits. Stashes form
// only from sustained unhappiness (or unopened contraband mail) while someone is on the level to
// see the tells; a shiv stash only matters in a riot (decision 8: shivs come out in riots only).

// ----- Stashes -----
/// Below this mood, held for OUTPOST_CONTRABAND_SOUR_TIME, a prisoner may make a shiv
#define OUTPOST_CONTRABAND_SHIV_MOOD 40
/// At or above this mood the sour clock resets
#define OUTPOST_CONTRABAND_SOUR_RESET 45
/// Seconds under OUTPOST_CONTRABAND_SHIV_MOOD before the first try
#define OUTPOST_CONTRABAND_SOUR_TIME 300
/// Percent chance per minute of starting a shiv, with no staff in sight
#define OUTPOST_CONTRABAND_SHIV_CHANCE 10
/// Seconds of scraping on the bed edge before the shiv goes under the mattress
#define OUTPOST_CONTRABAND_SHIV_TIME 25
/// How far a prisoner making or stashing contraband watches for staff
#define OUTPOST_CONTRABAND_WATCH_RANGE 7
/// Below this mood, held for OUTPOST_CONTRABAND_BREW_SOUR_TIME, a prisoner may brew pruno
#define OUTPOST_CONTRABAND_BREW_MOOD 55
#define OUTPOST_CONTRABAND_BREW_RESET 60
#define OUTPOST_CONTRABAND_BREW_SOUR_TIME 180
/// Percent chance per minute of brewing, with no staff in sight
#define OUTPOST_CONTRABAND_BREW_CHANCE 8
/// Weight of drinking a fermented bag from their own cistern, while under OUTPOST_CONTRABAND_DRINK_MOOD
#define OUTPOST_CONTRABAND_DRINK_WEIGHT 6
#define OUTPOST_CONTRABAND_DRINK_MOOD 70
/// Mood the drinker gains, once
#define OUTPOST_CONTRABAND_PRUNO_MOOD 8
/// Seconds drunk after a bag of pruno
#define OUTPOST_CONTRABAND_DRUNK_TIME 120
/// Fight chance multiplier when either prisoner is drunk, and the wing's spat chance multiplier while anyone is
#define OUTPOST_CONTRABAND_DRUNK_FIGHT_MULT 1.5
#define OUTPOST_CONTRABAND_DRUNK_SPAT_MULT 2
/// Tension each shiv hidden in an occupied cell adds, and the most all of them add
#define OUTPOST_CONTRABAND_SHIV_TENSION 2
#define OUTPOST_CONTRABAND_TENSION_MAX 4
/// How much higher a shiv stash's owner's riot line is
#define OUTPOST_CONTRABAND_RIOT_JOIN_BONUS 10

// ----- Searches -----
/// A mattress search and a pat-down take this long
#define OUTPOST_CONTRABAND_SEARCH_TIME (4 SECONDS)
/// Mood the cell's owner loses when a search finds something, and when it finds nothing
#define OUTPOST_CONTRABAND_FOUND_MOOD 3
#define OUTPOST_CONTRABAND_EMPTY_MOOD 6
/// Mood each other prisoner who sees an empty search loses
#define OUTPOST_CONTRABAND_ONLOOKER_MOOD 1
/// Mood a pat-down that finds nothing costs
#define OUTPOST_CONTRABAND_PATDOWN_MOOD 3
/// A cell's search, or a prisoner's pat-down, costs mood at most once per this
#define OUTPOST_CONTRABAND_SEARCH_GAP (5 MINUTES)

// ----- Mail -----
/// Between letters, counted only while the crew is home
#define OUTPOST_MAIL_GAP_MIN (6 MINUTES)
#define OUTPOST_MAIL_GAP_MAX (10 MINUTES)
/// Undelivered letters at once
#define OUTPOST_MAIL_MAX_WAITING 2
/// Seconds of sentence a prisoner needs left to get a letter; one letter per stay
#define OUTPOST_MAIL_MIN_SENTENCE 180
/// An undelivered letter is returned (deleted) after this long with the crew home, and its prisoner loses OUTPOST_MAIL_EXPIRED_MOOD
#define OUTPOST_MAIL_EXPIRY (10 MINUTES)
#define OUTPOST_MAIL_EXPIRED_MOOD 3
/// Letter kinds by weight, and the mood each gives the reader
#define OUTPOST_MAIL_WEIGHT_GOOD 30
#define OUTPOST_MAIL_WEIGHT_KID 15
#define OUTPOST_MAIL_WEIGHT_NEWS 20
#define OUTPOST_MAIL_WEIGHT_BAD 25
#define OUTPOST_MAIL_WEIGHT_CONTRABAND 10
#define OUTPOST_MAIL_MOOD_GOOD 8
#define OUTPOST_MAIL_MOOD_KID 10
#define OUTPOST_MAIL_MOOD_NEWS 4
#define OUTPOST_MAIL_MOOD_BAD -8
/// Extra mood a prisoner loses reading a letter someone opened first
#define OUTPOST_MAIL_OPENED_MOOD 6
/// Percent of contraband letters that feel hard on examine
#define OUTPOST_MAIL_HARD_TELL 70
/// Percent of contraband letters carrying a razor blade (a shiv stash); the rest carry yeast (pruno)
#define OUTPOST_MAIL_RAZOR_CHANCE 60
