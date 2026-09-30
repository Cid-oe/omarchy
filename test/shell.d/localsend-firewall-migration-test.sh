#!/bin/bash
#
# The LocalSend firewall migration must replace the unscoped 53317 rules an
# existing install carries with rules scoped to private and local networks,
# leave a machine without them alone, and do nothing on a rerun.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

migration="$ROOT/migrations/1790811737.sh"
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

stub_bin="$test_dir/bin"
rules="$test_dir/rules"
calls="$test_dir/calls"
mkdir -p "$stub_bin"

# ufw keeps its added rules in a file, in the form `ufw show added` prints them.
cat >"$stub_bin/ufw" <<'STUB'
#!/bin/bash
echo "ufw $*" >>"$UFW_CALLS"
case "$*" in
  "show added")
    echo "Added user rules (see 'ufw status' for running firewall):"
    cat "$UFW_RULES"
    ;;
  "delete allow "*)
    grep -Fvx "ufw allow $3" "$UFW_RULES" >"$UFW_RULES.new" || true
    mv "$UFW_RULES.new" "$UFW_RULES"
    ;;
  "allow in proto "*)
    echo "ufw allow from $6 to any port ${10} proto $4 comment '${12}'" >>"$UFW_RULES"
    ;;
esac
STUB
cat >"$stub_bin/sudo" <<'STUB'
#!/bin/bash
exec "$@"
STUB
chmod +x "$stub_bin/ufw" "$stub_bin/sudo"

run_migration() {
  rm -f "$calls"
  UFW_RULES="$rules" UFW_CALLS="$calls" PATH="$stub_bin:$ROOT/bin:$PATH" \
    bash -euo pipefail "$migration" >/dev/null 2>&1
}

nets=(10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 fc00::/7 fe80::/10)

printf '%s\n' "ufw allow 53317/udp" "ufw allow 53317/tcp" "ufw allow 22" >"$rules"
run_migration || fail "migration runs on an install with the unscoped rules"
! grep -Eq '^ufw allow 53317/(udp|tcp)$' "$rules" || fail "migration removes the unscoped LocalSend rules"
grep -Fqx "ufw allow 22" "$rules" || fail "migration leaves unrelated rules alone"
for net in "${nets[@]}"; do
  for proto in udp tcp; do
    grep -Fqx "ufw allow from $net to any port 53317 proto $proto comment 'localsend'" "$rules" ||
      fail "migration adds the $proto rule for $net"
  done
done
pass "migration replaces the unscoped LocalSend rules with private and local ones"

cp "$rules" "$test_dir/after-first-run"
run_migration || fail "migration reruns"
cmp -s "$rules" "$test_dir/after-first-run" || fail "a rerun changes no rules"
! grep -Eq '^ufw (allow|delete)' "$calls" || fail "a rerun adds or deletes nothing"
pass "migration is idempotent"

printf '%s\n' "ufw allow 22" >"$rules"
run_migration || fail "migration runs on an install without the LocalSend rules"
! grep -q 53317 "$rules" || fail "migration does not open LocalSend where it was closed"
pass "migration leaves a machine without the LocalSend rules closed"
