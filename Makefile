BUILD_DIR := build
GODOT := tools/godot/godot
JOBS := $(shell nproc)

.PHONY: all configure build test test-kernel test-godot clean import

all: build

configure:
	cmake -S . -B $(BUILD_DIR) -G Ninja

build: configure
	cmake --build $(BUILD_DIR) -j $(JOBS)

test-kernel: build
	./$(BUILD_DIR)/sxkernel/sxkernel_tests

# First import bakes .godot cache; needed once before running scripts headless.
import: build
	$(GODOT) --headless --path game --import > /dev/null 2>&1 || true

test-godot: build import
	$(GODOT) --headless --path game --script tests/run_tests.gd
	$(GODOT) --headless --path game --script tests/run_ui_tests.gd
	$(GODOT) --headless --path game --script tests/run_sketch_tests.gd
	$(GODOT) --headless --path game --script tests/run_sketch_tools_tests.gd
	$(GODOT) --headless --path game --script tests/run_display_tests.gd
	$(GODOT) --headless --path game --script tests/run_menu_tests.gd
	$(GODOT) --headless --path game --script tests/run_workflow_tests.gd

test: test-kernel test-godot
	@echo "ALL TESTS PASSED"

run: build import
	$(GODOT) --path game

clean:
	rm -rf $(BUILD_DIR)
