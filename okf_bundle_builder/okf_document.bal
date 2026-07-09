// Serializes an OkfConcept into a conformant OKF document (see SPEC.md
// section 4): a YAML frontmatter block followed by the markdown body.

import ballerina/time;

isolated function buildOkfDocumentText(OkfConcept concept) returns string {
    string tagsLine = buildTagsLine(concept.tags);
    string frontmatter = "---\n" +
        "type: " + yamlScalar(concept.'type) + "\n" +
        "id: " + yamlScalar(concept.id) + "\n" +
        "title: " + yamlScalar(concept.title) + "\n" +
        "description: " + yamlScalar(concept.description) + "\n" +
        "tags: " + tagsLine + "\n" +
        "timestamp: " + currentTimestamp() + "\n" +
        "---\n\n";
    return frontmatter + concept.body.trim() + "\n";
}

isolated function currentTimestamp() returns string {
    time:Utc now = time:utcNow(0);
    string formatted = time:utcToString(now);
    int? fractionStart = formatted.indexOf(".");
    if fractionStart is () {
        return formatted;
    }
    return formatted.substring(0, fractionStart) + "Z";
}

isolated function buildTagsLine(string[] tags) returns string {
    if tags.length() == 0 {
        return "[]";
    }
    string result = "[";
    foreach int i in 0 ..< tags.length() {
        if i > 0 {
            result = result + ", ";
        }
        result = result + yamlScalar(tags[i]);
    }
    return result + "]";
}

// Wraps a value as a double-quoted YAML scalar, escaping backslashes and
// quotes and flattening any stray newlines so it stays valid on one line.
isolated function yamlScalar(string value) returns string {
    string flattened = replaceLiteral(value.trim(), "\n", " ");
    string escaped = replaceLiteral(flattened, "\\", "\\\\");
    escaped = replaceLiteral(escaped, "\"", "\\\"");
    return "\"" + escaped + "\"";
}
