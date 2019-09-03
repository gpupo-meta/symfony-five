.SILENT:
.PHONY: help

NORMAL_CONSOLE=bin/console
CRONTAB_CONSOLE=bin/console --no-interaction --no-ansi --no-debug
TEST_CONSOLE=APP_ENV=test bin/console

## Colors
COLOR_RESET=\033[0m
COLOR_INFO=\033[32m
COLOR_COMMENT=\033[33m
COLOR_ERROR=\033[31m
SHELL:=/bin/bash

## VERBOSE=-vv
VERBOSE=

define run_console_command
	printf "\n\nRunning command ${COLOR_COMMENT} ${1} ${COLOR_RESET}\n"
    $(CRONTAB_CONSOLE) ${1} ${VERBOSE} || printf "\n Command ${COLOR_COMMENT}${1}${COLOR_RESET} ${COLOR_ERROR}FAIL${COLOR_RESET}\n\n\\n"
endef

## List Targets and Descriptions
help:
	printf "${COLOR_COMMENT}Usage:${COLOR_RESET}\n"
	printf " make [target]\n\n"
	printf "${COLOR_COMMENT}Available targets:${COLOR_RESET}\n"
	awk '/^[a-zA-Z\-\_0-9\.@]+:/ { \
	helpMessage = match(lastLine, /^## (.*)/); \
	if (helpMessage) { \
	helpCommand = substr($$1, 0, index($$1, ":")); \
	helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
	printf " ${COLOR_INFO}%-16s${COLOR_RESET} %s\n", helpCommand, helpMessage; \
	} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)

__header:
	if [ ! -f /.dockerenv ]; then \
		printf "\n\n!!! ${COLOR_ERROR}This target is only available for execution inside a container!${COLOR_RESET}\n\n\n"; \
		$(MAKE) help; \
		exit 1; \
	else \
		printf "\n";\
	fi;

__bottom:
	printf "\nTarget ${COLOR_COMMENT}Done!${COLOR_RESET}\n";


## Setup environment & Install & Build application
setup:
	printf "${COLOR_COMMENT}Rebuild .env files${COLOR_RESET}\n"
	touch .env.local;
	ln -snf Resources/docker-compose.dev.yaml docker-compose.yaml
	$(MAKE) __bottom;

## Project warmup
warmup: __header
	mkdir -p ./var/cache/prod ./var/cache/dev ./var/cache/test > /dev/null
	touch ./var/cache/prod/env.local.php;
	rm ./var/cache/*/env.local.php || true;
	rm -f .env.local.php > /dev/null;
	if [ ${APP_ENV} == "prod" ]; then \
		printf "\ncomposer dump-env prod DISABLED\n"; \
	fi;
	$(NORMAL_CONSOLE) cache:clear --no-warmup;
	$(NORMAL_CONSOLE) cache:warmup;
	chmod -R 777 ./var/cache/*;
	echo '' > var/log/dev.log
	echo '' > var/log/test.log
	$(MAKE) doctrine-migrate;

## Project Setup
install: __header
	COMPOSER_MEMORY_LIMIT=3G composer install --no-scripts -n
	yarn install
	$(MAKE) webpack@build

## Composer Update and register packages
update: __header
	rm -f composer.lock symfony.lock > /dev/null
	COMPOSER_MEMORY_LIMIT=3G composer update --no-scripts -n
	composer info > Resources/statistics/composer-packages.txt

## Build dotenv
dotenv-build:
	cat `ls -1 ./.env.* | grep -v test` > ./.env
	printf "\nDotenv ${COLOR_COMMENT}Done!${COLOR_RESET}\n";

## Build dotenv; build CSS, JS for production
build:
	$(MAKE) dotenv-build;
	if [ -f /.dockerenv ]; then \
		$(MAKE) webpack@build; \
	fi

## Prepare Deploy executed ate escalade build_target_files
prepare-deploy:
	$(MAKE) dotenv-build;
	printf "${COLOR_COMMENT}Prepare to Deploy.${COLOR_RESET}\n";
	COMPOSER_MEMORY_LIMIT=3G composer install -o --no-progress --ignore-platform-reqs -n --no-dev --no-ansi --no-scripts;
	COMPOSER_MEMORY_LIMIT=3G composer dump-autoload --classmap-authoritative;

## Clean and test
test@fresh: clean install test-env phpunit behat

## Rebuild Database (test) and run fixtures
test-env: __header
	$(TEST_CONSOLE) cache:clear;
	$(TEST_CONSOLE) about;
	printf "${COLOR_COMMENT}Rebuild database${COLOR_RESET}\n";
	$(TEST_CONSOLE) doctrine:database:create -q || $(TEST_CONSOLE) doctrine:schema:drop --force --full-database -q;
	$(TEST_CONSOLE) doctrine:schema:update --force;
	$(TEST_CONSOLE) doctrine:fixtures:load --no-interaction;
	$(TEST_CONSOLE) doctrine:migrations:version --add --all --no-interaction  --no-ansi

## Run xUnit tests
phpunit: __header
ifndef group
	APP_ENV=test vendor/bin/simple-phpunit
else
	APP_ENV=test vendor/bin/simple-phpunit --group $(group)
endif

## Run xUnit test on verbose mode.
phpunit-verbose: __header
ifndef group
	APP_ENV=test vendor/bin/simple-phpunit --verbose
else
	APP_ENV=test vendor/bin/simple-phpunit --verbose --group $(group)
endif

## Test Env Vars
test@check-env: __header
	$(TEST_CONSOLE) about
	$(TEST_CONSOLE) debug:config
	$(TEST_CONSOLE) doctrine:query:sql "SELECT NOW()"
	$(MAKE) __bottom;

## Run Behat tests
behat: __header
	APP_ENV=test vendor/bin/behat --format=progress
	$(MAKE) __bottom;

## Clean temporary files
clean:
	printf "${COLOR_COMMENT}Remove temporary files${COLOR_RESET}\n"
	rm -f ./*.log ./*.cache
	rm -rf var/*
	$(MAKE) __bottom;

## Doctrine Migrate
doctrine-migrate: __header
	$(NORMAL_CONSOLE) doctrine:migrations:migrate --no-interaction
	$(MAKE) __bottom;

## Build webpack files (dev mode)
webpack@compile: __header
	yarn run encore dev
	$(MAKE) __bottom;

## Build webpack files (dev mode) and watch
webpack@watch: __header
	yarn run encore dev --watch
	$(MAKE) __bottom;

## Build webpack files (prod mode)
webpack@build: __header
	yarn run encore production
	$(MAKE) __bottom;

## View Javascript (Babel) CS broken rules
eslint@view: __header
	yarn run eslint assets/js/app/index.js assets/js/app/modules/*.js
	$(MAKE) __bottom;

## Dry Run Javascript (Babel) CS broken rules
eslint@fix: __header
	yarn run eslint --fix assets/js/app/index.js assets/js/app/modules/*.js
	$(MAKE) __bottom;
