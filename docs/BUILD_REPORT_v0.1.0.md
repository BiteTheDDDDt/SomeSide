# SomeSide 0.1.0 构建与验收

验收日期：2026-10-04（Asia/Shanghai）。本报告对应 `dist/SomeSide.exe` 和 `dist/SomeSide-v0.1.0-windows-x64.zip`。

## 构建

- 固定引擎：`4.7.2.stable.official.ed1daf0bf`，Windows x86_64 portable。
- 引擎与导出模板均来自 Godot 官方发布，下载归档已通过官方 `SHA512-SUMS.txt` 校验。
- Release 导出，PCK 嵌入 EXE；无需目标电脑安装 Godot。
- EXE：122,550,064 字节；SHA256 为 `9DCC8E130B913C43D2010B679E1E2BDD69B721C58794571D1D560DD9BAA8AA58`。
- ZIP：52,613,447 字节；SHA256 为 `994E69DDFBE3B3E67AB1354DAA809AD962C348A20F5CC29375D30A101172BAAD`。
- ZIP 中仅有 `SomeSide.exe`、`README.txt`、`GODOT-LICENSE.txt` 和 `FONT-OFL.txt`。已重新读取 ZIP 内 EXE 并验证其 SHA256 与受测文件完全相同。

## 自动验证

| 验证 | 结果 | 证据（相对项目根目录） |
| --- | --- | --- |
| 模拟规则 | 53 / 53 通过 | `tools/results/final-tests.log` |
| 四人长时间构筑、地图与状态压力 | 21 / 21 通过 | `tools/results/final-tests.log` |
| 菜单、选角、HUD、背包、暂停与结算 | 63 / 63 通过 | `tools/results/final-tests.log` |
| Source：1 主机 + 3 客户端，强制结算 | 全部通过，全部进入相同结果状态 | `tools/results/network-20261004-150112/summary.json` |
| Source：双向延迟、抖动、丢包与结算 | 全部通过 | `tools/results/network-impaired-20261004-150112/summary.json` |
| 最终 EXE：1 主机 + 3 客户端，游戏中退出 | 全部通过 | `tools/results/network-export-20261004-150500/summary.json` |
| 最终 EXE：双向延迟、抖动、丢包与结算 | 全部通过 | `tools/results/network-export-impaired-20261004-150546/summary.json` |
| Release 导出 | 成功 | `tools/results/final-export.log` |
| 打包与哈希 | 成功 | `tools/results/package.json` |

合计 **137 项规则、压力与界面断言通过**。最终四进程 EXE 测试中，主机识别四人、接收 2,503 条输入，客户端各接收 251–276 个完整快照。三名客户端在 `playing` 状态退出后主机继续运行，全部进程退出码为 0，stderr 均为 0 字节。

延迟测试使用真实本地 UDP 代理转发 ENet 数据，配置每个方向 50 ± 10 ms 延迟与独立 2% 丢包。最终 EXE 测试实测两个方向平均延迟为 55.178 / 54.877 ms，实际丢弃 8 / 7 个数据报；主机与客户端均收到同一 `lost` / `results` 结算，客户端收到 140 个完整快照。主机、客户端和代理均退出成功，stderr 全为空。

完整快照已改为 DEFLATE 压缩与 950 字节分片，终局使用可靠消息。最终代理观察到客户端到主机最大数据报 1,228 字节，主机到客户端最大 1,392 字节；没有此前超过 MTU 的不可靠发送警告。关闭不需要的客户端间自动中继后，多个客户端同时离线也不再触发无效通道发送错误。

## 画面检查

实际 OpenGL 运行截图：

- 菜单：`tests/menu.png`，运行日志 `tests/menu.out.log`。
- 游戏：`tests/gameplay.png`，运行日志 `tests/gameplay.out.log`。
- 渲染辅助检查：`tools/art-main-demo.png`、`tools/world-preview.png`。

上述截图来自 Godot 实际渲染。先前的多边形三角化报错与退出音频对象泄漏均已修复，最终网络和自动测试没有相关报错。

## 验证边界

本次联机验证在同一台 Windows 电脑上运行多个独立进程，并通过真实 UDP 代理注入网络损伤；没有实测两台公网机器。当前连接方式为 IP 直连：局域网，或双方已具备可达公网/虚拟局域网地址。游戏未包含 Steam 房间、公共匹配服务、自动 NAT 穿透或主机迁移。

压力测试代表当前有限实体规模与测试构筑，不能据此保证任意硬件、任意玩家数量或更大内容规模的帧率。原始日志保留于证据路径，失败的早期探针不属于本次最终验收结果。
