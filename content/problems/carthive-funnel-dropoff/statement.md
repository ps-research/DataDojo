# Sessionized Funnel Drop-off by Channel

The web funnel runs `view -> add_to_cart -> checkout -> purchase`. For every
session, determine the **deepest stage it truly reached**, then report the funnel
by acquisition channel: how many sessions reached each stage, and the stage-to-stage
conversion rates.

The `events` stream is the messiest table in CartHive, and three of its quirks
break the obvious query:

- **Events are not in funnel order.** A client clock can log a `purchase` a few
  seconds **before** the `checkout` that produced it. So you cannot read a session's
  outcome as "the last event by timestamp" — that would call an inverted purchasing
  session a checkout. The deepest stage is the **maximum funnel rank** among the
  session's events (view=1, add_to_cart=2, checkout=3, purchase=4), which ignores
  timestamp order entirely.
- **Analytics double-fires events.** The same logical event can appear as two rows.
  Counting event rows per stage double-counts; work at the **session grain** so a
  duplicate does not change a session's deepest stage.
- **Sessions can be anonymous.** `events.customer_id` is NULL for not-logged-in
  sessions; those have no channel and fold into a single `unknown` bucket, together
  with logged-in customers whose `acquisition_channel` is NULL.

A session that reached stage *k* is counted at every stage `<= k` (funnel widths are
monotonic). Conversion from one stage to the next is
`sessions_at_next / sessions_at_stage`; when a stage has zero sessions the ratio is
undefined (return NULL, do not divide by zero).

## Task

Compute each session's deepest funnel stage from the stage hierarchy, attribute the
session to its channel (or `unknown`), and per channel report the sessions reaching
each of the four stages plus the three stage-to-stage conversion rates.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `channel` | acquisition channel, or `unknown` |
| 2 | `view_sessions` | sessions reaching view (deepest >= 1) |
| 3 | `cart_sessions` | sessions reaching add_to_cart (deepest >= 2) |
| 4 | `checkout_sessions` | sessions reaching checkout (deepest >= 3) |
| 5 | `purchase_sessions` | sessions reaching purchase (deepest >= 4) |
| 6 | `view_to_cart` | `cart_sessions / view_sessions`, 4 dp, NULL if no view sessions |
| 7 | `cart_to_checkout` | `checkout_sessions / cart_sessions`, 4 dp, NULL if no cart sessions |
| 8 | `checkout_to_purchase` | `purchase_sessions / checkout_sessions`, 4 dp, NULL if no checkout sessions |

**Order matters.** `ORDER BY channel ASC`.

## Worked example

One `organic` customer and one anonymous visitor, three sessions:

| session | channel | events (in log order) |
|---|---|---|
| 1 | organic | view, **view (duplicate)**, add_to_cart, checkout, purchase |
| 2 | organic | view, add_to_cart, **purchase @11:02**, **checkout @11:03** |
| 3 | (anonymous) | view, add_to_cart |

Session 1's deepest rank is 4 (purchase); its duplicate view does not change that.
Session 2 logs the purchase *before* the checkout, but both events exist, so its
deepest rank is still 4 — it reached purchase. Session 3 (anonymous → `unknown`)
reached only add_to_cart, rank 2.

`organic`: two sessions, both reaching all four stages → 2/2/2/2, every conversion
`1.0`. `unknown`: one session reaching cart → view 1, cart 1, checkout 0,
purchase 0; `cart_to_checkout = 0/1 = 0.0`, and `checkout_to_purchase` is undefined
(0 checkout sessions) so it is NULL.

Expected rows:

| channel | view | cart | checkout | purchase | v→c | c→co | co→p |
|---|---|---|---|---|---|---|---|
| organic | 2 | 2 | 2 | 2 | 1.0 | 1.0 | 1.0 |
| unknown | 1 | 1 | 0 | 0 | 1.0 | 0.0 | (NULL) |

On the visible sample fixture the `social` channel shows a real
checkout-to-purchase drop (`0.8333`), which the timestamp-order naive gets wrong
because several of its sessions log purchase before checkout.
