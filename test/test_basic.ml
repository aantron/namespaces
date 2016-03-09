open OUnit2
open Test_helpers

let basic_build_system () =
  myocamlbuild_ml ();
  tags ["<src/**/*>: namespace"]

let build_and_test ?(target = "main") expect =
  basic_build_system ();

  let byte_target = target ^ ".byte" in
  let native_target = target ^ ".native" in
  ocamlbuild [byte_target; native_target];

  let expect = Printf.sprintf "%i\n" expect in
  let byte_product =
    Filename.concat Filename.current_dir_name (Filename.basename byte_target) in
  let native_product =
    Filename.concat
      Filename.current_dir_name (Filename.basename native_target) in

  assert_equal (run byte_product []) expect;
  assert_equal (run native_product []) expect

let tests = "basic" >::: [
  test "namespacing" begin fun () ->
    project begin fun () ->
      file "src/namespace/foo.ml" ["let v = 1"];
      file "src/main.ml" ["Namespace.Foo.v |> string_of_int |> print_endline"];

      build_and_test ~target:"src/main" 1
    end
  end;

  test "inferred_target" begin fun () ->
    project begin fun () ->
      file "src/namespace/foo.ml" ["let v = 1"];
      file "src/main.ml" ["Namespace.Foo.v |> string_of_int |> print_endline"];

      build_and_test 1
    end
  end;

  test "sibling_not_linked" begin fun () ->
    project begin fun () ->
      file "src/namespace/foo.ml" ["let v = 1"];
      file "src/namespace/bar.ml" ["let () = exit 1"];
      file "src/main.ml" ["Namespace.Foo.v |> string_of_int |> print_endline"];

      build_and_test 1
    end;

    project begin fun () ->
      file "src/namespace/foo.ml" ["let v = 1"];
      file "src/namespace/bar.ml" ["let v = 2"];
      file "src/main.ml"
        ["(Namespace.Foo.v + Namespace.Bar.v)";
         "|> string_of_int |> print_endline"];

      build_and_test 3
    end
  end;

  test "nested_namespace" begin fun () ->
    project begin fun () ->
      file "src/namespace/a/foo.ml" ["let v = 1"];
      file "src/main.ml"
        ["Namespace.A.Foo.v |> string_of_int |> print_endline"];

      build_and_test 1
    end
  end;

  test "submodules_hidden" begin fun () ->
    project begin fun () ->
      file "src/namespace/foo.ml" ["let v = 1"];
      file "src/main.ml" ["Foo.v |> string_of_int |> print_endline"];

      basic_build_system ();

      ocamlbuild ~fails_with:"Unbound module Foo" ["main.native"]
    end
  end;

  test "sibling_reference" begin fun () ->
    project begin fun () ->
      file "src/namespace/foo.ml" ["let v = 1"];
      file "src/namespace/bar.ml" ["let v = Foo.v + 1"];
      file "src/main.ml" ["Namespace.Bar.v |> string_of_int |> print_endline"];

      build_and_test 2
    end
  end;

  test "cousin_reference" begin fun () ->
    project begin fun () ->
      file "src/namespace_1/foo.ml" ["let v = 1"];
      file "src/namespace_2/foo.ml" ["let v = Namespace_1.Foo.v + 1"];
      file "src/main.ml"
        ["Namespace_2.Foo.v |> string_of_int |> print_endline"];

      build_and_test 2
    end
  end;

  test "cousin_reference_reversed" begin fun () ->
    project begin fun () ->
      file "src/namespace_1/foo.ml" ["let v = Namespace_2.Foo.v + 1"];
      file "src/namespace_2/foo.ml" ["let v = 1"];
      file "src/main.ml"
        ["Namespace_1.Foo.v |> string_of_int |> print_endline"];

      build_and_test 2
    end
  end
]
