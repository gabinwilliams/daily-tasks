import { exec, ExecException } from 'child_process';
import { DeviceControl } from './deviceControl';

// Mock child_process.exec
jest.mock('child_process', () => ({
  exec: jest.fn((
    command: string,
    options: any,
    callback?: (error: ExecException | null, stdout: string, stderr: string) => void
  ) => {
    if (callback) {
      callback(null, '', '');
    }
    return undefined as any;
  }),
}));

describe('DeviceControl', () => {
  const mockExec = exec as jest.MockedFunction<typeof exec>;
  const networkInterface = 'eth0';
  const validMacAddress = '00:11:22:33:44:55';
  let deviceControl: DeviceControl;

  beforeEach(() => {
    jest.clearAllMocks();
    deviceControl = new DeviceControl(networkInterface);
  });

  describe('allowDevice', () => {
    it('should add iptables rule to allow device', async () => {
      mockExec.mockImplementation((command, options, callback) => {
        if (callback) {
          // First call checks if rule exists, second call adds the rule
          callback(null, '', '');
        }
        return undefined as any;
      });

      await deviceControl.allowDevice(validMacAddress);

      expect(mockExec).toHaveBeenCalledTimes(2);
      expect(mockExec).toHaveBeenCalledWith(
        expect.stringContaining(`sudo iptables -L FORWARD -v -n | grep ${validMacAddress}`),
        expect.any(Object),
        expect.any(Function)
      );
      expect(mockExec).toHaveBeenCalledWith(
        expect.stringContaining(`sudo iptables -A FORWARD -i ${networkInterface} -m mac --mac-source ${validMacAddress} -j ACCEPT`),
        expect.any(Object),
        expect.any(Function)
      );
    });

    it('should not add rule if device is already allowed', async () => {
      mockExec.mockImplementation((command, options, callback) => {
        if (callback) {
          // Return existing rule
          callback(null, 'ACCEPT  all  --  anywhere  anywhere  MAC 00:11:22:33:44:55', '');
        }
        return undefined as any;
      });

      await deviceControl.allowDevice(validMacAddress);

      expect(mockExec).toHaveBeenCalledTimes(1);
      expect(mockExec).toHaveBeenCalledWith(
        expect.stringContaining(`sudo iptables -L FORWARD -v -n | grep ${validMacAddress}`),
        expect.any(Object),
        expect.any(Function)
      );
    });

    it('should handle iptables errors', async () => {
      mockExec.mockImplementation((command, options, callback) => {
        if (callback) {
          callback(new Error('iptables error') as ExecException, '', '');
        }
        return undefined as any;
      });

      await expect(deviceControl.allowDevice(validMacAddress)).rejects.toThrow('iptables error');
    });
  });

  describe('blockDevice', () => {
    it('should remove iptables rule to block device', async () => {
      mockExec.mockImplementation((command, options, callback) => {
        if (callback) {
          callback(null, '', '');
        }
        return undefined as any;
      });

      await deviceControl.blockDevice(validMacAddress);

      expect(mockExec).toHaveBeenCalledWith(
        expect.stringContaining(`sudo iptables -D FORWARD -i ${networkInterface} -m mac --mac-source ${validMacAddress} -j ACCEPT`),
        expect.any(Object),
        expect.any(Function)
      );
    });

    it('should handle iptables errors', async () => {
      mockExec.mockImplementation((command, options, callback) => {
        if (callback) {
          callback(new Error('iptables error') as ExecException, '', '');
        }
        return undefined as any;
      });

      await expect(deviceControl.blockDevice(validMacAddress)).rejects.toThrow('iptables error');
    });
  });

  describe('getDeviceStatus', () => {
    it('should return true if device is allowed', async () => {
      mockExec.mockImplementation((command, options, callback) => {
        if (callback) {
          callback(null, 'ACCEPT  all  --  anywhere  anywhere  MAC 00:11:22:33:44:55', '');
        }
        return undefined as any;
      });

      const status = await deviceControl.getDeviceStatus(validMacAddress);
      expect(status).toBe(true);
      expect(mockExec).toHaveBeenCalledWith(
        expect.stringContaining(`sudo iptables -L FORWARD -v -n | grep ${validMacAddress}`),
        expect.any(Object),
        expect.any(Function)
      );
    });

    it('should return false if device is blocked', async () => {
      mockExec.mockImplementation((command, options, callback) => {
        if (callback) {
          callback(null, '', '');
        }
        return undefined as any;
      });

      const status = await deviceControl.getDeviceStatus(validMacAddress);
      expect(status).toBe(false);
    });

    it('should handle iptables errors and return false', async () => {
      mockExec.mockImplementation((command, options, callback) => {
        if (callback) {
          callback(new Error('iptables error') as ExecException, '', '');
        }
        return undefined as any;
      });

      const status = await deviceControl.getDeviceStatus(validMacAddress);
      expect(status).toBe(false);
    });
  });

  describe('error handling', () => {
    it('should handle command execution timeouts', async () => {
      mockExec.mockImplementation((command, options, callback) => {
        if (callback) {
          const error = new Error('Command timed out') as ExecException;
          error.code = 'ETIMEDOUT';
          callback(error, '', '');
        }
        return undefined as any;
      });

      await expect(deviceControl.allowDevice(validMacAddress)).rejects.toThrow('Command timed out');
    });

    it('should handle permission denied errors', async () => {
      mockExec.mockImplementation((command, options, callback) => {
        if (callback) {
          const error = new Error('Permission denied') as ExecException;
          error.code = 'EACCES';
          callback(error, '', '');
        }
        return undefined as any;
      });

      await expect(deviceControl.allowDevice(validMacAddress)).rejects.toThrow('Permission denied');
    });
  });
}); 