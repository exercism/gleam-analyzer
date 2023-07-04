import gleeunit/should
import gleam/string
import exercism/analyzer/comment.{Comment}

pub fn to_json_test() {
  [
    Comment(
      comment: "one.two.three",
      params: [#("k1", "v1"), #("k2", "v2")],
      type_: comment.Actionable,
    ),
    Comment(
      comment: "four.five",
      params: [#("k2", "v2"), #("k3", "v3")],
      type_: comment.Celebratory,
    ),
  ]
  |> comment.comments_to_json
  |> should.equal(string.concat([
    "{\"comments\":[",
    "{\"comment\":\"one.two.three\",\"params\":{\"k1\":\"v1\",\"k2\":\"v2\"},\"type\":\"actionable\"},",
    "{\"comment\":\"four.five\",\"params\":{\"k2\":\"v2\",\"k3\":\"v3\"},\"type\":\"celebratory\"}",
    "]}",
  ]))
}
