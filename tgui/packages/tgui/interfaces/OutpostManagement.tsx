import {
  type ReactNode,
  type PointerEvent as ReactPointerEvent,
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
  Button,
  Dropdown,
  Icon,
  Input,
  KeyListener,
  NumberInput,
  TextArea,
} from 'tgui-core/components';
import type { KeyEvent } from 'tgui-core/events';
import { acquireHotKey, releaseHotKey } from 'tgui-core/hotkeys';
import { KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_UP } from 'tgui-core/keycodes';
import type { BooleanLike } from 'tgui-core/react';
import { resolveAsset } from '../assets';
import { useBackend } from '../backend';
import { Window } from '../layouts';

// Matches the existing 1200 x 760 console plate, including its inset borders.
const FRAME = { width: 1200, height: 760 };
const PANELS = {
  identity: [8, 6, 470, 30],
  owner: [486, 6, 430, 30],
  status: [924, 6, 268, 30],
  directory: [10, 50, 586, 556],
  registry: [606, 50, 586, 556],
  broadcast: [10, 616, 586, 136],
  command: [606, 616, 586, 136],
  placement: [10, 50, 1182, 556],
} as const;

type Vessel = { ref: string; name: string };
type Candidate = Vessel & {
  ckey: string;
  is_resident?: BooleanLike;
};
type Resident = Vessel & {
  is_self: BooleanLike;
  active: BooleanLike;
  steward: BooleanLike;
  treasurer: BooleanLike;
  pricer?: BooleanLike;
};
type ShipBay = {
  ref: string;
  number: number;
  ship: string | null;
  status: string;
  arrived: BooleanLike;
  requested: BooleanLike;
  approved: BooleanLike;
  /** Eviction keys: absent until the dock fee package sends them. */
  evict_denial?: string | null;
  evicting?: BooleanLike;
  /** Seconds until the ship is sent off. */
  evict_eta?: number;
  /** Credits refunded if evicted now; 0 for none. */
  evict_refund?: number;
};

// ===== Marketplace (Pricing and Services tabs) =====

type PriceRow = {
  key: string;
  label: string;
  value: number;
  default: number;
  max: number;
  available: BooleanLike;
};
type ShopSummary = {
  installed?: BooleanLike;
  open?: BooleanLike;
  listings?: number;
  priced?: number;
  unpriced?: number;
  items?: number;
  capacity?: number;
};
type LedgerEntry = {
  time: string;
  service: string;
  label: string;
  payer: string;
  account: string;
  amount: number;
};
type ServiceTotal = { service: string; total: number; count: number };
type Pricing = {
  prices?: PriceRow[];
  shop?: ShopSummary | null;
  ledger?: LedgerEntry[] | null;
  totals?: ServiceTotal[] | null;
};
type CloningVat = {
  ref: string;
  state: 'empty' | 'growing' | 'ready' | 'offline' | string;
  holder: string | null;
  percent: number;
  paid: number;
  evict_denial: string | null;
};
type CloningDetail = {
  kind: 'cloning';
  price?: number;
  can_evict?: BooleanLike;
  vats?: CloningVat[];
};
type ShopDetail = ShopSummary & { kind: 'shop'; can_toggle?: BooleanLike };
type MedicalDetail = {
  kind: 'medical';
  price?: number;
  pass_minutes?: number;
  active_passes?: number;
  can_edit?: BooleanLike;
  procedures?: { id: string; name: string; enabled: BooleanLike }[];
};
type StorageDetail = {
  kind: 'storage';
  price?: number;
  lockers?: number;
  rented?: number;
};
type NetworkPad = { id: string; name: string; zone?: number | string | null };
/** grounding-teleporter §7.5; `policy`, `allow` and `trips` are the older spec names. */
type TeleporterDetail = {
  kind: 'teleporter';
  installed?: BooleanLike;
  padName?: string;
  arrivals?: string;
  policy?: string;
  allowlist?: NetworkPad[];
  candidates?: NetworkPad[];
  /** Seconds left on the raid lock. */
  raidLockLeft?: number;
  /** Why visitors cannot arrive right now (lockdown, raid lock, request mode), if anything. */
  policyNote?: string | null;
  fee?: number;
  price?: number;
  can_edit?: BooleanLike;
  tripsIn?: number;
  tripsOut?: number;
  trips?: number;
  destinations?: number;
};
type ServiceDetail =
  | CloningDetail
  | ShopDetail
  | MedicalDetail
  | StorageDetail
  | TeleporterDetail;
type ServiceRoom = {
  id: string;
  name: string;
  visitors_allowed?: BooleanLike;
  can_toggle_visitors?: BooleanLike;
  detail?: ServiceDetail | { kind?: string; [key: string]: unknown } | null;
};
type UpgradeEntry = {
  id: string;
  name: string;
  desc: string;
  price: number;
  width: number;
  height: number;
  /** BYOND dir of the entrance edge as authored */
  entrance: number;
  preview: string | null;
};
type UpgradeStatus = {
  id: string;
  state: 'available' | 'ready' | 'installed';
  denial: string | null;
  manage_denial: string | null;
};
/** One character per tile, rows from the bottom-left corner (see build_upgrade_survey()). */
type UpgradeSurvey = {
  x: number;
  y: number;
  z: number;
  width: number;
  height: number;
  cells: string;
  near: string;
};
type ResearchConnection = {
  ref: string;
  ship: string;
  server: string;
  status: string;
  approved: BooleanLike;
};
export type OutpostData = {
  linked: BooleanLike;
  outpost_name: string;
  founder_name: string | null;
  memo: string;
  is_owner: BooleanLike;
  has_owner: BooleanLike;
  can_claim: BooleanLike;
  can_manage: BooleanLike;
  can_spend: BooleanLike;
  can_set_prices: BooleanLike;
  /** Treasury user: picks the service silo. Older servers used can_set_prices. */
  can_select_silo?: BooleanLike;
  can_view_income?: BooleanLike;
  /** This user is billed as a visitor (admin testing aid). */
  playtest_visitor?: BooleanLike;
  pricing?: Pricing | null;
  services?: ServiceRoom[] | null;
  /** The last refusal from a pricing, service room or eviction action; null once one succeeds. */
  market_error?: string | null;
  /** Ship names whose crews count as members (abuse review F-12). */
  owner_crews?: (string | Vessel)[] | null;
  /** grounding-teleporter §7.5 top-level shape, used when no service row carries it. */
  teleporter?: Omit<TeleporterDetail, 'kind'> | null;
  treasury_balance: number;
  service_silo: string | null;
  service_silos: Vessel[];
  ship_bay_materials: { name: string; sheets: number; available: number }[];
  raidable: BooleanLike;
  dock_mode: string;
  rename_cooldown: number;
  advert_cost: number;
  advert_cooldown: number;
  advert_remaining: number;
  advert_denial: string | null;
  advert_error: string | null;
  dock_requests: Vessel[];
  approved_ships: Vessel[];
  banned_ships: Vessel[];
  builders: string[];
  candidates: Candidate[];
  resident_mode: string;
  resident_active: number;
  arrival_available: BooleanLike;
  residents: Resident[];
  resident_invites: Record<string, BooleanLike>;
  resident_blocked: string[];
  research_servers: Vessel[];
  research_ships: Vessel[];
  research_connections: ResearchConnection[];
  research_error: string | null;
  ship_bay_installed: BooleanLike;
  ship_bay_cost: number;
  ship_bay_denial: string | null;
  ship_bay_error: string | null;
  ship_bays: ShipBay[];
  upgrade_catalog: UpgradeEntry[];
  upgrades: UpgradeStatus[];
  upgrade_error: string | null;
  upgrade_surveying: BooleanLike;
  upgrade_survey?: UpgradeSurvey | null;
};
type Act = (action: string, params?: Record<string, unknown>) => unknown;
type Props = { data: OutpostData; act: Act };

function Panel({
  slot,
  children,
  className = '',
}: {
  slot: keyof typeof PANELS;
  children: ReactNode;
  className?: string;
}) {
  const [x, y, width, height] = PANELS[slot];
  return (
    <div
      className={`Outpost__panel Outpost__panel--${slot} ${className}`}
      style={{
        left: `${(x / FRAME.width) * 100}%`,
        top: `${(y / FRAME.height) * 100}%`,
        width: `${(width / FRAME.width) * 100}%`,
        height: `${(height / FRAME.height) * 100}%`,
      }}
    >
      {children}
    </div>
  );
}

function Empty({ icon, children }: { icon: string; children: ReactNode }) {
  return (
    <div className="Outpost__empty">
      <Icon name={icon} />
      <span>{children}</span>
    </div>
  );
}

/** Silo choice belongs to treasury users; older servers only sent can_set_prices. */
function canSelectSilo(data: OutpostData) {
  return data.can_select_silo === undefined
    ? !!data.can_set_prices
    : !!data.can_select_silo;
}

/** Whole seconds as m:ss. */
function clock(seconds?: number | null) {
  const total = Math.max(0, Math.ceil(Number(seconds) || 0));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
}

function credits(amount?: number | null) {
  const value = Number(amount) || 0;
  return value > 0 ? `${value.toLocaleString()} cr` : 'Free';
}

/** Evict or cancel for one bay row. Hidden until the server sends eviction keys. */
function BayEviction({ bay, data, act }: Props & { bay: ShipBay }) {
  if (bay.evict_denial === undefined && !bay.evicting) {
    return null;
  }
  if (bay.evicting) {
    return (
      <>
        <span className="Outpost__countdown" title="Time left to undock">
          <Icon name="stopwatch" /> {clock(bay.evict_eta)}
        </span>
        <Button
          icon="xmark"
          disabled={!data.can_manage}
          tooltip="Cancel the eviction"
          onClick={() => act('cancel_bay_eviction', { ref: bay.ref })}
        >
          Cancel
        </Button>
      </>
    );
  }
  if (!bay.ship) {
    return null;
  }
  const refund = Number(bay.evict_refund) || 0;
  return (
    <Button.Confirm
      icon="right-from-bracket"
      color="bad"
      disabled={!data.can_manage || !!bay.evict_denial}
      tooltip={
        bay.evict_denial ||
        (refund > 0
          ? `Three minutes to undock. Refunds ${refund} cr.`
          : 'Three minutes to undock. No refund.')
      }
      onClick={() => act('evict_bay_ship', { ref: bay.ref })}
    >
      Evict
    </Button.Confirm>
  );
}

function Residents({ data, act }: Props) {
  const { residents = [], candidates = [], builders = [] } = data;
  const crews = (data.owner_crews || [])
    .map((crew) => (typeof crew === 'string' ? crew : crew?.name))
    .filter(Boolean);
  return (
    <>
      {data.owner_crews ? (
        <div className="Outpost__quiet">
          {crews.length
            ? `Owner's crews: ${crews.join(', ')}. Their crew use services free.`
            : "Owner's crews: none"}
        </div>
      ) : null}
      <div className="Outpost__section-label">
        Residents <span>{residents.length}</span>
      </div>
      {residents.length === 0 && <Empty icon="users">No residents</Empty>}
      {residents.map((person) => (
        <div className="Outpost__row" key={person.ref}>
          <span
            className={`Outpost__dot ${person.active ? 'Outpost__dot--online' : ''}`}
          />
          <div className="Outpost__person">
            <strong>{person.name}</strong>
            <small>{person.active ? 'Active' : 'Away'}</small>
          </div>
          {!!data.is_owner && (
            <>
              <Button
                icon="id-badge"
                selected={!!person.steward}
                tooltip="Management"
                onClick={() =>
                  act('delegate', { ref: person.ref, role: 'steward' })
                }
              />
              <Button
                icon="coins"
                selected={!!person.treasurer}
                tooltip="Treasury"
                onClick={() =>
                  act('delegate', { ref: person.ref, role: 'treasurer' })
                }
              />
              <Button
                icon="tags"
                selected={!!person.pricer}
                tooltip="Pricing: sets service prices and takes shop stock free"
                onClick={() =>
                  act('delegate', { ref: person.ref, role: 'pricer' })
                }
              />
            </>
          )}
          <Button
            icon="user-minus"
            tooltip={
              person.is_self ? 'You cannot remove yourself' : 'Remove resident'
            }
            disabled={!data.can_manage || !!person.is_self}
            onClick={() => act('remove_resident', { ref: person.ref })}
          />
        </div>
      ))}
      <div className="Outpost__section-label">
        On site <span>{candidates.length}</span>
      </div>
      {candidates.length === 0 && (
        <Empty icon="location-dot">Nobody else on site</Empty>
      )}
      {candidates.map((person) => (
        <div className="Outpost__row" key={person.ref}>
          <div className="Outpost__person">
            <strong>{person.name}</strong>
            <small>{person.ckey}</small>
          </div>
          <Button
            icon="user-plus"
            tooltip="Add resident"
            selected={!!person.is_resident}
            disabled={!data.can_manage || !!person.is_resident}
            onClick={() => act('add_resident', { ref: person.ref })}
          />
          {!!data.is_owner && (
            <Button
              icon="hammer"
              tooltip="Construction"
              selected={builders.includes(person.ckey)}
              onClick={() =>
                act(
                  builders.includes(person.ckey)
                    ? 'remove_builder'
                    : 'add_builder',
                  { ref: person.ref, ckey: person.ckey },
                )
              }
            />
          )}
        </div>
      ))}
    </>
  );
}

function Docking({ data, act }: Props) {
  const groups = [
    { title: 'Requests', ships: data.dock_requests || [], kind: 'request' },
    { title: 'Cleared', ships: data.approved_ships || [], kind: 'approved' },
    { title: 'Blocked', ships: data.banned_ships || [], kind: 'banned' },
  ];
  return (
    <>
      <div className="Outpost__section-label">Ship bay</div>
      <div className="Outpost__field-label">Outpost material source</div>
      <Dropdown
        width="100%"
        disabled={!canSelectSilo(data) || !data.service_silos?.length}
        selected={data.service_silo || ''}
        options={(data.service_silos || []).map((silo) => ({
          value: silo.ref,
          displayText: silo.name,
        }))}
        placeholder="No outpost silo selected"
        onSelected={(ref) => act('select_service_silo', { ref })}
      />
      <div className="Outpost__quiet">Treasury: {data.treasury_balance} cr</div>
      {data.ship_bay_installed ? (
        <div className="Outpost__quiet">
          Permanent bay installed. Select Ship Bay at the helm or visit by
          elevator.
        </div>
      ) : (
        <div className="Outpost__row">
          <span className="Outpost__grow">
            One permanent construction bay: {data.ship_bay_cost} cr, 100 iron,
            50 glass.
          </span>
          <Button
            disabled={!!data.ship_bay_denial}
            tooltip={
              data.ship_bay_denial || 'Paid from the outpost treasury and silo'
            }
            onClick={() => act('install_ship_bay')}
          >
            Install
          </Button>
        </div>
      )}
      {!!data.ship_bay_error && (
        <div className="Outpost__quiet">{data.ship_bay_error}</div>
      )}
      {!data.ship_bay_installed && (
        <div className="Outpost__quiet">
          {(data.ship_bay_materials || []).map((material) => (
            <div key={material.name}>
              {material.name}: {Math.floor(material.available)} /{' '}
              {material.sheets} sheets
            </div>
          ))}
          {!!data.ship_bay_denial && <div>{data.ship_bay_denial}</div>}
        </div>
      )}
      {(data.ship_bays || []).map((bay) => (
        <div className="Outpost__row" key={bay.ref}>
          <span className="Outpost__grow">
            Bay {bay.number}: {bay.ship || bay.status}{' '}
            {!!bay.ship && `(${bay.status})`}
          </span>
          {!!bay.requested && (
            <Button
              disabled={!data.can_spend || !data.can_manage}
              tooltip="Allow this bay to use the outpost silo for this visit"
              onClick={() => act('approve_bay_silo', { ref: bay.ref })}
            >
              Allow materials
            </Button>
          )}
          {(!!bay.requested || !!bay.approved) && (
            <Button
              disabled={!data.can_spend || !data.can_manage}
              onClick={() => act('revoke_bay_silo', { ref: bay.ref })}
            >
              {bay.approved ? 'Revoke materials' : 'Deny'}
            </Button>
          )}
          <BayEviction bay={bay} data={data} act={act} />
        </div>
      ))}
      {groups.map(({ title, ships, kind }) => (
        <div key={kind}>
          <div className="Outpost__section-label">
            {title}
            <span>{ships.length}</span>
          </div>
          {ships.length === 0 && <div className="Outpost__quiet">None</div>}
          {ships.map((ship) => (
            <div className="Outpost__row" key={ship.ref}>
              <Icon name="shuttle-space" />
              <strong className="Outpost__grow">{ship.name}</strong>
              {kind === 'request' && (
                <Button
                  icon="check"
                  color="good"
                  tooltip="Clear approach"
                  disabled={!data.can_manage}
                  onClick={() => act('approve_request', { ref: ship.ref })}
                />
              )}
              <Button
                icon={kind === 'banned' ? 'unlock' : 'xmark'}
                tooltip={
                  kind === 'banned'
                    ? 'Unblock vessel'
                    : kind === 'request'
                      ? 'Deny approach'
                      : 'Revoke clearance'
                }
                disabled={!data.can_manage}
                onClick={() =>
                  act(
                    kind === 'banned'
                      ? 'unban_ship'
                      : kind === 'request'
                        ? 'deny_request'
                        : 'revoke_approval',
                    { ref: ship.ref },
                  )
                }
              />
              {kind !== 'banned' && (
                <Button
                  icon="ban"
                  tooltip="Block vessel"
                  disabled={!data.can_manage}
                  onClick={() => act('ban_ship', { ref: ship.ref })}
                />
              )}
            </div>
          ))}
        </div>
      ))}
    </>
  );
}

const UPGRADE_STATES = {
  available: 'Available',
  ready: 'Ready to place',
  installed: 'Installed',
};

function upgradePrice(price: number) {
  return price > 0 ? `${price} cr` : 'Free';
}

/** Tooltip for Cancel purchase: the denial, else the refund when there is one. */
function refundTooltip(price: number, denial?: string | null) {
  return denial || (price > 0 ? `Refund ${price} cr` : undefined);
}

type UpgradesProps = Props & { onPlace: (id: string) => void };

function Upgrades({ data, act, onPlace }: UpgradesProps) {
  const [index, setIndex] = useState(0);
  const catalog = data.upgrade_catalog || [];
  if (catalog.length === 0) {
    return <Empty icon="cubes">No upgrades</Empty>;
  }
  const current = Math.min(index, catalog.length - 1);
  const upgrade = catalog[current];
  const status = (data.upgrades || []).find((entry) => entry.id === upgrade.id);
  const state = status?.state || 'available';
  const step = (delta: number) =>
    setIndex((current + delta + catalog.length) % catalog.length);
  return (
    <>
      <div className="Outpost__carousel">
        <Button
          icon="chevron-left"
          disabled={catalog.length < 2}
          onClick={() => step(-1)}
        />
        <strong className="Outpost__grow">{upgrade.name}</strong>
        <Button
          icon="chevron-right"
          disabled={catalog.length < 2}
          onClick={() => step(1)}
        />
      </div>
      <div className="Outpost__preview">
        {upgrade.preview ? (
          <img src={resolveAsset(upgrade.preview)} alt={upgrade.name} />
        ) : (
          <Empty icon="image">No preview</Empty>
        )}
      </div>
      <div className="Outpost__quiet">{upgrade.desc}</div>
      <div className="Outpost__row">
        <span className="Outpost__grow">Size</span>
        <span>{`${upgrade.width}×${upgrade.height}`}</span>
      </div>
      <div className="Outpost__row">
        <span className="Outpost__grow">Price</span>
        <span>{upgradePrice(upgrade.price)}</span>
      </div>
      <div className="Outpost__row">
        <span className="Outpost__grow">State</span>
        <span>{UPGRADE_STATES[state]}</span>
      </div>
      <div className="Outpost__row">
        <span className="Outpost__grow">
          Treasury: {data.treasury_balance} cr
        </span>
        {state === 'available' ? (
          <Button.Confirm
            icon="cart-shopping"
            disabled={!status || !!status.denial}
            tooltip={status?.denial || undefined}
            onClick={() => act('buy_upgrade', { id: upgrade.id })}
          >
            Buy
          </Button.Confirm>
        ) : null}
        {state === 'ready' ? (
          <>
            <Button
              icon="map-location-dot"
              disabled={!!status?.manage_denial}
              tooltip={status?.manage_denial || undefined}
              onClick={() => onPlace(upgrade.id)}
            >
              Place
            </Button>
            <Button.Confirm
              icon="rotate-left"
              color="bad"
              disabled={!!status?.manage_denial}
              tooltip={refundTooltip(upgrade.price, status?.manage_denial)}
              onClick={() => act('cancel_upgrade', { id: upgrade.id })}
            >
              Cancel purchase
            </Button.Confirm>
          </>
        ) : null}
      </div>
      {data.upgrade_error ? (
        <div className="Outpost__research-error" role="alert">
          {data.upgrade_error}
        </div>
      ) : null}
    </>
  );
}

// ===== Placement map =====

/** Opening pixels per tile. The canvas shows 36 x 28 tiles at this zoom. */
const MAP_TILE = 16;
const MAP_WIDTH = 36 * MAP_TILE;
const MAP_HEIGHT = 28 * MAP_TILE;
/** Pixels per tile the wheel steps through. */
const ZOOM_STEPS = [4, 6, 8, 12, 16, 24];
/** Wheel travel per zoom step. A mouse notch is about 100; touchpads send many small deltas. */
const WHEEL_STEP = 60;
/** Survey cells an upgrade may cover: space, lattice, floor. */
const OPEN_CELLS = 'slf';
const CELL_COLORS: Record<string, string> = {
  s: '#07090b',
  l: '#27313b',
  f: '#474d54',
  w: '#9ca0a5',
  g: '#4f9fc4',
  d: '#d3a24c',
  m: '#8b5c34',
  x: '#5e2323',
};
const LEGEND: [string, string][] = [
  ['f', 'Floor'],
  ['w', 'Wall'],
  ['g', 'Window'],
  ['d', 'Door'],
  ['m', 'Object'],
  ['x', 'No build'],
];
const PAN_KEYS: Record<number, [number, number]> = {
  [KEY_LEFT]: [-1, 0],
  [KEY_RIGHT]: [1, 0],
  [KEY_UP]: [0, 1],
  [KEY_DOWN]: [0, -1],
};
/** Clockwise from north, as BYOND dirs. */
const CLOCKWISE_DIRS = [1, 4, 2, 8];
const DIR_NAMES: Record<number, string> = {
  1: 'north',
  2: 'south',
  4: 'east',
  8: 'west',
};

type Tile = { x: number; y: number };
type Footprint = {
  origin: Tile;
  width: number;
  height: number;
  blocked: Tile[];
  reason: string | null;
};

/** Index of a world tile in the survey strings, or -1 outside the surveyed region. */
function surveyIndex(survey: UpgradeSurvey, x: number, y: number) {
  const column = x - survey.x;
  const row = y - survey.y;
  if (column < 0 || row < 0 || column >= survey.width || row >= survey.height) {
    return -1;
  }
  return row * survey.width + column;
}

/** The same rule the server applies: every tile open, one tile near outpost ground. */
function checkFootprint(
  survey: UpgradeSurvey,
  origin: Tile,
  width: number,
  height: number,
): Footprint {
  const blocked: Tile[] = [];
  let outside = false;
  let near = false;
  for (let dx = 0; dx < width; dx++) {
    for (let dy = 0; dy < height; dy++) {
      const tile = { x: origin.x + dx, y: origin.y + dy };
      const index = surveyIndex(survey, tile.x, tile.y);
      if (index < 0) {
        outside = true;
        blocked.push(tile);
        continue;
      }
      if (!OPEN_CELLS.includes(survey.cells[index])) {
        blocked.push(tile);
      }
      if (survey.near[index] === '1') {
        near = true;
      }
    }
  }
  const reason = outside
    ? 'Out of range'
    : blocked.length > 0
      ? 'Blocked'
      : !near
        ? 'Too far from the outpost'
        : null;
  return { origin, width, height, blocked, reason };
}

/** The footprint of the room centred on a tile, at the given rotation. */
function ghostFootprint(
  survey: UpgradeSurvey | null,
  anchor: Tile | null,
  upgrade: UpgradeEntry,
  rotation: number,
): Footprint | null {
  if (!survey || !anchor) {
    return null;
  }
  const turned = rotation === 90 || rotation === 270;
  const width = turned ? upgrade.height : upgrade.width;
  const height = turned ? upgrade.width : upgrade.height;
  return checkFootprint(
    survey,
    {
      x: anchor.x - Math.floor(width / 2),
      y: anchor.y - Math.floor(height / 2),
    },
    width,
    height,
  );
}

type Point = { x: number; y: number };
/** x and y: the world tile position of the canvas's bottom-left corner, fractional while dragging. */
type Camera = { x: number; y: number; zoom: number };

/** World pixels left of and below the canvas, rounded so tile edges land on whole pixels. */
function cameraOffset(camera: Camera): Point {
  return {
    x: Math.round(camera.x * camera.zoom),
    y: Math.round(camera.y * camera.zoom),
  };
}

/** Canvas pixel of a world position in tiles, y up. */
function toCanvas(camera: Camera, world: Point): Point {
  const offset = cameraOffset(camera);
  return {
    x: world.x * camera.zoom - offset.x,
    y: MAP_HEIGHT - (world.y * camera.zoom - offset.y),
  };
}

function toWorld(camera: Camera, point: Point): Point {
  const offset = cameraOffset(camera);
  return {
    x: (point.x + offset.x) / camera.zoom,
    y: (MAP_HEIGHT - point.y + offset.y) / camera.zoom,
  };
}

/** The tile under a canvas pixel, or null off the canvas. */
function tileAt(camera: Camera, point: Point | null): Tile | null {
  if (
    !point ||
    point.x < 0 ||
    point.y < 0 ||
    point.x >= MAP_WIDTH ||
    point.y >= MAP_HEIGHT
  ) {
    return null;
  }
  const world = toWorld(camera, point);
  return { x: Math.floor(world.x), y: Math.ceil(world.y) - 1 };
}

/** Canvas pixel under a client position, whatever the canvas's CSS size. */
function canvasPoint(
  canvas: HTMLCanvasElement,
  clientX: number,
  clientY: number,
): Point | null {
  const rect = canvas.getBoundingClientRect();
  if (!rect.width || !rect.height) {
    return null;
  }
  return {
    x: ((clientX - rect.left) * MAP_WIDTH) / rect.width,
    y: ((clientY - rect.top) * MAP_HEIGHT) / rect.height,
  };
}

/** Keeps the view over the surveyed region, centring it when the region is smaller. */
function clampAxis(value: number, start: number, size: number, span: number) {
  if (size <= span) {
    return start - (span - size) / 2;
  }
  return Math.min(Math.max(value, start), start + size - span);
}

function clampCamera(camera: Camera, survey: UpgradeSurvey): Camera {
  return {
    x: clampAxis(camera.x, survey.x, survey.width, MAP_WIDTH / camera.zoom),
    y: clampAxis(camera.y, survey.y, survey.height, MAP_HEIGHT / camera.zoom),
    zoom: camera.zoom,
  };
}

/** Zooming out stops at the first step that shows the whole survey. */
function minZoom(survey: UpgradeSurvey) {
  let zoom = ZOOM_STEPS[0];
  for (const step of ZOOM_STEPS) {
    if (
      step <= MAP_TILE &&
      survey.width * step <= MAP_WIDTH &&
      survey.height * step <= MAP_HEIGHT
    ) {
      zoom = step;
    }
  }
  return zoom;
}

/** One zoom step in or out, keeping the world point under `point` where it is. */
function zoomCamera(
  camera: Camera,
  survey: UpgradeSurvey,
  point: Point,
  direction: number,
): Camera {
  const zoom = ZOOM_STEPS[ZOOM_STEPS.indexOf(camera.zoom) + direction];
  if (zoom === undefined || zoom < minZoom(survey)) {
    return camera;
  }
  const world = toWorld(camera, point);
  return clampCamera(
    {
      x: world.x - point.x / zoom,
      y: world.y - (MAP_HEIGHT - point.y) / zoom,
      zoom,
    },
    survey,
  );
}

function hexColor(hex: string) {
  return [1, 3, 5].map((start) => parseInt(hex.slice(start, start + 2), 16));
}

/** Pixel colour per cell class. */
const CELL_PIXELS: Record<string, number[]> = {};
for (const [cell, hex] of Object.entries(CELL_COLORS)) {
  CELL_PIXELS[cell] = hexColor(hex);
}

/** The build range border. Keep in step with $range in OutpostManagement.scss. */
const RANGE_COLOR = '#e03c3c';
/** Canvas pixels, at every zoom. */
const RANGE_LINE = 2;

/** x1, y1, x2, y2 in world tiles: one straight run of tile edges. */
export type Segment = [number, number, number, number];

/**
 * Every tile edge between an in-range tile and an out-of-range tile or the survey
 * edge, with runs along one line merged. Built once per survey.
 */
export function rangeOutline(survey: UpgradeSurvey): Segment[] {
  const { x, y, width, height, near } = survey;
  const inside = (column: number, row: number) =>
    column >= 0 &&
    row >= 0 &&
    column < width &&
    row < height &&
    near[row * width + column] === '1';
  const segments: Segment[] = [];
  // The line along the bottom of each row, plus the top of the last one.
  for (let row = 0; row <= height; row++) {
    let start = -1;
    for (let column = 0; column <= width; column++) {
      const edge =
        column < width && inside(column, row) !== inside(column, row - 1);
      if (edge && start < 0) {
        start = column;
      } else if (!edge && start >= 0) {
        segments.push([x + start, y + row, x + column, y + row]);
        start = -1;
      }
    }
  }
  // The line along the left of each column, plus the right of the last one.
  for (let column = 0; column <= width; column++) {
    let start = -1;
    for (let row = 0; row <= height; row++) {
      const edge =
        row < height && inside(column, row) !== inside(column - 1, row);
      if (edge && start < 0) {
        start = row;
      } else if (!edge && start >= 0) {
        segments.push([x + column, y + start, x + column, y + row]);
        start = -1;
      }
    }
  }
  return segments;
}

/** Strokes the build range border with the current camera. Off-canvas runs are skipped. */
function drawOutline(
  context: CanvasRenderingContext2D,
  camera: Camera,
  outline: Segment[],
) {
  if (outline.length === 0) {
    return;
  }
  const { zoom } = camera;
  const offset = cameraOffset(camera);
  const margin = RANGE_LINE;
  context.save();
  context.beginPath();
  for (const [x1, y1, x2, y2] of outline) {
    const left = x1 * zoom - offset.x;
    const right = x2 * zoom - offset.x;
    const bottom = MAP_HEIGHT - (y1 * zoom - offset.y);
    const top = MAP_HEIGHT - (y2 * zoom - offset.y);
    if (
      right < -margin ||
      left > MAP_WIDTH + margin ||
      bottom < -margin ||
      top > MAP_HEIGHT + margin
    ) {
      continue;
    }
    context.moveTo(left, bottom);
    context.lineTo(right, top);
  }
  context.strokeStyle = RANGE_COLOR;
  context.lineWidth = RANGE_LINE;
  // Square caps fill the outer pixel where two runs meet at a corner.
  context.lineCap = 'square';
  context.stroke();
  context.restore();
}

/** The survey at one pixel per tile, drawn once per survey and scaled up every frame. */
function renderSurvey(survey: UpgradeSurvey): HTMLCanvasElement | null {
  const { width, height, cells } = survey;
  const bitmap = document.createElement('canvas');
  bitmap.width = width;
  bitmap.height = height;
  const context = bitmap.getContext('2d');
  if (!context || width < 1 || height < 1) {
    return null;
  }
  const pixels = context.createImageData(width, height);
  for (let row = 0; row < height; row++) {
    // Survey rows run up from the bottom, bitmap rows down from the top.
    let offset = (height - 1 - row) * width * 4;
    for (let column = 0; column < width; column++) {
      const color = CELL_PIXELS[cells[row * width + column]] || [0, 0, 0];
      pixels.data[offset] = color[0];
      pixels.data[offset + 1] = color[1];
      pixels.data[offset + 2] = color[2];
      pixels.data[offset + 3] = 255;
      offset += 4;
    }
  }
  context.putImageData(pixels, 0, 0);
  return bitmap;
}

type MapMenu = {
  tile: Tile;
  /** The clicked spot in world tiles; the menu follows it when the view moves. */
  point: Point;
};
type MapScene = {
  survey: UpgradeSurvey | null;
  bitmap: HTMLCanvasElement | null;
  outline: Segment[];
  image: HTMLImageElement | null;
  upgrade: UpgradeEntry;
  rotation: number;
  menu: MapMenu | null;
};

function drawMap(
  canvas: HTMLCanvasElement,
  scene: MapScene,
  camera: Camera | null,
  hover: Tile | null,
) {
  const context = canvas.getContext('2d');
  if (!context) {
    return;
  }
  context.fillStyle = '#000';
  context.fillRect(0, 0, MAP_WIDTH, MAP_HEIGHT);
  const { survey, bitmap, outline, image, upgrade, rotation, menu } = scene;
  if (!survey || !bitmap || !camera) {
    return;
  }
  const { zoom } = camera;
  const corner = toCanvas(camera, {
    x: survey.x,
    y: survey.y + survey.height,
  });
  context.imageSmoothingEnabled = false;
  context.drawImage(
    bitmap,
    corner.x,
    corner.y,
    survey.width * zoom,
    survey.height * zoom,
  );
  drawOutline(context, camera, outline);
  const footprint = ghostFootprint(
    survey,
    menu ? menu.tile : hover,
    upgrade,
    rotation,
  );
  if (!footprint) {
    return;
  }
  const { x: left, y: top } = toCanvas(camera, {
    x: footprint.origin.x,
    y: footprint.origin.y + footprint.height,
  });
  const pixelWidth = footprint.width * zoom;
  const pixelHeight = footprint.height * zoom;
  if (image) {
    context.save();
    // The preview is much finer than the map, so smooth it as it shrinks.
    context.imageSmoothingEnabled = true;
    context.globalAlpha = 0.75;
    context.translate(left + pixelWidth / 2, top + pixelHeight / 2);
    // Canvas y points down, so a positive angle turns clockwise like the game's rotation.
    context.rotate((rotation * Math.PI) / 180);
    context.drawImage(
      image,
      (-upgrade.width * zoom) / 2,
      (-upgrade.height * zoom) / 2,
      upgrade.width * zoom,
      upgrade.height * zoom,
    );
    context.restore();
  }
  const valid = !footprint.reason;
  context.fillStyle = valid
    ? 'rgba(90, 200, 110, 0.22)'
    : 'rgba(220, 60, 60, 0.22)';
  context.fillRect(left, top, pixelWidth, pixelHeight);
  context.fillStyle = 'rgba(230, 50, 50, 0.55)';
  for (const tile of footprint.blocked) {
    const spot = toCanvas(camera, { x: tile.x, y: tile.y + 1 });
    context.fillRect(spot.x, spot.y, zoom, zoom);
  }
  const line = zoom < 8 ? 1 : 2;
  context.strokeStyle = valid ? '#6fd08a' : '#e05555';
  context.lineWidth = line;
  context.strokeRect(
    left + line / 2,
    top + line / 2,
    pixelWidth - line,
    pixelHeight - line,
  );
}

function usePreviewImage(name: string | null) {
  const [image, setImage] = useState<HTMLImageElement | null>(null);
  useEffect(() => {
    setImage(null);
    if (!name) {
      return;
    }
    let live = true;
    const loading = new Image();
    loading.onload = () => {
      if (live) {
        setImage(loading);
      }
    };
    loading.src = resolveAsset(name);
    return () => {
      live = false;
    };
  }, [name]);
  return image;
}

type PlacementProps = Props & {
  upgrade: UpgradeEntry;
  status: UpgradeStatus | undefined;
  onBack: () => void;
};

function UpgradePlacement({
  data,
  act,
  upgrade,
  status,
  onBack,
}: PlacementProps) {
  const survey = data.upgrade_survey || null;
  const surveying = !!data.upgrade_surveying || !survey;
  const [rotation, setRotation] = useState(0);
  const [camera, setCamera] = useState<Camera | null>(null);
  const [hover, setHover] = useState<Tile | null>(null);
  const [menu, setMenu] = useState<MapMenu | null>(null);
  const [panning, setPanning] = useState(false);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);
  // Input lands between renders, so the live camera and hover sit in refs. Each
  // animation frame draws from them, then copies them to state for the panel.
  const cameraRef = useRef<Camera | null>(null);
  const hoverRef = useRef<Tile | null>(null);
  const pointerRef = useRef<Point | null>(null);
  const dragRef = useRef<{
    pointerId: number;
    x: number;
    y: number;
    /** Canvas pixels per CSS pixel. */
    scale: Point;
  } | null>(null);
  const wheelRef = useRef(0);
  const frameRef = useRef<number | null>(null);
  const sceneRef = useRef<MapScene | null>(null);
  const handlersRef = useRef<{
    wheel: (event: WheelEvent) => void;
    key: (key: KeyEvent) => void;
  } | null>(null);
  const image = usePreviewImage(upgrade.preview);
  // Keyed on content: a static data update can resend the same survey.
  const bitmap = useMemo(
    () => (survey ? renderSurvey(survey) : null),
    [survey?.width, survey?.height, survey?.cells],
  );
  const outline = useMemo(
    () => (survey ? rangeOutline(survey) : []),
    [survey?.x, survey?.y, survey?.width, survey?.height, survey?.near],
  );

  const turned = rotation === 90 || rotation === 270;
  const footWidth = turned ? upgrade.height : upgrade.width;
  const footHeight = turned ? upgrade.width : upgrade.height;
  const footprint = ghostFootprint(
    survey,
    menu ? menu.tile : hover,
    upgrade,
    rotation,
  );
  const entrance =
    CLOCKWISE_DIRS[
      (CLOCKWISE_DIRS.indexOf(upgrade.entrance) + rotation / 90) % 4
    ];
  const menuSpot = menu && camera ? toCanvas(camera, menu.point) : null;

  /** At most one draw per animation frame, however many inputs asked for one. */
  const requestFrame = () => {
    if (frameRef.current !== null) {
      return;
    }
    frameRef.current = requestAnimationFrame(() => {
      frameRef.current = null;
      const canvas = canvasRef.current;
      if (canvas && sceneRef.current) {
        drawMap(canvas, sceneRef.current, cameraRef.current, hoverRef.current);
      }
      setCamera(cameraRef.current);
      setHover(hoverRef.current);
    });
  };

  /** Re-reads the tile under the cursor. The clicked tile holds while the menu is open. */
  const trackHover = () => {
    if (menu) {
      return;
    }
    const current = cameraRef.current;
    const tile = current ? tileAt(current, pointerRef.current) : null;
    const old = hoverRef.current;
    if (tile?.x === old?.x && tile?.y === old?.y) {
      return;
    }
    hoverRef.current = tile;
    requestFrame();
  };

  const moveCamera = (next: Camera) => {
    if (!survey) {
      return;
    }
    cameraRef.current = clampCamera(next, survey);
    trackHover();
    requestFrame();
  };

  const onWheel = (event: WheelEvent) => {
    const canvas = canvasRef.current;
    const current = cameraRef.current;
    if (!canvas || !current || !survey) {
      return;
    }
    const unit =
      event.deltaMode === 1 ? 33 : event.deltaMode === 2 ? MAP_HEIGHT : 1;
    const delta = event.deltaY * unit;
    // Small deltas add up to a step; turning the wheel back starts over.
    if (delta * wheelRef.current < 0) {
      wheelRef.current = 0;
    }
    wheelRef.current += delta;
    if (Math.abs(wheelRef.current) < WHEEL_STEP) {
      return;
    }
    const direction = wheelRef.current > 0 ? -1 : 1;
    wheelRef.current = 0;
    const point = canvasPoint(canvas, event.clientX, event.clientY);
    if (point) {
      moveCamera(zoomCamera(current, survey, point, direction));
    }
  };

  const onKey = (key: KeyEvent) => {
    const delta = PAN_KEYS[key.code];
    if (!delta) {
      return;
    }
    key.event.preventDefault();
    const current = cameraRef.current;
    if (!current) {
      return;
    }
    // About 16 screen pixels a press at any zoom, eight times that with shift.
    const stride =
      Math.max(1, Math.round(MAP_TILE / current.zoom)) * (key.shift ? 8 : 1);
    moveCamera({
      ...current,
      x: current.x + delta[0] * stride,
      y: current.y + delta[1] * stride,
    });
  };

  const endDrag = (event: ReactPointerEvent<HTMLCanvasElement>) => {
    const drag = dragRef.current;
    if (!drag || drag.pointerId !== event.pointerId) {
      return;
    }
    dragRef.current = null;
    if (event.currentTarget.hasPointerCapture(drag.pointerId)) {
      event.currentTarget.releasePointerCapture(drag.pointerId);
    }
    setPanning(false);
  };

  // Handlers bound outside React (the wheel, KeyListener) read these, so they always see this render.
  useLayoutEffect(() => {
    sceneRef.current = {
      survey,
      bitmap,
      outline,
      image,
      upgrade,
      rotation,
      menu,
    };
    handlersRef.current = { wheel: onWheel, key: onKey };
  });

  useLayoutEffect(() => {
    requestFrame();
  }, [bitmap, outline, image, rotation, menu, upgrade.width, upgrade.height]);

  // A new survey keeps the current view where it can, else opens on the outpost.
  useLayoutEffect(() => {
    if (!survey) {
      return;
    }
    const old = cameraRef.current;
    const zoom = Math.max(old?.zoom ?? MAP_TILE, minZoom(survey));
    moveCamera(
      old
        ? { ...old, zoom }
        : {
            x: survey.x + Math.floor((survey.width - MAP_WIDTH / zoom) / 2),
            y: survey.y + Math.floor((survey.height - MAP_HEIGHT / zoom) / 2),
            zoom,
          },
    );
  }, [survey?.x, survey?.y, survey?.z, survey?.width, survey?.height]);

  // React's onWheel is passive and cannot stop the window scrolling.
  useEffect(() => {
    const wrap = wrapRef.current;
    if (!wrap) {
      return;
    }
    const listener = (event: WheelEvent) => {
      event.preventDefault();
      handlersRef.current?.wheel(event);
    };
    wrap.addEventListener('wheel', listener, { passive: false });
    return () => wrap.removeEventListener('wheel', listener);
  }, []);

  useEffect(
    () => () => {
      if (frameRef.current !== null) {
        cancelAnimationFrame(frameRef.current);
        frameRef.current = null;
      }
    },
    [],
  );

  // The arrows already stay out of the game by default; hold them anyway while the map is up.
  useEffect(() => {
    for (const code of Object.keys(PAN_KEYS)) acquireHotKey(Number(code));
    return () => {
      for (const code of Object.keys(PAN_KEYS)) releaseHotKey(Number(code));
    };
  }, []);

  return (
    <>
      <KeyListener onKeyDown={(key) => handlersRef.current?.key(key)} />
      <div
        className={`Outpost__map ${panning ? 'Outpost__map--panning' : ''}`}
        ref={wrapRef}
      >
        <canvas
          ref={canvasRef}
          width={MAP_WIDTH}
          height={MAP_HEIGHT}
          onPointerDown={(event) => {
            if (event.button !== 1) {
              return;
            }
            // Middle-drag pans; the browser would start autoscroll instead.
            event.preventDefault();
            const rect = event.currentTarget.getBoundingClientRect();
            if (!cameraRef.current || !rect.width || !rect.height) {
              return;
            }
            event.currentTarget.setPointerCapture(event.pointerId);
            dragRef.current = {
              pointerId: event.pointerId,
              x: event.clientX,
              y: event.clientY,
              scale: { x: MAP_WIDTH / rect.width, y: MAP_HEIGHT / rect.height },
            };
            setPanning(true);
          }}
          onPointerMove={(event) => {
            pointerRef.current = canvasPoint(
              event.currentTarget,
              event.clientX,
              event.clientY,
            );
            const drag = dragRef.current;
            const current = cameraRef.current;
            if (!drag || drag.pointerId !== event.pointerId || !current) {
              trackHover();
              return;
            }
            // Middle button let go while another is still held.
            if (!(event.buttons & 4)) {
              endDrag(event);
              trackHover();
              return;
            }
            // Deltas from the last move, so a zoom mid-drag doesn't jump the map.
            const dx = ((event.clientX - drag.x) * drag.scale.x) / current.zoom;
            const dy = ((event.clientY - drag.y) * drag.scale.y) / current.zoom;
            drag.x = event.clientX;
            drag.y = event.clientY;
            moveCamera({ ...current, x: current.x - dx, y: current.y + dy });
          }}
          onPointerUp={endDrag}
          onPointerCancel={endDrag}
          onLostPointerCapture={endDrag}
          onPointerLeave={() => {
            pointerRef.current = null;
            trackHover();
          }}
          onMouseDown={(event) => {
            if (event.button === 1) {
              event.preventDefault();
            }
          }}
          onAuxClick={(event) => event.preventDefault()}
          onClick={(event) => {
            // A left press during a middle-drag belongs to the drag.
            if (dragRef.current) {
              return;
            }
            const current = cameraRef.current;
            const point = canvasPoint(
              event.currentTarget,
              event.clientX,
              event.clientY,
            );
            pointerRef.current = point;
            const tile = current ? tileAt(current, point) : null;
            if (menu) {
              setMenu(null);
              hoverRef.current = tile;
              requestFrame();
              return;
            }
            if (!tile || !point || !current || surveying) {
              return;
            }
            hoverRef.current = tile;
            setHover(tile);
            setMenu({ tile, point: toWorld(current, point) });
          }}
        />
        {surveying ? (
          <div className="Outpost__map-status">Surveying</div>
        ) : null}
        {menu && footprint && menuSpot ? (
          <div
            className="Outpost__map-menu"
            style={{
              left: `clamp(0px, ${(menuSpot.x / MAP_WIDTH) * 100}%, calc(100% - 130px))`,
              top: `clamp(0px, ${(menuSpot.y / MAP_HEIGHT) * 100}%, calc(100% - 70px))`,
            }}
          >
            <Button.Confirm
              icon="hammer"
              disabled={!!footprint.reason}
              tooltip={footprint.reason || undefined}
              confirmContent="Permanent. Build?"
              onClick={() => {
                act('place_upgrade', {
                  id: upgrade.id,
                  x: footprint.origin.x,
                  y: footprint.origin.y,
                  rotation,
                });
                setMenu(null);
              }}
            >
              Build
            </Button.Confirm>
            <Button
              icon="rotate-right"
              onClick={() => {
                setRotation((rotation + 90) % 360);
                setMenu(null);
              }}
            >
              Rotate
            </Button>
          </div>
        ) : null}
      </div>
      <div className="Outpost__map-side">
        <div className="Outpost__heading">
          <Icon name="map-location-dot" />
          {upgrade.name}
        </div>
        <div className="Outpost__row">
          <span className="Outpost__grow">Entrance</span>
          <span>{DIR_NAMES[entrance]}</span>
          <Button
            icon="rotate-right"
            tooltip="Rotate"
            onClick={() => {
              setRotation((rotation + 90) % 360);
              setMenu(null);
            }}
          />
        </div>
        <div className="Outpost__row">
          <span className="Outpost__grow">Size</span>
          <span>{`${footWidth}×${footHeight}`}</span>
        </div>
        <div className="Outpost__row">
          <span className="Outpost__grow">Spot</span>
          <span>
            {surveying
              ? 'Surveying'
              : footprint
                ? footprint.reason || 'Clear'
                : '-'}
          </span>
          <Button
            icon="arrows-rotate"
            tooltip="Refresh survey"
            disabled={surveying}
            onClick={() => act('refresh_upgrade_map', { id: upgrade.id })}
          />
        </div>
        {data.upgrade_error ? (
          <div className="Outpost__research-error" role="alert">
            {data.upgrade_error}
          </div>
        ) : null}
        <div className="Outpost__legend">
          {LEGEND.map(([cell, label]) => (
            <span key={cell}>
              <i style={{ background: CELL_COLORS[cell] }} />
              {label}
            </span>
          ))}
          <span>
            <i className="Outpost__legend-range" />
            Build range
          </span>
        </div>
        <div className="Outpost__quiet">
          Wheel: zoom · Middle-drag or arrows: pan
        </div>
        <div className="Outpost__map-actions">
          <Button icon="arrow-left" onClick={onBack}>
            Back
          </Button>
          <Button.Confirm
            icon="rotate-left"
            color="bad"
            disabled={!!status?.manage_denial}
            tooltip={refundTooltip(upgrade.price, status?.manage_denial)}
            onClick={() => act('cancel_upgrade', { id: upgrade.id })}
          >
            Cancel purchase
          </Button.Confirm>
        </div>
      </div>
    </>
  );
}

/** Ledger and totals name services by id or price key. */
const SERVICE_NAMES: Record<string, string> = {
  ship_bay: 'Ship bay',
  dock_bay: 'Ship bay docking',
  cloning_bay: 'Cloning bay',
  clone_imprint: 'Cloning imprint',
  medical_lab: 'Medical lab',
  medlab_pass: 'Medical lab pass',
  storage: 'Safe storage',
  storage_rent: 'Locker rental',
  shop: 'Shop',
  teleporter: 'Teleporter',
  teleport_arrival: 'Teleporter arrivals',
  teleport_trip: 'Teleporter trip',
};

function serviceName(key: string) {
  return SERVICE_NAMES[key] || key;
}

function PriceEditor({
  row,
  canSet,
  act,
}: {
  row: PriceRow;
  canSet: boolean;
  act: Act;
}) {
  const value = Number(row.value) || 0;
  const max = Math.max(0, Number(row.max) || 0);
  const [draft, setDraft] = useState<number | null>(null);
  // A new server value (ours accepted, or someone else's) replaces the draft.
  useEffect(() => {
    setDraft(null);
  }, [value]);
  const shown = draft ?? value;
  return (
    <div className="Outpost__row">
      <div className="Outpost__person">
        <strong>{row.label || serviceName(row.key)}</strong>
        <small>
          {row.available
            ? `Default ${credits(row.default)}, up to ${max} cr`
            : 'Room not installed'}
        </small>
      </div>
      <NumberInput
        value={shown}
        minValue={0}
        maxValue={max}
        step={1}
        stepPixelSize={2}
        width="92px"
        unit="cr"
        disabled={!canSet}
        onChange={(next) =>
          setDraft(Math.min(max, Math.max(0, Math.round(next))))
        }
      />
      <Button
        icon="check"
        disabled={!canSet || shown === value}
        tooltip={canSet ? undefined : 'Owner, treasurers and pricers only'}
        onClick={() => act('set_price', { key: row.key, value: shown })}
      >
        Set
      </Button>
    </div>
  );
}

function shopLine(shop: ShopSummary) {
  const listings = Number(shop.listings) || 0;
  return [
    shop.open ? 'Open' : 'Closed',
    `${listings} listing${listings === 1 ? '' : 's'}`,
    `${Number(shop.priced) || 0} priced`,
    `${Number(shop.unpriced) || 0} not for sale`,
    `${Number(shop.items) || 0} / ${Number(shop.capacity) || 0} items`,
  ].join(' · ');
}

function PricingTab({ data, act }: Props) {
  const pricing = data.pricing || {};
  const prices = pricing.prices || [];
  const shop = pricing.shop;
  const ledger = pricing.ledger || [];
  const totals = pricing.totals || [];
  const canSet = !!data.can_set_prices;
  const canView = !!data.can_view_income;
  return (
    <>
      <div className="Outpost__section-label">
        Service prices<span>{prices.length}</span>
      </div>
      {prices.length === 0 && <Empty icon="tags">No priced services</Empty>}
      {prices.map((row) => (
        <PriceEditor key={row.key} row={row} canSet={canSet} act={act} />
      ))}
      <div className="Outpost__quiet">
        Members use every service free. Visitors pay the price shown here.
      </div>
      {shop?.installed ? (
        <>
          <div className="Outpost__section-label">Shop</div>
          <div className="Outpost__row">
            <Icon name="store" />
            <span className="Outpost__grow">{shopLine(shop)}</span>
          </div>
          <div className="Outpost__quiet">
            Item prices are set at the stock machine in the shop.
          </div>
        </>
      ) : null}
      {canView ? (
        <>
          <div className="Outpost__section-label">
            Income by service<span>{totals.length}</span>
          </div>
          {totals.length === 0 && (
            <div className="Outpost__quiet">No income yet</div>
          )}
          {totals.map((entry) => (
            <div className="Outpost__row" key={entry.service}>
              <span className="Outpost__grow">
                {serviceName(entry.service)}
              </span>
              <span className="Outpost__research-status">
                {Number(entry.count) || 0} paid
              </span>
              <strong className="Outpost__amount">
                {(Number(entry.total) || 0).toLocaleString()} cr
              </strong>
            </div>
          ))}
          <div className="Outpost__section-label">
            Ledger<span>{ledger.length}</span>
          </div>
          {ledger.length === 0 && (
            <div className="Outpost__quiet">No entries</div>
          )}
          {/* The server sends the ledger newest first. */}
          {ledger.map((entry, index) => (
            <div
              className="Outpost__row"
              key={`${entry.time}-${ledger.length - index}`}
            >
              <span className="Outpost__time">{entry.time}</span>
              <div className="Outpost__person">
                <strong>{entry.label || serviceName(entry.service)}</strong>
                {entry.payer || entry.account ? (
                  <small>
                    {entry.payer}
                    {entry.account && entry.account !== entry.payer
                      ? ` (${entry.account})`
                      : ''}
                  </small>
                ) : null}
              </div>
              {Number(entry.amount) > 0 ? (
                <strong className="Outpost__amount">
                  +{Number(entry.amount).toLocaleString()} cr
                </strong>
              ) : Number(entry.amount) < 0 ? (
                <strong className="Outpost__amount Outpost__amount--refund">
                  -{Math.abs(Number(entry.amount)).toLocaleString()} cr
                </strong>
              ) : null}
            </div>
          ))}
        </>
      ) : null}
    </>
  );
}

type ServiceAct = (action: string, params?: Record<string, unknown>) => void;

const VAT_STATES: Record<string, string> = {
  empty: 'Empty',
  growing: 'Growing',
  ready: 'Ready',
  offline: 'Offline',
};

function CloningCard({
  detail,
  serviceAct,
}: {
  detail: CloningDetail;
  serviceAct: ServiceAct;
}) {
  const vats = detail.vats || [];
  return (
    <>
      <div className="Outpost__row">
        <span className="Outpost__grow">Imprint price</span>
        <span>{credits(detail.price)}</span>
      </div>
      {vats.length === 0 && <div className="Outpost__quiet">No vats</div>}
      {vats.map((vat, index) => {
        const paid = Number(vat.paid) || 0;
        return (
          <div className="Outpost__row" key={vat.ref || index}>
            <Icon name="dna" />
            <div className="Outpost__person">
              <strong>
                Vat {index + 1}:{' '}
                {VAT_STATES[vat.state] || vat.state || 'Unknown'}
                {vat.state === 'growing'
                  ? ` ${Math.round(Number(vat.percent) || 0)}%`
                  : ''}
              </strong>
              <small>
                {vat.holder
                  ? `${vat.holder}${paid > 0 ? `, paid ${paid} cr` : ''}`
                  : 'Unclaimed'}
              </small>
            </div>
            {vat.holder ? (
              <Button.Confirm
                icon="eject"
                color="bad"
                disabled={!detail.can_evict || !!vat.evict_denial}
                tooltip={
                  vat.evict_denial ||
                  (paid > 0 ? `Refund ${paid} cr` : 'No refund')
                }
                onClick={() => serviceAct('evict', { ref: vat.ref })}
              >
                Evict
              </Button.Confirm>
            ) : null}
          </div>
        );
      })}
    </>
  );
}

function ShopCard({
  detail,
  serviceAct,
}: {
  detail: ShopDetail;
  serviceAct: ServiceAct;
}) {
  return (
    <div className="Outpost__row">
      <Icon name="store" />
      <span className="Outpost__grow">{shopLine(detail)}</span>
      <Button
        icon={detail.open ? 'door-closed' : 'door-open'}
        disabled={!detail.can_toggle}
        onClick={() => serviceAct('toggle_open')}
      >
        {detail.open ? 'Close shop' : 'Open shop'}
      </Button>
    </div>
  );
}

function MedicalCard({
  detail,
  serviceAct,
}: {
  detail: MedicalDetail;
  serviceAct: ServiceAct;
}) {
  const procedures = detail.procedures || [];
  return (
    <>
      <div className="Outpost__row">
        <span className="Outpost__grow">
          Pass price ({Number(detail.pass_minutes) || 0} min)
        </span>
        <span>{credits(detail.price)}</span>
      </div>
      <div className="Outpost__row">
        <span className="Outpost__grow">Active passes</span>
        <span>{Number(detail.active_passes) || 0}</span>
      </div>
      <div className="Outpost__field-label">Auto-surgeon procedures</div>
      {procedures.length === 0 && (
        <div className="Outpost__quiet">No procedures</div>
      )}
      {procedures.map((procedure) => (
        <div className="Outpost__row" key={procedure.id}>
          <span className="Outpost__grow">{procedure.name}</span>
          <Button
            icon={procedure.enabled ? 'toggle-on' : 'toggle-off'}
            selected={!!procedure.enabled}
            disabled={!detail.can_edit}
            onClick={() =>
              serviceAct('toggle_procedure', { procedure: procedure.id })
            }
          >
            {procedure.enabled ? 'Offered' : 'Disabled'}
          </Button>
        </div>
      ))}
    </>
  );
}

function StorageCard({ detail }: { detail: StorageDetail }) {
  return (
    <>
      <div className="Outpost__row">
        <span className="Outpost__grow">Rental price</span>
        <span>{credits(detail.price)}</span>
      </div>
      <div className="Outpost__row">
        <span className="Outpost__grow">Lockers rented</span>
        <span>
          {Number(detail.rented) || 0} / {Number(detail.lockers) || 0}
        </span>
      </div>
    </>
  );
}

const ARRIVAL_POLICIES = [
  { id: 'open', name: 'Open', icon: 'door-open' },
  { id: 'members', name: 'Members', icon: 'users' },
  { id: 'allowlist', name: 'Allow list', icon: 'list-check' },
  { id: 'closed', name: 'Closed', icon: 'lock' },
];

function TeleporterCard({
  detail,
  canManage,
  serviceAct,
}: {
  detail: TeleporterDetail;
  canManage: boolean;
  serviceAct: ServiceAct;
}) {
  const [pick, setPick] = useState('');
  const canEdit = detail.can_edit === undefined ? canManage : !!detail.can_edit;
  const arrivals = detail.arrivals || detail.policy || 'open';
  const allowlist = detail.allowlist || [];
  const listed = new Set(allowlist.map((pad) => pad.id));
  const candidates = (detail.candidates || []).filter(
    (pad) => !listed.has(pad.id),
  );
  const chosen = candidates.find((pad) => pad.id === pick);
  const raidLock = Number(detail.raidLockLeft) || 0;
  const fee = detail.fee ?? detail.price;
  return (
    <>
      {detail.padName ? (
        <div className="Outpost__row">
          <Icon name="circle-nodes" />
          <strong className="Outpost__grow">{detail.padName}</strong>
        </div>
      ) : null}
      <div className="Outpost__row">
        <span className="Outpost__grow">Arrival fare</span>
        <span>{credits(fee)}</span>
      </div>
      <div className="Outpost__quiet">
        Visitors pay it when they leave another pad for this one. Set it on the
        Pricing tab.
      </div>
      <div className="Outpost__row">
        <span className="Outpost__grow">Trips in / out</span>
        <span>
          {Number(detail.tripsIn ?? detail.trips) || 0} /{' '}
          {Number(detail.tripsOut) || 0}
        </span>
      </div>
      {raidLock > 0 ? (
        <div className="Outpost__research-error" role="status">
          Raid lock: visitors cannot arrive for {clock(raidLock)}
        </div>
      ) : null}
      <label className="Outpost__field-label">Arrivals</label>
      <div className="Outpost__switches">
        {ARRIVAL_POLICIES.map((mode) => (
          <Button
            key={mode.id}
            icon={mode.icon}
            selected={arrivals === mode.id}
            disabled={!canEdit}
            onClick={() =>
              serviceAct('set_teleporter_arrivals', { mode: mode.id })
            }
          >
            {mode.name}
          </Button>
        ))}
      </div>
      {detail.policyNote ? (
        <div className="Outpost__research-error" role="status">
          {detail.policyNote}
        </div>
      ) : null}
      <div className="Outpost__section-label">
        Allow list<span>{allowlist.length}</span>
      </div>
      {arrivals !== 'allowlist' && (
        <div className="Outpost__quiet">
          Used when arrivals are set to Allow list.
        </div>
      )}
      {allowlist.length === 0 && (
        <div className="Outpost__quiet">No outposts listed</div>
      )}
      {allowlist.map((pad) => (
        <div className="Outpost__row" key={pad.id}>
          <Icon name="circle-nodes" />
          <span className="Outpost__grow">{pad.name}</span>
          <Button
            icon="xmark"
            tooltip="Remove from the allow list"
            disabled={!canEdit}
            onClick={() =>
              serviceAct('teleporter_disallow', { target: pad.id })
            }
          />
        </div>
      ))}
      <div className="Outpost__inline Outpost__allow-add">
        <Dropdown
          fluid
          placeholder="Outpost pad"
          selected={chosen?.id || ''}
          displayText={chosen?.name || 'Outpost pad'}
          options={candidates.map((pad) => ({
            displayText: pad.name,
            value: pad.id,
          }))}
          onSelected={setPick}
          disabled={!canEdit || candidates.length === 0}
        />
        <Button
          icon="plus"
          disabled={!canEdit || !chosen}
          onClick={() => {
            if (!chosen) {
              return;
            }
            serviceAct('teleporter_allow', { target: chosen.id });
            setPick('');
          }}
        >
          Allow
        </Button>
      </div>
    </>
  );
}

/** Any detail kind this console does not know: its plain values, so nothing is hidden. */
function GenericCard({ detail }: { detail: Record<string, unknown> }) {
  const rows = Object.entries(detail).filter(
    ([key, value]) =>
      key !== 'kind' &&
      (typeof value === 'string' ||
        typeof value === 'number' ||
        typeof value === 'boolean'),
  );
  if (rows.length === 0) {
    return null;
  }
  return (
    <>
      {rows.map(([key, value]) => (
        <div className="Outpost__row" key={key}>
          <span className="Outpost__grow">{key.replace(/_/g, ' ')}</span>
          <span>{String(value)}</span>
        </div>
      ))}
    </>
  );
}

function ServiceCard({
  room,
  data,
  act,
}: Props & {
  room: ServiceRoom;
}) {
  const serviceAct: ServiceAct = (service_action, params = {}) =>
    act('service_act', { ...params, id: room.id, service_action });
  const detail = room.detail;
  const kind = detail && typeof detail === 'object' ? detail.kind : undefined;
  // The teleporter is always public; its arrival policy is the lever (abuse review F-33).
  const showVisitors =
    room.visitors_allowed !== undefined &&
    room.visitors_allowed !== null &&
    kind !== 'teleporter';
  return (
    <div className="Outpost__service">
      <div className="Outpost__section-label">
        {room.name || serviceName(room.id)}
        {!!showVisitors && (
          <span>{room.visitors_allowed ? 'Public' : 'Members only'}</span>
        )}
      </div>
      {!!showVisitors && (
        <div className="Outpost__row">
          <span className="Outpost__grow">Visitors may enter</span>
          <Button
            icon={room.visitors_allowed ? 'door-open' : 'door-closed'}
            selected={!!room.visitors_allowed}
            disabled={!room.can_toggle_visitors}
            tooltip="Members always pass. Anyone inside can always leave."
            onClick={() =>
              act('set_room_visitors', {
                id: room.id,
                allowed: room.visitors_allowed ? 0 : 1,
              })
            }
          >
            {room.visitors_allowed ? 'Allowed' : 'Members only'}
          </Button>
        </div>
      )}
      {!detail ? (
        <div className="Outpost__quiet">No details</div>
      ) : kind === 'cloning' ? (
        <CloningCard detail={detail as CloningDetail} serviceAct={serviceAct} />
      ) : kind === 'shop' ? (
        <ShopCard detail={detail as ShopDetail} serviceAct={serviceAct} />
      ) : kind === 'medical' ? (
        <MedicalCard detail={detail as MedicalDetail} serviceAct={serviceAct} />
      ) : kind === 'storage' ? (
        <StorageCard detail={detail as StorageDetail} />
      ) : kind === 'teleporter' ? (
        <TeleporterCard
          detail={detail as TeleporterDetail}
          canManage={!!data.can_manage}
          serviceAct={serviceAct}
        />
      ) : (
        <GenericCard detail={detail as Record<string, unknown>} />
      )}
    </div>
  );
}

/** Installed rooms; the §7.5 top-level teleporter block becomes a card when no row carries it. */
function serviceRooms(data: OutpostData): ServiceRoom[] {
  const rooms = (data.services || []).filter((room) => !!room?.id);
  const teleporter = data.teleporter;
  if (
    teleporter?.installed &&
    !rooms.some((room) => room.detail?.kind === 'teleporter')
  ) {
    rooms.push({
      id: 'teleporter',
      name: 'Teleporter',
      detail: { ...teleporter, kind: 'teleporter' },
    });
  }
  return rooms;
}

function Services({ data, act }: Props) {
  const rooms = serviceRooms(data);
  if (rooms.length === 0) {
    return (
      <Empty icon="store">No service rooms. Buy one on the Upgrades tab.</Empty>
    );
  }
  return (
    <>
      {rooms.map((room) => (
        <ServiceCard key={room.id} room={room} data={data} act={act} />
      ))}
    </>
  );
}

function Access({ data, act }: Props) {
  const [account, setAccount] = useState('');
  const invites = Object.keys(data.resident_invites || {});
  const blocked = data.resident_blocked || [];
  const builders = data.builders || [];
  const submit = (action: string) => {
    act(action, { ckey: account.trim() });
    setAccount('');
  };
  return (
    <>
      <div className="Outpost__section-label">Return access</div>
      <div className="Outpost__inline">
        <Input
          fluid
          placeholder="Player account"
          value={account}
          onChange={setAccount}
          disabled={!data.can_manage}
        />
        <Button
          icon="user-check"
          tooltip="Invite"
          disabled={!data.can_manage || !account.trim()}
          onClick={() => submit('invite_resident')}
        />
        <Button
          icon="user-slash"
          tooltip="Block"
          disabled={!data.can_manage || !account.trim()}
          onClick={() => submit('block_resident')}
        />
      </div>
      <div className="Outpost__section-label">
        Invited<span>{invites.length}</span>
      </div>
      {invites.length === 0 && <div className="Outpost__quiet">None</div>}
      {invites.map((key) => (
        <div className="Outpost__row" key={key}>
          <span className="Outpost__grow">{key}</span>
          <Icon name="user-check" />
        </div>
      ))}
      <div className="Outpost__section-label">
        Blocked<span>{blocked.length}</span>
      </div>
      {blocked.length === 0 && <div className="Outpost__quiet">None</div>}
      {blocked.map((key) => (
        <div className="Outpost__row" key={key}>
          <span className="Outpost__grow">{key}</span>
          <Button
            icon="unlock"
            tooltip="Unblock account"
            disabled={!data.can_manage}
            onClick={() => act('unblock_resident', { ckey: key })}
          />
        </div>
      ))}
      <div className="Outpost__section-label">
        Construction<span>{builders.length}</span>
      </div>
      {builders.length === 0 && (
        <div className="Outpost__quiet">Owner only</div>
      )}
      {builders.map((key) => (
        <div className="Outpost__row" key={key}>
          <span className="Outpost__grow">{key}</span>
          <Button
            icon="xmark"
            tooltip="Revoke construction"
            disabled={!data.is_owner}
            onClick={() => act('remove_builder', { ckey: key })}
          />
        </div>
      ))}
      <Button.Confirm
        className="Outpost__reset"
        icon="rotate-left"
        color="bad"
        disabled={!data.can_manage}
        onClick={() => act('reset_resident_access')}
      >
        Reset return access
      </Button.Confirm>
    </>
  );
}

function Research({ data, act }: Props) {
  const [serverRef, setServerRef] = useState('');
  const [shipRef, setShipRef] = useState('');
  const servers = data.research_servers || [];
  const ships = data.research_ships || [];
  const connections = data.research_connections || [];
  const server =
    servers.find((candidate) => candidate.ref === serverRef) || servers[0];
  const ship = ships.find((candidate) => candidate.ref === shipRef) || ships[0];
  const canInvite = !!data.can_manage && !!server && !!ship;

  return (
    <>
      <div className="Outpost__heading">
        <Icon name="flask" />
        Research connections
      </div>
      <label className="Outpost__field-label">Source server</label>
      <div className="Outpost__inline">
        <Dropdown
          fluid
          placeholder="No local server"
          selected={server?.ref || ''}
          displayText={server?.name || 'No local server'}
          options={servers.map((candidate) => ({
            displayText: candidate.name,
            value: candidate.ref,
          }))}
          onSelected={setServerRef}
          disabled={!data.can_manage || servers.length === 0}
        />
      </div>
      <label className="Outpost__field-label">Docked ship</label>
      <div className="Outpost__inline">
        <Dropdown
          fluid
          placeholder="No docked ship"
          selected={ship?.ref || ''}
          displayText={ship?.name || 'No docked ship'}
          options={ships.map((candidate) => ({
            displayText: candidate.name,
            value: candidate.ref,
          }))}
          onSelected={setShipRef}
          disabled={!data.can_manage || ships.length === 0}
        />
        <Button
          icon="link"
          color="good"
          disabled={!canInvite}
          onClick={() => {
            if (!server || !ship) {
              return;
            }
            act('invite_research', { ship: ship.ref, server: server.ref });
          }}
        >
          Invite
        </Button>
      </div>
      {data.research_error ? (
        <div className="Outpost__research-error" role="alert">
          {data.research_error}
        </div>
      ) : null}
      <div className="Outpost__section-label">
        Connections<span>{connections.length}</span>
      </div>
      {connections.length === 0 && (
        <Empty icon="link-slash">No research connections</Empty>
      )}
      {connections.map((connection) => {
        const approved = !!connection.approved;
        return (
          <div className="Outpost__row" key={connection.ref}>
            <Icon name={approved ? 'link' : 'hourglass-half'} />
            <div className="Outpost__person">
              <strong>{connection.ship}</strong>
              <small>{connection.server}</small>
            </div>
            <span className="Outpost__research-status">
              {connection.status || (approved ? 'Connected' : 'Pending')}
            </span>
            <Button
              icon={approved ? 'link-slash' : 'xmark'}
              color={approved ? 'bad' : undefined}
              tooltip={approved ? 'Disconnect' : 'Cancel pending invitation'}
              disabled={!data.can_manage}
              onClick={() => act('revoke_research', { ref: connection.ref })}
            >
              {approved ? 'Disconnect' : 'Cancel'}
            </Button>
          </div>
        );
      })}
    </>
  );
}

function Registry({ data, act }: Props) {
  const [name, setName] = useState(data.outpost_name || '');
  const [memo, setMemo] = useState(data.memo || '');
  const [password, setPassword] = useState('');
  const docking = [
    { id: 'open', name: 'Open', icon: 'door-open' },
    { id: 'request', name: 'Request', icon: 'hand' },
    { id: 'lockdown', name: 'Lockdown', icon: 'lock' },
  ];
  const arrivals = [
    { id: 'open', name: 'Open' },
    { id: 'password', name: 'Password' },
    { id: 'approved', name: 'Invite' },
    { id: 'closed', name: 'Closed' },
  ];
  return (
    <>
      <div className="Outpost__heading">
        <Icon name="sliders" />
        Registry & policies
      </div>
      <div className="Outpost__registry-scroll">
        <label className="Outpost__field-label">Designation</label>
        <div className="Outpost__inline">
          <Input
            fluid
            value={name}
            onChange={setName}
            disabled={!data.can_manage}
            maxLength={64}
          />
          <Button
            icon="check"
            tooltip={
              data.rename_cooldown > 0
                ? `Rename available in ${Math.ceil(data.rename_cooldown)}s`
                : 'Rename'
            }
            disabled={
              !data.can_manage ||
              !name.trim() ||
              name.trim() === data.outpost_name ||
              data.rename_cooldown > 0
            }
            onClick={() => act('rename', { name: name.trim() })}
          />
        </div>
        <label className="Outpost__field-label">Public memo</label>
        <div className="Outpost__memo">
          <TextArea
            fluid
            height="62px"
            value={memo}
            onChange={setMemo}
            disabled={!data.can_manage}
            placeholder="Public memo"
          />
          <Button
            icon="floppy-disk"
            tooltip="Save memo"
            disabled={!data.can_manage || memo === data.memo}
            onClick={() => act('set_memo', { memo })}
          />
        </div>
        <label className="Outpost__field-label">Docking</label>
        <div className="Outpost__switches">
          {docking.map((mode) => (
            <Button
              key={mode.id}
              icon={mode.icon}
              selected={data.dock_mode === mode.id}
              disabled={!data.can_manage}
              onClick={() => act('set_dock_mode', { mode: mode.id })}
            >
              {mode.name}
            </Button>
          ))}
        </div>
        <label className="Outpost__field-label">Resident arrivals</label>
        <div className="Outpost__switches">
          {arrivals.map((mode) => (
            <Button
              key={mode.id}
              selected={data.resident_mode === mode.id}
              disabled={!data.can_manage}
              onClick={() => act('resident_mode', { mode: mode.id })}
            >
              {mode.name}
            </Button>
          ))}
        </div>
        {data.resident_mode === 'password' && (
          <div className="Outpost__inline Outpost__password">
            <input
              className="Input Input--fluid"
              type="password"
              placeholder="New password"
              value={password}
              onChange={(event) => setPassword(event.currentTarget.value)}
              autoComplete="new-password"
              maxLength={64}
              disabled={!data.can_manage}
            />
            <Button
              icon="key"
              tooltip="Set password"
              disabled={!data.can_manage || !password.trim()}
              onClick={() => {
                act('resident_password', { password });
                setPassword('');
              }}
            />
          </div>
        )}
        <div className="Outpost__limit">
          <span>{data.resident_active || 0} active residents</span>
        </div>
        <div
          className={
            'Outpost__arrival ' +
            (data.arrival_available ? 'Outpost__arrival--ready' : '')
          }
        >
          <Icon name="bed" />
          {data.arrival_available ? 'Cryo ready' : 'No free cryopod'}
        </div>
      </div>
    </>
  );
}

function Broadcast({ data, act }: Props) {
  const live = data.advert_remaining > 0;
  return (
    <>
      <div className="Outpost__heading">
        <Icon name="satellite-dish" />
        Broadcast{!!live && <span className="Outpost__live">LIVE</span>}
      </div>
      <div className="Outpost__footer-row">
        <div className="Outpost__readout">
          <strong>
            {live
              ? `${Math.ceil(data.advert_remaining / 60)} min`
              : `${data.advert_cost} cr`}
          </strong>
          <small
            role="status"
            className={
              !live && (data.advert_denial || data.advert_error)
                ? 'Outpost__broadcast-error'
                : undefined
            }
          >
            {live
              ? 'Broadcast live'
              : data.advert_denial || data.advert_error || 'Sector listing'}
          </small>
        </div>
        <Button
          icon="tower-broadcast"
          disabled={
            !data.can_manage ||
            !!data.advert_denial ||
            !data.can_spend ||
            live ||
            data.advert_cooldown > 0
          }
          tooltip={data.advert_denial || data.advert_error || undefined}
          onClick={() => act('buy_advert')}
        >
          {live ? 'On air' : 'Broadcast'}
        </Button>
      </div>
    </>
  );
}

function Ownership({ data, act }: Props) {
  const [recipient, setRecipient] = useState<string>('');
  const candidates = data.candidates || [];
  const selected = candidates.find((person) => person.ref === recipient);
  return (
    <>
      <div className="Outpost__heading">
        <Icon name="flag" />
        Ownership
      </div>
      {data.is_owner ? (
        <div className="Outpost__ownership">
          <Dropdown
            fluid
            placeholder="New owner"
            displayText={selected?.name || 'New owner'}
            selected={recipient}
            options={candidates.map((person) => ({
              displayText: person.name,
              value: person.ref,
            }))}
            onSelected={setRecipient}
          />
          <Button
            icon="right-left"
            disabled={!selected}
            onClick={() => act('transfer', { ref: recipient })}
          >
            Transfer
          </Button>
          <Button
            color="bad"
            icon="arrow-right-from-bracket"
            onClick={() => act('abandon')}
          >
            Abandon
          </Button>
        </div>
      ) : !data.has_owner ? (
        <div className="Outpost__ownership">
          <Button
            icon="flag"
            disabled={!data.can_claim}
            onClick={() => act('claim')}
          >
            Claim outpost
          </Button>
        </div>
      ) : (
        <div className="Outpost__quiet">{data.founder_name}</div>
      )}
    </>
  );
}

type Tab = { id: string; title: string; icon: string };
const TAB_DOCKING: Tab = { id: 'docking', title: 'Docking', icon: 'anchor' };
const TAB_PRICING: Tab = { id: 'pricing', title: 'Pricing', icon: 'tags' };
const TAB_SERVICES: Tab = { id: 'services', title: 'Services', icon: 'store' };

/**
 * Tabs by role (spec §1.4): managers see all; treasurers Docking and Pricing; pricers Pricing;
 * others Docking. Staff also get Services when the server sends them room cards: a treasurer
 * evicts unused vat imprints there (ruling R4), and each card gates its own buttons.
 */
function visibleTabs(data: OutpostData): Tab[] {
  if (data.is_owner || data.can_manage) {
    return [
      TAB_DOCKING,
      TAB_PRICING,
      { id: 'residents', title: 'Residents', icon: 'users' },
      { id: 'access', title: 'Access', icon: 'id-card' },
      { id: 'research', title: 'Research', icon: 'flask' },
      { id: 'upgrades', title: 'Upgrades', icon: 'cubes' },
      TAB_SERVICES,
    ];
  }
  const pricing = !!data.can_set_prices || !!data.can_view_income;
  const treasurer = canSelectSilo(data) || !!data.can_spend;
  const tabs: Tab[] = [];
  if (treasurer || !pricing) {
    tabs.push(TAB_DOCKING);
  }
  if (pricing) {
    tabs.push(TAB_PRICING);
  }
  if ((data.services?.length || 0) > 0) {
    tabs.push(TAB_SERVICES);
  }
  return tabs;
}

export function OutpostManagementPanel({ data, act }: Props) {
  const [chosenTab, setTab] = useState('docking');
  const [placingId, setPlacingId] = useState<string | null>(null);
  const placingUpgrade = (data.upgrade_catalog || []).find(
    (entry) => entry.id === placingId,
  );
  const placingStatus = (data.upgrades || []).find(
    (entry) => entry.id === placingId,
  );
  const placing = !!data.linked && !!placingUpgrade;
  // Placed, cancelled or refused: back to the carousel.
  useEffect(() => {
    if (placingId && placingStatus?.state !== 'ready') {
      setPlacingId(null);
    }
  }, [placingId, placingStatus?.state]);
  const tabs = visibleTabs(data);
  const tab = tabs.some((item) => item.id === chosenTab)
    ? chosenTab
    : tabs[0].id;
  return (
    <div className="Outpost">
      <div
        className="Outpost__plate"
        style={{
          backgroundImage: `url("${resolveAsset('outpost_management_plate.png')}")`,
        }}
      />
      <Panel slot="identity" className="Outpost__rail">
        <Icon name="house-flag" />
        <strong title={data.outpost_name}>
          {data.outpost_name || 'Outpost registry'}
        </strong>
      </Panel>
      <Panel slot="owner" className="Outpost__rail">
        <span>OWNER</span>
        <strong>{data.founder_name || 'Unclaimed'}</strong>
      </Panel>
      <Panel slot="status" className="Outpost__rail Outpost__rail--status">
        <Icon name={data.raidable ? 'shield-halved' : 'shield'} />
        <strong>{data.raidable ? 'Unpatrolled' : 'Patrolled'}</strong>
      </Panel>
      {placing && placingUpgrade ? (
        <>
          <Panel slot="placement">
            <UpgradePlacement
              data={data}
              act={act}
              upgrade={placingUpgrade}
              status={placingStatus}
              onBack={() => {
                act('close_upgrade_map');
                setPlacingId(null);
              }}
            />
          </Panel>
          <Panel slot="broadcast">
            <Broadcast data={data} act={act} />
          </Panel>
          <Panel slot="command">
            <Ownership data={data} act={act} />
          </Panel>
        </>
      ) : data.linked ? (
        <>
          <Panel slot="directory">
            <nav className="Outpost__tabs">
              {tabs.map((item) => (
                <Button
                  key={item.id}
                  icon={item.icon}
                  selected={tab === item.id}
                  onClick={() => setTab(item.id)}
                >
                  {item.title}
                  {item.id === 'docking' &&
                  (data.dock_requests?.length || 0) > 0 ? (
                    <span className="Outpost__count">
                      {data.dock_requests.length}
                    </span>
                  ) : null}
                </Button>
              ))}
            </nav>
            {data.playtest_visitor ? (
              <div className="Outpost__banner" role="status">
                <Icon name="user-secret" />
                Billed as a visitor. Services charge you and staff doors stay
                shut.
              </div>
            ) : null}
            {data.market_error ? (
              <div
                className="Outpost__research-error Outpost__market-error"
                role="alert"
              >
                <span className="Outpost__grow">{data.market_error}</span>
                <Button
                  icon="xmark"
                  tooltip="Dismiss"
                  onClick={() => act('dismiss_market_error')}
                />
              </div>
            ) : null}
            <div className="Outpost__directory-scroll">
              {tab === 'docking' ? (
                <Docking data={data} act={act} />
              ) : tab === 'pricing' ? (
                <PricingTab data={data} act={act} />
              ) : tab === 'services' ? (
                <Services data={data} act={act} />
              ) : tab === 'residents' ? (
                <Residents data={data} act={act} />
              ) : tab === 'research' ? (
                <Research data={data} act={act} />
              ) : tab === 'upgrades' ? (
                <Upgrades
                  data={data}
                  act={act}
                  onPlace={(id) => {
                    act('open_upgrade_map', { id });
                    setPlacingId(id);
                  }}
                />
              ) : (
                <Access data={data} act={act} />
              )}
            </div>
          </Panel>
          <Panel slot="registry">
            <Registry data={data} act={act} />
          </Panel>
          <Panel slot="broadcast">
            <Broadcast data={data} act={act} />
          </Panel>
          <Panel slot="command">
            <Ownership data={data} act={act} />
          </Panel>
        </>
      ) : (
        <Panel slot="directory">
          <Empty icon="link-slash">No outpost link</Empty>
        </Panel>
      )}
    </div>
  );
}

export const OutpostManagement = () => {
  const { data, act } = useBackend<OutpostData>();
  return (
    <Window title="Outpost Management" width={1000} height={680}>
      <Window.Content fitted>
        <OutpostManagementPanel data={data} act={act} />
      </Window.Content>
    </Window>
  );
};
