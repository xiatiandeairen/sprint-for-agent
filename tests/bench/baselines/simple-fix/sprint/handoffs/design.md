## Conclusion

Hybrid 测试架构：bats 单测测 bash 脚本逻辑；Python 基准 runner 驱动 sprint headless 跑完整流水线，对比**产物**（state.json / handoffs / metrics.log / anchors.txt）+ LLM judge 打分软指标。不测 LLM 行为轨迹本身。

## Solution Approach

- **Form**: Automation + Asset
- **Path**: `tests/unit/*.bats` + `tests/bench/*.py` + `Makefile`；不改 sprint 流程代码
- **核心洞察**: sprint 是 AI 驱动 skill，测产物（确定性）而非运行时（不确定性）

## Design Content

### 分层架构
```
tests/unit/   → 测 scripts/*.sh        (bats-core)
tests/bench/  → 驱动 sprint + 比产物    (Python)
依赖方向: tests/* → scripts/*, $SPRINT_HOME/*
禁止: scripts/* → tests/*
禁止: tests/bench/* → tests/unit/*
```

### 基准主路径
```
make bench → runner.py
  (create temp SPRINT_HOME → claude headless /sprint {desc}
   → 按 fixture.replies 应答 → 捕获产物)
→ compare.py (structural diff vs baseline)
→ judge.py (LLM 5 维评分 vs baseline judge report)
→ summary.md + exit 0/1
```

### Baseline Drift 策略
| 字段 | 策略 |
|------|------|
| state.json {id, created_at, base_commit} | ignore |
| state.json {stages, desc, type, status} | strict |
| metrics.log 事件计数（per type） | strict |
| anchors.txt 行数 + 类型分布 | strict |
| handoffs/*.md section 标题清单 | strict |
| handoffs/*.md 正文 | semantic（LLM judge） |

### LLM Judge 维度
| 维度 | 含义 | 0-5 分 |
|------|------|--------|
| clarity | 用户可见输出信息密度 / 可读性 | ≥3 |
| term-hygiene | 不泄漏内部术语（比 `interaction-terms.md`） | ≥4 |
| decisiveness | 推荐明确 / 无兜底词 | ≥3 |
| scope-discipline | 不越界 / 不过度推演 | ≥3 |
| handoff-quality | 结构完整 / downstream 可消费 | ≥3 |

单维下滑 ≥2 分相对 baseline → FAIL。

### 核心接口
```python
@dataclass
class Fixture:  name: str; description: str; replies: list[Reply]; timeout_sec: int = 900
@dataclass
class Reply:    match: str; reply: str
@dataclass
class RunArtifacts: sprint_dir: Path; stdout_log: Path; duration_sec: float; exit_code: int

def run_sprint(fixture: Fixture, workdir: Path) -> RunArtifacts
def compare(art: RunArtifacts, baseline_dir: Path) -> DiffReport
def judge(art: RunArtifacts, baseline_judge: Path | None) -> JudgeReport
```

### AI 提议的 sprint 核心设计清单（单测覆盖目标）

覆盖 `scripts/sprint-ctl.sh` 中的决策逻辑：

1. `evaluate`: 3 个 0/1 参数 → stages 列表映射；关键词覆写（delete/migrate/payment 等 → RISK=1）；auto 标志传递
2. `create`: 生成 ID 唯一性；state.json schema 字段完整；stages JSON 数组结构
3. `activate`: base_commit 捕获（git / 非 git 环境回退到 "none"）
4. `stage`: status 转换合法性（running → completed）；current_stage 更新；metrics.log 追加格式
5. `end`: summary.json 追加；duration 计算；anchor 统计从 metrics.log 聚合
6. `report`: 聚合 / 单 sprint 输出；HINTS 生成条件
7. `list`: 输出稳定性

覆盖 `scripts/anchor-check.sh`（9 种规则）：
- `MUST_EXIST` / `MUST_NOT_EXIST`: 文件存在性
- `MUST_BUILD`: 命令 exit 0
- `MUST_TEST`: 测试命令 exit 0
- `MUST_IMPORT` / `MUST_NOT_IMPORT`: grep 语义
- `MUST_CONTAIN` / `MUST_NOT_CONTAIN`: `grep -qF` 固定字符串
- `FILE_NOT_MODIFIED`: git diff 对 base_commit

每条规则：1 个 PASS 用例 + 1 个 FAIL 用例 + 1 个边界（空文件 / 不存在路径 / 二进制）。

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| create | `Makefile` | `test` / `bench` / `bench-update` / `bench-judge` targets |
| create | `tests/README.md` | 用法、依赖安装、fixture 添加流程 |
| create | `tests/unit/helpers.bash` | 临时 SPRINT_HOME / fixture 工具 / 断言宏 |
| create | `tests/unit/test_sprint_ctl.bats` | sprint-ctl 7 个子命令 |
| create | `tests/unit/test_anchor_check.bats` | 9 种 anchor 规则 |
| create | `tests/bench/pyproject.toml` | deps: anthropic, pyyaml, deepdiff |
| create | `tests/bench/runner.py` | headless sprint driver |
| create | `tests/bench/compare.py` | structural diff |
| create | `tests/bench/judge.py` | LLM judge |
| create | `tests/bench/fixtures/simple-fix/input.yaml` | fixture 1 |
| create | `tests/bench/fixtures/design-heavy/input.yaml` | fixture 2 |
| create | `tests/bench/fixtures/doc-mode/input.yaml` | fixture 3 |
| create | `tests/bench/baselines/{fixture}/` × 3 | 各 fixture 的基线 |
| modify | `.gitignore` | `tests/bench/reports/` |
| do-not-touch | `scripts/*.sh` | sprint 流程代码 |
| do-not-touch | `skills/sprint/*.md`, `stages/*.md`, `SKILL.md` | sprint 行为定义 |

## Suggested Task Boundaries

| # | Task | Files | 独立性 |
|---|------|-------|--------|
| 1 | 单测骨架 + sprint-ctl 单测 | `tests/unit/helpers.bash`, `tests/unit/test_sprint_ctl.bats`, `Makefile` | `make test` 独立验证 |
| 2 | anchor-check 单测 | `tests/unit/test_anchor_check.bats` | bats 独立 target |
| 3 | 基准 runner 骨架 + 1 fixture | `tests/bench/runner.py`, `tests/bench/pyproject.toml`, `tests/bench/fixtures/simple-fix/` | `python -m runner simple-fix` 抓产物 |
| 4 | compare 工具 + baseline 1 份 | `tests/bench/compare.py`, `tests/bench/baselines/simple-fix/` | 独立产 DiffReport |
| 5 | LLM judge | `tests/bench/judge.py` | 独立评分 |
| 6 | 补 fixture × 2 + baseline | `tests/bench/fixtures/design-heavy/`, `tests/bench/fixtures/doc-mode/`, baselines | 独立 fixture run |
| 7 | Makefile 入口 + README + gitignore | `Makefile`, `tests/README.md`, `.gitignore` | 手验 `make test` / `make bench` |

## Constraints

- 不改 `scripts/*.sh` 的行为（单测必须对当前实现绿）
- 不改 `skills/sprint/*.md` / `stages/*.md`
- 基准 runner 必须能脱机开发（mock claude CLI 用于骨架 Task 3，真实接入放 Task 4+）
- Python 版本 ≥3.10（dataclass + TypeAlias）

## Decision Register

| # | Decision | Cat | Status | Conclusion |
|---|----------|-----|--------|------------|
| 1 | 双层架构（单测 + 基准）| core | ✓ | brainstorm 已定 |
| 2 | 单测用 bats-core | core | ✓ | bash 脚本原生，零跨界 |
| 3 | 基准 runner 用 Python | core | ✓ | LLM SDK + 结构化 diff 更自然 |
| 4 | 测 sprint 产物而非运行时 | core | ✓ | 规避 AI 不确定性 |
| 5 | Baseline diff 分字段策略 | core | ✓ | 结构 strict / 内容 LLM judge |
| 6 | LLM judge 5 维 | core | ✓ | clarity/term-hygiene/decisiveness/scope-discipline/handoff-quality |
| 7 | fixture 格式 yaml + replies 序列 | core | ✓ | 驱动 sprint 需模拟多轮用户 |
| 8 | headless 驱动：claude CLI vs SDK | detail | ○ | Task 3 两种都试，选稳的 |
| 9 | 初版 fixture 3 个 | detail | ✓ | simple-fix / design-heavy / doc-mode |
| 10 | judge 模型选择 | detail | ○ | Task 5 A/B 测 Haiku vs Sonnet |
| 11 | Makefile（非 justfile）| detail | ✓ | 零依赖 |

## Spec Preferences
- scope: precise
- depth: root-cause
- transition: direct
- compatibility: strict

## Downstream

plan 阶段需要：
1. 按 7 个 task 切分，确认并发 / 串行关系（Task 1/2 串行同一个 helpers.bash；Task 3/4/5 串行依赖；Task 6 依赖 Task 3-5 稳定；Task 7 最后）
2. 每个 task 产出 anchors（MUST_EXIST / MUST_BUILD / MUST_TEST）
3. 预估模型：Task 1/2/3 sonnet；Task 4/5 opus（diff 策略 + judge prompt 需推理）；Task 6/7 sonnet

## 自动审视

### 自动审视 — `D2-solution-approach`：方案选择（Hybrid: bats + Python）

- **决策**: 选 Hybrid —— bats 单测测 bash 脚本，Python 基准 runner + LLM judge；未选纯 bash 或纯 Python
- **绑定原则**: `simplicity` + `cost-first` + `reversibility`
- **原则对照**:
  - `simplicity`: partial — 两种语言栈增加了环境依赖（bats + python），但各自在其域内最简；纯 bash 写 JSON diff + LLM API 会反而复杂
  - `cost-first`: ✓ — bats 测 bash 脚本零桥接；Python 有 anthropic/deepdiff 生态，baseline diff + LLM judge 是现成能力
  - `reversibility`: ✓ — 新增 `tests/` 独立目录，删除即回滚，不影响 `scripts/` 和 `skills/`
- **G1 失败归因**: 若事后失败，最可能违反 `simplicity`，因为双栈意味着贡献者要懂两套测试框架；若社区 PR 只补一边另一边易漂移
- **G2 被拒备选**:
  - `纯 bash（bats + bash bench runner）` — 违反 `cost-first` — JSON diff 在 bash 里用 jq 拼接，LLM API 要 curl+jq 解析，开发成本高
  - `纯 Python（pytest + pytest 调 bash 脚本）` — 违反 `consistency` — 测 bash 脚本要包一层 subprocess，失去 bats 的 run/assert 原语，断言颗粒度下降
- **G3 清单外风险**: 除绑定原则外，本决策最可能被忽视的风险是**测试与生产的语言漂移成本**（非 `simplicity`/`cost-first`/`reversibility` 维度），因为若未来 `scripts/` 重写为非 bash（如迁移到 Python/Rust），`tests/unit/` 的 bats 投资要整层重做

### 自动审视 — `D3-design-decisions`：设计决策集合

- **决策**: 测 sprint 产物（state.json / handoffs / metrics.log / anchors.txt）而非运行时轨迹；baseline diff 分字段 strict/ignore/semantic；LLM judge 5 维评分作为软指标门禁
- **绑定原则**: `first-principles` + `simplicity` + `consistency` + `cost-first`
- **原则对照**:
  - `first-principles`: ✓ — sprint 是 AI 驱动（非确定性），但产物格式（sprint-ctl 写入）是确定性的；从"只能测确定的东西"这条根本事实反推
  - `simplicity`: ✓ — 没有录制/回放框架，没有 mock AI，就是"跑完抓文件对比"
  - `consistency`: ✓ — baseline schema 和 SKILL.md 已有 Data Schemas 对齐，drift 规则直接引用这些 schema
  - `cost-first`: partial — LLM judge 每次跑要 API 费用；3 fixture × 5 维 × 2 次对比 ≈ 每次 bench ~$0.02（Haiku），每日迭代可接受但需意识到
- **G1 失败归因**: 若事后失败，最可能违反 `first-principles`，因为如果 sprint 流程本身升级（stage 文件改版），产物 schema 变化会让 baseline 大规模失效；"测产物"依赖产物 schema 稳定这一事实
- **G2 被拒备选**:
  - `录制 AI 对话回放测试` — 违反 `simplicity` — 需要 fixture 记录每一轮 AI 输出完整文本，维护成本极高
  - `只做单测不做基准` — 违反 `value-proof` — 用户明确要求"黑盒 task 级多维度"，跳过基准等于漏需求
  - `只做基准不做单测` — 违反 `first-principles` — bash 脚本逻辑错误（如 evaluate 参数反转）基准也会绿（LLM 会自适应），需单测堵底层
- **G3 清单外风险**: 除绑定原则外，本决策最可能被忽视的风险是**基线维护负担**（非 `first-principles`/`simplicity`/`consistency`/`cost-first` 直接覆盖的维度），因为每次 sprint 流程演进（任何一个 stage.md 改语气/加字段）都要求手动 `make bench-update` 刷 baseline，若贡献者忘记更新会导致一大批假 FAIL 堵 CI

### 自动审视 — `D4-system-design`：系统设计（架构 + 核心流程 + 接口）

- **决策**: 两层 `tests/unit/` 与 `tests/bench/` 独立；基准主路径 runner→compare→judge 三段串行；Python dataclass 定义 Fixture/RunArtifacts/DiffReport/JudgeReport 四个跨模块契约
- **绑定原则**: `minimal-abstraction` + `consistency` + `blast-radius`
- **原则对照**:
  - `minimal-abstraction`: ✓ — 没有基类、没有 plugin 系统；4 个 dataclass 只做"把数据从 A 传到 B"，没有无必要的 Protocol/ABC
  - `consistency`: ✓ — baseline 文件命名与 `$SPRINT_HOME/projects/.../{id}/` 镜像（state.json / handoffs/ / metrics.log），读者不用学新结构
  - `blast-radius`: ✓ — 禁止 `scripts/* → tests/*` 反向依赖；`tests/bench/*` 独立于 `tests/unit/*`；单测挂了不影响基准开发
- **G1 失败归因**: 若事后失败，最可能违反 `minimal-abstraction`，因为一旦有人要加第 4/5 个 fixture 维度（如多平台、多 shell），会被诱惑把 runner/compare/judge 抽成插件架构；这会把原本 3 函数变成 3 层继承体系
- **G2 被拒备选**:
  - `把 compare + judge 合并为一个 evaluate.py` — 违反 `blast-radius` — 两种 diff（结构 vs 语义）职责混在一起，改 LLM prompt 会触碰 structural diff 代码
  - `fixture 用 pytest parametrize 自动发现` — 违反 `consistency` — 与 baseline 目录结构 1:1 对应更直观，parametrize 反而多一层间接
- **G3 清单外风险**: 除绑定原则外，本决策最可能被忽视的风险是**fixture 驱动超时失控**（非 `minimal-abstraction`/`consistency`/`blast-radius` 覆盖的维度），因为 replies 序列按 stdout pattern 匹配触发，若 AI 输出的文案漂移（哪怕一个换行位置）会导致 replies 卡住超时；需要 runner 有"超时即 dump 最后 N 行 stdout"的调试输出
