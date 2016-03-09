open OUnit2
open Test_helpers

let prepare_library () =
  project begin fun () ->
    file "src/foo.ml" ["let v = 1"];
    file "src/optional/bar.ml" ["let v = Foo.v + 1"];
    file "src/optional_bar.ml" ["include Optional.Bar"];

    file "src/baz.ml" ["exit 1"];
    file "src/optional/quux.ml" ["exit 1"];

    tags
      ["<src/**/*>: namespace";
       "\"src\": namespace_with_name(Test_library), namespace_lib(library)";
       "\"src/optional\": namespace_lib(optional)";
       "\"src/optional_bar.ml\": namespace_lib(optional)"];
    myocamlbuild_ml ();

    ocamlbuild
      ["library.cma"; "library.cmxa"; "optional.cma"; "optional.cmxa"];

    file "META"
      ["archive(byte) = \"library.cma\"";
       "archive(native) = \"library.cmxa\"";
       "";
       "package \"optional\" (";
       "  requires = \"test-library\"";
       "  archive(byte) = \"optional.cma\"";
       "  archive(native) = \"optional.cmxa\"";
       ")"];

    install_project ()
  end

let depend ?(optional = false) code expect =
  depending begin fun () ->
    let package =
      if optional then "test-library.optional" else "test-library" in

    file "src/main.ml" code;
    tags ["<src/main.*>: package(" ^ package ^ ")"];
    ocamlbuild ["main.byte"; "main.native"];

    let expect = Printf.sprintf "%i\n" expect in
    assert_equal (run "./main.byte" []) expect;
    assert_equal (run "./main.native" []) expect
  end

let tests = "library" >::: [
  test "basic" begin fun () ->
    prepare_library ();
    depend ["Test_library.Foo.v |> string_of_int |> print_endline"] 1
  end;

  test "optional" begin fun () ->
    prepare_library ();
    depend ~optional:true
      ["Test_library.Optional.Bar.v |> string_of_int |> print_endline"] 2
  end;

  test "optional_legacy" begin fun () ->
    prepare_library ();
    depend ~optional:true
      ["Test_library.Optional_bar.v |> string_of_int |> print_endline"] 2
  end
]
