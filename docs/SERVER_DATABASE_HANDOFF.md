# 新项目服务器与数据库交接说明

## 目标

为新项目单独创建 Neon PostgreSQL，并部署到现有 Ubuntu 服务器时保持隔离，不复用图火数据库，不影响现有线上服务。

## 现有图火数据库

以下信息仅用于识别现有项目，不要连接、迁移或修改：

- Provider: Neon PostgreSQL
- Host 特征: `*.aws.neon.tech`
- Region: `ap-southeast-1`
- Database: `neondb`
- 现有图火表:
  - `users`
  - `image_generations`
  - `credit_transactions`
  - `recharge_orders`
  - `daily_login_rewards`

## 新开 Neon 数据库

1. 登录 Neon 控制台: `https://console.neon.tech`
2. 创建新 Project。
3. Project name 使用新项目名。
4. Region 建议选择 `ap-southeast-1`。
5. Database 可以使用默认 `neondb`，也可以改成新项目名。
6. Role/User 为新项目单独创建，不要复用图火用户。
7. 在 Neon 控制台复制 Connection string，格式类似:

```env
DATABASE_URL=postgresql://USER:PASSWORD@HOST/neondb?sslmode=require
```

## 本地连接方式

在新项目本地 `.env` 中放入:

```env
DATABASE_URL=postgresql://USER:PASSWORD@HOST/neondb?sslmode=require
```

Node.js `pg` 连接示例:

```js
import pg from 'pg';

export const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});
```

测试连接:

```bash
DATABASE_URL='postgresql://USER:PASSWORD@HOST/neondb?sslmode=require' node -e "import pg from 'pg'; const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } }); const r = await pool.query('select version(), current_database()'); console.log(r.rows[0]); await pool.end();"
```

## 服务器 SSH

服务器:

```bash
ssh -i ~/.ssh/hotwell_codex_ed25519 -o IdentitiesOnly=yes ubuntu@45.43.57.11
```

不要复制或外发私钥内容。如果在同一台 Mac 上操作，可以直接使用上面的本地 key 路径。

## 服务器部署时连接数据库

新项目使用独立部署目录，例如:

```bash
/var/www/your-new-project
```

在新项目目录下创建自己的 `.env`:

```bash
cd /var/www/your-new-project
nano .env
```

写入:

```env
DATABASE_URL=postgresql://USER:PASSWORD@HOST/neondb?sslmode=require
PORT=8791
NODE_ENV=production
```

注意:

- `.env` 只放在新项目目录。
- 不要覆盖 `/var/www/tuhuo-image/.env`。
- 不要复制图火 `.env`。
- 不要把 `DATABASE_URL` 写到全局 shell profile 或 system-wide env。

## systemd 示例

新项目 systemd 示例:

```ini
[Unit]
Description=Your New Project API
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/var/www/your-new-project
Environment=NODE_ENV=production
EnvironmentFile=/var/www/your-new-project/.env
ExecStart=/usr/bin/node /var/www/your-new-project/server/index.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

保存为:

```bash
sudo nano /etc/systemd/system/your-new-project.service
```

启动:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now your-new-project.service
sudo systemctl status your-new-project.service --no-pager
```

## 不要影响现有项目

不要操作这些目录:

- `/var/www/tuhuo-image`
- `/var/www/hotwell`

不要重启或修改这些服务:

- `tuhuo-image.service`
- `hotwell-api.service`
- `openclaw`
- `openclaw-gateway`

不要复用这些端口:

- 图火: `127.0.0.1:8790`
- hotwell: `*:8787`
- openclaw: `127.0.0.1:18789`
- openclaw: `127.0.0.1:18791`
- openclaw: `127.0.0.1:40071`
- UDP: `5353`

新项目建议使用:

- API 端口: `127.0.0.1:8791` 或更后面的空闲端口
- 部署目录: `/var/www/your-new-project`
- systemd: `your-new-project.service`
- Nginx 配置: `/etc/nginx/conf.d/your-new-project.conf`

部署前检查端口:

```bash
ss -lntup
```

## Nginx 配置建议

为新项目创建独立 Nginx 配置:

```bash
sudo nano /etc/nginx/conf.d/your-new-project.conf
```

只 reload Nginx，不要重启其他业务:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## 操作前检查

部署或改配置前建议先执行:

```bash
hostname
uptime
free -h
df -h /
systemctl is-active tuhuo-image.service hotwell-api.service openclaw-gateway.service
ss -lntup
ls -la /var/www
```

## 推荐结论

新项目可以使用同一台服务器，但数据库建议单独开 Neon Project。这样 migration、权限、备份、账单、删库风险都和图火隔离。
