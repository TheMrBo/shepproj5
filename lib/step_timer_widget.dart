import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ---------------------------------------------------------------------------
/// DURATION PICKER DIALOG (Minutes & Seconds)
/// ---------------------------------------------------------------------------
class StepTimerPickerDialog extends StatefulWidget {
  final Duration? initialDuration;

  const StepTimerPickerDialog({
    super.key,
    this.initialDuration,
  });

  @override
  State<StepTimerPickerDialog> createState() => _StepTimerPickerDialogState();
}

class _StepTimerPickerDialogState extends State<StepTimerPickerDialog> {
  late int _minutes;
  late int _seconds;

  @override
  void initState() {
    super.initState();
    final init = widget.initialDuration ?? const Duration(minutes: 5);
    _minutes = init.inMinutes;
    _seconds = init.inSeconds % 60;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.timer_outlined, color: Color(0xFFEC4E6E)),
          SizedBox(width: 8),
          Text('Set Step Timer'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Attach a countdown timer to this cooking step.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPickerColumn(
                theme,
                label: 'MINUTES',
                value: _minutes,
                onIncrement: () =>
                    setState(() => _minutes = (_minutes + 1) % 100),
                onDecrement: () =>
                    setState(() => _minutes = _minutes > 0 ? _minutes - 1 : 99),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  ':',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
              _buildPickerColumn(
                theme,
                label: 'SECONDS',
                value: _seconds,
                onIncrement: () =>
                    setState(() => _seconds = (_seconds + 5) % 60),
                onDecrement: () =>
                    setState(() => _seconds = _seconds >= 5 ? _seconds - 5 : 55),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (widget.initialDuration != null)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const Duration(seconds: 0)), // Clear signal
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Clear Timer'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final dur = Duration(minutes: _minutes, seconds: _seconds);
            Navigator.pop(context, dur.inSeconds > 0 ? dur : null);
          },
          child: const Text('Save Timer'),
        ),
      ],
    );
  }

  Widget _buildPickerColumn(
    ThemeData theme, {
    required String label,
    required int value,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return Column(
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up),
          onPressed: onIncrement,
        ),
        Container(
          width: 65,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          alignment: Alignment.center,
          child: Text(
            value.toString().padLeft(2, '0'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: onDecrement,
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// EMBEDDED STEP TIMER WIDGET (`StepTimerWidget`)
/// ---------------------------------------------------------------------------
class StepTimerWidget extends StatefulWidget {
  final Duration duration;
  final String? stepLabel;

  const StepTimerWidget({
    super.key,
    required this.duration,
    this.stepLabel,
  });

  @override
  State<StepTimerWidget> createState() => _StepTimerWidgetState();
}

class _StepTimerWidgetState extends State<StepTimerWidget> {
  late int _remainingSeconds;
  Timer? _timer;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.duration.inSeconds;
  }

  @override
  void didUpdateWidget(covariant StepTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration && !_isRunning) {
      setState(() {
        _remainingSeconds = widget.duration.inSeconds;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = true;
      _isPaused = false;
      _isCompleted = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _remainingSeconds = 0;
          _isRunning = false;
          _isPaused = false;
          _isCompleted = true;
        });

        // Trigger vibration / haptic feedback when timer hits zero
        HapticFeedback.vibrate();
        HapticFeedback.heavyImpact();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = true;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = widget.duration.inSeconds;
      _isRunning = false;
      _isPaused = false;
      _isCompleted = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalSec = widget.duration.inSeconds;
    final progress = totalSec > 0 ? _remainingSeconds / totalSec : 0.0;

    final formattedTime = _formatTime(_remainingSeconds);
    final semanticStatus = _isCompleted
        ? 'Timer complete!'
        : _isRunning
            ? '$formattedTime remaining'
            : _isPaused
                ? 'Timer paused at $formattedTime'
                : 'Timer set for ${_formatTime(totalSec)}';

    return Semantics(
      container: true,
      label: 'Step cooking timer. $semanticStatus',
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isCompleted
              ? theme.colorScheme.errorContainer.withAlpha(100)
              : _isRunning
                  ? theme.colorScheme.primaryContainer.withAlpha(100)
                  : theme.colorScheme.surfaceContainerHighest.withAlpha(80),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isCompleted
                ? theme.colorScheme.error
                : _isRunning
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
            width: _isRunning || _isCompleted ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _isCompleted
                      ? Icons.notifications_active
                      : Icons.timer_outlined,
                  color: _isCompleted
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.stepLabel ?? 'Step Timer',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _isCompleted
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  formattedTime,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: _isCompleted
                        ? theme.colorScheme.error
                        : _isRunning
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Linear progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: _isCompleted
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isRunning || _isPaused || _isCompleted)
                  TextButton.icon(
                    onPressed: _resetTimer,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                const SizedBox(width: 8),
                if (!_isRunning)
                  FilledButton.icon(
                    onPressed: _startTimer,
                    icon: Icon(
                      _isPaused ? Icons.play_arrow : Icons.timer,
                      size: 18,
                    ),
                    label: Text(_isPaused ? 'Resume' : 'Start Timer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _isCompleted
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: _pauseTimer,
                    icon: const Icon(Icons.pause, size: 18),
                    label: const Text('Pause'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
