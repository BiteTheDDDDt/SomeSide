# SomeSide v0.5.0 构建验收

2026-10-04，Godot `4.7.2.stable.official.ed1daf0bf`，项目内便携引擎与官方 SHA512 校验模板。交付 `dist/v0.5.0/SomeSide.exe`、`dist/SomeSide-v0.5.0-windows-x64.zip`；旧版保留。ZIP 只有 EXE、中文快速开始及引擎/字体许可，包内 EXE 已按哈希确认与测试文件一致。

**435 项断言全部通过**：模拟 61、拾取/装备 77、实际物品效果 56、奖励 20、地图/压力 45、探索调度 28、视觉 16、UI 132。证据：`tools/results/v0.5-test-summary.json`、`v0.5-final-tests.log`；共鸣器最后强化后复验 `v0.5-final-content.log`、`v0.5-final-stress.log`、`v0.5-final-visuals.log`。40 种物品均测实际效果；12000 次普通抽奖为 10559 被动、799 武器、642 主动。覆盖有限装备池历史回退、硬排除、多人磁环吸取、9 次长矛穿透与回旋满出程返航。24 被动各 12 层加四种新武器/主动运行 120 模拟秒，击杀 3608，所有状态与实体预算稳定；两角色三图无道具单跳路线仍全部可达。

| 最终网络验收 | tools/results 下证据 |
| --- | --- |
| 源码四人高级装备，可靠结算通过 | network-20261004-213619/summary.json |
| 最终 EXE 四人高级装备，40 秒正常退出通过 | network-export-20261004-214358/summary.json |
| 最终 EXE 二人延迟/丢包，可靠结算通过 | network-export-impaired-20261004-214457/summary.json |

四端均实际观察到炮台、陨击待触发状态、团队时序增益及回旋/雷击/光矛投射物。首次短测漏采一端的短暂陨击状态，已将验收记录移到每份接收快照，并延长测试覆盖真实冷却；最终严格观测断言全部通过。受损网络每方向配置 50±10ms、2% 丢包，实际平均延迟 54.98/53.70ms、丢弃 7/12 个数据报；客户端收到 134 份快照，两端均进入 lost/results。所有最终网络进程退出码 0、无脚本或运行错误；压缩快照沿用 950 字节分包，结算可靠发送。

| 产物 | 字节数 | SHA256 |
| --- | ---: | --- |
| EXE | 122647592 | 7A32982BE4C169A322724030F21398B1164EF9F305E626B9CD82147F92F72DE8 |
| ZIP | 52709991 | 02BB37E586C7F40B81F9AB6DEE3B12B62C28D1202B8FE770C23C323BA2460733 |

机器记录：`tools/results/package.json`、`v0.5-package-verification.json`；导出日志：`v0.5-final-export.log`。真实 UI 已查看持有 5/24 图标、无 Alt 悬停、四阶拾取卡与分类图鉴首尾（`tools/results/v05-*.png`），界面捕获 stderr 为空。最终 EXE 已以 OpenGL 实际运行 7 秒、420 tick、2 次击杀，正常退出且截图成功，stderr 为空；证据为 tools/results/v05-exported-game.png 及同名 .json/.log/.err，画面已目视检查。

网络测试使用本机独立进程与真实故障注入，尚未实测两台公网机器；合作需要直接 IP、局域网或可达公网，无 Steam 大厅、自动 NAT 穿透或房主迁移。上一版报告归档：`docs/BUILD_REPORT_v0.4.0.md`。
