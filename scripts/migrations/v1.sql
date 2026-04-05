-- Sprint DB Schema v1

CREATE TABLE IF NOT EXISTS schema_meta (
    version     INTEGER NOT NULL,
    migrated_at TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
INSERT INTO schema_meta (version) VALUES (1);

-- ═══════════════════════════════════
-- Sprint 主表
-- ═══════════════════════════════════

CREATE TABLE IF NOT EXISTS sprints (
    id          TEXT PRIMARY KEY,                -- YYYYMMDD-HHmmss
    dir_name    TEXT NOT NULL,                   -- YYYYMMDD-HHmm-简述-id
    description TEXT NOT NULL,
    type        TEXT NOT NULL CHECK (type IN ('simple', 'medium', 'complex', 'long', 'auto')),
    mode        TEXT NOT NULL DEFAULT 'auto' CHECK (mode IN ('auto', 'step-by-step')),
    status      TEXT NOT NULL DEFAULT 'created'
                CHECK (status IN ('created', 'running', 'failed', 'retrying', 'stopped', 'completed', 'archived')),
    base_commit TEXT,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- ═══════════════════════════════════
-- 阶段评估（替代 sprint_scoring）
-- 记录每个阶段为什么需要/不需要
-- ═══════════════════════════════════

CREATE TABLE IF NOT EXISTS sprint_stage_eval (
    sprint_id TEXT NOT NULL REFERENCES sprints(id),
    stage     TEXT NOT NULL,
    needed    INTEGER NOT NULL,                  -- 1=需要, 0=不需要
    reason    TEXT NOT NULL,                      -- 一句话理由
    PRIMARY KEY (sprint_id, stage)
);

-- ═══════════════════════════════════
-- 流水线阶段
-- ═══════════════════════════════════

CREATE TABLE IF NOT EXISTS sprint_stages (
    sprint_id    TEXT    NOT NULL REFERENCES sprints(id),
    stage        TEXT    NOT NULL,
    seq          INTEGER NOT NULL,
    status       TEXT    NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending', 'running', 'completed', 'failed', 'skipped')),
    params       TEXT,                           -- JSON, 阶段参数
    started_at   TEXT,
    completed_at TEXT,
    PRIMARY KEY (sprint_id, stage)
);

-- ═══════════════════════════════════
-- Chunk 执行追踪
-- execute 阶段的每个 chunk 一行
-- ═══════════════════════════════════

CREATE TABLE IF NOT EXISTS sprint_chunks (
    sprint_id    TEXT    NOT NULL REFERENCES sprints(id),
    chunk_num    INTEGER NOT NULL,
    description  TEXT,
    budget       INTEGER,                        -- diff 预算
    status       TEXT    NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending', 'running', 'completed', 'failed', 'skipped', 'reverted')),
    diff_lines   INTEGER DEFAULT 0,
    files_changed INTEGER DEFAULT 0,
    test_count   INTEGER DEFAULT 0,
    test_added   INTEGER DEFAULT 0,
    commit_hash  TEXT,
    started_at   TEXT,
    completed_at TEXT,
    PRIMARY KEY (sprint_id, chunk_num)
);

-- ═══════════════════════════════════
-- Gate 结果
-- 每个 chunk 的 gate 运行记录
-- ═══════════════════════════════════

CREATE TABLE IF NOT EXISTS sprint_gates (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    sprint_id    TEXT    NOT NULL REFERENCES sprints(id),
    chunk_num    INTEGER NOT NULL,
    overall      TEXT    NOT NULL CHECK (overall IN ('PASS', 'WARN', 'FAIL')),
    diff_lines   INTEGER NOT NULL DEFAULT 0,
    test_count   INTEGER NOT NULL DEFAULT 0,
    run_at       TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- gate 9 项详情
CREATE TABLE IF NOT EXISTS sprint_gate_items (
    gate_id  INTEGER NOT NULL REFERENCES sprint_gates(id),
    item_id  TEXT    NOT NULL,                   -- G1, G2, ..., G9
    name     TEXT    NOT NULL,                   -- build, test, invariants, ...
    status   TEXT    NOT NULL CHECK (status IN ('PASS', 'WARN', 'FAIL')),
    detail   TEXT,
    PRIMARY KEY (gate_id, item_id)
);

-- ═══════════════════════════════════
-- 错误记录
-- ═══════════════════════════════════

CREATE TABLE IF NOT EXISTS sprint_errors (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    sprint_id   TEXT    NOT NULL REFERENCES sprints(id),
    stage       TEXT    NOT NULL,
    step        INTEGER,
    chunk_num   INTEGER,                         -- execute 阶段时记录 chunk
    message     TEXT    NOT NULL,
    retry_count INTEGER NOT NULL DEFAULT 0,
    occurred_at TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- ═══════════════════════════════════
-- 事件日志
-- ═══════════════════════════════════

CREATE TABLE IF NOT EXISTS sprint_events (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    sprint_id TEXT NOT NULL REFERENCES sprints(id),
    event     TEXT NOT NULL,
    detail    TEXT,                              -- JSON
    ts        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- ═══════════════════════════════════
-- 基线值
-- plan 阶段记录的初始指标
-- ═══════════════════════════════════

CREATE TABLE IF NOT EXISTS sprint_baselines (
    sprint_id TEXT NOT NULL REFERENCES sprints(id),
    key       TEXT NOT NULL,                     -- test_count, todo_count, ...
    value     INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (sprint_id, key)
);
