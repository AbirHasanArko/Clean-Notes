import 'package:flutter/material.dart';

import '../models/subscriber.dart';
import '../services/notes_service.dart';
import '../services/subscription_service.dart';
import 'login_screen.dart';
import 'notes_list_screen.dart';
import 'subscription_success_screen.dart';

/// Root gate that decides between the subscription flow and the notes
/// app on every cold start.
///
/// - **First launch / cleared prefs**: render [LoginScreen] (hard gate —
///   no notes reachable until verified).
/// - **Has stored subscriber**: re-validate via
///   `SubscriptionService.verifySubscriber`; if still valid, swap to
///   [NotesListScreen]. If the API says invalid (or no signal), fall
///   back to [LoginScreen].
class SubscriptionGate extends StatefulWidget {
  const SubscriptionGate({
    required this.subscriptionService,
    required this.notesService,
    super.key,
  });

  final SubscriptionService subscriptionService;
  final NotesService notesService;

  @override
  State<SubscriptionGate> createState() => SubscriptionGateState();
}

/// Exposed so the notes AppBar can re-mount the gate after logout.
class SubscriptionGateState extends State<SubscriptionGate> {
  bool _bootstrapping = true;
  Subscriber? _verified;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final stored = await widget.subscriptionService.loadStored();
    if (!mounted) return;

    if (stored == null) {
      setState(() {
        _bootstrapping = false;
        _verified = null;
      });
      return;
    }

    final stillValid =
        await widget.subscriptionService.verifySubscriber(stored.subscriberId);
    if (!mounted) return;

    setState(() {
      _bootstrapping = false;
      _verified = stillValid ? stored : null;
    });
  }

  /// Re-runs the bootstrap. Called by the notes AppBar after logout.
  Future<void> refreshAfterLogout() async {
    setState(() {
      _bootstrapping = true;
      _verified = null;
    });
    await _bootstrap();
  }

  Future<void> _onVerified(Subscriber subscriber) async {
    if (!mounted) return;

    // Update gate state FIRST so that when the success screen pops back
    // to us, our build() returns NotesListScreen directly. This is what
    // makes "tap continue -> go to notes" work without re-pushing routes.
    setState(() => _verified = subscriber);

    // Push the success screen on top. Tapping "Continue" will pop it,
    // revealing the gate which now renders NotesListScreen.
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SubscriptionSuccessScreen(
          subscriber: subscriber,
          onContinue: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapping) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_verified != null) {
      return NotesListScreen(
        service: widget.notesService,
        subscriptionService: widget.subscriptionService,
        onLogout: refreshAfterLogout,
      );
    }

    return LoginScreen(
      subscriptionService: widget.subscriptionService,
      onVerified: _onVerified,
    );
  }
}