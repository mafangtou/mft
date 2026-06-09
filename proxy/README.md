# Windows LAN Reverse Proxy Kit

This directory provides a Windows-friendly Nginx reverse proxy scaffold for authorized LAN access to an internal website. It is designed to avoid common application-layer proxy mistakes:

- rewriting the upstream `Host` header to the real target domain;
- rewriting absolute frontend origins in HTML/JS/CSS/JSON responses with `sub_filter`;
- normalizing selected outbound headers for predictable server-side behavior;
- generating logs, validating the Nginx config, checking health, and opening the LAN URL automatically.

> Only use this for systems you own or are explicitly authorized to administer. Do not use it to bypass third-party security, anti-abuse, account, or access-control systems.



## 一键下载代码

如果你只是想把这套代理脚本下载到 Windows 电脑上，推荐用下面任一方式。

### 方式 A：网页一键下载 ZIP（最简单）

1. 打开仓库或 PR 页面。
2. 点击页面右上角或仓库首页的 **Code** 按钮。
3. 点击 **Download ZIP**。
4. 解压 ZIP 后，进入解压目录，按下方“使用方法（快速上手）”执行。

### 方式 B：PowerShell 一行命令下载 ZIP

把下面命令里的 `<仓库ZIP下载地址>` 替换成 GitHub/GitLab 的 ZIP 地址后执行：

```powershell
$zip = "$env:USERPROFILE\Downloads\mft-proxy.zip"; Invoke-WebRequest -Uri "<仓库ZIP下载地址>" -OutFile $zip; Expand-Archive -Path $zip -DestinationPath "$env:USERPROFILE\Downloads\mft-proxy" -Force; explorer "$env:USERPROFILE\Downloads\mft-proxy"
```

常见 ZIP 地址格式：

```text
https://github.com/<owner>/<repo>/archive/refs/heads/<branch>.zip
```

### 方式 C：已安装 Git 时克隆代码

```powershell
git clone <仓库地址>
cd <仓库目录>
```

克隆后先复制配置文件：

```powershell
Copy-Item .\proxy\env.example .\proxy\env.local.ps1
notepad .\proxy\env.local.ps1
```

## 使用方法（快速上手）

> 以下步骤在 Windows PowerShell 或双击 `.bat` 文件时使用。请只代理你拥有或已获授权管理的网站。

### 1. 准备 Nginx

下载并解压 Nginx for Windows 后，任选一种方式让脚本能找到 `nginx.exe`：

- 将 `nginx.exe` 加入系统 `PATH`；
- 或把 Nginx 放到 `proxy\tools\nginx\nginx.exe`；
- 或在 `proxy\env.local.ps1` 中设置 `$NginxExe = "C:\\nginx\\nginx.exe"`。

### 2. 创建本机配置

```powershell
Copy-Item .\proxy\env.example .\proxy\env.local.ps1
notepad .\proxy\env.local.ps1
```

至少修改以下字段：

```powershell
$TargetScheme = "https"                  # 目标站协议
$TargetHost = "www.example.com"          # 目标站真实域名，不要写局域网 IP
$ListenPort = 8080                        # 局域网访问端口
$RewriteOrigins = @(
  "https://www.example.com",             # 主站绝对地址
  "https://api.example.com"              # 如前端直连 API，也写在这里
)
```

如果脚本自动识别的内网 IP 不正确，再取消注释并设置：

```powershell
$BindIp = "192.168.1.10"
```

### 3. 一键启动

双击：

```text
proxy\start-proxy.bat
```

或在 PowerShell 中执行：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\proxy\start-proxy.ps1
```

启动脚本会自动生成 `proxy\run\nginx.conf`，执行 `nginx.exe -t` 配置检查，启动或重载 Nginx，访问 `/__proxy_health` 做健康检查，并打开 `http://<本机内网IP>:<端口>`。

### 4. 局域网访问

同一局域网内其他设备访问启动脚本输出的地址，例如：

```text
http://192.168.1.10:8080
```

如无法访问，请检查 Windows 防火墙是否放行 `$ListenPort`。

### 5. 验证是否真正走代理

1. 打开浏览器 DevTools 的 Network 面板。
2. 刷新页面并执行登录/查询操作。
3. 确认接口请求地址是 `http://<本机内网IP>:<端口>`，而不是目标站官方绝对域名。
4. 查看日志：
   - `proxy\logs\nginx-access.log`：请求是否进入代理；
   - `proxy\logs\nginx-error.log`：上游连接、DNS、TLS 或配置错误。
5. 打开 `proxy\run\nginx.conf`，确认生成后配置中包含 `proxy_set_header Host <目标站真实域名>;` 和对应 `sub_filter` 规则。

### 6. 停止服务

双击：

```text
proxy\stop-proxy.bat
```

或在 PowerShell 中执行：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\proxy\stop-proxy.ps1
```

## Files

- `env.example` — copy to `env.local.ps1` and edit target settings.
- `start-proxy.ps1` — generates `run/nginx.conf`, validates it, starts/reloads Nginx, runs a health check, and opens the default browser.
- `stop-proxy.ps1` — sends a stop signal to the Nginx instance.
- `nginx/templates/reverse-proxy.conf.template` — Nginx reverse proxy template with required header and response-body rewrite rules.
- `logs/` — runtime access/error logs.
- `run/` — generated runtime config and PID file.

## Prerequisites

1. Install Nginx for Windows.
2. Either add `nginx.exe` to `PATH`, place it at `proxy\tools\nginx\nginx.exe`, or set `$NginxExe` in `env.local.ps1`.
3. Ensure the selected port is allowed by Windows Firewall for LAN clients.

## Configure

```powershell
Copy-Item .\proxy\env.example .\proxy\env.local.ps1
notepad .\proxy\env.local.ps1
```

Set:

- `$TargetScheme`: `https` or `http` for the upstream site.
- `$TargetHost`: the real domain name of the upstream site.
- `$ListenPort`: the LAN port exposed by this proxy.
- `$BindIp`: optional static LAN IP override if auto-detection is wrong.
- `$RewriteOrigins`: all authorized absolute origins that must be rewritten to `http://<LAN-IP>:<PORT>`.

## Start

```powershell
PowerShell -ExecutionPolicy Bypass -File .\proxy\start-proxy.ps1
```

The script will:

1. detect or use the configured LAN IP;
2. generate `proxy\run\nginx.conf`;
3. run `nginx.exe -t`;
4. start or reload Nginx;
5. request `http://<LAN-IP>:<PORT>/__proxy_health`;
6. open `http://<LAN-IP>:<PORT>` in the default browser;
7. print access/error log locations.

## Stop

```powershell
PowerShell -ExecutionPolicy Bypass -File .\proxy\stop-proxy.ps1
```

## Verification checklist

- Confirm generated config contains `proxy_set_header Host <target-domain>;`.
- Confirm `sub_filter` rules map every authorized absolute upstream origin to the LAN proxy origin.
- Open DevTools Network and verify API calls use `http://<LAN-IP>:<PORT>` instead of direct upstream absolute URLs.
- Inspect `proxy\logs\nginx-access.log` and `proxy\logs\nginx-error.log` if login or API requests fail.
