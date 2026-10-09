# Moyue renderer patch

Vendored from the application's installed `liquid_glass_widgets` 0.29.7.
The original license, renderer attribution and shaders are retained. Shader
sources, pixel ratio, blur, refraction, chromatic aberration and interaction
parameters are unchanged. This is not a standard-quality fallback.

Local changes:

- `GeometryRasterCache`: compare geometry identities, ordered local transforms,
  local bounds and DPR before rasterizing the combined geometry texture.
- `LiquidGlassRenderObject`: reuse unchanged geometry across repeated layouts
  and ancestor movement. Background refraction is still painted live; this
  cache never stores the page background. Changed size/shape/transform/DPR
  invalidates the cache, including subpixel changes.
- `GeometryRenderLink`: removal marks geometry dirty, so a removed shape cannot
  remain in the cached matte.

Regression coverage lives in the application's `test/glass_rendering_performance_test.dart`.
When upgrading the dependency, review/reapply these fixes rather than replacing
the directory without testing. The root analyzer excludes unmodified dependency
sources; application compilation and the targeted tests still compile this code.
