# SomeSide v0.13.0 构建与验收

Godot 4.7.2 stable official `ed1daf0bf`。新增 itch.io HTML5 网页单人版，同时生成 Windows 单人 / 2–4 人合作包。旧记录见 [BUILD_REPORT_v0.12.0.md](BUILD_REPORT_v0.12.0.md)。

## 网页运行

- WebAssembly + WebGL 2 / Compatibility，使用官方单线程模板，不需要跨源隔离响应头或 PWA。安装脚本提取 Web 模板前校验官方 SHA512。
- 中英加载进度、启动失败提示、重试与 Windows 下载链接。部分 WASM 下载错误未进入引擎 `startGame` 的拒绝回调，现增加仅加载期间有效的异常监听；后续进度不会覆盖错误提示。
- 游戏初始语言跟随浏览器，后续优先使用保存设置；IndexedDB 保存语言、音量、FPS 等偏好。浏览器明确报告无法持久化时，设置页会提示。
- 完整 PCM WAV 音频首次游戏内按键或点击后启用；全屏由实际输入触发，不在刷新时自动恢复。失焦暂停单人游戏并清除按键。
- 网页版不使用当前 UDP/ENet 合作，菜单明确提供单人入口与 Windows 下载。未部署 WebSocket/WebRTC 服务。保留两名角色、三关、40 件物品、九种普通敌人、三名首领及 v0.12 的 128 姿态素材。

## 绘制与性能

网页远景使用带留白的纹理缓存，连续平移并在换缓存时以 0.22 秒淡入；大跨度镜头跳转在新缓存就绪前回退到完整绘制。平台植被保留在缓存内，省去细小风摆的逐帧曲线重建。角色、战斗、粒子、输入、碰撞和模拟未降频，原生版继续原绘制路径。

1280×720 下单背景 6,995,968 bytes；过渡最多两个，共 13,991,936 bytes，上限 16 MiB。地形原有 48 MiB / 40 项上限保持。精灵为 14 actors / 6 sheets，源纹理约 36 MiB、逻辑帧约 2.9 MiB。

同机 Chrome / AMD Radeon 610M / D3D11 短时演示：缓存前末段约 20 FPS、1052 次绘制，首次缓存候选约 28 FPS、578 次绘制。最终 Chrome / Edge 演示末段分别为 28 / 31 FPS。这些是短跑观察，不是固定场景统计或稳定帧率保证；Web 性能仍可能低于原生，复杂战斗可能下降。证据：`tools/results/web-profile/report.json`、`web-cached/report.json`、两份最终浏览器报告。

## 验证

- 完整 **26 套 / 1325 项通过 / 0 失败 / 0 运行时错误 / 0 警告**。新增 Web 适配 33 项、背景缓存 24 项，覆盖平台入口、输入、音频等待、连续移动、淡入、瞬移边界、预算、场景清理、快照只读和原生路径。证据：`tools/results/test-v0.13.0-final.log`、`test-v0.13.0-final-summary.json`。
- 最终构建：Chrome 154.0.8037.93 在不同站点来源的 iframe 内运行，无 COOP/COEP。14 项自动检查通过，并目视复核实际键鼠战斗、背包、地图、失焦暂停、中英菜单，以及 960×540 / 1280×720 / 1920×1080 布局。全屏、刷新后的语言和 FPS 保存通过；AudioContext 运行且数字输出信号非零。无浏览器/网络/Godot 运行时错误。证据：`tools/results/web-chrome-final/report.json` 及截图。
- 最终构建：Edge 154.0.4258.53 实战演示 542 tick，中文系统语言识别、14 个像素角色加载、运行时检查通过。证据：`tools/results/web-edge-final/report.json`。
- 中英两语言分别注入 WASM 404、JS 404、WebGL 不支持：**6 场景 / 44 项通过**。WASM 失败约 3.6 秒后显示重试及下载链接；重复重试仍可恢复提示，无未捕获异常。证据：`tools/results/web-loader-v013-fixed/report.json`。
- 最终 Windows EXE：英文主机 + 三个中文客户端真实本机 ENet，四端 `passed=true`、退出 0。证据：`tools/results/network-export-bilingual-20261005-031749/summary.json`。
- Web ZIP 根目录为 `index.html`，11 文件，解压总计 62,040,747 bytes，最大单文件 WASM 39,514,754 bytes。相对依赖、大小、文件头及 itch 限制检查通过；包内哈希与导出一致。`dist/.gdignore` 防止重复导入输出图标，包内无 PNG 导入旁文件。证据：`tools/results/web-zip-audit.json`、`package-v013-verification.json`。

浏览器使用全新独立 profile 和临时本机服务器；测试进程已关闭。未测试 Safari、手机触屏或公共互联网多人连接，未上传或修改 itch 页面。存储受浏览器隐私设置影响，不承诺跨设备同步。

## 发布产物

| 文件 | 大小 |
| --- | ---: |
| `dist/SomeSide-v0.13.0-web.zip` | 32,328,862 bytes |
| `dist/SomeSide-v0.13.0-windows-x64.zip` | 60,145,720 bytes |
| `dist/v0.13.0/SomeSide.exe` | 131,335,784 bytes |

Web ZIP SHA256：`A04A607788B9334341F7FCE967557E20C40296A37C443CBA9544287AD7E601A6`

Windows ZIP SHA256：`ABA0B60FDCAF560D270F537E450D7093700ABBD6016EABA5429FFDA14F2743DD`

EXE SHA256：`CFC5C5B9E211574F3CB8F893FD095510D72BEA1BD81F385E52CE877DBF268FE8`

两包保留 Godot 与字体许可，旧发行包保留。源码、测试与工具纳入 Git，运行时下载、证据和产物留在本地。用户 `cover.png` 及导入文件未修改、未纳入提交。

上传步骤及双语页面说明见 [ITCH_WEB.zh-CN.md](ITCH_WEB.zh-CN.md)。依据：[itch.io HTML5 上传说明](https://itch.io/docs/creators/html5)、[Godot Web 导出说明](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)。
