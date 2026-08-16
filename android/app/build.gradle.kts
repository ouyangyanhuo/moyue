plugins {
    id("com.android.application")
    // Flutter Gradle 插件必须在 Android 和 Kotlin Gradle 插件之后应用。
    id("dev.flutter.flutter-gradle-plugin")
}

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

    buildTypes {
        release {
            // TODO：为发布构建添加你自己的签名配置。
            // 目前使用调试密钥签名，以便 `flutter run --release` 可以正常运行。
            signingConfig = signingConfigs.getByName("debug")
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
