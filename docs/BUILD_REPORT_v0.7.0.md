# SomeSide v0.7.0 构建验收

2026-10-04，Godot `4.7.2.stable.official.ed1daf0bf`。交付 `dist/v0.7.0/SomeSide.exe` 与 `dist/SomeSide-v0.7.0-windows-x64.zip`；旧版继续保留，上一版报告归档为 `docs/BUILD_REPORT_v0.6.0.md`。

本次重绘三关环境、两种角色装甲、九种普通敌人、三种首领和敌我弹道，并为每关接入各自敌群。新战法包括跳扑、吐弹、孢子落点、冲锋、钻地、晶体散射、锁定射线、闪现齐射与有限治疗。危险区在权威模拟中锁定、计时和命中，显示端使用相同几何；射线两端圆头与实际胶囊判定一致。原有平台碰撞布局、基础单跳、初始性能和奖励规则保持不变。

**13 套测试、634 项断言全部通过，最终检查无脚本或运行错误。** 分项：模拟 61、拾取 77、物品效果 56、奖励 20、敌人 69、地图/压力 45、探索 28、枪口 49、客户端反馈 9、角色外观 60、敌人渲染集成 12、特效 16、UI 132。完整回归记录在 `tools/results/v0.7-final-tests.log`；末尾修改后定向重跑敌人 69 项与渲染集成 12 项，分别记录于 `v0.7-final-enemies.log`、`v0.7-final-enemy-visuals.log`，汇总见 `v0.7-test-summary.json`。

新增验证覆盖九种敌人真实伤害与冷却、三关池和设施增援、飞行替补、走位躲避、射线预警固定原点、地刺对空中目标仍落在支撑面、治疗总预算、首领攻击轮换、眩晕/死亡/换关取消、快照隔离、24 个危险区上限，以及真实战斗下的粒子/数字/震动预算。地图可达性仍使用无道具、无冲刺的两种角色实际物理验证。

| 最终 EXE 网络验收 | tools/results 下证据 |
| --- | --- |
| 四人跨三关，全部敌人和预警同步 | network-export-biomes-20261004-230708/summary.json |
| 四人高级装备与复杂构筑同步 | network-export-20261004-230807/summary.json |
| 二人延迟/丢包，可靠结算送达 | network-export-impaired-20261004-230914/summary.json |

跨关测试的四端均观察到三张地图、九种普通敌人、三种首领样式、16 种蓄力攻击类型及圆形/直线危险区，客户端分别收到 949、929、947 份快照。高级装备测试中四端均观察到炮台、待触发陨击、时序增益与回旋/雷击/光矛投射物。受损网络每方向配置 50±10 ms 与 2% 丢包，实测平均延迟 55.085/54.438 ms，丢弃 9/12 个数据报；客户端收到 133 份快照，两端均进入 `lost/results`。所有最终网络进程退出码 0，运行错误数为 0。

最终 EXE 以 OpenGL 实际运行 7.0208 秒、421 tick、2 次击杀、57 次事件，正常退出并成功截图，stderr 为空。记录：`tools/results/v07-exported-game.png` 及同名 `.json/.log/.err`。

三关环境进行了 **294 个实际 OpenGL 镜头位置扫描**，覆盖全部平台两侧与地图边缘，绘制前后布局字节级一致，stderr 为空；证据为 `art-v07-sweep.log/.err`。以下画面均经实际目视检查，完整图册日志为 `art-v07-full.log/.err`，无绘制错误：

| 画面 | tools/results 下文件 |
| --- | --- |
| 三关完整场景与 HUD、本关三怪一首领、真实攻击事件 | v07-battle-1.png、v07-battle-2.png、v07-battle-3.png |
| 两角色左右空装/遗物造型，原生尺寸与 4× | v07-players.png |
| 九种普通怪与三种首领，原生尺寸及放大 | v07-enemies.png |
| 危险区预警/实际生效、射线圆头、敌我弹形 | v07-danger.png |
| 三关环境分层、地标与平台材质 | v07-environment-1.png、v07-environment-2.png、v07-environment-3.png |

图册由原生 Godot SubViewport 输出，战斗画面调用真实 main/HUD 和模拟攻击。复现环境遍历使用 `--script res://tools/art-capture-v07.gd -- --sweep`，完整图册使用同脚本的 `--full`。图册是受控场景验收，不代替长时间人工游玩与难度平衡测试。

| 产物 | 字节数 | SHA256 |
| --- | ---: | --- |
| EXE | 122700504 | 901C499F3D8CC59770E4C6303D103D33D60C2F10F7205B85753F64A0DDB6ED13 |
| ZIP | 51580779 | 9905C27346CC235E2B9FE2D889832BC7799035C6BFDDEBCD707160697AE51272 |

EXE 文件/产品版本均为 `0.7.0.0`。ZIP 只有 EXE、中文快速开始、Godot 与字体许可四个文件，包内 EXE 哈希与实际测试文件一致。机器记录：`tools/results/package.json`、`v0.7-package-verification.json`；导出日志：`v0.7-final-export.log`。

网络验证使用本机独立进程与真实 UDP 故障注入，尚未实测两台公网机器。合作仍需直接可达 IP 或局域网；没有自动 NAT 穿透、Steam 大厅或房主迁移。
