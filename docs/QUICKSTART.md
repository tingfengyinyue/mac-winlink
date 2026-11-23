# 首次连接：三步引导

这套引导用于第一次连接，解决手工切目录、执行策略、管理员权限、Public 网络防火墙、公钥位置与主机指纹核对等配置步骤。

## 第零步：下载项目并进入正确目录

`setup.sh` 是仓库文件，不能在没有项目的电脑上直接执行。**Mac 和 Windows 都需要完整的项目目录。** 不需要安装 GitHub 客户端或注册账号。

推荐在浏览器打开[GitHub 项目](https://github.com/tingfengyinyue/mac-winlink)，选择 **Code → Download ZIP**，或[直接下载 ZIP](https://github.com/tingfengyinyue/mac-winlink/archive/refs/heads/main.zip)：

- **Mac**：双击 ZIP 解压。如果保存在“下载”目录，在终端执行以下命令，确认能列出两个文件：

  ```bash
  cd "$HOME/Downloads/mac-winlink-main"
  ls setup.sh Setup-Windows.cmd
  ```

  若解压目录不同，输入 `cd ` 后把 Finder 中的项目文件夹拖入终端，再按回车。
- **Windows**：右键 ZIP → **全部解压**，打开 `mac-winlink-main` 文件夹，确认能看到 `Setup-Windows.cmd`、`setup.sh` 和 `windows` 文件夹。不要从 ZIP 预览直接运行，也不要只复制单个脚本。

也可将同一份完整 ZIP 通过可信方式复制到另一台电脑后分别解压；GitHub 无法访问时可由同事下载后通过公司可信渠道提供。

**已安装 Git 的可选方式**：在 Mac 终端执行：

如果尚未下载项目，在 Mac 终端执行：

```bash
cd "$HOME/Downloads"
git clone https://github.com/tingfengyinyue/mac-winlink.git
cd mac-winlink
ls setup.sh Setup-Windows.cmd
```

Git 目录通常叫 `mac-winlink`，ZIP 目录通常叫 `mac-winlink-main`。已有 Git 仓库在原目录运行 `git pull --ff-only`，不必重新克隆。Mac 提示安装命令行开发工具时，也可以直接选择 ZIP 方式。

能同时看到 `setup.sh`、`Setup-Windows.cmd` 的文件夹就是后文的“项目根目录”；Windows 首次引导也在这里操作。

## 第一步：Mac 生成配对文件

完成第零步后，保持 Mac 终端位于项目根目录，再运行：

```bash
bash setup.sh prepare
```

它会安装当前用户的 `winlink` 命令、检查或生成本机密钥、检测 Mac 的 IPv4 地址，并生成 `office.winlink.json`。终端交互时可确认或修改检测到的 Mac 地址；有 VPN 或多网卡时，应填写 Windows 能访问、且发起 SSH 时实际使用的 Mac 来源地址。

### 这个 JSON 从哪里来、在哪里？

`office.winlink.json` **由上面的 Mac 命令自动生成**，不是从 GitHub 下载，也不需要自己新建或填写。默认保存在运行命令时所在的目录：按本指南操作，就是 Mac 项目根目录，与 `setup.sh` 同一层。

例如 ZIP 解压在“下载”目录时，文件通常在 `~/Downloads/mac-winlink-main/office.winlink.json`；Git 克隆时通常在 `~/Downloads/mac-winlink/office.winlink.json`。终端会打印 `Pairing file: ...`，后面就是本次实际保存路径。若用了 `--name` 或 `--out`，以这个实际路径为准。

仍在 Mac 项目根目录时，可以用下面两行确认文件并在 Finder 中找到它：

```bash
ls -l ./office.winlink.json
open .
```

### 必须传文件：Mac → Windows → 原来的 Mac

尚未建立 SSH，脚本**不会自动把文件发到另一台电脑**。需要你通过飞书私聊附件、U盘或公司认可的共享目录传送这个 `.json` **文件本身**，不要只复制文件名或把 JSON 内容粘贴成聊天文字。

| 阶段 | 文件在哪一端、做什么 |
| --- | --- |
| Mac 生成 | `prepare` 生成初始 JSON，包含这台 Mac 的公钥等配对数据。 |
| 发到 Windows | 将这个 JSON 作为文件传给 Windows，在 Windows 本机下载/复制到已解压的项目根目录，放在 `Setup-Windows.cmd` 旁边。 |
| Windows 更新 | 双击 `Setup-Windows.cmd`，在文件选择框里选择刚收到的 JSON。成功显示 `READY` 后，同一路径的 JSON 已被补齐 Windows 连接信息，文件名通常不变。 |
| 发回原 Mac | **从 Windows 重新上传本地已更新的 JSON 作为新附件**，或重新复制更新后的文件；不要转发第一次 Mac 发出的旧聊天附件。 |
| Mac 导入 | 在原来生成文件的 Mac 上接收更新版，放回原项目目录替换旧 JSON，再执行第三步的 `connect`。 |

每台 Mac 都要生成自己的配对文件；不要拿另一台 Mac 的 JSON 来连接。这个文件不是私钥，但包含真实设备信息，不要发到公共群或提交到 GitHub。

首次生成私钥时可设置本机保护口令。已有密钥会复用，不会覆盖。配对文件只包含公钥、指纹、Mac 地址等连接数据，不含私钥或密码。

也可以显式指定名称、地址和输出位置：

```bash
bash setup.sh prepare --name office --client-address 192.0.2.50 --out ./office.winlink.json
```

`192.0.2.50` 是保留的文档示例地址，必须换成 Mac 的真实地址。文件已存在时不会覆盖；重新开始可指定另一个输出路径。

## 第二步：Windows 双击完成安装与授权

先按上面的文件传送说明，把 **Mac 生成的 JSON 下载/复制到 Windows 本机项目根目录**。然后在这个目录双击（不是双击 JSON，也不需要进入 `windows` 子目录）：

```text
Setup-Windows.cmd
```

然后：

1. 在文件选择框中选中刚在 Windows 本机保存的 `office.winlink.json`。
2. 接受 Windows 的 UAC 提权提示，切到新打开的管理员窗口。
3. 默认使用启动引导时的本地 Windows 用户。若该用户是管理员，会解释管理员共享公钥文件的权限范围，需输入 `YES` 才继续；也可选择已登录过的本地标准账户。
4. 等待出现 `READY`。第一次安装 Windows OpenSSH 组件可能耗时较长，窗口会显示当前阶段。

引导会：

- 校验配对文件、公钥格式及指纹，拒绝无效或宽泛的来源地址。
- 按需安装系统 OpenSSH，设置服务自启，备份并校验 SSH 配置。
- 授权当前 Mac 公钥，处理 Windows 标准用户/管理员密钥文件与 ACL。
- 创建覆盖 Private、Domain、Public 网络的入站规则，来源仅限这台 Mac 的地址。既有规则仍可能放行其他来源，不会静默删除既有管理员规则。
- 根据到 Mac 的路由选择 Windows 地址，读取 Windows 主机指纹。
- 将同一个配对文件更新为可供 Mac 导入的连接文件。
- 将阶段和错误保存在 `%LOCALAPPDATA%\WinLink\logs`，方便后续排查。

启动器的执行策略参数仅用于它启动的 PowerShell 进程，不修改全机或当前用户的持久策略，也不覆盖组织组策略。Windows 本机第一次仍需明确执行该引导和接受系统提权；尚未建立连接的 Mac 无法代替这一步。

如果想使用其他本地用户或端口，可在管理员 PowerShell 进入项目根目录执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\Setup-Windows.ps1 -RequestFile .\office.winlink.json -User tester -Port 2222
```

已有 SSH 且不希望重启服务时，可增加 `-SkipServerInstall`。管理员共享授权可通过 `-AllowSharedAdministratorKey` 明确选择。只检查配对文件和账户可增加 `-ValidateOnly`，它不会安装服务、写公钥或创建防火墙规则。

## 第三步：Mac 导入并自动验证

看到 Windows 的 `READY` 后，从 Windows **重新发送本地更新后的 JSON 文件**回到原来的 Mac。不要转发第一次 Mac 发出的旧附件。

在 Mac 把收到的更新版放回项目根目录，替换最初那份旧 `office.winlink.json`，然后在 Mac 项目目录执行：

```bash
bash setup.sh connect ./office.winlink.json
```

如果更新版另存到其他目录，或下载后文件名带有 `(1)` 等后缀，`connect` 后面必须使用**更新版的实际路径和名称**；路径有空格时加引号。不要误选仍留在项目目录里的旧文件。

脚本会：

1. 确认该文件属于当前 Mac 的公钥。
2. 读取实际 Windows SSH 主机密钥，与文件中由 Windows 本机导出的指纹核对。
3. 保留原有 `known_hosts`，遇到冲突会停止，不会删除旧记录或忽略检查。
4. 写入 `office` 目标配置并验证公钥登录；仅允许本机密钥口令提示，不回退到 Windows 密码登录。

配对文件必须来自你信任的两台设备及传输途径。它不是签名证书；不要导入别人提供的文件，也不要上传到 GitHub 或公共聊天。`*.winlink.json` 已加入忽略规则。

如私钥有保护口令，连接时按提示输入本机口令，或先通过 `ssh-add` 解锁。Windows 与 Mac 的网络地址变化后，需要更新对应配置/来源规则。

## 日常使用

Mac 端：

```bash
export PATH="$HOME/.local/bin:$PATH"
winlink doctor office
winlink exec office -- '$env:COMPUTERNAME; whoami'
winlink shell office
winlink code office 'C:/work/my-project'
```

实际项目目录与依赖需事先存在于 Windows。图形桌面操作仍需另外部署交互式测试执行端；本引导只建立 SSH 命令与文件访问能力。

## 验证范围

2026-11-21：23 项 Mac 本地测试通过，覆盖配对文件生成、主机与本机密钥匹配、非法参数、既有指纹冲突、多算法记录、重复导入和登录失败传递。真实 Windows PowerShell 5.1 的语法与配对预检通过；已有 SSH 的实机链路已用 `-SkipServerInstall` 完成授权、来源地址防火墙、回写和 Mac 导入登录，重复执行未重复添加公钥。全新 Windows 首装、双击/UAC 交互、普通账户、VS Code 和图形桌面测试仍需单独验收。
