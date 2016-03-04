# Namespaces



<br>

<a id="Libraries"></a>
## Building libraries

To build one or more libraries with Namespaces, tag your library namespaces with
`namespace_lib` like this:

```
src/                            [no tags]
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
```

This causes Namespaces to generate the requisite `.mllib` files for Ocamlbuild.
Then, you can build the targets `lib_1.cma`, `lib_1.cmxa`, `lib_2.cma`,
`lib_2.cmxa`.

To install with Findlib, describe the libraries as normal in `META`. The easiest
way to list the files to install is to list the libraries, and then find all
`.cmi`, `.cmt`, and `.cmti` files. For example, in `Makefile` syntax:

```
TO_INSTALL :=                         \
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
    ocamlfind install $(PACKAGE) META $(TO_INSTALL)
```

See the [library test][libtest] for a working example.

[libtest]: https://github.com/aantron/namespaces/tree/master/test/3-library



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
