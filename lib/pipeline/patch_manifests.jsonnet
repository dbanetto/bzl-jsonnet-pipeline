local output = import 'lib/output.libsonnet';
local patches = import 'lib/patches.libsonnet';

function(namespace, input, config) (
  local libpatch = std.extVar('patch');
  local patchset = libpatch(std.parseJson(config), namespace);
  output.addon(
    std.parseJson(input) + {
      addtions: std.get(patchset, 'additions', default={}),
    },
    patches=std.get(patchset, 'patches', default=[]),
    namespace=namespace,
  )
)
