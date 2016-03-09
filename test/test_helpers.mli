val install_plugin : unit -> unit

val project : (unit -> unit) -> unit
val depending : (unit -> unit) -> unit

val file : string -> string list -> unit

val myocamlbuild_ml : unit -> unit
val tags : string list -> unit

val oasis_myocamlbuild_ml : unit -> unit
val oasis_tags : string list -> unit
val oasis_file : string list -> unit

val run : string -> string list -> string
val ocamlbuild : ?fails_with:string -> string list -> unit
val oasis : unit -> unit

val install_project : unit -> unit

val test : string -> (unit -> unit) -> OUnit2.test
