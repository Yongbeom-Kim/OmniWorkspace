.PHONY: setup test

setup:
	cp ./git-hooks/pre-commit ./.git/hooks/pre-commit
	chmod +x ./.git/hooks/pre-commit

fmt:
	shfmt -w main.sh

test:
	bash tests/test-runner.sh

test-verbose:
	bash tests/test-runner.sh -v