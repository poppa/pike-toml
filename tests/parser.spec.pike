// https://github.com/poppa/pest
import Pest;
import TOML;

int main() {
  describe("Parser tests", lambda () {
    test(
      "Parser->parse_file() should handle Stdio.File objects as argument",
      lambda () {
        Parser p = Parser();
        mapping res = p->parse_file(
          Stdio.File(combine_path(__DIR__, "simple.toml"))
        );

        expect(res["string-key"])->to_equal("string");
      }
    );

    // test(
    //   "Parser->parse_file() should handle path to a file as argument",
    //   lambda () {
    //     Parser p = Parser();
    //     mapping res = p->parse_file(combine_path(__DIR__, "simple.toml"));
    //     expect(res["string-key"])->to_equal("string");
    //   }
    // );

    test(
      "Parser->parse_string() should parse the string given as argument",
      lambda () {
        Parser p = Parser();
        mapping res = p->parse_string("key = 1");
        expect(res->key)->to_equal(1);
      }
    );
  });
}
