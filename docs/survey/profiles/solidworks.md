# SolidWorks (Dassault Systèmes)

**Surveyed version:** SOLIDWORKS 2026 (desktop), including the 2026-generation cloud-connected subscription offers.

## Positioning

The highest-installed-base professional mid-range parametric MCAD system (roughly 7–8 million cumulative users claimed; 30th anniversary in 2025). Core market: SMB and departmental mechanical engineering — industrial machinery, consumer products, medical devices, automation/robotics, tooling, and job shops. Sits between entry tools (Fusion, Onshape) and high-end PLM-integrated systems (CATIA, NX, Creo). Its enormous trained-user pool — it is the de facto standard in engineering education — is itself a major purchasing driver.

## Architecture

- **Kernel:** Parasolid, licensed from Siemens (a long-noted irony: Siemens owns competitors NX and Solid Edge), with Siemens D-Cubed DCM constraint solvers.
- **Native formats:** `.sldprt` (part), `.sldasm` (assembly), `.slddrw` (drawing).
- **Deployment:** Pure Windows desktop application (Windows 11 only as of the 2026 release). The 2026-era strategy wraps it in the 3DEXPERIENCE cloud for licensing, data services, AI features, and ~10-week functional updates, while modeling runs locally. Dassault's fully cloud-native offerings (xDesign, xShape) are separate products.
- **Known constraint:** single-threaded feature-tree rebuild limits very large model performance.

## Standout features

1. **Ease of use** — consistently rated the most approachable full-power parametric MCAD, with an unmatched tutorial/community ecosystem.
2. **3D Interconnect** — opens native CATIA/NX/Creo/Inventor/Solid Edge/JT files with a live update link rather than dead translation (CATIA V5 requires Premium).
3. **Breadth in one box** — sheet metal, weldments, mold tools, surfacing, basic FEA, bundled 2.5-axis CAM, and rendering inside or alongside the CAD seat at every tier.
4. **Toolbox + Smart Fasteners** — standards hardware that auto-populates holes; 2026 adds AI fastener recognition and auto-mating.
5. **Largest partner marketplace in MCAD** — Gold/Solution Partner add-ins: CAMWorks, DriveWorks, SigmaNEST, Power Surfacing, KeyShot, and hundreds more.
6. **Tiered in-CAD simulation lineage** — SimulationXpress through nonlinear/dynamics/composites, CFD (Flow Simulation), and Plastics without leaving the UI.
7. **eDrawings** — the ubiquitous free lightweight viewer that lubricates supply-chain communication.
8. **2026 AI push** — auto-generated drawings, "What's Wrong" feature-failure diagnosis, prompt-based assembly structure generation (mostly Beta, but ahead of desktop rivals).

## Notable weaknesses

- Windows-only; no native Mac/Linux/web version of the real product.
- Large-assembly and multicore performance lag high-end systems; 10k+ component assemblies require discipline (SpeedPak, lightweight, 2026 Selective Loading).
- No true synchronous/history-free mode and no native SubD modeling (gaps vs. NX, Fusion, Creo; xShape fills SubD on the cloud platform).
- Surfacing is capable but not Class-A.
- Community friction over the push from perpetual licenses toward 3DEXPERIENCE-connected subscriptions.
- File-based data model makes multi-user concurrency clunky without PDM; stability complaints persist among heavy users.
- Generative design and advanced multiphysics require leaving the desktop product for 3DEXPERIENCE roles.

## Licensing and pricing (2025–2026)

- Subscription offers (named user, includes cloud services, CAM, support): Standard **$2,820/yr**, Professional **$3,456/yr**, Premium **$4,716/yr** (quarterly from $846).
- Perpetual via resellers: ~**$4,195 / $5,765 / $8,395** + ~$1.3–2k/yr maintenance; floating licenses at a premium.
- Add-on ballparks (perpetual list): Simulation Standard ~$4k, Professional ~$8k, Premium ~$12k; Flow Simulation ~$12k; MBD ~$2k; PDM Professional, CAM Professional, Electrical, Plastics, Inspection each separately priced.
- **Makers edition** ~$48/yr non-commercial; free/cheap education licensing; startup program.

## Ecosystem

Mature COM API (VBA/C#/VB.NET/C++) with add-in framework, plus Document Manager (headless), eDrawings, and PDM APIs; built-in VBA macro recorder. Content: 3D ContentCentral, 3DEXPERIENCE Marketplace/PartSupply. Bundled technology partnerships: HCL CAMWorks (CAM), DriveWorksXpress (automation). Upgrade path to CATIA/SIMULIA/DELMIA roles on 3DEXPERIENCE. Worldwide VAR channel handles most sales, training, and support.
