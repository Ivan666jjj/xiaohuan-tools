import Foundation

// ============================================================
// FinanceData.swift — 金融学经济学浏览器数据层
// 复用文史哲浏览器 3 源文件架构，仅在数据层做定向替换
// ============================================================

// MARK: - 应用名（双版本通过修改此常量构建）

let APP_NAME = "金融学经济学浏览器"

// MARK: - 市场指数（模拟数据，用于起始页顶部滚动条）

struct MarketIndex {
    let name: String
    let code: String
    let price: Double
    let change: Double          // 涨跌幅 %
    var isUp: Bool { change >= 0 }

    /// 显示用价格字符串（千分位）
    var priceText: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = price >= 100 ? 2 : 4
        return f.string(from: NSNumber(value: price)) ?? "\(price)"
    }

    var changeText: String {
        let sign = change > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", change))%"
    }
}

/// 全球主要股指 / 汇率 / 贵金属 / 加密（模拟值，仅用于展示布局）
let marketIndexes: [MarketIndex] = [
    MarketIndex(name: "道琼斯",   code: "DJI",      price: 39431.51, change: 0.62),
    MarketIndex(name: "纳斯达克", code: "IXIC",     price: 16947.23, change: -0.32),
    MarketIndex(name: "标普500",  code: "GSPC",     price: 5308.15,  change: 0.21),
    MarketIndex(name: "上证指数", code: "000001",   price: 3091.68,  change: 0.85),
    MarketIndex(name: "深证成指", code: "399001",   price: 9796.12,  change: -0.47),
    MarketIndex(name: "恒生指数", code: "HSI",      price: 18637.42, change: 1.23),
    MarketIndex(name: "日经225",  code: "N225",     price: 38745.19, change: 0.15),
    MarketIndex(name: "富时100",  code: "FTSE",     price: 8323.27,  change: -0.08),
    MarketIndex(name: "德国DAX",  code: "GDAXI",    price: 18604.94, change: 0.53),
    MarketIndex(name: "比特币",   code: "BTC",      price: 67452.30, change: 2.34),
    MarketIndex(name: "以太坊",   code: "ETH",      price: 3148.26,  change: 1.78),
    MarketIndex(name: "现货黄金", code: "GC=F",     price: 2341.60,  change: 0.42),
    MarketIndex(name: "美元指数", code: "DXY",      price: 104.82,   change: -0.11),
]

// MARK: - 金融网站磁贴数据（20+ 核心资源）
// 结构：(图标, 名称, URL, 分类)

let financeSites: [(String, String, String, String)] = [
    // 📈 行情
    ("📈", "东方财富",   "https://www.eastmoney.com",          "行情"),
    ("📉", "同花顺",     "https://www.10jqka.com.cn",           "行情"),
    ("🇺🇸", "Yahoo Finance", "https://finance.yahoo.com",       "行情"),
    ("📊", "TradingView", "https://www.tradingview.com",        "行情"),
    ("💹", "新浪财经",   "https://finance.sina.com.cn",         "行情"),
    // 📊 宏观数据
    ("🏦", "FRED",       "https://fred.stlouisfed.org",         "宏观"),
    ("🇨🇳", "国家统计局", "https://www.stats.gov.cn",            "宏观"),
    ("🌍", "世界银行",   "https://data.worldbank.org",          "宏观"),
    ("🏛️", "IMF",        "https://www.imf.org",                 "宏观"),
    ("📐", "OECD",       "https://data.oecd.org",               "宏观"),
    // 📚 学术研究
    ("🎓", "SSRN",       "https://www.ssrn.com",                "学术"),
    ("🏫", "NBER",       "https://www.nber.org",                "学术"),
    ("📖", "知网",       "https://www.cnki.net",                "学术"),
    ("🗂️", "JSTOR",      "https://www.jstor.org",               "学术"),
    // 📰 财经新闻
    ("🌐", "彭博",       "https://www.bloomberg.com",           "新闻"),
    ("🕊️", "路透",       "https://www.reuters.com",             "新闻"),
    ("💼", "华尔街见闻", "https://wallstreetcn.com",            "新闻"),
    ("⚡", "财联社",     "https://www.cls.cn",                  "新闻"),
    ("📰", "第一财经",   "https://www.yicai.com",               "新闻"),
    // 🏛️ 监管与央行
    ("🏢", "SEC EDGAR",  "https://www.sec.gov/edgar",           "监管"),
    ("🇨🇳", "中国证监会", "https://www.csrc.gov.cn",             "监管"),
    ("🏦", "中国人民银行", "http://www.pbc.gov.cn",              "监管"),
    // 🛠️ 工具
    ("💱", "XE 汇率",    "https://www.xe.com",                  "工具"),
    ("📅", "金十数据",   "https://www.jin10.com",               "工具"),
    ("📉", "英为财情",   "https://cn.investing.com",            "工具"),
]

// MARK: - 智能磁贴分类映射（专业方向下拉 → 磁贴索引）

let financeCategories: [String: [Int]] = [
    "全部":   Array(0..<financeSites.count),
    "股市行情": [0, 1, 2, 3, 4, 22],
    "宏观经济": [5, 6, 7, 8, 9],
    "外汇汇率": [2, 22, 23, 24],
    "固定收益": [5, 22, 24, 21],
    "加密货币": [2, 3, 9, 24],
    "财经新闻": [14, 15, 16, 17, 18],
    "学术研究": [10, 11, 12, 13],
    "监管与央行": [19, 20, 21],
]

// MARK: - 搜索引擎列表（地址栏 + 起始页共用）

let financeSearchEngines: [(String, String)] = [
    ("百度股市通", "https://gushitong.baidu.com/search?q={query}"),
    ("Google Finance", "https://www.google.com/finance/search?q={query}"),
    ("东方财富", "https://so.eastmoney.com/web/s?keyword={query}"),
    ("彭博", "https://www.bloomberg.com/search?query={query}"),
    ("SSRN", "https://ssrn.com/abstract={query}"),
    ("FRED", "https://fred.stlouisfed.org/search?q={query}"),
]

// MARK: - 右键搜索服务（金融术语速查）

let financeSearchServices: [(String, String)] = [
    ("财报查询", "https://so.eastmoney.com/web/s?keyword={query}"),
    ("K线图",   "https://quote.eastmoney.com/concept/search?keyword={query}"),
    ("相关新闻", "https://www.bloomberg.com/search?query={query}"),
    ("经济指标", "https://fred.stlouisfed.org/search?q={query}"),
    ("学术论文", "https://scholar.baidu.com/s?wd={query}"),
]

// MARK: - 经典金融著作库（替代文史哲古籍库）

let financeBooks: [(String, String, String, String)] = [
    ("《国富论》",     "亚当·斯密",   "经济学奠基之作", "https://www.google.com/books"),
    ("《就业、利息和货币通论》", "凯恩斯", "宏观经济学开山之作", "https://www.google.com/books"),
    ("《资本论》",     "马克思",      "政治经济学经典", "https://www.google.com/books"),
    ("《货币金融学》", "米什金",      "货币银行学教材", "https://www.google.com/books"),
    ("《投资学》",     "博迪",        "投资学标准教材", "https://www.google.com/books"),
    ("《证券分析》",   "格雷厄姆",    "价值投资圣经", "https://www.google.com/books"),
    ("《漫步华尔街》", "马尔基尔",    "市场随机漫步理论", "https://www.google.com/books"),
    ("《黑天鹅》",     "塔勒布",      "不确定性理论", "https://www.google.com/books"),
    ("《反脆弱》",     "塔勒布",      "从波动中获益", "https://www.google.com/books"),
    ("《经济学原理》", "曼昆",        "经济学入门教材", "https://www.google.com/books"),
]

// MARK: - 每日一句（经济学名言）

let financeQuotes: [(String, String)] = [
    ("经济预测的唯一作用，是让占星学看起来更体面。", "加尔布雷思"),
    ("市场保持非理性的时间，可以比你保持不破产的时间更长。", "凯恩斯"),
    ("在别人贪婪时恐惧，在别人恐惧时贪婪。", "巴菲特"),
    ("风险来自于你不知道自己在做什么。", "巴菲特"),
    ("历史总是在重演，但细节各不相同。", "马克·吐温"),
    ("通货膨胀是唯一能同时欺骗所有人的税收。", "萨缪尔森"),
    ("价格是你付出的，价值是你得到的。", "巴菲特"),
    ("不要把所有鸡蛋放在一个篮子里。", "谚语"),
    ("复利是世界上最强大的力量。", "爱因斯坦"),
    ("需求与供给，是市场的两只手。", "经济学常识"),
    ("现金是垃圾，但也是氧气。", "达里奥"),
    ("永远不要问理发师你是否需要理发。", "巴菲特"),
]

// MARK: - 金融术语词典（纠正通用翻译误译）

enum FinGlossary {
    static let en2zh: [String: String] = [
        "duration": "久期", "convexity": "凸性",
        "equity": "权益/股权", "margin": "保证金/利润率",
        "exposure": "敞口", "leverage": "杠杆",
        "liquidity": "流动性", "default": "违约",
        "option": "期权", "future": "期货",
        "swap": "互换", "derivative": "衍生品",
        "arbitrage": "套利", "hedge": "对冲",
        "yield": "收益率", "basis point": "基点",
        "moral hazard": "道德风险",
        "adverse selection": "逆向选择",
        "elasticity": "弹性", "marginal": "边际",
        "opportunity cost": "机会成本",
        "quantitative easing": "量化宽松",
        "discount rate": "贴现率",
        "capital adequacy ratio": "资本充足率",
        "non-performing loan": "不良贷款",
        "systemic risk": "系统性风险",
        "maturity mismatch": "期限错配",
        "credit spread": "信用利差",
        "carry trade": "套息交易",
    ]
}

// MARK: - 金融缩写词典

enum FinAbbrev {
    static let all: [String: String] = [
        "GDP": "国内生产总值 Gross Domestic Product",
        "CPI": "消费者物价指数 Consumer Price Index",
        "PPI": "生产者物价指数 Producer Price Index",
        "PMI": "采购经理指数 Purchasing Managers' Index",
        "FOMC": "美联储联邦公开市场委员会",
        "ECB": "欧洲中央银行 European Central Bank",
        "QE": "量化宽松 Quantitative Easing",
        "LTRO": "长期再融资操作 Long-Term Refinancing Operation",
        "EBITDA": "息税折旧摊销前利润",
        "ROE": "净资产收益率 Return on Equity",
        "ROA": "总资产收益率 Return on Assets",
        "WACC": "加权平均资本成本 Weighted Avg Cost of Capital",
        "DCF": "现金流折现 Discounted Cash Flow",
        "VAR": "在险价值 Value at Risk",
        "CAPM": "资本资产定价模型 Capital Asset Pricing Model",
        "PE": "市盈率 Price/Earnings",
        "EPS": "每股收益 Earnings Per Share",
        "IPO": "首次公开募股 Initial Public Offering",
        "ETF": "交易所交易基金 Exchange-Traded Fund",
        "NPL": "不良贷款 Non-Performing Loan",
        "LPR": "贷款市场报价利率 Loan Prime Rate",
        "MLF": "中期借贷便利 Medium-term Lending Facility",
        "SLF": "常备借贷便利 Standing Lending Facility",
        "RRR": "存款准备金率 Required Reserve Ratio",
    ]
}
