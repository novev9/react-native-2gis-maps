package com.dgismaps

import android.content.Context
import ru.dgis.sdk.DGis
import ru.dgis.sdk.PersonalDataCollectionConsent
import ru.dgis.sdk.platform.HttpOptions
import ru.dgis.sdk.platform.KeyFromAsset
import ru.dgis.sdk.platform.KeyFromString
import ru.dgis.sdk.platform.KeySource
import ru.dgis.sdk.platform.LogLevel
import ru.dgis.sdk.platform.LogOptions
import ru.dgis.sdk.Context as DGisContext

object DGisSdkHolder {
  private val lock = Any()
  private var sdkContext: DGisContext? = null
  private var initializedKey: String? = null

  val isInitialized: Boolean
    get() = synchronized(lock) { sdkContext != null }

  fun initialize(context: Context, apiKey: String, logLevel: String?): Boolean = synchronized(lock) {
    val existingKey = initializedKey
    if (existingKey != null) {
      if (existingKey == apiKey) {
        return@synchronized true
      }
      throw IllegalStateException("2GIS SDK is already initialized with another key")
    }

    val level = when (logLevel) {
      "verbose" -> LogLevel.VERBOSE
      "warning" -> LogLevel.WARNING
      "error" -> LogLevel.ERROR
      "off" -> LogLevel.OFF
      else -> LogLevel.INFO
    }

    val keySource = resolveKeySource(context, apiKey)

    sdkContext = DGis.initialize(
      appContext = context.applicationContext,
      httpOptions = HttpOptions(useCache = true),
      logOptions = LogOptions(systemLevel = level),
      keySource = keySource,
      dataCollectConsent = PersonalDataCollectionConsent.GRANTED
    )
    initializedKey = apiKey
    true
  }

  private fun resolveKeySource(context: Context, apiKey: String): KeySource {
    // Prefer the signed binary key file shipped as an asset.
    val assets = runCatching { context.applicationContext.assets.list("") ?: emptyArray<String>() }
      .getOrDefault(emptyArray())
    if (assets.contains("dgissdk.key")) {
      return KeySource(KeyFromAsset("dgissdk.key"))
    }
    return KeySource(KeyFromString(apiKey))
  }

  fun requireContext(): DGisContext = synchronized(lock) {
    sdkContext ?: throw IllegalStateException(
      "2GIS SDK is not initialized. Call DgisMapsModule.initialize(...) before mounting DgisMapsView."
    )
  }

  fun contextOrNull(): DGisContext? = synchronized(lock) {
    sdkContext
  }
}
