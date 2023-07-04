/// https://github.com/exercism/gleam/tree/main/exercises/concept/pizza-pricing
/// 
/// Checks that no imports are used.
/// Checks that list.length is not used for the special cases of 1 or 2 pizzas in `order_price`.
/// 
/// TODO: Checks that the functions are tail recursive.
/// 
import glance.{Call, Expression, FieldAccess, Variable}
import gleam/list
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
  use function <- require(find_function(module, "order_price"))

  let visitor =
    Visitor(
      visit_statement: fn(state, _statement) { state },
      visit_expression: check_if_call_to_list_length,
    )

  let state = LengthCheckState(used: False)
  let state = code.fold_statements(function.body, state, visitor)

  case state.used {
    True -> [Comment(comment_prefix <> "list_length_used", [], Actionable)]
    False -> []
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

fn find_function(
  module: glance.Module,
  desired_name: String,
) -> Result(glance.Function, String) {
  case module.functions {
    [] -> Error("No functions found")
    [glance.Definition(definition: function, ..), ..] -> {
      case function.name == desired_name {
        True -> Ok(function)
        False -> find_function(module, desired_name)
      }
    }
    [_, ..] -> find_function(module, desired_name)
  }
}

fn require(value: Result(t, e), next: fn(t) -> List(Comment)) -> List(Comment) {
  case value {
    Ok(v) -> next(v)
    Error(_) -> []
  }
}
