// Builds a flat, global concept-id -> relative-path map for the bundle, and
// reads concept files by relative path. Replaces the old currentDir-relative
// link resolver: the model now passes a concept id, and this file is a pure
// dictionary lookup with no "where am I" state at all.

import ballerina/file;
import ballerina/io;

// Recursively finds every ".md" file under `root`, INCLUDING index.md/log.md
// -- unlike okf_bundle_builder's source-side walker, which skips them because
// those are reserved filenames it generates rather than converts. Here, every
// markdown file in the built bundle must be openable: navigation descends
// into subdirectories by opening their index.md.
isolated function findAllMarkdownFiles(string root) returns string[]|error {
    string[] results = [];
    check collectAllMarkdownFiles(root, root, results);
    return results;
}

isolated function collectAllMarkdownFiles(string root, string currentDir, string[] results) returns error? {
    file:MetaData[] entries = check file:readDir(currentDir);
    foreach file:MetaData entry in entries {
        if entry.dir {
            check collectAllMarkdownFiles(root, entry.absPath, results);
            continue;
        }
        string name = check file:basename(entry.absPath);
        if !name.endsWith(".md") {
            continue;
        }
        string relativePath = check file:relativePath(root, entry.absPath);
        results.push(toForwardSlashes(relativePath));
    }
}

isolated function toForwardSlashes(string path) returns string {
    return replaceLiteral(path, "\\", "/");
}

// Literal (non-regex) substring replace, since `string` has no such method.
isolated function replaceLiteral(string value, string target, string replacement) returns string {
    if !value.includes(target) {
        return value;
    }
    string result = "";
    string remaining = value;
    while true {
        int? matchIndex = remaining.indexOf(target);
        if matchIndex is () {
            result = result + remaining;
            break;
        }
        result = result + remaining.substring(0, matchIndex) + replacement;
        remaining = remaining.substring(matchIndex + target.length());
    }
    return result;
}

// Tolerant of the raw link/id text a model copies verbatim: an optional
// leading "/" (SPEC.md section 5.1 bundle-root-relative marker) and an
// optional trailing ".md" are both stripped before matching against the map,
// so "/apis/accounts.md", "apis/accounts.md", and "apis/accounts" all
// resolve identically.
isolated function normalizeConceptId(string rawId) returns string {
    string trimmed = rawId.trim();
    if trimmed.startsWith("/") {
        trimmed = trimmed.substring(1);
    }
    if trimmed.endsWith(".md") {
        trimmed = trimmed.substring(0, trimmed.length() - 3);
    }
    return trimmed;
}

isolated function buildConceptIdMap(string bundleRootPath) returns (map<string> & readonly)|error {
    string[] relativePaths = check findAllMarkdownFiles(bundleRootPath);
    map<string> result = {};
    foreach string relativePath in relativePaths {
        result[normalizeConceptId(relativePath)] = relativePath;
    }
    return result.cloneReadOnly();
}

final map<string> & readonly CONCEPT_ID_TO_PATH = check buildConceptIdMap(bundleRootPath);

isolated function getPathFromMap(string conceptId) returns string|error {
    string? relativePath = CONCEPT_ID_TO_PATH[normalizeConceptId(conceptId)];
    if relativePath is () {
        return error(string `no concept or index page with id '${conceptId}' exists in this bundle`);
    }
    return relativePath;
}

isolated function readConceptFile(string bundleRootPath, string relativePath) returns string|error {
    string fullPath = bundleRootPath + "/" + relativePath;
    string content = check io:fileReadString(fullPath);
    return content;
}
