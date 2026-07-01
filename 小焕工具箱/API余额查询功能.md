## 十、DeepSeek API 余额查询 + 可用量估算（必做）

### 10.1 原理
DeepSeek 有余额查询接口。根据余额 ÷ 每次查询的预估花费 = 预估剩余次数。

### 10.2 接口
```javascript
async function getDeepSeekBalance(apiKey) {
  try {
    const resp = await fetch('https://api.deepseek.com/user/balance', {
      headers: { 'Authorization': 'Bearer ' + apiKey, 'Accept': 'application/json' }
    });
    const data = await resp.json();
    if (data.balance !== undefined) {
      const balance = data.balance;           // 余额（元）
      const currency = data.currency || 'CNY';
      const isAvailable = data.is_available;  // 是否可用
      const totalUsed = data.total_used || 0; // 总已用金额
      return { balance, currency, isAvailable, totalUsed };
    }
    return null;
  } catch(e) {
    return { error: e.message };
  }
}
```

### 10.3 可用量估算（重要）
根据不同模型和输入长度，自动估算每次查询的成本：

```javascript
const MODEL_COST = {
  'deepseek-chat': 0.0005,  // 元/次（约500 token）
  'deepseek-coder': 0.0008, // 元/次
};

function estimateUsage(balance) {
  const costPerQuery = 0.0005; // 平均每次查询
  const remainingQueries = Math.floor(balance / costPerQuery);
  
  // 按使用场景估算
  const daily = 30;                // 每天30次查询
  const daysLeft = Math.floor(remainingQueries / daily);
  
  return {
    remainingQueries,              // 剩余次数
    daysLeft,                      // 还能用多少天
    costPerQuery                   // 每次花费
  };
}
```

### 10.4 UI 设计（底部固定栏）

```
┌──────────────────────────────────────┐
│ 🔑 ¥12.50 🟢  | 📊 约25,000次 | 📅 ≈83天 │
│ ↑ 余额           ↑ 剩余次数      ↑ 可用天数  │
└──────────────────────────────────────┘
```

点击可展开详情：

```
┌──────────────────────────────────────┐
│ DeepSeek API 状态                     │
├──────────────────────────────────────┤
│ 余额：        ¥12.50                    │
│ 剩余调用：    约25,000次                │
│ 日均消耗：    约300次（¥0.15）           │
│ 预计可用：    约83天                     │
│ 上次查询：    30秒前                     │
│                                      │
│ [🔁 刷新]    [⚙️ 设置 Key]              │
└──────────────────────────────────────┘
```

### 10.5 三级颜色

| 余额 | 剩余次数 | 颜色 | 显示 |
|---|---|---|---|
| > ¥10 | > 20,000 | 🟢 绿 | 正常使用 |
| ¥1-¥10 | 2,000-20,000 | 🟡 黄 | 「余额不足¥10」提示 |
| < ¥1 | < 2,000 | 🔴 红 |「即将耗尽，请充值」弹窗 |
| 查询失败 | — | ⚪ 灰 |「离线模式」 |

### 10.6 日消耗统计
- 每次调用 API 时记录 token 消耗
- 保存在 `localStorage('daily_usage')`
- 每天自动归零重置
- 显示本日已用次数和花费

### 10.7 界面位置
主窗口右下角，**固定悬浮**，不随内容滚动，始终可见。
