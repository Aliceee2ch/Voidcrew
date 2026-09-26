import {
  Box,
  Button,
  Dropdown,
  Icon,
  LabeledList,
  NoticeBox,
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
  pricer?: BooleanLike;
};

/** One service room's admin rows (admin_ui_data()); a row with an action gets a button. */
type ServiceAdminRoom = {
  id: string;
  name: string;
  rows?: { label: string; action: string | null; ref: string | null }[] | null;
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
  /** Ckey billed as a visitor here, or null. */
  playtest_visitor?: string | null;
  services?: ServiceAdminRoom[] | null;
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

/** "release_locker" -> "Release locker". */
const actionLabel = (action: string) => modeLabel(action.replace(/_/g, ' '));

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
              icon="user-secret"
              selected={!!selected.playtest_visitor}
              disabled={busy}
              tooltip="Bill yourself as a visitor here: services charge you and staff doors stay shut. Management rights are unchanged."
              onClick={() => mutate('playtest_visitor')}
            >
              {selected.playtest_visitor
                ? 'Stop Visitor Billing'
                : 'Bill Me as a Visitor'}
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
          {selected.playtest_visitor ? (
            <NoticeBox mt={1}>
              Billing {selected.playtest_visitor} as a visitor.
            </NoticeBox>
          ) : null}
        </Section>
      </Stack.Item>

      <Stack.Item>
        <ShipBays data={selected.ship_bays} busy={busy} act={mutate} />
      </Stack.Item>

      <Stack.Item>
        <ServiceRooms rooms={selected.services} busy={busy} act={mutate} />
      </Stack.Item>

      {!!selected.checkpoints?.enabled && (
        <Stack.Item>
          <CheckpointTools
            data={selected.checkpoints}
            busy={busy}
            act={mutate}
          />
        </Stack.Item>
      )}

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
                    {!!resident.pricer && (
                      <Box inline color="teal" ml={1}>
                        Pricer
                      </Box>
                    )}
                    {!resident.steward &&
                    !resident.treasurer &&
                    !resident.pricer ? (
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
                      icon="tags"
                      disabled={busy}
                      tooltip="Pricing: sets service prices and takes shop stock free"
                      onClick={() =>
                        mutate('delegate', {
                          ref: resident.ref,
                          role: 'pricer',
                        })
                      }
                    >
                      {resident.pricer ? 'Unmake Pricer' : 'Pricer'}
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

const ServiceRooms = ({
  rooms,
  busy,
  act,
}: {
  rooms?: ServiceAdminRoom[] | null;
  busy: boolean;
  act: DetailsProps['act'];
}) => (
  <Section title="Service Rooms">
    {!rooms?.length ? (
      <Box color="label">No service rooms installed.</Box>
    ) : (
      rooms.map((room) => (
        <Box key={room.id} mb={1}>
          <Box bold mb={0.5}>
            {room.name || room.id}
          </Box>
          {!room.rows?.length ? (
            <Box color="label">Nothing to manage.</Box>
          ) : (
            <Table>
              {room.rows.map((row, index) => (
                <Table.Row key={`${row.ref ?? ''}:${row.label}:${index}`}>
                  <Table.Cell style={{ overflowWrap: 'anywhere' }}>
                    {row.label}
                  </Table.Cell>
                  <Table.Cell collapsing>
                    {row.action ? (
                      <Button
                        compact
                        disabled={busy}
                        onClick={() =>
                          act('service_admin', {
                            id: room.id,
                            service_action: row.action,
                            ref: row.ref,
                          })
                        }
                      >
                        {actionLabel(row.action)}
                      </Button>
                    ) : null}
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          )}
        </Box>
      ))
    )}
  </Section>
);

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
