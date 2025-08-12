load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_jsonnet//jsonnet:jsonnet.bzl", "jsonnet_library", "jsonnet_to_json")
load("//:pipeline.bzl", "render_directory", "render_pipeline_manifests")
load("//addons:defaults.bzl", "ADDON_DEFAUlTS")

def render_addons(name, config, applications, addons, visibility = []):
    # Folder-based Namespaces
    write_file(
        name = "{}-applications-config".format(name),
        out = "{}-applications.json".format(name),
        content = [json.encode(applications)],
        visibility = visibility,
    )

    # Template customised Addons and collect targets
    finalAddons = {}
    for addonName, addonConfig in addons.items():
        addonShortName = addonName.split("/")[-1].replace(":", "--")

        # Merge config
        mergedConfig = dict(ADDON_DEFAUlTS.get(addonName, {}).items() + addonConfig.items())
        mergedConfig["pipeline"] = ADDON_DEFAUlTS.get(addonName, {}).get("pipeline", []) + addonConfig.get("pipeline", [])
        mergedConfig["ociPath"] = addonName.lstrip("//").replace(":", "--")

        if len(mergedConfig["pipeline"]) > 0:
            render_pipeline_manifests(
                name = "{}-{}-manifests".format(name, addonShortName),
                pipeline = mergedConfig["pipeline"] + [
                    render_directory(),
                ],
                namespace = mergedConfig.get("namespace", None),
                config = config,
            )

            # manifest_container(
            #     name = "{}".format(addonShortName),
            #     label = ":{}-{}-manifests".format(name, addonShortName),
            # )

            mergedConfig["ociPath"] = "{}-{}".format(
                native.package_name().lstrip("@").split(":")[0],
                "{}".format(addonShortName),
            )
        else:
            print(addonShortName, "skipped, no pipeline defined")

        finalAddons[addonName] = mergedConfig

    write_file(
        name = "{}-addons-config".format(name),
        out = "{}-addons.json".format(name),
        content = [json.encode(finalAddons)],
        visibility = visibility,
    )

    # Namespaces
    jsonnet_to_json(
        name = "{}-namespaces-manifests".format(name),
        src = "//lib/cluster:namespaces.jsonnet",
        extra_args = ["-S"],
        out_dir = "{}-namespaces-manifests".format(name),
        tla_str_files = {
            ":{}-applications-config".format(name): "applicationsJson",
            ":{}-addons-config".format(name): "addonsJson",
        },
        deps = [
            "//lib:output",
            "//lib:patches",
        ],
    )

    # manifest_container(
    #     name = "namespaces".format(name),
    #     label = ":{}-namespaces-manifests".format(name),
    # )

    # Optionally render the FluxCD Source/Kustomize resources
    if "//addons/fluxcd" in finalAddons:
        # Flux Applications
        jsonnet_to_json(
            name = "{}-applications-manifests".format(name),
            src = "//lib/cluster:applications.jsonnet",
            extra_args = ["-S"],
            out_dir = "{}-applications-manifests".format(name),
            tla_str_files = {
                ":{}-applications-config".format(name): "applicationsJson",
                ":{}-addons-config".format(name): "addonsJson",
                "{}".format(config): "configJson",
            },
            tla_strs = {
                "namespace": finalAddons.get("//manifests/addons/fluxcd").get("namespace"),
                "basePath": native.package_name().lstrip("@//"),
            },
            deps = [
                "//lib:output",
                "//lib:patches",
                "//third_party/jsonnet/k",
                "//third_party/jsonnet/crds:flux",
                "//third_party/jsonnet/crds:external-secrets",
            ],
        )

        # manifest_container(
        #     name = "applications".format(name),
        #     label = ":{}-applications-manifests".format(name),
        # )
