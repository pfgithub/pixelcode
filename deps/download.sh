#!/bin/sh

set -e

rm -rf deps/build
mkdir deps/build

cd deps/build
    git clone https://github.com/tree-sitter/tree-sitter.git
    cd tree-sitter
        # before breaking change
        git reset --hard c393591e1db759c0f16f877165a6370d06b22472
    cd ..
	git clone https://github.com/GrayJack/tree-sitter-zig.git
    cd tree-sitter/lib
        echo "Building tree-sitter with allowed undefined behaviour"
        gcc -O3 -c -o src/lib.o -I src -I include src/lib.c
        echo "Done building tree-sitter"
    cd ..
cd ../..