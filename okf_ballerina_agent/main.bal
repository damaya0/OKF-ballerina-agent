import ballerina/ai;
import ballerina/io;
import ballerina/log;

configurable string bundleRootPath = ?;
configurable int maxNavigationSteps = ?;

public function main(string question = "") returns error? {
    string askedQuestion = question;
    if askedQuestion.trim().length() == 0 {
        askedQuestion = io:readln("Question: ");
    }

    string rootIndexRelativePath = "index.md";
    string rootIndexContent = check readConceptFile(bundleRootPath, rootIndexRelativePath);
    string currentDir = dirnameOf(rootIndexRelativePath);

    string initialUserContent = "Question: " + askedQuestion +
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
            string resultText;
            do {
                ConceptResult conceptResult = check openConcept(toolCall, currentDir, bundleRootPath);
                currentDir = conceptResult.newCurrentDir;
                resultText = conceptResult.content;
            } on fail error err {
                resultText = "Error: " + err.message();
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
