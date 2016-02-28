(** Generator specification parser. *)

type t = string * string list

val ocamllex : t
val ocamlyacc : t
val builtin : t list

type parsed = string -> string list
val parse : t list -> parsed
