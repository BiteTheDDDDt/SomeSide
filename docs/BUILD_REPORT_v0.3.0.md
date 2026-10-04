# SomeSide v0.3.0 构建验收

2026-10-04，使用项目内 Godot `4.7.2.stable.official.ed1daf0bf` 与官方 SHA512 校验过的 Windows 导出模板。新版为 `dist/v0.3.0/SomeSide.exe`；发布包为 `dist/SomeSide-v0.3.0-windows-x64.zip`，只含 EXE、中文快速开始和两份许可。旧版产物保留，v0.2 报告归档为 `docs/BUILD_REPORT_v0.2.0.md`。

**283 项断言全部通过**：模拟 53、掉落装备 77、压力与地图 27、探索调度 26、UI 100。记录：`tools/results/v0.3-final-tests.log`。降速后两角色三关仍可无道具、无冲刺到达全部平台，并通过起跳/落点余量与 ±12px 起跳容差；新测试验证静止、小巡、原地跳跃与旧路回访不持续刷怪、停留暂停难度、重新探索无积累爆发、闲置远队友不被选为刷怪点，门和主动试炼正常。UI 验证 Alt 收放、实际可见文本行和高度、风险始终可见及精简槽位面积。

| 最终网络验收 | 结果与证据 |
| --- | --- |
| 源码一房主三客户端，真实结算 | 通过；`tools/results/network-20261004-163116/summary.json` |
| EXE 一房主三客户端，游玩中正常退出 | 通过；`tools/results/network-export-20261004-163206/summary.json` |
| EXE 一房主一客户端，延迟/丢包与结算送达 | 通过；`tools/results/network-export-impaired-20261004-163206/summary.json` |

受损网络使用真实 UDP 代理：每方向 50 ± 10 ms、2% 丢包；实测平均延迟 56.29 / 55.39 ms，丢弃 8 / 10 个数据报，两端进入相同结果界面。全部最终 EXE 测试退出码 0，所有 stderr 0 字节。快照沿用压缩与 950 字节分包，最终结算可靠发送。构建日志：`tools/results/v0.3-final-export.log`。

OpenGL 画面已实际检查，截图见 `tools/results/v03-collapsed.png`、`v03-inspect.png`、`v03-loot.png`、`v03-guide.png`。测试为本机独立进程和真实 UDP 故障注入，尚未实测两台公网机器；合作使用 IP/局域网或可达公网地址，无 Steam 大厅、自动 NAT 穿透或房主迁移。

最终 EXE 另经真实 OpenGL 游玩演示 7 秒、420 tick、2 次击杀并正常退出，stderr 0 字节；已查看截图 `tools/results/v03-release-gameplay.png`，日志 `v03-release.log` / `v03-release.err` 同目录。

| 文件 | 字节数 | SHA256 |
| --- | ---: | --- |
| EXE | 122583184 | 59FB87602A77B487322E53C14CE6B45BC8F0F3B4142EFC7D10AE53A6666273F0 |
| ZIP | 52646870 | 9B40946D139F64DD9C06CDA31C0717C0592956FEACF208C1D12282ABBB058A26 |

机器可读发布记录：`tools/results/package.json`。
