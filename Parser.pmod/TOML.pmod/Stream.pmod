#include "toml.h"

class Stream
{
  public bool is_eof();
  public char next();
  public s8 next_str(int(..) n);
  public variant s8 next_str();
}

class StringStream
{
  inherit Stream;

  constant EOF = '\0';

  protected s8 data;
  protected int(0..) len;
  protected int(0..) cursor;

  protected void create(s8 data)
  {
    set_data(data);
  }

  public this_program set_data(s8 data)
  {
    this::data    = replace(data, ([ "\r\n" : "\n", "\r" : "\n" ]));
    this::len     = sizeof(this::data);
    this::cursor = 0;

    this::data += "\0";

    return this_program::this;
  }

  public bool is_eof()
  {
    return cursor >= len;
  }

  public char next()
  {
    if (cursor >= len) {
      return 0;
    }

    return data[cursor++];
  }

  public s8 next_str(int(0..) n)
  {
    if (cursor + n > len) {
      return 0;
    }

    s8 s = data[cursor .. cursor + (n-1)];
    cursor += n;

    return s;
  }

  public variant s8 next_str()
  {
    if (cursor >= len) {
      return 0;
    }

    s8 s = data[cursor .. cursor];
    cursor += 1;
    return s;
  }

  public s8 current_str()
  {
    if (is_eof()) {
      return 0;
    }

    return data[cursor .. cursor];
  }

  public char current()
  {
    if (is_eof()) {
      return 0;
    }

    return data[cursor];
  }

  public variant s8 current(int(0..) n)
  {
    if (cursor + n >= len) {
      return 0;
    }

    return data[cursor .. cursor + n - 1];
  }

  public char peek(int(0..) n)
  {
    if (cursor + n >= len) {
      return 0;
    }

    return data[cursor + n];
  }

  public variant char peek()
  {
    return peek(1);
  }

  public s8 peek_str(int(0..) n)
  {
    if (cursor + n >= len) {
      return 0;
    }

    return data[cursor + 1 .. cursor + n];
  }

  public variant s8 peek_str()
  {
    return peek_str(1);
  }

  public char rearview(int(0..) n)
  {
    if (cursor - n < 0) {
      return 0;
    }

    return data[cursor - n];
  }

  public variant char rearview()
  {
    return rearview(1);
  }

  public s8 read_to(char|s8|multiset(char) what, bool inclusive)
  {
    s8 s;

    if (stringp(what) || intp(what)) {
      int pos = search(data, what, cursor);

      if (pos > -1) {
        int(0..) rlen = pos;

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

          if (inclusive) {
            pos += 1;
          }

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

  public variant s8 read_to(char|s8|multiset(char) what)
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

  public this_program eat(char|multiset(char) c)
  {
    if (intp(c)) {
      c = (< c >);
    }

    int(0..) start = cursor;
    while (c[data[cursor]]) {
      cursor += 1;

      if (cursor >= len) {
        break;
      }
    }

    return this_program::this;
  }

  public this_program move(int n)
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

  public int(0..) position()
  {
    return cursor;
  }
}
