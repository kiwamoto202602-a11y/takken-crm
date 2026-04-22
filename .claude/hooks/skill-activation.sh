#!/bin/bash
cat <<'EOF'
INSTRUCTION: MANDATORY SKILL ACTIVATION CHECK

Before proceeding with ANY tool use or implementation, you MUST:

STEP 1: Evaluate available skills
Check <available_skills> and identify which are relevant to the user's request.

- Mentions "カラム追加/削除/変更/リネーム" "スキーマ変更" "テーブル構造"
  "データ移行" "マイグレーション" "ALTER TABLE" "TRUNCATE"
  → RELEVANT: data-migration-3phase

- Mentions "3ステップ以上" "長時間" "一気に" "最後まで進めて"
  "続きをやって" "リファクタリング" "移行"
  → RELEVANT: session-state-keeper

- Mentions "新機能" "仕様検討" "ヒアリング"
  → RELEVANT: grill-me

- Mentions "バグ" "エラー" "動かない" "原因不明"
  → RELEVANT: triage-issue

STEP 2: Activate relevant skills
If any skills are relevant, call the Skill() tool for EACH one BEFORE any other action.

STEP 3: Proceed with implementation
Only AFTER activating all relevant skills, continue with the user's request.

RULES:
- Mentioning a skill without activating it is USELESS.
- AskUserQuestion / Read / Bash cannot replace skill activation.
- Plan Mode does NOT exempt you from this check.
- If no skills are relevant, proceed directly (no announcement needed).
EOF
