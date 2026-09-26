/**
 * The wanted board on a trader outpost's concourse (bounty_outpost.dm, P6).
 * Read-only: the public bounties with their mugshots, tier, reward and
 * where they were last seen. Mugshots come in the static data.
 */
import { Box, NoticeBox, Section, Stack } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Entry = {
  id: string;
  name: string;
  alias: string | null;
  tier: string;
  tier_level: number;
  crime: string | null;
  reward: number;
  // Trade vouchers on top of the reward, on a full-share turn-in
  vouchers?: number;
  // WANTED: DEAD, paid only on the kill
  kill_only?: boolean;
  place: string;
  // The fugitive is somewhere on this concourse
  here?: boolean;
  time_left: number | null;
};

type Data = {
  entries: Entry[];
  mugshots: Record<string, string>;
};

const tierColor = (level: number) =>
  level >= 3 ? 'bad' : level === 2 ? 'average' : 'label';

const timeText = (seconds: number | null) => {
  if (seconds === null || seconds === undefined) {
    return null;
  }
  const minutes = Math.ceil(seconds / 60);
  return minutes <= 1 ? 'Under a minute left' : `${minutes} minutes left`;
};

const WantedCard = (props: { entry: Entry; mugshot?: string }) => {
  const { entry, mugshot } = props;
  const time = timeText(entry.time_left);
  const vouchers = entry.vouchers ?? 0;
  const voucherText =
    vouchers > 0
      ? ` + ${vouchers} trade voucher${vouchers > 1 ? 's' : ''}`
      : '';
  return (
    <Section>
      <Stack>
        <Stack.Item>
          {mugshot ? (
            <img
              src={mugshot}
              width={64}
              height={64}
              style={{ imageRendering: 'pixelated' }}
            />
          ) : (
            <Box
              width="64px"
              height="64px"
              backgroundColor="rgba(0, 0, 0, 0.3)"
              textAlign="center"
              lineHeight="64px"
              color="label"
            >
              No photo
            </Box>
          )}
        </Stack.Item>
        <Stack.Item grow>
          <Box bold>
            {entry.name}
            {entry.alias ? (
              <Box as="span" color="label" bold={false}>
                {` "${entry.alias}"`}
              </Box>
            ) : null}
          </Box>
          <Box color={tierColor(entry.tier_level)} bold>
            {entry.kill_only ? 'WANTED: DEAD' : entry.tier}
          </Box>
          {entry.crime ? <Box>Wanted for {entry.crime}.</Box> : null}
          <Box>{entry.place}.</Box>
          {entry.here ? (
            <Box bold color="bad">
              Seen on this concourse.
            </Box>
          ) : null}
          <Box color="good">
            {entry.kill_only
              ? `Reward: ${entry.reward} cr${voucherText}, dead only`
              : `Reward: up to ${entry.reward} cr${voucherText}`}
          </Box>
          {time ? <Box color="label">{time}</Box> : null}
        </Stack.Item>
      </Stack>
    </Section>
  );
};

export const WantedBoard = (props) => {
  const { data } = useBackend<Data>();
  const { entries = [], mugshots = {} } = data;

  return (
    <Window width={420} height={520}>
      <Window.Content scrollable>
        {entries.length === 0 ? (
          <NoticeBox>Nobody is wanted right now.</NoticeBox>
        ) : (
          entries.map((entry) => (
            <WantedCard
              key={entry.id}
              entry={entry}
              mugshot={mugshots[entry.id]}
            />
          ))
        )}
        <Box color="label" mt={1}>
          Hunts are taken on at your ship's mission console.
        </Box>
      </Window.Content>
    </Window>
  );
};
