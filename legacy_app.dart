import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../services/service_locator.dart';
import '../services/wallet_service.dart';
import '../services/withdrawal_service.dart';
import '../repositories/catalog_repository.dart';
import 'theme.dart';
import 'widgets/glass_card.dart';

class AppState extends ChangeNotifier {
  UserSession? session;
  WalletBalance balance = const WalletBalance(points: 0);
  List<TaskItem> tasks = [];
  List<ShopProduct> shop = [];
  List<TransactionRecord> transactions = [];
  List<WithdrawalRequest> withdrawals = [];
  VipStatus vip = const VipStatus();
  bool loading = false;
  bool earlyAccessClaimed = false;
  int completedTaskCount = 0;

  final _sl = ServiceLocator.I;

  Future<void> bootstrap() async {
    loading = true;
    notifyListeners();
    final s = await _sl.auth.currentSession();
    session = s.valueOrNull;
    if (session != null) await refreshAll();
    loading = false;
    notifyListeners();
  }

  Future<void> refreshAll() async {
    final b = await _sl.wallet.getBalance();
    if (b.isOk) balance = b.valueOrNull!;
    final t = await _sl.catalog.getTasks();
    if (t.isOk) tasks = t.valueOrNull!;
    final sh = await _sl.catalog.getShop();
    if (sh.isOk) shop = sh.valueOrNull!;
    final tx = await _sl.wallet.getTransactions();
    if (tx.isOk) transactions = tx.valueOrNull!;
    final w = await _sl.withdrawals.list();
    if (w.isOk) withdrawals = w.valueOrNull!;
    final v = await _sl.billing.getVipStatus();
    if (v.isOk) vip = v.valueOrNull!;
    completedTaskCount = tasks.where((e) => e.completed).length;
    notifyListeners();
  }

  Future<String?> login(String email, String pass) async {
    final r = await _sl.auth.login(email, pass);
    if (r.isErr) return r.errorOrNull;
    session = r.valueOrNull;
    await refreshAll();
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    await _sl.auth.logout();
    session = null;
    balance = const WalletBalance(points: 0);
    earlyAccessClaimed = false;
    notifyListeners();
  }

  Future<String?> watchTripleAds() async {
    HapticFeedback.lightImpact();
    final r = await _sl.ads.runTripleAdCycle();
    if (r.isErr) return r.errorOrNull;
    await refreshAll();
    HapticFeedback.mediumImpact();
    return null;
  }

  Future<String?> completeTask(String taskId) async {
    HapticFeedback.selectionClick();
    final r = await _sl.catalog.completeTask(taskId);
    if (r.isErr) return r.errorOrNull;
    final credit = await _sl.wallet.creditByReference(
      referenceId: 'task_' + taskId + '_' + DateTime.now().millisecondsSinceEpoch.toString(),
      reason: 'task',
    );
    if (credit.isErr) return credit.errorOrNull;
    await refreshAll();
    return null;
  }

  Future<String?> completeOfferOrSurvey(String taskId, String reason) async {
    HapticFeedback.selectionClick();
    final r = await _sl.catalog.completeTask(taskId);
    if (r.isErr) return r.errorOrNull;
    final ref = reason + '_' + taskId + '_' + DateTime.now().millisecondsSinceEpoch.toString();
    final credit = await _sl.wallet.creditByReference(referenceId: ref, reason: reason);
    if (credit.isErr) return credit.errorOrNull;
    await refreshAll();
    return null;
  }

  Future<String?> redeemShopProduct(ShopProduct product) async {
    if (product.pricePoints <= 0) return 'Geçersiz ürün fiyatı';
    if (balance.available < product.pricePoints) {
      return 'Yetersiz puan (${product.pricePoints} gerekli)';
    }
    if (product.requiresTripleAd) {
      final adErr = await watchTripleAds();
      if (adErr != null) return 'Üçlü reklam gerekli: $adErr';
      await refreshAll();
      if (balance.available < product.pricePoints) {
        return 'Reklam sonrası bakiye yetersiz';
      }
    }
    if (_sl.wallet is DemoWalletService) {
      final demo = _sl.wallet as DemoWalletService;
      final hold = await demo.hold(product.pricePoints);
      if (hold.isErr) return hold.errorOrNull;
      final fin = await demo.finalizeWithdrawal(product.pricePoints);
      if (fin.isErr) {
        await demo.releaseHold(product.pricePoints);
        return fin.errorOrNull;
      }
    }
    await refreshAll();
    HapticFeedback.mediumImpact();
    return null;
  }

  Future<String?> claimEarlyAccess() async {
    if (earlyAccessClaimed) return 'Erken erişim bonusu zaten alındı';
    final credit = await _sl.wallet.creditByReference(
      referenceId: 'early_access_' + (session?.userId ?? 'x'),
      reason: 'early_access',
    );
    if (credit.isErr) return credit.errorOrNull;
    earlyAccessClaimed = true;
    await refreshAll();
    return null;
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.loading) {
      return Scaffold(
        body: Container(
          decoration: HakTheme.spaceBg(),
          child: const Center(child: CircularProgressIndicator(color: HakTheme.neonPurple)),
        ),
      );
    }
    if (state.session == null) return const LoginScreen();
    return const HomeShell();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(text: 'demo@hakpay.app');
  final pass = TextEditingController(text: 'demo1234');
  bool busy = false;
  String? err;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: HakTheme.spaceBg(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'hakpay_logo',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/hakpay_logo.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.hexagon, size: 72, color: HakTheme.neonPurple),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('HakPay', style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: HakTheme.textPrimary)),
                const SizedBox(height: 6),
                const Text('Paradox Manga ekosistemi · Cemalcan',
                    style: TextStyle(color: HakTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 36),
                _field(email, 'E-posta', Icons.mail_outline),
                const SizedBox(height: 12),
                _field(pass, 'Şifre', Icons.lock_outline, obscure: true),
                if (err != null) ...[
                  const SizedBox(height: 12),
                  Text(err!, style: const TextStyle(color: HakTheme.danger)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() { busy = true; err = null; });
                            final e = await context.read<AppState>().login(email.text.trim(), pass.text);
                            if (mounted) setState(() { busy = false; err = e; });
                          },
                    child: busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Giriş Yap'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      style: const TextStyle(color: HakTheme.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: HakTheme.textMuted),
        prefixIcon: Icon(icon, color: HakTheme.neonPurple, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int idx = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [
      HomeDashboard(),
      TasksScreen(),
      EarnHubScreen(),
      WalletScreen(),
      ProfileScreen(),
    ];
    return Scaffold(
      body: Container(
        decoration: HakTheme.spaceBg(),
        child: pages[idx],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          setState(() => idx = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Ana Sayfa'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Görevler'),
          NavigationDestination(icon: Icon(Icons.attach_money), selectedIcon: Icon(Icons.attach_money), label: 'Kazan'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Bakiye'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

class _PageScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  const _PageScaffold({required this.title, required this.children, this.actions});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              ...?actions,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// Ana sayfa dashboard
class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final name = state.session?.displayName ?? 'Gezgin';
    final pts = state.balance.points;
    final tl = AppConfig.pointsToTl(pts);

    return _PageScaffold(
      title: 'HakPay',
      children: [
        Text('Hoş geldin, $name 👋',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Paradox Manga × Cemalcan ekosistemi',
            style: TextStyle(color: HakTheme.textMuted, fontSize: 12)),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bakiye', style: TextStyle(color: HakTheme.textMuted, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text('$pts',
                        style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: HakTheme.neonPurple)),
                    Text('≈ ${tl.toStringAsFixed(2)} TL',
                        style: const TextStyle(color: HakTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Görevler', style: TextStyle(color: HakTheme.textMuted, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text('${state.completedTaskCount}/${state.tasks.length}',
                        style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700)),
                    const Text('tamamlanan',
                        style: TextStyle(color: HakTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const SectionTitle('Hızlı Kazanç'),
        const SizedBox(height: 10),
        GlassCard(
          onTap: () async {
            final err = await state.watchTripleAds();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(err ?? 'Üçlü reklam · +${AppConfig.tripleAdCyclePoints} puan'),
              ));
            }
          },
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: HakTheme.neonBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.play_circle_fill, color: HakTheme.neonBlue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Video İzle (3’lü)', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('+${AppConfig.tripleAdCyclePoints} puan · ≈ 6 kuruş',
                        style: const TextStyle(color: HakTheme.success, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: HakTheme.textMuted),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Yaklaşan', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Paradox Manga · Yeni bölüm ve etkinlik duyuruları yakında burada.',
                  style: TextStyle(color: HakTheme.textSecondary, fontSize: 13, height: 1.4)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: HakTheme.neonMagenta.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('YAKINDA', style: TextStyle(color: HakTheme.neonMagenta, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle('Son İşlemler'),
        const SizedBox(height: 10),
        if (state.transactions.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long,
            title: 'Henüz işlem yok',
            subtitle: 'Görev tamamla veya reklam izleyerek ilk puanını kazan.',
          )
        else
          ...state.transactions.take(5).map((tx) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(tx.amount >= 0 ? Icons.check_circle : Icons.remove_circle,
                          color: tx.amount >= 0 ? HakTheme.success : HakTheme.danger, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(tx.description,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      Text(
                        '${tx.amount > 0 ? '+' : ''}${tx.amount}',
                        style: TextStyle(
                          color: tx.amount >= 0 ? HakTheme.success : HakTheme.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }
}

/// Görevler — screenshot tarzı kartlar
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  IconData _icon(String type) {
    return switch (type) {
      'survey' => Icons.assignment_turned_in,
      'offer' => Icons.sports_esports,
      'daily' => Icons.today,
      _ => Icons.star,
    };
  }

  Color _color(String type) {
    return switch (type) {
      'survey' => const Color(0xFF7E57C2),
      'offer' => const Color(0xFF26A69A),
      'daily' => const Color(0xFF42A5F5),
      _ => HakTheme.accent,
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return _PageScaffold(
      title: 'Görevler',
      children: [
        const SectionTitle('Tüm Görevler'),
        const SizedBox(height: 10),
        if (state.tasks.isEmpty)
          const EmptyState(
            icon: Icons.assignment_outlined,
            title: 'Görev bulunamadı',
            subtitle: 'Daha sonra tekrar dene veya Kazan sekmesinden başla.',
          )
        else
          ...state.tasks.map((t) {
            final c = _color(t.type);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_icon(t.type), color: c),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(t.description,
                              style: const TextStyle(color: HakTheme.textSecondary, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('+${t.rewardPoints} puan',
                              style: const TextStyle(color: HakTheme.success, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (!t.completed)
                      FilledButton(
                        onPressed: () async {
                          final err = await state.completeTask(t.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(err ?? 'Görev tamamlandı')),
                            );
                          }
                        },
                        child: const Text('Başla'),
                      )
                    else
                      const Icon(Icons.check_circle, color: HakTheme.success),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// Kazan hub — anket, video, offerwall, mağaza kısayolu
class EarnHubScreen extends StatelessWidget {
  const EarnHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pts = state.balance.points;

    return _PageScaffold(
      title: 'Kazan',
      children: [
        Row(
          children: [
            Expanded(
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bugünkü potansiyel', style: TextStyle(color: HakTheme.textMuted, fontSize: 11)),
                    const SizedBox(height: 6),
                    Text('$pts', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
                    const Text('puan', style: TextStyle(color: HakTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Offer payı', style: TextStyle(color: HakTheme.textMuted, fontSize: 11)),
                    const SizedBox(height: 6),
                    Text('%${(AppConfig.offerwallUserShare * 100).toInt()}',
                        style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: HakTheme.neonMagenta)),
                    const Text('kullanıcıya', style: TextStyle(color: HakTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const SectionTitle('Kazanma Fırsatları'),
        const SizedBox(height: 10),
        _earnTile(
          context,
          icon: Icons.assignment,
          color: const Color(0xFF7E57C2),
          title: 'Anket Tamamla',
          subtitle: '5–7 dk · Kısa anketler, ödülünü kazan.',
          reward: '+%35 pay',
          onTap: () async {
            final err = await state.completeOfferOrSurvey('t5', 'survey');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(err ?? 'Anket tamamlandı')),
              );
            }
          },
        ),
        _earnTile(
          context,
          icon: Icons.play_circle_fill,
          color: const Color(0xFF26C6DA),
          title: 'Video İzle',
          subtitle: '3’lü döngü · +${AppConfig.tripleAdCyclePoints} puan',
          reward: '+${AppConfig.tripleAdCyclePoints}p',
          onTap: () async {
            final err = await state.watchTripleAds();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(err ?? 'Reklam ödülü alındı')),
              );
            }
          },
        ),
        _earnTile(
          context,
          icon: Icons.sports_esports,
          color: const Color(0xFFFFA726),
          title: 'Oyun Oyna · Para Kazan',
          subtitle: 'Offerwall · oyun ve teklifler · %35 pay',
          reward: 'Offer',
          onTap: () async {
            final err = await state.completeOfferOrSurvey('t6', 'offerwall');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(err ?? 'Offer tamamlandı')),
              );
            }
          },
        ),
        _earnTile(
          context,
          icon: Icons.group_add,
          color: const Color(0xFFEF5350),
          title: 'Arkadaşını Davet Et',
          subtitle: 'Referral ile bonus puan kazan',
          reward: '+500p',
          onTap: () async {
            final err = await state.completeTask('t4');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(err ?? 'Davet görevi işlendi')),
              );
            }
          },
        ),
        const SizedBox(height: 16),
        const SectionTitle('Mağaza · UC'),
        const SizedBox(height: 10),
        ...state.shop.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          Text('${NumberFormat.decimalPattern().format(p.pricePoints)} puan',
                              style: const TextStyle(color: HakTheme.neonPurple, fontSize: 13)),
                          const Text('Satın almadan önce 3’lü reklam',
                              style: TextStyle(color: HakTheme.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () async {
                        final err = await state.redeemShopProduct(p);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(err ?? '${p.coinAmount} UC talebi alındı')),
                          );
                        }
                      },
                      child: const Text('Al'),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _earnTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String reward,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: const TextStyle(color: HakTheme.textSecondary, fontSize: 12)),
                  Text(reward, style: const TextStyle(color: HakTheme.success, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            FilledButton(onPressed: onTap, child: const Text('Başla')),
          ],
        ),
      ),
    );
  }
}

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final fmt = DateFormat('d MMMM yyyy · HH:mm');
    final pts = state.balance.points;
    final tl = AppConfig.pointsToTl(pts);

    return _PageScaffold(
      title: 'Cüzdanım',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF7C4DFF), Color(0xFFB388FF), Color(0xFF5C6BC0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: HakTheme.accent.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Toplam Bakiye', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Text('$pts puan',
                  style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
              Text('≈ ${tl.toStringAsFixed(2)} TL', style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _quickAction(Icons.add, 'Kazan', HakTheme.success, () {}),
            _quickAction(Icons.remove, 'Çekim', HakTheme.textMuted, null),
            _quickAction(Icons.history, 'Geçmiş', HakTheme.neonBlue, () {}),
            _quickAction(Icons.storefront, 'Mağaza', HakTheme.neonPurple, () {}),
          ],
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text('Nakit çekim · YAKINDA GELECEK',
              style: TextStyle(color: HakTheme.danger, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 20),
        const SectionTitle('Son İşlemler'),
        const SizedBox(height: 10),
        if (state.transactions.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'İşlem geçmişi boş',
            subtitle: 'İlk görevini tamamladığında burada görünecek.',
          )
        else
          ...state.transactions.take(12).map((tx) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: (tx.amount >= 0 ? HakTheme.success : HakTheme.danger).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          tx.amount >= 0 ? Icons.check : Icons.remove,
                          color: tx.amount >= 0 ? HakTheme.success : HakTheme.danger,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tx.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(fmt.format(tx.createdAt),
                                style: const TextStyle(color: HakTheme.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      Text(
                        '${tx.amount > 0 ? '+' : ''}${tx.amount}',
                        style: TextStyle(
                          color: tx.amount >= 0 ? HakTheme.success : HakTheme.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Widget _quickAction(IconData icon, String label, Color color, VoidCallback? onTap) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Icon(icon, color: color),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: HakTheme.textSecondary)),
      ],
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.session;
    final initial = (s?.displayName.isNotEmpty == true ? s!.displayName[0] : '?').toUpperCase();

    return _PageScaffold(
      title: 'Profil',
      children: [
        GlassCard(
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: HakTheme.accent,
                child: Text(initial, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              Text(s?.displayName ?? '', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
              Text(s?.email ?? '', style: const TextStyle(color: HakTheme.textMuted, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: HakTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  state.vip.tier == VipTier.none ? 'Standart Üye' : 'VIP ${state.vip.tier.name}',
                  style: const TextStyle(color: HakTheme.warning, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stat('${state.completedTaskCount}', 'Görev'),
                  _stat('${state.balance.points}', 'Puan'),
                  _stat('MVP', 'Sürüm'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _menuTile(Icons.person_outline, 'Hesap Bilgileri', () {}),
        _menuTile(Icons.payment, 'Ödeme Yöntemleri', () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nakit ödeme · YAKINDA GELECEK')),
          );
        }),
        _menuTile(Icons.lock_outline, 'Güvenlik', () {}),
        _menuTile(Icons.info_outline, 'Hakkında · Paradox Manga × Cemalcan', () {
          showAboutDialog(
            context: context,
            applicationName: 'HakPay',
            applicationVersion: '1.0.0 MVP',
            applicationLegalese: 'Geliştirici: Cemalcan\nStratejik destek: Paradox Manga',
          );
        }),
        _menuTile(Icons.help_outline, 'Destek & SSS', () {}),
        const SizedBox(height: 8),
        GlassCard(
          onTap: () => state.logout(),
          child: const Row(
            children: [
              Icon(Icons.logout, color: HakTheme.danger),
              SizedBox(width: 12),
              Text('Çıkış Yap', style: TextStyle(color: HakTheme.danger, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String v, String l) {
    return Column(
      children: [
        Text(v, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        Text(l, style: const TextStyle(color: HakTheme.textMuted, fontSize: 11)),
      ],
    );
  }

  Widget _menuTile(IconData icon, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: HakTheme.neonPurple, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500))),
            const Icon(Icons.chevron_right, color: HakTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
