## 十、DeepSeek API 余额查询功能（必做）

### 10.1 原理
DeepSeek 余额查询接口，通过 API Key 获取账户信息。

### 10.2 实现
```javascript
async function checkDeepSeekBalance(apiKey) {
  try {
    const resp = await fetch('https://api.deepseek.com/user/balance', {
      headers: { 'Authorization': 'Bearer ' + apiKey, 'Accept': 'application/json' }
    });
    const data = await resp.json();
    if (data.balance !== undefined) {
      updateBalanceUI(data.balance, data.currency || 'CNY');
    }
    return data;
  } catch(e) {
    showStatus('⚠️ 余额查询失败', 'red');
    return null;
  }
}

function updateBalanceUI(balance, currency) {
  const el = document.getElementById('balance-display');
  if (!el) return;
  const color = balance > 10 ? '#4CAF50' : balance > 1 ? '#FF9800' : '#f44336';
  el.innerHTML = `🔑 DeepSeek: ${currency} ${balance.toFixed(2)}`;
  el.style.color = color;
}
```

### 10.3 UI 设计
界面底部固定显示：
```
┌─────────────────────────┐
│ 🔑 API: ¥12.50  🟢     │
│ 📊 本日已用: 2,341 tokens│
└─────────────────────────┘
```

### 10.4 触发时机
- 应用启动时：自动查询
- 每次调用 AI API 后：刷新余额
- 用户点击余额区域：手动刷新
- 余额自动刷新间隔：10分钟

### 10.5 余额级别
| 余额 | 显示 | 行为 |
|---|---|---|
| > ¥10 | 🟢 绿色 | 正常 |
| ¥1-¥10 | 🟡 黄色 | 提醒注意 |
| < ¥1 | 🔴 红色 | 弹出提示充值 |
| 查询失败 | ⚪ 灰色 | 显示「离线模式」 |

### 10.6 本地存储
- 用户输入 API Key → 存入 `localStorage('deepseek_api_key')`
- 每次启动自动读取
- 提供「设置 API Key」的入口
- 支持清除已保存的 Key
