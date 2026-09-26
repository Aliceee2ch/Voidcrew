// MARKET-OWNER: P1
// Outpost marketplace: shared price keys, the income ledger and service doors (outpost_market.dm)

// Price keys of the shared price table (GLOB.outpost_price_table). Also the ledger's service keys.
#define OUTPOST_PRICE_DOCK_BAY "dock_bay"
#define OUTPOST_PRICE_CLONE_IMPRINT "clone_imprint"
#define OUTPOST_PRICE_MEDLAB_PASS "medlab_pass"
#define OUTPOST_PRICE_STORAGE_RENT "storage_rent"
/// Set by the destination outpost, paid by the traveller at departure (outpost_network.dm)
#define OUTPOST_PRICE_TELEPORT_ARRIVAL "teleport_arrival"
/// Ledger service key for shop sales, which are priced per item rather than from the table
#define OUTPOST_SERVICE_SHOP "shop"

/// Income ledger lines kept per outpost; the treasury's own history keeps 20
#define OUTPOST_SERVICE_LEDGER_MAX 50
/// One price change per user this often
#define OUTPOST_PRICE_SET_COOLDOWN (1 SECONDS)

/// Service door policies (outpost_service_doors.dm)
#define OUTPOST_DOOR_PUBLIC "public"
#define OUTPOST_DOOR_STAFF "staff"

/// Magic recall (the summon item spell) cannot pull an item out of a holder with this trait
#define TRAIT_BLOCKS_RECALL "blocks_recall"

/// A singularity or reality tear neither eats nor pulls this (outpost service room fixtures; see singularity_spares())
#define TRAIT_SINGULARITY_IMMUNE "singularity_immune"
/// Sold by an outpost shop: summon marks made before the sale no longer recall it (sever_magic_recall())
#define TRAIT_RECALL_SEVERED "recall_severed"
/// Trait source for outpost service rooms
#define OUTPOST_SERVICE_TRAIT "outpost_service"
