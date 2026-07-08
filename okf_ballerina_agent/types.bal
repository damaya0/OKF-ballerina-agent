// Wire types for the Anthropic Messages API (https://api.anthropic.com/v1/messages).
// Field names follow the API's own JSON keys (snake_case) rather than the
// two-word-camelCase convention, since these records bind directly to the
// external payload.

type TextBlock record {|
    "text" 'type = "text";
    string text;
|};

type OpenConceptInput record {|
    string path;
|};

type ToolUseBlock record {|
    "tool_use" 'type = "tool_use";
    string id;
    string name;
    OpenConceptInput input;
|};

// What Claude can send back in one turn: prose, and/or a request to open a concept.
type AssistantContentBlock TextBlock|ToolUseBlock;

type ToolResultBlock record {|
    "tool_result" 'type = "tool_result";
    string tool_use_id;
    string content;
    boolean is_error?;
|};

type ChatMessage record {|
    string role;
    string|AssistantContentBlock[]|ToolResultBlock[] content;
|};

type OpenConceptSchemaProperty record {|
    string 'type;
    string description;
|};

type OpenConceptProperties record {|
    OpenConceptSchemaProperty path;
|};

type OpenConceptInputSchema record {|
    string 'type = "object";
    OpenConceptProperties properties;
    string[] required;
|};

type ToolDefinition record {|
    string name;
    string description;
    OpenConceptInputSchema input_schema;
|};

type MessagesRequest record {|
    string model;
    int max_tokens;
    string system;
    ChatMessage[] messages;
    ToolDefinition[] tools?;
|};

type Usage record {|
    int input_tokens;
    int output_tokens;
|};

type MessagesResponse record {|
    string id;
    string 'type;
    string role;
    string model;
    AssistantContentBlock[] content;
    string? stop_reason;
    string? stop_sequence;
    Usage usage;
|};
