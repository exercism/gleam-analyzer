# Gleam Analzyer

The script will receive three parameters:

    The slug of the exercise (e.g. two-fer).
    A path to a directory containing the submitted file(s) (with a trailing slash).
    A path to an output directory (with a trailing slash). This directory is writable.


The analysis.json file should be structured as followed:

{
  "summary": "This solution looks good but has a few points to address",
  "comments": [
    {
      "comment": "ruby.general.some_parameterised_message",
      "params": { "foo": "param1", "bar": "param2" },
      "type": "essential"
    },
    {
      "comment": "ruby.general.some_unparameterised_message",
      "params": {},
      "type": "actionable"
    },
    {
      "comment": "ruby.general.some_unparameterised_message"
    },
    "ruby.general.some_unparameterised_message"
  ]
}
