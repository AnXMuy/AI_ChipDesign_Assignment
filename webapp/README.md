# Web 工作台

启动本地服务：

```bash
conda activate ./.conda
python webapp/server.py
```

打开 <http://127.0.0.1:8765>。页面提供 Python golden 生成、Verilator 小尺寸/课程尺寸回归、Ultra96 PYNQ 配置保存和三份 LaTeX 模板入口。服务只监听本机，不会自动连接或修改 Ultra96。

