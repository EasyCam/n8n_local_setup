# n8n Local Setup Script

A one-click native setup script for n8n on Ubuntu 24.04 (no Docker required). Optimized for Chinese users with mirror sources for faster installation.

## Features

- **Native Installation**: Direct installation without Docker overhead
- **Mirror Sources**: Uses Chinese mirror sources for faster downloads
  - Node.js (npmmirror.com)
  - npm packages (registry.npmmirror.com)
  - Ubuntu APT sources (Alibaba Cloud mirrors)
- **Database Options**: PostgreSQL (recommended) or SQLite
- **Reverse Proxy**: Optional Caddy with automatic HTTPS
- **System Service**: Automatic startup with systemd
- **Firewall**: Optional UFW configuration

## Requirements

- Ubuntu 24.04 LTS (other versions may work but not tested)
- Root access (sudo)
- Internet connection

## Quick Start

1. **Download and run the script:**
   ```bash
   wget https://raw.githubusercontent.com/EasyCam/n8n_local_setup/main/setup.sh
   sudo bash setup.sh
   ```

2. **Follow the interactive prompts:**
   - Choose deployment mode (production with domain or local/internal)
   - Select database type (PostgreSQL or SQLite)
   - Configure firewall if needed

3. **Access n8n:**
   - Local mode: `http://your-server-ip:5678`
   - Production mode: `https://your-domain.com`

## Deployment Modes

### 1. Production Mode (with domain)
- Requires a valid domain name
- Automatic HTTPS with Let's Encrypt
- Caddy reverse proxy
- Firewall configuration (ports 80, 443, 22)

### 2. Local/Internal Mode
- Direct access via port 5678
- No domain required
- Optional firewall configuration (ports 5678, 22)

## Database Options

### PostgreSQL (Recommended)
- Better performance for production
- Automatic database and user creation
- Suitable for multi-user environments

### SQLite
- Lightweight option
- Good for testing and small deployments
- Single file database

## Post-Installation

### Service Management
```bash
# Start n8n
sudo systemctl start n8n

# Stop n8n
sudo systemctl stop n8n

# Restart n8n
sudo systemctl restart n8n

# View logs
sudo journalctl -u n8n -f
```

### Upgrade n8n
```bash
npm i -g n8n@latest
sudo systemctl restart n8n
```

### Important Paths
- **Installation directory**: `/opt/n8n`
- **Data directory**: `/opt/n8n/.n8n`
- **Environment file**: `/opt/n8n/.env`
- **Service file**: `/etc/systemd/system/n8n.service`
- **Caddy config**: `/etc/caddy/Caddyfile` (if using domain)

## Configuration

The script automatically generates an environment file at `/opt/n8n/.env` with optimized settings. You can modify this file to customize n8n behavior.

### Key Environment Variables
- `N8N_PORT`: Port number (default: 5678)
- `N8N_HOST`: Hostname or IP
- `N8N_PROTOCOL`: http or https
- `WEBHOOK_URL`: Webhook base URL
- `N8N_ENCRYPTION_KEY`: Data encryption key
- `GENERIC_TIMEZONE`: Timezone setting

## Troubleshooting

### Check Service Status
```bash
sudo systemctl status n8n
```

### View Detailed Logs
```bash
sudo journalctl -u n8n --no-pager
```

### Test Database Connection (PostgreSQL)
```bash
sudo -u postgres psql -c "\l" | grep n8n
```

### Verify Firewall Rules
```bash
sudo ufw status verbose
```

## Security Considerations

- The script generates secure random passwords and encryption keys
- Database credentials are stored in `/opt/n8n/.env` with restricted permissions
- UFW firewall is optionally configured to limit access
- HTTPS is automatically configured in production mode

## Mirror Sources

This script uses the following Chinese mirror sources for faster downloads:
- **Node.js**: https://npmmirror.com/mirrors/node/
- **npm registry**: https://registry.npmmirror.com
- **Ubuntu packages**: https://mirrors.aliyun.com/ubuntu/

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

This project is licensed under the GPL-3.0 License - see the LICENSE file for details.

## Support

If you encounter any issues, please:
1. Check the troubleshooting section
2. Review the service logs
3. Open an issue with detailed error information
