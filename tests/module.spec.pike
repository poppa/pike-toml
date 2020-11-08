// https://github.com/poppa/pest
import Pest;
import Parser.TOML;

#include "helpers.h"

int main() {
  describe("Root module tests", lambda () {
    test("TOML.parse_file() should handle a Stdio.File object", lambda () {
      Stdio.File f = Stdio.File(toml_file("simple.toml"), "r");
      mapping res = parse_file(f);
      expect(res["string-key"])->to_equal("string");
    });

    test("TOML.parse_file() should handle a path to a file", lambda () {
      mapping res = parse_file(toml_file("simple.toml"));
      expect(res["string-key"])->to_equal("string");
    });

    test(
      "TOML.parse_string() should handle a string with TOML data",
      lambda () {
        mapping res = parse_string("key=1");
        expect(res->key)->to_equal(1);
      }
    );
  });
}
