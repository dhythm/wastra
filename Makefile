SHELL := /bin/bash
.DEFAULT_GOAL := check

TOOLS ?= .bench/env/bin
BIOME := npx --yes @biomejs/biome@2.6.7
BENCH := cd .bench && PATH="$(CURDIR)/tools/bin:$$PATH" uvx --python 3.14 --from frappe-bench bench
SITE := wastra.localhost

# vulture の --ignore-names は pyproject.toml の ignore_names を置き換えるので、ここで合成して渡す。
# DocType のクラス名とフィールド名は Frappe が JSON から名前で参照する。
frappe_invoked_names = $(shell $(TOOLS)/python -c "import json, pathlib, tomllib; \
	doctypes = [json.loads(p.read_text()) for p in pathlib.Path('wastra').glob('*/doctype/*/*.json')]; \
	print(','.join(tomllib.loads(pathlib.Path('pyproject.toml').read_text())['tool']['vulture']['ignore_names'] \
	+ [d['name'].replace(' ', '') for d in doctypes] + [f['fieldname'] for d in doctypes for f in d['fields']]))")

.PHONY: setup start check fix lint typecheck test-unit test-integration test

setup: ## 開発環境を作る。何度実行してもよい
	./scripts/setup.sh

start: ## http://wastra.localhost:8000 で起動する
	docker compose up --detach --wait
	$(BENCH) start

check: lint typecheck test ## コミット前に通す全チェック

fix: ## 自動修正できるものを直す
	$(TOOLS)/ruff check --fix
	$(TOOLS)/ruff format
	$(BIOME) check --write --no-errors-on-unmatched wastra

lint: ## bench なしで動く静的チェック
	$(TOOLS)/ruff check
	$(TOOLS)/ruff format --check
	$(TOOLS)/vulture --ignore-names "$(frappe_invoked_names)"
	$(BIOME) check --no-errors-on-unmatched wastra

typecheck:
	$(TOOLS)/mypy

test-unit: ## DB を使わないテスト
	$(BENCH) --site $(SITE) run-tests --app wastra --test-category unit

test-integration: ## DB を使うテスト
	$(BENCH) --site $(SITE) run-tests --app wastra --test-category integration

test: test-unit test-integration
