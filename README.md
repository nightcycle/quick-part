# QuickPart

Strict, native Luau for rendering many visual parts through shared EditableMeshes. Compatible parts share a MeshPart; a block uses eight vertices and twelve triangles. Colour and opacity live on face-corner colour IDs, so changing one handle does not recolour its neighbours. Models use separate batches so rigid movement and uniform scaling only change the hosting MeshParts.

This follows the `local-package` template's `src` / standalone Rojo project / demo Rojo project / Rokit / Wally layout. No runtime dependencies. Prepared as `nightcycle/quick-part@0.1.0`; **not published**.

## Build and try it

```sh
rokit install
lune run scripts/check
lune run scripts/build
rojo serve demo.project.json
```

`check` runs the Lune sandbox, StyLua and Roblox strict type analysis. It caches upstream luau-lsp Roblox definitions in `.tools/`; for offline checking, pass an existing definitions file: `lune run scripts/check path/to/globalTypes.d.luau`. `build` deserializes the artifacts to verify their structure and compiles every embedded script:

- `build/quick-part-demo.rbxl`: includes a spawn point and five labeled, side-by-side comparison rows, visible before Play. Press **Play (F5)** to animate the real BaseParts/models on the left and their QuickPart versions on the right: five primitives changing properties, 100 moving cubes, a rotating/scaling 26-part arch, two birch trees with separate trunks and transparent leaf cards, and a woodland scene with a round tree, pine, bush, ferns, grass and boulder. Walk around with the avatar and normal Roblox camera; **Pause animation** lets you inspect matching poses. The right side is explicitly labeled as a BasePart preview until mesh creation succeeds; if EditableMesh is unavailable, the reference animations continue and the UI reports the failure. Use Play, not the server-only Run mode, for the client animation.
- `build/quick-part.rbxm`: standalone ModuleScript package.
- `build/quick-part-0.1.0.tar.gz`: Wally archive, containing only package sources, README, license and manifests.

Enable Mesh / Image APIs in the experience's security settings. Mesh imports also require Roblox's asset permissions. Editable assets have client memory limits and may fail to allocate. See [Roblox's EditableMesh documentation](https://create.roblox.com/docs/reference/engine/classes/EditableMesh).

The foliage comes directly from the supplied `local-package/demo/lib.rbxm`. The selected subset is checked in at `demo/assets/LibrarySamples.rbxm`, with original paths in `provenance.json`; normal builds do not need the template repository. `lune run scripts/extract-library <path-to-lib.rbxm>` refreshes it. Geometry, textures, double-sided leaf cards and SurfaceAppearance are retained; samples are anchored and positioned with a ground-level pivot. Demo assets are excluded from the Wally package.

These third-party meshes currently render as MeshParts but their EditableMesh imports are denied in the connected Studio session. Roblox requires mesh ownership or explicit sharing for editing; enabling the API alone does not grant that access. Until the assets are shared appropriately (or replaced with editable assets), the new rows show synchronized animated originals and an **Asset access denied** status. They do not claim to be QuickPart output.

## Part handles

```luau
--!strict
--!native
local QuickPart = require(game.ReplicatedStorage.Packages.QuickPart)
QuickPart.CONSTANTS.TRIANGLE_BUDGET_PERCENT = 70

local part, reason = QuickPart.Create({
    Size = Vector3.new(4, 2, 6),
    CFrame = CFrame.new(0, 10, 0),
    PivotOffset = CFrame.new(0, -1, 0),
    Material = Enum.Material.SmoothPlastic,
    Reflectance = 0,
    CastShadow = true,
    Color = Color3.fromRGB(60, 180, 255),
    Transparency = 0.2,
    -- SurfaceAppearance = anExistingSurfaceAppearance,
})
if not part then
    warn(reason)
    return
end

part.CFrame = CFrame.new(0, 15, 0)
part.Size = Vector3.new(6, 2, 6)
QuickPart.Update(part)
QuickPart.PivotTo(part, CFrame.new(0, 20, 0))
QuickPart.Remove(part)
```

A `PartHandle` has `Id: number` (monotonically increasing integer, treat as read-only), `Size`, `CFrame`, `PivotOffset`, `Color`, and `Transparency`. Mutating a table does nothing until `Update` / `UpdateMany`. Like a BasePart, its pivot is `CFrame * PivotOffset`; changing PivotOffset alone does not move geometry. `PivotTo` computes CFrame from that offset. Size must be positive and transparency in `[0, 1]`.

Prefer `CreateMany(options)` and `UpdateMany(handles)` for populations. Creation prepares all topology before yielding to attach hosts, and a failed creation rolls back the entire call. UpdateMany uses one `BatchSetValues` call per changed mesh when supported, reuses mesh buffers, and skips unchanged geometry. Older engines fall back to SetPosition. Colour-only changes do not write vertices. Concurrent creation/mutation on the same renderer is rejected while an asynchronous creation is in flight.

| API | Result / purpose |
| --- | --- |
| `Create(options)` | `PartHandle?, reason?`; default shape is Block |
| `CreateMany(optionsArray)` | `{PartHandle}?, reason?`; atomic creation |
| `FromPart(basePart)` | Imports a supported visual BasePart; leaves the source alone |
| `Update(handle)` / `UpdateMany(handles)` | Applies mutable handle properties synchronously |
| `GetPivot(handle)` / `PivotTo(handle, pivot)` | BasePart-style pivot operations |
| `Remove(handle)` / `RemoveMany(handles)` | Removes faces and unused attributes; destroys empty mesh hosts |
| `GetGeometry(handle)` | EditableMesh, host, and copies of stable vertex, face, triangle, colour and normal IDs |
| `GetStats()` | Parts, Models, Meshes, Triangles, TriangleLimit and BatchMeshes |
| `Destroy()` | Disconnects and destroys everything owned by this renderer; idempotent |
| `new()` | Independent renderer with the same API and shared CONSTANTS |

`GetGeometry` is an inspection/advanced integration escape hatch. Do not remove IDs, destroy its mesh, or edit its host's Size/CFrame behind the renderer. IDs are stable but sparse; never use an ID as an array index. Handles belong to their originating renderer and become invalid after removal or destruction.

Creation options also accept `MaterialVariant`, `Shape` (Block, Wedge, CornerWedge, Ball, Cylinder), `TextureID`, `DoubleSided`, or an explicit normalized `Geometry`. `Geometry.primitive` and `Geometry.transform` expose reusable functions. Treat cached primitive geometry as read-only. Custom geometry uses vertices in size-normalized local space and triangle/quad faces with per-corner UVs, optional normals, colours and alpha; `TriangleCount` must match the actual triangulation.

## Models and rendering root

```luau
local renderer = QuickPart.new()
local model, reason = renderer.FromModel(workspace.MyModel)
assert(model, reason)
model.WorldPivot = CFrame.new(0, 20, 0) * CFrame.Angles(0, math.pi / 2, 0)
model.Scale *= 2
renderer.UpdateModel(model)
renderer.RenderingPart.Name = "Scene visuals"
renderer.RenderingPart.CFrame = CFrame.new(50, 0, 0)
renderer.RemoveModel(model)
renderer.Destroy()
```

`FromModel` includes descendant BaseParts and captures the model's pivot and existing scale. `Scale` is absolute, matching `Model:GetScale()`; doubling it doubles the captured geometry. WorldPivot/Scale edits need `UpdateModel`. Models retain internal part records for cleanup but do not expose independently editable part handles. Their transforms cost O(material batches), with no per-vertex writes. Source models remain untouched; hide or remove them yourself after a successful import if replacing their visuals.

Each renderer exposes an invisible, anchored `RenderingPart` in Workspace. Its child MeshParts host the EditableMeshes. Changing the root CFrame applies an additional transform to all batches via a property-change connection, including models. Handle CFrame/WorldPivot values stay in the original coordinate system; rendered transforms are `RenderingPart.CFrame * handleTransform`. Renaming/reparenting the root is supported. Moving it does not rewrite every handle. Root Size is not a scale control. Call `Destroy` instead of manually destroying the root.

Batches are separated by material, material variant, reflectance, CastShadow, texture, DoubleSided, and SurfaceAppearance **instance identity**, plus capacity and model ownership. Sharing the same SurfaceAppearance instance allows batching; it is cloned onto the host. Those settings are captured at creation and are not mutable handle properties.

## Budget and fidelity

`CONSTANTS.TRIANGLE_BUDGET` defaults to 20,000 and `TRIANGLE_BUDGET_PERCENT` to 80, allowing 16,000 live triangles **per renderer**. This is an application allowance: Roblox does not expose remaining device EditableMesh memory or a conversion between triangle count and bytes. The allowance cannot guarantee allocation success. Lowering it blocks new allocations until enough geometry is removed; it does not evict existing handles. Roblox's per-mesh limits are also enforced. `Create*` / `From*` return `nil, reason` on exhaustion, unsupported sources or engine errors. Luau's null value is `nil`. See [AssetService allocation behavior](https://create.roblox.com/docs/reference/engine/classes/AssetService).

This is a visual renderer: hosts are anchored with collision, touch and query disabled, and collision geometry is not rebuilt on updates. Build client visuals locally; EditableMesh changes are not a network replication protocol. `--!native` is included, but native execution depends on the Roblox execution context.

Blocks and wedges preserve primitive shape. Balls and cylinders are tessellated approximations with smooth normals; `CURVE_SEGMENTS` controls detail for newly created handles. Static MeshParts preserve accessible geometry, normal/UV seams, vertex colours/alpha, TextureID and SurfaceAppearance. Asset decoding may yield and use temporary editable memory. Skinned meshes, CSG/UnionOperation, TrussPart, SpecialMesh and Decal/Texture children are rejected. Other descendants such as lights, particles, attachments and scripts are not imported.

Pixel-identical rendering for every Roblox BasePart is not promised: primitive texture mapping, legacy surfaces, transparency sorting, built-in material shading and engine culling can differ from individual parts. Primitive UVs cover each polygon; supply custom geometry/UVs for a specific PBR atlas. Host bounds originate at creation, so validate culling for your movement range in Studio, especially when adding geometry far outside the initial bounds. Prefer creating related populations together and spatially partition large scenes with separate renderers.

## Benchmarks

The supplied `Benchmarker (1).rbxm` was deserialized with Lune and its Runner/Template inspected as reference data. Its plugin code is not redistributed. Select one of these modules under `ReplicatedStorage.Benchmarks` in the built place and run the installed Benchmarker plugin in edit mode:

- `Independent100.bench`: 100 independently updated handles.
- `Independent1000.bench`: 1,000 independently updated handles.
- `RigidModel1000.bench`: 1,000 parts moving as one rigid model.
- `LibraryWoodland.bench`: the eight original woodland MeshParts moving as one model.
- `LibraryFoliage.bench`: those same MeshParts moving through individual handles and UpdateMany.

Both library benchmarks use one full population update per sample and import real mesh geometry before timing. Asset permission or budget failures abort setup and clean up; they are not reported as performance results. Run them once the mesh assets can be edited by the current experience/user.

Each compares direct `BasePart.CFrame`, `Workspace:BulkMoveTo(..., FireAllEvents)`, `Workspace:BulkMoveTo(..., FireCFrameChanged)` and QuickPart. Each case owns separate live Workspace fixtures, alternates targets on every invocation, and uses the same update count across all cases: eight updates per sample for 100 parts, one update per sample for 1,000 parts. This bounds repeated work under the plugin's preflight timeout without reducing the population. Target arrays are prepared outside timing; QuickPart's handle assignments and commit cost are included. Setup happens while the benchmark ModuleScript is required. The plugin starts its 40 ms preflight timer **before ParameterGenerator** and runs its yield checks **before BeforeAll**, so ParameterGenerator must do no fixture creation. AfterAll cleans up successful runs. The plugin skips AfterAll on cancellation/error: if that happens, remove `QuickPartBenchmark_*` and the matching QuickPart roots, or reopen the place before rerunning.

For a programmatic median/p90 report with guaranteed cleanup and an optional performance assertion, run in the demo's command bar:

```luau
local run = require(game.ReplicatedStorage.Benchmarks.Run)
local independent = run(1000, false) -- report only
local rigid = run(1000, true, true)  -- errors if QuickPart does not beat all baselines
```

`Run` rotates case order, discards warmup samples, and reports microseconds per update. Studio checks: `require(game.ReplicatedStorage.Checks)()`.

Run `require(game.ReplicatedStorage.FoliageChecks)()` on the server in Play for the library integration checks. The returned entries distinguish `Passed` from `Blocked` asset permissions. They check paired source geometry, rigid movement/scale, untouched sources and mesh cleanup; an unrelated import error fails the check. Lune also checks the selected library's mesh/material preservation, grounded pivots, and failed-import recovery without network access.

**Validation completed:** Lune fault-injection and geometry/lifecycle checks, strict Roblox type analysis, formatting, Rojo builds, artifact deserialization and script compilation. Studio checks verified synchronized foliage previews, failure cleanup, and benchmark execution using a temporary EditableMesh fixture. **Library performance comparisons remain blocked by asset permissions.** Lune cannot measure Roblox's EditableMesh submission, rendering or BulkMoveTo costs. Independent mesh movement requires eight vertex writes per block and may be slower than BulkMoveTo; rigid model batches are the intended strongest optimization. Plugin timings measure synchronous CPU submission, so also profile frame/render cost and memory on representative clients before choosing this over BaseParts.
