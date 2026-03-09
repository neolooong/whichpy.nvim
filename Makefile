.PHONY: test test_deps format format-check

test_deps:
ifeq (,$(wildcard test_deps/plenary.nvim))
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim test_deps/plenary.nvim
endif

test: test_deps
	nvim --headless --noplugin -u scripts/minimal_init.lua -c "PlenaryBustedDirectory tests {minimal_init='./scripts/minimal_init.lua'}"

format:
	stylua lua/

format-check:
	stylua --check lua/
