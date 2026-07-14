# CATIA (Dassault Systèmes)

**Surveyed versions:** CATIA V5-6R2026 (R36) and CATIA on 3DEXPERIENCE R2026x. Both lines are actively developed and sold; 3DEXPERIENCE ("3DX") is the strategic platform receiving most new capability, while V5 remains dominant in installed aerospace/automotive supply chains.

## Positioning

The archetypal high-end/enterprise MCAD system, competing with NX and Creo above the mid-range. De facto standard in **commercial aerospace** (Boeing standardized on CATIA/3DX; Airbus is a foundational V5 customer; Bombardier, Embraer, Dassault Aviation, Safran, and the airframe supply chain) and very strong in **automotive** (most European OEMs at least for Class-A/body engineering; VW Group is the notable NX exception). Other strongholds: shipbuilding, industrial equipment, styling-heavy consumer goods. Enterprise-scale seat counts; individual/freelance use is rare due to price and complexity.

## Architecture

- **Kernel:** **CGM (Convergence Geometric Modeler)** — Dassault's own, shared by V5 and 3DX and licensed externally via Spatial. All cross-vendor exchange is translation (no Parasolid/ACIS affinity).
- **V5 (file-based desktop):** `.CATPart` / `.CATProduct` / `.CATDrawing` / `.cgr`; workbench-based UI; optional external PDM; **no backward compatibility across releases** (a supply-chain pain point).
- **3DEXPERIENCE (database-backed):** no user-visible files — everything is a PLM entity in the platform database, edited through apps grouped into named-user roles; on-premise or DS-hosted cloud. Geometry is kernel-identical with V5; coexistence utilities move data both ways.
- The V5 → 3DX transition is the defining product-line dynamic: new capability (xGenerative Design, ICEM Design Experience, Motion Design, AI features) is 3DX-only, while aerospace program lock-in keeps V5 fully supported.

## Standout features

1. **Class-A surfacing leadership** — GSD + FreeStyle + ICEM heritage; automotive exterior surfacing is effectively a CATIA/ICEM vs. Alias duopoly. No surveyed competitor matches the surface-quality toolchain.
2. **Knowledgeware / KBE depth** — EKL language, rules/checks/reactions, Power Copies/UDFs, Product Knowledge Templates, design tables, optimization loops: the strongest platform for capturing corporate design intelligence.
3. **Multi-body Boolean part architecture** — bodies with Boolean assembly inside one part enable tooling/mold methodologies competitors handle more awkwardly.
4. **True platform concurrency (3DX)** — database-native CAD with real-time multi-user collaboration and PLM as the substrate rather than a bolt-on.
5. **Aerospace vertical depth** — aerospace sheet metal (joggles, hydro-formed flanges), industry-leading composites design (CPD), airframe fasteners, harness install: decades of Boeing/Airbus-driven functionality.
6. **Systems engineering span** — CATIA Magic (SysML/MBSE), Dymola (Modelica multiphysics), Stimulus under one brand with RFLP traceability.
7. **One-database brand ecosystem** — SIMULIA (Abaqus/Tosca/CST), DELMIA (CAM/robotics/MES), ENOVIA, 3DEXCITE share the 3DX data model: MODSIM workflows without translation.
8. **xGenerative Design** — associative visual-scripting/algorithmic modeling natively inside the CAD system (3DX only).

## Notable weaknesses

- **Price and packaging complexity**: capabilities users expect in the box (FTA/MBD, GSD surfacing, JT, feature recognition) are separately licensed; the V5 config matrix and 3DX role catalog are notoriously hard to navigate.
- **Steep learning curve; dated V5 UX**; 3DX's web-style UI drew years of complaints (now matured).
- **Weak direct/synchronous editing** vs. NX ST and Creo FMX — pieces exist (feature recognition, SubD, ICEM soft parametrics) but no unified mode.
- **No native lightweight configurations in V5** — variants need design tables or PLM effectivity.
- **No backward compatibility across V5 releases**; JT and multi-CAD readers are paid add-ons.
- 3DX migration friction: ENOVIA administration overhead; heavyweight for small suppliers; some scripting requires extra licenses.
- Windows-only clients; reseller/enterprise support model with little community-scale support.

## Licensing and pricing (2025–2026)

- **3DX:** named-user roles (subscription): CATIA Mechanical Designer ≈ **$7,560/yr**; Mechanical Essentials ≈ $7,080/yr; richer roles toward ~$15k/yr; on-prem or DS cloud. Student offer ≈ $60/yr; startup program discounts.
- **V5:** configurations + add-on products, perpetual from ≈ **$14,100 + ~$2,500/yr maintenance** (entry config) or lease from ≈ $5,600/yr; loaded seats (GSD + FTA + DMU…) commonly **$25k–65k+** perpetual; ICEM Surf and CAA/RADE premium-priced. Node-locked or floating (DSLS).
- Cadence: V5 one release/year + service packs; 3DX annual x-release + quarterly FD fix packs (cloud updated continuously).

## Ecosystem

**CAA C++ with RADE** — the deepest ISV-grade API in MCAD (the same components DS builds CATIA with); COM automation (CATScript/VBA) in V5; EKL knowledge language platform-wide; web services on 3DX. Sibling brands: SIMULIA, DELMIA (incl. Apriso MES), ENOVIA, 3DEXCITE, CATIA Composer, CATIA Magic/Dymola. Partner ISVs: Q-Checker/CENIT, ICAM/IMSpost posts, 3DCS tolerance analysis, Theorem/CoreTechnologie/Elysium translators. Major driver of STEP AP242/MBD standards and aerospace LOTAR archiving practice. Global VAR + services network with deep aerospace/automotive methodology consultancies.
