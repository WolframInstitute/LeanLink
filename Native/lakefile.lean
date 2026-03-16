import Lake
open Lake DSL

package leanlink where
  leanOptions := #[⟨`autoImplicit, false⟩]

@[default_target]
lean_lib LeanLink where
  srcDir := "lib"

lean_exe leanlink where
  root := `Main
  srcDir := "app"

