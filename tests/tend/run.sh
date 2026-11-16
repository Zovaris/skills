#!/usr/bin/env bash
# Offline tests for the tend skill: frontmatter and pr-state.sh parsing (fixtures, no network).
set -uo pipefail
cd "$(dirname "$0")/../.."
S=skills/tend; F=tests/tend/fixtures; fail=0
pass() { echo "  ok   $1"; }
bad()  { echo "  FAIL $1"; fail=1; }
eq()   { [ "$2" = "$3" ] && pass "$1" || bad "$1: expected '$3', got '$2'"; }

echo "tend"
head -1 $S/SKILL.md | grep -qx -- '---' && pass "frontmatter opens" || bad "frontmatter opens"
grep -q '^name: tend$' $S/SKILL.md && pass "name: tend" || bad "name: tend"
grep -q '^description: .\{40,\}' $S/SKILL.md && pass "description present" || bad "description present"
grep -q '^disable-model-invocation: true$' $S/SKILL.md && pass "user-invoked" || bad "user-invoked"
for r in $(grep -oE 'references/[A-Za-z-]+\.md|scripts/[a-z.-]+\.sh' $S/SKILL.md | sort -u); do
  [ -e "$S/$r" ] && pass "exists $r" || bad "missing $r"
done
bash -n $S/scripts/pr-state.sh && pass "pr-state.sh syntax" || bad "pr-state.sh syntax"

st() { $S/scripts/pr-state.sh --from "$F/$1" "$F/$2" "$F/$3"; }
o="$(st view-red.json threads-2open.json compare-behind.json)"
eq "red: checks"     "$(jq -r .checks <<<"$o")" fail
eq "red: mergeable"  "$(jq -r .mergeable <<<"$o")" CONFLICTING
eq "red: review"     "$(jq -r .review <<<"$o")" CHANGES_REQUESTED
eq "red: unresolved" "$(jq -r .unresolved <<<"$o")" 2
eq "red: behind"     "$(jq -r .behind <<<"$o")" 3
eq "red: head"       "$(jq -r .head <<<"$o")" warden/t1
o="$(st view-green.json threads-none.json compare-even.json)"
eq "green: checks"     "$(jq -r .checks <<<"$o")" pass
eq "green: review"     "$(jq -r .review <<<"$o")" none
eq "green: unresolved" "$(jq -r .unresolved <<<"$o")" 0
eq "green: behind"     "$(jq -r .behind <<<"$o")" 0
o="$(st view-pending.json threads-none.json compare-even.json)"
eq "pending: checks" "$(jq -r .checks <<<"$o")" pending
eq "pending: review" "$(jq -r .review <<<"$o")" none
o="$(st view-nochecks.json threads-none.json compare-even.json)"
eq "merged: state"  "$(jq -r .state <<<"$o")" MERGED
eq "merged: checks" "$(jq -r .checks <<<"$o")" none
$S/scripts/pr-state.sh >/dev/null 2>&1; eq "no args exits 2" "$?" 2

# watch.sh with a fake gh: first snapshot is stored, a new PR shows up as a change.
W="$(mktemp -d)"; mkdir -p "$W/bin"
cat > "$W/bin/gh" <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
  "repo view") echo "acme/app" ;;
  "api user") echo "me" ;;
  "pr list") cat "$GH_PRS" ;;
  "issue list") cat "$GH_ISSUES" ;;
esac
GH
chmod +x "$W/bin/gh"
echo '[{"number":1,"url":"u1","headRefName":"feat/x","author":{"login":"me"},"labels":[],"updatedAt":"t1"}]' > "$W/prs.json"
echo '[{"number":9,"url":"i9","updatedAt":"t1"}]' > "$W/issues.json"
export TEND_HOME="$W/state" GH_PRS="$W/prs.json" GH_ISSUES="$W/issues.json"
PATH="$W/bin:$PATH" "$S/scripts/watch.sh" prs --every 1 --max-min 0 >/dev/null 2>&1; eq "watch: no change → heartbeat" "$?" 4
echo '[{"number":1,"url":"u1","headRefName":"feat/x","author":{"login":"me"},"labels":[],"updatedAt":"t1"},{"number":2,"url":"u2","headRefName":"feat/b-02","author":{"login":"me"},"labels":[],"updatedAt":"t2"},{"number":3,"url":"u3","headRefName":"other","author":{"login":"x"},"labels":[],"updatedAt":"t2"}]' > "$W/prs.json"
o="$(PATH="$W/bin:$PATH" "$S/scripts/watch.sh" prs --every 1 --max-min 1)"
eq "watch: new PR of mine reported, others' ignored" "$o" "pr 2 new u2"
PATH="$W/bin:$PATH" "$S/scripts/watch.sh" all --every 1 --max-min 0 >/dev/null 2>&1
echo '[{"number":9,"url":"i9","updatedAt":"t1"},{"number":10,"url":"i10","updatedAt":"t3"}]' > "$W/issues.json"
o="$(PATH="$W/bin:$PATH" "$S/scripts/watch.sh" all --every 1 --max-min 1)"
eq "watch all: new labeled issue reported" "$o" "issue 10 new i10"
rm -rf "$W"

[ $fail -eq 0 ] && echo "tend: all passed" || echo "tend: FAILED"
exit $fail
