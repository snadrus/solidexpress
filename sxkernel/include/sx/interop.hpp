#pragma once
// Geometry interchange: STEP / IGES / STL import and export against a Document.

#include <string>
#include <vector>

#include "sx/ids.hpp"

namespace sx {

class Document;

namespace interop {

// Export all document bodies. On failure returns false and sets *err (if non-null).
bool export_step(const Document& doc, const std::string& path, std::string* err = nullptr);
bool export_iges(const Document& doc, const std::string& path, std::string* err = nullptr);
bool export_stl(const Document& doc,
                const std::string& path,
                bool binary = true,
                std::string* err = nullptr);

// Import into doc, adding one body per root/solid (STL: a single mesh body).
// Returns created body ids; empty vector + *err on failure.
std::vector<EntityId> import_step(Document& doc, const std::string& path, std::string* err = nullptr);
std::vector<EntityId> import_iges(Document& doc, const std::string& path, std::string* err = nullptr);
std::vector<EntityId> import_stl(Document& doc, const std::string& path, std::string* err = nullptr);

}  // namespace interop
}  // namespace sx
