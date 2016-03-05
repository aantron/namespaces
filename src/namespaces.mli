(* This file is part of Namespaces, distributed under the terms of the 2-clause
   BSD license. See https://github.com/aantron/namespaces. *)

(** [ocamlbuild] namespaces plugin. This plugin turns directories in the source
    tree into namespace modules. For example:

    The directory tree
    {v
    main.ml
    foo/
      bar/
        some.ml v}

    results in modules [Main], [Foo], [Foo.Bar], and [Foo.Bar.Some], provided
    the directories [foo/] and [bar/] are tagged with [namespace]. The easiest
    way to do this is to add [<**/*>: namespace] to your [_tags] file.

    To include this plugin in your build process, call [Namespaces.handler] from
    your [myocamlbuild.ml] file, and invoke ocamlbuild using
    [ocamlbuild -use-ocamlfind -plugin-tag "package(namespaces)" [your_target]].
    A minimal [myocamlbuild.ml] file using this plugin looks like this:

    {v
    open Ocamlbuild_plugin
    let () = dispatch Namespaces.handler v}

    For more information on [ocamlbuild], [_tags], and [myocamlbuild.ml], see
    the 
    {{:http://caml.inria.fr/pub/docs/manual-ocaml/ocamlbuild.html}
    ocamlbuild manual}.
 *)

open Ocamlbuild_plugin



(** {1 Generated files} *)

(** The plugin does not automatically detect generated [.ml] and [.mli] files in
    namespaces. If some of your files are generated, you must describe the
    generator to the plugin. The syntax is the same as for [ocamlbuild] rule
    dependencies and products. For example, the description of [ocamllex] is
    ["%.mll", ["%.ml"]]. Note that the outer brackets are part of `ocamldoc`
    code style syntax, not OCaml list syntax!
 *)
type generator = string * string list

(** ["%.mll", ["%.ml"]]. *)
val ocamllex : generator

(** ["%.mly", ["%.ml"]]. *)
val ocamlyacc : generator

(** The list [[ocamllex; ocamlyacc]]. *)
val builtin_generators : generator list



(** {1 Plugin} *)

(** Scans the source tree and creates namespaces, as described above. If the
    [generators] parameter is not specified, it is equal to
    [builtin_generators]. The [filter] parameter allows transformation of the
    detected filenames or the omission of the files. *)
val handler :
  ?generators:generator list ->
  ?filter:(string -> string option) -> hook -> unit

(** Deletes all [.mllib] files in the source tree. This function is a workaround
    for building libraries with OASIS. OASIS generates its own [.mllib] files.
    To prevent them from being used, they should be deleted on each build by
    calling this function in `myocamlbuild.ml`, e.g.:

    {v
    let () = Namespaces.delete_mllib_files () v} *)
val delete_mllib_files : unit -> unit



(** {1 Debugging} *)

(** Type of a file that has been indexed by the plugin during its scan of the
    source tree. [file] can represent a module, interface, or namespace. In the
    first two cases, [original_name] and [prefixed_name] end with [.ml] or
    [.mli], respectively. If the file is a namespace, [original_name] and
    [prefixed_name] are directory names without suffix. *)
type file =
  {original_name : string;
   (** File or directory name as it appears in the source tree. *)
   renamed_name  : string;
   (** If the file is a namespace tagged with [namespace_with_name(n)], this is
       [n]. Otherwise, it is equal to [original_name]. *)
   prefixed_name : string;
   (** File or directory name after prefixing with its namespace path. *)
   directory     : string list;
   (** List of path components giving the directory containing the file. *)
   namespace     : string list
   (** Module path of the namespace containing the module resulting from the
       file. *)}

(** Calls the given function for each [.ml] file, [.mli] file, and namespace in
    the source tree. Must be called in the [After_rules] hook. *)
val iter : ([ `Module | `Interface | `Namespace ] * file -> unit) -> unit
