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

pub fn is_singular_test() {
  Singular("", "", None, []) |> poreader.is_singular |> should.be_true()

  Plural("", "", dict.from_list([]), None, [])
  |> poreader.is_singular
  |> should.be_false()
}

pub fn is_plural_test() {
  Singular("", "", None, []) |> poreader.is_plural |> should.be_false()

  Plural("", "", dict.from_list([]), None, [])
  |> poreader.is_plural
  |> should.be_true()
}

pub fn get_id_test() {
  Singular("some id", "some translation", None, [])
  |> poreader.get_id
  |> should.equal("some id")

  Plural("some id", "some plural id", dict.from_list([]), None, [])
  |> poreader.get_id
  |> should.equal("some id")
}

pub fn get_plural_id_test() {
  Singular("some id", "some translation", None, [])
  |> poreader.get_plural_id
  |> should.be_none

  Plural("some id", "some plural id", dict.from_list([]), None, [])
  |> poreader.get_plural_id
  |> should.be_some
  |> should.equal("some plural id")
}

pub fn get_context_test() {
  Singular("some id", "some translation", Some("context"), [])
  |> poreader.get_context
  |> should.be_some
  |> should.equal("context")

  Plural("some id", "some plural id", dict.from_list([]), Some("context"), [])
  |> poreader.get_context
  |> should.be_some
  |> should.equal("context")
}

pub fn get_comments_test() {
  Singular("some id", "some translation", Some("context"), [
    Flag("fuzzy"),
    Reference("myfile", Some(3)),
  ])
  |> poreader.get_comments
  |> should.equal([Flag("fuzzy"), Reference("myfile", Some(3))])

  Plural("some id", "some plural id", dict.from_list([]), Some("context"), [
    Translator("wibble"),
    Extracted("wobble"),
  ])
  |> poreader.get_comments
  |> should.equal([Translator("wibble"), Extracted("wobble")])
}

pub fn get_text_test() {
  Singular("message id", "translation", Some("some context"), [])
  |> poreader.get_text()
  |> should.equal(Some("translation"))

  Plural("one", "more", dict.from_list([#(0, "eins"), #(1, "mehr")]), None, [])
  |> poreader.get_text()
  |> should.equal(Some("eins"))

  Plural("one", "more", dict.from_list([]), None, [])
  |> poreader.get_text()
  |> should.equal(None)
}

pub fn get_plural_text_test() {
  Singular("message id", "translation", Some("some context"), [])
  |> poreader.get_plural_text(0)
  |> should.equal(Some("translation"))

  Plural("one", "more", dict.from_list([#(0, "eins"), #(1, "mehr")]), None, [])
  |> poreader.get_plural_text(1)
  |> should.equal(Some("mehr"))

  Plural("one", "more", dict.from_list([]), None, [])
  |> poreader.get_plural_text(1)
  |> should.equal(None)
}
