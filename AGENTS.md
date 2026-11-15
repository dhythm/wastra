# AGENTS.md

Wastra は、地方の現場業務（清掃、設備点検、保守）向けの業務管理 SaaS です。Frappe Framework v16 のアプリとして作ります。設計の全体像は [ARCHITECTURE.md](ARCHITECTURE.md) にあります。

## コードは書かないほど良い

コードは資産ではなく保守コストです。価値があるのは、動く業務と、それを説明するテストです。

1. まず Frappe の設定で解きます。DocType、権限、Workflow、Report、Print Format、Web Form で表現できるものに Python や JavaScript を書きません。
2. 設定で表現できない業務ルールだけをコードにします。置き場所は DocType のコントローラです。
3. 名前で説明します。変数名、関数名、テスト名を読めば何をしているか分かるように書きます。コメントは、コードから読み取れない理由だけに使います。
4. テスト名は振る舞いの文にします。例は `test_field_worker_cannot_create_work_site` です。
5. 使わないものは同じ変更の中で消します。Frappe が生成した空のひな形（中身のない `.js`、空のテストクラス、コメントアウトされたコード）も消します。
6. 呼び出し元が 1 つしかない関数、基底クラス、ヘルパー層を作りません。

## コマンド

| コマンド | すること |
| --- | --- |
| `make setup` | 開発環境を作ります。何度実行しても同じ状態になります。 |
| `make check` | lint、型、単体テスト、統合テストをすべて実行します。 |
| `make fix` | 自動で直せる lint と書式を直します。 |
| `make lint` | 静的チェックだけを実行します。 |
| `make test-unit` | DB を使わないテストを実行します。 |
| `make test-integration` | DB を使うテストを実行します。 |
| `make start` | `http://wastra.localhost:8000` で起動します。 |

`make setup` は Docker がない環境でも動きます。Docker に接続できないときは、MariaDB と Redis をプロジェクト内のプロセスとして起動します。テストが DB や Redis に接続できないときは `make services` を実行します。

## 変更の手順

1. 失敗するテストを先に書きます。期待した理由で失敗することを確認します。
2. テストを通す最小の変更をします。DocType の JSON は手で書かず、開発者モードの Frappe に生成させます。
3. `make check` を実行します。終了コードが 0 になるまで完了ではありません。
4. テストで確認できない変更（画面の見た目など）は、`make start` で起動して実物を確認します。確認していないことは、確認していないと報告します。

## テストの置き場所

- DB を使わないものは `frappe.tests.UnitTestCase` で書きます。
- DB を使うものは `frappe.tests.IntegrationTestCase` で書きます。権限のテストは Administrator ではなく、そのロールを持つユーザーとして実行します。
- E2E テスト（ブラウザ操作）は、今は書きません。
- Frappe 自体の動作はテストしません。Wastra の設定とコードが決めた振る舞いだけをテストします。

## ルールは文書ではなく検査にする

同じ注意を 2 回書きたくなったら、この文書に足す前に lint かテストにします。次のルールはすでに `wastra/tests/test_doctype_conventions.py` が検査しています。

- DocType 名、フィールド名、ラベルは英語で書きます。日本語は `wastra/translations/ja.csv` に書きます。
- DocType の権限には Wastra のロール（`Field Manager`、`Field Worker`）だけを使います。

## してはいけないこと

- パスワードや API キーをコードや設定ファイルに書きません。ローカルの秘密情報は `make setup` が `.env` に生成します。
- `.bench/` と `.services/` の中を編集しません。Frappe 本体と生成物の置き場で、Git の管理外です。
- lint や型のルールを、指摘を消す目的で緩めません。
