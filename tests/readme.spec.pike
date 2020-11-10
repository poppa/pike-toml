// https://github.com/poppa/pest
import Pest;
import Parser.TOML;

#include "helpers.h"

int main() {
  describe("Readme tests", lambda () {
    test("The readme examples should do fine", lambda () {
      mapping res = parse_file(toml_file("readme.toml"));

      expect(object_program(res["last-updated"]))->to_equal(Calendar.Second);

      m_delete(res, "last-updated");

      expect(res)->to_equal(([
        "name": "Global Server Config",
        "regex": ({
          ([ "dot": "\\." ]),
          ([ "dot": "\\.\\." ])
        }),
        "server": ([
          "dev": ([
            "host": "dev.host.com",
            "os": ([ "platform": "CentOS", "version": "6.5" ]),
            "port": 1337,
            "tls": Val.false
          ]),
          "prod": ([
            "host": "host.com",
            "os": ([ "platform": "CentOS", "version": "7.6" ]),
            "port": 80,
            "tls": Val.true
          ])
        ]),
        "support": ({ "email@support.com", "055-5555" })
      ]));
    });
  });
}
