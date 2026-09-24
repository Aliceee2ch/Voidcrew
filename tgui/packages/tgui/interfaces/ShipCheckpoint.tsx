import { useEffect, useState } from 'react';
import {
  Box,
  Button,
  ByondUi,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';
import { useBackend } from '../backend';
import { Window } from '../layouts';

type Data = {
  outpost: string;
  bay_view: string | null;
  working: BooleanLike;
  error: string | null;
  notice: string | null;
  save_cost: number;
  update_cost: number;
  has_checkpoint: BooleanLike;
  bays: {
    ref: string;
    name: string;
    number: number;
    balance: number;
    denial: string | null;
  }[];
  blueprints: {
    ref: string;
    name: string;
    width: number;
    height: number;
    denial: string | null;
  }[];
  rebuilds: {
    ref: string;
    name: string;
    status: string;
    progress: number;
  }[];
};

export const ShipCheckpoint = () => {
  const { data, act } = useBackend<Data>();
  const cost = data.has_checkpoint ? data.update_cost : data.save_cost;
  const rebuilds = data.rebuilds || [];
  return (
    <Window width={560} height={860} title={`${data.outpost} Checkpoints`}>
      <Window.Content scrollable>
        {!!data.bay_view && (
          <Section title="Ship bay">
            <BayView key={data.bay_view} mapRef={data.bay_view} />
          </Section>
        )}
        {!!data.error && <NoticeBox danger>{data.error}</NoticeBox>}
        {!!data.notice && <NoticeBox success>{data.notice}</NoticeBox>}
        {!!data.working && <NoticeBox>Processing checkpoint...</NoticeBox>}
        {rebuilds.length > 0 && (
          <Section title="Reconstruction">
            {rebuilds.map((rebuild) => (
              <Box key={rebuild.ref} mb={1}>
                <Box bold style={{ overflowWrap: 'anywhere' }}>
                  {rebuild.name}
                </Box>
                <Box color="label" mb={1}>
                  {rebuild.status}
                </Box>
                <ProgressBar value={rebuild.progress / 100}>
                  {rebuild.progress}%
                </ProgressBar>
              </Box>
            ))}
          </Section>
        )}
        <Section title="Ship checkpoints">
          <LabeledList>
            <LabeledList.Item label="Save / update">
              {data.save_cost.toLocaleString()} cr /{' '}
              {data.update_cost.toLocaleString()} cr
            </LabeledList.Item>
            <LabeledList.Item label="Includes">
              Hull, infrastructure, constructible machinery and fitted upgrades
            </LabeledList.Item>
            <LabeledList.Item label="Restocked">
              Charged batteries and engine fuel
            </LabeledList.Item>
            <LabeledList.Item label="Excluded">
              Cargo, ammunition, stored materials and other supplies
            </LabeledList.Item>
            <LabeledList.Item label="Recovery">
              One prepaid rebuild after the original ship is lost or abandoned
            </LabeledList.Item>
          </LabeledList>
          <Box color="label" mt={1}>
            One checkpoint per captain at this outpost. Updating replaces it
            with the latest design of the docked ship you choose. Fees are spent
            from that ship&apos;s account.
          </Box>
        </Section>
        <Section title="Docked ships">
          {data.bays.length === 0 && (
            <Box color="label">
              Dock a ship you command in a ship bay to save or update.
            </Box>
          )}
          {data.bays.map((bay) => (
            <Box key={bay.ref} mb={2}>
              <Box bold mb={1} style={{ overflowWrap: 'anywhere' }}>
                Bay {bay.number}: {bay.name}
              </Box>
              <Box color="label" mb={1}>
                Ship account: {bay.balance.toLocaleString()} cr
              </Box>
              {!!bay.denial && (
                <Box color="label" mb={1}>
                  {bay.denial}
                </Box>
              )}
              <Button
                icon="floppy-disk"
                disabled={!!data.working || !!bay.denial || bay.balance < cost}
                onClick={() =>
                  act(data.has_checkpoint ? 'update' : 'save', { ref: bay.ref })
                }
              >
                {data.has_checkpoint ? 'Update checkpoint' : 'Save checkpoint'}{' '}
                ({cost.toLocaleString()} cr)
              </Button>
            </Box>
          ))}
        </Section>
        <Section title="Your checkpoint">
          {data.blueprints.length === 0 && (
            <Box color="label">No checkpoint saved here.</Box>
          )}
          {data.blueprints.map((checkpoint) => (
            <Box key={checkpoint.ref} mb={1}>
              <Box bold style={{ overflowWrap: 'anywhere' }}>
                {checkpoint.name}
              </Box>
              <Box color="label" mb={1}>
                {checkpoint.width} x {checkpoint.height} tiles
              </Box>
              {!!checkpoint.denial && (
                <Box color="label" mb={1}>
                  {checkpoint.denial}
                </Box>
              )}
              <Button
                icon="ship"
                disabled={!!data.working || !!checkpoint.denial}
                onClick={() => act('rebuild', { ref: checkpoint.ref })}
              >
                Rebuild ship (prepaid)
              </Button>
            </Box>
          ))}
        </Section>
      </Window.Content>
    </Window>
  );
};

/**
 * Live view of the bay pad. A map control measures its box once, when it mounts, and the
 * window is still settling right after opening, so the control mounts a moment later.
 * The server registers the view into it only once it exists.
 */
const BayView = ({ mapRef }: { mapRef: string }) => {
  const { act } = useBackend<Data>();
  const [settled, setSettled] = useState(false);
  useEffect(() => {
    const timer = setTimeout(() => setSettled(true), 300);
    return () => clearTimeout(timer);
  }, []);
  useEffect(() => {
    if (settled) {
      act('bay_view_mounted', { map: mapRef });
    }
  }, [settled, mapRef]);
  if (!settled) {
    return <Box height="260px" />;
  }
  return (
    <ByondUi
      key={mapRef}
      width="100%"
      height="260px"
      params={{ id: mapRef, type: 'map' }}
    />
  );
};
