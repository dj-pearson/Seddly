package com.pearsonmedia.seddly.service

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.FileProvider
import com.pearsonmedia.seddly.data.local.dao.CommitmentDao
import com.pearsonmedia.seddly.data.local.dao.EntityDao
import com.pearsonmedia.seddly.data.local.dao.PrivacyAuditDao
import com.pearsonmedia.seddly.data.local.entity.CommitmentEntity
import com.pearsonmedia.seddly.data.local.entity.EntityProfile
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.first
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton

@Serializable
data class ExportCommitment(
    val id: String,
    val entityName: String,
    val summary: String,
    val status: String,
    val category: String,
    val deadline: String? = null,
    val dollarAmount: Double? = null,
    val confidenceScore: Int,
    val source: String,
    val notes: String? = null,
    val createdAt: String,
    val updatedAt: String
)

@Serializable
data class ExportData(
    val exportDate: String,
    val commitmentCount: Int,
    val entityCount: Int,
    val commitments: List<ExportCommitment>,
    val entities: List<String>
)

/**
 * Data export service for CSV and JSON formats.
 * Mirrors the iOS DataExportService with:
 * - CSV export with all commitment fields
 * - JSON export with structured data
 * - Android share sheet for sharing exported files
 * - Includes entity profiles and audit log count
 */
@Singleton
class DataExportService @Inject constructor(
    @ApplicationContext private val context: Context,
    private val commitmentDao: CommitmentDao,
    private val entityDao: EntityDao,
    private val privacyAuditDao: PrivacyAuditDao
) {
    private val json = Json { prettyPrint = true; encodeDefaults = true }
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
    private val fileDateFormat = SimpleDateFormat("yyyy-MM-dd_HHmmss", Locale.US)

    /**
     * Export all data as CSV and share via system share sheet.
     */
    suspend fun exportCSV(): File? {
        return try {
            val commitments = commitmentDao.observeAll().first()
            val csv = buildCSV(commitments)
            val file = writeToFile("seddly_export_${fileDateFormat.format(Date())}.csv", csv)
            Log.i(TAG, "CSV export: ${commitments.size} commitments")
            file
        } catch (e: Exception) {
            Log.e(TAG, "CSV export failed", e)
            null
        }
    }

    /**
     * Export all data as JSON and share via system share sheet.
     */
    suspend fun exportJSON(): File? {
        return try {
            val commitments = commitmentDao.observeAll().first()
            val entities = entityDao.observeAll().first()

            val exportData = ExportData(
                exportDate = dateFormat.format(Date()),
                commitmentCount = commitments.size,
                entityCount = entities.size,
                commitments = commitments.map { it.toExport() },
                entities = entities.map { it.name }
            )

            val jsonString = json.encodeToString(exportData)
            val file = writeToFile("seddly_export_${fileDateFormat.format(Date())}.json", jsonString)
            Log.i(TAG, "JSON export: ${commitments.size} commitments, ${entities.size} entities")
            file
        } catch (e: Exception) {
            Log.e(TAG, "JSON export failed", e)
            null
        }
    }

    /**
     * Launch Android share sheet with the exported file.
     */
    fun shareFile(file: File) {
        try {
            val uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file
            )

            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                type = if (file.extension == "csv") "text/csv" else "application/json"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            context.startActivity(Intent.createChooser(shareIntent, "Export Seddly Data")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: Exception) {
            Log.e(TAG, "Share failed", e)
        }
    }

    private fun buildCSV(commitments: List<CommitmentEntity>): String {
        val sb = StringBuilder()
        sb.appendLine("id,entity_name,summary,status,category,deadline,dollar_amount,confidence_score,source,notes,created_at,updated_at")

        for (c in commitments) {
            sb.appendLine(listOf(
                c.id,
                c.entityName.csvEscape(),
                c.summary.csvEscape(),
                c.status,
                c.category,
                c.deadline?.let { dateFormat.format(Date(it)) } ?: "",
                c.dollarAmount?.toString() ?: "",
                c.confidenceScore.toString(),
                c.source,
                (c.notes ?: "").csvEscape(),
                dateFormat.format(Date(c.createdAt)),
                dateFormat.format(Date(c.updatedAt))
            ).joinToString(","))
        }

        return sb.toString()
    }

    private fun CommitmentEntity.toExport() = ExportCommitment(
        id = id,
        entityName = entityName,
        summary = summary,
        status = status,
        category = category,
        deadline = deadline?.let { dateFormat.format(Date(it)) },
        dollarAmount = dollarAmount,
        confidenceScore = confidenceScore,
        source = source,
        notes = notes,
        createdAt = dateFormat.format(Date(createdAt)),
        updatedAt = dateFormat.format(Date(updatedAt))
    )

    private fun writeToFile(filename: String, content: String): File {
        val exportDir = File(context.cacheDir, "exports").apply { mkdirs() }
        val file = File(exportDir, filename)
        file.writeText(content)
        return file
    }

    private fun String.csvEscape(): String {
        val escaped = this.replace("\"", "\"\"")
        return if (escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"")) {
            "\"$escaped\""
        } else {
            escaped
        }
    }

    companion object {
        private const val TAG = "DataExportService"
    }
}
