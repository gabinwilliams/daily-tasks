# Daily Tasks - Raspberry Pi Network Controller

This component runs on a Raspberry Pi and controls internet access for registered devices based on task completion status.

## Prerequisites

- Raspberry Pi 4 (recommended) or 3B+
- Raspbian OS (64-bit recommended)
- Node.js 18.x or later
- npm 9.x or later
- Git

## Installation

1. Update system and install dependencies:
```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y iptables nodejs npm git nginx certbot python3-certbot-nginx
```

2. Clone the repository:
```bash
git clone https://github.com/yourusername/daily-tasks.git
cd daily-tasks/raspberry-pi
```

3. Install Node.js dependencies:
```bash
npm install
npm install -g pm2
```

4. Configure environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
nano .env
```

## Network Setup

### Static IP Configuration

1. Edit the network configuration:
```bash
sudo nano /etc/dhcpcd.conf
```

2. Add static IP configuration:
```bash
interface eth0
static ip_address=192.168.1.2/24
static routers=192.168.1.1
static domain_name_servers=1.1.1.1 8.8.8.8
```

### Firewall Configuration

1. Create the initial firewall setup script:
```bash
sudo nano /usr/local/bin/setup-firewall.sh
```

2. Add the following content:
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

3. Make the script executable and run it:
```bash
sudo chmod +x /usr/local/bin/setup-firewall.sh
sudo /usr/local/bin/setup-firewall.sh
```

## Application Setup

1. Configure PM2:
```bash
pm2 start src/index.js --name "network-controller"
pm2 save
pm2 startup
```

2. Configure Nginx:
```bash
sudo nano /etc/nginx/sites-available/network-controller
```

Add the following configuration:
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

3. Enable the site:
```bash
sudo ln -s /etc/nginx/sites-available/network-controller /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

4. Set up SSL certificate:
```bash
sudo certbot --nginx -d your-pi-domain.com
```

## Usage

### Managing Devices

The network controller exposes a REST API for managing device access:

- `POST /network/allow`: Allow device access
- `POST /network/block`: Block device access
- `GET /network/status`: Get device status

Example:
```bash
# Allow device access
curl -X POST http://localhost:3000/network/allow \
  -H "Content-Type: application/json" \
  -d '{"macAddress": "00:11:22:33:44:55"}'

# Block device access
curl -X POST http://localhost:3000/network/block \
  -H "Content-Type: application/json" \
  -d '{"macAddress": "00:11:22:33:44:55"}'
```

### Monitoring

1. Check application status:
```bash
pm2 status
pm2 logs network-controller
```

2. Check system resources:
```bash
htop
df -h
```

3. Monitor network traffic:
```bash
sudo iftop -i eth0
sudo tcpdump -i eth0
```

## Troubleshooting

### Common Issues

1. Network Access Issues
- Check iptables rules: `sudo iptables -L`
- Verify device MAC address
- Check network interface status

2. API Connection Issues
- Verify SSL certificate validity
- Check nginx logs
- Verify API server status

3. Performance Issues
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

1. Backup iptables rules:
```bash
sudo iptables-save > /backup/iptables.rules
```

2. Backup environment variables:
```bash
cp .env /backup/.env
```

3. Backup SSL certificates:
```bash
sudo cp -r /etc/letsencrypt/live/your-pi-domain.com /backup/ssl/
```

### Recovery Steps

1. Restore iptables rules:
```bash
sudo iptables-restore < /backup/iptables.rules
```

2. Restore environment:
```bash
cp /backup/.env .env
```

3. Restore SSL certificates:
```bash
sudo cp -r /backup/ssl/* /etc/letsencrypt/live/
```

## Security Considerations

1. Firewall Rules
- Regularly update and audit iptables rules
- Monitor logs for unauthorized access attempts
- Use fail2ban for SSH protection

2. API Security
- Implement rate limiting
- Use strong JWT validation
- Keep dependencies updated

3. Network Security
- Regularly update SSL certificates
- Monitor network traffic
- Implement intrusion detection

## Maintenance

### Regular Tasks

1. System Updates
```bash
sudo apt update
sudo apt upgrade -y
```

2. Log Rotation
```bash
sudo logrotate -f /etc/logrotate.conf
```

3. SSL Certificate Renewal
```bash
sudo certbot renew
```

## Contributing

Please read [CONTRIBUTING.md](../CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details. 