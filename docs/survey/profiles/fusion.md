# Autodesk Fusion (formerly Fusion 360)

**Surveyed version:** current continuous-release Fusion as of mid-2026.

## Positioning

The affordable all-in-one cloud product-development platform: CAD + CAM + CAE + PCB + PDM in a single subscription at roughly one-fifth the cost of an equivalently equipped SolidWorks or Inventor seat. Strongholds: startups, small/mid product design firms, job-shop machining, consumer hardware, education, and the maker community (free personal license). Autodesk's designated successor for EAGLE (electronics, end-of-access June 2026) and the front door to its "Design & Make" cloud. Not positioned for large enterprise machinery/automotive/aerospace — Autodesk steers those to Inventor.

## Architecture

- **Kernel:** Autodesk ShapeManager (proprietary ACIS derivative, shared with Inventor and AutoCAD); Autodesk's own variational constraint solver; T-Splines technology for the Form workspace; CAM descends from HSMWorks.
- **Data:** no user-facing native files — designs live as cloud documents in Autodesk Team hubs; `.f3d`/`.f3z` are export/archive formats only. Cloud services handle translation, rendering, generative design, and advanced sim solves; interactive modeling runs locally.
- **Platforms:** Windows and macOS desktop clients; browser for viewing/collaboration; temporary offline mode only.
- **Known constraint:** largely single-threaded kernel operations; no lightweight assembly representations.

## Standout features

1. **True single-environment CAD/CAM** — production-grade HSM machining (through simultaneous 5-axis with the Manufacturing Extension) fully associative with design; free, open, editable post-processor library.
2. **Integrated ECAD/MCAD** — schematic capture, PCB layout, SPICE, and associative 3D board-in-enclosure workflows in one product; best-in-class electromechanical co-design in its class.
3. **T-spline subdivision modeling (Form workspace)** built into a parametric modeler — organic surfacing competitors sell separately.
4. **Hybrid parametric + direct modeling** — the timeline can be disabled per document; direct edits can be captured as history features.
5. **Cloud-native data and collaboration** included: versioning, browser review/markup, share links, team hubs, zero server administration.
6. **Generative design** with manufacturing-aware constraints (milling/additive/casting) solved in the cloud.
7. **Free personal-use license** — an on-ramp no major competitor matches, producing a huge community and tutorial ecosystem.
8. **Configurations across workspaces** — variant tables flow into drawings, CAM, simulation, and rendering.

## Notable weaknesses

- **Large assemblies**: no lightweight/LOD representations; practical degradation above ~300–1,000 unique components; slow full recomputes in distributed designs.
- **Cloud dependency**: no offline/on-premises data option; outages and forced updates affect access; IP-sensitive customers object.
- **Drawings are shallower** than SolidWorks/Inventor/Creo (ASME/ISO only, less detailing depth).
- **No native weldments/frames, routing/piping/harness, or mold core-cavity tools**; no semantic MBD/PMI.
- **"Nickel-and-diming" perception**: capability moved behind extensions and token-metered cloud solves; the 2020 free-tier tightening left lasting community distrust.
- Advanced simulation is cloud-solve-only and shallower than dedicated FEA.

## Licensing and pricing (2025–2026)

- Subscription only, named user: base **$680/yr** (~$85/mo).
- Extensions: Design **$595/yr**; Simulation **$1,465/yr**; Manufacturing **$1,465/yr**; Fusion Manage (PLM) **$1,115/yr**.
- Bundles: Fusion for Manufacturing **$2,040/yr**; Fusion for Design **$2,190/yr**.
- Flex tokens meter some cloud solves and renders (linear static is token-free).
- Free tiers: Personal Use (non-commercial, 10 editable docs, reduced CAM/electronics/drawings), Education, Startup program. Signal Integrity Extension discontinued March 2026.

## Ecosystem

Desktop API in Python and C++ (full object model incl. CAM and drawings); TypeScript cloud automation API on Autodesk Platform Services; no macro recorder. Active Autodesk App Store section (frame generators, dogbone, parameter tools, gear generators). Integrations: Fusion Manage/Upchain PLM, Inventor/AutoCAD/Alias interop, McMaster-Carr insertion, open CAM post library, growing AI features (Autodesk Assistant, drawing automation). Exceptionally rich third-party tutorial/content ecosystem thanks to the education/hobbyist base.
