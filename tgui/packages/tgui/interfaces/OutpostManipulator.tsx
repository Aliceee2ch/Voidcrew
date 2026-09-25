import {
  Box,
  Button,
  Dropdown,
  Icon,
  LabeledList,
  NoticeBox,
  NumberInput,
  ProgressBar,
  Section,
  Stack,
  Table,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type OutpostSummary = {
  ref: string;
  name: string;
  owner: string;
  coords: string;
  loaded: BooleanLike;
};

type Resident = {
  ref: string;
  name: string;
  is_self: BooleanLike;
  steward: BooleanLike;
  treasurer: BooleanLike;
};

type ShipBayData = {
  installed: BooleanLike;
  capacity: number;
  install_denial: string | null;
  remove_denial: string | null;
  saved_checkpoints: number;
  silo: string | null;
  silos: { ref: string; name: string }[];
  slots: {
    number: number;
    ref: string | null;
    status: string;
    ship?: string;
    can_jump?: BooleanLike;
    silo?: string | null;
    requested?: BooleanLike;
    approved?: BooleanLike;
    owner_crew?: BooleanLike;
    grant_denial?: string | null;
    can_remove_ship?: BooleanLike;
  }[];
};

type CheckpointAdminData = {
  enabled: BooleanLike;
  docked: string | null;
  checkpoints: {
    ref: string;
    name: string;
    owner: string;
    size: string;
    original: string;
    rebuild_denial: string | null;
  }[];
  rebuilds: {
    ref: string;
    name: string;
    owner: string;
    status: string;
    progress: number;
    can_rush: BooleanLike;
    can_hand_over: BooleanLike;
  }[];
};

type PrisonAdminPrisoner = {
  ref: string;
  name: string;
  cell: number;
  personality: string;
  crime: string;
  activity: string;
  /** 0-100 each; hunger is how fed they are, 100 = full */
  hunger: number;
  grime: number;
  health: number;
  care: number;
  /** 0-100 */
  mood: number;
  state: PrisonerState;
  /** seconds until an escaped prisoner is gone for good, null when not loose */
  loose_left: number | null;
  /** seconds */
  sentence_left: number;
  dead: BooleanLike;
};

type PrisonerState = 'normal' | 'fighting' | 'beaten' | 'rioting' | 'loose';

type PrisonStage = 'calm' | 'grumbling' | 'restless' | 'riot';

type PrisonAdminData = {
  intake_open: BooleanLike;
  /** seconds, null when nothing is scheduled */
  next_arrival: number | null;
  /** cr/min */
  pay_rate: number;
  paid_total: number;
  powered: BooleanLike;
  /** 0-100 each */
  conditions: { clean: number; lit: number; powered: number; score: number };
  cells: { number: number; occupant_ref: string | null }[];
  prisoners: PrisonAdminPrisoner[];
  /** 0-100 */
  tension: number;
  stage: PrisonStage;
  /** seconds until an unresolved riot becomes a breakout, null when none */
  breakout_in: number | null;
};

type SelectedOutpost = {
  ref: string;
  name: string;
  owner: string;
  coords: string;
  shell: string;
  balance: number;
  dock_mode: 'open' | 'request' | 'lockdown';
  resident_mode: 'open' | 'password' | 'approved' | 'closed';
  resident_active: number;
  freight_state: string;
  freight_error: string;
  research_connection: string;
  residents: Resident[];
  ship_bays: ShipBayData;
  checkpoints: CheckpointAdminData;
  /** null when the outpost has no prison */
  prison?: PrisonAdminData | null;
};

export type Data = {
  outposts: OutpostSummary[];
  selected: SelectedOutpost | null;
  busy: BooleanLike;
  error: string | null;
};

const dockModes: SelectedOutpost['dock_mode'][] = [
  'open',
  'request',
  'lockdown',
];

const residentModes: SelectedOutpost['resident_mode'][] = [
  'open',
  'password',
  'approved',
  'closed',
];

const modeLabel = (mode: string) =>
  mode.charAt(0).toUpperCase() + mode.slice(1);

export const OutpostManipulator = () => {
  const { act, data } = useBackend<Data>();

  return (
    <Window title="Outpost Manipulator" theme="admin" width={920} height={640}>
      <Window.Content fitted>
        <OutpostManipulatorPanel data={data} act={act} />
      </Window.Content>
    </Window>
  );
};

type OutpostManipulatorPanelProps = {
  data: Data;
  act: (action: string, params?: unknown) => void;
};

export const OutpostManipulatorPanel = ({
  data,
  act,
}: OutpostManipulatorPanelProps) => {
  const { outposts, selected, busy, error } = data;
  const isBusy = !!busy;

  return (
    <Stack fill>
      <Stack.Item width="31%">
        <Section title="Player Outposts" fill scrollable>
          <Button
            fluid
            icon="plus"
            color="good"
            disabled={isBusy}
            onClick={() => act('create')}
          >
            Create Outpost
          </Button>
          <Box mt={1}>
            {outposts.length ? (
              <Stack vertical>
                {outposts.map((outpost) => (
                  <Stack.Item key={outpost.ref}>
                    <Button
                      fluid
                      selected={outpost.ref === selected?.ref}
                      disabled={isBusy}
                      onClick={() => act('select', { ref: outpost.ref })}
                    >
                      <Stack align="center">
                        <Stack.Item grow>
                          <Box bold>{outpost.name}</Box>
                          <Box color="label" fontSize="11px">
                            {outpost.owner || 'Unclaimed'}
                          </Box>
                        </Stack.Item>
                        <Stack.Item>
                          <Icon
                            name={outpost.loaded ? 'circle-check' : 'circle'}
                            color={outpost.loaded ? 'good' : 'label'}
                          />
                        </Stack.Item>
                      </Stack>
                    </Button>
                  </Stack.Item>
                ))}
              </Stack>
            ) : (
              <NoticeBox info>No player outposts found.</NoticeBox>
            )}
          </Box>
        </Section>
      </Stack.Item>

      <Stack.Item grow overflowY="auto">
        {error ? <NoticeBox danger>{error}</NoticeBox> : null}
        {selected ? (
          <OutpostDetails selected={selected} busy={isBusy} act={act} />
        ) : (
          <Section title="Registry" fill>
            <NoticeBox info>
              Select an outpost to inspect or manipulate it.
            </NoticeBox>
          </Section>
        )}
      </Stack.Item>
    </Stack>
  );
};

type DetailsProps = {
  selected: SelectedOutpost;
  busy: boolean;
  act: (action: string, params?: unknown) => void;
};

const OutpostDetails = ({ selected, busy, act }: DetailsProps) => {
  const mutate = (action: string, params?: unknown) => {
    if (!busy) {
      act(action, params);
    }
  };

  return (
    <Stack vertical>
      <Stack.Item>
        <Section title={selected.name}>
          <LabeledList>
            <LabeledList.Item label="Owner">
              {selected.owner || 'Unclaimed'}
            </LabeledList.Item>
            <LabeledList.Item label="Coordinates">
              {selected.coords}
            </LabeledList.Item>
            <LabeledList.Item label="Shell">{selected.shell}</LabeledList.Item>
            <LabeledList.Item label="Balance">
              {selected.balance.toLocaleString()} cr
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Stack.Item>

      <Stack.Item>
        <Section title="Navigation and Identity">
          <Stack wrap>
            <Button
              icon="location-crosshairs"
              disabled={busy}
              onClick={() => act('jump')}
            >
              Jump to Outpost
            </Button>
            <Button
              icon="globe"
              disabled={busy}
              onClick={() => act('jump_overmap')}
            >
              Jump Overmap
            </Button>
            <Button icon="code" disabled={busy} onClick={() => act('vv')}>
              View Variables
            </Button>
            <Button icon="pen" disabled={busy} onClick={() => mutate('rename')}>
              Rename
            </Button>
            <Button
              icon="user-gear"
              disabled={busy}
              onClick={() => mutate('owner')}
            >
              Set Owner
            </Button>
            <Button
              icon="coins"
              disabled={busy}
              onClick={() => mutate('balance')}
            >
              Adjust Balance
            </Button>
            <Button
              icon="person-circle-minus"
              color="caution"
              disabled={busy}
              onClick={() => mutate('abandon')}
            >
              Abandon
            </Button>
            <Button
              icon="trash"
              color="bad"
              disabled={busy}
              onClick={() => mutate('delete')}
            >
              Delete
            </Button>
          </Stack>
        </Section>
      </Stack.Item>

      <Stack.Item>
        <ShipBays data={selected.ship_bays} busy={busy} act={mutate} />
      </Stack.Item>

      {!!selected.checkpoints.enabled && (
        <Stack.Item>
          <CheckpointTools
            data={selected.checkpoints}
            busy={busy}
            act={mutate}
          />
        </Stack.Item>
      )}

      <Stack.Item>
        {selected.prison ? (
          <PrisonTools data={selected.prison} busy={busy} act={mutate} />
        ) : (
          <Section title="Prison">
            <Box color="label">No prison</Box>
          </Section>
        )}
      </Stack.Item>

      <Stack.Item>
        <Section title="Services">
          <Stack vertical>
            <Stack.Item>
              <Stack align="center" wrap>
                <Stack.Item width="90px" bold>
                  Docking
                </Stack.Item>
                {dockModes.map((mode) => (
                  <Button
                    key={mode}
                    selected={selected.dock_mode === mode}
                    disabled={busy}
                    onClick={() => mutate('dock_mode', { mode })}
                  >
                    {modeLabel(mode)}
                  </Button>
                ))}
              </Stack>
            </Stack.Item>
            <Stack.Item>
              <Stack align="center" wrap>
                <Stack.Item width="90px" bold>
                  Residents
                </Stack.Item>
                {residentModes.map((mode) => (
                  <Button
                    key={mode}
                    selected={selected.resident_mode === mode}
                    disabled={busy}
                    onClick={() => mutate('resident_mode', { mode })}
                  >
                    {modeLabel(mode)}
                  </Button>
                ))}
                <Box color="label">
                  {selected.resident_active} active residents
                </Box>
              </Stack>
            </Stack.Item>
            <Stack.Item>
              <Stack wrap>
                <Button
                  icon="key"
                  disabled={busy}
                  onClick={() => mutate('resident_password')}
                >
                  Set Resident Password
                </Button>
                <Button
                  icon="user-slash"
                  disabled={busy}
                  onClick={() => mutate('reset_resident_access')}
                >
                  Reset Resident Access
                </Button>
                <Button
                  icon="link"
                  disabled={busy}
                  onClick={() => mutate('relink')}
                >
                  Relink Services
                </Button>
                <Button
                  icon="flask"
                  color="caution"
                  disabled={busy}
                  onClick={() => mutate('revoke_research')}
                >
                  Revoke Research
                </Button>
              </Stack>
            </Stack.Item>
            <Stack.Item>
              <Box color={selected.freight_error ? 'bad' : 'good'}>
                Freight: {selected.freight_state}
                {selected.freight_error ? ` - ${selected.freight_error}` : null}
              </Box>
              <Box color="label">
                Research connections: {selected.research_connection}
              </Box>
            </Stack.Item>
          </Stack>
        </Section>
      </Stack.Item>

      <Stack.Item>
        <Section title="Residents">
          <Stack align="center" mb={1}>
            <Stack.Item grow>
              <Box color="label">
                {selected.resident_active} active residents
              </Box>
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="user-plus"
                disabled={busy}
                onClick={() => mutate('add_resident')}
              >
                Add Resident
              </Button>
            </Stack.Item>
          </Stack>
          {selected.residents.length ? (
            <Table>
              <Table.Row header>
                <Table.Cell>Name</Table.Cell>
                <Table.Cell>Roles</Table.Cell>
                <Table.Cell collapsing>Actions</Table.Cell>
              </Table.Row>
              {selected.residents.map((resident) => (
                <Table.Row key={resident.ref}>
                  <Table.Cell>{resident.name}</Table.Cell>
                  <Table.Cell>
                    {!!resident.steward && (
                      <Box inline color="good">
                        Steward
                      </Box>
                    )}
                    {!!resident.treasurer && (
                      <Box inline color="yellow" ml={1}>
                        Treasurer
                      </Box>
                    )}
                    {!resident.steward && !resident.treasurer ? (
                      <Box color="label">Resident</Box>
                    ) : null}
                  </Table.Cell>
                  <Table.Cell collapsing>
                    <Button
                      compact
                      icon="user-shield"
                      disabled={busy}
                      onClick={() =>
                        mutate('delegate', {
                          ref: resident.ref,
                          role: 'steward',
                        })
                      }
                    >
                      {resident.steward ? 'Unmake Steward' : 'Steward'}
                    </Button>
                    <Button
                      compact
                      icon="coins"
                      disabled={busy}
                      onClick={() =>
                        mutate('delegate', {
                          ref: resident.ref,
                          role: 'treasurer',
                        })
                      }
                    >
                      {resident.treasurer ? 'Unmake Treasurer' : 'Treasurer'}
                    </Button>
                    <Button
                      compact
                      color="bad"
                      icon="user-minus"
                      disabled={busy || !!resident.is_self}
                      tooltip={
                        resident.is_self
                          ? 'You cannot remove yourself'
                          : undefined
                      }
                      onClick={() =>
                        mutate('remove_resident', { ref: resident.ref })
                      }
                    >
                      Remove
                    </Button>
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          ) : (
            <NoticeBox info>No residents are registered.</NoticeBox>
          )}
        </Section>
      </Stack.Item>
    </Stack>
  );
};

const ShipBays = ({
  data,
  busy,
  act,
}: {
  data: ShipBayData;
  busy: boolean;
  act: DetailsProps['act'];
}) => (
  <Section
    title="Ship Bay"
    buttons={
      data.installed ? (
        <Button
          icon="trash"
          color="bad"
          disabled={busy || !!data.remove_denial}
          tooltip={data.remove_denial}
          onClick={() => act('remove_bays')}
        >
          Remove Upgrade
        </Button>
      ) : (
        <Button
          icon="plus"
          color="good"
          disabled={busy || !!data.install_denial}
          tooltip={data.install_denial}
          onClick={() => act('install_bays')}
        >
          Install Bay (Free)
        </Button>
      )
    }
  >
    <Box mb={1}>
      {data.installed ? 'One permanent bay installed' : 'Not installed'}
      {' / '}
      {data.saved_checkpoints} saved checkpoints
    </Box>
    <Box color="label" mb={1}>
      The bay stays loaded between visits.
    </Box>
    {!!(data.installed ? data.remove_denial : data.install_denial) && (
      <Box color="label" mb={1}>
        {data.installed ? data.remove_denial : data.install_denial}
      </Box>
    )}
    <LabeledList>
      <LabeledList.Item label="Outpost silo">
        <Dropdown
          width="100%"
          disabled={busy || data.silos.length === 0}
          selected={data.silo || ''}
          placeholder="No outpost silo selected"
          options={data.silos.map((silo) => ({
            value: silo.ref,
            displayText: silo.name,
          }))}
          onSelected={(ref) => act('bay_select_silo', { ref })}
        />
      </LabeledList.Item>
    </LabeledList>
    {data.slots.map((bay) => (
      <Box key={bay.number} mt={2}>
        <Box bold mb={0.5} style={{ overflowWrap: 'anywhere' }}>
          Bay {bay.number}: {bay.ship || bay.status}
        </Box>
        {!!bay.ref && (
          <>
            <Box color="label" mb={1}>
              {bay.status} / {bay.silo || 'No linked materials'}
              {bay.owner_crew
                ? ' / Owner crew access'
                : bay.approved
                  ? ' / Outpost materials approved'
                  : bay.requested
                    ? ' / Materials requested'
                    : ''}
            </Box>
            <Stack wrap>
              <Button
                icon="location-crosshairs"
                disabled={busy || !bay.can_jump}
                onClick={() => act('bay_jump', { ref: bay.ref })}
              >
                Jump
              </Button>
              <Button
                icon="code"
                disabled={busy}
                onClick={() => act('bay_vv', { ref: bay.ref })}
              >
                Inspect Bay
              </Button>
              <Button
                icon="boxes-stacked"
                disabled={busy || !!bay.grant_denial || !!bay.approved}
                tooltip={bay.grant_denial}
                onClick={() => act('bay_grant_materials', { ref: bay.ref })}
              >
                Grant Materials
              </Button>
              <Button
                icon="ban"
                disabled={busy || (!bay.approved && !bay.requested)}
                onClick={() => act('bay_revoke_materials', { ref: bay.ref })}
              >
                Revoke Materials
              </Button>
              <Button
                icon="trash"
                color="bad"
                disabled={busy || !bay.can_remove_ship}
                tooltip="Delete the docked ship. Living people aboard move to the bay elevator."
                onClick={() => act('bay_remove_ship', { ref: bay.ref })}
              >
                Remove Ship
              </Button>
            </Stack>
          </>
        )}
      </Box>
    ))}
  </Section>
);

const CheckpointTools = ({
  data,
  busy,
  act,
}: {
  data: CheckpointAdminData;
  busy: boolean;
  act: DetailsProps['act'];
}) => (
  <Section title="Checkpoints (Admin)">
    <Box color="label" mb={1}>
      Free. No fees, captain rules or materials.
    </Box>
    <Stack wrap mb={1}>
      <Button
        icon="floppy-disk"
        disabled={busy}
        onClick={() => act('checkpoint_save')}
      >
        Save Checkpoint
      </Button>
      <Button
        icon="rotate"
        disabled={busy || !data.docked}
        tooltip={
          data.docked
            ? `Save ${data.docked}, delete it and rebuild it`
            : 'No ship is docked in the bay'
        }
        onClick={() => act('checkpoint_rebuild_docked')}
      >
        Rebuild Docked Ship
      </Button>
      <Button
        icon="ship"
        disabled={busy}
        tooltip="Build a new ship from the shipyard catalog for you"
        onClick={() => act('checkpoint_order_free')}
      >
        Build Ship (Free)
      </Button>
    </Stack>
    {data.rebuilds.map((rebuild) => (
      <Box key={rebuild.ref} mb={1}>
        <Box bold style={{ overflowWrap: 'anywhere' }}>
          {rebuild.name}
        </Box>
        <Box color="label">
          {rebuild.status} / {rebuild.owner}
        </Box>
        <ProgressBar value={rebuild.progress / 100} my={0.5}>
          {rebuild.progress}%
        </ProgressBar>
        <Stack wrap>
          <Button
            icon="forward-fast"
            disabled={busy || !rebuild.can_rush}
            onClick={() => act('rebuild_rush', { ref: rebuild.ref })}
          >
            Finish Now
          </Button>
          <Button
            icon="handshake"
            disabled={busy || !rebuild.can_hand_over}
            onClick={() => act('rebuild_hand_over', { ref: rebuild.ref })}
          >
            Hand Over Now
          </Button>
          <Button
            icon="stop"
            color="bad"
            disabled={busy}
            onClick={() => act('rebuild_stop', { ref: rebuild.ref })}
          >
            Stop
          </Button>
        </Stack>
      </Box>
    ))}
    {data.checkpoints.length === 0 ? (
      <Box color="label">No saved checkpoints.</Box>
    ) : (
      <Table>
        <Table.Row header>
          <Table.Cell>Ship</Table.Cell>
          <Table.Cell>Owner</Table.Cell>
          <Table.Cell>Original</Table.Cell>
          <Table.Cell collapsing>Actions</Table.Cell>
        </Table.Row>
        {data.checkpoints.map((checkpoint) => (
          <Table.Row key={checkpoint.ref}>
            <Table.Cell style={{ overflowWrap: 'anywhere' }}>
              {checkpoint.name}
              <Box color="label" fontSize="11px">
                {checkpoint.size}
              </Box>
            </Table.Cell>
            <Table.Cell>{checkpoint.owner}</Table.Cell>
            <Table.Cell>{checkpoint.original}</Table.Cell>
            <Table.Cell collapsing>
              <Button
                compact
                icon="ship"
                disabled={busy || !!checkpoint.rebuild_denial}
                tooltip={
                  checkpoint.rebuild_denial ||
                  (checkpoint.original === 'In service'
                    ? 'Builds an extra copy; the original is left alone'
                    : undefined)
                }
                onClick={() =>
                  act('checkpoint_rebuild', { ref: checkpoint.ref })
                }
              >
                Rebuild
              </Button>
              <Button
                compact
                icon="trash"
                color="bad"
                disabled={busy}
                onClick={() =>
                  act('checkpoint_delete', { ref: checkpoint.ref })
                }
              >
                Delete
              </Button>
            </Table.Cell>
          </Table.Row>
        ))}
      </Table>
    )}
  </Section>
);

/** m:ss */
const clock = (seconds: number) => {
  const total = Math.max(0, Math.ceil(seconds || 0));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
};

const conditionColor = (value: number) =>
  value >= 80 ? 'good' : value >= 50 ? 'average' : 'bad';

type PrisonStat = {
  field: 'hunger' | 'grime' | 'health' | 'mood';
  label: string;
  presets: number[];
  color: (value: number) => string;
};

// Colours follow the PRISONER_* thresholds in voidcrew/_DEFINES/player_outposts.dm.
const PRISON_STATS: PrisonStat[] = [
  {
    field: 'hunger',
    label: 'Fed',
    presets: [0, 30, 100],
    // Hungry below 40, starving below 15.
    color: (value) => (value < 15 ? 'bad' : value < 40 ? 'average' : 'good'),
  },
  {
    field: 'grime',
    label: 'Grime',
    presets: [0, 60, 100],
    // Dirty at 50, filthy at 80.
    color: (value) => (value >= 80 ? 'bad' : value >= 50 ? 'average' : 'good'),
  },
  {
    field: 'health',
    label: 'Health',
    presets: [20, 60, 100],
    // Injured below 90.
    color: (value) => (value < 50 ? 'bad' : value < 90 ? 'average' : 'good'),
  },
  {
    field: 'mood',
    label: 'Mood',
    // 10 attacks staff and fights, 40 only climbs out of an open hatch, 70 is the start value.
    presets: [10, 40, 70],
    // Attacks staff below 35, escapes below 50.
    color: (value) => (value < 35 ? 'bad' : value < 50 ? 'average' : 'good'),
  },
];

/** Seconds. 30 s starts the walk back to the cell. */
const SENTENCE_PRESETS = [30, 300, 900];

const PRISON_ALL = [
  ['starve', 'Starve'],
  ['feed', 'Feed'],
  ['dirty', 'Dirty'],
  ['clean', 'Clean'],
  ['hurt', 'Hurt'],
  ['heal', 'Heal'],
  ['enrage', 'Enrage'],
  ['calm', 'Calm'],
] as const;

const PRISON_STAGES: Record<PrisonStage, { label: string; color: string }> = {
  calm: { label: 'Calm', color: 'good' },
  grumbling: { label: 'Grumbling', color: 'average' },
  restless: { label: 'Restless', color: 'orange' },
  riot: { label: 'Riot', color: 'bad' },
};

/** Normal prisoners get no badge. */
const PRISONER_STATES: Partial<
  Record<PrisonerState, { label: string; icon: string; color: string }>
> = {
  fighting: { label: 'Fighting', icon: 'hand-back-fist', color: 'orange' },
  beaten: { label: 'Beaten', icon: 'user-injured', color: 'average' },
  rioting: { label: 'Rioting', icon: 'hand-fist', color: 'bad' },
  loose: { label: 'Loose', icon: 'person-running', color: 'bad' },
};

/** Stage thresholds: calm below 40, riot at 80. */
const tensionColor = (value: number) =>
  value >= 80 ? 'bad' : value >= 40 ? 'average' : 'good';

/** Minutes */
const PRISON_ADVANCE = [1, 5, 10];

type PrisonProps = {
  data: PrisonAdminData;
  busy: boolean;
  act: DetailsProps['act'];
};

const PrisonTools = ({ data, busy, act }: PrisonProps) => {
  const open = !!data.intake_open;
  const powered = !!data.powered;
  const conditions = data.conditions || {
    clean: 0,
    lit: 0,
    powered: 0,
    score: 0,
  };
  const prisoners = [...(data.prisoners || [])].sort((a, b) => a.cell - b.cell);
  const names: Record<string, string> = {};
  for (const prisoner of prisoners) {
    names[prisoner.ref] = prisoner.name;
  }
  const conditionParts: [string, number][] = [
    ['Clean', conditions.clean],
    ['Lit', conditions.lit],
    ['Power', conditions.powered],
    ['Score', conditions.score],
  ];
  const tension = Math.round(data.tension || 0);
  const stage = PRISON_STAGES[data.stage] || {
    label: data.stage || '?',
    color: 'label',
  };

  return (
    <Section title="Prison">
      <Stack wrap align="center" mb={1}>
        <Button
          icon={open ? 'door-open' : 'door-closed'}
          selected={open}
          disabled={busy}
          onClick={() => act('prison_intake', { open: open ? 0 : 1 })}
        >
          {open ? 'Intake: Open' : 'Intake: Closed'}
        </Button>
        <Button
          icon="user-plus"
          disabled={busy}
          onClick={() => act('prison_spawn', {})}
        >
          Spawn One
        </Button>
        <Button
          icon="users"
          disabled={busy}
          onClick={() => act('prison_fill', {})}
        >
          Fill Cells
        </Button>
        <Button
          icon="coins"
          disabled={busy}
          onClick={() => act('prison_pay_now', {})}
        >
          Pay Now
        </Button>
        <Button
          icon="trash"
          disabled={busy}
          onClick={() => act('prison_mess', {})}
        >
          Mess
        </Button>
        <Button
          icon="lightbulb"
          disabled={busy}
          onClick={() => act('prison_break_lights', {})}
        >
          Break Lights
        </Button>
        <Button
          icon={powered ? 'plug-circle-xmark' : 'plug'}
          color={powered ? undefined : 'good'}
          disabled={busy}
          onClick={() => act('prison_power', { on: powered ? 0 : 1 })}
        >
          {powered ? 'Cut Power' : 'Restore Power'}
        </Button>
        {PRISON_ADVANCE.map((minutes) => (
          <Button
            key={minutes}
            icon="forward"
            disabled={busy}
            tooltip={`Skip ${minutes} min`}
            onClick={() => act('prison_advance', { minutes })}
          >
            {`+${minutes} min`}
          </Button>
        ))}
      </Stack>
      <Stack className="OutpostPrisonAdmin__trouble" align="center" wrap mb={1}>
        <Stack.Item width="90px" bold>
          Trouble
        </Stack.Item>
        <Button
          icon="hand-fist"
          color="bad"
          disabled={busy || prisoners.length === 0}
          onClick={() => act('prison_riot', {})}
        >
          Riot
        </Button>
        <Button
          icon="dove"
          color="good"
          disabled={busy}
          onClick={() => act('prison_calm', {})}
        >
          Calm all
        </Button>
        <Stack.Item className="OutpostPrisonAdmin__tension" ml={1}>
          {'Tension '}
          <Box
            inline
            bold
            className="OutpostPrisonAdmin__tension-value"
            color={tensionColor(tension)}
          >
            {`${tension}`}
          </Box>
          <Box inline bold ml={1} color={stage.color}>
            {stage.label}
          </Box>
          {typeof data.breakout_in === 'number' ? (
            <Box inline bold ml={1} color="bad">
              {`breakout in ${clock(data.breakout_in)}`}
            </Box>
          ) : null}
        </Stack.Item>
      </Stack>

      <LabeledList>
        <LabeledList.Item label="Pay">
          {`${Math.round((data.pay_rate || 0) * 10) / 10} cr/min, ${Math.floor(
            data.paid_total || 0,
          ).toLocaleString()} cr paid`}
        </LabeledList.Item>
        <LabeledList.Item label="Arrivals">
          {!open
            ? 'Intake closed'
            : typeof data.next_arrival === 'number'
              ? `Next in ${clock(data.next_arrival)}`
              : 'None scheduled'}
          {powered ? null : (
            <Box inline color="bad" ml={1}>
              No power
            </Box>
          )}
        </LabeledList.Item>
        <LabeledList.Item label="Conditions">
          {conditionParts.map(([label, value]) => (
            <Box inline key={label} mr={1.5}>
              {`${label} `}
              <Box inline bold color={conditionColor(value || 0)}>
                {Math.round(value || 0)}
              </Box>
            </Box>
          ))}
        </LabeledList.Item>
        <LabeledList.Item label="Cells">
          {(data.cells || []).map((cell) => (
            <Box
              inline
              key={cell.number}
              mr={1.5}
              color={cell.occupant_ref ? undefined : 'label'}
            >
              {`${cell.number}: ${
                cell.occupant_ref
                  ? names[cell.occupant_ref] || `? ${cell.occupant_ref}`
                  : 'Empty'
              }`}
            </Box>
          ))}
        </LabeledList.Item>
      </LabeledList>

      <Stack align="center" wrap mt={1}>
        <Stack.Item width="90px" bold>
          All prisoners
        </Stack.Item>
        {PRISON_ALL.map(([what, label]) => (
          <Button
            key={what}
            disabled={busy || prisoners.length === 0}
            onClick={() => act('prison_all', { what })}
          >
            {label}
          </Button>
        ))}
      </Stack>

      {prisoners.length === 0 ? (
        <Box color="label" mt={1}>
          No prisoners
        </Box>
      ) : (
        prisoners.map((prisoner) => (
          <PrisonerRow
            key={prisoner.ref}
            prisoner={prisoner}
            busy={busy}
            act={act}
          />
        ))
      )}
    </Section>
  );
};

type PrisonerRowProps = {
  prisoner: PrisonAdminPrisoner;
  busy: boolean;
  act: DetailsProps['act'];
};

const PrisonerRow = ({ prisoner, busy, act }: PrisonerRowProps) => {
  const dead = !!prisoner.dead;
  const locked = busy || dead;
  const ref = prisoner.ref;
  const set = (field: string, value: number) =>
    act('prison_set', { ref, field, value });
  const loose = !dead && typeof prisoner.loose_left === 'number';
  // No badge for normal or dead prisoners, and none for Loose while the
  // loose timer shows, since it says the same thing.
  const badged =
    !dead &&
    !!prisoner.state &&
    prisoner.state !== 'normal' &&
    !(loose && prisoner.state === 'loose');
  const state = badged
    ? PRISONER_STATES[prisoner.state] || {
        label: prisoner.state,
        icon: 'circle-question',
        color: 'label',
      }
    : null;

  return (
    <Box
      className="OutpostPrisonAdmin__prisoner"
      mt={1}
      pt={1}
      style={{
        borderTop: '1px solid rgba(255, 255, 255, 0.1)',
        opacity: dead ? 0.6 : undefined,
      }}
    >
      <Stack align="center">
        <Stack.Item grow>
          <Box bold style={{ overflowWrap: 'anywhere' }}>
            {`Cell ${prisoner.cell}: ${prisoner.name}`}
            {dead ? (
              <Box inline color="bad" ml={1}>
                Dead
              </Box>
            ) : null}
            {state ? (
              <Box
                inline
                className="OutpostPrisonAdmin__state"
                color={state.color}
                ml={1}
              >
                <Icon name={state.icon} mr={0.5} />
                {state.label}
              </Box>
            ) : null}
            {loose ? (
              <Box
                inline
                className="OutpostPrisonAdmin__loose"
                color="bad"
                ml={1}
              >
                <Icon name="person-running" mr={0.5} />
                {`loose ${clock(prisoner.loose_left as number)}`}
              </Box>
            ) : null}
          </Box>
          <Box color="label" fontSize="11px">
            {[prisoner.personality, prisoner.crime, prisoner.activity]
              .filter(Boolean)
              .join(' / ')}
          </Box>
        </Stack.Item>
        <Stack.Item>
          <Button
            compact
            icon="hand-back-fist"
            disabled={locked}
            onClick={() => act('prison_fight', { ref })}
          >
            Fight
          </Button>
          <Button
            compact
            icon="burst"
            disabled={locked}
            onClick={() => act('prison_breakout', { ref })}
          >
            Breakout
          </Button>
          <Button
            compact
            icon="person-walking-arrow-right"
            disabled={locked}
            onClick={() => act('prison_release', { ref })}
          >
            Release
          </Button>
          <Button.Confirm
            compact
            icon="skull"
            color="bad"
            confirmContent="Kill?"
            disabled={locked}
            onClick={() => act('prison_kill', { ref })}
          >
            Kill
          </Button.Confirm>
          <Button.Confirm
            compact
            icon="trash"
            color="bad"
            confirmContent="Remove?"
            disabled={busy}
            onClick={() => act('prison_remove', { ref })}
          >
            Remove
          </Button.Confirm>
        </Stack.Item>
      </Stack>
      <Stack align="center" wrap mt={0.5}>
        {PRISON_STATS.map((stat) => {
          const value = Math.round(prisoner[stat.field] || 0);
          return (
            <Stack.Item
              key={stat.field}
              className={`OutpostPrisonAdmin__stat OutpostPrisonAdmin__stat--${stat.field}`}
              mr={1}
            >
              <Box inline bold color={stat.color(value)} mr={0.5}>
                {stat.label}
              </Box>
              <NumberInput
                value={value}
                minValue={0}
                maxValue={100}
                step={1}
                stepPixelSize={2}
                width="38px"
                disabled={locked}
                onChange={(next) => set(stat.field, Math.round(next))}
              />
              {stat.presets.map((preset) => (
                <Button
                  key={preset}
                  compact
                  disabled={locked}
                  onClick={() => set(stat.field, preset)}
                >
                  {preset}
                </Button>
              ))}
            </Stack.Item>
          );
        })}
        <Stack.Item
          className="OutpostPrisonAdmin__stat OutpostPrisonAdmin__stat--care"
          mr={1}
          color="label"
        >
          {`Care ${Math.round(prisoner.care || 0)}`}
        </Stack.Item>
        <Stack.Item className="OutpostPrisonAdmin__stat OutpostPrisonAdmin__stat--sentence">
          <Box inline bold mr={0.5}>
            Left
          </Box>
          <NumberInput
            value={Math.max(0, Math.round(prisoner.sentence_left || 0))}
            minValue={0}
            maxValue={3600}
            step={30}
            stepPixelSize={4}
            width="48px"
            format={clock}
            disabled={locked}
            onChange={(next) => set('sentence', Math.round(next))}
          />
          {SENTENCE_PRESETS.map((preset) => (
            <Button
              key={preset}
              compact
              disabled={locked}
              onClick={() => set('sentence', preset)}
            >
              {clock(preset)}
            </Button>
          ))}
        </Stack.Item>
      </Stack>
    </Box>
  );
};
