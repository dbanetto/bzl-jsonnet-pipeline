local output = import 'lib/output.libsonnet';

function(input) (
  output.renderDirectory(std.parseJson(input))
)
