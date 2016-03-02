PACKAGE := namespaces
TARGETS := src/namespaces.cma src/namespaces.cmxa src/namespaces.cmi

INSTALL := \
	$(foreach target,$(TARGETS),_build/$(target)) src/namespaces.mli \
	_build/src/namespaces.cmt _build/src/namespaces.cmti

DEV_INSTALL_DIR := _findlib

CFLAGS := -bin-annot
OCAMLBUILD := ocamlbuild -use-ocamlfind -cflags $(CFLAGS)

for_tests = \
	for TEST in `ls test` ; do $1 ; if [ $$? -ne 0 ] ; then exit 1 ; fi ; done

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
test : build
	$(call for_tests,make one NAME=$$TEST)

.PHONY : one
one : build
	@mkdir -p $(DEV_INSTALL_DIR)
	export OCAMLPATH=`pwd`/$(DEV_INSTALL_DIR):$$OCAMLPATH && \
	export OCAMLFIND_DESTDIR=`pwd`/$(DEV_INSTALL_DIR) && \
	make install && \
	make -C test/$(NAME)

.PHONY : clean
clean :
	ocamlbuild -clean
	$(call for_tests,make -C test/$$TEST clean)
	rm -rf $(DEV_INSTALL_DIR)
