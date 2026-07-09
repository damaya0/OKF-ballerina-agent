// A single converted OKF concept: frontmatter classified by the model, body
// carried through verbatim from the source file (see anthropic_client.bal
// for why the model is never asked to reproduce the body itself).
type OkfConcept record {|
    string id;
    string 'type;
    string title;
    string description;
    string[] tags;
    string body;
|};

// What the model actually produces per source file -- classification only.
type OkfClassification record {|
    string 'type;
    string title;
    string description;
    string[] tags;
|};

// The subset of a converted concept's frontmatter needed later to build
// index.md files -- kept in memory so index generation never has to re-parse
// YAML frontmatter back out of the files this tool just wrote.
type ConceptEntry record {|
    string relativePath; // bundle-relative path including filename, e.g. "apis/foo.md"
    string id; // SPEC.md section 2 Concept ID: relativePath with the .md suffix removed.
    string 'type;
    string title;
    string description;
|};

// One line in a generated index.md, grouped and rendered by 'type (see
// SPEC.md section 6). Subdirectories use the synthetic type "Subdirectories".
type IndexItem record {|
    string 'type;
    string title;
    string link;
    string description;
|};
