# SomeSide v0.6.0 构建验收

2026-10-04，Godot `4.7.2.stable.official.ed1daf0bf`。交付 `dist/v0.6.0/SomeSide.exe` 与 `dist/SomeSide-v0.6.0-windows-x64.zip`，旧版产物保留；上一版报告归档为 `docs/BUILD_REPORT_v0.5.0.md`。

**11 套测试、553 项断言全部通过，零脚本或运行错误。** 分项：模拟 61、拾取 77、物品效果 56、奖励 20、地图/压力 45、探索 28、枪口 49、客户端反馈 9、角色外观/渲染 60、特效 16、UI 132。证据：`tools/results/v0.6-final-tests.log`、`v0.6-test-summary.json`。新增覆盖八武器多方向真实发射与近距命中、预测与权威反馈一致、远端插值期间闪光跟随枪口、换装后旧闪光失效、首帧尾迹不越过枪口，以及 24 遗物六部位选择、百万叠层封顶和输入快照只读。

| 最终 EXE 网络验收 | tools/results 下证据 |
| --- | --- |
| 四人高级装备，四进程正常退出 | network-export-20261004-224052/summary.json |
| 二人延迟/丢包，可靠结算送达 | network-export-impaired-20261004-224159/summary.json |

四端均观察到炮台、待触发陨击、时序增益与回旋/雷击/光矛投射物；三个客户端分别收到 708、614、625 份快照。受损网络每方向配置 50±10 ms 与 2% 丢包，实测平均延迟 56.04/54.755 ms，丢弃 7/14 个数据报；客户端收到 129 份快照，两端均进入 `lost/results`。所有最终网络进程退出码 0，stderr 无脚本或运行错误。

最终 EXE 已以 OpenGL 实际运行 7.0056 秒、420 tick、3 次击杀、61 次事件，正常退出且截图成功；`tools/results/v06-exported-game.png` 及同名 `.json/.log/.err` 留存证据，stderr 为空。该游戏画面与三张最终画册 `v06-weapons.png`、`v06-appearance.png`、`v06-muzzles.png` 均经实际目视检查：八武器模型可辨，左右及八向枪口衔接正确，24 种饰件在 1×/4× 图示与高叠层下保持可读且不越界。

| 产物 | 字节数 | SHA256 |
| --- | ---: | --- |
| EXE | 122660720 | BA5F5C81A5B839ABDE15C232B630D851F24917C2848918E3B550E75D912C25A9 |
| ZIP | 51542356 | 62F4C4B68F7329DAC98F055F8583889A1378139EC2F597AE834D0022E68D0364 |

EXE 文件/产品版本均为 `0.6.0.0`。ZIP 只有 EXE、中文快速开始、Godot 与字体许可四个文件，包内 EXE 哈希与实际测试文件一致。机器记录：`tools/results/package.json`、`v0.6-package-verification.json`；导出日志：`v0.6-final-export.log`。

网络验证使用本机独立进程与真实 UDP 故障注入，尚未实测两台公网机器。合作仍需直接可达 IP 或局域网；没有自动 NAT 穿透、Steam 大厅或房主迁移。
