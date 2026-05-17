import 'package:flutter/material.dart';
import 'package:android_manager/models/device_info.dart';

class DeviceInfoCard extends StatelessWidget {
  final DeviceInfo device;
  final bool isSelected;
  final VoidCallback onTap;

  const DeviceInfoCard({
    super.key,
    required this.device,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.phone_android, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      device.model.isNotEmpty ? device.model : device.serial,
                      style: Theme.of(context).textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (device.batteryLevel.isNotEmpty)
                    _buildBattery(context),
                ],
              ),
              const SizedBox(height: 8),
              _infoRow(context, 'Android', device.androidVersion),
              if (device.storageUsed.isNotEmpty)
                _infoRow(context, '存储', '${device.storageUsed} / ${device.storageTotal}'),
              if (device.screenResolution.isNotEmpty)
                _infoRow(context, '分辨率', device.screenResolution),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBattery(BuildContext context) {
    final level = int.tryParse(device.batteryLevel) ?? 0;
    final isCharging = device.batteryStatus == 'Charging';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isCharging ? Icons.battery_charging_full : Icons.battery_std,
          size: 16,
          color: level < 20 ? Colors.red : null,
        ),
        Text('$level%', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
          ),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
