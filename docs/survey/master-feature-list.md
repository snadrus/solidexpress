# Master Feature List — Commercial Parametric MCAD

This is the merged, vendor-neutral catalog of every capability found across the seven surveyed products: SolidWorks, Autodesk Fusion, Onshape, Autodesk Inventor, PTC Creo, Siemens NX (Designcenter), and Dassault CATIA. Each feature has a canonical name and a short description of what it does and why it matters. Per-product support is recorded in [feature-matrix.md](feature-matrix.md); product-specific terminology is noted in the matrix footnotes.

Features are grouped into 16 categories. Within each category, features are ordered roughly from "table stakes" (present in every product) to differentiators (present in only one or two).

---

## 1. Sketching and 2D Constraints

- **2D parametric sketching.** A dedicated environment for drawing 2D profiles (lines, arcs, circles, ellipses, conics, splines, slots, polygons, text) on planes or planar faces. Sketches are the input to most solid features, so sketcher quality drives overall modeling productivity.
- **Dimensional constraints (driving dimensions).** Numeric dimensions that control sketch geometry rather than merely measuring it. Editing the value updates the geometry; dimensions are usually named parameters usable in equations.
- **Geometric constraints (relations).** Non-numeric rules between sketch entities — coincident, tangent, parallel, perpendicular, concentric, symmetric, equal, midpoint, horizontal/vertical, fix — that capture design intent so geometry stays correct as dimensions change.
- **Constraint solver with definition-state feedback.** A variational 2D solver that classifies sketches as under-defined, fully defined, or over-defined/conflicting, with visual cues (color coding) and diagnostic/repair tools. Most products license Siemens' D-Cubed 2D DCM; solver behavior differences (e.g. Creo's "weak dimension" auto-complete approach vs. the allow-under-defined model) are a genuine UX differentiator.
- **Constraint inference during sketching.** Automatic application of constraints (horizontal, tangent, coincident) as the user draws, with on-screen glyphs and the option to suppress inference.
- **Auto-dimension / fully-define tools.** One-click application of the dimensions and constraints needed to fully constrain a sketch.
- **Constraint relaxation / drag-to-repair.** The ability to drag geometry and have the solver relax or remove conflicting constraints rather than refusing to move (e.g. Inventor's Relax Mode, drag-to-test in Onshape).
- **Advanced spline tools.** Fit-point and control-vertex B-splines, Bézier-style "style splines," curvature combs, G2/curvature constraints, and equation-driven curves for high-quality profile geometry.
- **Sketch blocks.** Reusable grouped sketch geometry, optionally rigid or flexible, used for 2D layout/mechanism concept studies and repeated detail.
- **3D sketching.** Sketching curves in 3D space (splines, lines, intersection curves, curves-on-surface), used for sweeps, lofts, routing paths, and weldment/frame skeletons.
- **Projected/derived sketch geometry.** Associative projection of model edges, silhouettes, and cross-sections into the active sketch so profiles follow upstream geometry.
- **Sketch pictures / image tracing.** Underlay of raster images in a sketch for tracing scanned drawings or logos.
- **Equation/variable-driven sketches.** Dimensions driven by named variables and math expressions, with variable scopes spanning a part, a document, or (in some products) shared cross-document variable libraries.
- **Sketch analysis/diagnostics.** Tools that detect open profiles, self-intersections, tiny gaps, and isolated geometry before feature creation fails.
- **2D-to-3D conversion.** Importing legacy 2D drawings (DWG/DXF) into sketches and semi-automatically constructing 3D models from orthographic views.
- **AI-assisted sketching.** Emerging capability (2025–2026): smart selection, auto-constraint suggestions, and AI-completed sketch geometry.

## 2. Part Modeling — Feature-Based Solids

- **History-based parametric modeling.** The core paradigm: an ordered feature tree (timeline) records every operation; edits regenerate downstream features. Includes rollback, reordering, suppression, folders, and (in some products) a freeze bar to lock upstream features for performance.
- **Extrude (boss/cut).** Linear extrusion of a profile with end conditions (blind, through-all, to-face/next), draft/taper, thin-wall, and symmetric options.
- **Revolve.** Full or partial revolution of a profile about an axis, additive or subtractive.
- **Sweep.** Profile driven along a path, with guide curves/rails, twist control, and variable-section options (section geometry driven by position along the trajectory).
- **Helical sweep / coil.** Springs, threads, and worm profiles with constant or variable pitch.
- **Loft / blend.** Transition solid or surface through multiple sections with guide curves, centerlines, point mapping, and end-condition continuity control (G0/G1/G2).
- **Hole feature (standards-based).** Engineered holes — simple, counterbore, countersink, spotface, tapped, clearance — sized from ANSI/ISO/DIN standards libraries, with multi-position placement and stacked/multi-element holes.
- **Thread features.** Cosmetic threads from standards libraries (for drawings/manufacturing callouts) and physically modeled threads where needed.
- **Fillets / rounds.** Constant, variable-radius, full-round, face-face, and curvature-continuous (C2/conic) edge blends, with setback corners, hold lines, and transition control. Fillet robustness on hard cases is a classic kernel-quality benchmark.
- **Chamfers.** Distance, distance-distance, distance-angle, and partial chamfers on edges and corners.
- **Shell.** Hollowing a solid to uniform or per-face thickness with face removal.
- **Draft.** Adding mold-release angle to faces via neutral plane, parting line, step, or reflect-line methods, including variable draft.
- **Rib / web / stiffener.** Thin structural features generated from open profiles, with draft and boss options for molded parts.
- **Patterns.** Linear/rectangular, circular, curve-driven, sketch/point-driven, table-driven, fill, and geometry patterns of features, faces, bodies, or components — including per-instance variation (variable patterns), pattern-of-pattern, and reference patterns that follow a parent pattern.
- **Mirror.** Mirroring features, bodies, or components about a plane, with associative left-hand/right-hand version generation.
- **Multibody part design.** Multiple disjoint solid bodies within one part file, with body-level Boolean operations (unite/subtract/intersect), split, and tools to push bodies out into separate part files plus an assembly. Foundation for weldments, mold tooling, and master-model workflows.
- **Boolean / combine operations.** Explicit body-level unite, subtract, intersect, and split operations, including hybrid solid/surface Booleans.
- **Emboss / wrap / decal.** Wrapping text or profiles onto curved faces (raised, recessed, or split) and applying image decals.
- **Global deformation features.** Flex, bend, twist, dome, and freeform deformation of finished solids for styling adjustments.
- **Derived / linked parts.** Associatively referencing one part (or bodies from it) inside another, with scale/mirror options — the base mechanism for master-model and skeleton workflows.
- **Reusable feature templates.** Parameterized, library-stored feature groups with published inputs that can be instantiated repeatedly (iFeatures, UDFs, Power Copies, FeatureScript features).
- **Part configurations.** Named variants within one part definition — differing dimensions, suppressed features, materials, properties — driven by tables (Excel or native) or configuration UIs. See also category 14 for table-driven families.
- **Lattice structures.** Generating internal beam/stochastic/TPMS (gyroid) lattices for lightweighting and additive manufacturing, optionally with simulation-driven density grading.
- **Mesh geometry as reference.** Importing STL/OBJ/3MF meshes and referencing (measuring, snapping to, Boolean-ing against) them alongside B-rep geometry; full mesh/B-rep hybrid modeling ("convergent modeling") is a high-end differentiator.
- **Feature-failure diagnostics.** Tools that explain why a feature failed to regenerate and propose fixes; newest versions add AI-driven root-cause analysis.

## 3. Direct Editing and History-Free Modeling

- **Direct face editing.** Move, offset, rotate, delete, and replace faces of a solid without editing the feature history — essential for modifying imported ("dumb") geometry and for late-stage changes.
- **Hybrid direct-parametric editing.** Direct edits recorded as features in the history tree, so they remain editable, suppressible, and parameter-driven. The dominant mid-range approach (SolidWorks, Fusion, Onshape, Inventor, Creo Flexible Modeling).
- **True synchronous/history-free technology.** A modeling mode that solves geometric conditions (concentricity, symmetry, coplanarity) live on the model with no history dependency, letting users edit any geometry — native or imported — as if it were parametric. Siemens NX Synchronous Technology is the reference implementation; most competitors lack a true equivalent.
- **Feature recognition on imports.** Automatic reconstruction of a parametric feature tree (holes, fillets, extrudes, patterns) from imported dumb solids.
- **Pattern and symmetry recognition.** Detecting patterns/symmetry in imported geometry so a direct edit to one instance propagates to all (Creo FMX, NX ST).
- **Drag-handle editing.** In-canvas dragging of faces, edges, and dimension handles to modify features live without opening dialogs.
- **Standalone direct-modeling application.** A separate history-free modeler sharing the native format, aimed at concept work and non-expert users (Creo Direct, Creo Elements/Direct).
- **Imported-geometry repair.** Healing tools for translated data: stitching gaps, fixing bad topology, replacing faces, fitting surfaces within tolerance.

## 4. Surfacing and Freeform Geometry

- **Core surface toolset.** Surface equivalents of solid features (extrude/revolve/sweep/loft) plus trim, extend, untrim, offset, ruled, radiate, knit/join, and thicken-to-solid.
- **Boundary/N-sided patch surfaces.** Surfaces defined by boundary curves in two directions with per-edge continuity control (G0/G1/G2) — the highest-quality blend tool in most systems.
- **Fill/patch surface.** Closing an N-sided hole with contact/tangent/curvature conditions to surrounding faces.
- **3D curve toolset.** Helixes, projected curves, bridging/composite curves, curves-on-surface, iso-parameter curves, and 3D fit splines feeding advanced surfacing.
- **Continuity control and analysis.** Authoring and verifying G0 (contact), G1 (tangency), G2 (curvature), and G3 continuity across surface boundaries; zebra stripes, curvature maps, reflection/environment-map analysis, draft analysis, and surface-deviation color maps.
- **Subdivision (SubD) freeform modeling.** Box-style push/pull sculpting of a control cage that converts to smooth B-rep surfaces (T-splines and similar). Standard in Fusion (Form) and Creo (Freestyle); an add-on or separate app for SolidWorks (xShape), Inventor (Freeform), NX (Realize Shape), and CATIA (Imagine & Shape); absent in Onshape.
- **Interactive/stylized surfacing environment.** A dedicated industrial-design surfacing mode with freeform curve sketching, curves-on-surface, real-time surface regeneration, and multi-view editing (Creo ISDX/Style, CATIA FreeStyle, NX Studio Surface).
- **Class-A surfacing.** Explicit Bezier/NURBS control-point modeling, matching/fairing, and highlight-quality analysis to automotive exterior standards. Effectively a CATIA (ICEM) / Alias duopoly; NX is credible; the mid-range products are not positioned for it.
- **Global surface deformation.** Wrap, bump, morph, and target-driven global deformation of existing surface models.
- **Surface flattening (non-developable).** Flattening complex doubly-curved surfaces for fabric, leather, and composite patterns (beyond sheet-metal unfold).
- **Reverse engineering / scan-to-CAD.** Importing point clouds and meshes, aligning/cleaning them, and fitting NURBS surfaces or auto-converting organic meshes to editable bodies.
- **Algorithmic/visual-scripting geometry.** Node-graph generative modeling associative with the parametric model (CATIA xGenerative Design, NX Algorithmic Modeling); Grasshopper-style workflows inside MCAD.

## 5. Sheet Metal, Weldments, and Specialized Part Environments

- **Sheet metal environment.** Rules-driven thin-metal design: base/edge/miter/contour flanges, hems, jogs, bends, folds, tabs, rips, corner treatments and reliefs, with material-based rules (thickness, bend radius, K-factor/bend allowance/bend tables).
- **Flat pattern generation.** Associative unfolded state with bend lines, bend zones, and bend tables; DXF/DWG export for laser/punch/waterjet programming.
- **Simultaneous folded/flat editing.** Folded model, flat pattern, and bend table visible and editable side by side, updating live (an Onshape signature).
- **Lofted/transitional sheet metal.** Flattenable lofts between differing profiles (round-to-square transitions) with generated bend lines.
- **Convert solid to sheet metal.** Recognizing an arbitrary thin solid or imported body as sheet metal so it can be unfolded and edited with sheet-metal features.
- **Forming tools / punches.** Library-based stamped features (louvers, lances, embosses, bridges) with punch ID tables for fabrication drawings.
- **Aerospace sheet metal.** Hydro-pressed/brake-formed panels on contoured surfaces with joggles and surfaced flanges (CATIA ASL; high-end only).
- **Weldments (weld beads and prep).** Assembly- or part-level weld definition: cosmetic and solid fillet/groove beads, weld preparation geometry, post-weld machining features, and weld symbols that flow to drawings.
- **Frames / structural members.** Skeleton-sketch-driven structural design using standard profile libraries (tubes, channels, beams, angles) with miter/trim/notch end treatments, gussets, end caps, and associative cut lists with lengths and angles.
- **Plastic part features.** Purpose-built bosses, snap fits, lips/grooves, grills, rests, and rule fillets, optionally driven by material manufacturability rules (wall thickness, draft).
- **Plastics manufacturability checks.** Draft analysis, undercut detection, wall-thickness analysis, and knife-edge detection for molded parts.
- **Mold tooling design.** Parting-line and parting-surface extraction, shut-off surfaces, core/cavity split, side cores/lifters, shrinkage, mold-base catalogs (Hasco, DME), ejectors, and cooling channels.
- **Progressive die / stamping tooling.** Strip layout and progressive-die design for stamped parts (NX, Creo PDX; high-end only).
- **Electrode design.** EDM electrode extraction and management from tooling geometry (NX; high-end only).
- **Composites design.** Zone- and ply-based laminate definition, draping/producibility simulation, ply books, flat patterns, and links to laser projection and cutting (CATIA CPD is the industry leader; Creo and NX have offerings).
- **Casting design.** Cast-part and die design workflows through tooling extensions.

## 6. Assemblies

- **Constraint-based mating.** Positioning components with mates/constraints: coincident, concentric, distance, angle, tangent, parallel, symmetric, width, lock. The traditional paradigm (SolidWorks, Inventor constraints, CATIA, Creo, NX).
- **Joint-based assembly.** Kinematic joints (rigid, revolute, slider, cylindrical, planar, ball, pin-slot) that define position and degrees of freedom in one step, reducing constraint counts (Fusion Joints, Onshape Mates, Inventor Joints, Creo Connections).
- **Mate connectors / local frames.** Named coordinate frames on geometry that mates attach to, decoupling mating from face selection and making assemblies robust to topology change (Onshape's signature; NX/CATIA have analogous published frames).
- **Mechanical/advanced mates.** Gear, rack-and-pinion, screw, cam, slot, path, linear-coupler, hinge, and universal-joint relationships for mechanism behavior.
- **Mate limits and driven motion.** Ranges of motion on joints/mates, drivable by sliders or motors for motion checks and animation capture.
- **Contact-based motion.** Physical contact sets so components push each other during drag/motion simulation.
- **Smart/automated fastening.** Auto-populating holes with correctly sized standard hardware, including stack (bolt-washer-nut) intelligence; newest versions add AI recognition and auto-mating of fasteners.
- **Standard parts libraries.** Built-in libraries of fasteners, bearings, structural shapes, and fittings per ANSI/ISO/DIN/JIS, with smart insertion (SolidWorks Toolbox, Inventor Content Center, Onshape Standard Content).
- **Design accelerators / machine-element generators.** Calculation-driven generators for bolted connections, shafts, gears, cams, belts, and springs that produce both geometry and engineering reports (Inventor's differentiator).
- **Large-assembly modes.** Lightweight/graphics-only loading, on-demand geometry resolution, view-only large design review, selective/partial loading, and automatic culling of small components — the toolset that determines each product's practical assembly-size ceiling.
- **Simplified representations / envelopes.** Named representations that substitute simplified geometry (shrinkwrap/envelope parts, SpeedPak, simplified reps) for performance and IP protection when sharing.
- **Defeature / IP protection.** Removing internal detail, holes, and features to produce shareable "dumb" models that protect proprietary design content.
- **Top-down / skeleton design.** Master layout sketches or skeleton parts driving component geometry, with published named references for stable change propagation; formalized data-sharing controls in high-end systems (Creo AAX, NX WAVE, CATIA Publications).
- **In-context editing with managed references.** Editing parts in assembly position while referencing neighbors, with explicit control over when external references update (snapshot "contexts" in Onshape; lockable/breakable references elsewhere) to avoid silently broken links.
- **Assembly features.** Cuts, holes, and other features applied at assembly level across multiple components (machining-after-assembly representation).
- **Assembly configurations / variants.** Named assembly variants controlling component inclusion, suppressed instances, mate values, and positional states; table-driven at scale (iAssemblies, Family Tables).
- **Positional representations.** Named kinematic positions (open/closed, extended/retracted) reusable in drawings and views.
- **Flexible subassemblies.** The same subassembly solving to different positions in different parent contexts (a spring or cylinder shown at different compressions).
- **Modular product/variant architecture.** Formal option/variant management for configure-to-order platforms, usually integrated with the PLM layer (Creo Options Modeler, CATIA/ENOVIA effectivity, NX/Teamcenter).
- **Interference and clearance checking.** Static interference detection, clearance verification, and collision detection during motion drag.
- **Exploded views.** Reusable exploded states with tweak paths and animation, consumable in drawings and technical documentation.
- **Assembly mirroring.** Producing a mirrored assembly with correct left/right-hand component versions.
- **Real-time multi-user assembly editing.** Multiple users editing the same assembly simultaneously with live presence — native to Onshape; offered by Creo+ (SaaS) and CATIA 3DEXPERIENCE; absent in file-based desktop products.

## 7. Drawings and Documentation

- **Associative 2D drawings.** Drawing views generated from and synchronized with the 3D model: standard/orthographic, projected, isometric, section (full/half/offset/aligned), detail, broken, broken-out/breakout, auxiliary, crop, alternate-position, and exploded views.
- **Drafting standards support.** Per-document standards (ANSI/ASME, ISO, DIN, JIS, BSI, GB, GOST) controlling projection angle, symbology, and dimension styles, with customizable style hierarchies and templates. Breadth varies: desktop incumbents support 6–7 standards; Fusion supports ASME/ISO only.
- **Dimensioning and annotation.** Retrieved model dimensions plus created driven dimensions (ordinate, baseline, chain), notes, leaders, center marks/centerlines, surface-finish symbols, weld symbols, and edge-condition symbols.
- **GD&T on drawings.** Feature control frames, datum features/targets, and tolerance display per ASME Y14.5 / ISO GPS, with standards-aware input validation.
- **BOM / parts-list tables.** Associative bills of materials (top-level, parts-only, indented/structured) with item numbering, balloons/auto-balloon, custom properties, rollups, and export; plus hole tables, revision tables, bend tables, cut lists, weldment tables, and punch tables.
- **Sheet formats and title blocks.** Template sheets with title blocks, borders, and property-linked fields; import of legacy border/title-block standards.
- **Flat-pattern views.** Sheet-metal flat-pattern drawing views with bend-line annotation and bend direction/angle callouts.
- **Native DWG authoring.** Drawings authored directly as AutoCAD-compatible DWG files with no translation step (Inventor's differentiator).
- **Drawing standards checking.** Automated validation of drawings/documents against company CAD standards.
- **Drawing comparison.** Diffing two revisions of a drawing or model to highlight changes.
- **Auto-generated drawings (AI).** One-click or prompt-based generation of drawing sheets with views, hole callouts, and proposed dimensions (SolidWorks 2026 beta; emerging industry-wide).
- **Batch publishing.** Scheduled/batch printing, PDF export, and format conversion of drawing sets.
- **Lightweight publishing formats.** 2D PDF, 3D PDF, DWF/DWFx, and free-viewer formats (eDrawings) for supply-chain communication without CAD seats.

## 8. Model-Based Definition (MBD / PMI)

- **3D annotations (PMI) on models.** Dimensions, notes, surface finish, weld symbols, and datum symbols attached directly to 3D geometry, organized on annotation planes, replacing or supplementing 2D drawings.
- **Semantic (machine-readable) GD&T.** Tolerances stored as structured data linked to geometry — not just graphical text — so downstream CAM, CMM, and tolerance-analysis tools can consume them. Compliant with ASME Y14.41 / ISO 16792.
- **GD&T authoring validation.** Expert-system guidance that blocks invalid feature control frames and flags incomplete or over-constrained tolerance schemes (Creo GD&T Advisor and Inventor Tolerance Advisor are the standouts).
- **Auto-dimension schemes.** Automatic generation of a complete plus/minus or geometric tolerancing scheme on a part.
- **Saved annotation/view states.** Combination states pairing model orientation, visible annotations, and display settings for structured consumption by viewers and drawings.
- **PMI-carrying neutral export.** STEP AP242 export with semantic PMI (plus 3D PDF and JT with PMI) so MBD deliverables survive translation to suppliers and inspection software.
- **PMI import from other CAD.** Reading annotations from competitor native formats and STEP AP242 during import.
- **Inspection documentation.** Ballooned inspection sheets and first-article inspection reports (AS9102/PPAP) generated from PMI or drawings.
- **Tolerance stack-up analysis.** 1D/3D worst-case, RSS, and statistical stack-up analysis driven by the model's dimensions and GD&T scheme.
- **Drawing reuse of PMI.** 2D drawing views that retrieve and display the 3D annotation set, keeping drawings and MBD in sync.

## 9. Simulation and Analysis

- **Guided/basic FEA wizard.** Entry-level single-part linear static analysis with simplified loads and fixtures for designers (SimulationXpress-class).
- **Linear static FEA.** Stress, strain, displacement, and factor-of-safety analysis of parts and assemblies with contacts, connectors, and standard loads/fixtures.
- **Modal/frequency analysis.** Natural frequencies and mode shapes.
- **Buckling analysis.** Critical load factors and buckling mode shapes.
- **Thermal analysis.** Steady-state and transient heat transfer, plus thermal-stress coupling.
- **Nonlinear FEA.** Large deformation, plasticity, hyperelasticity (rubber/gaskets), creep, and nonlinear contact.
- **Dynamics (linear and explicit).** Harmonic, random-vibration, response-spectrum, modal time history, and explicit event/impact/drop-test simulation.
- **Fatigue/durability.** S-N high-cycle fatigue and durability estimation from stress results.
- **Composite laminate analysis.** Ply-based laminate shells in FEA.
- **Real-time simulation while modeling.** GPU-accelerated instantaneous structural/thermal/modal/flow feedback that updates live as geometry changes (Creo Simulation Live via Ansys is unique; Onshape's cloud re-solve is adjacent).
- **Kinematic motion simulation.** Joint-driven mechanism motion, servo motors, cams, traces, and swept-volume/motion-envelope generation.
- **Rigid-body dynamics.** Force-based motion with springs, dampers, friction, gravity, and contact; motion loads transferable to FEA.
- **CFD (fluid flow).** Internal/external flow, conjugate heat transfer, turbulence, rotating regions; advanced variants add particles, radiation, species mixing, and moving mesh.
- **Electronics cooling.** Airflow/thermal simulation purpose-built for enclosures and PCBs.
- **Injection-molding simulation.** Fill/pack, weld lines, air traps, sink marks, cooling, warp/shrinkage, and gate-location advice with plastics material libraries.
- **Topology optimization.** Load-driven material-reduction studies producing organic shapes, with reconstruction back to editable B-rep geometry.
- **Generative design (multi-outcome).** Cloud exploration of many design alternatives against functional specs and manufacturing constraints (milling/additive/casting), returning ranked editable candidates.
- **Goal-driven design studies.** Sensitivity, feasibility, and optimization studies driving model dimensions against analysis measures (Creo Behavioral Modeling; parametric design studies elsewhere).
- **Design exploration / what-if checkpoints.** Branching checkpoint trees for exploring alternatives without breaking the main model.
- **Additive process simulation.** Distortion/thermal prediction and pre-compensated geometry for metal powder-bed printing.
- **Ergonomics / human factors.** Posable anthropometric manikins with reach, vision, and comfort (RULA) analysis.
- **Tolerance variation simulation.** 3D Monte-Carlo variation analysis of assemblies (often via partners such as 3DCS/Sigmetrix).
- **Sustainability / LCA screening.** Environmental-impact estimates (carbon, energy, water) tied to material and process choices, increasingly linked to PLM material data.
- **Enterprise CAE platform integration.** Escalation path from in-CAD simulation to full analyst suites sharing the same model (SIMULIA/Abaqus, Simcenter 3D, Ansys, Inventor Nastran).

## 10. CAM / Manufacturing

- **Integrated CAM environment.** Toolpath programming inside the CAD product, associative so toolpaths flag/update when the model changes.
- **2.5-axis milling.** Facing, pocketing, contouring, drilling cycles, and feature-recognition-driven prismatic machining.
- **3-axis surface machining.** Roughing (including adaptive/constant-engagement high-speed strategies), rest machining, pencil, Z-level, and steep-shallow finishing for molds and freeform parts.
- **3+2 (positional 5-axis) machining.** Indexed multi-axis setups.
- **Simultaneous 4/5-axis machining.** Swarf, multi-axis contouring, rotary, blade/impeller strategies. NX CAM is the industry reference; others offer it via extensions or partners.
- **Turning and mill-turn.** Lathe cycles (turning, grooving, threading) and synchronized mill-turn with live tooling.
- **Wire EDM.** 2/4-axis wire-cut programming.
- **Feature-based/automated CAM.** Automatic feature recognition, knowledge-based machining rules, templates, and whole-part strategy automation.
- **Tolerance-based machining.** Reading model PMI/tolerances to select operations and machining strategies automatically.
- **Machine simulation and verification.** Material-removal simulation, gouge checking, and full machine-kinematics collision simulation, ideally G-code-level.
- **Post-processing.** Post-processor libraries and generator tools to produce controller-specific NC code; openness/editability of posts varies (Fusion's free open library is a differentiator).
- **On-machine probing and CMM inspection programming.** In-process probing cycles and coordinate-measuring-machine program generation from model PMI.
- **Sheet nesting.** True-shape nesting of flat patterns across sheets with multi-sheet optimization, associative to design changes.
- **Sheet-metal NC (punching/nibbling).** Punch-press programming with tool libraries.
- **Additive manufacturing preparation.** Print-tray setup, orientation optimization, support generation, slicing, lattice integration, and build-file export (3MF/CLI); metal LPBF workflows with certified printer links at the high end.
- **Cutting (laser/plasma/waterjet).** 2D profile cutting toolpaths.
- **Robotics programming.** Offline programming of industrial robots for machining/finishing (NX/DELMIA; high-end only).
- **Costing / manufacturability estimation.** Automatic machining and sheet-metal cost estimation from geometry with customizable cost templates, plus rule-based DFM checks.
- **Process documentation.** Setup sheets, operation lists, and step-by-step process plans generated from CAM data.

## 11. Rendering and Visualization

- **Real-time viewport quality modes.** Hardware-shaded display with ambient occlusion, order-independent transparency, physically-based materials in-viewport, and non-photoreal styles (illustration, watercolor) for technical communication.
- **Photorealistic rendering.** Ray-traced/path-traced still rendering with physically-based materials, HDRI environments, decals, and denoising — embedded (Creo Render Studio via KeyShot, Onshape Render Studio) or as a companion app (SolidWorks Visualize, Inventor Studio).
- **Animation rendering.** Turntables, exploded-view storyboards, camera paths, and configuration/variant imagery rendered to video.
- **Cloud rendering.** Offloading renders to vendor cloud GPU farms, sometimes token-metered.
- **AR publishing.** One-click publication of models to phone/tablet/headset AR viewers with IP-protecting access control (Creo AR Design Share included in every seat is the standout).
- **VR / immersive review.** Design review in VR headsets, native (3DEXPERIENCE, NX immersive engineering, Onshape Vision on Apple Vision Pro) or via export (glTF/GLB XR pipelines).
- **Technical illustration.** Dedicated tools for exploded views, callouts, interactive parts catalogs, and assembly instructions from CAD data (Composer, Creo Illustrate) — usually separate products.
- **Presentation/exploded animation environments.** Storyboarded exploded views with tweak paths driving both animations and drawing views.

## 12. Data Management, PDM/PLM, and Collaboration

- **File versioning and check-in/check-out.** Vault-based control of CAD files: versions, where-used, copy-design, and reservation to prevent conflicting edits. The baseline for file-based products (Vault, SolidWorks PDM).
- **Automatic cloud versioning.** Every change or save captured automatically as a version with restore/promote, no vault administration (Onshape microversions, Fusion versions/milestones).
- **Branching and merging.** Git-style branches of a design with merge of alternatives — native and unlimited in Onshape; available in SolidWorks PDM Professional and Creo+ workspaces; absent in most file-based products.
- **Real-time multi-user co-editing.** Simultaneous editing of one model by multiple users with live presence and follow mode (Onshape native; Creo+ and 3DEXPERIENCE offer variants).
- **Release and revision management.** Formal release candidates, approval workflows, revision schemes, and part numbering.
- **Engineering change management.** ECO/ECN workflows, change actions, and impact analysis.
- **Item/BOM management (PLM).** Part-centric (not file-centric) BOM management, EBOM/MBOM, options and effectivity, NPI workflows, quality records, and supplier collaboration — the PLM tier (Windchill, Teamcenter, ENOVIA, Fusion Manage, Arena).
- **Multi-CAD data management.** Managing competitor CAD files in the same vault/PLM with native integrations.
- **Multi-site replication.** Vault replication across locations for distributed teams.
- **Browser-based review and markup.** View, measure, section, and comment on models in a browser without a CAD seat, via share links with granular permissions.
- **Design review round-tripping.** Markup formats that flow reviewer comments back into the authoring tool.
- **Database-native (fileless) CAD data.** Designs stored as database objects rather than files, eliminating save/copy semantics entirely and enabling audit-grade history (Onshape, CATIA 3DEXPERIENCE).
- **Analytics and audit trails.** Usage dashboards, activity reporting, and IP-access auditing for administrators.
- **Enterprise security/administration.** SSO, role-based access control, provisioning, and data-sovereignty controls (on-premises options where cloud is disqualifying).

## 13. Interoperability

- **STEP import/export (AP203/AP214/AP242).** The primary neutral B-rep exchange; AP242 adds semantic PMI carriage. Universal, but PMI-carrying export sometimes requires an add-on.
- **IGES import/export.** Legacy surface/wireframe exchange, still demanded in aerospace supply chains.
- **Parasolid exchange.** Kernel-exact exchange for the Parasolid-based products (NX, SolidWorks, Onshape import/export; Fusion/Inventor import only).
- **ACIS/SAT exchange.** Kernel-affinity exchange for ShapeManager-based products (Inventor, Fusion).
- **JT import/export.** Siemens' lightweight/exact visualization format, an ISO standard; export support and pricing vary (CATIA charges; Fusion imports only).
- **Native competitor-format import.** Reading SolidWorks/CATIA/NX/Creo/Inventor/Solid Edge files directly, typically geometry-only.
- **Associative native import (no-translate).** Foreign native files referenced live so source-file changes propagate into the local assembly — the differentiating tier of multi-CAD (Creo Unite, Inventor AnyCAD, SolidWorks 3D Interconnect).
- **Save-as to competitor formats.** Writing competitor native formats for supplier deliverables (Creo Collaboration Extensions; rare elsewhere).
- **Feature-history migration.** Rebuilding parametric feature trees from foreign files — essentially unsolved natively; third-party tools (Proficiency) only.
- **DWG/DXF 2D exchange.** Import/export of 2D drawings, flat patterns, and sketch geometry.
- **Mesh format support (STL/OBJ/3MF/glTF).** Import for reference/reverse-engineering and export for printing/visualization, with tessellation quality control; 3MF carries print metadata.
- **Lightweight/visualization formats.** CGR, PVZ, DWF, 3DXML, eDrawings, glTF/GLB for review and AR/VR pipelines.
- **3D PDF publishing.** Template-driven 3D PDF output for drawing-less deliverables.
- **IFC (BIM) exchange.** Import/export for plant and construction coordination; BIM-ready content authoring for Revit pipelines (Inventor's lane).
- **ECAD exchange (IDF/IDX).** Board-outline and component exchange with PCB tools, incremental change propagation (EDMD), and cloud ECAD co-design connectors (Onshape-Altium).
- **URDF/robotics export.** Robot-description export for simulation toolchains (Onshape; niche but growing).
- **Point-cloud/scan import.** Reading scan data for reverse engineering.
- **Cloud translation services.** Server-side format translation with no local translator installs (Onshape, Fusion), typically included in all plans.
- **Version compatibility policy.** Whether newer-version files open in older releases; a supply-chain pain point (CATIA V5 and most desktop products: no; SaaS products: moot).

## 14. Automation and Extensibility

- **Macro recording and scripting.** Recording UI interactions to replayable scripts with an embedded editor (VBA in SolidWorks/Inventor; mapkeys in Creo; journaling in NX; absent in Fusion/Onshape).
- **Desktop API (full object model).** Programmatic access to modeling, assemblies, drawings, and UI: COM/VBA/.NET (SolidWorks, Inventor), Python/C++ (Fusion), C/C++/C#/Java/Python (NX Open), C toolkit + Java/JS/.NET (Creo), C++ CAA (CATIA). Depth and language breadth vary widely.
- **REST/web API.** Cloud API for document management, feature creation, translation, and webhooks without a desktop session (Onshape's is the reference; Autodesk Platform Services and PTC/Siemens cloud APIs growing).
- **Headless/server-side automation.** Running the modeler without UI in the cloud for web configurators and batch processing (Autodesk Design Automation API, Onshape server-side FeatureScript evaluation).
- **User-defined feature language.** Writing first-class custom parametric features in the system's own feature language (Onshape FeatureScript is unique: the vendor's entire feature set is written in it and open-sourced).
- **Equations and global parameters.** Named parameters with math expressions, conditionals, and units driving dimensions across parts and assemblies; external spreadsheet linkage.
- **Table-driven design families.** Excel or native tables generating families of parts/assemblies (design tables, iParts/iAssemblies, Family Tables, configurations).
- **Rules-based design automation.** Embedded rules engines (VB.NET iLogic rules, Knowledgeware rules/reactions/checks, Configuration Rules) that drive parameters, features, components, and drawings from logic — the machinery behind engineer-to-order configurators.
- **Conditional model logic.** Feature-level programming embedded in the model (Pro/PROGRAM, Knowledge Fusion) with input prompts and conditional suppression.
- **Knowledge-based engineering (KBE).** Corporate design-intelligence capture: rules, checks, engineering templates with published inputs, and optimization loops (CATIA Knowledgeware/EKL is the deepest).
- **Design-standard enforcement.** Automated checks validating models/drawings against company standards.
- **Form-driven configurators.** No-code UI builders exposing model parameters to non-CAD users (DriveWorksXpress, iLogic forms, Configuration Publisher, Informed Design).
- **Embedded engineering calculations.** Calculation worksheets (Mathcad) embedded in models with bidirectional parameter flow.
- **App marketplace / partner ecosystem.** Certified third-party add-in stores; ecosystem size is a real selection criterion (SolidWorks' is the largest).
- **AI assistants.** Embedded LLM-based help, command suggestion, error diagnosis, and prompt-based geometry/drawing generation (2025–2026: SolidWorks AURA, Creo AI Assistant, NX/Designcenter embedded assistance, Autodesk Assistant).

## 15. Electrical, Routing, and Domain Modules

- **3D piping design.** Spec-driven and free routing of rigid pipe with fittings catalogs, slopes, and supports; isometric drawing output.
- **3D tubing/hose design.** Bent-tube and flexible-hose routing with bend tables for fabrication.
- **3D electrical harness routing.** Wires, cables, ribbon cables, bundles, splices, connectors from electrical catalogs, with bend-radius and diameter rules.
- **Harness flattening / nailboard drawings.** Flattening 3D harnesses to formboard manufacturing drawings with wire lists and cut lengths.
- **Schematic-to-3D connectivity.** Importing wiring connectivity from schematic tools to drive and validate 3D routing.
- **2D electrical schematics.** Single-line and multi-line diagrams, PLC support, terminal strips, and reports (SolidWorks Electrical, Creo Schematics, AutoCAD Electrical interop).
- **ECAD/PCB co-design.** Bidirectional, associative board-in-enclosure exchange with PCB tools; Fusion uniquely embeds full schematic capture, PCB layout, and SPICE simulation in the MCAD product.
- **Electrical clearance/creepage analysis.** Verifying electrical safety distances for compliance (Creo CCX).
- **P&ID and diagram-driven plant design.** 2D functional schematics driving 3D routed systems (high-end plant/ship products).
- **Shipbuilding.** Hull structure, compartments, and stiffened-panel design (CATIA, NX ship design; vertical modules).
- **Factory/plant layout.** Asset-library-driven factory line layout (Inventor Factory Design Utilities; magnetic-mate layout in SolidWorks).
- **IoT-connected design.** Feeding real-world sensor data into models and simulations (Creo Product Insight/ThingWorx).
- **Systems engineering / MBSE.** SysML architecture modeling and Modelica multi-physics systems simulation linked to the 3D product structure (CATIA Magic/Dymola; unique breadth).

## 16. Platform and Licensing

- **Operating system support.** Windows-only remains the norm for desktop MCAD (SolidWorks, Inventor, Creo, NX*, CATIA); Fusion adds macOS; Onshape runs in any browser on any OS including Linux/ChromeOS. (*NX has limited Linux batch support.)
- **Deployment architecture.** Desktop thick client (file-based), desktop client with mandatory cloud data (Fusion), full SaaS/browser (Onshape, NX X/Designcenter X, 3DEXPERIENCE cloud), and desktop-plus-PLM-managed hybrids.
- **Offline capability.** Full offline work (desktop products), temporary offline caching (Fusion), or none (Onshape) — decisive for air-gapped/ITAR environments.
- **Mobile and spatial clients.** Native iOS/Android apps with real editing (Onshape), viewer apps, and Apple Vision Pro / HMD clients.
- **Licensing models.** Named-user subscription (now dominant), floating/network licenses, perpetual + maintenance (still sold by SolidWorks resellers and CATIA V5), token/consumption models (Autodesk Flex, Siemens Value-Based Licensing token pools), and per-tier packaging with paid extensions.
- **Pricing tiers (2025–2026 rough US list).** Entry professional seats: Fusion ~$680/yr, Onshape Standard $1,500/yr, Inventor ~$2,500/yr, SolidWorks Standard ~$2,820/yr sub, Creo Design Essentials ~$3,190/yr, NX/Designcenter mid tiers ~$7,000–12,000/yr, CATIA 3DX roles ~$7,100–7,600/yr entry (loaded V5 seats $25k–65k+ perpetual). Fully equipped seats span roughly 5–10x the entry price in every family.
- **Free and low-cost tiers.** Free personal/hobbyist licenses (Fusion, Onshape Free with public documents), maker editions (~$48/yr SolidWorks for Makers), free education licenses (universal), and startup programs with steep discounts.
- **Release cadence and updates.** Annual desktop major releases with service packs versus continuous SaaS delivery (Onshape every ~3 weeks; cloud-connected offers every ~10 weeks); backward file compatibility policies differ and matter to supply chains.
- **Hardware requirements.** Certified workstation GPUs for desktop products (some features require specific NVIDIA hardware); browser/modest hardware for SaaS.
- **Data residency and security.** Cloud-only storage vs. on-premises options; SSO, RBAC, and audit controls at enterprise tiers.
