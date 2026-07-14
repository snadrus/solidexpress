# Feature Support Matrix

Per-product support for the features cataloged in [master-feature-list.md](master-feature-list.md). Feature rows are condensed to the level where products meaningfully differ; universally supported basics (e.g. extrude, revolve) are collapsed into single rows.

## Legend

| Symbol | Meaning |
|---|---|
| **F** | Full — built into the base/entry commercial offering |
| **P** | Partial — limited depth, workaround-level, or notable restrictions |
| **A** | Add-on — requires a higher tier, paid extension/module, or separate product from the same vendor |
| **–** | Not supported (third-party/partner apps may fill the gap) |

Product columns: **SW** = SolidWorks (desktop 2026), **FU** = Autodesk Fusion, **ON** = Onshape, **INV** = Autodesk Inventor Professional, **CR** = PTC Creo Parametric (Design Essentials baseline), **NX** = Siemens NX / Designcenter (Standard-tier baseline), **CAT** = CATIA (V5 mid config / 3DEXPERIENCE mechanical role baseline).

Where a footnote number appears, see [Terminology and nuance notes](#terminology-and-nuance-notes).

## 1. Sketching and 2D constraints

| Feature | SW | FU | ON | INV | CR | NX | CAT |
|---|---|---|---|---|---|---|---|
| 2D parametric sketching, dimensions, geometric constraints | F | F | F | F | F | F | F |
| Solver definition-state feedback + over-constraint repair | F | F | F | F | F [1] | F | F |
| Auto-dimension / fully-define tools | F | F | P | F | F [1] | F | P |
| Constraint relaxation / drag-to-repair | P | P | F | F | P | F | P |
| Sketch blocks (reusable rigid/flexible groups) | F | – | P | F | P | P | P |
| 3D sketching | F | F | P | F | F | F | P [2] |
| Sketch pictures / image tracing | F | F | F | F | F | F | P |
| Cross-document shared variables | P | P | F | F | F | F | F |
| 2D-to-3D drawing conversion | P | P | – | P | F | P | P |
| AI-assisted sketching | F [3] | P | – | – | P | P | P |

## 2. Part modeling — feature-based solids

| Feature | SW | FU | ON | INV | CR | NX | CAT |
|---|---|---|---|---|---|---|---|
| Core features (extrude, revolve, sweep, loft, shell, draft, rib) | F | F | F | F | F | F | F |
| Variable-section sweep | F | P | F | F | F | F | F |
| Helical sweep / coil | F | F | F | F | F | F | P |
| Standards-based hole feature | F | F | F | F | F | F | F |
| Full pattern toolset incl. table/fill/variable patterns | F | P [4] | F | F | F | F | F |
| Curvature-continuous (C2) fillets | F | F | F | P | F | F | F |
| Multibody parts + Booleans | F | F | F | F | F | F | F |
| Multi-part single modeling environment | – | F | F [5] | – | – | – | – |
| Derived/linked parts (master model) | F | F | F | F | F | F | F |
| Reusable feature templates (UDF/iFeature/PowerCopy) | F | – | F [6] | F | F | A | F [7] |
| Part configurations | F | F [8] | F | F | F | F | P [9] |
| Global deformation (flex/bend/wrap) | F | P | P | P | P | F | A |
| Lattice structures | – | A | – | – | A | A | A |
| Mesh reference / convergent modeling | P | F | P | P | P | F [10] | A |
| AI feature-failure diagnosis | F [3] | – | – | – | F | P | P |

## 3. Direct editing and history-free modeling

| Feature | SW | FU | ON | INV | CR | NX | CAT |
|---|---|---|---|---|---|---|---|
| Direct face editing (move/delete/replace face) | F | F | F | F | F | F | P |
| Hybrid direct edits recorded in history | F | F | F | F | F [11] | F | P |
| True synchronous/history-free technology | – | P [12] | – | – | A [13] | F [14] | P |
| Feature recognition on imports | A | – | P | P | F | F | A |
| Pattern/symmetry recognition on dumb geometry | – | – | – | – | F [11] | F | – |
| Drag-handle live editing | F | F | F | F | F | F | P |

## 4. Surfacing and freeform geometry

| Feature | SW | FU | ON | INV | CR | NX | CAT |
|---|---|---|---|---|---|---|---|
| Core surface toolset + boundary/fill surfaces | F | F | F | F | F | F | F [15] |
| Continuity authoring/analysis (G2; G3 where noted) | F | P | F [16] | P | F | A | F |
| Subdivision (SubD) freeform modeling | A [17] | F [18] | – | F | F [19] | A [20] | A [21] |
| Stylized/interactive surfacing environment | – | – | – | – | A [22] | A | A [23] |
| Class-A surfacing | – | – | – | – | P | P | A [24] |
| Global surface deformation (wrap/morph) | P | – | – | – | P | F | A |
| Non-developable surface flattening | A [25] | – | – | – | P | A | A |
| Reverse engineering / scan-to-CAD | A | F/A [26] | P | P | P | A | A |
| Algorithmic/visual-scripting geometry | – | – | – | – | – | A | A [27] |

## 5. Sheet metal, weldments, and specialized environments

| Feature | SW | FU | ON | INV | CR | NX | CAT |
|---|---|---|---|---|---|---|---|
| Sheet metal environment + flat patterns | F | F | F | F | F | F | A |
| Simultaneous folded/flat editing | – | – | F | – | P | – | – |
| Lofted/transitional sheet metal | F | P | F | F | P | F | A |
| Convert solid to sheet metal | F | P | P | F | F [11] | F | A |
| Forming tools / punches | F | – | F | F | F | F | A |
| Aerospace sheet metal (joggles, contoured flanges) | – | – | – | – | – | A | A |
| Weldments (beads, prep, symbols) | F | – [28] | P | F | F | A | A |
| Frames / structural members with profile libraries | F | – [28] | F | F | F | A | A |
| Plastic part features (boss/snap-fit/lip) | P | A | P | F | F | F | A |
| Mold tooling (core/cavity, mold base) | F | – | P | A [29] | A | A [30] | A |
| Progressive die design | – | – | – | – | A | A | A |
| Composites design | – | – | – | – | A | A | A [31] |

## 6. Assemblies

| Feature | SW | FU | ON | INV | CR | NX | CAT |
|---|---|---|---|---|---|---|---|
| Constraint-based mating | F | F | F | F | F | F | F |
| Joint-based (DOF) assembly | P [32] | F | F [33] | F | F | P | F [34] |
| Mechanical mates (gear/screw/cam/path) | F | F | F | F | F | F | A [35] |
| Contact-based motion | F | F | P | F | F | F | A |
| Smart fastening / hardware auto-insert | A [36] | – | F | F | F | A | A |
| Design accelerators (gears/shafts/cams generators) | – | – | – | F | P | P | – |
| Standard parts libraries | F [36] | P | F | F | F | F | F |
| Large-assembly modes (lightweight/selective load) | F | – [37] | F | F | F | F | F |
| Simplified reps / envelopes / shrinkwrap | F | – | P | F | F | F | F [38] |
| Defeature / IP protection | F | P | P | F | F | F | A |
| Top-down / skeleton design | F | F | F | F | A [39] | F [40] | F |
| In-context editing with managed references | F | F | F [41] | F | F | F | F |
| Assembly features (cross-part cuts) | F | P | F | F | F | F | F |
| Assembly configurations / variants | F | F | F | F | F | F | P [9] |
| Positional representations | P | P | P | F | F | F | P |
| Flexible subassemblies | F | P | P | F | F | F | P |
| Modular product/variant architecture | – | – | – | – | A [42] | A [43] | A [44] |
| Interference/clearance checking | F | F | F | F | F | F | F [45] |
| Exploded views | F | F | F | F | F | F | F |
| Associative assembly mirroring | F | P | F | F | F | F | P |
| Real-time multi-user assembly editing | – | – | F | – | A [46] | – | F [47] |

## 7. Drawings and documentation

| Feature | SW | FU | ON | INV | CR | NX | CAT |
|---|---|---|---|---|---|---|---|
| Full associative view suite | F | F | F | F | F | F | F |
| Broad drafting standards (5+ standards) | F | P [48] | P [48] | F | F | F | F |
| GD&T on drawings | F | F | F | F | F | F | F |
| BOM/parts lists + balloons + specialty tables | F | F | F | F | F | F | F |
| Flat-pattern views with bend tables | F | F | F | F | F | F | A |
| Native DWG drawing authoring | – [49] | – | – | F | – | – | – |
| Drawing standards checking | A [50] | – | – | F | P | F | A |
| Drawing/model comparison | A [50] | – | F [51] | F | F | F | A |
| AI auto-generated drawings | F [3] | P | – | – | – | P | – |
| Batch publishing | A [50] | – | P | F | F | F | F |
| Lightweight publishing (2D/3D PDF, free viewer) | F [52] | F | F | F | F | F | P [53] |

## 8. Model-based definition (MBD/PMI)

| Feature | SW | FU | ON | INV | CR | NX | CAT |
|---|---|---|---|---|---|---|---|
| 3D annotations on models | F [54] | – | F | F | F | A [55] | A [56] |
| Semantic machine-readable GD&T | F [54] | – | F | F | F | A | A |
| GD&T authoring validation (advisor) | – | – | P | F | A [57] | P | A |
| Auto-dimension schemes | F | – | – | P | P | P | P |
| Saved annotation/view states | F | – | P | F | F | F | F |
| STEP AP242 export with semantic PMI | A [58] | – | F | F | F | F | F |
| PMI import from other CAD | F | – | P | F | F | F | F |
| Inspection documentation (FAI/ballooning) | A [59] | – | F | P | A | A | A |
| Tolerance stack-up analysis | A [60] | – | – | A [61] | A [62] | A | A [63] |

## 9. Simulation and analysis

| Feature | SW | FU | ON | INV | CR | NX | CAT |
|---|---|---|---|---|---|---|---|
| Linear static FEA | A [64] | F | A [65] | F | P [66] | A [67] | A [68] |
| Modal/frequency analysis | A | F [69] | A [65] | F | P | A | A |
| Buckling | A | A | – | A | A | A | A |
| Thermal analysis | A | F [69] | – | A | A | A | A |
| Nonlinear FEA | A [70] | A | – | A [71] | A | A | A [72] |
| Dynamics (linear/explicit/drop test) | A [70] | A | – | A [71] | A | A | A |
| Fatigue/durability | A | – | – | A | A | A | A |
| Real-time simulation while modeling | – | – | P [65] | – | A [73] | – | – |
| Kinematic motion simulation | F | F | P | F | F | A | A [74] |
| Rigid-body dynamics with loads transfer | A [75] | A | – | F | A [76] | A | A |
| CFD | A [77] | – [78] | – | – [79] | A [80] | A | A |
| Electronics cooling | A [77] | A | – | – | A | A | A |
| Injection-molding simulation | A [81] | A | – | P [29] | A | A | A |
| Topology optimization | A [70] | F/A [82] | – | F [83] | A | A | A |
| Generative design (multi-outcome) | – [84] | A | – | – | A [85] | A | A |
| Goal-driven design studies / optimization | A | – | – | P | A [86] | A | A |
| Design exploration checkpoints | – | – | P [51] | – | F | – | – |
| Additive process simulation | – | A | – | – | A | A | A |
| Ergonomics / human factors | – | – | – | – | F | A | A |
| Sustainability / LCA screening | A [87] | – | – | – | F [88] | P | A |
| Enterprise CAE platform escalation | A [89] | – | – | A [71] | A [90] | A [91] | A [92] |

## 10. CAM / manufacturing

| Feature | SW | FU | ON | INV | CR | NX | CAT |
|---|---|---|---|---|---|---|---|
| Integrated associative CAM | F [93] | F | A [94] | A [95] | A | A [96] | A [97] |
| 2.5-axis milling | F [93] | F | A [94] | A | A | A | A |
| 3-axis surface machining | F [93] | F | A [94] | A | A | A | A |
| 3+2 positional machining | A | F | A | A | A | A | A |
| Simultaneous 4/5-axis | A [98] | A [99] | A | A | A [100] | A | A |
| Turning / mill-turn | A | F/A [99] | A | A | A | A | A |
| Wire EDM | A [98] | – | – | – | A | A | A |
| Feature-based/automated CAM | F [93] | A [99] | P | A | A | A | A |
| Tolerance-based machining | F [93] | – | – | – | P | F [96] | P |
| Machine simulation / verification | F/A | F/A | A | A | A | A | A |
| Open/editable post-processors | P | F | P | P | A | A | P |
| Probing / CMM inspection programming | – | A [99] | – | – | A | A | A |
| Sheet nesting | F [101] | A [99] | – | A [95] | A | A | A |
| Additive prep (trays, supports, slicing) | P | F/A [102] | P | P | A [103] | A | A |
| Robotics programming | – | – | – | – | – | A | A [104] |
| Costing / DFM estimation | A [50] | P | – | P | P | P | P |

## 11. Rendering and visualization

| Feature | SW | FU | ON | INV | CR | NX | CAT |
|---|---|---|---|---|---|---|---|
| Photorealistic rendering | A [105] | F | A [106] | F | F [107] | A | A [108] |
| Animation rendering | A [105] | F | P | F | F | A | A |
| Cloud rendering | – | P [109] | A [106] | P | – | – | A |
| AR publishing | P [110] | – | F [111] | – | F [112] | P | A |
| VR / immersive review | P [110] | – | F [111] | – | P | A | A |
| Technical illustration | A [113] | – | – | F [114] | A [115] | A | A [116] |

## 12. Data management, PDM/PLM, and collaboration

| Feature | SW | FU | ON | INV | CR | NX | CAT |
|---|---|---|---|---|---|---|---|
| File vault PDM (check-in/out, versions) | F/A [117] | F [118] | F [118] | F [119] | A [120] | A [121] | A [122] |
| Automatic versioning (no save/vault admin) | – | F | F | – | A [46] | A [123] | F [47] |
| Branching and merging | A [117] | – | F | – | A [46] | – | P |
| Real-time multi-user co-editing | – | – | F | – | A [46] | – | F [47] |
| Release/revision management | A [117] | A [124] | A [125] | A [119] | A [120] | A [121] | A [122] |
| Engineering change management (ECO/ECN) | A [117] | A [124] | A [125] | A [119] | A [120] | A [121] | A [122] |
| Item/BOM PLM | A [126] | A [124] | A [127] | A [124] | A [120] | A [121] | F/A [122] |
| Multi-CAD data management | A [117] | P | P | F [128] | A [120] | A [121] | A [129] |
| Browser review and markup | F [52] | F | F | F [130] | P | A | F |
| Database-native (fileless) CAD data | – | P [131] | F | – | – | – | F [47] |
| Analytics/audit trails | A | P | A [125] | A | A | A | A |
| Enterprise security (SSO/RBAC) | A | F | A [125] | F | A | A | A |

## 13. Interoperability

| Feature | SW | FU | ON | INV | CR | NX | CAT |
|---|---|---|---|---|---|---|---|
| STEP AP203/214/242 import/export | F | F | F | F | F | F | F |
| STEP AP242 semantic-PMI export | A [58] | – | F | F | F | F | F |
| IGES import/export | F | F | F | F | F | F | F |
| Parasolid exchange | F [132] | P [133] | F [132] | F | P [133] | F [132] | – |
| JT import/export | P [134] | P [134] | F | F | A | F [135] | A [136] |
| Native competitor-format import | F [137] | F | F | F | F | A [138] | A [139] |
| Associative native import (live update) | F [137] | – | – | F [140] | F [141] | P | – |
| Save-as competitor formats | – | – | F [142] | – | A [141] | – | – |
| DWG/DXF exchange | F | F | F | F | F | F | F |
| Mesh formats (STL/OBJ/3MF/glTF) | F | F | F | F | F | F | P |
| 3D PDF publishing | A [58] | – | – | F | F | A | – [143] |
| IFC (BIM) exchange | F | – | – | F | P | A | A |
| ECAD exchange (IDF/IDX) | A [144] | F [145] | A [146] | P | A | A | A |
| URDF/robotics export | – | – | F | – | – | – | – |
| Cloud translation (no local installs) | – | F | F | – | – | P | – |

## 14. Automation and extensibility

| Feature | SW | FU | ON | INV | CR | NX | CAT |
|---|---|---|---|---|---|---|---|
| Macro recording | F [147] | – | – | F [147] | F [148] | F [149] | F [150] |
| Desktop API (full object model) | F [151] | F [152] | – | F [153] | F/A [154] | F [155] | A [156] |
| REST/web API + webhooks | P | F [157] | F | P [157] | P | P | P |
| Headless/server-side automation | P [158] | A [157] | F | A [157] | P | P | F |
| User-defined feature language | – | – | F [159] | – | – | A [160] | A [161] |
| Equations and global parameters | F | F | F | F | F | F | F |
| Table-driven design families | F | F [8] | F | F | F | F | F [162] |
| Rules-based design automation | P [163] | A [164] | P [159] | F [165] | F [166] | A | A [167] |
| Knowledge-based engineering (KBE) | – | – | P | P | A | A | A [167] |
| Design-standard enforcement checks | A [50] | – | P | P | P | A | A |
| Form-driven configurators | F [163] | – | P | A [168] | P | P | A |
| Embedded engineering calculations | – | – | – | – | F/A [169] | P | P |
| App marketplace | F [170] | F | F | F | P | P | A [171] |
| AI assistant | F [3] | F | P | P | F [172] | F [173] | A [174] |

## 15. Electrical, routing, and domain modules

| Feature | SW | FU | ON | INV | CR | NX | CAT |
|---|---|---|---|---|---|---|---|
| 3D piping design (spec-driven) | A [175] | – | – [176] | F | F [177] | A | A |
| 3D tubing/hose design | A [175] | – | – [176] | F | F [177] | A | A |
| 3D electrical harness routing | A [175] | – | P [176] | F | F [177] | A | A |
| Harness flattening / nailboard | A [175] | – | – | F | A [178] | A | A |
| Schematic-to-3D connectivity | A [179] | F [145] | P | F [180] | F/A [181] | A | A |
| 2D electrical schematics | A [179] | F [145] | – | A [180] | P [181] | A | A |
| ECAD/PCB co-design (embedded PCB layout) | – | F [145] | A [146] | P | A | A | A |
| Electrical clearance/creepage analysis | – | – | – | – | A | – | – |
| P&ID / plant diagrams | – | – | – | – | A | A | A |
| Shipbuilding | – | – | – | – | – | A | A |
| Factory/plant layout | P | – | – | A [95] | – | A | A [182] |
| IoT-connected design | – | – | – | – | A | P | P |
| Systems engineering / MBSE | – | – | – | – | – | P | A [183] |

## 16. Platform and licensing

| Aspect | SW | FU | ON | INV | CR | NX | CAT |
|---|---|---|---|---|---|---|---|
| Windows desktop | F | F | (browser) | F | F | F | F |
| macOS | – | F | F (browser) | – | – | – | – |
| Linux / ChromeOS | – | – | F (browser) | – | – | P [184] | P [184] |
| Browser client (full modeling) | – [185] | P | F | – | – | A [186] | A [187] |
| Native mobile editing | – | – | F | – | – | – | – |
| Full offline work | F | P | – | F | F | F | F |
| Free hobbyist tier | A [188] | F [189] | F [190] | – | – | – | – |
| Perpetual license availability | F [191] | – | – | – | – | P | F (V5) |
| Token/consumption licensing | – | F [192] | – | F [192] | – | F [193] | – |
| Entry pro price (USD/yr, 2025–26 list) | ~$2,820 | ~$680 | $1,500 | ~$2,500 | ~$3,190 | ~$2,400–7,300 [194] | ~$7,100+ |

---

## Terminology and nuance notes

1. **Creo solver behavior**: Creo's Sketcher auto-completes with "weak" dimensions/constraints, so sketches are always fully solved; users strengthen or replace weak items. Different paradigm rather than a deficiency.
2. CATIA 3DEXPERIENCE adds Natural Sketch (3D styling curves) in Creative Design roles; V5 lacks 3D sketching outside GSD wireframe.
3. SolidWorks 2026 AI features (AURA assistant, "What's Wrong" diagnosis, auto-generated drawings, assembly structure generation) are partly Beta and partly tied to cloud-connected subscription offers.
4. Fusion's gradient/distribution-controlled advanced patterns require the Design Extension.
5. Onshape **Part Studios**: multiple parts share one feature history by design — its signature multi-part paradigm.
6. Via FeatureScript custom features (see note 159).
7. CATIA Power Copies are core; authoring User Defined Features requires Knowledgeware (PKT) licensing in V5.
8. Fusion Configurations require a Team hub and are excluded from the free Personal license; logic-driven Configuration Rules require the Design Extension.
9. CATIA V5 has no lightweight configuration switcher; variants are handled via design tables or ENOVIA/PLM effectivity (heavyweight but powerful). 3DEXPERIENCE adds platform-level variant management.
10. NX **Convergent Modeling**: facet and B-rep geometry mixed in one model — an NX differentiator.
11. Creo **Flexible Modeling (FMX)** is included in every Creo license including Design Essentials, records direct edits as history features, and includes pattern/symmetry recognition and sheet-metal direct editing.
12. Fusion can disable the timeline per-document ("Do Not Capture Design History") — direct modeling, but without live geometric-condition solving.
13. **Creo Direct** is a separate history-free app sharing the .prt/.asm format; not in standard Design packages.
14. NX **Synchronous Technology** is the industry-reference history-free editing mode, included in every NX tier.
15. Full CATIA surfacing is **Generative Shape Design (GSD)**, included in mid/high (hybrid) configurations; entry configs get the reduced Wireframe & Surface toolset.
16. Onshape added G3 continuity edge analysis and reflection/deviation analysis in 2026.
17. **xShape** (3D Sculptor role) is a separate browser-based product on 3DEXPERIENCE; third-party Power Surfacing is the common desktop alternative.
18. Fusion **Form** workspace, built on acquired T-Splines technology — a differentiator at its price.
19. Creo **Freestyle** is included in all packages.
20. NX **Realize Shape**, a Value-Based-Licensing module.
21. CATIA **Imagine & Shape** (V5 IMA / 3DX Creative Design roles).
22. Creo **Style / ISDX** requires Design Advanced Professional or the standalone extension.
23. CATIA **FreeStyle** workbench, separately licensed in V5.
24. CATIA/ICEM (ICEM Surf standalone; ICEM Design Experience on 3DX) is the automotive Class-A standard, premium-priced.
25. SolidWorks **Surface Flatten** is Premium-tier.
26. Fusion Mesh workspace (repair/remesh) is core; automated organic mesh-to-BRep conversion requires the Design Extension.
27. CATIA **xGenerative Design**, 3DEXPERIENCE-only.
28. Fusion has no weldment or frame environment; App Store add-ins fill the gap. Weld symbols exist in drawings only.
29. Inventor Mold Design (Moldflow-based) is deprecated (removed by the 2027 release); embedded Moldflow Adviser goes with it. Autodesk positions Fusion as the successor.
30. NX **Mold Wizard**, an industry-leading tooling module in the token pool.
31. CATIA **Composites Design (CPD)** is widely considered the industry-leading composites tool.
32. SolidWorks models joints through advanced/mechanical mates rather than a joint paradigm.
33. Onshape **mate connectors**: local coordinate frames + one DOF-typed mate per connection — far fewer constraints than traditional mating.
34. CATIA 3DEXPERIENCE **Engineering Connections** double as kinematic joints; V5 uses classic constraints.
35. In CATIA, mechanism relationships live in DMU Kinematics (separately licensed in V5).
36. SolidWorks **Toolbox** + **Smart Fasteners** require the Professional tier.
37. Fusion has no lightweight/LOD representations; practical ceiling widely cited at ~300–1,000 unique components.
38. CATIA's **CGR visualization mode** with on-demand exact loading is the classic V5 large-assembly mechanism; DMU products extend it.
39. Creo skeletons/Copy Geometry at scale require the **Advanced Assembly Extension (AAX)**, bundled from Design Advanced up.
40. NX **WAVE geometry linking** is the reference high-end top-down system.
41. Onshape **contexts** are named snapshots with explicit update — no silently broken in-context references.
42. **Creo Options Modeler**, Design Engineering Professional tier or extension, integrates with Windchill options/variants.
43. Via Teamcenter product configurator.
44. Via ENOVIA effectivity/variant apps on 3DEXPERIENCE.
45. Basic clash is built in; full interference matrix/clearance analysis requires DMU Space Analysis in V5.
46. **Creo+** (SaaS delivery of Creo) adds real-time co-editing, branching cloud workspaces, and automatic cloud versioning.
47. CATIA on **3DEXPERIENCE** stores designs as database objects with native concurrent multi-user design; V5 remains file-based.
48. Fusion supports ASME/ISO only; Onshape ships ANSI/ISO/JIS templates.
49. SolidWorks exports DWG but authors its own .slddrw format; DraftSight (separate product) covers DWG authoring.
50. Part of SolidWorks **Professional** tier (Design Checker, Utilities/Compare, Task Scheduler, Costing).
51. Onshape's database model gives full compare/restore between any versions and branching "what-if" exploration for free.
52. **eDrawings** free viewer is a SolidWorks ecosystem staple; eDrawings Professional included with SW Professional.
53. CATIA relies on 3DXML/CGR/Composer for lightweight publishing; no native 3D PDF (partner tools).
54. SolidWorks MBD dimensions (formerly DimXpert) are core; organizing/publishing them (3D Views, 3D PDF, AP242 out) needs the **SOLIDWORKS MBD** add-on.
55. NX PMI is a named module starting at the Advanced tier; regarded as industry-leading in depth.
56. CATIA **FTA (Functional Tolerancing & Annotation)** is separately licensed; the foundation of Boeing/Airbus MBD programs.
57. **Creo GD&T Advisor** (Sigmetrix) from Design Advanced Professional; Creo is consistently cited as the strongest MBD authoring platform.
58. Requires the SOLIDWORKS MBD add-on.
59. **SOLIDWORKS Inspection** add-on.
60. **TolAnalyst** ships with SW Professional; 1D stackups only.
61. **Inventor Tolerance Analysis**, PDMC collection only.
62. **Creo EZ Tolerance Analysis** (Sigmetrix CETOL-based), Design Advanced Professional up.
63. Via 3DX tolerance-analysis apps or the 3DCS partner product inside CATIA.
64. SolidWorks: SimulationXpress (single part) is core; real static FEA needs CAD Premium or a Simulation add-on tier.
65. **Onshape Simulation** (linear static + modal, always-on cloud re-solve) requires the Professional plan; no thermal/CFD/nonlinear natively (SimScale partner app).
66. Creo Design Essentials includes limited linear structural ("Simulation Elite"); full Creo Simulate comes at Design Engineering tier.
67. NX simulation is the **Simcenter 3D** product line (NX Nastran heritage), licensed separately/modularly.
68. CATIA V5 GSA/GPS products; the strategic path is **SIMULIA** (Abaqus) roles on 3DEXPERIENCE.
69. Fusion modal/thermal study types are included but cloud solves consume Flex tokens without the Simulation Extension; linear static is token-free.
70. SolidWorks Simulation add-on ladder: Standard (fatigue, event-based motion) → Professional (modal, buckling, thermal, drop, topology) → Premium (nonlinear, dynamics, composites).
71. **Inventor Nastran** (nonlinear, dynamics, heat, fatigue, composites) is in the Product Design & Manufacturing Collection (PDMC).
72. Abaqus implicit/explicit via SIMULIA roles.
73. **Creo Simulation Live** (Ansys Discovery GPU solver): instantaneous structural/thermal/modal/flow feedback while modeling — unique; needs NVIDIA CUDA GPU ≥8 GB.
74. CATIA V5 DMU Kinematics is separately licensed; 3DX Motion Design app added rigid-body dynamics in R2026x.
75. SolidWorks **Motion Analysis** in CAD Premium (time-based dynamics with loads export to FEA).
76. **Mechanism Dynamics (MDO)** at Design Advanced Professional; kinematic Mechanism Design is core.
77. **SOLIDWORKS Flow Simulation** add-on; HVAC/Electronics Cooling are extra-cost modules on top of it.
78. Fusion's Electronic Cooling study (Simulation Extension) is the only CFD-adjacent capability; general CFD was Autodesk CFD, now discontinued for new sale.
79. Autodesk CFD discontinued; not in PDMC.
80. **Creo Flow Analysis** (Simerics): Basic bundled at Design Engineering; Advanced at top tier.
81. **SOLIDWORKS Plastics** add-on line (Standard/Pro/Premium).
82. Fusion Shape Optimization study is core-with-tokens; unlimited with Simulation Extension.
83. Inventor **Shape Generator**, included.
84. Dassault's generative design lives in 3DEXPERIENCE roles, not desktop SolidWorks.
85. Creo **GTO** (local topology optimization) at Design Engineering Professional; cloud **GDX** generative design add-on on top.
86. Creo **Behavioral Modeling (BMX)** at Design Advanced Professional — goal-driven optimization heritage feature.
87. SolidWorks Sustainability full version in CAD Premium; Xpress core.
88. Creo 12+ links models to Windchill material sustainability/carbon data.
89. Via 3DEXPERIENCE SIMULIA (Abaqus) roles.
90. Creo Ansys Simulation embeds full Ansys solvers.
91. Simcenter 3D shares NX geometry/associativity.
92. SIMULIA on the same 3DX platform/database — the deepest CAD-CAE integration story.
93. **SOLIDWORKS CAM Standard** (CAMWorks-powered 2.5-axis + basic 3-axis, feature recognition, tolerance-based machining) is included with any tier on active subscription. 2026 Design offers also bundle 3-axis NC, machine simulation, and sheet-metal nesting.
94. Onshape **CAM Studio** (2.5- through 5-axis, browser-native, 2026 adaptive roughing) requires the Professional plan; partner apps (Kiri:Moto etc.) remain an option.
95. **Inventor CAM Ultimate** and **Inventor Nesting** are PDMC-collection products.
96. **NX CAM** is the industry-leading system (full multi-axis, robotics, CMM); licensed via NX X Manufacturing tiers/tokens, separate from the design seat.
97. CATIA V5 machining workbenches (PMG/SMG/AMG/LMG); on 3DEXPERIENCE the machining portfolio is branded **DELMIA**, same platform/geometry.
98. Via SOLIDWORKS CAM Professional, the 2026 Milling/Turning roles, or partner CAMWorks.
99. Fusion **Manufacturing Extension**: simultaneous 4/5-axis, probing, nesting, metal LPBF additive, machining automation.
100. Creo CAM ladder: Prismatic/Multi-Surface Milling (Design Advanced) → Production Machining (Design Engineering) → Complete Machining CMX (top tier); Mold Machining at DAP.
101. Sheet-metal nesting + NC bundled in SolidWorks 2026 Design subscription offers (historically partner add-ins).
102. Fusion FFF additive is core; metal LPBF build prep and process simulation require the Manufacturing Extension.
103. Creo **Additive Manufacturing Extension** (lattices, trays, build optimization) standard at DAP; AM Plus (Materialise metal pipeline) at top tier.
104. Robotics OLP is DELMIA on the 3DX platform.
105. **SOLIDWORKS Visualize** Standard seat included with Professional+ subscription; Visualize Professional (animation/VR) is paid.
106. Onshape **Render Studio** (cloud ray tracing) requires Professional plan.
107. **Creo Render Studio** (Luxion KeyShot engine) is included in Design Essentials.
108. V5 Photo Studio (dated) or 3DX **Live Rendering** (Iray) in styling/viz roles; 3DEXCITE for marketing CGI.
109. Fusion cloud rendering consumes Flex tokens for some account types.
110. Via XR/glTF export and eDrawings AR; no in-product AR/VR review.
111. Onshape mobile AR + **Onshape Vision** Apple Vision Pro app.
112. **Creo AR Design Share** (Vuforia) included in every seat — publish to phone/tablet/HoloLens with IP controls.
113. **SOLIDWORKS Composer**, separate product.
114. Inventor **Presentations (IPN)** environment covers exploded instructions; full illustration via 3ds Max/other.
115. **Creo Illustrate**, separate product.
116. **CATIA Composer**, separate desktop product.
117. **SOLIDWORKS PDM Standard** included with Professional/Premium tiers; PDM Professional (multi-site, branching, web client, automation) is a paid add-on; SOLIDWORKS Manage adds item/project/process management.
118. Fusion Team cloud data management and Onshape's document model are built into the base subscription.
119. **Vault Basic** included with Inventor subscription; Vault Professional (lifecycles, ECO, items, replication) paid.
120. **Windchill** (or SaaS Windchill+), separate PTC product with deep native Creo integration.
121. **Teamcenter** (or SaaS Teamcenter X), separate Siemens product; NX X tiers embed cloud-based data management.
122. **ENOVIA / 3DEXPERIENCE platform**; for 3DX CATIA the platform is the native data layer (baseline collaboration included in every role), while V5 connects via adapters.
123. NX X (Designcenter X) cloud offering includes built-in cloud data management.
124. **Fusion Manage** (Upchain-based cloud PLM), $1,115/yr add-on.
125. Onshape Release Management and company controls are Professional-plan features; custom workflows, analytics, SSO, and the **Arena PLM** connection are Enterprise.
126. Via SOLIDWORKS Manage or 3DEXPERIENCE ENOVIA roles.
127. Onshape-Arena Connection (Enterprise + Arena subscription).
128. **Vault Workgroup/Professional** manage multi-CAD; AnyCAD covers in-session referencing.
129. Windchill Workgroup Manager equivalent on the Dassault side is MULTICAx + ENOVIA connectors.
130. Inventor **Shared Views** publish to the free Autodesk Viewer for browser markup.
131. Fusion data is cloud-resident (no local files) but documents are still discrete files-in-cloud, not a granular database model.
132. Parasolid is the native kernel for NX and Onshape and licensed-native for SolidWorks — exchange among them is kernel-exact.
133. Import only; no Parasolid export (ShapeManager kernel for Fusion/Inventor, GRANITE for Creo).
134. Import only; JT export needs third-party tools (SolidWorks) or is absent (Fusion).
135. JT is Siemens' own format — reference implementation.
136. CATIA JT support is an extra-cost Multi-CAx interface — a friction point in JT-centric supply chains.
137. SolidWorks **3D Interconnect** reads native CATIA V5 (Premium only), Creo, NX, Inventor, Solid Edge, JT, STEP, IGES with live source-file update links.
138. NX native translators (NX↔CATIA/Creo/SolidWorks) are token-pool modules.
139. **MULTICAx** plug-in products, separately priced.
140. Inventor **AnyCAD**: associative live references to SolidWorks/CATIA/NX/Creo/Solid Edge/Alias/Fusion/Revit/STEP — best-in-class among mid-range CAD, including forward version interop.
141. Creo **Unite**: open/assemble CATIA, NX, SolidWorks, Inventor files with no translation step; Collaboration Extensions add auto-update and save-as (SW/Inventor collaboration from Design Essentials; CATIA/NX at Design Engineering).
142. Onshape exports SolidWorks and Rhino native formats (cloud translation).
143. Via partner tools (Theorem, Tetra4D).
144. **CircuitWorks** (IDF/IDX/PADS), SW Professional tier.
145. **Fusion Electronics** embeds full ECAD: schematics, PCB layout, SPICE, associative 3D board-in-enclosure — best-in-class electromechanical co-design in its price class (EAGLE successor).
146. Onshape **PCB Studio** + cloud **Altium Connector**, Professional plan.
147. VBA macro recording/editing built in (SolidWorks .swp; Inventor VBA).
148. Creo **Mapkeys** (UI macros); plus Pro/PROGRAM model logic.
149. NX **journaling** records Python/C#/VB journals.
150. CATScript/VBA macros in V5; more restricted on 3DX.
151. Mature COM API (VBA/C#/VB.NET/C++), plus Document Manager and PDM APIs.
152. Python and C++ desktop API; TypeScript cloud automation API via Autodesk Platform Services.
153. COM + VBA + .NET APIs, iLogic .NET rules; Design Automation API (cloud headless Inventor) on APS.
154. **Creo TOOLKIT** (C) is the deepest but needs a paid runtime license; J-Link (Java), VB API, and WebLink (JS) are free.
155. **NX Open** (C/C++/C#/Java/Python) plus SNAP; Knowledge Fusion for KBE.
156. **CAA C++/RADE** is the deepest ISV API in MCAD but separately licensed with a steep curve; EKL and automation object model vary by platform.
157. Autodesk Platform Services (Forge) provides cloud APIs incl. Design Automation for Inventor/Fusion; consumption-priced.
158. Via Document Manager API and PDM automation; no vendor headless-cloud SolidWorks.
159. **FeatureScript**: Onshape's open language in which all native features are written; users author first-class custom features — unique among mainstream MCAD. REST API supports server-side FeatureScript evaluation.
160. NX **Knowledge Fusion**, token-pool module.
161. CATIA **EKL** + Knowledgeware products (KWA/KWE/PKT).
162. CATIA **Design Tables** (Excel-driven) are core Knowledgeware.
163. **DriveWorksXpress** bundled free (upgrade path to paid DriveWorks Solo/Pro); Configuration Publisher for form-driven variants.
164. Fusion **Configuration Rules** (low-code) require the Design Extension; no macro recorder.
165. **iLogic** — arguably the strongest mainstream in-CAD rules engine, included free.
166. Relations + **Pro/PROGRAM** included; BMX optimization higher tier.
167. CATIA **Knowledgeware** (EKL, rules, checks, reactions, PKT templates, PEO optimization) is the deepest KBE stack in MCAD, licensed as products/roles.
168. **Informed Design** entitlement publishes Inventor configurators to non-CAD users.
169. **Mathcad**: Express bundled in Design Essentials; full Mathcad from Design Advanced.
170. SolidWorks' Gold/Solution Partner ecosystem is the largest third-party add-in market in MCAD.
171. CAA Adopter ISV program; 3DEXPERIENCE Marketplace.
172. **Creo AI Assistant** (Creo 13).
173. Designcenter June 2026 release ships embedded AI assistance.
174. 3DX R2026x "Command Intelligence" and AI assistants, cloud roles.
175. **SOLIDWORKS Routing** (piping/tubing/electrical) is Premium-tier.
176. Onshape has parametric **Routing Curves** and community wiring FeatureScripts, but no spec-driven routing module.
177. Creo **Piping and Cabling Extension (PCX)** is included in Design Essentials — unusual generosity vs. competitors.
178. **Harness Manufacturing Extension (HMX)**.
179. **SOLIDWORKS Electrical** Schematic/3D are separate paid products.
180. Inventor ↔ **AutoCAD Electrical** electromechanical link; AutoCAD Electrical ships in PDMC.
181. **Creo Schematics** Lite included with PCX; full product separate.
182. Via DELMIA plant apps.
183. **CATIA Magic** (SysML/Cameo) + **Dymola** (Modelica) — unmatched systems-engineering breadth under one CAD brand.
184. Server/batch components only (and browser clients of the cloud offerings); no native Linux desktop CAD.
185. Dassault's browser CAD is xDesign/xShape on 3DEXPERIENCE, separate from desktop SolidWorks.
186. **NX X / Designcenter X** Essentials tier is browser-based.
187. Some 3DX apps run in-browser; full CATIA design apps need the Windows native client.
188. **3DEXPERIENCE SOLIDWORKS for Makers**, ~$48/yr, non-commercial.
189. **Fusion for Personal Use**: free, non-commercial, 10 editable documents, reduced CAM/electronics/drawings.
190. **Onshape Free**: full modeling tools but all documents public.
191. Perpetual SolidWorks still sold via resellers (~$4,195–8,395 + maintenance); subscription offers are the strategic push.
192. **Autodesk Flex** tokens for occasional users and cloud solves.
193. Siemens **Value Based Licensing**: a token pool unlocking 110+ NX modules on demand.
194. NX/Designcenter spans NX X Essentials (~€2,150/yr browser tier) through Standard/Advanced/Premium (~€7,300–12,000/yr); named-user cloud subscriptions; June 2026 rebrand: the CAD line is now **Designcenter** (NX name retained for manufacturing/CAM).
