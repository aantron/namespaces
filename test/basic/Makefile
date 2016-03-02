OCAMLBUILD := \
	ocamlbuild -use-ocamlfind -plugin-tag "package(namespaces)" -no-links \
		-quiet

.PHONY : all
all : success original_name_hidden

# - Directories not tagged with "namespace" don't become namespaces.
# - Directories tagged with "namespace" do become namespaces.
# - Namespaces can be nested.
# - Top-level modules remain accessible even if there is a nested module with
#   the same base name.
# - Modules can refer to their siblings.
# - All of the above holds true for bytecode as well as native code.
# - Modules in one namespace can refer to modules in another.
.PHONY : success
success :
	make clean
	$(OCAMLBUILD) success.native --
	make clean
	$(OCAMLBUILD) success.byte --

# The unqualified names of nested modules are not visible.
.PHONY : original_name_hidden
original_name_hidden : clean
	! $(OCAMLBUILD) original_name_hidden.native --

.PHONY : clean
clean :
	ocamlbuild -clean
