# claude-with-codex

**Claude 为主，Codex 为辅。** 一组经过实战打磨的 [Claude Code](https://claude.com/claude-code) skills，把 OpenAI Codex CLI 变成 Claude 的第二视角——常驻的审阅者、对抗性挑战者，以及（在两个严格圈定的白名单场景下）受托执行者——全部通过一个长驻 tmux pane 驱动，上下文跨轮次累积。

[English → README.md](README.md)

## 核心理念

两个前沿 coding agent 比一个强——**前提是分工明确**：

- **Claude 是主工程师。** 每一行代码由它写，每一次构建由它跑，每个决策由它负责。
- **Codex 是第二视角。** 审阅计划与 diff、挑战已拍板的决策、从全新角度诊断顽固 bug——拥有仓库的完整读权限。
- 协作通道是 **tmux pane 里的常驻 Codex TUI**，而不是一次性的 `codex exec` 调用。常驻正是关键：Codex 跨轮次记得变更集、此前的发现、你的修复和设计意图，复审成本极低、简报可以很轻。
- 审阅以 **review ⇄ fix 共识循环**运转：Codex 提出发现，Claude 立即修复，Codex 复审——直到 clean 判定（约 5 轮封顶，并为「判断类分歧」写明了坚持立场的协议）。

两个精心圈定的例外场景中 Codex *执行*而非审阅：**图片资产生成**与 **computer use（GUI 自动化）**——都是一次性产出物，永不进入代码审查循环。代码永不委派。

## Skills 一览

| Skill | 角色 | 定义了什么 |
|---|---|---|
| [`using-codex-collaboration`](skills/using-codex-collaboration/SKILL.md) | ⭐ 核心 | 完整体系：tmux 通道搭建与 pane 定位、发送/等待/读取机制、四大协作场景（变更审阅、计划审阅、对抗性挑战、bug 救援）、共识循环、立场纪律、故障恢复手册 |
| [`codex-image-gen`](skills/codex-image-gen/SKILL.md) | 例外 #1 | 委派图片资产生产（图标、插图、占位图），含硬约束、合规规则与自主核验 |
| [`codex-computer-use`](skills/codex-computer-use/SKILL.md) | 例外 #2 | 委派 GUI 自动化（桌面 App、浏览器界面、系统面板），含安全边界：不可逆操作须授权、简报不含凭据、结果独立核验 |

## 环境要求

- [Claude Code](https://claude.com/claude-code)（skills 为其编写，但协议本身与 harness 无关——任何能执行 `tmux` 命令的 agent 都能遵循）
- [tmux](https://github.com/tmux/tmux)
- [OpenAI Codex CLI](https://github.com/openai/codex)，已登录（`codex login`）

一键检查：

```bash
./scripts/check-env.sh
```

## 安装

把 skill 目录复制（或 symlink）到 user 级 skills 目录：

```bash
git clone https://github.com/Jewel591/claude-with-codex.git
cd claude-with-codex
cp -R skills/* ~/.claude/skills/
```

就这样。Claude Code 会自动发现 user 级 skills；下个会话在情境匹配时自动触发（完成大改动、写完计划、卡在 bug 上、需要出图或驱动 GUI）。

更新 = pull 后重新复制；卸载 = 从 `~/.claude/skills/` 删掉这三个目录。

## 设计笔记（为什么这样设计）

- **tmux pane，绝不 `codex exec`。** 每次 `codex exec` 都是零记忆的全新进程——每轮都要付全额重述成本，协作被切碎。pane 让每个仓库保有一条连续对话。
- **Pane 定位以仓库路径为键**，以不可变 pane ID（`%N`）寻址——多个并发 Claude 会话各自只对话自己的 Codex，仓库 A 的审阅绝不会落进仓库 B 的 pane。
- **简报只指路，不粘贴。** Codex 有仓库访问权；把 diff 发给它既浪费 token 又会过期。发送的是诉求、意图、有意的非目标和审查重点。
- **构建门禁留在 Claude 手里。** Codex 的沙箱会让平台构建工具虚假失败，且委派验证会模糊责任归属。Claude 在轮次之间编译/测试，保证 Codex 复审的永远是能跑的代码。
- **立场纪律成文。** Codex 的语气比实际把握更笃定，且轮次间很少软化。循环的通过判据是*客观缺陷清零*——不是 Codex 对每个设计选择点头。记录在案的分歧同样算收敛。
- **TUI 驱动细节是承重墙。** 文本与 Enter 分开发送（忙碌的 TUI 会吞掉同时发出的回车）、发送前清空输入框（自动补全的 ghost text 会凭空虚构消息）、轮询 `capture-pane` 等待空闲提示符而非盲目 sleep。这些小规则正是「演示能跑」与「无人值守也能跑」的分界。

## License

[MIT](LICENSE)
