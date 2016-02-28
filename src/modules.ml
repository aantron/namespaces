open Ocamlbuild_plugin

let sprintf = Printf.sprintf
let bprintf = Printf.bprintf

(* User tags. *)
let namespace_tag = "namespace"
let namespace_level_tag = "namespace_level"
let namespace_library_tag = "namespace_lib"

(* Internal use tags. *)
let alias_file_tag = "namespace_alias_file"
let ordered_open_tag = "namespace_open"
let namespace_library_dependency_tag lib =
  sprintf "namespace_library_dependency_%s" lib

let namespace_library_title = "_namespaces"

type file =
  {original_name : string;
   prefixed_name : string;
   directory     : string list;
   namespace     : string list}

type namespace_members =
  {modules    : file list;
   interfaces : file list;
   namespaces : namespace list}
and namespace = file * namespace_members

let empty_members = {modules = []; interfaces = []; namespaces = []}

let tree : namespace_members ref = ref empty_members

let path_to_string (path : string list) =
  match path with
    [] -> Filename.current_dir_name
  | _  -> String.concat Filename.dir_sep path

let original_module {original_name; _} =
  module_name_of_pathname original_name

let original_path {original_name; directory; _} =
  directory @ [original_name] |> path_to_string

let final_path {prefixed_name; directory; _} =
  directory @ [prefixed_name] |> path_to_string

let module_path {original_name; namespace; _} =
  namespace @ [module_name_of_pathname original_name]

let member_module_files {modules; namespaces; _} =
  (List.map fst namespaces) @ modules

let scan_tree =
  let is_namespace directory_path =
    Tags.does_match
      (tags_of_pathname directory_path) (Tags.of_list [namespace_tag]) in

  let make_file directory namespace name =
    let prefixed_name = String.concat "_" (namespace @ [name]) in
    {original_name = name; prefixed_name; directory = directory;
     namespace = namespace} in

  let unique {modules; interfaces; namespaces} =
    let compare_files {original_name = name; _} {original_name = name'; _} =
      String.compare name name' in
    {modules    = List.sort_uniq compare_files modules;
     interfaces = List.sort_uniq compare_files interfaces;
     namespaces} in

  fun generators filter ->
    let rec traverse directory namespace members_acc =
      path_to_string directory
      |> Sys.readdir
      |> Array.fold_left
        (fun members_acc entry ->
          let entry_path = directory @ [entry] in
          let entry_path_string = path_to_string entry_path in

          if Sys.is_directory entry_path_string then
            let absolute_path =
              Filename.concat
                (Sys.getcwd ()) (String.concat Filename.dir_sep directory) in
            if absolute_path = !Options.build_dir then members_acc
            else
              if is_namespace entry_path_string then
                let new_namespace =
                  create_namespace directory namespace entry entry_path in
                {members_acc
                  with namespaces = new_namespace::members_acc.namespaces}
              else
                traverse entry_path namespace members_acc

          else
            create_modules directory namespace entry members_acc)
        members_acc

    and create_namespace directory namespace entry entry_path =
      let file = make_file directory namespace entry in
      let nested_namespace = namespace @ [original_module file] in
      let members = traverse entry_path nested_namespace empty_members in
      (file, unique members)

    and create_modules directory namespace entry members_acc =
      generators entry
      |> List.map filter
      |> List.fold_left
        (fun accumulator -> function
          | None      -> accumulator
          | Some name -> name::accumulator)
        []
      |> List.fold_left
        (fun members_acc generated_file ->
          let file = make_file directory namespace generated_file in
          if Filename.check_suffix generated_file ".ml" then
            {members_acc with modules = file::members_acc.modules}
          else if Filename.check_suffix generated_file ".mli" then
            {members_acc with interfaces = file::members_acc.interfaces}
          else members_acc)
        members_acc in

    let top_level_members = traverse [] [] empty_members in
    unique top_level_members

let iter f =
  let rec traverse members =
    List.iter (fun file -> f (`Interface, file)) members.interfaces;
    List.iter (fun file -> f (`Module, file)) members.modules;
    List.iter
      (fun (file, members') -> f (`Namespace, file); traverse members')
      members.namespaces in
  traverse !tree

let renamed_files : (string, file) Hashtbl.t =
  Hashtbl.create 512
let namespace_directory_map : (string, namespace) Hashtbl.t =
  Hashtbl.create 32
let namespace_module_map : (string list, namespace) Hashtbl.t =
  Hashtbl.create 32
let namespace_libraries : (string, string list) Hashtbl.t =
  Hashtbl.create 32

let index_renamed_files () =
  iter
    (function
    | `Namespace,             _    -> ()
    | (`Interface | `Module), file ->
      if file.prefixed_name <> file.original_name then
        Hashtbl.add renamed_files (final_path file) file)

let file_by_renamed_path s =
  try Some (Hashtbl.find renamed_files s)
  with Not_found -> None

let index_namespaces () =
  let rec traverse members =
    members.namespaces |> List.iter
      (fun ((file, members') as namespace) ->
        Hashtbl.add namespace_directory_map (final_path file) namespace;
        Hashtbl.add namespace_module_map (module_path file) namespace;
        traverse members') in
  traverse !tree;

  mark_tag_used namespace_tag;
  mark_tag_used namespace_level_tag

let namespace_by_final_directory s =
  try Some (Hashtbl.find namespace_directory_map s)
  with Not_found -> None

let digest_file base_name =
  sprintf "%s.digest" base_name

let alias_container_module base_name =
  sprintf "%s_aliases_" (module_name_of_pathname base_name)

let alias_group_module base_name for_module =
  sprintf "%s_aliases__for_%s_"
    (module_name_of_pathname base_name) (module_name_of_pathname for_module)

let alias_export_module base_name =
  sprintf "%s_aliases__export_" (module_name_of_pathname base_name)

let alias_container_file base_name =
  sprintf "%s_aliases_.ml" base_name

let namespace_file base_name =
  sprintf "%s.ml" base_name

let library_list_file base_name =
  sprintf "%s.mllib" base_name

let build_native_and_or_bytecode () =
  let extension s =
    try
      let index = (String.rindex s '.') + 1 in
      let remainder_length = (String.length s) - index in
      String.sub s index remainder_length
    with Not_found -> "" in

  !Options.targets
  |> List.fold_left
    (fun (native, bytecode) target ->
      match extension target with
      | "native" | "cmx" | "cmxa" -> true, bytecode
      | "byte" | "cmo" | "cma"    -> native, true
      | _                         -> native, bytecode)
    (false, false)

(* TODO Can the inconsistent implementation assumption problem be solved by
   simply making all namespace files depend on cmx/o files directly instead, as
   was the case before libraries and digest files were added? *)
let digest_dependencies (_, members) =
  let build_native, build_bytecode = build_native_and_or_bytecode () in

  let module_files = List.map final_path members.modules in
  let namespace_files =
    members.namespaces
    |> List.map (fun (file, _) -> final_path file |> namespace_file) in
  let ml_files = module_files @ namespace_files in

  let native_objects =
    if build_native then
      ml_files |> List.map (fun name -> (Filename.chop_extension name) ^ ".cmx")
    else [] in
  let bytecode_objects =
    if build_bytecode then
      ml_files |> List.map (fun name -> (Filename.chop_extension name) ^ ".cmo")
    else [] in

  native_objects @ bytecode_objects
  |> List.sort_uniq String.compare

let alias_file_contents (namespace_file, members) =
  let buffer = Buffer.create 4096 in
  let member_modules = member_module_files members in

  member_modules |> List.iter
    (fun member ->
      bprintf buffer "module %s =\nstruct\n"
        (alias_group_module namespace_file.prefixed_name member.original_name);
      member_modules |> List.iter
        (fun member' ->
          if member' <> member then
            bprintf buffer "  module %s = %s\n"
              (module_name_of_pathname member'.original_name)
              (module_name_of_pathname member'.prefixed_name));
      bprintf buffer "end\n\n");

  bprintf buffer "module %s =\nstruct\n"
    (alias_export_module namespace_file.prefixed_name);
  member_modules |> List.iter
    (fun member ->
      bprintf buffer "  module %s = %s\n"
        (module_name_of_pathname member.original_name)
        (module_name_of_pathname member.prefixed_name));
  bprintf buffer "end\n";

  Buffer.contents buffer

let namespace_file_contents (namespace_file, members) digest =
  let buffer = Buffer.create 4096 in
  let alias_module = alias_container_module namespace_file.prefixed_name in
  let export_module = alias_export_module namespace_file.prefixed_name in
  let included_members =
    member_module_files members
    |> List.fold_left
      (fun names member ->
        let tags = tags_of_pathname (original_path member) in
        if Tags.does_match tags (Tags.of_list [namespace_level_tag]) then
          (module_name_of_pathname member.prefixed_name)::names
        else names)
      [] in

  bprintf buffer "open %s\n" alias_module;
  bprintf buffer "include %s\n" export_module;
  included_members |> List.iter (bprintf buffer "include %s\n");
  bprintf buffer "\nlet _digest_%s = ()\n" digest;

  Buffer.contents buffer

let library_file_contents_by_final_base_path path =
  try
    Hashtbl.find namespace_libraries path
    |> String.concat "\n"
    |> fun s -> Some (s ^ "\n")
  with Not_found -> None

(* TODO Perhaps it is better to store namespaces reversed, or at least use
   reversed keys into Modules.namespace_scopes. *)
let resolve (referrer : file) (referent : string) : string =
  let rec loop self = function
    | []                              -> referent
    | (_::rest) as reversed_namespace ->
      let namespace_file, members =
        List.rev reversed_namespace |> Hashtbl.find namespace_module_map in
      let member_modules = member_module_files members in
      try
        let matching_module =
          member_modules |> List.find
            (fun {original_name; _} ->
              referent = (module_name_of_pathname original_name))
          |> fun {prefixed_name; _} -> module_name_of_pathname prefixed_name in
        if matching_module = self then raise_notrace Not_found
        else matching_module
      with Not_found ->
        loop (module_name_of_pathname namespace_file.prefixed_name) rest in

  loop
    (module_name_of_pathname referrer.prefixed_name)
    (List.rev referrer.namespace)

let tag_namespace_files () =
  let for_namespace base_path (_, members) =
    let alias_file_path = alias_container_file base_path in

    tag_file alias_file_path [alias_file_tag; "no_alias_deps"];

    member_module_files members
    |> List.iter
      (fun {prefixed_name; _} ->
        non_dependency
          alias_file_path (module_name_of_pathname prefixed_name)) in

  Hashtbl.iter for_namespace namespace_directory_map;

  flag ["ocaml"; "compile"; alias_file_tag] (S [A "-w"; A "-49"])

let add_open_tags () =
  let tag_file final_path file =
    let rec list_modules_to_open accumulator enclosing_namespace_path = function
      | []          -> failwith "impossible"
      | [_]         -> List.rev accumulator
      | c::c'::rest ->
        let enclosing_namespace_path = enclosing_namespace_path @ [c] in
        let namespace_file, _ =
          Hashtbl.find namespace_module_map enclosing_namespace_path in

        let alias_container =
          alias_container_module namespace_file.prefixed_name in
        let alias_group =
          alias_group_module namespace_file.prefixed_name c' in

        list_modules_to_open
          (alias_group::alias_container::accumulator)
          enclosing_namespace_path
          (c'::rest) in

    let tag =
      list_modules_to_open [] [] (module_path file)
      |> String.concat ","
      |> sprintf "%s(%s)" ordered_open_tag in

    tag_file final_path [tag];
    tag_file (final_path ^ ".depends") [tag] in

  Hashtbl.iter tag_file renamed_files;

  let open_tag_to_flags modules_string =
    modules_string
    |> Str.split (Str.regexp ",")
    |> List.map (fun m -> S [A "-open"; A m])
    |> fun options -> S options in

  pflag ["ocaml"; "compile"] ordered_open_tag open_tag_to_flags;
  pflag ["ocamldep"]         ordered_open_tag open_tag_to_flags

let assemble_libraries () =
  let rec at_namespace_list accumulator namespaces =
    namespaces |> List.fold_left
      (fun accumulator ((file, _) as namespace) ->
        let tags = original_path file |> tags_of_pathname in
        if Tags.mem namespace_library_tag tags then
          let nested_library_modules = at_namespace [] namespace in
          Hashtbl.add namespace_libraries
            (final_path file) nested_library_modules;
          accumulator
        else at_namespace accumulator namespace)
      accumulator

  and at_namespace accumulator (file, members) =
    let alias_module = alias_container_module file.prefixed_name in
    let namespace_module = module_name_of_pathname file.prefixed_name in
    let accumulator =
      (List.map
        (fun {prefixed_name; _} -> module_name_of_pathname prefixed_name)
        members.modules)
      @ accumulator in
    at_namespace_list
      (alias_module::namespace_module::accumulator) members.namespaces in

  let top_level_modules = at_namespace_list [] !tree.namespaces in
  if top_level_modules <> [] then
    Hashtbl.add namespace_libraries namespace_library_title top_level_modules;

  mark_tag_used namespace_library_tag;

  Hashtbl.iter
    (fun base_path _ ->
      let tag_name = namespace_library_dependency_tag base_path in
      ocaml_lib ~tag_name base_path;
      List.iter (fun target -> tag_file target [tag_name]) !Options.targets)
    namespace_libraries

let hide_original_nested_modules () =
  let top_level_names =
    member_module_files !tree
    |> List.map (fun {original_name; _} ->
      module_name_of_pathname original_name) in

  let hide_if_nested file =
    match file.namespace with
    | [] -> ()
    | _  ->
      let original_module_name = module_name_of_pathname file.original_name in
      if not (List.mem original_module_name top_level_names) then
        Options.ignore_list := original_module_name::!Options.ignore_list in

  Hashtbl.iter (fun _ file      -> hide_if_nested file) renamed_files;
  Hashtbl.iter (fun _ (file, _) -> hide_if_nested file) namespace_directory_map

let scan generators filter =
  tree := scan_tree generators filter;
  index_renamed_files ();
  index_namespaces ();
  tag_namespace_files ();
  add_open_tags ();
  assemble_libraries ();
  hide_original_nested_modules ()