all: build

ocamlfind_check=$(shell ocamlfind query $(1) > /dev/null 2> /dev/null && echo "true")

LWT=$(call ocamlfind_check,lwt)
ifeq ($(LWT), true)
	LWT_FLAG=--enable-lwt
endif

UNIX_FLAG=--enable-unix

TESTS_FLAG=--enable-tests

FLAGS=-use-ocamlfind
TESTS_PKGS=oUnit
OVERAGE_TAGS=package\(bisect\),syntax\(camlp4o\),syntax\(bisect_pp\)

NAME=osc
J=4

setup.ml: _oasis
	oasis setup

setup.data: setup.ml
	ocaml setup.ml -configure $(LWT_FLAG) $(UNIX_FLAG) $(TESTS_FLAG)

build: setup.data
	ocaml setup.ml -build -j $(J)

doc: setup.data
	ocaml setup.ml -doc -j $(J)

install: setup.data
	ocaml setup.ml -install

uninstall:
	ocamlfind remove $(NAME)

reinstall: setup.data
	ocamlfind remove $(NAME) || true
	ocaml setup.ml -reinstall

clean:
	ocamlbuild -clean
	rm -f setup.data setup.log

test: build
	ocaml setup.ml -test

test-interop-sclang: build
	./test-interop-sclang.sh

coverage:
	ocamlbuild $(FLAGS) -pkgs $(TESTS_PKGS) -tags $(COVERAGE_TAGS) foo.byte bar.byte
	BISECT_FILE=_build/coverage ./foo.byte
	BISECT_FILE=_build/coverage ./bar.byte
