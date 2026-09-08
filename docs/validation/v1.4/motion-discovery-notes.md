# Preserved motion-regression discoveries

The strict actual-scene checks were retained while the renderer was improved. These reports preserve failures; they are not the final validation result.

- `motion-before-material-coverage.json`: 32-frame, 8-SPP Bean night sequence at 960 × 600 against 128-SPP references. Image RMSE regressed from 0.036934 to 0.038095 despite reduced temporal residual. Isolated temporal/spatial experiments localized the main bias to 24 mm dark physical plaza joints whose coverage was lost from adjacent pale-center pixels. Symmetric material-boundary coverage preservation fixed the source, with an exact GPU regression.
- `motion-before-spatial-confidence.json`: the later complete Chicago 8-SPP suite passed four cases but Willis night still regressed from 0.024948 to 0.024987 image RMSE. The prior spatial confidence scale (18 samples) retained too much blur as the samples converged. The final scale of eight limits that bias. A converged low-contrast contact-shadow fixture fails with the old scale and passes with the final one; the actual image and temporal thresholds were unchanged. `motion-before-spatial-confidence-input.json` records that packaged input.
- `motion-negative-controls.json`: intentionally disabled fixes are detected by the numerical regressions. These altered shaders were temporary files, never packaged or pushed as production behavior.

Final results are in `motion-comparison.json`, `motion-chicago.json`, `motion-millennium.json` and `motion-paris.json`. Only the isolated paired comparison supplies performance claims; full-location correctness checks may run alongside movie exports. The historical version 1.3 presentation-baseline distinction remains documented separately in `../v1.3/motion-baseline-notes.md`.
