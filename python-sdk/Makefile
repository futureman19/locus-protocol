# Locus Protocol Python SDK Makefile

.PHONY: help install install-dev test test-cov lint format type-check clean build publish

help:
	@echo "Locus Protocol Python SDK"
	@echo ""
	@echo "Available commands:"
	@echo "  install      Install package"
	@echo "  install-dev  Install with dev dependencies"
	@echo "  test         Run tests"
	@echo "  test-cov     Run tests with coverage"
	@echo "  lint         Run linter (ruff)"
	@echo "  format       Format code (black)"
	@echo "  type-check   Run type checker (mypy)"
	@echo "  clean        Clean build artifacts"
	@echo "  build        Build package"
	@echo "  publish      Publish to PyPI"

install:
	pip install -e .

install-dev:
	pip install -e ".[dev]"

test:
	pytest -v

test-cov:
	pytest --cov=locus --cov-report=term-missing --cov-report=html

lint:
	ruff check locus tests

format:
	black locus tests

format-check:
	black --check locus tests

type-check:
	mypy locus

clean:
	rm -rf build/
	rm -rf dist/
	rm -rf *.egg-info/
	rm -rf .pytest_cache/
	rm -rf .mypy_cache/
	rm -rf htmlcov/
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete

build: clean
	python -m build

publish: build
	twine check dist/*
	twine upload dist/*

# Development shortcuts
run-example-1:
	python examples/01_found_city.py

run-example-2:
	python examples/02_claim_territory.py

run-example-3:
	python examples/03_deploy_ghost.py

run-example-4:
	python examples/04_governance.py

run-example-5:
	python examples/05_treasury_ubi.py

run-example-6:
	python examples/06_full_transaction.py

run-all-examples:
	python examples/01_found_city.py
	python examples/02_claim_territory.py
	python examples/03_deploy_ghost.py
	python examples/04_governance.py
	python examples/05_treasury_ubi.py
	python examples/06_full_transaction.py
