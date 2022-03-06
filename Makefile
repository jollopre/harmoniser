.PHONY: build clean down install lint lint_fix logs shell start_dependencies test up

build:
	docker compose build --no-cache
clean:
	docker compose down --rmi all --volumes
down:
	docker compose down --remove-orphans
install:
	docker compose exec gem bundle install
lint:
	docker compose exec gem standardrb
lint_fix:
	docker compose exec gem standardrb --fix
logs:
	docker compose logs
shell: start_dependencies
	docker compose run --rm gem sh
start_dependencies:
	docker compose run --rm start_dependencies
test: start_dependencies
	docker compose run --rm gem bundle exec rake
up: start_dependencies
	docker compose up -d
