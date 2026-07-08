import ballerina/http;

configurable string anthropicApiKey = ?;
configurable string anthropicModel = ?;

final http:Client anthropicClient = check new ("https://api.anthropic.com/v1", timeout = 60);

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

final ToolDefinition & readonly OPEN_CONCEPT_TOOL = {
    name: "open_concept",
    description: "Open a concept page in the OKF knowledge bundle by following a " +
        "link/id copied verbatim from the document you're currently viewing " +
        "(e.g. 'datasets/index.md', '/tables/users.md', '../tables/index.md').",
    input_schema: {
        properties: {
            path: {
                'type: "string",
                description: "The link path or concept id to open, copied exactly as it appears in the markdown you just read."
            }
        },
        required: ["path"]
    }
};

isolated function callMessagesApi(ChatMessage[] chatMessages, boolean includeTools = true) returns MessagesResponse|error {
    MessagesRequest requestPayload = includeTools ? {
            model: anthropicModel,
            max_tokens: 2048,
            system: SYSTEM_PROMPT,
            messages: chatMessages,
            tools: [OPEN_CONCEPT_TOOL]
        } : {
            model: anthropicModel,
            max_tokens: 2048,
            system: SYSTEM_PROMPT,
            messages: chatMessages
        };

    MessagesResponse messagesResponse = check anthropicClient->/messages.post(
        requestPayload,
        headers = {"x-api-key": anthropicApiKey, "anthropic-version": "2023-06-01"}
    );
    return messagesResponse;
}
