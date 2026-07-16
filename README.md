# cstack-abtest-control

The **control repo** for the cstack supervisor A/B test — it holds the task ledger, task specs,
and the control-plane machinery (`kernel/`, `roles/`, `AGENT_BASE.md`). Pairs with the work repo
[`cstack-abtest-work`](../cstack-abtest-work), which has 10 stubbed functions to implement.

## What's here

| Path | What |
|---|---|
| `tasks/T-01.md … T-10.md` | 10 coding-task specs. Each `done_check` is a `unittest` gate on one function. |
| `ledger/` | The task ledger (populate with `./kernel/task sync` — see below). |
| `kernel/task` | The ledger "syscall" tool: `eligible` / `claim` / `complete` / `fail` / `sync`. |
| `roles/`, `AGENT_BASE.md` | The agent operating manual + role contracts. |
| `fleet.conf` | The roster (agent → role). |
| `contracts/`, `mailboxes/`, `progress/`, `registry/` | Standard control-plane dirs. |

## One-time: populate the ledger from the specs

```sh
./kernel/task sync                 # batch-creates ledger entries from tasks/*.md
./kernel/task eligible --role feature --domain be --repo cstack-abtest-work   # should list 10 ids
```

## Connect to the fleet console

1. Push **both** repos to git (`cstack-abtest-work` and `cstack-abtest-control`).
2. In the console, add a workspace whose **control repo** is this repo and whose **work repo** is
   `cstack-abtest-work`. Start the `agent-be` feature agent.
3. The agent claims tasks and turns each red test green. Watch progress in the console.

## Running the A/B (monolithic vs phased loop)

The whole point of this project — measure whether the phased loop is cheaper.

1. **Baseline (monolithic).** Run `agent-be` as normal (default `SUPERVISOR_LOOP=monolithic`) over
   the 10 tasks. Note its cost/task and calls in the console **Cost** pane.
2. **Reset.** `git -C ../cstack-abtest-work reset --hard <start-commit>` and re-`sync` the ledger so
   the same 10 tasks are open again.
3. **Phased.** Set `SUPERVISOR_LOOP=phased` in `agent-be`'s `~/agents/agent-be/config`, run the same
   10 tasks. Phased metric rows are tagged `loop_mode:"phased"`.
4. **Compare** in the Cost pane / weekly digest. **GO** if cost/task drops ≥30% and success holds.

Each task is a pure function with an independent gate, so tasks don't interfere and the gate is
deterministic — ideal for a clean comparison.
# cstack-abtest-control
