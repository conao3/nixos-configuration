all:

EMACS ?= emacs

build:
	keg build

lint:
	keg lint

test: build
	keg exec $(EMACS) --batch -l {{repo-name}}-tests.el -f cort-test-run

clean:
	keg clean
