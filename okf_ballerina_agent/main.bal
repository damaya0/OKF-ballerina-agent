import ballerina/ai;
import ballerina/io;
import ballerina/log;

configurable string bundleRootPath = ?;
configurable int maxNavigationSteps = ?;

public function main(string question) returns error? {
    string rootIndexRelativePath = "index.md";
    string rootIndexContent = check readConceptFile(bundleRootPath, rootIndexRelativePath);
    string currentDir = dirnameOf(rootIndexRelativePath);

    string initialUserContent = "Question: " + question +
        "\n\nRoot index of the knowledge bundle (index.md):\n\n" + rootIndexContent;

    ai:ChatMessage[] conversation = [
        {role: "system", content: SYSTEM_PROMPT},
        {role: "user", content: initialUserContent}
    ];

    foreach int _ in 0 ..< maxNavigationSteps {
        ai:ChatAssistantMessage response = check anthropicModelProvider->chat(conversation, tools = [OPEN_CONCEPT_TOOL]);
        conversation.push(response);

        ai:FunctionCall[]? toolCalls = response.toolCalls;
        if toolCalls is () || toolCalls.length() == 0 {
            string? answerText = response.content;
            io:println(answerText ?: "");
            return;
        }

        foreach ai:FunctionCall toolCall in toolCalls {
            string toolName = toolCall.name;
            map<json>? toolArguments = toolCall.arguments;

            string resultText;
            if toolArguments is () {
                resultText = "Error: no arguments received for this tool call";
            } else {
                OpenConceptArgs|error parsedArgs = toolArguments.cloneWithType();
                if parsedArgs is error {
                    string parseErrorMessage = parsedArgs.message();
                    resultText = "Error: could not parse tool arguments: " + parseErrorMessage;
                } else {
                    string linkPath = parsedArgs.path;
                    string|error resolved = resolveConceptLink(currentDir, linkPath);
                    if resolved is error {
                        string resolveErrorMessage = resolved.message();
                        log:printWarn("failed to resolve link", link = linkPath, cause = resolveErrorMessage);
                        resultText = "Error: " + resolveErrorMessage;
                    } else {
                        string relativePath = resolved;
                        string|error fileContent = readConceptFile(bundleRootPath, relativePath);
                        if fileContent is error {
                            log:printWarn("failed to open concept", concept = relativePath);
                            resultText = "Error: no document at '" + linkPath + "'";
                        } else {
                            string concept = fileContent;
                            log:printInfo("opened concept", concept = relativePath);
                            currentDir = dirnameOf(relativePath);
                            resultText = concept;
                        }
                    }
                }
            }

            conversation.push({role: "function", name: toolName, content: resultText});
        }
    }

    log:printWarn("reached navigation step limit, forcing a final answer", maxNavigationSteps = maxNavigationSteps);
    conversation.push({
        role: "user",
        content: "You've reached the exploration limit. Answer now using what you've read so far."
    });
    ai:ChatAssistantMessage finalResponse = check anthropicModelProvider->chat(conversation);
    string? finalAnswer = finalResponse.content;
    io:println(finalAnswer ?: "");
}
