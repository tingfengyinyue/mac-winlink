# 命令解释与常见问题

## 要先安装 GitHub 或 Git 吗？

不必。GitHub 是托管项目的网站；推荐打开[项目页面](https://github.com/tingfengyinyue/mac-winlink)，点击 **Code → Download ZIP**，再分别在 Mac 和 Windows 解压完整项目。已经安装 Git 的用户也可克隆仓库。具体路径和目录检查见[第零步：下载项目](QUICKSTART.md#第零步下载项目并进入正确目录)。

## `bash setup.sh prepare` 提示找不到文件怎么办？

这通常表示尚未下载/解压项目，或终端不在项目根目录。在 Mac 先进入解压后的 `mac-winlink-main`（Git 克隆通常是 `mac-winlink`），运行 `ls setup.sh Setup-Windows.cmd` 确认两个文件都存在，再执行 `bash setup.sh prepare`。只复制文档里的命令、只下载一个脚本或在 ZIP 里直接运行都不够。

## 第一次配置一定要反复复制终端输出吗？

可以使用新的[三步引导](QUICKSTART.md)：先在两台电脑下载并解压完整项目，然后 Mac 在项目根目录运行 `bash setup.sh prepare` 生成配对文件，Windows 双击 `Setup-Windows.cmd` 处理安装/提权/授权/防火墙并更新文件，Mac 导回文件后运行 `bash setup.sh connect ...` 自动验证。首次仍需在 Windows 本机运行一次并接受系统授权，之后可由 Mac 远程操作。

## `winlink add office --host ...` 是 Mac 命令还是 Windows 命令？

这是 **Mac 终端命令**。先安装本项目，再在 Mac 的 Terminal、iTerm 或 VS Code 本地终端运行它。Windows 上运行的是 `windows` 目录里的 PowerShell 安装和授权脚本。

```bash
winlink add office --host 192.0.2.10 --user tester --workdir 'C:\work\my-project'
```

这里的地址是保留的文档示例，用户名和路径也是示例，执行前需要替换：

- `winlink`：本项目提供的命令，不是系统内置命令。
- `add`：在当前 Mac 保存一份连接配置。
- `office`：Windows 的别名，自己取名，后续命令使用同一个名字。
- `--host`：Windows 的真实 IP 或 DNS 主机名，不是 Mac 的地址。
- `--user`：Windows 登录用户名，不是 Mac 用户名；要与授权公钥时的 `-User` 一致。
- `--workdir`：Windows 上的项目目录，即使在 Mac 输入，也应填写 Windows 路径。

`add` 不会立即登录 Windows。完成配置后：

```bash
winlink shell office
```

才会进入 Windows 的交互终端。输入 `exit` 退出连接，回到 Mac 终端。

## 如何查 Windows 的 IP 和用户名？

在 **Windows PowerShell** 中执行：

```powershell
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.AddressState -eq 'Preferred' } | Select-Object InterfaceAlias,IPAddress
whoami
```

选 Mac 能访问的局域网或 VPN 网卡地址；存在虚拟网卡时，不要直接取列表第一项。`whoami` 常显示 `电脑名\用户名`，本地账户通常在 `--user` 和授权脚本里填写后半部分。管理员安装脚本窗口的当前账户可能不是你要授权的标准测试账户，需以目标账户为准。

## 末尾的 `\` 是什么意思？

Mac 的 Bash/Zsh 用行尾反斜杠把一条长命令分成多行：

```bash
winlink add office \
  --host 192.0.2.10 \
  --user tester \
  --workdir 'C:\work\my-project'
```

它与前面的一行命令等价。**反斜杠后不能有空格，最后一行不需要反斜杠。** 不熟悉时直接使用一行版本。

Windows PowerShell 的换行规则不同，不要把这种换行写法复制到 Windows。代码块标为 `bash`/`powershell` 是为了标明语言与执行环境；这些命令不属于 SQL，也不需要打开数据库工具。

## `exec ... -- '...'` 中的 `--` 和引号是什么意思？

`--` 后是一整段 PowerShell 命令，用外层单引号防止 Mac 提前展开 Windows 环境变量：

```bash
winlink exec office -- '$env:COMPUTERNAME; Get-Location'
```

你在 Mac 输入，PowerShell 在 Windows 执行，结果回到 Mac。需要复杂引号或多行内容时，把 UTF-8 脚本保存在 Mac 文件里，再用 `winlink script office ./test.ps1` 执行小脚本。脚本引用的其他文件仍需存在于 Windows。

## 每台 Mac 都需要操作一次 Windows 吗？

SSH 服务通常只安装一次。每台 Mac 分别生成独立密钥，把自己的 `.pub` 公钥交给 Windows 操作者，通过 `Authorize-Mac.ps1` 授权。不要共享私钥。每台 Mac 还需自行执行 `add`，配置目标电脑。

## 连接时询问的密码是哪种？

- `Enter passphrase for key ...`：Mac 上这把 SSH 私钥的保护口令。
- `user@host's password:`：Windows 账户密码。它与 Windows Hello PIN 不同；按本项目完成公钥授权后，应能通过公钥认证。
- `Are you sure you want to continue connecting ...`：首次连接的主机指纹确认，与 Windows 安装脚本输出核对后再接受。

不要把密码或口令写进命令行、GitHub issue 或项目配置。

## 代码放在哪？能看到 Windows 桌面吗？

`winlink code office` 打开 Windows 上的项目，编辑与保存作用于远端文件。Mac 本地已有的另一份源码不会自动同步；需要通过 Git 或另行配置的同步方式传递改动。

SSH 用于终端、文件和远程开发。查看 Windows 桌面、点击软件、验证图形界面需要另配远程桌面。Mac 与 Windows 必须同时运行，未启动的双系统无法被 SSH 连接。

## 如何添加第二台 Windows？

用不同别名：

```bash
winlink add lab --host 198.51.100.20 --user tester --workdir 'D:\projects\demo'
winlink list
winlink shell lab
```

示例地址仍需替换。每台 Windows 都需要安装 SSH 并授权当前 Mac 的公钥。
