(* This file is part of Namespaces, distributed under the terms of the 2-clause
   BSD license. See https://github.com/aantron/namespaces. *)

(** Module scanning and index. *)

type file =
  {original_name : string;
   (** The original basename of the file or directory, including extension, if
       any. For example, [server/foo.ml] has this set to ["foo.ml"]. *)
   renamed_name  : string;
   (** For namespaces tagged with [namespace_with_name(n)], this is [n].
       Otherwise, the same as [original_name]. *)
   prefixed_name : string;
   (** The prefixed name of the file or directory. For example, [server/foo.ml]
       has this field set to [server__foo.ml]. *)
   directory     : string list;
   (** The path, relative to the project root, in which this file or directory
       was found. For example, [server/foo.ml] has this set to [["server"]]. *)
   namespace     : string list
   (** The module path in which this file's or directory's module is aliased.
       For example, [server/foo] is has this set to ["Server"]. *)}

type namespace

val scan : Generators.parsed -> (string -> string option) -> unit
(** Scans the source tree for directories to become namespaces and files to
    become namespace members, and notes the results as values of type [file] in
    a state variable inside this module. *)

val iter : ([ `Module | `Interface | `Namespace ] * file -> unit) -> unit

val namespace_level_tag : string

(** File by its final path. Used for symlink rules and [ocamldep] output
    rewriting. *)
val file_by_renamed_path : string -> file option

val original_path : file -> string

(** Namespace by its final directory. *)
val namespace_by_final_directory : string -> namespace option

(** Digest file by namespace final directory. Simply appends [.digest]. *)
val digest_file : string -> string

(** List of [.cmi] files, one for each member of the given namespace. *)
val digest_dependencies : namespace -> string list

(** Alias file by namespace final directory. Appends [__aliases_.ml]. *)
val alias_container_file : string -> string

(** Contents of the alias file. For each module [M] of the namespace ([N]),
    creates a module (in the alias file) called [N__aliases__for_M_], which
    contains aliases for all the members of [N] besides [M]. These are the
    siblings of [M]. The module is opened while compiling [M] to make the
    siblings accessible by their short paths.

    Also creates a module in the alias file called [N__aliases__export_], which
    contains aliases for all the members of [N]. This module is included in the
    namespace file, which makes the members of [N] accessible from modules
    outside the namespace. *)
val alias_file_contents : namespace -> string

(** Contents of the namespace file. This file includes the export module from
    the alias file, and any namespace members that are tagged with
    [namespace_level]. The string argument gives the digest, which is a dummy
    value used to force recompilation of any file depending on the namespace
    file when the interfaces inside the namespace change. *)
val namespace_file_contents : namespace -> string -> string

(** Library module list file by namespace final directory. Appends [.mllib]. *)
val library_list_file : string -> string

(** Lists the module file names in the given namespace library. *)
val library_contents_by_final_base_path : string -> string list option

(** Makes the given executable depend on all namespace libraries. *)
val tag_executable_with_libraries : string -> unit

(** Given a file (the referrer) and the short name of a module it refers to,
    tries to resolve the module name to a namespaced module. *)
val resolve : file -> string -> string
