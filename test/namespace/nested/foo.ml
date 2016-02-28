(* This module is inside a directory tagged with "namespace", so it will be not
   be reachable by module path Foo, but by module path Namespace.Nested.Foo. The
   sibling module Foo_sibling is externally reachable as
   Namespace.Nested.Foo_sibling, but, from here, it is reachable as just
   Foo_sibling. From Namespace, it is reachable as Nested.Foo_sibling. *)

let v = Foo_sibling.v + 1
