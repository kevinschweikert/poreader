# poreader

[![Package Version](https://img.shields.io/hexpm/v/poreader)](https://hex.pm/packages/poreader)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/poreader/)

```sh
gleam add poreader
```

```gleam
import poreader

pub fn main() {
  "#, fuzzy
  msgid \"some id\"
  msgstr \"some translation\"
  "
  |> poreader.parse()
  // Ok([ Singular("some id", "some translation", None, [Flag("fuzzy")])]),
}
```

Further documentation can be found at <https://hexdocs.pm/poreader>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
