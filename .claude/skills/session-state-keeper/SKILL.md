---
name: session-state-keeper
description: |
  TRIGGER（以下の語を含む発話で必ず発動）:
  - "3ステップ以上" "長時間" "一気に" "最後まで進めて"
  - "続きをやって" "さっきの作業" "前回の続き"
  - リファクタリング / 移行 / 大規模編集
  - ファイル生成・DB操作・外部APIコールを伴うタスク
  SKIP:
  - 単一ファイル1〜2行の修正
  - 読み取り専用の調査
  動作: `.claude/session/<task-id>.json`に作業状態を自動保存。auto-compact・中断後も途中から再開可能。他スキル(data-migration-3phase等)からサブルーチンとして利用。
---

# session-state-keeper

任意の長期作業に対して、auto-compact耐性のある状態管理を提供する汎用スキル。

## このスキルが解決する問題

Claudeの会話はauto-compactや中断で**作業途中の情報が失われる**。状態をClaude側の記憶ではなくファイルに書き出すことで、どの時点で中断しても再開できるようにする。

## 設計思想

1. **状態はファイル、記憶ではない** — Claudeの会話履歴は信頼しない
2. **こまめに書く** — 各ステップ・エラーごとに保存
3. **呼び出し側は簡潔に** — 3つの基本動作（init / checkpoint / resume）だけで使える
4. **復帰時は自動で続きから** — 状態ファイルがあれば発動時に再開を提案

## ファイル構造

```
.claude/session/<task-id>.json
```

`<task-id>` は呼び出し側が決める（例: `kakuzen-feature-contract-history`, `migration-firebase-to-supabase-20260421`）。

### スキーマ

```json
{
  "task_id": "kakuzen-feature-contract-history",
  "task_type": "feature_development",
  "description": "KAKUZENに契約履歴タブを追加",
  "created_at": "2026-04-21T10:00:00+09:00",
  "updated_at": "2026-04-21T10:45:00+09:00",
  "last_saved_reason": "step_completed",
  "status": "in_progress",

  "steps": [
    {
      "id": "s1",
      "name": "UIモックアップ作成",
      "status": "completed",
      "started_at": "2026-04-21T10:00:00+09:00",
      "completed_at": "2026-04-21T10:15:00+09:00",
      "artifacts": ["./mockups/contract-history-v1.html"]
    },
    {
      "id": "s2",
      "name": "Supabaseテーブル追加",
      "status": "in_progress",
      "started_at": "2026-04-21T10:15:00+09:00",
      "progress": {
        "current": 2,
        "total": 5,
        "last_checkpoint": "migration SQL書き終わり、レビュー待ち"
      }
    }
  ],

  "context": {
    "files_touched": ["index.html", "supabase_migration_003.sql"],
    "open_questions": ["外部システムフラグの型はboolean? enum?"],
    "decisions_made": [
      {"time": "2026-04-21T10:10:00+09:00", "decision": "契約履歴はモーダルではなくタブで表示"}
    ]
  },

  "next_actions": [
    "Supabaseダッシュボードでマイグレーション実行",
    "実行後、テーブル構造をindex.htmlから確認"
  ],

  "resume_hint": "s2の途中。migration SQLは書けているのでユーザーに確認してから実行する。"
}
```

## 3つの基本動作

### 1. init — 作業開始時

状態ファイルを新規作成する。`task_id` は以下のルールで決める：

- 機能開発: `<app-name>-feature-<short-name>` 例: `kakuzen-feature-contract-history`
- バグ修正: `<app-name>-bugfix-<issue>` 例: `takken-crm-bugfix-kanban-drag`
- 移行系: `migration-<from>-to-<to>-<YYYYMMDD>`
- その他: `task-<short-name>-<YYYYMMDD>`

initの直後にユーザーへ宣言する：

```
[session-state-keeper] この作業の状態を .claude/session/<task-id>.json に保存しながら進めます。
中断しても再開可能です。
```

### 2. checkpoint — 作業中

以下の**3つのタイミング**で自動的に状態ファイルを更新する。

| トリガー | 発動条件 | 保存内容 |
|---|---|---|
| **step_completed** | ステップが完了した瞬間 | status更新、completed_at、artifacts |
| **error** | エラー検出時 | errors配列に追記、next_actionsに復旧手順 |
| **pre_response** | ユーザーに長文返信する直前 | 直近の決定事項をcontext.decisions_madeに追記 |

**重要**: Claudeは自分のターン中に複数の処理を行う。各処理の区切り（bashコマンド1つ、ファイル編集1つ、等）を1ステップとみなし、完了ごとに保存する。

時間経過を理由に保存することはしない。Claudeは正確な経過時間を把握できないため、「5分経過」のような時間トリガーは判断が曖昧になる。代わりに**処理単位を細かく**することでカバレッジを確保する：

- 長時間のバッチ処理は、バッチサイズを小さくする（1000件より100件）
- 長時間の連続処理は、意味のある区切りを見つけてステップに分割する

checkpointの際、`last_saved_reason` に発動トリガーを必ず記録する（デバッグ用）。

### 3. resume — 再開時

セッション開始時に必ず以下を実行：

1. `.claude/session/` ディレクトリの全ファイルを `ls`
2. 更新日時が新しい順に最大3件を読み込む
3. `status` が `in_progress` のものがあれば、ユーザーに報告：

```
[session-state-keeper] 前回の作業が途中で終わっています：
- タスク: <description>
- 最終更新: <updated_at> (<◯分前>)
- 進捗ヒント: <resume_hint>
- 次のアクション: <next_actions>

このまま再開しますか？
```

ユーザーが「再開」と答えたら、`resume_hint` と `next_actions` を起点に作業を続ける。

## 呼び出し側スキルとの連携

他のスキル（data-migration-3phase等）は、このスキルを「サブルーチン」として呼び出す。

### 連携パターン

```
[呼び出し側スキル]
  ↓ 開始時
[session-state-keeper: init] task_id="migration-..."
  ↓ 各ステップ完了時
[session-state-keeper: checkpoint step_completed]
  ↓ エラー時
[session-state-keeper: checkpoint error]
  ↓ 完了時
[session-state-keeper: status=completed]
```

### 呼び出し側が拡張したい場合

`context` オブジェクトは呼び出し側が自由にキーを追加してよい。例：

- data-migration-3phase: `context.phases`, `context.rollback_plan`
- 機能開発系: `context.files_touched`, `context.test_results`

ただし**トップレベルのキー**（task_id, status, steps, next_actions, resume_hint）は共通スキーマを守る。

## checkpointの実装ルール

### いつ保存するか（Claudeが判断）

以下のいずれかに該当したら即座にファイル更新：

- ✅ bashコマンドを1つ実行し終わった直後
- ✅ ファイルを1つ作成・編集し終わった直後
- ✅ ユーザーに質問を投げる直前
- ✅ エラーメッセージを受け取った直後
- ✅ 大きな決定（技術選択、方針転換）をした直後

### 保存しすぎないルール

- 1ターン内で同じ内容を複数回書かない
- 純粋な読み取り（viewだけ）の直後は保存しない
- 意味のある差分がないなら`updated_at`だけ更新で十分

## 出力形式（ユーザーへの報告）

大きなステップ完了時のみ、以下をユーザーに短く伝える：

```
[saved] s2完了、次はs3
```

毎回のcheckpointを全部報告すると煩雑になるため、**冗長にならないよう抑制**する。

## 再開時の例

### セッション開始時にClaudeが行うべき挙動

```
ユーザー: KAKUZENの契約履歴タブ、続きやって

[Claude]
1. .claude/session/ を確認 → kakuzen-feature-contract-history.json を発見
2. status="in_progress" のため再開モード
3. ユーザーに報告:

前回の続きを確認しました:
- s2（Supabaseテーブル追加）が途中
- migration SQLは作成済み
- 次: 実行確認を取って、その後index.htmlから確認

この通りに進めていいですか？
```

## チェックリスト

- [ ] init時にtask_idを決めてファイル作成したか
- [ ] ステップ完了ごとにcheckpointしているか
- [ ] エラー発生時に即checkpointしたか
- [ ] 完了時にstatus=completedに更新したか
- [ ] 再開時に状態ファイルを読んだか

## 注意事項

- **複数タスクの並行**: `.claude/session/` に複数ファイルを置いて管理する。task_idが衝突しないよう命名規則を守る
- **古いファイルのクリーンアップ**: completedになってから30日経過したファイルはユーザー確認のうえ削除を提案
- **機密情報の記録禁止**: パスワード、APIキー、個人情報は絶対に状態ファイルに書かない
