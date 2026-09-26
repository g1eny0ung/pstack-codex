# pstack-codex迁移与分发计划

状态：已进入实施。2026-09-26用户补充：在指定work目录创建项目，上传GitHub后安装并简单验证调用；不做全量测试。

## 1. 目标与边界

将Cursor pstack中的poteto-mode及其需要的技能迁移为Codex插件`pstack-codex`。保留本地工程工作流，排除云端代理编排，支持公开GitHub仓库分发和ZIP解压安装。

- 手动调用`$poteto-mode`，作用于当前任务；其他技能可单独调用。
- 技能之间可以互相引用，运行时不依赖Cursor内部功能。
- 所有代理默认使用GPT-6 Astra，型号与推理强度分别配置。
- 不改变用户主对话的模型设置，不要求每条回复都另开写作代理。
- 不包含作者个人路径、账号、会话、凭据或个人插件依赖。
- 本次实施交付完整分发仓库、ZIP及本地安装验收结果。GitHub仓库为g1eny0ung/pstack-codex；用户已授权创建并上传。

## 2. 上游基线与迁移范围

| 项目 | 固定值 |
|---|---|
| 上游仓库 | https://github.com/cursor/plugins.git |
| 跟踪分支 | `main` |
| 初始迁移commit | `ecc249f1e306fc64ddf83c7bed16cacf7c2239db` |
| 首次完成迁移时的同步基线 | 同初始迁移commit |
| 插件名、marketplace名 | 均为`pstack-codex` |
| 首版发布版本 | `0.1.0` |

### 2.1 迁移42个skill

| 分组 | 数量 | 技能 |
|---|---:|---|
| 主入口 | 1 | `poteto-mode` |
| 工程原则 | 23 | 上述commit中的全部`principle-*`技能 |
| 分析与协作 | 7 | `how`、`why`、`architect`、`arena`、`swarm`、`interrogate`、`figure-it-out` |
| 记录与复盘 | 2 | `show-me-your-work`、`reflect` |
| 代码与验证 | 4 | `tdd`、`no-comments`、`deslop`、`typescript-best-practices` |
| 写作与操作 | 4 | `technical-writing`、`unslop`、`control-cli`、`control-ui` |
| 配置 | 1 | `setup-pstack` |

`deslop`、`control-cli`、`control-ui`取自同一上游commit的cursor-team-kit；其余技能取自pstack。保留所选技能必要的参考文件和脚本。

迁移原版`poteto-agent`和`Comment Sicko`角色规则，分别放入所属技能的参考目录。调用者通过文件引用让Codex子代理读取规则，不向用户的全局代理目录安装自定义角色。

不迁移以下8个独立入口：`automate-me`、`blast-radius`、`bro`、`create-verification-skill`、`maintain-verification-skill`、`make-bot-ui`、`recall`、`teach`。删除保留技能中仅用于推荐这些入口的安装建议，避免产生失效依赖。

### 2.2 删除云端代理编排

不迁移以下文件和目录：

- `poteto-mode/playbooks/orchestrate.md`
- `poteto-mode/playbooks/autopilot-full.md`
- `poteto-mode/playbooks/autopilot-stack.md`
- `poteto-mode/scripts/orch/`，包括`orch.ts`、`store.ts`和`orch.test.ts`

poteto-mode原有23个playbook保留20个。清理入口、配套模板、引用和脚本中的云端要求：

| 位置 | 调整 |
|---|---|
| `poteto-mode/SKILL.md` | 删除三套云编排入口及云任务接管路由 |
| `swarm` | 改为本地子代理，删除`environment: cloud`和`cloud_base_branch` |
| `shipping.md` | 每个PR仍由独立代理验收，执行位置改为本地隔离工作区 |
| `multi-phase-plan.md` | 主代理按阶段执行，不再选择三套已删除流程；删除云VM、云端唤醒和PR云owner要求 |
| `opening-a-pr.md`、`babysit.md` | 删除云端PR工具分支及Autopilot专属例外 |
| `session-pickup.md`、`pause-safely.md` | 保留本地会话、日志和Git分支接续，删除云任务URL与云端恢复要求 |
| `check-plan.mjs`、`package.json` | 删除云编排模板检查及`orch`测试入口 |

保留本地并行、候选比较、独立审查和分阶段验证。任务场景数量与代理并发数分别处理，按宿主可用槽位分批运行，不把所有并行任务都固定成三个代理。

## 3. 模型与互审规则

### 3.1 默认角色配置

所有实际启动的子代理默认使用`gpt-6-astra`。

| 角色或任务 | 推理强度 |
|---|---|
| `interrogate`审查者A | **`ultra`** |
| `interrogate`审查者B | **`xhigh`** |
| `interrogate`审查者C | **`high`** |
| 写作、改写、文档、PR描述、提交说明 | **`medium`** |
| 一般判断、普通解释、结果整理 | `high` |
| 功能开发、常规重构、修复、性能优化、hillclimb | `high` |
| `how`探索与普通解释、`why`调查取证 | `high` |
| `swarm`普通工作者、常规验证、注释审查 | `high` |
| `reflect`工具使用复盘 | `high` |
| `why`复杂综合、`reflect`判断与综合、执行记录独立审计 | `xhigh` |
| 复杂证据分歧处理、最困难的实现任务 | `xhigh` |
| `arena`和`architect`候选生成 | 默认三个独立候选，各用`high` |
| `arena`和`architect`独立裁判 | `xhigh` |

除三方互审中的一个`ultra`外，不把此前讨论过的其他ultra建议设为默认。

### 3.2 互审行为

1. 确定修改目的、审查范围及需要的上下文。
2. 给三个独立代理相同材料、提示和审查标准，显式传入型号与推理强度。
3. 审查代理只读，不自动修改被审查代码，也不预先看到其他审查者的结论。
4. 主代理合并重复问题，标出共同发现、单独发现和分歧。
5. 根据代码证据和完整上下文判定应修复、值得考虑、仅记录或不成立；不按票数或推理档位决定对错。

保留主动调用`$interrogate`及poteto-mode在存在设计争议时的调用规则，不默认让每次代码修改都触发三方互审。

### 3.3 配置方式

- 插件内`config/models.defaults.json`保存默认值。
- `setup-pstack`管理`${CODEX_HOME:-$HOME/.codex}/pstack-codex/models.json`中的个人覆盖。
- 角色配置分别保存`model`和`reasoning_effort`；审查组合保存三个有序条目。
- 不修改用户全局模型设置，不修改插件安装缓存。
- 使用者可明确选择自己有权限使用的GPT配置；型号或档位不可用时报告具体缺项，不静默替换、降档或谎称已按指定档位审查。

## 4. Codex平台适配

| 原版机制 | 迁移方式 |
|---|---|
| Cursor技能元数据 | 使用Codex支持的frontmatter及`agents/openai.yaml`，所有入口显式调用 |
| `Task`和Cursor代理参数 | 使用Codex子代理启动、等待、补充指令和中断能力 |
| Cursor自定义代理类型 | 子代理读取插件中的角色参考文件 |
| Cursor模型规则文件 | 使用插件默认配置与个人覆盖 |
| 内置`create-skill` | 优先使用宿主的`skill-creator`；缺失时按Codex技能格式提供指导 |
| Cursor聊天记录目录 | 统一使用Codex会话读取辅助脚本 |
| `/loop` | 当前任务持续执行；明确请求持续目标或定时检查时使用Goal或宿主自动化 |
| Cursor工具发现方式 | 使用当前宿主实际提供的工具和接口 |

### 4.1 会话读取

新增`read-thread.mjs`，通过本地`codex app-server`读取指定会话：

- 完成初始化握手，通过`thread/turns/list`和`itemsView: full`分页读取已保存条目。
- 输出关联清楚的消息、工具调用和结果，供`reflect`、`show-me-your-work`、eval及任务接续使用。
- 只调用读取接口，不通过启动或恢复会话来取得历史。
- 明确标记缺失、截断或无法读取的记录，不把摘要当完整记录。
- 不扫描无关会话；完整历史接口不可用时报告该功能的缺项。

当前已验证的CLI版本为`0.158.0-alpha.2.1`。这是调研验证基线，不据此推断所有旧版本或新版本都兼容；发布时记录实际验证版本和所需能力。

### 4.2 worktree与运行状态

- **保留`worktree-audit.sh`的Bash实现，不改写为JavaScript。**
- 修正macOS/Linux/WSL的命令兼容、含空格等特殊路径处理，以及Cursor专用路径。
- 默认分支从Git读取，不固定假设为`origin/main`。
- 审计脚本只检查和报告；Codex托管worktree通过原生工具管理，普通Git worktree使用Git流程。
- 配置与运行状态写到用户或任务运行目录，插件安装目录保持只读。

### 4.3 宿主差异

- 桌面端能力可用时使用原生自动化、会话和托管worktree工具。
- CLI缺少定时自动化时，支持当前进程继续执行和显式恢复，不自行搭建后台调度服务。
- UI验证优先复用项目已有测试工具或使用者可用的浏览器工具，不依赖作者个人的ego-browser等插件。
- `why`使用的Slack、Notion、Linear等连接保持可选，缺少时明确记录证据缺口。
- 某项可选工具缺失只影响对应流程，不阻止其他技能使用。

## 5. 代码、配置与文件改动清单

以下路径以分发仓库根目录为准。未实施的新文件名称在此固定，方便后续落实和审查。

### 5.1 修改原版代码

| 文件 | 语言／工具 | 改动 |
|---|---|---|
| `plugins/pstack-codex/skills/poteto-mode/scripts/watch-pr/watch-pr` | TypeScript | 去掉运行时依赖安装，作为可预打包的PR工具入口 |
| `plugins/pstack-codex/skills/poteto-mode/scripts/check-plan.mjs` | JavaScript＋Node.js | 配合本地多阶段模板，删除云端规则和失效的固定标记 |
| `plugins/pstack-codex/skills/poteto-mode/scripts/worktree-audit.sh` | **Bash＋Git** | 保留语言，修改Cursor依赖、跨平台命令和路径处理 |
| `plugins/pstack-codex/skills/poteto-mode/scripts/package.json` | JSON | 移除`orch`测试任务，增加必要测试和构建命令 |

依赖或构建配置发生变化时同步维护原版`bun.lock`，不无故升级依赖。

### 5.2 新增代码

| 文件 | 语言／工具 | 用途 |
|---|---|---|
| `plugins/pstack-codex/skills/poteto-mode/scripts/read-thread.mjs` | JavaScript＋Node.js | Codex会话读取 |
| `plugins/pstack-codex/skills/poteto-mode/scripts/read-thread.test.ts` | TypeScript＋Bun | 验证分页、缺失记录与接口错误处理 |
| `scripts/upstream.sh` | **Bash＋Git及系统文本工具** | 检查上游更新，准备三方对照材料 |
| `scripts/upstream.test.sh` | Bash＋Git | 验证修改、删除、重命名及同步基线不被误改 |
| `scripts/build.sh` | Bash调用Bun | 打包PR工具和第三方依赖，生成Node.js可运行文件 |
| `scripts/package.sh` | Bash调用压缩工具 | 制作包含marketplace和插件的版本化ZIP |

生成的PR工具为`plugins/pstack-codex/skills/poteto-mode/scripts/dist/watch-pr.mjs`，由Node.js运行。

**不新增**`check-plan.test.ts`或`worktree-audit.test.ts`；**不创建**`worktree-audit.mjs`。上游追踪不使用Python或JavaScript实现。

### 5.3 保留与删除

- 保留`watch-pr/`中的`cli.ts`、`github.ts`、`policy.ts`、`render.ts`、`types.ts`及原有测试，除迁移所必需的接口修正外不改业务逻辑。
- 保留`watch-pr/cli.test.ts`、`github.test.ts`、`policy.test.ts`、`fakes.test-helper.ts`、`types.compile.ts`。
- 保留`skills/show-me-your-work/scripts/log.sh`。
- 删除`bootstrap.ts`的运行时安装机制，发布前完成依赖打包。
- 删除专属云编排的`scripts/orch/`，不迁移其他pstack自动化配置。

### 5.4 新增配置与文档

| 文件 | 格式 | 用途 |
|---|---|---|
| `.agents/plugins/marketplace.json` | JSON | GitHub及本地目录安装目录 |
| `plugins/pstack-codex/.codex-plugin/plugin.json` | JSON | Codex插件描述与版本 |
| 各技能的`agents/openai.yaml` | YAML | 展示信息与显式调用策略 |
| `plugins/pstack-codex/config/models.defaults.json` | JSON | 默认角色模型配置 |
| `upstream.lock.json` | JSON | 初始迁移与最近同步commit |
| `UPSTREAM.md` | Markdown | 文件对应关系、排除项、迁移规则与同步记录 |
| `README.md` | Markdown | 安装、依赖、配置、调用、升级、回退与卸载说明 |

### 5.5 开发工具与使用者依赖

| 阶段／功能 | 工具 |
|---|---|
| 加载技能、执行代理流程 | 支持插件和子代理的Codex |
| Node辅助脚本 | Node.js 22或更新版本 |
| Bash脚本与Git工作流 | Bash、Git及系统基础命令 |
| GitHub功能 | 使用者自己登录的`gh` |
| 浏览器、交互式CLI验证 | 项目或宿主相应工具，按功能使用 |
| 开发构建和原版测试 | Bun、TypeScript编译器 |
| 格式校验 | Codex自带的`quick_validate.py`和`validate_plugin.py`，使用Python |

Bun和两个Python校验器仅用于开发维护，不作为插件使用者运行技能的依赖。发布物不在用户机器上执行`bun install`，也不要求用户安装npm依赖。

## 6. 分发、安装与升级

分发仓库在用户指定的work目录下以`pstack-codex/`构建，结构为：

```text
.agents/plugins/marketplace.json
plugins/pstack-codex/
  .codex-plugin/plugin.json
  config/models.defaults.json
  skills/
scripts/
  upstream.sh
  upstream.test.sh
  build.sh
  package.sh
upstream.lock.json
UPSTREAM.md
README.md
```

### 6.1 两种安装方式

GitHub安装：

```bash
codex plugin marketplace add <GitHub仓库地址>
codex plugin add pstack-codex@pstack-codex
```

ZIP安装：先解压整个分发仓库，再执行：

```bash
codex plugin marketplace add <解压后的仓库目录>
codex plugin add pstack-codex@pstack-codex
```

尖括号部分由使用者替换为实际值。ZIP保留隐藏的manifest和marketplace目录；不宣称支持直接拖入ZIP安装。安装后启动新会话使用。

### 6.2 发布约定

- GitHub仓库与ZIP使用相同内容和版本，manifest版本、Git标签及ZIP名称对应一致。
- ZIP包含预构建PR工具和所需资源，不包含个人记录、凭据、开发缓存或`node_modules`目录。
- 插件内路径相对解析，支持解压到含空格的目录。
- 升级通过刷新marketplace并重新安装完成，保留个人模型配置；回退使用对应历史Release。
- 保留pstack的Lauren Tan版权声明、cursor-team-kit的Cursor版权声明及两份MIT许可证；打包第三方依赖时保留其必要声明。
- 首版不包含向官方公共插件目录提交上架申请。

支持目标为macOS、Linux和Windows WSL；原生Windows不列为已支持。发布说明分别记录实测环境与未实测环境，不用支持目标替代验证结果。

## 7. 上游追踪与增量同步

### 7.1 固定记录

`upstream.lock.json`保存以下固定字段：

```json
{
  "repository": "https://github.com/cursor/plugins.git",
  "branch": "main",
  "initial_commit": "ecc249f1e306fc64ddf83c7bed16cacf7c2239db",
  "last_synced_commit": "ecc249f1e306fc64ddf83c7bed16cacf7c2239db"
}
```

初始commit不变；最近同步commit仅在完整验证后更新。Bash脚本处理本项目固定结构的锁文件，并用Git验证commit，不引入Python、Node.js或额外JSON解析器作为上游追踪依赖。

### 7.2 检查进度

```bash
bash scripts/upstream.sh check
```

- 获取远端信息，比较`last_synced_commit`与`main`。
- 跟踪整个`pstack/`、已选的三个cursor-team-kit技能目录及相关许可证。
- 输出目标commit、相关提交、文件增删改，并区分已迁移功能、已排除云功能和新增／范围外功能。
- 可以更新维护者的Git缓存，但不修改插件源文件或同步基线。
- 默认按需运行，不创建定时检查任务。

### 7.3 准备同步

```bash
bash scripts/upstream.sh prepare --commit <SHA>
```

固定目标commit，在维护工作目录准备三方对照：上次同步的上游内容、目标commit的上游内容、当前Codex迁移版内容。同步材料不进入插件安装包。

脚本负责准备材料，不自动覆盖插件。后续逐项合入更新：

1. 合入已迁移功能的有效修复与改进。
2. 保留Codex接口适配、Bash脚本选择和当前模型配置。
3. 持续排除云端编排；新增skill先报告，不自动扩大范围。
4. 检查删除、重命名、依赖变化和失效引用。
5. 验证通过后更新`last_synced_commit`及`UPSTREAM.md`，再发布新版本。
6. 中断或失败时保留旧基线，不能把“检查到了更新”写成“已经完成同步”。

## 8. 原计划验证范围（本次以简单验收覆盖）

本次按用户最新指令，仅做必要静态／构建检查和Codex安装、调用验证。下表保留原设计供维护者参考，不表示本次全部运行。实际结果见validation.md。

按以下范围验证，避免为低影响辅助脚本建立额外测试体系。

| 项目 | 验证方式 |
|---|---|
| 技能、插件和marketplace结构 | 使用现有校验工具；检查42个技能及引用完整性 |
| Cursor与云端依赖清理 | 扫描实际接口、路径和被删除流程的引用；许可证、来源说明和识别GitHub机器人名称不作为依赖误报 |
| 原版PR工具 | 运行已有测试和类型检查，验证打包后的Node入口可用 |
| `check-plan.mjs` | 直接用合格、不合格样例运行确认，不新增独立测试文件 |
| **`worktree-audit.sh`** | **仅做`bash -n`语法检查和一次正常运行确认；不搭临时Git仓库，不做专门多场景或多平台测试** |
| `read-thread.mjs` | 保留`read-thread.test.ts`，覆盖分页不漏读、不重复及缺失／错误结果；做一次实际只读调用确认 |
| `upstream.sh` | 保留`upstream.test.sh`，用临时Git仓库验证差异、删除重命名和基线保护；该测试不用于worktree审计 |
| 模型与互审 | 在隔离示例任务中核对实际启动参数为Astra的`ultra/xhigh/high`，检查独立、只读及证据判断行为 |
| 整体工作流 | 验证普通修复、候选比较和暂停接续；PR流程优先使用现有测试与只读数据，不为验收创建或合并真实PR |
| 安装与发布 | 在不带作者个人配置的测试环境中验证ZIP目录安装、只读安装目录和个人配置保留；已有公开仓库后再验证GitHub安装路径 |

只在相关代码发生变化、检查失败或存在未解决问题时增加验证。记录实际运行过的命令与结果，不把计划中的测试写成已通过。

## 9. 实施顺序与交付物

1. 建立分发仓库和Codex插件结构，写入来源与commit记录。
2. 按42个技能清单复制必要内容，排除云端编排及无关入口。
3. 统一Codex工具调用、角色参考和模型配置。
4. 修改现有脚本，新增会话读取和Bash上游追踪工具。
5. 完成发布构建与ZIP打包，保留依赖声明及许可证。
6. 按第8节完成必要验证，修复发现的问题。
7. 在本机安装验收，交付可公开分发的产物；按用户本轮授权上传公开GitHub仓库。

最终交付：

- 完整分发仓库`pstack-codex/`。
- 版本化安装包`pstack-codex-0.1.0.zip`。
- 安装、配置、使用、升级、回退与卸载说明。
- 上游锁文件、来源和同步记录。
- 验证报告，区分已通过、未运行和受环境限制的项目。
