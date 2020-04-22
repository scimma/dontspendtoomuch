.PHONY: help
help :
	@echo
	@echo 'Commands:'
	@echo
	@echo '  make test                  run unit tests'
	@echo '  make lint                  run linter'
	@echo '  make format                run code formatter, giving a diff for recommended changes'
	@echo '  make venv                  prepare virtualenv'
	@echo '  make lambda                build lambda-deployable zip archives'
	@echo '  make deploy                rebuild lambda and push it up'
	@echo

.PHONY: deploy
deploy: deploy-deps deploy-script

.PHONY: deploy-deps
deploy-deps: dontspendtoomuch-deps.zip
	aws s3 cp dontspendtoomuch-deps.zip s3://scimma-deployables/dontspendtoomuch/latest/dependencies.zip

.PHONY: deploy-script
deploy-script: dontspendtoomuch-script.zip
	aws s3 cp dontspendtoomuch-script.zip s3://scimma-deployables/dontspendtoomuch/latest/script.zip

.PHONY: lambda
lambda: dontspendtoomuch-script.zip dontspendtoomuch-deps.zip
dontspendtoomuch-deps.zip: venv setup.py
# Install dependencies into a 'build-deps' directory
	. venv/bin/activate; pip install --no-compile --no-cache-dir --target=./build-deps/python .
# Delete python metadata; we won't be needing it up in lambda
	find ./build-deps -name "*.dist-info" -depth -type d -exec rm -rf "{}" +
# Bundle all the deps into a zip file. Make sure they're at the root level of
# the resulting zip - we 'cd' in order to accomplish that.
	cd build-deps; zip -r9 ../dontspendtoomuch-deps.zip .
	rm -rf ./build-deps

dontspendtoomuch-script.zip: venv dontspendtoomuch.py
	zip -r9 dontspendtoomuch-script.zip dontspendtoomuch.py

.PHONY: test
test: venv
	. venv/bin/activate; python -m pytest

.PHONY: lint
lint: venv
	. venv/bin/activate; flake8 . --count --exit-zero --max-line-length=100 --statistics

.PHONY: format
format: venv
	. venv/bin/activate; autopep8 .

venv: venv/bin/activate
venv/bin/activate: setup.py
	virtualenv venv
	. venv/bin/activate; pip install -e '.[dev]'

.PHONY: clean
clean:
	rm -rf venv
	rm -rf __pycache__
	rm -rf .pytest_cache
	rm -rf dontspendtoomuch.egg-info
	rm -rf dontspendtoomuch-deps.zip
	rm -rf dontspendtoomuch-script.zip
	rm -rf ./build-deps
