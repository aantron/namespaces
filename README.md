# Namespaces &nbsp; [![version 0.6][version]][releases] [![BSD license][license-img]][license] [![Travis status][travis-img]][travis]

[version]:     https://img.shields.io/badge/version-0.5-blue.svg
[releases]:    https://github.com/aantron/namespaces/releases
[license-img]: https://img.shields.io/badge/license-BSD-blue.svg
[travis]:      https://travis-ci.org/aantron/namespaces/branches
[travis-img]:  https://img.shields.io/travis/aantron/namespaces/master.svg

Ever wish `src/server/foo.ml` was module `Server.Foo` and not just `Foo`?

Who likes to name it `src/server/server_foo.ml`, just to avoid naming conflicts?

*Namespaces* is an Ocamlbuild plugin that turns directories in your source tree
into scoped OCaml modules. You get a nice, logical, and predictable structure,
and you don't have to worry about duplicate filenames anymore. It's the sane
file naming convention that most other languages have always had.

If you have the directory structure on the left, you will get the OCaml modules
on the right:

![Effect summary][summary]

[summary]: https://github.com/aantron/namespaces/blob/master/src/summary.png

The module structure works as if you had written:

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

There is no conflict between `server/foo.ml` and `client/foo.ml`, because there
is no globally-visible module `Foo`.

Within a module, you don't have to (indeed, must not) qualify sibling module
names: from `Server.Foo`, you access `Server.Bar` as just `Bar`. You can access
children and nephews, but cannot access parents.

The usual dependency restrictions between OCaml modules apply: there must not be
any dependency cycles. Siblings, if they depend on each other, must depend on
each other in some order, and each parent module depends on all of its child
modules.

The modules are composed with `-no-alias-deps`, so depending on a directory
module does not automatically pull in all of its descendants, unless they are
actually used. This also means that Namespaces requires OCaml 4.02 or higher.



<br>

## Instructions

1. Install Namespaces:

        opam install namespaces

2. Add it to your build system.

   - If using Ocamlbuild, create `myocamlbuild.ml`, and make it look like this:

            let () = Ocamlbuild_plugin.dispatch Namespaces.handler

     Invoke Ocamlbuild with:

          ocamlbuild -use-ocamlfind -plugin-tag "package(namespaces)"

     If you already have `myocamlbuild.ml`, call `Namespaces.handler` before or
     after your hook that you pass to `dispatch`.

   - If using OASIS, find the bottom of your `myocamlbuild.ml` file, and replace
     the call to `dispatch` with this:

          let () =
            dispatch
              (MyOCamlbuildBase.dispatch_combine
                 [MyOCamlbuildBase.dispatch_default conf package_default;
                  Namespaces.handler])

     Then, add this to the top of your OASIS file:

          OCamlVersion:           >= 4.02
          AlphaFeatures:          ocamlbuild_more_args
          XOCamlbuildPluginTags:  package(namespaces)

     and re-run `oasis setup`.

3. Tag the directories that you want to become namespaces with the `namespace`
   tag. For example, to make all directories in `src/` into namespaces, you
   can add this to your `_tags` file:

        <src/*/**>: namespace
        <src/**>: include

4. If you are building a library, see additional instructions in
   [`manual.md`][manual]. See also that file if you have generated files in your
   project.

5. Enjoy!

[manual]: https://github.com/aantron/namespaces/blob/master/manual.md



<br>

## The Future

An Ocamlbuild plugin is by no means the best way, ideally, to deal with the
problem of structuring modules in OCaml. I am releasing this, in part, to
advance the discussion. My hope is that after some time, we will have a more
conclusive solution integrated into the OCaml tool chain.



<br>

## License

Namespaces is distributed under the terms of the 2-clause
[BSD license][license].

[license]:    https://opensource.org/licenses/BSD-2-Clause
