#!/bin/bash
# ANON-STATUS v1.0 - Anonymization status checker
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

# Status check functions
check_tor() {
    if pgrep -x tor >/dev/null 2>&1; then
        echo -e "Tor Service: ${GREEN}Running${NC} (PID: $(pgrep -x tor))"
        
        # Check if port is listening
        if ss -tlnp 2>/dev/null | grep -q 9050 || netstat -tlnp 2>/dev/null | grep -q 9050; then
            echo -e "Tor SOCKS Port: ${GREEN}9050 listening${NC}"
        else
            echo -e "Tor SOCKS Port: ${RED}9050 not listening${NC}"
        fi
    else
        echo -e "Tor Service: ${RED}Not running${NC}"
        echo -e "Tor SOCKS Port: ${RED}9050 not listening${NC}"
    fi
}

check_proxy_tools() {
    echo "Proxy Tools:"
    
    if command -v proxychains4 >/dev/null 2>&1; then
        echo -e "  proxychains4: ${GREEN}Available${NC}"
    elif command -v proxychains >/dev/null 2>&1; then
        echo -e "  proxychains: ${GREEN}Available${NC}"
    else
        echo -e "  proxychains: ${RED}Not found${NC}"
    fi
    
    if command -v torsocks >/dev/null 2>&1; then
        echo -e "  torsocks: ${GREEN}Available${NC}"
    else
        echo -e "  torsocks: ${RED}Not found${NC}"
    fi
}

check_dns() {
    local dns_server=$(grep nameserver /etc/resolv.conf 2>/dev/null | head -n1 | awk '{print $2}' || echo "unknown")
    
    if [[ "$dns_server" == "127.0.0.1" ]]; then
        echo -e "DNS Configuration: ${GREEN}Anonymized${NC} ($dns_server)"
    else
        echo -e "DNS Configuration: ${RED}Not anonymized${NC} ($dns_server)"
    fi
}

check_ipv6() {
    local ipv6_status=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo "unknown")
    
    case $ipv6_status in
        1)
            echo -e "IPv6: ${GREEN}Disabled${NC} (leak prevented)"
            ;;
        0)
            echo -e "IPv6: ${RED}Enabled${NC} (leak risk)"
            if ip -6 addr show >/dev/null 2>&1 && ip -6 addr show | grep -q "inet6"; then
                local ipv6_addr=$(ip -6 addr show | grep "inet6" | grep -v "::1" | head -n1 | awk '{print $2}' || echo "none")
                echo -e "  IPv6 Address: $ipv6_addr"
            fi
            ;;
        *)
            echo -e "IPv6: ${YELLOW}Unknown status${NC}"
            ;;
    esac
}

check_connectivity() {
    echo "Connectivity Test:"
    
    # Test direct connection
    echo -n "  Direct connection: "
    if timeout 5 curl -s ifconfig.me >/dev/null 2>&1; then
        local direct_ip=$(timeout 5 curl -s ifconfig.me 2>/dev/null || echo "failed")
        echo -e "${GREEN}Working${NC} (IP: $direct_ip)"
    else
        echo -e "${RED}Failed${NC}"
    fi
    
    # Test proxychains
    if command -v proxychains4 >/dev/null 2>&1; then
        echo -n "  Proxychains: "
        if timeout 10 proxychains4 curl -s ifconfig.me >/dev/null 2>&1; then
            local proxy_ip=$(timeout 10 proxychains4 curl -s ifconfig.me 2>/dev/null || echo "failed")
            echo -e "${GREEN}Working${NC} (IP: $proxy_ip)"
        else
            echo -e "${RED}Failed${NC}"
        fi
    fi
    
    # Test torsocks
    if command -v torsocks >/dev/null 2>&1; then
        echo -n "  Torsocks: "
        if timeout 10 torsocks curl -s ifconfig.me >/dev/null 2>&1; then
            local torsocks_ip=$(timeout 10 torsocks curl -s ifconfig.me 2>/dev/null || echo "failed")
            echo -e "${GREEN}Working${NC} (IP: $torsocks_ip)"
        else
            echo -e "${RED}Failed${NC}"
        fi
    fi
}

check_user() {
    local current_user=$(whoami)
    local current_host=$(hostname)
    
    echo "Current User: $current_user@$current_host"
    
    if [[ "$current_user" == "anon" ]]; then
        echo -e "User Mode: ${GREEN}Anonymized${NC}"
    else
        echo -e "User Mode: ${YELLOW}Normal${NC} (consider switching to 'anon' user)"
    fi
    
    # Check if anon user exists
    if id anon >/dev/null 2>&1; then
        echo -e "Anon User: ${GREEN}Exists${NC}"
    else
        echo -e "Anon User: ${RED}Does not exist${NC}"
    fi
}

check_processes() {
    echo "Background Processes:"
    
    # Check for potential privacy-leaking processes
    local problematic_processes=("avahi-daemon" "cups" "bluetoothd" "NetworkManager")
    
    for proc in "${problematic_processes[@]}"; do
        if pgrep -x "$proc" >/dev/null 2>&1; then
            echo -e "  $proc: ${YELLOW}Running${NC} (potential leak)"
        else
            echo -e "  $proc: ${GREEN}Not running${NC}"
        fi
    done
}

main() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════╗"
    echo "║         ANON-STATUS v1.0              ║"
    echo "║      Anonymization Status Checker      ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    echo -e "${BLUE}=== SYSTEM STATUS ===${NC}"
    check_user
    echo ""
    
    echo -e "${BLUE}=== ANONYMIZATION TOOLS ===${NC}"
    check_tor
    check_proxy_tools
    echo ""
    
    echo -e "${BLUE}=== LEAK PREVENTION ===${NC}"
    check_dns
    check_ipv6
    echo ""
    
    echo -e "${BLUE}=== CONNECTIVITY ===${NC}"
    check_connectivity
    echo ""
    
    echo -e "${BLUE}=== PROCESSES ===${NC}"
    check_processes
    echo ""
    
    echo -e "${CYAN}=== SUMMARY ===${NC}"
    
    # Overall assessment
    local issues=0
    
    if ! pgrep -x tor >/dev/null 2>&1; then
        ((issues++))
    fi
    
    if [[ "$(grep nameserver /etc/resolv.conf 2>/dev/null | head -n1 | awk '{print $2}')" != "127.0.0.1" ]]; then
        ((issues++))
    fi
    
    if [[ "$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo '1')" != "1" ]]; then
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        echo -e "${GREEN}✓ All anonymization checks passed${NC}"
    else
        echo -e "${YELLOW}⚠ $issues issue(s) found - run anon-evader.sh to fix${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Quick commands:${NC}"
    echo "  anon-evader.sh    - Full setup and configuration"
    echo "  proxy-runner.sh   - Run commands through proxy"
    echo "  sudo -u anon bash - Switch to anon user"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi