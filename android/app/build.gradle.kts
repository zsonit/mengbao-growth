import java.util.Base64

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.zsonit.mengbao"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.zsonit.mengbao"
        minSdk = 26
        targetSdk = 34
        versionCode = 59
        versionName = "2.10.26"

        resourceConfigurations += listOf("zh", "en")

        // 高德 Android Key 可通过 -Pamap.android.key=xxx 或 gradle.properties 注入。
        // Android Key 需要在高德控制台绑定「包名 + SHA1」，没有 Key 时地图页自动降级为外部导航。
        val amapKey = (project.findProperty("amap.android.key") as String?) ?: ""
        buildConfigField("String", "AMAP_ANDROID_KEY", "\"$amapKey\"")
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    signingConfigs {
        // CI 通过环境变量注入固定 keystore（GitHub Actions Secrets），保证每次发版签名一致，
        // 覆盖安装不再报「签名冲突」。本地无这些环境变量时回落 debug 签名。
        create("ci") {
            val ksB64 = System.getenv("ANDROID_KEYSTORE_BASE64")
            val ksPass = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            val ksAlias = System.getenv("ANDROID_KEY_ALIAS")
            val keyPass = System.getenv("ANDROID_KEY_PASSWORD")
            if (ksB64 != null && ksPass != null && ksAlias != null && keyPass != null) {
                val ksFile = File(rootDir.parent, "ci-signing/mengbao-release.jks")
                ksFile.parentFile.mkdirs()
                ksFile.writeBytes(Base64.getDecoder().decode(ksB64))
                storeFile = ksFile
                storePassword = ksPass
                this.keyAlias = ksAlias
                keyPassword = keyPass
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            val ci = signingConfigs.getByName("ci")
            // 有 CI 签名环境变量就用固定正式签名，否则用 debug 签名保证 APK 可直接安装
            signingConfig = if (ci.storeFile?.exists() == true) ci else signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    lint {
        abortOnError = false
        checkReleaseBuilds = false
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    // 离线中文语音识别（sherpa-onnx，模型在 assets/asr）
    implementation(files("libs/sherpa-classes.jar"))
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.exifinterface:exifinterface:1.3.7")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.3")
    implementation("androidx.activity:activity-compose:1.9.0")
    implementation("androidx.navigation:navigation-compose:2.7.7")

    implementation(platform("androidx.compose:compose-bom:2024.06.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")

    debugImplementation("androidx.compose.ui:ui-tooling")
}
