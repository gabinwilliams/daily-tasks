# Raspberry Pi Network Controller Setup

This guide explains how to set up your Raspberry Pi as a network controller for the Daily Tasks system.

## Prerequisites

- Raspberry Pi 4 (recommended) or 3B+
- Raspbian OS (64-bit recommended)
- Node.js 18.x or later
- npm 9.x or later
- Git

## Network Setup

### 1. Install Required Packages

```bash
# Update system
sudo apt update
sudo apt upgrade -y

# Install required packages
sudo apt install -y \
  iptables \
  nodejs \
  npm \
  git \
  nginx \
  certbot \
  python3-certbot-nginx
```

### 2. Network Configuration

#### Configure Network Interfaces

Edit `/etc/dhcpcd.conf`:

```bash
# Static IP configuration
interface eth0
static ip_address=192.168.1.2/24
static routers=192.168.1.1
static domain_name_servers=1.1.1.1 8.8.8.8

# Optional: WiFi configuration if using wireless
interface wlan0
static ip_address=192.168.1.3/24
static routers=192.168.1.1
static domain_name_servers=1.1.1.1 8.8.8.8
```

### 3. Firewall Setup

Create the initial iptables configuration:

```bash
#!/bin/bash

# Flush existing rules
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t mangle -F
sudo iptables -t mangle -X

# Default policies
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

# Allow established connections
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow local loopback
sudo iptables -A INPUT -i lo -j ACCEPT

# Allow SSH (adjust port if needed)
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP/HTTPS for API
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Save rules
sudo sh -c "iptables-save > /etc/iptables.rules"
```

### 4. Node.js Application Setup

#### Install PM2 for Process Management

```bash
sudo npm install -g pm2
```

#### Clone and Setup Application

```bash
# Clone repository
git clone https://github.com/yourusername/daily-tasks.git
cd daily-tasks/raspberry-pi

# Install dependencies
npm install

# Start application with PM2
pm2 start src/index.js --name "network-controller"
pm2 save

# Enable PM2 startup script
pm2 startup
```

## Application Configuration

### 1. Environment Variables

Create `.env` file:

```bash
# API Configuration
API_PORT=3000
API_HOST=0.0.0.0
JWT_SECRET=your-secret-key

# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key

# Network Configuration
NETWORK_INTERFACE=eth0
ALLOWED_NETWORKS=192.168.1.0/24
```

### 2. SSL Certificate Setup

```bash
# Install SSL certificate using Let's Encrypt
sudo certbot --nginx -d your-pi-domain.com
```

### 3. Nginx Configuration

Create `/etc/nginx/sites-available/network-controller`:

```nginx
server {
    listen 443 ssl;
    server_name your-pi-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-pi-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-pi-domain.com/privkey.pem;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Enable the site:

```bash
sudo ln -s /etc/nginx/sites-available/network-controller /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## Network Control Scripts

### MAC Address Management

Create script for managing device access:

```typescript
// src/network/deviceControl.ts
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

export class DeviceControl {
  private interface: string;

  constructor(networkInterface: string) {
    this.interface = networkInterface;
  }

  async allowDevice(macAddress: string): Promise<void> {
    try {
      await execAsync(`
        sudo iptables -A FORWARD -i ${this.interface} -m mac --mac-source ${macAddress} -j ACCEPT
      `);
    } catch (error) {
      console.error(`Failed to allow device ${macAddress}:`, error);
      throw error;
    }
  }

  async blockDevice(macAddress: string): Promise<void> {
    try {
      await execAsync(`
        sudo iptables -D FORWARD -i ${this.interface} -m mac --mac-source ${macAddress} -j ACCEPT
      `);
    } catch (error) {
      console.error(`Failed to block device ${macAddress}:`, error);
      throw error;
    }
  }

  async getDeviceStatus(macAddress: string): Promise<boolean> {
    try {
      const { stdout } = await execAsync(`
        sudo iptables -L FORWARD -v -n | grep ${macAddress}
      `);
      return stdout.trim().length > 0;
    } catch (error) {
      console.error(`Failed to get device status ${macAddress}:`, error);
      return false;
    }
  }
}
```

## Security Considerations

1. **Firewall Rules**
   - Regularly update and audit iptables rules
   - Monitor logs for unauthorized access attempts
   - Use fail2ban for SSH protection

2. **API Security**
   - Implement rate limiting
   - Use strong JWT validation
   - Keep dependencies updated

3. **Network Security**
   - Regularly update SSL certificates
   - Monitor network traffic
   - Implement intrusion detection

## Maintenance

### Regular Tasks

1. **System Updates**
   ```bash
   sudo apt update
   sudo apt upgrade -y
   ```

2. **Log Rotation**
   ```bash
   sudo logrotate -f /etc/logrotate.conf
   ```

3. **SSL Certificate Renewal**
   ```bash
   sudo certbot renew
   ```

### Monitoring

1. **Check Application Status**
   ```bash
   pm2 status
   pm2 logs network-controller
   ```

2. **Check System Resources**
   ```bash
   htop
   df -h
   ```

3. **Network Monitoring**
   ```bash
   sudo iftop -i eth0
   sudo tcpdump -i eth0
   ```

## Troubleshooting

### Common Issues

1. **Network Access Issues**
   - Check iptables rules: `sudo iptables -L`
   - Verify device MAC address
   - Check network interface status

2. **API Connection Issues**
   - Verify SSL certificate validity
   - Check nginx logs
   - Verify API server status

3. **Performance Issues**
   - Monitor system resources
   - Check application logs
   - Verify network bandwidth

### Debug Commands

```bash
# Check iptables rules
sudo iptables -L -v -n

# Check network interfaces
ip addr show

# Check application logs
pm2 logs network-controller

# Check nginx logs
sudo tail -f /var/log/nginx/error.log

# Check system logs
sudo journalctl -u network-controller
```

## Backup and Recovery

### Backup Configuration

1. **Iptables Rules**
   ```bash
   sudo iptables-save > /backup/iptables.rules
   ```

2. **Environment Variables**
   ```bash
   cp .env /backup/.env
   ```

3. **SSL Certificates**
   ```bash
   sudo cp -r /etc/letsencrypt/live/your-pi-domain.com /backup/ssl/
   ```

### Recovery Steps

1. **Restore Iptables Rules**
   ```bash
   sudo iptables-restore < /backup/iptables.rules
   ```

2. **Restore Environment**
   ```bash
   cp /backup/.env .env
   ```

3. **Restore SSL Certificates**
   ```bash
   sudo cp -r /backup/ssl/* /etc/letsencrypt/live/
   ``` 