.PHONY: help
help :
	@echo
	@echo 'Commands:'
	@echo
	@echo '  make test                  run unit tests'
	@echo '  make lint                  run linter'
	@echo '  make format                run code formatter, giving a diff for recommended changes'
	@echo '  make venv                  prepare virtualenv'
	@echo '  make lambda                build lambda-deployable zip archive'
	@echo '  make deploy                rebuild lambda and push it up'
	@echo

.PHONY: deploy
deploy: clean lambda
	terraform apply -target=aws_lambda_function.dontspendtoomuch

.PHONY: lambda
lambda: dontspendtoomuch-lambda.zip
dontspendtoomuch-lambda.zip: venv dontspendtoomuch.py
# Install dependencies into a 'build-deps' directory
	. venv/bin/activate; pip install --no-compile --no-cache-dir --target=./build-deps .
# Delete python metadata; we won't be needing it up in lambda
	find ./build-deps -name "*.dist-info" -depth -type d -exec rm -rf "{}" +
# Bundle all the deps into a zip file. Make sure they're at the root level of
# the resulting zip - we 'cd' in order to accomplish that.
	cd build-deps; zip -r9 ../dontspendtoomuch-lambda.zip .
# Add the main script, dontspendtoomuch.py, to the zip result
	zip -g dontspendtoomuch-lambda.zip dontspendtoomuch.py
	rm -rf ./build-deps

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
	rm -rf dontspendtoomuch-lambda.zip
	rm -rf ./build-deps
