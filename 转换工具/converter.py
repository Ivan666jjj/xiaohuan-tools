#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
小焕的转换工具 — PDF / 图片 / Word 互转
支持 Apple Silicon (M系列) / Intel Mac / Windows / Linux

双击运行 → 选择功能 → 选择文件 → 自动转换
"""

import os
import sys
import tkinter as tk
from tkinter import filedialog, messagebox, ttk, simpledialog
from pathlib import Path
import threading
import shutil
import subprocess
import tempfile
import platform


def open_folder(path):
    """跨平台打开文件夹"""
    path = str(path)
    if sys.platform == 'darwin':
        subprocess.run(['open', path], capture_output=True)
    elif sys.platform == 'win32':
        os.startfile(path)
    else:  # Linux
        subprocess.run(['xdg-open', path], capture_output=True)

# ── PDF 操作（纯 Python，不依赖外部命令）──
try:
    import fitz  # PyMuPDF
    HAS_PYMUPDF = True
except ImportError:
    HAS_PYMUPDF = False


def pdf_to_images(pdf_path, dpi=150):
    """PDF 每页转成图片"""
    import fitz
    doc = fitz.open(pdf_path)
    images = []
    for i in range(doc.page_count):
        zoom = dpi / 72
        mat = fitz.Matrix(zoom, zoom)
        pix = doc[i].get_pixmap(matrix=mat)
        tmp = os.path.join(tempfile.gettempdir(), f'_xh_p{i}.png')
        pix.save(tmp)
        images.append(tmp)
    doc.close()
    return images


def merge_pdfs(files, output_path):
    """合并多个 PDF"""
    import fitz
    doc = fitz.open()
    for fp in files:
        src = fitz.open(fp)
        doc.insert_pdf(src)
        src.close()
    doc.save(output_path)
    doc.close()


def split_pdf(pdf_path, output_dir):
    """拆分 PDF 为每页一个文件"""
    import fitz
    name = Path(pdf_path).stem
    doc = fitz.open(pdf_path)
    for i in range(doc.page_count):
        ndoc = fitz.open()
        ndoc.insert_pdf(doc, from_page=i, to_page=i)
        out = os.path.join(output_dir, f"{name}_p{i+1:03d}.pdf")
        ndoc.save(out)
        ndoc.close()
    doc.close()
    return doc.page_count


def extract_pages(pdf_path, pages, output_path):
    """提取指定页码"""
    import fitz
    doc = fitz.open(pdf_path)
    ndoc = fitz.open()
    for p in sorted(pages):
        if 1 <= p <= doc.page_count:
            ndoc.insert_pdf(doc, from_page=p-1, to_page=p-1)
    ndoc.save(output_path)
    ndoc.close()
    doc.close()


def images_to_pdf(images, output_path):
    """图片合并为 PDF"""
    import fitz
    doc = fitz.open()
    for img_path in images:
        img = fitz.open(img_path)
        rect = img[0].rect
        page = doc.new_page(width=rect.width, height=rect.height)
        page.insert_image(rect, filename=img_path)
        img.close()
    doc.save(output_path)
    doc.close()


# ── 转换工具类 ──
class ConverterApp:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title('小焕的转换工具')
        self.root.geometry('600x520')
        self.root.resizable(False, False)

        # 标题
        tk.Label(self.root, text='🔧 小焕的转换工具', font=('', 22, 'bold'),
                 fg='#2c3e50').pack(pady=(20, 5))
        tk.Label(self.root, text='PDF / 图片 / Word 互转 · 选择功能即可使用',
                 font=('', 11), fg='#7f8c8d').pack(pady=(0, 15))

        # 检查依赖
        if not HAS_PYMUPDF:
            tk.Label(self.root,
                     text='⚠️ 首次使用请先安装依赖：pip3 install PyMuPDF Pillow',
                     font=('', 10), fg='#c0392b').pack(pady=5)

        # 按钮区域
        frame = tk.Frame(self.root)
        frame.pack(fill='both', expand=True, padx=30, pady=5)

        self.tools = [
            ('📄 合并 PDF', self.do_merge, '将多个 PDF 合并为一个文件'),
            ('✂️ 拆分 PDF', self.do_split, '每页拆成一个单独的 PDF'),
            ('📋 提取页面', self.do_extract, '提取指定页码范围'),
            ('🖼️ 图片转 PDF', self.do_img2pdf, '多张图片合并为 PDF'),
            ('📝 PDF 转文字', self.do_pdf2text, '提取 PDF 中的文字内容'),
            ('📎 DOCX 转 PDF', self.do_docx2pdf, 'Word 文档转为 PDF'),
        ]

        for title, cmd, desc in self.tools:
            subf = tk.Frame(frame, relief='groove', borderwidth=1, padx=12, pady=6)
            subf.pack(fill='x', pady=3)
            btn = tk.Button(subf, text=title, command=cmd, width=18, height=1,
                            font=('', 12), bg='#3498db', fg='white',
                            activebackground='#2980b9', activeforeground='white')
            btn.pack(side='left', padx=(0, 12))
            tk.Label(subf, text=desc, font=('', 10), fg='#666').pack(side='left')

        # 状态
        self.status = tk.Label(self.root, text='就绪', font=('', 11), fg='#999')
        self.status.pack(pady=(10, 2))

        # 进度条
        self.progress = ttk.Progressbar(self.root, mode='indeterminate', length=300)

        # 输出文件夹
        self.out_var = tk.StringVar(value=str(Path.home() / 'Desktop' / '转换输出'))
        out_frame = tk.Frame(self.root)
        out_frame.pack(pady=5, padx=30, fill='x')
        tk.Label(out_frame, text='输出到:', font=('', 10)).pack(side='left')
        tk.Entry(out_frame, textvariable=self.out_var, font=('', 9),
                 relief='solid', bd=1).pack(side='left', fill='x', expand=True, padx=5, ipady=2)
        tk.Button(out_frame, text='选择', command=self.select_output,
                  font=('', 9)).pack(side='right')

    def select_output(self):
        folder = filedialog.askdirectory(title='选择输出文件夹')
        if folder:
            self.out_var.set(folder)

    def run_task(self, func):
        if not HAS_PYMUPDF:
            messagebox.showerror('缺少依赖', '请先运行：pip3 install PyMuPDF Pillow')
            return
        self.progress.pack(pady=5)
        self.progress.start()
        self.status.config(text='⏳ 处理中…')
        self.root.update()
        try:
            func()
        finally:
            self.progress.stop()
            self.progress.pack_forget()

    def do_merge(self):
        files = filedialog.askopenfilenames(title='选择要合并的 PDF', filetypes=[('PDF', '*.pdf')])
        if len(files) < 2:
            messagebox.showinfo('提示', '请选择至少 2 个 PDF 文件')
            return
        out = filedialog.asksaveasfilename(title='保存合并后的 PDF', defaultextension='.pdf',
                                            filetypes=[('PDF', '*.pdf')])
        if not out:
            return
        def task():
            merge_pdfs(files, out)
            self.status.config(text=f'✅ 合并完成：{Path(out).name}')
            messagebox.showinfo('完成', f'合并完成！\n共 {len(files)} 个文件\n保存到：{out}')
            open_folder(Path(out).parent)
        self.run_task(task)

    def do_split(self):
        fp = filedialog.askopenfilename(title='选择要拆分的 PDF', filetypes=[('PDF', '*.pdf')])
        if not fp:
            return
        output_dir = self.out_var.get()
        Path(output_dir).mkdir(parents=True, exist_ok=True)
        def task():
            n = split_pdf(fp, output_dir)
            self.status.config(text=f'✅ 拆分完成：{n} 页')
            messagebox.showinfo('完成', f'拆分完成！共 {n} 页\n保存到：{output_dir}')
            open_folder(output_dir)
        self.run_task(task)

    def do_extract(self):
        fp = filedialog.askopenfilename(title='选择 PDF', filetypes=[('PDF', '*.pdf')])
        if not fp:
            return
        pages_str = simpledialog.askstring('提取页面', '输入页码范围（如 1,3-5,8）：')
        if not pages_str:
            return
        pages = set()
        for part in pages_str.split(','):
            part = part.strip()
            if '-' in part:
                a, b = part.split('-')
                pages.update(range(int(a.strip()), int(b.strip())+1))
            else:
                pages.add(int(part))
        output_dir = self.out_var.get()
        Path(output_dir).mkdir(parents=True, exist_ok=True)
        name = Path(fp).stem
        out = os.path.join(output_dir, f'{name}_提取.pdf')
        def task():
            extract_pages(fp, pages, out)
            self.status.config(text=f'✅ 提取完成：{len(pages)} 页')
            messagebox.showinfo('完成', f'提取完成！共 {len(pages)} 页\n保存到：{out}')
            open_folder(Path(output_dir))
        self.run_task(task)

    def do_img2pdf(self):
        files = filedialog.askopenfilenames(title='选择图片', filetypes=[
            ('图片', '*.png *.jpg *.jpeg *.gif *.bmp *.webp')])
        if not files:
            return
        out = filedialog.asksaveasfilename(title='保存 PDF', defaultextension='.pdf',
                                            filetypes=[('PDF', '*.pdf')])
        if not out:
            return
        def task():
            images_to_pdf(files, out)
            self.status.config(text=f'✅ 转换完成：{len(files)} 张图片')
            messagebox.showinfo('完成', f'转换完成！共 {len(files)} 张图片\n保存到：{out}')
            open_folder(Path(out).parent)
        self.run_task(task)

    def do_pdf2text(self):
        fp = filedialog.askopenfilename(title='选择 PDF', filetypes=[('PDF', '*.pdf')])
        if not fp:
            return
        output_dir = self.out_var.get()
        Path(output_dir).mkdir(parents=True, exist_ok=True)
        name = Path(fp).stem
        out = os.path.join(output_dir, f'{name}.txt')
        def task():
            try:
                import fitz
                doc = fitz.open(fp)
                text = ''
                is_scanned = False
                for i in range(doc.page_count):
                    page_text = doc[i].get_text('text', sort=True)
                    if page_text.strip():
                        text += f'--- 第 {i+1} 页 ---\n{page_text}\n\n'
                    else:
                        is_scanned = True
                        text += f'--- 第 {i+1} 页（扫描页，无可选文字）---\n\n'
                doc.close()
                
                # 如果是扫描版 PDF，询问用户是否用 OCR
                if is_scanned:
                    use_ocr = messagebox.askyesno(
                        '检测到扫描版',
                        '这个 PDF 看起来是扫描版（图片型），用普通方式提取不到文字。\n\n'
                        '是否尝试用 OCR 识别文字？（需要额外安装 OCR 引擎）'
                    )
                    if use_ocr:
                        try:
                            import rapidocr_onnxruntime
                        except ImportError:
                            install = messagebox.askyesno(
                                '需要安装 OCR',
                                '需要安装 OCR 引擎（约 200MB）。是否现在安装？\n\n'
                                '命令：pip3 install rapidocr-onnxruntime'
                            )
                            if install:
                                self.status.config(text='⏳ 正在安装 OCR 引擎…')
                                self.root.update()
                                import subprocess
                                p = subprocess.run(
                                    [sys.executable, '-m', 'pip', 'install', 'rapidocr-onnxruntime'],
                                    capture_output=True, text=True, timeout=300)
                                if p.returncode != 0:
                                    messagebox.showerror('安装失败', f'安装失败：{p.stderr[:200]}')
                                    return
                                messagebox.showinfo('安装完成', 'OCR 引擎安装成功！再次点击"PDF 转文字"即可使用。')
                                return
                            else:
                                messagebox.showinfo('提示', '可以到 guji-tools 仓库下载古籍专用 OCR 工具。')
                                return
                        
                        # OCR 识别
                        from rapidocr_onnxruntime import RapidOCR
                        ocr_engine = RapidOCR()
                        self.status.config(text='⏳ OCR 识别中…')
                        self.root.update()
                        
                        doc2 = fitz.open(fp)
                        ocr_text = ''
                        for i in range(doc2.page_count):
                            zoom = 200 / 72
                            mat = fitz.Matrix(zoom, zoom)
                            pix = doc2[i].get_pixmap(matrix=mat)
                            from PIL import Image
                            import io
                            img_data = pix.tobytes("png")
                            img = Image.open(io.BytesIO(img_data))
                            result, _ = ocr_engine(img)
                            if result:
                                for line in result:
                                    ocr_text += line[1] + '\n'
                            ocr_text += '\n'
                        doc2.close()
                        text = ocr_text
                
                with open(out, 'w', encoding='utf-8') as f:
                    f.write(text)
                self.status.config(text='✅ 文字提取完成')
                messagebox.showinfo('完成', f'提取完成！保存到：{out}')
                open_folder(Path(output_dir))
            except Exception as e:
                messagebox.showerror('错误', str(e))
        self.run_task(task)

    def do_docx2pdf(self):
        files = filedialog.askopenfilenames(title='选择 Word 文档', filetypes=[('Word', '*.docx')])
        if not files:
            return
        output_dir = self.out_var.get()
        Path(output_dir).mkdir(parents=True, exist_ok=True)
        def task():
            results = []
            for fp in files:
                name = Path(fp).stem
                out = os.path.join(output_dir, f'{name}.pdf')
                converted = False
                
                # 方法1：macOS 自带的 textutil
                if sys.platform == 'darwin':
                    try:
                        subprocess.run(['textutil', '-convert', 'pdf', fp, '-output', out],
                                      check=True, timeout=30)
                        results.append(f'✅ {name}.pdf')
                        converted = True
                    except:
                        pass
                
                # 方法2：LibreOffice（如果已安装）
                if not converted:
                    for cmd in ['libreoffice', 'soffice']:
                        try:
                            subprocess.run([cmd, '--headless', '--convert-to', 'pdf', fp,
                                          '--outdir', output_dir],
                                          check=True, timeout=60,
                                          capture_output=True)
                            results.append(f'✅ {name}.pdf（通过 LibreOffice）')
                            converted = True
                            break
                        except:
                            pass
                
                # 方法3：纯 Python 转文字版 PDF（保底）
                if not converted:
                    try:
                        from docx import Document
                        from fpdf import FPDF
                        
                        doc = Document(fp)
                        pdf = FPDF()
                        pdf.add_page()
                        
                        # 尝试用系统自带中文字体
                        font_paths = {
                            'darwin': '/System/Library/Fonts/PingFang.ttc',
                            'win32': 'C:/Windows/Fonts/simsun.ttc',
                        }
                        font_file = font_paths.get(sys.platform, '')
                        if os.path.exists(font_file):
                            pdf.add_font('CJK', '', font_file, uni=True)
                            pdf.set_font('CJK', '', 12)
                        else:
                            pdf.add_font('CJK', '', '', uni=True)
                            pdf.set_font('CJK', '', 12)
                        
                        for para in doc.paragraphs:
                            if para.text.strip():
                                pdf.multi_cell(0, 8, para.text)
                        
                        pdf.output(out)
                        results.append(f'✅ {name}.pdf（文字版）')
                        converted = True
                    except ImportError:
                        results.append(f'⚠️ {name}: 需要安装 python-docx 和 fpdf2')
                    except Exception as e:
                        results.append(f'⚠️ {name}: {str(e)[:60]}')
                
                if not converted:
                    results.append(f'⚠️ {name}: 未能转换（可尝试安装 LibreOffice）')
            
            msg = '\n'.join(results)
            self.status.config(text='转换完成')
            messagebox.showinfo('完成', msg)
            open_folder(output_dir)
        self.run_task(task)

    def run(self):
        self.root.mainloop()


if __name__ == '__main__':
    # 在 macOS 上检查是否有 tkinter 和 PyMuPDF
    if sys.platform == 'darwin':
        # macOS 自带的 Python3 通常有 tkinter
        pass
    app = ConverterApp()
    app.run()
