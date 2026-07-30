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

import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.interstitial.InterstitialAd;
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback;

/**
 * Custom Godot Activity for Luani Client running 100% Native Godot UI with real Google AdMob Ads SDK integration.
 */
public class GodotApp extends GodotActivity {
	private static GodotApp instance;
	public static String pendingUri = "";

	public static InterstitialAd mInterstitialAd;
	public static final String AD_UNIT_ID = "ca-app-pub-6798749288294292/8584348398";

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

		// Initialize Real Google Mobile Ads SDK & Preload Interstitial Ad
		initAdMob();

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

	public void initAdMob() {
		runOnUiThread(() -> {
			try {
				MobileAds.initialize(this, initializationStatus -> {
					Log.i("GODOT_ADMOB", "Real Google Mobile Ads SDK Initialized successfully.");
					loadInterstitialAdStatic();
				});
			} catch (Exception e) {
				Log.e("GODOT_ADMOB", "Error initializing MobileAds: " + e.getMessage());
			}
		});
	}

	public static void loadInterstitialAdStatic() {
		if (instance == null) return;
		instance.runOnUiThread(() -> {
			try {
				AdRequest adRequest = new AdRequest.Builder().build();
				InterstitialAd.load(instance, AD_UNIT_ID, adRequest, new InterstitialAdLoadCallback() {
					@Override
					public void onAdLoaded(InterstitialAd interstitialAd) {
						mInterstitialAd = interstitialAd;
						Log.i("GODOT_ADMOB", "Real AdMob Interstitial Ad loaded successfully!");
					}

					@Override
					public void onAdFailedToLoad(LoadAdError loadAdError) {
						mInterstitialAd = null;
						Log.e("GODOT_ADMOB", "AdMob Interstitial Ad failed to load: " + loadAdError.getMessage());
					}
				});
			} catch (Exception e) {
				Log.e("GODOT_ADMOB", "Error loading Interstitial Ad: " + e.getMessage());
			}
		});
	}

	public static boolean showInterstitialAdStatic() {
		if (instance == null) return false;
		final boolean[] shown = {false};
		instance.runOnUiThread(() -> {
			try {
				if (mInterstitialAd != null) {
					mInterstitialAd.setFullScreenContentCallback(new FullScreenContentCallback() {
						@Override
						public void onAdDismissedFullScreenContent() {
							mInterstitialAd = null;
							Log.i("GODOT_ADMOB", "Interstitial Ad dismissed by user. Reloading next ad...");
							loadInterstitialAdStatic();
						}

						@Override
						public void onAdFailedToShowFullScreenContent(AdError adError) {
							mInterstitialAd = null;
							Log.e("GODOT_ADMOB", "Interstitial Ad failed to show: " + adError.getMessage());
							loadInterstitialAdStatic();
						}
					});
					mInterstitialAd.show(instance);
					shown[0] = true;
					Log.i("GODOT_ADMOB", "Real AdMob Interstitial Ad displayed on screen!");
				} else {
					Log.w("GODOT_ADMOB", "Interstitial Ad not loaded yet. Requesting load...");
					loadInterstitialAdStatic();
				}
			} catch (Exception e) {
				Log.e("GODOT_ADMOB", "Error displaying Interstitial Ad: " + e.getMessage());
			}
		});
		return shown[0];
	}

	public static boolean isInterstitialLoadedStatic() {
		return mInterstitialAd != null;
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
