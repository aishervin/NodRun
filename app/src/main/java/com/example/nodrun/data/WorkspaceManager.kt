package com.example.nodrun.data

import android.content.Context
import java.io.File

class WorkspaceManager(private val context: Context) {
    private val rootDir: File
        get() = File(context.filesDir, "nodrun_workspace").apply {
            if (!exists()) {
                mkdirs()
                // Create sample files
                File(this, "MainActivity.kt").writeText("package com.example.app\n\nfun main() {\n    println(\"Hello NodRun\")\n}")
                File(this, "config.json").writeText("{\n  \"name\": \"NodRun Project\",\n  \"version\": \"1.0.0\"\n}")
            }
        }

    fun listFiles(): List<WorkspaceFile> {
        val result = mutableListOf<WorkspaceFile>()
        walkDirectory(rootDir, rootDir, result)
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
                        content = file.readText(),
                        language = if (file.extension == "kt") "kotlin" else "text"
                    )
                )
            }
        }
    }

    fun saveFile(path: String, content: String) {
        val file = File(rootDir, path)
        if (!file.parentFile?.exists()!!) {
            file.parentFile?.mkdirs()
        }
        file.writeText(content)
    }

    fun createFile(path: String, initialContent: String = "") {
        val file = File(rootDir, path)
        if (!file.parentFile?.exists()!!) {
            file.parentFile?.mkdirs()
        }
        file.writeText(initialContent)
    }

    fun deleteFile(path: String) {
        val file = File(rootDir, path)
        if (file.exists()) {
            file.delete()
        }
    }
}
