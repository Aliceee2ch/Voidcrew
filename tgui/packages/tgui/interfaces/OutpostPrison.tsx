import type { ReactNode } from 'react';
import { Button, Icon, ProgressBar } from 'tgui-core/components';
import { formatMoney } from 'tgui-core/format';
import { keyOfMatchingRange } from 'tgui-core/math';
import type { BooleanLike } from 'tgui-core/react';
import { useBackend } from '../backend';
import { Window } from '../layouts';

type PrisonerStatus =
  | 'present'
  | 'arriving'
  | 'leaving'
  | 'dead'
  | 'confined'
  | 'rioting'
  | 'loose'
  | 'subject';

/** Priority, highest first: breakout, escape, riot, riot_imminent, hatch_empty */
type PrisonAlarm =
  | 'riot'
  | 'escape'
  | 'breakout'
  | 'riot_imminent'
  | 'hatch_empty';

type IntakeState =
  | 'open'
  | 'closed'
  | 'suspended'
  | 'debt'
  | 'experiment'
  | 'no_power';

type PrisonStage = 'calm' | 'grumbling' | 'restless' | 'riot';

type Prisoner = {
  ref: string;
  name: string;
  /** 1 to capacity */
  cell: number;
  crime: string;
  /** seconds */
  sentence_left: number;
  status: PrisonerStatus;
};

type Conditions = {
  /** 0-100 each; powered is graded */
  clean: number;
  lit: number;
  powered: number;
  score: number;
  /** tiles with mess */
  mess_spots?: number;
  /** cell numbers */
  dark_cells?: number[];
  /** APC cell percent while not charging, null otherwise */
  battery?: number | null;
};

type Money = { paid: number; spent: number; fined: number; net: number };

type HatchStock = {
  meals: number;
  clean_suits: number;
  dirty_suits: number;
  /** items, both hatches together */
  capacity: number;
  /** null with nobody to feed */
  lasts_minutes: number | null;
};

type Trouble = {
  stage: PrisonStage;
  /** 0-100 */
  tension: number;
  /** seconds, null when not subdued */
  subdued_left: number | null;
  riot_imminent: BooleanLike;
  /** seconds, null when no riot */
  breakout_in: number | null;
  loose: { name: string; area: string; time_left: number }[];
};

type GuardStatus =
  | 'arriving'
  | 'post'
  | 'rounds'
  | 'routine'
  | 'responding'
  | 'riot'
  | 'down'
  | 'away';

type Guard = {
  ref: string;
  name: string;
  rank: string;
  status: GuardStatus;
  /** seconds until a down or away guard is back, null otherwise */
  back_in: number | null;
};

type Guards = {
  max: number;
  hire_cost: number;
  /** cr/min per guard, only while a member is home */
  wage: number;
  can_manage: BooleanLike;
  /** a manager, a free slot, and the fee in the treasury */
  can_hire: BooleanLike;
  /** wages skipped in a row */
  unpaid: number;
  list: Guard[];
};

type TurretState = 'loose' | 'on' | 'off' | 'broken' | 'no_power';

type Security = {
  turret_max: number;
  turret_cost: number;
  /** a manager, under the cap, and the fee in the treasury */
  can_buy: BooleanLike;
  turrets: { ref: string; state: TurretState }[];
};

/** Guards, turrets and mail (outpost_prison_extras.dm); null on an unlinked console */
type Extras = {
  guards?: Guards | null;
  security?: Security | null;
  /** undelivered letters */
  mail?: { waiting: number } | null;
};

type ExperimentForm = 'unknown' | 'hulk' | 'fly' | 'nightmare' | 'changeling';

type ExperimentStage =
  | 'offered'
  | 'dosed'
  | 'twitching'
  | 'incubating'
  | 'live'
  | 'vents'
  | 'horror'
  | 'contained'
  | 'failed';

type Experiment = {
  /** "unknown" for a blind serum until the creature shows */
  form: ExperimentForm;
  stage: ExperimentStage;
  subject: string | null;
  /** seconds; a paused clock keeps its value */
  time_left: number | null;
  researcher_present: BooleanLike;
  fee_paid: number;
  bonus_paid: number;
  /** "up" or "regenerating" while the horror is out; time_left is then the time until it gets up */
  horror?: string | null;
};

export type OutpostPrisonData = {
  linked: BooleanLike;
  powered: BooleanLike;
  intake_open: BooleanLike;
  /** seconds, null when nothing is scheduled */
  next_arrival: number | null;
  capacity: number;
  /** cr/min for every prisoner right now */
  pay_rate: number;
  paid_total: number;
  can_manage: BooleanLike;
  conditions: Conditions;
  prisoners: Prisoner[];
  log: { time: string; text: string }[];
  /** null when nothing is wrong */
  alarm?: PrisonAlarm | null;
  alarm_text?: string;
  // Everything below may be missing from an older payload; its part of the console is then hidden.
  intake_state?: IntakeState;
  intake_note?: string | null;
  /** 0-100: how much of full pay the prisoners serving now earn */
  pay_percent?: number;
  money?: Money;
  /** treasury debt, 0 when none */
  debt?: number;
  /** missing means the console leaves it to the server */
  can_pay_debt?: BooleanLike;
  visitors_allowed?: BooleanLike;
  hatch?: HatchStock;
  trouble?: Trouble;
  extras?: Extras | null;
  /** null with no experiment */
  experiment?: Experiment | null;
};

type Act = (action: string, params?: Record<string, unknown>) => unknown;
type Props = { data: OutpostPrisonData; act: Act };
type Ranges = Record<string, [number, number]>;
type Tone = 'good' | 'average' | 'bad';

const CONDITION_RANGES: Ranges = {
  good: [80, Infinity],
  average: [50, 80],
  bad: [-Infinity, 50],
};

/** Readouts: green from 90%, red under 50%, amber between. */
const PAY_RANGES: Ranges = {
  good: [90, Infinity],
  average: [50, 90],
  bad: [-Infinity, 50],
};

/** Present prisoners get no badge. */
const STATUSES: Partial<
  Record<PrisonerStatus, { label: string; icon: string; tone: Tone }>
> = {
  arriving: { label: 'Arriving', icon: 'right-to-bracket', tone: 'good' },
  leaving: { label: 'Leaving', icon: 'right-from-bracket', tone: 'average' },
  dead: { label: 'Dead', icon: 'skull', tone: 'bad' },
  confined: { label: 'Confined', icon: 'lock', tone: 'average' },
  rioting: { label: 'Rioting', icon: 'hand-fist', tone: 'bad' },
  loose: { label: 'Loose', icon: 'person-running', tone: 'bad' },
  subject: { label: 'Subject', icon: 'flask', tone: 'average' },
};

/** Red alarms pulse. */
const ALARMS: Record<
  PrisonAlarm,
  { label: string; icon: string; tone: 'red' | 'amber' }
> = {
  riot: { label: 'Riot', icon: 'hand-fist', tone: 'red' },
  escape: { label: 'Escape', icon: 'person-running', tone: 'amber' },
  breakout: { label: 'Breakout', icon: 'burst', tone: 'red' },
  riot_imminent: { label: 'Riot imminent', icon: 'people-group', tone: 'red' },
  hatch_empty: { label: 'Hatch empty', icon: 'utensils', tone: 'amber' },
};

/** What the line under the intake switch says; open and closed have their own. */
const INTAKE_LINES: Partial<Record<IntakeState, { text: string; tone: Tone }>> =
  {
    suspended: { text: 'Suspended', tone: 'bad' },
    debt: { text: 'Held: debt', tone: 'bad' },
    experiment: { text: 'Paused: experiment', tone: 'average' },
    no_power: { text: 'Paused: no power', tone: 'bad' },
  };

const STAGES: Record<PrisonStage, { label: string; color: string }> = {
  calm: { label: 'Calm', color: 'good' },
  grumbling: { label: 'Grumbling', color: 'average' },
  restless: { label: 'Restless', color: 'orange' },
  riot: { label: 'Riot', color: 'bad' },
};

/** What each guard is doing. Down and away add when they are back. */
const GUARD_STATUSES: Record<
  GuardStatus,
  { label: string; icon: string; tone?: Tone }
> = {
  arriving: { label: 'Arriving', icon: 'right-to-bracket', tone: 'good' },
  post: { label: 'On post', icon: 'user-shield' },
  rounds: { label: 'On rounds', icon: 'person-walking' },
  routine: { label: 'On duty', icon: 'user-shield' },
  responding: {
    label: 'Responding',
    icon: 'person-running',
    tone: 'average',
  },
  riot: { label: 'Holding the door', icon: 'shield-halved', tone: 'bad' },
  down: { label: 'Down', icon: 'user-injured', tone: 'bad' },
  away: { label: 'Away', icon: 'right-from-bracket', tone: 'average' },
};

const TURRET_STATES: Record<
  TurretState,
  { label: string; icon: string; tone: Tone }
> = {
  on: { label: 'On', icon: 'power-off', tone: 'good' },
  off: { label: 'Off', icon: 'power-off', tone: 'average' },
  broken: { label: 'Broken', icon: 'screwdriver-wrench', tone: 'bad' },
  no_power: { label: 'No power', icon: 'plug-circle-xmark', tone: 'bad' },
  loose: { label: 'Not mounted', icon: 'box-open', tone: 'average' },
};

/** A blind serum reads Serum until its creature shows. */
const EXPERIMENT_FORMS: Record<ExperimentForm, string> = {
  unknown: 'Serum',
  hulk: 'Hulk',
  fly: 'Fly',
  nightmare: 'Nightmare',
  changeling: 'Changeling',
};

const EXPERIMENT_STAGES: Record<
  ExperimentStage,
  { label: string; tone: string }
> = {
  offered: { label: 'Offered', tone: 'average' },
  dosed: { label: 'Dosed', tone: 'average' },
  twitching: { label: 'Twitching', tone: 'average' },
  incubating: { label: 'Incubating', tone: 'average' },
  live: { label: 'Loose', tone: 'bad' },
  vents: { label: 'In vents', tone: 'bad' },
  horror: { label: 'Horror', tone: 'bad' },
  contained: { label: 'Contained', tone: 'good' },
  failed: { label: 'Failed', tone: 'label' },
};

/** Only a changeling has these; a serum still unknown reads Dosed instead. */
const CHANGELING_STAGES: string[] = ['incubating', 'vents', 'horror'];

/** m:ss */
function clock(seconds: number) {
  const total = Math.max(0, Math.ceil(seconds || 0));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
}

/** Credits per minute, to one decimal place when it has one. */
function rate(value: number) {
  return `${Math.round((value || 0) * 10) / 10}`;
}

function percent(value: number | null | undefined) {
  return `${Math.round(value || 0)}%`;
}

function credits(value: number | null | undefined) {
  return formatMoney(Math.floor(value || 0));
}

function isNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

/** An extras block the server sent as an object; anything else hides its part. */
function block<T>(value: T | null | undefined): T | null {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? value
    : null;
}

/** Whole minutes, at least 1 */
function minutes(seconds: number) {
  return Math.max(1, Math.ceil(seconds / 60));
}

function Empty({ icon, children }: { icon: string; children: ReactNode }) {
  return (
    <div className="Outpost__empty">
      <Icon name={icon} />
      <span>{children}</span>
    </div>
  );
}

function Alarm({ data }: Props) {
  if (!data.alarm) {
    return null;
  }
  const known = ALARMS[data.alarm] || {
    label: data.alarm,
    icon: 'triangle-exclamation',
    tone: 'red',
  };
  return (
    <div
      className={`OutpostPrison__alarm OutpostPrison__alarm--${known.tone}`}
      role="alert"
    >
      <Icon name={known.icon} />
      <strong>{data.alarm_text || known.label}</strong>
    </div>
  );
}

function Readout({
  value,
  label,
  tone,
}: {
  value: string;
  label: string;
  tone?: string;
}) {
  return (
    <div className="Outpost__readout">
      <strong className={tone ? `OutpostPrison__tone--${tone}` : undefined}>
        {value}
      </strong>
      <small>{label}</small>
    </div>
  );
}

/** The line under the intake switch: arrivals when open, or why nobody is coming. */
function intakeLine(data: OutpostPrisonData, count: number) {
  const state = data.intake_state;
  const open = !!data.intake_open;
  if (state && state !== 'open' && state !== 'closed') {
    return INTAKE_LINES[state] || { text: state, tone: 'average' as Tone };
  }
  if (!open) {
    return null;
  }
  if (isNumber(data.next_arrival)) {
    return {
      text: `Next arrival ${clock(data.next_arrival)}`,
      tone: undefined,
    };
  }
  return count >= data.capacity ? { text: 'Full', tone: undefined } : null;
}

function Stats({ data, act }: Props) {
  const count = (data.prisoners || []).length;
  const open = !!data.intake_open;
  const line = intakeLine(data, count);
  // Intake can be closed while the treasury owes, but not opened.
  const held = data.intake_state === 'debt' && !open;
  const money = data.money;
  const net = money ? money.net || 0 : 0;
  const hasVisitors =
    data.visitors_allowed !== undefined && data.visitors_allowed !== null;
  const visitors = !!data.visitors_allowed;
  return (
    <div className="OutpostPrison__stats">
      <Readout value={`${rate(data.pay_rate)} cr`} label="Pay / min" />
      {isNumber(data.pay_percent) ? (
        <Readout
          value={percent(data.pay_percent)}
          label="Of full pay"
          tone={keyOfMatchingRange(data.pay_percent, PAY_RANGES)}
        />
      ) : null}
      {money ? (
        <Readout
          value={`${credits(net)} cr`}
          label="Net"
          tone={net < 0 ? 'bad' : undefined}
        />
      ) : (
        <Readout value={`${credits(data.paid_total)} cr`} label="Paid" />
      )}
      <Readout value={`${count}/${data.capacity || 0}`} label="Prisoners" />
      <div className="OutpostPrison__intake">
        <Button
          icon={open ? 'door-open' : 'door-closed'}
          selected={open}
          disabled={!data.can_manage || held}
          tooltip={
            !data.can_manage
              ? 'Managers only'
              : held
                ? 'Pay the debt first'
                : undefined
          }
          onClick={() => act('toggle_intake')}
        >
          {open ? 'Intake: Open' : 'Intake: Closed'}
        </Button>
        <small
          className={
            line?.tone ? `OutpostPrison__tone--${line.tone}` : undefined
          }
        >
          {line ? line.text : null}
        </small>
        {hasVisitors ? (
          <Button
            icon={visitors ? 'people-arrows' : 'user-lock'}
            selected={visitors}
            disabled={!data.can_manage}
            tooltip={data.can_manage ? undefined : 'Managers only'}
            onClick={() => act('toggle_visitors')}
          >
            {visitors ? 'Visitors: Yes' : 'Visitors: No'}
          </Button>
        ) : null}
      </div>
    </div>
  );
}

function Note({ data }: Props) {
  const note = typeof data.intake_note === 'string' ? data.intake_note : '';
  if (!note) {
    return null;
  }
  return (
    <div className="OutpostPrison__note">
      <Icon name="circle-info" />
      <span>{note}</span>
    </div>
  );
}

function MoneyLine({ data, act }: Props) {
  const money = data.money;
  const debt = isNumber(data.debt) && data.debt > 0 ? data.debt : 0;
  if (!money && debt <= 0) {
    return null;
  }
  // Debt is paid by managers and treasurers; without a hint the server decides.
  const canPay =
    data.can_pay_debt === undefined ||
    data.can_pay_debt === null ||
    !!data.can_pay_debt;
  return (
    <div className="OutpostPrison__money">
      {money ? (
        <>
          <span>
            Paid <b>{credits(money.paid)}</b>
          </span>
          <span>
            Spent <b>{credits(money.spent)}</b>
          </span>
          <span>
            Fined <b>{credits(money.fined)}</b>
          </span>
        </>
      ) : null}
      {debt > 0 ? (
        <span className="OutpostPrison__debt">
          Debt <b>{`${credits(debt)} cr`}</b>
          <Button
            icon="hand-holding-dollar"
            disabled={!canPay}
            tooltip={canPay ? undefined : 'Managers and treasurers only'}
            onClick={() => act('pay_debt')}
          >
            Pay debt
          </Button>
        </span>
      ) : null}
    </div>
  );
}

function ExperimentPanel({ data }: Props) {
  const experiment = data.experiment;
  if (!experiment) {
    return null;
  }
  const form = experiment.form || 'unknown';
  // A blind serum's outcome stays hidden until the server names its form.
  const stageKey =
    form === 'unknown' && CHANGELING_STAGES.includes(experiment.stage)
      ? 'dosed'
      : experiment.stage;
  const stage = EXPERIMENT_STAGES[stageKey] || {
    label: stageKey || '?',
    tone: 'label',
  };
  const formLabel = EXPERIMENT_FORMS[form] || form;
  const present = !!experiment.researcher_present;
  const fee = isNumber(experiment.fee_paid) ? experiment.fee_paid : 0;
  const bonus = isNumber(experiment.bonus_paid) ? experiment.bonus_paid : 0;
  return (
    <>
      <div className="Outpost__section-label">Experiment</div>
      <div className="OutpostPrison__experiment">
        <span
          className={`OutpostPrison__experiment-stage OutpostPrison__tone--${stage.tone}`}
        >
          {stage.label}
        </span>
        <div className="Outpost__person">
          <strong>{experiment.subject || formLabel}</strong>
          {experiment.subject ? <small>{formLabel}</small> : null}
        </div>
        <span className="OutpostPrison__number">
          {isNumber(experiment.time_left) ? clock(experiment.time_left) : ''}
        </span>
      </div>
      <div className="OutpostPrison__flags OutpostPrison__flags--experiment">
        <span className={`OutpostPrison__tone--${present ? 'good' : 'label'}`}>
          <Icon name="user-doctor" />
          {present ? 'Researcher here' : 'Researcher away'}
        </span>
        {experiment.horror === 'regenerating' ? (
          <span className="OutpostPrison__tone--bad">
            <Icon name="heart-pulse" />
            Regenerating
          </span>
        ) : null}
        {fee > 0 ? (
          <span className="OutpostPrison__tone--good">
            <Icon name="coins" />
            {`Fee ${credits(fee)} cr`}
          </span>
        ) : null}
        {bonus > 0 ? (
          <span className="OutpostPrison__tone--good">
            <Icon name="award" />
            {`Bonus ${credits(bonus)} cr`}
          </span>
        ) : null}
      </div>
    </>
  );
}

function Tension({ data }: Props) {
  const trouble = data.trouble;
  if (!trouble) {
    return null;
  }
  const stage = STAGES[trouble.stage] || {
    label: trouble.stage || '?',
    color: 'label',
  };
  const tension = Math.max(0, Math.min(100, Math.round(trouble.tension || 0)));
  const loose = (trouble.loose || []).filter(Boolean);
  return (
    <>
      <div className="Outpost__section-label">Tension</div>
      <div className="OutpostPrison__tension">
        <span
          className={`OutpostPrison__stage OutpostPrison__stage--${stage.color}`}
        >
          {stage.label}
        </span>
        <ProgressBar value={tension} maxValue={100} color={stage.color}>
          {`${tension}`}
        </ProgressBar>
      </div>
      <div className="OutpostPrison__flags OutpostPrison__flags--trouble">
        {trouble.riot_imminent ? (
          <span className="OutpostPrison__tone--bad">
            <Icon name="people-group" />
            Riot imminent
          </span>
        ) : null}
        {isNumber(trouble.breakout_in) ? (
          <span className="OutpostPrison__tone--bad">
            <Icon name="burst" />
            {`Breakout in ${clock(trouble.breakout_in)}`}
          </span>
        ) : null}
        {isNumber(trouble.subdued_left) && trouble.subdued_left > 0 ? (
          <span className="OutpostPrison__tone--good">
            <Icon name="dove" />
            {`Subdued ${clock(trouble.subdued_left)}`}
          </span>
        ) : null}
      </div>
      {loose.length > 0 ? (
        <div className="OutpostPrison__loose">
          {loose.map((entry, index) => (
            <div className="OutpostPrison__loose-row" key={index}>
              <Icon name="person-running" />
              <strong>{entry.name}</strong>
              <span>{entry.area || '?'}</span>
              <span className="OutpostPrison__number">
                {clock(entry.time_left)}
              </span>
            </div>
          ))}
        </div>
      ) : null}
    </>
  );
}

function Conditions({ data }: Props) {
  const conditions = data.conditions || {
    clean: 0,
    lit: 0,
    powered: 0,
    score: 0,
  };
  const bars: [string, number][] = [
    ['Clean', conditions.clean],
    ['Lit', conditions.lit],
    ['Power', conditions.powered],
  ];
  const mess = isNumber(conditions.mess_spots) ? conditions.mess_spots : 0;
  const dark = (conditions.dark_cells || []).filter(isNumber);
  const battery = isNumber(conditions.battery) ? conditions.battery : null;
  return (
    <>
      <div className="Outpost__section-label">Conditions</div>
      <div className="OutpostPrison__conditions">
        {bars.map(([label, value]) => (
          <div className="OutpostPrison__condition" key={label}>
            <span>{label}</span>
            <ProgressBar
              value={value || 0}
              maxValue={100}
              ranges={CONDITION_RANGES}
            />
          </div>
        ))}
        <div
          className={`OutpostPrison__score OutpostPrison__tone--${
            keyOfMatchingRange(conditions.score || 0, CONDITION_RANGES) ||
            'average'
          }`}
        >
          <strong>{percent(conditions.score)}</strong>
          <small>Score</small>
        </div>
      </div>
      {mess > 0 || dark.length > 0 || battery !== null ? (
        <div className="OutpostPrison__flags OutpostPrison__flags--conditions">
          {mess > 0 ? (
            <span className="OutpostPrison__tone--average">
              <Icon name="broom" />
              {`${mess} mess spot${mess === 1 ? '' : 's'}`}
            </span>
          ) : null}
          {dark.length > 0 ? (
            <span className="OutpostPrison__tone--average">
              <Icon name="moon" />
              {`${dark.length === 1 ? 'Cell' : 'Cells'} ${dark.join(', ')} dark`}
            </span>
          ) : null}
          {battery !== null ? (
            <span
              className={`OutpostPrison__tone--${battery < 40 ? 'bad' : 'average'}`}
            >
              <Icon name="car-battery" />
              {`On battery ${percent(battery)}`}
            </span>
          ) : null}
        </div>
      ) : null}
    </>
  );
}

function Hatch({ data }: Props) {
  const hatch = data.hatch;
  if (!hatch) {
    return null;
  }
  const meals = hatch.meals || 0;
  const clean = hatch.clean_suits || 0;
  const dirty = hatch.dirty_suits || 0;
  const capacity = hatch.capacity || 0;
  const mail = block(block(data.extras)?.mail);
  const waiting = mail && isNumber(mail.waiting) ? mail.waiting : 0;
  return (
    <>
      <div className="Outpost__section-label">
        Hatches
        {capacity > 0 ? (
          <span>{`${meals + clean + dirty}/${capacity}`}</span>
        ) : null}
      </div>
      <div className="OutpostPrison__hatch">
        <Readout
          value={`${meals}`}
          label="Meals"
          tone={meals > 0 ? undefined : 'bad'}
        />
        <Readout
          value={`${clean}`}
          label="Clean suits"
          tone={clean > 0 ? undefined : 'bad'}
        />
        <Readout value={`${dirty}`} label="Dirty suits" />
        <span className="OutpostPrison__lasts">
          {isNumber(hatch.lasts_minutes)
            ? `Lasts about ${Math.max(0, Math.round(hatch.lasts_minutes))} min`
            : null}
        </span>
      </div>
      {waiting > 0 ? (
        <div className="OutpostPrison__flags OutpostPrison__flags--mail">
          <span className="OutpostPrison__tone--average">
            <Icon name="envelope" />
            {`Mail: ${waiting} waiting`}
          </span>
        </div>
      ) : null}
    </>
  );
}

function GuardRow({
  guard,
  canDismiss,
  act,
}: {
  guard: Guard;
  canDismiss: boolean;
  act: Act;
}) {
  const known = GUARD_STATUSES[guard.status] || {
    label: guard.status || '?',
    icon: 'circle-question',
    tone: 'average' as Tone,
  };
  const back =
    (guard.status === 'down' || guard.status === 'away') &&
    isNumber(guard.back_in) &&
    guard.back_in > 0
      ? `, back in ${minutes(guard.back_in)} min`
      : '';
  // The rank is shown unless the name already starts with it ("Officer Hale").
  const rank = guard.rank || '';
  const showRank =
    rank !== '' &&
    !(guard.name || '').toLowerCase().startsWith(rank.toLowerCase());
  return (
    <div className="OutpostPrison__staff-row">
      <div className="Outpost__person">
        <strong>{guard.name}</strong>
        {showRank ? <small>{rank}</small> : null}
      </div>
      <span
        className={`OutpostPrison__status${
          known.tone ? ` OutpostPrison__tone--${known.tone}` : ''
        }`}
      >
        <Icon name={known.icon} />
        {`${known.label}${back}`}
      </span>
      {canDismiss ? (
        <Button.Confirm
          icon="user-minus"
          confirmContent="Dismiss?"
          onClick={() => act('guard_dismiss', { ref: guard.ref })}
        >
          Dismiss
        </Button.Confirm>
      ) : (
        <span />
      )}
    </div>
  );
}

function GuardsSection({ data, act }: Props) {
  const guards = block(block(data.extras)?.guards);
  if (!guards) {
    return null;
  }
  const list = (guards.list || []).filter(Boolean);
  const max = guards.max || 0;
  const manager = !!guards.can_manage;
  const missed = isNumber(guards.unpaid) ? guards.unpaid : 0;
  const hireBlocked = !manager
    ? 'Managers only'
    : max > 0 && list.length >= max
      ? `${max} at most`
      : 'Not enough in the treasury';
  return (
    <>
      <div className="Outpost__section-label">
        Guards
        {max > 0 ? <span>{`${list.length}/${max}`}</span> : null}
      </div>
      {list.length === 0 ? (
        <div className="Outpost__quiet">None</div>
      ) : (
        list.map((guard) => (
          <GuardRow
            key={guard.ref}
            guard={guard}
            canDismiss={manager}
            act={act}
          />
        ))
      )}
      <div className="OutpostPrison__staff-foot">
        <small>{`${rate(guards.wage)} cr/min each while you're home`}</small>
        {missed > 0 ? (
          <small className="OutpostPrison__tone--bad">
            {`Missed ${missed} wage${missed === 1 ? '' : 's'}`}
          </small>
        ) : null}
        <Button
          icon="user-plus"
          disabled={!guards.can_hire}
          tooltip={guards.can_hire ? undefined : hireBlocked}
          onClick={() => act('guard_hire')}
        >
          {`Hire (${credits(guards.hire_cost)} cr)`}
        </Button>
      </div>
    </>
  );
}

function TurretsSection({ data, act }: Props) {
  const security = block(block(data.extras)?.security);
  if (!security) {
    return null;
  }
  const turrets = (security.turrets || []).filter(Boolean);
  const max = security.turret_max || 0;
  const buyBlocked = !data.can_manage
    ? 'Managers only'
    : max > 0 && turrets.length >= max
      ? `${max} at most`
      : 'Not enough in the treasury';
  return (
    <>
      <div className="Outpost__section-label">
        Turrets
        {max > 0 ? <span>{`${turrets.length}/${max}`}</span> : null}
      </div>
      {turrets.length === 0 ? (
        <div className="Outpost__quiet">None</div>
      ) : (
        <div className="OutpostPrison__turrets">
          {turrets.map((turret, index) => {
            const known = TURRET_STATES[turret.state] || {
              label: turret.state || '?',
              icon: 'circle-question',
              tone: 'average' as Tone,
            };
            return (
              <span
                key={turret.ref}
                className={`OutpostPrison__turret OutpostPrison__tone--${known.tone}`}
              >
                <Icon name={known.icon} />
                {`Turret ${index + 1}: ${known.label}`}
              </span>
            );
          })}
        </div>
      )}
      <div className="OutpostPrison__staff-foot">
        <Button
          icon="cart-shopping"
          disabled={!security.can_buy}
          tooltip={security.can_buy ? undefined : buyBlocked}
          onClick={() => act('turret_buy')}
        >
          {`Buy (${credits(security.turret_cost)} cr)`}
        </Button>
      </div>
    </>
  );
}

function Status({ status }: { status: PrisonerStatus }) {
  if (status === 'present') {
    return <span />;
  }
  const known = STATUSES[status] || {
    label: status,
    icon: 'circle-question',
    tone: 'average',
  };
  return (
    <span
      className={`OutpostPrison__status OutpostPrison__tone--${known.tone}`}
    >
      <Icon name={known.icon} />
      {known.label}
    </span>
  );
}

function RosterRow({ prisoner, cell }: { prisoner: Prisoner; cell: string }) {
  const dead = prisoner.status === 'dead';
  return (
    <div
      className={`OutpostPrison__roster-row ${
        dead ? 'OutpostPrison__roster-row--dead' : ''
      }`}
    >
      <span className="OutpostPrison__cell">{cell}</span>
      <div className="Outpost__person">
        <strong>{prisoner.name}</strong>
        <small>{prisoner.crime}</small>
      </div>
      <span className="OutpostPrison__number">
        {dead ? '-' : clock(prisoner.sentence_left)}
      </span>
      <Status status={prisoner.status} />
    </div>
  );
}

function Roster({ data }: Props) {
  const prisoners = data.prisoners || [];
  // One row per cell. A prisoner past the last cell still gets a row; one
  // with no cell is listed after the cells.
  const cellCount = Math.max(
    data.capacity > 0 ? data.capacity : 4,
    ...prisoners.map((prisoner) => prisoner.cell || 0),
  );
  const cells = Array.from({ length: cellCount }, (_, index) => index + 1);
  const unassigned = prisoners.filter((prisoner) => !(prisoner.cell > 0));
  return (
    <>
      <div className="Outpost__section-label">Cells</div>
      <div className="OutpostPrison__roster-row OutpostPrison__roster-head">
        <span>Cell</span>
        <span>Prisoner</span>
        <span>Left</span>
        <span />
      </div>
      {cells.map((cell) => {
        const occupants = prisoners.filter(
          (prisoner) => prisoner.cell === cell,
        );
        if (occupants.length === 0) {
          return (
            <div
              className="OutpostPrison__roster-row OutpostPrison__roster-row--empty"
              key={`empty-${cell}`}
            >
              <span className="OutpostPrison__cell">{cell}</span>
              <span className="OutpostPrison__vacant">Empty</span>
              <span />
              <span />
            </div>
          );
        }
        return occupants.map((prisoner) => (
          <RosterRow key={prisoner.ref} prisoner={prisoner} cell={`${cell}`} />
        ));
      })}
      {unassigned.map((prisoner) => (
        <RosterRow key={prisoner.ref} prisoner={prisoner} cell="-" />
      ))}
    </>
  );
}

function Log({ data }: Props) {
  const log = data.log || [];
  return (
    <>
      <div className="Outpost__section-label">Log</div>
      {log.length === 0 ? (
        <div className="Outpost__quiet">None</div>
      ) : (
        <div className="OutpostPrison__log">
          {log.map((entry, index) => (
            <div key={index}>
              <span>{entry.time}</span>
              {entry.text}
            </div>
          ))}
        </div>
      )}
    </>
  );
}

export function OutpostPrisonPanel({ data, act }: Props) {
  return (
    <div className="Outpost OutpostPrison">
      <div className="OutpostPrison__head">
        <Icon name="handcuffs" />
        <strong>Prison</strong>
        {!!data.linked && !data.powered && (
          <span className="OutpostPrison__alert" role="alert">
            <Icon name="plug-circle-xmark" />
            No power
          </span>
        )}
      </div>
      {data.linked ? <Alarm data={data} act={act} /> : null}
      {data.linked ? (
        <div className="OutpostPrison__body">
          <Stats data={data} act={act} />
          <Note data={data} act={act} />
          <MoneyLine data={data} act={act} />
          <ExperimentPanel data={data} act={act} />
          <Tension data={data} act={act} />
          <Conditions data={data} act={act} />
          <Hatch data={data} act={act} />
          <Roster data={data} act={act} />
          <GuardsSection data={data} act={act} />
          <TurretsSection data={data} act={act} />
          <Log data={data} act={act} />
        </div>
      ) : (
        <Empty icon="link-slash">No prison link</Empty>
      )}
    </div>
  );
}

export const OutpostPrison = () => {
  const { data, act } = useBackend<OutpostPrisonData>();
  return (
    <Window title="Prison Warden" width={600} height={640}>
      <Window.Content fitted>
        <OutpostPrisonPanel data={data} act={act} />
      </Window.Content>
    </Window>
  );
};
