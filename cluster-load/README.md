# cluster-load

Lists the math cluster compute nodes sorted by combined CPU + memory load
(freest first). Stdlib-only Python, no credentials needed — reads Prometheus
(node_exporter) metrics through the anonymous Grafana datasource proxy at
`login.cluster.math.kit.edu:3000`.

## Usage

```
cluster-load              # overview (Opterons pde01/02/06/07 and pde-fs excluded)
cluster-load --all        # include the excluded nodes
cluster-load pde12        # single node (also works for excluded nodes)
```

## Columns

- `load5` / `cpu%` — 5-minute load average, absolute and as % of cores
- `now%` — instantaneous CPU utilization from the last two 15s scrapes
  (`irate` on the idle counters); reacts immediately when a job starts or
  ends, unlike `load5`
- `mem used` / `mem%` — `MemTotal - MemAvailable`, so reclaimable page cache
  doesn't count as used
- `score` — `load5/cores + mem_used/mem_total`; 0 = idle, ~2 = fully loaded
  on both axes. Sort key for the table.

## Install

Symlinked into `~/bin`:

```
ln -s ~/config/cluster-load/cluster-load ~/bin/cluster-load
```
