#!/bin/bash
# PROXY-RUNNER v1.0 - Quick anonymized command execution
# Companion to anon-evader.sh

set -euo pipefail

# Ensure script is run with bash
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script must be run with bash, not sh." >&2
    echo "Try: bash $0" >&2
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
LOG_FILE="/tmp/proxy-runner.log"

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2
}

# Show usage
show_usage() {
    cat << EOF
PROXY-RUNNER v1.0 - Quick anonymized command execution

Usage: $0 [OPTIONS] COMMAND

OPTIONS:
    -p, --proxy METHOD     Proxy method (proxychains, torsocks, direct)
    -t, --test             Test proxy connectivity before running
    -v, --verbose          Show detailed output
    -h, --help             Show this help

PROXY METHODS:
    proxychains    Use proxychains4 (default)
    torsocks        Use torsocks
    direct          Run without proxy (not recommended)

EXAMPLES:
    $0 curl -s ifconfig.me
    $0 -p torsocks nmap -sS target.com
    $0 -t wget http://example.com
    
EOF
}

# Test connectivity
test_connectivity() {
    local method=${1:-proxychains}
    
    echo -e "${CYAN}Testing connectivity with $method...${NC}"
    
    case $method in
        proxychains)
            if command -v proxychains4 >/dev/null 2>&1; then
                if proxychains4 curl -s --max-time 5 ifconfig.me >/dev/null 2>&1; then
                    echo -e "${GREEN}✓ proxychains working${NC}"
                    return 0
                fi
            else
                echo -e "${RED}✗ proxychains4 not found${NC}"
                return 1
            fi
            ;;
        torsocks)
            if command -v torsocks >/dev/null 2>&1; then
                if torsocks curl -s --max-time 5 ifconfig.me >/dev/null 2>&1; then
                    echo -e "${GREEN}✓ torsocks working${NC}"
                    return 0
                fi
            else
                echo -e "${RED}✗ torsocks not found${NC}"
                return 1
            fi
            ;;
        direct)
            if curl -s --max-time 5 ifconfig.me >/dev/null 2>&1; then
                echo -e "${GREEN}✓ direct connection working${NC}"
                return 0
            fi
            ;;
    esac
    
    echo -e "${RED}✗ Connectivity test failed${NC}"
    return 1
}

# Get proxy command
get_proxy_cmd() {
    local method=$1
    
    case $method in
        proxychains)
            if command -v proxychains4 >/dev/null 2>&1; then
                echo "proxychains4"
            elif command -v proxychains >/dev/null 2>&1; then
                echo "proxychains"
            else
                log_error "proxychains not found"
                return 1
            fi
            ;;
        torsocks)
            if command -v torsocks >/dev/null 2>&1; then
                echo "torsocks"
            else
                log_error "torsocks not found"
                return 1
            fi
            ;;
        direct)
            echo ""
            ;;
        *)
            log_error "Unknown proxy method: $method"
            return 1
            ;;
    esac
}

# Main execution
main() {
    local proxy_method="proxychains"
    local test_mode=false
    local verbose=false
    local command_args=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--proxy)
                proxy_method="$2"
                shift 2
                ;;
            -t|--test)
                test_mode=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                command_args+=("$1")
                shift
                ;;
        esac
    done
    
    # Test mode
    if $test_mode; then
        test_connectivity "$proxy_method"
        exit $?
    fi
    
    # Check if command provided
    if [[ ${#command_args[@]} -eq 0 ]]; then
        log_error "No command provided"
        show_usage
        exit 1
    fi
    
    # Get proxy command
    local proxy_cmd=$(get_proxy_cmd "$proxy_method")
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    
    # Show info
    if $verbose; then
        echo -e "${CYAN}Running: ${NC}${command_args[*]}"
        if [[ -n "$proxy_cmd" ]]; then
            echo -e "${CYAN}Proxy: ${NC}$proxy_cmd"
        else
            echo -e "${YELLOW}Warning: Running without proxy${NC}"
        fi
        echo -e "${CYAN}Real IP: ${NC}$(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo 'Unknown')"
        
        if [[ -n "$proxy_cmd" ]]; then
            echo -e "${CYAN}Proxy IP: ${NC}$($proxy_cmd curl -s --max-time 3 ifconfig.me 2>/dev/null || echo 'Unknown')"
        fi
        echo ""
    fi
    
    # Execute command
    if [[ -n "$proxy_cmd" ]]; then
        log_info "Executing through $proxy_cmd: ${command_args[*]}"
        $proxy_cmd "${command_args[@]}"
    else
        log_info "Executing directly: ${command_args[*]}"
        "${command_args[@]}"
    fi
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}Command completed successfully${NC}"
    else
        echo -e "${RED}Command failed with exit code $exit_code${NC}"
    fi
    
    exit $exit_code
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi