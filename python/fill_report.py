import argparse
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(); parser.add_argument("--summary", default="results/summary.csv"); parser.add_argument("--template", default="report/report_template.md"); parser.add_argument("--out", default="report/report_draft.md"); args = parser.parse_args()
    summary = Path(args.summary).read_text(encoding="utf-8") if Path(args.summary).exists() else "尚未运行实验。"
    template = Path(args.template).read_text(encoding="utf-8")
    Path(args.out).write_text(template.replace("{{SUMMARY_CSV}}", "```csv\n" + summary + "```"), encoding="utf-8")


if __name__ == "__main__": main()
