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

(* TODO Detailed documentation link. *)
(* TODO Add link to home page in documentation. *)

open Ocamlbuild_plugin

(** {1 Generated files} *)

(** The plugin does not automatically detect generated [.ml] and [.mli] files in
    namespaces. If some of your files are generated, you must describe the
    generator to the plugin. The syntax is the same as for [ocamlbuild] rule
    dependencies and products. For example, the description of [ocamllex] is
    [("%.mll", ["%.ml"])].
 *)
type generator = string * string list

val ocamllex : generator
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

(** {1 Utilities} *)

(** Type of a file that has been indexed by the plugin during its scan of the
    source tree. [file] can represent a module, interface, or namespace. In the
    first two cases, [original_name] and [prefixed_name] end with [.ml] or
    [.mli], respectively. If the file is a namespace, [original_name] and
    [prefixed_name] are directory names without suffix. *)
type file =
  {original_name : string;
   (** File or directory name as it appears in the source tree. *)
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

(** Gives each file that has the same (original) name as its containing
    namespace the tag [namespace_level]. This causes the module it produces to
    be included in the namespace module (using [include]). Must be called in the
    [After_rules] hook. For example, if [foo/bar/] is a namespace directory, and
    there is a file [foo/bar/bar.ml], the members of [Foo.Bar.Bar] will become
    members of [Foo.Bar]. See the main documentation for more information about
    [namespace_level]. *)
val include_files_sharing_namespace_title : unit -> unit
