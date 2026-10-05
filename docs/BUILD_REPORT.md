# SomeSide v0.13.1 本地网页预览修复

用户在 Chrome 与 Firefox 中直接双击导出的 `index.html`，以 `file://` 运行，导致 WebAssembly / 资源下载被浏览器阻止，显示 `Failed to fetch`。问题与是否支持 WebGL 无关；旧加载页将所有启动失败都提示为浏览器兼容性问题，造成误导。

## 修改

- 新增项目根目录 `PlayWeb.cmd`，通过 `tools/serve-web.ps1` 和 Python 标准库预览服务，自动打开默认浏览器中的 `http://127.0.0.1:8765/`。只绑定本机，只提供 Web 导出目录；不开放目录列表或越界路径。游玩时保留控制台，Ctrl+C 停止。
- 默认读取当前项目版本选择导出目录；可指定 `-Directory`、`-Port`，开发自动化可用 `-NoBrowser`。本地预览需要 Python 3，当前机器已安装；上传 itch 后，玩家无需 Python 或本地服务器。
- 加载页在 `file://` 下提前停止，不请求 `.wasm` / `.pck`，明确提示使用预览服务器或 itch，并给出 `PlayWeb.cmd`；隐藏无意义的重试按钮，保留 Windows 下载链接。
- 真实下载失败和缺少浏览器功能分别显示对应提示，不再把 `Failed to fetch` 归为 WebGL 不兼容。
- 更新中英使用说明；游戏运行逻辑仅更新版本号，玩法、图像和联机没有变化。

## 验证

- 真实启动新 Python 预览服务：HTTP/HEAD、WASM/PCK MIME、仅本机地址、越界路径拒绝检查通过。
- Chrome **154.0.8037.93**、Firefox **148.0.2** 均从该服务加载最终 v0.13.1、点击进入单人并移动/射击，无浏览器或 Godot 运行时错误。合计 **11 项检查通过**。证据：`tools/results/web-preview-v0131/report.json` 及两浏览器菜单/实战截图。
- 实际运行 `PlayWeb.cmd -NoBrowser -Port 0`，服务器返回 HTTP 200；随后通过 Ctrl+C 关闭测试会话。
- Chrome 加载回归：中英 `file://`、WASM 404、JS 404、WebGL 缺失，共 **8 场景 / 60 项通过**。本地文件场景不发出 WASM/PCK 请求，显示准确说明。
- Firefox 中英 `file://` 另测 **16 项通过**，无未捕获异常。证据：`tools/results/web-loader-v0131-chrome/report.json`、`web-loader-v0131-firefox/report.json`。浏览器与预览服务均已关闭。
- 发布 ZIP 11 个文件，根目录 `index.html`，相对依赖、大小、文件头及 itch 限制检查通过，解压 62,041,758 bytes。证据：`tools/results/web-zip-v0131-audit.json`。

本补丁未修改玩法，未重复完整逻辑回归；v0.13.0 的 26 套 / 1325 项检查及 Windows 四人联机基线见 [上版构建报告](BUILD_REPORT_v0.13.0.md)。未修改 itch 页面。

## 产物

- Web：`dist/SomeSide-v0.13.1-web.zip`，32,329,360 bytes。
- Web SHA256：`F6BFB15F7B13B10ECBD6E86C190F25D10D31AB3A4838B8AEC7046D6D103EC628`
- Windows 同版本包：`dist/SomeSide-v0.13.1-windows-x64.zip`，60,145,712 bytes。
- Windows ZIP SHA256：`272BCED49AAECE506DC745579D6CBB8BA9CD4688B63E80773BA2BC87158BCB27`
- EXE SHA256：`4EA2C88B392D3A65940C8941401385F60403E5051BEA54E174853AC08022D71F`

旧版本保留，用户封面及导入文件未修改。新的本地预览辅助脚本保存在源码工程，HTML5 上传包不包含 Windows 启动脚本。操作见 [网页使用与上传说明](ITCH_WEB.zh-CN.md)。
