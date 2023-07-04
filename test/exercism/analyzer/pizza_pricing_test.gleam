import gleeunit/should
import glance
import exercism/analyzer/pizza_pricing
import exercism/analyzer/comment.{Actionable, Comment}

fn lint(src: String) -> List(Comment) {
  let assert Ok(module) = glance.module(src)
  module
  |> pizza_pricing.lint
}

pub fn nothing_test() {
  lint("")
  |> should.equal([])
}

pub fn import_used_test() {
  lint("import wibble")
  |> should.equal([
    Comment(
      comment: "gleam.pizza_pricing.imports_used",
      params: [],
      type_: Actionable,
    ),
  ])
}

pub fn length_not_used_for_order_price_test() {
  "
pub fn order_price(order: List(Pizza)) -> Int {
  case order {
    [pizza] -> pizza_price(pizza) + 3
    [pizza1, pizza2] -> pizza_price(pizza1) + pizza_price(pizza2) + 2
    _ -> count_order_price(order, 0)
  }
}
  "
  |> lint
  |> should.equal([])
}

pub fn length_used_for_order_price_test() {
  "import gleam/list

pub fn order_price(order: List(Pizza)) -> Int {
  case list.length(order) {
    1 -> todo
    2 -> todo
    _ -> count_order_price(order, 0)
  }
}
  "
  |> lint
  |> should.equal([
    Comment(
      comment: "gleam.pizza_pricing.imports_used",
      params: [],
      type_: Actionable,
    ),
    Comment(
      comment: "gleam.pizza_pricing.list_length_used",
      params: [],
      type_: Actionable,
    ),
  ])
}
// TODO: test that we catch the use of list.length even when unqualified
// TODO: test that we catch the use of list.length even when aliasing the module
// TODO: test that we catch the use of list.length even when aliasing the unqualied function
