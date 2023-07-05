import glance.{
  BinaryOperator, BitString, Block, Call, Case, Expression, FieldAccess, Float,
  Fn, FnCapture, Int, List, NegateBool, NegateInt, Panic, RecordUpdate, String,
  Todo, Tuple, TupleIndex, Variable,
}
import gleam/list
import gleam/result
import gleam/string
import gleam/option.{None, Option, Some}

pub fn get_function(
  module: glance.Module,
  desired_name: String,
) -> Result(glance.Definition(glance.Function), Nil) {
  module.functions
  |> list.find(fn(function) { function.definition.name == desired_name })
}

pub fn get_import(
  module: glance.Module,
  desired_name: String,
) -> Result(glance.Definition(glance.Import), Nil) {
  module.imports
  |> list.find(fn(import_) { import_.definition.module == desired_name })
}

pub fn import_alias(import_: glance.Import) -> String {
  import_.alias
  |> option.lazy_or(fn() {
    import_.module
    |> string.split("/")
    |> list.last
    |> option.from_result
  })
  |> option.unwrap(import_.module)
}

pub fn unqualified_name(
  import_: glance.Import,
  name: String,
) -> Result(String, Nil) {
  import_.unqualified
  |> list.find(fn(item) { item.name == name })
  |> result.map(fn(unqualified) {
    unqualified.alias
    |> option.unwrap(name)
  })
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

/// Checks if a function is imported and called.
/// 
/// TODO: FIXME: This can give a false positive if:
/// - The function is imported in an unqualified fashiona and then shadowed by a
///   variable which is then called.
/// - There is a record assigned to the same name as the import and then a field
///   on it with the same name as the function is accessed and called.
/// 
pub fn imported_function_called(
  module module: glance.Module,
  caller caller: String,
  callee callee: #(String, String),
) -> Bool {
  use import_ <- require(get_import(module, callee.0), or: False)
  use function <- require(get_function(module, caller), or: False)

  let state =
    ImportedFunctionCalledState(
      unqualified: option.from_result(unqualified_name(
        import_.definition,
        callee.1,
      )),
      module: import_alias(import_.definition),
      function: callee.1,
      used: False,
    )

  let visitor =
    Visitor(
      visit_statement: fn(state, _statement) { state },
      visit_expression: imported_function_used_visit_expression,
    )

  fold_statements(function.definition.body, state, visitor).used
}

fn require(
  value: Result(t, e),
  or fallback: out,
  then next: fn(t) -> out,
) -> out {
  case value {
    Ok(v) -> next(v)
    Error(_) -> fallback
  }
}

type ImportedFunctionCalledState {
  ImportedFunctionCalledState(
    used: Bool,
    module: String,
    function: String,
    unqualified: Option(String),
  )
}

fn imported_function_used_visit_expression(
  state: ImportedFunctionCalledState,
  expression: Expression,
) -> ImportedFunctionCalledState {
  let desired_module = state.module
  let desired_function = state.function
  let unqualified_name = state.unqualified

  case expression {
    Call(function: FieldAccess(Variable(module), function), ..) -> {
      case module == desired_module && function == desired_function {
        True -> ImportedFunctionCalledState(..state, used: True)
        False -> state
      }
    }

    Call(function: Variable(function), ..) if Some(function) == unqualified_name -> {
      ImportedFunctionCalledState(..state, used: True)
    }

    _ -> state
  }
}
