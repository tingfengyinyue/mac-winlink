# 可选 GitHub Actions CI

`github-actions.yml` 是模板，放在文档目录下，默认不会触发 GitHub Actions。它包含：

- macOS：Bash 语法检查、隔离客户端测试、空白字符检查。
- Windows：通过 Windows PowerShell 5.1 解析 `.ps1` 语法，不执行安装器或修改 SSH 服务、防火墙、授权文件。

要启用，在对目标仓库具有工作流写入权限的环境中，将模板复制到 `.github/workflows/ci.yml`，提交并推送：

```bash
mkdir -p .github/workflows
cp docs/ci/github-actions.yml .github/workflows/ci.yml
git add .github/workflows/ci.yml
git commit -m 'Enable GitHub Actions CI'
git push
```

上述操作在 Mac 的项目目录执行；提交前检查实际 diff。若使用 OAuth 凭据推送，GitHub 可能要求 `workflow` 权限。不要把凭据、真实主机配置或私钥写入工作流。

CI 语法检查不验证 Windows 安装、ACL、网络连接或 VS Code 远程会话。实机验收清单见主 README。
