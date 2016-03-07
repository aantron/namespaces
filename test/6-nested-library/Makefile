OCAMLBUILD := \
	ocamlbuild -use-ocamlfind -plugin-tag "package(namespaces)" -no-links \
		-quiet

.PHONY : test
test : clean
	$(OCAMLBUILD) base.cma base.cmxa unix.cma unix.cmxa
	make install

.PHONY : clean
clean :
	ocamlbuild -clean

PACKAGE := namespaces-nested-lib-test
INSTALL := \
	_build/base.cma _build/base.cmxa _build/base.a \
	_build/unix.cma _build/unix.cmxa _build/unix.a \
	$(shell find _build -name *.cmi) \
	$(shell find _build -name *.cmt) \
	$(shell find _build -name *.cmti)

.PHONY : install
install : uninstall
	ocamlfind install $(PACKAGE) META $(INSTALL)

.PHONY : uninstall
uninstall :
	ocamlfind remove $(PACKAGE)
