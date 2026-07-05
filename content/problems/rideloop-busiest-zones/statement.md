# Busiest Pickup Zones in a City

RideLoop's city operations team for **Northgate** wants to know where rides
actually happen. Every ride request lands in the `trips` table, but a request is
not a ride: some end in `no_driver` (nobody was ever matched), and others in
`cancelled_rider` or `cancelled_driver`. Only a `completed` trip is a ride that
carried a passenger, and only those should count toward "busiest".

Each pickup zone belongs to a city through the `geozones` dimension (`geozones.city`).
Produce the ranking of Northgate's pickup zones by the number of completed trips
that originated there.

## Task

For the city **`'Northgate'`**, count the **completed** trips whose
`pickup_zone_id` falls in that city, grouped by pickup zone, and return the top 10
zones by completed-trip count.

## Output columns

| Column | Meaning |
|--------|---------|
| `zone_name` | the pickup zone's name (from `geozones`) |
| `completed_trips` | number of `status = 'completed'` trips that started in that zone |

Return **at most 10 rows**. Order by `completed_trips` **descending**; break ties
on `zone_name` **ascending** (so the cut at 10 is deterministic). `orderMatters`
is true.

## Worked example (visible sample, seed 42)

Northgate has four pickup zones. Counting only `status = 'completed'` trips whose
pickup zone is in Northgate:

| zone_name | completed_trips |
|-----------|-----------------|
| Northgate East | 32 |
| Northgate Old | 17 |
| Northgate North | 15 |
| Northgate Upper | 15 |

Note the tie at 15: `Northgate North` sorts before `Northgate Upper` by name.
Counting *all* trip rows (including `no_driver` and cancellations) would inflate
every zone and change the order, for example `Northgate East` has 55 total
requests but only 32 completed rides. The count is over completed rides only.
