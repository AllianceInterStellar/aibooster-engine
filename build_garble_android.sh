#!/bin/bash
#===============================================================================
# HiddifyCore 4.1.0 Android 混淆构建脚本
# 使用 garble + gomobile 构建深度混淆的 Android AAR
#===============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log_info()  { echo -e "${GREEN}✓${NC} $1"; }
log_warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_step()  { echo -e "${BLUE}▶${NC} $1"; }
log_title() { echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"; }

#===============================================================================
# 配置
#===============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$SCRIPT_DIR/bin"
OUTPUT_NAME="hiddify-core.aar"
INSTALL_DIR="$PROJECT_ROOT/android/app/libs"

# 本地工具目录
LOCAL_TOOLS_DIR="${HOME}/.cache/hiddify-build/tools"
GARBLE_BIN="$LOCAL_TOOLS_DIR/garble"
GOMOBILE_BIN="$LOCAL_TOOLS_DIR/gomobile"
GOBIND_BIN="$LOCAL_TOOLS_DIR/gobind"

# Android NDK 配置
ANDROID_API=21
if [ -z "$ANDROID_HOME" ]; then
    export ANDROID_HOME="$HOME/Library/Android/sdk"
fi
if [ -z "$ANDROID_NDK_HOME" ]; then
    # 自动寻找 NDK
    NDK_DIR=$(ls -d "$ANDROID_HOME/ndk/"* 2>/dev/null | sort -V | tail -1)
    if [ -n "$NDK_DIR" ]; then
        export ANDROID_NDK_HOME="$NDK_DIR"
    fi
fi

# 构建标签 - 与 Makefile 中 android 目标一致
BASE_TAGS="with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api,with_grpc,with_awg,tfogo_checklinkname0,with_naive_outbound,with_conntrack"
BUILD_TAGS="${BASE_TAGS}"

# Garble 参数
# -tiny: 移除额外的运行时信息以减小二进制大小
# -seed=random: 使用随机种子增加混淆强度
# 注意: 不使用 -literals 因为它会破坏 JSON 标签的反射操作
GARBLE_FLAGS="-tiny -seed=random"

# LDFLAGS
LDFLAGS="-w -s -checklinkname=0 -buildid="

# 开始时间
START_TIME=$(date +%s)

#===============================================================================
# 函数定义
#===============================================================================

print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║   HiddifyCore 4.1.0 Android 混淆构建脚本 (Garble + Gomobile)  ║"
    echo "║                                                               ║"
    echo "║  特性: 包路径混淆 | 函数名混淆 | Tiny模式 | 反射保护          ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

install_local_tools() {
    log_title "编译本地工具链"

    mkdir -p "$LOCAL_TOOLS_DIR"

    # ── 1. garble (从项目内 garble/ 源码编译) ──
    local GARBLE_SRC="$PROJECT_ROOT/garble"
    if [ ! -d "$GARBLE_SRC" ] || [ ! -f "$GARBLE_SRC/mobile.go" ]; then
        log_error "本地 garble 源码不存在: $GARBLE_SRC"
        log_error "请确保项目根目录下有 garble/ 目录 (含 Go 补丁的 starlancer1/garble fork)"
        exit 1
    fi

    if [ ! -f "$GARBLE_BIN" ] || [ "$GARBLE_SRC/main.go" -nt "$GARBLE_BIN" ] || [ "$GARBLE_SRC/go_std_tables.go" -nt "$GARBLE_BIN" ]; then
        log_step "编译 garble → $LOCAL_TOOLS_DIR/garble"
        (cd "$GARBLE_SRC" && go build -o "$GARBLE_BIN" . 2>&1)
        log_info "garble 编译完成"
    else
        log_info "garble 已是最新，跳过编译"
    fi

    # ── 2. gomobile ──
    if [ ! -f "$GOMOBILE_BIN" ]; then
        log_step "编译 gomobile → $LOCAL_TOOLS_DIR/gomobile"
        GOBIN="$LOCAL_TOOLS_DIR" go install github.com/sagernet/gomobile/cmd/gomobile@v0.1.11 2>&1
        log_info "gomobile 编译完成"
    else
        log_info "gomobile 已存在，跳过编译"
    fi

    # ── 3. gobind ──
    if [ ! -f "$GOBIND_BIN" ]; then
        log_step "编译 gobind → $LOCAL_TOOLS_DIR/gobind"
        GOBIN="$LOCAL_TOOLS_DIR" go install github.com/sagernet/gomobile/cmd/gobind@v0.1.11 2>&1
        log_info "gobind 编译完成"
    else
        log_info "gobind 已存在，跳过编译"
    fi

    # 将本地工具目录置于 PATH 最前面
    export PATH="$LOCAL_TOOLS_DIR:$PATH"

    log_info "工具链就绪: $LOCAL_TOOLS_DIR"
    log_info "  garble:   $($GARBLE_BIN version 2>&1 | head -1)"
    log_info "  gomobile: $(which gomobile)"
    log_info "  gobind:   $(which gobind)"
}

check_environment() {
    log_title "环境检查"

    # 检查 Go
    if ! check_command go; then
        log_error "Go 未安装，请先安装: brew install go"
        exit 1
    fi
    GO_VERSION=$(go version | awk '{print $3}')
    log_info "Go: $GO_VERSION"

    # 设置 GOPATH
    if [ -z "$GOPATH" ]; then
        export GOPATH="$HOME/go"
    fi

    # 检查 Android SDK
    if [ ! -d "$ANDROID_HOME" ]; then
        log_error "Android SDK 未找到: $ANDROID_HOME"
        log_error "请设置 ANDROID_HOME 环境变量"
        exit 1
    fi
    log_info "Android SDK: $ANDROID_HOME"

    # 检查 Android NDK
    if [ -z "$ANDROID_NDK_HOME" ] || [ ! -d "$ANDROID_NDK_HOME" ]; then
        log_error "Android NDK 未找到"
        log_error "请安装 NDK 或设置 ANDROID_NDK_HOME 环境变量"
        exit 1
    fi
    NDK_VERSION=$(basename "$ANDROID_NDK_HOME")
    log_info "Android NDK: $NDK_VERSION ($ANDROID_NDK_HOME)"
    log_info "Android API: $ANDROID_API"

    # 编译并安装工具链
    install_local_tools
}

prepare_build() {
    log_title "准备构建"

    cd "$SCRIPT_DIR"

    # 清理旧构建
    log_step "清理旧构建产物..."
    rm -f "$OUTPUT_DIR/$OUTPUT_NAME"
    rm -f "$OUTPUT_DIR/hiddify-core-sources.jar"

    # 下载依赖
    log_step "下载 Go 依赖..."
    export GOFLAGS=""
    export GOSUMDB="sum.golang.org"
    go mod download 2>&1 | head -5 || true
    go mod tidy 2>&1 | head -5 || true

    log_info "依赖准备完成"
}

build_aar() {
    log_title "构建混淆版 Android AAR"

    cd "$SCRIPT_DIR"
    mkdir -p "$OUTPUT_DIR"

    log_step "使用 garble mobile bind 构建..."
    log_info "混淆参数: $GARBLE_FLAGS"
    log_info "构建标签: $BUILD_TAGS"
    log_info "目标平台: android (API $ANDROID_API)"
    log_info "输出文件: $OUTPUT_DIR/$OUTPUT_NAME"

    echo ""
    log_warn "构建可能需要 15-30 分钟，请耐心等待..."
    echo ""

    # 设置环境变量
    export CGO_ENABLED=1
    export GOFLAGS=""
    export GOSUMDB="sum.golang.org"

    # 设置 GOGARBLE 环境变量来控制混淆范围
    # 重要: 只混淆 hiddify 自己的包！
    # 第三方包含 ARM/ARM64 汇编文件 (.s)，混淆会导致寄存器名被破坏
    export GOGARBLE="github.com/hiddify/*"

    log_info "混淆范围: github.com/hiddify/* (自有代码)"
    log_info "第三方包全部排除，避免汇编/cgo/linkname 兼容性问题"

    # 使用 garble mobile bind 构建 Android AAR
    "$GARBLE_BIN" $GARBLE_FLAGS mobile bind \
        -v \
        -androidapi=$ANDROID_API \
        -javapkg=com.ai.mybooster.core \
        -libname=hiddify-core \
        -tags="$BUILD_TAGS" \
        -trimpath \
        -ldflags="$LDFLAGS" \
        -target=android \
        -o "$OUTPUT_DIR/$OUTPUT_NAME" \
        github.com/sagernet/sing-box/experimental/libbox \
        ./platform/mobile 2>&1 | while IFS= read -r line; do
            # 过滤日志，只显示关键信息
            if [[ "$line" == *"write "* ]] || [[ "$line" == *".aar"* ]] || [[ "$line" == *"error"* ]] || [[ "$line" == *"Error"* ]] || [[ "$line" == *"warning"* ]]; then
                echo "$line"
            elif [[ ! "$line" =~ ^github\.com/ ]] && [[ ! "$line" =~ ^golang\.org/ ]] && [[ ! "$line" =~ ^internal/ ]] && [[ ! "$line" =~ ^vendor/ ]]; then
                echo "$line"
            fi
        done

    # 检查构建结果
    if [ ! -f "$OUTPUT_DIR/$OUTPUT_NAME" ]; then
        log_error "构建失败: 未生成 $OUTPUT_NAME"
        exit 1
    fi

    local AAR_SIZE=$(du -sh "$OUTPUT_DIR/$OUTPUT_NAME" | cut -f1)
    log_info "构建成功! AAR 大小: $AAR_SIZE"
}

verify_obfuscation() {
    log_title "验证混淆效果"

    local AAR_FILE="$OUTPUT_DIR/$OUTPUT_NAME"

    if [ ! -f "$AAR_FILE" ]; then
        log_warn "找不到 AAR 文件，跳过验证"
        return
    fi

    # 创建临时目录解压 AAR
    local TEMP_DIR=$(mktemp -d)
    unzip -q "$AAR_FILE" -d "$TEMP_DIR" 2>/dev/null || true

    # 查找 .so 文件
    local SO_FILES=$(find "$TEMP_DIR" -name "*.so" | head -5)

    if [ -z "$SO_FILES" ]; then
        log_warn "AAR 中未找到 .so 文件"
        rm -rf "$TEMP_DIR"
        return
    fi

    for SO_FILE in $SO_FILES; do
        local ARCH=$(echo "$SO_FILE" | grep -oE "arm64-v8a|armeabi-v7a|x86_64|x86")
        log_step "检查 $ARCH 架构..."

        # 检查包路径泄露
        local PKG_COUNT=$(strings "$SO_FILE" 2>/dev/null | grep -cE "^github\.com/|^golang\.org/" || echo "0")
        if [ "$PKG_COUNT" -eq 0 ]; then
            log_info "  ✓ 包路径: 已完全隐藏"
        else
            log_warn "  包路径泄露: $PKG_COUNT 处"
        fi

        # 检查敏感关键词
        local SENSITIVE_COUNT=$(strings "$SO_FILE" 2>/dev/null | grep -ciE "hiddify|sagernet|sing-box" || echo "0")
        if [ "$SENSITIVE_COUNT" -lt 5 ]; then
            log_info "  ✓ 敏感关键词: 基本隐藏 ($SENSITIVE_COUNT 处)"
        else
            log_warn "  敏感关键词: $SENSITIVE_COUNT 处"
        fi

        local SO_SIZE=$(du -sh "$SO_FILE" | cut -f1)
        log_info "  .so 大小: $SO_SIZE"
    done

    # 检查包含的架构
    log_step "AAR 包含架构:"
    find "$TEMP_DIR" -name "*.so" | while read -r f; do
        echo "  $(echo "$f" | grep -oE "arm64-v8a|armeabi-v7a|x86_64|x86")/$(basename "$f")"
    done | sort -u

    rm -rf "$TEMP_DIR"
}

install_aar() {
    log_title "安装到项目"

    # 确保目标目录存在
    mkdir -p "$INSTALL_DIR"

    # 备份旧 AAR
    if [ -f "$INSTALL_DIR/$OUTPUT_NAME" ]; then
        local BACKUP_NAME="${OUTPUT_NAME}.backup.$(date +%Y%m%d_%H%M%S)"
        log_step "备份旧 AAR: $BACKUP_NAME"
        cp "$INSTALL_DIR/$OUTPUT_NAME" "$INSTALL_DIR/$BACKUP_NAME"
    fi

    # 复制新 AAR
    log_step "安装新 AAR..."
    cp "$OUTPUT_DIR/$OUTPUT_NAME" "$INSTALL_DIR/"

    # 同时复制 sources jar 如果存在
    if [ -f "$OUTPUT_DIR/hiddify-core-sources.jar" ]; then
        cp "$OUTPUT_DIR/hiddify-core-sources.jar" "$INSTALL_DIR/"
        log_info "已复制 sources.jar"
    fi

    # 验证安装
    if [ -f "$INSTALL_DIR/$OUTPUT_NAME" ]; then
        local NEW_SIZE=$(du -sh "$INSTALL_DIR/$OUTPUT_NAME" | cut -f1)
        log_info "安装成功: $INSTALL_DIR/$OUTPUT_NAME"
        log_info "新 AAR 大小: $NEW_SIZE"

        # 显示对比
        local LATEST_BACKUP=$(ls -t "$INSTALL_DIR"/*.backup.* 2>/dev/null | head -1)
        if [ -n "$LATEST_BACKUP" ] && [ -f "$LATEST_BACKUP" ]; then
            local OLD_SIZE=$(du -sh "$LATEST_BACKUP" | cut -f1)
            log_info "旧 AAR 大小: $OLD_SIZE"
        fi
    else
        log_error "安装失败"
        exit 1
    fi
}

cleanup_backups() {
    log_step "清理旧备份 (保留最近3个)..."

    cd "$INSTALL_DIR" 2>/dev/null || return
    local BACKUPS=($(ls -t *.backup.* 2>/dev/null))
    local COUNT=${#BACKUPS[@]}

    if [ "$COUNT" -gt 3 ]; then
        for ((i=3; i<COUNT; i++)); do
            rm -f "${BACKUPS[$i]}"
            log_info "删除旧备份: ${BACKUPS[$i]}"
        done
    fi
}

print_summary() {
    local END_TIME=$(date +%s)
    local DURATION=$((END_TIME - START_TIME))
    local MINUTES=$((DURATION / 60))
    local SECONDS=$((DURATION % 60))

    log_title "构建完成"

    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                        构建摘要                               ║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}  内核版本:    HiddifyCore 4.1.0"
    echo -e "${GREEN}║${NC}  目标平台:    Android (API $ANDROID_API)"
    echo -e "${GREEN}║${NC}  混淆模式:    garble $GARBLE_FLAGS (本地工具链)"
    echo -e "${GREEN}║${NC}  工具目录:    $LOCAL_TOOLS_DIR"
    echo -e "${GREEN}║${NC}  构建标签:    $BUILD_TAGS"
    echo -e "${GREEN}║${NC}  输出位置:    $INSTALL_DIR/$OUTPUT_NAME"
    echo -e "${GREEN}║${NC}  AAR 大小:    $(du -sh "$INSTALL_DIR/$OUTPUT_NAME" 2>/dev/null | cut -f1 || echo "N/A")"
    echo -e "${GREEN}║${NC}  构建耗时:    ${MINUTES}分${SECONDS}秒"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}下一步:${NC}"
    echo "  1. 运行 flutter clean && flutter pub get"
    echo "  2. 运行 flutter build appbundle 或 flutter run 测试"
    echo ""
}

show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --build-only    仅构建，不安装到项目"
    echo "  --skip-verify   跳过混淆验证步骤"
    echo "  --clean-tools   强制重新编译所有本地工具 (garble/gomobile/gobind)"
    echo "  --help, -h      显示此帮助信息"
    echo ""
    echo "环境变量:"
    echo "  ANDROID_HOME      Android SDK 路径 (默认: ~/Library/Android/sdk)"
    echo "  ANDROID_NDK_HOME  Android NDK 路径 (默认: 自动检测)"
    echo ""
    echo "示例:"
    echo "  $0                    # 完整构建并安装"
    echo "  $0 --build-only       # 仅构建到 bin 目录"
    echo "  $0 --clean-tools      # 清除工具缓存后重新构建"
    echo ""
}

#===============================================================================
# 主流程
#===============================================================================

main() {
    local BUILD_ONLY=false
    local SKIP_VERIFY=false

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --build-only)
                BUILD_ONLY=true
                shift
                ;;
            --skip-verify)
                SKIP_VERIFY=true
                shift
                ;;
            --clean-tools)
                log_step "清除本地工具缓存..."
                rm -rf "$LOCAL_TOOLS_DIR"
                log_info "已清除: $LOCAL_TOOLS_DIR"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done

    print_banner

    # 1. 环境检查
    check_environment

    # 2. 准备构建
    prepare_build

    # 3. 构建 AAR
    build_aar

    # 4. 验证混淆
    if [ "$SKIP_VERIFY" = false ]; then
        verify_obfuscation
    fi

    # 5. 安装到项目
    if [ "$BUILD_ONLY" = false ]; then
        install_aar
        cleanup_backups
    else
        log_info "仅构建模式，AAR 位于: $OUTPUT_DIR/$OUTPUT_NAME"
    fi

    # 6. 打印摘要
    print_summary
}

# 执行主流程
main "$@"
