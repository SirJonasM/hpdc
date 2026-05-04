# Compiler and flags
CXX = mpic++
CXXSTD = -std=c++20
DEBUG_FLAGS = -g -Wall -Wextra -DDEBUG
RELEASE_FLAGS = -O3
INC = -I./inc

# Paths
SRC = main.cpp
DEBUG_OUT = ./build/main_dbg
RELEASE_OUT = ./build/main

# Check if we're in the right directory
$(if $(wildcard $(SRC)),,$(error Source file $(SRC) not found. Please run make from the directory containing $(SRC)))

# Default target
all: release

bin:
	mkdir -p build

# Debug build
debug: $(DEBUG_OUT)

$(DEBUG_OUT): $(SRC)
	$(CXX) $(SRC) -o $(DEBUG_OUT) $(CXXSTD) $(DEBUG_FLAGS) $(INC)

# Release build
release: $(RELEASE_OUT)

$(RELEASE_OUT): $(SRC) | bin
	$(CXX) $(SRC) -o $(RELEASE_OUT) $(CXXSTD) $(RELEASE_FLAGS) $(INC)

# Clean up
clean:
	rm -f $(DEBUG_OUT) $(RELEASE_OUT)

# Phony targets
.PHONY: all debug release clean
