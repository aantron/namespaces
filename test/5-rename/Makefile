OCAMLBUILD := \
	ocamlbuild -use-ocamlfind -plugin-tag "package(namespaces)" -no-links

.PHONY : test
test : clean
	$(OCAMLBUILD) library.cma library.cmxa
	make install

.PHONY : clean
clean :
	ocamlbuild -clean

PACKAGE := namespaces-rename-test
INSTALL := \
	_build/library.cma \
	_build/library.cmxa \
	_build/library.a \
	$(shell find _build -name *.cmi) \
	$(shell find _build -name *.cmt) \
	$(shell find _build -name *.cmti)

.PHONY : install
install : uninstall
	ocamlfind install $(PACKAGE) META $(INSTALL)

.PHONY : uninstall
uninstall :
	ocamlfind remove $(PACKAGE)

