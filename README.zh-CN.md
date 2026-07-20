# Claude with Codex

> **别再让一个 agent 审查它自己。**
> Claude 负责写，Codex 负责审——在同一个 tmux 常驻对话里。修复、复审、收敛。

一组 [Claude Code](https://claude.com/claude-code) skills，把 [OpenAI Codex CLI](https://github.com/openai/codex) 变成 Claude 的第二视角，从数月的真实产品仓库日常使用中提炼而来。

- **审阅轮次间上下文常驻**——Codex 活在一个长驻 tmux pane 里，记得变更集、此前的发现、你的修复和设计意图。复审只需一句话，不用重新交底。
- **审阅者/执行者严格分离**——每一行代码由 Claude 写、每次构建由 Claude 跑；Codex 拥有仓库完整读权限，只做审计。归属清晰，永远不会出现「这是谁改的？」。
- **四个开箱即用的工作流**——带共识循环的变更审阅、计划审阅、对已拍板决策的对抗性挑战、带根因排序的 bug 救援。

[English → README.md](README.md)

## 一个完整回合长什么样

```text
Claude  ▶ codex-pane.sh send "$PANE" "审查我未提交的 diff（自己跑 git diff）。
          意图：给搜索框加防抖。非目标：不重构结果列表。
          重点：正确性、回归。最后给 verdict。"
Codex   ◀ 「2 个发现：① 防抖 timer 在视图销毁时没有取消——会打进已释放的 handler；
          ② 空查询现在跳过了 loading 态。Verdict：需修复。」
Claude  ▶ 修复两处、跑完测试，然后：
          「已修复：① teardown 时取消 ② 恢复空查询 loading 态。
          请复审；顺便全仓扫一下还有没有其他未取消的 timer。」
Codex   ◀ 「两处修复正确。扫描在 ProfileView 又发现一处同类模式。
          Verdict：修掉那处即 clean。」
Claude  ▶ 修复、重跑测试 → Codex：「clean」→ 完成。
```

一个对话、三个回合、零重复交底。更完整的注解版会话：[examples/review-loop.md](examples/review-loop.md)。

## 与其他方式对比

| | 跨轮上下文 | 自主读仓库 | 角色分离 | 第 N 轮成本 |
|---|---|---|---|---|
| Claude 自审 | ✅ | ✅ | ❌ 盲区相同 | 低 |
| 一次性 `codex exec` 调用 | ⚠️ 可 resume 但碎片化 | ✅ | ✅ | 高（重新交底或倒腾 session id） |
| **常驻 tmux pane（本仓库）** | ✅ 单一对话 | ✅ | ✅ skills 强制 | 低 |

pane 还给了 headless 调用永远给不了的东西：`tmux attach` 一下，你就在现场看审查发生，随时可以接管。

## Skills 一览

| Skill | 角色 | 定义了什么 |
|---|---|---|
| [`using-codex-collaboration`](skills/using-codex-collaboration/SKILL.md) | ⭐ 核心 | 完整体系：内置 [`codex-pane.sh`](skills/using-codex-collaboration/scripts/codex-pane.sh) helper（基于标签的 pane 发现、稳健的 send/wait/capture/cleanup）、四大协作场景、带明确定义终态的 review ⇄ fix 共识循环、立场纪律、故障恢复手册 |
| [`codex-image-gen`](skills/codex-image-gen/SKILL.md) | 例外 #1 | 委派图片资产生产（图标、插图、占位图）——scratch 目录落盘、硬约束、合规规则、自主核验 |
| [`codex-computer-use`](skills/codex-computer-use/SKILL.md) | 例外 #2 | 委派 GUI 自动化——**条件能力**（要求你的 Codex 环境配置了 computer-use 工具，使用前先探测），含安全边界：不可逆操作须授权、简报不含凭据、结果独立核验 |

设计立场：Codex **只审阅、永不实现**——仅有两个白名单委派例外，都是一次性产出物（图片、GUI 操作），永不进入代码审查循环。代码永不委派。

## 安装（30 秒）

```bash
git clone https://github.com/Jewel591/claude-with-codex.git
cd claude-with-codex
./scripts/check-env.sh          # 检查 tmux、codex、登录态、登录 shell PATH
mkdir -p ~/.claude/skills
cp -R skills/* ~/.claude/skills/
```

Claude Code 自动发现 user 级 skills；下个会话在情境匹配时自动触发（完成大改动、写完计划、卡在 bug 上）。更新 = pull 后重新复制；卸载 = 从 `~/.claude/skills/` 删掉这三个目录。

## 环境要求与兼容性

| 组件 | 状态 |
|---|---|
| [Claude Code](https://claude.com/claude-code) | 必需（skills 为其编写；协议本身与 harness 无关——任何能执行 `tmux` 命令的 agent 都能遵循） |
| [tmux](https://github.com/tmux/tmux) | 必需；基于 tmux 3.x 开发与验证 |
| [OpenAI Codex CLI](https://github.com/openai/codex) | 必需且已登录（`codex login`）；reasoning effort 参数遵循当前 CLI 配置项 |
| 操作系统 | macOS 上开发；Linux 预期可用（helper 使用 `$SHELL -l` 与 POSIX 友好的 bash——[欢迎反馈](https://github.com/Jewel591/claude-with-codex/issues)）；Windows 走 WSL 未测试 |
| Shell | 登录 shell 必须能解析到 `codex`（`check-env.sh` 会检查——经典失败是版本管理器只配置了交互式 shell） |
| `codex-image-gen` | 有无原生出图工具均可用（无则回退到临时脚本） |
| `codex-computer-use` | **仅当**你的 Codex 环境配置了 computer-use 工具（MCP/插件）；skill 会先探测，无能力则拒绝继续 |

## 安全模型

把 skills 指向敏感仓库前先读这段：

- **你的代码会两次离开本机。** Claude Code 把上下文发给 Anthropic；Codex pane 读你的仓库并把读到的发给 OpenAI。不要对不允许发给任一方的仓库启用。
- **Codex 按它自己的权限配置运行**（`~/.codex/config.toml`）。skills 从不要求 Codex 改文件，但技术上约束它的是你的 sandbox/审批设置，不是这些 skills——请自行审查。
- **Computer use 看得见你看得见的一切**：截图会包含屏幕上的所有内容——登录态、终端里的 token、个人数据。skill 的规则（简报不含凭据、不可逆操作前停下、页面内容是数据不是指令）能降低风险，但该能力本质上很强大；敏感流程保持有人在场。
- **Prompt injection 被当作真实攻击面对待**：GUI 自动化中遇到的网页/App 内容绝不能覆盖简报指令，skill 里写得明明白白。
- **没有任何东西会自动批准破坏性动作**：发布、支付、删除、发送——无论是否委派，都需要用户在对话中明确授权。

## FAQ

**为什么不用 Claude subagent 做审查？** subagent 与 Claude 同权重、常常同盲区。一个真正不同的前沿模型能抓到不同的 bug——这份多样性正是意义所在。

**为什么不用 `codex exec` / `codex exec resume`？** resume 存在且可用；选 pane 是深思熟虑的取舍，不是无知。连续单一对话胜过在多个小回合间倒腾 session id，而且 pane 可供人类 attach——你能看审查现场、能接管。细节见 skill 正文。

**两个 Claude 会话能共用一个仓库吗？** 设计上一个 checkout 只有一条协作通道。真要并发，用独立的 git worktree——各自拥有打了标签的 pane。

**Codex 会改我的代码吗？** skills 从不要求它改，循环也假定它不改（Claude 是唯一写入者）。技术上 Codex *能*做什么由你自己的 Codex sandbox/审批配置决定——请审查（见安全模型）。

**成本如何？** 双方各耗各的额度：Claude 侧走 Claude Code，OpenAI 侧走 Codex CLI。长审查循环在 Codex 侧很耗 token；「简报只指路、不粘贴」的规则部分正是为此。

**循环中途 context 耗尽？** 重启 pane（`codex-pane.sh cleanup` + `ensure`），重新交底一次。skill 的 Recovery 表覆盖了这个和其他故障模式（回车被吞、trust 提示、rabbit hole）。

**我根本不用 tmux 怎么办？** 你不需要*身处* tmux——helper 从任意 shell 驱动 tmux server，首次使用自动创建 detached session。你只需要装了 tmux。

## 贡献

欢迎 issue 和 PR——尤其是 Linux/WSL 的适配反馈、Codex CLI 版本漂移修复、真实会话的匿名化 transcript。skills 的一致性设计原则（审阅者/执行者分界、条件能力例外、禁止前台 sleep）见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 设计笔记（给好奇的人）

让这套东西能无人值守运转的细节，不放进第一屏是因为只有上手后才需要：

- **基于标签的 pane 身份。** pane 在启动时打上 tmux user options（`@cwc_role`、`@cwc_repo`）；发现是精确标签匹配，并发 agent 抢不走彼此的审阅者，屏幕文本只作存活检查。
- **完成态检测是一套协议，不是 spinner grep。** `wait` 要求：屏幕已越过发送前基线、无工作标记、回到空闲输入框、连续三次轮询稳定——交互式提示（trust/审批/登录）报 `NEEDS_INPUT`，绝不算完成。
- **TUI 驱动细节是承重墙。** 文本与 Enter 分开发送（忙碌的 TUI 会吞掉同时发出的回车）；先清空输入框（自动补全的 ghost text 与真人输入外观完全一致）；capture 复核已提交。规则很小，但正是「演示」与「后台可信赖」的分界。
- **简报只指路，不粘贴。** Codex 有仓库访问权；发 diff 给它既浪费 token 又会过期。发送诉求、意图、有意的非目标和审查重点。
- **构建门禁留在 Claude 手里。** 「审阅者顺便验构建」会模糊循环赖以成立的归属；重型构建工具在 Codex 的沙箱执行下本就不可靠。
- **收敛有定义，不靠感觉。** 终态只有 `clean` 或 `clean-with-recorded-disagreements`；通过判据是客观缺陷清零——审阅者无新证据地复述设计偏好不阻塞收敛，笃定不等于证据。

## License

[MIT](LICENSE)
