#!/bin/sh
# audit_symbols.sh - verify every undefined symbol of tcp_bbr3.ko is exported
# by the target kernel. This is the reproducible counterpart of the build
# matrix in README.md: probes only check *compile-time* API availability;
# symbol resolution is verified here (and by strict modpost on trees with a
# Module.symvers).
#
# Usage: ./audit_symbols.sh /path/to/kernel/tree [path/to/tcp_bbr3.ko]
set -e

KDIR=${1:?usage: $0 <kernel-tree> [ko]}
KO=${2:-tcp_bbr3.ko}

[ -f "$KO" ] || { echo "error: $KO not found (build first)"; exit 1; }

# Plain EXPORT_SYMBOL/EXPORT_SYMBOL_GPL plus the token-pasted exports from
# DEFINE_BATCHED_ENTROPY(u8/u16/u32/u64).
{
	grep -rhoE 'EXPORT_SYMBOL(_GPL)?\([A-Za-z0-9_]+\)' "$KDIR/" 2>/dev/null \
		| sed -E 's/EXPORT_SYMBOL(_GPL)?\(([A-Za-z0-9_]+)\)/\1/'
	printf '%s\n' get_random_u8 get_random_u16 get_random_u32 get_random_u64
} | sort -u > /tmp/bbr3-exports.$$.txt

missing=$(nm -u "$KO" | awk '{print $2}' | grep -v '^$' | sort -u \
	| grep -vxF -f /tmp/bbr3-exports.$$.txt \
	| grep -vE '^(__x86_return_thunk|__stack_chk_fail|__indirect_thunk_[a-z_]+|_GLOBAL_OFFSET_TABLE_)$' \
	|| true)
rm -f /tmp/bbr3-exports.$$.txt

if [ -n "$missing" ]; then
	echo "FAIL: symbols not exported by $KDIR:"
	echo "$missing"
	exit 1
fi
echo "OK: all undefined symbols of $KO are exported by $KDIR"
