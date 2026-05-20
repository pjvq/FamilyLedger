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
#
# TLS:
#   如果 deploy/tls/certs/ 下存在证书文件，自动部署 TLS 证书到服务器。
#   首次生成证书: cd deploy/tls && ./generate-self-signed.sh ./certs
# ─────────────────────────────────────────────────────────────────────────────

HOST="${1:?用法: ./deploy.sh <HOST> [USER] [PORT]}"
USER="${2:-root}"
PORT="${3:-22}"

SSH_OPTS="-o StrictHostKeyChecking=accept-new -p ${PORT}"
SCP_OPTS="-o StrictHostKeyChecking=accept-new -P ${PORT}"
SSH_CMD="ssh ${SSH_OPTS} ${USER}@${HOST}"
SCP_CMD="scp ${SCP_OPTS}"

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="familyledger-server"
IMAGE_TAG="$(git -C "${PROJECT_DIR}" rev-parse --short HEAD)"
IMAGE_FULL="${IMAGE_NAME}:${IMAGE_TAG}"
REMOTE_DIR="/opt/familyledger"
ARCHIVE="/tmp/${IMAGE_NAME}-${IMAGE_TAG}.tar.gz"
TLS_CERTS_DIR="${PROJECT_DIR}/deploy/tls/certs"
REMOTE_TLS_DIR="/etc/familyledger/tls"

# Detect TLS certificates
HAS_TLS=false
if [[ -f "${TLS_CERTS_DIR}/server.pem" && -f "${TLS_CERTS_DIR}/server-key.pem" && -f "${TLS_CERTS_DIR}/ca.pem" ]]; then
  HAS_TLS=true
fi

echo "══════════════════════════════════════════════════"
echo "  FamilyLedger Deploy"
echo "  Target: ${USER}@${HOST}:${PORT}"
echo "  Image:  ${IMAGE_FULL}"
echo "  TLS:    ${HAS_TLS}"
echo "══════════════════════════════════════════════════"

# ─── Step 1: 本地构建 Docker 镜像 ───────────────────────────────────────────
echo ""
echo "📦 [1/5] Building Docker image (linux/amd64)..."
docker build --platform linux/amd64 -t "${IMAGE_FULL}" -t "${IMAGE_NAME}:latest" "${PROJECT_DIR}/server"

# ─── Step 2: 导出镜像为 tar.gz ───────────────────────────────────────────────
echo ""
echo "💾 [2/5] Saving image to ${ARCHIVE}..."
docker save "${IMAGE_FULL}" | gzip > "${ARCHIVE}"
SIZE=$(du -h "${ARCHIVE}" | cut -f1)
echo "   Size: ${SIZE}"

# ─── Step 3: 传输到服务器 ────────────────────────────────────────────────────
echo ""
echo "🚀 [3/6] Uploading to ${HOST}..."
${SSH_CMD} "mkdir -p ${REMOTE_DIR}"
${SCP_CMD} "${ARCHIVE}" "${USER}@${HOST}:${REMOTE_DIR}/"

# 传输 deploy/ 下的 docker-compose.yml（生产版，含 TLS volume mount）
${SCP_CMD} "${PROJECT_DIR}/deploy/docker-compose.yml" "${USER}@${HOST}:${REMOTE_DIR}/docker-compose.yml"

# 传输 .env 文件（按优先级查找）
if [[ -f "${PROJECT_DIR}/deploy/.env.production" ]]; then
  ${SCP_CMD} "${PROJECT_DIR}/deploy/.env.production" "${USER}@${HOST}:${REMOTE_DIR}/.env"
  echo "   deploy/.env.production → .env"
elif [[ -f "${PROJECT_DIR}/.env.production" ]]; then
  ${SCP_CMD} "${PROJECT_DIR}/.env.production" "${USER}@${HOST}:${REMOTE_DIR}/.env"
  echo "   .env.production → .env"
elif [[ -f "${PROJECT_DIR}/deploy/.env" ]]; then
  ${SCP_CMD} "${PROJECT_DIR}/deploy/.env" "${USER}@${HOST}:${REMOTE_DIR}/.env"
  echo "   deploy/.env → .env"
else
  # 检查远端是否已有 .env，没有则报错
  if ! ${SSH_CMD} "test -f ${REMOTE_DIR}/.env" 2>/dev/null; then
    echo "   ❌ No .env file found! Create deploy/.env.production or deploy/.env"
    echo "   See deploy/.env.example for template."
    exit 1
  fi
  echo "   Using existing .env on remote"
fi

# ─── Step 4: 部署 TLS 证书 ───────────────────────────────────────────────────
if [[ "${HAS_TLS}" == "true" ]]; then
  echo ""
  echo "🔒 [4/6] Deploying TLS certificates..."
  ${SSH_CMD} "sudo mkdir -p ${REMOTE_TLS_DIR} && sudo chmod 700 ${REMOTE_TLS_DIR} && sudo chown ${USER}: ${REMOTE_TLS_DIR}"
  ${SCP_CMD} "${TLS_CERTS_DIR}/ca.pem" "${USER}@${HOST}:${REMOTE_TLS_DIR}/ca.pem"
  ${SCP_CMD} "${TLS_CERTS_DIR}/server.pem" "${USER}@${HOST}:${REMOTE_TLS_DIR}/server.pem"
  ${SCP_CMD} "${TLS_CERTS_DIR}/server-key.pem" "${USER}@${HOST}:${REMOTE_TLS_DIR}/server-key.pem"
  ${SSH_CMD} "sudo chmod 644 ${REMOTE_TLS_DIR}/ca.pem ${REMOTE_TLS_DIR}/server.pem && sudo chmod 600 ${REMOTE_TLS_DIR}/server-key.pem"
  echo "   ✓ ca.pem, server.pem, server-key.pem → ${REMOTE_TLS_DIR}/"
else
  echo ""
  echo "⚠️  [4/6] TLS certificates not found in deploy/tls/certs/, skipping TLS."
  echo "   Run: cd deploy/tls && ./generate-self-signed.sh ./certs"
fi

# ─── Step 5: 远端加载镜像 ────────────────────────────────────────────────────
echo ""
echo "🐳 [5/6] Loading image on remote..."
${SSH_CMD} "docker load < ${REMOTE_DIR}/${IMAGE_NAME}-${IMAGE_TAG}.tar.gz"
# 打 latest tag 以便 docker-compose 引用
${SSH_CMD} "docker tag ${IMAGE_FULL} ${IMAGE_NAME}:latest"

# ─── Step 6: 启动/重启服务 ───────────────────────────────────────────────────
echo ""
echo "🔄 [6/6] Starting services..."
${SSH_CMD} "cd ${REMOTE_DIR} && docker compose up -d --force-recreate server"

# ─── 清理本地临时文件 ────────────────────────────────────────────────────────
rm -f "${ARCHIVE}"

# ─── 验证 ────────────────────────────────────────────────────────────────────
echo ""
echo "⏳ Waiting for server to start..."
sleep 3
if ${SSH_CMD} "docker ps --filter name=familyledger-server --format '{{.Status}}'" | grep -q "Up"; then
  TLS_STATUS="plaintext"
  if [[ "${HAS_TLS}" == "true" ]]; then
    TLS_STATUS="TLS enabled"
  fi
  echo ""
  echo "══════════════════════════════════════════════════"
  echo "  ✅ Deploy SUCCESS"
  echo "  gRPC: ${HOST}:50051  (${TLS_STATUS})"
  echo "  WS:   ${HOST}:8080   (${TLS_STATUS})"
  echo "══════════════════════════════════════════════════"
else
  echo ""
  echo "❌ Deploy FAILED — container not running"
  echo "   Check logs: ssh ${USER}@${HOST} -p ${PORT} 'docker logs familyledger-server'"
  exit 1
fi
