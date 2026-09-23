import {
  Box,
  Button,
  LabeledList,
  NoticeBox,
  Section,
  Table,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';
import { useBackend } from '../backend';
import { Window } from '../layouts';

type Entry = { ref: string; name: string; denial: string | null };
type Data = {
  outpost: string;
  working: BooleanLike;
  error: string | null;
  notice: string | null;
  fee: number;
  bays: (Entry & {
    number: number;
    silo: string | null;
    outpost_materials: BooleanLike;
    requested: BooleanLike;
    available: BooleanLike;
  })[];
  blueprints: (Entry & { width: number; height: number })[];
  quote: {
    name: string;
    cost: { name: string; sheets: number; available: number }[];
    silo: string | null;
    outpost_materials: BooleanLike;
    fee: number;
    balance: number;
    denial: string | null;
    replaces: BooleanLike;
  } | null;
};

export const HullRegistry = () => {
  const { data, act } = useBackend<Data>();
  const { quote } = data;
  return (
    <Window width={600} height={660} title={`${data.outpost} Hull Registry`}>
      <Window.Content scrollable>
        {!!data.error && <NoticeBox danger>{data.error}</NoticeBox>}
        {!!data.notice && <NoticeBox success>{data.notice}</NoticeBox>}
        {!!data.working && <NoticeBox>Processing...</NoticeBox>}
        <Section title="Hull recovery">
          <LabeledList>
            <LabeledList.Item label="Coverage">
              Hull and infrastructure · One rebuild
            </LabeledList.Item>
            <LabeledList.Item label="Excluded">
              Helm, other machinery, supplies, cells and fuel
            </LabeledList.Item>
            <LabeledList.Item label="Registration">
              Materials + {data.fee} cr to the outpost
            </LabeledList.Item>
            <LabeledList.Item label="Rebuild">
              Prepaid · Original must be lost or abandoned
            </LabeledList.Item>
          </LabeledList>
        </Section>
        <Section title="Register a docked ship">
          {data.bays.length === 0 && (
            <Box color="label">Dock a ship you command in a ship bay.</Box>
          )}
          {data.bays.map((bay) => (
            <Box key={bay.ref} mb={2}>
              <Box bold mb={1} style={{ overflowWrap: 'anywhere' }}>
                Bay {bay.number} · {bay.name}
              </Box>
              <Box color="label" mb={1}>
                {bay.silo
                  ? `${bay.outpost_materials ? 'Outpost' : 'Ship'} materials: ${bay.silo}`
                  : 'No material source selected'}
              </Box>
              <Box mb={1}>
                <Button
                  selected={!!bay.silo && !bay.outpost_materials}
                  disabled={!!data.working}
                  onClick={() => act('ship_materials', { ref: bay.ref })}
                >
                  Ship materials
                </Button>
                <Button
                  selected={!!bay.outpost_materials}
                  disabled={
                    !!data.working || (!!bay.requested && !bay.available)
                  }
                  onClick={() => act('outpost_materials', { ref: bay.ref })}
                >
                  {bay.available
                    ? 'Outpost materials'
                    : bay.requested
                      ? 'Awaiting approval'
                      : 'Request outpost materials'}
                </Button>
              </Box>
              {!!bay.denial && (
                <Box color="label" mb={1}>
                  {bay.denial}
                </Box>
              )}
              <Button
                icon="file-invoice"
                disabled={!!data.working || !!bay.denial}
                onClick={() => act('quote', { ref: bay.ref })}
              >
                Prepare quote
              </Button>
            </Box>
          ))}
        </Section>
        {!!quote && (
          <Section title="Registration quote">
            <Box bold mb={1} style={{ overflowWrap: 'anywhere' }}>
              {quote.name}
            </Box>
            <Box color="label" mb={1}>
              {quote.outpost_materials ? 'Outpost' : 'Ship'} materials ·{' '}
              {quote.silo || 'Silo unavailable'}
            </Box>
            <Table mb={1}>
              <Table.Row header>
                <Table.Cell>Material</Table.Cell>
                <Table.Cell textAlign="right">Required</Table.Cell>
                <Table.Cell textAlign="right">Available</Table.Cell>
              </Table.Row>
              {quote.cost.map((material) => (
                <Table.Row key={material.name}>
                  <Table.Cell>{material.name} sheets</Table.Cell>
                  <Table.Cell textAlign="right">{material.sheets}</Table.Cell>
                  <Table.Cell
                    textAlign="right"
                    color={
                      material.available < material.sheets ? 'bad' : 'good'
                    }
                  >
                    {Math.floor(material.available)}
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
            <LabeledList>
              <LabeledList.Item label="Registry fee">
                {quote.fee} cr to {data.outpost}
              </LabeledList.Item>
              <LabeledList.Item
                label="Ship account"
                color={quote.balance < quote.fee ? 'bad' : undefined}
              >
                {quote.balance} cr available
              </LabeledList.Item>
            </LabeledList>
            {!!quote.replaces && (
              <Box color="average" mt={1}>
                Replaces your previous save. The full price applies again.
              </Box>
            )}
            {!!quote.denial && (
              <Box color="bad" mt={1}>
                {quote.denial}
              </Box>
            )}
            <Button
              mt={1}
              icon="floppy-disk"
              disabled={!!data.working || !!quote.denial}
              onClick={() => act('save')}
            >
              Pay and save hull
            </Button>
          </Section>
        )}
        <Section title="Your saved hulls">
          {data.blueprints.length === 0 && (
            <Box color="label">No hulls registered here.</Box>
          )}
          {data.blueprints.map((blueprint) => (
            <Box key={blueprint.ref} mb={2}>
              <Box bold mb={1} style={{ overflowWrap: 'anywhere' }}>
                {blueprint.name}
              </Box>
              <Box mb={1}>
                {blueprint.width} × {blueprint.height} · One prepaid rebuild
              </Box>
              {!!blueprint.denial && (
                <Box color="label" mb={1}>
                  {blueprint.denial}
                </Box>
              )}
              <Button.Confirm
                icon="ship"
                confirmContent="Use registration?"
                disabled={!!data.working || !!blueprint.denial}
                onClick={() => act('rebuild', { ref: blueprint.ref })}
              >
                Rebuild in ship bay
              </Button.Confirm>
            </Box>
          ))}
        </Section>
      </Window.Content>
    </Window>
  );
};
