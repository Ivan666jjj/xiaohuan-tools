import Cocoa
import WebKit

// ============================================================
// AppDelegate.swift — 金融学经济学浏览器核心逻辑
// 复用文史哲浏览器架构铁律：
//   1. contentView = webView（不嵌套容器，防白屏）
//   2. 按钮 target = self
//   3. 工具栏 / 标签栏是 webView.subview
// ============================================================

// MARK: - FinanceWebView（右键金融搜索）

final class FinanceWebView: WKWebView, NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // 清空上次加入的自定义项（tag=8888），保留系统默认项
        menu.items.filter { $0.tag == 8888 }.forEach { menu.removeItem($0) }
        menu.addItem(.separator())
        for s in financeSearchServices {
            let item = NSMenuItem(title: "🔍 \(s.0)", action: #selector(searchIn(_:)), keyEquivalent: "")
            item.representedObject = s.1; item.target = self; item.tag = 8888
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let tools: [(String, Selector)] = [
            ("🌐 翻译（金融领域）", #selector(trFin(_:))),
            ("📖 展开缩写 / 查术语", #selector(lkTerm(_:))),
            ("🔢 换算数量级", #selector(cvtMag(_:))),
            ("💱 按汇率换算", #selector(cvtFx(_:))),
        ]
        for (t, a) in tools {
            let item = NSMenuItem(title: t, action: a, keyEquivalent: "")
            item.target = self; item.tag = 8888
            menu.addItem(item)
        }
    }

    @objc func searchIn(_ sender: NSMenuItem) {
        guard let template = sender.representedObject as? String else { return }
        selText { [weak self] tx in
            let url = template.replacingOccurrences(
                of: "{query}",
                with: tx.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? tx
            )
            self?.load(URLRequest(url: URL(string: url)!))
        }
    }

    // MARK: 金融学术工具（转发 AppDelegate）

    private func selText(_ done: @escaping (String) -> Void) {
        Task { @MainActor in
            if let r = try? await evaluateJavaScript("window.getSelection().toString()"),
               let tx = r as? String, !tx.trimmingCharacters(in: .whitespaces).isEmpty {
                done(tx)
            }
        }
    }
    @objc func trFin(_ s: NSMenuItem) { selText { (NSApp.delegate as? AppDelegate)?.translateFinance($0) } }
    @objc func lkTerm(_ s: NSMenuItem) { selText { (NSApp.delegate as? AppDelegate)?.lookupTerm($0) } }
    @objc func cvtMag(_ s: NSMenuItem) { selText { (NSApp.delegate as? AppDelegate)?.convertMagnitude($0) } }
    @objc func cvtFx(_ s: NSMenuItem) { selText { (NSApp.delegate as? AppDelegate)?.convertCurrency($0) } }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate {

    // MARK: 窗口与标签

    var window: NSWindow!
    var tabs: [WKWebView] = []
    var activeIndex = 0
    var urlField: NSTextField!
    var backBtn: NSButton!, fwdBtn: NSButton!
    var tabBar: NSView!, toolbar: NSView!
    var bookmarkPanel: NSView?, settingsPanel: NSView?
    var tickerBar: NSView!
    var tickerTimer: Timer?
    var tickerOffset: CGFloat = 0
    var history: [(String, String)] = []

    var activeWV: WKWebView { tabs[activeIndex] }

    // MARK: 生命周期

    func applicationDidFinishLaunching(_ n: Notification) {
        let rect = NSRect(x: 0, y: 0, width: 1280, height: 820)
        window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = APP_NAME
        window.minSize = NSSize(width: 800, height: 500)
        window.center()

        let wv = makeWV()
        window.contentView = wv
        setupChrome(on: wv, width: rect.width)
        tabs.append(wv); activeIndex = 0
        buildMenu()
        window.makeKeyAndOrderFront(nil)
        goHome()
    }

    // MARK: WebView 工厂

    func makeWV() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        // 广告拦截（财经网站通用广告类名）
        let adJS = """
        (function(){
        var s=document.createElement('style');s.id='fa';
        s.textContent='[class*="ad-"],[id*="ad-"],[class*="ads"],[class*="gg_"],[class*="ggbox"],[class*="adt"],[class*="adv"],[class*="banner"],[id*="banner"],[class*="sponsor"],[class*="promo"],[class*="popup"],[class*="recommend"],[class*="advert"],.advertisement,iframe[src*="doubleclick"],iframe[src*="googlead"],iframe[src*="cpro"],iframe[src*="tanx"],iframe[src*="pos.baidu"],div[id*="gpt-ad"],[data-google-query-id],.adsbygoogle,ins.adsbygoogle,div[id^="google_ads"],div[id^="aswift"],div[class*="tj_"],[class*="s_ad"],[class*="adbox"],[class*="m_adv"],[class*="ec_ad"],[class*="gg"][class*="box"],.dsp,.dspad,[class*="advertise"],[class*="list_ad"],[class*="col_ad"],[id*="adFrame"],[class*="ggbox"],[class*="ggad"],[class*="adbanner"],[class*="afu"],a[href*="go.peak.gg"],a[href*="union-click"],a[href*="cpro.baidu"]{display:none!important;height:0!important;overflow:hidden!important;opacity:0!important;pointer-events:none!important}';
        if(document.head)document.head.appendChild(s);else document.addEventListener('DOMContentLoaded',function(){document.head.appendChild(s)})})();
        """
        config.userContentController.addUserScript(
            WKUserScript(source: adJS, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )

        let wv = FinanceWebView(frame: .zero, configuration: config)
        // 右键菜单：显式绑定 NSMenu + delegate，确保 menuNeedsUpdate 稳定触发
        let ctxMenu = NSMenu()
        ctxMenu.delegate = wv
        wv.menu = ctxMenu
        wv.navigationDelegate = self
        wv.uiDelegate = self
        wv.allowsBackForwardNavigationGestures = true
        wv.allowsMagnification = true
        // 伪装为合法浏览器 UA，规避部分金融网站反爬
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        // 术语悬浮气泡（仅词典词触发）
        let hoverJS = """
        (function(){
        var D={duration:"久期",leverage:"杠杆",equity:"权益",margin:"保证金/利润率",exposure:"敞口",liquidity:"流动性",arbitrage:"套利",hedge:"对冲",convexity:"凸性",yield:"收益率",default:"违约",option:"期权",future:"期货",swap:"互换",derivative:"衍生品"};
        var tip=null;
        document.addEventListener('mouseover',function(e){
          var el=e.target;if(!el||!el.innerText)return;
          var w=(el.innerText||'').trim().split(/\\s+/)[0].toLowerCase();
          if(!D[w])return;
          tip=document.createElement('div');tip.textContent=w+' → '+D[w];
          tip.style.cssText='position:fixed;z-index:2147483647;background:#1e293b;color:#e2e8f0;padding:4px 8px;border-radius:6px;font-size:12px;pointer-events:none';
          tip.style.left=(e.clientX+12)+'px';tip.style.top=(e.clientY+12)+'px';
          document.body.appendChild(tip);
        });
        document.addEventListener('mouseout',function(){if(tip){tip.remove();tip=null}});
        })();
        """
        config.userContentController.addUserScript(
            WKUserScript(source: hoverJS, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        )

        // MathJax 公式渲染（仅学术站点：ssrn/repec/nber）
        let mathjaxJS = """
        (function(){var h=location.host;
        if(h.indexOf('ssrn.com')>=0||h.indexOf('repec.org')>=0||h.indexOf('nber.org')>=0){
          var s=document.createElement('script');s.src='https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js';s.async=true;document.head.appendChild(s);
        }})();
        """
        config.userContentController.addUserScript(
            WKUserScript(source: mathjaxJS, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        )
        return wv
    }

    // MARK: 工具栏 / 标签栏 / 行情条

    func setupChrome(on wv: WKWebView, width: CGFloat) {
        let barH: CGFloat = 30, toolH: CGFloat = 36, tickH: CGFloat = 24

        tabBar = NSView(frame: NSRect(x: 0, y: wv.bounds.height - barH - toolH - tickH, width: width, height: barH))
        tabBar.autoresizingMask = [.width, .minYMargin]
        wv.addSubview(tabBar)

        toolbar = NSView(frame: NSRect(x: 0, y: wv.bounds.height - toolH - tickH, width: width, height: toolH))
        toolbar.autoresizingMask = [.width, .minYMargin]
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
        wv.addSubview(toolbar)

        // 行情滚动条（底部）
        tickerBar = NSView(frame: NSRect(x: 0, y: wv.bounds.height - tickH, width: width, height: tickH))
        tickerBar.autoresizingMask = [.width, .minYMargin]
        tickerBar.wantsLayer = true
        tickerBar.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        wv.addSubview(tickerBar)
        buildTicker()

        let btns: [(String, Selector)] = [
            ("◀", #selector(goBack)), ("▶", #selector(goForward)), ("↻", #selector(goRefresh)),
            ("🏠", #selector(goHome)), ("📈", #selector(openMarket)), ("📖", #selector(toggleBM)),
            ("🧮", #selector(openCalculator)), ("📅", #selector(openCalendar)), ("🌐", #selector(translatePage)),
            ("⚙", #selector(toggleSettings)), ("📊", #selector(openFinanceBooks)),
        ]
        var bx: CGFloat = 4
        for (t, a) in btns {
            let b = NSButton(frame: NSRect(x: bx, y: 0, width: 36, height: 34))
            b.title = t
            b.bezelStyle = .roundRect
            b.font = .systemFont(ofSize: 14)
            b.target = self
            b.action = a
            toolbar.addSubview(b)
            if t == "◀" { backBtn = b } else if t == "▶" { fwdBtn = b }
            bx += 36
        }

        // 搜索引擎切换
        let engBtn = NSPopUpButton(frame: NSRect(x: bx, y: 0, width: 130, height: 34))
        engBtn.addItems(withTitles: financeSearchEngines.map { $0.0 })
        engBtn.font = .systemFont(ofSize: 11)
        engBtn.target = self
        engBtn.action = #selector(engineChanged(_:))
        engBtn.selectItem(at: UserDefaults.standard.integer(forKey: "searchEngine"))
        toolbar.addSubview(engBtn)
        bx += 134

        urlField = NSTextField(frame: NSRect(x: bx, y: 3, width: width - bx - 8, height: 28))
        urlField.autoresizingMask = [.width]
        urlField.placeholderString = "搜索股票 / 基金 / 经济指标 / 网址…"
        urlField.font = .systemFont(ofSize: 13)
        urlField.bezelStyle = .roundedBezel
        urlField.target = self
        urlField.action = #selector(urlGo)
        toolbar.addSubview(urlField)
    }

    // MARK: 行情滚动条

    func buildTicker() {
        tickerBar.subviews.forEach { $0.removeFromSuperview() }
        tickerOffset = 0
        startTicker()
    }

    func startTicker() {
        tickerTimer?.invalidate()
        tickerTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            self?.tickTicker()
        }
        // 确保 timer 在滚动模式运行
        RunLoop.main.add(tickerTimer!, forMode: .common)
    }

    func tickTicker() {
        guard let bar = tickerBar else { return }
        let content = tickerContent()
        tickerOffset -= 0.8
        if -tickerOffset >= CGFloat(content.count * 120) { tickerOffset = 0 }
        // 重建内容并平移
        bar.subviews.forEach { $0.removeFromSuperview() }
        var x = tickerOffset
        for item in content {
            let label = NSTextField(labelWithString: item)
            label.font = NSFont(name: "Menlo", size: 11) ?? .systemFont(ofSize: 11)
            label.textColor = item.contains("▲") ? NSColor(red: 0.35, green: 0.75, blue: 0.42, alpha: 1)
                                                  : (item.contains("▼") ? NSColor(red: 0.88, green: 0.35, blue: 0.35, alpha: 1)
                                                                         : .white)
            label.frame = NSRect(x: x, y: 4, width: 110, height: 16)
            bar.addSubview(label)
            x += 120
        }
    }

    func tickerContent() -> [String] {
        var out: [String] = []
        for m in marketIndexes {
            // 模拟实时：基于当前秒做小幅漂移，避免静止感
            let sec = Int(Date().timeIntervalSince1970) % 60
            let drift = Double((sec % 5) - 2) * 0.01
            let p = m.price + drift
            let chg = m.change + drift * 0.3
            let up = chg >= 0
            let priceText: String
            let fmt = NumberFormatter()
            fmt.numberStyle = .decimal
            fmt.maximumFractionDigits = p >= 100 ? 2 : 4
            priceText = fmt.string(from: NSNumber(value: p)) ?? "\(p)"
            out.append("\(m.name) \(priceText) \(up ? "▲" : "▼")\(String(format: "%.2f", chg))%")
        }
        return out
    }

    // MARK: 搜索逻辑（金融智能识别）

    @objc func engineChanged(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(sender.indexOfSelectedItem, forKey: "searchEngine")
    }

    func isStockCode(_ s: String) -> Bool {
        if s.count == 6, s.allSatisfy({ $0.isNumber }) { return true }          // A股代码
        if (1...5).contains(s.count), s.allSatisfy({ $0.isLetter && $0.isUppercase }) { return true } // 美股代码
        return false
    }

    @objc func urlGo() {
        let t = urlField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        var u: String

        if t.hasPrefix("http://") || t.hasPrefix("https://") {
            u = t
        } else if t.contains(".") && !t.contains(" ") {
            u = "https://\(t)"
        } else if isStockCode(t) {
            if t.count == 6, t.allSatisfy({ $0.isNumber }) {
                // A股：6开头沪市，其余深市
                let prefix = t.hasPrefix("6") ? "sh" : "sz"
                u = "https://quote.eastmoney.com/\(prefix)\(t).html"
            } else {
                // 美股 / 加密
                u = "https://finance.yahoo.com/quote/\(t.uppercased())"
            }
        } else {
            let idx = UserDefaults.standard.integer(forKey: "searchEngine")
            let eng = financeSearchEngines[min(max(idx, 0), financeSearchEngines.count - 1)]
            u = eng.1.replacingOccurrences(
                of: "{query}",
                with: t.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? t
            )
        }
        if let url = URL(string: u) { activeWV.load(URLRequest(url: url)) }
    }

    // MARK: 起始页（金融交易大厅风格）

    @objc func goHome() {
        activeWV.loadHTMLString(startHTML, baseURL: nil)
    }

    var startHTML: String {
        // 搜索引擎 JS 数据
        var engJS = "["
        for (i, e) in financeSearchEngines.enumerated() {
            if i > 0 { engJS += "," }
            engJS += "{n:'\(e.0)',u:'\(e.1)'}"
        }
        engJS += "]"

        // 指数滚动条（双份用于无缝循环）
        func ticker() -> String {
            var s = ""
            for _ in 0..<2 {
                for m in marketIndexes {
                    let color = m.isUp ? "var(--up)" : "var(--down)"
                    let arrow = m.isUp ? "▲" : "▼"
                    s += "<span class='tk'>\(m.name) <b>\(m.priceText)</b> <em style='color:\(color)'>\(arrow)\(m.changeText)</em></span>"
                }
            }
            return "<div class='tick'>\(s)</div>"
        }

        // 磁贴 HTML
        var tilesHTML = ""
        for (i, s) in financeSites.enumerated() {
            tilesHTML += "<a href='\(s.2)' class='tile' data-i='\(i)'><span class='ic'>\(s.0)</span><span class='nm'>\(s.1)</span><span class='ct cat-\(s.3)'>[\(s.3)]</span></a>"
        }

        // 专业方向 -> 索引映射 JS
        var catJS = "{"
        var firstCat = true
        for (k, v) in financeCategories {
            let idxs = v.map(String.init).joined(separator: ",")
            if !firstCat { catJS += "," }
            catJS += "'\(k)':[\(idxs)]"
            firstCat = false
        }
        catJS += "}"

        // 每日一句（按日期取模）
        let dayIdx = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let q = financeQuotes[dayIdx % financeQuotes.count]

        return """
        <!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><style>
        :root{
          --bg:#1E2A3A;--card:#0D1117;--text:#D0D8E0;--sub:#78909C;
          --accent:#4FC3F7;--bdr:#2A3A4A;--up:#59A14F;--down:#E15759;
          --shadow:0 2px 10px rgba(0,0,0,.25);
        }
        @media(prefers-color-scheme:light){
          :root{--bg:#EFF4F7;--card:#FFFFFF;--text:#2C3E50;--sub:#78909C;
            --accent:#1976D2;--bdr:#DCE6EA;--up:#2E7D32;--down:#C62828;
            --shadow:0 2px 8px rgba(44,62,80,.08);}
        }
        *{box-sizing:border-box;margin:0;padding:0;outline:none}
        body{font-family:"PingFang SC","Hiragino Sans GB","Microsoft YaHei",sans-serif;
          background:var(--bg);color:var(--text);min-height:100vh;padding:18px 20px 60px;
          display:flex;flex-direction:column;align-items:center;transition:background .3s}
        .tick{width:96%;max-width:1060px;background:var(--card);border:1px solid var(--bdr);
          border-radius:8px;padding:9px 0;white-space:nowrap;overflow:hidden;margin-bottom:26px;
          box-shadow:var(--shadow);font-size:0;animation:marquee 60s linear infinite}
        @keyframes marquee{0%{transform:translateX(0)}100%{transform:translateX(-50%)}}
        .tick .tk{display:inline-block;font-size:12px;margin:0 16px;color:var(--sub);
          font-family:Menlo,Consolas,monospace}
        .tick .tk b{color:var(--text);font-weight:600}
        .tick .tk em{font-style:normal;font-weight:700}
        h1{font-size:27px;letter-spacing:4px;font-weight:700}
        .sub{color:var(--sub);font-size:13px;margin:6px 0 20px;letter-spacing:1px}
        .search{display:flex;gap:8px;width:92%;max-width:640px;margin-bottom:16px}
        .search input{flex:1;height:44px;padding:0 16px;border:1px solid var(--bdr);border-radius:22px;
          background:var(--card);color:var(--text);font-size:15px;font-family:inherit;box-shadow:var(--shadow);transition:all .25s}
        .search input:focus{border-color:var(--accent);box-shadow:0 0 0 3px rgba(79,195,247,.18)}
        .search input::placeholder{color:#8AA0B0}
        .search select{padding:0 12px;border-radius:22px;border:1px solid var(--bdr);background:var(--card);
          color:var(--text);cursor:pointer;font-size:13px;font-family:inherit;box-shadow:var(--shadow)}
        .quote{width:92%;max-width:640px;background:var(--card);border:1px solid var(--bdr);border-radius:8px;
          padding:14px 22px;margin-bottom:26px;position:relative;box-shadow:var(--shadow);text-align:center}
        .quote .qt{font-size:16px;font-family:KaiTi,STKaiti,serif;font-weight:600}
        .quote .qs{font-size:12px;color:var(--sub);margin-top:6px}
        .dirs{display:flex;flex-wrap:wrap;gap:8px;justify-content:center;margin-bottom:24px}
        .dirs button{padding:6px 16px;border:1px solid var(--bdr);border-radius:20px;background:var(--card);
          color:var(--sub);cursor:pointer;font-size:12px;font-family:inherit;transition:all .2s}
        .dirs button:hover{border-color:var(--accent);color:var(--accent)}
        .dirs button.on{background:var(--accent);color:#fff;border-color:var(--accent)}
        .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:14px;
          width:96%;max-width:1060px}
        .tile{background:var(--card);border:1px solid var(--bdr);border-radius:10px;padding:16px 10px;
          display:flex;flex-direction:column;align-items:center;text-decoration:none;color:var(--text);
          transition:all .2s;box-shadow:var(--shadow)}
        .tile:hover{transform:translateY(-3px);border-color:var(--accent)}
        .tile .ic{font-size:26px;margin-bottom:6px}
        .tile .nm{font-size:13px;font-weight:600;text-align:center;line-height:1.3}
        .tile .ct{font-size:10px;margin-top:4px;padding:1px 8px;border-radius:10px;border:1px solid}
        .cat-行情{color:#4FC3F7;border-color:#4FC3F7!important}
        .cat-宏观{color:#4DB6AC;border-color:#4DB6AC!important}
        .cat-学术{color:#9575CD;border-color:#9575CD!important}
        .cat-新闻{color:#FFB74D;border-color:#FFB74D!important}
        .cat-监管{color:#EF5350;border-color:#EF5350!important}
        .cat-工具{color:#A1887F;border-color:#A1887F!important}
        .tile.hide{display:none}
        @media(max-width:700px){.grid{grid-template-columns:repeat(auto-fill,minmax(130px,1fr))}
          .search{flex-direction:column}}
        </style></head><body>
        \(ticker())
        <h1>📊 \(APP_NAME)</h1>
        <p class="sub">市场数据 · 学术研究 · 投资工具</p>
        <div class="search"><input id="q" placeholder="搜索股票 / 基金 / 经济指标 / 网址…"
          autofocus onkeydown="if(event.key==='Enter')go()"><select id="eng"></select></div>
        <div class="quote"><div class="qt">「\(q.0)」</div><div class="qs">—— \(q.1)</div></div>
        <div class="dirs" id="dirs"></div>
        <div class="grid" id="g">\(tilesHTML)</div>
        <script>
        var ENG=\(engJS);
        var CATS=\(catJS);
        var se=localStorage.getItem('feng')||0;
        document.getElementById('eng').innerHTML=ENG.map(function(e,i){return'<option value='+i+(i==se?' selected':'')+'>'+e.n});
        document.getElementById('eng').onchange=function(){localStorage.setItem('feng',this.value)};
        function go(){var v=document.getElementById('q').value.trim();if(!v)return;
          if(/^[A-Z]{1,5}$/.test(v)){window.location.href='https://finance.yahoo.com/quote/'+v.toUpperCase();return}
          if(/^[0-9]{6}$/.test(v)){var p=v.charAt(0)=='6'?'sh':'sz';window.location.href='https://quote.eastmoney.com/'+p+v+'.html';return}
          var u;if(v.includes('.')&&!v.includes(' '))u='https://'+v;else u=ENG[parseInt(document.getElementById('eng').value)].u.replace('{query}',encodeURIComponent(v));
          window.location.href=u}
        var dirs=Object.keys(CATS);
        document.getElementById('dirs').innerHTML='<button class="on" data-cat="__all">全部</button>'+dirs.map(function(d){return'<button data-cat="'+d+'">'+d+'</button>'}).join('');
        document.getElementById('dirs').addEventListener('click',function(e){
          if(!e.target.tagName=='BUTTON')return;
          document.querySelectorAll('#dirs button').forEach(function(b){b.classList.remove('on')});
          e.target.classList.add('on');
          var cat=e.target.dataset.cat;
          document.querySelectorAll('.tile').forEach(function(t){
            if(cat=='__all'||CATS[cat].includes(parseInt(t.dataset.i)))t.classList.remove('hide');
            else t.classList.add('hide')})});
        </script></body></html>
        """
    }

    // MARK: 标签页

    @objc func addTab() {
        let wv = makeWV()
        wv.isHidden = true
        activeWV.addSubview(wv)
        tabs.append(wv)
        switchTo(tabs.count - 1)
        goHome()
        renderTabs()
    }

    func switchTo(_ i: Int) {
        guard i != activeIndex, i < tabs.count else { return }
        bookmarkPanel?.removeFromSuperview(); bookmarkPanel = nil
        settingsPanel?.removeFromSuperview(); settingsPanel = nil
        tabs[activeIndex].isHidden = true
        if tabBar.superview != tabs[i] { tabs[i].addSubview(tabBar) }
        if toolbar.superview != tabs[i] { tabs[i].addSubview(toolbar) }
        if tickerBar.superview != tabs[i] { tabs[i].addSubview(tickerBar) }
        window.contentView = tabs[i]
        activeIndex = i
        tabs[i].isHidden = false
        updateNav(); renderTabs()
    }

    func closeTab(_ i: Int) {
        guard tabs.count > 1, i < tabs.count else { return }
        tabs[i].removeFromSuperview()
        tabs.remove(at: i)
        if i <= activeIndex && activeIndex > 0 { activeIndex -= 1 }
        if activeIndex >= tabs.count { activeIndex = tabs.count - 1 }
        window.contentView = tabs[activeIndex]
        if tabBar.superview != tabs[activeIndex] { tabs[activeIndex].addSubview(tabBar) }
        if toolbar.superview != tabs[activeIndex] { tabs[activeIndex].addSubview(toolbar) }
        if tickerBar.superview != tabs[activeIndex] { tabs[activeIndex].addSubview(tickerBar) }
        tabs[activeIndex].isHidden = false
        updateNav(); renderTabs()
    }

    func renderTabs() {
        tabBar.subviews.forEach { $0.removeFromSuperview() }
        let add = NSButton(frame: NSRect(x: tabBar.bounds.width - 34, y: 2, width: 28, height: 26))
        add.title = "+"
        add.bezelStyle = .roundRect
        add.font = .systemFont(ofSize: 14)
        add.target = self
        add.action = #selector(addTab)
        add.autoresizingMask = [.minXMargin]
        tabBar.addSubview(add)

        var x: CGFloat = 4
        for (i, _) in tabs.enumerated() {
            let w = min(CGFloat((tabs[i].title?.prefix(12).count ?? 3)) * 9 + 40, 130)
            let tb = NSButton(frame: NSRect(x: x, y: 2, width: w, height: 26))
            tb.title = tabs[i].title ?? "标签"
            tb.bezelStyle = .roundRect
            tb.font = .systemFont(ofSize: 10)
            tb.tag = i
            tb.target = self
            tb.action = #selector(tabClick(_:))
            if i == activeIndex { tb.state = .on; tb.setButtonType(.toggle) }
            let cl = NSButton(frame: NSRect(x: w - 18, y: 2, width: 16, height: 16))
            cl.title = "×"
            cl.bezelStyle = .inline
            cl.font = .systemFont(ofSize: 9, weight: .bold)
            cl.isBordered = false
            cl.tag = i
            cl.target = self
            cl.action = #selector(closeClick(_:))
            tb.addSubview(cl)
            tabBar.addSubview(tb)
            x += w + 4
        }
    }

    @objc func tabClick(_ s: NSButton) { switchTo(s.tag) }
    @objc func closeClick(_ s: NSButton) { closeTab(s.tag) }

    // MARK: 导航动作

    @objc func goBack() { if activeWV.canGoBack { activeWV.goBack() } }
    @objc func goForward() { if activeWV.canGoForward { activeWV.goForward() } }
    @objc func goRefresh() { activeWV.reload() }
    @objc func openMarket() { activeWV.load(URLRequest(url: URL(string: "https://quote.eastmoney.com/")!)) }

    // MARK: 金融学术工具（术语翻译 / 缩写查询 / 数量级 / 汇率）

    private func showInfo(_ title: String, _ msg: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = msg
        a.addButton(withTitle: "确定")
        a.runModal()
    }

    /// 翻译（金融领域）：本地术语兜底 + MyMemory 免费引擎 + 缓存 7 天
    func translateFinance(_ text: String) {
        let cacheKey = "fin_tr_" + text
        if let cached = UserDefaults.standard.string(forKey: cacheKey) {
            showFinTranslation(text, cached); return
        }
        // 命中本地术语表 → 直接给出对照
        let lc = text.lowercased()
        let matched = FinGlossary.en2zh.filter { lc.contains($0.key) }

        let hasHan = text.range(of: "\\p{Han}", options: .regularExpression) != nil
        let lang = hasHan ? "zh-CN|en-GB" : "en-GB|zh-CN"
        let q = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        let url = "https://api.mymemory.translated.net/get?q=\(q)&langpair=\(lang)"
        URLSession.shared.dataTask(with: URL(string: url)!) { data, _, _ in
            var translated = "翻译服务暂不可用"
            if let data = data,
               let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let resp = j["responseData"] as? [String: Any],
               let t = resp["translatedText"] as? String {
                translated = t
                UserDefaults.standard.set(translated, forKey: cacheKey)
            }
            DispatchQueue.main.async {
                self.showFinTranslation(text, translated, matched: matched)
            }
        }.resume()
    }

    private func showFinTranslation(_ original: String, _ translated: String, matched: [String: String] = [:]) {
        var msg = "原文：\(original)\n\n译文：\(translated)"
        if !matched.isEmpty {
            var gloss = ""
            for (k, v) in matched.sorted(by: { $0.key.count > $1.key.count }) {
                gloss += "  \(k) → \(v)\n"
            }
            msg += "\n\n📌 术语对照（纠正通用误译）：\n\(gloss)"
        }
        showInfo("🌐 翻译（金融领域）", msg)
    }

    /// 展开缩写 / 查术语
    func lookupTerm(_ raw: String) {
        let key = raw.trimmingCharacters(in: .whitespaces).uppercased()
        if let hit = FinAbbrev.all[key] { showInfo("📖 \(key)", hit); return }
        if let g = FinGlossary.en2zh[key.lowercased()] { showInfo("📖 \(raw)", g); return }
        showInfo("📖 \(raw)", "未收录，可右键「翻译（金融领域）」")
    }

    /// 换算数量级（$1.2 billion → 12 亿）
    func convertMagnitude(_ raw: String) {
        let pattern = "([0-9][0-9,]*\\.?[0-9]*)\\s*(trillion|billion|million|thousand|亿|万)?"
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
              let numStr = Range(m.range(at: 1), in: raw) else {
            showInfo("提示", "未识别到数字"); return
        }
        let num = Double(String(raw[numStr]).replacingOccurrences(of: ",", with: "")) ?? 0
        var unit = ""
        if m.range(at: 2).location != NSNotFound, let ur = Range(m.range(at: 2), in: raw) {
            unit = String(raw[ur]).lowercased()
        }
        let factor: Double
        switch unit {
        case "trillion": factor = 10_000
        case "billion":  factor = 10
        case "million":  factor = 0.01
        case "thousand": factor = 0.00001
        case "亿":       factor = 1
        case "万":       factor = 0.0001
        default:         factor = 1
        }
        let yi = num * factor
        showInfo("🔢 数量级换算", "\(raw)\n\n≈ \(String(format: "%.2f", yi)) 亿")
    }

    /// 实时汇率换算（open.er-api.com 免费 + 1 小时缓存）
    func convertCurrency(_ raw: String) {
        let pattern = "([0-9][0-9,]*\\.?[0-9]*)"
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
              let numStr = Range(m.range(at: 1), in: raw),
              let amount = Double(String(raw[numStr]).replacingOccurrences(of: ",", with: "")) else {
            showInfo("提示", "未识别到金额"); return
        }
        // 识别货币符号
        let sym: String
        if raw.contains("€") { sym = "EUR" } else if raw.contains("£") { sym = "GBP" }
        else if raw.contains("¥") || raw.contains("￥") { sym = "CNY" }
        else if raw.contains("HK") { sym = "HKD" } else { sym = "USD" }

        fetchRates { [weak self] rates in
            guard let self, !rates.isEmpty else {
                self?.showInfo("💱 汇率换算", "汇率获取失败（离线或接口不可用）"); return
            }
            let targets = ["USD", "CNY", "EUR", "JPY", "HKD", "GBP"]
            var lines = ["\(raw)  =  \(String(format: "%.0f", amount)) \(sym)\n"]
            for t in targets where t != sym {
                if let v = self.convert(amount, from: sym, to: t, rates: rates) {
                    let fmt = v >= 100 ? "%.0f" : (v >= 10 ? "%.1f" : "%.2f")
                    lines.append("  → \(t): \(String(format: fmt, v))")
                }
            }
            DispatchQueue.main.async { self.showInfo("💱 按汇率换算", lines.joined(separator: "\n")) }
        }
    }

    func fetchRates(base: String = "USD", then: @escaping ([String: Double]) -> Void) {
        // 缓存 1 小时
        let ts = UserDefaults.standard.double(forKey: "fx_ts")
        if Date().timeIntervalSince1970 - ts < 3600,
           let cached = UserDefaults.standard.dictionary(forKey: "fx_cache") as? [String: Double] {
            then(cached); return
        }
        let url = URL(string: "https://open.er-api.com/v6/latest/\(base)")!
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rates = j["rates"] as? [String: Double] else {
                then(UserDefaults.standard.dictionary(forKey: "fx_cache") as? [String: Double] ?? [:]); return
            }
            UserDefaults.standard.set(rates, forKey: "fx_cache")
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "fx_ts")
            then(rates)
        }.resume()
    }

    func convert(_ amount: Double, from: String, to: String, rates: [String: Double]) -> Double? {
        guard let f = rates[from.uppercased()], let t = rates[to.uppercased()], f > 0 else { return nil }
        return amount * t / f
    }

    @objc func openFinanceBooks() {
        var items = ""
        for b in financeBooks {
            items += "<a href='\(b.3)' style='display:block;padding:14px 18px;margin:6px 0;background:#0D1117;border:1px solid #2A3A4A;border-radius:8px;text-decoration:none;color:#D0D8E0'><b>\(b.0)</b> <span style='color:#78909C;font-size:12px'>\(b.1) · \(b.2)</span></a>"
        }
        let html = "<!DOCTYPE html><html><head><meta charset='utf-8'><style>body{background:#1E2A3A;font-family:'PingFang SC',sans-serif;padding:40px 20px}h1{color:#E8F0F8;text-align:center}</style></head><body><h1>📚 经典金融著作</h1><div style='max-width:700px;margin:0 auto'>\(items)</div></body></html>"
        activeWV.loadHTMLString(html, baseURL: nil)
    }

    func updateNav() {
        if let url = activeWV.url?.absoluteString, !url.isEmpty, url != "about:blank" {
            urlField.stringValue = url
        } else {
            urlField.stringValue = "🏠 首页"
        }
        backBtn.isEnabled = activeWV.canGoBack
        fwdBtn.isEnabled = activeWV.canGoForward
        renderTabs()
    }

    func addH(_ u: String, _ t: String) {
        history.removeAll { $0.0 == u }
        history.insert((u, t), at: 0)
        if history.count > 100 { history = Array(history.prefix(100)) }
    }

    // MARK: 书签面板（金融分类）

    @objc func toggleBM() {
        if let p = bookmarkPanel { p.removeFromSuperview(); bookmarkPanel = nil; return }
        let p = NSView(frame: NSRect(x: 132, y: toolbar.frame.minY - 400, width: 230, height: 400))
        p.wantsLayer = true
        p.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.97).cgColor
        p.layer?.cornerRadius = 8
        p.layer?.borderWidth = 1
        p.layer?.borderColor = NSColor.separatorColor.cgColor

        let sc = NSScrollView(frame: p.bounds)
        sc.hasVerticalScroller = true
        sc.autoresizingMask = [.width, .height]
        let doc = NSView(frame: sc.bounds)
        doc.autoresizingMask = [.width]
        var y: CGFloat = 8
        var lc = ""
        for (i, bm) in financeSites.enumerated() {
            if bm.3 != lc {
                let lb = NSTextField(frame: NSRect(x: 8, y: y, width: 190, height: 18))
                lb.stringValue = bm.3
                lb.font = .boldSystemFont(ofSize: 10)
                lb.textColor = .secondaryLabelColor
                lb.isEditable = false; lb.isBordered = false; lb.backgroundColor = .clear
                doc.addSubview(lb); y += 20; lc = bm.3
            }
            let lk = NSButton(frame: NSRect(x: 8, y: y, width: 210, height: 20))
            lk.title = "\(bm.0) \(bm.1)"
            lk.bezelStyle = .inline
            lk.font = .systemFont(ofSize: 11)
            lk.alignment = .left
            lk.isBordered = false
            lk.tag = i
            lk.target = self
            lk.action = #selector(openBM(_:))
            doc.addSubview(lk); y += 22
        }
        doc.frame.size.height = y + 8
        sc.documentView = doc
        p.addSubview(sc)
        activeWV.addSubview(p)
        bookmarkPanel = p
    }

    @objc func openBM(_ s: NSButton) {
        if s.tag < financeSites.count, let url = URL(string: financeSites[s.tag].2) {
            activeWV.load(URLRequest(url: url))
        }
        bookmarkPanel?.removeFromSuperview(); bookmarkPanel = nil
    }

    // MARK: 设置面板

    @objc func toggleSettings() {
        if let p = settingsPanel { p.removeFromSuperview(); settingsPanel = nil; return }
        let pw: CGFloat = 340, ph: CGFloat = 360
        let p = NSView(frame: NSRect(x: 160, y: toolbar.frame.minY - ph - 10, width: pw, height: ph))
        p.wantsLayer = true
        p.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.98).cgColor
        p.layer?.cornerRadius = 12
        p.layer?.borderWidth = 1
        p.layer?.borderColor = NSColor.separatorColor.cgColor

        func sec(_ y: CGFloat, _ t: String) -> CGFloat {
            let sp = NSView(frame: NSRect(x: 16, y: y, width: pw - 32, height: 1))
            sp.wantsLayer = true
            sp.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
            p.addSubview(sp)
            let lb = NSTextField(frame: NSRect(x: 16, y: y - 20, width: 200, height: 16))
            lb.stringValue = t
            lb.font = .boldSystemFont(ofSize: 10)
            lb.textColor = .secondaryLabelColor
            lb.isEditable = false; lb.isBordered = false; lb.backgroundColor = .clear
            p.addSubview(lb)
            return y - 40
        }
        func pop(_ y: CGFloat, _ items: [String], _ sel: String, _ act: Selector) {
            let pb = NSPopUpButton(frame: NSRect(x: 16, y: y - 26, width: pw - 32, height: 24))
            pb.addItems(withTitles: items)
            pb.selectItem(withTitle: sel)
            pb.font = .systemFont(ofSize: 12)
            pb.target = self
            pb.action = act
            p.addSubview(pb)
        }
        func btn(_ y: CGFloat, _ title: String, _ act: Selector) {
            let b = NSButton(frame: NSRect(x: 16, y: y - 36, width: pw - 32, height: 36))
            b.title = title
            b.bezelStyle = .roundRect
            b.font = .systemFont(ofSize: 13)
            b.target = self
            b.action = act
            p.addSubview(b)
        }

        var y = ph - 12
        let tl = NSTextField(frame: NSRect(x: 16, y: y - 26, width: 200, height: 22))
        tl.stringValue = "⚙ 设置"
        tl.font = .boldSystemFont(ofSize: 15)
        tl.isEditable = false; tl.isBordered = false; tl.backgroundColor = .clear
        p.addSubview(tl); y -= 34

        y = sec(y, "📈 研究方向")
        pop(y, Array(financeCategories.keys.sorted()), UserDefaults.standard.string(forKey: "major") ?? "全部", #selector(majorChanged(_:)))
        y = sec(y, "🔍 搜索引擎")
        pop(y, financeSearchEngines.map { $0.0 }, financeSearchEngines[UserDefaults.standard.integer(forKey: "searchEngine")].0, #selector(engineChanged(_:)))
        y = sec(y, "📋 其他")
        btn(y, "🗑 清除浏览历史", #selector(clearHistory))
        btn(y - 40, "✕ 关闭设置", #selector(toggleSettings))

        activeWV.addSubview(p)
        settingsPanel = p
    }

    @objc func majorChanged(_ s: NSPopUpButton) {
        UserDefaults.standard.set(s.selectedItem?.title ?? "全部", forKey: "major")
        settingsPanel?.removeFromSuperview(); settingsPanel = nil
        goHome()
    }

    @objc func clearHistory() {
        history.removeAll()
        settingsPanel?.removeFromSuperview(); settingsPanel = nil
    }

    // MARK: 菜单栏

    func buildMenu() {
        let mm = NSMenu()
        let am = NSMenu()
        am.addItem(NSMenuItem(title: "关于 \(APP_NAME)", action: #selector(showAbout), keyEquivalent: ""))
        am.addItem(.separator())
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

    // MARK: 金融计算器

    private lazy var calcPanel: NSPanel = {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 300),
                            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "🧮 金融计算器"
        panel.isFloatingPanel = true
        panel.isReleasedWhenClosed = false

        let content = panel.contentView!
        func mkLabel(_ t: String, _ y: CGFloat) -> NSTextField {
            let l = NSTextField(labelWithString: t)
            l.frame = NSRect(x: 20, y: y, width: 140, height: 20)
            l.font = .systemFont(ofSize: 12)
            content.addSubview(l)
            return l
        }
        func mkField(_ y: CGFloat) -> NSTextField {
            let f = NSTextField(frame: NSRect(x: 165, y: y, width: 170, height: 22))
            f.font = .systemFont(ofSize: 12)
            content.addSubview(f)
            return f
        }

        let modeSeg = NSSegmentedControl(labels: ["复利终值", "贷款月供"], trackingMode: .selectOne, target: nil, action: nil)
        modeSeg.frame = NSRect(x: 20, y: 250, width: 200, height: 24)
        modeSeg.selectedSegment = 0
        content.addSubview(modeSeg)

        let pL = mkLabel("本金 / 贷款额", 215); let pF = mkField(213)
        let rL = mkLabel("年利率 %", 180);   let rF = mkField(178)
        let nL = mkLabel("年限", 145);       let nF = mkField(143)
        let res = NSTextField(labelWithString: "结果：—")
        res.frame = NSRect(x: 20, y: 100, width: 320, height: 40)
        res.font = .boldSystemFont(ofSize: 14)
        res.textColor = .systemGreen
        content.addSubview(res)

        let calcBtn = NSButton(title: "计算", target: nil, action: nil)
        calcBtn.frame = NSRect(x: 20, y: 55, width: 90, height: 30)
        calcBtn.bezelStyle = .rounded
        content.addSubview(calcBtn)

        calcBtn.target = self
        calcBtn.action = #selector(runCalculator)
        objc_setAssociatedObject(calcBtn, &AssocKey.calcPanel, panel, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(calcBtn, &AssocKey.calcMode, modeSeg, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(calcBtn, &AssocKey.calcP, pF, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(calcBtn, &AssocKey.calcR, rF, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(calcBtn, &AssocKey.calcN, nF, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(calcBtn, &AssocKey.calcRes, res, .OBJC_ASSOCIATION_RETAIN)
        return panel
    }()

    @objc func openCalculator() { calcPanel.center(); calcPanel.makeKeyAndOrderFront(nil) }

    @objc func runCalculator(_ sender: NSButton) {
        guard let mode = objc_getAssociatedObject(sender, &AssocKey.calcMode) as? NSSegmentedControl,
              let pF = objc_getAssociatedObject(sender, &AssocKey.calcP) as? NSTextField,
              let rF = objc_getAssociatedObject(sender, &AssocKey.calcR) as? NSTextField,
              let nF = objc_getAssociatedObject(sender, &AssocKey.calcN) as? NSTextField,
              let res = objc_getAssociatedObject(sender, &AssocKey.calcRes) as? NSTextField else { return }

        guard let p = Double(pF.stringValue), let r = Double(rF.stringValue), let n = Double(nF.stringValue) else {
            res.stringValue = "请输入有效数字"; res.textColor = .systemRed; return
        }
        let rDec = r / 100.0
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 2

        if mode.selectedSegment == 0 {
            // 复利终值 A = P(1+r)^n（年复利）
            let a = p * pow(1 + rDec, n)
            res.stringValue = "复利终值：¥\(fmt.string(from: NSNumber(value: a)) ?? "\(a)")"
        } else {
            // 等额本息月供 PMT = P*r/12*(1+r/12)^(12n) / ((1+r/12)^(12n)-1)
            let m = n * 12
            let ir = rDec / 12
            let pmt: Double
            if ir == 0 { pmt = p / m } else { pmt = p * ir * pow(1 + ir, m) / (pow(1 + ir, m) - 1) }
            res.stringValue = "月供：¥\(fmt.string(from: NSNumber(value: pmt)) ?? "\(pmt)")"
        }
        res.textColor = .systemGreen
    }

    // MARK: 经济日历

    private struct EconEvent { let date: String; let country: String; let name: String; let importance: Int }
    private let econEvents: [EconEvent] = [
        EconEvent(date: "每月 第一周五", country: "美国", name: "非农就业数据", importance: 3),
        EconEvent(date: "每月 月中", country: "美国", name: "CPI 通胀数据", importance: 3),
        EconEvent(date: "每年 8 次会议", country: "美国", name: "FOMC 议息会议", importance: 3),
        EconEvent(date: "每季度", country: "中国", name: "GDP 数据发布", importance: 2),
        EconEvent(date: "每月", country: "中国", name: "CPI / PPI 数据", importance: 2),
        EconEvent(date: "每月", country: "中国", name: "社融 / M2 数据", importance: 2),
        EconEvent(date: "每月", country: "欧元区", name: "ECB 利率决议", importance: 2),
        EconEvent(date: "每月", country: "日本", name: "BOJ 利率决议", importance: 2),
    ]

    @objc func openCalendar() {
        var rows = ""
        for ev in econEvents {
            let star = String(repeating: "★", count: ev.importance)
            rows += "<div style='display:flex;justify-content:space-between;padding:10px 16px;border-bottom:1px solid var(--bdr);font-size:13px'><span style='color:var(--sub)'>\(ev.date)</span><span>\(ev.country) · \(ev.name)</span><b style='color:#F5A623'>\(star)</b></div>"
        }
        let html = """
        <!DOCTYPE html><html><head><meta charset="utf-8"><style>
        :root{--bg:#1E2A3A;--bdr:#2A3A4A;--text:#D0D8E0;--sub:#78909C}
        @media(prefers-color-scheme:light){:root{--bg:#EFF4F7;--bdr:#DCE6EA;--text:#2C3E50;--sub:#78909C}}
        body{background:var(--bg);color:var(--text);font-family:"PingFang SC",sans-serif;margin:0;padding:30px 20px}
        h1{text-align:center;font-size:22px;margin-bottom:20px}
        .box{max-width:640px;margin:0 auto;border:1px solid var(--bdr);border-radius:10px;overflow:hidden}
        </style></head><body><h1>📅 全球经济日历</h1><div class="box">\(rows)</div></body></html>
        """
        activeWV.loadHTMLString(html, baseURL: nil)
    }

    // MARK: 整页翻译（Google Translate 代理）

    @objc func translatePage() {
        guard let url = activeWV.url, url.absoluteString != "about:blank" else {
            showInfo("提示", "当前是起始页，无内容可翻译")
            return
        }
        // 菜单选择翻译方向
        let menu = NSMenu()
        let toZh = NSMenuItem(title: "🌐 翻译为中文", action: #selector(translateTo(_:)), keyEquivalent: "")
        toZh.representedObject = "zh-CN"; toZh.target = self
        menu.addItem(toZh)
        let toEn = NSMenuItem(title: "🌐 翻译为英文", action: #selector(translateTo(_:)), keyEquivalent: "")
        toEn.representedObject = "en"; toEn.target = self
        menu.addItem(toEn)
        if let e = NSApp.currentEvent {
            menu.popUp(positioning: nil, at: e.locationInWindow, in: window.contentView)
        } else {
            translateTo(toZh)
        }
    }

    @objc func translateTo(_ sender: NSMenuItem) {
        guard let url = activeWV.url, url.absoluteString != "about:blank" else { return }
        let tl = sender.representedObject as? String ?? "zh-CN"
        let enc = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        activeWV.load(URLRequest(url: URL(string: "https://translate.google.com/translate?u=\(enc)&sl=auto&tl=\(tl)")!))
    }

    @objc func showAbout() {
        let a = NSAlert()
        a.messageText = APP_NAME
        a.informativeText = "面向金融学 / 经济学专业用户的浏览器\n市场数据 · 学术研究 · 投资工具\n基于文史哲浏览器架构开发"
        a.runModal()
    }

    @objc func focusURL() { window.makeFirstResponder(urlField) }
    @objc func closeCur() { closeTab(activeIndex) }

    // MARK: - WKNavigationDelegate

    func webView(_ wv: WKWebView, didCommit nav: WKNavigation!) {
        if wv == activeWV { updateNav() }
        if let u = wv.url { addH(u.absoluteString, wv.title ?? u.absoluteString) }
    }
    func webView(_ wv: WKWebView, didFinish nav: WKNavigation!) { if wv == activeWV { updateNav() } }
    func webView(_ wv: WKWebView, didFail nav: WKNavigation!, withError e: Error) { if wv == activeWV { updateNav() } }
    func webView(_ wv: WKWebView, didFailProvisionalNavigation nav: WKNavigation!, withError e: Error) {
        if (e as NSError).code != NSURLErrorCancelled && wv == activeWV { updateNav() }
    }
    func webView(_ wv: WKWebView, didReceive ch: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if ch.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let t = ch.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: t))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    func webView(_ wv: WKWebView, createWebViewWith c: WKWebViewConfiguration, for nav: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if nav.targetFrame == nil { wv.load(nav.request) }
        return nil
    }
    func webView(_ wv: WKWebView, decidePolicyFor nav: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // 防劫持：拦截百度安全验证相关跳转（金融站常被劫持）
        if let url = nav.request.url {
            if url.absoluteString.contains("wappass.baidu.com") || url.absoluteString.contains("security-check") {
                decisionHandler(.cancel); return
            }
        }
        decisionHandler(.allow)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool { true }
}

// MARK: - 安全数组访问

// MARK: - 关联对象 Key（计算器面板传参）

private enum AssocKey {
    static var calcPanel = 0
    static var calcMode = 0
    static var calcP = 0
    static var calcR = 0
    static var calcN = 0
    static var calcRes = 0
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
