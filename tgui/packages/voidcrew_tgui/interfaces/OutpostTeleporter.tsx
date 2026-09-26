import {
  Box,
  Button,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';
import { useBackend } from '../../tgui/backend';
import { Window } from '../../tgui/layouts';

type Destination = {
  id: string;
  name: string;
  kind: 'market' | 'colony';
  zone: number | null;
  zoneName: string;
  fee: number;
  chargeTime: number;
  available: BooleanLike;
  reason: string | null;
};

type Charging = {
  destination: string;
  secondsLeft: number;
  total: number;
  mine: BooleanLike;
};

type Data = {
  padName: string;
  online: BooleanLike;
  trader: BooleanLike;
  zone: number | null;
  zoneName: string;
  onPad: BooleanLike;
  blocked: string | null;
  cooldownLeft: number;
  payer: string | null;
  balance: number | null;
  charging: Charging | null;
  incoming: BooleanLike;
  destinations: Destination[];
};

const ZONE_COLORS: Record<number, string> = {
  1: 'good',
  2: 'average',
  3: 'bad',
};

const zoneColor = (zone: number | null) =>
  zone ? ZONE_COLORS[zone] || 'label' : 'label';

export const OutpostTeleporter = () => {
  const { act, data } = useBackend<Data>();
  const {
    padName,
    online,
    zone,
    zoneName,
    blocked,
    payer,
    balance,
    charging,
    incoming,
    destinations = [],
  } = data;

  return (
    <Window width={440} height={520} title="Network pad">
      <Window.Content scrollable>
        <Section title={padName}>
          <LabeledList>
            <LabeledList.Item label="Zone" color={zoneColor(zone)}>
              {zoneName}
            </LabeledList.Item>
            <LabeledList.Item label="Pays">
              {payer
                ? `${payer} (${balance ?? 0} cr)`
                : 'No account on your ID'}
            </LabeledList.Item>
          </LabeledList>
        </Section>
        {!online ? (
          <NoticeBox danger>This pad is not linked to the network.</NoticeBox>
        ) : charging ? (
          <Section
            title={`Charging for ${charging.destination}`}
            buttons={
              charging.mine ? (
                <Button icon="xmark" color="bad" onClick={() => act('cancel')}>
                  Cancel
                </Button>
              ) : null
            }
          >
            <ProgressBar
              value={Math.max(0, charging.total - charging.secondsLeft)}
              maxValue={Math.max(charging.total, 0.1)}
            >
              {`${charging.secondsLeft} s`}
            </ProgressBar>
            <Box mt={1} color="label">
              Stay on the pad. Moving off it, being hurt or passing out cancels
              the trip.
            </Box>
          </Section>
        ) : (
          <DestinationList
            destinations={destinations}
            blocked={blocked}
            incoming={incoming}
          />
        )}
      </Window.Content>
    </Window>
  );
};

type ListProps = {
  destinations: Destination[];
  blocked: string | null;
  incoming: BooleanLike;
};

const DestinationList = (props: ListProps) => {
  const { act } = useBackend<Data>();
  const { destinations, blocked, incoming } = props;
  return (
    <Section
      title="Destinations"
      buttons={
        blocked === 'Stand on the pad.' ? (
          <Button
            icon="person-walking-arrow-right"
            tooltip="Moves someone idle off the pad"
            onClick={() => act('clear_pad')}
          >
            Clear pad
          </Button>
        ) : null
      }
    >
      {blocked ? <NoticeBox>{blocked}</NoticeBox> : null}
      {incoming ? (
        <NoticeBox info>Someone is arriving on this pad.</NoticeBox>
      ) : null}
      {destinations.length === 0 ? (
        <Box color="label">No other outpost is on the network yet.</Box>
      ) : (
        <Stack vertical>
          {destinations.map((dest) => (
            <Stack.Item key={dest.id}>
              <Stack align="center">
                <Stack.Item grow>
                  <Box bold>{dest.name}</Box>
                  <Box color={zoneColor(dest.zone)} fontSize={0.9}>
                    {`${dest.kind === 'market' ? 'Trading outpost' : 'Outpost'}, ${dest.zoneName}, ${dest.chargeTime} s charge`}
                  </Box>
                </Stack.Item>
                <Stack.Item>
                  <Box color={dest.fee > 0 ? 'average' : 'good'}>
                    {dest.fee > 0 ? `${dest.fee} cr` : 'Free'}
                  </Box>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="bolt"
                    disabled={!dest.available || !!blocked}
                    tooltip={dest.reason || blocked || undefined}
                    onClick={() =>
                      act('depart', { id: dest.id, fee: dest.fee })
                    }
                  >
                    {dest.available ? 'Travel' : dest.reason}
                  </Button>
                </Stack.Item>
              </Stack>
            </Stack.Item>
          ))}
        </Stack>
      )}
    </Section>
  );
};
