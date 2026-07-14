# Autodesk Inventor (Inventor Professional)

**Surveyed version:** Inventor 2026. Autodesk now sells a single SKU delivered as Inventor Professional; the key tiering question is Inventor alone vs. the Product Design & Manufacturing Collection (PDMC).

## Positioning

Mid-range mainstream parametric MCAD, the direct head-to-head competitor of SolidWorks and Solid Edge. Core users: machinery builders, industrial equipment, factory automation, sheet-metal fabrication, and shops embedded in the AutoCAD/DWG ecosystem — the AutoCAD-to-Inventor upgrade path has been its growth engine. Strong in engineer-to-order businesses thanks to iLogic. Autodesk's strategic energy is visibly shifting to Fusion; Inventor remains the established professional desktop tool with meaningful annual releases (140+ enhancements in 2026), but new-frontier capability lands in Fusion first.

## Architecture

- **Kernel:** ShapeManager, Autodesk's proprietary ACIS fork (also under AutoCAD 3D and Fusion) — Autodesk controls its own kernel, unlike SolidWorks.
- **Native formats:** IPT (part), IAM (assembly), IDW/**DWG** (drawing — Inventor authors real AutoCAD-compatible DWG directly), IPN (presentation), IDE (iFeature).
- **Deployment:** classic single-desktop, file-based, Windows-only. Large-assembly mitigation via Express mode (cached graphics), Model States, and Simplify/shrinkwrap. Cloud touchpoints (Shared Views, Docs/Drive, Design Automation API, Informed Design) are bolt-ons.
- **Known constraint:** partial multithreading; single-threaded regeneration like all history CAD.

## Standout features

1. **AnyCAD associative multi-CAD referencing** — live, update-propagating references to SolidWorks/CATIA/NX/Creo/Solid Edge/Fusion/Revit/STEP without translation freezing; best-in-class among mid-range CAD, including forward version interop.
2. **iLogic** — embedded VB.NET rules engine; arguably the strongest mainstream CAD for design automation/configurators without a separate automation product.
3. **Native DWG drawings** — unmatched for DWG-centric supply chains.
4. **Frame Generator + Design Accelerators** — structural frame design plus calculation-driven machine-element generators (gears, shafts, bolted joints, cams, springs) included free.
5. **Collection economics** — PDMC (~$3,375/yr) bundles Inventor, AutoCAD (all toolsets), Fusion, Inventor CAM Ultimate (5-axis), Inventor Nastran (nonlinear FEA), Nesting, Tolerance Analysis, HSMWorks, Navisworks, 3ds Max, Vault Basic — dramatically undercutting equivalent SolidWorks stacks.
6. **MBD with Tolerance Advisor** — semantic GD&T authoring with active validation and AP242 semantic PMI export, in the base product (SolidWorks charges for MBD).
7. **Revit/BIM content authoring** — purpose-built lane for equipment manufacturers serving construction.
8. **Design Automation API (Autodesk Platform Services)** — headless cloud Inventor for web configurators.

## Notable weaknesses

- Windows-only; no cloud/browser Inventor.
- Surfacing and Class-A weaker than Creo/NX/Alias and generally behind SolidWorks; Freeform (T-spline) tools basic.
- Built-in simulation dated (years of stagnant investment); advanced FEA needs Inventor Nastran via PDMC; Autodesk CFD discontinued outright.
- Mold Design module deprecated/removed (Fusion is the successor).
- Direct editing is a history-recorded overlay, not true synchronous technology.
- Subscription-only with steady 5–8%/yr price increases; smaller add-in ecosystem than SolidWorks in some niches.

## Licensing and pricing (2025–2026)

- Named-user subscription only: **~$305–310/mo, ~$2,440–2,625/yr**, ~$7,320–7,505/3-yr.
- **PDMC: ~$3,375/yr** — only ~$750–900 more than Inventor alone, so most buyers take the Collection.
- Flex tokens (~24 tokens/day for Inventor) for occasional users; free education licenses.

## Ecosystem

Full COM + VBA + .NET APIs with add-in SDK; iLogic in-document automation; Autodesk App Store; APS Design Automation (cloud headless). First-party integrations: AutoCAD (incl. Electrical electromechanical link), Fusion (AnyCAD referencing, CAM/generative escalation), Vault Basic included → Vault Professional (paid PDM), Fusion Manage (cloud PLM), Docs/Drive/Shared Views, Revit/Navisworks (BIM), Factory Design Utilities. Content Center supplies standards components; Informed Design exposes models as configurable products to non-CAD users.
