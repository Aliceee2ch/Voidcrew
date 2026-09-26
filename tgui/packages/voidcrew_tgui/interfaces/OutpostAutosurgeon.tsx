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

type Procedure = { id: string; name: string; desc: string };

type Occupant = {
  name: string;
  stat: string;
  health: number;
  maxHealth: number;
  brute: number;
  burn: number;
  tox: number;
  oxy: number;
  brain: number;
};

type Offer = {
  id: string;
  name: string;
  available: BooleanLike;
  reason: string | null;
  seconds: number;
};

type Run = {
  id: string;
  name: string;
  elapsed: number;
  total: number;
  stage: string;
};

type Data = {
  procedures: Procedure[];
  lab_name: string;
  occupant: Occupant | null;
  occupant_is_user: BooleanLike;
  can_unbuckle: BooleanLike;
  consent_denial: string | null;
  pass: { valid: BooleanLike; exempt: BooleanLike; seconds_left: number };
  offers: Offer[];
  run: Run | null;
  powered: BooleanLike;
};

const formatTime = (seconds: number) => {
  const whole = Math.max(0, Math.round(seconds));
  const minutes = Math.floor(whole / 60);
  const rest = whole % 60;
  return minutes > 0 ? `${minutes}m ${rest}s` : `${rest}s`;
};

const PassLine = (props: { pass: Data['pass'] }) => {
  const { pass } = props;
  if (pass.exempt) {
    return <Box color="good">Free for members.</Box>;
  }
  if (pass.valid) {
    return (
      <Box color="good">Lab pass: {formatTime(pass.seconds_left)} left.</Box>
    );
  }
  return (
    <Box color="average">No lab pass. Buy one at the terminal by the door.</Box>
  );
};

const OccupantPanel = (props: { occupant: Occupant }) => {
  const { occupant } = props;
  return (
    <LabeledList>
      <LabeledList.Item label="Patient">{occupant.name}</LabeledList.Item>
      <LabeledList.Item label="State">{occupant.stat}</LabeledList.Item>
      <LabeledList.Item label="Health">
        <ProgressBar
          value={occupant.health}
          minValue={-100}
          maxValue={occupant.maxHealth}
          ranges={{
            good: [occupant.maxHealth * 0.7, Infinity],
            average: [0, occupant.maxHealth * 0.7],
            bad: [-Infinity, 0],
          }}
        >
          {occupant.health} / {occupant.maxHealth}
        </ProgressBar>
      </LabeledList.Item>
      <LabeledList.Item label="Damage">
        Brute {occupant.brute} · Burn {occupant.burn} · Toxin {occupant.tox} ·
        Oxygen {occupant.oxy} · Brain {occupant.brain}
      </LabeledList.Item>
    </LabeledList>
  );
};

export const OutpostAutosurgeon = () => {
  const { act, data } = useBackend<Data>();
  const {
    procedures = [],
    lab_name,
    occupant,
    occupant_is_user,
    can_unbuckle,
    consent_denial,
    pass,
    offers = [],
    run,
    powered,
  } = data;
  const descById: Record<string, string> = {};
  for (const procedure of procedures) {
    descById[procedure.id] = procedure.desc;
  }
  const canOrder = !!occupant_is_user && !consent_denial && !run;
  return (
    <Window width={480} height={560} title={`Auto-surgeon: ${lab_name}`}>
      <Window.Content scrollable>
        {!powered ? <NoticeBox danger>No power.</NoticeBox> : null}
        <Section
          title="Patient"
          buttons={
            occupant ? (
              <Button
                icon="person-walking"
                disabled={!occupant_is_user && !can_unbuckle}
                onClick={() => act('get_up')}
              >
                {occupant_is_user ? 'Get up' : 'Help off'}
              </Button>
            ) : null
          }
        >
          {occupant ? (
            <OccupantPanel occupant={occupant} />
          ) : (
            <Box color="label">Lie on the slab to use it.</Box>
          )}
          <Box mt={1}>{pass ? <PassLine pass={pass} /> : null}</Box>
        </Section>
        {run ? (
          <Section
            title={run.name}
            buttons={
              occupant_is_user ? (
                <Button icon="stop" color="bad" onClick={() => act('cancel')}>
                  Stop
                </Button>
              ) : null
            }
          >
            <Box mb={1}>{run.stage}</Box>
            <ProgressBar value={run.elapsed} maxValue={Math.max(1, run.total)}>
              {formatTime(run.elapsed)} / {formatTime(run.total)}
            </ProgressBar>
          </Section>
        ) : null}
        {occupant ? (
          <Section title="Procedures">
            {occupant_is_user && consent_denial && !run ? (
              <NoticeBox>{consent_denial}</NoticeBox>
            ) : null}
            {!occupant_is_user ? (
              <Box color="label" mb={1}>
                Only the patient can order a procedure.
              </Box>
            ) : null}
            {offers.length === 0 ? (
              <Box color="label">No procedures are offered here.</Box>
            ) : (
              <Stack vertical>
                {offers.map((offer) => (
                  <Stack.Item key={offer.id}>
                    <Stack align="center">
                      <Stack.Item grow>
                        <Box bold>{offer.name}</Box>
                        <Box color="label" fontSize="0.9em">
                          {offer.available
                            ? descById[offer.id]
                            : offer.reason}
                        </Box>
                      </Stack.Item>
                      <Stack.Item>
                        <Button
                          icon="play"
                          disabled={!canOrder || !offer.available}
                          tooltip={
                            offer.available
                              ? `About ${formatTime(offer.seconds)}`
                              : undefined
                          }
                          onClick={() => act('start', { id: offer.id })}
                        >
                          Start
                        </Button>
                      </Stack.Item>
                    </Stack>
                  </Stack.Item>
                ))}
              </Stack>
            )}
          </Section>
        ) : null}
      </Window.Content>
    </Window>
  );
};
