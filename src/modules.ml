(* This file is part of Namespaces, distributed under the terms of the 2-clause
   BSD license. See https://github.com/aantron/namespaces. *)

open Ocamlbuild_plugin

let sprintf = Printf.sprintf
let bprintf = Printf.bprintf

(* User tags. *)
let namespace_tag = "namespace"
let namespace_with_name_tag = "namespace_with_name"
let namespace_level_tag = "namespace_level"
let namespace_library_tag = "namespace_lib"

let namespace_tag_regexp =
  Str.regexp
    (sprintf "%s$\\|%s\\((\\([^)]*\\))\\)$"
      namespace_tag namespace_with_name_tag)

let library_tag_regexp =
  Str.regexp (sprintf "%s\\((\\([^)]*\\))\\)?$" namespace_library_tag)

(* Internal use tags. *)
(* TODO Fix the names here. *)
let alias_file_tag = "namespace_alias_file"
let ordered_open_tag = "namespace_open"
let use_map_file_tag = "namespace_use_map_file"
let map_file_tag = "namespace_map_file"
let namespace_library_dependency_tag lib =
  sprintf "namespace_library_dependency_%s" lib
let dummy_tag = "namespaces_dummy"

let namespace_library_title = "_namespaces"
(* TODO Think about this name more. *)
let map_file_name = "namespaces_map.ml"

type file =
  {original_name : string;
   renamed_name  : string;
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

let module_path {renamed_name; namespace; _} =
  namespace @ [module_name_of_pathname renamed_name]

let member_module_files {modules; namespaces; _} =
  (List.map fst namespaces) @ modules

let digest_file base_name =
  sprintf "%s.digest" base_name

let alias_container_module base_name =
  sprintf "%s__aliases_" (module_name_of_pathname base_name)

let alias_group_module base_name for_module =
  sprintf "%s__aliases__for_%s_"
    (module_name_of_pathname base_name) (module_name_of_pathname for_module)

let alias_export_module base_name =
  sprintf "%s__aliases__export_" (module_name_of_pathname base_name)

let alias_container_file base_name =
  sprintf "%s__aliases_.ml" base_name

let namespace_file base_name =
  sprintf "%s.ml" base_name

let library_list_file base_name =
  sprintf "%s.mllib" base_name

(* Recursively traverses the source tree. Keeps track of the current filesystem
   path as a list of strings. Keeps track of the current namespace path in the
   same way. The namespace path is extended when a directory is encountered that
   has the "namespace" tag set.

   Notes all [.ml] and [.mli] files and "namespace" directories found by
   creating records of type [file] for them. Organizes these into a forest of
   records of type [namespace], represented by a single top-level record of type
   [namespace_members]. This top-level record represents the top-level modules
   and namespaces in the project.

   Generated [.ml] and [.mli] files are part of the project, but cannot be found
   in the source tree. These are discovered through the rules passed in the
   [generators] argument to [scan_tree]. *)
let scan_tree :
    Generators.parsed -> (string -> string option) ->
      namespace_members * (string, string list) Hashtbl.t =

  (* If the given directory is tagged with "namespace", evaluates to Some None.
     If it is tagged with "namespace(foo)", evaluates to Some (Some "foo").
     Otherwise, evaluates to None. *)
  let is_namespace directory_path =
    let rec scan_for_namespace_tag namespace_tag_found = function
      | [] -> if namespace_tag_found then Some None else None
      | tag::more_tags ->
        if not @@ Str.string_match namespace_tag_regexp tag 0 then
          scan_for_namespace_tag namespace_tag_found more_tags
        else
          try Some (Some (Str.matched_group 2 tag))
          with Not_found -> scan_for_namespace_tag true more_tags in

    directory_path
    |> tags_of_pathname
    |> Tags.elements
    |> scan_for_namespace_tag false in

  (* If the given path is tagged with "namespace_lib(foo)", evaluates to
     Some "foo". Otherwise, evaluates to None. *)
  let is_for_library path =
    let rec scan_for_library_tag = function
      | [] -> None
      | tag::more_tags ->
        if not @@ Str.string_match library_tag_regexp tag 0 then
          scan_for_library_tag more_tags
        else
          try Some (Str.matched_group 2 tag)
          with Not_found ->
            sprintf
              "The %s tag requires an argument (library name)"
              namespace_library_tag
            |> failwith in

    path
    |> tags_of_pathname
    |> Tags.elements
    |> scan_for_library_tag in

  (* Constructs a [file] record when given the current filesystem and module
     paths, and the basename of a file or directory. *)
  let make_file_record directory namespace original_name maybe_renamed_name =
    let renamed_name =
      match maybe_renamed_name with
      | None -> original_name
      | Some other_name -> other_name in
    let prefixed_name = String.concat "__" (namespace @ [renamed_name]) in
    {original_name;
     renamed_name;
     prefixed_name;
     directory;
     namespace} in

  (* Given a [namespace_members], eliminates duplicates in its [modules] and
     [interfaces] fields. *)
  let unique {modules; interfaces; namespaces} =
    let compare_files {original_name = name; _} {original_name = name'; _} =
      String.compare name name' in
    {modules    = List.sort_uniq compare_files modules;
     interfaces = List.sort_uniq compare_files interfaces;
     namespaces} in

  fun generators filter ->
    let libraries = Hashtbl.create 32 in
    let add_to_library library_name module_file =
      let modules =
        try Hashtbl.find libraries library_name
        with Not_found -> [] in
      Hashtbl.replace libraries library_name (module_file::modules) in

    let rec traverse library directory namespace members_acc =
      path_to_string directory
      |> Sys.readdir
      |> Array.fold_left
        (fun members_acc entry ->
          let entry_path = directory @ [entry] in
          let entry_path_string = path_to_string entry_path in

          let library =
            match is_for_library entry_path_string with
            | None -> library
            | Some library_name -> Some library_name in

          (* Directories. *)
          if Sys.is_directory entry_path_string then
            let absolute_path =
              Filename.concat
                (Sys.getcwd ()) (String.concat Filename.dir_sep directory) in
            if absolute_path = !Options.build_dir then members_acc
            else
              match is_namespace entry_path_string with
              | None -> traverse library entry_path namespace members_acc
              | Some rename ->
                let new_namespace =
                  create_namespace
                    library directory namespace entry entry_path rename in
                {members_acc
                  with namespaces = new_namespace::members_acc.namespaces}

          (* Files. *)
          else
            create_modules library directory namespace entry members_acc)
        members_acc

    and create_namespace library directory namespace entry entry_path rename =
      let file = make_file_record directory namespace entry rename in

      let library_name =
        match library with
        | None -> namespace_library_title
        | Some name -> name in

      add_to_library library_name (final_path file);
      add_to_library library_name (alias_container_file (final_path file));

      let nested_namespace =
        namespace @ [module_name_of_pathname file.renamed_name] in
      let members =
        traverse
          (Some library_name) entry_path nested_namespace empty_members in
      (file, unique members)

    and create_modules library directory namespace entry members_acc =
      generators entry
      |> List.map filter
      |> List.fold_left
        (fun accumulator -> function
          | None      -> accumulator
          | Some name -> name::accumulator)
        []
      |> List.fold_left
        (fun members_acc generated_file ->
          let file = make_file_record directory namespace generated_file None in
          if Filename.check_suffix generated_file ".ml" then
            ((match library with
            | None -> ()
            | Some library_name ->
              add_to_library library_name (final_path file));
            {members_acc with modules = file::members_acc.modules})
          else if Filename.check_suffix generated_file ".mli" then
            {members_acc with interfaces = file::members_acc.interfaces}
          else members_acc)
        members_acc in

    let top_level_members = traverse None [] [] empty_members in

    unique top_level_members, libraries

let iter f =
  let rec traverse members =
    List.iter (fun file -> f (`Interface, file)) members.interfaces;
    List.iter (fun file -> f (`Module, file)) members.modules;
    List.iter
      (fun (file, members') -> f (`Namespace, file); traverse members')
      members.namespaces in
  traverse !tree

(* Maps namespaced file paths to [file] records. For example, for
   [server/foo.ml], the key is ["server/server__foo.ml"]. *)
let renamed_files : (string, file) Hashtbl.t =
  Hashtbl.create 512

(* Maps namespaced namespace directories to [namespace] records. For example,
   for [server/api], the key is ["server/server__api"]. *)
let namespace_directory_map : (string, namespace) Hashtbl.t =
  Hashtbl.create 32

(** Maps namespace directory namespace paths to [namespace] records. For
    example, for [server/api], the key is [["Server"; "Api"]]. *)
let namespace_module_map : (string list, namespace) Hashtbl.t =
  Hashtbl.create 32

let namespace_libraries : (string, string list) Hashtbl.t ref =
  ref (Hashtbl.create 1)

(* For each [.ml] or [.mli] file found during the source tree scan, if its
   namespaced name differs from its original name, adds it to [renamed_files].
   The condition holds for files inside namespaces, and doesn't hold for files
   representing top-level modules that have not been renamed with
   [namespace_with_name]. *)
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

(* Populates [namespace_directory_map] and [namespace_module_map]. *)
let index_namespaces () =
  let rec traverse members =
    members.namespaces |> List.iter
      (fun ((file, members') as namespace) ->
        Hashtbl.add namespace_directory_map (final_path file) namespace;
        Hashtbl.add namespace_module_map (module_path file) namespace;
        traverse members') in
  traverse !tree;

  (* Silence warnings about unused tags. *)
  pflag [dummy_tag] namespace_with_name_tag (fun _ -> N);
  pflag [dummy_tag] namespace_library_tag (fun _ -> N);
  mark_tag_used namespace_tag;
  mark_tag_used namespace_level_tag

let namespace_by_final_directory s =
  try Some (Hashtbl.find namespace_directory_map s)
  with Not_found -> None

let extension s =
  try
    let index = (String.rindex s '.') + 1 in
    let remainder_length = (String.length s) - index in
    String.sub s index remainder_length
  with Not_found -> ""

let build_native_and_or_bytecode () =
  !Options.targets
  |> List.fold_left
    (fun (native, bytecode) target ->
      match extension target with
      | "native" | "cmx" | "cmxa" -> true, bytecode
      | "byte" | "cmo" | "cma"    -> native, true
      | _                         -> native, bytecode)
    (false, false)

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
        (alias_group_module namespace_file.prefixed_name member.renamed_name);
      member_modules |> List.iter
        (fun member' ->
          if member' <> member then
            bprintf buffer "  module %s = %s\n"
              (module_name_of_pathname member'.renamed_name)
              (module_name_of_pathname member'.prefixed_name));
      bprintf buffer "end\n\n");

  bprintf buffer "module %s =\nstruct\n"
    (alias_export_module namespace_file.prefixed_name);
  member_modules |> List.iter
    (fun member ->
      bprintf buffer "  module %s = %s\n"
        (module_name_of_pathname member.renamed_name)
        (module_name_of_pathname member.prefixed_name));
  bprintf buffer "end\n";

  Buffer.contents buffer

let namespace_file_contents (namespace_file, members) =
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

  Buffer.contents buffer

(* TODO Create alias modules for each inner module. Right now, it should be
   impossible to shadow List, for example. *)
let map_file_contents () =
  let write, finish =
    let buffer = Buffer.create 4096 in

    begin fun indent s ->
      for i = 1 to indent do
        Buffer.add_string buffer "  "
      done;
      Buffer.add_string buffer s;
      Buffer.add_char buffer '\n'
    end,

    fun () -> Buffer.contents buffer
  in

  let rec traverse indent members =
    members.namespaces |> List.iter (fun (namespace_file, members) ->
      module_name_of_pathname namespace_file.renamed_name
      |> sprintf "module %s ="
      |> write indent;
      write indent "struct";

      traverse (indent + 1) members;

      write indent "end");

    members.modules |> List.iter (fun module_file ->
      sprintf "module %s = %s"
        (module_name_of_pathname module_file.original_name)
        (module_name_of_pathname module_file.prefixed_name)
      |> write indent)
  in

  traverse 0 !tree;
  finish ()

let library_contents_by_final_base_path path =
  try Some (Hashtbl.find !namespace_libraries path)
  with Not_found -> None

(* TODO Should be obsolete. *)
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
            (fun {renamed_name; _} ->
              referent = (module_name_of_pathname renamed_name))
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

(* TODO Remove, or replace. *)
(* TODO Must make sure that the namespace map file is always opened first, so
   perhaps that is best taken care of in this function. *)
let add_open_tags () =
  let tag_file final_path file =
    let rec list_modules_to_open accumulator enclosing_namespace_path = function
      | []          -> failwith "impossible"
      | [_]         -> List.rev accumulator
      | c::c'::rest ->
        let enclosing_namespace_path = enclosing_namespace_path @ [c] in
        let namespace_file, _ =
          Hashtbl.find namespace_module_map enclosing_namespace_path in

        (* let alias_container =
          alias_container_module namespace_file.prefixed_name in
        let alias_group =
          alias_group_module namespace_file.prefixed_name c' in *)

        list_modules_to_open
          (c::accumulator)
          enclosing_namespace_path
          (c'::rest) in

    let tag =
      list_modules_to_open [] [] (module_path file)
      |> String.concat ","
      |> sprintf "%s(%s)" ordered_open_tag in

    tag_file final_path [tag];
    tag_file (final_path ^ ".depends") [tag] in

  Hashtbl.iter tag_file renamed_files;

  (* The reverse argument is a workaround for
     http://caml.inria.fr/mantis/view.php?id=7248. *)
  let open_tag_to_flags reverse modules_string =
    modules_string
    |> Str.split (Str.regexp ",")
    |> (fun l -> if reverse then List.rev l else l)
    |> List.map (fun m -> S [A "-open"; A m])
    |> fun options -> S options in

  pflag ["ocaml"; "compile"] ordered_open_tag (open_tag_to_flags false);
  pflag ["ocamldep"]         ordered_open_tag (open_tag_to_flags false)

(* TODO Remove. *)
(* let add_map_tags () =
  let tag_file final_path file =
    let namespace_file, _ = Hashtbl.find namespace_module_map file.namespace in
    let alias_container = alias_container_file namespace_file.prefixed_name in
    let tag = sprintf "%s(%s)" map_file_tag alias_container in
    tag_file (final_path ^ ".depends") [tag]
  in

  Hashtbl.iter tag_file renamed_files;

  pflag ["ocamldep"] map_file_tag (fun map_file -> S [A "-map"; A map_file]) *)

let add_map_tags () =
  let map_file_path = Filename.concat !Options.build_dir map_file_name in
  Command.(execute (Echo ([map_file_contents ()], map_file_path)));

  let tag = sprintf "%s(%s)" use_map_file_tag map_file_name in
  pflag ["ocamldep"] use_map_file_tag (fun map_file ->
    S [A "-map"; A map_file; A "-open"; A (module_name_of_pathname map_file)]);
  pflag ["ocaml"; "compile"] use_map_file_tag (fun map_file ->
    S [A "-open"; A (module_name_of_pathname map_file)]);

  let rec tag_all members =
    members.modules @ members.interfaces
    |> List.iter (fun file -> tag_file (final_path file) [tag]);
    members.namespaces |> List.map snd |> List.iter tag_all
  in

  tag_all !tree;

  tag_file map_file_name [map_file_tag];
  flag ["ocamldep"; map_file_tag] (A "-as-map");
  flag ["ocaml"; "compile"; map_file_tag]
    (S [A "-no-alias-deps"; A "-w"; A "-49"])

(* Makes each executable target depend on all the libraries in the current
   project. *)
let create_library_tags () =
  Hashtbl.iter
    (fun base_path _ ->
      let tag_name = namespace_library_dependency_tag base_path in
      ocaml_lib ~tag_name base_path)
    !namespace_libraries

let tag_executable_with_libraries filename =
  Hashtbl.iter
    (fun base_path _ ->
      let tag_name = namespace_library_dependency_tag base_path in
      tag_file filename [tag_name])
    !namespace_libraries

(* For each module [Foo] that is not a top-level module, hides the module from
   Ocamlbuild by extending [Options.ignore_list]. *)
let hide_original_nested_modules () =
  let top_level_names =
    member_module_files !tree
    |> List.map (fun {renamed_name; _} ->
      module_name_of_pathname renamed_name) in

  let hide_if_nested file =
    match file.namespace with
    | [] -> ()
    | _  ->
      let renamed_module_name = module_name_of_pathname file.renamed_name in
      if not (List.mem renamed_module_name top_level_names) then
        Options.ignore_list := renamed_module_name::!Options.ignore_list in

  Hashtbl.iter (fun _ file      -> hide_if_nested file) renamed_files;
  Hashtbl.iter (fun _ (file, _) -> hide_if_nested file) namespace_directory_map

let scan generators filter =
  let namespace_trees, libraries = scan_tree generators filter in
  tree := namespace_trees;
  namespace_libraries := libraries;

  index_renamed_files ();
  index_namespaces ();
  tag_namespace_files ();
  add_open_tags ();
  (* add_map_tags (); *)
  add_map_tags ();
  hide_original_nested_modules ();
  create_library_tags ()
