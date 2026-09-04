# Steam Work MCP

个人使用的只读 Steam MCP，部署在 Windows VPS，并通过 HTTPS 隧道连接到
ChatGPT Work。它基于 `Sarg338/steam-mcp` 1.14.0，增加了远程
Streamable HTTP 入口和 PowerShell 自动部署脚本。

## 能做什么

- 查询完整游戏库、游玩时间和最近游玩
- 查询成就、稀有成就、好友与共同拥有的游戏
- 查询愿望单、实时折扣、价格、评价和在线人数
- 根据个人游戏库进行推荐和联机规划

全部工具都是只读操作，不能购买、交易、发帖、启动游戏或修改 Steam
账号。服务器不需要 Steam 密码、Cookie 或 Steam Guard。

## 安全原则

- Steam Web API Key 只保存在 VPS 的 `C:\steam-work-mcp\.env`。
- `.env` 已被 Git 忽略，不要把它上传到 GitHub、聊天或截图中。
- 服务默认只监听 VPS 本机的 `127.0.0.1:4100`。
- 安装脚本会自动生成一个随机 MCP 路径，完整的远程 URL 应视为私密信息。
- 公开访问必须经过现有的 HTTPS 隧道，不要直接开放 4100 端口。

## Windows VPS 首次安装

在 VPS 的管理员 PowerShell 中运行：

```powershell
$u='https://raw.githubusercontent.com/kui-2026/steam-work-mcp/main/scripts/install-windows.ps1'; $f="$env:TEMP\install-steam-work.ps1"; Invoke-WebRequest $u -OutFile $f; powershell.exe -NoProfile -ExecutionPolicy Bypass -File $f
```

脚本会：

1. 从本仓库下载最新版代码；
2. 在 `C:\steam-work-runtime` 安装独立运行环境；
3. 在 `C:\steam-work-mcp` 创建项目与私密 `.env`；
4. 安装固定版本的依赖；
5. 启动服务并检查 `127.0.0.1:4100` 是否监听。

首次安装不需要 Steam API Key，此时商店、评价、价格、折扣和在线人数工具
已经可用。

## 开启个人游戏库

先在 Steam 官方页面创建 Web API Key，然后只在 VPS PowerShell 中运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\steam-work-mcp\scripts\configure-steam.ps1
```

脚本会在服务器本地询问 API Key 和 Steam 主页名称/链接，并重启服务。输入
不会进入 GitHub。游戏库和游玩时间还要求 Steam 隐私设置中的“游戏详情”
对外公开；API Key 无法绕过隐私设置。

## MCP 地址

安装结束时 PowerShell 会显示本地地址，形式如下：

```text
http://127.0.0.1:4100/steam-<随机值>/mcp
```

将现有 HTTPS 隧道的新配置指向这个本地地址。随后在 ChatGPT Work 中创建
自定义 App，填入对应的 `https://.../steam-<随机值>/mcp`，扫描工具即可。

## 手动重启

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\steam-work-mcp\scripts\start-windows.ps1
```

日志位于：

- `C:\steam-work-mcp\mcp.log`
- `C:\steam-work-mcp\mcp-error.log`

## Linux / Docker（备用）

仓库也保留 Docker 配置。复制 `.env.example` 为 `.env`、设置随机
`MCP_PATH` 后运行 `docker compose up -d --build`。Compose 只把端口绑定到
`127.0.0.1:4100`。
