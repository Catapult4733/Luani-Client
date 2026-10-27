package org.luani.client;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.net.Uri;
import android.net.http.SslError;
import android.os.Build;
import android.view.Gravity;
import android.view.Display;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.view.inputmethod.InputMethodManager;
import android.webkit.CookieManager;
import android.webkit.PermissionRequest;
import android.webkit.SslErrorHandler;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;
import java.util.Collections;
import java.util.Set;

/** Chrome-free first-party website. Only a one-use launch URI crosses into Godot. */
public final class LuaniWebsitePlugin extends GodotPlugin {
    private Activity host;
    private FrameLayout overlay;
    private WebView browser;
    private LinearLayout connection;
    private TextView status;
    private TextView detail;
    private ProgressBar spinner;
    private Button retry;
    private volatile boolean visible;
    private boolean pageFailed;
    private boolean loading;
    private int pageLoadGeneration;
    private static final int BACKGROUND = Color.rgb(32,26,45);
    private static final Set<SignalInfo> SIGNALS = Collections.singleton(new SignalInfo("launch_requested", String.class));
    public LuaniWebsitePlugin(Godot godot) { super(godot); }
    @Override public String getPluginName() { return "LuaniWebsite"; }
    @Override public Set<SignalInfo> getPluginSignals() { return SIGNALS; }
    private int dp(int value) { return Math.round(value * host.getResources().getDisplayMetrics().density); }
    private void prefer60Hz() {
        Display display=host.getWindowManager().getDefaultDisplay();
        Display.Mode current=display.getMode();
        for (Display.Mode mode : display.getSupportedModes()) {
            if (mode.getPhysicalWidth()==current.getPhysicalWidth() && mode.getPhysicalHeight()==current.getPhysicalHeight() && Math.abs(mode.getRefreshRate()-60f)<1f) {
                WindowManager.LayoutParams params=host.getWindow().getAttributes();
                params.preferredDisplayModeId=mode.getModeId();params.preferredRefreshRate=60f;host.getWindow().setAttributes(params);return;
            }
        }
    }
    @Override public View onMainCreate(Activity activity) {
        if (activity == null) return null;
        host = activity;
        prefer60Hz();
        overlay = new FrameLayout(host); overlay.setBackgroundColor(BACKGROUND); overlay.setVisibility(View.GONE);
        overlay.setLayoutParams(new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        browser = new WebView(host); browser.setBackgroundColor(BACKGROUND);
        overlay.addView(browser, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        connection = new LinearLayout(host); connection.setOrientation(LinearLayout.VERTICAL); connection.setGravity(Gravity.CENTER);
        connection.setPadding(dp(28),dp(28),dp(28),dp(28)); connection.setBackgroundColor(BACKGROUND);
        spinner = new ProgressBar(host); spinner.setIndeterminateTintList(ColorStateList.valueOf(Color.rgb(193,173,255)));
        connection.addView(spinner,new LinearLayout.LayoutParams(dp(32),dp(32)));
        status = new TextView(host); status.setTextColor(Color.WHITE); status.setTextSize(22); status.setGravity(Gravity.CENTER); status.setPadding(0,dp(20),0,dp(12)); connection.addView(status);
        detail = new TextView(host); detail.setTextColor(Color.rgb(190,188,201)); detail.setTextSize(15); detail.setGravity(Gravity.CENTER); connection.addView(detail);
        retry = new Button(host); retry.setText("Retry"); retry.setAllCaps(false); retry.setMinHeight(dp(48));
        retry.setOnClickListener(v -> { if (browser != null) browser.loadUrl(WebsitePolicy.isTrustedPage(browser.getUrl()) ? browser.getUrl() : WebsitePolicy.HOME); });
        connection.addView(retry); overlay.addView(connection, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        showConnecting();
        WebSettings settings = browser.getSettings();
        settings.setJavaScriptEnabled(true); settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(false); settings.setAllowContentAccess(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setJavaScriptCanOpenWindowsAutomatically(false); settings.setSupportMultipleWindows(false);
        settings.setMediaPlaybackRequiresUserGesture(true);
        if (Build.VERSION.SDK_INT >= 26) settings.setSafeBrowsingEnabled(true);
        settings.setUserAgentString(settings.getUserAgentString() + " LuaniClient/0.5.0-android.3");
        CookieManager.getInstance().setAcceptCookie(true);
        CookieManager.getInstance().setAcceptThirdPartyCookies(browser, false);
        WebView.setWebContentsDebuggingEnabled(false);
        browser.setWebChromeClient(new WebChromeClient() {
            @Override public void onPermissionRequest(PermissionRequest request) { request.deny(); }
        });
        browser.setWebViewClient(new WebViewClient() {
            @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                String target = request.getUrl().toString();
                if (!request.isForMainFrame()) return !WebsitePolicy.isSafeHttps(target);
                if (request.hasGesture() && WebsitePolicy.isTrustedPage(view.getUrl()) && WebsitePolicy.isSupportMail(target)) {
                    try { host.startActivity(new Intent(Intent.ACTION_SENDTO,Uri.parse(target))); }
                    catch (RuntimeException e) { message("Email help@luani.fyi from your mail app. Never send your password."); }
                    return true;
                }
                if (WebsitePolicy.canLaunchFrom(view.getUrl(), target, request.isForMainFrame())) {
                    hideNow(); emitSignal("launch_requested", target); return true;
                }
                if (WebsitePolicy.isTrustedPage(target)) {
                    if (request.getUrl().getPath() != null && request.getUrl().getPath().endsWith(".apk")) { openExternal(target); return true; }
                    return false;
                }
                if (request.hasGesture() && WebsitePolicy.isSafeHttps(target)) openExternal(target);
                else message("That link cannot open inside Luani.");
                return true;
            }
            @Override public boolean shouldOverrideUrlLoading(WebView view, String target) { return true; }
            @Override public void onPageStarted(WebView view, String url, android.graphics.Bitmap icon) {
                if (!WebsitePolicy.isTrustedPage(url)) { view.stopLoading(); showError("Only the Luani website can open here."); return; }
                pageFailed=false; loading=true; showConnecting();
                final int generation=++pageLoadGeneration;
                view.postDelayed(() -> {
                    if (browser != null && loading && generation == pageLoadGeneration) {
                        browser.stopLoading(); showError("Luani is taking too long to connect. Check your connection and retry.");
                    }
                },20000);
            }
            @Override public void onPageFinished(WebView view, String url) {
                loading=false;
                if (!pageFailed && WebsitePolicy.isTrustedPage(url)) connection.setVisibility(View.GONE);
            }
            @Override public void onReceivedSslError(WebView view, SslErrorHandler handler, SslError error) {
                handler.cancel(); showError("Secure connection failed. Check your connection and retry.");
            }
            @Override public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
                if (request.isForMainFrame()) showError("Could not connect to Luani. Check your connection and retry.");
            }
            @Override public void onReceivedHttpError(WebView view, WebResourceRequest request, WebResourceResponse response) {
                if (request.isForMainFrame()) showError("Luani could not load this page. Please retry.");
            }
        });
        browser.setDownloadListener((url, userAgent, disposition, mime, length) -> {
            if (WebsitePolicy.isTrustedPage(browser.getUrl()) && WebsitePolicy.isTrustedPage(url)) openExternal(url);
        });
        return overlay;
    }
    private void showConnecting() {
        status.setText("connecting"); spinner.setVisibility(View.VISIBLE); detail.setVisibility(View.GONE); retry.setVisibility(View.GONE); connection.setVisibility(View.VISIBLE);
    }
    private void showError(String text) {
        loading=false; pageFailed=true; status.setText("Connection unavailable"); detail.setText(text); detail.setVisibility(View.VISIBLE);
        spinner.setVisibility(View.GONE); retry.setVisibility(View.VISIBLE); connection.setVisibility(View.VISIBLE);
    }
    private void message(String text) { if (host != null) Toast.makeText(host,text,Toast.LENGTH_LONG).show(); }
    private void openExternal(String url) {
        if (!WebsitePolicy.isSafeHttps(url)) return;
        try { Intent i = new Intent(Intent.ACTION_VIEW, Uri.parse(url)); i.addCategory(Intent.CATEGORY_BROWSABLE); host.startActivity(i); }
        catch (RuntimeException e) { message("No browser is available for this link."); }
    }
    private void hideNow() {
        if (browser == null) return;
        visible = false;
        InputMethodManager input = (InputMethodManager)host.getSystemService(Activity.INPUT_METHOD_SERVICE);
        if (input != null) input.hideSoftInputFromWindow(browser.getWindowToken(), 0);
        browser.onPause(); browser.pauseTimers(); overlay.clearFocus(); overlay.setVisibility(View.GONE); CookieManager.getInstance().flush();
        host.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);
    }
    @UsedByGodot public void showWebsite() {
        runOnHostThread(() -> {
            if (browser == null) return;
            visible = true; host.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_FULL_USER);
            overlay.setVisibility(View.VISIBLE); browser.resumeTimers(); browser.onResume(); browser.requestFocus();
            if (browser.getUrl() == null) browser.loadUrl(WebsitePolicy.HOME);
        });
    }
    @UsedByGodot public void hideWebsite() { runOnHostThread(this::hideNow); }
    @UsedByGodot public boolean isWebsiteVisible() { return visible; }
    @UsedByGodot public void showMessage(String text) {
        final String bounded = text == null ? "" : text.substring(0, Math.min(text.length(), 240));
        runOnHostThread(() -> message(bounded));
    }
    @Override public boolean onMainBackPressed() {
        if (!visible || browser == null) return false;
        if (browser.canGoBack()) browser.goBack(); else host.moveTaskToBack(true);
        return true;
    }
    @Override public void onMainPause() { if (browser != null) { browser.onPause(); browser.pauseTimers(); CookieManager.getInstance().flush(); } }
    @Override public void onMainResume() { if (browser != null && visible) { browser.resumeTimers(); browser.onResume(); } }
    @Override public void onMainDestroy() {
        if (browser != null) { browser.stopLoading(); overlay.removeView(browser); browser.destroy(); browser = null; }
        visible = false; host = null;
    }
}
