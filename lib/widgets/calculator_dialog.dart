part of '../main.dart';

// ---------------- CALCULATOR DIALOG ----------------
class _CalculatorDialog extends StatefulWidget {
  const _CalculatorDialog();

  @override
  State<_CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<_CalculatorDialog> {
  String _display = '0';
  double? _storedValue;
  String? _pendingOp;
  bool _shouldResetDisplay = false;

  void _tapNumber(String digit) {
    setState(() {
      if (_display == '0' || _shouldResetDisplay) {
        _display = digit;
        _shouldResetDisplay = false;
      } else {
        _display += digit;
      }
    });
  }

  void _tapDot() {
    setState(() {
      if (_shouldResetDisplay) {
        _display = '0.';
        _shouldResetDisplay = false;
      } else if (!_display.contains('.')) {
        _display += '.';
      }
    });
  }

  void _tapOperator(String op) {
    setState(() {
      if (_storedValue != null && _pendingOp != null && !_shouldResetDisplay) {
        _calculate();
      }
      _storedValue = double.tryParse(_display) ?? 0;
      _pendingOp = op;
      _shouldResetDisplay = true;
    });
  }

  void _calculate() {
    if (_storedValue == null || _pendingOp == null) return;
    final current = double.tryParse(_display) ?? 0;
    double result;
    switch (_pendingOp) {
      case '+':
        result = _storedValue! + current;
        break;
      case '-':
        result = _storedValue! - current;
        break;
      case '×':
        result = _storedValue! * current;
        break;
      case '÷':
        result = current == 0 ? 0 : _storedValue! / current;
        break;
      default:
        result = current;
    }
    setState(() {
      _display = result == result.roundToDouble()
          ? result.toStringAsFixed(0)
          : result.toString();
      _storedValue = null;
      _pendingOp = null;
      _shouldResetDisplay = true;
    });
  }

  void _clear() {
    setState(() {
      _display = '0';
      _storedValue = null;
      _pendingOp = null;
      _shouldResetDisplay = false;
    });
  }

  void _backspace() {
    setState(() {
      if (_display.length > 1) {
        _display = _display.substring(0, _display.length - 1);
      } else {
        _display = '0';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      // Dialog's own default insetPadding (40px each side) plus a fixed 300 content width
      // could exceed a narrow phone's actual screen width - constrain to whatever's really
      // available instead.
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr('Calculator'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AESColors.darkGreen,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: AESColors.lightGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerRight,
                child: Text(
                  _display,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AESColors.darkGrey,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _calcRow(['C', '⌫', '÷'], isTopRow: true),
              _calcRow(['7', '8', '9', '×']),
              _calcRow(['4', '5', '6', '-']),
              _calcRow(['1', '2', '3', '+']),
              _calcRow(['0', '.', '=']),
            ],
          ),
        ),
      ),
    );
  }

  Widget _calcRow(List<String> keys, {bool isTopRow = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: keys
            .map(
              (k) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _calcButton(k),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _calcButton(String key) {
    final isOperator = ['+', '-', '×', '÷', '='].contains(key);
    final isFunction = ['C', '⌫'].contains(key);

    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: () {
          if (key == 'C') {
            _clear();
          } else if (key == '⌫') {
            _backspace();
          } else if (key == '=') {
            _calculate();
          } else if (key == '.') {
            _tapDot();
          } else if (isOperator) {
            _tapOperator(key);
          } else {
            _tapNumber(key);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isOperator
              ? AESColors.primaryGreen
              : (isFunction ? AESColors.lightGrey : Colors.white),
          foregroundColor: isOperator ? Colors.white : AESColors.darkGrey,
          elevation: isOperator ? 0 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          key,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
