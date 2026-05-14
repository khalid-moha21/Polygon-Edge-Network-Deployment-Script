# Polygon Edge Network Bootstrap

A small GitHub-ready repository to bootstrap a local Polygon Edge network deployment.

This project uses bash scripts and Docker to prepare a local Polygon Edge validator network, generate validator secrets, create a genesis configuration, and provide management scripts for starting and stopping the network.

## What this repository contains

- `main.sh` - primary orchestration script that wires together the bootstrap process.
- `polygon-edge.sh` - core Polygon Edge deployment logic:
  - creates directory structure
  - downloads Polygon Edge binaries
  - pulls Polygon Edge Docker images
  - generates validator secrets
  - collects validator metadata
  - generates a local genesis file
  - creates helper start/stop scripts
- `pre-reqs.sh` - installs Linux prerequisites such as Docker, `curl`, `tar`, and `jq`.
- `utils.sh` - shared configuration, logging, and helper functions.
- `docker-compose.polygon.yml` - Docker Compose configuration for a 4-node local Polygon Edge network.

## Prerequisites

- Bash-compatible shell
- Docker engine installed and running
- Docker Compose v2 (or compatible Docker Compose plugin)
- `curl`, `tar`, and `jq`

## Setup and usage

1. Clone the repository.
2. Make scripts executable.
   chmod +x main.sh polygon-edge.sh pre-reqs.sh utils.sh

3. Run the main bootstrap script.
   ./main.sh

## Starting and stopping the network

After bootstrap, use the generated helper scripts under `polygon-edge/scripts`:
./polygon-edge/scripts/start.sh
./polygon-edge/scripts/stop.sh

## Network details

The Docker Compose file defines four Polygon Edge nodes (`node1` through `node4`) on a bridged Docker network. The first node publishes JSON-RPC on `localhost:8545`.
