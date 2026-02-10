# IsoCity iOS Performance Profiling Plan

## Goal
Produce a bottleneck report for the current iOS `WKWebView` build (bundle-only, localhost server) so we can decide whether:
- targeted web/runtime optimizations are enough, or
- a native rewrite (Unity/SpriteKit/Metal) is justified.

This plan is designed to answer, with evidence:
- CPU-bound vs GPU-bound vs memory/GC/asset-decode bound
- how performance scales with city size
- whether a rewrite would yield meaningful gains

## Benchmark Target
- Environment: physical iPhone (device profiling only; Simulator is not a reliable perf signal)
- Scenario: **large city stress** using one canonical saved state

## Keep Runs Comparable
1. Pick one "Large City" save as the canonical benchmark input.
2. Define a deterministic 2-3 minute benchmark script (human checklist):
- cold launch to first interactive frame
- pan continuously for 15s
- zoom in/out 10 cycles
- place 50 buildings quickly
- open/close key panels 10 times
- run at fastest sim speed for 30s
3. Run with:
- same device + iOS version
- Low Power Mode OFF
- Airplane Mode ON
- Release build preferred (or "debuggable but optimized" if needed for tooling)

## Determine Renderer Path (Canvas2D vs WebGL)
We need to confirm whether rendering is:
- Canvas 2D (`canvas.getContext('2d')`), or
- WebGL (`getContext('webgl'|'webgl2')`)

Do both:
- Code check: search for `getContext('2d')` vs `getContext('webgl')`.
- Runtime check: Safari Web Inspector console: inspect the main canvas context type.

## Primary Tooling (On Device)

### A) Xcode Instruments (native-side truth)
Run while executing the benchmark script:
1. Time Profiler
- Identify where CPU time goes: WebKit, JS execution, compositing, native host, local server.
2. Animation Hitches / Core Animation (whichever is available in this Xcode)
- Quantify stutters and frame-time spikes.
3. Allocations + VM Tracker
- Peak memory, allocation spikes, leak-like growth, jetsam risk.
4. Energy Log
- Thermal/battery cost under stress.

Optional (if WebGL suspected):
- GPU/Metal system trace (device-dependent) to prove GPU-bound vs CPU-bound.

### B) Safari Web Inspector (web-side truth)
Attach the device and profile the WebView:
1. Performance/Timelines
- Long tasks, compositing, layout/style work, raster cost, frame pacing.
2. JavaScript Profiler
- Top JS hotspots: simulation tick, render loop, input handlers.
3. Memory (if available)
- Heap trends and suspicious growth.

## In-App Perf Telemetry (quick feedback without tools)
Add minimal, low-overhead instrumentation displayed in the native debug overlay:
- FPS + frame time percentiles (p50/p95/p99)
- per-frame simulation tick time and render time (`performance.now()`)
- dropped/slow frames count (e.g. >32ms, >50ms)
- aggregate asset decode errors/warnings (avoid log spam)

This is for iteration speed; Instruments + Web Inspector remain source-of-truth.

## Outputs (Decision-Ready Deliverables)
After 2-3 runs:
1. Bottleneck table:
- Startup: time to first frame, time to interactive
- Steady-state: FPS distribution, hitch rate
- CPU: top 5 hotspots (native + JS)
- GPU/compositing: evidence of GPU bound or raster bound
- Memory: peak + trend (stable vs growing)
2. Ranked action list:
- 3 concrete optimization options for current runtime with rough effort/impact
3. Rewrite rubric:
- If dominated by JS simulation scaling with city size: consider moving sim native (or WASM/worker) before "full rewrite".
- If dominated by Canvas2D draw-call churn: renderer refactor (chunking/batching/offscreen) likely beats rewriting everything.
- If dominated by WebKit compositing/texture upload/asset decode: fix asset formats/loading first; rewrite is not guaranteed to help.

## Acceptance Criteria
- We can confidently state CPU-bound vs GPU-bound vs memory-bound with evidence.
- We can estimate likely payoff of targeted optimization vs rewrite.
- We have a go/no-go recommendation for a rewrite, and if "go", a justified engine choice direction.
