PACKAGE := namespaces
TARGETS := namespaces.cma namespaces.cmxa namespaces.cmi

INSTALL := $(foreach target,$(TARGETS),_build/$(target)) namespaces.mli

OCAMLBUILD := ocamlbuild -use-ocamlfind

.PHONY : all install uninstall clean docs internal-docs

all :
	$(OCAMLBUILD) namespaces.cma namespaces.cmxa

install :
	ocamlfind install $(PACKAGE) META $(INSTALL) _build/namespaces.a

uninstall :
	ocamlfind remove $(PACKAGE)

clean :
	ocamlbuild -clean

docs :
	$(OCAMLBUILD) docs.docdir/index.html

internal-docs :
	$(OCAMLBUILD) internal.docdir/index.html
