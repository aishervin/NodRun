package com.example.nodrun.data

import android.content.Context
import java.io.File

class WorkspaceManager(private val context: Context) {
    private val rootDir: File
        get() = File(context.filesDir, "nodrun_workspace").apply {
            try {
                if (!exists()) {
                    mkdirs()
                    File(this, "MainActivity.kt").writeText("package com.example.app\n\nfun main() {\n    println(\"Hello NodRun\")\n}")
                    File(this, "config.json").writeText("{\n  \"name\": \"NodRun Project\",\n  \"version\": \"1.0.0\"\n}")
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

    fun listFiles(): List<WorkspaceFile> {
        val result = mutableListOf<WorkspaceFile>()
        try {
            walkDirectory(rootDir, rootDir, result)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return result
    }

    private fun walkDirectory(currentDir: File, baseDir: File, list: MutableList<WorkspaceFile>) {
        currentDir.listFiles()?.forEach { file ->
            if (file.isDirectory) {
                walkDirectory(file, baseDir, list)
            } else {
                val relativePath = file.absolutePath.removePrefix(baseDir.absolutePath)
                list.add(
                    WorkspaceFile(
                        name = file.name,
                        path = relativePath,
                        content = try { file.readText() } catch (e: Exception) { "" },
                        language = if (file.extension == "kt") "kotlin" else "text"
                    )
                )
            }
        }
    }

    fun saveFile(path: String, content: String) {
        try {
            val file = File(rootDir, path)
            file.parentFile?.mkdirs()
            file.writeText(content)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun createFile(path: String, initialContent: String = "") {
        try {
            val file = File(rootDir, path)
            file.parentFile?.mkdirs()
            file.writeText(initialContent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun deleteFile(path: String) {
        try {
            val file = File(rootDir, path)
            if (file.exists()) {
                file.delete()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
