#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
小焕归类器 (Windows 版)
—— 选择文件夹 → 自动归类
双击运行，图形界面操作
"""

import os
import sys
import shutil
import subprocess
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from pathlib import Path
from datetime import datetime
import threading

# ── 分类规则 ──
RULES = [
    (['课件','讲义','教案','syllabus','课程','笔记','知识点','章节','复习','备考',
      '重点','大纲','课堂','lecture','handout','slide'], '课程学习'),
    (['论文','作业','报告','essay','paper','assignment','课题','项目','调研',
      '分析','综述','实验','结题','开题','答辩'], '论文作业'),
    (['english','ielts','toefl','cet4','cet6','单词','英语','外语','grammar',
      'vocabulary','reading','writing','listening','考研英语','专四','专八'], '英语学习'),
    (['文学','历史','哲学','社会','文化','人类学','考古','宗教','艺术',
      '美学','逻辑','伦理','心理','传播','新闻','政治','国际','改革'], '人文社科'),
    (['民法','刑法','诉讼法','宪法','行政法','国际法','经济法','法理','法制史',
      '权利','义务','合同','侵权','物权','债权','法律','法治','立法'], '法学'),
    (['数学','物理','化学','生物','统计','编程','python','java','c++','代码',
      '算法','数据','数据库','网络','人工智能','machine learning','deep learning',
      '实验报告','实验数据','代码'], '理工编程'),
    (['简历','求职','面试','实习','offer','招聘','网申','笔试','面经',
      'excel','word','ppt','powerpoint','wps','办公','office'], '求职办公'),
    (['png','jpg','jpeg','gif','webp','bmp','svg','heic'], '图片素材', 'by_ext'),
    (['电影','影视','剧集','综艺','纪录片','动漫','片单','追剧','影评','剪辑','视频'], '影视娱乐'),
    (['考研','保研','推免','复试','初试','分数线','专硕','学硕','考博',
      '研究生','硕士','博士'], '升学考研'),
    (['旅游','旅行','攻略','景点','酒店','机票','行程','签证','导游'], '旅游生活'),
    (['读书报告','读书笔记','札记','读后感','书评','书摘','摘抄','阅读'], '读书写作'),
]


def classify_file(filename):
    name_lower = filename.lower()
    ext = Path(filename).suffix.lower().lstrip('.')
    stem = Path(filename).stem.lower()
    for keywords, category, *flags in RULES:
        if flags and flags[0] == 'by_ext':
            if ext in keywords:
                return category
        else:
            for kw in keywords:
                if kw in stem or kw in name_lower:
                    return category
    return '其他'


def safe_move(src, dest_dir):
    dest = Path(dest_dir) / src.name
    if dest.exists():
        stem = dest.stem
        suffix = dest.suffix
        i = 1
        while True:
            new_name = f"{stem}_{i}{suffix}"
            new_path = dest.parent / new_name
            if not new_path.exists():
                dest = new_path
                break
            i += 1
    shutil.move(str(src), str(dest))
    return dest


def run_classify(folder_path, callback):
    try:
        folder = Path(folder_path)
        files = [f for f in folder.iterdir() if f.is_file() and f.name not in ('.DS_Store','Thumbs.db','desktop.ini')]
        if not files:
            callback(True, "文件夹是空的，没有需要整理的文件。", {})
            return
        classified = {}
        for f in files:
            cat = classify_file(f.name)
            classified.setdefault(cat, []).append(f)
        total = 0
        moved_details = []
        for cat, cat_files in classified.items():
            if cat == '其他':
                continue
            dest = folder / cat
            dest.mkdir(parents=True, exist_ok=True)
            for f in cat_files:
                safe_move(f, dest)
                moved_details.append(f"  {f.name} → {cat}/")
            total += len(cat_files)
        if '其他' in classified:
            dest = folder / '其他'
            dest.mkdir(parents=True, exist_ok=True)
            for f in classified['其他']:
                safe_move(f, dest)
                moved_details.append(f"  {f.name} → 其他/")
            total += len(classified['其他'])
        log_path = folder / '归类日志.txt'
        with open(log_path, 'a', encoding='utf-8') as log:
            log.write(f"小焕归类器 — {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            log.write(f"共整理 {total} 个文件\n")
            for cat, cf in sorted(classified.items()):
                log.write(f"  {cat}: {len(cf)} 个\n")
            log.write("\n【移动详情】\n")
            for detail in moved_details:
                log.write(detail + "\n")
            log.write("\n")
        callback(True, f"✅ 整理完成！共 {total} 个文件", classified)
    except Exception as e:
        callback(False, f"❌ 出错了：{str(e)}", {})


class ClassifierApp:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title('小焕归类器')
        self.root.geometry('520x420')
        self.root.resizable(False, False)

        tk.Label(self.root, text='📂 小焕归类器', font=('', 24, 'bold'),
                 fg='#2c3e50').pack(pady=(25, 5))
        tk.Label(self.root, text='选择文件夹 → 自动归类', font=('', 13),
                 fg='#7f8c8d').pack(pady=(0, 15))

        self.folder_var = tk.StringVar()
        frame = tk.Frame(self.root)
        frame.pack(pady=10, padx=30, fill='x')
        tk.Entry(frame, textvariable=self.folder_var, font=('', 11),
                 relief='solid', bd=1).pack(side='left', fill='x', expand=True, ipady=3)
        tk.Button(frame, text='选择文件夹', command=self.select_folder,
                  font=('', 11), bg='#3498db', fg='white',
                  padx=10).pack(side='right', padx=(8, 0))

        self.start_btn = tk.Button(self.root, text='开始归类 ▶', command=self.start_classify,
                                   font=('', 14, 'bold'), bg='#27ae60', fg='white',
                                   padx=20, pady=5, state='disabled')
        self.start_btn.pack(pady=10)

        self.progress = ttk.Progressbar(self.root, mode='indeterminate', length=300)
        self.status = tk.Label(self.root, text='', font=('', 11), fg='#555',
                                wraplength=450, justify='left')
        self.status.pack(pady=5)

        self.result_text = tk.Text(self.root, height=8, width=55, font=('', 10),
                                    relief='solid', bd=1, fg='#2c3e50')
        self.result_text.pack(pady=10, padx=30, fill='both', expand=True)

        self.log_var = tk.BooleanVar(value=True)
        tk.Checkbutton(self.root, text='整理完成后打开归类日志',
                       variable=self.log_var, font=('', 10)).pack(pady=(0, 10))

        self.root.protocol("WM_DELETE_WINDOW", self.root.quit)

    def select_folder(self):
        folder = filedialog.askdirectory(title='选择要整理的文件夹')
        if folder:
            self.folder_var.set(folder)
            self.start_btn.config(state='normal')
            self.result_text.delete('1.0', 'end')
            self.status.config(text='已选择文件夹，点击"开始归类"')

    def start_classify(self):
        folder = self.folder_var.get()
        if not folder or not os.path.isdir(folder):
            messagebox.showerror('错误', '请选择一个有效的文件夹')
            return
        self.start_btn.config(state='disabled')
        self.progress.pack(pady=5)
        self.progress.start()
        self.status.config(text='⏳ 正在整理中…')
        self.result_text.delete('1.0', 'end')
        threading.Thread(target=run_classify, args=(folder, self.callback), daemon=True).start()

    def callback(self, success, msg, classified):
        self.progress.stop()
        self.progress.pack_forget()
        self.start_btn.config(state='normal')
        self.status.config(text=msg)
        if success:
            self.result_text.insert('1.0', msg + '\n\n')
            for cat, cf in sorted(classified.items()):
                self.result_text.insert('end', f"  📁 {cat}: {len(cf)} 个\n")
            folder = Path(self.folder_var.get())
            log_file = folder / '归类日志.txt'
            if self.log_var.get() and log_file.exists():
                if sys.platform == 'win32':
                    os.startfile(str(log_file))
                elif sys.platform == 'darwin':
                    subprocess.run(['open', str(log_file)], capture_output=True)
                else:
                    subprocess.run(['xdg-open', str(log_file)], capture_output=True)
        else:
            self.result_text.insert('1.0', msg)

    def run(self):
        self.root.mainloop()


if __name__ == '__main__':
    app = ClassifierApp()
    app.run()
