#pragma once
// .sxp container: zip with manifest.json, breps/<uuid>.brep, cards/<uuid>.md.

#include <string>

namespace sx {

class Document;

// Returns true on success. On failure, err (if non-null) receives a message.
bool save_sxp(const Document& doc, const std::string& path, std::string* err = nullptr);
bool load_sxp(Document& doc, const std::string& path, std::string* err = nullptr);

}  // namespace sx
