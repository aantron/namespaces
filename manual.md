# Namespaces

- [Building libraries](#Libraries)
  - [With Ocamlbuild](#LibrariesOcamlbuild)
  - [With OASIS](#LibrariesOASIS)
- [Generated files](#Generated)
- [Effect on separate compilation](#SeparateCompilation)



<br>

<a id="Libraries"></a>
## Building libraries

These instructions are in addition to the main instructions in
[README.md][readme-instructions]. Follow those first, then the ones in this
file.

[readme-instructions]: https://github.com/aantron/namespaces#instructions

<a id="LibrariesOcamlbuild"></a>
#### With Ocamlbuild

To build one or more libraries with Namespaces and Ocamlbuild:

1. Tag your library directories with the additional tag `namespace_lib`, like
   this:

        "src/lib_1" or "src/lib_2": namespace_lib

   That gives the tag structure:

        src/
        |-- lib_1/                      namespace, namespace_lib
        |   |-- namespace/              namespace
        |   |   |-- foo.ml
        |   |   +-- bar.ml
        |   |
        |   +-- other_namespace/        namespace
        |       +-- foo.ml
        |
        +-- lib_2/                      namespace, namespace_lib
            +-- namespace/              namespace
                |-- foo.ml
                +-- bar.ml

   These tags tell Namespaces to generate the requisite `.mllib` files for
   Ocamlbuild.

2. You can now build the library targets `lib_1.cma`, `lib_1.cmxa`, `lib_2.cma`,
   `lib_2.cmxa`.

3. To install the libraries with Findlib, describe the libraries as normal in a
   `META` file. Then, install it, together with the library files. For example,
   in `Makefile` syntax:

        TO_INSTALL :=                         \
            META                              \
            _build/src/lib_1.cma              \
            _build/src/lib_1.cmxa             \
            _build/src/lib_1.a                \
            _build/src/lib_2.cma              \
            _build/src/lib_2.cmxa             \
            _build/src/lib_2.a                \
            $(shell find _build -name *.cmi)  \
            $(shell find _build -name *.cmt)  \
            $(shell find _build -name *.cmti)

        install :
            ocamlfind install $(PACKAGE) $(TO_INSTALL)

See the [library test][libtest] for a small example.

[libtest]: https://github.com/aantron/namespaces/tree/master/test/3-library

<a id="LibrariesOASIS"></a>
#### With OASIS

To build libraries with Namespaces and OASIS:

1. Tag your library directories with `namespace_lib`, as described in step (1)
   above for Ocamlbuild.

2. Namespaces will now generate its own `.mllib` files, but these will conflict
   with the ones that OASIS generates from each `Library` section in `_oasis`.
   To fix that, the OASIS `.mllib` files need to be deleted. Make sure your
   project doesn't have any `.mllib` files that you want to keep, and then add
   the following to the bottom of your `myocamlbuild.ml`:

        let () = Namespaces.delete_mllib_files ()

   This is an unpleasant hack, and I hope to remove it in a future version of
   Namespaces.

3. When using Namespaces with OASIS, the `_oasis` file is essentially only for
   assembling the `META` file – at least with respect to these instructions. The
   `_oasis` file will look something like this:

        OASISFormat: 0.4
        Name:        my_lib
        Version:     0.1
        Synopsis:    Description
        Authors:     Me
        License:     BSD-2-clause
        BuildTools:  ocamlbuild
        Plugins:     META (0.3)

        OCamlVersion:           >= 4.02
        AlphaFeatures:          ocamlbuild_more_args
        XOCamlbuildPluginTags:  package(namespaces)

        Library lib_1
          FindlibName:      my_lib
          Path:             src
          Modules:          Lib_1
          XMETADescription: lib_1

        Library lib_2
          FindlibParent:    lib_1
          Path:             src
          Modules:          Lib_2
          XMETADescription: lib_2

4. Do not use `ocaml setup.ml -install` to install your library. Instead,
   install as in step (3) of the Ocamlbuild instructions above, but change the
   path `META` to `src/META`, `lib/META`, or whatever subdirectory your
   libraries are located in.

See the [OASIS library test][oasis-libtest] for an example.

[oasis-libtest]: https://github.com/aantron/namespaces/tree/master/test/4-oasis-library



<br>

<a id="Generated"></a>
## Generated files

Namespaces has trouble with generated files, such as `.ml` files generated from
`.mll` files by `ocamllex`. If you have such files in your project, you need to
tell Namespaces about the generator. For example, if you have a program that
generates `.ml` and `.mli` files from `.rpc` files,

    let () =
        Ocamlbuild_plugin.dispatch
            (Namespaces.handler ~generators:["%.rpc", ["%.ml"; "%.mli"]])

The default value of `~generators` is `Namespaces.builtin_generators`, which has
rules for `ocamllex` and `ocamlyacc`. See [`namespaces.mli`][mli] for details.

[mli]: https://github.com/aantron/namespaces/blob/master/src/namespaces.mli#L37



<br>

<a id="SeparateCompilation"></a>
## Effect on separate compilation

As currently implemented, grouping modules in a namespace causes recompilation
of everything that depends on that namespace, each time one of the namespace
child modules changes. However, only the children that are actually referenced
by depending code are linked with that code. To illustrate, suppose there are
modules

```
Namespace.Foo
Namespace.Bar
Main
```

and `Main` refers only to `Namespace.Foo`. `Main` could be in the same project,
or `Namespace` might be packaged as a library, with `Main` in a different
project.

When an executable with `Main` is linked, only `Namespace.Foo` is included.
However, if `Main` is in the same project as `Namespace`, then when *either*
`Namespace.Foo` or `Namespace.Bar` is changed, `Main` is recompiled – even
though that is not strictly necessary in the case `Namespace.Bar` is changed.
This is a result of an imprecision in the current dependency analysis.
