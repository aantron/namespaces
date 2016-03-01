OCAMLBUILD := \
	ocamlbuild -use-ocamlfind -plugin-tag "package(namespaces)" -no-links

.PHONY : test clean

test :
	make clean
	$(OCAMLBUILD) main.native --
	make clean
	! $(OCAMLBUILD) bad.native
	make clean
	$(OCAMLBUILD) main.byte --
	make clean
	$(OCAMLBUILD) -byte-plugin main.native --
	make clean
	$(OCAMLBUILD) main.native --
	$(OCAMLBUILD) main.native --

clean :
	ocamlbuild -clean
