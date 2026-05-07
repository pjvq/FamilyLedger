#!/usr/bin/env bash
set -euo pipefail

# ─── FamilyLedger 一键部署脚本 ───────────────────────────────────────────────
# 用法: ./deploy.sh <HOST> [USER] [PORT]
#   HOST  - 目标服务器 IP 或域名 (必填)
#   USER  - SSH 用户名 (默认 root)
#   PORT  - SSH 端口 (默认 22)
#
# 示例:
#   ./deploy.sh 1.2.3.4
#   ./deploy.sh 1.2.3.4 ubuntu 2222
#
# 前置条件:
#   - 本地已安装 docker
#   - 目标服务器已安装 docker + docker compose
#   - 本地 SSH key 可免密登录目标服务器
# ─────────────────────────────────────────────────────────────────────────────

HOST="${1:?用法: ./deploy.sh <HOST> [USER] [PORT]}"
USER="${2:-root}"
PORT="${3:-22}"

SSH_OPTS="-o StrictHostKeyChecking=accept-new -p ${PORT}"
SSH_CMD="ssh ${SSH_OPTS} ${USER}@${HOST}"
SCP_CMD="scp ${SSH_OPTS}"

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="familyledger-server"
IMAGE_TAG="$(git -C "${PROJECT_DIR}" rev-parse --short HEAD)"
IMAGE_FULL="${IMAGE_NAME}:${IMAGE_TAG}"
REMOTE_DIR="/opt/familyledger"
ARCHIVE="/tmp/${IMAGE_NAME}-${IMAGE_TAG}.tar.gz"

echo "══════════════════════════════════════════════════"
echo "  FamilyLedger Deploy"
echo "  Target: ${USER}@${HOST}:${PORT}"
echo "  Image:  ${IMAGE_FULL}"
echo "══════════════════════════════════════════════════"

# ─── Step 1: 本地构建 Docker 镜像 ───────────────────────────────────────────
echo ""
echo "📦 [1/5] Building Docker image..."
docker build -t "${IMAGE_FULL}" -t "${IMAGE_NAME}:latest" "${PROJECT_DIR}/server"

# ─── Step 2: 导出镜像为 tar.gz ───────────────────────────────────────────────
echo ""
echo "💾 [2/5] Saving image to ${ARCHIVE}..."
docker save "${IMAGE_FULL}" | gzip > "${ARCHIVE}"
SIZE=$(du -h "${ARCHIVE}" | cut -f1)
echo "   Size: ${SIZE}"

# ─── Step 3: 传输到服务器 ────────────────────────────────────────────────────
echo ""
echo "🚀 [3/5] Uploading to ${HOST}..."
${SSH_CMD} "mkdir -p ${REMOTE_DIR}"
${SCP_CMD} "${ARCHIVE}" "${USER}@${HOST}:${REMOTE_DIR}/"

# 传输 docker-compose.yml
${SCP_CMD} "${PROJECT_DIR}/docker-compose.yml" "${USER}@${HOST}:${REMOTE_DIR}/"

# 传输 .env.production（如果有）
if [[ -f "${PROJECT_DIR}/.env.production" ]]; then
  ${SCP_CMD} "${PROJECT_DIR}/.env.production" "${USER}@${HOST}:${REMOTE_DIR}/.env"
  echo "   .env.production → .env"
fi

# ─── Step 4: 远端加载镜像 ────────────────────────────────────────────────────
echo ""
echo "🐳 [4/5] Loading image on remote..."
${SSH_CMD} "docker load < ${REMOTE_DIR}/${IMAGE_NAME}-${IMAGE_TAG}.tar.gz"
# 打 latest tag 以便 docker-compose 引用
${SSH_CMD} "docker tag ${IMAGE_FULL} ${IMAGE_NAME}:latest"

# ─── Step 5: 启动/重启服务 ───────────────────────────────────────────────────
echo ""
echo "🔄 [5/5] Starting services..."
${SSH_CMD} "cd ${REMOTE_DIR} && docker compose up -d --force-recreate server"

# ─── 清理本地临时文件 ────────────────────────────────────────────────────────
rm -f "${ARCHIVE}"

# ─── 验证 ────────────────────────────────────────────────────────────────────
echo ""
echo "⏳ Waiting for server to start..."
sleep 3
if ${SSH_CMD} "docker ps --filter name=familyledger-server --format '{{.Status}}'" | grep -q "Up"; then
  echo ""
  echo "══════════════════════════════════════════════════"
  echo "  ✅ Deploy SUCCESS"
  echo "  gRPC: ${HOST}:50051"
  echo "  WS:   ${HOST}:8080"
  echo "══════════════════════════════════════════════════"
else
  echo ""
  echo "❌ Deploy FAILED — container not running"
  echo "   Check logs: ssh ${USER}@${HOST} -p ${PORT} 'docker logs familyledger-server'"
  exit 1
fi
