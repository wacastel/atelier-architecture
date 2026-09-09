# Performance investigation

The temporal history cap is **not the major cause** of the observed slowdown.
Two copied apps kept the final executable, full Chicago scene, renderer shader
and geometry partitions identical. Only the uncapped copy's bundled
`Denoise.metal` was replaced with the preceding version. Production source and
the production app were not modified by this experiment.

All four jobs ran serially on the M3 Ultra at 640×400, 16 frames, 8 samples per
frame and 64-sample independent references. The Mac remained locked.

| Case | Cap GPU ms | No-cap GPU ms | Result |
|---|---:|---:|---|
| Field hall | 135.207 | 134.444 | 0.57% difference |
| Hyde Park flight | 47.239 | 48.858 | Cap is 3.31% faster |

These are paired validation command times, including tracing, reconstruction
and both presentations. They are not normal preview frame rates. The short
sequence isolates this performance question; the longer release captures remain
the quality checks.

The uncapped flight's exit code **1** is preserved. Its image RMSE worsened by
1.04% relative to raw output, although temporal residual improved by 5.16%.
The capped flight improved both measures. This expected ablation failure is not
a failed release validation.

The earlier faster Robie package and the final package have the same
`Renderer.metal` SHA256, `223e94e5338fd7906e649ef62537de182235ac544c7138f7c19212103a4987df`,
and the same geometry-partition helper. The three `ulong` vertex addressing
sites and descriptor partitioning were already present in that faster run, so
they cannot alone explain the later change. The older Field comparison also
changes the city geometry and does not isolate one renderer change.

Initial pipeline and acceleration-structure setup took 25–38 seconds during
these copied-app tests, compared with roughly 1–2 seconds in earlier logs. A
process sample caught a wait for an acceleration-structure build before any
temporal frame ran. Device scheduling, idle state or App Nap remains a hypothesis;
the cause is not established. The final no-cap flight may overlap a root-owned
CPU build, so its wall time is not a clean performance comparison.

A subsequent scoped `ProcessInfo.beginActivity(.userInitiated)` during
command-line work **did not remove the measured slowdown**. With the accepted
cap and the same Field benchmark parameters, paired GPU time was **145.478 ms**,
initial pipeline/AS setup was **24.20 seconds**, and wall time was **91.31 seconds**.
The run passed its image and temporal-quality checks. Its final executable is
`fce35def02427bfbf19582dcae6aa1103f1bed7bc4a6d882e6bdf38e6496f7de`;
renderer/model resources remain unchanged according to the
[production input equivalence audit](../production-input-equivalence.json).

The bounded investigation ends with the timing cause unresolved. Neither this
result nor the earlier A/B establishes a device, lock-state, scheduling or driver
cause. No native preview FPS claim follows from these paired validation times.

[Inputs](inputs.json), [complete results](results.json), and
[source investigation](investigation.json) preserve the commands, hashes and
limits. [Artifact index](artifact-index.json) verifies the copied logs and
per-case metrics. No failures or timing outliers were removed.

[Activity run](activity-field-run.json), [activity log](activity-field.log),
[activity metrics](activity-field/metrics.json), and [closed conclusion](conclusion.json)
preserve the final experiment and its limits.
