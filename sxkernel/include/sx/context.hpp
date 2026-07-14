#pragma once
// AI context export: renders the whole document as one Markdown bundle —
// the parametric timeline (as JSON), every body with its semantic card, and
// face cards including user aliases/notes. This is the document an AI
// assistant reads to discuss the model in arbitrary language; entity UUIDs
// in the text are the handles it passes back to commands.

#include <string>

namespace sx {

class Document;

std::string export_context_markdown(const Document& doc);

}  // namespace sx
