#!/bin/bash


# main functions
create_directories() {
    log_step "Creating directory structure..."

  
    
    # Clean up any existing deployment
    if [ -d "$BASE_DIR" ]; then
        log_warn "Existing deployment found at $BASE_DIR"
        read -p "Remove and start fresh? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Removing existing deployment..."
            rm -rf "$BASE_DIR"
        else
            log_error "Deployment cancelled. Remove $BASE_DIR manually if needed."
            exit 1
        fi
    fi
    
    mkdir -p "$BASE_DIR"
    chown -R $(whoami):$(whoami) "$BASE_DIR"
    chmod -R 755 "$BASE_DIR"
    mkdir -p "$SCRIPTS_DIR"
    chown -R $(whoami):$(whoami) "$SCRIPTS_DIR"
    chmod -R 755 "$SCRIPTS_DIR"

    cd "$BASE_DIR"
    
    log_info "Directory structure created at $BASE_DIR"
}


download_polygon_edge() {
    log_step "Downloading Polygon Edge Binary v$POLYGON_EDGE_VERSION..."
    
    
    # Detect OS and architecture
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    # Convert architecture to Polygon Edge naming
    if [ "$ARCH" = "x86_64" ]; then
        ARCH="amd64"
    elif [ "$ARCH" = "aarch64" ]; then
        ARCH="arm64"
    fi
    
    BINARY_NAME="polygon-edge_${POLYGON_EDGE_VERSION}_${OS}_${ARCH}.tar.gz"
    DOWNLOAD_URL="https://github.com/0xPolygon/polygon-edge/releases/download/v${POLYGON_EDGE_VERSION}/${BINARY_NAME}"
    
    log_info "Downloading from: $DOWNLOAD_URL"
    curl -sL "$DOWNLOAD_URL" -o polygon-edge.tar.gz
    if [ $? -ne 0 ]; then
        log_error "Failed to download Polygon Edge binary."
        exit 1
    fi
    tar -xzf polygon-edge.tar.gz
    chmod +x polygon-edge
    rm polygon-edge.tar.gz

    log_info "Polygon Edge v$POLYGON_EDGE_VERSION downloaded successfully."
}

pull_docker_images() {
    log_step "Downloading Docker images..."
    
    log_info "Pulling Polygon Edge v$POLYGON_EDGE_VERSION (this may take a few minutes)..."
    if docker pull 0xpolygon/polygon-edge:$POLYGON_EDGE_VERSION &>/dev/null; then
        log_info "Polygon Edge v$POLYGON_EDGE_VERSION image downloaded"
    else
        log_error "Failed to pull Polygon Edge image"
        exit 1
    fi
}

generate_validator_secrets() {
    log_step "Generating validator secrets for $NUM_VALIDATORS nodes..."
        
    for i in $(seq 1 $NUM_VALIDATORS); do
        log_info "Generating secrets for node $i..."
        ./polygon-edge secrets init --data-dir "node-$i" --insecure &>/dev/null
        if [ $? -ne 0 ]; then
            log_error "Failed to generate secrets for node $i"
            exit 1
        fi
        log_info "Secrets generated for node $i"
    done
    
    log_info "All validator secrets generated"
}

collect_validator_info() {
    #collect validator addresses, BLS keys, and node IDs for genesis configuration
    log_step "Collecting validator information..."
    
    
    # Arrays to store validator info
    declare -a VALIDATORS
    declare -a NODE_IDS
    
    for i in $(seq 1 $NUM_VALIDATORS); do
        log_info "Reading validator info for node$i..."
        
        # Get validator address and BLS key
        OUTPUT=$(./polygon-edge secrets output --data-dir "node-$i")
        
        # Extract address (without 0x prefix for genesis)
        ADDRESS=$(echo "$OUTPUT" | grep "Public key (address)" | awk '{print $NF}')
        ADDRESS_NO_PREFIX=${ADDRESS#0x}
        
        # Extract BLS public key
        BLS_KEY=$(echo "$OUTPUT" | grep "BLS Public key" | awk '{print $NF}')
        
        # Extract Node ID for bootnode
        NODE_ID=$(echo "$OUTPUT" | grep "Node ID" | awk '{print $NF}')
        
        # Store validator in format: ADDRESS:BLS_KEY
        VALIDATORS+=("${ADDRESS_NO_PREFIX}:${BLS_KEY}")
        NODE_IDS+=("$NODE_ID")
        
        log_info "  Address: $ADDRESS"
        log_info "  BLS Key: $BLS_KEY"
        log_info "  Node ID: $NODE_ID"
    done
    
    # Export for use in genesis generation
    export VAL1="${VALIDATORS[0]}"
    export VAL2="${VALIDATORS[1]}"
    export VAL3="${VALIDATORS[2]}"
    export VAL4="${VALIDATORS[3]}"
    export BOOTNODE_ID="${NODE_IDS[0]}"
    
    log_info "Validator information collected"
}

generate_genesis() {
    log_step "Generating genesis configuration..."
    
    
    # Use dns4 bootnode for Docker networking
    BOOTNODE="/dns4/node1/tcp/1478/p2p/$BOOTNODE_ID"
    
    log_info "Bootnode: $BOOTNODE"
    log_info "Validators: $NUM_VALIDATORS"
    
    ./polygon-edge genesis \
        --consensus ibft \
        --ibft-validator "$VAL1" \
        --ibft-validator "$VAL2" \
        --ibft-validator "$VAL3" \
        --ibft-validator "$VAL4" \
        --bootnode "$BOOTNODE" \
        --premine 0x85da99c8a7c2c95964c8efd687e95e632fc423a6:1000000000000000000000 \
        --block-gas-limit 10000000 \
        --chain-id $CHAIN_ID  &>/dev/null
    if [ $? -ne 0 ]; then
        log_error "Failed to generate genesis configuration"
        exit 1
    fi
    
    log_info "Genesis configuration written to $BASE_DIR/genesis.json"
    
    # Show bootnode config
    log_info "Verifying bootnode configuration..."
    echo "Bootnodes:"
    jq '.bootnodes' genesis.json
}


create_management_scripts() {
    log_step "Creating management scripts..."
    
    # Start script
    cat > "$SCRIPTS_DIR/start.sh" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "Starting CrowdfundChain Polygon Edge Network..."
docker compose -f ../docker-compose.polygon.yml up -d
echo "Network started"
echo "" 
echo "Monitor with: ./monitor.sh"
echo "View logs with: ./logs.sh"
EOF
    chmod +x "$SCRIPTS_DIR/start.sh"
    
    # Stop script
    cat > "$SCRIPTS_DIR/stop.sh" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "Stopping CrowdfundChain Polygon Edge Network..."
docker compose -f ../docker-compose.polygon.yml down
echo "Network stopped"
EOF
    chmod +x "$SCRIPTS_DIR/stop.sh"
    
    # Monitor script
    cat > "$SCRIPTS_DIR/monitor.sh" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"

echo "=== CrowdfundChain Polygon Edge Network Status ==="
echo ""

echo "Container Status:"
docker compose -f ../docker-compose.polygon.yml ps
echo ""

echo "Blockchain Status:"
BLOCK=$(curl -s -X POST http://localhost:8545 -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | \
    grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -n "$BLOCK" ] && [ "$BLOCK" != "0x" ]; then
    BLOCK_DEC=$((BLOCK))
    echo " Current Block: $BLOCK_DEC"
    echo " RPC Endpoint: http://localhost:8545"
    echo " Chain ID: 100"
else
    echo "Network starting up..."
fi

echo ""
echo "Network Info:"
docker logs node1 2>&1 | grep -i "peer connected" | tail -3

echo ""
echo "Commands:"
echo "  ./logs.sh        - View logs"
echo "  ./stop.sh        - Stop network"
echo "  ./restart.sh     - Restart network"
EOF
    chmod +x "$SCRIPTS_DIR/monitor.sh"
    
    # Logs script
    cat > "$SCRIPTS_DIR/logs.sh" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"

if [ -z "$1" ]; then
    echo "Showing logs for all nodes..."
    docker compose -f ../docker-compose.polygon.yml logs -f
else
    echo "Showing logs for $1..."
    docker logs -f "$1"
fi
EOF
    chmod +x "$SCRIPTS_DIR/logs.sh"
    
    # Restart script
    cat > "$SCRIPTS_DIR/restart.sh" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "Restarting CrowdfundChain Polygon Edge Network..."
docker compose -f ../docker-compose.polygon.yml down
sleep 2
docker compose -f ../docker-compose.polygon.yml up -d
echo "Network restarted"
echo ""
./monitor.sh
EOF
    chmod +x "$SCRIPTS_DIR/restart.sh"

    #move docker compose file to BASE directory
    mv "$OLDPWD/docker-compose.polygon.yml" "$BASE_DIR/docker-compose.polygon.yml"
    
    log_info "Polygon Edge Management scripts created at: $SCRIPTS_DIR"

}

start_network() {
    log_step "Starting the network..."
    cd "$SCRIPTS_DIR"
    ./start.sh &>/dev/null
    log_info "Network started successfully"
}





# Main deployment flow
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  Polygon Edge Deployment                                       ║"
    echo "║  4-Node IBFT Validator Network                                 ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    

    create_directories
    download_polygon_edge
    pull_docker_images
    generate_validator_secrets
    collect_validator_info
    generate_genesis
    # create_docker_compose
    create_management_scripts
    # create_readme
    start_network
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║     DEPLOYMENT COMPLETE!                                       ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    
}

# Run main function
main