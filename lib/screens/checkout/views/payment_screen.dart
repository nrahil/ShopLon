import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/providers/order_provider.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/services/api_client.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pays for a pending order.
///
/// Mock provider: card details are posted straight to the PSP with the
/// attempt's client secret, then the app waits for the shop's webhook to mark
/// the order paid. Stripe: opens Stripe's hosted checkout and waits the same way.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.order});

  final OrderModel order;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

enum _Phase { form, processing, waitingForStripe }

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController(text: TestCard.all.first.number);
  final _expiry = TextEditingController(text: '12/34');
  final _cvc = TextEditingController(text: '123');

  late OrderModel _order = widget.order;
  _Phase _phase = _Phase.form;
  String? _error;
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (_order.payment == null || !_order.payment!.isOpen) {
      // e.g. payment start failed during checkout: open a new attempt.
      WidgetsBinding.instance.addPostFrameCallback((_) => _newAttempt());
    }
  }

  void _tick() {
    final left = (_order.expiresAt ?? DateTime.now()).difference(DateTime.now());
    if (mounted) setState(() => _remaining = left.isNegative ? Duration.zero : left);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _number.dispose();
    _expiry.dispose();
    _cvc.dispose();
    super.dispose();
  }

  Future<void> _newAttempt() async {
    try {
      final order = await context.read<OrderProvider>().startPayment(_order.id);
      if (mounted) setState(() => _order = order);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    final payment = _order.payment;
    if (payment == null || !payment.isOpen) return _newAttempt();
    final orders = context.read<OrderProvider>();
    setState(() {
      _phase = _Phase.processing;
      _error = null;
    });
    try {
      final parts = _expiry.text.split('/');
      await orders.confirmMockPayment(
        payment,
        cardNumber: _number.text,
        expMonth: int.parse(parts[0]),
        expYear: int.parse(parts[1]),
        cvc: _cvc.text,
      );
      await _awaitResult();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.form;
          _error = e.message;
        });
      }
    }
  }

  Future<void> _payWithStripe() async {
    final url = _order.payment?.redirectUrl;
    if (url == null) return;
    await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
    setState(() => _phase = _Phase.waitingForStripe);
    await _awaitResult(timeout: const Duration(minutes: 10));
  }

  Future<void> _awaitResult({Duration timeout = const Duration(seconds: 45)}) async {
    final orders = context.read<OrderProvider>();
    try {
      final order = await orders.waitForSettlement(_order.id, timeout: timeout);
      if (!mounted) return;
      if (order.isPaid) {
        Navigator.pushNamedAndRemoveUntil(
            context, thanksForOrderScreenRoute, (route) => route.isFirst);
        return;
      }
      final p = order.payment;
      if (order.isAwaitingPayment && p != null && p.status == 'FAILED') {
        // Declined: open a fresh attempt so the shopper can try another card.
        setState(() {
          _order = order;
          _error = p.failureMessage;
          _phase = _Phase.form;
        });
        await _newAttempt();
        return;
      }
      if (order.isAwaitingPayment) {
        // Still unconfirmed (e.g. a lost webhook). Reconciliation will settle it.
        _showAndLeave("We're still confirming your payment. Your order will update automatically.");
        return;
      }
      _showAndLeave("This order is ${order.statusLabel.toLowerCase()}.");
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.form;
          _error = e.message;
        });
      }
    }
  }

  void _showAndLeave(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    Navigator.pushNamedAndRemoveUntil(context, ordersScreenRoute, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStripe = _order.payment?.provider == 'stripe';
    final mm = _remaining.inMinutes.toString().padLeft(2, '0');
    final ss = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: const Text("Payment")),
      body: ListView(
        padding: const EdgeInsets.all(defaultPadding),
        children: [
          Container(
            padding: const EdgeInsets.all(defaultPadding),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(defaultBorderRadious),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Order ${_order.shortId}", style: theme.textTheme.titleSmall),
                    Text("\$${_order.total.toStringAsFixed(2)}",
                        style: theme.textTheme.titleLarge?.copyWith(color: primaryColor)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _remaining == Duration.zero
                            ? "Reservation expired"
                            : "Items reserved for $mm:$ss",
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: defaultPadding),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: defaultPadding),
              child: Text(_error!, style: const TextStyle(color: errorColor)),
            ),
          if (_phase != _Phase.form)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: defaultPadding * 2),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: defaultPadding),
                  Text(_phase == _Phase.processing
                      ? "Confirming your payment…"
                      : "Complete the payment in the Stripe tab. This page updates automatically."),
                ],
              ),
            )
          else if (isStripe)
            ElevatedButton.icon(
              onPressed: _order.payment?.redirectUrl == null ? null : _payWithStripe,
              icon: const Icon(Icons.open_in_new),
              label: const Text("Pay with Stripe"),
            )
          else
            _cardForm(theme),
          const SizedBox(height: defaultPadding),
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Card details go directly to the payment provider and never touch ShopLon's servers.",
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Test cards", style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final card in TestCard.all)
                ChoiceChip(
                  label: Text(card.label),
                  selected: _number.text == card.number,
                  onSelected: (_) => setState(() => _number.text = card.number),
                ),
            ],
          ),
          const SizedBox(height: defaultPadding),
          TextFormField(
            controller: _number,
            decoration: const InputDecoration(labelText: "Card number"),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
            validator: (v) {
              final digits = (v ?? '').replaceAll(' ', '');
              return digits.length < 12 || digits.length > 19 ? "Enter a valid card number" : null;
            },
          ),
          const SizedBox(height: defaultPadding),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _expiry,
                  decoration: const InputDecoration(labelText: "Expiry (MM/YY)"),
                  validator: (v) =>
                      RegExp(r'^(0[1-9]|1[0-2])/\d{2}$').hasMatch(v ?? '') ? null : "MM/YY",
                ),
              ),
              const SizedBox(width: defaultPadding),
              Expanded(
                child: TextFormField(
                  controller: _cvc,
                  decoration: const InputDecoration(labelText: "CVC"),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  validator: (v) => RegExp(r'^\d{3,4}$').hasMatch(v ?? '') ? null : "3–4 digits",
                ),
              ),
            ],
          ),
          const SizedBox(height: defaultPadding * 1.5),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _remaining == Duration.zero ? null : _pay,
              child: Text("Pay \$${_order.total.toStringAsFixed(2)}"),
            ),
          ),
        ],
      ),
    );
  }
}
