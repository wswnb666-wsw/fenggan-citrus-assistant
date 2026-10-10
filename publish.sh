#!/usr/bin/env bash
# 把本仓库的工作流 DSL 与文档同步到 GitHub。
#
# 用法：
#   bash publish.sh <github_token> ["提交说明"]
#
# 做三件事：
#   1) （可选）从 Dify 导出当前已发布版本的 DSL → workflow/fenggan-workflow-v<版本号>.yml。
#      导出逻辑放在本地脚本 _export_local.sh 里（该文件不随仓库公开；不存在时自动跳过，
#      直接使用仓库内现有 DSL 文件）。
#   2) git add / commit（无变化则跳过）
#   3) git push 到 origin（token 只在本次命令里用，不写入 git 配置）
#
# 注意：token 用完请在 https://github.com/settings/tokens 撤销。
set -euo pipefail
cd "$(dirname "$0")"

TOKEN="${1:-}"
MSG="${2:-同步工作流 DSL 与文档}"
REPO="wswnb666-wsw/fenggan-citrus-assistant"

if [ -z "$TOKEN" ]; then
  echo "用法: bash publish.sh <github_token> [\"提交说明\"]"
  exit 1
fi

# 本机访问 GitHub 走本地代理（按需改成你自己的代理端口）
export HTTPS_PROXY="http://127.0.0.1:7897"
export HTTP_PROXY="http://127.0.0.1:7897"
export GIT_TERMINAL_PROMPT=0

# ---------- 1) 可选：本地导出最新 DSL ----------
if [ -f "./_export_local.sh" ]; then
  echo "[1/3] 尝试导出最新 DSL …"
  bash "./_export_local.sh" || echo "      （导出跳过：本地导出工具不可用，继续用仓库内现有 DSL 文件）"
else
  echo "[1/3] 跳过导出（未配置本地导出工具，直接使用仓库内现有 DSL 文件）"
fi

# ---------- 1.5) 脱敏闸门（提交前再扫一遍：非占位符的 X-Internal-Token 值不得进仓库；覆盖 YAML/JSON/等号，fail-closed） ----------
#   ① 多格式：Token 后允许引号/空格再接 冒号或等号；② grep 自身出错（rc>=2）也一律中止，绝不静默放行
_gate_pat="X-Internal-Token[[:space:]]*[\"']?[[:space:]]*[:=][[:space:]]*[\"']?[0-9A-Za-z._-]{16,}"
_gate_hits=$(grep -rnE "$_gate_pat" . --exclude-dir=.git --exclude=publish.sh --exclude=_export_local.sh 2>/dev/null) || _gate_rc=$?
if [ "${_gate_rc:-0}" -ge 2 ]; then
  echo "      【中止】脱敏闸门自身执行失败（grep rc=${_gate_rc}）—— 已中止提交与推送！"
  exit 1
fi
if [ -n "$_gate_hits" ]; then
  echo "$_gate_hits"
  echo "      【中止】检出未脱敏的 X-Internal-Token 值 —— 已中止提交与推送！"
  exit 1
fi
echo "      [1.5] 脱敏闸门通过（无真实密钥）"

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
