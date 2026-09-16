#!/bin/bash
#===============================================================================
# HiddifyCore 4.1.0 iOS 混淆构建脚本
# 使用 garble + gomobile 构建深度混淆的 iOS xcframework
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
OUTPUT_NAME="HiddifyCore.xcframework"
INSTALL_DIR="$PROJECT_ROOT/ios/Frameworks"

# 本地工具目录 - 编译到用户缓存目录，避免 macOS 对项目目录内二进制的安全策略限制 (SIGKILL)
LOCAL_TOOLS_DIR="${HOME}/.cache/hiddify-build/tools"
GARBLE_BIN="$LOCAL_TOOLS_DIR/garble"
GOMOBILE_BIN="$LOCAL_TOOLS_DIR/gomobile"
GOBIND_BIN="$LOCAL_TOOLS_DIR/gobind"

# 构建标签 - 与 Makefile 中的 ios 目标一致
BASE_TAGS="with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api,with_grpc,with_awg,tfogo_checklinkname0,with_naive_outbound,with_conntrack"
IOS_ADD_TAGS="with_dhcp,with_low_memory,with_purego"
BUILD_TAGS="${BASE_TAGS},${IOS_ADD_TAGS}"

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
    echo "║   HiddifyCore 4.1.0 iOS 混淆构建脚本 (Garble + Gomobile)      ║"
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
        log_error "请确保项目根目录下有 garble/ 目录 (含 Go 1.25 补丁的 starlancer1/garble fork)"
        exit 1
    fi
    
    if [ ! -f "$GARBLE_BIN" ] || [ "$GARBLE_SRC/main.go" -nt "$GARBLE_BIN" ] || [ "$GARBLE_SRC/go_std_tables.go" -nt "$GARBLE_BIN" ]; then
        log_step "编译 garble → bin/tools/garble"
        # 验证关键补丁
        if ! grep -q 'go1.25' "$GARBLE_SRC/go_std_tables.go" 2>/dev/null; then
            log_warn "go_std_tables.go 中未检测到 Go 1.25 条目，可能不兼容当前 Go 版本"
        fi
        if ! grep -q 'go1.26' "$GARBLE_SRC/main.go" 2>/dev/null; then
            log_warn "main.go 中 unsupportedGo 可能未调整，检查版本兼容性"
        fi
        (cd "$GARBLE_SRC" && go build -o "$GARBLE_BIN" . 2>&1)
        log_info "garble 编译完成"
    else
        log_info "garble 已是最新，跳过编译"
    fi
    
    # ── 2. gomobile (从 go module cache 编译) ──
    if [ ! -f "$GOMOBILE_BIN" ]; then
        log_step "编译 gomobile → bin/tools/gomobile"
        GOBIN="$LOCAL_TOOLS_DIR" go install github.com/sagernet/gomobile/cmd/gomobile@v0.1.11 2>&1
        log_info "gomobile 编译完成"
    else
        log_info "gomobile 已存在，跳过编译"
    fi
    
    # ── 3. gobind (从 go module cache 编译) ──
    if [ ! -f "$GOBIND_BIN" ]; then
        log_step "编译 gobind → bin/tools/gobind"
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
        log_error "Go 未安装"
        exit 1
    fi
    GO_VERSION=$(go version | awk '{print $3}')
    log_info "Go: $GO_VERSION"
    
    # 设置 GOPATH (仅用于 go module cache，工具链不依赖它)
    if [ -z "$GOPATH" ]; then
        export GOPATH="$HOME/go"
    fi
    
    # 检查 Xcode
    if ! check_command xcodebuild; then
        log_error "Xcode 未安装"
        exit 1
    fi
    XCODE_VERSION=$(xcodebuild -version | head -1)
    log_info "Xcode: $XCODE_VERSION"
    
    # 编译并安装所有工具到项目本地 bin/tools/
    install_local_tools
}

prepare_build() {
    log_title "准备构建"
    
    cd "$SCRIPT_DIR"
    
    # 自动检测本地代理 (127.0.0.1:12334)
    if [ -z "$HTTP_PROXY" ] && [ -z "$http_proxy" ]; then
        if curl -s --connect-timeout 2 -x http://127.0.0.1:12334 https://proxy.golang.org -o /dev/null 2>/dev/null; then
            export HTTP_PROXY="http://127.0.0.1:12334"
            export HTTPS_PROXY="http://127.0.0.1:12334"
            log_info "自动检测到本地代理: $HTTP_PROXY"
        fi
    elif [ -n "$HTTP_PROXY" ]; then
        log_info "使用环境代理: $HTTP_PROXY"
    fi
    
    # 清理旧构建
    log_step "清理旧构建产物..."
    rm -rf "$OUTPUT_DIR/$OUTPUT_NAME"
    rm -rf build/
    
    # 下载依赖
    log_step "下载 Go 依赖..."
    export GOFLAGS=""
    export GOSUMDB="sum.golang.google.cn"
    export GOPROXY="https://goproxy.cn,direct"
    go mod download 2>&1 | head -5 || true
    go mod tidy 2>&1 | head -5 || true
    
    log_info "依赖准备完成"
}

build_framework() {
    log_title "构建混淆版 iOS Framework"
    
    cd "$SCRIPT_DIR"
    mkdir -p "$OUTPUT_DIR"
    
    log_step "使用 garble mobile bind 构建..."
    log_info "混淆参数: $GARBLE_FLAGS"
    log_info "构建标签: $BUILD_TAGS"
    log_info "输出目录: $OUTPUT_DIR/$OUTPUT_NAME"
    
    echo ""
    log_warn "构建可能需要 20-40 分钟，请耐心等待..."
    echo ""
    
    # 设置环境变量
    export CGO_ENABLED=1
    export GOFLAGS=""
    export GOSUMDB="sum.golang.google.cn"
    export GOPROXY="https://goproxy.cn,direct"
    
    # 设置 GOGARBLE 环境变量来控制混淆范围
    # 重要: 只混淆 hiddify 自己的包！
    # 第三方包 (ebitengine/purego, klauspost/compress 等) 包含 ARM64 汇编文件 (.s)
    # 如果 garble 尝试混淆这些汇编，会导致寄存器名被破坏 (R9 等)
    # golang.org/x/sys/unix 包含类型转换代码也不能被混淆
    export GOGARBLE="github.com/hiddify/*"
    
    # 显示混淆范围
    log_info "混淆范围: github.com/hiddify/* (自有代码)"
    log_info "第三方包全部排除，避免汇编/cgo/linkname 兼容性问题"
    
    # 使用 garble mobile bind 构建
    # 只针对 iOS arm64，跳过模拟器以加速构建
    "$GARBLE_BIN" $GARBLE_FLAGS mobile bind \
        -target=ios/arm64,macos \
        -libname=hiddify-core \
        -tags="$BUILD_TAGS" \
        -trimpath \
        -ldflags="$LDFLAGS" \
        -o "$OUTPUT_DIR/$OUTPUT_NAME" \
        github.com/sagernet/sing-box/experimental/libbox \
        ./platform/mobile 2>&1 | while IFS= read -r line; do
            # 过滤掉重复的包名输出，只显示关键信息
            if [[ "$line" == *"write "* ]] || [[ "$line" == *"xcframework"* ]] || [[ "$line" == *"error"* ]] || [[ "$line" == *"Error"* ]]; then
                echo "$line"
            elif [[ ! "$line" =~ ^github\.com/ ]] && [[ ! "$line" =~ ^golang\.org/ ]] && [[ ! "$line" =~ ^internal/ ]] && [[ ! "$line" =~ ^vendor/ ]]; then
                echo "$line"
            fi
        done
    
    # 检查构建结果
    if [ ! -d "$OUTPUT_DIR/$OUTPUT_NAME" ]; then
        log_error "构建失败: 未生成 xcframework"
        exit 1
    fi
    
    # 复制 Info.plist
    if [ -f "$SCRIPT_DIR/Info.plist" ]; then
        cp "$SCRIPT_DIR/Info.plist" "$OUTPUT_DIR/$OUTPUT_NAME/"
        log_info "已复制 Info.plist"
    fi
    
    log_info "构建成功!"
}

verify_obfuscation() {
    log_title "验证混淆效果"
    
    local BINARY="$OUTPUT_DIR/$OUTPUT_NAME/ios-arm64/HiddifyCore.framework/HiddifyCore"
    
    if [ ! -f "$BINARY" ]; then
        # 尝试其他可能的路径
        BINARY=$(find "$OUTPUT_DIR/$OUTPUT_NAME" -name "HiddifyCore" -type f 2>/dev/null | head -1)
    fi
    
    if [ -z "$BINARY" ] || [ ! -f "$BINARY" ]; then
        log_warn "找不到二进制文件，跳过验证"
        return
    fi
    
    # 检查包路径
    log_step "检查包路径泄露..."
    local PKG_COUNT=$(strings "$BINARY" 2>/dev/null | grep -cE "^github\.com/|^golang\.org/" || echo "0")
    if [ "$PKG_COUNT" -eq 0 ]; then
        log_info "✓ 包路径: 已完全隐藏"
    else
        log_warn "包路径泄露: $PKG_COUNT 处"
    fi
    
    # 检查敏感关键词
    log_step "检查敏感关键词..."
    local SENSITIVE_COUNT=$(strings "$BINARY" 2>/dev/null | grep -ciE "hiddify|sagernet|sing-box" || echo "0")
    if [ "$SENSITIVE_COUNT" -lt 5 ]; then
        log_info "✓ 敏感关键词: 基本隐藏 ($SENSITIVE_COUNT 处)"
    else
        log_warn "敏感关键词: $SENSITIVE_COUNT 处"
    fi
    
    # 框架大小
    local SIZE=$(du -sh "$OUTPUT_DIR/$OUTPUT_NAME" | cut -f1)
    log_info "框架大小: $SIZE"
}

install_framework() {
    log_title "安装到项目"
    
    # 确保目标目录存在
    mkdir -p "$INSTALL_DIR"
    
    # 备份旧框架
    if [ -d "$INSTALL_DIR/$OUTPUT_NAME" ]; then
        local BACKUP_NAME="${OUTPUT_NAME}.backup.$(date +%Y%m%d_%H%M%S)"
        log_step "备份旧框架: $BACKUP_NAME"
        mv "$INSTALL_DIR/$OUTPUT_NAME" "$INSTALL_DIR/$BACKUP_NAME"
    fi
    
    # 复制新框架
    log_step "安装新框架..."
    cp -R "$OUTPUT_DIR/$OUTPUT_NAME" "$INSTALL_DIR/"
    
    # 验证安装
    if [ -d "$INSTALL_DIR/$OUTPUT_NAME" ]; then
        log_info "安装成功: $INSTALL_DIR/$OUTPUT_NAME"
        
        # 显示大小对比
        local NEW_SIZE=$(du -sh "$INSTALL_DIR/$OUTPUT_NAME" | cut -f1)
        log_info "新框架大小: $NEW_SIZE"
        
        # 如果存在备份，显示对比
        local LATEST_BACKUP=$(ls -td "$INSTALL_DIR"/*.backup.* 2>/dev/null | head -1)
        if [ -n "$LATEST_BACKUP" ] && [ -d "$LATEST_BACKUP" ]; then
            local OLD_SIZE=$(du -sh "$LATEST_BACKUP" | cut -f1)
            log_info "旧框架大小: $OLD_SIZE"
        fi
    else
        log_error "安装失败"
        exit 1
    fi
}

cleanup_backups() {
    log_step "清理旧备份 (保留最近3个)..."
    
    cd "$INSTALL_DIR" 2>/dev/null || return
    local BACKUPS=($(ls -td *.backup.* 2>/dev/null))
    local COUNT=${#BACKUPS[@]}
    
    if [ "$COUNT" -gt 3 ]; then
        for ((i=3; i<COUNT; i++)); do
            rm -rf "${BACKUPS[$i]}"
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
    echo -e "${GREEN}║${NC}  混淆模式:    garble $GARBLE_FLAGS (本地工具链)"
    echo -e "${GREEN}║${NC}  工具目录:    $LOCAL_TOOLS_DIR"
    echo -e "${GREEN}║${NC}  构建标签:    $BUILD_TAGS"
    echo -e "${GREEN}║${NC}  输出位置:    $INSTALL_DIR/$OUTPUT_NAME"
    echo -e "${GREEN}║${NC}  框架大小:    $(du -sh "$INSTALL_DIR/$OUTPUT_NAME" 2>/dev/null | cut -f1 || echo "N/A")"
    echo -e "${GREEN}║${NC}  构建耗时:    ${MINUTES}分${SECONDS}秒"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}下一步:${NC}"
    echo "  1. 在 Xcode 中重新构建项目"
    echo "  2. 运行 flutter clean && flutter pub get"
    echo "  3. 运行 flutter run 测试"
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
    
    # 3. 构建框架
    build_framework
    
    # 4. 验证混淆
    if [ "$SKIP_VERIFY" = false ]; then
        verify_obfuscation
    fi
    
    # 5. 安装到项目
    if [ "$BUILD_ONLY" = false ]; then
        install_framework
        cleanup_backups
    else
        log_info "仅构建模式，框架位于: $OUTPUT_DIR/$OUTPUT_NAME"
    fi
    
    # 6. 打印摘要
    print_summary
}

# 执行主流程
main "$@"
