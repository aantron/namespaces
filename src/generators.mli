(* This file is part of Namespaces, distributed under the terms of the 2-clause
   BSD license. See https://github.com/aantron/namespaces. *)

(** Generator specification parser. *)

type t = string * string list

val ocamllex : t
val ocamlyacc : t
val builtin : t list

type parsed = string -> string list
val parse : t list -> parsed
