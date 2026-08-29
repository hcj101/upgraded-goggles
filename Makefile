SHELL := /bin/bash
-include .env
export

.PHONY: help build up down migrate run run-config test lint push-acr submit

help:
	@grep -E '^[a-z-]+:.*?##' $(MAKEFILE_LIST) | sed 's/:.*##/\t/'

build:       ## build all three images
	docker compose build

up:          ## start postgres, api and interface
	docker compose up -d postgres api interface

down:
	docker compose down

migrate:     ## apply pending SQL migrations
	docker compose run --rm pipeline bash /app/sql/run_migrations.sh

run:         ## run the example config end to end
	docker compose run --rm pipeline python launch.py /app/input/000_example.yml

run-config:  ## make run-config CONFIG=input/foo.yml
	docker compose run --rm pipeline python launch.py /app/$(CONFIG)

test:
	docker compose run --rm pipeline pytest -q
	docker compose run --rm api pytest -q

lint:
	docker compose run --rm pipeline ruff check /app/pipeline /app/core

push-acr:    ## build and push all three images
	bash bash/push_to_acr.sh pipeline
	bash bash/push_to_acr.sh api
	bash bash/push_to_acr.sh interface

submit:      ## make submit CONFIG=blob://user-uploads/x.yml
	bash bash/submit_job.sh $(CONFIG)
