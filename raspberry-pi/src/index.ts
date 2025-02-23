import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { exec } from 'child_process';
import { promisify } from 'util';
import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

const execAsync = promisify(exec);

const app = express();
const port = process.env.PORT || 3000;
const jwtSecret = process.env.JWT_SECRET || 'your-secret-key';
const networkInterface = process.env.NETWORK_INTERFACE || 'eth0';

// Middleware
app.use(express.json());
app.use(cors());
app.use(helmet());

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
});
app.use(limiter);

// JWT Authentication middleware
const authenticateToken = (req: express.Request, res: express.Response, next: express.NextFunction) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  try {
    const user = jwt.verify(token, jwtSecret) as { role: string };
    if (user.role !== 'parent') {
      return res.status(403).json({ error: 'Only parents can control network access' });
    }
    next();
  } catch (error) {
    return res.status(403).json({ error: 'Invalid token' });
  }
};

// Device control functions
class DeviceControl {
  private interface: string;

  constructor(networkInterface: string) {
    this.interface = networkInterface;
  }

  async allowDevice(macAddress: string): Promise<void> {
    try {
      // Check if rule already exists
      const { stdout } = await execAsync(
        `sudo iptables -L FORWARD -v -n | grep ${macAddress}`
      );

      if (!stdout) {
        await execAsync(`
          sudo iptables -A FORWARD -i ${this.interface} -m mac --mac-source ${macAddress} -j ACCEPT
        `);
      }
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
      const { stdout } = await execAsync(
        `sudo iptables -L FORWARD -v -n | grep ${macAddress}`
      );
      return stdout.trim().length > 0;
    } catch (error) {
      console.error(`Failed to get device status ${macAddress}:`, error);
      return false;
    }
  }
}

const deviceControl = new DeviceControl(networkInterface);

// Validate MAC address format
const isValidMacAddress = (mac: string): boolean => {
  return /^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/.test(mac);
};

// Routes
app.post('/network/allow', authenticateToken, async (req, res) => {
  const { macAddress } = req.body;

  if (!macAddress || !isValidMacAddress(macAddress)) {
    return res.status(400).json({ error: 'Invalid MAC address' });
  }

  try {
    await deviceControl.allowDevice(macAddress);
    res.json({ message: 'Device access allowed', macAddress });
  } catch (error) {
    console.error('Error allowing device:', error);
    res.status(500).json({ error: 'Failed to allow device access' });
  }
});

app.post('/network/block', authenticateToken, async (req, res) => {
  const { macAddress } = req.body;

  if (!macAddress || !isValidMacAddress(macAddress)) {
    return res.status(400).json({ error: 'Invalid MAC address' });
  }

  try {
    await deviceControl.blockDevice(macAddress);
    res.json({ message: 'Device access blocked', macAddress });
  } catch (error) {
    console.error('Error blocking device:', error);
    res.status(500).json({ error: 'Failed to block device access' });
  }
});

app.get('/network/status/:macAddress', authenticateToken, async (req, res) => {
  const { macAddress } = req.params;

  if (!isValidMacAddress(macAddress)) {
    return res.status(400).json({ error: 'Invalid MAC address' });
  }

  try {
    const isAllowed = await deviceControl.getDeviceStatus(macAddress);
    res.json({ macAddress, isAllowed });
  } catch (error) {
    console.error('Error getting device status:', error);
    res.status(500).json({ error: 'Failed to get device status' });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Error handling middleware
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(port, () => {
  console.log(`Network controller listening on port ${port}`);
}); 