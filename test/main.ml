let () =
  Printf.printf "%i\n" Namespace.Nested.Foo.v;
  Printf.printf "%i\n" Namespace.Nested.v;
  Printf.printf "%i\n" Other_namespace.Nested.Foo.v;
  Printf.printf "%i\n" Bar.v
