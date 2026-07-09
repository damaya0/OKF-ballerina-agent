import ballerina/ai;
import ballerina/log;
import ballerinax/ai.anthropic as anthropic;

configurable string anthropicApiKey = ?;
configurable string anthropicModelName = ?;

final anthropic:ANTHROPIC_MODEL_NAMES ANTHROPIC_MODEL = check anthropicModelName.ensureType();
final ai:ModelProvider anthropicModelProvider = check new anthropic:ModelProvider(anthropicApiKey, ANTHROPIC_MODEL, maxTokens = 4096);

final string SYSTEM_PROMPT =
    "You are a research agent that answers questions using a knowledge bundle " +
    "written in the Open Knowledge Format (OKF): a directory tree of markdown " +
    "files with YAML frontmatter, cross-linked by concept id (a relative or " +
    "bundle-root-relative path, e.g. 'tables/users' -> 'tables/users.md').\n\n" +
    "You do not have the whole bundle in context. You navigate it one concept " +
    "at a time:\n" +
    "- You are given the root index.md, which lists subdirectories and/or " +
    "concepts with a short description of each.\n" +
    "- Use the open_concept tool to open exactly one concept at a time -- copy " +
    "the link/id verbatim from the markdown you are currently looking at (e.g. " +
    "'datasets/index.md', '/tables/users.md', '../tables/index.md').\n" +
    "- Directory index.md files exist purely for navigation -- they tell you " +
    "what's available so you can decide where to look next. Concept files " +
    "contain the schema/reference content you need to answer the question.\n" +
    "- Keep opening concepts -- including ones referenced from inside a concept " +
    "you already opened -- until you have enough concrete detail to answer " +
    "accurately. Don't guess if the bundle has the specific answer.\n" +
    "- If a link is broken, try a different one instead of giving up.\n" +
    "- Don't over-explore: once you've found the concept(s) that answer the " +
    "question, stop calling the tool and answer.\n\n" +
    "When you have enough information, respond with plain text (no tool call). " +
    "Answer the user's question directly and concisely, grounded in what you " +
    "read, and mention which concept id(s) the answer came from.";

final ai:ChatCompletionFunctions OPEN_CONCEPT_TOOL = {
    name: "open_concept",
    description: "Open a concept page in the OKF knowledge bundle by following a " +
        "link/id copied verbatim from the document you're currently viewing " +
        "(e.g. 'datasets/index.md', '/tables/users.md', '../tables/index.md').",
    parameters: {
        'type: "object",
        properties: {
            path: {'type: "string", description: "The link path or concept id to open, copied exactly as it appears in the markdown you just read."}
        },
        required: ["path"]
    }
};

// Resolves and reads the concept file for a single open_concept tool call.
// Returns the file content and the updated current directory, or an error.
isolated function openConcept(ai:FunctionCall toolCall, string currentDir, string bundleRootPath) returns ConceptResult|error {
    map<json> toolArguments = check toolCall.arguments.ensureType();
    OpenConceptArgs parsedArgs = check toolArguments.cloneWithType();
    string linkPath = parsedArgs.path;
    string relativePath = check resolveConceptLink(currentDir, linkPath);
    string conceptContent = check readConceptFile(bundleRootPath, relativePath);
    log:printInfo("opened concept", concept = relativePath);
    return {content: conceptContent, newCurrentDir: dirnameOf(relativePath)};
}
