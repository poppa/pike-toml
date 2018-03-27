
typedef string(8bit) string_t;
typedef int(0..)     char_t;
typedef int(0..)     int_t;
typedef int          uint_t;

class StringStream
{
  constant EOL = '\0';

  private string_t data;
  private int_t    len;
  private int_t    cursor;

  protected void create(string_t data)
  {
    set_data(data);
  }

  public this_program set_data(string_t data)
  {
    this::data    = replace(data, ([ "\r\n" : "\n", "\r" : "\n" ]));
    this::len     = sizeof(this::data);
    this::cursor = 0;

    this::data += "\0";


    return this_program::this;
  }

  public bool is_eol()
  {
    return cursor >= len;
  }

  public char_t next()
  {
    if (cursor >= len) {
      return 0;
    }

    return data[cursor++];
  }

  public string_t next_str(int_t n)
  {
    if (cursor + n > len) {
      return 0;
    }

    string_t s = data[cursor .. cursor + (n-1)];
    cursor += n;

    return s;
  }

  public variant string_t next_str()
  {
    if (cursor >= len) {
      return 0;
    }

    string_t s = data[cursor .. cursor];
    cursor += 1;
    return s;
  }

  public string_t current_str()
  {
    if (is_eol()) {
      return 0;
    }

    return data[cursor .. cursor];
  }

  public char_t current()
  {
    if (is_eol()) {
      return 0;
    }

    return data[cursor];
  }

  public variant string_t current(int_t n)
  {
    if (cursor + n >= len) {
      return 0;
    }

    return data[cursor .. cursor + n - 1];
  }

  public char_t peek(int_t n)
  {
    if (cursor + n >= len) {
      return 0;
    }

    return data[cursor + n];
  }

  public variant char_t peek()
  {
    return peek(1);
  }

  public string_t peek_str(int_t n)
  {
    if (cursor + n >= len) {
      return 0;
    }

    return data[cursor + 1 .. cursor + n];
  }

  public variant string_t peek_str()
  {
    return peek_str(1);
  }

  public char_t rearview(int_t n)
  {
    if (cursor - n < 0) {
      return 0;
    }

    return data[cursor - n];
  }

  public variant char_t rearview()
  {
    return rearview(1);
  }

  public string_t read_to(char_t|string_t|multiset(char_t) what, bool inclusive)
  {
    string_t s;

    if (stringp(what) || intp(what)) {
      uint_t pos = search(data, what, cursor);

      if (pos > -1) {
        int_t rlen = pos;

        if (inclusive) {
          rlen += stringp(what) ? sizeof(what) : 1;
        }

        s = data[cursor .. rlen-1];
        cursor = rlen;
      }
    }
    else {
      bool hit;
      int pos = cursor + 1;

      while (1) {
        if (what[data[pos]]) {
          hit = true;
          break;
        }

        pos += 1;

        if (pos > len) {
          break;
        }
      }

      if (hit) {
        if (!inclusive) {
          pos -= 1;
        }

        s = data[cursor .. pos];
        cursor = pos;
      }
    }

    return s;
  }

  public variant string_t read_to(char_t|string_t what)
  {
    return read_to(what, false);
  }

  public this_program trim()
  {
    while ((< '\n', ' ', '\t' >)[data[cursor]]) {
      cursor += 1;

      if (cursor == len) {
        break;
      }
    }

    return this_program::this;
  }

  public this_program eat(int_t c)
  {
    while (data[cursor] == c) {
      cursor += 1;

      if (cursor >= len) {
        break;
      }
    }

    return this_program::this;
  }

  public this_program move(uint_t n)
  {
    if (cursor + n >= len) {
      error("Moving by %d would move the cursor past the end. ", n);
    }

    if (cursor + n < 0) {
      error("Moving by %d would move the cursor before the start. ", n);
    }

    cursor += n;

    return this_program::this;
  }

  public variant this_program move()
  {
    return move(1);
  }

  public this_program rewind()
  {
    cursor = 0;
    return this_program::this;
  }

  public int_t position()
  {
    return cursor;
  }
}

mixed lex(string in)
{
  StringStream ps = StringStream(in);
  ps->trim();

  while (!ps->is_eol())  {
    if (ps->current() == '\n') {
      ps->eat('\n');
    }

    if (ps->peek() == '#') {
      ps->next();
      ps->read_to((< '\n', StringStream.EOL >), true);
      continue;
    }

    char_t c = ps->next();
    werror("%c\n", c);
  };
}