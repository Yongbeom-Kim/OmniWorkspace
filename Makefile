.PHONY: setup

setup:
	cp ./git-hooks/pre-commit ./.git/hooks/pre-commit
	chmod +x ./.git/hooks/pre-commit

fmt:
	shfmt -w main.sh