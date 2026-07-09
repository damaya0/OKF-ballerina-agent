$questions = @(
    "What MCP tools are available for CIAM, and what do they do?",
    "How do I update a customer's email address across all backend systems?",
    "What loyalty system does the Engage API manage, and what operations does it support?",
    "What can I retrieve from the ProfileDB MCP tools?",
    "What is SFMC used for and what MCP tools does it expose?",
    "What ELK index families are queried by the MCP tools, and what do they track?",
    "What fields are available in the CIAM logs, and what kind of events do they capture?",
    "What kind of information do the WSO2 integration logs contain, such as latency or correlation tracking?",
    "How are notification delivery failures tracked in the integration logs?",
    "Give an example of a real-world web authentication failure scenario from the ELK CIAM web scenarios document.",
    "What steps should I take when a customer says they can't log in?",
    "A customer says their Unity Points balance looks wrong. What's the diagnostic process?",
    "What should I check if a customer's personal information like email, phone, or address looks incorrect across channels?",
    "How do I investigate a customer's free play issues?",
    "How can I view a customer's complete activity history?",
    "How do I analyze system-wide login patterns or investigate an authentication issue affecting many users?",
    "What are the login eligibility rules? Who is allowed or restricted from logging in?",
    "Is there a connection between the login rules and the login issue troubleshooting guide? Explain how they relate.",
    "What categories of issues does the troubleshooting playbook cover?",
    "If I'm not sure which runbook to use for a customer issue, where should I start?",
    "A customer can't log in AND their Unity Points look wrong. Which two runbooks should I combine, and what's the first diagnostic step for each?",
    "What's the difference between the CIAM MCP tools and the ELK CIAM logs? When would I use one versus the other?",
    "What is the refund policy for cancelled orders?",
    "How many badge classes are there on Stack Overflow?"
)

Set-Location "C:\Users\Damsith Adikari\SupportOKF\okf_ballerina_agent"

$outFile = "C:\Users\Damsith Adikari\SupportOKF\okf_ballerina_agent\test_battery_results.txt"
Remove-Item $outFile -ErrorAction SilentlyContinue

$javaExe = "C:\Program Files\Ballerina\dependencies\jdk-21.0.5+11-jre\bin\java.exe"
$jar = "C:\Users\Damsith Adikari\SupportOKF\okf_ballerina_agent\target\bin\okf_ballerina_agent.jar"

for ($i = 0; $i -lt $questions.Length; $i++) {
    $q = $questions[$i]
    $n = $i + 1
    Add-Content -Path $outFile -Value "===== Q$n ====="
    Add-Content -Path $outFile -Value "QUESTION: $q"
    $start = Get-Date
    $output = & $javaExe -jar $jar $q 2>&1
    $elapsed = (Get-Date) - $start
    Add-Content -Path $outFile -Value "--- output ---"
    Add-Content -Path $outFile -Value ($output | Out-String)
    Add-Content -Path $outFile -Value "--- elapsed: $($elapsed.TotalSeconds) sec ---"
    Add-Content -Path $outFile -Value ""
}

Add-Content -Path $outFile -Value "ALL DONE: $($questions.Length) questions run."
