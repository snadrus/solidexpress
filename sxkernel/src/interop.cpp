#include "sx/interop.hpp"

#include "sx/document.hpp"

#include <BRepMesh_IncrementalMesh.hxx>
#include <BRep_Builder.hxx>
#include <IFSelect_ReturnStatus.hxx>
#include <IGESControl_Reader.hxx>
#include <IGESControl_Writer.hxx>
#include <Interface_Static.hxx>
#include <STEPControl_Reader.hxx>
#include <STEPControl_Writer.hxx>
#include <StlAPI_Reader.hxx>
#include <StlAPI_Writer.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Shape.hxx>

#include <Standard_Failure.hxx>
#include <exception>
#include <sstream>

namespace sx::interop {
namespace {

void set_err(std::string* err, const std::string& msg) {
    if (err) *err = msg;
}

// One body per solid when the root contains solids; otherwise the root itself
// (shells/surfaces from IGES, mesh compounds from STL, etc.).
void collect_units(const TopoDS_Shape& root, std::vector<TopoDS_Shape>& out) {
    if (root.IsNull()) return;
    TopTools_IndexedMapOfShape solids;
    TopExp::MapShapes(root, TopAbs_SOLID, solids);
    if (solids.Extent() > 0) {
        for (int i = 1; i <= solids.Extent(); ++i) out.push_back(solids(i));
    } else {
        out.push_back(root);
    }
}

std::vector<EntityId> add_units(Document& doc,
                                const std::vector<TopoDS_Shape>& units,
                                const std::string& name_prefix,
                                std::string* err) {
    if (units.empty()) {
        set_err(err, "no shapes to import");
        return {};
    }
    std::vector<EntityId> ids;
    ids.reserve(units.size());
    for (size_t i = 0; i < units.size(); ++i) {
        std::ostringstream name;
        name << name_prefix << (i + 1);
        ids.push_back(doc.add_body(units[i], name.str()));
    }
    return ids;
}

TopoDS_Shape make_compound(const Document& doc) {
    TopoDS_Compound compound;
    BRep_Builder builder;
    builder.MakeCompound(compound);
    for (const auto& id : doc.body_ids()) {
        const Body* b = doc.body(id);
        if (!b || b->shape.IsNull()) continue;
        builder.Add(compound, b->shape);
    }
    return compound;
}

}  // namespace

bool export_step(const Document& doc, const std::string& path, std::string* err) {
    try {
        auto ids = doc.body_ids();
        if (ids.empty()) {
            set_err(err, "document has no bodies");
            return false;
        }
        Interface_Static::SetCVal("write.step.schema", "AP214");
        STEPControl_Writer writer;
        for (const auto& id : ids) {
            const Body* b = doc.body(id);
            if (!b || b->shape.IsNull()) continue;
            IFSelect_ReturnStatus st = writer.Transfer(b->shape, STEPControl_AsIs);
            if (st != IFSelect_RetDone) {
                set_err(err, "STEP transfer failed for body " + b->name);
                return false;
            }
        }
        IFSelect_ReturnStatus st = writer.Write(path.c_str());
        if (st != IFSelect_RetDone) {
            set_err(err, "cannot write STEP file " + path);
            return false;
        }
        return true;
    } catch (const Standard_Failure& e) {
        set_err(err, std::string("STEP export: ") + e.GetMessageString());
        return false;
    } catch (const std::exception& e) {
        set_err(err, std::string("STEP export: ") + e.what());
        return false;
    }
}

std::vector<EntityId> import_step(Document& doc, const std::string& path, std::string* err) {
    try {
        STEPControl_Reader reader;
        IFSelect_ReturnStatus st = reader.ReadFile(path.c_str());
        if (st != IFSelect_RetDone) {
            set_err(err, "cannot read STEP file " + path);
            return {};
        }
        reader.TransferRoots();
        const int n = reader.NbShapes();
        if (n <= 0) {
            set_err(err, "STEP file contains no shapes: " + path);
            return {};
        }
        std::vector<TopoDS_Shape> units;
        for (int i = 1; i <= n; ++i) collect_units(reader.Shape(i), units);
        return add_units(doc, units, "Imported ", err);
    } catch (const Standard_Failure& e) {
        set_err(err, std::string("STEP import: ") + e.GetMessageString());
        return {};
    } catch (const std::exception& e) {
        set_err(err, std::string("STEP import: ") + e.what());
        return {};
    }
}

bool export_iges(const Document& doc, const std::string& path, std::string* err) {
    try {
        auto ids = doc.body_ids();
        if (ids.empty()) {
            set_err(err, "document has no bodies");
            return false;
        }
        // BRep mode (1) preserves solid topology better than Face mode.
        IGESControl_Writer writer("MM", 1);
        for (const auto& id : ids) {
            const Body* b = doc.body(id);
            if (!b || b->shape.IsNull()) continue;
            if (!writer.AddShape(b->shape)) {
                set_err(err, "IGES transfer failed for body " + b->name);
                return false;
            }
        }
        writer.ComputeModel();
        if (!writer.Write(path.c_str())) {
            set_err(err, "cannot write IGES file " + path);
            return false;
        }
        return true;
    } catch (const Standard_Failure& e) {
        set_err(err, std::string("IGES export: ") + e.GetMessageString());
        return false;
    } catch (const std::exception& e) {
        set_err(err, std::string("IGES export: ") + e.what());
        return false;
    }
}

std::vector<EntityId> import_iges(Document& doc, const std::string& path, std::string* err) {
    try {
        IGESControl_Reader reader;
        IFSelect_ReturnStatus st = reader.ReadFile(path.c_str());
        if (st != IFSelect_RetDone) {
            set_err(err, "cannot read IGES file " + path);
            return {};
        }
        reader.TransferRoots();
        const int n = reader.NbShapes();
        if (n <= 0) {
            set_err(err, "IGES file contains no shapes: " + path);
            return {};
        }
        std::vector<TopoDS_Shape> units;
        for (int i = 1; i <= n; ++i) collect_units(reader.Shape(i), units);
        return add_units(doc, units, "Imported ", err);
    } catch (const Standard_Failure& e) {
        set_err(err, std::string("IGES import: ") + e.GetMessageString());
        return {};
    } catch (const std::exception& e) {
        set_err(err, std::string("IGES import: ") + e.what());
        return {};
    }
}

bool export_stl(const Document& doc, const std::string& path, bool binary, std::string* err) {
    try {
        auto ids = doc.body_ids();
        if (ids.empty()) {
            set_err(err, "document has no bodies");
            return false;
        }

        TopoDS_Shape shape;
        if (ids.size() == 1) {
            const Body* b = doc.body(ids[0]);
            if (!b || b->shape.IsNull()) {
                set_err(err, "body has null shape");
                return false;
            }
            shape = b->shape;
        } else {
            shape = make_compound(doc);
            if (shape.IsNull()) {
                set_err(err, "failed to build compound for STL export");
                return false;
            }
        }

        BRepMesh_IncrementalMesh mesher(shape, 0.1);
        (void)mesher;

        StlAPI_Writer writer;
        writer.ASCIIMode() = binary ? Standard_False : Standard_True;
        if (!writer.Write(shape, path.c_str())) {
            set_err(err, "cannot write STL file " + path);
            return false;
        }
        return true;
    } catch (const Standard_Failure& e) {
        set_err(err, std::string("STL export: ") + e.GetMessageString());
        return false;
    } catch (const std::exception& e) {
        set_err(err, std::string("STL export: ") + e.what());
        return false;
    }
}

std::vector<EntityId> import_stl(Document& doc, const std::string& path, std::string* err) {
    try {
        TopoDS_Shape shape;
        StlAPI_Reader reader;
        if (!reader.Read(shape, path.c_str()) || shape.IsNull()) {
            set_err(err, "cannot read STL file " + path);
            return {};
        }
        return {doc.add_body(shape, "Mesh 1")};
    } catch (const Standard_Failure& e) {
        set_err(err, std::string("STL import: ") + e.GetMessageString());
        return {};
    } catch (const std::exception& e) {
        set_err(err, std::string("STL import: ") + e.what());
        return {};
    }
}

}  // namespace sx::interop
