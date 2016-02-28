(* This file is part of Namespaces, distributed under the terms of the 2-clause
   BSD license. See https://github.com/aantron/namespaces. *)

type t = string * string list

let identity = "%.ml", ["%.ml"]
let signature = "%.mli", ["%.mli"]
let ocamllex = "%.mll", ["%.ml"]
let ocamlyacc = "%.mly", ["%.ml"]
let builtin = [ocamllex; ocamlyacc]

type parsed = string -> string list

let parse_single =
  let wildcard = Str.regexp_string "%" in
  fun (dep, prods) ->
    let dep_prefix, dep_suffix =
      match Str.split_delim wildcard dep with
      | [p; s] -> p, s
      | _      ->
        failwith "Generator dependency must contain exactly one wildcard" in
    let dep_regexp =
      "^" ^ (Str.quote dep_prefix) ^ "\\(.+\\)" ^
      (Str.quote dep_suffix) ^ "$"
      |> Str.regexp in

    let substitute prod =
      let prod_fragments = Str.split_delim wildcard prod in
      fun stem -> String.concat stem prod_fragments in
    let substitute_all = List.map substitute prods in

    let parsed_generator file =
      try
        Str.search_forward dep_regexp file 0 |> ignore;
        let stem = Str.matched_group 1 file in
        List.map (fun f -> f stem) substitute_all
      with Not_found -> [] in

    parsed_generator

let parse generators =
  let parsed_generators =
    List.map parse_single (identity::signature::generators) in
  fun file ->
    List.map (fun g -> g file) parsed_generators |> List.concat
