(** Module scanning and index. *)

type file =
  {original_name : string;
   prefixed_name : string;
   directory     : string list;
   namespace     : string list}

type namespace

val scan : Generators.parsed -> (string -> string option) -> unit
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

(** Alias file by namespace final directory. Appends [_aliases_.ml]. *)
val alias_container_file : string -> string

(** Contents of the alias file. For each module [M] of the namespace ([N]),
    creates a module (in the alias file) called [N_aliases__for_M_], which
    contains aliases for all the members of [N] besides [M]. These are the
    siblings of [M]. The module is opened while compiling [M] to make the
    siblings accessible by their short paths.

    Also creates a module in the alias file called [N_aliases__export_], which
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

(** Lists the modules in the given namespace library. *)
val library_file_contents_by_final_base_path : string -> string option

(** Given a file (the referrer) and the short name of a module it refers to,
    tries to resolve the module name to a namespaced module. *)
val resolve : file -> string -> string
