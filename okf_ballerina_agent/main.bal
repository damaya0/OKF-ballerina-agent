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

    ChatMessage[] conversation = [
        {role: "user", content: initialUserContent}
    ];

    foreach int _ in 0 ..< maxNavigationSteps {
        MessagesResponse response = check callMessagesApi(conversation);

        ToolUseBlock[] toolUseBlocks = [];
        string answerText = "";
        foreach AssistantContentBlock block in response.content {
            if block is ToolUseBlock {
                toolUseBlocks.push(block);
            } else {
                string blockText = block.text;
                answerText = answerText + blockText;
            }
        }

        if toolUseBlocks.length() == 0 {
            io:println(answerText);
            return;
        }

        conversation.push({role: "assistant", content: response.content});

        ToolResultBlock[] toolResults = [];
        foreach ToolUseBlock toolUse in toolUseBlocks {
            string linkPath = toolUse.input.path;
            string toolUseId = toolUse.id;

            string|error resolved = resolveConceptLink(currentDir, linkPath);
            if resolved is error {
                string resolveErrorMessage = resolved.message();
                log:printWarn("failed to resolve link", link = linkPath, cause = resolveErrorMessage);
                toolResults.push({tool_use_id: toolUseId, content: "Error: " + resolveErrorMessage, is_error: true});
                continue;
            }
            string relativePath = resolved;

            string|error fileContent = readConceptFile(bundleRootPath, relativePath);
            if fileContent is error {
                log:printWarn("failed to open concept", concept = relativePath);
                toolResults.push({tool_use_id: toolUseId, content: "Error: no document at '" + linkPath + "'", is_error: true});
                continue;
            }
            string concept = fileContent;

            log:printInfo("opened concept", concept = relativePath);
            currentDir = dirnameOf(relativePath);
            toolResults.push({tool_use_id: toolUseId, content: concept});
        }

        conversation.push({role: "user", content: toolResults});
    }

    log:printWarn("reached navigation step limit, forcing a final answer", maxNavigationSteps = maxNavigationSteps);
    conversation.push({
        role: "user",
        content: "You've reached the exploration limit. Answer now using what you've read so far."
    });
    MessagesResponse finalResponse = check callMessagesApi(conversation, includeTools = false);
    string finalAnswer = "";
    foreach AssistantContentBlock block in finalResponse.content {
        if block is TextBlock {
            string blockText = block.text;
            finalAnswer = finalAnswer + blockText;
        }
    }
    io:println(finalAnswer);
}
