# WinLink：Mac 连接 Windows 开发与测试

[MIT License](LICENSE)

在任意一台 Mac 上安装同一个 `winlink` 命令，配置目标后即可登录 Windows、执行 PowerShell、运行测试或用 VS Code 编辑远端项目。

首版针对**同一局域网或已有 VPN，且两端地址与 SSH 端口可达**。Windows 必须保持运行。客户端使用 macOS 自带的 Bash、OpenSSH 和 iconv，不需要 Python、Node 或 Homebrew；自动化测试使用 Python 3。Windows 端使用系统 OpenSSH Server 与 Windows PowerShell 5.1。

## 开始前：先获取项目（Mac 和 Windows 都要做）

`setup.sh` 是这个仓库里的文件，不是系统自带命令。**必须先下载整个项目、解压并进入项目根目录，再运行安装命令。** 不需要安装“GitHub 软件”，也不必注册 GitHub 账号。

### 推荐：浏览器下载 ZIP，不需要 Git

1. 在 Mac 和 Windows 上分别打开[项目页面](https://github.com/tingfengyinyue/mac-winlink)，点击 **Code → Download ZIP**，或直接[下载 main 分支 ZIP](https://github.com/tingfengyinyue/mac-winlink/archive/refs/heads/main.zip)。也可以将同一份完整 ZIP 通过可信方式复制到另一台电脑。
2. **Mac**：双击 ZIP 解压。默认文件夹名是 `mac-winlink-main`；若放在“下载”目录，打开终端执行：

   ```bash
   cd "$HOME/Downloads/mac-winlink-main"
   ls setup.sh Setup-Windows.cmd
   ```

   应看到这两个文件名。若目录不同，在终端输入 `cd `（后面有空格），把 Finder 中解压后的项目文件夹拖进终端，再按回车。
3. **Windows**：在资源管理器中右键 ZIP → **全部解压**，打开解压后的 `mac-winlink-main` 文件夹。应能同时看到 `Setup-Windows.cmd`、`setup.sh` 和 `windows` 文件夹。不要在 ZIP 预览里直接运行脚本，也不要只复制一个脚本文件。

这里能看到上述文件的文件夹就是“项目根目录”。首次引导使用根目录的 `Setup-Windows.cmd`；只有手动运行安装/授权脚本时才进入 `windows` 子目录。

### 可选：已经安装 Git

在 **Mac 终端**运行：

```bash
cd "$HOME/Downloads"
git clone https://github.com/tingfengyinyue/mac-winlink.git
cd mac-winlink
ls setup.sh Setup-Windows.cmd
```

Git 克隆的默认目录是 `mac-winlink`，ZIP 解压的默认目录是 `mac-winlink-main`，不要混用。Mac 若提示安装命令行开发工具，可以直接选择上面的 ZIP 方式。已有 Git 仓库在原目录执行 `git pull --ff-only`；不要反复克隆到同一个目录。

Windows 已有 Git 时也可克隆同一仓库，然后在资源管理器打开仓库根目录。GitHub 无法访问时，可请能访问的同事下载完整 ZIP 后通过公司可信渠道传递。

## 推荐：首次连接用引导脚本

为了减少首次使用时来回复制命令与诊断输出，新增配对文件引导：

完成上面的下载和目录检查后：

1. **Mac** 在项目根目录运行 `bash setup.sh prepare`，生成 `office.winlink.json`。
2. 将文件传到已解压项目的 Windows，**Windows** 双击项目根目录 `Setup-Windows.cmd`，选中配对文件，按提示完成一次提权和授权。
3. 将 Windows 更新后的同一个文件传回 Mac，**Mac** 运行 `bash setup.sh connect ./office.winlink.json`，自动核对指纹并验证登录。

引导处理本次安装遇到的执行策略、管理员窗口、公钥路径和 Public 网络防火墙问题。配对文件包含真实设备元数据，应通过可信方式传递，已加入 Git 忽略规则。[完整三步说明、参数与验证边界](docs/QUICKSTART.md)。

下面保留逐步手动配置说明，便于理解和排查。

## 先看：命令在哪台电脑执行？

**所有 `winlink ...` 命令都在 Mac 终端运行。** `winlink` 是本项目安装的工具，需要先安装；它不是 macOS 自带命令，也不是 SQL。

| 操作 | 在哪里执行 | 用途 |
| --- | --- | --- |
| `bash ./install-mac.sh` | Mac 终端 | 安装客户端 |
| `winlink keygen`、`winlink pubkey` | Mac 终端 | 为当前 Mac 生成密钥、导出公钥 |
| `Install-WinLink.ps1` | Windows 管理员 PowerShell | 安装并配置 SSH 服务 |
| `Authorize-Mac.ps1` | Windows 管理员 PowerShell | 授权某台 Mac 的公钥 |
| `winlink add ...` | Mac 终端 | 保存 Windows 连接参数，不会立即登录 |
| `winlink shell / exec / script / doctor / code ...` | Mac 终端 | 连接并使用 Windows |

```text
Mac：运行 winlink、操作 VS Code
                 │ SSH
                 ▼
Windows：存放远端项目、执行命令与测试
```

不熟悉参数、终端换行或公钥？见 [命令解释与常见问题](docs/FAQ.md)。连接出错时见 [故障排查](docs/TROUBLESHOOTING.md)。

## 一次配置后的用法

以下命令均在 Mac 执行，前提是已完成后面的安装、授权与添加目标步骤：

```bash
winlink list
winlink shell office
winlink doctor office
winlink exec office -- 'Get-Process | Select-Object -First 5'
winlink exec office -- 'npm.cmd test; exit $LASTEXITCODE'
winlink script office ./examples/test.ps1
winlink code office 'C:/work/my-project'
```

`exec` 的参数是一整段 **PowerShell**，用单引号包住以保留 `$env:...` 等远端变量。需要显式调用 cmd 时使用 `winlink exec office -- 'cmd.exe /c ver'`。执行时默认进入 `--workdir` 指定的目录；`shell` 是标准 SSH 交互登录，进入 Windows 默认 shell 和默认目录。

## 1. 在每台 Mac 上安装、生成自己的密钥

将整个项目目录复制到 Mac，进入该目录：

```bash
bash ./install-mac.sh
export PATH="$HOME/.local/bin:$PATH"
winlink keygen
winlink pubkey > ./my-mac.pub
```

把 `export PATH="$HOME/.local/bin:$PATH"` 加入 `~/.zshrc` 可永久生效。安装器只复制命令，不自动改 shell 配置。`keygen` 会交互询问密钥口令，建议设置口令；不要把私钥复制给其他 Mac。

只将 `my-mac.pub` 公钥交给 Windows 操作者。每台新 Mac 执行同样步骤，分别授权；不需要再次安装 Windows SSH 服务。

可选：用 macOS ssh-agent 保存解锁后的密钥，避免频繁输入口令：

```bash
ssh-add --apple-use-keychain "$HOME/.config/winlink/id_ed25519"
```

## 2. 在 Windows 上安装 SSH 服务

将项目的 `windows` 目录复制到 Windows。在**64 位、管理员 PowerShell**中进入该目录，执行：

```powershell
.\Install-WinLink.ps1
```

脚本会按需安装 OpenSSH Server、备份 `sshd_config`、设置端口、校验配置、重启服务、设置开机启动，并创建 WinLink 防火墙规则。默认 TCP 22，仅允许 `LocalSubnet`，适用 Private/Domain 网络配置文件。

已有 VPN 需要按实际客户端来源网段配置，例如：

```powershell
.\Install-WinLink.ps1 -Port 2222 -RemoteAddress '192.0.2.0/24','198.51.100.0/24'
```

这里使用保留的文档示例网段，不是可直接连接的真实网络，必须换成你的真实局域网/VPN 客户端来源网段。如果可信网络被 Windows 标记为 Public，需按实际情况通过 `-NetworkProfile` 指定适用配置文件。脚本修改的是整台 Windows 的 SSH 服务端口，会断开现有连接，首次应在 Windows 本机执行。

新安装时，脚本会禁用这次安装自动生成的宽泛默认 SSH 防火墙规则，改用上述限定范围的规则。对安装前已经存在的规则，只提示检查，不改动。**Windows 防火墙允许规则会叠加，既有规则也可能放行流量。**

若 Windows 阻止本地脚本执行，可先阅读脚本；确认项目来源后在当前 PowerShell 窗口执行 `Set-ExecutionPolicy -Scope Process RemoteSigned`，对已审核的下载文件用 `Unblock-File` 解除标记，再运行脚本。组织策略限制时需由管理员按既有策略处理。

安装输出会包含 Windows IP 和 SSH 主机指纹，留作 Mac 首次连接核对。Windows 应禁止自动睡眠，并为目标配置稳定的 IP/DNS 名称。

## 3. 授权这台 Mac 的公钥

推荐使用一个**已有的本地标准账户**，例如 `tester`；先在 Windows 登录该账户一次，确保用户配置目录已生成。脚本不会创建账户或更改密码。

将 `my-mac.pub` 复制到 Windows 后，在管理员 PowerShell 执行：

```powershell
.\Authorize-Mac.ps1 -User tester -PublicKeyFile .\my-mac.pub
```

该脚本验证公钥格式、保留已有授权、去重追加公钥，并按 Windows OpenSSH 要求配置 ACL。重复授权同一公钥不会重复追加。首版授权助手面向本地 Windows 账户；域账户的密钥路径与权限请由管理员按现有环境配置。

如果使用管理员账户，Windows 默认通过所有管理员共用的 `administrators_authorized_keys` 授权，这把密钥可能用于登录其他管理员账户。脚本默认拒绝这种共享授权；明确接受该行为时才使用：

```powershell
.\Authorize-Mac.ps1 -User youradmin -PublicKeyFile .\my-mac.pub -AllowSharedAdministratorKey
```

若 Windows 已定制 `AuthorizedKeysFile`、`Match` 或禁用了公钥登录，需要先按真实 sshd 配置核对。脚本按微软标准密钥路径工作，不自动重写你的认证策略。Windows 的 Microsoft Entra 账户不在本工具支持范围。

## 4. Mac 添加目标、验证、打开项目

```bash
winlink add office --host 192.0.2.10 --user tester --port 22 --workdir 'C:\work\my-project'
winlink doctor office
winlink exec office -- '$env:COMPUTERNAME; Get-Location'
```

`192.0.2.10` 是保留的文档示例地址，不能直接用来连接。IP、用户、端口、工作目录都换成真实值。首次连接时，核对 Windows 安装输出中的主机指纹后再接受。需要更换参数时重新运行 `winlink add office ...`；它会替换该目标的完整配置，未传的参数恢复默认值。

这条命令**在 Mac 执行**，表示“保存一台别名为 `office` 的 Windows”：

| 参数 | 含义 | 要填写哪一端的信息 |
| --- | --- | --- |
| `add` | 添加或更新本机连接配置 | 在 Mac 本机保存 |
| `office` | 目标电脑的别名，可改为 `lab`、`home-pc` 等 | 自己命名 |
| `--host` | 目标地址 | Windows 的真实 IP 或可解析主机名 |
| `--user` | SSH 登录账户 | Windows 上已授权的本地用户名 |
| `--port` | SSH 服务端口，默认 22 | Windows 安装脚本设置的端口 |
| `--workdir` | 远程执行命令时进入的目录 | Windows 上实际存在的项目路径 |

添加配置不会安装 Windows 服务、传代码或立即登录。随后 `winlink shell office` 才会打开连接；`winlink exec office -- 'Get-Location'` 会在 Windows 执行命令并把结果返回 Mac。

VS Code 需要先安装微软 **Remote - SSH** 扩展，并在命令面板执行 **Shell Command: Install 'code' command in PATH**。然后：

```bash
winlink code office
```

VS Code 会打开 Windows 上的目录；Node、Python、Git、编译工具、项目依赖需要装在 Windows 上。VS Code Server 首次安装需要对应下载资源可达。代码保存在 Windows，工具不会自动同步 Mac 上另一份源码，也不安装项目依赖。

## 配置存放与移除

- Mac：`~/.config/winlink/hosts/<name>` 是标准 OpenSSH 配置；`workdirs/<name>` 存工作目录；`id_ed25519` 为本机私钥（不可分享），`.pub` 是公钥。
- 首次添加目标，会备份既有 `~/.ssh/config`，在开头加入指向 WinLink 主机目录的 `Include` 及 `Host *` 上下文重置。保留原配置内容。之后普通 `ssh winlink-office` 也能连接。
- `winlink remove office` 只移除本机目标配置。撤销远端密钥请在 Windows 使用原公钥执行：

  ```powershell
  .\Authorize-Mac.ps1 -User tester -PublicKeyFile .\my-mac.pub -Revoke
  ```

- 撤销助手只删除它所管理的无选项公钥行。若同一密钥还以 `authorized_keys` 带选项行或其他自定义文件存在，需一起检查。管理员共享文件撤销同样要传 `-AllowSharedAdministratorKey`。
- 卸载 Mac 客户端可删除 `~/.local/bin/winlink`，移除 `~/.ssh/config` 顶部的 WinLink `Include` 和对应 `Host *`，然后按需处理 `~/.config/winlink`。如仍有其他目标使用同一私钥，应保留。
- Windows 端修改前的 SSH 配置备份位于 `%ProgramData%\ssh\sshd_config.winlink.*.bak`。回退端口需恢复备份、校验配置并重启 `sshd`；删除 `WinLink-SSH-In-TCP` 规则前先确认其他连接的需要。

## 首版范围与验证

- 命令与小脚本通过 UTF-16LE 编码交给 PowerShell，避免本地 shell 和远端 cmd 对中文、引号二次解析。输出设置为 UTF-8。Windows 命令行长度有限，编码后超过 7000 字符会在本地拒绝；大脚本请先存到 Windows，再执行 `winlink exec office -- '& "C:\work\long-test.ps1"'`。`script` 只传脚本内容，不上传依赖文件，`$PSScriptRoot` 不指向本地脚本目录。
- 显式 `exit N` 返回该退出码；默认传播最后一次原生程序的 `$LASTEXITCODE`；PowerShell 抛错返回 1。涉及多个程序的流水线，请在脚本中明确处理各程序状态。
- 不包含自动发现电脑、穿透网络、代码同步、桌面截图或图形界面操作。桌面测试可另配远程桌面；通过 SSH 启动的 GUI 进程不能视为当前交互桌面的可见窗口。
- 不存储 Windows 密码、不携带共享私钥、不关闭主机指纹检查。首次授权在 Windows 上本地执行。

本地验证：

```bash
python3 -m unittest discover -s tests -v
bash -n bin/winlink install-mac.sh setup.sh
```

客户端的 23 项本地测试在隔离目录运行，调用真实 `/usr/bin/ssh -G` 验证配置解析，网络执行与 VS Code 启动使用替身捕获参数。2026-11-21 已在 Windows PowerShell 5.1 上验证脚本语法、配对预检，以及已有 SSH 环境的授权、防火墙、连接文件回写和 Mac 导入登录链路；重复执行未改变公钥文件内容。另已实测中文输出、读取远端文件和退出码传递。

**已有 SSH 环境的引导测试使用 `-SkipServerInstall`，不等于全新 Windows 的组件下载、双击/UAC 交互、普通账户授权、VS Code 或桌面 UI 全部通过。**这些场景仍需分别验收。可选的 [GitHub Actions CI 模板](docs/ci/README.md) 默认不自动运行。

首次实机验收按顺序执行：Windows 安装与公钥授权 → Mac `doctor` → `exec ... 'exit 7'` 后 `echo $?` 应为 7 → `exec` 输出中文并访问带空格目录 → `code` 打开项目 → 第二台 Mac 独立密钥授权 → 撤销该密钥并确认新连接被拒绝（不要用密码回退替代验证）。

官方依据：[Windows OpenSSH 安装](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse)、[密钥认证与 ACL](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement)、[Windows SSH 配置](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh-server-configuration)、[VS Code Remote-SSH](https://code.visualstudio.com/docs/remote/ssh)。

隐私与发布范围见 [SECURITY.md](SECURITY.md)，参与开发见 [CONTRIBUTING.md](CONTRIBUTING.md)，架构见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。
