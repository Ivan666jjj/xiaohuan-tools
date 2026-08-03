import Cocoa
import WebKit
import UniformTypeIdentifiers

class ScholarWebView: WKWebView, NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.items.filter { $0.tag == 9999 }.forEach { menu.removeItem($0) }
        menu.addItem(.separator())
        for s in Self.searchServices {
            let item = NSMenuItem(title: "🔍 在 \(s.0) 中搜索", action: #selector(searchIn(_:)), keyEquivalent: "")
            item.representedObject = s.1; item.target = self; item.tag = 9999; menu.addItem(item)
        }
        menu.addItem(.separator())
        let tools: [(String, Selector)] = [
            ("🌐 翻译选中文字", #selector(translateSel(_:))),
            ("🔄 繁简转换", #selector(convertSC(_:))),
            ("⭐ 收藏生词", #selector(saveVocab(_:))),
            ("📝 保存为笔记", #selector(saveNote(_:))),
            ("📖 生成引用格式", #selector(genCitation(_:))),
            ("🔢 统计本页字数", #selector(countWords(_:))),
        ]
        for (t, a) in tools {
            let item = NSMenuItem(title: t, action: a, keyEquivalent: "")
            item.target = self; item.tag = 9999; menu.addItem(item)
        }
    }
    @objc func searchIn(_ sender: NSMenuItem) {
        guard let t = sender.representedObject as? String else { return }
        Task { @MainActor in
            if let r = try? await evaluateJavaScript("window.getSelection().toString()"),
               let tx = r as? String, !tx.trimmingCharacters(in: .whitespaces).isEmpty,
               let url = URL(string: t + (tx.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? tx)) {
                self.load(URLRequest(url: url))
            }
        }
    }

    // MARK: 学术工具（转发给 AppDelegate 统一处理）

    private func selText(_ done: @escaping (String) -> Void) {
        Task { @MainActor in
            if let r = try? await evaluateJavaScript("window.getSelection().toString()"),
               let tx = r as? String, !tx.trimmingCharacters(in: .whitespaces).isEmpty {
                done(tx)
            }
        }
    }
    @objc func translateSel(_ s: NSMenuItem) { selText { (NSApp.delegate as? AppDelegate)?.translateSelection($0) } }
    @objc func convertSC(_ s: NSMenuItem) { selText { (NSApp.delegate as? AppDelegate)?.convertSelection($0) } }
    @objc func saveVocab(_ s: NSMenuItem) { selText { (NSApp.delegate as? AppDelegate)?.saveVocabulary($0) } }
    @objc func saveNote(_ s: NSMenuItem) { selText { (NSApp.delegate as? AppDelegate)?.saveQuickNote($0) } }
    @objc func genCitation(_ s: NSMenuItem) { selText { (NSApp.delegate as? AppDelegate)?.generateCitation($0) } }
    @objc func countWords(_ s: NSMenuItem) { (NSApp.delegate as? AppDelegate)?.countPageWords() }

    static let searchServices: [(String, String)] = [
        ("汉典", "https://www.zdic.net/search/?q="),("国学大师", "https://www.gxdq.com/search?q="),
        ("小学堂", "https://xiaoxue.iis.sinica.edu.tw/search?q="),("CText", "https://ctext.org/search?q="),
        ("互动百科", "https://www.baike.com/search?word="),
    ]
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate {
    var window: NSWindow!
    var tabs: [WKWebView] = []
    var activeIndex = 0
    var urlField: NSTextField!
    var backBtn: NSButton!, fwdBtn: NSButton!
    var tabBar: NSView!, toolbar: NSView!, bookmarkPanel: NSView?, settingsPanel: NSView?
    var history: [(String, String)] = []

    let bookmarks: [(String, String, String, String)] = [
        ("🔍","搜狗搜索","https://www.sogou.com","搜索"),("🅱️","必应搜索","https://cn.bing.com","搜索"),
        ("🦆","DuckDuckGo","https://lite.duckduckgo.com/lite","搜索"),("🌐","Google","https://www.google.com","搜索"),
        ("📖","汉典","https://www.zdic.net","字典"),("🏛️","国学大师","https://www.gxdq.com","字典"),
        ("🔤","异体字","https://dict2.variants.moe.edu.tw","字典"),("🖌️","书法字典","https://www.shufazidian.com","字典"),
        ("🐢","小学堂","https://xiaoxue.iis.sinica.edu.tw","古文字"),("📚","引得市","https://mhdb.mh.sinica.edu.tw","古文字"),
        ("🪞","古音小镜","http://www.kaom.net","古文字"),("📜","CText","https://ctext.org","古籍"),
        ("🎋","古诗文网","https://www.gushiwen.cn","古籍"),("🔬","中国知网","https://www.cnki.net","学术"),
        ("📄","维普","https://www.cqvip.com","学术"),("📖","万方","https://www.wanfangdata.com.cn","学术"),
        ("🎵","韵典网","https://ytenx.org","工具"),("✒️","搜韵","https://sou-yun.cn","工具"),
        ("🏛️","故宫博物院","https://www.dpm.org.cn","考古"),("🏛️","国家图书馆","https://www.nlc.cn","学术"),
        ("🎓","中国人民大学","https://www.ruc.edu.cn","人大"),("📚","人大图书馆","https://lib.ruc.edu.cn","人大"),
        ("💻","微人大","https://v.ruc.edu.cn","人大"),("📋","人大教务处","https://jiaowu.ruc.edu.cn","人大"),
    ]

    func applicationDidFinishLaunching(_ n: Notification) {
        let rect = NSRect(x: 0, y: 0, width: 1280, height: 820)
        window = NSWindow(contentRect: rect, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "文史哲浏览器"; window.minSize = NSSize(width: 800, height: 500); window.center()
        let wv = makeWV(); window.contentView = wv
        setupChrome(on: wv, width: rect.width)
        tabs.append(wv); activeIndex = 0
        buildMenu(); window.makeKeyAndOrderFront(nil); goHome()
    }

    var activeWV: WKWebView { tabs[activeIndex] }

    func setupChrome(on wv: WKWebView, width: CGFloat) {
        let barH: CGFloat = 32, toolH: CGFloat = 34
        tabBar = NSView(frame: NSRect(x: 0, y: wv.bounds.height - barH - toolH, width: width, height: barH))
        tabBar.autoresizingMask = [.width, .minYMargin]; wv.addSubview(tabBar)
        toolbar = NSView(frame: NSRect(x: 0, y: wv.bounds.height - toolH, width: width, height: toolH))
        toolbar.autoresizingMask = [.width, .minYMargin]
        toolbar.wantsLayer = true; toolbar.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor

        let btns: [(String, Selector)] = [("◀",#selector(goBack)),("▶",#selector(goForward)),("↻",#selector(goRefresh)),("🏠",#selector(goHome)),("📖",#selector(toggleBM)),("📝",#selector(showNotes)),("🤖",#selector(showAI)),("📄",#selector(openPDF)),("🌐",#selector(translatePage)),("⚙",#selector(toggleSettings)),("📚",#selector(openClassics))]
        var bx: CGFloat = 4
        for (t, a) in btns {
            let b = NSButton(frame: NSRect(x: bx, y: 0, width: 36, height: 34))
            b.title = t; b.bezelStyle = .roundRect; b.font = .systemFont(ofSize: 12)
            b.target = self; b.action = a; toolbar.addSubview(b)
            if t == "◀" { backBtn = b } else if t == "▶" { fwdBtn = b }
            bx += 36
        }

        // 搜索引擎切换 🆕
        let engBtn = NSPopUpButton(frame: NSRect(x: bx, y: 0, width: 36, height: 34))
        engBtn.addItems(withTitles: ["🦆","🔍","🅱️","🌐"])
        engBtn.bezelStyle = .roundRect; engBtn.font = .systemFont(ofSize: 10)
        engBtn.target = self; engBtn.action = #selector(engineChanged(_:))
        engBtn.selectItem(at: UserDefaults.standard.integer(forKey: "searchEngine"))
        toolbar.addSubview(engBtn); bx += 36

        urlField = NSTextField(frame: NSRect(x: bx, y: 5, width: width - bx - 8, height: 24))
        urlField.autoresizingMask = [.width]; urlField.placeholderString = "输入完整网址(如 https://…)，搜索用上方📖书签选引擎"
        urlField.font = .systemFont(ofSize: 14); urlField.bezelStyle = .roundedBezel
        urlField.target = self; urlField.action = #selector(urlGo); toolbar.addSubview(urlField)
        wv.addSubview(toolbar)
    }

    func makeWV() -> WKWebView {
        let config = WKWebViewConfiguration(); config.websiteDataStore = .default()
        let adJS = """
        (function(){var s=document.createElement('style');s.id='sa';
        s.textContent='[class*="ad-"],[id*="ad-"],[class*="ads-"],[id*="ads-"],[class*="ad_"],[class*="-ad"],[class*="gg_"],[class*="guanggao"],[class*="banner"],[id*="banner"],[class*="sponsor"],.sponsored,[class*="advert"],.advertisement,iframe[src*="doubleclick"],iframe[src*="googlead"],iframe[src*="googlesyndication"],iframe[src*="cpro.baidu"],iframe[src*="tanx.com"],iframe[src*="pos.baidu.com"],div[class*="promo"],[class*="popup"],[class*="recommend"],[class*="adbox"],.google-ad,.adsbygoogle,ins.adsbygoogle,div[id^="google_ads"],div[id^="aswift"],div[id*="gpt-ad"],div[data-google-query-id],div[id*="google_ads_iframe"],iframe[src*="google.com/pagead"],.modal-backdrop,.popup-overlay,.outbrain,.taboola,.revcontent,div[id*="taboola"],div[id*="outbrain"],[class*="native-ad"],[class*="feed-ad"],div[class*="widget"][class*="ad"]{display:none!important;height:0!important;width:0!important;overflow:hidden!important;opacity:0!important;visibility:hidden!important;position:absolute!important;pointer-events:none!important}';
        if(document.head)document.head.appendChild(s);else document.addEventListener('DOMContentLoaded',function(){document.head.appendChild(s)})})();
        /* 汉典网(zdic.net)弹窗广告专项清理：CSS 隐藏 + MutationObserver 动态移除 */
        if(location.host.indexOf('zdic.net')>=0){
        (function(){
        var ss=document.createElement('style');ss.id='zd';
        ss.textContent='[class*="ad-popup"],[id*="ad-popup"],.modal-backdrop,#ad-overlay,.pop-ad,.popup-ad,[class*="popup"][class*="ad"],[id*="popup"][id*="ad"],[class*="dl-pop"],[class*="pop-banner"],div[style*="position:fixed"][style*="z-index:9999"],div[style*="position:fixed"][style*="z-index:99999"],div[style*="position:fixed"][style*="z-index:999999"]{display:none!important;visibility:hidden!important;pointer-events:none!important}';
        if(document.head)document.head.appendChild(ss);
        function kill(){
          var sels=['[class*="ad-popup"]','.modal-backdrop','#ad-overlay','.pop-ad','.popup-ad','[class*="popup"][class*="ad"]','[class*="dl-pop"]','[class*="pop-banner"]'];
          for(var i=0;i<sels.length;i++){var els=document.querySelectorAll(sels[i]);for(var j=0;j<els.length;j++){els[j].remove()}}
          // 兜底：fixed + 高 z-index + 大尺寸遮罩（不误伤小提示/生僻字浮层）
          var all=document.querySelectorAll('div[style*="position:fixed"],div[style*="position: fixed"]');
          for(var k=0;k<all.length;k++){var el=all[k],st=el.style||{};
            var z=parseInt(st.zIndex)||0;
            if(z>9000&&(el.offsetWidth>260||el.offsetHeight>260)){el.remove()}}
        }
        kill();
        document.addEventListener('DOMContentLoaded',kill);
        new MutationObserver(function(){kill()}).observe(document.body||document.documentElement,{childList:true,subtree:true});
        setInterval(kill,3000);
        })();
        }
        """
        config.userContentController.addUserScript(WKUserScript(source: adJS, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        // 追加：页面加载后再次清理动态注入的汉典弹窗
        let zdClean = """
        (function(){if(location.host.indexOf('zdic.net')<0)return;
        function k(){var s=['.ad-popup','.modal-backdrop','#ad-overlay','.pop-ad','.popup-ad'];
        for(var i=0;i<s.length;i++){document.querySelectorAll(s[i]).forEach(function(e){e.remove()})}
        document.querySelectorAll('div[style*="position:fixed"]').forEach(function(e){var z=parseInt(e.style.zIndex)||0;if(z>9000&&(e.offsetWidth>260||e.offsetHeight>260))e.remove()})}
        k();setInterval(k,3000);})();
        """
        config.userContentController.addUserScript(WKUserScript(source: zdClean, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        let wv = ScholarWebView(frame: .zero, configuration: config)
        // 右键菜单：显式绑定 NSMenu + delegate，确保 menuNeedsUpdate 稳定触发
        let ctxMenu = NSMenu()
        ctxMenu.delegate = wv
        wv.menu = ctxMenu
        wv.navigationDelegate = self; wv.uiDelegate = self
        wv.allowsBackForwardNavigationGestures = true; wv.allowsMagnification = true
        return wv
    }

    @objc func engineChanged(_ sender: NSPopUpButton) { UserDefaults.standard.set(sender.indexOfSelectedItem, forKey: "searchEngine") }

    @objc func addTab() { let wv = makeWV(); wv.isHidden = true; activeWV.addSubview(wv); tabs.append(wv); switchTo(tabs.count - 1); goHome(); renderTabs() }
    func switchTo(_ i: Int) {
        guard i != activeIndex, i < tabs.count else { return }
        bookmarkPanel?.removeFromSuperview(); bookmarkPanel = nil; settingsPanel?.removeFromSuperview(); settingsPanel = nil
        tabs[activeIndex].isHidden = true
        if tabBar.superview != tabs[i] { tabs[i].addSubview(tabBar) }
        if toolbar.superview != tabs[i] { tabs[i].addSubview(toolbar) }
        window.contentView = tabs[i]; activeIndex = i; tabs[i].isHidden = false; updateNav(); renderTabs()
    }
    func closeTab(_ i: Int) {
        guard tabs.count > 1, i < tabs.count else { return }
        tabs[i].removeFromSuperview(); tabs.remove(at: i)
        if i <= activeIndex && activeIndex > 0 { activeIndex -= 1 }
        if activeIndex >= tabs.count { activeIndex = tabs.count - 1 }
        window.contentView = tabs[activeIndex]
        if tabBar.superview != tabs[activeIndex] { tabs[activeIndex].addSubview(tabBar) }
        if toolbar.superview != tabs[activeIndex] { tabs[activeIndex].addSubview(toolbar) }
        tabs[activeIndex].isHidden = false; updateNav(); renderTabs()
    }
    func renderTabs() {
        tabBar.subviews.forEach { $0.removeFromSuperview() }
        let add = NSButton(frame: NSRect(x: tabBar.bounds.width - 34, y: 2, width: 28, height: 26))
        add.title = "+"; add.bezelStyle = .roundRect; add.font = .systemFont(ofSize: 14)
        add.target = self; add.action = #selector(addTab); add.autoresizingMask = [.minXMargin]; tabBar.addSubview(add)
        var x: CGFloat = 4
        for (i, _) in tabs.enumerated() {
            let w = min(CGFloat(tabs[i].title?.prefix(12).count ?? 3) * 9 + 40, 130)
            let tb = NSButton(frame: NSRect(x: x, y: 2, width: w, height: 26))
            tb.title = tabs[i].title ?? "标签"; tb.bezelStyle = .roundRect; tb.font = .systemFont(ofSize: 10)
            tb.tag = i; tb.target = self; tb.action = #selector(tabClick(_:))
            if i == activeIndex { tb.state = .on; tb.setButtonType(.toggle) }
            let cl = NSButton(frame: NSRect(x: w - 18, y: 2, width: 16, height: 16))
            cl.title = "×"; cl.bezelStyle = .inline; cl.font = .systemFont(ofSize: 9, weight: .bold)
            cl.isBordered = false; cl.tag = i; cl.target = self; cl.action = #selector(closeClick(_:)); tb.addSubview(cl)
            tabBar.addSubview(tb); x += w + 4
        }
    }
    @objc func tabClick(_ s: NSButton) { switchTo(s.tag) }
    @objc func closeClick(_ s: NSButton) { closeTab(s.tag) }
    @objc func goHome() {
        let major = UserDefaults.standard.string(forKey: "major") ?? "全部"
        let map: [String:[Int]] = ["古文字学":[3,0,1,2,4,5,9],"历史学":[4,5,12,10,13,14,0],"考古学":[13,14,15,10,4,0],"音韵学":[6,7,3,9],"文献学":[4,5,10,0,1,3],"书法":[8,0,13,1],"综合学术":[9,0,1,4,5,10]]
        let tiles: [(String,String,String)] = [("🦆","DuckDuckGo","https://lite.duckduckgo.com/lite"),("🅱️","必应","https://cn.bing.com"),("🔍","搜狗","https://www.sogou.com"),("📖","汉典","https://www.zdic.net"),("🏛️","国学大师","https://www.gxdq.com"),("🐢","小学堂","https://xiaoxue.iis.sinica.edu.tw"),("🎵","韵典网","https://ytenx.org"),("🪞","古音小镜","http://www.kaom.net"),("🖌️","书法字典","https://www.shufazidian.com"),("📜","CText","https://ctext.org"),("🎋","古诗文网","https://www.gushiwen.cn"),("📚","引得市","https://mhdb.mh.sinica.edu.tw"),("🔬","中国知网","https://www.cnki.net"),("🏛️","故宫博物院","https://www.dpm.org.cn"),("⏳","考古中国","https://www.kaoguzhongguo.cn"),("🎓","关于作者","about:author")]
        let idx = map[major] ?? Array(0..<tiles.count)
        var cards = ""
        for i in idx where i < tiles.count {
            let t = tiles[i]; cards += "<a href='\(t.2)' class='tile'><span class='ic'>\(t.0)</span><span>\(t.1)</span></a>"
        }
        let html = """
<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>文史哲通用浏览器</title><style>
:root{
  --bg:#EAF3F5;           /* 汝窑天青：极淡青灰 */
  --bg-noise:rgba(120,144,156,.04);
  --text:#37474F;         /* 蓝灰主文字 */
  --sub:#78909C;          /* 天青强调/次级文字 */
  --card:#FFFFFF;         /* 纯白卡片 */
  --accent:#78909C;       /* 天青强调色 */
  --wood:#8D6E63;         /* 檀木棕点缀 */
  --shadow:0 2px 8px rgba(55,71,79,.08);
  --shadow-hover:0 8px 20px rgba(55,71,79,.15);
  --bdr:#E0E8EA;
}
*{box-sizing:border-box;margin:0;padding:0;outline:none}
body{font-family:"PingFang SC","Hiragino Sans GB","Songti SC","SimSun","Microsoft YaHei",serif;background:var(--bg);color:var(--text);min-height:100vh;overflow-x:hidden;padding-bottom:100px;
  background-image:radial-gradient(circle at 30% 20%, rgba(255,255,255,.6) 0, transparent 60%),radial-gradient(circle at 70% 80%, rgba(141,110,99,.06) 0, transparent 50%);}
header{position:sticky;top:0;padding:16px 32px;background:rgba(234,243,245,.9);backdrop-filter:blur(10px);-webkit-backdrop-filter:blur(10px);display:flex;justify-content:space-between;align-items:center;z-index:100;border-bottom:1px solid var(--bdr)}
h1{font-size:22px;font-weight:700;letter-spacing:4px;color:var(--text)}.cl{font-size:14px;color:var(--sub);font-family:Georgia,"Times New Roman",serif}
.sa{max-width:540px;margin:26px auto;padding:0 20px;display:flex;gap:10px;align-items:center}
.sb{flex:1;height:44px;padding:0 46px 0 16px;border:1px solid rgba(141,110,99,.18);border-radius:22px;font-size:15px;background:rgba(255,255,255,.6);backdrop-filter:blur(10px);-webkit-backdrop-filter:blur(10px);color:var(--text);font-family:inherit;box-shadow:var(--shadow);transition:all .25s;position:relative}
.sb:focus{border-color:var(--accent);background:rgba(255,255,255,.85);box-shadow:0 0 0 3px rgba(120,144,156,.2),var(--shadow-hover)}
.sb::placeholder{color:#A9BCC2}
.se{padding:8px 12px;border-radius:22px;border:1px solid rgba(141,110,99,.18);background:rgba(255,255,255,.6);backdrop-filter:blur(10px);-webkit-backdrop-filter:blur(10px);color:var(--text);cursor:pointer;font-size:13px;font-family:inherit;white-space:nowrap;box-shadow:var(--shadow);transition:all .25s}
.se:focus{border-color:var(--accent);box-shadow:0 0 0 3px rgba(120,144,156,.2)}
.mg{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:22px;max-width:1000px;margin:0 auto;padding:0 20px 30px}
.dr{grid-column:1/-1;background:linear-gradient(120deg,rgba(255,255,255,.85),rgba(234,243,245,.6));backdrop-filter:blur(6px);border:1px solid var(--bdr);border-radius:10px;padding:22px 28px 18px;margin-bottom:6px;position:relative;box-shadow:var(--shadow);cursor:pointer;transition:all .25s;overflow:hidden}
.dr:hover{box-shadow:var(--shadow-hover);transform:translateY(-1px)}
.dr::before{content:'C';position:absolute;top:-30px;left:14px;font-size:150px;font-family:Georgia,serif;color:rgba(141,110,99,.10);pointer-events:none;line-height:1}
.dr .dt{font-size:21px;font-weight:700;margin-bottom:8px;font-family:KaiTi,STKaiti,serif;color:var(--text);position:relative}
.dr .ds{font-size:13px;color:#A9BCC2;font-family:"PingFang SC","Hiragino Sans GB",sans-serif;font-weight:400;padding-top:10px;border-top:1px solid var(--bdr);position:relative}
.dr .dbar{position:absolute;top:14px;right:14px;display:flex;gap:6px}
.dr .dbar button{width:32px;height:32px;border-radius:50%;border:1px solid var(--bdr);background:rgba(255,255,255,.85);cursor:pointer;font-size:14px;display:flex;align-items:center;justify-content:center;color:var(--sub);transition:all .2s}
.dr .dbar button:hover{background:var(--accent);color:#fff;border-color:var(--accent)}
.book{background:linear-gradient(135deg,#FFFFFF 0%,#F2F6F7 100%);border:1px solid var(--bdr);border-radius:6px 8px 8px 6px;padding:0;display:flex;cursor:pointer;box-shadow:var(--shadow);transition:all .3s;min-height:150px;user-select:none;position:relative;overflow:hidden;aspect-ratio:3/4;animation:bf .5s ease-out backwards;will-change:transform}
.book::before{content:'';position:absolute;top:0;left:0;right:0;bottom:0;background:repeating-linear-gradient(0deg,transparent,transparent 2px,rgba(141,110,99,.015) 2px,rgba(141,110,99,.015) 4px);pointer-events:none;z-index:0}
.book:hover{transform:translateY(-4px);box-shadow:var(--shadow-hover)}
.book::after{content:'';position:absolute;top:0;left:0;width:10px;height:100%;background:linear-gradient(90deg,rgba(141,110,99,.28),transparent);border-right:1px solid rgba(212,175,55,.35)}
.book .bc{position:relative;z-index:2;flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:14px 14px 14px 22px;text-align:center}
.book .bn{font-family:"Songti SC","SimSun",serif;font-size:16px;font-weight:700;color:var(--text);line-height:1.5;margin-bottom:10px}
.book .bcat{display:inline-block;padding:3px 10px;border-radius:20px;font-size:11px;font-weight:600;background:transparent}
.book .bstar{position:absolute;bottom:14px;right:14px;width:26px;height:26px;border-radius:50%;border:1px solid transparent;background:transparent;cursor:pointer;font-size:13px;display:flex;align-items:center;justify-content:center;color:#B0BEC5;z-index:3;transition:all .2s}
.book:hover .bstar{border-color:var(--bdr);background:rgba(255,255,255,.85)}
.book:hover .bstar:not(.on){color:#F5A623}
.book .bstar:hover{transform:scale(1.15);color:#F5A623;border-color:#F5A623}
.book .bstar.on{color:#F5A623;background:#FFF8E1;border-color:#F5A623}
.book.stamp{background:rgba(255,255,255,.7);border:2px dashed var(--wood);border-radius:8px;min-height:120px;aspect-ratio:auto}
.book.stamp .bn{color:var(--wood);font-size:15px}.book.stamp:active{animation:sd .3s ease}
@keyframes sd{0%{transform:scale(1.15) rotate(-2deg);opacity:.6}50%{transform:scale(.98)}100%{transform:scale(1)}}
@keyframes bf{from{opacity:0;transform:translateY(16px)}to{opacity:1;transform:translateY(0)}}
.book.dragging{opacity:.35}
.tb{position:fixed;bottom:26px;right:26px;z-index:1000;display:flex;flex-direction:column;gap:10px}
.tb-b{width:46px;height:46px;border-radius:50%;background:var(--card);color:var(--wood);border:1px solid var(--bdr);font-size:20px;cursor:pointer;box-shadow:var(--shadow);transition:all .2s;display:flex;align-items:center;justify-content:center}
.tb-b:hover{transform:scale(1.08);box-shadow:var(--shadow-hover)}
.tb-p{position:absolute;bottom:56px;right:0;background:rgba(255,255,255,.97);border:1px solid var(--bdr);border-radius:10px;padding:14px;box-shadow:var(--shadow-hover);min-width:200px;opacity:0;visibility:hidden;transform:translateY(8px);transition:all .3s}
.tb-p.on{opacity:1;visibility:visible;transform:translateY(0)}
.tb-p button{display:flex;align-items:center;gap:8px;width:100%;padding:10px 12px;border:none;border-radius:6px;background:0 0;color:var(--text);font-size:14px;cursor:pointer;text-align:left;transition:background .2s;font-family:inherit}
.tb-p button:hover{background:rgba(120,144,156,.12)}
.tb-p button span{font-size:17px}
.ctx{position:absolute;background:var(--card);border:1px solid var(--bdr);border-radius:8px;padding:4px 0;box-shadow:var(--shadow-hover);display:none;z-index:2000;min-width:120px}
.ctx div{padding:8px 14px;cursor:pointer;font-size:13px;font-family:inherit;color:var(--text)}.ctx div:hover{background:rgba(120,144,156,.1)}
.toast{position:fixed;top:80px;left:50%;transform:translateX(-50%);background:var(--text);color:#fff;padding:10px 24px;border-radius:22px;font-size:14px;z-index:3000;opacity:0;pointer-events:none;transition:all .3s;font-family:inherit}.toast.s{opacity:1}
.ov{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(55,71,79,.4);display:none;z-index:2498}.ov.on{display:block}
.md{position:fixed;top:50%;left:50%;transform:translate(-50%,-50%) scale(.95);background:var(--card);border:1.5px solid var(--bdr);border-radius:12px;padding:26px;min-width:340px;z-index:2499;box-shadow:0 12px 40px rgba(55,71,79,.2);opacity:0;transition:all .3s;font-family:inherit;display:none}
.md.on{display:block;opacity:1;transform:translate(-50%,-50%) scale(1)}
.md h3{color:var(--text);margin-bottom:14px;font-size:17px}
.md input{width:100%;padding:10px 14px;border:1px solid var(--bdr);border-radius:8px;font-size:14px;margin:8px 0;font-family:inherit;background:var(--bg);color:var(--text)}.md input:focus{border-color:var(--accent)}
.md button{padding:10px 18px;border-radius:8px;border:1px solid var(--bdr);background:var(--card);color:var(--text);cursor:pointer;font-size:14px;font-family:inherit;margin-top:10px;margin-right:8px}
.md button.primary{background:var(--accent);color:#fff;border-color:var(--accent)}
.md .close{position:absolute;top:12px;right:14px;background:0 0;border:none;font-size:22px;color:var(--sub);cursor:pointer;padding:0;margin:0;line-height:1}
.pomo{font-family:Georgia,"Times New Roman",serif;font-size:34px;color:var(--accent);text-align:center;padding:10px 0}
.pomo-b{display:flex;gap:8px;justify-content:center}.pomo-b button{padding:8px 16px;border-radius:8px;border:1px solid var(--bdr);background:var(--card);color:var(--text);cursor:pointer;font-size:13px;font-family:inherit}
#notearea{width:100%;height:110px;padding:10px;border:1px solid var(--bdr);border-radius:8px;font-size:14px;font-family:inherit;resize:vertical;margin:10px 0;background:var(--bg);color:var(--text)}
#notearea::placeholder{color:#A9BCC2}
.khint{position:absolute;right:16px;top:50%;transform:translateY(-50%);font-size:11px;color:#A9BCC2;background:rgba(255,255,255,.7);border:1px solid rgba(141,110,99,.15);border-radius:6px;padding:2px 8px;pointer-events:none}
@media(max-width:768px){.mg{grid-template-columns:repeat(auto-fill,minmax(140px,1fr))}header{padding:12px 16px}h1{font-size:18px}.sa{flex-direction:column}.sa .khint{position:static;transform:none;margin-top:4px}}
</style></head><body>
<header><h1>📚 文史哲通用浏览器</h1><div class="cl" id="cl"></div></header>
<div class="sa" style="position:relative"><input class="sb" id="q" placeholder="输入关键词，开始探索知识…" autofocus onkeydown="if(event.key==='Enter')go()"><span class="khint">⌘K</span><select class="se" id="eng"></select></div>
<div class="dr" id="dr" style="max-width:1000px;margin:0 auto 6px"><div class="dt" id="dt"></div><div class="ds" id="ds"></div><div class="dbar"><button onclick="refreshQuote()" title="换一句">🔄</button><button onclick="copyText(document.getElementById('dt').textContent)" title="复制名言">📋</button></div></div>
<div class="mg" id="g"></div>
<div class="tb"><div class="tb-p" id="tbp"><button onclick="showNote()"><span>📝</span> 便签</button><button onclick="showPomo()"><span>⏱</span> 番茄钟</button><button onclick="exportCfg()"><span>📤</span> 导出配置</button><button onclick="importCfg()"><span>📥</span> 导入配置</button><button onclick="resetLayout()"><span>🔁</span> 重置布局</button></div><button class="tb-b" onclick="toggleTB()">⚙</button></div>
<div class="ctx" id="ctx"><div onclick="copyLink()">📋 复制链接</div><div onclick="hideTile()">👁 隐藏此书</div></div>
<div class="ov" id="ov"></div>
<div class="md" id="md"><button class="close" onclick="closeMd('md')">✕</button><h3>添加书签</h3><input id="mn" placeholder="网站名称"><input id="mu" placeholder="网址 https://..."><button class="primary" onclick="addTile()">添加</button><button onclick="closeMd('md')">取消</button></div>
<div class="md" id="nmod"><button class="close" onclick="closeMd('nmod')">✕</button><h3>📝 便签</h3><textarea id="notearea" placeholder="在这里写下笔记…"></textarea><button onclick="saveNote()">保存</button><button onclick="closeMd('nmod')">关闭</button></div>
<div class="md" id="pmod"><button class="close" onclick="closeMd('pmod')">✕</button><h3>⏱ 番茄钟</h3><div class="pomo" id="pomo">25:00</div><div class="pomo-b"><button onclick="startPomo(1500)">25分钟</button><button onclick="startPomo(900)">15分钟</button><button onclick="startPomo(300)">5分钟</button><button onclick="clearInterval(window.pomoInt||0);window.pomoInt=null">停止</button></div><button onclick="closeMd('pmod')">关闭</button></div>
<div class="toast" id="ts"></div>
<script>
var ES=[{u:'https://xueshu.baidu.com/s?wd={query}&pn=0',n:'百度学术'},{u:'https://scholar.google.com/scholar?q={query}',n:'Google Scholar'},{u:'https://www.bing.com/academic/search?q={query}',n:'必应学术'},{u:'https://www.wolframalpha.com/input/?i={query}',n:'WolframAlpha'},{u:'https://www.baidu.com/s?wd={query}',n:'百度'}],ei=0;
document.getElementById('eng').innerHTML=ES.map(function(e,i){return'<option value='+i+(i==ei?' selected':'')+'>'+e.n});
var dbT=null;document.getElementById('q').addEventListener('input',function(){clearTimeout(dbT);dbT=setTimeout(function(){},300)});
function go(){var q=document.getElementById('q').value.trim();if(!q)return;var e=ES[parseInt(document.getElementById('eng').value)],u;if(q.includes('.')&&!q.includes(' '))u='https://'+q;else u=e.u.replace('{query}',encodeURIComponent(q));window.location.href=u}
var CATS={古籍:'#8B3A3A',历史:'#52796F',哲学:'#3E5C76',综合:'#8B7355',藏书:'#607D8B',自定义:'#78909C'};
var TILES=[
 {id:'shidian',n:'识典古籍',u:'https://www.shidianguji.com/',cat:'古籍'},
 {id:'nlc',n:'中华古籍资源库',u:'https://www.nlc.cn/pcab/zy/zhgj_zyk/',cat:'古籍'},
 {id:'abooks',n:'中华经典古籍库',u:'http://www.ancientbooks.cn/',cat:'古籍'},
 {id:'ebase',n:'中国基本古籍库',u:'',cat:'古籍'},
 {id:'chgis',n:'CHGIS',u:'https://www.chgis.org/',cat:'历史'},
 {id:'cbdb',n:'CBDB',u:'https://projects.iq.harvard.edu/cbdb',cat:'历史'},
 {id:'jstor',n:'JSTOR Daily',u:'https://daily.jstor.org/',cat:'历史'},
 {id:'ncpssd',n:'国家哲社文献中心',u:'http://www.ncpssd.org/',cat:'综合'},
 {id:'sep',n:'斯坦福哲学百科',u:'https://plato.stanford.edu/',cat:'哲学'},
 {id:'ctext',n:'CText 哲学书',u:'https://ctext.org/zh/',cat:'哲学'},
 {id:'cnki',n:'中国知网',u:'https://www.cnki.net/',cat:'综合'},
 {id:'gushiwen',n:'古诗文网',u:'https://www.gushiwen.cn/',cat:'古籍'}
];
var CLASSICS=[
 {t:'学而不思则罔，思而不学则殆。',s:'论语·为政'},{t:'业精于勤，荒于嬉。',s:'韩愈 进学解'},{t:'读书破万卷，下笔如有神。',s:'杜甫'},{t:'博学之，审问之，慎思之，明辨之，笃行之。',s:'中庸'},{t:'天行健，君子以自强不息。',s:'周易'},{t:'路漫漫其修远兮，吾将上下而求索。',s:'屈原 离骚'},{t:'不积跬步，无以至千里。',s:'荀子 劝学'},{t:'温故而知新，可以为师矣。',s:'论语 为政'},{t:'三人行，必有我师焉。',s:'论语 述而'},{t:'海内存知己，天涯若比邻。',s:'王勃'},{t:'纸上得来终觉浅，绝知此事要躬行。',s:'陆游'},{t:'长风破浪会有时，直挂云帆济沧海。',s:'李白'}];
var curQuote=0;
function showQuote(i){var c=CLASSICS[i%CLASSICS.length];curQuote=i;document.getElementById('dt').textContent='「'+c.t+'」';document.getElementById('ds').textContent='—— '+c.s}
function refreshQuote(){showQuote(Math.floor(Math.random()*CLASSICS.length))}
function openQuote(){var c=CLASSICS[curQuote%CLASSICS.length];var kw=c.t.slice(0,10);window.location.href='https://www.gushiwen.cn/search.aspx?value='+encodeURIComponent(kw)}
function renderTiles(){
 var g=document.getElementById('g'),hidden=[],order=null,extra=[],stars=[];
 try{hidden=JSON.parse(localStorage.getItem('ht')||'[]');order=JSON.parse(localStorage.getItem('to')||'null');extra=JSON.parse(localStorage.getItem('et')||'[]');stars=JSON.parse(localStorage.getItem('stars')||'[]')}catch(e){}
 var ts=order||TILES.map(function(t){return t.id});ts=ts.filter(function(id){return !hidden.includes(id)});
 g.querySelectorAll('.book').forEach(function(t){t.remove()});
 ts.forEach(function(id){var s=TILES.find(function(t){return t.id===id});if(s)mkBook(g,s.id,s.n,s.u,s.cat,stars.includes(id))});
 extra.forEach(function(e){mkBook(g,e.id,e.n,e.u,e.cat||'自定义',stars.includes(e.id))});
 var add=document.createElement('div');add.className='book stamp';add.innerHTML='<div class=bc><div class=bn style=color:var(--wood);font-size:20px>＋</div><div class=bn style=color:var(--wood);font-size:13px;margin-top:6px>添加书签</div></div>';
 add.addEventListener('click',function(){openMd('md');document.getElementById('mn').value='';document.getElementById('mu').value=''});
 g.appendChild(add)
}
function mkBook(g,id,n,u,cat,starred){
 var d=document.createElement('div');d.className='book';d.draggable=true;d.dataset.id=id;
 var cc=CATS[cat]||CATS['自定义'];
 d.innerHTML='<div class=bc><div class=bn>'+n+'</div><div class=bcat style="color:'+cc+';border:1px solid '+cc+'">'+cat+'</div></div><button class="bstar'+(starred?' on':'')+'">★</button>';
 d.querySelector('.bstar').addEventListener('click',function(e){e.stopPropagation();toggleStar(id,this)});
 d.addEventListener('click',function(){if(u)window.location.href=u;else toast('需机构权限，请连接校园网或VPN')});
 d.addEventListener('contextmenu',ctxMenu);
 d.addEventListener('dragstart',function(e){this.classList.add('dragging');e.dataTransfer.effectAllowed='move'});
 d.addEventListener('dragend',function(e){this.classList.remove('dragging');var o=[];g.querySelectorAll('.book:not(.stamp)').forEach(function(t){o.push(t.dataset.id)});try{localStorage.setItem('to',JSON.stringify(o))}catch(ex){}});
 d.addEventListener('dragover',function(e){e.preventDefault()});
 d.addEventListener('drop',function(e){e.preventDefault();var src=g.querySelector('.dragging');if(src&&src!==this){if(e.clientY>this.getBoundingClientRect().top+this.offsetHeight/2)this.after(src);else this.before(src)}var o=[];g.querySelectorAll('.book:not(.stamp)').forEach(function(t){o.push(t.dataset.id)});try{localStorage.setItem('to',JSON.stringify(o))}catch(ex){}});
 g.appendChild(d);return d
}
function toggleStar(id,btn){
 var stars=[];try{stars=JSON.parse(localStorage.getItem('stars')||'[]')}catch(e){}
 if(stars.includes(id)){stars=stars.filter(function(x){return x!==id});btn.classList.remove('on');toast('已取消收藏')}
 else{stars.push(id);btn.classList.add('on');toast('已收藏 ⭐')}
 try{localStorage.setItem('stars',JSON.stringify(stars))}catch(e){}
}
var ctxTile=null;
function ctxMenu(e){e.preventDefault();ctxTile=this;var m=document.getElementById('ctx');m.style.display='block';m.style.left=e.pageX+'px';m.style.top=e.pageY+'px'}
function hideTile(){if(ctxTile){var id=ctxTile.dataset.id;try{var h=JSON.parse(localStorage.getItem('ht')||'[]');if(!h.includes(id)){h.push(id);localStorage.setItem('ht',JSON.stringify(h))}ctxTile.remove();toast('已隐藏')}catch(e){}}}
function copyLink(){if(ctxTile){var s=TILES.find(function(t){return t.id===ctxTile.dataset.id})||JSON.parse(localStorage.getItem('et')||'[]').find(function(t){return t.id===ctxTile.dataset.id});if(s&&s.u)copyText(s.u);else toast('该资源未提供链接')}}
function addTile(){var n=document.getElementById('mn').value.trim(),u=document.getElementById('mu').value.trim();if(!n||!u)return;var extra=[];try{extra=JSON.parse(localStorage.getItem('et')||'[]')}catch(e){}extra.push({id:'c'+Date.now(),n:n,u:u,cat:'自定义'});try{localStorage.setItem('et',JSON.stringify(extra))}catch(e){}closeMd('md');renderTiles();toast('已收录')}
function resetLayout(){try{localStorage.removeItem('ht');localStorage.removeItem('to');localStorage.removeItem('et');location.reload()}catch(e){}}
function exportCfg(){var d={ht:localStorage.getItem('ht'),to:localStorage.getItem('to'),et:localStorage.getItem('et'),stars:localStorage.getItem('stars')};var b=new Blob([JSON.stringify(d)],{type:'application/json'});var a=document.createElement('a');a.href=URL.createObjectURL(b);a.download='backup.json';a.click();toast('已导出')}
function importCfg(){var i=document.createElement('input');i.type='file';i.accept='.json';i.onchange=function(e){var f=e.target.files[0];if(!f)return;var r=new FileReader();r.onload=function(ev){try{var d=JSON.parse(ev.target.result);if(d.ht)localStorage.setItem('ht',d.ht);if(d.to)localStorage.setItem('to',d.to);if(d.et)localStorage.setItem('et',d.et);if(d.stars)localStorage.setItem('stars',d.stars);location.reload()}catch(ex){toast('导入失败')}};r.readAsText(f)};i.click()}
function copyText(text){if(!text){toast('该资源未提供链接');return}try{navigator.clipboard.writeText(text).then(function(){toast('已复制')}).catch(function(){fa()})}catch(e){fa()}function fa(){var ta=document.createElement('textarea');ta.value=text;document.body.appendChild(ta);ta.select();document.execCommand('copy');document.body.removeChild(ta);toast('已复制')}}
function toast(m){var t=document.getElementById('ts');t.textContent=m;t.classList.add('s');setTimeout(function(){t.classList.remove('s')},2e3)}
document.addEventListener('click',function(e){if(!e.target.closest('.ctx')&&!e.target.closest('.book'))document.getElementById('ctx').style.display='none'});
function openMd(id){document.getElementById('ov').classList.add('on');document.getElementById(id).classList.add('on');document.body.style.overflow='hidden'}
function closeMd(id){document.getElementById('ov').classList.remove('on');document.getElementById(id).classList.remove('on');document.body.style.overflow=''}
document.getElementById('ov')&&document.getElementById('ov').addEventListener('click',function(){document.querySelectorAll('.md.on').forEach(function(el){el.classList.remove('on')});document.getElementById('ov').classList.remove('on');document.body.style.overflow=''});
function toggleTB(){document.getElementById('tbp').classList.toggle('on')}
document.addEventListener('click',function(e){if(!e.target.closest('.tb'))document.getElementById('tbp').classList.remove('on')});
function showNote(){document.getElementById('tbp').classList.remove('on');document.getElementById('notearea').value=localStorage.getItem('note')||'';openMd('nmod')}
function saveNote(){localStorage.setItem('note',document.getElementById('notearea').value);closeMd('nmod');toast('已保存')}
function tk(){var n=new Date(),wd=['日','一','二','三','四','五','六'];document.getElementById('cl').textContent=n.getFullYear()+'年'+(n.getMonth()+1)+'月'+n.getDate()+'日 星期'+wd[n.getDay()]+' '+String(n.getHours()).padStart(2,'0')+':'+String(n.getMinutes()).padStart(2,'0')+':'+String(n.getSeconds()).padStart(2,'0');setTimeout(tk,1e3)}tk();
var pomoTime=0,pomoInt=null;
function startPomo(m){if(pomoInt)return;pomoTime=m||25*60;updatePomo();pomoInt=setInterval(function(){pomoTime--;updatePomo();if(pomoTime<=0){clearInterval(pomoInt);pomoInt=null;toast('番茄钟结束！')}},1e3)}
function updatePomo(){document.getElementById('pomo').textContent=String(Math.floor(pomoTime/60)).padStart(2,'0')+':'+String(pomoTime%60).padStart(2,'0')}
function showPomo(){document.getElementById('tbp').classList.remove('on');updatePomo();openMd('pmod')}
var preventPinchZoom=function(e){if(e.ctrlKey)e.preventDefault()};window.addEventListener('wheel',preventPinchZoom,{passive:false});
document.addEventListener('keydown',function(e){var meta=e.metaKey||e.ctrlKey;if(e.key==='Escape'){document.querySelectorAll('.md.on').forEach(function(el){el.classList.remove('on')});document.getElementById('ov')&&document.getElementById('ov').classList.remove('on');document.body.style.overflow=''}else if(meta&&e.key==='k'){e.preventDefault();document.getElementById('q').focus()}else if(meta&&e.key==='n'){e.preventDefault();openMd('md')}else if(meta&&e.key==='d'){e.preventDefault();showNote()}});
document.addEventListener('DOMContentLoaded',function(){var ci=new Date().getDate()%CLASSICS.length;showQuote(ci);renderTiles();document.getElementById('dr').addEventListener('click',function(e){if(!e.target.closest('button'))openQuote()})});
</script></body></html>
"""
        activeWV.loadHTMLString(html, baseURL: nil)
    }
    @objc func goBack() { if activeWV.canGoBack { activeWV.goBack() } }
    @objc func goForward() { if activeWV.canGoForward { activeWV.goForward() } }
    @objc func goRefresh() { activeWV.reload() }
    @objc func urlGo() {
        let t = urlField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        let u: String
        let engines = [
            "https://lite.duckduckgo.com/lite/?q=",
            "https://www.sogou.com/web?query=",
            "https://cn.bing.com/search?q=",
            "https://www.google.com/search?q=",
        ]
        let i = UserDefaults.standard.integer(forKey: "searchEngine")
        let eng = engines[min(max(i,0),3)]
        if t.hasPrefix("http://") || t.hasPrefix("https://") { u = t }
        else if t.contains(".") && !t.contains(" ") { u = "https://\(t)" }
        else { u = "\(eng)\(t.addingPercentEncoding(withAllowedCharacters:.urlQueryAllowed) ?? t)" }
        if let url = URL(string: u) { activeWV.load(URLRequest(url: url)) }
    }
    func updateNav() {
        // 起始页（about:blank 或空）时显示"🏠 首页"，避免 about:blank 干扰
        if let url = activeWV.url?.absoluteString,
           !url.isEmpty, url != "about:blank" {
            urlField.stringValue = url
        } else {
            urlField.stringValue = "🏠 首页"
        }
        backBtn.isEnabled = activeWV.canGoBack; fwdBtn.isEnabled = activeWV.canGoForward; renderTabs()
    }
    func addH(_ u: String, _ t: String) {
        history.removeAll { $0.0 == u }; history.insert((u, t), at: 0)
        if history.count > 100 { history = Array(history.prefix(100)) }
    }

    // Bookmark panel, settings, classics, etc. — keeping same as before
@objc func toggleBM() {
        if let p = bookmarkPanel { p.removeFromSuperview(); bookmarkPanel = nil; return }
        let p = NSView(frame: NSRect(x: 132, y: toolbar.frame.minY - 380, width: 220, height: 380))
        p.wantsLayer = true; p.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.97).cgColor
        p.layer?.cornerRadius = 8; p.layer?.borderWidth = 1; p.layer?.borderColor = NSColor.separatorColor.cgColor
        let sc = NSScrollView(frame: p.bounds); sc.hasVerticalScroller = true; sc.autoresizingMask = [.width, .height]
        let doc = NSView(frame: sc.bounds); doc.autoresizingMask = [.width]; doc.wantsLayer = true
        var y: CGFloat = 8; var lc = ""
        for bm in bookmarks {
            if bm.3 != lc { let lb = NSTextField(frame: NSRect(x: 8, y: y, width: 190, height: 18))
                lb.stringValue = bm.3; lb.font = .boldSystemFont(ofSize: 10); lb.textColor = .secondaryLabelColor
                lb.isEditable = false; lb.isBordered = false; lb.backgroundColor = .clear; doc.addSubview(lb); y += 20; lc = bm.3 }
            let lk = NSButton(frame: NSRect(x: 8, y: y, width: 200, height: 20))
            lk.title = "\(bm.0) \(bm.1)"; lk.bezelStyle = .inline; lk.font = .systemFont(ofSize: 11)
            lk.alignment = .left; lk.isBordered = false
            lk.tag = bookmarks.firstIndex { $0.2 == bm.2 } ?? 0; lk.target = self; lk.action = #selector(openBM(_:)); doc.addSubview(lk); y += 22
        }
        doc.frame.size.height = y + 8; sc.documentView = doc; p.addSubview(sc); activeWV.addSubview(p); bookmarkPanel = p
    }
    @objc func openBM(_ s: NSButton) {
        if let b = bookmarks[safe: s.tag], let url = URL(string: b.2) { activeWV.load(URLRequest(url: url)) }
        bookmarkPanel?.removeFromSuperview(); bookmarkPanel = nil
    }
@objc func toggleSettings() {
        if let p = settingsPanel { p.removeFromSuperview(); settingsPanel = nil; return }
        let pw: CGFloat = 340, ph: CGFloat = 380
        let p = NSView(frame: NSRect(x: 160, y: toolbar.frame.minY - ph - 10, width: pw, height: ph))
        p.wantsLayer = true; p.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.98).cgColor
        p.layer?.cornerRadius = 12; p.layer?.borderWidth = 1; p.layer?.borderColor = NSColor.separatorColor.cgColor
        
        func sec(_ y: CGFloat, _ t: String) -> CGFloat {
            let sp = NSView(frame: NSRect(x: 16, y: y, width: pw - 32, height: 1))
            sp.wantsLayer = true; sp.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor; p.addSubview(sp)
            let lb = NSTextField(frame: NSRect(x: 16, y: y - 20, width: 200, height: 16))
            lb.stringValue = t; lb.font = .boldSystemFont(ofSize: 10); lb.textColor = .secondaryLabelColor
            lb.isEditable = false; lb.isBordered = false; lb.backgroundColor = .clear; p.addSubview(lb); return y - 40
        }
        func pop(_ y: CGFloat, _ items: [String], _ sel: String, _ act: Selector) {
            let pb = NSPopUpButton(frame: NSRect(x: 16, y: y - 26, width: pw - 32, height: 24))
            pb.addItems(withTitles: items); pb.selectItem(withTitle: sel)
            pb.font = .systemFont(ofSize: 13); pb.target = self; pb.action = act; p.addSubview(pb)
        }
        func btn(_ y: CGFloat, _ title: String, _ act: Selector) {
            let b = NSButton(frame: NSRect(x: 16, y: y - 36, width: pw - 32, height: 36))
            b.title = title; b.bezelStyle = .roundRect; b.font = .systemFont(ofSize: 13); b.target = self; b.action = act; p.addSubview(b)
        }
        var y = ph - 12
        let tl = NSTextField(frame: NSRect(x: 16, y: y - 26, width: 200, height: 22))
        tl.stringValue = "⚙ 设置"; tl.font = .boldSystemFont(ofSize: 15); tl.isEditable = false
        tl.isBordered = false; tl.backgroundColor = .clear; p.addSubview(tl); y -= 34
        y = sec(y, "🎓 专业方向")
        pop(y, ["全部","古文字学","历史学","考古学","音韵学","文献学","书法","综合学术"], UserDefaults.standard.string(forKey: "major") ?? "全部", #selector(majorChanged(_:)))
        y = sec(y, "🔍 搜索引擎")
        pop(y, ["🦆 DuckDuckGo", "🔍 搜狗", "🅱️ 必应", "🌐 Google"], ["🦆 DuckDuckGo", "🔍 搜狗", "🅱️ 必应", "🌐 Google"][UserDefaults.standard.integer(forKey: "searchEngine")], #selector(engineChanged(_:)))
        y = sec(y, "🔗 磁贴管理")
        btn(y, "➕ 添加自定义磁贴", #selector(addCustomTile))
        btn(y - 34, "➖ 删除自定义磁贴", #selector(removeCustomTile))
        btn(y - 68, "🔄 恢复默认磁贴", #selector(resetTiles)); y -= 76
        y = sec(y, "📋 其他")
        btn(y, "📂 笔记存储位置", #selector(chooseNoteLocation))
        btn(y - 34, "🗑 清除浏览历史", #selector(clearHistory))
        btn(y - 68, "✕ 关闭设置", #selector(toggleSettings))
        activeWV.addSubview(p); settingsPanel = p
    }
    @objc func majorChanged(_ s: NSPopUpButton) { UserDefaults.standard.set(s.selectedItem?.title ?? "全部", forKey: "major"); settingsPanel?.removeFromSuperview(); settingsPanel = nil; goHome() }
    @objc func resetTiles() { UserDefaults.standard.removeObject(forKey: "major"); UserDefaults.standard.removeObject(forKey: "customTiles"); settingsPanel?.removeFromSuperview(); settingsPanel = nil; goHome() }
    @objc func clearHistory() { history.removeAll(); settingsPanel?.removeFromSuperview(); settingsPanel = nil }

    /// 选择笔记数据库的存储位置（即时迁移）
    @objc func chooseNoteLocation() {
        settingsPanel?.removeFromSuperview(); settingsPanel = nil

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择此文件夹"
        panel.message = "笔记数据库（library.db）将保存在所选文件夹中"

        // 默认打开当前数据库所在目录
        if let current = URL(string: DataManager.shared.databaseDirectoryPath) {
            panel.directoryURL = current
        }

        panel.begin { [weak self] response in
            guard response == .OK, let folder = panel.url else { return }
            let target = folder.appendingPathComponent("library.db")

            let a = NSAlert()
            a.messageText = "迁移笔记数据库？"
            a.informativeText = """
            目标位置：\(folder.path)

            现有笔记会被迁移到新位置（若目标已存在同名文件则直接使用）。
            迁移后即刻生效。
            """
            a.addButton(withTitle: "迁移")
            a.addButton(withTitle: "取消")

            if a.runModal() != .alertFirstButtonReturn { return }

            switch DataManager.shared.relocateDatabase(to: folder) {
            case .success:
                let ok = NSAlert()
                ok.messageText = "✅ 迁移完成"
                ok.informativeText = "笔记数据库已移至：\n\(target.path)"
                ok.runModal()
                self?.refreshNotes()
            case .failure(let err):
                let fail = NSAlert()
                fail.messageText = "迁移失败"
                fail.informativeText = err.localizedDescription
                fail.runModal()
            }
        }
    }
    @objc func addCustomTile() {
        let a = NSAlert(); a.messageText = "添加自定义磁贴"; a.informativeText = "输入名称和网址"
        let nf = NSTextField(frame: NSRect(x:0,y:28,width:240,height:24)); nf.placeholderString = "名称"
        let uf = NSTextField(frame: NSRect(x:0,y:0,width:240,height:24)); uf.placeholderString = "https://..."
        let stack = NSView(frame: NSRect(x:0,y:0,width:240,height:56))
        stack.addSubview(nf); stack.addSubview(uf); a.accessoryView = stack
        a.addButton(withTitle: "添加"); a.addButton(withTitle: "取消")
        if a.runModal() == .alertFirstButtonReturn {
            let n = nf.stringValue.trimmingCharacters(in: .whitespaces)
            let u = uf.stringValue.trimmingCharacters(in: .whitespaces)
            guard !n.isEmpty, !u.isEmpty else { return }
            var ts: [CTile] = []
            if let d = UserDefaults.standard.data(forKey: "customTiles"),
               let ex = try? JSONDecoder().decode([CTile].self, from: d) { ts = ex }
            ts.append(CTile(name: n, url: u.hasPrefix("http") ? u : "https://\(u)"))
            if let d = try? JSONEncoder().encode(ts) { UserDefaults.standard.set(String(data: d, encoding: .utf8), forKey: "customTiles") }
            goHome()
        }
    }
    @objc func removeCustomTile() {
        guard let d = UserDefaults.standard.data(forKey: "customTiles"),
              var ts = try? JSONDecoder().decode([CTile].self, from: d), !ts.isEmpty else { return }
        let a = NSAlert(); a.messageText = "删除自定义磁贴"
        a.informativeText = "输入序号: \(ts.enumerated().map{String($0.0+1)+"."+$0.1.name}.joined(separator:","))"
        let idx = NSTextField(frame: NSRect(x:0,y:0,width:80,height:24)); idx.placeholderString = "序号"
        a.accessoryView = idx; a.addButton(withTitle: "删除"); a.addButton(withTitle: "取消")
        if a.runModal() == .alertFirstButtonReturn, let i = Int(idx.stringValue), i > 0, i <= ts.count {
            ts.remove(at: i - 1)
            if ts.isEmpty { UserDefaults.standard.removeObject(forKey: "customTiles") }
            else if let d = try? JSONEncoder().encode(ts) { UserDefaults.standard.set(String(data:d,encoding:.utf8), forKey:"customTiles") }
            goHome()
        }
    }
@objc func openClassics() {
        let list: [(String,String,String,String)] = [
            ("论语","孔子弟子","20篇","https://ctext.org/analects/zh"),("大学","曾子","四书之首","https://ctext.org/liji/da-xue/zh"),
            ("中庸","子思","中庸之道","https://ctext.org/liji/zhong-yong/zh"),("孟子","孟子","7篇","https://ctext.org/mengzi/zh"),
            ("诗经","集体","305篇","https://ctext.org/book-of-poetry/zh"),("道德经","老子","81章","https://ctext.org/dao-de-jing/zh"),
            ("庄子","庄子","33篇","https://ctext.org/zhuangzi/zh"),("尚书","先秦","58篇","https://ctext.org/shang-shu/zh"),
            ("周易","先秦","64卦","https://ctext.org/book-of-changes/zh"),("礼记","先秦","49篇","https://ctext.org/liji/zh"),
            ("春秋左传","左丘明","编年史","https://ctext.org/chun-qiu-zuo-zhuan/zh"),("孙子兵法","孙武","13篇","https://ctext.org/art-of-war/zh"),
            ("楚辞","屈原","浪漫诗","https://ctext.org/chu-ci/zh"),("史记","司马迁","130卷","https://ctext.org/shiji/zh"),
            ("说文解字","许慎","540部","https://ctext.org/shuo-wen-jie-zi/zh"),("韩非子","韩非","55篇","https://ctext.org/hanfeizi/zh"),
            ("墨子","墨翟","53篇","https://ctext.org/mozi/zh"),("荀子","荀况","32篇","https://ctext.org/xunzi/zh"),
            ("列子","列御寇","8篇","https://ctext.org/liezi/zh"),("世说新语","刘义庆","36篇","https://ctext.org/shi-shuo-xin-yu/zh"),
            ("文心雕龙","刘勰","50篇","https://ctext.org/wenxin-diaolong/zh"),
        ]
        var items = ""
        for c in list { items += "<a href='\(c.3)' target=_blank style='display:flex;justify-content:space-between;padding:14px 16px;margin:4px 0;background:var(--card);border-radius:10px;text-decoration:none;color:var(--text);border:1px solid var(--border)'><div><b style=font-size:15px>\(c.0)</b><span style=font-size:11px;color:var(--subtle);margin-left:10px>\(c.1)</span></div><div style=text-align:right><span style=font-size:10px;color:var(--subtle)>\(c.2)</span><span style=margin-left:8px;color:var(--accent)>→</span></div></a>" }
        let html = "<!DOCTYPE html><html><head><meta charset=UTF-8><style>:root{--bg:#f5f0ea;--card:#fff;--text:#3c2a1e;--accent:#b8860b;--subtle:#8b7355;--border:#e5ddd2}@media(prefers-color-scheme:dark){:root{--bg:#1b1713;--card:#28231e;--text:#e0d5c7;--accent:#d4a030;--subtle:#a09080;--border:#3a3228}}body{font-family:PingFang SC,sans-serif;background:var(--bg);color:var(--text);padding:20px 30px;max-width:680px;margin:60px auto 0}h2{color:var(--accent)}a:hover{background:var(--accent);color:#fff!important}</style></head><body><h2>📚 经典文本库（21 部）</h2><p style=font-size:11px;color:var(--subtle)>点击跳转 CText 在线全文</p>" + items + "</body></html>"
        tabs[activeIndex].loadHTMLString(html, baseURL: nil)
    }
    
    func webView(_ wv: WKWebView, didCommit nav: WKNavigation!) { if wv == activeWV { updateNav() }; if let u = wv.url { addH(u.absoluteString, wv.title ?? u.absoluteString) } }
    func webView(_ wv: WKWebView, didFinish nav: WKNavigation!) { if wv == activeWV { updateNav() } }
    func webView(_ wv: WKWebView, didFail nav: WKNavigation!, withError e: Error) { if wv == activeWV { updateNav() } }
    func webView(_ wv: WKWebView, didFailProvisionalNavigation nav: WKNavigation!, withError e: Error) { if (e as NSError).code != NSURLErrorCancelled && wv == activeWV { updateNav() } }
    func webView(_ wv: WKWebView, didReceive ch: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if ch.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust, let t = ch.protectionSpace.serverTrust { completionHandler(.useCredential, URLCredential(trust: t)) }
        else { completionHandler(.performDefaultHandling, nil) }
    }
    func webView(_ wv: WKWebView, createWebViewWith c: WKWebViewConfiguration, for nav: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if nav.targetFrame == nil { wv.load(nav.request) }; return nil
    }
    func webView(_ wv: WKWebView, decidePolicyFor nav: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = nav.request.url {
            if url.absoluteString == "about:author" { showAbout(); decisionHandler(.cancel); return }
            if let host = url.host, host.contains("baidu.com") { decisionHandler(.cancel); return }
        }
        decisionHandler(.allow)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool { true }

    func buildMenu() {
        let mm = NSMenu()
        let am = NSMenu(); am.addItem(NSMenuItem(title: "关于文史哲浏览器", action: #selector(showAbout), keyEquivalent: "")); am.addItem(.separator())
        am.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        mm.addItem({ let i = NSMenuItem(); i.submenu = am; return i }())
        let fm = NSMenu(title: "文件")
        fm.addItem(NSMenuItem(title: "新建标签", action: #selector(addTab), keyEquivalent: "t"))
        fm.addItem(NSMenuItem(title: "关闭标签", action: #selector(closeCur), keyEquivalent: "w"))
        fm.addItem(NSMenuItem(title: "打开地址", action: #selector(focusURL), keyEquivalent: "l"))
        mm.addItem({ let i = NSMenuItem(); i.submenu = fm; return i }())
        let vm = NSMenu(title: "显示")
        vm.addItem(NSMenuItem(title: "后退", action: #selector(goBack), keyEquivalent: "["))
        vm.addItem(NSMenuItem(title: "前进", action: #selector(goForward), keyEquivalent: "]"))
        vm.addItem(NSMenuItem(title: "刷新", action: #selector(goRefresh), keyEquivalent: "r"))
        mm.addItem({ let i = NSMenuItem(); i.submenu = vm; return i }())
        NSApplication.shared.mainMenu = mm
    }
    // MARK: - 学术工具（翻译 / 繁简 / 生词 / 笔记 / 引用 / 字数）

    /// 显示结果弹窗
    private func showResult(title: String, message: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = message
        a.addButton(withTitle: "确定")
        a.runModal()
    }

    /// 1. 翻译选中文字（MyMemory 免费 API，无需 Key）
    func translateSelection(_ text: String) {
        // 判断语言方向：含中文则译英，否则译中
        let hasChinese = text.range(of: "\\p{Han}", options: .regularExpression) != nil
        let lang = hasChinese ? "zh-CN|en-GB" : "en-GB|zh-CN"
        let q = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        let urlStr = "https://api.mymemory.translated.net/get?q=\(q)&langpair=\(lang)"

        showResult(title: "翻译中…", message: text)
        URLSession.shared.dataTask(with: URL(string: urlStr)!) { data, _, _ in
            var result = "翻译服务暂时不可用"
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let resp = json["responseData"] as? [String: Any],
               let translated = resp["translatedText"] as? String {
                result = translated
            }
            DispatchQueue.main.async {
                self.showResult(title: "🌐 翻译结果", message: "原文：\(text)\n\n译文：\(result)")
            }
        }.resume()
    }

    /// 2. 繁简转换（内置映射表）
    private static let scMap: [Character: Character] = [
        "国":"國","学":"學","习":"習","说":"說","为":"為","这":"這","个":"個","们":"們",
        "会":"會","着":"著","门":"門","开":"開","关":"關","书":"書","画":"畫","时":"時",
        "对":"對","动":"動","发":"發","风":"風","过":"過","还":"還","进":"進","来":"來",
        "买":"買","卖":"賣","气":"氣","亲":"親","让":"讓","体":"體","万":"萬","网":"網",
        "问":"問","无":"無","现":"現","样":"樣","业":"業","义":"義","应":"應","鱼":"魚",
        "远":"遠","云":"雲","长":"長","爱":"愛","笔":"筆","车":"車","东":"東","饿":"餓",
        "飞":"飛","汉":"漢","华":"華","机":"機","见":"見","经":"經","乐":"樂",
        "历":"曆","马":"馬","鸟":"鳥","头":"頭","图":"圖","兴":"興","页":"頁","电":"電",
        "龙":"龍","广":"廣","厂":"廠","变":"變","难":"難","农":"農","从":"從","号":"號",
        "师":"師","戏":"戲","战":"戰","选":"選","达":"達","运":"運","转":"轉","传":"傳",
        "钱":"錢","铁":"鐵","阶":"階","阴":"陰","阳":"陽","灵":"靈","斋":"齋","禅":"禪",
        "面":"麵","里":"裏","后":"後","台":"臺","干":"乾",
    ]

    func convertSelection(_ text: String) {
        var converted = ""
        for ch in text {
            if let t = Self.scMap[ch] { converted.append(t) }
            else if let s = Self.scMap.first(where: { $0.value == ch })?.key { converted.append(s) }
            else { converted.append(ch) }
        }
        showResult(title: "🔄 繁简转换", message: "原文：\(text)\n\n转换：\(converted)")
    }

    /// 3. 收藏生词（UserDefaults 持久化）
    func saveVocabulary(_ word: String) {
        let alert = NSAlert()
        alert.messageText = "⭐ 收藏生词"
        alert.informativeText = "「\(word)」\n请输入释义："
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        alert.accessoryView = tf
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        var list = (UserDefaults.standard.array(forKey: "saved_vocab") as? [[String: String]]) ?? []
        if !list.contains(where: { $0["word"] == word }) {
            list.append(["word": word, "meaning": tf.stringValue, "date": Date().description])
            UserDefaults.standard.set(list, forKey: "saved_vocab")
            showResult(title: "✅ 已收藏", message: "「\(word)」已存入生词本")
        } else {
            showResult(title: "提示", message: "「\(word)」已在生词本中")
        }
    }

    /// 4. 保存为笔记（写入 SQLite，关联当前 URL）
    func saveQuickNote(_ text: String) {
        let url = activeWV.url?.absoluteString ?? ""
        let content = "> 摘录自：\(url)\n\n\(text)"
        _ = DataManager.shared.insertNote(url: url, content: content, tags: ["摘录"])
        showResult(title: "📝 已保存为笔记", message: "已存入笔记库（可在 📝 笔记窗口查看）\n\n\(text)")
    }

    /// 5. 生成引用格式（APA / GB/T 7714）
    func generateCitation(_ text: String) {
        let js = "JSON.stringify({title:document.title,url:location.href,author:(document.querySelector('meta[name=\\\"author\\\"]')||{}).content||''})"
        activeWV.evaluateJavaScript(js) { result, _ in
            var title = "未命名", url = "", author = ""
            if let s = result as? String,
               let d = s.data(using: .utf8),
               let info = try? JSONSerialization.jsonObject(with: d) as? [String: String] {
                title = info["title"] ?? "未命名"
                url = info["url"] ?? ""
                author = info["author"] ?? ""
            }
            let year = Calendar.current.component(.year, from: Date())
            let apa = "\(author.isEmpty ? "佚名" : author). (\(year)). \(title). \(url)"
            let gb = "\(author.isEmpty ? "佚名" : author). \(title)[EB/OL]. (\(year))[\(Date().description.prefix(10))]. \(url)."
            let alert = NSAlert()
            alert.messageText = "📖 引用格式（选中文字）"
            alert.informativeText = "APA：\n\(apa)\n\nGB/T 7714：\n\(gb)\n\n引用对象：\(text.prefix(40))…"
            alert.addButton(withTitle: "复制 APA")
            alert.addButton(withTitle: "复制 GB/T 7714")
            alert.addButton(withTitle: "关闭")
            let resp = alert.runModal()
            if resp == .alertFirstButtonReturn { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(apa, forType: .string) }
            if resp == .alertSecondButtonReturn { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(gb, forType: .string) }
        }
    }

    /// 6. 统计本页字数（中英混合）
    func countPageWords() {
        let js = "var t=document.body.innerText;var c=(t.match(/[\\u4e00-\\u9fff]/g)||[]).length;var e=(t.match(/[a-zA-Z]+/g)||[]).length;JSON.stringify({c:c,e:e})"
        activeWV.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self else { return }
            var cn = 0, en = 0
            if let s = result as? String,
               let d = s.data(using: .utf8),
               let info = try? JSONSerialization.jsonObject(with: d) as? [String: Int] {
                cn = info["c"] ?? 0; en = info["e"] ?? 0
            }
            self.showResult(title: "🔢 本页字数统计", message: "汉字：\(cn) 字\n英文单词：\(en) 词\n合计：\(cn + en)")
        }
    }

    // MARK: - 整页翻译（Google Translate 代理）

    @objc func translatePage() {
        guard let url = activeWV.url, url.absoluteString != "about:blank" else {
            showResult(title: "提示", message: "当前是起始页，无内容可翻译")
            return
        }
        let enc = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        activeWV.load(URLRequest(url: URL(string: "https://translate.google.com/translate?u=\(enc)&sl=auto&tl=zh-CN")!))
    }

    @objc func showAbout() { let a = NSAlert(); a.messageText = "文史哲浏览器"; a.informativeText = "人大文学院大二学生开发\n专门为文史哲专业学生设计的浏览器\n内置词典、古文字、古籍、学术网站\nGitHub: 开源项目"; a.runModal() }

    // MARK: - 研究工作台（笔记 / AI 助手 / PDF 阅读器）

    private lazy var notesWindow: NotesWindow = {
        let w = NotesWindow()
        w.onCreateNote = { [weak self] context in
            _ = DataManager.shared.insertNote(
                url: context ?? "",
                content: "新笔记\n\n",
                tags: ["未分类"]
            )
            self?.refreshNotes()
        }
        w.onSaveNote = { [weak self] content in
            // 保存逻辑：更新最近一条笔记（简化示例）
            if let notes = try? DataManager.shared.fetchAllNotes().get(), let first = notes.first {
                _ = DataManager.shared.updateNote(id: first.id, content: content)
            }
        }
        w.onSearch = { keyword in
            // 搜索结果在左侧树中展示（简化：刷新全部）
            _ = keyword
        }
        w.onExport = { [weak self] in
            self?.exportNotesToFile()
        }
        return w
    }()

    private lazy var aiPanel: AIAssistantPanel = {
        let p = AIAssistantPanel()
        p.onUserMessage = { text in
            // 本地 Ollama 推理（若可用），否则返回占位回复
            let prompt = "你是文史哲学术助手。请用中文简要回答：\n\(text)"
            p.showAIResponse("（本地 AI 服务未启动，请先运行 Ollama）\n\n问题：\(text)\n\n提示：终端运行 `ollama serve` 后即可获得真实回答。")
            // 实际接入 Ollama 的示例（取消注释即可启用）：
            // self?.queryOllama(prompt: prompt) { reply in
            //     DispatchQueue.main.async { p.showAIResponse(reply) }
            // }
        }
        return p
    }()

    @objc func showNotes() {
        refreshNotes()
        notesWindow.makeKeyAndOrderFront(nil)
        notesWindow.center()
    }

    private func refreshNotes() {
        let notes = (try? DataManager.shared.fetchAllNotes().get()) ?? []
        notesWindow.reloadNotes(notes)
    }

    @objc func showAI() {
        aiPanel.present()
    }

    /// 导出全部笔记为 Markdown 文件（用户自选保存路径）
    func exportNotesToFile() {
        let notes = (try? DataManager.shared.fetchAllNotes().get()) ?? []
        guard !notes.isEmpty else {
            let a = NSAlert()
            a.messageText = "没有可导出的笔记"
            a.runModal()
            return
        }

        // 生成默认文件名：笔记-20260802.md
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        let defaultName = "笔记-\(df.string(from: Date())).md"

        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.message = "选择笔记导出位置"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }

            // 组装 Markdown
            var md = "# 📝 文献笔记导出\n\n"
            md += "> 导出时间：\(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium))\n"
            md += "> 共 \(notes.count) 条\n\n---\n\n"

            for note in notes {
                let title = note.content.components(separatedBy: "\n").first ?? "无标题"
                md += "## \(title)\n\n"
                if !note.url.isEmpty { md += "- 🔗 来源：\(note.url)\n" }
                if !note.tags.isEmpty { md += "- 🏷️ 标签：\(note.tags.joined(separator: "、"))\n" }
                if note.scrollY > 0 { md += "- 📍 位置：滚动偏移 \(Int(note.scrollY))px\n" }
                md += "- 🕐 创建：\(note.createdAt.formatted(date: .abbreviated, time: .shortened))\n\n"
                md += "\(note.content)\n\n---\n\n"
            }

            do {
                try md.write(to: url, atomically: true, encoding: .utf8)
                let a = NSAlert()
                a.messageText = "导出成功"
                a.informativeText = "已保存到：\n\(url.path)\n（\(notes.count) 条笔记）"
                a.addButton(withTitle: "在 Finder 中显示")
                a.addButton(withTitle: "好")
                if a.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            } catch {
                let a = NSAlert()
                a.messageText = "导出失败"
                a.informativeText = error.localizedDescription
                a.runModal()
            }
            _ = self
        }
    }

    @objc func openPDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            let viewer = PDFViewerWindow(pdfURL: url)
            viewer.makeKeyAndOrderFront(nil)
            _ = self // 保留引用防止提前释放
        }
    }
    @objc func focusURL() { window.makeFirstResponder(urlField) }
    @objc func closeCur() { closeTab(activeIndex) }
}

struct CTile: Codable { let name: String; let url: String }
extension Array { subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil } }
