package com.zsonit.mengbao

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.zsonit.mengbao.data.AppLog
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.data.SyncManager
import com.zsonit.mengbao.ui.MengBaoTheme
import com.zsonit.mengbao.ui.Palette

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        AppLog.init(applicationContext)
        Store.init(applicationContext)
        AppLog.isEnabled = Store.settings.showLog
        AppLog.i("Main", "App 启动：${Store.state.children.size} 个宝宝档案")
        setContent {
            val dark = Store.settings.darkMode
            MengBaoTheme(darkOverride = dark) {
                Surface(modifier = Modifier.fillMaxSize(), color = Palette.background) {
                    MengBaoApp()
                }
            }
        }
    }

    // 回到前台：立即同步一次并开启自动刷新；退到后台：停止轮询，不耗电
    override fun onResume() {
        super.onResume()
        SyncManager.onForeground()
    }

    override fun onPause() {
        super.onPause()
        SyncManager.onBackground()
    }
}
