package org.luani.client;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.regex.Pattern;

/** Data-only URL policy; no session/cookie inspection and no Android dependencies. */
public final class WebsitePolicy {
    public static final String HOME = "https://new.luani.fyi/";
    private static final Pattern LAUNCH = Pattern.compile("\\Aluani://launch\\?ticket=[A-Za-z0-9_-]{43}\\z");
    private WebsitePolicy() {}
    public static boolean isSupportMail(String value) {
        return "mailto:help@luani.fyi".equals(value);
    }
    public static boolean isSafeHttps(String value) {
        if (value == null || value.length() > 16384) return false;
        try {
            URI u = new URI(value);
            return "https".equalsIgnoreCase(u.getScheme()) && u.getHost() != null && u.getRawUserInfo() == null && (u.getPort() == -1 || u.getPort() == 443);
        } catch (URISyntaxException e) { return false; }
    }
    public static boolean isTrustedPage(String value) {
        if (!isSafeHttps(value)) return false;
        try { return "new.luani.fyi".equalsIgnoreCase(new URI(value).getHost()); }
        catch (URISyntaxException e) { return false; }
    }
    public static boolean isLaunch(String value) {
        return value != null && value.length() <= 256 && LAUNCH.matcher(value).matches();
    }
    public static boolean canLaunchFrom(String source, String target, boolean mainFrame) {
        return mainFrame && isTrustedPage(source) && isLaunch(target);
    }
}
