#ifndef HELPERS_H
#define HELPERS_H

string toml_file(string name) {
  return combine_path(__DIR__, ".tomls", name);
}

#endif
