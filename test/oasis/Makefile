.PHONY : test clean

test : clean
	oasis setup
	ocaml setup.ml -configure
	ocaml setup.ml -build
	./foo.byte

clean :
	ocamlbuild -clean
	rm -f setup.data setup.*
