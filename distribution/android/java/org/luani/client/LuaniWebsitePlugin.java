package org.luani.client;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.graphics.Color;
import android.net.Uri;
import android.net.http.SslError;
import android.os.Build;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.InputMethodManager;
import android.webkit.CookieManager;
import android.webkit.PermissionRequest;
import android.webkit.SslErrorHandler;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

/** First-party website overlay. Login stays in WebView; only one-use launch URIs reach Godot. */
public final class LuaniWebsitePlugin extends GodotPlugin {
    private Activity host;
    private LinearLayout overlay;
    private WebView browser;
    private TextView notice;
    private volatile boolean visible;
    private static final Set<SignalInfo> SIGNALS = Collections.unmodifiableSet(new HashSet<>(Arrays.asList(
        new SignalInfo("launch_requested", String.class), new SignalInfo("practice_requested")
    )));
    public LuaniWebsitePlugin(Godot godot) { super(godot); }
    @Override public String getPluginName() { return "LuaniWebsite"; }
    @Override public Set<SignalInfo> getPluginSignals() { return SIGNALS; }
    private int dp(int value) { return Math.round(value * host.getResources().getDisplayMetrics().density); }
    private Button button(String text, Runnable action) {
        Button b = new Button(host); b.setText(text); b.setTextSize(14); b.setAllCaps(false);
        b.setMinHeight(dp(48)); b.setMinimumWidth(dp(64)); b.setOnClickListener(v -> action.run());
        return b;
    }
    @Override public View onMainCreate(Activity activity) {
        if (activity == null) return null;
        host = activity;
        overlay = new LinearLayout(host); overlay.setOrientation(LinearLayout.VERTICAL);
        overlay.setBackgroundColor(Color.rgb(32,26,45)); overlay.setVisibility(View.GONE);
        overlay.setLayoutParams(new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        LinearLayout toolbar = new LinearLayout(host); toolbar.setOrientation(LinearLayout.HORIZONTAL);
        toolbar.addView(button("Back", () -> { if (browser.canGoBack()) browser.goBack(); else browser.loadUrl(WebsitePolicy.HOME); }));
        toolbar.addView(button("Refresh", () -> browser.reload()));
        TextView brand = new TextView(host); brand.setText("Luani"); brand.setTextColor(Color.WHITE); brand.setTextSize(17); brand.setGravity(android.view.Gravity.CENTER);
        toolbar.addView(brand, new LinearLayout.LayoutParams(0, dp(48), 1));
        toolbar.addView(button("Practice", () -> { hideNow(); emitSignal("practice_requested"); }));
        overlay.addView(toolbar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52)));
        notice = new TextView(host); notice.setTextColor(Color.WHITE); notice.setPadding(dp(12),dp(8),dp(12),dp(8)); notice.setTextSize(14); notice.setVisibility(View.GONE); overlay.addView(notice);
        browser = new WebView(host); browser.setBackgroundColor(Color.rgb(32,26,45));
        WebSettings settings = browser.getSettings();
        settings.setJavaScriptEnabled(true); settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(false); settings.setAllowContentAccess(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setJavaScriptCanOpenWindowsAutomatically(false); settings.setSupportMultipleWindows(false);
        settings.setMediaPlaybackRequiresUserGesture(true);
        if (Build.VERSION.SDK_INT >= 26) settings.setSafeBrowsingEnabled(true);
        settings.setUserAgentString(settings.getUserAgentString() + " LuaniClient/0.5.0-android.2");
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
            @Override public boolean shouldOverrideUrlLoading(WebView view, String target) {
                // API24+ supplies the main-frame-aware overload; fail closed otherwise.
                return true;
            }
            @Override public void onPageStarted(WebView view, String url, android.graphics.Bitmap icon) {
                if (!WebsitePolicy.isTrustedPage(url)) { view.stopLoading(); message("Only the Luani website can open in this view."); }
                else notice.setVisibility(View.GONE);
            }
            @Override public void onReceivedSslError(WebView view, SslErrorHandler handler, SslError error) {
                handler.cancel(); message("Secure connection failed. Check your connection, then refresh.");
            }
            @Override public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
                if (request.isForMainFrame()) message("Could not load Luani. Check your connection, then refresh.");
            }
        });
        browser.setDownloadListener((url, userAgent, disposition, mime, length) -> {
            if (WebsitePolicy.isTrustedPage(browser.getUrl()) && WebsitePolicy.isTrustedPage(url)) openExternal(url);
        });
        overlay.addView(browser, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        return overlay;
    }
    private void message(String text) { notice.setText(text); notice.setVisibility(View.VISIBLE); }
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
        browser.onPause(); overlay.clearFocus(); overlay.setVisibility(View.GONE);
        CookieManager.getInstance().flush();
        host.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);
    }
    @UsedByGodot public void showWebsite() {
        runOnHostThread(() -> {
            if (browser == null) return;
            visible = true; host.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_FULL_USER);
            overlay.setVisibility(View.VISIBLE); browser.onResume(); browser.requestFocus();
            if (browser.getUrl() == null) browser.loadUrl(WebsitePolicy.HOME);
        });
    }
    @UsedByGodot public void hideWebsite() { runOnHostThread(this::hideNow); }
    @UsedByGodot public boolean isWebsiteVisible() { return visible; }
    @UsedByGodot public void showMessage(String text) {
        final String bounded = text == null ? "" : text.substring(0, Math.min(text.length(), 240));
        runOnHostThread(() -> { if (host != null) Toast.makeText(host, bounded, Toast.LENGTH_LONG).show(); });
    }
    @Override public boolean onMainBackPressed() {
        if (!visible || browser == null) return false;
        if (browser.canGoBack()) browser.goBack(); else host.moveTaskToBack(true);
        return true;
    }
    @Override public void onMainPause() { if (browser != null) { browser.onPause(); CookieManager.getInstance().flush(); } }
    @Override public void onMainResume() { if (browser != null && visible) browser.onResume(); }
    @Override public void onMainDestroy() {
        if (browser != null) { browser.stopLoading(); overlay.removeView(browser); browser.destroy(); browser = null; }
        visible = false; host = null;
    }
}
