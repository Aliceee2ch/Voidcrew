import { useEffect, useState } from 'react';
import {
  Box,
  Button,
  ByondUi,
  Dropdown,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
  Tabs,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';
import { useBackend } from '../backend';
import { Window } from '../layouts';
import {
  type PreviewData,
  ShipPreview,
  type UpgradeSlot,
} from './ShipUpgradeSelector';

type ShopTheme = {
  id: string;
  name: string;
  desc: string;
  is_default: BooleanLike;
  price: number;
  crew: number;
};

type ShopModule = {
  id: string;
  name: string;
  desc: string;
  slot: string;
  is_default: BooleanLike;
  price: number;
  themes: string[];
};

type ShopHull = {
  id: string;
  name: string;
  description: string;
  price: number;
  crew: number;
  themes: ShopTheme[];
  slots_by_theme: Record<string, string[]>;
  modules: ShopModule[];
  preview: PreviewData | null;
};

type Shop = {
  hull: string;
  theme: string | null;
  selections: Record<string, string>;
  lines: { label: string; amount: number }[];
  price: number;
  payers: {
    id: string;
    name: string;
    balance: number;
    available: BooleanLike;
  }[];
  payer: string;
  denial: string | null;
};

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
  catalog: ShopHull[];
  shop: Shop | null;
};

const credits = (amount: number) => `${amount.toLocaleString()} cr`;

export const ShipCheckpoint = () => {
  const { data } = useBackend<Data>();
  const [tab, setTab] = useState('checkpoints');
  const rebuilds = data.rebuilds || [];
  return (
    <Window width={620} height={900} title={`${data.outpost} Shipyard`}>
      <Window.Content scrollable>
        {!!data.bay_view && (
          <Section title="Ship bay">
            <BayView key={data.bay_view} mapRef={data.bay_view} />
          </Section>
        )}
        {!!data.error && <NoticeBox danger>{data.error}</NoticeBox>}
        {!!data.notice && <NoticeBox success>{data.notice}</NoticeBox>}
        {!!data.working && <NoticeBox>Processing...</NoticeBox>}
        {rebuilds.length > 0 && (
          <Section title="Construction">
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
        <Tabs>
          <Tabs.Tab
            icon="floppy-disk"
            selected={tab === 'checkpoints'}
            onClick={() => setTab('checkpoints')}
          >
            Checkpoints
          </Tabs.Tab>
          <Tabs.Tab
            icon="ship"
            selected={tab === 'shop'}
            onClick={() => setTab('shop')}
          >
            New ship
          </Tabs.Tab>
        </Tabs>
        {tab === 'shop' ? <ShopTab /> : <CheckpointsTab />}
      </Window.Content>
    </Window>
  );
};

const CheckpointsTab = () => {
  const { data, act } = useBackend<Data>();
  const cost = data.has_checkpoint ? data.update_cost : data.save_cost;
  return (
    <>
      <Section title="Ship checkpoints">
        <LabeledList>
          <LabeledList.Item label="Save / update">
            {credits(data.save_cost)} / {credits(data.update_cost)}
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
          One checkpoint per captain at this outpost. Updating replaces it with
          the latest design of the docked ship you choose. Fees are spent from
          that ship&apos;s account.
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
              Ship account: {credits(bay.balance)}
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
              {data.has_checkpoint ? 'Update checkpoint' : 'Save checkpoint'} (
              {credits(cost)})
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
    </>
  );
};

/** Matches is_module_available_for_theme(): themeless hulls take only themeless modules. */
const fitsTheme = (module: ShopModule, theme: string) =>
  theme ? module.themes.includes(theme) : module.themes.length === 0;

const slotName = (key: string) => {
  const spaced = key.replace(/_/g, ' ');
  return spaced.charAt(0).toUpperCase() + spaced.slice(1);
};

const ShopTab = () => {
  const { data, act } = useBackend<Data>();
  const shop = data.shop;
  const catalog = data.catalog || [];
  const hull = catalog.find((entry) => entry.id === shop?.hull);
  if (!shop || !hull) {
    return (
      <Section title="New ship">
        <Box color="label">No ships for sale.</Box>
      </Section>
    );
  }
  const themeKey = shop.theme || '';
  const theme = hull.themes.find((entry) => entry.id === shop.theme);
  const slotKeys = hull.slots_by_theme[themeKey] || [];
  const slots: UpgradeSlot[] = slotKeys.map((key) => ({
    key,
    display_name: slotName(key),
    modules: hull.modules
      .filter((module) => module.slot === key && fitsTheme(module, themeKey))
      .map((module) => ({
        id: module.id,
        name: module.name,
        desc: module.desc,
        part_cost: {},
        is_default: !!module.is_default,
      })),
  }));
  const payer = shop.payers.find((entry) => entry.id === shop.payer);
  return (
    <>
      <Section title="Hull">
        <Dropdown
          width="100%"
          selected={hull.id}
          displayText={`${hull.name} (${credits(hull.price)})`}
          options={catalog.map((entry) => ({
            value: entry.id,
            displayText: `${entry.name} (${credits(entry.price)})`,
          }))}
          onSelected={(value) => act('shop_hull', { id: value })}
        />
        <Box color="label" mt={1}>
          {hull.description}
        </Box>
        <Box color="label" mt={1}>
          Crew: {theme ? theme.crew : hull.crew}
        </Box>
      </Section>
      {hull.themes.length > 0 && (
        <Section title="Theme">
          <Stack wrap>
            {hull.themes.map((entry) => (
              <Stack.Item key={entry.id} mb={0.5}>
                <Button
                  selected={entry.id === shop.theme}
                  tooltip={entry.desc}
                  onClick={() => act('shop_theme', { id: entry.id })}
                >
                  {entry.name}
                  {entry.price > 0 ? ` (+${credits(entry.price)})` : ''}
                </Button>
              </Stack.Item>
            ))}
          </Stack>
          {!!theme && (
            <Box color="label" mt={1}>
              {theme.desc}
            </Box>
          )}
        </Section>
      )}
      {!!hull.preview && (
        <Section title="Layout">
          <Box height="240px">
            <ShipPreview
              preview={hull.preview}
              themeKey={themeKey}
              slots={slots}
              selectedUpgrades={shop.selections}
              hoverModule={null}
            />
          </Box>
        </Section>
      )}
      {slots.length > 0 && (
        <Section title="Modules">
          <LabeledList>
            {slots.map((slot) => {
              const chosen = hull.modules.find(
                (module) => module.id === shop.selections[slot.key],
              );
              const options = hull.modules.filter(
                (module) =>
                  module.slot === slot.key && fitsTheme(module, themeKey),
              );
              return (
                <LabeledList.Item key={slot.key} label={slot.display_name}>
                  <Dropdown
                    width="100%"
                    selected={chosen?.id || ''}
                    displayText={
                      chosen
                        ? `${chosen.name}${chosen.price > 0 ? ` (+${credits(chosen.price)})` : ''}`
                        : 'Default'
                    }
                    options={options.map((module) => ({
                      value: module.id,
                      displayText: `${module.name}${module.price > 0 ? ` (+${credits(module.price)})` : ''}`,
                    }))}
                    onSelected={(value) =>
                      act('shop_module', { slot: slot.key, id: value })
                    }
                  />
                  {!!chosen && (
                    <Box color="label" mt={0.5}>
                      {chosen.desc}
                    </Box>
                  )}
                </LabeledList.Item>
              );
            })}
          </LabeledList>
        </Section>
      )}
      <Section title="Price">
        <LabeledList>
          {shop.lines.map((line) => (
            <LabeledList.Item key={line.label} label={line.label}>
              {credits(line.amount)}
            </LabeledList.Item>
          ))}
          <LabeledList.Item label="Total">
            <Box bold>{credits(shop.price)}</Box>
          </LabeledList.Item>
          <LabeledList.Item label="Pay from">
            <Dropdown
              width="100%"
              selected={shop.payer}
              displayText={
                payer
                  ? `${payer.name} (${payer.available ? credits(payer.balance) : 'no ID'})`
                  : 'Choose'
              }
              options={shop.payers.map((entry) => ({
                value: entry.id,
                displayText: `${entry.name} (${entry.available ? credits(entry.balance) : 'no ID'})`,
              }))}
              onSelected={(value) => act('shop_payer', { id: value })}
            />
          </LabeledList.Item>
        </LabeledList>
        <Box color="label" mt={1}>
          Spent when construction begins. You take command at handover.
        </Box>
        {!!shop.denial && (
          <Box color="bad" mt={1}>
            {shop.denial}
          </Box>
        )}
        <Button
          mt={1}
          icon="ship"
          color="good"
          disabled={!!data.working || !!shop.denial}
          onClick={() => act('shop_buy')}
        >
          Order ship ({credits(shop.price)})
        </Button>
      </Section>
    </>
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
