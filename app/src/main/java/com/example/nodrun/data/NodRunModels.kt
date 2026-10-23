package com.example.nodrun.data

data class ChatMessage(
    val id: String,
    val sender: MessageSender,
    val text: String,
    val timestamp: Long = System.currentTimeMillis()
)

enum class MessageSender {
    USER, AGENT, SYSTEM
}

data class WorkspaceFile(
    val name: String,
    val path: String,
    val content: String,
    val language: String
)

data class AgentLog(
    val id: String,
    val title: String,
    val detail: String,
    val status: LogStatus,
    val timestamp: Long = System.currentTimeMillis()
)

enum class LogStatus {
    SUCCESS, RUNNING, ERROR, INFO
}
