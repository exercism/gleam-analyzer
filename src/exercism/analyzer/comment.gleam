import gleam/json.{Json}
import gleam/pair
import gleam/list

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

pub fn comments_to_json(comments: List(Comment)) -> String {
  json.object([#("comments", json.array(comments, comment_to_json))])
  |> json.to_string
}

pub fn comment_to_json(comment: Comment) -> Json {
  json.object([
    #("comment", json.string(comment.comment)),
    #(
      "params",
      json.object(list.map(comment.params, pair.map_second(_, json.string))),
    ),
    #("type", json.string(comment_type_to_string(comment.type_))),
  ])
}

fn comment_type_to_string(type_: CommentType) -> String {
  case type_ {
    Essential -> "essential"
    Actionable -> "actionable"
    Informative -> "informative"
    Celebratory -> "celebratory"
  }
}
