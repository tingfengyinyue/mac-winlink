# 故障排查

## Mac 提示 `command not found: winlink`

在项目目录执行 `bash ./install-mac.sh`，再执行：

```bash
export PATH="$HOME/.local/bin:$PATH"
winlink --help
```

将 PATH 设置写入 `~/.zshrc` 可让新终端继续使用。如果设置过 `WINLINK_BIN_DIR`，改为实际安装目录。

## SSH 连接超时或被拒绝

确认 Windows 开机且未睡眠，目标 IP/端口正确，Mac 到 Windows 的局域网或 VPN 路由可达。Windows 管理员 PowerShell 可检查：

```powershell
Get-Service sshd
Get-NetFirewallRule -Name WinLink-SSH-In-TCP | Format-List Enabled,Profile,Direction,Action
Get-NetFirewallRule -Name WinLink-SSH-In-TCP | Get-NetFirewallAddressFilter
```

默认规则只允许 LocalSubnet 的 Private/Domain 网络。VPN 客户端来源网段、Windows 网卡配置文件与规则需一致。已有 SSH/组织策略规则也会影响连接。不要通过关闭整机防火墙排查。

## `Permission denied (publickey,password)`

确认 Mac 选用的是 `winlink pubkey` 对应的私钥，Windows 授权脚本的 `-User` 与 Mac `--user` 相同。标准用户与管理员使用不同公钥文件；管理员默认共享文件需要明确选择。已有自定义 `AuthorizedKeysFile`、`Match`、Allow/Deny 规则或 ACL 需按真实配置检查。

密钥有保护口令时先用 `ssh-add` 解锁。Microsoft Entra 账户不在授权助手支持范围。不要把私钥复制到 Windows，也不要在公开 issue 中粘贴完整调试日志。

## Windows 阻止 `.ps1` 执行

先检查脚本来源和内容。按 README 的当前进程执行策略与下载文件解除标记步骤处理；组织策略由管理员处理。安装与授权脚本需要 64 位管理员 PowerShell，不能在 cmd 或 Mac 终端直接执行。

## 能登录，但项目目录或依赖不存在

`--workdir` 必须是 Windows 上实际存在且目标账户可访问的目录。Node、Python、Git 和项目依赖要安装在 Windows；Mac 本地安装不会自动出现在远端。`shell` 不自动切换工作目录，`exec`、`script`、`doctor` 使用配置的工作目录。

## `winlink code` 提示找不到 `code`

在 Mac 的 VS Code 命令面板运行 **Shell Command: Install 'code' command in PATH**，安装微软 **Remote - SSH** 扩展，再重开终端。若已自定义 `remote.SSH.configFile`，确保它能读取 WinLink 写入默认 `~/.ssh/config` 的 Include。

可先在 VS Code 里用 **Remote-SSH: Connect to Host...** 选择 `winlink-office`。Windows 平台识别或 TCP 转发问题见 [VS Code 官方排查](https://code.visualstudio.com/docs/remote/troubleshooting)。

## 主机指纹变了

先在 Windows 本机确认是否重装过系统或重新生成过 SSH 主机密钥，核对新指纹。确认原因后再更新本机相应记录，不要直接忽略指纹检查。
