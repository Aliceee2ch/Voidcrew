import type { ReactNode } from 'react';
import { Button, Icon, ProgressBar } from 'tgui-core/components';
import { formatMoney } from 'tgui-core/format';
import { keyOfMatchingRange } from 'tgui-core/math';
import type { BooleanLike } from 'tgui-core/react';
import { useBackend } from '../backend';
import { Window } from '../layouts';

type PrisonerStatus = 'present' | 'arriving' | 'leaving' | 'dead';

type PrisonAlarm = 'riot' | 'escape' | 'breakout';

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
  /** 0-100 each; powered is 0 or 100 */
  conditions: { clean: number; lit: number; powered: number; score: number };
  prisoners: Prisoner[];
  log: { time: string; text: string }[];
  /** null when nothing is wrong */
  alarm?: PrisonAlarm | null;
  alarm_text?: string;
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

/** Present prisoners get no badge. */
const STATUSES: Partial<
  Record<PrisonerStatus, { label: string; icon: string; tone: Tone }>
> = {
  arriving: { label: 'Arriving', icon: 'right-to-bracket', tone: 'good' },
  leaving: { label: 'Leaving', icon: 'right-from-bracket', tone: 'average' },
  dead: { label: 'Dead', icon: 'skull', tone: 'bad' },
};

/** Riots and breakouts are red and pulse; an escape is amber. */
const ALARMS: Record<
  PrisonAlarm,
  { label: string; icon: string; tone: 'red' | 'amber' }
> = {
  riot: { label: 'Riot', icon: 'hand-fist', tone: 'red' },
  escape: { label: 'Escape', icon: 'person-running', tone: 'amber' },
  breakout: { label: 'Breakout', icon: 'burst', tone: 'red' },
};

/** m:ss */
function clock(seconds: number) {
  const total = Math.max(0, Math.ceil(seconds));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
}

/** Credits per minute, to one decimal place when it has one. */
function rate(value: number) {
  return `${Math.round((value || 0) * 10) / 10}`;
}

function percent(value: number) {
  return `${Math.round(value || 0)}%`;
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

function Stats({ data, act }: Props) {
  const count = (data.prisoners || []).length;
  const open = !!data.intake_open;
  const arrival = !open
    ? null
    : typeof data.next_arrival === 'number'
      ? `Next arrival ${clock(data.next_arrival)}`
      : count >= data.capacity
        ? 'Full'
        : null;
  return (
    <div className="OutpostPrison__stats">
      <div className="Outpost__readout">
        <strong>{`${rate(data.pay_rate)} cr`}</strong>
        <small>Pay / min</small>
      </div>
      <div className="Outpost__readout">
        <strong>{`${formatMoney(Math.floor(data.paid_total || 0))} cr`}</strong>
        <small>Paid</small>
      </div>
      <div className="Outpost__readout">
        <strong>{`${count}/${data.capacity || 0}`}</strong>
        <small>Prisoners</small>
      </div>
      <div className="OutpostPrison__intake">
        <Button
          icon={open ? 'door-open' : 'door-closed'}
          selected={open}
          disabled={!data.can_manage}
          tooltip={data.can_manage ? undefined : 'Managers only'}
          onClick={() => act('toggle_intake')}
        >
          {open ? 'Intake: Open' : 'Intake: Closed'}
        </Button>
        <small>{arrival}</small>
      </div>
    </div>
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
          <Conditions data={data} act={act} />
          <Roster data={data} act={act} />
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
    <Window title="Prison Warden" width={560} height={520}>
      <Window.Content fitted>
        <OutpostPrisonPanel data={data} act={act} />
      </Window.Content>
    </Window>
  );
};
