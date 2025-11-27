# EdgeBox Makefile for Docker Image Building
# 使用方法: make build [ARCH=amd64|arm64] [TAG=latest]

# 默认参数
ARCH ?= $(shell uname -m | sed 's/aarch64/arm64/' | sed 's/x86_64/amd64/')
IMAGE_TAG ?= latest
DOCKER_FILE_PATH ?= ./sandbox

# 镜像名称
IMAGE_NAME ?= e2b-sandbox

# 构建输出目录
OUTPUT_DIR ?= ./sandbox_images
OUTPUT_FILE ?= $(OUTPUT_DIR)/$(IMAGE_NAME)-$(ARCH).tar.gz

# 颜色定义
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m

.PHONY: help build build-local build-multi clean verify-images list-images load-image

# 默认目标 - 显示帮助
help: ## 显示帮助信息
	@echo "$(CYAN)EdgeBox Docker Image Build System$(RESET)"
	@echo ""
	@echo "$(YELLOW)可用命令:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)示例用法:$(RESET)"
	@echo "  make build                    # 构建当前架构的镜像"
	@echo "  make build ARCH=arm64         # 构建 ARM64 镜像"
	@echo "  make build ARCH=amd64         # 构建 AMD64 镜像"
	@echo "  make build TAG=v1.0.0         # 构建指定标签的镜像"
	@echo "  make build-local              # 构建并加载到本地 Docker"
	@echo "  make build-multi ARCH=arm64,amd64  # 构建多架构镜像"
	@echo ""
	@echo "$(YELLOW)当前环境:$(RESET)"
	@echo "  架构: $(ARCH)"
	@echo "  镜像名: $(IMAGE_NAME):$(IMAGE_TAG)"
	@echo "  Docker 文件: $(DOCKER_FILE_PATH)/Dockerfile"

# 检查 Docker 环境
check-docker:
	@echo "$(CYAN)检查 Docker 环境...$(RESET)"
	@which docker > /dev/null || (echo "$(RED)错误: 未找到 Docker 命令$(RESET)" && exit 1)
	@docker info > /dev/null || (echo "$(RED)错误: Docker 服务未运行$(RESET)" && exit 1)
	@echo "$(GREEN)✓ Docker 环境正常$(RESET)"
	@echo "  Docker 版本: $$(docker --version)"
	@echo "  当前架构: $(ARCH)"

# 检查 Docker Buildx 是否可用
check-buildx:
	@echo "$(CYAN)检查 Docker Buildx...$(RESET)"
	@docker buildx version > /dev/null 2>&1 || (echo "$(YELLOW)警告: Docker Buildx 不可用，使用标准 build$(RESET)" && exit 1)
	@echo "$(GREEN)✓ Docker Buildx 可用$(RESET)"
	@docker buildx version

# 构建 Docker 镜像 - 核心命令
build: check-docker ## 构建 Docker 镜像 (使用 buildx)
	@echo "$(CYAN)开始构建 Docker 镜像...$(RESET)"
	@echo "  架构: $(ARCH)"
	@echo "  镜像名: $(IMAGE_NAME):$(IMAGE_TAG)"
	@echo "  工作目录: $(DOCKER_FILE_PATH)"
	@echo ""
	@cd $(DOCKER_FILE_PATH) && \
	docker buildx build \
		--platform linux/$(ARCH) \
		--tag $(IMAGE_NAME):$(IMAGE_TAG) \
		--load \
		.
	@echo ""
	@echo "$(GREEN)✓ 镜像构建完成: $(IMAGE_NAME):$(IMAGE_TAG)$(RESET)"

# 构建并加载到本地 Docker (简化版)
build-local: check-docker ## 构建并加载镜像到本地 Docker
	@echo "$(CYAN)构建并加载镜像到本地 Docker...$(RESET)"
	@echo ""
	@cd $(DOCKER_FILE_PATH) && \
	docker build \
		-t $(IMAGE_NAME):$(IMAGE_TAG) \
		-t $(IMAGE_NAME):$(ARCH) \
		.
	@echo ""
	@echo "$(GREEN)✓ 镜像已加载到本地 Docker$(RESET)"
	@echo "  镜像 ID: $$(docker images $(IMAGE_NAME):$(IMAGE_TAG) --format '{{.ID}}')"
	@echo "  大小: $$(docker images $(IMAGE_NAME):$(IMAGE_TAG) --format '{{.Size}}')"

# 构建多架构镜像
build-multi: check-docker check-buildx ## 构建多架构镜像
	@echo "$(CYAN)构建多架构镜像...$(RESET)"
	@echo "  架构列表: $(ARCH)"
	@echo "  镜像名: $(IMAGE_NAME):$(IMAGE_TAG)"
	@echo ""
	@cd $(DOCKER_FILE_PATH) && \
	docker buildx build \
		--platform $(patsubst %,linux/%,$(subst ,,$(ARCH))) \
		--tag $(IMAGE_NAME):$(IMAGE_TAG) \
		--load \
		.
	@echo ""
	@echo "$(GREEN)✓ 多架构镜像构建完成$(RESET)"

# 构建并导出为压缩文件
build-export: check-docker ## 构建并导出为 tar.gz 文件
	@echo "$(CYAN)构建并导出镜像...$(RESET)"
	@echo "  架构: $(ARCH)"
	@echo "  输出文件: $(OUTPUT_FILE)"
	@echo ""
	# 先构建镜像
	@$(MAKE) build
	# 创建输出目录
	@mkdir -p $(OUTPUT_DIR)
	# 导出镜像
	@echo "导出镜像到 $(OUTPUT_FILE)..."
	@docker save $(IMAGE_NAME):$(IMAGE_TAG) | gzip -1 > $(OUTPUT_FILE)
	@echo ""
	@echo "$(GREEN)✓ 镜像已导出: $(OUTPUT_FILE)$(RESET)"
	@ls -lh $(OUTPUT_FILE)

# 清理构建缓存
clean: ## 清理 Docker 构建缓存和临时文件
	@echo "$(CYAN)清理构建缓存...$(RESET)"
	@docker builder prune -f
	@docker buildx prune -f
	@echo "$(GREEN)✓ 缓存清理完成$(RESET)"

# 清理镜像
clean-images: ## 删除本地构建的镜像
	@echo "$(CYAN)删除本地镜像...$(RESET)"
	@docker rmi -f $(IMAGE_NAME):$(IMAGE_TAG) $(IMAGE_NAME):$(ARCH) 2>/dev/null || true
	@docker rmi -f $$(docker images $(IMAGE_NAME) -q) 2>/dev/null || true
	@echo "$(GREEN)✓ 镜像清理完成$(RESET)"

# 清理所有相关文件
clean-all: clean-images clean ## 清理所有构建文件
	@echo "$(CYAN)清理所有构建文件...$(RESET)"
	@rm -rf $(OUTPUT_DIR)
	@echo "$(GREEN)✓ 清理完成$(RESET)"

# 验证镜像
verify: check-docker ## 验证构建的镜像
	@echo "$(CYAN)验证镜像: $(IMAGE_NAME):$(IMAGE_TAG)$(RESET)"
	@docker images $(IMAGE_NAME) | grep -E "REPOSITORY|$(IMAGE_NAME)"
	@echo ""
	@if docker image inspect $(IMAGE_NAME):$(IMAGE_TAG) > /dev/null 2>&1; then \
		echo "$(GREEN)✓ 镜像验证成功$(RESET)"; \
		echo "  镜像 ID: $$(docker images $(IMAGE_NAME):$(IMAGE_TAG) --format '{{.ID}}')"; \
		echo "  大小: $$(docker images $(IMAGE_NAME):$(IMAGE_TAG) --format '{{.Size}}')"; \
		echo "  创建时间: $$(docker images $(IMAGE_NAME):$(IMAGE_TAG) --format '{{.CreatedSince}}')"; \
	else \
		echo "$(RED)✗ 镜像验证失败: $(IMAGE_NAME):$(IMAGE_TAG)$(RESET)"; \
		exit 1; \
	fi

# 列出所有相关镜像
list-images: ## 列出所有相关镜像
	@echo "$(CYAN)本地镜像列表:$(RESET)"
	@docker images | grep -E "REPOSITORY|$(IMAGE_NAME)|e2b" || echo "未找到相关镜像"

# 运行镜像测试
test-image: check-docker ## 测试镜像是否能正常启动
	@echo "$(CYAN)测试镜像启动...$(RESET)"
	@docker run --rm -d --name test-$(IMAGE_NAME) $(IMAGE_NAME):$(IMAGE_TAG) sleep 10
	@echo "等待容器启动..."
	@sleep 5
	@if docker ps | grep -q test-$(IMAGE_NAME); then \
		echo "$(GREEN)✓ 镜像测试成功$(RESET)"; \
		docker stop test-$(IMAGE_NAME) > /dev/null 2>&1; \
	else \
		echo "$(RED)✗ 镜像测试失败$(RESET)"; \
		docker stop test-$(IMAGE_NAME) > /dev/null 2>&1; \
		exit 1; \
	fi

# 从压缩文件加载镜像
load-image: ## 从 tar.gz 文件加载镜像
	@echo "$(CYAN)从压缩文件加载镜像...$(RESET)"
	@if [ -f "$(OUTPUT_FILE)" ]; then \
		docker load < $(OUTPUT_FILE); \
		echo "$(GREEN)✓ 镜像加载完成: $(OUTPUT_FILE)$(RESET)"; \
	else \
		echo "$(RED)错误: 文件不存在: $(OUTPUT_FILE)$(RESET)"; \
		echo "请先运行: make build-export"; \
		exit 1; \
	fi

# 显示构建信息
info: ## 显示当前构建配置信息
	@echo "$(CYAN)EdgeBox Docker 构建配置$(RESET)"
	@echo ""
	@echo "$(YELLOW)环境信息:$(RESET)"
	@echo "  操作系统: $$(uname -s)"
	@echo "  架构: $(ARCH)"
	@echo "  Docker 版本: $$(docker --version 2>/dev/null || echo '未安装')"
	@echo "  Buildx 版本: $$(docker buildx version 2>/dev/null || echo '不可用')"
	@echo ""
	@echo "$(YELLOW)镜像配置:$(RESET)"
	@echo "  镜像名: $(IMAGE_NAME)"
	@echo "  标签: $(IMAGE_TAG)"
	@echo "  完整名称: $(IMAGE_NAME):$(IMAGE_TAG)"
	@echo "  Dockerfile: $(DOCKER_FILE_PATH)/Dockerfile"
	@echo ""
	@echo "$(YELLOW)输出配置:$(RESET)"
	@echo "  输出目录: $(OUTPUT_DIR)"
	@echo "  输出文件: $(OUTPUT_FILE)"
	@echo ""
	@if [ -f "$(OUTPUT_FILE)" ]; then \
		echo "$(GREEN)✓ 输出文件存在: $$(ls -lh $(OUTPUT_FILE))$(RESET)"; \
	else \
		echo "$(YELLOW)输出文件不存在: 需要先运行 make build-export$(RESET)"; \
	fi
