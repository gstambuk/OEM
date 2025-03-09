// Network configuration script by Gorstak, ver 12.
// Enhanced ad-blocking PAC file

// Variable to skip proxy
var pass = "DIRECT";

// Variable for dead-end route
var blackhole = "PROXY 0.0.0.0:3421";

// Comprehensive regex pattern to block ad-related, tracking, and analytics domains
var adRegex = new RegExp(
    "^(.+[-_.])?(ads?|adv(ert(s|ising)?)?|banners?|track(er|ing|s)?|beacons?|doubleclick|adservice|adnxs|adtech|googleads|gads|adwords|partner|sponsor(ed)?|click(s|bank|tale|through)?|pop(up|under)s?|promo(tion)?|market(ing|er)?|affiliates?|metrics?|stat(s|counter|istics)?|analytics?|pixel(s)?|campaign|traff(ic|iq)|monetize|syndicat(e|ion)|revenue|yield|impress(ion)?s?|conver(sion|t)?|audience|target(ing)?|behavior|profil(e|ing)|telemetry|survey|poll|outbrain|taboola|quantcast|scorecard|omniture|comscore|krux|bluekai|exelate|adform|adroll|rubicon|vungle|inmobi|flurry|mixpanel|heap|amplitude|optimizely|bizible|pardot|hubspot|marketo|eloqua|salesforce|media(math|net)|criteo|appnexus|turn|adbrite|admob|adsonar|adscale|zergnet|revcontent|mgid|nativeads|contentad|displayads|bannerflow|adblade|adcolony|chartbeat|newrelic|pingdom|gauges|kissmetrics|webtrends|tradedesk|bidder|auction|rtb|programmatic|splash|interstitial|overlay)",
    "i" // Case-insensitive flag
);

// Proxy auto-config function
function FindProxyForURL(url, host) {
    host = host.toLowerCase();
    
    // Exception for Twitter/X domains and requested sites
    if (host === "twitter.com" || 
        host === "x.com" || 
        host.endsWith(".twitter.com") || 
        host.endsWith(".x.com") ||
        host === "perplexity.ai" ||
        host.endsWith(".perplexity.ai") ||
        host === "mediafire.com" ||
        host.endsWith(".mediafire.com")) {
        return pass;
    }

    // Block ad domains
    if (adRegex.test(host)) {
        return blackhole;
    }
    
    // Allow everything else
    return pass;
}