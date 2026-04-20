# プロジェクト引き継ぎ資料 (HANDOVER)

---

## プロジェクト基本情報

| 項目 | 内容 |
|------|------|
| アプリ名 | 宅建業 案件管理CRM |
| 用途・目的 | 宅建業（不動産仲介業）向けの案件・顧客・物件を一元管理するCRMアプリ |
| GitHubアカウント名 | kiwamoto202602-a11y |
| GitHubリポジトリ名 | takken-crm |
| 公開URL | https://kiwamoto202602-a11y.github.io/takken-crm/ |

---

## 技術構成

| 項目 | 内容 |
|------|------|
| DB | Firebase Firestore (compat SDK v10.12.0) |
| プロジェクトID | `takken-crm` |
| 認証方式 | Firebase Authentication（メール＋パスワード） |
| ファイル保存先 | Firebase Storage |
| ホスティング | GitHub Pages（`main` ブランチの `index.html` を直接配信） |
| 実装形式 | **単一HTMLファイル**（`index.html` 1ファイルにHTML/CSS/JSをすべて記述） |

### Firebase SDK 読み込み（CDN compat 方式）
```html
<script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-auth-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-storage-compat.js"></script>
```

### Firebase 設定値
```js
const firebaseConfig = {
  apiKey: "AIzaSyA8hhIo_WwT51UcKzcRJ9AAumDQHEU5FnE",
  authDomain: "takken-crm.firebaseapp.com",
  projectId: "takken-crm",
  // ... (index.html 内参照)
};
```

---

## データ構造

Firestore コレクション一覧：

| コレクション名 | 役割 |
|--------------|------|
| `customers` | 顧客情報（姓・名・電話・メール・役割など） |
| `properties` | 物件情報（物件名・種別・価格・所在地など） |
| `deals` | 案件情報（顧客ID・物件ID・ステージ・担当者・期限など） |
| `activities` | 活動履歴（案件ID・日時・種別・スタッフ・メモ） |
| `tasks` | タスク（案件ID・内容・優先度・担当者・期限・完了フラグ） |
| `deal_checklist` | 案件ステージ別チェックリスト（key・完了フラグ） |
| `deal_files` | 案件添付ファイル（案件ID・Firebase Storage パス・ファイル名） |

### 案件ステージ（`deals.stage`）
```
媒介契約 → 広告活動 → 内見 → 条件交渉 → 申込・買付 → 契約 → 決済 → 成約 / 破談
```

---

## 主要機能

### 実装済み

- **認証** ― Firebase Auth によるメール/パスワードログイン・ログアウト
- **ダッシュボード** ― KPI（総案件数・進行中・未完了タスク・今月成約）、今日のタスク一覧、直近の活動ログ表示
- **案件管理（CRUD）** ― 案件一覧・新規作成・編集・ステージ変更・成約/破談クローズ・削除
- **顧客管理（CRUD）** ― 顧客一覧・新規作成・編集
- **物件管理（CRUD）** ― 物件一覧・新規作成・編集（物件種別・仲介種別・価格・所在地・図面URLなど）
- **タスク管理（CRUD）** ― タスク一覧・新規作成・完了切替・削除
- **活動履歴（CRUD）** ― 活動ログ一覧・新規作成・編集
- **案件詳細パネル（DP）** ― 案件詳細・チェックリスト・タスク・活動・ファイルのタブ表示
- **チェックリスト** ― ステージ別の必須/任意チェック項目
- **ファイル添付** ― Firebase Storage へのアップロード・ダウンロードリンク表示
- **ナビゲーション** ― ダッシュボード/案件/顧客/物件/タスク/活動の6ビュー切替

---

## 現在の状態

| 項目 | 内容 |
|------|------|
| 完成度 | 約 70% |
| 状態 | **開発中**（基本CRUD動作、UI調整・バグ修正フェーズ） |

---

## 進行中の作業

### 取り組んでいるタスク
モーダルダイアログ（新規追加・編集画面）が表示されない問題の修正。

### 原因の特定
`dealModal` / `custModal` / `propModal` / `taskModal` / `actModal` の5つのモーダルが、
HTML パーサによって `id="dp"`（`display:none` の案件詳細パネル）の子要素として解釈されてしまい、
`position: fixed` でも表示できない状態になっていた。

### 対処の経緯
1. モーダルHTMLを `#dp` の外・`</body>` 直前に移動 → ブラウザパーサが依然 `#dp` 内と解釈
2. `<script>` 冒頭で `document.body.appendChild()` で移動 → スクリプト実行後にパースされる要素に非対応
3. **現在の対応**：`MutationObserver` でDOM追加を監視し、モーダルが追加されるたびに `body` へ移動するコードを適用済み（デプロイ確認中）

```js
var MODAL_IDS = ['dealModal','custModal','propModal','taskModal','actModal','stageModal',...];
function moveModalsToBody() {
  MODAL_IDS.forEach(function(id) {
    var m = document.getElementById(id);
    if (m && m.parentElement !== document.body) document.body.appendChild(m);
  });
}
moveModalsToBody();
new MutationObserver(moveModalsToBody).observe(document.documentElement, {childList: true, subtree: true});
```

### どこまで完了しているか
- `stageModal`（ステージ変更モーダル）は `body` への移動を確認済み
- 他のモーダル（`custModal` 等）はデプロイ後の動作確認中

---

## 次にやること（優先順）

1. **モーダル表示問題の完全解消確認** ― デプロイ後に全ページの「+ 新規追加」ボタンを実際にクリックして動作検証
2. **全機能の結合テスト** ― ログイン → 顧客登録 → 物件登録 → 案件作成 → タスク追加 → 成約の一連フロー確認
3. **UIポリッシュ** ― レスポンシブ対応・モバイル表示の確認、スタイル統一
4. **Firebase セキュリティルール** ― Firestore/Storage のセキュリティルールを本番用に強化（現状は開発用の緩いルールの可能性）
5. **エラーハンドリング** ― 保存失敗・ネットワークエラー時のユーザー通知

---

## 未解決の課題・既知のバグ

| # | 内容 | 優先度 |
|---|------|--------|
| 1 | モーダルが `#dp` 内にパースされる HTML 構造上の問題（JS 回避策で対処中） | 高 |
| 2 | `stageModal` の `failModal` / `closeDealModal` のIDが存在しない可能性（要確認） | 中 |
| 3 | `openAdd()` がタスク/活動ページでも呼ばれるが、案件IDが未設定の場合の挙動が未確認 | 中 |
| 4 | Firebase Storage のパスにユーザー認証が紐付いていないため、URLが漏洩した場合にアクセス可能 | 低（開発フェーズ） |

---

## 注意事項・独自ルール

- **単一HTMLファイル構成**：HTML/CSS/JSがすべて `index.html` に記述されているため、分割しないこと
- **Firebase compat SDK を使用**：モジュラーSDK（v9+）ではなく compat 版（`firebase.firestore()` 形式）で統一
- **GitHub Pages で直接配信**：ビルドプロセスなし。`main` ブランチの `index.html` を直接 push すれば即反映
- **CSS変数**：カラーテーマは `:root` の CSS変数（`--primary`, `--surface`, `--text` 等）で管理
- **関数命名**：モーダル系は `open〇〇Modal()` / `save〇〇()` / `closeModal('id')` パターン

---

## 直近で編集したファイルと箇所

| ファイル名 | 箇所 | 内容 |
|-----------|------|------|
| `index.html` | L575〜L586（`<script>` 直後） | `moveModalsToBody()` + `MutationObserver` によるモーダル移動コード追加 |
| `index.html` | `function openAdd()` (L885〜L892) | `view-tasks` → `openTaskModal(null)`、`view-activities` → `openActModal(null)` のケースを追加 |
| `index.html` | 全体 | Firebase compat SDK v10.12.0 への移行（旧: localStorage ベース） |
| `index.html` | L1247付近 | `${c.role|）` → `${c.role}）` の文字化けバグ修正（chunk注入時の1バイトずれ） |
| `index.html` | 全体（63箇所） | `\!` → `!` の不正エスケープシーケンス修正 |

---

## コミット履歴（直近）

| ハッシュ | 内容 |
|---------|------|
| 最新 | MutationObserver によるモーダル移動コード追加 |
| 前 | moveModalsToBody() の初期実装 |
| 前々 | モーダルHTMLを `</body>` 直前に移動 |
| 前々々 | `openAdd()` にタスク/活動ページのケース追加 |
| 398a66f | Firebase版 index.html の初回デプロイ |

---

*このファイルは Claude (Cowork mode) により自動生成されました。*
