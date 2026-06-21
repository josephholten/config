#!/usr/bin/env bash
# Per-physical-core CPU usage for conky, htop-style.
#
# Aggregates SMT sibling threads into their physical core (via /sys
# topology), computes utilisation since the previous call (counters
# cached in $STATE, so no sleeping -> safe to run every conky update),
# and prints one bar line per physical core.

STATE="${TMPDIR:-/tmp}/conky-cpu.$(id -u)"
WIDTH=10   # bar width in characters

# core_id -> list of logical cpu indices
declare -A core_cpus
for d in /sys/devices/system/cpu/cpu[0-9]*; do
    cpu=${d##*/cpu}
    cid=$(cat "$d/topology/core_id" 2>/dev/null) || continue
    core_cpus[$cid]+=" $cpu"
done

# current jiffies per logical cpu
declare -A tot idle
while read -r name user nice sys idl iowait irq softirq steal _; do
    case "$name" in
        cpu[0-9]*)
            n=${name#cpu}
            tot[$n]=$((user+nice+sys+idl+iowait+irq+softirq+steal))
            idle[$n]=$((idl+iowait))
            ;;
    esac
done < /proc/stat

# previous snapshot
declare -A ptot pidle
if [ -f "$STATE" ]; then
    while read -r n a b; do ptot[$n]=$a; pidle[$n]=$b; done < "$STATE"
fi

# save current snapshot
: > "$STATE"
for n in "${!tot[@]}"; do printf '%s %s %s\n' "$n" "${tot[$n]}" "${idle[$n]}" >> "$STATE"; done

# one line per physical core, sorted by core id
for cid in $(printf '%s\n' "${!core_cpus[@]}" | sort -n); do
    dt=0; di=0
    for cpu in ${core_cpus[$cid]}; do
        pt=${ptot[$cpu]:-${tot[$cpu]}}
        pi=${pidle[$cpu]:-${idle[$cpu]}}
        dt=$((dt + tot[$cpu] - pt))
        di=$((di + idle[$cpu] - pi))
    done
    if [ "$dt" -gt 0 ]; then use=$(( (100*(dt-di))/dt )); else use=0; fi

    fill=$(( (use*WIDTH+50)/100 ))
    bar=""
    for ((i=0;i<WIDTH;i++)); do
        if [ "$i" -lt "$fill" ]; then bar+="#"; else bar+="."; fi
    done
    printf 'c%-2d [%s] %3d%%\n' "$cid" "$bar" "$use"
done
