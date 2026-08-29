# design_notes.md

Design notes. Read `ARCHITECTURE.md` for how the code fits
together; this file is about what we're building and why, and which decisions
are settled versus still open.

## What this is

A simulation engine and modular course teaching the **temporal dynamics of
investing** to teens / young adults.

The market is full of teen finance apps that are a card with quizzes attached,
or stock-picking games with leaderboards. Those teach that returns come from
picking correctly and that a good outcome means a good decision. We teach the
opposite: outcomes are distributions, short windows mislead, sequence matters,
and decision quality is not the same as outcome quality.

**A shared entrypoint for teens and adults** The quiet aim is to equip a parent who lacks 
confidence in discussing finance with their teen. That cannot be
marketed as parent education — nobody buys a course that says you don't
understand this. It is sold as something for the teenager that the parent does
alongside them.

## Phases

1. **Course.** 6–8 sessions. Model portfolio instantiated in week 1, not
   as a payoff at the end. Different clock times: a day / week / month / year in a day.
2. **Graduate tier.** Clock drops to 1x and stays there. Semi-topical content
   releases on a cadence to sustain a subscription. This is where the recurring
   revenue is.
3. **White label.** Partner brokers licence the interface under their own
   livery and supply their own market data. Higher contract value, lower churn,
   and the data licensing problem becomes theirs.

## Settled design decisions

- **All market data is synthetic.** The engine fits parameters and generates;
  it does not block-bootstrap real series. See "Data constraints" below.
- **Record of learning.** Reasoning captured *before* the outcome is visible.
  A forced choice plus one sentence, not a free-text box a fifteen-year-old
  won't fill in. It must be exportable and outlive a subscription.
- **Influencer strategies as archetypes, never named individuals.** Run them
  fairly and let the distribution make the argument. No debunking — teenagers
  defend the person, not the strategy. Concentration wins sometimes, wins big
  when it wins, and has a poor median. That's the lesson, arrived at by the
  learner.
- **Grounded in objectives a teens/young adults recognise**: university,
  accommodation, travel, a year out. Not retirement. Each has a date attached
  and a parent on the other side of it.

## Data constraints

Nasdaq's European Data Policies distinguish **multiple-security** derived data
(portfolio valuation — named explicitly, not fee-liable at underlying rates)
from **single-security** derived data (anything keyed to one symbol, including
"analytical or graphical representations with prices" — fee-liable per
subscriber). A chart of one real company is therefore a per-user charge, and it
lands squarely on the concentration module.

The derived-data licence also requires that derived works cannot be reverse
engineered back to the underlying data. That's why we fit and generate:
resampled segments of real prices are recoverable in principle, fitted
parameters are not.

Displaying real non-professional data would also require collecting name,
postal code, country, occupation and employer per recipient. For a fifteen-year
old that's absurd and a GDPR minimisation problem.

Historical series worth knowing about, all needing licence checks: Bank of
England Millennium dataset (permissive, UK equity back to C13th), Riksbank
Historical Monetary Statistics (Waldenström's Swedish stock/bond returns,
1856–2012), Vaihekoski's Helsinki index (open access, 1912–1981), Le Bris &
Hautcoeur's Paris index (HAL). **JST Macrohistory is CC BY-NC-SA — commercial
use is prohibited.** Don't build against it.

## Open 
- **Sweden first?**, then Finland, then UK/France. Parent is always the account
  holder; the young person is a profile beneath. Consent flows from the adult,
  which sidesteps the differing GDPR Art. 8 digital-consent ages (SE 13, FR 15,
  IE 16, UK 13).
- **Session topic order.** Objectives and values must come first, since the
  portfolios can't be instantiated without them, but the rest is undecided.
- **The weekly artifact.** What actually lands in front of the two of them and
  makes them talk. This is the retention model and it isn't settled.
- **Kitchen table prompts.** The failure mode is prompts that assume the parent
  holds the answer, forcing them to perform teaching. The cohort gap is real —
  a parent's experience of markets doesn't transfer to a teenager's world, so
  prompts built on "here's what happened to me" are worse than useless.
- **Course length.** 6–8 sessions, exact number open.

## Conventions

- Stages communicate **only through the database**. Nothing but a `run_id`
  passes between them. A stage deletes and rewrites its own run-scoped rows so
  re-running is idempotent.
- Every run-scoped table carries a `run_id` referencing
  `initiate.run_registry` `ON DELETE CASCADE`.
- Anything too large for Postgres goes to Blob and is registered in
  `initiate.artefacts`, hashed.
- The interface never touches Postgres. It calls the REST layer in `api/`,
  which connects as `api_ro` and physically cannot write run-scoped tables.
- `api/src/api/queries.py` is the only module outside the pipeline that knows
  the schema. Route handlers contain no SQL.
- Migrations are numbered, forward-only, never edited once applied.
- Azure lives in a subscription entirely separate from Safinea. Nothing shared.

## Commands

```bash
make build      # build pipeline, api, interface images
make up         # start postgres, api, interface
make migrate    # apply pending migrations
make run        # run input/000_example.yml end to end
make test
make lint
```

## Current state

Scaffold only. All three pipeline stages are no-op stubs, the C++ module is a
placeholder proving the build path, and `sql/migrations/002_domain_placeholder.sql`
creates empty schemas. No model exists yet.

`deploy.yml` fails on every push until Azure credentials and repo variables are
configured. Disable the workflow or set them up.
