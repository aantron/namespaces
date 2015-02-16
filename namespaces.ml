open Ocamlbuild_plugin

type generator = Generators.t

let ocamllex = Generators.ocamllex
let ocamlyacc = Generators.ocamlyacc
let builtin_generators = Generators.builtin

let identity_filter = fun s -> Some s

let handler ?(generators = Generators.builtin) ?(filter = identity_filter) =
  function
  | After_rules ->
    Modules.scan (Generators.parse generators) filter;
    Rules.add_all ()
  | _           -> ()

type file = Modules.file =
  {original_name : string;
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
