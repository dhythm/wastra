# アーキテクチャ

## Wastra が解く問題

地方の現場業務には、紙と電話と Excel で回っている領域が多く残っています。Wastra は業種ごとに DocType を組み替えて、その業務を管理します。最初の対象は清掃、設備点検、保守です。建設や産業廃棄物は、同じ土台の上に後から足します。

Frappe を選んだ理由は、DocType を定義すると DB テーブル、フォーム、一覧、REST API、権限が生成されるからです。業務アプリの大半は「データの形と、誰が何をできるか」で決まるので、そこを設定で済ませれば、書くコードは業務固有のルールだけになります。

## どこに何を置くか

変更したい内容に対して、表の上にある手段から順に検討します。下に行くほどコードが増えます。

| 表現したいこと | 手段 | 置き場所 |
| --- | --- | --- |
| データの形、入力画面、一覧、必須や一意の制約 | DocType | `wastra/<module>/doctype/<name>/<name>.json` |
| 誰が読めて誰が書けるか | DocType の権限とロール | 同じ JSON の `permissions` |
| 承認などの状態遷移 | Frappe の Workflow | fixtures として書き出す |
| 集計と帳票 | Report、Print Format | `wastra/<module>/report/`、`print_format/` |
| 日本語の表示 | 翻訳 | `wastra/translations/ja.csv` |
| 設定で書けない業務ルール | DocType のコントローラ | `wastra/<module>/doctype/<name>/<name>.py` |
| DocType をまたぐ処理、定期実行 | `hooks.py` から呼ぶ関数 | `wastra/<module>/` |
| 独自の画面 | 作りません | 必要になった時点でこの文書を改訂します |

承認状態をコントローラの `if` で書かないことが、この表でいちばん大事な点です。状態と遷移と、遷移できるロールは Workflow というデータで持ちます。そうすると不正な遷移は設定に存在せず、条件分岐を書く場所がなくなります。

独自の画面を作らないので、TypeScript は今は使いません。クライアントスクリプトが必要になったら `.js` を置き、Biome が検査します。TypeScript を導入する変更では、同じ変更で `tsc --noEmit` を `make lint` に足します。

## ドメインモデル

| DocType | 日本語 | 持つもの | 状態 |
| --- | --- | --- | --- |
| `Client` | 顧客 | 会社名、連絡先 | 実装済み |
| `Work Site` | 現場 | 住所、設備情報、顧客へのリンク | 実装済み |
| `Inspection Request` | 点検依頼 | 内容、希望日、現場へのリンク | 未実装 |
| `Work Record` | 作業記録 | 担当者、作業結果、点検依頼へのリンク | 未実装 |
| `Inspection Report` | 報告書 | 写真、点検結果、承認状態 | 未実装 |

未実装の名前は予定です。実装するときに見直してかまいません。

DocType 名は 1 つのサイトの中で一意でなければなりません。ERPNext を同じサイトに入れると `Customer` が衝突するので、顧客は `Client` と名付けました。

ロールは 2 つです。`Field Manager` は事務と管理の担当で、すべての操作ができます。`Field Worker` は現場の作業員で、顧客と現場を読むことだけができます。

モジュールは今は `Wastra` の 1 つです。2 つ目の業種を足すときに、業種ごとのモジュールへ分けます。それまでは分けません。

## 検査の層

速い検査を厚くして、遅い検査は持ちません。E2E テストは CI を数十分にするので、MVP の形が固まるまで導入しません。

| 層 | 検査すること | 道具 | bench |
| --- | --- | --- | --- |
| 書式と lint | 書式、未使用の import と変数、コメントアウトされたコード、複雑度 | ruff、Biome | 不要 |
| 不要コード | 呼ばれない関数、クラス、属性 | vulture | 不要 |
| 型 | `wastra/` 全体を strict で検査 | mypy | 必要 |
| 単体テスト | DB なしで分かること。プロジェクトの規約もここで検査 | `UnitTestCase` | 必要 |
| 統合テスト | 権限、制約、Workflow など DB を通して分かること | `IntegrationTestCase` | 必要 |

`make check` がすべての層を実行します。CI は同じ `make` ターゲットを 2 つのジョブで実行します。`lint` ジョブは bench なしで終わり、`test` ジョブは `make setup` で bench を作ってから型とテストを実行します。ローカルと CI で検査の中身は同じです。

## 開発環境の構成

```
wastra/                  リポジトリのルート。Frappe アプリそのもの
├── wastra/              Python パッケージ
│   ├── hooks.py         Frappe への登録
│   ├── translations/    日本語訳
│   ├── tests/           DocType に属さないテスト
│   └── wastra/doctype/  DocType の定義、コントローラ、テスト
├── scripts/setup.sh     環境を作る唯一の手順
├── scripts/services.sh  MariaDB と Redis を起動する
├── tools/               Yarn 1 の shim と Git フック
├── compose.yaml         MariaDB と Redis
├── .bench/              Frappe 本体、仮想環境、サイト（Git 管理外）
└── .services/           Docker なしの方式での DB と Redis のデータ（Git 管理外）
```

`.bench/apps/wastra` はリポジトリのルートへのシンボリックリンクです。編集したファイルは、コピーなしで bench から見えます。

動かすのに必要なサーバーは MariaDB と Redis の 2 つだけです。`scripts/services.sh` が 2 つを起動します。Docker が使える環境では `compose.yaml` を使い、バージョンを固定します。Docker が使えない環境では、同じ 2 つをプロジェクト内のプロセスとして起動し、データを `.services/` に置きます。どちらの方式でも、システムの常駐サービスは増やしません。

Docker なしの方式は、AI エージェントの実行環境で動作確認をするためのものです。そこでは Docker が動かないことが多いので、`apt-get` で入るサーバーのバイナリだけで `make setup` と `make check` が通るようにしています。

bench 自体はホストで動かします。テストの起動が速く、エディタと型検査が bench の仮想環境をそのまま使えるからです。

## 決めたことと理由

| 決定 | 理由 |
| --- | --- |
| Frappe v16（`version-16` ブランチ） | 現行の安定版です。Python 3.14 と Node 24 が必要です。 |
| DB は MariaDB | Frappe の既定で、本番と同じ DB でテストできます。 |
| 軽量な確認用にも SQLite を使わない | Frappe 16.56.0 では `bench new-site --db-type sqlite` が一意制約エラーで失敗します（frappe/frappe#44524）。Frappe 自身の CI も SQLite のテストを無効にしています。 |
| Redis を省かない | Redis を止めると統合テストが失敗します。Frappe は検索インデックスの更新を Redis のキューに積みます。 |
| Yarn 1 を `tools/bin/yarn` 経由で使う | Frappe は `yarn install --check-files` を実行し、Yarn 4 はこのオプションを拒否します。 |
| 開発ツールのバージョンは `pyproject.toml` の `dependency-groups.dev` と `Makefile` に固定 | ローカルと CI で同じ結果にするためです。 |
| pre-commit フレームワークを使わず、Git フックから `make lint typecheck` を呼ぶ | 検査の定義を `Makefile` の 1 か所にするためです。 |
