open OUnit2

let tests = "namespaces" >::: [
  Test_basic.tests;
  Test_oasis.tests;
  Test_library.tests
]

let () =
  Test_helpers.install_plugin ();
  run_test_tt_main tests
