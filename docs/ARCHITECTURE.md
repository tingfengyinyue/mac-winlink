# 架构与边界

WinLink 将系统 OpenSSH 封装为可复用的 Mac 命令，不引入自研常驻服务。

| 组件 | 责任 |
| --- | --- |
| `bin/winlink` | 保存目标、调用 SSH、构造 PowerShell 命令、打开 VS Code |
| `install-mac.sh` | 将单文件客户端安装到本机用户目录 |
| `windows/Install-WinLink.ps1` | 系统 SSH 服务、端口、防火墙、主机指纹 |
| `windows/Authorize-Mac.ps1` | 公钥授权/撤销、Windows 标准密钥文件与 ACL |
| `tests/test_cli.py` | 本地客户端行为和真实 OpenSSH 配置解析测试 |

执行路径：Mac CLI 参数 → 校验 → 组合 Windows 工作目录与脚本 → UTF-16LE Base64 → SSH → Windows PowerShell → 输出与退出码返回 Mac。

每台 Mac 独立保存密钥与主机配置。目标配置以 SSH Include 接入默认配置，保留现有用户配置并生成备份；VS Code 与 CLI 使用同一主机别名。

身份验证、主机指纹与加密传输交由 OpenSSH。脚本不保存 Windows 密码，不关闭主机身份检查。普通本地账户与管理员共享授权文件分开处理。

首版要求两端网络已经可达。不提供跨网中继、自动发现、源码同步、GUI 控制或项目运行时安装。Windows 自定义 SSH 认证策略、域账户和更复杂的网络拓扑由现有环境管理。

仓库提供可选 CI 模板，启用后检查客户端行为、Bash 语法与 Windows PowerShell 语法，不会修改 runner 的 SSH 服务、防火墙或用户授权。模板默认不运行；真实 Windows 安装、ACL、连接及 VS Code 会话仍需实机验收。
