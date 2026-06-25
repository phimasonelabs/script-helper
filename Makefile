# Convenience wrapper around ./install.sh
# Override the bin dir:   make install BINDIR=/usr/local/bin
# Install one tool:       make install TOOL=claude-switch
BINDIR ?= $(HOME)/.local/bin
TOOL   ?=

.PHONY: install link uninstall list help

help:
	@./install.sh --help

list:
	@./install.sh --list --bindir "$(BINDIR)"

install:
	@./install.sh --bindir "$(BINDIR)" $(TOOL)

link:
	@./install.sh --link --bindir "$(BINDIR)" $(TOOL)

uninstall:
	@./install.sh --uninstall --bindir "$(BINDIR)" $(TOOL)
