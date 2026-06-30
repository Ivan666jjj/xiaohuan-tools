#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
北京天气校准版 — 动态偏差校准
实时比对 GFS 预报 vs 实测数据，自动计算当日校准系数
"""

import sys, json, tkinter as tk
from tkinter import ttk, scrolledtext
from datetime import datetime
import threading, urllib.request, urllib.parse

CITY, LAT, LON = "北京", 39.9, 116.4

# ── 默认校准系数（当实测数据不足时使用） ──
DEFAULT_CLOUD_OFFSET = -25
DEFAULT_RAIN_FACTOR = 0.6


def fetch(url, timeout=10):
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode('utf-8', errors='ignore')


CODES = {0:'☀️晴',1:'🌤晴',2:'⛅多云',3:'☁️阴',45:'🌫雾',48:'🌫雾',
         51:'🌦毛毛雨',53:'🌦毛毛雨',55:'🌦大毛毛雨',
         61:'🌧小雨',63:'🌧中雨',65:'🌧大雨',
         71:'❄️小雪',73:'❄️中雪',75:'❄️大雪',
         80:'🌦阵雨',81:'🌧中阵雨',82:'🌧大阵雨',
         95:'⛈雷暴',96:'⛈冰雹雷暴',99:'⛈大冰雹'}


class BeijingWeatherApp:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title('北京天气校准版 · 动态偏差校准')
        self.root.geometry('720x780')
        self.root.resizable(False, False)

        tk.Label(self.root, text='🌤 北京天气校准版', font=('', 22, 'bold'), fg='#1a3a5a').pack(pady=(20, 0))
        tk.Label(self.root, text='📍 海淀 · 实时比对 GFS vs 实测 · 动态计算今日校准系数',
                 font=('', 11), fg='#5a7a9a').pack(pady=(2, 5))

        # 校准帧
        self.cal_frame = tk.LabelFrame(self.root, text='🎯 动态校准系数（实时计算）', font=('', 10, 'bold'), fg='#2c3e50', padx=12, pady=6)
        self.cal_frame.pack(pady=5, padx=25, fill='x')
        self.cal_label = tk.Label(self.cal_frame, text='点击查询后自动计算', font=('', 10), fg='#888')
        self.cal_label.pack()

        self.btn = tk.Button(self.root, text='🌤 查询北京天气', command=self.do_query,
                             font=('', 14, 'bold'), bg='#2980b9', fg='white', padx=25, pady=5, cursor='hand2')
        self.btn.pack(pady=8)

        self.progress = ttk.Progressbar(self.root, mode='indeterminate', length=440)
        self.status = tk.Label(self.root, text='点击按钮查询', font=('', 10), fg='#999')
        self.status.pack()

        self.result = scrolledtext.ScrolledText(self.root, height=26, width=80, font=('Menlo', 9),
                                                  relief='solid', bd=1, fg='#2c3e50', bg='#fafafa')
        self.result.pack(pady=8, padx=25, fill='both', expand=True)
        self.root.protocol("WM_DELETE_WINDOW", self.root.quit)

    def log(self, text):
        self.root.after(0, lambda: (self.result.insert('end', text + '\n'), self.result.see('end')))

    def cal_update(self, cloud_off, rain_fac, source):
        self.root.after(0, lambda: self.cal_label.config(
            text=f'☁️ 云量偏差 {cloud_off:+.0f}%  |  🌧 降雨系数 ×{rain_fac:.1f}  |  依据：{source}'))

    def do_query(self):
        self.btn.config(state='disabled')
        self.progress.pack(pady=3); self.progress.start()
        self.status.config(text='⏳ 查询中…'); self.result.delete('1.0', 'end')
        threading.Thread(target=self.query, daemon=True).start()

    def query(self):
        try:
            wttr, gfs, nmc = None, None, None
            cloud_off, rain_fac = DEFAULT_CLOUD_OFFSET, DEFAULT_RAIN_FACTOR
            cal_source = '历史默认（实测不足时）'

            self.log(f"📍 北京海淀（{LAT}, {LON}）⏰ {datetime.now().strftime('%Y-%m-%d %H:%M')}")
            self.log('━' * 70)

            # ── 源1：wttr.in 实测 ──
            self.log('📡 源1 — wttr.in 实测站…')
            try:
                d = json.loads(fetch(f"https://wttr.in/{urllib.parse.quote(CITY)}?format=j1"))
                cc = d['current_condition'][0]
                wttr = {
                    'temp': int(cc['temp_C']), 'feels': int(cc.get('FeelsLikeC', cc['temp_C'])),
                    'humid': int(cc['humidity']), 'wind': int(cc['windspeedKmph']),
                    'cloud': int(cc['cloudcover']), 'desc': cc.get('weatherDesc', [{}])[0].get('value', ''),
                }
                self.log(f"\n🌡 当前实况：{wttr['temp']}°C（体感 {wttr['feels']}°C）")
                self.log(f"   湿度：{wttr['humid']}%  风速：{wttr['wind']}km/h")
                self.log(f"   云量：{wttr['cloud']}%  天气：{wttr['desc']}")
            except Exception as e:
                self.log(f"⚠️ 实测获取失败：{e}")

            # ── 源2：Open-Meteo GFS ──
            self.log('\n📡 源2 — Open-Meteo（GFS 模型）…')
            try:
                u = (f"https://api.open-meteo.com/v1/forecast?latitude={LAT}&longitude={LON}"
                     f"&current_weather=true"
                     f"&hourly=temperature_2m,precipitation_probability,cloudcover,weathercode"
                     f"&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,weathercode"
                     f"&timezone=auto&forecast_days=3")
                d = json.loads(fetch(u))
                gfs = {'current': {}, 'daily': [], 'hourly': []}

                if 'current_weather' in d:
                    c = d['current_weather']
                    gfs['current'] = {'temp': c['temperature'], 'wind': c['windspeed'], 'code': c['weathercode']}
                    self.log(f"   当前温度：{c['temperature']}°C  风速：{c['windspeed']}km/h")

                from datetime import datetime as d2
                now_h = d2.now().hour
                times = d['hourly']['time']
                for i, t in enumerate(times):
                    h = int(t.split('T')[1].split(':')[0])
                    if h == now_h or (h == now_h - 1 and not [x for x in zip(times, d['hourly']['temperature_2m']) if int(x[0].split('T')[1].split(':')[0]) == now_h]):
                        gfs['h_cloud'] = d['hourly']['cloudcover'][i]
                        gfs['h_rain'] = d['hourly']['precipitation_probability'][i]
                        gfs['h_temp'] = d['hourly']['temperature_2m'][i]
                        self.log(f"   逐小时预报：{gfs['h_temp']}°C, 云量{gfs['h_cloud']}%, 降雨{gfs['h_rain']}%")
                        break

                # 未来 3 天
                daily = d.get('daily', {})
                dates = daily.get('time', [])
                for i in range(min(len(dates), 3)):
                    gfs['daily'].append({
                        'date': dates[i], 'max': daily['temperature_2m_max'][i],
                        'min': daily['temperature_2m_min'][i],
                        'rain': daily['precipitation_probability_max'][i],
                        'code': daily['weathercode'][i],
                    })
            except Exception as e:
                self.log(f"⚠️ GFS 获取失败：{e}")

            # ── 源3：nmc.cn 中国天气网 ──
            self.log('\n📡 源3 — nmc.cn 中国天气网…')
            for eid in ['54511', '54399']:
                try:
                    d = json.loads(fetch(f"http://www.nmc.cn/rest/weather?stationid={eid}"))
                    r = d.get('real', {})
                    if r and r.get('temperature'):
                        nmc = {'temp': r['temperature'], 'humid': r.get('humidity','?')}
                        self.log(f"   站 {eid}：{r['temperature']}°C, 湿度{r.get('humidity','?')}%")
                        break
                except:
                    continue
            if not nmc:
                self.log('   nmc.cn 暂不可用（API 端点可能已更新）')

            # ── 动态校准计算 ──
            self.log('\n' + '━' * 70)
            self.log('🧮 动态校准计算…')
            cal_notes = []

            if wttr and gfs and 'h_cloud' in gfs:
                # 云量偏差：实测 - 预报 = 负值说明预报偏高
                raw_cloud_off = wttr['cloud'] - gfs['h_cloud']
                cloud_off = raw_cloud_off
                # 如果偏差非常大，限制一下范围
                cloud_off = max(-80, min(20, cloud_off))
                cal_source = f'实时比对（GFS 报{gfs["h_cloud"]}% vs 实测{wttr["cloud"]}%）'
                cal_notes.append(f'☁️ GFS 报云量 {gfs["h_cloud"]}% → 实测 {wttr["cloud"]}% → 偏差 {cloud_off:+.0f}%')

                # 降雨系数：如果云量预报偏高，降雨概率也应该打折
                if cloud_off < -30:
                    rain_fac = 0.4
                elif cloud_off < -15:
                    rain_fac = 0.5
                else:
                    rain_fac = 0.6
                cal_notes.append(f'🌧 云量偏差 {cloud_off:+.0f}% → 降雨系数取 ×{rain_fac:.1f}')

                # 温度校验
                temp_diff = wttr['temp'] - gfs['h_temp']
                cal_notes.append(f'🌡 GFS 报温 {gfs["h_temp"]}°C vs 实测 {wttr["temp"]}°C → 差 {temp_diff:+.0f}°C')
            else:
                cal_notes.append('⚠️ 实测或预报数据不足，使用历史默认校准系数')
                cal_notes.append(f'   ☁️ 云量 {DEFAULT_CLOUD_OFFSET:+.0f}%   🌧 降雨 ×{DEFAULT_RAIN_FACTOR}')

            self.cal_update(cloud_off, rain_fac, cal_source)
            for note in cal_notes:
                self.log(f'   {note}')

            # ── 校准后预报 ──
            self.log('\n📅 校准后逐时预报：')
            self.log(f"{'时间':>6} {'天气':>6} {'温度':>6} {'降雨':>6} {'云量':>6}")

            from datetime import datetime as d3
            now_h = d3.now().hour
            shown = 0
            times = d['hourly']['time']
            for i, t in enumerate(times):
                h = int(t.split('T')[1].split(':')[0])
                if h >= now_h and shown < 10:
                    cr = min(100, max(0, int(d['hourly']['precipitation_probability'][i] * rain_fac)))
                    cc = min(100, max(0, d['hourly']['cloudcover'][i] + cloud_off))
                    rmark = '⚠️' if cr > 50 else ('🌂' if cr > 30 else '')
                    cmark = '☁️' if cc > 60 else ('🌤' if cc > 25 else '☀️')
                    self.log(f"  {t[11:16]}  {CODES.get(d['hourly']['weathercode'][i],'?'):>6}  "
                             f"{d['hourly']['temperature_2m'][i]:>4}°C  {cr:>3}%{rmark}  {cc:>3}%{cmark}")
                    shown += 1

            # 未来 3 天
            if gfs and gfs.get('daily'):
                self.log(f"\n📅 未来 3 天（已校准）：")
                for day in gfs['daily']:
                    cr = min(100, max(0, int(day['rain'] * rain_fac)))
                    rmark = ' ⚠️带伞' if cr > 50 else (' 🌂备伞' if cr > 30 else '')
                    self.log(f"   {day['date']}  {CODES.get(day['code'],'?')}  "
                             f"{day['min']}~{day['max']}°C  降雨 {cr}%{rmark}")

            # 建议
            self.log('\n' + '━' * 70)
            self.log('🎯 建议：')
            if wttr:
                t = wttr['temp']
                if t > 35: self.log('   🥵 高温预警！注意防暑')
                elif t < 10: self.log('   🥶 气温较低，注意保暖')
                else: self.log(f'   🌡 当前 {t}°C，体感舒适')
            self.log('\n   💡 校准逻辑：实时比对 GFS 预报 vs 实测站数据')
            self.log('   💡 系数随每次查询动态更新，不是固定值')
            self.log('   💡 数据源：wttr.in（实测）+ Open-Meteo（GFS）+ nmc.cn')

            self.root.after(0, self.done)
        except Exception as e:
            self.root.after(0, lambda: self.err(str(e)))

    def done(self):
        self.progress.stop(); self.progress.pack_forget()
        self.btn.config(state='normal'); self.status.config(text='✅ 查询完成')
    def err(self, msg):
        self.progress.stop(); self.progress.pack_forget()
        self.btn.config(state='normal'); self.status.config(text='❌ 失败')
        self.log(f'\n❌ {msg}')
    def run(self): self.root.mainloop()

if __name__ == '__main__':
    BeijingWeatherApp().run()
