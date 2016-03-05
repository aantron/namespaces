(* This file is part of Namespaces, distributed under the terms of the 2-clause
   BSD license. See https://github.com/aantron/namespaces. *)

open Ocamlbuild_plugin

type generator = Generators.t

let ocamllex = Generators.ocamllex
let ocamlyacc = Generators.ocamlyacc
let builtin_generators = Generators.builtin

let identity_filter = fun s -> Some s

type file = Modules.file =
  {original_name : string;
   renamed_name  : string;
   prefixed_name : string;
   directory     : string list;
   namespace     : string list}

let iter = Modules.iter

let rec innermost_namespace = function
  | []            -> None
  | [n]           -> Some n
  | _::namespaces -> innermost_namespace namespaces

let include_files_sharing_namespace_title () =
  iter
    (function
    | `Module, file ->
        (match innermost_namespace file.namespace with
        | Some n when n = (module_name_of_pathname file.original_name) ->
          tag_file (Modules.original_path file) [Modules.namespace_level_tag]
        | _ -> ())
    | _ -> ())

let handler ?(generators = Generators.builtin) ?(filter = identity_filter) =
  function
  | After_rules ->
    Modules.scan (Generators.parse generators) filter;
    Rules.add_all ();
    include_files_sharing_namespace_title ()
  | _           -> ()

let delete_mllib_files () =
  let rec traverse path =
    path
    |> Sys.readdir
    |> Array.iter (fun entry ->
      let path = Filename.concat path entry in
      if Sys.is_directory path then
        traverse path
      else
        if Filename.check_suffix entry ".mllib" then
          Sys.remove path)
  in
  traverse Filename.current_dir_name
