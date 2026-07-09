import ballerina/ai;
import ballerina/io;
import ballerina/log;

configurable string bundleRootPath = ?;

public function main(string question = "") returns error? {
    string askedQuestion = question;
    if askedQuestion.trim().length() == 0 {
        askedQuestion = io:readln("Question: ");
    }

    string rootIndexRelativePath = "index.md";
    string rootIndexContent = check readConceptFile(bundleRootPath, rootIndexRelativePath);

    ai:Agent okfAgent = check new (
        systemPrompt = SYSTEM_PROMPT,
        model = anthropicModelProvider,
        tools = [open_concept]
    );

    // Prepend the root index so the agent knows where to start navigating.
    string userMessage = "Question: " + askedQuestion +
        "\n\nindex.md file of the knowledge bundle:\n\n" + rootIndexContent;

    string answer = check okfAgent.run(userMessage);
    io:println(answer);
}

# Opens a page in the OKF knowledge bundle -- a concept, or a directory's
# index page -- by its concept id, copied verbatim from the markdown
# currently being viewed.
# + conceptId - The concept id to open. Always a concept id, nothing else.
# + return - The markdown content of the file, or an error string.
@ai:AgentTool
public isolated function open_concept(string conceptId) returns string|error {
    string relativePath = check getPathFromMap(conceptId);
    string conceptContent = check readConceptFile(bundleRootPath, relativePath);
    log:printInfo("opened concept", concept = relativePath);
    return conceptContent;
}

