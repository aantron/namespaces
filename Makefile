PACKAGE := namespaces
TARGETS := src/namespaces.cma src/namespaces.cmxa src/namespaces.cmi

INSTALL := \
	$(foreach target,$(TARGETS),_build/$(target)) src/namespaces.mli \
	_build/src/namespaces.cmt _build/src/namespaces.cmti

CFLAGS := -bin-annot
OCAMLBUILD := ocamlbuild -use-ocamlfind -cflags $(CFLAGS)

.PHONY : build
build :
	$(OCAMLBUILD) src/namespaces.cma src/namespaces.cmxa

.PHONY : install
install : uninstall build
	ocamlfind install $(PACKAGE) src/META $(INSTALL) _build/src/namespaces.a

.PHONY : uninstall
uninstall :
	ocamlfind remove $(PACKAGE)

.PHONY : test
test :
	make -C test

.PHONY : clean
clean :
	ocamlbuild -clean
	make -C test clean
