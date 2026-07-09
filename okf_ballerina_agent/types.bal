// Shape of the arguments the model sends back for an open_concept tool call.
type OpenConceptArgs record {|
    string path;
|};

// Return value of openConcept: the file content and the updated current directory.
type ConceptResult record {|
    string content;
    string newCurrentDir;
|};
