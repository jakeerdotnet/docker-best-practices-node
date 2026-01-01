#!/bin/bash

# Docker Best Practices - Quick Start Script
# This script helps get the project up and running quickly

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Docker Best Practices - Node.js Sample Project${NC}"
echo -e "${BLUE}================================================${NC}\n"

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}✗ Docker not found. Please install Docker.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Docker is installed${NC}"
    
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}✗ Docker Compose not found. Please install Docker Compose.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Docker Compose is installed${NC}"
    
    if ! command -v npm &> /dev/null; then
        echo -e "${RED}✗ npm not found. Please install Node.js.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ npm is installed${NC}\n"
}

# Development setup
setup_dev() {
    echo -e "${YELLOW}Setting up development environment...${NC}"
    
    # Copy environment file
    if [ ! -f .env ]; then
        cp .env.example .env
        echo -e "${GREEN}✓ Created .env from .env.example${NC}"
    fi
    
    # Install dependencies
    if [ ! -d node_modules ]; then
        echo -e "${YELLOW}Installing dependencies...${NC}"
        npm install
        echo -e "${GREEN}✓ Dependencies installed${NC}"
    fi
    
    # Start Docker Compose dev environment
    echo -e "${YELLOW}Starting Docker Compose development environment...${NC}"
    docker-compose -f docker-compose.dev.yml up -d
    echo -e "${GREEN}✓ Started development environment${NC}"
    
    echo -e "\n${GREEN}Development environment ready!${NC}"
    echo -e "Application: ${BLUE}http://localhost:3000${NC}"
    echo -e "Health check: ${BLUE}http://localhost:3000/health${NC}"
    echo -e "Info endpoint: ${BLUE}http://localhost:3000/api/info${NC}"
    echo -e "\nView logs: ${BLUE}docker-compose -f docker-compose.dev.yml logs -f${NC}"
    echo -e "Stop services: ${BLUE}docker-compose -f docker-compose.dev.yml down${NC}\n"
}

# Production build
build_production() {
    echo -e "${YELLOW}Building production image...${NC}"
    
    docker build -t docker-best-practices-app:1.0.0 .
    echo -e "${GREEN}✓ Production image built successfully${NC}"
    
    # Show image size
    SIZE=$(docker images docker-best-practices-app:1.0.0 --format "{{.Size}}")
    echo -e "Image size: ${BLUE}${SIZE}${NC}\n"
}

# Start production
start_production() {
    echo -e "${YELLOW}Starting production environment...${NC}"
    
    # Copy environment file if missing
    if [ ! -f .env ]; then
        cp .env.example .env
        echo -e "${YELLOW}⚠ Created .env from example - PLEASE UPDATE WITH REAL VALUES${NC}"
    fi
    
    docker-compose up -d
    
    # Wait for container to be healthy
    echo -e "${YELLOW}Waiting for container to be healthy...${NC}"
    for i in {1..30}; do
        if curl -f http://localhost:3000/health > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Container is healthy${NC}"
            break
        fi
        echo -n "."
        sleep 1
    done
    
    echo -e "\n${GREEN}Production environment running!${NC}"
    echo -e "Application: ${BLUE}http://localhost:3000${NC}"
    echo -e "Health check: ${BLUE}http://localhost:3000/health${NC}"
    echo -e "\nView logs: ${BLUE}docker-compose logs -f app${NC}"
    echo -e "Stop services: ${BLUE}docker-compose down${NC}\n"
}

# Test endpoints
test_endpoints() {
    echo -e "${YELLOW}Testing endpoints...${NC}\n"
    
    base_url="http://localhost:3000"
    
    endpoints=(
        "/"
        "/health"
        "/ready"
        "/api/info"
    )
    
    for endpoint in "${endpoints[@]}"; do
        echo -ne "${YELLOW}Testing${NC} ${base_url}${endpoint}... "
        if response=$(curl -s -w "\n%{http_code}" "$base_url$endpoint"); then
            http_code=$(echo "$response" | tail -n 1)
            body=$(echo "$response" | head -n -1)
            
            if [ "$http_code" = "200" ]; then
                echo -e "${GREEN}✓ (${http_code})${NC}"
                echo -e "Response: ${BLUE}$(echo $body | head -c 80)...${NC}\n"
            else
                echo -e "${RED}✗ (${http_code})${NC}"
            fi
        else
            echo -e "${RED}✗ Failed to connect${NC}"
        fi
    done
}

# Show usage
show_usage() {
    echo -e "${BLUE}Usage:${NC}"
    echo -e "  $0 [COMMAND]\n"
    echo -e "${BLUE}Commands:${NC}"
    echo -e "  ${GREEN}dev${NC}          - Start development environment"
    echo -e "  ${GREEN}build${NC}        - Build production image"
    echo -e "  ${GREEN}start${NC}        - Start production environment"
    echo -e "  ${GREEN}test${NC}         - Test API endpoints"
    echo -e "  ${GREEN}stop${NC}         - Stop running containers"
    echo -e "  ${GREEN}logs${NC}         - View Docker Compose logs"
    echo -e "  ${GREEN}stats${NC}        - Show container resource usage"
    echo -e "  ${GREEN}clean${NC}        - Remove containers, images, volumes"
    echo -e "  ${GREEN}help${NC}         - Show this message\n"
    echo -e "${BLUE}Examples:${NC}"
    echo -e "  $0 dev              # Start development"
    echo -e "  $0 build            # Build production image"
    echo -e "  $0 start            # Start production container"
    echo -e "  $0 test             # Test endpoints\n"
}

# Main
main() {
    check_prerequisites
    
    case "${1:-help}" in
        dev)
            setup_dev
            ;;
        build)
            build_production
            ;;
        start)
            build_production
            start_production
            ;;
        test)
            test_endpoints
            ;;
        stop)
            echo -e "${YELLOW}Stopping containers...${NC}"
            docker-compose down
            echo -e "${GREEN}✓ Containers stopped${NC}"
            ;;
        logs)
            docker-compose logs -f "${2:---all}"
            ;;
        stats)
            docker stats
            ;;
        clean)
            echo -e "${RED}Removing containers, images, and volumes...${NC}"
            docker-compose down -v
            docker rmi docker-best-practices-app:1.0.0 2>/dev/null || true
            echo -e "${GREEN}✓ Cleanup complete${NC}"
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}\n"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
