package org.luani.client;
public final class WebsitePolicyTest {
    private static int cases;
    private static void check(boolean value,String name) { cases++; if(!value)throw new AssertionError(name); }
    public static void main(String[] args) {
        String ticket="A".repeat(43),launch="luani://launch?ticket="+ticket;
        check(WebsitePolicy.isTrustedPage("https://new.luani.fyi/"),"home");
        check(WebsitePolicy.isTrustedPage("https://new.luani.fyi/profile/1#settings"),"profile");
        check(WebsitePolicy.isTrustedPage("https://NEW.LUANI.FYI:443/games/baseplate"),"standard TLS port");
        for(String bad:new String[]{"http://new.luani.fyi/","https://new.luani.fyi.evil.invalid/","https://evil.invalid/","file:///etc/passwd","content://local/data","javascript:alert(1)","https://name@new.luani.fyi/","https://new.luani.fyi:444/"})check(!WebsitePolicy.isTrustedPage(bad),"reject untrusted page");
        check(WebsitePolicy.isLaunch(launch),"canonical one-use link");
        for(String bad:new String[]{launch+"&extra=1",launch+"#fragment",launch+"\n","luani://launch/?ticket="+ticket,"luani://launch?ticket=short","luani://other?ticket="+ticket,"intent://launch?ticket="+ticket})check(!WebsitePolicy.isLaunch(bad),"reject malformed launch");
        check(WebsitePolicy.canLaunchFrom("https://new.luani.fyi/games/baseplate",launch,true),"first-party main frame");
        check(!WebsitePolicy.canLaunchFrom("https://evil.invalid/",launch,true),"no untrusted source");
        check(!WebsitePolicy.canLaunchFrom("https://new.luani.fyi/",launch,false),"no iframe launch");
        System.out.println("WebsitePolicy actual JVM checks passed: "+cases);
    }
}
