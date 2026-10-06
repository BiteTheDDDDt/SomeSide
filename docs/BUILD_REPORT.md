# SomeSide v0.20.2 构建记录

日期：2026-10-06。引擎：Godot 4.7.2，GDScript，Compatibility 渲染。

## 本次变化

上一版把辅助线换成了大面积通用烟雾，但前摇与生效仍像同一种效果，材质也与实际攻击脱节。本版重新建立准备、伤害与结束的区别。

- 地刺：低矮裂石准备，生效时刺出实体岩峰。潜地：小土块扰动，生效时破土。贴图底部按实际支撑面定位。
- 孢子：18–26像素闭合囊体准备，生效时切为完整酸液爆裂。专门二次编辑去除地基，锁定空中玩家时不会出现悬空土块，也不擅自把模拟位置移到地面。
- 激光：前摇初段仅在发射器内蓄能，末段向固定方向伸出24–64像素短能量舌；生效时才出现完整亮束，整个伤害窗保持完整宽度和不透明度。没有全长瞄准预览。
- 冲锋与扑击：移除未来路线上的烟尘带，用身体压低、后撤蓄势和脚下土屑准备。孢子／晶体蓄弹与真正发射的弹体使用相同材质，发射位置一致。裂隙为窄紫色，修复为小型薄荷绿碎片，与有伤害的珊瑚色弹体区分。
- 危险表现直接由权威 hazard.active 选择。生效结束就移除，不额外生成滞留烟团、冲击圆环或定点假弹体。事件收尾只保留短小裂隙与修复反馈。
- 两张新活跃图集 `assets/fx/v0202/terrain-v2.png`、`energy.png` 提供12类48帧像素素材。加上原玩家效果，共18类96帧，按源文件共享8张纹理、32 MiB。旧烟雾图集与未采用的初版terrain仅保留来源记录，排除导出。内置imagegen生成和二次编辑的完整提示词见 [素材记录](../assets/fx/v0202/ART_PROMPTS.md)。

没有修改 simulation.gd、content.gd 或攻击数值。截图与测试中，锁定、伤害窗口及客户端只读行为保持原规则。

## 视觉与行为验收

- `tools/capture-attack-phases-v0202.gd` 通过真实AI分别采集早期准备、晚期准备、伤害生效；以真正hazard.active决定阶段，避免用怪物自己的前摇计时替代伤害边界。共16张普通/低特效对照，每格960×540、1倍比例，包含额外空中孢子场景。保存于 `tools/results/attack-phases-v0202/`。
- 12秒 `attack-phases-preview.webm`：激光、地刺、孢子、破土各3秒，1280×720、30fps、360帧。使用真实模拟与事件历史，未制造伤害或放大局部来代替正式画面。
- 自然预警123项、攻击阶段98项、图集129项通过，覆盖低特效、暂停采样、锁定与躲避、空中位置、源端与弹体材料、伤害期间完整表现、相同快照只读和纹理共享。
- 完整回归50套、2905项通过，0失败、0运行错误、0警告。日志 `tools/results/tests-v0202.log`，汇总 `tests-v0202-summary.json`。

## 导出与联机验收

- Windows和Web独立导出成功，日志无运行错误或警告。Windows程序运行480tick、86事件、4击杀，正常截图并以0退出；18类效果从8张发布纹理加载。`tools/results/export-v0202-report.json`、`export-v0202-game.png`。
- 四人真实ENet跨三关，房主英文/客户端中文，覆盖9种普通敌人、3种首领、16种起手与两种危险区形状；三客户端分别收到943/951/950次快照，全进程正常退出、零运行错误。`tools/results/network-export-biomes-bilingual-20261006-193227/summary.json`。此次为同机联机，没有重跑网络丢包模拟。
- Chrome154 Web验收15/15通过，跨源iframe、两种窗口尺寸、全屏、实际音频输出、语言/FPS偏好持久化、18类素材加载均正常，模拟540tick，浏览器/网络/Godot错误为0。`tools/results/web-v0202-chrome/report.json`。测试iframe的allow/allowfullscreen优先级提示不影响功能。
- 本轮单次末尾读数：Windows/RTX5070Ti为73FPS，Chrome/AMD610M/ANGLE为27FPS，Web冷启动5.20秒。没有持续帧率或严格前后性能基准；这些读数不代表帧率保证。
- Web ZIP离线审计通过，入口、资源和许可齐全，无缺失引用。`tools/results/web-v0202-artifacts.json`。
- 本机用户profile前后SHA-256一致：`D5DE413B5920A75F031E6C509F598D7B09CCC9ADEF40AC2A14DB1A8E12A726F0`。

## 发布文件

| 文件 | 字节 | SHA-256 |
| --- | ---: | --- |
| `dist/SomeSide-v0.20.2-windows-x64.zip` | 68264716 | `89895710ED5C8E3892AB39858CEC49DA299EB3815AC98E5F97D7EAD4905216FE` |
| `dist/v0.20.2/SomeSide.exe` | 138321184 | `CA71B67D0E0B0D3AD506817B02403165B35C9D6189759A4E3861D06388273FFC` |
| `dist/SomeSide-v0.20.2-web.zip` | 39416849 | `92ACDCD41269F3449DE0702933AF92489F053C540E9D8481DE82EA7AEE014632` |

清单：`tools/results/package-v0202-windows.json`、`package-v0202-web.json`。Windows支持2–4人合作，Web仍为单人。本轮生成本地包，未替换itch线上文件。

证据和发布产物按既有规则保存在本机忽略目录。旧版本与宣传图保留。上版记录：[v0.20.1](BUILD_REPORT_v0.20.1.md)。
