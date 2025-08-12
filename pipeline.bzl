load("@jq.bzl//jq:jq.bzl", "jq")
load("@rules_helm//:helm.bzl", "helm_template")
load("@rules_jsonnet//jsonnet:jsonnet.bzl", "jsonnet_library", "jsonnet_to_json")

def render_pipeline_manifests(name, config, pipeline, namespace = None):
    pipeline = validate_pipeline(pipeline)
    _render_pipeline_manifests(name, config, pipeline, namespace)

def _render_pipeline_manifests(name, config, pipeline, namespace):
    prev = None
    for (n, stage) in enumerate(pipeline):
        stage_name = "{}-{}".format(name, n)
        if stage.get("type") == "merge_outputs":
            outputs = []

            for (m, sub_pipeline) in enumerate(stage.get("pipelines")):
                sub_name = "{}-{}".format(stage_name, m)
                _render_sub_pipeline_manifests(sub_name, config, sub_pipeline + [
                    render_file(),
                ], namespace, prev_stage_name = prev)
                outputs.append(":{}".format(sub_name))

            _manifest_merge_outputs(
                # Terminal stage uses the given name
                name = stage_name,
                inputs = outputs,
            )
        else:
            _render_pipeline_stage(name, stage_name, config, stage, namespace, prev_stage_name = prev)
        prev = stage_name

def _render_sub_pipeline_manifests(name, config, pipeline, namespace = None, prev_stage_name = None):
    prev = prev_stage_name
    for (n, stage) in enumerate(pipeline):
        stage_name = "{}-{}".format(name, n)
        _render_pipeline_stage(name, stage_name, config, stage, namespace, prev_stage_name = prev)
        prev = stage_name

def _render_pipeline_stage(name, stage_name, config, stage, namespace, prev_stage_name):
    # Inputs
    if stage.get("type") == "input_yaml":
        _manifest_yaml_file(
            name = stage_name,
            input = stage.get("file"),
        )
    elif stage.get("type") == "input_json":
        _manifest_render_file(
            name = stage_name,
            input = stage.get("file"),
        )
    elif stage.get("type") == "helm_values":
        _manifest_input_helm_file(
            name = stage_name,
            config = config,
            values = stage.get("values"),
            namespace = namespace,
            **stage.get("args")
        )
    elif stage.get("type") == "helm":  # Intermediate stages
        if prev_stage_name == None:
            fail("render_helm requires an input stage")
        _manifest_render_helm(
            name = stage_name,
            chart = stage.get("chart"),
            values = ":{}".format(prev_stage_name),
            namespace = namespace,
            **stage.get("args")
        )
    elif stage.get("type") == "patch_manifests":
        if prev_stage_name == None:
            fail("patch_manifests requires an input stage")
        _patch_manifests(
            name = stage_name,
            input = ":{}".format(prev_stage_name),
            config = config,
            patch = stage.get("patch"),
            namespace = namespace,
            **stage.get("args")
        )
    elif stage.get("type") == "render_directory":  # Terminal stages
        if prev_stage_name == None:
            fail("render_directory requires an input stage")

        _manifest_render_directory(
            # Terminal stage uses the given name
            name = name,
            input = ":{}".format(prev_stage_name),
        )
    elif stage.get("type") == "render_file":
        _manifest_render_file(
            # Terminal stage uses the given name
            name = name,
            input = ":{}".format(prev_stage_name),
        )
    elif stage.get("type") == "merge_outputs":  # Special case for merging
        fail("merge_outputs cannot be recursive")
    else:
        fail("unknown pipeline stage {}".format(stage.get("type")))

def validate_pipeline(stages = [], required_terminal = True, prev_stage = None):
    validated_stages = []

    prev_stage = prev_stage or None
    for stage in stages:
        if stage.get("type") == "merge_output":
            for sub in stage.get("pipelines"):
                validate_pipeline(sub, required_terminal = False, prev_stage = stage)

        if prev_stage == None and stage.get("requires_input", default = False) == True:
            fail("{} requires an input step".format(stage.get("name")))

        if prev_stage != None and prev_stage.get("terminal", default = False):
            fail("{} is after a terminal step".format(stage.get("name")))

        validated_stages.append(stage)
        prev_stage = stage

    if required_terminal and prev_stage != None and not prev_stage.get("terminal", default = False):
        fail("pipeline does not end with a terminal step")

    if not required_terminal and prev_stage != None and prev_stage.get("terminal", default = False):
        fail("sub-pipeline should not end with a terminal step")

    return validated_stages

def input_yaml(file):
    return {
        "type": "input_yaml",
        "file": file,
    }

def input_helm_values(values, **kwargs):
    return {
        "type": "helm_values",
        "values": values,
        "args": kwargs,
    }

def render_helm(chart, **kwargs):
    return {
        "type": "helm",
        "chart": chart,
        "args": kwargs,
        "requires_input": True,
    }

def patch_manifests(patch, **kwargs):
    return {
        "type": "patch_manifests",
        "patch": patch,
        "args": kwargs,
        "requires_input": True,
    }

def input_json(file):
    return {
        "type": "input_json",
        "file": file,
    }

def render_directory(**kwargs):
    return {
        "type": "render_directory",
        "args": kwargs,
        "requires_input": True,
        "terminal": True,
    }

def render_file(**kwargs):
    return {
        "type": "render_file",
        "args": kwargs,
        "requires_input": True,
        "terminal": True,
    }

def merge_outputs(pipelines, **kwargs):
    return {
        "type": "merge_outputs",
        "pipelines": pipelines,
        "args": kwargs,
        "terminal": False,
    }

def _manifest_yaml_file(name, input):
    jsonnet_to_json(
        name = name,
        src = "//lib/pipeline:render_helm.jsonnet",
        outs = [name + ".json"],
        tla_str_files = {
            input: "input",
        },
        deps = ["//lib:output"],
    )

def _patch_manifests(name, input, config, patch, namespace, deps = []):
    # Jsonnet rule to apply patch file
    jsonnet_to_json(
        name = name,
        src = "//lib/pipeline:patch_manifests.jsonnet",
        outs = [name + "_patched.json"],
        ext_code_file_vars = [
            "patch",
        ],
        ext_code_files = [patch],
        tla_str_files = {
            input: "input",
            config: "config",
        },
        tla_strs = {
            "namespace": namespace,
        },
        deps = [
            "//lib:output",
            "//lib:patches",
        ] + deps,
    )

def _manifest_input_helm_file(name, config, values, namespace, deps = []):
    jsonnet_to_json(
        name = name,
        src = "//lib/pipeline:render_helm_values.jsonnet",
        outs = [name + "_input_helm.json"],
        ext_code_file_vars = [
            "values",
        ],
        ext_code_files = [values],
        tla_str_files = {
            config: "config",
        },
        tla_strs = {
            "namespace": namespace,
        },
        deps = deps,
    )

def _manifest_render_helm(name, chart, values, namespace, **kwargs):
    helm_template(
        name = name + "-helm",
        chart = chart,
        values = values,
        namespace = namespace,
        **kwargs
    )

    #
    jsonnet_to_json(
        name = name,
        src = "//lib/pipeline:render_helm.jsonnet",
        outs = [name + "_helm.json"],
        tla_str_files = {
            ":" + name + "-helm": "input",
        },
        deps = ["//lib:output"],
    )

def _manifest_render_directory(name, input, **kwargs):
    jsonnet_to_json(
        name = name,
        src = "//lib/pipeline:render_directory.jsonnet",
        extra_args = ["-S"],
        out_dir = name,
        tla_str_files = {
            input: "input",
        },
        deps = ["//lib:output"],
        **kwargs
    )

def _manifest_render_file(name, input, **kwargs):
    native.alias(
        name = name,
        actual = input,
    )

def _manifest_merge_outputs(name, inputs, **kwargs):
    jq(
        name = name,
        srcs = inputs,
        out = name + "-merged.json",
        args = ["--slurp"],
        filter = "add",
    )
