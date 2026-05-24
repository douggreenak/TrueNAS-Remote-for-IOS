# TrueNAS Remote — iOS App

## Architecture
- **Pattern**: MVVM — `@Observable` ViewModels, SwiftUI Views, async/await Networking
- **Auth**: `Authorization: Bearer <key>` header; credentials stored in iOS Keychain
- **NetworkManager**: One core class + per-domain Swift extensions for each feature area
- **Navigation**: iOS 26 adaptive `TabView` (sidebar on iPad, tab bar on iPhone)
- **Charts**: Swift Charts (`import Charts`) for all time-series graphs
- **Design target**: Native Apple look — SF Symbols, Materials, insetGrouped Lists,
  large NavBar titles, `ContentUnavailableView`, swipe actions, context menus
- **Build**: Xcode 26.5, Swift 5.0, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`

---

## TrueNAS REST API v2.0 — Endpoint Map

| Domain | Endpoint | Method | Notes |
|--------|----------|--------|-------|
| System | `/api/v2.0/system/info` | GET | version, hostname, uptime_seconds, physmem |
| System | `/api/v2.0/system/version` | GET | short version string |
| System | `/api/v2.0/update/check_available` | POST | update availability |
| System | `/api/v2.0/boot/get_state` | GET | boot environment info |
| System | `/api/v2.0/bootenv` | GET | boot environments list |
| System | `/api/v2.0/bootenv/id/{id}/activate` | POST | activate boot env |
| System | `/api/v2.0/core/get_jobs` | GET | background job list |
| System | `/api/v2.0/alert/list` | GET | active alerts |
| System | `/api/v2.0/alert/dismiss` | POST | dismiss alert |
| System | `/api/v2.0/alert/restore` | POST | restore dismissed alert |
| System | `/api/v2.0/system/general` | GET | timezone, language, NTP, GUI settings |
| System | `/api/v2.0/system/advanced` | GET | console, syslog, kernel settings |
| System | `/api/v2.0/audit` | GET | audit log entries |
| System | `/api/v2.0/user` | GET | user list |
| System | `/api/v2.0/group` | GET | group list |
| System | `/api/v2.0/certificate` | GET | certificates list |
| System | `/api/v2.0/certificateauthority` | GET | CAs list |
| Storage | `/api/v2.0/pool` | GET | pool list |
| Storage | `/api/v2.0/pool/id/{id}/scrub` | POST | start pool scrub |
| Storage | `/api/v2.0/pool/id/{id}/export` | POST | export pool |
| Storage | `/api/v2.0/disk` | GET | all disks |
| Storage | `/api/v2.0/disk/id/{id}/smart_test` | POST | run S.M.A.R.T. test |
| Storage | `/api/v2.0/smart/test/results` | GET | S.M.A.R.T. test results |
| Dataset | `/api/v2.0/pool/dataset` | GET | dataset tree |
| Dataset | `/api/v2.0/pool/dataset` | POST | create dataset |
| Dataset | `/api/v2.0/pool/dataset/id/{id}` | PUT | update dataset |
| Dataset | `/api/v2.0/pool/dataset/id/{id}` | DELETE | delete dataset |
| Dataset | `/api/v2.0/pool/snapshot` | GET | snapshot list |
| Dataset | `/api/v2.0/pool/snapshot` | POST | create snapshot |
| Dataset | `/api/v2.0/pool/snapshot/id/{id}` | DELETE | delete snapshot |
| Dataset | `/api/v2.0/pool/snapshot/id/{id}/rollback` | POST | rollback to snapshot |
| Network | `/api/v2.0/interface` | GET | interfaces list |
| Network | `/api/v2.0/network/configuration` | GET | global network config |
| Network | `/api/v2.0/staticroute` | GET | static routes |
| Network | `/api/v2.0/reporting/get_data` | POST | bandwidth/CPU/mem/temp graphs |
| Shares | `/api/v2.0/sharing/smb` | GET | SMB shares |
| Shares | `/api/v2.0/sharing/smb/id/{id}` | PUT | enable/disable SMB share |
| Shares | `/api/v2.0/sharing/nfs` | GET | NFS shares |
| Shares | `/api/v2.0/sharing/nfs/id/{id}` | PUT | update NFS share |
| Shares | `/api/v2.0/iscsi/target` | GET | iSCSI targets |
| Shares | `/api/v2.0/iscsi/extent` | GET | iSCSI extents |
| DataProt | `/api/v2.0/replication` | GET | replication tasks |
| DataProt | `/api/v2.0/replication/id/{id}/run` | POST | run replication now |
| DataProt | `/api/v2.0/pool/snapshottask` | GET | periodic snapshot tasks |
| DataProt | `/api/v2.0/pool/snapshottask/id/{id}/run` | POST | run snapshot task now |
| DataProt | `/api/v2.0/cloudsync` | GET | cloud sync tasks |
| DataProt | `/api/v2.0/cloudsync/id/{id}/run` | POST | run cloud sync now |
| DataProt | `/api/v2.0/rsynctask` | GET | rsync tasks |
| DataProt | `/api/v2.0/rsynctask/id/{id}/run` | POST | run rsync now |
| DataProt | `/api/v2.0/pool/scrub` | GET | scrub tasks |
| DataProt | `/api/v2.0/smart/test` | GET | S.M.A.R.T. test schedules |
| Services | `/api/v2.0/service` | GET | service list |
| Services | `/api/v2.0/service/start` | POST | `{"service":"name"}` |
| Services | `/api/v2.0/service/stop` | POST | `{"service":"name"}` |
| Services | `/api/v2.0/service/restart` | POST | `{"service":"name"}` |
| VMs | `/api/v2.0/vm` | GET | VM list |
| VMs | `/api/v2.0/vm/id/{id}/start` | POST | start VM |
| VMs | `/api/v2.0/vm/id/{id}/stop` | POST | stop VM |
| VMs | `/api/v2.0/vm/id/{id}/restart` | POST | restart VM |
| Apps | `/api/v2.0/app` | GET | installed apps |
| Apps | `/api/v2.0/app/id/{id}/start` | POST | start app |
| Apps | `/api/v2.0/app/id/{id}/stop` | POST | stop app |

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
- [ ] Migrate to 9-tab adaptive navigation
- [ ] Create all model files
- [ ] Split NetworkManager into domain extensions

### Phase 2 — Dashboard & Reporting
- [ ] Dashboard v2 (full metrics)
- [ ] Reporting charts (8 chart types, time range picker)

### Phase 3 — Storage & Datasets
- [ ] StorageRootView (Pools / Disks / Datasets segmented)
- [ ] Pool list, pool detail, VDEV tree
- [ ] Disk list + S.M.A.R.T.
- [ ] Dataset tree + snapshots

### Phase 4 — Network & Shares
- [ ] Network interfaces list + detail
- [ ] Global config view
- [ ] SMB / NFS / iSCSI shares views

### Phase 5 — Data Protection
- [ ] Snapshot tasks, replication, cloud sync, rsync, scrub

### Phase 6 — Services, VMs, Apps
- [ ] Services (full list), VMs (actions), Apps (list + control)

### Phase 7 — System
- [ ] Alerts, Update, Boot Envs, Users/Groups, Certificates, Audit Log

### All Builds — iPhone 17 Simulator
- [ ] Build clean after Phase 1
- [ ] Build clean after Phase 2
- [ ] Build clean after Phase 3
- [ ] Build clean after Phase 4
- [ ] Build clean after Phase 5
- [ ] Build clean after Phase 6
- [ ] Build clean after Phase 7
