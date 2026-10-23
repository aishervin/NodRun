package com.example.nodrun

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.example.nodrun.ui.screens.MainScreen
import com.example.nodrun.ui.theme.NodRunTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            NodRunTheme {
                MainScreen()
            }
        }
    }
}
