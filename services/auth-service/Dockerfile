# ============================================================
# Secure Enterprise Chat - Auth Service
# Production-grade multi-stage Dockerfile
# ============================================================

# Stage 1: Builder
FROM golang:1.23-alpine AS builder

# 安装构建依赖
RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /build

# 复制依赖文件并下载
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# 复制源代码
COPY . .

# 构建二进制文件（静态编译，无 CGO）
ARG VERSION=dev
ARG BUILD_TIME
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.Version=${VERSION} -X main.BuildTime=${BUILD_TIME}" \
    -trimpath \
    -o auth-service ./cmd/main.go

# Stage 2: Runtime
FROM alpine:3.23

# 安装运行时依赖
RUN apk --no-cache add ca-certificates tzdata curl && \
    rm -rf /var/cache/apk/*

# 创建非 root 用户
RUN addgroup -g 1000 appgroup && \
    adduser -u 1000 -G appgroup -s /bin/sh -D appuser

WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /build/auth-service .

# 复制静态资源（管理后台）
COPY --from=builder /build/internal/handler/admin_dashboard /app/admin_dashboard

# 创建必要目录
RUN mkdir -p /app/uploads/media \
             /app/uploads/thumbnails \
             /app/uploads/temp \
             /app/data \
             /app/logs && \
    chown -R appuser:appgroup /app

# 设置时区
ENV TZ=Asia/Shanghai

# 切换到非 root 用户
USER appuser

# 暴露端口
EXPOSE 8081

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8081/health || exit 1

# 启动服务
ENTRYPOINT ["/app/auth-service"]
