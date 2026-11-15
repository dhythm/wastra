#!/usr/bin/env bash
# 開発環境を何度実行しても同じ状態に収束させる。CI も同じスクリプトを使う。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bench_dir="${BENCH_DIR:-$repo_root/.bench}"
site_name="${SITE_NAME:-wastra.localhost}"
frappe_branch="version-16"
python_version="3.14"

cd "$repo_root"

if [[ "$(id -u)" == 0 ]]; then
	echo "bench は root では動きません。一般ユーザーで実行してください（README を参照）" >&2
	exit 1
fi

for required_command in uv node npx mariadb; do
	command -v "$required_command" >/dev/null || {
		echo "必要なコマンドがありません: $required_command（README の前提条件を参照）" >&2
		exit 1
	}
done


git config core.hooksPath tools/githooks

./scripts/services.sh
grep --quiet '^ADMIN_PASSWORD=' .env || printf 'ADMIN_PASSWORD=%s\n' "$(openssl rand -hex 24)" >>.env
set -a && source .env && set +a

export PATH="$repo_root/tools/bin:$PATH"
bench() { uvx --python "$python_version" --from frappe-bench bench "$@"; }

if [[ ! -d "$bench_dir/apps/frappe" ]]; then
	uv python install "$python_version"
	bench init "$bench_dir" \
		--frappe-branch "$frappe_branch" \
		--python "$(uv python find "$python_version")" \
		--skip-redis-config-generation \
		--no-backups \
		${BENCH_INIT_EXTRA_ARGS:-}
fi

cd "$bench_dir"

redis_url="redis://127.0.0.1:${REDIS_PORT:-6379}"
bench set-config --global db_host 127.0.0.1
bench set-config --global --parse db_port "${MARIADB_PORT:-3306}"
bench set-config --global redis_cache "$redis_url"
bench set-config --global redis_queue "$redis_url"
bench set-config --global redis_socketio "$redis_url"
bench set-config --global --parse developer_mode 1

ln -sfn "$repo_root" apps/wastra
uv pip install --quiet --python env/bin/python --editable apps/wastra --group "$repo_root/pyproject.toml:dev"
printf 'frappe\nwastra\n' >sites/apps.txt

if [[ ! -d "sites/$site_name" ]]; then
	bench new-site "$site_name" \
		--mariadb-root-password "$MARIADB_ROOT_PASSWORD" \
		--mariadb-user-host-login-scope='%' \
		--admin-password "$ADMIN_PASSWORD" \
		--install-app wastra
fi
bench --site "$site_name" set-config --parse allow_tests True

bench use "$site_name"
bench --site "$site_name" migrate
bench --site "$site_name" execute frappe.desk.page.setup_wizard.setup_wizard.setup_complete \
	--kwargs '{"args": {"language": "日本語", "country": "Japan", "timezone": "Asia/Tokyo", "currency": "JPY"}}'

echo "セットアップ完了: make check / make test を実行できます"
