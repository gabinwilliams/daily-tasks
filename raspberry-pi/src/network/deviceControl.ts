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
      // Check if rule already exists
      const { stdout } = await execAsync(
        `sudo iptables -L FORWARD -v -n | grep ${macAddress}`
      );

      if (!stdout) {
        await execAsync(
          `sudo iptables -A FORWARD -i ${this.interface} -m mac --mac-source ${macAddress} -j ACCEPT`
        );
      }
    } catch (error) {
      console.error(`Failed to allow device ${macAddress}:`, error);
      throw error;
    }
  }

  async blockDevice(macAddress: string): Promise<void> {
    try {
      await execAsync(
        `sudo iptables -D FORWARD -i ${this.interface} -m mac --mac-source ${macAddress} -j ACCEPT`
      );
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