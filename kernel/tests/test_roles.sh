#!/usr/bin/env bash
# kernel/tests/test_roles.sh — the role REGISTRY contract.
#
# The kernel used to hardcode feature|qa|doc in five if/elif chains, so the extractor/loader/migqa
# role files shipped in this repo could never run (`task eligible --role extractor` died), and no
# squad could ever declare a terminal role of its own. Roles are now data: each role file's YAML
# frontmatter declares what it claims and where it hands off, and the kernel reads that.
#
# This test pins the behaviour that rewrite must preserve (the stock feature→qa→doc pipeline) and
# the behaviour it adds (custom + terminal roles, the migration chain, honest errors).
set -e

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

cd "$WORK"
git init -q --bare remote.git
git clone -q remote.git a 2>/dev/null
cd a && git config user.email t@t && git config user.name t
mkdir -p kernel ledger roles
cp "$ROOT/kernel/task" kernel/task && chmod +x kernel/task
cp "$ROOT/roles"/*.md roles/
git add -A && git commit -qm init && git push -q

T=./kernel/task

# --- 1. The registry loads every role file, not just the three the kernel used to know ----------
for role in feature qa doc extractor loader migqa; do
  $T roles | grep -q "^$role:" || { echo "FAIL: role '$role' missing from registry"; exit 1; }
done

# --- 2. The stock pipeline still works end to end: open → testing → documenting → done ----------
$T create P-1 --repo r1 --domain be --desc "pipeline" >/dev/null
[ "$($T eligible --role feature --domain be)" = "P-1" ] || { echo "FAIL: feature eligibility"; exit 1; }
$T claim P-1 --agent a1 --role feature >/dev/null
$T show P-1 | grep -q "^status: in_progress" || { echo "FAIL: feature claim → in_progress"; exit 1; }
$T complete P-1 --agent a1 --role feature >/dev/null
$T show P-1 | grep -q "^status: testing" || { echo "FAIL: feature complete → testing"; exit 1; }
$T show P-1 | grep -q "^domain: qa" || { echo "FAIL: feature complete → domain qa"; exit 1; }

[ "$($T eligible --role qa)" = "P-1" ] || { echo "FAIL: qa eligibility"; exit 1; }
$T claim P-1 --agent q1 --role qa >/dev/null
$T show P-1 | grep -q "^status: testing" || { echo "FAIL: qa claims in place (status must stay testing)"; exit 1; }
$T complete P-1 --agent q1 --role qa --verdict passed >/dev/null
$T show P-1 | grep -q "^status: documenting" || { echo "FAIL: qa passed → documenting"; exit 1; }

[ "$($T eligible --role doc)" = "P-1" ] || { echo "FAIL: doc eligibility"; exit 1; }
$T claim P-1 --agent d1 --role doc >/dev/null
$T complete P-1 --agent d1 --role doc >/dev/null
$T show P-1 | grep -q "^status: done" || { echo "FAIL: doc complete → done"; exit 1; }

# --- 3. qa verdict=failed still bounces to origin_domain and burns a failure ---------------------
$T create P-2 --repo r1 --domain fe --desc "bounce" >/dev/null
$T claim P-2 --agent a1 --role feature >/dev/null
$T complete P-2 --agent a1 --role feature >/dev/null
$T claim P-2 --agent q1 --role qa >/dev/null
$T complete P-2 --agent q1 --role qa --verdict failed >/dev/null
$T show P-2 | grep -q "^status: open" || { echo "FAIL: qa failed → open"; exit 1; }
$T show P-2 | grep -q "^domain: fe" || { echo "FAIL: qa failed → \$origin_domain (fe)"; exit 1; }
$T show P-2 | grep -q "^failure_count: 1" || { echo "FAIL: qa failed → failure_count +1"; exit 1; }

# --- 4. A TERMINAL custom role: claims `open`, completes straight to `done` ----------------------
# This is what a standalone squad (testers, no feature agent upstream) needs and could never have:
# every role the kernel knew handed off to another role, so only `doc` could ever reach done.
cat > roles/TESTER_ROLE.md <<'EOS'
---
role: tester
claims:      { status: open, domain: qa }
on_claim:    { status: in_progress }
on_complete: { status: done }
on_fail:     { status: open }
---
# TESTER_ROLE.md — exploratory tester
EOS
$T create T-1 --repo r1 --domain qa --desc "explore checkout" >/dev/null
[ "$($T eligible --role tester)" = "T-1" ] || { echo "FAIL: tester eligibility (open + domain qa)"; exit 1; }
# A qa agent must NOT see it — qa only picks up rows a feature agent handed off (status: testing).
$T eligible --role qa 2>/dev/null | grep -q "^T-1$" && { echo "FAIL: qa must not claim an open row"; exit 1; }
$T claim T-1 --agent t1 --role tester >/dev/null
$T complete T-1 --agent t1 --role tester >/dev/null
$T show T-1 | grep -q "^status: done" || { echo "FAIL: terminal role must reach done directly"; exit 1; }

# --- 5. The migration chain — three roles that COULD NOT RUN AT ALL before ----------------------
# extractor(open/extract) → loader(loading/load) → migqa(verifying/migqa) → done
$T create M-1 --repo r1 --domain extract --desc "migrate accounts" >/dev/null
[ "$($T eligible --role extractor)" = "M-1" ] || { echo "FAIL: extractor eligibility"; exit 1; }
$T claim M-1 --agent e1 --role extractor >/dev/null
$T complete M-1 --agent e1 --role extractor >/dev/null
$T show M-1 | grep -q "^status: loading" || { echo "FAIL: extractor → loading"; exit 1; }
$T show M-1 | grep -q "^domain: load" || { echo "FAIL: extractor → domain load"; exit 1; }

[ "$($T eligible --role loader)" = "M-1" ] || { echo "FAIL: loader eligibility"; exit 1; }
$T claim M-1 --agent l1 --role loader >/dev/null
$T complete M-1 --agent l1 --role loader >/dev/null
$T show M-1 | grep -q "^status: verifying" || { echo "FAIL: loader → verifying"; exit 1; }

[ "$($T eligible --role migqa)" = "M-1" ] || { echo "FAIL: migqa eligibility"; exit 1; }
$T claim M-1 --agent v1 --role migqa >/dev/null
$T complete M-1 --agent v1 --role migqa --verdict passed >/dev/null
$T show M-1 | grep -q "^status: done" || { echo "FAIL: migqa passed → done"; exit 1; }

# --- 6. A ledger-free role is refused for ledger ops, not silently treated as a claimer ---------
cat > roles/CONTENT_MIGRATOR_ROLE.md <<'EOS'
---
role: content-migrator
work_source: none
---
# CONTENT_MIGRATOR_ROLE.md — schedule-driven, never touches the ledger
EOS
$T roles | grep -q "content-migrator: work_source=none" || { echo "FAIL: roles should report work_source=none"; exit 1; }
set +e
OUT=$($T eligible --role content-migrator 2>&1); RC=$?
set -e
[ "$RC" -ne 0 ] || { echo "FAIL: a work_source=none role must not be queried for tasks"; exit 1; }
echo "$OUT" | grep -q "does not use the ledger" || { echo "FAIL: error should say the role has no ledger"; exit 1; }

# --- 7. An unknown role dies loudly, naming the roles that DO exist -----------------------------
set +e
OUT=$($T eligible --role nonesuch 2>&1); RC=$?
set -e
[ "$RC" -ne 0 ] || { echo "FAIL: unknown role must not succeed"; exit 1; }
echo "$OUT" | grep -q "unknown role: nonesuch" || { echo "FAIL: should name the unknown role"; exit 1; }
echo "$OUT" | grep -q "known roles:.*tester" || { echo "FAIL: should list the roles that exist"; exit 1; }

# --- 8. respects_locks still gates feature; a role that doesn't declare it is unaffected --------
$T create L-1 --repo r1 --domain be --desc "migration A" --locks migrations >/dev/null
$T create L-2 --repo r1 --domain be --desc "migration B" --locks migrations >/dev/null
$T claim L-1 --agent a1 --role feature >/dev/null
$T show L-1 | grep -q "^lock_state: held" || { echo "FAIL: feature claim should take the lock"; exit 1; }
$T eligible --role feature --domain be | grep -q "^L-2$" && { echo "FAIL: contended lock should withhold L-2"; exit 1; }

# --- 9. human override: `fail --role human` releases a claim without a role contract -----------
# The console uses this to force a task off a stuck agent on restart. "human" is not a ledger role,
# so it must be handled without get_role() — otherwise it dies "unknown role" and 500s the restart.
$T create H-1 --repo r1 --domain be --desc "human fail" >/dev/null
$T claim H-1 --agent f1 --role feature >/dev/null
$T show H-1 | grep -q "^claimed_by: f1" || { echo "FAIL: H-1 should be claimed"; exit 1; }
OUT=$($T fail H-1 --agent operator --role human 2>&1) || { echo "FAIL: human fail errored: $OUT"; exit 1; }
$T show H-1 | grep -q "^claimed_by: -" || { echo "FAIL: human fail should release the claim"; exit 1; }
$T show H-1 | grep -q "^failure_count: 1" || { echo "FAIL: human fail should increment failure_count"; exit 1; }
$T show H-1 | grep -q "^status: open" || { echo "FAIL: human fail should revert to a claimable status (open — no role owns domain be)"; exit 1; }
# --needs-human escalates instead
$T claim H-1 --agent f1 --role feature >/dev/null
$T fail H-1 --agent operator --role human --needs-human >/dev/null
$T show H-1 | grep -q "^status: needs_human" || { echo "FAIL: human fail --needs-human should escalate"; exit 1; }

echo "kernel roles: ALL PASS"
