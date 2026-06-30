#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
小焕归类器 (Windows 版) — 双击运行，无控制台窗口
"""
import os, sys
os.chdir(os.path.dirname(os.path.abspath(__file__)))
# 启动主程序（不显示控制台）
import classifier_win
classifier_win.ClassifierApp().run()
