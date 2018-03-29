
#include "toml.h"

enum SimpleType {
  SIMPLE_TYPE_NONE           = 0,
  SIMPLE_TYPE_KEY            = 1 << 0,
  SIMPLE_TYPE_UNQUOTED_KEY   = 1 << 1,
  SIMPLE_TYPE_QUOTED_KEY     = 1 << 2,
  SIMPLE_TYPE_DOTTED_KEY     = 1 << 3,
  SIMPLE_TYPE_KEYVAL_SEP     = 1 << 4,
  SIMPLE_TYPE_WHITESPACE     = 1 << 5,
  SIMPLE_TYPE_NEWLINE        = 1 << 6,
  SIMPLE_TYPE_STRING         = 1 << 7,
  SIMPLE_TYPE_M_STRING       = 1 << 8,
  SIMPLE_TYPE_VALUE          = SIMPLE_TYPE_STRING | SIMPLE_TYPE_M_STRING,
}

protected mapping(int:s8) simple_type_to_str = ([
  SIMPLE_TYPE_NONE           : "SIMPLE_TYPE_NONE",
  SIMPLE_TYPE_KEY            : "SIMPLE_TYPE_KEY",
  SIMPLE_TYPE_UNQUOTED_KEY   : "SIMPLE_TYPE_UNQUOTED_KEY",
  SIMPLE_TYPE_QUOTED_KEY     : "SIMPLE_TYPE_QUOTED_KEY",
  SIMPLE_TYPE_DOTTED_KEY     : "SIMPLE_TYPE_DOTTED_KEY",
  SIMPLE_TYPE_KEYVAL_SEP     : "SIMPLE_TYPE_KEYVAL_SEP",
  SIMPLE_TYPE_WHITESPACE     : "SIMPLE_TYPE_WHITESPACE",
  SIMPLE_TYPE_NEWLINE        : "SIMPLE_TYPE_NEWLINE",
  SIMPLE_TYPE_STRING         : "SIMPLE_TYPE_STRING",
  SIMPLE_TYPE_M_STRING       : "SIMPLE_TYPE_M_STRING",
  SIMPLE_TYPE_VALUE          : "SIMPLE_TYPE_VALUE",
]);

class Token
{
  protected SimpleType type;
  protected s8         text;
  protected int        line;
  protected int        col;

  protected void create(SimpleType type, s8 text, int(1..) line, int(1..) col)
  {
    this::type = type;
    this::text = text;
    this::line = line;
    this::col  = col;
  }

  protected string _sprintf(int t)
  {
    switch (t) {
      default:
        return sprintf("%O(%O, %O, %O, %O)",
                       object_program(this),
                       type_to_str(),
                       shorten_text(text), line, col);
    }
  }

  protected s8 shorten_text(s8 t)
  {
    if (sizeof(t) > 20) {
      t = t[0..20] + " [...]";
    }

    if (search(t, "\n")) {
      replace(t, "\n", "\\n");
    }

    return t;
  }

  protected s8 type_to_str()
  {
    array(s8) t = ({});

    foreach (simple_type_to_str; int tt; string st) {
      if (type & tt) {
        t += ({ st });
      }
    }

    return t * " | ";
  }
}