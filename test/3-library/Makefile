OCAMLBUILD := \
	ocamlbuild -use-ocamlfind -plugin-tag "package(namespaces)" -no-links \
		-cflags -bin-annot

.PHONY : build
build : clean
	$(OCAMLBUILD) lib_1.cma lib_1.cmxa lib_2.cma lib_2.cmxa
	make install

.PHONY : clean
clean :
	ocamlbuild -clean

PACKAGE := namespaces-lib-test
INSTALL := \
	_build/lib_1.cma \
	_build/lib_1.cmxa \
	_build/lib_1.a \
	_build/lib_2.cma \
	_build/lib_2.cmxa \
	_build/lib_2.a \
	$(shell find _build/src -name *.cmi) \
	$(shell find _build/src -name *.cmt) \
	$(shell find _build/src -name *.cmti)

.PHONY : install
install : uninstall
	ocamlfind install $(PACKAGE) META $(INSTALL)

.PHONY : uninstall
uninstall :
	ocamlfind remove $(PACKAGE)
