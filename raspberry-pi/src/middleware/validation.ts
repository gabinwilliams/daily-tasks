import { Request, Response, NextFunction } from 'express';

const MAC_ADDRESS_REGEX = /^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/;

export const validateMacAddress = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const macAddress = req.params.macAddress || req.body.macAddress;

  if (!macAddress) {
    res.status(400).json({ error: 'MAC address is required' });
    return;
  }

  if (!MAC_ADDRESS_REGEX.test(macAddress)) {
    res.status(400).json({ error: 'Invalid MAC address' });
    return;
  }

  next();
};

export const isValidMacAddress = (mac: string): boolean => {
  return MAC_ADDRESS_REGEX.test(mac);
}; 