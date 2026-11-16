@echo off
echo ====================================
echo   AWDAR - Updating Project to GitHub
echo ====================================
echo Pulling latest changes from GitHub...
git pull origin main --rebase
echo.
echo Pushing your local changes...
git add .
git commit -m "Auto update project files"
git push origin main
echo ====================================
echo   Done! Project updated successfully.
echo ====================================
pause