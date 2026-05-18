import 'dart:async';
import 'package:flutter/material.dart';
import 'package:android_manager/services/adb_service.dart';
import 'package:android_manager/services/startup_checker.dart';

class SplashView extends StatefulWidget {
  final AdbService adb;
  final VoidCallback onReady;

  const SplashView({super.key, required this.adb, required this.onReady});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with SingleTickerProviderStateMixin {
  late StartupChecker _checker;
  List<ToolCheckItem> _items = [];
  bool _checking = true;

  // 安装状态
  final Map<String, _InstallState> _installStates = {};

  late AnimationController _logoController;
  late Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();
    _checker = StartupChecker(widget.adb);

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoController.forward();

    _runCheck();
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _runCheck() async {
    final result = await _checker.checkAll((items) {
      if (mounted) setState(() => _items = items);
    });

    if (!mounted) return;

    setState(() {
      _checking = false;
      _items = result.items;
    });

    if (result.allRequiredReady) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) widget.onReady();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF0F4FF);
    final cardColor = isDark ? const Color(0xFF252542) : Colors.white;

    final missingItems = _items.where((i) => i.status != ToolStatus.available).toList();
    final allReady = _items.every((i) => i.status == ToolStatus.available);

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                ScaleTransition(
                  scale: _logoScale,
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4267E8).withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset('assets/icon.png', fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('DroidLink', style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      )),
                      const SizedBox(height: 4),
                      Text('Android 设备管理工具', style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white54 : Colors.black45,
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // 检测结果列表
                ..._items.map((item) => _buildCheckItem(item, theme, cardColor)),

                // 全部就绪 → 自动进入
                if (!_checking && allReady) ...[
                  const SizedBox(height: 24),
                  const Text('所有工具已就绪', style: TextStyle(color: Colors.green, fontSize: 14)),
                ],

                // 有缺失 → 安装引导
                if (!_checking && missingItems.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildInstallSection(missingItems, theme, cardColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItem(ToolCheckItem item, ThemeData theme, Color cardColor) {
    final statusColor = _statusColor(item);
    final statusIcon = _statusIcon(item);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: statusColor.withValues(alpha: 0.3), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(IconData(item.iconCodePoint, fontFamily: 'MaterialIcons'), size: 20, color: statusColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(item.description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              statusIcon,
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(ToolCheckItem item) {
    switch (item.status) {
      case ToolStatus.available: return Colors.green;
      case ToolStatus.missing: return Colors.red;
      case ToolStatus.checking: return Colors.grey;
      case ToolStatus.pending: return Colors.grey;
    }
  }

  Widget _statusIcon(ToolCheckItem item) {
    switch (item.status) {
      case ToolStatus.checking:
        return SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[400]),
        );
      case ToolStatus.available:
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case ToolStatus.missing:
        return const Icon(Icons.cancel, color: Colors.red, size: 20);
      case ToolStatus.pending:
        return Icon(Icons.circle_outlined, color: Colors.grey[300], size: 20);
    }
  }

  Widget _buildInstallSection(List<ToolCheckItem> missingItems, ThemeData theme, Color cardColor) {
    final allRequiredReady = _items.where((i) => i.required).every((i) => i.status == ToolStatus.available);

    return Column(
      children: [
        for (final item in missingItems) _buildInstallCard(item, cardColor),
        if (allRequiredReady) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onReady,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('跳过，直接进入'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInstallCard(ToolCheckItem item, Color cardColor) {
    final state = _installStates[item.id];
    final isInstalling = state?.installing == true;
    final log = state?.log ?? '';
    final hasError = state?.error == true;

    return Card(
      color: cardColor,
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(IconData(item.iconCodePoint, fontFamily: 'MaterialIcons'), size: 22, color: Colors.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isInstalling ? '正在安装 ${item.name}...' : hasError ? '${item.name} 安装失败' : '安装 ${item.name}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: hasError ? Colors.red : null,
                    ),
                  ),
                ),
                if (!isInstalling)
                  hasError
                      ? FilledButton.tonal(
                          onPressed: () => _installTool(item),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.refresh, size: 18),
                            SizedBox(width: 6),
                            Text('重试'),
                          ]),
                        )
                      : FilledButton.tonal(
                          onPressed: () => _installTool(item),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.download, size: 18),
                            SizedBox(width: 6),
                            Text('安装'),
                          ]),
                        ),
                if (isInstalling)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            if (isInstalling || log.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(log, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                ),
              ),
            ],
            if (isInstalling) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _installTool(ToolCheckItem item) async {
    setState(() {
      _installStates[item.id] = _InstallState();
    });

    final logBuffer = StringBuffer();
    Stream<InstallEvent> eventStream;

    if (item.id == 'homebrew') {
      eventStream = widget.adb.installHomebrew();
    } else {
      eventStream = widget.adb.installTool(item.id);
    }

    await for (final event in eventStream) {
      if (!mounted) return;
      switch (event.type) {
        case InstallEventType.log:
          logBuffer.write(event.message);
          setState(() {
            _installStates[item.id] = _InstallState(
              installing: true,
              log: logBuffer.toString(),
            );
          });
        case InstallEventType.success:
          logBuffer.write(event.message);
          setState(() {
            _installStates[item.id] = _InstallState(
              log: logBuffer.toString(),
            );
          });
        case InstallEventType.error:
          logBuffer.write(event.message);
          setState(() {
            _installStates[item.id] = _InstallState(
              log: logBuffer.toString(),
              error: true,
            );
          });
      }
    }

    if (!mounted) return;

    // 重新检测
    await _checker.recheck(item, (items) {
      if (mounted) setState(() => _items = items);
    }, _items);

    // 如果安装成功（状态变为 available），移除安装状态
    if (item.status == ToolStatus.available) {
      setState(() => _installStates.remove(item.id));
    }

    // 全部就绪 → 进入
    if (_items.every((i) => i.status == ToolStatus.available)) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) widget.onReady();
    }
  }
}

class _InstallState {
  final bool installing;
  final String log;
  final bool error;

  _InstallState({this.installing = true, this.log = '', this.error = false});
}
