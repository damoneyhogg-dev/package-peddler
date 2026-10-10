"""Create a disposable MPFB character and report export-critical properties."""

import bpy

from bl_ext.user_default.mpfb.services import HumanService


def main() -> None:
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

    print("PACKAGE_PEDDLER_CHARACTER_PROBE")
    print(f"vertices={len(body.data.vertices)}")
    print(f"polygons={len(body.data.polygons)}")
    print(f"bones={len(rig.data.bones)}")
    print("bone_names=" + ",".join(bone.name for bone in rig.data.bones))
    print(f"armature_modifiers={sum(1 for mod in body.modifiers if mod.type == 'ARMATURE')}")


if __name__ == "__main__":
    main()
