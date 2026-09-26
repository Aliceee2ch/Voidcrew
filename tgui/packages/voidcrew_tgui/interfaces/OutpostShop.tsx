/**
 * Owner shop register: the buyer window (outpost_shop.dm, outpost_shop_stock.dm).
 *
 * `price` is what this viewer pays per unit (0 for staff who take stock free);
 * `buy` echoes it so a price change while the window is open is refused.
 */
import { useState } from 'react';
import {
  Box,
  Button,
  DmIcon,
  Icon,
  Input,
  NoticeBox,
  NumberInput,
  Section,
  Stack,
  Tabs,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Category = { id: string; name: string };

type Listing = {
  id: string;
  name: string;
  category: string;
  icon: string;
  icon_state: string;
  price: number;
  list_price: number;
  per_unit: BooleanLike;
  available: number;
  max_per_buy: number;
};

type Data = {
  shop_name: string;
  open: BooleanLike;
  closed_reason: string | null;
  member: BooleanLike;
  free_take: BooleanLike;
  account_holder: string | null;
  account_credits: number | null;
  confirm_total: number;
  categories: Category[];
  listings: Listing[];
};

const ALL = '__all__';

export const OutpostShop = (props) => {
  const { data } = useBackend<Data>();
  const {
    shop_name,
    open,
    closed_reason,
    free_take,
    account_holder,
    account_credits,
    categories = [],
    listings = [],
  } = data;
  const [category, setCategory] = useState(ALL);
  const [search, setSearch] = useState('');

  const shownCategory =
    category === ALL || categories.some((cat) => cat.id === category)
      ? category
      : ALL;
  const needle = search.trim().toLowerCase();
  const visible = listings.filter(
    (listing) =>
      (shownCategory === ALL || listing.category === shownCategory) &&
      (!needle || listing.name.toLowerCase().includes(needle)),
  );

  return (
    <Window width={640} height={600} title={shop_name}>
      <Window.Content>
        <Stack fill vertical>
          <Stack.Item>
            <Section title={shop_name}>
              {free_take ? (
                <NoticeBox info>
                  You are shop staff: you take stock free. It is logged.
                </NoticeBox>
              ) : account_holder ? (
                <Box>
                  Paying from: <b>{account_holder}</b> ({account_credits ?? 0}{' '}
                  cr)
                </Box>
              ) : (
                <NoticeBox warning>
                  No bank account on your ID. You can browse but not buy.
                </NoticeBox>
              )}
              {open ? null : (
                <NoticeBox danger mt={1}>
                  {closed_reason || 'Closed.'}
                </NoticeBox>
              )}
            </Section>
          </Stack.Item>
          <Stack.Item grow>
            <Stack fill>
              <Stack.Item width="170px">
                <Section fill scrollable>
                  <Tabs vertical>
                    <Tabs.Tab
                      selected={shownCategory === ALL}
                      onClick={() => setCategory(ALL)}
                    >
                      All ({listings.length})
                    </Tabs.Tab>
                    {categories.map((cat) => (
                      <Tabs.Tab
                        key={cat.id}
                        selected={shownCategory === cat.id}
                        onClick={() => setCategory(cat.id)}
                      >
                        {cat.name} (
                        {
                          listings.filter(
                            (listing) => listing.category === cat.id,
                          ).length
                        }
                        )
                      </Tabs.Tab>
                    ))}
                  </Tabs>
                </Section>
              </Stack.Item>
              <Stack.Item grow>
                <Section
                  fill
                  scrollable
                  title="For sale"
                  buttons={
                    <Input
                      placeholder="Search"
                      value={search}
                      onChange={setSearch}
                    />
                  }
                >
                  {visible.length === 0 ? (
                    <NoticeBox>
                      {open ? 'Nothing for sale here.' : 'The shop is closed.'}
                    </NoticeBox>
                  ) : null}
                  {visible.map((listing) => (
                    <BuyRow key={listing.id} listing={listing} />
                  ))}
                </Section>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const BuyRow = (props: { listing: Listing }) => {
  const { act, data } = useBackend<Data>();
  const { listing } = props;
  const { free_take, account_credits, confirm_total, open } = data;
  const limit = Math.max(1, Math.min(listing.max_per_buy, listing.available));
  const [quantity, setQuantity] = useState(1);
  const [confirming, setConfirming] = useState(false);
  const amount = Math.min(Math.max(1, quantity), limit);
  const total = listing.price * amount;
  const soldOut = listing.available < 1;
  const cantAfford =
    !free_take && (account_credits === null || account_credits < total);
  const needsConfirm = total >= confirm_total;

  const buy = () => {
    if (needsConfirm && !confirming) {
      setConfirming(true);
      return;
    }
    setConfirming(false);
    act('buy', { id: listing.id, price: listing.price, quantity: amount });
  };

  return (
    <Box
      mb={0.5}
      p={0.5}
      style={{ background: 'rgba(255, 255, 255, 0.04)', borderRadius: '2px' }}
    >
      <Stack align="center">
        <Stack.Item>
          <DmIcon
            icon={listing.icon}
            icon_state={listing.icon_state}
            width="32px"
            height="32px"
            fallback={<Icon name="box" size={1.5} />}
          />
        </Stack.Item>
        <Stack.Item grow>
          <Box bold>{listing.name}</Box>
          <Box color="label">
            {soldOut ? 'Sold out' : `${listing.available} available`}
            {' · '}
            {free_take
              ? `listed at ${listing.list_price} cr${listing.per_unit ? ' each' : ''}`
              : `${listing.price} cr${listing.per_unit ? ' each' : ''}`}
          </Box>
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="magnifying-glass"
            tooltip="Inspect the next unit"
            onClick={() => act('inspect', { id: listing.id })}
          />
        </Stack.Item>
        <Stack.Item>
          <NumberInput
            value={amount}
            minValue={1}
            maxValue={limit}
            step={1}
            width="45px"
            disabled={soldOut}
            onChange={(value) => {
              setQuantity(Math.round(value));
              setConfirming(false);
            }}
          />
        </Stack.Item>
        <Stack.Item width="120px">
          <Button
            fluid
            icon={free_take ? 'hand-holding' : 'cart-shopping'}
            color={confirming ? 'caution' : undefined}
            disabled={!open || soldOut || cantAfford}
            tooltip={cantAfford ? 'Not enough credits.' : undefined}
            onClick={buy}
          >
            {free_take ? 'Take' : confirming ? `Confirm ${total} cr` : `${total} cr`}
          </Button>
        </Stack.Item>
      </Stack>
    </Box>
  );
};
