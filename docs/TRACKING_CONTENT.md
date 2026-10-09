# SomeSide 追踪内容实现（v0.23.0）

Baseline: fa47fff / v0.22.0. Existing IDs, numerical definitions, default guidance,
one-way platform collision and established art remain the compatibility boundary.

New files: tracking_rules.gd (opt-in modes, target legality, swept solid geometry,
personal-mark selection), tracking_art.gd (new silhouettes and damage/harmless
states), tests/test_tracking_content.gd and a real-scene capture tool.

Touchpoints: content/catalog append only; simulation host-only spawning, cleanup,
new-projectile sweep; main role validation, input viewport and three-role entry;
renderer dispatch, icons/weapon art, localized text, new synthesized sound voices.
Movement prediction never creates marks, blades or deployables. Snapshots use IDs
and value types only. Legacy guidance profiles have no `mode` and retain nearest
selection, acquisition-range flight checks and passed-target stopping.

Crystal moth safety: only solid_cover is opaque; platform tops remain one-way.
The floor is currently the production level's solid cover. Walls supplied by
future layouts use this explicit array; scenery and floating platforms are not
silently walls. Locks require visibility in a conservative 660×420 area around
the intended player AND that player's reported local viewport when supplied.
Flight leaving every living player's safe visible interior disperses harmlessly.
This intentionally sacrifices range rather than adding unseen danger. No retarget.

Crystal moth was admitted to the canyon pool only after the 94 initial content
checks and real four-player ENet tests (including delay, jitter and loss) passed.
The final content suite contains 107 checks; all 59 regression suites pass.

## 可玩入口与初始参数

| 内容 | 稳定 ID | 实际入口与区别 |
| --- | --- | --- |
| 弧针枪 | arc_needle | 精良武器；常规装备候选与奖励池，织轨者开局；7伤害/.20秒，1100速度，.7秒绝对寿命；12°窄锥、520范围，最多辅助.20秒/转12° |
| 寻星发射器 | star_seeker | 稀有武器；实际武器掉落、商店与奖励候选；38伤害/1.2秒，360速度；35°/650寻敌，直行.10秒后150°/秒持续转向，总寿命2.8秒，每拥有者最多3发 |
| 追猎信标 | hunting_beacon | 稀有主动装备；实际装备候选，织轨者开局；地面部署，3.6秒寿命/12秒冷却，.4/1.4/2.4秒各一次18基础伤害；每人1台、全队4台 |
| 织轨者 | weaver | 开局选人及合作大厅的第三独立职业，100生命；弧针枪/信标；Shift刻印，循迹被动，不继承游侠或先锋技能 |
| 巡猎晶蛾 | crystal_moth | 峡谷正式普通遭遇与对应战斗试炼；34基础生命、92移速，.65秒蓄力/4.3秒攻击间隔；一枚250速度/8基础伤害晶体，.22秒直行，3秒总寿命 |

刻印在600范围/40°锥内选择目标，个人标记持续4秒，8秒基础冷却。
三枚12基础伤害飞刃在.12/.22/.32秒生成；无目标不扣冷却。
施法不锁定移动/跳跃/普通开火，抬手只是视觉与释放节点。
技能飞刃、信标弹都不暴击、不递归触发遗物，合计预算分别36、54。
信标冻结部署时伤害；脉冲无目标或错过节点直接跳过，不蓄积补发。
飞刃取消不会退还已消耗冷却；死亡、凤凰恢复、断线、重开与换关清理新状态。

弱吸附和有限制导耗尽预算后沿切线直行，不掉头；持续追踪允许转向身后，
不因目标超出初始寻敌半径失锁，但不能重置寿命或自动改锁。
发射时按合法角度、距离、稳定ID排序；信标按距离选敌。
个人刻印只能优先自己的新武器/信标，仍受范围、锥角与遮挡约束。
旧追踪配置不含mode，其最近目标、范围失锁、错身停止与旧测试全部保留。

## 专用碰撞、视野与联机

新弹丸通过显式kind进入专用扫掠分支。实体遮挡按扩展矩形的首次接触
参数和身体扫掠比较，先到者挡弹；锁定目标不是唯一可命中的对象。
制导路径最多每1/120秒细分，角速度改变方向而不加速；20/60/120Hz
对照检查和一像素墙、沿途挡弹、平台底部检查已通过。
枪口第一段从原肩部扫到枪口，保留贴身敌人挡弹，显示从动画枪口开始。

主机维护每只晶蛾一枚、每玩家最多两份蓄力/飞行锁定额度。
蓄力目标死亡或消失立即取消，不能暗换队友。
晶蛾只在目标玩家实际报送视口与保守660×420区域的交集内锁定；
无视口信息仍使用更小的保守范围。实际可攻击距离因此常小于620。
晶体在任何存活玩家的安全可见内部之外无害碎解，不制作屏边危险箭头。
这一规则有意牺牲追击范围；不保证覆盖装饰背景中未声明的墙。

客户端仅同步稳定ID、值类型与已有预测，移动预测入口不能生成
刻印、飞刃、部署物或命中。新增快照spawn_cursor保留ID和随机状态；
旧快照缺少新增字段时可读取，旧ConfigFile职业偏好保持ranger/vanguard含义。
新状态不会保存Node引用，权威中按目标ID取已锁定对象，不在飞行中重新全场寻敌。

## 掉落与遭遇概率变化

旧43个物品定义、旧9种普通怪物定义逐行核对不变，旧图片未修改。
现有类别入口仍为88%被动、7%武器、5%主动装备；装备避开起始、
当前持有、地面、设施保留与近期重复的规则不变。
新增候选使用相应稀有度的原始权重，旧条目的分母仍按旧候选数量计算，
保证同一候选集合中旧条目相互的原始权重比例不变。
候选总权重增加后，旧条目的绝对概率降低；不能称为完全无影响。

第一关单人游侠、无地面装备/设施/历史、排除四件初始装备的实际候选示例：

| 候选池 / 来源 | 弧针枪 | 寻星 | 信标 | 旧条目概率相对旧池的倍数 |
| --- | ---: | ---: | ---: | ---: |
| 武器 / ambient | 25.00% | 7.69% | — | .6731 |
| 主动装备 / ambient | — | — | 7.08% | .9292 |
| 混合装备 / equipment | 13.40% | 5.63% | 5.63% | .7535 |
| 武器 / boss | 12.89% | 16.02% | — | .7109 |

这些是进入该候选池之后的条件概率，不是所有击杀的全局掉率。
例如ambient武器选择本身仍只占7%；还需要先触发原有掉落规则。
织轨者开局已经持有弧针枪/信标，这两件会被候选排除。
后续关卡、候选排除、近期历史与奖励类型都会改变实际概率。
复现命令与完整9组计算见check-tracking-balance-v0230.gd及交付证据JSON。

峡谷常规地面探索导演给晶蛾12%的分支；旧三种在剩余88%中仍保持
52:23:25比例，即冲锋兽45.76%、潜伏者20.24%、原晶翼巡猎者22%。
导演原有强制飞行回退仍使用drone，因此以上不是所有生成路径的总占比。
峡谷战斗试炼均匀池由3种扩为4种，旧每种1/3变为1/4，新晶蛾1/4。
雨林与遗迹的普通怪物池未变。

## 美术、音效与成本

旧背景、旧插画、旧特效原画保留。织轨者使用一张内置image_gen生成的
1536×1024透明RGBA图集，7个真正的关键姿态；原文件不修像素，
运行时校准分区、脚底与身体锚点，复用现有24姿态步态/跳跃衔接。
完整提示词和生成方式在assets/art/tracking-v0230/provenance.json。
晶蛾、信标、两把武器与新弹体使用项目原生几何/SVG及现有缓存流程。
轻针、带翼寻星弹、弯刃、信标镖和敌方菱晶由轮廓区分，不只换颜色。
蓄力为空心红色短虚线与目标括号；伤害为实体弹体；命中是几何碎片，
超时/屏外消散为离散短划，不残留完整危险轮廓。不画未来预测路线。
新武器及技能/信标/晶蛾有独立合成声音，沿用现有音频生命周期。

图集无mipmap，RGBA显存估算6MiB；一份纹理与最多7份AtlasTexture复用。
新武器缓存增加两把，原武器纹理总缓存仍限制13项/2.6MiB以内。
每弹尾迹最多10点、长度最多约100单位；全局弹丸280上限保留。
信标与旧炮台共用设备数组但额度分离：旧4炮台不挤掉新4信标，
总设备最多8；死亡/断线/换关的无主输出检查通过。

## 验证的实际范围

59套/6610项回归通过，追踪专属107项，旧制导54项。
真实ENet主机加3客户端，中英不同语言，正常网络及50ms每向延迟、
±10ms抖动、2%配置丢包均已运行；两名织轨者个人标记与四台信标隔离。
原生正常镜头三阶段截图与6秒织轨者运动影片来自真实模拟/世界绘制。
Chrome跨源iframe与所有五种新弹体、选角、Web音频/存档均实际运行。
自动化平衡探针另含20种武器工况、12种职业压力/首领工况。
真人长局平衡、公网异机合作、Firefox/Safari与低配置帧率尚待验证。
报告明确记录织轨者无道具首领工况的生存风险，不据此声称已完成平衡。
