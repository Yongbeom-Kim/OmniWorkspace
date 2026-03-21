.PHONY: install-dev setup fmt test test-verbose test-smoke test-smoke-verbose

install-dev:
	sudo ln -sf "$(CURDIR)/main.sh" /usr/local/bin/ows

setup:
	cp ./git-hooks/pre-commit ./.git/hooks/pre-commit
	chmod +x ./.git/hooks/pre-commit

fmt:
	shfmt -w main.sh

test:
	bash tests/test-runner.sh

test-verbose:
	bash tests/test-runner.sh -v

test-smoke:
	bash tests/test-runner.sh -f tests/TestImage.Dockerfile

test-smoke-verbose:
	bash tests/test-runner.sh -v -f tests/TestImage.Dockerfile