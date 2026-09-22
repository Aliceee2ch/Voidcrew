import { Box, Button, NoticeBox, Section, Stack } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';
import { useBackend } from '../backend';
import { Window } from '../layouts';

type Entry = { ref: string; name: string; denial: string | null };
type Data = {
  outpost: string;
  working: BooleanLike;
  error: string | null;
  bays: Entry[];
  blueprints: (Entry & { width: number; height: number })[];
  quote: {
    name: string;
    cost: { name: string; sheets: number }[];
  } | null;
};

export const HullRegistry = () => {
  const { data, act } = useBackend<Data>();
  return (
    <Window width={550} height={570} title={`${data.outpost} Hull Registry`}>
      <Window.Content scrollable>
        {!!data.error && <NoticeBox danger>{data.error}</NoticeBox>}
        {!!data.working && <NoticeBox>Processing registration...</NoticeBox>}
        <Section title="Register hull">
          <Box mb={1}>
            Hull + infrastructure · One rebuild this round
          </Box>
          <Box color="label" mb={1}>
            Excludes helm, other machinery, supplies, cells and fuel.
          </Box>
          {data.bays.length === 0 && (
            <Box color="label">Dock a ship you command in a ship bay.</Box>
          )}
          {data.bays.map((bay) => (
            <Stack key={bay.ref} align="center" mb={1}>
              <Stack.Item grow>{bay.name}</Stack.Item>
              <Stack.Item>
                <Button
                  disabled={!!data.working || !!bay.denial}
                  tooltip={bay.denial}
                  onClick={() => act('quote', { ref: bay.ref })}
                >
                  Prepare quote
                </Button>
              </Stack.Item>
            </Stack>
          ))}
          {!!data.quote && (
            <Section title={data.quote.name}>
              {data.quote.cost.map((material) => (
                <Box key={material.name}>
                  {material.sheets} {material.name} sheets
                </Box>
              ))}
              <Button
                mt={1}
                icon="floppy-disk"
                disabled={!!data.working}
                onClick={() => act('save')}
              >
                Pay and save hull
              </Button>
            </Section>
          )}
        </Section>
        <Section title="Your saved hulls">
          {data.blueprints.length === 0 && (
            <Box color="label">No hulls registered here.</Box>
          )}
          {data.blueprints.map((blueprint) => (
            <Section key={blueprint.ref} title={blueprint.name}>
              <Box mb={1}>
                {blueprint.width} × {blueprint.height} · One rebuild available
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
                Rebuild in ship bay — no charge
              </Button.Confirm>
            </Section>
          ))}
        </Section>
      </Window.Content>
    </Window>
  );
};
