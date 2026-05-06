---
id: 20260418-030405-003
type: sprint-for-code
desc: 在订单、支付、发票三个独立模块中批量替换已知 validator import，并跑验证
sequence: plan → parallel(implement) → verify
created: 2026-04-18T03:04:05Z
---

# Sprint Handoff — 在订单、支付、发票三个独立模块中批量替换已知 validator import，并跑验证

<!-- generated from tests/units/sprint-for-code/full-run-parallel/expected.json -->

## Stages
<!-- SECTION: stages -->
### 1. plan

tasks: orders, payments, invoices

### 2. implement (task: orders)

migrated order validation

### 3. implement (task: payments)

migrated payment validation

### 4. implement (task: invoices)

migrated invoice validation

### 5. verify

validator test suite passed
<!-- /SECTION: stages -->

## Runtime
<!-- SECTION: runtime -->
cursor: verify
loop:
  active: 
parallel:
  completed: []
<!-- /SECTION: runtime -->

## Finalize
<!-- SECTION: finalize -->
status: completed
completed_at: 2026-04-18T03:09:05Z
insight:
<!-- /SECTION: finalize -->
