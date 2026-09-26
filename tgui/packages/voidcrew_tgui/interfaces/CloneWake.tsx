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

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Clone = {
  ref: string;
  site: string;
  site_kind: 'ship' | 'outpost' | 'other';
  zone: 'green' | 'yellow' | 'red' | null;
  ready: BooleanLike;
  offline: BooleanLike;
  percent: number;
  eta: number;
  single_use: BooleanLike;
  unsafe_air: BooleanLike;
  denial: string | null;
  warning: string | null;
};

type Data = {
  alive: BooleanLike;
  clones: Clone[];
};

const ZONE_LABELS = {
  green: { label: 'Neutral Zone', color: 'good' },
  yellow: { label: 'Contested Zone', color: 'average' },
  red: { label: 'Lawless Zone', color: 'bad' },
};

const SITE_LABELS = {
  ship: 'Ship',
  outpost: 'Outpost',
  other: 'Other',
};

const formatEta = (seconds: number) => {
  const minutes = Math.floor(seconds / 60);
  const rest = seconds % 60;
  return minutes > 0 ? `${minutes} min ${rest} s` : `${rest} s`;
};

const CloneRow = (props: { clone: Clone; alive: BooleanLike }) => {
  const { act } = useBackend<Data>();
  const { clone, alive } = props;
  const zone = clone.zone ? ZONE_LABELS[clone.zone] : null;
  const canWake = !alive && !clone.denial;
  let wakeTooltip: string | undefined;
  if (alive) {
    wakeTooltip = 'You are still alive.';
  } else if (clone.denial) {
    wakeTooltip = clone.denial;
  }

  return (
    <Section
      title={clone.site}
      buttons={
        <>
          <Button icon="eye" onClick={() => act('view', { ref: clone.ref })}>
            View
          </Button>
          <Button
            icon="user"
            color="good"
            disabled={!canWake}
            tooltip={wakeTooltip}
            onClick={() => act('wake', { ref: clone.ref })}
          >
            Wake
          </Button>
        </>
      }
    >
      <LabeledList>
        <LabeledList.Item label="Site">
          {SITE_LABELS[clone.site_kind] || 'Other'}
          {zone ? (
            <Box as="span" color={zone.color} ml={1}>
              ({zone.label})
            </Box>
          ) : null}
        </LabeledList.Item>
        <LabeledList.Item label="Clone">
          {clone.ready ? (
            <Box color="good">Fully grown</Box>
          ) : (
            <ProgressBar value={clone.percent / 100}>
              {clone.percent}%
              {!clone.offline && clone.eta > 0
                ? `, ready in ${formatEta(clone.eta)}`
                : ''}
            </ProgressBar>
          )}
        </LabeledList.Item>
        {clone.single_use ? (
          <LabeledList.Item label="Uses">
            One life: the clone is used up when you wake.
          </LabeledList.Item>
        ) : null}
      </LabeledList>
      {clone.offline ? (
        <NoticeBox danger>The vat has no power. The clone is dissolving.</NoticeBox>
      ) : null}
      {clone.unsafe_air ? (
        <NoticeBox>The air at this vat is not safe to breathe.</NoticeBox>
      ) : null}
      {clone.warning ? <NoticeBox>{clone.warning}</NoticeBox> : null}
      {clone.denial && !clone.offline ? (
        <NoticeBox info>{clone.denial}</NoticeBox>
      ) : null}
    </Section>
  );
};

export const CloneWake = (props) => {
  const { data } = useBackend<Data>();
  const { alive, clones = [] } = data;

  return (
    <Window title="Wake in a Clone" width={420} height={480}>
      <Window.Content scrollable>
        <Stack vertical>
          {alive ? (
            <Stack.Item>
              <NoticeBox>
                You are still alive. You can wake in a clone after you die.
              </NoticeBox>
            </Stack.Item>
          ) : null}
          {clones.length === 0 ? (
            <Stack.Item>
              <NoticeBox info>You have no clones.</NoticeBox>
            </Stack.Item>
          ) : (
            clones.map((clone) => (
              <Stack.Item key={clone.ref}>
                <CloneRow clone={clone} alive={alive} />
              </Stack.Item>
            ))
          )}
        </Stack>
      </Window.Content>
    </Window>
  );
};
