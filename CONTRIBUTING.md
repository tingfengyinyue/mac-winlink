# 参与开发

客户端兼容 macOS 自带 Bash 3.2，不为普通使用者引入 Python、Node 或 Homebrew 依赖。Windows 脚本以 Windows PowerShell 5.1 为基线。

提交变更前运行：

```bash
python3 -m unittest discover -s tests -v
bash -n bin/winlink install-mac.sh
git diff --check
```

增加或修复行为时，补充能够观察该行为的测试。客户端测试使用隔离临时目录，不修改开发者真实 SSH 配置，不连接任何真实主机。Windows 语法检查与客户端替身测试不能代替真实安装与连接测试；报告测试结果时请说明范围。

不要提交本机运行目录、密钥、真实地址、公司资料、个人路径或完整 SSH 调试日志。具体隐私边界见 [SECURITY.md](SECURITY.md)。

文档中的命令应标明 Mac/Windows 执行位置，明确哪些参数必须替换。网络示例使用保留的文档地址；不要把实际设备配置当作示例。
