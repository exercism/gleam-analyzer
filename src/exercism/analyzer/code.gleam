import glance.{
  BinaryOperator, BitString, Block, Call, Case, Expression, FieldAccess, Float,
  Fn, FnCapture, Int, List, NegateBool, NegateInt, Panic, RecordUpdate, String,
  Todo, Tuple, TupleIndex, Variable,
}
import gleam/list
import gleam/option.{None, Some}

pub fn get_function(
  module: glance.Module,
  desired_name: String,
) -> Result(glance.Function, String) {
  case module.functions {
    [] -> Error("No functions found")
    [glance.Definition(definition: function, ..), ..] -> {
      case function.name == desired_name {
        True -> Ok(function)
        False -> get_function(module, desired_name)
      }
    }
    [_, ..] -> get_function(module, desired_name)
  }
}

pub type Visitor(state) {
  Visitor(
    visit_expression: fn(state, Expression) -> state,
    visit_statement: fn(state, glance.Statement) -> state,
  )
}

pub fn fold_statements(
  statements: List(glance.Statement),
  state: state,
  visitor: Visitor(state),
) -> state {
  let fold = fn(state, statement) { fold_statement(statement, state, visitor) }
  list.fold(statements, state, fold)
}

pub fn fold_expressions(
  expressions: List(glance.Expression),
  state: state,
  visitor: Visitor(state),
) -> state {
  let fold = fn(state, expression) {
    fold_expression(expression, state, visitor)
  }
  list.fold(expressions, state, fold)
}

pub fn fold_statement(
  statement: glance.Statement,
  state: state,
  visitor: Visitor(state),
) -> state {
  let state = visitor.visit_statement(state, statement)

  case statement {
    glance.Use(function: expression, ..)
    | glance.Assignment(value: expression, ..)
    | Expression(expression) -> {
      let state = visitor.visit_expression(state, expression)
      fold_expression(expression, state, visitor)
    }
  }
}

fn fold_expression(
  expression: Expression,
  state: state,
  visitor: Visitor(state),
) -> state {
  let state = visitor.visit_expression(state, expression)

  case expression {
    Int(_) | Float(_) | String(_) | Variable(_) | Panic(_) | Todo(_) -> state

    TupleIndex(tuple: expression, ..)
    | NegateInt(expression)
    | NegateBool(expression) -> fold_expression(expression, state, visitor)

    Tuple(expressions) -> {
      fold_expressions(expressions, state, visitor)
    }

    Fn(body: statements, ..) | Block(statements) -> {
      fold_statements(statements, state, visitor)
    }

    List(elements: elements, rest: rest) -> {
      let state = fold_expressions(elements, state, visitor)
      case rest {
        None -> state
        Some(expression) -> fold_expression(expression, state, visitor)
      }
    }

    RecordUpdate(record: record, fields: fields, ..) -> {
      let state = fold_expression(record, state, visitor)
      let fold = fn(state, pair: #(String, Expression)) {
        fold_expression(pair.1, state, visitor)
      }
      list.fold(fields, state, fold)
    }

    FieldAccess(container: container, ..) -> {
      visitor.visit_expression(state, container)
    }

    Call(function: function, arguments: arguments) -> {
      let state = fold_expression(function, state, visitor)
      let fold = fn(state, field: glance.Field(Expression)) {
        fold_expression(field.item, state, visitor)
      }
      list.fold(arguments, state, fold)
    }

    FnCapture(
      function: function,
      arguments_before: before,
      arguments_after: after,
    ) -> {
      let state = fold_expression(function, state, visitor)
      let fold = fn(state, field: glance.Field(Expression)) {
        fold_expression(field.item, state, visitor)
      }
      let state = list.fold(before, state, fold)
      list.fold(after, state, fold)
    }

    BitString(segments) -> {
      let fold = fn(state, segment: #(Expression, _)) {
        fold_expression(segment.0, state, visitor)
      }
      list.fold(segments, state, fold)
    }

    Case(subjects: subjects, clauses: clauses) -> {
      let state = fold_expressions(subjects, state, visitor)

      let fold = fn(state, clause: glance.Clause) {
        fold_expression(clause.body, state, visitor)
      }
      list.fold(clauses, state, fold)
    }

    BinaryOperator(left: left, right: right, ..) -> {
      let state = fold_expression(left, state, visitor)
      fold_expression(right, state, visitor)
    }
  }
}
