# Large-buffer ray tracing regression

Run `scripts/validate-large-geometry-gpu.sh` on a Metal ray tracing Mac with at
least 6 GB of available unified memory. Run it separately from rendering jobs.

The default `sparseDescriptorProbe` allocates a vertex buffer larger than 4 GiB
and obtains four descriptors from the production `GeometryPartition` helper.
It checks the full descriptor offsets and counts, then restricts each descriptor
to eight triangles while retaining its exact buffer offset. The fourth section
starts at 4.5 GiB. Shader buffers remain bound at zero, as in the renderer.

Four rays exercise geometry IDs 0–3 with local primitive IDs 0–3. A two-instance
TLAS also tests the traffic tail beyond 4 GiB. Assertions check hit distance,
global primitive ID, static/dynamic identity, vertex coordinates, material ID,
and the actual material value. Test kernels append to the production Metal
source and call its `sceneIntersection` overloads. They do not duplicate its
geometry ID normalization.

This is partial-section coverage. It does not traverse tens of millions of
triangles or every section end. Full-city Robie House day/night images and
motion captures provide separate integration checks.

Two original synthetic diagnostics remain available explicitly:

- `--legacy-sparse`: 44.7M primitives with zero-area filler. On the development
  Mac it missed all sentinels after primitive 0, even though direct GPU vertex
  reads were correct. The cause is unresolved.
- `--full-field`: 44.7M real triangles in a distributed planar field. Its AS build
  exceeded the three-minute investigation bound and the isolated process was
  terminated before any probe completed. This arrangement is unlike the actual
  city, whose corresponding build took approximately one second.

These modes retain their original sentinel and material assertions; they are
diagnostics, not passing release checks. They may take substantial GPU time.
The release investigation JSON and stderr logs preserve those failures instead
of treating the smaller probe as equivalent coverage. A monolithic negative
control is attempted only if a full-span diagnostic reaches that stage; future
driver fixes are permitted to make the negative control succeed.
