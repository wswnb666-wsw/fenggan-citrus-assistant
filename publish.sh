#!/usr/bin/env bash
# 把「丰柑智农助手」最新工作流同步到 GitHub。
#
# 用法：
#   bash publish.sh <github_token> ["提交说明"]
#
# 做三件事：
#   1) 从 Dify 导出**当前已发布版本**的 DSL → workflow/fenggan-workflow-v<版本号>.yml
#      · 按线上 version_number 自动命名；其余旧版本文件自动清理（git 历史里仍保留）
#      · 自动把 X-Internal-Token 的真实取值替换为 <YOUR-INTERNAL-TOKEN>（公开仓库绝不带真密钥）
#      · 依赖本机已登录 Dify 的 Chrome/CDP 会话；取不到就跳过导出，继续用现有 DSL 文件
#   2) git add / commit（无变化则跳过）
#   3) git push 到 origin（token 只在本次命令里用，不写入 git 配置）
#
# ⚠️ token 用完请在 https://github.com/settings/tokens 撤销。
set -euo pipefail
cd "$(dirname "$0")"

TOKEN="${1:-}"
MSG="${2:-同步工作流 DSL 与文档}"
REPO="wswnb666-wsw/fenggan-citrus-assistant"

if [ -z "$TOKEN" ]; then
  echo "用法: bash publish.sh <github_token> [\"提交说明\"]"
  exit 1
fi

# 🔴 宿主 shell 会注入自己的代理（如 http://127.0.0.1:50183，连不上 GitHub）——
#    这里必须【无条件覆盖】成 Clash 端口；写 "${HTTPS_PROXY:-7897}" 会被注入值顶掉（10-10 踩过）。
export HTTPS_PROXY="http://127.0.0.1:7897"
export HTTP_PROXY="http://127.0.0.1:7897"
export GIT_TERMINAL_PROMPT=0

# ---------- 1) 尝试从 Dify 导出最新 DSL ----------
PY="C:/Users/MR/.workbuddy/binaries/python/envs/default/Scripts/python.exe"
if [ -x "$PY" ]; then
  echo "[1/3] 尝试从 Dify 导出最新 DSL …"
  "$PY" - <<'PYEOF' || echo "      （导出跳过：Dify 会话不可用，继续用现有 DSL 文件）"
import glob
import json
import os
import re
import sys

sys.path.insert(0, r"C:/Users/MR/.workbuddy/skills/dify-console-automation/scripts")
from dify_api import Dify

APP = "77e5061a-78c6-4d80-b210-06c56caa5f05"
d = Dify(url_substr="cloud.dify.ai")
d.ws.settimeout(300)
try:
    st, r = d.api("/console/api/apps/%s/export?include_secret=false" % APP, "GET")
    if st != 200:
        sys.exit(1)
    try:
        j = json.loads(r)
        y = j.get("data") if isinstance(j, dict) else None
    except Exception:
        y = r
    if not y or len(y) < 1000:
        sys.exit(1)

    # 🔴 脱敏：X-Internal-Token 的真实取值绝不进公开仓库
    y, n = re.subn(r"(X-Internal-Token:\s*)([A-Za-z0-9._\-]{16,})", r"\1<YOUR-INTERNAL-TOKEN>", y)

    pub = d.api_json("/console/api/apps/%s/workflows/publish" % APP)[1]
    ver = pub.get("version_number")
    if not ver:
        sys.exit(1)
    fn = "workflow/fenggan-workflow-v%s.yml" % ver
    for old in glob.glob("workflow/fenggan-workflow-v*.yml"):
        if os.path.abspath(old) != os.path.abspath(fn):
            os.remove(old)
            print("      已移除旧文件:", old)
    open(fn, "w", encoding="utf-8").write(y)
    print("      已导出 %d 字节 → %s（脱敏 %d 处）；线上 version_number=%s hash=%s"
          % (len(y.encode("utf-8")), fn, n, ver, str(pub.get("hash"))[:16]))
finally:
    d.close()
PYEOF
else
  echo "[1/3] 跳过导出（未找到 Python 环境）"
fi

# ---------- 1.5) 脱敏闸门（提交前再扫一遍：任何非占位符的 X-Internal-Token 值都不得进仓库） ----------
if grep -rnE 'X-Internal-Token:[[:space:]]*[0-9a-zA-Z._-]{16,}' . --exclude-dir=.git --exclude=publish.sh 2>/dev/null; then
  echo "      ⛔ 检出未脱敏的 X-Internal-Token 值 —— 已中止提交与推送！"
  exit 1
fi
echo "      [1.5] 脱敏闸门 ✓（无真实密钥）"

# ---------- 2) 提交 ----------
echo "[2/3] 提交改动 …"
git add -A
if git diff --cached --quiet; then
  echo "      无变化，跳过提交"
else
  git -c core.quotepath=false commit -q -m "$MSG"
  git log --oneline -1
fi

# ---------- 3) 推送 ----------
echo "[3/3] 推送到 GitHub …"
git push -q "https://${TOKEN}@github.com/${REPO}.git" main:main
echo "      完成 → https://github.com/${REPO}"
echo
echo "提醒：用完请在 https://github.com/settings/tokens 撤销本次使用的 token。"
