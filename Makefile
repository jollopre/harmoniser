.PHONY: build clean down install lint lint_fix logs shell test up

build:
	docker-compose build --no-cache
clean:
	docker-compose down --rmi all --volumes
down:
	docker-compose down --remove-orphans
install:
	docker-compose exec gem bundle install
lint:
	docker-compose exec gem standardrb
lint_fix:
	docker-compose exec gem standardrb --fix
logs:
	docker-compose logs
shell:
	docker-compose exec gem sh
test:
	docker-compose build
	docker-compose run --rm gem bundle exec rake
up:
	docker-compose up -d
