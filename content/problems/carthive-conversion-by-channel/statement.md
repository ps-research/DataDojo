# Cart-to-Purchase Conversion by Acquisition Channel

Growth wants to know which acquisition channels turn intent into money. For each
channel, compute the **cart-to-purchase conversion rate**:

```
conversion_rate = (distinct sessions that reached purchase)
                / (distinct sessions that reached add_to_cart)
```

A session's channel is the acquisition channel of the customer who owned it.

Three facts about the data make the naive query wrong:

- **Analytics double-fires events.** The same logical `add_to_cart` can be written
  twice in one session (different `event_id`, sometimes a slightly different
  timestamp). Count **distinct sessions** per stage, not event rows — otherwise the
  denominator inflates and conversion is understated.
- **Sessions can be anonymous.** When `events.customer_id IS NULL` the session has
  no customer and therefore no channel. It must not vanish: fold anonymous traffic,
  together with logged-in customers whose `acquisition_channel` is NULL, into a
  single bucket labelled `unknown`. An inner join to `customers` deletes anonymous
  sessions.
- **Only channels with at least one add-to-cart session appear.** A channel with no
  add-to-cart sessions has no denominator; drop it rather than dividing by zero.

## Task

Attribute each session to its channel (or `unknown`), then for each channel report
the number of add-to-cart sessions, the number of purchase sessions, and the
conversion rate. Include only channels with at least one add-to-cart session.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `channel` | the acquisition channel, or `unknown` |
| 2 | `cart_sessions` | distinct sessions that reached `add_to_cart` |
| 3 | `purchase_sessions` | distinct sessions that reached `purchase` |
| 4 | `conversion_rate` | `purchase_sessions / cart_sessions`, real division, rounded to 4 decimals |

**Order matters.** `ORDER BY channel ASC`.

## Worked example

Two customers (customer 1 is `organic`; customer 2 has a NULL channel) and four
sessions:

| session | customer | events |
|---|---|---|
| 1 | 1 (organic) | view, add_to_cart, **add_to_cart (double fire)**, checkout, purchase |
| 2 | 1 (organic) | view, add_to_cart, checkout, purchase |
| 3 | (anonymous) | view, add_to_cart |
| 4 | 2 (NULL channel) | view, add_to_cart, checkout, purchase |

`organic`: sessions 1 and 2 both reached add_to_cart and purchase. Session 1 fired
add_to_cart twice, but it is one session — so `cart_sessions = 2`, not 3, and
`conversion_rate = 2 / 2 = 1.0`.

`unknown`: session 3 (anonymous) and session 4 (NULL-channel customer) both land
here. Both reached add_to_cart; only session 4 reached purchase — so
`cart_sessions = 2`, `purchase_sessions = 1`, `conversion_rate = 0.5`.

Expected rows:

| channel | cart_sessions | purchase_sessions | conversion_rate |
|---|---|---|---|
| organic | 2 | 2 | 1.0 |
| unknown | 2 | 1 | 0.5 |

On the visible sample fixture the `unknown` bucket converts at `0.5455` (6 of 11
cart sessions) and never disappears.
