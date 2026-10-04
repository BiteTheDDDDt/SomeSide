# SomeSide v0.4.0 构建验收

2026-10-04，Godot `4.7.2.stable.official.ed1daf0bf`，项目内便携引擎和官方 SHA512 验证过的导出模板。交付：`dist/v0.4.0/SomeSide.exe` 和 `dist/SomeSide-v0.4.0-windows-x64.zip`。ZIP 只包含 EXE、中文快速开始和两份许可；以前版本保留。

**347 项断言全部通过**：模拟 61、掉落装备 77、地图与压力 45、探索调度 28、视觉预算 16、UI 120。完整日志：`tools/results/v0.4-final-tests.log`。地图标签避让最后修订后另复验 UI 120/120，无错误。两角色在三关全部 48 / 45 / 54 个平台上通过真实单跳可达测试，无道具或冲刺，保留 32px 起跳余量、24px 落点余量和 ±12px 起跳容差；18 个设施均有可达支撑，高门无法从底层直接交互。归一化拓扑两两重合率仅 0.26 / 0.31 / 0.31。新增测试验证动态边界、三图预测、0/120/600 秒敌人生命与弹伤增长、静止不补怪但时间难度继续、3600 事件特效预算，以及 M 地图与特效设置。

| 最终网络验收 | 结果及 tools/results 下证据 |
| --- | --- |
| 源码一房主三客户端，真实结算 | 通过；network-20261004-165631/summary.json |
| EXE 一房主三客户端，游玩中正常退出 | 通过；network-export-20261004-165903/summary.json |
| EXE 一房主一客户端，延迟/丢包结算 | 通过；network-export-impaired-20261004-165903/summary.json |

真实 UDP 代理每方向配置 50±10ms、2% 丢包；实测平均延迟 55.96 / 55.05ms，丢弃 11 / 7 个数据报，客户端收到 139 份快照，两端进入相同结果界面。所有最终 EXE 网络进程退出码 0，stderr 均 0 字节。快照沿用压缩与 950 字节分包，结算可靠发送。导出日志：`tools/results/v0.4-final-export.log`。

最终 EXE 已实际 OpenGL 游玩 7 秒、420 tick、3 次击杀，正常退出无错误；已目视 `tools/results/v04-exported-game.png`，同目录 `.log`、`.err`、`.json` 为证据。三生物群系与 0/8 层特效对照也已实际检查：`v04-biome-1.png` 至 `v04-biome-3.png`、`v04-fx-0.png`、`v04-fx-8.png`，均位于 `tools/results`。

| 产物 | 字节数 | SHA256 |
| --- | ---: | --- |
| EXE | 122619416 | C43A706ACD2778163399695E5C26747D5F9127E9FB5EA37E5FEFD135878C7537 |
| ZIP | 52681692 | E6B0C77CA78935A930304D0D20CBA526EF4911A13B873872B7F7DA77964AB461 |

机器可读记录：`tools/results/package.json`。网络验证使用本机独立进程和真实故障注入，尚未实测两台公网机器；合作需要直接 IP、局域网或可达公网地址，当前无 Steam 大厅、自动 NAT 穿透或房主迁移。旧报告归档在 `docs/BUILD_REPORT_v0.3.0.md`。
