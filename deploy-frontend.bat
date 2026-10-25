@echo off
setlocal EnableDelayedExpansion

echo =======================================================
echo    STAR ORPHANS - DEPLOY AUTOMATIZADO DO FRONTEND WEB
echo =======================================================
echo.

REM 1. Deteccao automatica da pasta do app Flutter
set "APP_DIR=%~dp0"
if "%APP_DIR:~-1%"=="\" set "APP_DIR=%APP_DIR:~0,-1%"

if exist "%APP_DIR%\pubspec.yaml" goto :FOUND
if exist "C:\projetos\star_orphans_app\pubspec.yaml" (
    set "APP_DIR=C:\projetos\star_orphans_app"
    goto :FOUND
)
if exist "%USERPROFILE%\star_orphans_app\pubspec.yaml" (
    set "APP_DIR=%USERPROFILE%\star_orphans_app"
    goto :FOUND
)

echo [ERRO] Nao foi possivel encontrar a pasta do aplicativo Flutter!
goto :END

:FOUND
echo [OK] Pasta local identificada: "%APP_DIR%"
cd /d "%APP_DIR%"

REM 2. Verificacao do disco Z:
set "DEST_DIR=Z:\OrphansSolutions\apis\src\public"
if not exist "Z:\OrphansSolutions" (
    echo [ERRO] O disco de rede Z:\OrphansSolutions nao esta acessivel!
    echo Verifique se a pasta compartilhada do servidor esta mapeada como Z:.
    goto :END
)
if not exist "%DEST_DIR%" (
    mkdir "%DEST_DIR%" >nul 2>&1
)
echo [OK] Disco do servidor Z: conectado!

REM 3. Compilacao Flutter Web em modo Release
echo.
echo [1/3] Compilando versao Web Release otimizada (CanvasKit/WASM)...
call flutter build web --release
if errorlevel 1 (
    echo [ERRO] Falha ao compilar o aplicativo Flutter!
    goto :END
)

REM 4. Copia dos arquivos estaticos para o servidor
echo.
echo [2/3] Publicando arquivos no servidor (Z:\OrphansSolutions\apis\src\public)...
robocopy "%APP_DIR%\build\web" "%DEST_DIR%" /E /NFL /NDL /NJH /NJS /nc /ns /np

REM 5. Atualizacao dos arquivos dentro do container apis_novas via SSH
echo.
echo [3/3] Atualizando assets dentro do container apis_novas...

set "SERVER_IP=192.168.15.19"
ping -n 1 -w 500 192.168.15.19 >nul 2>&1
if errorlevel 1 (
    set "SERVER_IP=26.239.180.177"
)

set "TEMP_ASKPASS=%TEMP%\askpass_orphans.bat"
echo @echo wizard@321> "%TEMP_ASKPASS%"
set "SSH_ASKPASS=%TEMP_ASKPASS%"
set "SSH_ASKPASS_REQUIRE=force"

ssh.exe -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null luizp@!SERVER_IP! "docker cp C:\Hyper-V\OrphansSolutions\apis\src\public\. apis_novas:/usr/src/public/"
if exist "%TEMP_ASKPASS%" del "%TEMP_ASKPASS%" >nul 2>&1

echo.
echo =======================================================
echo    FRONTEND WEB/PWA ATUALIZADO COM SUCESSO!
echo =======================================================
echo.

:END
