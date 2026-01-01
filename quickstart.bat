@echo off
REM Docker Best Practices - Quick Start Script for Windows
REM This script helps get the project up and running quickly

setlocal enabledelayedexpansion

echo.
echo ================================================
echo Docker Best Practices - Node.js Sample Project
echo ================================================
echo.

REM Check if Docker is installed
docker --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker not found. Please install Docker Desktop for Windows.
    exit /b 1
)

REM Check if Docker Compose is installed
docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker Compose not found. Please install Docker Desktop for Windows.
    exit /b 1
)

REM Check if Node.js is installed
node --version >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Node.js not found. Some features may not work locally.
)

REM Parse command
set command=%1
if "%command%"=="" set command=help

if "%command%"=="dev" (
    call :setup_dev
) else if "%command%"=="build" (
    call :build_production
) else if "%command%"=="start" (
    call :start_production
) else if "%command%"=="test" (
    call :test_endpoints
) else if "%command%"=="push" (
    call :push_image
) else if "%command%"=="stop" (
    call :stop_containers
) else if "%command%"=="logs" (
    call :show_logs %2
) else if "%command%"=="stats" (
    call :show_stats
) else if "%command%"=="clean" (
    call :clean_all
) else if "%command%"=="help" (
    call :show_help
) else (
    echo [ERROR] Unknown command: %command%
    echo.
    call :show_help
    exit /b 1
)

exit /b 0

:setup_dev
echo [*] Setting up development environment...
if not exist .env (
    copy .env.example .env
    echo [+] Created .env from .env.example
)
docker-compose -f docker-compose.dev.yml up -d
echo.
echo [+] Development environment started!
echo Application: http://localhost:3000
echo Health check: http://localhost:3000/health
echo.
echo View logs: docker-compose -f docker-compose.dev.yml logs -f
echo Stop: docker-compose -f docker-compose.dev.yml down
exit /b 0

:build_production
echo [*] Building production image...
docker build -t docker-best-practices-app:1.0.0 .
echo [+] Production image built successfully
for /f "tokens=*" %%i in ('docker images docker-best-practices-app:1.0.0 --format "{{.Size}}"') do set SIZE=%%i
echo Image size: %SIZE%
echo.
exit /b 0

:start_production
call :build_production
echo [*] Starting production environment...
if not exist .env (
    copy .env.example .env
    echo [!] Created .env - PLEASE UPDATE WITH REAL VALUES
)
docker-compose up -d
echo.
echo [+] Production environment running!
echo Application: http://localhost:3000
echo Health check: http://localhost:3000/health
echo.
echo View logs: docker-compose logs -f app
echo Stop: docker-compose down
exit /b 0

:push_image
echo [*] Pushing image to Docker Hub...

REM Check if image exists, if not build it
docker image inspect docker-best-practices-app:1.0.0 >nul 2>&1
if errorlevel 1 call :build_production

if "!DOCKER_USERNAME!"=="" set /p DOCKER_USERNAME="Enter Docker Hub Username: "
if "!DOCKER_USERNAME!"=="" (
    echo [ERROR] Docker Hub username is required to push.
    exit /b 1
)

echo [*] Tagging and pushing to !DOCKER_USERNAME!/docker-best-practices-app...
docker tag docker-best-practices-app:1.0.0 !DOCKER_USERNAME!/docker-best-practices-app:1.0.0
docker tag docker-best-practices-app:1.0.0 !DOCKER_USERNAME!/docker-best-practices-app:latest
docker push !DOCKER_USERNAME!/docker-best-practices-app:1.0.0
docker push !DOCKER_USERNAME!/docker-best-practices-app:latest
exit /b 0

:test_endpoints
echo [*] Testing endpoints...
echo.

set urls[0]=http://localhost:3000/
set urls[1]=http://localhost:3000/health
set urls[2]=http://localhost:3000/ready
set urls[3]=http://localhost:3000/api/info

for /l %%i in (0,1,3) do (
    echo Testing !urls[%%i]!...
    curl -s -o nul -w "Status: %%{http_code}\n" !urls[%%i]!
    echo.
)
exit /b 0

:stop_containers
echo [*] Stopping containers...
docker-compose down
echo [+] Containers stopped
exit /b 0

:show_logs
if "%2"=="" (
    docker-compose logs -f
) else (
    docker-compose logs -f %2
)
exit /b 0

:show_stats
docker stats
exit /b 0

:clean_all
echo [*] Removing containers, images, and volumes...
docker-compose down -v
docker rmi docker-best-practices-app:1.0.0 >nul 2>&1
echo [+] Cleanup complete
exit /b 0

:show_help
echo Usage: quickstart.bat [COMMAND]
echo.
echo Commands:
echo   dev              - Start development environment
echo   build            - Build production image
echo   start            - Start production environment
echo   test             - Test API endpoints
echo   push             - Push image to Docker Hub
echo   stop             - Stop running containers
echo   logs             - View Docker Compose logs
echo   stats            - Show container resource usage
echo   clean            - Remove containers, images, volumes
echo   help             - Show this message
echo.
echo Examples:
echo   quickstart.bat dev              # Start development
echo   quickstart.bat build            # Build production image
echo   quickstart.bat start            # Start production container
echo   quickstart.bat test             # Test endpoints
echo   quickstart.bat push             # Push to registry
echo.
exit /b 0
