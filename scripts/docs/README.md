# City building guide generation

`docs/CITY-BUILDING-GUIDE.md` is the common content source. These helpers generate `docs/city-building-guide.html` and `docs/City-Building-Guide.pdf`, then check content parity, contents anchors, PDF outlines, page bounds and example-command syntax. They do not build or render the application.

Use Python with `reportlab`, `pypdf` and `pdfplumber`. The guide was generated with the Codex bundled runtime; exact package versions and font hashes are recorded in the review proof. The builder discovers its repository root from its own path and accepts `--font-dir`. That directory must contain `Ubuntu-R.ttf`, `Ubuntu-B.ttf`, `Ubuntu-RI.ttf`, `Ubuntu-BI.ttf` and `UbuntuMono-R.ttf`. Fonts are read from an installed runtime or font package and are not separately redistributed here. The default looks under the current user's Codex runtime cache.

```sh
python3 scripts/docs/build-city-building-guide.py --font-dir /path/to/fonts
python3 scripts/docs/verify-city-building-guide.py
pdftoppm -r 120 -png docs/City-Building-Guide.pdf \
  output/city-building-guide-review/page
```

Run these commands with the appropriate Python/Poppler executables from your environment. The code blocks in the guide are syntax-checked, not executed by the verifier. The HTML embeds CSS and uses system fonts; its body needs no network access. External reference links point to the current project documentation or original sources.

The PDF uses embedded fonts and deterministic PDF metadata. The same Markdown, helper version, dependencies and fonts should reproduce the same outputs; the build report records artifact and font hashes. Intermediate reports and page PNGs stay under ignored `output/city-building-guide-review/`.

After any meaningful content or layout change, render the PDF and visually inspect every page. The structural verifier cannot establish visual quality, source accuracy or application behavior. Record the inspected final PDF hash and page-image hashes in the review proof. `<!-- page -->` deliberately separates the printable chapters, and `<a id="...">` defines the linked contents targets.
