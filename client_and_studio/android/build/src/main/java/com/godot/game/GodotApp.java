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

import android.app.Dialog;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.net.Uri;
import android.net.http.SslError;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.SslErrorHandler;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import androidx.activity.EdgeToEdge;
import androidx.core.splashscreen.SplashScreen;

/**
 * Custom Godot Activity with Native In-App WebView Overlay via Dialog for Luani.
 */
public class GodotApp extends GodotActivity {
	private static GodotApp instance;
	private static Dialog webDialog;
	public static String pendingUri = "";

	public static String getPendingUri() {
		String uri = pendingUri;
		pendingUri = ""; // clear after reading
		return uri;
	}

	public static GodotApp getInstance() {
		return instance;
	}

	public static void showWebPortalStatic() {
		if (instance != null) {
			instance.showWebPortal();
		}
	}

	public static void hideWebPortalStatic() {
		hideWebPortal();
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
			hideWebPortal();
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
		// Native Godot UI renders on launch — web portal dialog bypassed
		Log.i("GODOT_APP", "[Luani Native UI] Native Godot UI active on launch.");
	}

	public void showWebPortal() {
		runOnUiThread(new Runnable() {
			@Override
			public void run() {
				try {
					Log.i("GODOT_WEBVIEW", "showWebPortal() invoked on UI Thread.");
					if (webDialog == null) {
						webDialog = new Dialog(GodotApp.this, android.R.style.Theme_Black_NoTitleBar_Fullscreen);
						webDialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
						Window window = webDialog.getWindow();
						if (window != null) {
							window.setBackgroundDrawable(new ColorDrawable(Color.BLACK));
							window.setFlags(
								WindowManager.LayoutParams.FLAG_FULLSCREEN | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
								WindowManager.LayoutParams.FLAG_FULLSCREEN | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
							);
							window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
						}

						WebView.setWebContentsDebuggingEnabled(true);
						WebView webView = new WebView(GodotApp.this);
						webView.setBackgroundColor(Color.BLACK);
						webView.setLayerType(View.LAYER_TYPE_HARDWARE, null);
						webView.setWebChromeClient(new WebChromeClient());

						WebSettings settings = webView.getSettings();
						settings.setJavaScriptEnabled(true);
						settings.setDomStorageEnabled(true);
						settings.setDatabaseEnabled(true);
						settings.setAllowFileAccess(true);
						settings.setAllowContentAccess(true);
						settings.setMediaPlaybackRequiresUserGesture(false);
						settings.setUseWideViewPort(true);
						settings.setLoadWithOverviewMode(true);
						settings.setJavaScriptCanOpenWindowsAutomatically(true);
						settings.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);

						webView.setWebViewClient(new WebViewClient() {
							@Override
							public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
								if (request != null && request.getUrl() != null) {
									String url = request.getUrl().toString();
									if (url.startsWith("luani://") || url.contains("join?server=")) {
										Log.d("LuaniBridge", "Captured URI: " + url);
										pendingUri = url;
										hideWebPortal();
										return true;
									}
								}
								return false;
							}

							@Override
							public boolean shouldOverrideUrlLoading(WebView view, String url) {
								if (url != null && (url.startsWith("luani://") || url.contains("join?server="))) {
									Log.d("LuaniBridge", "Captured URI: " + url);
									pendingUri = url;
									hideWebPortal();
									return true;
								}
								return false;
							}

							@Override
							public void onReceivedSslError(WebView view, SslErrorHandler handler, SslError error) {
								if (handler != null) {
									handler.proceed();
								}
							}

							@Override
							public void onPageFinished(WebView view, String url) {
								super.onPageFinished(view, url);
								Log.i("GODOT_WEBVIEW", "onPageFinished loaded URL: " + url);
								String js = "if (!localStorage.getItem('luani_token')) {" +
									"  fetch('/api/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ username: 'LuaniAlt', password: 'ygs6j&R6^pOfDZ' }) })" +
									"  .then(r => r.json())" +
									"  .then(data => {" +
									"    if (data.success && data.token) {" +
									"      localStorage.setItem('luani_token', data.token);" +
									"      console.log('Automated login succeeded for LuaniAlt.');" +
									"      location.reload();" +
									"    }" +
									"  });" +
									"}";
								view.evaluateJavascript(js, null);
							}
						});

						webDialog.setContentView(webView, new ViewGroup.LayoutParams(
							ViewGroup.LayoutParams.MATCH_PARENT,
							ViewGroup.LayoutParams.MATCH_PARENT
						));
						if (window != null) {
							window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
						}
						webView.loadUrl("https://www.luani.fyi");
						Log.i("GODOT_WEBVIEW", "Native Android WebView Dialog initialized loading https://www.luani.fyi");
					}
					webDialog.show();
					Log.i("GODOT_WEBVIEW", "webDialog.show() executed successfully.");
				} catch (Exception e) {
					Log.e("GODOT_WEBVIEW", "Error showing WebView Dialog: " + e.getMessage(), e);
				}
			}
		});
	}

	public static void hideWebPortal() {
		if (instance != null) {
			instance.runOnUiThread(() -> {
				try {
					if (webDialog != null && webDialog.isShowing()) {
						webDialog.dismiss();
						Log.i("GODOT_WEBVIEW", "Native Android WebView Dialog dismissed.");
					}
				} catch (Exception e) {
					Log.e("GODOT_WEBVIEW", "Error dismissing WebView Dialog: " + e.getMessage(), e);
				}
			});
		}
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
