open OUnit2

let _plugin_install_directory = "_plugin_findlib"
let _plugin_install_directory_absolute =
  Filename.concat (Sys.getcwd ()) _plugin_install_directory

let _project_install_directory = "_project_findlib"
let _project_install_directory_absolute =
  Filename.concat (Sys.getcwd ()) _project_install_directory

let _project_directory = "_project"
let _depending_directory = "_depending"

let _package_name = "test-library"

let run command arguments =
  let open Process in
  let result = run command (Array.of_list arguments) in
  if result.Output.exit_status <> Exit.Exit 0 then
    let report =
      Printf.sprintf
        "Command failed (%s):\n%s %s\n\nSTDERR:\n\n%s\n\nSTDOUT:\n\n%s"
        (Exit.to_string result.Output.exit_status)
        command (String.concat " " arguments)
        (String.concat "\n" result.Output.stderr)
        (String.concat "\n" result.Output.stdout)
    in
    assert_failure report
  else
    String.concat "\n" result.Output.stdout

let _run command arguments = run command arguments |> ignore

let _fresh_dir name =
  _run "rm" ["-rf"; name];
  _run "mkdir" ["-p"; name]

let install_plugin () =
  _fresh_dir _plugin_install_directory;

  Unix.putenv "OCAMLFIND_DESTDIR" _plugin_install_directory_absolute;
  _run "make" ["-C"; ".."; "install"];
  Unix.putenv "OCAMLFIND_DESTDIR" _project_install_directory_absolute;

  Printf.sprintf "%s:%s"
    _plugin_install_directory_absolute _project_install_directory_absolute
  |> Unix.putenv "OCAMLPATH"

let _project directory f =
  _fresh_dir directory;

  let cwd = Sys.getcwd () in
  let project_directory = Filename.concat cwd directory in
  Sys.chdir project_directory;

  try
    f ();
    Sys.chdir cwd

  with e ->
    Sys.chdir cwd;
    raise e

let project = _project _project_directory

let depending = _project _depending_directory

let file name lines =
  _run "mkdir" ["-p"; (Filename.dirname name)];

  let channel = open_out name in
  try
    lines |> List.iter (fun s ->
      output_string channel s; output_char channel '\n');
    close_out_noerr channel

  with e ->
    close_out_noerr channel;
    raise e

let myocamlbuild_ml () =
  file "myocamlbuild.ml"
    ["let () = Ocamlbuild_plugin.dispatch Namespaces.handler"]

let tags lines =
  file "_tags" ("<**/*>: include"::lines)

let oasis_myocamlbuild_ml () =
  file "myocamlbuild.ml"
    ["(* OASIS_START *)";
     "(* OASIS_STOP *)";
     "";
     "let () =";
     "  dispatch";
     "    (MyOCamlbuildBase.dispatch_combine";
     "      [MyOCamlbuildBase.dispatch_default conf package_default;";
     "       Namespaces.handler])"]

let oasis_tags lines =
  file "_tags"
    (["# OASIS_START";
      "# OASIS_STOP";
      "";
      "<**/*>: include"] @ lines)

let oasis_file lines =
  file "_oasis"
    (["OASISFormat: 0.4";
     "Name: namespaces-oasis-test";
     "Version: 0.1";
     "Synopsis: OASIS test";
     "Authors: Anton Bachin";
     "License: BSD-2-clause";
     "OCamlVersion: >= 4.02";
     "AlphaFeatures: ocamlbuild_more_args";
     "XOCamlbuildPluginTags: package(namespaces)";
     ""] @ lines)

let ocamlbuild ?fails_with targets =
  let arguments =
    ["-use-ocamlfind"; "-plugin-tag"; "package(namespaces)"; "-cflags";
     "-bin-annot"] @ targets
  in

  match fails_with with
  | None -> _run "ocamlbuild" arguments

  | Some message ->
    let open Process in
    let result = run "ocamlbuild" (Array.of_list arguments) in
    if result.Output.exit_status = Exit.Exit 0 then
      let report =
        Printf.sprintf "Command did not fail:\n%s %s"
          "ocamlbuild" (String.concat " " arguments)
      in
      assert_failure report
    else
      let stdout = String.concat "\n" result.Output.stdout in
      let regexp = Str.regexp_string message in
      try Str.search_forward regexp stdout 0 |> ignore
      with Not_found ->
        let report = Printf.sprintf
          "Command did not fail with expected message:\n%s %s\n\nSTDOUT:\n\n%s"
          "ocamlbuild" (String.concat " " arguments)
          stdout
        in
        assert_failure report

let oasis () =
  _run "oasis" ["setup"];
  _run "ocaml" ["setup.ml"; "-configure"];
  _run "ocaml" ["setup.ml"; "-build"]

let test name f = name >:: fun context -> f ()

let install_project =
  let whitespace = Str.regexp "[ \t\r\n]+" in

  fun () ->
    _fresh_dir _project_install_directory_absolute;

    let find_files extension =
      run "find" ["_build"; "-name"; "*." ^ extension]
      |> Str.split whitespace
    in

    let files =
      ["cma"; "cmxa"; "a"; "cmi"; "cmt"; "cmti"]
      |> List.map find_files
      |> List.flatten
      |> List.filter ((<>) "_build/myocamlbuild.cmi")
    in

    _run "ocamlfind" (["install"; _package_name; "META"] @ files)
