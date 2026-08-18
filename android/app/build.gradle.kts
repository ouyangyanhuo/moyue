plugins {
    id("com.android.application")
    // Flutter Gradle 插件必须在 Android 和 Kotlin Gradle 插件之后应用。
    id("dev.flutter.flutter-gradle-plugin")
}

// 从环境变量读取发布签名配置（由 GitHub Actions 等 CI 注入）。
// 未配置时回退到 debug 签名，便于本地运行与未签名构建。
val keystorePath = providers.environmentVariable("KEYSTORE_PATH").orNull
val keystorePassword = providers.environmentVariable("KEYSTORE_PASSWORD").orNull
val keyAlias = providers.environmentVariable("KEY_ALIAS").orNull
val keyPassword = providers.environmentVariable("KEY_PASSWORD").orNull
val hasReleaseSigning = listOf(keystorePath, keystorePassword, keyAlias, keyPassword)
    .all { !it.isNullOrBlank() }

android {
    namespace = "com.moyue.application"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO：请指定你自己的唯一 Application ID
        //（https://developer.android.com/studio/build/application-id.html）。
        applicationId = "com.moyue.application"
        // 你可以根据应用程序需求更新以下值。
        // 更多信息请参见：https://flutter.dev/to/review-gradle-config。
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // 使用 pubspec.yaml 中的版本号。使用拆分 APK 时，Flutter 会自动加上 1000 * ABI_VERSION。
        //（https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions）
        // 构建时指定 `-P force-version-code-ignoring-abi=true` 参数，
        // 可以强制使用 versionCode 的值。
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystorePath!!)
                storePassword = keystorePassword
                keyAlias = keyAlias
                keyPassword = keyPassword
            }
        }
    }

    buildTypes {
        release {
            // 已配置签名环境变量（KEYSTORE_PATH 等，由 CI 注入）时使用正式签名，
            // 否则使用 debug 密钥签名，方便本地运行和未签名构建。
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
