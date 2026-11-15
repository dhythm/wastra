#!/usr/bin/env bash
# MariaDB と Redis を起動する。起動済みなら何もしない。
# Docker が使える環境では compose.yaml を使い、使えない環境（クラウドのエージェント環境など）では
# 同じ 2 つをプロジェクト内のプロセスとして起動する。最初に選んだ方式は .env に記録して使い続ける。
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

touch .env && chmod 600 .env
grep --quiet '^MARIADB_ROOT_PASSWORD=' .env || printf 'MARIADB_ROOT_PASSWORD=%s\n' "$(openssl rand -hex 24)" >>.env
if ! grep --quiet '^WASTRA_SERVICES=' .env; then
	if [[ -n "${WASTRA_SERVICES:-}" ]]; then
		chosen_mode="$WASTRA_SERVICES"
	elif docker info >/dev/null 2>&1; then
		chosen_mode=docker
	else
		chosen_mode=local
	fi
	printf 'WASTRA_SERVICES=%s\n' "$chosen_mode" >>.env
fi
set -a && source .env && set +a

mariadb_port="${MARIADB_PORT:-3306}"
redis_port="${REDIS_PORT:-6379}"

if [[ "$WASTRA_SERVICES" == docker ]]; then
	exec docker compose up --detach --wait
fi

for required_command in mariadbd mariadb-install-db mariadb-admin redis-server redis-cli; do
	command -v "$required_command" >/dev/null || {
		echo "Docker を使わない方式には $required_command が必要です（README の前提条件を参照）" >&2
		exit 1
	}
done

data_dir="$repo_root/.services"
socket="$data_dir/mariadb.sock"
mkdir -p "$data_dir"

mariadb_is_up() { mariadb-admin --socket="$socket" --user=root --password="$1" ping >/dev/null 2>&1; }

start_mariadb() {
	nohup mariadbd \
		--datadir="$data_dir/mariadb" \
		--socket="$socket" \
		--pid-file="$data_dir/mariadb.pid" \
		--port="$mariadb_port" \
		--bind-address=127.0.0.1 \
		--character-set-server=utf8mb4 \
		--collation-server=utf8mb4_unicode_ci \
		--skip-character-set-client-handshake \
		>"$data_dir/mariadb.log" 2>&1 &
	for _ in $(seq 1 60); do
		mariadb_is_up "$1" && return
		sleep 0.5
	done
	echo "MariaDB が起動しませんでした。$data_dir/mariadb.log を確認してください" >&2
	exit 1
}

if [[ ! -d "$data_dir/mariadb/mysql" ]]; then
	mariadb-install-db --datadir="$data_dir/mariadb" \
		--auth-root-authentication-method=normal --skip-test-db >"$data_dir/mariadb-install.log" 2>&1
	start_mariadb ""
	mariadb --socket="$socket" --user=root <<-SQL
		ALTER USER 'root'@'localhost' IDENTIFIED BY '$MARIADB_ROOT_PASSWORD';
		CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY '$MARIADB_ROOT_PASSWORD';
		GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
	SQL
elif ! mariadb_is_up "$MARIADB_ROOT_PASSWORD"; then
	start_mariadb "$MARIADB_ROOT_PASSWORD"
fi

if ! redis-cli -p "$redis_port" ping >/dev/null 2>&1; then
	redis-server --port "$redis_port" --bind 127.0.0.1 --daemonize yes \
		--dir "$data_dir" --pidfile "$data_dir/redis.pid" --logfile "$data_dir/redis.log" --save "" >/dev/null
fi
