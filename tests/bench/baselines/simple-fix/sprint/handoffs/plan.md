## Execution Mode
Step-by-step，commit per task。依赖：1↔2 独立；3→4→5 串行；6 依赖 3；7 最后。

## Commit Preference
每 task 单独 commit；anchor-check 在每 task 末尾跑部分相关项；最后一次全量校验。

## Spec Preferences
- scope: precise
- depth: root-cause
- transition: direct
- compatibility: strict
- test: thorough（本任务本身是测试体系）
- dependency: external（引入 anthropic SDK、bats-core、deepdiff，均在 tests/ 下隔离）

## Decision Points
跳过（Step 2 gated — 新增独立 `tests/` 目录，零兼容性/数据风险）。

## Tasks

### Task 1: 单测骨架 + sprint-ctl 单测
- **Model**: sonnet — 多文件但单模块
- **Files**:
  - create: `tests/unit/helpers.bash`（临时 SPRINT_HOME、assert 宏、git fixture 工具）
  - create: `tests/unit/test_sprint_ctl.bats`（evaluate/create/activate/stage/end/list/report 7 个子命令）
  - create: `Makefile`（`test:` target：`bats tests/unit/`）
- **Steps**:
  1. 写 helpers.bash（setup/teardown 隔离 HOME 与 SPRINT_HOME）
  2. 写 7 组用例，每组 PASS + 1-2 个边界
  3. `make test` → FAIL（bats 或路径问题）则调试至 PASS
  4. commit
- **AI verify**: `bats tests/unit/test_sprint_ctl.bats` exit 0；`anchor-check` 对本 task 相关的 MUST_EXIST / MUST_CONTAIN Makefile test:
- **User verify**: [ ] `make test` 本机能跑 [ ] 读 3-5 条断言是否直指逻辑

### Task 2: anchor-check 单测
- **Model**: sonnet
- **Files**:
  - create: `tests/unit/test_anchor_check.bats`（9 种规则 × 每种 PASS+FAIL+边界）
- **Steps**:
  1. 构造临时仓库（helpers.bash 扩 git_fixture 工具）
  2. 每种规则写 3 个用例
  3. `make test` → PASS
  4. commit
- **AI verify**: `bats tests/unit/test_anchor_check.bats` exit 0
- **User verify**: [ ] 9 种规则每种至少 3 用例 [ ] 故意改一条 anchor 行，测试 FAIL

### Task 3: 基准 runner 骨架 + 1 fixture
- **Model**: sonnet
- **Files**:
  - create: `tests/bench/pyproject.toml`（deps: anthropic, pyyaml, deepdiff）
  - create: `tests/bench/runner.py`（Fixture/Reply/RunArtifacts dataclass + run_sprint 函数；骨架阶段 mock `claude` 调用，真实集成留注释）
  - create: `tests/bench/fixtures/simple-fix/input.yaml`（description + replies 序列）
- **Steps**:
  1. pyproject 写死 deps，`uv` or `pip install -e .` 本地可安装
  2. runner.py 实现：临时 SPRINT_HOME → subprocess 调 `claude`（骨架阶段可 `echo` 代替）→ 捕获产物
  3. `python -m tests.bench.runner simple-fix` → 产生 reports/simple-fix/{ts}/
  4. commit
- **AI verify**: `python -m tests.bench.runner --dry-run simple-fix` exit 0；`tests/bench/pyproject.toml` 包含 "anthropic"
- **User verify**: [ ] fixture input.yaml 可读 [ ] reports 目录结构与 $SPRINT_HOME 镜像

### Task 4: compare 工具 + baseline
- **Model**: opus — drift 策略需推理
- **Files**:
  - create: `tests/bench/compare.py`（按 design drift 表实现字段级 diff）
  - create: `tests/bench/baselines/simple-fix/`（首次运行产物复制过来作基线）
- **Steps**:
  1. compare.py 实现 DiffReport dataclass + compare(art, baseline_dir)
  2. ignore 字段 / strict 字段 / semantic 字段（semantic 段留空 dict，judge 填）
  3. 跑 Task 3 runner 产出 → cp 到 baselines/
  4. 改动 state.json 某字段模拟回归 → compare 输出 FAIL
  5. commit
- **AI verify**: `python -m tests.bench.compare simple-fix` 对 baseline 自比 PASS；故意 mutate → FAIL
- **User verify**: [ ] drift 表全部覆盖 [ ] FAIL 消息定位到具体字段

### Task 5: LLM judge
- **Model**: opus — judge prompt 设计需推理
- **Files**:
  - create: `tests/bench/judge.py`（5 维 prompt + anthropic SDK 调用 + JudgeReport）
- **Steps**:
  1. 定义 JudgeReport / Score dataclass
  2. 编写单一 prompt 模板（读 handoffs 全文 → 返回 JSON 5 维分数 + 理由）
  3. 使用 prompt caching（读 interaction-terms.md 等静态上下文）
  4. A/B 测 Haiku vs Sonnet：同 fixture 跑各 3 次，看 variance
  5. 选定模型，固化到 judge.py
  6. commit
- **AI verify**: `python -m tests.bench.judge simple-fix` 输出合法 JSON 5 维 scores；`ANTHROPIC_API_KEY` 缺失时给清晰错误
- **User verify**: [ ] 故意在 handoff 插入"尽量/大概"→ term-hygiene 分必须下滑 [ ] A/B 结果你认可所选模型

### Task 6: 补 fixture × 2
- **Model**: sonnet
- **Files**:
  - create: `tests/bench/fixtures/design-heavy/input.yaml`
  - create: `tests/bench/fixtures/doc-mode/input.yaml`
  - create: `tests/bench/baselines/design-heavy/`、`tests/bench/baselines/doc-mode/`
- **Steps**:
  1. 设计 design-heavy fixture（触发 brainstorm + design + plan + execute）
  2. 设计 doc-mode fixture（关键词"tech"/"prd"触发 doc mode，skip plan）
  3. runner 各跑一次 → 落 baseline
  4. commit
- **AI verify**: 3 个 fixture 全部 compare PASS
- **User verify**: [ ] 3 fixture 覆盖主要流水线变体

### Task 7: 入口收尾 + README + .gitignore
- **Model**: sonnet
- **Files**:
  - modify: `Makefile`（追加 `bench:` / `bench-update:` / `bench-judge:` targets）
  - create: `tests/README.md`（安装、运行、添加 fixture、更新 baseline 流程）
  - modify: `.gitignore`（追加 `tests/bench/reports/`）
- **Steps**:
  1. 追加 Makefile targets
  2. README 四段：Prereq / Run / Add fixture / Update baseline
  3. .gitignore 追加
  4. 全量 anchor-check
  5. commit
- **AI verify**: 全部 25 条 anchor PASS；`make test` + `make bench FIXTURE=simple-fix` 均 exit 0
- **User verify**: [ ] README 按步骤可跑通 [ ] reports/ 不进 git

## Expected Files
- create: Makefile, tests/README.md, .gitignore(modify), tests/unit/{helpers.bash, test_sprint_ctl.bats, test_anchor_check.bats}, tests/bench/{pyproject.toml, runner.py, compare.py, judge.py}, tests/bench/fixtures/{simple-fix,design-heavy,doc-mode}/input.yaml, tests/bench/baselines/{simple-fix,design-heavy,doc-mode}/
- modify: .gitignore, Makefile (Task 7 追加)
- total new files: ~16

## Downstream

execute 按 7 个 task 顺序跑；Task 3-5 若 `claude` CLI headless 行为不稳，允许降级为 SDK 调用（design Decision #8 留 ○）；Task 5 若两种模型区分度都不足，升级 maxprompt 或加 rubric anchor。

## 自动审视

### 自动审视 — `D5-task-split`：任务切分（7 个 task，依赖 1↔2 / 3→4→5 / 6 / 7）

- **决策**: 7 task 串并结合切分 —— 单测两 task 并行独立；基准三件套（runner/compare/judge）强串行；收尾 task 最后做全量校验；未合并 Task 1+2，也未拆 Task 4
- **绑定原则**: `independence` + `reversibility`
- **原则对照**:
  - `independence`: ✓ — 每 task 有独立 verify handle：Task 1/2 分别 bats 单文件绿；Task 3 `runner --dry-run` exit 0；Task 4 compare 自比 + mutate；Task 5 judge JSON 合法性；Task 6 3 fixture compare 全绿；Task 7 全量 anchor-check
  - `reversibility`: ✓ — 每 task commit per task，任何一 task 回退只影响自己；`tests/` 目录与 `scripts/`/`skills/` 物理隔离，不波及主流程
- **G1 失败归因**: 若事后失败，最可能违反 `independence`，因为 Task 4 的 compare 实现严重依赖 Task 3 的产物 schema —— 若 Task 3 产物字段与 design drift 表漂移，Task 4 会连锁返工；"串行依赖"本身弱化了真正的独立性
- **G2 被拒备选**:
  - `把 Task 3+4+5 合并成一个大 task`（基准三件套一起上）— 违反 `reversibility` — L 升 XL，失败回滚颗粒变粗，无法定位是 runner 还是 judge 出问题
  - `把 Task 1+2 合并` — 违反 `independence` — 两个测试集覆盖不同脚本，合并后单测失败要查两处
  - `把 Task 6 拆成两 task（每个 fixture 一个）` — 违反 `simplicity`（隐性考量）— 两个 fixture 共享 runner/compare 接口，拆只会多一次 commit 开销
- **G3 清单外风险**: 除绑定原则外，本决策最可能被忽视的风险是**Task 5 的 LLM 成本与速率限制**（非 `independence`/`reversibility` 覆盖的维度），因为 judge A/B 测试 × 2 模型 × 3 次/fixture = 每轮 ≥6 次 API 调用，开发阶段反复迭代 prompt 会撞 rate limit；需要在 judge.py 加可重试 / 降级到 mock 的开关
