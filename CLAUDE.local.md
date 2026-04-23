# takken-crm プロジェクト設定



## テンプレート変数の展開値



| 変数 | 値 |

|---|---|

| `{{PROJECT\_NAME}}` | 宅建CRM |

| `{{CLIENT\_NAME}}` | (クライアント名未設定) |

| `{{DB\_STACK}}` | Firebase |

| `{{REPO\_NAME}}` | takken-crm |

| `{{GHPAGES\_URL}}` | https://kiwamoto202602-a11y.github.io/takken-crm |

| `{{FIREBASE\_PROJECT\_ID}}` | (記入) |

| `{{SUPABASE\_PROJECT\_REF}}` | (Firebase使用のため該当なし) |

| `{{MONTHLY\_PLAN}}` | (記入) |



## プロジェクト固有情報



### 技術スタック

\- \*\*DB\*\*: Firebase Firestore

\- \*\*認証\*\*: Firebase Auth

\- \*\*ファイル保存\*\*: Firebase Storage

\- \*\*公開\*\*: GitHub Pages



### アプリ概要

宅建士(宅地建物取引士)業務向けCRMアプリ。

7つのSupabaseテーブル、8段階のカンバンボード、法令遵守チェックリストを含む。



※ 過去の記録ではSupabase使用となっているが、現在はFirebaseに移行済み。

　要確認: 実際の使用DBと一致しているか



## プロジェクト固有のルール・メモ



### 宅建業務特有の考慮事項

\- 法令遵守(宅建業法)に関する機能を含む

\- 媒介契約の種類・期限・報告義務等の管理



### 開発状況

\- index.html ベースの単一ファイル構成



## 更新履歴



| 日付 | 内容 |

|---|---|

| 2026-04-23 | 新雛形CLAUDE.md適用、CLAUDE.local.md初版作成 |

