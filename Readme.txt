
[ 自動安裝 - Readme ]

1. 修改 Makefile 內以下屬性:

GIT_BRANCH=GIT 分支名稱(預設填 develop)
DB=資料庫名稱
USER=資料庫 User Name
PASSWORD=資料庫 User 密碼
PROJECT_NAME=專案名稱 (跟 Gitlab 上的專案名稱一致)
SERVER_NAME=伺服器名稱 (預設填本機 IP)
SERVER_PORT=伺服器PORT (預設填 80)

2. 在本資料夾底下執行:
make install
