
#include "toml.h"

enum Type {
  TYPE_NONE            = 0,
  TYPE_KEY             = 1 << 0,
  TYPE_UNQUOTED_KEY    = 1 << 1,
  TYPE_QUOTED_KEY      = 1 << 2,
  TYPE_DOTTED_KEY      = 1 << 3,
  TYPE_KEYVAL_SEP      = 1 << 4,
  TYPE_WHITESPACE      = 1 << 5,
  TYPE_NEWLINE         = 1 << 6,
  TYPE_STRING          = 1 << 7,
  TYPE_M_STRING        = 1 << 8,
  TYPE_STD_TABLE_OPEN  = 1 << 9,
  TYPE_STD_TABLE_CLOSE = 1 << 10,
  TYPE_COMMENT         = 1 << 11,
  TYPE_KEY_SEP         = 1 << 12,
  TYPE_VALUE           = TYPE_STRING | TYPE_M_STRING,
  TYPE_DEBUG           = 1 << 20,
}

protected mapping(int:s8) _type_to_str = ([
  TYPE_NONE            : "TYPE_NONE",
  TYPE_KEY             : "TYPE_KEY",
  TYPE_UNQUOTED_KEY    : "TYPE_UNQUOTED_KEY",
  TYPE_QUOTED_KEY      : "TYPE_QUOTED_KEY",
  TYPE_DOTTED_KEY      : "TYPE_DOTTED_KEY",
  TYPE_KEYVAL_SEP      : "TYPE_KEYVAL_SEP",
  TYPE_WHITESPACE      : "TYPE_WHITESPACE",
  TYPE_NEWLINE         : "TYPE_NEWLINE",
  TYPE_STRING          : "TYPE_STRING",
  TYPE_M_STRING        : "TYPE_M_STRING",
  TYPE_VALUE           : "TYPE_VALUE",
  TYPE_STD_TABLE_OPEN  : "TYPE_STD_TABLE_OPEN",
  TYPE_STD_TABLE_CLOSE : "TYPE_STD_TABLE_CLOSE",
  TYPE_COMMENT         : "TYPE_COMMENT",
  TYPE_KEY_SEP         : "TYPE_KEY_SEP",
  TYPE_DEBUG           : "<< TYPE_DEBUG >>",
]);

class Token
{
  protected Type _type;
  protected s8   _text;
  protected int  _line;
  protected int  _col;

  protected void create(Type type, s8 text, int(1..) line, int(1..) col)
  {
    this::_type = type;
    this::_text = text;
    this::_line = line;
    this::_col  = col;
  }

  public Type `type() { return _type; }
  public s8   `text() { return _text; }
  public int  `line() { return _line; }
  public int  `column() { return _col; }

  public bool is_a(Type t)
  {
    return this::_type & t;
  }

  protected string _sprintf(int t)
  {
    switch (t) {
      default:
        return sprintf("%O(%O, %O, %O, %O)",
                       object_program(this),
                       type_to_str(),
                       shorten_text(_text), _line, _col);
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

    foreach (_type_to_str; int tt; s8 st) {
      if (_type & tt) {
        t += ({ st });
      }
    }

    return t * " | ";
  }
}
