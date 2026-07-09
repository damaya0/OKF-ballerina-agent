// Model setup and the two one-shot LLM calls this tool needs:
//   1. classifyConcept          -- classify one raw markdown file's frontmatter.
//   2. synthesizeDirDescription -- write a short blurb for a subdirectory
//      that groups more than one concept, for use in its parent's index.md.
//
// Neither call is a multi-turn navigation task, so this talks to
// ai:ModelProvider directly instead of going through ai:Agent (which the
// sibling navigator agent uses for its multi-hop retrieval loop) -- there is
// nothing to navigate here, just one structured-output call per file.
//
// The model is only ever asked to classify a document (type/title/
// description/tags), never to reproduce or rewrite its body: source files in
// a real dataset can run into the thousands of lines, far past what a
// bounded output-token budget could safely reproduce without silent
// truncation. The body is instead carried through verbatim from disk (see
// main.bal), which guarantees no content loss regardless of file size.

import ballerina/ai;
import ballerinax/ai.anthropic as anthropic;

configurable string anthropicApiKey = ?;
configurable string anthropicModelName = ?;

final anthropic:ANTHROPIC_MODEL_NAMES ANTHROPIC_MODEL = check anthropicModelName.ensureType();
final ai:ModelProvider anthropicModelProvider = check new anthropic:ModelProvider(anthropicApiKey, ANTHROPIC_MODEL, maxTokens = 4096);

final string CONVERT_SYSTEM_PROMPT =
    "You classify a single raw markdown document for inclusion in an Open " +
    "Knowledge Format (OKF) bundle -- a directory of markdown files with " +
    "YAML frontmatter, one concept per file. You do NOT rewrite or reproduce " +
    "the document; you only choose its frontmatter metadata. The document's " +
    "body will be carried through unchanged separately.\n\n" +
    "Given the document's concept id (its path within the source dataset) " +
    "and its raw content, decide:\n" +
    "- type: a short label for what kind of concept this is (e.g. 'API " +
    "Reference', 'Issue', 'Rule', 'Playbook', 'Reference'). Pick something " +
    "descriptive; be consistent for documents that clearly belong to the " +
    "same category (e.g. by their directory).\n" +
    "- title: a human-readable display name.\n" +
    "- description: one sentence summarizing the concept.\n" +
    "- tags: up to 5 short cross-cutting tags.\n\n" +
    "You MUST answer by calling the write_concept_doc tool exactly once with " +
    "these fields. Never respond in plain text.";

final string SYNTHESIZE_SYSTEM_PROMPT =
    "You write a single short sentence describing a directory in a knowledge " +
    "bundle, given the titles and descriptions of the concepts directly " +
    "inside it. Summarize what the directory contains as a whole; do not " +
    "just repeat one child's description. Respond with plain text: the " +
    "sentence only, no preamble, no quotes.";

type WriteConceptDocArgs record {|
    string 'type;
    string title;
    string description;
    string[] tags;
|};

final ai:ChatCompletionFunctions & readonly WRITE_CONCEPT_DOC_TOOL = {
    name: "write_concept_doc",
    description: "Submit the frontmatter classification for the source markdown you were given.",
    parameters: {
        'type: "object",
        properties: {
            'type: {'type: "string", description: "Short label for the kind of concept, e.g. 'API Reference', 'Issue', 'Rule'."},
            title: {'type: "string", description: "Human-readable display name."},
            description: {'type: "string", description: "One sentence summarizing the concept."},
            tags: {'type: "array", items: {'type: "string"}, description: "Up to 5 short cross-cutting tags."}
        },
        required: ["type", "title", "description", "tags"]
    }
};

isolated function classifyConcept(string conceptId, string rawContent) returns OkfClassification|error {
    ai:ChatMessage[] messages = [
        {role: "system", content: CONVERT_SYSTEM_PROMPT},
        {
            role: "user",
            content: string `Concept id: ${conceptId}` + "\n\nRaw content:\n\n" + rawContent
        }
    ];

    ai:ChatAssistantMessage response = check anthropicModelProvider->chat(messages, tools = [WRITE_CONCEPT_DOC_TOOL]);
    ai:FunctionCall[]? toolCalls = response.toolCalls;

    if toolCalls is () || toolCalls.length() == 0 {
        // The model answered in plain text instead of calling the tool -- nudge once.
        messages.push(response);
        messages.push({
            role: "user",
            content: "You must call the write_concept_doc tool now with your analysis of the document above, not plain text."
        });
        response = check anthropicModelProvider->chat(messages, tools = [WRITE_CONCEPT_DOC_TOOL]);
        toolCalls = response.toolCalls;
    }

    if toolCalls is () || toolCalls.length() == 0 {
        return error(string `model did not call write_concept_doc for '${conceptId}'`);
    }

    ai:FunctionCall toolCall = toolCalls[0];
    map<json>? toolArguments = toolCall.arguments;
    if toolArguments is () {
        return error(string `write_concept_doc call for '${conceptId}' had no arguments`);
    }

    WriteConceptDocArgs args = check toolArguments.cloneWithType();
    if args.'type.trim().length() == 0 || args.title.trim().length() == 0 {
        return error(string `write_concept_doc call for '${conceptId}' is missing a required field`);
    }

    return {'type: args.'type, title: args.title, description: args.description, tags: args.tags};
}

isolated function synthesizeDirDescription(string dirRelativePath, IndexItem[] children) returns string|error {
    string childList = "";
    foreach int i in 0 ..< children.length() {
        if i > 0 {
            childList = childList + "\n";
        }
        childList = childList + string `- ${children[i].title}: ${children[i].description}`;
    }

    ai:ChatMessage[] messages = [
        {role: "system", content: SYNTHESIZE_SYSTEM_PROMPT},
        {
            role: "user",
            content: string `Directory: ${dirRelativePath}` + "\n\nContents:\n" + childList
        }
    ];

    ai:ChatAssistantMessage response = check anthropicModelProvider->chat(messages);
    string? content = response.content;
    return content is string ? content.trim() : "";
}
