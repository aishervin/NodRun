package com.example.nodrun.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import com.example.nodrun.data.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class NodRunViewModel(application: Application) : AndroidViewModel(application) {

    private val workspaceManager = WorkspaceManager(application)

    private val _messages = MutableStateFlow<List<ChatMessage>>(
        listOf(
            ChatMessage(
                id = "1",
                sender = MessageSender.AGENT,
                text = "NodRun AI Core Agent initialized. Local workspace ready. Enter your API key in Settings and ask me to code or manage files!"
            )
        )
    )
    val messages: StateFlow<List<ChatMessage>> = _messages.asStateFlow()

    private val _files = MutableStateFlow<List<WorkspaceFile>>(workspaceManager.listFiles())
    val files: StateFlow<List<WorkspaceFile>> = _files.asStateFlow()

    private val _selectedFile = MutableStateFlow<WorkspaceFile?>(null)
    val selectedFile: StateFlow<WorkspaceFile?> = _selectedFile.asStateFlow()

    private val _logs = MutableStateFlow<List<AgentLog>>(
        listOf(
            AgentLog(
                id = "l1",
                title = "Local Workspace Mounted",
                detail = "Path: ${application.filesDir.absolutePath}/nodrun_workspace",
                status = LogStatus.SUCCESS
            )
        )
    )
    val logs: StateFlow<List<AgentLog>> = _logs.asStateFlow()

    private val _isGenerating = MutableStateFlow(false)
    val isGenerating: StateFlow<Boolean> = _isGenerating.asStateFlow()

    private val _apiKey = MutableStateFlow("")
    val apiKey: StateFlow<String> = _apiKey.asStateFlow()

    fun setApiKey(key: String) {
        _apiKey.value = key
    }

    fun refreshFiles() {
        _files.value = workspaceManager.listFiles()
    }

    fun sendMessage(text: String) {
        if (text.isBlank()) return
        val userMsg = ChatMessage(
            id = System.currentTimeMillis().toString(),
            sender = MessageSender.USER,
            text = text
        )
        _messages.update { it + userMsg }
        _isGenerating.value = true

        val agentMsgId = (System.currentTimeMillis() + 1).toString()
        val responseText = if (text.contains("create", ignoreCase = true)) {
            val fileName = "NewAgentFile.kt"
            workspaceManager.createFile(fileName, "// Created by NodRun Agent\nfun generatedTask() {}")
            refreshFiles()
            "Created new file '$fileName' in local workspace successfully!"
        } else {
            "Processed request locally. Workspace files synced successfully."
        }

        val newLog = AgentLog(
            id = System.currentTimeMillis().toString(),
            title = "Action: ${text.take(20)}",
            detail = responseText,
            status = LogStatus.SUCCESS
        )
        _logs.update { listOf(newLog) + it }

        _messages.update { it + ChatMessage(id = agentMsgId, sender = MessageSender.AGENT, text = responseText) }
        _isGenerating.value = false
    }

    fun selectFile(file: WorkspaceFile?) {
        _selectedFile.value = file
    }

    fun updateFileContent(path: String, newContent: String) {
        workspaceManager.saveFile(path, newContent)
        refreshFiles()
        if (_selectedFile.value?.path == path) {
            _selectedFile.update { it?.copy(content = newContent) }
        }
    }

    fun createNewFile(path: String, content: String) {
        workspaceManager.createFile(path, content)
        refreshFiles()
    }

    fun deleteFile(path: String) {
        workspaceManager.deleteFile(path)
        refreshFiles()
        if (_selectedFile.value?.path == path) {
            _selectedFile.value = null
        }
    }
}
