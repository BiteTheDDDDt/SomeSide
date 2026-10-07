# SomeSide 网页版上传 / Web upload

目标页面：[SomeSide by BiteTheDDDDt](https://bitetheddddt.itch.io/someside)。本说明面向 v0.20.7 网页单人模式；Windows 下载版继续提供单人和 2–4 人合作。

Target: update the existing SomeSide page. This first Web build is single-player; keep the Windows download for solo play and 2–4 player co-op.

## 本地预览 / Local preview

双击项目根目录 `PlayWeb.cmd`，通过自动打开的 `http://127.0.0.1:8765/` 游玩；保持预览窗口打开，Ctrl+C 停止。直接双击 HTML 的 `file://` 地址不能加载游戏的 WASM 和资源文件，不代表浏览器不支持 WebGL。

For local testing, run `PlayWeb.cmd` (Python 3 required), keep its console open and play through the HTTP address. Do not open `index.html` via `file://`. itch.io serves uploaded games through HTTPS; its players need no local server.

## 上传设置 / Upload settings

1. 在已有项目的编辑页，将 **Kind** 设为 **HTML Game**。不需要另建页面。
2. 上传 `dist/SomeSide-v0.20.7-web.zip`，将这个 Web ZIP 标为 **This file will be played in the browser**。另将 `SomeSide-v0.20.7-windows-x64.zip` 保持为可下载文件并标为 Windows。
3. Web ZIP 的根目录必须直接包含 `index.html`，以及同次导出的所有配套文件，例如 `index.js`、`index.wasm`、`index.pck`。不要再包一层文件夹，不要只上传 HTML，也不要改动导出文件名。
4. 在 **Embed options** 中优先选择 **Click to launch in fullscreen**，玩家点击后直接展开游玩，无须填写固定尺寸。若希望留在页面内，选择 **Embed in page**、设为 **1280 × 720**、保留 **Click to Play** 并启用 **Fullscreen Button**；不要保留640 × 360的小窗口。使用桌面键盘和鼠标；本版没有触屏操作，不标记 **Mobile Friendly**。
5. 等 itch.io 处理完 ZIP，在预览中点击开始，检查载入、声音、瞄准和全屏，再保存页面更改。这份说明不代表已经上传或发布。

Edit the existing project, choose HTML Game, upload the Web ZIP and mark it browser-playable. Keep the Windows ZIP as a separate Windows download. Place `index.html` and all companion export files at the ZIP root. Prefer **Click to launch in fullscreen** under **Embed options**. For inline play, use a 1280 × 720 embed with click-to-start and the fullscreen button enabled. Target desktop keyboard and mouse. Preview before saving. This document does not indicate that an upload has occurred. [itch.io upload reference](https://itch.io/docs/creators/html5)

嵌入尺寸由itch项目页控制；Godot的1280 × 720设计尺寸不会自动修改网站的iframe。当前画布已配置为跟随容器尺寸，960 × 540和1920 × 1080均经过浏览器验收。因此只调整以上网页设置，不需要重新打包上传。浏览器F11可能只放大浏览器外壳，应使用itch的全屏入口或游戏设置里的“切换全屏”。

## 页面说明建议 / Suggested page copy

> **浏览器版：** 单人游戏，建议桌面键盘鼠标并开启全屏。在 itch.io 点击开始加载；进入游戏后首次点击或按键启用声音。需要 2–4 人合作，请下载 Windows 版；合作通过局域网或可达的房主 IP 连接。

> **Browser version:** Single-player. Desktop keyboard and mouse recommended; use fullscreen for the best view. Click Play on itch.io to load; click or press a key inside the game to enable audio. For 2–4 player co-op, download the Windows version and connect over a LAN or to a reachable host IP.

浏览器不能直接使用当前 Windows 版的 ENet / UDP 联机方式，因此网页单人模式不提供 Windows 房间加入功能。网页导出需要 WebAssembly 和 WebGL 2.0；声音和全屏由玩家点击触发。相关平台限制见 [Godot Web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)。

The browser build cannot join the Windows build's current ENet/UDP rooms. It requires WebAssembly and WebGL 2.0; player interaction enables audio and fullscreen. [Godot Web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)

本包带有加载页，采用单线程 Compatibility 导出；按普通 HTML 游戏上传即可，无需另设跨源隔离请求头或 PWA。

The package includes a loading page and uses single-threaded Compatibility export. No additional cross-origin isolation headers or PWA setup are needed. [Godot export options](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html#thread-and-extension-support)

## 本次核对 / Page snapshot checked

2026-10-05通过浏览器只读检查公开页面：已有 **Run game** 网页入口和 `SomeSide-v0.17.0-windows-x64.zip` 下载。点击后，外层游戏容器与iframe实测均为 **640 × 360 CSS像素**，页面内容列宽960；iframe已允许全屏。公开页正文仍以Windows版本描述可用平台，建议按上方双语文案补充网页单人模式。

The public page checked on 2026-10-05 contains browser play and the Windows v0.17.0 ZIP. The loaded game iframe is only 640 × 360 CSS pixels inside a 960-pixel content column, so enlarge the embed or use fullscreen launch in the project settings. Update the Windows-only description to mention browser single-player. No account access or page changes were performed.
