# Namespaces for OCaml [![version 0.6][version]][releases] [![BSD license][license-img]][license]

[version]:     https://img.shields.io/badge/version-0.5-blue.svg
[releases]:    https://github.com/aantron/namespaces/releases
[license-img]: https://img.shields.io/badge/license-BSD-blue.svg

**Namespaces** helps you organize your code. It is an [Ocamlbuild][ocamlbuild]
plugin that turns directories in your source tree into scoped OCaml modules.

So, if you have:

```
my_project
+-- src
    |-- server
    |   |-- foo.ml
    |   +-- bar.ml
    +-- client
        |-- foo.ml
        |-- bar.ml
        |-- ui
        |   +-- reactive.ml
        +-- client.ml
```

Your project will get a module structure that looks as if you had written this:

```ocaml
module Server =
struct
    module Foo = (* server/foo.ml *)
    module Bar = (* server/bar.ml *)
end

module Client =
struct
    module Foo = (* client/foo.ml *)
    module Bar = (* client/bar.ml *)

    module Ui =
    struct
        module Reactive = (* client/ui/reactive.ml *)
    end

    include (* client/client.ml *)
end
```

You can now access these modules as `Server.Foo` or `Client.Ui.Reactive`. Within
a module, you don't have to (indeed, must not) qualify sibling module names:
from `Server.Foo`, you access `Server.Bar` as just `Bar`. You can access
children and nephews, but cannot access parents.

Note that there is no conflict between `server/foo.ml` and `client/foo.ml`,
since there is no globally-visible module `Foo`, like there would be without
Namespaces.

The usual dependency restrictions on OCaml modules apply: there must not be any
dependency cycles. Siblings must depend on each other in some order, and each
parent module depends on all of its child modules.

The modules are composed with `-no-alias-deps`, so depending on a directory
module does not automatically pull in all of its descendants, unless they are
actually used.



## Instructions

1. Install Namespaces:

        opam install namespaces

2. Add it to your build system.

   - If using Ocamlbuild, create `myocamlbuild.ml`, make it look like this:

            let () = Ocamlbuild_plugin.dispatch Namespaces.handler

     and invoke it with

            ocamlbuild -use-ocamlfind -plugin-tag "package(namespaces)"

     If you already have `myocamlbuild.ml`, call `Namespaces.handler` before or
     after your hook that you pass to `dispatch`.

   - If using OASIS, find the bottom of your `myocamlbuild.ml` file, and replace
     the call to `dispatch` with this:

            let () =
              dispatch
                (MyOCamlbuildBase.dispatch_combine
                   [MyOCamlbuildBase.dispatch_default conf package_default;
                    Namespaces.dispatch])

     Then, add this to the top of your OASIS file:

            OCamlVersion:           >= 4.01
            AlphaFeatures:          ocamlbuild_more_args
            XOCamlbuildPluginTags:  package(bisect_ppx.plugin)

     and re-run `oasis setup`.

3. Tag the directories that you want to become namespaces with the `namespace`
   tag. For example, to make all directories in `src/` into namespaces, you
   can add this to your `_tags` file:

        <src/*/**>: namespace

4. Enjoy!



## Generated files

Namespaces has trouble with generated files, such as `.ml` files generated from
`.mll` files by `ocamllex`. If you have such files in your project, you need to
tell Namespaces about the generator. For example, if you have a program that
generates `.ml` and `.mli` files from `.rpc` files,

    let () =
        Ocamlbuild_plugin.dispatch
            (Namespaces.handler ~generators:["%.rpc", ["%.ml"; "%.mli"]])

The default value of [~generators] is [Namespaces.builtin_generators], which has
rules for `ocamllex` and `ocamlyacc`.



## License

Namespaces is distributed under the terms of the 2-clause
[BSD license][license].



[ocamlbuild]: https://github.com/gasche/manual-ocamlbuild
[license]:    https://opensource.org/licenses/BSD-2-Clause
