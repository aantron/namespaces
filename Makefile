PACKAGE := namespaces
TARGETS := src/namespaces.cma src/namespaces.cmxa src/namespaces.cmi

INSTALL := \
	$(foreach target,$(TARGETS),_build/$(target)) src/namespaces.mli \
	_build/src/namespaces.cmt _build/src/namespaces.cmti

CFLAGS := -bin-annot
OCAMLBUILD := ocamlbuild -use-ocamlfind -cflags $(CFLAGS)

.PHONY : test build install uninstall clean

build :
	$(OCAMLBUILD) src/namespaces.cma src/namespaces.cmxa

install : uninstall build
	ocamlfind install $(PACKAGE) src/META $(INSTALL) _build/src/namespaces.a

test : install
	make -C test

uninstall :
	ocamlfind remove $(PACKAGE)

clean :
	ocamlbuild -clean
	make -C test clean
