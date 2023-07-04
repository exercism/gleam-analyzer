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
