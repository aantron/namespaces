OCAMLBUILD := ocamlbuild -use-ocamlfind -no-links

.PHONY : unit
unit : rebuild
	$(OCAMLBUILD) test_main.native -- -runner sequential

.PHONY : one
one : rebuild
	$(OCAMLBUILD) test_main.native -- -runner sequential -only-test $(NAME)

.PHONY : clean
clean :
	ocamlbuild -clean
	rm -rf _plugin_findlib _project _project_findlib _depending

.PHONY : rebuild
rebuild :
	make -C ..
