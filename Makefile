build:
	docker build -t harmoniser .
shell:
	docker run -it -v ${PWD}:/opt --rm harmoniser:test sh
test:
	docker build -t harmoniser:test .
	docker run --rm harmoniser:test bundle exec rake
