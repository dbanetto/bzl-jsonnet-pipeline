load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:subpackages.bzl", "subpackages")

def _all_namespaces():
    """
    _all_namespaces is intented to be used in the base of a cluster to create a list of all
    namespaces derived from the //manifests/cluster_name/* names
    """
    dirs = subpackages.all(fully_qualified = False)
    namespaces = {}

    for dir in dirs:
        namespaces[paths.basename(dir)] = None

    return list(namespaces.keys())

def _as_applications():
    """
    _all_namespaces is intented to be used in the base of a cluster to create a list of all
    namespaces derived from the //manifests/cluster_name/* names
    """
    dirs = subpackages.all(fully_qualified = True, allow_empty = True)
    namespaces = {}

    for dir in dirs:
        namespaces[dir] = {
            "namespace": paths.basename(dir),
            "ociPath": dir.lstrip("//"),
        }

    return namespaces

def _current_namespace():
    return native.package_name().lstrip("@").split("/")[-1]

def _set_of_namespaces(input):
    namespaces = {}

    for name in input:
        namespaces[paths.basename(name)] = None

    return list(namespaces.keys())

namespaces = struct(
    all = _all_namespaces,
    as_applications = _as_applications,
    current = _current_namespace,
    set_of_namespaces = _set_of_namespaces,
)
