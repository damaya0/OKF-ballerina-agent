// Converts a directory of raw markdown files into an OKF bundle: one
// concept document per source file (via the model), plus index.md at every
// directory level. No web-enrichment pass -- this only ever reads from
// `sourceDirPath`, it never fetches anything.

import ballerina/log;

configurable string sourceDirPath = ?;
configurable string bundleRootPath = ?;

public function main() returns error? {
    string[] sourceFiles = check findMarkdownFiles(sourceDirPath);
    log:printInfo("found source files", count = sourceFiles.length());

    ConceptEntry[] concepts = [];
    map<string> conceptIdToPath = {};

    foreach string relativePath in sourceFiles {
        string conceptId = conceptIdOf(relativePath);
        if conceptIdToPath.hasKey(conceptId) {
            log:printWarn("duplicate concept id, skipping", concept = relativePath, id = conceptId,
                existing = conceptIdToPath.get(conceptId));
            continue;
        }

        string|error rawContent = readSourceFile(sourceDirPath, relativePath);
        if rawContent is error {
            log:printWarn("failed to read source file", concept = relativePath, cause = rawContent.message());
            continue;
        }

        OkfClassification|error classification = classifyConcept(relativePath, rawContent);
        if classification is error {
            log:printWarn("failed to classify concept", concept = relativePath, cause = classification.message());
            continue;
        }

        OkfConcept converted = {
            id: conceptId,
            'type: classification.'type,
            title: classification.title,
            description: classification.description,
            tags: classification.tags,
            body: rawContent
        };
        string documentText = buildOkfDocumentText(converted);
        error? writeResult = writeOutputFile(bundleRootPath, relativePath, documentText);
        if writeResult is error {
            log:printWarn("failed to write concept", concept = relativePath, cause = writeResult.message());
            continue;
        }

        conceptIdToPath[conceptId] = relativePath;
        concepts.push({
            relativePath,
            id: conceptId,
            'type: converted.'type,
            title: converted.title,
            description: converted.description
        });
        log:printInfo("wrote concept", concept = relativePath, id = conceptId, 'type = converted.'type);
    }

    check regenerateIndexes(bundleRootPath, concepts);
    log:printInfo("done", converted = concepts.length(), of = sourceFiles.length());
}
