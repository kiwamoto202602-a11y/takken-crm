# 宅建業 案件管理CRM

宅建業（不動産仲介業）向けの案件・顧客・物件を一元管理するCRMアプリです。

---

## 公開URL

https://kiwamoto202602-a11y.github.io/takken-crm/

---

## 技術構成

| 項目 | 内容 |
|------|------|
| DB | Firebase Firestore (compat SDK v10.12.0) |
| 認証 | Firebase Authentication（メール＋パスワード） |
| ファイル保存 | Firebase Storage |
| ホスティング | GitHub Pages（`main` ブランチの `index.html` を直接配信） |
| 実装形式 | `index.html` 1ファイル（HTML/CSS/JS一体型） |

---

## デプロイ方法

```bash
git add index.html
git commit -m "update"
git push origin main
```

`main` ブランチに push するだけで GitHub Pages に即反映されます。

---

## 初期セットアップ手順

### 1. Firebase プロジェクトの設定

`index.html` 内の `firebaseConfig` を自分のプロジェクトの値に書き換えてください。

```js
const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_PROJECT_ID.appspot.com",
  messagingSenderId: "YOUR_SENDER_ID",
  appId: "YOUR_APP_ID"
};
```

### 2. Firebase Authentication の設定

Firebase Console → Authentication → Sign-in method → **メール/パスワード** を有効化。

ユーザーを追加: Authentication → Users → ユーザーを追加。

### 3. Firestore セキュリティルールの設定

Firebase Console → Firestore Database → ルール に `firestore.rules` の内容をコピーして公開します。

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 4. Firebase Storage セキュリティルールの設定

Firebase Console → Storage → ルール に `storage.rules` の内容をコピーして公開します。

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /deals/{dealId}/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 5. GitHub Pages の設定

GitHub リポジトリ → Settings → Pages → Source: **Deploy from a branch** → Branch: `main` / `/ (root)` → Save。

---

## データ構造

| コレクション | 主なフィールド |
|-------------|--------------|
| `customers` | sei, mei, tel, email, role, budget, memo, created_at |
| `properties` | name, prop_type, addr, deal_type, price, area, age, layout, status, memo, created_at |
| `deals` | customer_id, property_id, agency_type, stage, deadline, memo, created_at |
| `activities` | deal_id, date, type, note, staff, created_at |
| `tasks` | deal_id, title, due_date, priority, assigned_to, done, created_at |
| `deal_checklist` | deal_id, stage, item_key, checked, checked_by, checked_at |
| `deal_files` | deal_id, file_name, file_type, storage_path, created_at |

---

## 案件ステージ

```
問合せ → 媒介契約 → 内見 → 条件交渉 → 申込・買付 → 重説・契約 → ローン審査 → 決済・引渡し → 成約 / 失注
```
