# TrueNAS Remote — iOS App

## Architecture
- **Pattern**: MVVM — `@Observable` ViewModels, SwiftUI Views, async/await Networking
- **Transport**: JSON-RPC 2.0 over WebSocket at `ws(s)://<host>/api/current` — **no REST**
- **Auth**: `auth.login_with_api_key` on every new WebSocket connection; API key stored in iOS Keychain
- **NetworkManager**: Swift `actor` (`TrueNASNetworkManager`) + per-domain extension files; single persistent WebSocket connection reused across all calls
- **Navigation**: iOS 26 adaptive `TabView` (sidebar on iPad, tab bar on iPhone); all `NavigationStack` wrappers live in `MainTabView` only
- **Charts**: Swift Charts (`import Charts`) for all time-series graphs
- **Design target**: Native Apple look — SF Symbols, Materials, insetGrouped Lists,
  `.inline` NavBar titles, `ContentUnavailableView`, swipe actions, context menus
- **Build**: Xcode 26.5, Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`

---

## JSON-RPC 2.0 Method Map

All calls go to `ws(s)://<host>/api/current` as `{"jsonrpc":"2.0","id":"<uuid>","method":"...","params":[...]}`.
Params are a JSON array — `[]` when a method takes no arguments.

| Domain | Method | Params | Notes |
|--------|--------|--------|-------|
| Auth | `auth.login_with_api_key` | `[apiKey]` | Called once per connection; result `true` = success |
| System | `system.info` | `[]` | version, hostname, uptime_seconds, physmem, loadavg |
| System | `alert.list` | `[]` | active alerts |
| System | `alert.dismiss` | `[uuid]` | dismiss one alert |
| System | `boot.environment.query` | `[]` | boot environments; `id` is the display name (version string) |
| System | `boot.environment.activate` | `[id]` | activate a boot environment |
| System | `user.query` | `[]` | user list |
| System | `group.query` | `[]` | group list |
| System | `certificate.query` | `[]` | certificates |
| System | `audit.query` | `[{"query-options":{"limit":N,"order_by":["-message_timestamp"]}}]` | audit log entries |
| Storage | `pool.query` | `[]` | pools with topology + scan info |
| Storage | `pool.scrub` | `[id, {"action":"START"}]` | start a scrub |
| Storage | `disk.query` | `[]` | all disks |
| Storage | `smart.test.manual_test` | `[{"disks":[name],"type":"SHORT"}]` | run S.M.A.R.T. test |
| Dataset | `pool.dataset.query` | `[[["pool","=","name"]]]` | datasets; omit filter for all |
| Dataset | `pool.snapshot.query` | `[[["dataset","=","name"]],{"limit":200}]` | snapshots for a dataset |
| Dataset | `pool.snapshot.create` | `[{"dataset":"...","name":"...","recursive":false}]` | create snapshot |
| Dataset | `pool.snapshot.delete` | `[id]` | delete snapshot |
| Dataset | `pool.snapshot.rollback` | `[id]` | rollback to snapshot |
| Network | `interface.query` | `[]` | interfaces; IPs are in `state.aliases` |
| Network | `network.configuration.config` | `[]` | hostname, gateways, DNS (was `network.configuration`) |
| Network | `staticroute.query` | `[]` | static routes |
| Shares | `sharing.smb.query` | `[]` | SMB shares; `guestok` under `options.guestok` in 25.x |
| Shares | `sharing.smb.update` | `[id, {"enabled":bool}]` | enable/disable SMB share |
| Shares | `sharing.nfs.query` | `[]` | NFS exports |
| Shares | `iscsi.target.query` | `[]` | iSCSI targets |
| Shares | `iscsi.extent.query` | `[]` | iSCSI extents |
| DataProt | `pool.snapshottask.query` | `[]` | periodic snapshot tasks |
| DataProt | `pool.snapshottask.run` | `[id]` | run snapshot task now |
| DataProt | `replication.query` | `[]` | replication tasks; `state.datetime` is BSON `{"$date":ms}` |
| DataProt | `replication.run` | `[id]` | run replication now |
| DataProt | `cloudsync.query` | `[]` | cloud sync tasks |
| DataProt | `cloudsync.run` | `[id]` | run cloud sync now |
| DataProt | `rsynctask.query` | `[]` | rsync tasks |
| DataProt | `rsynctask.run` | `[id]` | run rsync now |
| DataProt | `pool.scrub.query` | `[]` | scrub schedules; `pool` field is Int (ID) in 25.x |
| Services | `service.query` | `[]` | system services |
| Services | `service.start` | `[name]` | start service by name |
| Services | `service.stop` | `[name]` | stop service by name |
| Services | `service.restart` | `[name]` | restart service by name |
| VMs | `vm.query` | `[]` | VMs; `memory` is already MB — do not divide |
| VMs | `vm.start` | `[id]` | start VM |
| VMs | `vm.stop` | `[id]` | stop VM |
| VMs | `vm.restart` | `[id]` | restart VM |
| Apps | `app.query` | `[]` | installed apps; icon URL in `metadata.icon` |
| Apps | `app.start` | `[id]` | start app |
| Apps | `app.stop` | `[id]` | stop app |
| Reporting | `reporting.get_data` | `[[{"name":"cpu"}]]` | params[0] is array of graph objects — NOT `{"graphs":[…]}` |

### Valid reporting.get_data graph names (verified against 25.10.3)
`cpu`, `cputemp`, `disk`†, `interface`†, `load`, `processes`, `memory`, `uptime`,
`arcsize`, `arcresult`‡, `arcrate`‡, `arcactualrate`‡,
`disktemp`†, `upscharge`, `upsruntime`, `upsvoltage`†, `upscurrent`, `upsfrequency`, `upsload`, `upstemperature`

† requires `"identifier"` key (disk: full string like `"sdc | Type: HDD | Model: … | Serial: …"`, interface: `"enxc8a362406da3"`, upsvoltage: `"battery"/"input"/"output"`)
‡ valid name but returns "Method call error" if ARC rate collection not enabled on the server

### Known 25.x Quirks (verified against 25.10.3)
- `bootenv.query` → renamed to `boot.environment.query`; `id` field is the version string used as display name
- `network.configuration` → renamed to `network.configuration.config`
- `audit.query` params → `[{"query-options":{…}}]` NOT `[[], {…}]`
- `reporting.get_data` params → `[[{…}]]` NOT `[{"graphs":[{…}]}]`
- `state.aliases` — interface IPs live here, not top-level `aliases`
- `link_state` — value contains "UP" substring (e.g. `"LINK_STATE_UP"`); use `.contains("UP")`
- `reporting` rows — `row[0]` is Unix timestamp; `legend[0]` is always `"time"` (skip it)
- `compressratio.parsed` — String `"1.88x"` in 25.x, not Double; `ZFSDouble` handles both
- Memory reporting — only `available` bytes returned; compute `used = physmem − available`
- BSON dates — timestamps come as `{"$date": ms}` objects; decoded by `TaskBSONDate` / `BSONDate` helpers
- WSS required — TrueNAS revokes API keys used over plain `ws://`; app always connects via `wss://`
- Self-signed cert — `InsecureTLSDelegate` in `TrueNASNetworkManager.swift` accepts it unconditionally
- `disk.query` always returns `pool: null` — DO NOT use for pool membership
- `disk.details` is the ONLY correct way to get pool membership (including boot-pool for OS drives)
  - params: `[{"type":"BOTH","join_partitions":false}]`
  - returns `{"used":[…],"unused":[…]}` each entry has `imported_zpool` and `exported_zpool`
  - boot drives (sda/sdf) → `imported_zpool: "boot-pool"` (not in pool.query)
- `disk.temperatures` params must be `[[]]` (outer = params array, inner = empty list of names = all disks)
  - **NOT** `[{}]` which causes EINVAL "Input should be a valid list"
- `disk.smart_test` — method exists but is NOT in core.get_methods (internal)
  - correct params: `[[diskName], "SHORT"]` (two positional args: list of names, type string)
  - **NOT** `[{"disks":[…],"type":"…"}]`
  - Old method `smart.test.manual_test` does NOT exist in 25.x
- No public API to READ S.M.A.R.T. results or attributes in 25.x; display status as "Unknown"

---

## Navigation Structure (9 Tabs)

```
TabView (adaptive — sidebar on iPad, tab bar on iPhone)
├── 1. Dashboard          ← gauge.with.dots.needle.bottom.50percent
├── 2. Storage            ← externaldrive.fill.badge.checkmark
├── 3. Network            ← network
├── 4. Shares             ← folder.fill.badge.person.crop
├── 5. Data Protection    ← shield.checkered
├── 6. Services           ← server.rack
├── 7. Apps               ← square.grid.2x2.fill
├── 8. Reporting          ← chart.xyaxis.line
└── 9. System             ← gearshape.2.fill
```

---

## EXHAUSTIVE FEATURE LIST (All Planned for Implementation)

### TAB 1 — Dashboard
- [ ] System hostname + version + software edition badge
- [ ] Live uptime counter (animated, formatted d/h/m/s)
- [ ] CPU circular progress ring (animated, color changes with load)
- [ ] CPU mini sparkline chart (last 30 data points)
- [ ] RAM circular progress ring with color tiers
- [ ] RAM breakdown: free / ZFS ARC cache / services / used
- [ ] Network I/O live bar chart (in Mbps / out Mbps, per active interface)
- [ ] Storage pool health summary cards (mini, one per pool)
- [ ] Active alerts count badge + top 3 alert preview
- [ ] Backup task status strip (last replication/cloud sync result)
- [ ] Update available banner (when update is pending)
- [ ] Pull-to-refresh + auto-refresh per configured interval

### TAB 2 — Storage
**Pools**
- [ ] Pool list: name, status badge (color-coded), capacity bar, disk count
- [ ] Pool health: Online / Degraded / Faulted / Unavailable
- [ ] Per-pool: total capacity, used/free in GiB/TiB, % used
- [ ] Per-pool: VDEV count, last scrub date + result
- [ ] Per-pool: error counts (read/write/checksum)
- [ ] Pool actions: Scrub Now, Export Pool (confirmation dialog)
- [ ] VDEV topology view (data/cache/log/dedup/spare tree)
- [ ] Per-VDEV status and capacity
**Disks**
- [ ] Disk list: device name, model, serial, size, pool assignment
- [ ] Per-disk: temperature, power-on hours, S.M.A.R.T. status (pass/fail/unknown)
- [ ] Per-disk: read/write errors
- [ ] S.M.A.R.T. test action (short/long) with confirmation
- [ ] Last S.M.A.R.T. test result detail
**Datasets & Zvols**
- [ ] Dataset tree (hierarchical indented list)
- [ ] Per-dataset: path, type (filesystem/zvol), used/available
- [ ] Per-dataset: compression ratio, dedup ratio
- [ ] Per-dataset: encryption status (encrypted / locked / unencrypted)
- [ ] Per-dataset: snapshot count
- [ ] Dataset actions: Create child dataset, Create snapshot, Edit quotas, Delete
- [ ] Zvol list with size and sparse flag
- [ ] Snapshot list per dataset: name, creation date, referenced size, hold count
- [ ] Snapshot actions: Delete, Rollback (with confirmation), Clone

### TAB 3 — Network
**Interfaces**
- [ ] Interface list: name, type badge (Physical/VLAN/Bridge/LAG), link status
- [ ] Per-interface: IP address, speed, MTU
- [ ] Per-interface: live in/out traffic (Mbps), total bytes sent/received
- [ ] Per-interface: link state indicator (Up = green, Down = red)
- [ ] Interface detail: traffic history chart (last hour)
- [ ] DHCP vs static indicator
- [ ] MAC address display
**Global Config**
- [ ] Hostname, domain, IPv4 default gateway
- [ ] DNS servers (primary, secondary, search domain)
- [ ] IPv6 status
- [ ] Outbound network interface
**Static Routes**
- [ ] Route list: destination, gateway, description
**IPMI** (if available)
- [ ] IPMI status + channel IP (read-only view)

### TAB 4 — Shares
**SMB (Windows)**
- [ ] SMB service status (running / stopped) with toggle
- [ ] Share list: name, path, enabled toggle, comment
- [ ] Per-share: enabled/disabled state
- [ ] Quick enable/disable toggle per share
**NFS**
- [ ] NFS service status with toggle
- [ ] Export list: path, network/hosts, permission summary
- [ ] maproot/mapall display
**iSCSI**
- [ ] iSCSI service status
- [ ] Target list: name, IQN, auth type
- [ ] Extent list: name, path/device, size
- [ ] Initiator groups list

### TAB 5 — Data Protection
**Snapshot Tasks**
- [ ] Task list: dataset, lifetime, schedule (cron expression → human readable)
- [ ] Last run time + status
- [ ] Enable/disable toggle
- [ ] Run now action
**Replication Tasks**
- [ ] Task list: source → destination, transport (SSH/local/netcat)
- [ ] Last run: time + status (success/failed/in-progress)
- [ ] Run now action + live progress indicator
- [ ] Enabled/disabled toggle
**Cloud Sync Tasks**
- [ ] Task list: description, provider, direction (push/pull), schedule
- [ ] Last run: time + status + bytes transferred
- [ ] Run now action
- [ ] Enabled/disabled toggle
**Rsync Tasks**
- [ ] Task list: source path, remote host, schedule
- [ ] Last run status
- [ ] Run now action
**Scrub Tasks**
- [ ] Per-pool scrub schedule
- [ ] Last scrub: date, duration, errors
- [ ] Run scrub now action (confirmation)
- [ ] Live scrub progress (% complete) when running
**S.M.A.R.T. Tests**
- [ ] Scheduled test list: disk, test type, schedule
- [ ] Run test now (short / long / conveyance)

### TAB 6 — Services & VMs
**Services** (segmented: Services / VMs)
- [ ] All TrueNAS system services: SMB, NFS, SSH, FTP, S.M.A.R.T., SNMP, iSCSI, UPS, NTPd, Rsyncd
- [ ] Per-service: status dot, running/stopped label, "Start on Boot" indicator
- [ ] Actions: Start, Stop, Restart (swipe + context menu + inline buttons)
- [ ] Quick status toggle (tap to start/stop)
**Virtual Machines**
- [ ] VM list: name, status, CPU count, RAM allocation
- [ ] Per-VM: uptime when running, description
- [ ] Actions: Start, Stop, Restart, Force Stop (with confirmation)
- [ ] VM status: Running / Stopped / Error

### TAB 7 — Apps
**Installed Apps**
- [ ] App list: name, version, status badge (Running/Stopped/Deploying/Error)
- [ ] Per-app: icon (SF Symbol fallback), description
- [ ] Actions: Start, Stop, Upgrade (if update available)
- [ ] Update available badge
- [ ] App log viewer (last N lines) — read-only

### TAB 8 — Reporting
**Charts (all with time range selector: 1h / 6h / 24h / 7d)**
- [ ] CPU Usage: line chart with average + per-core overlay option
- [ ] System Load: 1-min, 5-min, 15-min load averages
- [ ] Memory: stacked area chart (used / ZFS cache / services / free)
- [ ] Network: per-interface in/out area chart (switchable interface)
- [ ] Disk I/O: read/write throughput per disk (switchable)
- [ ] ZFS ARC: size + hit rate line chart
- [ ] CPU Temperature: line chart per sensor
- [ ] UPS (if configured): input/output voltage, load %

### TAB 9 — System
**Alerts**
- [ ] Active alert list: level badge (Critical/Warning/Info), message, timestamp
- [ ] One-tap dismiss
- [ ] Dismissed alerts view
- [ ] Alert level color coding (red/orange/blue)
**Update**
- [ ] Current version display
- [ ] Available update info (version, changelog summary)
- [ ] Update in progress: live job progress bar
**Boot Environments**
- [ ] Boot env list: name, created date, size, active status (star)
- [ ] Actions: Activate (confirmation), Clone, Delete (swipe)
**Users & Groups**
- [ ] User list: username, UID, full name, shell, groups
- [ ] Group list: name, GID, member count
**Certificates**
- [ ] Certificate list: name, CN, issuer, expiry date + color (green/orange/red)
- [ ] CA list: name, CN, expiry
- [ ] Days-until-expiry badge
**Audit Log**
- [ ] Log entries: timestamp, username, service, event, status
- [ ] Filter bar (by service, by user)
- [ ] Expandable detail per entry
**General Info** (read-only)
- [ ] Hostname, domain, timezone, language
- [ ] NTP servers
- [ ] GUI protocol/port

---

## File Structure (Target)

```
TrueNAS Remote/
├── TrueNAS_RemoteApp.swift
├── ContentView.swift (stub)
│
├── Models/
│   ├── SystemInfo.swift          ← SystemInfo, TemperaturePoint
│   ├── StoragePool.swift         ← StoragePool, PoolStatus, VDEV
│   ├── Disk.swift                ← Disk, SmartStatus, SmartTestResult
│   ├── Dataset.swift             ← Dataset, DatasetType, Zvol, Snapshot
│   ├── NetworkInterface.swift    ← NetworkInterface, InterfaceType, TrafficSample
│   ├── Share.swift               ← SMBShare, NFSShare, ISCSITarget, ISCSIExtent
│   ├── DataProtection.swift      ← SnapshotTask, ReplicationTask, CloudSyncTask, RsyncTask, ScrubTask
│   ├── Service.swift             ← AppService, ServiceState (system services)
│   ├── VirtualMachine.swift      ← VirtualMachine, VMState
│   ├── TrueNASApp.swift          ← TrueNASApp, AppStatus (installed apps)
│   ├── Alert.swift               ← TrueNASAlert, AlertLevel
│   ├── User.swift                ← TrueNASUser, TrueNASGroup
│   ├── Certificate.swift         ← Certificate, CertificateAuthority
│   ├── BootEnvironment.swift     ← BootEnvironment
│   └── AuditLog.swift            ← AuditEntry
│
├── Networking/
│   ├── KeychainManager.swift
│   ├── TrueNASNetworkManager.swift        ← core request engine
│   ├── TrueNASNetworkManager+System.swift
│   ├── TrueNASNetworkManager+Storage.swift
│   ├── TrueNASNetworkManager+Dataset.swift
│   ├── TrueNASNetworkManager+Network.swift
│   ├── TrueNASNetworkManager+Shares.swift
│   ├── TrueNASNetworkManager+DataProtection.swift
│   ├── TrueNASNetworkManager+Services.swift
│   └── TrueNASNetworkManager+Reporting.swift
│
├── ViewModels/
│   ├── DashboardViewModel.swift
│   ├── StorageViewModel.swift
│   ├── DatasetViewModel.swift
│   ├── NetworkViewModel.swift
│   ├── SharesViewModel.swift
│   ├── DataProtectionViewModel.swift
│   ├── ServicesViewModel.swift
│   ├── AppsViewModel.swift
│   ├── ReportingViewModel.swift
│   ├── SystemViewModel.swift
│   └── SettingsViewModel.swift
│
└── Views/
    ├── MainTabView.swift
    ├── Components/
    │   ├── CircularProgressRing.swift
    │   ├── StatusDot.swift
    │   ├── HealthBadge.swift
    │   ├── CapacityBar.swift
    │   ├── MetricCard.swift
    │   └── TimeRangePicker.swift
    ├── Dashboard/
    │   ├── DashboardView.swift
    │   ├── PoolSummaryCard.swift
    │   ├── NetworkSparklineCard.swift
    │   └── TemperatureChartView.swift
    ├── Storage/
    │   ├── StorageRootView.swift      ← Pools / Disks / Datasets tabs
    │   ├── PoolListView.swift
    │   ├── PoolDetailView.swift
    │   ├── VDEVTreeView.swift
    │   ├── DiskListView.swift
    │   ├── DiskDetailView.swift
    │   ├── DatasetListView.swift
    │   ├── DatasetDetailView.swift
    │   └── SnapshotListView.swift
    ├── Network/
    │   ├── NetworkView.swift
    │   ├── InterfaceDetailView.swift
    │   └── GlobalNetworkView.swift
    ├── Shares/
    │   ├── SharesView.swift
    │   ├── SMBSharesView.swift
    │   ├── NFSSharesView.swift
    │   └── ISCSIView.swift
    ├── DataProtection/
    │   ├── DataProtectionView.swift
    │   ├── SnapshotTasksView.swift
    │   ├── ReplicationView.swift
    │   ├── CloudSyncView.swift
    │   ├── RsyncView.swift
    │   └── ScrubView.swift
    ├── Services/
    │   └── ServicesView.swift
    ├── Apps/
    │   └── AppsView.swift
    ├── Reporting/
    │   ├── ReportingView.swift
    │   └── ReportingChartView.swift
    └── System/
        ├── SystemView.swift
        ├── AlertsView.swift
        ├── UpdateView.swift
        ├── BootEnvironmentsView.swift
        ├── UsersGroupsView.swift
        ├── CertificatesView.swift
        ├── AuditLogView.swift
        └── GeneralInfoView.swift
```

---

## Build Checklist

### Phase 1 — Architecture & Navigation
- [x] Old 4-tab structure
- [x] Migrate to 9-tab adaptive navigation
- [x] Create all model files (16 model files)
- [x] Split NetworkManager into domain extensions (9 networking files)

### Phase 2 — Dashboard & Reporting
- [x] Dashboard v2 (full metrics — system card, CPU/RAM rings, network chart, pool health, temperature)
- [x] Reporting charts (7 chart types: CPU, Load, Memory, Network, ARC, Temperature, Disk I/O)
- [x] Time range selector (1h / 24h / 7d) with live refresh

### Phase 3 — Storage & Datasets
- [x] StorageRootView (Pools / Disks / Datasets segmented with lazy loading)
- [x] Pool list with health badge + capacity bar; pool detail with VDEV tree
- [x] Disk list + disk detail with S.M.A.R.T. test runner
- [x] Dataset tree (hierarchical) + dataset detail with snapshot create/delete/rollback
- [x] Snapshot list per dataset with swipe actions

### Phase 4 — Network & Shares
- [x] Network interfaces list with live traffic sparklines + interface detail chart
- [x] Global config view (hostname, gateways, DNS, proxy)
- [x] Static routes list
- [x] SMB / NFS / iSCSI shares views with enable/disable toggle

### Phase 5 — Data Protection
- [x] Snapshot tasks, replication, cloud sync, rsync, scrub (all 5 types)
- [x] Run now buttons + status badges + progress for scrub

### Phase 6 — Services, VMs, Apps
- [x] Services (grouped Running/Stopped with search), VMs, Apps (all 3 in ServicesView)
- [x] Swipe actions + context menus for start/stop/restart
- [x] Searchable services list

### Phase 7 — System
- [x] Alerts (active + dismissed) with swipe-to-dismiss
- [x] Boot Environments with activate button
- [x] Users & Groups list
- [x] Certificates with days-to-expiry color coding
- [x] Audit Log with search + service filter
- [x] Update tab with version info and update available banner

### All Builds — iPhone 17 Simulator
- [x] Build clean after Phase 1
- [x] Build clean after Phase 2
- [x] Build clean after Phase 3
- [x] Build clean after Phase 4
- [x] Build clean after Phase 5
- [x] Build clean after Phase 6
- [x] Build clean after Phase 7
- [x] Final clean build — BUILD SUCCEEDED (2026-05-23)
- [x] Build clean after Session 2 API fixes — BUILD SUCCEEDED (2026-05-24)
- [x] Build clean after Session 3 nav + loading fixes — BUILD SUCCEEDED (2026-05-24)
- [x] Build clean after Session 4 WebSocket migration — BUILD SUCCEEDED (2026-05-26)

---

## Real-Data Audit (2026-05-24)

Goal: eliminate all hardcoded placeholder / mock data so the app shows only real server data when connected.

### ViewModels — Remove `loadMockData()` from `init()`
- [x] `DashboardViewModel` — removed; `refresh()` now fetches real data via reporting API
- [x] `StorageViewModel`   — removed; pools/disks/datasets load from API on first refresh
- [x] `NetworkViewModel`   — removed; interfaces and config load from API on first refresh
- [x] `SharesViewModel`    — removed; SMB/NFS/iSCSI data loads from API on first refresh
- [x] `DataProtectionViewModel` — removed; all task lists load from API on first refresh
- [x] `ServicesViewModel`  — removed; services/VMs/apps load from API on first refresh
- [x] `SystemViewModel`    — removed; alerts/boot-envs/users/certs load from API on first refresh
- [x] `ReportingViewModel` — removed `loadMockData()` and `mockSeries()` helper

### DashboardViewModel — Real-data `refresh()`
- [x] Parallel `async let` for `fetchSystemInfo()` + CPU/memory/temp reporting graphs
- [x] `cpuHistory` and `systemInfo.cpuUsage` populated from `cpu` reporting series
- [x] `systemInfo.memoryUsed` and `memoryZFSCache` derived from memory reporting series
- [x] `temperatures` populated from first `cputemp` reporting series
- [x] `networkSeries` — best-effort: discovers primary interface via `fetchInterfaces()`, then fetches reporting; falls back to empty on error

### Network Layer — Fix incomplete API decoders
- [x] `fetchDatasets()` — added `ZFSInt/ZFSDouble/ZFSCount/ZFSString` prop helpers; `usedBytes`, `availableBytes`, `referencedBytes`, `compressionRatio`, `deduplicationRatio`, `snapshotCount`, `comments` all decoded from top-level ZFS property containers
- [x] `fetchSnapshots()` — added `properties.creation.rawvalue` (Unix seconds string → `Date`), `properties.referenced/used.parsed` for byte sizes, `holds.count` for hold count
- [x] `fetchPools()` — replaced `AnyCodable?` scan.endTime with `BSONDate` struct that decodes `{"$date": ms}` format; `lastScrub` now populated
- [x] `fetchDisks()` — added `temperature: Int?` to Raw struct (populated when drive firmware reports it)

### Reporting API — Format correction (TrueNAS 25.x)
- [x] Fixed request body: removed `reporting_query` wrapper — correct format is `{"graphs":[{"name":"cpu"}]}`
- [x] Fixed response parser: `step` is `null` in 25.x; timestamp is now read from `row[0]` instead of `start + rowIdx * step`
- [x] Fixed legend: `legend[0]` is always `"time"` (skipped); series names are `legend[1…]`; values are `row[1…]`
- [x] Fixed memory: 25.x reports only `available` bytes (no `used`); app now computes `memoryUsed = physmem − available`
- [x] Fixed CPU series: aggregate `"cpu"` is `legend[1]` (first series after skipping "time")
- [x] Fixed compressratio decoder: `parsed` field is a String `"1.88"`, not a Double — `ZFSDouble` now handles both
- [x] `ReportingViewModel` network chart: auto-discovers interface name via `fetchInterfaces()` on first load; isolated to its own do-catch so a bad interface name can't fail the whole refresh

### SettingsView — API key instructions
- [x] Added "API Key Setup" section with 4-step instructions (Credentials → API Keys)
- [x] Added `Link` button that opens `<hostURL>/ui/apikeys` in Safari when a host URL is configured

---

## Live API Audit & Fixes (2026-05-24 — Session 2)

All changes verified against TrueNAS SCALE 25.10.3 at http://192.168.1.99.

### `TrueNASNetworkManager+System.swift`
- [x] **Boot environments**: `/api/v2.0/bootenv` returns 404 on 25.x — `fetchBootEnvironments()` now wraps the GET in a do-catch and returns `[]` silently instead of throwing
- [x] **Users `home` field**: API returns `"home"` not `"home_directory"` — Raw struct renamed `homeDirectory` → `home`; initializer updated
- [x] **Certificates `common` field**: API returns `"common"` not `"common_name"` — Raw struct renamed `commonName` → `common`; initializer updated
- [x] **Audit log endpoint**: `GET /api/v2.0/audit` returns config object not entries — changed to `POST /api/v2.0/audit/query` with `{"query-options":{"limit":100,"order_by":["-message_timestamp"]}}` body; `timestamp` field decoded as BSON `{"$date": ms}` date; whole function wrapped in do-catch returning `[]` on any failure

### `SystemViewModel.swift`
- [x] **Resilient refresh**: Restructured so alerts/users/groups/certs are fetched in primary do-catch, while bootenv and audit use `try?` independently — a 404 on bootenv no longer prevents the other data from loading

### `TrueNASNetworkManager+Network.swift`
- [x] **Interface IP addresses**: IPs were decoded from top-level `aliases` (always empty in 25.x) — moved to `state.aliases`; added `aliases: [AliasRaw]?` to `StateRaw`; top-level `aliases` field removed from `Raw`
- [x] **Link state check**: Made lenient — now matches any string containing "UP" (handles both "LINK_STATE_UP" and "UP" variants)
- [x] **Network "labeled as Down" bug**: Fixed — was caused by empty IP list making the Down path show even for connected interfaces; now resolved via state.aliases fix

### `TrueNASNetworkManager+Services.swift`
- [x] **VM memory already in MB**: API `memory` field is already MB (e.g. 5120 = 5 GB) — removed erroneous `/ (1024 * 1024)` divide
- [x] **App icon URLs**: Added `icon: String?` to `MetaRaw`; `InstalledApp.iconURL` now populated from `metadata.icon` URL (e.g. `https://media.sys.truenas.net/apps/…`)

### `InstalledApp.swift`
- [x] Added `iconURL: String?` field to the model

### `TrueNASNetworkManager+DataProtection.swift`
- [x] **BSON dates**: Added `TaskBSONDate` struct (handles `{"$date": ms}` format) for all task state timestamps
- [x] **Replication datetime**: `StateRaw.datetime` changed from `Double?` to `TaskBSONDate?`; `lastRun` now correctly populated
- [x] **Cloud sync job time**: `JobRaw.timeStarted` changed from `Double?` to `TaskBSONDate?`
- [x] **Rsync job time**: `JobRaw.timeStarted` changed from `Double?` to `TaskBSONDate?`
- [x] **Cloud sync credentials.provider**: Was `String?` but API returns an object in 25.x — removed the `provider` field from `CredsRaw`, keep only `name`
- [x] **Scrub task pool**: `pool` field is Int (pool ID) not String in 25.x — now decoded via `AnyCodable?`; display shows "Pool N" for numeric IDs; also added `poolName: String?` field as fallback for future API versions

### `TrueNASNetworkManager+Shares.swift`
- [x] **SMB `guestok` nesting**: In 25.x `guestok` is under `options.guestok` not top-level — added `Options` nested struct; decoder uses `options?.guestok ?? guestok` (fallback for older API)

### UI — Navigation Bar & Spacing
- [x] **All main tab views now use `.navigationBarTitleDisplayMode(.inline)`**: Dashboard, Storage, Network, Shares, DataProtection, Services, Reporting, System — eliminates "spaced out at top" large-title gap and puts reload button in same compact nav bar row as the title/back button area

### UI — Disk Status Indicators (`StorageRootView.swift`)
- [x] **`DiskListRow` redesigned**: Now shows:
  - Colored status dot (blue = in a pool, orange = has errors, red = SMART failed, grey = unallocated)
  - Pool membership badge (pill: pool name in blue, or "Unallocated" in grey)
  - Error count label (orange, shown only when `totalErrors > 0`)
  - Temperature label (moved inline, shown only when available)
  - SMART status label on trailing side
  - Drive size on trailing side

### UI — App Icons (`ServicesView.swift`)
- [x] **`AppRow` now shows real app icons via `AsyncImage`**: Loads icon from `app.iconURL` URL; falls back to generic `app.fill` SF Symbol icon with accent color background if URL is nil or load fails

### Endpoint Map Updates
- `GET /api/v2.0/bootenv` → 404 on 25.x (not available)
- `GET /api/v2.0/audit` → returns config (not entries)
- `POST /api/v2.0/audit/query` → correct audit entries endpoint for 25.x

---

## UI Polish & Navigation Fixes (2026-05-24 — Session 3)

### iOS 26 NavigationStack Architecture Fix

**Root cause**: iOS 26's new `Tab` API creates its own navigation layer. Wrapping individual view bodies in a second `NavigationStack` caused double-nesting, which iOS 26 injected as a spurious `<` back button on every root tab view, plus extra blank space below the status bar.

**Fix**: All `NavigationStack` wrappers moved to `MainTabView` (one per `Tab`). Individual views use `.navigationTitle()`, `.navigationBarTitleDisplayMode(.inline)`, and `.toolbar {}` as modifiers that propagate up to the owning stack.

**Rule going forward**: Never wrap a tab root view's `body` in `NavigationStack`. Only `MainTabView` owns stacks. Detail views pushed via `NavigationLink` (e.g. `PoolDetailView`, `DiskDetailView`, `InterfaceDetailView`) do not need their own stack either — they inherit the tab's stack.

Files updated (NavigationStack removed from `body`):
- [x] `DashboardView.swift`
- [x] `StorageRootView.swift`
- [x] `NetworkView.swift`
- [x] `SharesView.swift`
- [x] `DataProtectionView.swift`
- [x] `ServicesView.swift`
- [x] `ReportingView.swift`
- [x] `SystemView.swift`
- [x] `SettingsView.swift`

`MainTabView.swift` — added `NavigationStack { }` around every `Tab`'s content view (9 tabs total).

### Loading State — ProgressView Replaces Flash-of-Empty-State

**Problem**: All list views checked `if data.isEmpty` and showed `ContentUnavailableView` immediately on first render, before the first `refresh()` completed. This caused a brief flash of "No Pools", "No SMB Shares", etc. every time a tab was tapped.

**Fix**: Added a three-way guard at the top of every list view:
```swift
if vm.isLoading && data.isEmpty   → ProgressView (centered, full area)
else if data.isEmpty              → ContentUnavailableView (genuine empty)
else                              → the real list
```

This means the spinner shows only on first load (when data is empty AND a fetch is in progress). On subsequent refreshes the existing data stays visible while the toolbar spinner updates.

Views fixed:
- [x] `StorageRootView.swift` — Pools, Disks, Datasets
- [x] `SharesView.swift` — SMB, NFS, iSCSI
- [x] `NetworkView.swift` — Interfaces, Static Routes
- [x] `DataProtectionView.swift` — Snapshots, Replication, Cloud Sync, Rsync, Scrub (all 5)
- [x] `ServicesView.swift` — VMs, Apps (also added proper `ContentUnavailableView` empty states that were missing)
- [x] `SystemView.swift` — Alerts

Note: Services list (system services) is not guarded because an empty Running+Stopped list renders as blank rather than a misleading error message, and the toolbar spinner is sufficient feedback there.

---

## WebSocket JSON-RPC 2.0 Migration (2026-05-26 — Session 4)

### Background

TrueNAS SCALE issued a deprecation warning that the REST API will be **removed in version 26.04**. The app was generating ~2,275 REST calls per day. All networking code was migrated to JSON-RPC 2.0 over WebSocket (`ws(s)://<host>/api/current`).

### Architecture Change: `class` → `actor`

`TrueNASNetworkManager` was rewritten from a plain `class` to a Swift `actor`. This provides automatic thread-safety for mutable WebSocket state without locks.

Key design decisions:
- **Single persistent WebSocket connection** — authenticated on connect via `auth.login_with_api_key`, reused for all calls; reconnects transparently on next call after drop
- **`nonisolated func configure()`** — allows `SettingsViewModel` to call `configure()` synchronously without `await`; dispatches actor state update via `Task { await self._apply(...) }`
- **`params: Data?`** — pre-serialised JSON array as `Data` is `Sendable`; avoids Swift 6 `[Any]` Sendability violations across actor boundaries
- **Auth stored in `pending["__auth__"]`** — ensures `_drop()` always resumes auth continuation; prevents orphaned-continuation crashes if connection drops during auth
- **`connecting: Task<Void, Error>?`** — serialises concurrent first-call connection attempts (prevents multiple simultaneous `_connect()` runs)
- **`_drop()` clears `pending` before resuming** — `let p = pending; pending = [:]; p.values.forEach { ... }` — makes drop idempotent; prevents double-resume

### Files Rewritten (all 9 networking extensions)

| File | Methods converted |
|------|-------------------|
| `TrueNASNetworkManager.swift` | Full rewrite: REST engine → WebSocket actor |
| `TrueNASNetworkManager+System.swift` | `system.info`, `alert.list/dismiss`, `bootenv.query/activate`, `user.query`, `group.query`, `certificate.query`, `audit.query` |
| `TrueNASNetworkManager+Storage.swift` | `pool.query`, `pool.scrub`, `disk.query`, `smart.test.manual_test` |
| `TrueNASNetworkManager+Dataset.swift` | `pool.dataset.query`, `pool.snapshot.query/create/delete/rollback` |
| `TrueNASNetworkManager+Network.swift` | `interface.query`, `network.configuration`, `staticroute.query` |
| `TrueNASNetworkManager+Shares.swift` | `sharing.smb.query/update`, `sharing.nfs.query`, `iscsi.target.query`, `iscsi.extent.query` |
| `TrueNASNetworkManager+DataProtection.swift` | `pool.snapshottask.query/run`, `replication.query/run`, `cloudsync.query/run`, `rsynctask.query/run`, `pool.scrub.query` |
| `TrueNASNetworkManager+Services.swift` | `service.query`, `service.<action>` (start/stop/restart), `vm.query`, `vm.<action>`, `app.query`, `app.<action>` |
| `TrueNASNetworkManager+Reporting.swift` | `reporting.get_data` with `{"graphs":[{"name":"cpu"}]}` params |

### Build Fix — `nonisolated` on global helpers

With `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, global free functions and extension methods are implicitly `@MainActor`. Two helpers in `TrueNASNetworkManager+System.swift` needed explicit `nonisolated`:
- `private nonisolated func decodeBSONDate(from:)` — called from inside `Decodable.init(from:)` (synchronous, nonisolated context)
- `nonisolated subscript(safe index: Int)` on `Array` — called from actor context; without `nonisolated` triggers "expression is async but not marked with await" error

### Build Verification
- [x] Build clean after Session 4 WebSocket migration — **BUILD SUCCEEDED** (2026-05-26)
- [x] Build clean after Session 5 endpoint audit — **BUILD SUCCEEDED** (2026-05-26)
- [x] Build clean after Session 6 performance + nav fixes — **BUILD SUCCEEDED** (2026-05-27)

---

## Performance & Navigation Fixes (2026-05-27 — Session 6)

### Root-cause: 30-second startup

Three compounding causes identified and fixed:

1. **No per-call timeout** — any `reporting.get_data` call that received no server response
   blocked the `withCheckedThrowingContinuation` forever (or until `timeoutIntervalForResource = 300`).
   A single hung call was enough to freeze the whole `DashboardViewModel.refresh()` cycle.

2. **All reporting data waited before showing anything** — `isLoading` stayed `true` until all
   5 concurrent `reporting.get_data` calls completed (~5–15 s). Rings and cards showed 0 / blank
   the entire time even though `system.info` returned in <1 s.

3. **WebSocket connected on first API call** — the TLS handshake + auth cost (~1–2 s) hit every
   cold launch because the socket was lazy-connected only when a view first appeared.

### Fixes applied

**`TrueNASNetworkManager.swift`**
- Added 15-second per-call timeout inside `call()`: a background `Task` sleeps for 15 s then
  calls `_fail(id:err:)`. If the real response arrives first, `_fail` is a no-op (continuation
  already removed from `pending`). Prevents any single hung call from blocking indefinitely.
- Added `nonisolated func preconnect()` — fires `_ensureConnected()` as a detached best-effort
  task; called from `SettingsViewModel.init()` on app launch.

**`ViewModels/DashboardViewModel.swift`** — split into fast + slow paths
- `refresh()` — **fast path**: fetches only `system.info` (~0.5 s); sets `isLoading = false`
  immediately after; triggers background chart load if one isn't already running.
- `refreshCharts()` — **slow path**: fetches 4 reporting graphs + network sparkline concurrently;
  guarded by `isLoadingCharts`; updates ring values (`cpuUsage`, `memoryUsed`, `memoryZFSCache`)
  and history arrays when data arrives.
- `isLoadingCharts` — new flag; `DashboardView` toolbar spinner shows while EITHER `isLoading`
  OR `isLoadingCharts` is true.

**`ViewModels/SettingsViewModel.swift`**
- `init()` now calls `network.preconnect()` when credentials are already stored — starts the
  WebSocket handshake in the background while the app's first view is still rendering.

**`Views/Dashboard/DashboardView.swift`**
- `.refreshable` now awaits both `vm.refresh()` AND `vm.refreshCharts()` so pull-to-refresh
  updates charts immediately.
- Toolbar spinner condition: `vm.isLoading || vm.isLoadingCharts`.

### Navigation bar gap fix (back-button on separate row)

**Root cause**: `.navigationBarTitleDisplayMode(.inline)` (iOS 14 API) is not fully respected by
iOS 26's new `Tab` + `NavigationStack` navigation renderer, causing the back button to render in
its own "back bar" row above the view title.

**Fix**: replaced every `.navigationBarTitleDisplayMode(.inline)` with `.toolbarTitleDisplayMode(.inline)`
(iOS 17+ API, designed for the new navigation system) in all 18 call-sites across:
`DashboardView`, `StorageRootView`, `StorageView`, `PoolDetailView`, `NetworkView`,
`InterfaceDetailView`, `SharesView`, `DataProtectionView`, `ServicesView`, `ReportingView`,
`SystemView`, `SettingsView`, `SetupWizardView`.

Additionally, `.toolbarTitleDisplayMode(.inline)` is now applied to the `NavigationStack`
wrapper in each of the 9 tabs in `MainTabView.swift`. This sets the inline mode as the
**default for all pushed detail views** in the stack, so any view that doesn't explicitly set it
still behaves correctly.

**`StorageView.swift`** (legacy file, superseded by `StorageRootView.swift`): removed the
embedded `NavigationStack` to prevent double-stacking if the view is ever instantiated.
`.toolbarTitleDisplayMode(.inline)` added for consistency.
