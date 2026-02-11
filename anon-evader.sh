#!/bin/bash
# ANON-EVADER v1.0 - Standalone Anonymization Tool
# Extracted from killchain-hub anonymization logic

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
ANON_USER="anon"
LOG_FILE="/tmp/anon-evader.log"
BACKUP_DIR="/tmp/anon-backups"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2
}

# Silent command execution
silent() {
    "$@" >/dev/null 2>&1
}

# Check if running as root when needed
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This operation requires root privileges"
        return 1
    fi
}

# Install required packages
install_dependencies() {
    log_info "Installing dependencies..."
    
    # Check package manager
    if command -v apt >/dev/null 2>&1; then
        PKG_CMD="apt"
        PKG_UPDATE="apt update"
        PKG_INSTALL="apt install -y"
    elif command -v yum >/dev/null 2>&1; then
        PKG_CMD="yum"
        PKG_UPDATE="yum check-update"
        PKG_INSTALL="yum install -y"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_CMD="pacman"
        PKG_UPDATE="pacman -Sy"
        PKG_INSTALL="pacman -S --noconfirm"
    else
        log_error "No supported package manager found"
        return 1
    fi
    
    # Update package list
    silent $PKG_UPDATE
    
    # Install required packages
    $PKG_INSTALL tor torsocks proxychains4 curl net-tools iproute2
    
    log_success "Dependencies installed"
}

# Create anonymized user
create_anon_user() {
    if ! id "$ANON_USER" >/dev/null 2>&1; then
        log_info "Creating anonymized user: $ANON_USER"
        check_root || return 1
        
        useradd -m -s /bin/bash "$ANON_USER"
        usermod -aG sudo,docker "$ANON_USER" 2>/dev/null || true
        echo "$ANON_USER ALL=(ALL) NOPASSWD:ALL" | tee "/etc/sudoers.d/$ANON_USER"
        chmod 440 "/etc/sudoers.d/$ANON_USER"
        
        log_success "Created user: $ANON_USER"
    else
        log_info "User $ANON_USER already exists"
    fi
}

# Setup Tor configuration
setup_tor() {
    log_info "Setting up Tor configuration..."
    
    # Enable and start Tor service
    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable tor
        systemctl start tor
    elif command -v service >/dev/null 2>&1; then
        service tor start
    else
        tor &
    fi
    
    # Wait for Tor to start
    sleep 3
    
    # Check if Tor is listening
    if ss -tlnp 2>/dev/null | grep -q 9050 || netstat -tlnp 2>/dev/null | grep -q 9050; then
        log_success "Tor is running on port 9050"
    else
        log_error "Tor failed to start"
        return 1
    fi
}

# Setup proxychains configuration
setup_proxychains() {
    log_info "Configuring proxychains..."
    
    local proxychains_conf="/etc/proxychains4.conf"
    if [[ ! -f "$proxychains_conf" ]]; then
        proxychains_conf="/etc/proxychains.conf"
    fi
    
    # Backup original config
    [[ -f "$proxychains_conf" ]] && cp "$proxychains_conf" "$proxychains_conf.backup"
    
    # Create new configuration
    cat > "$proxychains_conf" << 'EOF'
# Proxychains configuration for anonymity
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
[ProxyList]
socks5  127.0.0.1 9050
EOF
    
    log_success "Proxychains configured"
}

# Prevent DNS leaks
prevent_dns_leaks() {
    log_info "Preventing DNS leaks..."
    
    # Remove immutable flag if present (requires root)
    chattr -i /etc/resolv.conf 2>/dev/null || true
    
    # Backup current resolv.conf
    # If it's a symlink, we want to backup the link itself or its content? 
    # Usually better to backup the content if we're replacing it.
    if [[ -L /etc/resolv.conf ]]; then
        log_warning "/etc/resolv.conf is a symlink, replacing with regular file"
        cp -L /etc/resolv.conf "$BACKUP_DIR/resolv.conf.backup"
        rm /etc/resolv.conf
    elif [[ -f /etc/resolv.conf ]]; then
        cp /etc/resolv.conf "$BACKUP_DIR/resolv.conf.backup"
    fi
    
    # Set DNS to localhost (Tor)
    cat > /etc/resolv.conf << 'EOF'
nameserver 127.0.0.1
options timeout:1 attempts:3 rotate
EOF
    
    # Make resolv.conf immutable (requires root)
    chattr +i /etc/resolv.conf 2>/dev/null || log_warning "Could not make resolv.conf immutable"
    
    log_success "DNS leak prevention enabled"
}

# Disable IPv6 to prevent leaks
disable_ipv6() {
    log_info "Disabling IPv6 to prevent leaks..."
    
    # Set sysctl parameters
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null
    
    # Make persistent
    cat >> /etc/sysctl.conf << 'EOF'

# IPv6 disabled for anonymity
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
    
    log_success "IPv6 disabled"
}

# Test anonymity
test_anonymity() {
    log_info "Testing anonymity..."
    
    # Get real IP
    local real_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "N/A")
    echo "Real IP: $real_ip"
    
    # Test through proxychains
    local tor_ip=$(proxychains4 curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "N/A")
    echo "Tor IP:  $tor_ip"
    
    # Test through torsocks
    local torsocks_ip=$(torsocks curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "N/A")
    echo "Torsocks IP: $torsocks_ip"
    
    if [[ "$real_ip" != "$tor_ip" ]] && [[ "$real_ip" != "$torsocks_ip" ]]; then
        log_success "Anonymity test passed - IPs are different"
    else
        log_warning "Anonymity test failed - IPs may be the same"
    fi
}

# Setup environment for anonymized user
setup_anon_environment() {
    log_info "Setting up environment for $ANON_USER user..."
    
    # Create home directory structure
    mkdir -p "/home/$ANON_USER"/{tmp,logs,workspace}
    chown -R "$ANON_USER:$ANON_USER" "/home/$ANON_USER"
    
    # Setup bashrc for anon user
    cat >> "/home/$ANON_USER/.bashrc" << 'EOF'

# Anonymization environment
export HISTSIZE=0
export HISTFILESIZE=0
unset HISTFILE

# Aliases for anonymized commands
alias curl='proxychains4 curl'
alias wget='proxychains4 wget'
alias nmap='proxychains4 nmap'
alias curl-tor='torsocks curl'
alias wget-tor='torsocks wget'
alias nmap-tor='torsocks nmap'

# Prompt
export PS1='\[\033[01;31m\]anon@\[\033[01;36m\]pentest-lab\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
EOF
    
    log_success "Environment configured for $ANON_USER"
}

# Switch to anonymized user
switch_to_anon() {
    log_info "Switching to anonymized user..."
    
    # Change hostname
    hostnamectl set-hostname pentest-lab 2>/dev/null || true
    
    echo -e "${GREEN}=== SWITCHING TO ANON MODE ===${NC}"
    echo -e "From: ${YELLOW}$(whoami)@$(hostname)${NC}"
    echo -e "To:   ${CYAN}$ANON_USER@pentest-lab${NC}"
    echo ""
    
    # Clear current history
    history -c 2>/dev/null || true
    unset HISTFILE HISTFILESIZE HISTSIZE 2>/dev/null || true
    
    # Switch user
    exec sudo -u "$ANON_USER" /bin/bash -l
}

# Restore normal configuration
restore_normal() {
    log_info "Restoring normal configuration..."
    
    # Remove immutable flag if present
    chattr -i /etc/resolv.conf 2>/dev/null || true
    
    # Restore resolv.conf
    if [[ -f "$BACKUP_DIR/resolv.conf.backup" ]]; then
        cp "$BACKUP_DIR/resolv.conf.backup" /etc/resolv.conf
        log_success "DNS configuration restored"
    else
        log_warning "No DNS backup found to restore"
    fi
    
    # Re-enable IPv6
    sed -i '/# IPv6 disabled for anonymity/,$d' /etc/sysctl.conf
    sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null 2>/dev/null || true
    sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null 2>/dev/null || true
    
    log_success "Normal configuration restored"
}

# Show status
show_status() {
    echo -e "${CYAN}=== ANONYMITY STATUS ===${NC}"
    echo ""
    
    # Current user
    echo "Current user: $(whoami)@$(hostname)"
    
    # Tor status
    if pgrep -x tor >/dev/null; then
        echo -e "Tor service: ${GREEN}Running${NC}"
    else
        echo -e "Tor service: ${RED}Not running${NC}"
    fi
    
    # Proxy check
    echo ""
    echo "Testing connectivity:"
    
    # Real IP
    local real_ip=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "Failed")
    echo "Real IP: $real_ip"
    
    # Tor IP
    if command -v proxychains4 >/dev/null 2>&1; then
        local tor_ip=$(proxychains4 curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "Failed")
        echo "Tor IP:  $tor_ip"
    fi
    
    # DNS check
    local dns_server=$(grep nameserver /etc/resolv.conf 2>/dev/null | head -n1 | awk '{print $2}')
    if [[ "$dns_server" == "127.0.0.1" ]]; then
        echo -e "DNS: ${GREEN}Anonymized${NC} ($dns_server)"
    else
        echo -e "DNS: ${RED}Not anonymized${NC} ($dns_server)"
    fi
    
    # IPv6 check
    local ipv6_status=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo "unknown")
    if [[ "$ipv6_status" == "1" ]]; then
        echo -e "IPv6: ${GREEN}Disabled${NC}"
    else
        echo -e "IPv6: ${RED}Enabled${NC} (leak risk)"
    fi
    
    echo ""
}

# Main menu
show_menu() {
    echo -e "${CYAN}"
    echo "     \\ /"
    echo "     oVo"
    echo " \\___XXX___/"
    echo "  __XXXXX__"
    echo " /__XXXXX__\\"
    echo " /   XXX   \\"
    echo "      V"
    echo -e "${NC}"
    echo -e "${GREEN}=== ANON-EVADER v1.0 ===${NC}"
    echo -e "${YELLOW}Standalone Anonymization Tool${NC}"
    echo ""
    echo "1) Full Setup (Dependencies + User + Tor + Configuration)"
    echo "2) Quick Anonymize (Assume dependencies installed)"
    echo "3) Switch to Anon User"
    echo "4) Test Anonymity"
    echo "5) Show Status"
    echo "6) Restore Normal Configuration"
    echo "7) Exit"
    echo ""
}

# Main function
main() {
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Check if already anon user
    if [[ "$(whoami)" == "$ANON_USER" ]]; then
        echo -e "${YELLOW}Already running as $ANON_USER user${NC}"
        echo "Aliases available: curl, wget, nmap, curl-tor, wget-tor, nmap-tor"
        echo "Type 'exit' to return to normal user"
        exec /bin/bash
    fi
    
    while true; do
        show_menu
        read -p "Select option [1-7]: " choice
        
        case $choice in
            1)
                log_info "Starting full setup..."
                install_dependencies
                create_anon_user
                setup_tor
                setup_proxychains
                prevent_dns_leaks
                disable_ipv6
                setup_anon_environment
                log_success "Full setup completed"
                ;;
            2)
                log_info "Starting quick anonymize..."
                setup_tor
                setup_proxychains
                prevent_dns_leaks
                disable_ipv6
                setup_anon_environment
                log_success "Quick anonymize completed"
                ;;
            3)
                switch_to_anon
                ;;
            4)
                test_anonymity
                ;;
            5)
                show_status
                ;;
            6)
                restore_normal
                ;;
            7)
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid option"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
        clear
    done
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi