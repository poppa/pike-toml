// https://github.com/poppa/pest
import Pest;
import Parser.TOML;

#include "helpers.h"

int main() {
  describe("Basic Lexer", lambda () {
    test("Expect Lexer to take a File object as input", lambda () {
      Stdio.File file = Stdio.File(toml_file("simple.toml"));
      mixed err = catch (Lexer lexer = Lexer(file));
      expect(err)->to_equal(UNDEFINED);
      Token.Token t = lexer->lex();
      expect(t->is_key())->to_equal(true);
    });

    test("Expect Lexer to take a string as input", lambda () {
      mixed err = catch (Lexer lexer = Lexer("key = 1"));
      expect(err)->to_equal(UNDEFINED);
      Token.Token t = lexer->lex();
      expect(t->is_key())->to_equal(true);
    });

    test("Expect lexer to return UNDEFINED at end of input", lambda () {
      Lexer lexer = Lexer("key = 2");
      Token.Token t = lexer->lex();
      expect(t->is_key())->to_equal(true);
      t = lexer->lex();
      expect(t->is_value())->to_equal(true);
      t = lexer->lex();
      expect(t)->to_equal(UNDEFINED);
    });

    test(
      "Expect lexer to strip whitespace and comments at beginning of file",
      lambda () {
        Lexer lexer = Lexer(#"
          # This is a comment

          key = 1
        ");

        expect(lexer->lex()->is_key())->to_equal(true);
        expect(lexer->lex()->is_value())->to_equal(true);
      }
    );

    test("Expect lexer to handle comment after value", lambda () {
      Lexer lexer = Lexer(#"
        key-1 = 1 # This is the first comment
                  # which continues
        key-2 = 2
      ");

      lexer->lex();
      lexer->lex();
      expect(lexer->lex()->is_key())->to_equal(true);
      expect(lexer->lex()->is_value())->to_equal(true);
    });
  });
}
