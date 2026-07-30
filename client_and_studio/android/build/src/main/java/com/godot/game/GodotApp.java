/**************************************************************************/
/*  GodotApp.java                                                         */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/

package com.godot.game;

import org.godotengine.godot.Godot;
import org.godotengine.godot.GodotActivity;
import org.godotengine.godot.GodotLib;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

import androidx.activity.EdgeToEdge;
import androidx.core.splashscreen.SplashScreen;

/**
 * Custom Godot Activity for Luani Client running 100% Native Godot UI.
 */
public class GodotApp extends GodotActivity {
	private static GodotApp instance;
	public static String pendingUri = "";

	public static String getPendingUri() {
		String uri = pendingUri;
		pendingUri = ""; // clear after reading
		return uri;
	}

	public static GodotApp getInstance() {
		return instance;
	}

	static {
		// .NET libraries.
		if (BuildConfig.FLAVOR.equals("mono")) {
			try {
				Log.v("GODOT", "Loading System.Security.Cryptography.Native.Android library");
				System.loadLibrary("System.Security.Cryptography.Native.Android");
			} catch (UnsatisfiedLinkError e) {
				Log.e("GODOT", "Unable to load System.Security.Cryptography.Native.Android library");
			}
		}
	}

	private final Runnable updateWindowAppearance = () -> {
		Godot godot = getGodot();
		if (godot != null) {
			godot.enableImmersiveMode(godot.isInImmersiveMode(), true);
			godot.enableEdgeToEdge(godot.isInEdgeToEdgeMode(), true);
			godot.setSystemBarsAppearance();
		}
	};

	@Override
	public void onCreate(Bundle savedInstanceState) {
		instance = this;
		SplashScreen splashScreen = SplashScreen.installSplashScreen(this);
		EdgeToEdge.enable(this);
		super.onCreate(savedInstanceState);

		Godot godot = getGodot();
		if (godot != null && godot.getDisableGodotSplash()) {
			splashScreen.setKeepOnScreenCondition(() -> godot.getRunStatus() != Godot.RunStatus.STARTED);
		}

		// Automatic APK Cache Clearing on Version Code Bump
		try {
			android.content.SharedPreferences prefs = getSharedPreferences("luani_app_prefs", MODE_PRIVATE);
			int lastVersionCode = prefs.getInt("version_code", -1);
			int currentVersionCode = BuildConfig.VERSION_CODE;
			if (lastVersionCode != currentVersionCode) {
				Log.i("GODOT_APP", "[Luani Cache] New version detected (" + currentVersionCode + "). Purging stale app cache...");
				clearAppCache(getCacheDir());
				clearAppCache(getExternalCacheDir());
				prefs.edit().putInt("version_code", currentVersionCode).apply();
			}
		} catch (Exception e) {
			Log.e("GODOT_APP", "Error executing cache clear check: " + e.getMessage());
		}
	}

	private void clearAppCache(java.io.File dir) {
		if (dir != null && dir.isDirectory()) {
			java.io.File[] files = dir.listFiles();
			if (files != null) {
				for (java.io.File f : files) {
					if (f.isDirectory()) {
						clearAppCache(f);
					}
					f.delete();
				}
			}
		}
	}

	@Override
	public void onNewIntent(Intent intent) {
		super.onNewIntent(intent);
		if (intent != null && intent.getData() != null) {
			String url = intent.getData().toString();
			Log.d("LuaniBridge", "Captured URI: " + url);
			pendingUri = url;
		}
	}

	@Override
	public void onResume() {
		super.onResume();
		updateWindowAppearance.run();
	}

	@Override
	public void onGodotMainLoopStarted() {
		super.onGodotMainLoopStarted();
		runOnUiThread(updateWindowAppearance);
		Log.i("GODOT_APP", "[Luani Native UI] Native Godot UI active on launch.");
	}

	@Override
	public void onGodotForceQuit(Godot instance) {
		if (!BuildConfig.FLAVOR.equals("instrumented")) {
			super.onGodotForceQuit(instance);
		}
	}

	@Override
	protected boolean isPiPEnabled() {
		return true;
	}
}
