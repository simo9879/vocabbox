"""Restore missing joint transforms in the supplied npc_2 Fab GLB.

The source keeps valid inverse bind matrices but omits every joint's rest
transform. This rebuilds only the glTF node transforms; mesh buffers, skin
weights, materials, and textures are copied unchanged.
"""

import json
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1] / "vocab-box/models/market"
SOURCE = ROOT / "npc_2.glb"
OUTPUT = ROOT / "npc_2_restored.glb"


def rows(values):
    return [[values[column * 4 + row] for column in range(4)] for row in range(4)]


def columns(matrix):
    return [matrix[row][column] for column in range(4) for row in range(4)]


def multiply(left, right):
    return [[sum(left[row][part] * right[part][column] for part in range(4))
             for column in range(4)] for row in range(4)]


def inverse(matrix):
    work = [line[:] + [float(row == column) for column in range(4)]
            for row, line in enumerate(matrix)]
    for column in range(4):
        pivot = max(range(column, 4), key=lambda row: abs(work[row][column]))
        if abs(work[pivot][column]) < 1e-10:
            raise ValueError("Noninvertible joint matrix")
        work[column], work[pivot] = work[pivot], work[column]
        divisor = work[column][column]
        work[column] = [value / divisor for value in work[column]]
        for row in range(4):
            if row != column:
                factor = work[row][column]
                work[row] = [value - factor * other
                             for value, other in zip(work[row], work[column])]
    return [line[4:] for line in work]


def read_glb(path):
    data = path.read_bytes()
    magic, version, total = struct.unpack_from("<4sII", data)
    if magic != b"glTF" or version != 2 or total != len(data):
        raise ValueError("Expected a complete glTF 2 GLB")
    chunks = []
    offset = 12
    while offset < total:
        length, kind = struct.unpack_from("<II", data, offset)
        offset += 8
        chunks.append((kind, data[offset:offset + length]))
        offset += length
    return json.loads(chunks[0][1]), chunks


def restore():
    document, chunks = read_glb(SOURCE)
    binary = next(data for kind, data in chunks if kind == 0x004E4942)
    parents = {child: parent for parent, node in enumerate(document["nodes"])
               for child in node.get("children", [])}
    bind_globals = {}

    # A joint's inverse bind matrix supplies the rest transform missing from its node.
    for skin in document["skins"]:
        accessor = document["accessors"][skin["inverseBindMatrices"]]
        view = document["bufferViews"][accessor["bufferView"]]
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        stride = view.get("byteStride", 64)
        for index, node_id in enumerate(skin["joints"]):
            values = struct.unpack_from("<16f", binary, start + index * stride)
            global_rest = inverse(rows(values))
            if node_id in bind_globals:
                difference = max(abs(a - b) for left, right in zip(bind_globals[node_id], global_rest)
                                 for a, b in zip(left, right))
                if difference > 0.0001:
                    raise ValueError(f"Inconsistent bind pose for joint {node_id}")
            bind_globals[node_id] = global_rest

    for node_id, global_rest in bind_globals.items():
        parent_rest = bind_globals.get(parents.get(node_id))
        local_rest = multiply(inverse(parent_rest), global_rest) if parent_rest else global_rest
        document["nodes"][node_id]["matrix"] = columns(local_rest)

    json_bytes = json.dumps(document, separators=(",", ":")).encode("utf-8")
    json_bytes += b" " * (-len(json_bytes) % 4)
    rebuilt = [(0x4E4F534A, json_bytes)] + chunks[1:]
    total = 12 + sum(8 + len(data) for _, data in rebuilt)
    result = bytearray(struct.pack("<4sII", b"glTF", 2, total))
    for kind, data in rebuilt:
        result.extend(struct.pack("<II", len(data), kind))
        result.extend(data)
    OUTPUT.write_bytes(result)
    print(f"Restored {len(bind_globals)} joint transforms in {OUTPUT}")


if __name__ == "__main__":
    restore()
