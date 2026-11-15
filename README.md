# Wastra

地方の現場業務（清掃、設備点検、保守）向けの業務管理 SaaS です。[Frappe Framework](https://frappe.io/framework) v16 のアプリです。

開発のルールは [AGENTS.md](AGENTS.md)、設計は [ARCHITECTURE.md](ARCHITECTURE.md) にあります。

## 開発環境を作る

次のものを先に入れます。

- [uv](https://docs.astral.sh/uv/)。Python 3.14 と bench は `make setup` が uv 経由で取得します。
- Node.js 24
- Docker
- MariaDB のクライアントと開発用ライブラリ。macOS では `brew install mariadb pkg-config` で入ります。Ubuntu では `apt-get install mariadb-client libmariadb-dev pkg-config` で入ります。

リポジトリのルートで実行します。

```bash
make setup
```

初回は Frappe の取得とビルドで数分かかります。`make setup` は MariaDB と Redis を Docker で起動し、`.bench/` に bench を作り、サイト `wastra.localhost` に Wastra をインストールします。

## 動かす

```bash
make start
```

ブラウザで `http://wastra.localhost:8000` を開きます。ユーザー名は `Administrator` です。パスワードは `.env` の `ADMIN_PASSWORD` です。

## 変更を検査する

```bash
make check
```

lint、型、単体テスト、統合テストをすべて実行します。コミット時には Git フックが `make lint typecheck` を実行します。
