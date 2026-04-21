# 作業進捗ログ

---

## プロジェクト名
宅建業 案件管理CRM

## 現在のフェーズ
Phase 3: 実装（仕上げ段階）

## 完了済み
- Firebase compat SDK v10.12.0 への移行
- 全コレクションの CRUD 実装（案件・顧客・物件・タスク・活動・チェックリスト・ファイル）
- モーダル表示問題の修正（MutationObserver + HTML構造整理）
- ログイン時の二重 loadAll() 解消（doLogin → onAuthStateChanged に一本化）
- deal_files を NO_ORDER_COLS に追加（Firestore orderBy エラー防止）
- モバイルレスポンシブ改善（#edp 全画面化・dash-grid クラス化・data-label 追加）
- Firebase セキュリティルール本番化（firestore.rules / storage.rules 作成）
- README.md 作成（セットアップ手順・デプロイ方法・データ構造）

## 進行中
なし

## 次にやること（優先順）
1. 実機での結合テスト（ログイン→顧客登録→物件登録→案件作成→タスク追加→成約の一連フロー）
2. エラーハンドリング（保存失敗・ネットワークエラー時のユーザー通知）
3. Firebase Console でセキュリティルールを手動適用（Kazuki 作業）

## 未解決・注意事項
- Firebase Storage のパスにユーザー認証が紐付いていない（URL 漏洩時にアクセス可能）→ 現フェーズでは許容
- 実機テストはブラウザで https://kiwamoto202602-a11y.github.io/takken-crm/ を開いて確認が必要

## 直近で触ったファイル
- index.html（ログイン二重読み込み修正・モバイル対応改善）
- firestore.rules（新規作成）
- storage.rules（新規作成）
- README.md（新規作成）

---

最終更新: 2026-04-21
