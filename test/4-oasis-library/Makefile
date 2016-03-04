.PHONY : test
test : clean
	oasis setup
	ocaml setup.ml -configure
	ocaml setup.ml -build
	make install

.PHONY : clean
clean :
	ocamlbuild -clean
	rm -f setup.data setup.*
	find src/ -name '*.mllib' | xargs rm -f
	find src/ -name '*.mldylib' | xargs rm -f

PACKAGE := namespaces-oasis-lib-test
INSTALL := \
	_build/src/lib_1.cma \
	_build/src/lib_1.cmxa \
	_build/src/lib_1.a \
	_build/src/lib_2.cma \
	_build/src/lib_2.cmxa \
	_build/src/lib_2.a \
	$(shell find _build/src -name *.cmi) \
	$(shell find _build/src -name *.cmt) \
	$(shell find _build/src -name *.cmti)

.PHONY : install
install : uninstall
	ocamlfind install $(PACKAGE) src/META $(INSTALL)

.PHONY : uninstall
uninstall :
	ocamlfind remove $(PACKAGE)
