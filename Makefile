.PHONY: help
help :
	@echo
	@echo 'Commands:'
	@echo
	@echo '  make test                  run unit tests'
	@echo '  make lint                  run linter'
	@echo '  make format                run code formatter, giving a diff for recommended changes'
	@echo '  make venv                  prepare virtualenv'
	@echo

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
