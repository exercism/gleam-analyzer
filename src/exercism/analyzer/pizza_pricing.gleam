/// https://github.com/exercism/gleam/tree/main/exercises/concept/pizza-pricing
/// 
/// Checks that no imports are used.
/// Checks that list.length is not used for the special cases of 1 or 2 pizzas in `order_price`.
/// 
/// TODO: Checks that the functions are tail recursive.
/// 
import glance.{Call, Expression, FieldAccess, Variable}
import gleam/list
import gleam/bool
import exercism/analyzer/code.{Visitor}
import exercism/analyzer/comment.{Actionable, Comment}

pub const comment_prefix = "gleam.pizza_pricing."

pub fn lint(module: glance.Module) -> List(Comment) {
  list.flatten([
    check_no_imports_are_used(module),
    check_list_length_not_used(module),
  ])
}

/// Checks that no imports are used.
fn check_no_imports_are_used(module: glance.Module) -> List(Comment) {
  case module.imports {
    [] -> []
    _ -> [Comment(comment_prefix <> "imports_used", [], Actionable)]
  }
}

type LengthCheckState {
  LengthCheckState(used: Bool)
}

/// Checks that list.length is not used for the special cases of 1 or 2 pizzas in `order_price`.
fn check_list_length_not_used(module: glance.Module) -> List(Comment) {
  let state = LengthCheckState(used: False)
  let state = list.fold(module.imports, state, check_list_length_not_imported)

  use function <- require(code.get_function(module, "order_price"))

  let visitor =
    Visitor(
      visit_statement: fn(state, _statement) { state },
      visit_expression: check_if_call_to_list_length,
    )

  let state = code.fold_statements(function.body, state, visitor)

  case state.used {
    True -> [Comment(comment_prefix <> "list_length_used", [], Actionable)]
    False -> []
  }
}

fn check_list_length_not_imported(
  state: LengthCheckState,
  import_: glance.Definition(glance.Import),
) -> LengthCheckState {
  let import_ = import_.definition
  use <- bool.guard(import_.module != "gleam/list", state)

  let is_list_length = fn(x: glance.UnqualifiedImport) { x.name == "length" }
  case list.any(import_.unqualified, is_list_length) {
    True -> LengthCheckState(used: True)
    False -> state
  }
}

fn check_if_call_to_list_length(
  state: LengthCheckState,
  expression: Expression,
) -> LengthCheckState {
  case expression {
    Call(function: FieldAccess(Variable("list"), "length"), ..) -> {
      LengthCheckState(used: True)
    }
    _ -> state
  }
}

fn require(value: Result(t, e), next: fn(t) -> List(Comment)) -> List(Comment) {
  case value {
    Ok(v) -> next(v)
    Error(_) -> []
  }
}
