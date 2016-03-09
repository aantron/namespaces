OCAMLBUILD := \
	ocamlbuild -use-ocamlfind -plugin-tag "package(namespaces)" -no-links

.PHONY : all
all :
	make not_linked
	make linked

# - A sibling module is not automatically linked (already tested implicitly by
#   other tests).
# - (Does not work at the moment) Changing the sibling module does not cause
#   recompilation.
.PHONY : not_linked
not_linked : clean prepare
	$(OCAMLBUILD) not_linked.native --
	make twiddle
	$(OCAMLBUILD) not_linked.native --
	$(OCAMLBUILD) not_linked.native --

# - That sibling module is present, however.
# - Changing a child module causes recompilation of referring modules, if they
#   reference it.
.PHONY : linked
linked : clean prepare
	! $(OCAMLBUILD) linked.native --
	make twiddle
	! $(OCAMLBUILD) linked.native --
	! $(OCAMLBUILD) linked.native --

.PHONY : prepare
prepare :
	cp -r ../common/src .

.PHONY : twiddle
twiddle :
	sed -i -e 's/linked in/linked in!/' src/namespace/nested/not_referenced.ml

.PHONY : clean
clean :
	ocamlbuild -clean
	rm -rf src
