package com.zsonit.mengbao

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.zsonit.mengbao.data.AppLog
import com.zsonit.mengbao.data.AutoBackup
import com.zsonit.mengbao.data.Reminders
import com.zsonit.mengbao.data.Store
import com.zsonit.mengbao.data.SyncManager
import com.zsonit.mengbao.ui.MengBaoTheme
import com.zsonit.mengbao.ui.Palette

class MainActivity : ComponentActivity() {

    private val notifPerm = registerForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) Reminders.reschedule(applicationContext)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AutoBackup.init(applicationContext)
        enableEdgeToEdge()
        AppLog.init(applicationContext)
        Store.init(applicationContext)
        // 接种程序表：应用已保存的远程版本 + 每年首次启动检查一次更新
        com.zsonit.mengbao.data.Standards.bootScheduleSync(applicationContext)
        Reminders.init(applicationContext)
        Reminders.reschedule(applicationContext)
        AppLog.isEnabled = Store.settings.showLog
        AppLog.i("Main", "App 启动：${Store.state.children.size} 个宝宝档案")
        // Android 13+ 通知权限：排了提醒但没权限时补问一次
        if (android.os.Build.VERSION.SDK_INT >= 33 &&
            Store.settings.let { it.growthReminderOn || it.todoReminderOn || it.suppReminderOn || it.medReminderOn } &&
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
            android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            notifPerm.launch(android.Manifest.permission.POST_NOTIFICATIONS)
        }
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
