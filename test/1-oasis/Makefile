.PHONY : test
test : clean
	oasis setup
	ocaml setup.ml -configure
	ocaml setup.ml -build
	./foo.byte

.PHONY : clean
clean :
	ocamlbuild -clean
	rm -f setup.data setup.* *.byte
