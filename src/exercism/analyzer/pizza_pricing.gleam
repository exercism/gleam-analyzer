/// https://github.com/exercism/gleam/tree/main/exercises/concept/pizza-pricing
/// 
/// Checks that no imports are used.
/// Checks that list.length is not used for the special cases of 1 or 2 pizzas in `order_price`.
/// 
/// TODO: Checks that the functions are tail recursive.
/// 
import glance.{
  BinaryOperator, BitString, Block, Call, Case, FieldAccess, Float, Fn,
  FnCapture, Int, List, NegateBool, NegateInt, Panic, RecordUpdate, String, Todo,
  Tuple, TupleIndex, Variable,
}
import gleam/list
import gleam/option.{None, Some}

pub const comment_prefix = "gleam.pizza_pricing."

pub type Comment {
  Comment(comment: String, params: List(#(String, String)), type_: CommentType)
}

pub type CommentType {
  /// This one will prevent the student from being able to submit their solution.
  Essential
  Actionable
  Informative
  Celebratory
}

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

/// Checks that list.length is not used for the special cases of 1 or 2 pizzas in `order_price`.
fn check_list_length_not_used(module: glance.Module) -> List(Comment) {
  use function <- require(find_function(module, "order_price"))
  case list.any(function.body, statement_uses_list_length) {
    True -> [Comment(comment_prefix <> "list_length_used", [], Actionable)]
    False -> []
  }
}

fn statement_uses_list_length(statement: glance.Statement) -> Bool {
  case statement {
    glance.Use(function: expression, ..)
    | glance.Assignment(value: expression, ..)
    | glance.Expression(expression) -> expression_uses_list_length(expression)
  }
}

fn field_uses_list_length(field: glance.Field(glance.Expression)) -> Bool {
  expression_uses_list_length(field.item)
}

fn expression_uses_list_length(expression: glance.Expression) -> Bool {
  case expression {
    Call(function: FieldAccess(Variable("list"), "length"), ..) -> {
      True
    }

    Int(_) | Float(_) | String(_) | Variable(_) | Panic(_) | Todo(_) -> False

    TupleIndex(tuple: expression, ..)
    | NegateInt(expression)
    | NegateBool(expression) -> expression_uses_list_length(expression)

    Tuple(expressions) -> list.any(expressions, expression_uses_list_length)

    Fn(body: statements, ..) | Block(statements) ->
      list.any(statements, statement_uses_list_length)

    List(elements: elements, rest: rest) -> {
      list.any(elements, expression_uses_list_length) || case rest {
        None -> False
        Some(expression) -> expression_uses_list_length(expression)
      }
    }

    RecordUpdate(record: record, fields: fields, ..) -> {
      expression_uses_list_length(record) || list.any(
        fields,
        fn(pair) { expression_uses_list_length(pair.1) },
      )
    }

    FieldAccess(container: container, ..) -> {
      expression_uses_list_length(container)
    }

    Call(function: function, arguments: arguments) -> {
      let first = expression_uses_list_length(function)
      first || list.any(arguments, field_uses_list_length)
    }

    FnCapture(
      function: function,
      arguments_before: before,
      arguments_after: after,
    ) -> {
      let check_fields = list.any(_, field_uses_list_length)
      let first = expression_uses_list_length(function)
      first || check_fields(before) || check_fields(after)
    }

    BitString(segments) -> list.any(segments, segment_uses_list_length)

    Case(subjects: subjects, clauses: clauses) -> {
      let first = list.any(subjects, expression_uses_list_length)
      first || list.any(clauses, clause_uses_list_length)
    }

    BinaryOperator(left: left, right: right, ..) -> {
      expression_uses_list_length(left) || expression_uses_list_length(right)
    }
  }
}

fn clause_uses_list_length(clause: glance.Clause) -> Bool {
  expression_uses_list_length(clause.body)
}

fn segment_uses_list_length(segment: #(glance.Expression, _)) -> Bool {
  expression_uses_list_length(segment.0)
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
