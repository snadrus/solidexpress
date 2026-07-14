# Onshape (PTC)

**Surveyed version:** current SaaS release as of mid-2026 (updates ship every ~3 weeks).

## Positioning

The only fully cloud-native professional parametric MCAD system. Founded 2012 by the SolidWorks founders (Hirschtick, McEleney, Corcoran); acquired by PTC in 2019 for ~$470M. Targets agile product-development teams, hardware startups, consumer products, machinery, and robotics — teams that value collaboration over specialized depth — plus a dominant education presence (free EDU plan, FIRST Robotics). Competes most directly with SolidWorks and Fusion.

## Architecture

- **Kernel/solver:** Parasolid and D-Cubed DCM (licensed from Siemens), running on cloud geometry servers; the browser client renders tessellations via WebGL.
- **Data model:** no files. All data lives in a replicated cloud database as append-only increments ("microversions"), explicitly Git-inspired. No save button; versions are tags in history; branching/merging is native. Documents contain typed elements (Part Studios, Assemblies, Drawings, Feature Studios, app elements).
- **Platform:** multitenant SaaS on AWS; the foundation of PTC's broader Atlas infrastructure. Full clients in any WebGL browser (Windows/macOS/Linux/ChromeOS), native iOS/Android editing apps, and an Apple Vision Pro app.
- **Known constraint:** no offline editing whatsoever.

## Standout features

1. **Real-time multi-user editing** — simultaneous editing of the same model with live presence, Google-Docs style; eliminates PDM check-out bottlenecks.
2. **Built-in version control with branching/merging** — Git-style workflows for mechanical design; no separate PDM product to buy or administer.
3. **FeatureScript** — an open language in which all native Onshape features are written; users author first-class custom features (unique among mainstream MCAD), with a large community library.
4. **Part Studios + mate connectors** — multi-part single-history modeling for top-down design; one DOF-typed mate per connection drastically cuts constraint counts.
5. **Zero-install SaaS** — full CAD on any OS/browser, real editing on mobile, updates every 3 weeks with no migrations, cloud translation included in all plans.
6. **Managed in-context design** — snapshot-based contexts give predictable top-down updates with no silently broken references.
7. **Cloud-native MBD (2025–26)** — semantic PMI with inspection tables and STEP AP242 PMI export.
8. **Simultaneous sheet metal** — folded model, flat pattern, and bend table live side by side.

## Notable weaknesses

- **Hard internet dependency** — disqualifying for air-gapped/classified/poor-connectivity environments; cloud-only storage raises data-sovereignty concerns (no on-prem option).
- **Large-assembly performance** trails high-end desktop CAD despite culling/rigid-subassembly tooling; latency-sensitive.
- **Surfacing depth** improving (G3 analysis, reflection analysis in 2026) but behind SolidWorks/Creo; **no SubD/freeform modeling**.
- **Simulation and CAM are young**: native linear static + modal only; no thermal/CFD/nonlinear without partner apps (SimScale); CAM Studio is new.
- **Drawings**: single-editor-at-a-time limitation; slower updates on large drawing sets.
- No dedicated routing/piping/harness modules, no mold tools; smaller plugin ecosystem than SolidWorks; free-plan documents are public; subscription-only.

## Licensing and pricing (2025–2026)

- **Free**: $0, non-commercial, documents public.
- **Standard**: **$1,500/user/yr** — private documents, built-in PDM basics.
- **Professional**: **$2,500/user/yr** — adds company-owned data, release management, **Simulation, Render Studio, CAM Studio, PCB Studio/Altium Connector**, custom properties, unlimited viewer licenses.
- **Enterprise**: custom — custom workflows, analytics, **Arena PLM connection**, SSO, audit trails, guest licensing, higher API limits.
- Free Education plan; Discovery Program (up to 6 months free Professional); AWS Marketplace availability.

## Ecosystem

Comprehensive REST API (documents, programmatic feature creation, server-side FeatureScript evaluation, translations, releases, webhooks, OAuth). App Store with embedded third-party apps (SimScale FEA/CFD, CAM tools like Kiri:Moto, rendering, costing, ERP/PLM connectors). First-party integrations: Altium Connector, Arena PLM (Enterprise), Slack (2026), URDF export for robotics. The community FeatureScript library is a de facto extension ecosystem of its own.
