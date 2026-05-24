INC=-I./inc
MPIC=mpic++

.PHONY: build
build: ./bin/4_4 ./bin/4_1

.PHONY: clean
clean:
	rm -f ./bin/*
	
.PHONY: rebuild
rebuild: clean build

./bin/4_4: ./src/4_4.cpp ./src/heat_shared.cpp
	$(MPIC) -std=c++20 -O3 -o $@ $^ $(INC)

./bin/4_1: ./src/4_1.cpp ./src/heat_shared.cpp
	$(MPIC) -std=c++20 -O3 -o $@ $^ $(INC)
