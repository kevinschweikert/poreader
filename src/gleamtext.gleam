import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/string
import simplifile

pub type Message {
  Singular(id: String, text: String)
  Plural(id: String, id_plural: String, text: Dict(Int, String))
}

pub type PO {
  PO(messages: List(Message))
}

pub fn main() {
  let assert Ok(content) = simplifile.read(from: "test.po")
  content
  |> string.split("\n\n")
  |> list.filter_map(parse_message)
  |> echo
}

fn parse_message(input: String) -> Result(Message, String) {
  let lines =
    input
    |> string.split("\n")
    |> list.filter_map(fn(line) {
      case string.split_once(line, " ") {
        Ok(#("msgid", id)) -> Ok(#("msgid", id))
        Ok(#("msgid_plural", id)) -> Ok(#("msgid_plural", id))
        Ok(#("msgstr", str)) -> Ok(#("msgstr", str))
        Ok(#("msgstr[" <> id, str)) -> {
          case string.split_once(id, "]") {
            Ok(#(id, _)) -> Ok(#(id, str))
            _ -> Error("MsgId wrong format")
          }
        }
        _ -> Error("Unknown line type")
      }
    })

  case lines {
    [#("msgid", id), #("msgstr", str)] -> Ok(Singular(id, str))
    [#("msgid", id), #("msgid_plural", plural), ..rest] -> {
      let text =
        rest
        |> list.filter_map(fn(line) {
          case int.parse(line.0) {
            Ok(int) -> Ok(#(int, line.1))
            _ -> Error("MsgId not an integer")
          }
        })
        |> dict.from_list

      Ok(Plural(id, plural, text))
    }
    _ -> Error("Uknown message")
  }
}
