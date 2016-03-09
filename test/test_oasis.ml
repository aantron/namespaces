open OUnit2
open Test_helpers

let tests = "oasis" >::: [
  test "binary" begin fun () ->
    project begin fun () ->
      file "src/namespace/foo.ml" ["let v = 1"];
      file "src/main.ml" ["Namespace.Foo.v |> string_of_int |> print_endline"];

      oasis_myocamlbuild_ml ();
      oasis_tags ["<src/**/*>: namespace"];

      oasis_file
        ["Executable main";
         "  Path: src";
         "  BuildTools: ocamlbuild";
         "  MainIs: main.ml"];

      oasis ();

      assert_equal (run "./main.byte" []) "1\n"
    end
  end
]
