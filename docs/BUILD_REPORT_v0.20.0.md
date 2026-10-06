# SomeSide v0.20.0 构建记录

日期：2026-10-06。引擎：Godot 4.7.2，GDScript，Compatibility 渲染。

## 本次变化

- 敌人的蓄能、光束、范围爆发、弹丸及闪现/扑击/治疗准备接入透明多帧贴图；细边界保留实际危险范围。新增六组八帧共48帧素材，固定裁剪与锚点，运行时六张1024²纹理约24 MiB、硬预算32 MiB。内置 image_gen 的源文件和完整提示词见 `assets/fx/v020/ART_PROMPTS.md`；早期布局保留在源码中但排除出发布包。
- 三件条件遗物：蜂群弹舱由直接暴击触发有限追踪弹；落震线圈由至少90高度落地触发双向波；霜环发生器由直接击杀触发1.5秒随身减速伤害场。当前共27遗物、8武器、8主动装备。
- 每个职业一个Shift主动和一个自动被动。游侠连续6次不同主武器动作命中后追加8伤害追击弹，相邻有效命中超过2秒重置，冷却3秒；先锋累计实际失去30生命后获得独立10护盾，持续3秒、冷却6秒。两者冷却期间不累积，换装不刷新。
- 派生攻击禁止暴击与递归触发，落地波一组最多8敌且每敌一次；死亡、凤凰、切关、射击过程中新增弹丸和客户端预测均有独立边界。霜环与霜凝结晶保留当前更强的减速，弱效果不会覆盖强效果。
- 新物品有图标、角色饰件和独立合成触发音效。选角、构筑和Shift悬停显示主动/被动完整双语说明；已持有27遗物保持两行，临时盾并入原护盾读数，没有增加常驻技能槽。

## 原生画面与真实触发

- `tools/capture-enemy-fx-v020.gd`：真实哨卫蓄能和释放、棱镜交叉光束、普通敌人准备动作；1x画面、阶段图和48帧图册保存在 `tools/results/enemy-attacks-v020/`。
- `tools/capture-proc-combat-v020.gd`：五场各180个60Hz模拟步，由真实输入、攻击和伤害触发；没有直接造派生实体或事件。`tools/results/proc-combat-v020/report.json` 全部通过。暴击飞弹总伤42、落地波每侧12、霜环3次各8、游侠6次攻击后总伤56、先锋失血30后护盾再吸收8剩2。PNG、30fps短片、逐tick记录及合并15秒 `proc-preview.webm` 均保留。
- `tools/capture-class-passives-v020.gd`：21张中英角色、指南、构筑、悬停和遗物截图；`tools/results/class-passives-v020/`。43件实体图册见 `tools/results/icon-art-v020/`。逐项检查没有说明溢出，金币与角色保持可见。

## 验证与产物

最终自动检查、独立导出、浏览器和网络结果见下方完成记录。测试与截图保存在本机 `tools/results/`，发布文件位于 `dist/`，这两个目录按原规则不纳入 Git。

上版记录：[v0.19.0](BUILD_REPORT_v0.19.0.md)。
### 完成记录

- 完整回归49套、2642项通过，0失败、0运行错误、0警告。原始日志 `tools/results/tests-v020.log`，逐套汇总 `tools/results/tests-v020-summary.json`。
- 四人120模拟秒压力回归：44敌堆积时最多49弹，12层全遗物构筑最多30弹、34事件；当前机debug最慢步2.213/2.569ms。这是模拟步耗时，不是帧率保证。触发音效共71个样本，PCM约1.11 MiB，保持既有声音总量限制。
- 独立Windows程序运行480tick、39事件、2击杀，正常截图并以0退出；六组特效纹理全部从导出资源加载。`tools/results/export-v020-report.json`，原生日志无错误。
- 导出程序四人高级联机、房主英文/客户端中文通过；三客户端分别收到612/712/714次快照，全部观察到追击弹、落地波、霜环，以及炮台、延迟技能、时序与导引。全部进程零错误并加载六组特效。`tools/results/network-export-bilingual-20261006-181459/summary.json`。本轮为同机真实ENet连接，没有重跑丢包模拟。
- Chrome154 Web验收15/15通过，540tick，新六组贴图24MiB、跨源iframe、960×540/1920×1080适配、全屏、实际Web Audio输出、语言/FPS偏好保存均正常，浏览器/网络/Godot错误为0。冷启动5.53秒。AMD610M/ANGLE下末次FPS读数27，与上版记录一致；本轮未做持续帧率基准。`tools/results/web-v020-chrome/report.json`。
- Web ZIP离线审计通过，入口和资源齐全。`tools/results/web-v020-artifacts.json`。本机profile前后SHA-256相同（FCFC06500030549CF81BC94C90B13F6FE7B326C6030D404F2250F414D070ACFA）。

| 文件 | 字节 | SHA-256 |
| --- | ---: | --- |
| `dist/SomeSide-v0.20.0-windows-x64.zip` | 67028151 | `1B9712930D9D776900079DA44303D55F01E102C25E64C5F3A9FBAAD53E3F96E6` |
| `dist/v0.20.0/SomeSide.exe` | 137069440 | `E82CAC64593297FDCC16B737BF60BA82D49A13CC63D013EE12204B18C29C9114` |
| `dist/SomeSide-v0.20.0-web.zip` | 38181569 | `717D01BC756B716339D8833BD1054EC2351D5869DD1C77E224577F60B9CFC3D6` |

清单：`tools/results/package-v020-windows.json`、`package-v020-web.json`。旧版本与宣传素材保留。已生成本地上传包，没有上传或替换itch线上文件。