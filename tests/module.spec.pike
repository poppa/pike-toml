// https://github.com/poppa/pest
import Pest;
import Parser.TOML;

int main() {
  describe("Parser tests", lambda () {
    test("TOML.parse_file() should handle a Stdio.File object", lambda () {
      Stdio.File f = Stdio.File(combine_path(__DIR__, "simple.toml"), "r");
      mapping res = parse_file(f);
      expect(res["string-key"])->to_equal("string");
    });

    test("TOML.parse_file() should handle a path to a file", lambda () {
      mapping res = parse_file(combine_path(__DIR__, "simple.toml"));
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
