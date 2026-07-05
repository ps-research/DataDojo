# Judging at scale

Current: three hidden fixtures per SQL problem at sample scale (different seeds).
This defeats hardcoding and gives a tests-passed count, but is not large enough
to create real time-limit pressure.

- Pre-build large hidden fixtures (millions of rows) into read-only fixture
  databases, referenced by the judge instead of rebuilt per submission. Embedding
  them is not viable; the seed file grew past Node's string limit.
- Calibrate a time limit per problem and engine so a naive solution times out
  while the reference passes with margin.
- Prove each landmine by running a naive solution and confirming it fails.
- Stream per-test progress to the client instead of animating to the final count.
