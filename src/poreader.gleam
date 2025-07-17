//// a parser for GNU gettext Portable Objects (.po) files

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{type Order}
import gleam/result
import gleam/string
import nibble
import nibble/lexer

pub type ParseError {
  LexerError(row: Int, col: Int, lexeme: String)
  ParserError(List(String))
}

pub type Comment {
  Flag(String)
  Translator(String)
  Extracted(String)
  Reference(filename: String, line_number: Option(Int))
  Previous(String)
}

pub type Message {
  Singular(
    msgid: String,
    msgstr: String,
    msgctx: Option(String),
    comments: List(Comment),
  )
  Plural(
    msgid: String,
    msgid_plural: String,
    msgstr: Dict(Int, String),
    msgctx: Option(String),
    comments: List(Comment),
  )
}

/// parses the given string into a list of messages
///
pub fn parse(content) -> Result(List(Message), ParseError) {
  use tokens <- result.try(
    lexer.run(content, po_lexer())
    |> result.map_error(translate_lex_error),
  )
  use parsed <- result.try(
    nibble.run(tokens, po_parser())
    |> result.map_error(fn(error) {
      ParserError(list.map(error, translate_parse_error))
    }),
  )
  Ok(parsed)
}

fn translate_lex_error(error: lexer.Error) -> ParseError {
  case error {
    lexer.NoMatchFound(row:, col:, lexeme:) -> LexerError(row, col, lexeme)
  }
}

fn translate_parse_error(dead_end: nibble.DeadEnd(Token, b)) -> String {
  case dead_end.problem {
    nibble.BadParser(str) -> "bad parser: " <> str
    nibble.Custom(str) -> "custom: " <> str
    nibble.EndOfInput -> "Unexpected end of input"
    nibble.Expected(exp, token) ->
      "Expected " <> exp <> " got: " <> to_string(token)
    nibble.Unexpected(token) -> "Unexpected token " <> to_string(token)
  }
}

/// returns true when the message is of type singular
///
pub fn is_singular(message: Message) -> Bool {
  case message {
    Singular(..) -> True
    Plural(..) -> False
  }
}

/// returns true when the message is of type plural
///
pub fn is_plural(message: Message) -> Bool {
  case message {
    Singular(..) -> False
    Plural(..) -> True
  }
}

/// returns the translation id of the message
///
pub fn get_id(message: Message) -> String {
  case message {
    Singular(msgid: msgid, ..) -> msgid
    Plural(msgid: msgid, ..) -> msgid
  }
}

/// returns the text of the message
/// when given a plural message, the first translation is returned
///
pub fn get_text(message: Message) -> Option(String) {
  case message {
    Singular(msgstr: msgstr, ..) -> Some(msgstr)
    Plural(msgstr: msgstr, ..) ->
      dict.to_list(msgstr)
      |> list.sort(by: tuple_compare)
      |> list.first()
      |> result.map(fn(el) { el.1 })
      |> option.from_result()
  }
}

/// returns the plural id of the message
///
pub fn get_plural_id(message: Message) -> Option(String) {
  case message {
    Singular(..) -> None
    Plural(msgid_plural: msgid, ..) -> Some(msgid)
  }
}

fn tuple_compare(a: #(Int, a), with b: #(Int, a)) -> Order {
  case a.0 == b.0 {
    True -> order.Eq
    False ->
      case a.0 < b.0 {
        True -> order.Lt
        False -> order.Gt
      }
  }
}

/// returns the plural translation of the message
/// when given a singular message, the single translation is returned
///
pub fn get_plural_text(message: Message, idx: Int) -> Option(String) {
  case message {
    Singular(msgstr: msgstr, ..) -> Some(msgstr)
    Plural(msgstr: msgstr, ..) -> dict.get(msgstr, idx) |> option.from_result()
  }
}

// Lexer
type Token {
  MsgId
  MsgIdPlural
  MsgStr
  MsgCtx
  StringLiteral(String)
  CommentTranslator(String)
  CommentFlag(String)
  CommentReference(String)
  CommentExtracted(String)
  CommentPrevious(String)
  Newline
  LeftBracket
  RightBracket
  Number(Int)
}

fn to_string(token: Token) -> String {
  case token {
    CommentExtracted(_) -> "#."
    CommentFlag(_) -> "#,"
    CommentPrevious(_) -> "#|"
    CommentReference(_) -> "#:"
    CommentTranslator(_) -> "# "
    LeftBracket -> "["
    MsgCtx -> "msgctx"
    MsgId -> "msgid"
    MsgIdPlural -> "msgid_plural"
    MsgStr -> "msgstr"
    Newline -> "\n"
    Number(int) -> int.to_string(int)
    RightBracket -> "]"
    StringLiteral(str) -> str
  }
}

fn po_lexer() {
  lexer.simple([
    // Keywords
    lexer.keyword("msgid_plural", " ", MsgIdPlural),
    lexer.keyword("msgid", " ", MsgId),
    lexer.keyword("msgstr", "", MsgStr),
    lexer.keyword("msgctx", "", MsgCtx),
    lexer.token("[", LeftBracket),
    lexer.token("]", RightBracket),
    lexer.int(Number),
    // String literals (quoted strings)
    lexer.string("\"", StringLiteral),
    // Comments (lines starting with #)
    lexer.comment("# ", CommentTranslator),
    lexer.comment("#, ", CommentFlag),
    lexer.comment("#: ", CommentReference),
    lexer.comment("#. ", CommentExtracted),
    lexer.comment("#| ", CommentPrevious),
    // Newlines
    lexer.token("\n", Newline),
    lexer.token("\r\n", Newline),
    // Skip whitespace (except newlines)
    lexer.whitespace(Nil)
      |> lexer.ignore,
  ])
}

// Parser

fn blank_lines() {
  nibble.many1(nibble.token(Newline))
}

fn string_literal_parser() {
  nibble.take_map("Expected string", fn(tok) {
    case tok {
      StringLiteral(s) -> option.Some(s)
      _ -> option.None
    }
  })
}

fn multiline_string_parser() {
  // at least one line is required
  use parts <- nibble.do(
    nibble.many1(fn() {
      use part <- nibble.do(string_literal_parser())
      use _ <- nibble.do(nibble.token(Newline))
      nibble.return(part)
    }()),
  )

  nibble.return(string.concat(parts))
}

fn msgid_parser() {
  use _ <- nibble.do(nibble.token(MsgId))
  use id <- nibble.do(multiline_string_parser())
  nibble.return(id)
}

fn msgctx_parser() {
  use _ <- nibble.do(nibble.token(MsgCtx))
  use ctx <- nibble.do(multiline_string_parser())
  nibble.return(ctx)
}

fn msgid_plural_parser() {
  use _ <- nibble.do(nibble.token(MsgIdPlural))
  use id <- nibble.do(multiline_string_parser())
  nibble.return(id)
}

fn msgstr_parser() {
  use _ <- nibble.do(nibble.token(MsgStr))
  use str <- nibble.do(multiline_string_parser())
  nibble.return(str)
}

fn msgstr_plural_parser() {
  nibble.many(fn() {
    use _ <- nibble.do(nibble.token(MsgStr))
    use _ <- nibble.do(nibble.token(LeftBracket))
    use index <- nibble.do(
      nibble.take_map("expected index", fn(tok) {
        case tok {
          Number(idx) -> Some(idx)
          _ -> None
        }
      }),
    )
    use _ <- nibble.do(nibble.token(RightBracket))
    use str <- nibble.do(multiline_string_parser())
    nibble.return(#(index, str))
  }())
  |> nibble.map(fn(values) { dict.from_list(values) })
}

fn comment_flag_parser() {
  nibble.many1(fn() {
    use comment <- nibble.do(
      nibble.take_map("expected comment", fn(tok) {
        case tok {
          CommentFlag(f) -> Some(f)
          _ -> None
        }
      }),
    )
    use _ <- nibble.do(nibble.token(Newline))
    let flags = string.split(comment, ", ") |> list.map(fn(str) { Flag(str) })
    nibble.return(flags)
  }())
  |> nibble.map(list.flatten)
}

fn comment_translator_parser() {
  nibble.many1(fn() {
    use comment <- nibble.do(
      nibble.take_map("expected comment", fn(tok) {
        case tok {
          CommentTranslator(t) -> Some(t)
          _ -> None
        }
      }),
    )
    use _ <- nibble.do(nibble.token(Newline))
    nibble.return(Translator(comment))
  }())
}

fn comment_extracted_parser() {
  nibble.many1(fn() {
    use comment <- nibble.do(
      nibble.take_map("expected comment", fn(tok) {
        case tok {
          CommentExtracted(t) -> Some(t)
          _ -> None
        }
      }),
    )
    use _ <- nibble.do(nibble.token(Newline))
    nibble.return(Extracted(comment))
  }())
}

fn comment_previous_parser() {
  nibble.many1(fn() {
    use comment <- nibble.do(
      nibble.take_map("expected comment", fn(tok) {
        case tok {
          CommentPrevious(t) -> Some(t)
          _ -> None
        }
      }),
    )
    use _ <- nibble.do(nibble.token(Newline))
    nibble.return(Previous(comment))
  }())
}

fn comment_reference_parser() {
  nibble.many1(fn() {
    use comment <- nibble.do(
      nibble.take_map("Expected comment", fn(tok) {
        case tok {
          CommentReference(r) -> Some(r)
          _ -> None
        }
      }),
    )
    use _ <- nibble.do(nibble.token(Newline))

    case string.split_once(comment, ":") {
      Ok(#(file, line)) -> {
        let number = int.parse(line) |> option.from_result()
        nibble.return(Reference(file, number))
      }
      _ -> nibble.return(Reference(comment, None))
    }
  }())
}

fn message_parser() {
  use comments <- nibble.do(
    nibble.many(
      nibble.one_of([
        comment_flag_parser(),
        comment_reference_parser(),
        comment_translator_parser(),
        comment_extracted_parser(),
        comment_previous_parser(),
      ]),
    )
    |> nibble.map(list.flatten),
  )

  use msgctx <- nibble.do(nibble.optional(msgctx_parser()))
  use msgid <- nibble.do(msgid_parser())
  use msgid_plural <- nibble.do(nibble.optional(msgid_plural_parser()))
  case msgid_plural {
    None -> {
      use msgstr <- nibble.do(msgstr_parser())
      nibble.return(Singular(msgid, msgstr, msgctx, comments))
    }

    Some(msgid_plural) -> {
      use msgstrs <- nibble.do(msgstr_plural_parser())
      nibble.return(Plural(msgid, msgid_plural, msgstrs, msgctx, comments))
    }
  }
}

fn po_parser() {
  use _ <- nibble.do(nibble.many(blank_lines()))

  use messages <- nibble.do(
    nibble.many(fn() {
      use msg <- nibble.do(message_parser())
      use _ <- nibble.do(nibble.many(blank_lines()))
      nibble.return(msg)
    }()),
  )
  use _ <- nibble.do(nibble.many(blank_lines()))
  use _ <- nibble.do(nibble.eof())

  nibble.return(messages)
}
