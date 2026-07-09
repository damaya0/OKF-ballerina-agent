// Regenerates index.md at every directory level of the output bundle,
// mirroring okf/src/reference_agent/bundle/index.py's regenerate_indexes:
// process directories deepest-first so a subdirectory's synthesized
// description is already known by the time its parent's index is built.

import ballerina/log;

isolated function regenerateIndexes(string bundleRootPath, ConceptEntry[] concepts) returns error? {
    string[] dirs = sortByDescendingDepth(collectDirectories(concepts));
    map<string> dirDescriptions = {};

    foreach string dir in dirs {
        IndexItem[] items = [];

        foreach ConceptEntry concept in concepts {
            if dirnameOfRel(concept.relativePath) == dir {
                items.push({
                    'type: concept.'type,
                    title: concept.title,
                    link: "/" + concept.relativePath,
                    description: concept.description
                });
            }
        }

        foreach string childDir in dirs {
            if childDir != dir && dirnameOfRel(childDir) == dir {
                string childDescription = dirDescriptions.hasKey(childDir) ? dirDescriptions.get(childDir) : "";
                items.push({
                    'type: "Subdirectories",
                    title: basenameOfRel(childDir),
                    link: "/" + childDir + "/index.md",
                    description: childDescription
                });
            }
        }

        if items.length() == 0 {
            continue;
        }

        string indexRelativePath = dir == "" ? "index.md" : dir + "/index.md";
        check writeOutputFile(bundleRootPath, indexRelativePath, buildIndexText(items));
        log:printInfo("wrote index", directory = dir == "" ? "." : dir);

        if dir == "" {
            continue;
        }
        if items.length() == 1 {
            dirDescriptions[dir] = items[0].description;
            continue;
        }
        string|error synthesized = synthesizeDirDescription(dir, items);
        if synthesized is error {
            log:printWarn("failed to synthesize directory description", directory = dir, cause = synthesized.message());
            dirDescriptions[dir] = "";
        } else {
            dirDescriptions[dir] = synthesized;
        }
    }
}

// Every ancestor directory (including "" for the bundle root) of every
// concept's path, deduplicated.
isolated function collectDirectories(ConceptEntry[] concepts) returns string[] {
    string[] dirs = [];
    foreach ConceptEntry concept in concepts {
        string dir = dirnameOfRel(concept.relativePath);
        while true {
            if !containsString(dirs, dir) {
                dirs.push(dir);
            }
            if dir == "" {
                break;
            }
            dir = dirnameOfRel(dir);
        }
    }
    return dirs;
}

isolated function containsString(string[] values, string target) returns boolean {
    foreach string value in values {
        if value == target {
            return true;
        }
    }
    return false;
}

isolated function buildIndexText(IndexItem[] items) returns string {
    string[] types = [];
    foreach IndexItem item in items {
        if !containsString(types, item.'type) {
            types.push(item.'type);
        }
    }
    types = sortStrings(types);

    string result = "";
    foreach int t in 0 ..< types.length() {
        string currentType = types[t];
        IndexItem[] group = [];
        foreach IndexItem item in items {
            if item.'type == currentType {
                group.push(item);
            }
        }
        group = sortItemsByTitle(group);

        if t > 0 {
            result = result + "\n";
        }
        result = result + "# " + currentType + "\n\n";
        foreach IndexItem item in group {
            string suffix = item.description.trim().length() > 0 ? " - " + item.description : "";
            result = result + "* [" + item.title + "](" + item.link + ")" + suffix + "\n";
        }
    }
    return result;
}

isolated function depthOf(string dir) returns int {
    if dir == "" {
        return 0;
    }
    return countSegments(dir);
}

isolated function countSegments(string dir) returns int {
    string[] segments = [];
    string remaining = dir;
    while true {
        int? separatorIndex = remaining.indexOf("/");
        if separatorIndex is () {
            segments.push(remaining);
            break;
        }
        segments.push(remaining.substring(0, separatorIndex));
        remaining = remaining.substring(separatorIndex + 1);
    }
    return segments.length();
}

isolated function sortByDescendingDepth(string[] dirs) returns string[] {
    string[] sorted = dirs.clone();
    int n = sorted.length();
    foreach int i in 1 ..< n {
        string current = sorted[i];
        int currentDepth = depthOf(current);
        int j = i - 1;
        while j >= 0 && depthOf(sorted[j]) < currentDepth {
            sorted[j + 1] = sorted[j];
            j = j - 1;
        }
        sorted[j + 1] = current;
    }
    return sorted;
}

isolated function sortStrings(string[] values) returns string[] {
    string[] sorted = values.clone();
    int n = sorted.length();
    foreach int i in 1 ..< n {
        string current = sorted[i];
        int j = i - 1;
        while j >= 0 && sorted[j] > current {
            sorted[j + 1] = sorted[j];
            j = j - 1;
        }
        sorted[j + 1] = current;
    }
    return sorted;
}

isolated function sortItemsByTitle(IndexItem[] items) returns IndexItem[] {
    IndexItem[] sorted = items.clone();
    int n = sorted.length();
    foreach int i in 1 ..< n {
        IndexItem current = sorted[i];
        string currentTitle = current.title;
        int j = i - 1;
        while j >= 0 && sorted[j].title > currentTitle {
            sorted[j + 1] = sorted[j];
            j = j - 1;
        }
        sorted[j + 1] = current;
    }
    return sorted;
}
