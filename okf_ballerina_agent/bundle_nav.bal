// Resolves and reads links within an OKF bundle, mirroring the link rules in
// okf/SPEC.md section 5: a leading "/" is bundle-root-relative, anything else
// is relative to the directory of the document currently being viewed.

import ballerina/io;

type OkfNavigationError distinct error;

isolated function splitPathSegments(string path) returns string[] {
    string[] segments = [];
    string remaining = path;
    while true {
        int? separatorIndex = remaining.indexOf("/");
        if separatorIndex is () {
            if remaining.length() > 0 {
                segments.push(remaining);
            }
            break;
        }
        string segment = remaining.substring(0, separatorIndex);
        if segment.length() > 0 {
            segments.push(segment);
        }
        remaining = remaining.substring(separatorIndex + 1);
    }
    return segments;
}

isolated function joinPathSegments(string[] segments) returns string {
    string joined = "";
    foreach int i in 0 ..< segments.length() {
        if i > 0 {
            joined = joined + "/";
        }
        joined = joined + segments[i];
    }
    return joined;
}

// Resolves a link found inside the document at `currentDir` to a bundle-relative
// path, e.g. resolveConceptLink("tables", "../datasets/index.md") -> "datasets/index.md".
isolated function resolveConceptLink(string currentDir, string link) returns string|error {
    string trimmedLink = link.trim();
    boolean isAbsolute = trimmedLink.startsWith("/");
    string[] baseSegments = isAbsolute ? [] : splitPathSegments(currentDir);
    string linkBody = isAbsolute ? trimmedLink.substring(1) : trimmedLink;
    string[] linkSegments = splitPathSegments(linkBody);

    string[] stack = baseSegments.clone();
    foreach string segment in linkSegments {
        if segment == "." {
            continue;
        } else if segment == ".." {
            if stack.length() == 0 {
                return error OkfNavigationError("link '" + link + "' escapes the bundle root");
            }
            _ = stack.pop();
        } else {
            stack.push(segment);
        }
    }

    string relativePath = joinPathSegments(stack);
    if !relativePath.endsWith(".md") {
        relativePath = relativePath.length() > 0 ? relativePath + "/index.md" : "index.md";
    }
    return relativePath;
}

isolated function dirnameOf(string relativeFilePath) returns string {
    int? separatorIndex = relativeFilePath.lastIndexOf("/");
    if separatorIndex is () {
        return "";
    }
    return relativeFilePath.substring(0, separatorIndex);
}

isolated function readConceptFile(string bundleRootPath, string relativePath) returns string|error {
    string fullPath = bundleRootPath + "/" + relativePath;
    string content = check io:fileReadString(fullPath);
    return content;
}
