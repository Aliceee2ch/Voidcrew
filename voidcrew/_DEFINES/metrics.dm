// Round metrics (voidcrew/modules/metrics). Each call to record_metric() becomes one row in
// the `round_metric` SQL table; tally_metric() rows carry a count for the minute they cover.
// The category groups events for querying. Event names are snake_case strings, listed in the
// header of the metrics file that records them.

/// Ship account changes, cash deposits, starting funds.
#define METRIC_ECONOMY "economy"
/// Outpost shop purchases, buybacks and paid outpost services.
#define METRIC_TRADE "trade"
/// Cargo console orders and exports, including the materials market.
#define METRIC_CARGO "cargo"
/// Mission board missions and outpost contracts.
#define METRIC_MISSION "mission"
/// Research points gained and nodes researched.
#define METRIC_RESEARCH "research"
/// Encounters with NPC ships: fights, retreats, kills, boardings, theft, siphons, deals.
#define METRIC_PIRATE "pirate"
/// Player ship lifecycle and crew.
#define METRIC_SHIP "ship"
/// Hit and kill tallies between players, and against NPCs.
#define METRIC_COMBAT "combat"
/// Player deaths and revivals.
#define METRIC_DEATH "death"

/// Rows held in memory while they can't be written. Past this the oldest are dropped.
#define METRIC_MAX_PENDING 20000
/// Rows per INSERT statement.
#define METRIC_BATCH_SIZE 500
/// Flushes in a row that may fail before the held rows are dropped.
#define METRIC_MAX_FAILED_FLUSHES 5
