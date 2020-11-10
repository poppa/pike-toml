#charset utf-8
#pike __REAL_VERSION__

//! Parse a TOML file.
//!
//! @param file
//!  @[file] can be a path to a file or a @code{Stdio.File@} object
public mapping parse_file(Stdio.File|string file) {
  return .Parser()->parse_file(file);
}

//! Parse a string containing TOML data
public mapping parse_string(string toml_data) {
  return .Parser()->parse_string(toml_data);
}
