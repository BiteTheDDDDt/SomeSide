# SomeSide v0.8.0 构建验收

2026-10-04，Godot `4.7.2.stable.official.ed1daf0bf`。交付 `dist/v0.8.0/SomeSide.exe` 和 `dist/SomeSide-v0.8.0-windows-x64.zip`。旧版保留，上一版报告归档为 `docs/BUILD_REPORT_v0.7.0.md`。

本版加入完整简体中文/英文显示。首次启动按系统 locale 选择：zh 及其区域变体使用中文，其余默认英文；有效的已保存偏好优先，主菜单和暂停菜单均可即时切换。语言仅影响本地显示，合作玩家可分别选择。364 条精确翻译覆盖菜单、指南、40 件物品的名字/说明/代价、设施交互、地图地标、敌人与首领名和通知。模板先翻译再填参数，玩家昵称和权威状态不做文本替换。

金币从小号阶段信息中分离，改为独立金色币图标、24px 数值和轻微变化反馈；完整余额随宽度调整，不用缩写隐藏数值，保留鼠标穿透。英文页面按文字长度调整了指南、设置和选角布局。

**14 套测试合计 858 项断言通过。** 原有 13 套共 634 项：模拟 61、拾取 77、物品效果 56、奖励 20、敌人 69、地图/压力 45、探索 28、枪口 49、客户端反馈 9、外观 60、敌人渲染 12、特效 16、中文 UI 132。新增本地化 224 项。汇总见 `tools/results/v0.8-test-summary.json`。原有回归记录为 `v0.8-full-tests.log`；该首次完整执行在新增语言测试发现设置标题漏译，修复后的最终定向结果为 `v08-localization.log/.err`（224/224）及 `v08-ui.log/.err`（132/132），两份最终 stderr 均为空。

本地化验证覆盖系统语言/旧存档回退/保存选择优先、全部物品数字和风险完整、设施价格/ID/可用性一致、真实主机通知同一事件两语显示、翻译键同名昵称原样保留、切语言时整个模拟状态不变、用户 profile 字节不变。真实收集金币与购买扣费均反映到余额；余额测试包括 9876543210，文字完整且字号保持 24px。英文菜单、设置、加入、四人大厅、指南、全部图鉴、地面物品、地图、暂停、结算均检查无漏译及文字越界；增加了返回按钮与版本文字不相交的回归。

| 最终 EXE 网络验收 | tools/results 下证据 |
| --- | --- |
| 英文主机 + 三个中文客户端，跨三关 | network-export-biomes-bilingual-20261004-233549/summary.json |
| 英文主机 + 中文客户端，延迟/丢包及可靠结算 | network-export-impaired-bilingual-20261004-233724/summary.json |

四人测试逐端验证实际 language 字段，全部看到三关、九种普通敌人、三种首领样式和 16 种蓄力攻击；客户端收到 949、930、848 份快照，全部正常退出、无运行错误。二人测试使用每方向 50±10 ms 延迟及 2% 丢包的真实 UDP 代理，两端均进入结果页，保留各自语言并正常退出。

最终 EXE 分别以英文和中文实际 OpenGL 运行约 7 秒、420 tick 并截图，退出码均为 0，stderr 为空；英文临时覆盖时报告的 profile_language 仍是 zh。证据：`tools/results/v08-exported-en` 与 `v08-exported-zh` 的 `.png/.json/.log/.err`。

16 张 1280×720 原生 OpenGL 受控截图均经目视检查：`v08-en-menu/characters/settings/lobby/guide/game/inventory/catalogue-passive/catalogue-weapon/catalogue-equipment/map/pause/settings-in-run.png`，以及 `v08-zh-game/coins-large/settings.png`。图册入口为 `tools/capture-v08.gd`，记录在 `tools/results/v08-capture.log/.err`；最终错误日志为空、profile 未修改。英文设置标题和选角页版本文字重叠均已修正并重拍确认。

| 产物 | 字节数 | SHA256 |
| --- | ---: | --- |
| EXE | 122729832 | A57709E4A46531596B98A6B29662BC9CBC564C1B873D1286E839C77F6EC2E6D4 |
| ZIP | 51610620 | 50B80AE70CD498A9F2ADE99F107AD2FCA88C6B0A44A4EEBEC5555487AD115671 |

EXE 文件/产品版本均为 `0.8.0.0`。ZIP 仅含 EXE、中英快速开始、Godot 与字体许可四个文件；包内 EXE SHA256 与被测试文件一致。记录为 `tools/results/package.json`、`v0.8-package-verification.json`、`v0.8-final-export.log`。

网络验证使用本机独立进程和 UDP 故障注入，尚未实测两台公网机器。中文界面为简体中文，其他中文系统区域初始也使用这一套文本；当前提供的显示语言仅为中文与英文。
