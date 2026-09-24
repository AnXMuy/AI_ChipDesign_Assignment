from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={"width": 1280, "height": 900})
    page.goto("http://127.0.0.1:8765")
    page.wait_for_load_state("networkidle")
    assert page.locator("#overview h1").inner_text() == "卷积算子实验台"
    page.get_by_role("button", name="Python 仿真").click()
    page.get_by_label("输入高度").fill("3")
    page.get_by_label("输入宽度").fill("3")
    page.get_by_label("输入通道").fill("1")
    page.get_by_label("输出通道").fill("1")
    page.get_by_role("button", name="▶ 生成 golden").click()
    page.wait_for_function("document.querySelector('#python-log').textContent.includes('完成')")
    assert "input.hex" in page.locator("#python-files").inner_text()
    page.get_by_role("button", name="RTL 仿真").click()
    page.get_by_role("button", name="▶ 运行 RTL").click()
    page.wait_for_function("document.querySelector('#rtl-log').textContent.includes('PASS: 60 outputs compared')", timeout=30000)
    page.screenshot(path="/tmp/ai-chip-lab.png", full_page=True)
    print("UI PASS")
    browser.close()
