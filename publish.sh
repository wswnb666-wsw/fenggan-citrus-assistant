#!/usr/bin/env bash
# 把「丰柑智农助手」最新工作流同步到 GitHub。
#
# 用法：
#   bash publish.sh <github_token> ["提交说明"]
#
# 做三件事：
#   1) 从 Dify 导出**当前已发布版本**的 DSL → workflow/fenggan-workflow-v88.yml
#      （依赖本机已登录 Dify 的 Chrome/CDP 会话；取不到就跳过，只提交现有文件）
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

export HTTPS_PROXY="${HTTPS_PROXY:-http://127.0.0.1:7897}"
export HTTP_PROXY="${HTTP_PROXY:-http://127.0.0.1:7897}"

# ---------- 1) 尝试从 Dify 导出最新 DSL ----------
PY="C:/Users/MR/.workbuddy/binaries/python/envs/default/Scripts/python.exe"
if [ -x "$PY" ]; then
  echo "[1/3] 尝试从 Dify 导出最新 DSL …"
  "$PY" - <<'PYEOF' || echo "      （导出跳过：Dify 会话不可用，继续用现有 DSL 文件）"
import json, sys
sys.path.insert(0, r"C:/Users/MR/.workbuddy/skills/dify-console-automation/scripts")
from dify_api import Dify
APP = "77e5061a-78c6-4d80-b210-06c56caa5f05"
d = Dify(url_substr="cloud.dify.ai"); d.ws.settimeout(180)
st, r = d.api("/console/api/apps/%s/export?include_secret=false" % APP, "GET")
if st != 200:
    sys.exit(1)
y = json.loads(r).get("data") or ""
if len(y) < 1000:
    sys.exit(1)
open("workflow/fenggan-workflow-v88.yml", "w", encoding="utf-8").write(y)
pub = d.api_json("/console/api/apps/%s/workflows/publish" % APP)[1]
print("      已导出 %d 字节；线上 version_number=%s hash=%s"
      % (len(y), pub.get("version_number"), str(pub.get("hash"))[:16]))
d.close()
PYEOF
else
  echo "[1/3] 跳过导出（未找到 Python 环境）"
fi

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
