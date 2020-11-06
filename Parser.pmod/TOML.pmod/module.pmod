
#ifdef WITH_MODULE_ROOT

public mapping parse_file(Stdio.File|string file) {
  return .Parser()->parse_file(file);
}

public mapping parse_string(string toml_data) {
  return .Parser()->parse_string(toml_data);
}

#endif
