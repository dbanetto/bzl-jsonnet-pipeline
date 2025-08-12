function(config, namespace) (
  local libvalues = std.extVar('values');
  libvalues(std.parseJson(config), namespace)
)
