import gleam/dict
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import poreader.{
  Extracted, Flag, Plural, Previous, Reference, Singular, Translator,
}

pub fn main() {
  gleeunit.main()
}

pub fn singular_message_test() {
  "msgid \"message id\"
  msgstr \"translation\"
  "
  |> poreader.parse()
  |> should.equal(Ok([Singular("message id", "translation", None, [])]))
}

pub fn singular_message_with_ctx_test() {
  "
  msgctx \"some context\"
  msgid \"message id\"
  msgstr \"translation\"
  "
  |> poreader.parse()
  |> should.equal(
    Ok([Singular("message id", "translation", Some("some context"), [])]),
  )
}

pub fn singular_message_multiline_test() {
  "
  msgid \"\"
  \"first line \n\"
  \"second line\"
  msgstr \"translation\"
  "
  |> poreader.parse()
  |> should.equal(
    Ok([Singular("first line \nsecond line", "translation", None, [])]),
  )
}

pub fn singular_message_flags_test() {
  "#, elixir-autogen, elixir-format, fuzzy
  msgid \"message id\"
  msgstr \"translation\"
  "
  |> poreader.parse()
  |> should.equal(
    Ok([
      Singular("message id", "translation", None, [
        Flag("elixir-autogen"),
        Flag("elixir-format"),
        Flag("fuzzy"),
      ]),
    ]),
  )
}

pub fn singular_message_references_test() {
  "#: my/file:123
  #: my/very/nested/file
  msgid \"message id\"
  msgstr \"translation\"
  "
  |> poreader.parse()
  |> should.equal(
    Ok([
      Singular("message id", "translation", None, [
        Reference("my/file", Some(123)),
        Reference("my/very/nested/file", None),
      ]),
    ]),
  )
}

pub fn singular_message_all_comments_test() {
  "#. some extracted comment
  # somme translator comment
  #: my/very/nested/file
  #, fuzzy
  #| msgid old msgid
  msgid \"message id\"
  msgstr \"translation\"
  "
  |> poreader.parse()
  |> should.equal(
    Ok([
      Singular("message id", "translation", None, [
        Extracted("some extracted comment"),
        Translator("somme translator comment"),
        Reference("my/very/nested/file", None),
        Flag("fuzzy"),
        Previous("msgid old msgid"),
      ]),
    ]),
  )
}

pub fn singular_message_translator_test() {
  "# some comment
  msgid \"message id\"
  msgstr \"translation\"
  "
  |> poreader.parse()
  |> should.equal(
    Ok([
      Singular("message id", "translation", None, [Translator("some comment")]),
    ]),
  )
}

pub fn plural_message_test() {
  "msgid \"one\"
  msgid_plural \"more\"
  msgstr[0] \"eins\"
  msgstr[1] \"mehr\"
  "
  |> poreader.parse()
  |> should.equal(
    Ok([
      Plural(
        "one",
        "more",
        dict.from_list([#(0, "eins"), #(1, "mehr")]),
        None,
        [],
      ),
    ]),
  )
}

pub fn get_translation_test() {
  Singular("message id", "translation", Some("some context"), [])
  |> poreader.get_translation(None)
  |> should.equal(Ok("translation"))

  Plural("one", "more", dict.from_list([#(0, "eins"), #(1, "mehr")]), None, [])
  |> poreader.get_translation(Some(1))
  |> should.equal(Ok("mehr"))
}
