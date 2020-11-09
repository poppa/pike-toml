// https://github.com/poppa/pest
import Pest;
import Parser.TOML;

#include "helpers.h"

int main() {
  describe("Readme tests", lambda () {
    test("The readme examples should do file", lambda () {
      mapping res = parse_file(toml_file("readme.toml"));
      werror("Res: %O\n", res);
    });
  });
}
