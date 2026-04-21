---
name: data-migration-3phase
description: データ移行を「バックアップ → 変換 → 検証」の3フェーズで安全に実行するスキル。auto-compactで中断されても`.claude/migration.json`から再開できる。以下の状況では必ずこのスキルを使うこと — 明示的な「移行」という語がなくても発動する：(1) 既存テーブルへのカラム追加・型変更・リネーム・削除、(2) 「古い◯◯を新しい◯◯に統合」「_old/_test/_draftテーブルの整理」「試作ファイルを本番に寄せる」、(3) 大量レコードのUPDATE/DELETE/INSERTを一括実行する場面、(4) Firebase/Firestore ↔ Supabase/Postgres間のデータ移し替え、(5) Plan A → Plan B等のクライアント移管、(6) 「データを入れ直す」「リストアする」「テーブル構造を変えたい」「スキーマを直したい」「クレンジングしたい」「正規化したい」といった発言、(7) 稼働中アプリ（KAKUZEN、takken-crm、consulting-v2等）のDB構造に触る作業全般。バックアップやロールバックが必要かユーザーが明示していなくても、破壊的なDB操作に該当する場合は先回りでこのスキルを提案すること。git-guardrailsと連携してPhase 2前にバックアップブランチを作成し、systematic-debuggingと連携してPhase 3で不整合を検出した際は自動でデバッグフローに移行する。
---

# data-migration-3phase

稼働中アプリのデータ移行を3フェーズで安全に実行するためのスキル。ロールバック可能な状態を常に確保し、中断からの再開に対応する。

## 設計原則

1. **破壊的操作の前に必ずバックアップ** — Phase 1が完了するまでPhase 2を開始しない
2. **状態は`.claude/migration.json`に保存** — auto-compactや会話中断後も再開可能
3. **各Phase開始前にユーザー確認** — 暴走防止（dry-run時を除く）
4. **失敗時は自動でロールバック手順を提示** — 手順はログに記録する

## 実行フロー

```
[ユーザー要求]
    ↓
[状態ファイル読込 or 新規作成]
    ↓
[Phase 1: バックアップ] ← 確認 → 実行 → 完了
    ↓
[git-guardrails連携: バックアップブランチ作成]
    ↓
[Phase 2: 変換] ← 確認 → 実行 → 完了
    ↓
[Phase 3: 検証] ← 確認 → 実行 → 完了
    ↓ (不整合検出時)
[systematic-debuggingへ移行]
```

## 状態ファイル仕様

状態管理は **`session-state-keeper` スキルを利用する**。

- 保存先: `.claude/session/migration-<YYYYMMDD>-<short-name>.json`
- 基本スキーマは session-state-keeper に従う
- data-migration-3phase 固有の情報は `context` オブジェクト内に入れる

### 保存タイミング

session-state-keeper の checkpoint ルールに加え、以下でも保存する：

- **Phase 2 のバッチ完了ごと**（100件処理するたび）
- **Phase 3 のサンプル比較1件ごと**に不整合が見つかった瞬間
- **git操作の前後**（ブランチ作成・チェックアウト・コミット）
- **バックアップファイル書き込み完了ごと**

### 状態ファイル例（改訂版）

```json
{
  "task_id": "migration-20260421-kakuzen-cleanup",
  "task_type": "migration",
  "description": "KAKUZEN employee-ledger の試作ファイル整理",
  "created_at": "2026-04-21T14:00:00+09:00",
  "updated_at": "2026-04-21T14:05:00+09:00",
  "last_saved_reason": "step_completed",
  "status": "in_progress",

  "steps": [
    {"id": "phase1_backup", "name": "バックアップ", "status": "completed",
     "started_at": "...", "completed_at": "...",
     "artifacts": ["./backups/20260421-1400/"]},
    {"id": "phase2_transform", "name": "変換", "status": "in_progress",
     "started_at": "...",
     "progress": {"current": 300, "total": 1234, "last_checkpoint": "batch 3/13 完了"}},
    {"id": "phase3_verify", "name": "検証", "status": "pending"}
  ],

  "context": {
    "source": {
      "type": "supabase", "project_ref": "kakuzen-prod",
      "tables": ["employees_old", "employees_test", "contracts_draft"]
    },
    "target": {
      "type": "supabase", "project_ref": "kakuzen-prod",
      "schema_version": "cleanup-v1"
    },
    "dry_run": false,
    "git_backup_branch": "backup/pre-migration-20260421",
    "config": {
      "small_table_threshold": 10,
      "batch_size": 100
    },
    "rollback_plan": [
      "1. git checkout backup/pre-migration-20260421",
      "2. Restore from ./backups/20260421-1400/",
      "3. Verify record count"
    ]
  },

  "errors": [],

  "next_actions": [
    "Phase 2: batch 4/13 から再開",
    "employees_old の残り934件を変換"
  ],

  "resume_hint": "Phase 2 で employees_old を300件変換済み、batch 4から続ける"
}
```

### Phase内の細粒度チェックポイント

Phase 2を例にとる。従来は Phase 2 完了時にのみ状態を更新していたが、改訂版では以下のタイミングで細かく保存する：

```
Phase 2 開始
  ├─ git branch 作成 → [checkpoint]
  ├─ batch 1完了 → steps[1].progress.current = 100 → [checkpoint]
  ├─ batch 2完了 → steps[1].progress.current = 200 → [checkpoint]
  ├─ batch 3完了 → steps[1].progress.current = 300 → [checkpoint]
  ├─ ... (auto-compact発生してもこの時点で再開可能)
  ├─ batch 13完了 → [checkpoint]
  └─ Phase 2 完了 → status=completed → [checkpoint]
```

再開時は `steps[1].progress.current` を見て、その続きから実行する。

### ステータス遷移

各stepの`status`: `pending` → `in_progress` → `completed` / `failed`

`failed` になったら次のPhaseへ進まず、`next_actions`にロールバック手順を詰めてユーザー確認を求める。

## 起動時の判定

セッション開始時、**session-state-keeper の resume ロジックに従う**：

1. `.claude/session/` 配下で `task_type="migration"` かつ `status="in_progress"` のファイルを探す
2. 見つかれば `resume_hint` と `next_actions` をユーザーに報告
3. 「再開しますか？新規に始めますか？」を確認
4. 新規の場合は session-state-keeper の init を呼び、task_id を決めてファイル作成

## Phase 1: バックアップ

**目的**: 元データを完全保存し、いつでも戻せる状態を作る。

### 実行前の確認事項（ユーザーに確認）

- 移行元の種別（Supabase / Firebase / その他）
- 対象テーブル/コレクション名
- バックアップの保存先ディレクトリ
- dry-run かどうか

### 実行内容

1. タイムスタンプ付きディレクトリを作成: `./backups/<YYYYMMDD-HHMM>/`
2. 全レコードをJSON/JSONLで保存
3. スキーマ定義も一緒に保存（Supabaseは`pg_dump --schema-only`、Firestoreはルール＆インデックス）
4. **各テーブルのバックアップ完了ごとに session-state-keeper の checkpoint を呼ぶ**
   - `steps[phase1].progress.current` にバックアップ済みテーブル数を記録
   - auto-compactで中断しても未処理テーブルだけ再開できる
5. レコード数を記録して`context.record_counts`に書き込む
6. `steps[phase1].status` を `completed` に更新

### 小規模テーブルの扱い（閾値スキップ）

レコード数が極端に少ないテーブル（デフォルト閾値: **10件以下**）は、フルバックアップの工数対効果が低い。この場合は以下の判定フローを実行する：

1. Phase 1開始時に各テーブルのレコード数をプリスキャン
2. 閾値以下のテーブルをユーザーに提示し、3択で確認：
   - **(A) 通常通りバックアップする**（安全側）
   - **(B) JSONL保存のみ行い、スキーマダンプは省略**（軽量）
   - **(C) スキップして削除候補リストに追加**（試作ファイル整理時の推奨）
3. 選択結果を`artifacts.small_table_policy`に記録
4. (C)選択時は`artifacts.deletion_candidates`にテーブル名を記録し、Phase 3完了後にユーザーへ削除確認を促す

閾値は`.claude/migration.json`の`config.small_table_threshold`で上書き可能。

### テンプレート

- Supabase: `templates/supabase_backup.sql.template`
- Firebase: `templates/firebase_backup.js.template`

### 失敗時のロールバック

Phase 1の失敗＝まだ何も変えていない状態。`next_actions`に以下を記録：
- 「バックアップが不完全なためPhase 2へ進行禁止」
- 「エラー内容を確認し、権限・接続・容量を再点検」

## Phase 2: 変換

**目的**: スキーマ変換・データクレンジング・投入。

### 実行前の必須条件

1. Phase 1 が `completed` である
2. **git-guardrails連携**: バックアップブランチを作成済みである
   ```bash
   git checkout -b backup/pre-migration-<YYYYMMDD>
   git push origin backup/pre-migration-<YYYYMMDD>
   git checkout -
   ```
   作成したブランチ名を`artifacts.git_backup_branch`に記録する。

3. ユーザーに「Phase 2を開始してよいですか？」と確認（dry-run時はスキップ可）

### 実行内容

1. 変換スクリプトをバッチ単位で実行（1バッチ100〜1000件推奨）
2. **各バッチ完了ごとに session-state-keeper の checkpoint を呼ぶ**
   - `steps[phase2].progress.current` に処理済み件数を記録
   - `steps[phase2].progress.last_processed_id` に最終処理レコードIDを記録
   - これにより auto-compact 発生時も `current` の続きから再開可能
3. 進捗ログを出力（例: `[Phase2] 500/1234 records transformed, checkpoint saved`）
4. クレンジング規則（NULL処理、型変換、正規化）は事前に明文化する
5. 失敗バッチは `errors` 配列に `{batch_id, reason, retry_count}` で記録し即時 checkpoint
6. 全件完了で `steps[phase2].status` を `completed` に

### 再開時のバッチ処理

セッション再開時、`steps[phase2].progress.current` が `total` 未満なら：

1. 処理済みの `last_processed_id` より大きいIDのレコードのみを対象にする
2. 残りレコード数をユーザーに報告してから再開
3. 冪等性のため、同じIDで再実行しても壊れない変換スクリプトを使う（UPSERT推奨）

### テンプレート

- Supabase → Supabase: `templates/supabase_transform.sql.template`
- Firebase → Supabase: `templates/firebase_to_supabase.js.template`

### 失敗時のロールバック

`next_actions`に以下を自動で積む：
```
1. git checkout backup/pre-migration-<YYYYMMDD>
2. 移行先テーブルの変換済みレコードを削除（DELETE FROM ... WHERE migrated_at >= '<phase2_started_at>'）
3. Phase 1で作成したバックアップから復元
4. 復元後、レコード数が元の数と一致することを確認
```

## Phase 3: 検証

**目的**: 移行結果の整合性を保証する。

### 実行内容

1. **レコード数一致チェック**: source vs target の全件数を比較
2. **サンプルデータ比較**: 動的サンプリングで主要フィールドを突合
   - **サンプル数 = max(50, 全レコード数 × 5%)、上限500件**
   - 100件以下のテーブルは全件比較
   - 固定50件ではなく動的にすることで、大規模テーブルでの検出漏れを防ぐ
   - 比較対象フィールドは事前に`config.sample_compare_fields`で指定（未指定時は全カラム）
3. **整合性チェック**:
   - 外部キー参照の整合性
   - NOT NULL制約違反の検出
   - 一意制約違反の検出
   - 日付フィールドの範囲チェック
4. 結果を`artifacts.verification_report`に記録（sample_size, matched, mismatches）

### False positive対策

サンプル比較では、トリム済み文字列の前後空白差など「意図した変換」が不整合として誤検出されやすい。以下で抑制する：

- 文字列比較は両側`.trim()`後に行う
- NULL ⇔ 空文字 は同値とみなす（`config.strict_null: true`で厳格化可能）
- タイムスタンプはミリ秒以下の差を無視（`config.timestamp_tolerance_ms: 1000`）

それでも残った不整合のみ`errors`に記録する。

### 不整合検出時

**systematic-debugging連携を自動発動**:

1. `status`を`failed`に
2. `errors`に不整合の詳細を記録
3. ユーザーに報告し、systematic-debuggingスキルの発動を提案
4. デバッグフロー移行時は状態ファイルを引き継ぐ（`migration.json`の内容をデバッグ文脈に含める）

### テンプレート

- `templates/verify_count.sql.template`
- `templates/verify_sample.js.template`

## dry-run モード

`dry_run: true` の場合、以下の挙動に変わる：

- Phase 1: バックアップは実施するが、対象外テーブルをリストアップするのみでも可
- Phase 2: 変換スクリプトは`BEGIN; ... ROLLBACK;`で囲む、または書き込み先を一時テーブルに変更
- Phase 3: 通常通り検証を行い、レポートを出す
- ユーザー確認は省略可（ただし最終レポート提示は必ず行う）

## 出力形式

各Phase完了時、以下をユーザーに報告：

```
### Phase N: <name> 完了
- 開始: YYYY-MM-DD HH:MM
- 完了: YYYY-MM-DD HH:MM
- 処理件数: XXXX
- エラー: 0件
- 次のアクション: Phase N+1を開始しますか？
```

失敗時：

```
### Phase N: <name> 失敗
- エラー: <内容>
- ロールバック手順:
  1. ...
  2. ...
- 状態ファイル: .claude/migration.json に保存済み（再開可能）
```

## 他スキルとの連携

| 連携先 | トリガー | 連携内容 |
|---|---|---|
| git-guardrails | Phase 2開始前 | バックアップブランチ作成、destructive操作のブロック確認 |
| systematic-debugging | Phase 3で不整合検出時 | 状態ファイルを引き継いでデバッグフローへ移行 |

## 想定ユースケース

1. **KAKUZEN等の稼働中アプリのスキーマ変更** — 既存テーブルに新カラム追加＋既存データの埋め戻し
2. **Plan A → Plan B 切り替え時のデータ移管** — クライアント向けプラン変更に伴う移行
3. **Firebase → Supabase 移行** — Firestore ドキュメントをリレーショナルに変換
4. **試作ファイル整理** — 開発中の`_old`, `_test`, `_draft`テーブルを正式テーブルへ統合・削除

## config（.claude/migration.json内 `config` キー）

任意項目。未指定時はデフォルト値を使用。

```json
"config": {
  "small_table_threshold": 10,
  "sample_compare_fields": ["name", "email"],
  "strict_null": false,
  "timestamp_tolerance_ms": 1000,
  "batch_size": 500
}
```

## チェックリスト（各Phase開始前）

- [ ] `.claude/migration.json` が最新の状態で保存されているか
- [ ] 前Phaseが `completed` か（Phase 1以外）
- [ ] dry-run かどうかユーザーと合意済みか
- [ ] ロールバック手順が書かれているか
- [ ] ユーザー確認を取ったか（dry-run時を除く）
- [ ] 小規模テーブルのポリシー（A/B/C）が記録されているか（Phase 1のみ）
