---
name: smart-weather
description: 智能天气校准：多模型交叉验证（GFS/WWO/ICON/Open-Meteo），基于实测偏差自动修正云量和降雨概率，适配任何地区。比普通天气预报更准。
runAs: subagent
---

# 智能天气校准助手

一个基于多模型交叉验证的智能天气预报技能。同时拉取多个独立数据源进行交叉比对，结合用户实况反馈校准，输出修正后的预报。

## 数据源

| 来源 | 类型 | API | 是否免费 |
|------|------|-----|:--------:|
| wttr.in | 实测观测站 | `wttr.in/{城市}?format=j1` | ✅ |
| Open-Meteo | GFS + ICON + Météo-France 多模型 | `api.open-meteo.com/v1/forecast` | ✅ |
| CMA 中国气象局 | 官方预报 | `nmc.cn/rest/weather`（需关注时效性） | ✅ |

### API 参考
```
# wttr.in 实测（JSON 格式）
wttr.in/Beijing?format=j1

# Open-Meteo 逐小时预报
api.open-meteo.com/v1/forecast?latitude=39.9&longitude=116.4&current_weather=true&hourly=温度,降水概率,云量,天气码&daily=最高温,最低温,降水概率,天气码&timezone=auto&forecast_days=3

# CMA 全国天气（仅供参考）
nmc.cn/rest/weather?stationid=54511
```

## 校准方法论

1. 同时拉取至少 2-3 个独立数据源
2. 对比模型预报 vs 实测数据，识别偏差
3. 根据历史偏差率调整后续预报
4. 用户实况作为最终覆盖层

### 已知偏差

| 地区 | 季节 | 已知偏差 | 校准建议 |
|------|------|---------|---------|
| 北京海淀 | 夏季 | GFS 云量报高 20-30%，降雨概率虚高 | 云量−25%，降雨×0.6 |
| 南方城市 | 梅雨季 | 模型常低估连续性降水 | 降雨概率上调 10-15% |
| （其他地区可逐步积累） | — | — | — |

## 应用场景
- 🌇 今天适合去公园看日落吗？
- 📚 下午去图书馆会淋雨吗？  
- 🏔 周末爬山天气如何？
- 📄 输出 DOCX 天气报告
- 🎯 比手机天气更准的定制化判断

## 可用工具
- `智能天气/smart_weather.py` — 图形界面版（双击运行）
- `智能天气/beijing_weather.py` — 北京校准版（海淀专用）
- web_fetch — 获取天气 API 数据
- python-docx — 生成 DOCX 报告

## 输出格式
- 📝 文字分析 + 校准说明
- 📄 可选 DOCX 报告（含数据源对比表格）
- 🎯 具体行动建议（带伞/穿衣/出行）
