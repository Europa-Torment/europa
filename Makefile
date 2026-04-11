SHELL := /bin/bash
export PATH := $(HOME)/.asdf/shims:$(PATH)

.PHONY: test
test:
	MIX_ENV=test mix test --exclude slow:true --exclude perfomance:true

.PHONY: test-all
test-all:
	MIX_ENV=test mix test

.PHONY: test-perfomance
test-perfomance:
	MIX_ENV=test mix test --only perfomance:true

.PHONY: analyze-code
analyze-code:
	mix credo

.PHONY: coverage 
coverage: 
	MIX_ENV=test mix coveralls --exclude perfomance:true

.PHONY: coverage-lint
coverage-lint:
	MIX_ENV=test mix coveralls.lint --required-project-coverage=0.90 --missed-lines-threshold=4 --required-file-coverage=0.60

.PHONY: check-all
check-all:
	MIX_ENV=test make coverage-lint
	make analyze-code

.PHONY: release
release:
	mix local.hex --force
	mix local.rebar --force
	mix deps.get --only prod
	npm ci --prefix assets
	MIX_ENV=prod mix prepare_tiles
	MIX_ENV=prod mix phx.copy default
	MIX_ENV=prod mix assets.deploy
	MIX_ENV=prod mix compile
	MIX_ENV=prod mix release --overwrite
	mix phx.digest.clean --all