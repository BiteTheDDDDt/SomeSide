# SomeSide v0.14.0 操作、金币与声音更新

## 行为变化

- 普通与精英击杀金币立即给当前全队到账，保留 4/9 基础金额及首领固定 35 奖金；远处和倒地队友照常收到。丰收协议采用存活队员中的最高层数，最多翻倍，固定首领奖金不加成。金币不再占用地面物品预算；治疗吸取和遗物、武器、主动装备的手动选择不变。同步更新磁环/丰收协议的中英说明。
- Space、W、上方向键各自记录新的物理按下，可在另一键仍按住时发起新跳跃。保留短按低跳、长按高跳、羽翼空跳次数、A/D 后按优先、平台下落和失焦清理，不会因交替按键获得额外空跳。
- 两个角色的跑步循环由实际显示位移推进，完整步幅由约 127.4px 标定为 60px；相对瞄准方向后退时反转循环，停下时停止积累步幅，高移速不再卡在原先 2 倍动画速度上限。落地移动超过 4px 即回到跑步；身体与武器采样相同的插值位置，权威坐标与命中规则不变。
- 61 种原创分层 PCM 音效覆盖 8 主武器、8 主动装备、跳跃/空跳/落地/冲刺、命中/受伤/死亡、金币/治疗、4 稀有度拾取、设施、传送门、复活和 UI。主机发成功动作事件；预测主武器不会被权威副本重复播放，客户端移动重放不发音效。
- 12 声部，其中普通战斗最多使用 8 个，给重要反馈留出空间；按事件和事件族限频，金币连杀提示间隔至少 90ms。音库 1,049,210 bytes，加环境声 352,800 bytes，共约 1.34 MiB；本机单独首次合成约 0.7 秒，之后复用静态缓存，不在每次攻击时生成。

## 验证

- 30 套逻辑、输入、布局、渲染缓存和 Web 平台回归，共 **1520 项通过，0 失败**。最终音效 72、主路径音效 14、Web 运行时 33 项再次检查，无错误或警告。汇总：`tools/results/tests-v014-summary.json`。初次 runner 到尚未保存的音效测试时停止，保存后继续余下套件；最终音效测试已修正 headless dummy mixer 的退出警告。
- 模拟检查覆盖全队金币金额、重复死亡、Boss 奖金、地面物品满预算、连锁击杀、预测/快照幂等；跳跃覆盖两键顺序、落地后保留旧键、无羽翼/有羽翼限制。两角色三关无道具单跳可达性继续通过。
- 原生渲染录制：150 帧、60fps 的前进/后退对照，两名角色共四列。`tools/results/gait-v014/comparison.webm`，逐帧 PNG 与位移/相位记录同目录。上行为旧时钟相位参考，下行为新 World 显示路径。实际导出 EXE 演示运行 480 tick，截图 `tools/results/native-v014.png`，无运行时错误。
- Windows 导出成品：主机加 3 客户端，中英混合，高级武器/技能场景四端均通过，退出码均 0、运行时错误均 0。记录：`tools/results/network-export-bilingual-20261005-101323/summary.json`。
- Chrome 实际 Web 成品 14 项通过：跨域 iframe、手势音频、IndexedDB 偏好、全屏、真实单人输入、不同尺寸、模拟推进与 14 种角色缓存。Firefox 本地 HTTP 预览另测 9 项通过，包括实际单人、声音输出和资源响应。两浏览器都检测到运行中的 AudioContext 和非零输出信号，未报告运行时错误。记录：`tools/results/web-browser-v014/report.json`、`tools/results/web-preview-v014-firefox/report.json`。
- 最终 Web ZIP 11 个文件、根目录 index.html；相对资源路径、大小、WASM/PCK 文件头和 itch 限制检查通过，解压 62,056,734 bytes。记录：`tools/results/web-zip-v014-audit.json`。临时浏览器、预览服务器与验证进程均已关闭。

原有八帧中仍有相似腿部姿态，本次未编辑 PNG，尚不是精确脚掌锁地的骨骼/IK 动画。声音验证包括路由、样本的峰值/RMS/包络差异和实际输出，不代表经过人工听感混音。试听按顺序存于 `tools/results/audio-preview/weapons.wav`、`equipment.wav`、`feedback.wav`，对应时间轴与测量在同目录 report.json。

## 产物

- Windows：`dist/SomeSide-v0.14.0-windows-x64.zip`，60,160,399 bytes。
- Windows ZIP SHA256：`902E0A882ECF94471AB0D2C3D759D0ECACA385E3F0295FDC33F0F7211B0F8EDA`
- EXE：`dist/v0.14.0/SomeSide.exe`；SHA256：`7116580FDCAA261E651A942C9583AFCA499B5758390FB869076D9A07473E2CEE`
- Web：`dist/SomeSide-v0.14.0-web.zip`，32,344,031 bytes。
- Web ZIP SHA256：`15BC90BE498BF4DBB1147850018F850EDBD1B1B57ACE35A0FABC2E4EEE4F5F4C`

本地玩网页版用根目录 PlayWeb.cmd；itch 上传包直接使用上述 Web ZIP。旧版本产物继续保留，用户 cover.png 未纳入此提交。没有自动替换线上 itch 文件。上版记录：[v0.13.1](BUILD_REPORT_v0.13.1.md)。
