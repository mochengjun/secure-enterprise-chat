# 部署指南

本文档详细介绍企业安全聊天应用的部署流程，包括本地开发、Docker部署和Kubernetes生产环境部署。

## 目录

- [环境要求](#环境要求)
- [本地开发部署](#本地开发部署)
- [Docker部署](#docker部署)
- [Kubernetes生产部署](#kubernetes生产部署)
- [配置说明](#配置说明)
- [监控与运维](#监控与运维)
- [故障排除](#故障排除)

---

## 环境要求

### 开发环境

| 工具 | 版本要求 | 说明 |
|------|----------|------|
| Go | 1.21+ | 后端服务开发 |
| Flutter | 3.16+ | 客户端开发 |
| Docker | 24.0+ | 容器化部署 |
| Docker Compose | 2.20+ | 本地多容器编排 |
| kubectl | 1.28+ | Kubernetes管理 |
| Helm | 3.12+ | K8s包管理(可选) |

### 生产环境

| 组件 | 推荐配置 |
|------|----------|
| CPU | 4核心+ |
| 内存 | 8GB+ |
| 存储 | 100GB SSD+ |
| 网络 | 100Mbps+ |

---

## 本地开发部署

### 1. 克隆项目

```bash
git clone <repository-url>
cd secure-enterprise-chat
```

### 2. 启动后端服务

```bash
# 进入后端服务目录
cd services/auth-service

# 安装Go依赖
go mod tidy

# 使用SQLite本地运行(开发模式)
export USE_SQLITE=true
export JWT_SECRET=your-secret-key-at-least-32-chars

# 启动服务
go run cmd/main.go
```

服务将在 `http://localhost:8081` 启动。

### 3. 验证后端服务

```bash
# 健康检查
curl http://localhost:8081/health

# 测试注册
curl -X POST http://localhost:8081/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"TestPass123!"}'

# 测试登录
curl -X POST http://localhost:8081/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"TestPass123!"}'
```

### 4. 启动Flutter客户端

```bash
cd apps/flutter_app

# 安装依赖
flutter pub get

# Windows桌面端
flutter run -d windows

# Android模拟器
flutter run -d android

# iOS模拟器(需要macOS)
flutter run -d ios
```

---

## Docker部署

### 1. 基础设施服务

```bash
cd deployments/docker

# 启动数据库和缓存
docker-compose up -d postgres redis

# 查看服务状态
docker-compose ps
```

### 2. 环境变量配置

创建 `.env` 文件:

```env
# 数据库配置
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=secchat
POSTGRES_PASSWORD=your-secure-password
POSTGRES_DB=secchat

# Redis配置
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=your-redis-password

# JWT配置
JWT_SECRET=your-jwt-secret-key-at-least-32-characters

# 服务配置
AUTH_SERVICE_PORT=8081
MEDIA_SERVICE_PORT=8082
```

### 3. 启动应用服务

```bash
# 构建并启动所有服务
docker-compose up -d

# 查看日志
docker-compose logs -f auth-service
```

### 服务端口映射

| 服务 | 容器端口 | 主机端口 |
|------|----------|----------|
| PostgreSQL | 5432 | 5432 |
| Redis | 6379 | 6379 |
| Auth Service | 8081 | 8081 |
| Media Proxy | 8082 | 8082 |
| MinIO | 9000/9001 | 9000/9001 |

---

## Kubernetes生产部署

### 1. 命名空间创建

```bash
kubectl apply -f deployments/k8s/base/namespace.yaml
```

### 2. 配置Secrets

```bash
# 创建数据库密钥
kubectl create secret generic db-credentials \
  --namespace=sec-chat \
  --from-literal=postgres-password=your-secure-password \
  --from-literal=redis-password=your-redis-password

# 创建JWT密钥
kubectl create secret generic jwt-secret \
  --namespace=sec-chat \
  --from-literal=secret=your-jwt-secret-key-32chars
```

### 3. 部署基础设施

```bash
# PostgreSQL
kubectl apply -f deployments/k8s/base/postgres.yaml

# Redis
kubectl apply -f deployments/k8s/base/redis.yaml

# ConfigMap
kubectl apply -f deployments/k8s/base/configmap.yaml
```

### 4. 部署应用服务

```bash
# Auth Service
kubectl apply -f deployments/k8s/base/auth-service.yaml

# Ingress
kubectl apply -f deployments/k8s/base/ingress.yaml
```

### 5. 使用Kustomize部署

```bash
# 开发环境
kubectl apply -k deployments/k8s/overlays/development

# 生产环境
kubectl apply -k deployments/k8s/overlays/production
```

### 6. 验证部署

```bash
# 查看Pod状态
kubectl get pods -n sec-chat

# 查看服务
kubectl get svc -n sec-chat

# 查看Ingress
kubectl get ingress -n sec-chat

# 查看日志
kubectl logs -f deployment/auth-service -n sec-chat
```

---

## 配置说明

### 环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `USE_SQLITE` | 使用SQLite(开发模式) | false |
| `POSTGRES_HOST` | PostgreSQL主机 | localhost |
| `POSTGRES_PORT` | PostgreSQL端口 | 5432 |
| `POSTGRES_USER` | PostgreSQL用户 | secchat |
| `POSTGRES_PASSWORD` | PostgreSQL密码 | - |
| `POSTGRES_DB` | PostgreSQL数据库 | secchat |
| `REDIS_HOST` | Redis主机 | localhost |
| `REDIS_PORT` | Redis端口 | 6379 |
| `JWT_SECRET` | JWT签名密钥 | - |
| `PORT` | 服务监听端口 | 8081 |

### TLS/SSL配置

生产环境建议启用HTTPS:

```yaml
# Ingress TLS配置示例
spec:
  tls:
  - hosts:
    - api.your-domain.com
    secretName: tls-secret
```

---

## 监控与运维

### Prometheus指标

服务暴露以下Prometheus指标端点:

- `/metrics` - Prometheus指标

### 健康检查端点

| 端点 | 说明 |
|------|------|
| `/health` | 服务健康状态 |
| `/ready` | 服务就绪状态 |

### 日志管理

日志格式为JSON，包含以下字段:
- `timestamp` - 时间戳
- `level` - 日志级别
- `message` - 日志消息
- `service` - 服务名称

### 备份策略

```bash
# PostgreSQL备份
pg_dump -h localhost -U secchat secchat > backup_$(date +%Y%m%d).sql

# 恢复
psql -h localhost -U secchat secchat < backup_20240101.sql
```

---

## 故障排除

### 常见问题

#### 1. 数据库连接失败

```bash
# 检查PostgreSQL状态
docker-compose ps postgres

# 检查连接
psql -h localhost -U secchat -d secchat
```

#### 2. Redis连接超时

```bash
# 检查Redis状态
redis-cli ping

# 检查内存使用
redis-cli info memory
```

#### 3. Flutter构建失败

```bash
# 清理构建缓存
flutter clean
flutter pub get

# 检查Flutter版本
flutter doctor
```

#### 4. Kubernetes Pod启动失败

```bash
# 查看Pod详情
kubectl describe pod <pod-name> -n sec-chat

# 查看Pod日志
kubectl logs <pod-name> -n sec-chat --previous
```

### 联系支持

如遇到无法解决的问题，请联系开发团队并提供:
1. 错误日志
2. 环境信息
3. 复现步骤

---

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0.0 | 2026-02 | 初始版本 |
