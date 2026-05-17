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
  bool _showInstallGuide = false;

  // 安装状态
  final Map<String, bool> _installing = {};
  final Map<String, String> _installLog = {};

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
      // 全部必须工具就绪，延迟后进入主界面
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) widget.onReady();
    } else {
      setState(() => _showInstallGuide = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF0F4FF);
    final cardColor = isDark ? const Color(0xFF252542) : Colors.white;

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

                // 底部操作区
                if (!_checking) ...[
                  const SizedBox(height: 32),
                  if (_showInstallGuide)
                    _buildInstallGuide(theme, cardColor)
                  else
                    _buildEnterButton(theme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItem(ToolCheckItem item, ThemeData theme, Color cardColor) {
    final iconColor = item.checking
        ? Colors.grey
        : item.available
            ? Colors.green
            : item.required
                ? Colors.red
                : Colors.orange;

    final icon = item.checking
        ? SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: iconColor),
          )
        : Icon(
            item.available ? Icons.check_circle : (item.required ? Icons.cancel : Icons.warning),
            color: iconColor, size: 20,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: iconColor.withValues(alpha: 0.3), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(item.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (item.required) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('必须', style: TextStyle(fontSize: 10, color: Colors.red)),
                          ),
                        ] else ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('可选', style: TextStyle(fontSize: 10, color: Colors.orange)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(item.description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              icon,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstallGuide(ThemeData theme, Color cardColor) {
    final missing = _items.where((i) => !i.available).toList();
    final allRequiredReady = _items.where((i) => i.required).every((i) => i.available);

    return Column(
      children: [
        // 缺失工具的安装卡片
        ...missing.map((item) => _buildInstallCard(item, theme, cardColor)),
        const SizedBox(height: 16),
        // 跳过按钮（所有必须工具就绪时可用）
        if (allRequiredReady)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onReady,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('进入应用'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '请先安装必须的工具 (ADB) 后再继续',
              style: TextStyle(color: Colors.red[400], fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _buildInstallCard(ToolCheckItem item, ThemeData theme, Color cardColor) {
    final isInstalling = _installing[item.id] == true;
    final log = _installLog[item.id] ?? '';

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
                Text(item.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('安装 ${item.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (item.installHint != null)
                        Text(item.installHint!, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: 'monospace')),
                    ],
                  ),
                ),
                if (!isInstalling && item.installHint == null)
                  Text('请手动安装', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                if (!isInstalling && item.installHint != null)
                  FilledButton.tonal(
                    onPressed: () => _installTool(item),
                    child: const Text('安装'),
                  ),
                if (isInstalling)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            if (log.isNotEmpty) ...[
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
          ],
        ),
      ),
    );
  }

  Future<void> _installTool(ToolCheckItem item) async {
    setState(() {
      _installing[item.id] = true;
      _installLog[item.id] = '';
    });

    final logBuffer = StringBuffer();
    await for (final line in widget.adb.installTool(item.id)) {
      logBuffer.write(line);
      if (mounted) {
        setState(() => _installLog[item.id] = logBuffer.toString());
      }
    }

    if (!mounted) return;

    // 重新检测该工具
    await _checker.recheck(item, (items) {
      if (mounted) setState(() => _items = items);
    }, _items);

    setState(() {
      _installing[item.id] = false;
    });

    // 检查是否所有必须工具都就绪
    final allRequiredReady = _items.where((i) => i.required).every((i) => i.available);
    final allReady = _items.every((i) => i.available);

    if (allReady) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) widget.onReady();
    } else if (allRequiredReady) {
      setState(() {}); // 更新显示跳过按钮
    }
  }

  Widget _buildEnterButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: widget.onReady,
        icon: const Icon(Icons.arrow_forward),
        label: const Text('进入应用'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
