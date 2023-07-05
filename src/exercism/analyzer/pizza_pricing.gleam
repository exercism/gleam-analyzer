/// https://github.com/exercism/gleam/tree/main/exercises/concept/pizza-pricing
/// 
/// Checks that no imports are used.
/// Checks that list.length is not used for the special cases of 1 or 2 pizzas in `order_price`.
/// 
/// TODO: Checks that the functions are tail recursive.
/// 
import glance
import exercism/analyzer/code
import exercism/analyzer/comment.{Actionable, Comment}

pub const list_length_used = "gleam.pizza_pricing.list_length_used"

pub const imports_used = "gleam.pizza_pricing.imports_used"

pub fn lint(module: glance.Module) -> List(Comment) {
  []
  |> comment.add(
    Comment(list_length_used, [], Actionable),
    when: code.imported_function_called(
      module: module,
      caller: "order_price",
      callee: #("gleam/list", "length"),
    ),
  )
  |> comment.add(
    Comment(imports_used, [], Actionable),
    when: module.imports != [],
  )
}
