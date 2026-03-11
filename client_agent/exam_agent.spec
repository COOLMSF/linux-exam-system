# -*- mode: python ; coding: utf-8 -*-
# PyInstaller 打包配置文件
# 用于将 exam_agent.py 打包为麒麟系统可执行文件
#
# 使用方法:
#   pip3 install pyinstaller
#   pyinstaller exam_agent.spec
#
# 生成文件: dist/exam_agent (Linux 可执行文件)

block_cipher = None

a = Analysis(
    ['exam_agent.py'],
    pathex=[],
    binaries=[],
    datas=[],
    hiddenimports=[
        'requests',
        'urllib3',
        'certifi',
        'charset_normalizer',
        'idna',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'tkinter',
        'matplotlib',
        'numpy',
        'pandas',
        'PIL',
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='exam_agent',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,  # 终端程序，保持 console=True
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
