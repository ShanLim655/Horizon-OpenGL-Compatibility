# Horizon OpenGL 4.0 Compatibility Plan

## Goal

Make the renderer usable on legacy OpenGL 4.0 hardware, using the Intel HD Graphics 2500 and its Windows driver as the primary compatibility target. Preserve rendering behavior and keep Vulkan, DirectX 12, and newer OpenGL paths working.

## Baseline

- Upstream: https://github.com/gerdaroot/Horizon-Offline-Launcher
- Fork: https://github.com/ShanLim655/Horizon-OpenGL-Compatibility
- Base commit: `6f3d7b2e84989edff1c2d47ee9777c5e265e6097`
- Crash build: Horizon Nightly 2026-11-01, commit `6f3d7b2`
- Renderer crate: `crates/horizon-client-render`
- Workspace edition: Rust 2024
- License: MIT; retain all upstream notices and attribution.

## Confirmed root cause

The crash occurs when wgpu creates the `Terrain solid` render pipeline on the Intel HD 2500 OpenGL adapter. The generated GLSL requests `ARB_arrays_of_arrays`, which the driver's OpenGL 4.0 implementation does not support. The subsequent GLSL identifier and conversion errors are cascading failures.

Both `terrain.wgsl` and `entity.wgsl` declared `colored_lights: array<array<vec4<f32>, 2>, 16>` and read each record with two-dimensional indexing. The Rust-side representation is `[dynamic_light::Colored; dynamic_light::MAX]`, where `Colored = [[f32; 4]; 2]` and `MAX = 16`. The upload contains 16 records with two consecutive vec4 values each.

## Primary fix

Flatten the WGSL uniform member in both shaders to:

```wgsl
colored_lights: array<vec4<f32>, 32>,
```

For each light index `i`, load the same two values from:

```wgsl
let at = globals.colored_lights[i * 2u];
let color = globals.colored_lights[i * 2u + 1u];
```

Keep the Rust data representation unchanged. Verify uniform offsets, alignment, size, and upload order rather than relying on visual similarity. The flat array represents the same 32 consecutive vec4 values and removes the nested array type from the generated GLSL.

## Portability audit

The renderer crate contains 25 WGSL files. The complete renderer shader-source audit found nested arrays only in `gfx/frame_gen/optical_flow.wgsl`; the other renderer WGSL files, including the affected graphics shaders, do not declare nested arrays.

The optical-flow WGSL contains nested workgroup-array constructs. Its Rust module is declared `#[allow(dead_code)]`, and no runtime call site or active pipeline path was found, so it is not currently compiled into an OpenGL pipeline. Keep it unchanged for this fix; if frame generation is activated later, it needs its own backend-compatibility work.

Continue to audit other GLSL portability requirements separately. Do not change unrelated shaders blindly or silently remove renderer features. Where a feature is not supported by the legacy backend, provide an explicit capability check and safe fallback.

## Implementation scope

1. Flatten the colored-light WGSL uniform in terrain and entity shaders.
2. Update both shader accessors to use the flat index mapping.
3. Verify the Rust/WGSL uniform memory layout and add focused regression coverage.
4. Use existing shader parsing and validation tests to cover terrain and entity modules.
5. Add a real wgpu OpenGL pipeline-creation regression test for the affected terrain pipeline, with entity coverage where feasible.
6. Address any other OpenGL 4.0-incompatible shader constructs that can reach the GL backend.
7. Improve shader compilation diagnostics only where needed to make backend, adapter, shader label/stage, and source context actionable.
8. Preserve backend selection defaults and all modern backend behavior.

This is a renderer-portability change. Do not rewrite launcher, gameplay, world, networking, or unrelated systems.

## Validation

Required checks:

- `cargo fmt --all -- --check`
- `cargo check --workspace`
- `cargo test -p horizon-client-render`
- Focused tests for the 16 colored-light records and their exact two-vector ordering.
- WGSL parse/validation tests for terrain and entity shaders.
- A real wgpu OpenGL pipeline-creation test for the affected shader path.

Compatibility targets:

- OpenGL 4.0, especially Intel HD Graphics 2500 on the available Windows driver.
- A newer OpenGL implementation.
- Vulkan.
- DirectX 12 where supported.

Functional acceptance:

- The title screen opens without the `Terrain solid` pipeline validation panic.
- A world loads and terrain renders.
- Entity rendering and colored dynamic lights retain their expected behavior.
- Texture arrays, lightmaps, fog, HDR, resource packs, and shader-pack behavior do not regress.
- No unsupported backend is forced and no software fallback is misreported as hardware support.

A software OpenGL CI runner is useful but does not replace testing on the actual Intel driver. The final acceptance test must be run on the target HD 2500 machine.

## Backend notes

The code already supports `HORIZON_GRAPHICS_API=auto|vulkan|dx12|opengl`; wgpu backend selection can also be affected by `WGPU_BACKEND`. These variables select an API. They cannot add a missing GLSL extension or lower the generated shader requirements. The crash already identifies the OpenGL adapter, so forcing OpenGL is not a solution. Vulkan or DX12 overrides are useful only if the installed driver exposes a working implementation.

No source evidence currently identifies a Minecraft/JVM argument that disables nested-array GLSL generation or changes the GLSL target.

## Workflow

- Work on `fix/opengl-40-shader-portability`, based on the exact upstream crash commit.
- Keep the upstream repository and MIT notices intact.
- Make coherent commits rather than many tiny commits.
- Run the relevant renderer tests and repository self-check before proposing a pull request.
- The fork currently has GitHub Issues disabled, so the upstream issue-claim workflow cannot be used in this fork. Check for duplicate open PRs before opening any PR.
