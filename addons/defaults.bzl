load("//:pipeline.bzl", "input_helm_values", "patch_manifests", "render_helm")


ADDON_DEFAUlTS = {
    "cert-manager": {
        "namespace": "cert-manager",
        "pipeline": [
            input_helm_values(
                values = "//addons/cert-manager:values.libsonnet",
            ),
            render_helm(
                chart = "@io_jetstack_charts_cert_manager//:chart",
                generate_name = "",
                include_crds = True,
            ),
            patch_manifests(
                patch = "//addons/cert-manager:patches.libsonnet",
            ),
        ],
    },
}
