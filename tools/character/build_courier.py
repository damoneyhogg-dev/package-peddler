"""Build Package Peddler's locally-authored, open-source courier character.

The base human and game-engine rig come from MPFB.  Clothing colors and the
three locomotion clips are authored here so the project does not depend on an
account-gated animation service.
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy

from bl_ext.user_default.mpfb.services import HumanService


ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = ROOT / "assets" / "characters"
BLEND_PATH = ROOT / "tools" / "character" / "courier_source.blend"
GLB_PATH = OUTPUT_DIR / "courier.glb"


def material(name: str, color: tuple[float, float, float, float], metallic: float = 0.0) -> bpy.types.Material:
    result = bpy.data.materials.new(name)
    result.diffuse_color = color
    result.use_nodes = True
    principled = result.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Roughness"].default_value = 0.72
    principled.inputs["Metallic"].default_value = metallic
    return result


def classify_body_materials(body: bpy.types.Object) -> None:
    skin = material("Skin", (0.48, 0.25, 0.14, 1.0))
    shirt = material("CourierSafetyTop", (0.58, 0.92, 0.05, 1.0))
    pants = material("CourierPants", (0.075, 0.12, 0.18, 1.0))
    shoes = material("CourierShoes", (0.015, 0.018, 0.022, 1.0))
    for item in (skin, shirt, pants, shoes):
        body.data.materials.append(item)

    skin_bones = {"head", "neck_01", "hand_l", "hand_r"}
    shirt_bones = {
        "spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r",
        "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r",
    }
    pants_bones = {"pelvis", "thigh_l", "thigh_r", "calf_l", "calf_r"}
    shoe_bones = {"foot_l", "foot_r", "ball_l", "ball_r"}
    names = {group.index: group.name for group in body.vertex_groups}

    def score(vertex_indices: tuple[int, ...] | list[int], group_names: set[str]) -> float:
        total = 0.0
        for vertex_index in vertex_indices:
            for assignment in body.data.vertices[vertex_index].groups:
                if names.get(assignment.group) in group_names:
                    total += assignment.weight
        return total

    for polygon in body.data.polygons:
        scores = (
            score(polygon.vertices, skin_bones),
            score(polygon.vertices, shirt_bones),
            score(polygon.vertices, pants_bones),
            score(polygon.vertices, shoe_bones),
        )
        polygon.material_index = max(range(len(scores)), key=scores.__getitem__)


def make_vest(rig: bpy.types.Object) -> bpy.types.Object:
    # A lightweight, deforming low-poly vest. It is an original mesh and is
    # deliberately simple enough for the target Intel UHD 620 laptop.
    vertices = [
        (-0.28, -0.14, 1.00), (0.28, -0.14, 1.00),
        (-0.32, -0.13, 1.42), (0.32, -0.13, 1.42),
        (-0.28, 0.14, 1.00), (0.28, 0.14, 1.00),
        (-0.32, 0.13, 1.42), (0.32, 0.13, 1.42),
    ]
    faces = [
        (0, 1, 3, 2), (4, 6, 7, 5), (0, 2, 6, 4),
        (1, 5, 7, 3),
    ]
    mesh = bpy.data.meshes.new("CourierVestMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    vest = bpy.data.objects.new("CourierVest", mesh)
    bpy.context.collection.objects.link(vest)
    vest.data.materials.append(material("SafetyVest", (0.58, 0.92, 0.05, 1.0)))

    lower = vest.vertex_groups.new(name="spine_02")
    upper = vest.vertex_groups.new(name="spine_03")
    lower.add([0, 1, 4, 5], 1.0, "REPLACE")
    upper.add([2, 3, 6, 7], 1.0, "REPLACE")
    modifier = vest.modifiers.new("CourierRig", "ARMATURE")
    modifier.object = rig
    vest.parent = rig
    return vest


def reset_pose(rig: bpy.types.Object) -> None:
    for pose_bone in rig.pose.bones:
        pose_bone.rotation_mode = "XYZ"
        pose_bone.rotation_euler = (0.0, 0.0, 0.0)
        pose_bone.location = (0.0, 0.0, 0.0)
        pose_bone.scale = (1.0, 1.0, 1.0)


def create_action(
    rig: bpy.types.Object,
    name: str,
    length: int,
    poses: dict[int, dict[str, tuple[float, float, float]]],
) -> bpy.types.Action:
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    for frame, bones in poses.items():
        reset_pose(rig)
        for bone_name, angles in bones.items():
            pose_bone = rig.pose.bones.get(bone_name)
            if pose_bone is None:
                raise RuntimeError(f"Missing animation bone: {bone_name}")
            pose_bone.rotation_euler = tuple(math.radians(angle) for angle in angles)
        for pose_bone in rig.pose.bones:
            pose_bone.keyframe_insert("rotation_euler", frame=frame, group=pose_bone.name)
    # Blender 5 stores action curves in layered channel bags rather than the
    # legacy action.fcurves collection. The exporter samples these keyed poses,
    # so no version-specific curve traversal is required here.
    if tuple(action.frame_range) != (1.0, float(length)):
        raise RuntimeError(f"Unexpected frame range for {name}: {tuple(action.frame_range)}")
    return action


def create_animations(rig: bpy.types.Object) -> list[bpy.types.Action]:
    rig.animation_data_create()
    idle = create_action(
        rig,
        "Idle",
        60,
        {
            1: {"spine_02": (0, 0, -1.0), "head": (0, 0, 1.0)},
            30: {"spine_02": (1.2, 0, 1.0), "head": (-0.8, 0, -1.0)},
            60: {"spine_02": (0, 0, -1.0), "head": (0, 0, 1.0)},
        },
    )
    walk = create_action(
        rig,
        "Walk",
        32,
        {
            1: {
                "thigh_l": (-28, 0, 0), "calf_l": (12, 0, 0),
                "thigh_r": (28, 0, 0), "calf_r": (5, 0, 0),
                "upperarm_l": (24, 0, 0), "upperarm_r": (-24, 0, 0),
            },
            9: {"thigh_l": (0, 0, 0), "calf_l": (4, 0, 0), "thigh_r": (0, 0, 0), "calf_r": (22, 0, 0)},
            17: {
                "thigh_l": (28, 0, 0), "calf_l": (5, 0, 0),
                "thigh_r": (-28, 0, 0), "calf_r": (12, 0, 0),
                "upperarm_l": (-24, 0, 0), "upperarm_r": (24, 0, 0),
            },
            25: {"thigh_l": (0, 0, 0), "calf_l": (22, 0, 0), "thigh_r": (0, 0, 0), "calf_r": (4, 0, 0)},
            32: {
                "thigh_l": (-28, 0, 0), "calf_l": (12, 0, 0),
                "thigh_r": (28, 0, 0), "calf_r": (5, 0, 0),
                "upperarm_l": (24, 0, 0), "upperarm_r": (-24, 0, 0),
            },
        },
    )
    run = create_action(
        rig,
        "Run",
        20,
        {
            1: {
                "spine_01": (9, 0, 0), "thigh_l": (-48, 0, 0), "calf_l": (28, 0, 0),
                "thigh_r": (38, 0, 0), "calf_r": (12, 0, 0),
                "upperarm_l": (42, 0, 0), "upperarm_r": (-42, 0, 0),
            },
            6: {"spine_01": (8, 0, 0), "thigh_l": (0, 0, 0), "calf_l": (15, 0, 0), "thigh_r": (0, 0, 0), "calf_r": (48, 0, 0)},
            11: {
                "spine_01": (9, 0, 0), "thigh_l": (38, 0, 0), "calf_l": (12, 0, 0),
                "thigh_r": (-48, 0, 0), "calf_r": (28, 0, 0),
                "upperarm_l": (-42, 0, 0), "upperarm_r": (42, 0, 0),
            },
            16: {"spine_01": (8, 0, 0), "thigh_l": (0, 0, 0), "calf_l": (48, 0, 0), "thigh_r": (0, 0, 0), "calf_r": (15, 0, 0)},
            20: {
                "spine_01": (9, 0, 0), "thigh_l": (-48, 0, 0), "calf_l": (28, 0, 0),
                "thigh_r": (38, 0, 0), "calf_r": (12, 0, 0),
                "upperarm_l": (42, 0, 0), "upperarm_r": (-42, 0, 0),
            },
        },
    )
    rig.animation_data.action = idle
    return [idle, walk, run]


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    body = HumanService.create_human(
        mask_helpers=True,
        detailed_helpers=False,
        extra_vertex_groups=True,
        feet_on_ground=True,
        scale=0.1,
    )
    body.name = "CourierBody"
    rig = HumanService.add_builtin_rig(body, "game_engine", import_weights=True)
    rig.name = "CourierRig"

    # Remove MPFB helper geometry permanently after its official skin weights
    # have been loaded. This keeps the runtime mesh lean and avoids exporting
    # hidden authoring surfaces.
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    if body.data.shape_keys:
        bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
    if body.modifiers.get("Hide helpers"):
        bpy.ops.object.modifier_apply(modifier="Hide helpers")

    classify_body_materials(body)
    actions = create_animations(rig)

    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 60
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))

    bpy.ops.object.select_all(action="DESELECT")
    for item in (rig, body):
        item.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_frame_step=1,
        export_optimize_animation_size=True,
        export_skins=True,
        export_influence_nb=4,
        export_all_influences=False,
        export_morph=False,
        export_cameras=False,
        export_lights=False,
    )

    triangles = sum(len(polygon.vertices) - 2 for polygon in body.data.polygons)
    print("PACKAGE_PEDDLER_COURIER_BUILT")
    print(f"glb={GLB_PATH}")
    print(f"triangles={triangles}")
    print(f"bones={len(rig.data.bones)}")
    print("animations=" + ",".join(action.name for action in actions))


if __name__ == "__main__":
    main()
