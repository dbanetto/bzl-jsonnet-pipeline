local output = import 'lib/output.libsonnet';

function(input) (
  output.renderStage(std.parseYaml(input))
)
