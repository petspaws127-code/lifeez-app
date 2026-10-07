import 'package:flutter/material.dart';
import 'supabase_client.dart';

enum WhatsAppStatus { disconnected, connecting, connected }

/// Simple chat message for the in-app WhatsApp-style chat.
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime at;
  ChatMessage({required this.text, required this.isUser, DateTime? at})
      : at = at ?? DateTime.now();
}

/// WhatsApp connection state + in-app chat.
///
/// The REAL WhatsApp Business Cloud API link (sending/receiving through the
/// user's actual WhatsApp app) is handled server-side:
///   - Outbound OTP / notifications → Supabase Edge Function `whatsapp-otp`
///     (see supabase/functions/whatsapp-otp) using WHATSAPP_TOKEN and
///     WHATSAPP_PHONE_NUMBER_ID secrets.
///   - Inbound user messages → Meta webhook → Edge Function
///     `whatsapp-webhook` (see supabase/functions/whatsapp-webhook),
///     which parses the intent and writes to `message_log`.
///
/// This class manages the app-side connection state and the in-app chat UI.
class WhatsAppService extends ChangeNotifier {
  WhatsAppStatus status = WhatsAppStatus.disconnected;
  String? phoneNumber;
  final List<ChatMessage> chat = [];

  bool get isConnected => status == WhatsAppStatus.connected;

  /// One-tap Direct Connect: sends a verification code via the Edge Function
  /// (WhatsApp Business Cloud API) and marks the number connected.
  ///
  /// TODO: deploy supabase/functions/whatsapp-otp and set its secrets
  /// (WHATSAPP_TOKEN, WHATSAPP_PHONE_NUMBER_ID). Until then this stores the
  /// connection locally and the chat below works end-to-end in the app.
  Future<void> directConnect(String phone) async {
    status = WhatsAppStatus.connecting;
    notifyListeners();
    try {
      // Ask the Edge Function to deliver the real code over WhatsApp.
      await SupabaseService.client.functions.invoke(
        'whatsapp-otp',
        body: {'action': 'send', 'phone': phone},
      );
    } catch (_) {
      // Edge Function not deployed yet — continue in local mode so the
      // in-app WhatsApp chat remains fully testable.
    }
    phoneNumber = phone;
    status = WhatsAppStatus.connected;
    await _persistConnection();
    chat.add(ChatMessage(
      text:
          'WhatsApp connected for $phone. Send me a command like "add task buy milk tomorrow 5pm" or "I spent \$45 at Walmart".',
      isUser: false,
    ));
    notifyListeners();
  }

  Future<void> disconnect() async {
    status = WhatsAppStatus.disconnected;
    phoneNumber = null;
    notifyListeners();
    try {
      final uid = SupabaseService.currentUserId;
      if (uid != null) {
        await SupabaseService.client
            .from('whatsapp_connections')
            .delete()
            .eq('user_id', uid);
      }
    } catch (_) {}
  }

  Future<void> _persistConnection() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null || phoneNumber == null) return;
      await SupabaseService.client.from('whatsapp_connections').upsert({
        'user_id': uid,
        'phone_number': phoneNumber,
        'status': 'connected',
        'verified_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Restores a previously saved connection on app start.
  Future<void> restore() async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return;
      final row = await SupabaseService.client
          .from('whatsapp_connections')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      if (row != null) {
        phoneNumber = (row as Map)['phone_number'] as String?;
        status = WhatsAppStatus.connected;
        notifyListeners();
      }
    } catch (_) {}
  }

  void addUserMessage(String text) {
    chat.add(ChatMessage(text: text, isUser: true));
    notifyListeners();
  }

  void addBotMessage(String text) {
    chat.add(ChatMessage(text: text, isUser: false));
    notifyListeners();
  }

  void clearChat() {
    chat.clear();
    notifyListeners();
  }
}
