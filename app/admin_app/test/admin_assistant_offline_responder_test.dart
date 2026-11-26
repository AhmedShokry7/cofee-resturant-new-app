import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/core/auth/admin_role_scope.dart';
import 'package:admin_app/core/auth/admin_permission_scope.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_business_data.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_customer_snapshot.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_offline_responder.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_repository.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_live_data_repository.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_operational_read_repository.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_recent_order.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_item.dart';
import 'package:admin_app/features/inventory/domain/entities/admin_inventory_metrics.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon_metrics.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.arabic));

  group('offline conversation understanding', () {
    final cases = <({String input, AdminAssistantOfflineIntent intent})>[
      // Greetings and social turns, including dialect and spelling variants.
      (input: 'السلام عليكم', intent: AdminAssistantOfflineIntent.greeting),
      (input: 'اهلا بيك', intent: AdminAssistantOfflineIntent.greeting),
      (input: 'أهلاً', intent: AdminAssistantOfflineIntent.greeting),
      (input: 'ازيك يا مساعد', intent: AdminAssistantOfflineIntent.greeting),
      (input: 'صباح الخير', intent: AdminAssistantOfflineIntent.greeting),
      (input: 'مساء الخير', intent: AdminAssistantOfflineIntent.greeting),
      (input: 'hello there', intent: AdminAssistantOfflineIntent.greeting),
      (input: 'Hi!', intent: AdminAssistantOfflineIntent.greeting),
      (input: 'thanks', intent: AdminAssistantOfflineIntent.thanks),
      (input: 'شكرًا يا فندم', intent: AdminAssistantOfflineIntent.thanks),
      (input: 'متشكر جدا', intent: AdminAssistantOfflineIntent.thanks),
      (input: 'تسلم ايدك', intent: AdminAssistantOfflineIntent.thanks),

      // Drink comparisons: Egyptian, Gulf, transliterated, and misspelled.
      (
        input: 'ايه الفرق بين اللاتيه والكابتشينو؟',
        intent: AdminAssistantOfflineIntent.compareDrinks,
      ),
      (
        input: 'إيه الفرق ما بين لاتيه وكابتشينو',
        intent: AdminAssistantOfflineIntent.compareDrinks,
      ),
      (
        input: 'اللاتيه والكبتشينو مين احسن',
        intent: AdminAssistantOfflineIntent.compareDrinks,
      ),
      (
        input: 'عاوز اقارن اللاتي بالكابوتشينو',
        intent: AdminAssistantOfflineIntent.compareDrinks,
      ),
      (
        input: 'اي الفرق ما بين اللاتيه والكباتشينو',
        intent: AdminAssistantOfflineIntent.compareDrinks,
      ),
      (
        input: 'قارن بين موكا ولاتيه',
        intent: AdminAssistantOfflineIntent.compareDrinks,
      ),
      (
        input: 'Compare latte vs cappuccino',
        intent: AdminAssistantOfflineIntent.compareDrinks,
      ),
      (
        input: 'What is the diffrence between latte and capuccino?',
        intent: AdminAssistantOfflineIntent.compareDrinks,
      ),
      (
        input: 'Which tastes stronger, latte or cappuchino?',
        intent: AdminAssistantOfflineIntent.compareDrinks,
      ),
      (
        input: 'arabica versus robusta',
        intent: AdminAssistantOfflineIntent.compareDrinks,
      ),
      (
        input: 'فرق الارابيكا والروبوستا',
        intent: AdminAssistantOfflineIntent.compareDrinks,
      ),
      (
        input: 'الفرق بين الآيس كوفي والكولد برو',
        intent: AdminAssistantOfflineIntent.compareDrinks,
      ),
      (
        input: 'Compare V60 and cold brew',
        intent: AdminAssistantOfflineIntent.compareDrinks,
      ),

      // Copywriting requests; missing data should be requested, not invented.
      (
        input: 'اكتب وصف جذاب لمنتج جديد',
        intent: AdminAssistantOfflineIntent.productCopy,
      ),
      (
        input: 'اكتبلي وصف للاتيه',
        intent: AdminAssistantOfflineIntent.productCopy,
      ),
      (
        input: 'محتاج كابشن لموكا كراميل',
        intent: AdminAssistantOfflineIntent.productCopy,
      ),
      (
        input: 'اعمل اعلان للكابتشينو',
        intent: AdminAssistantOfflineIntent.productCopy,
      ),
      (
        input: 'صيغ وصف منتج بحليب الشوفان',
        intent: AdminAssistantOfflineIntent.productCopy,
      ),
      (
        input: 'Write a product description',
        intent: AdminAssistantOfflineIntent.productCopy,
      ),
      (
        input: 'Write product copy for iced latte with oat milk',
        intent: AdminAssistantOfflineIntent.productCopy,
      ),
      (
        input: 'Create a caption for caramel mocha',
        intent: AdminAssistantOfflineIntent.productCopy,
      ),

      // Recommendations gather preferences but do not claim a menu item exists.
      (
        input: 'رشحلي حاجة ساقعة',
        intent: AdminAssistantOfflineIntent.recommendation,
      ),
      (
        input: 'تنصحني بمشروب قهوة قوي؟',
        intent: AdminAssistantOfflineIntent.recommendation,
      ),
      (
        input: 'عايز حاجة تصحصحني',
        intent: AdminAssistantOfflineIntent.recommendation,
      ),
      (
        input: 'ابغى شي بارد',
        intent: AdminAssistantOfflineIntent.recommendation,
      ),
      (
        input: 'Recommend a drink',
        intent: AdminAssistantOfflineIntent.recommendation,
      ),
      (
        input: 'What should I drink?',
        intent: AdminAssistantOfflineIntent.recommendation,
      ),

      // Live business facts must never be fabricated by the offline path.
      (
        input: 'كم مبيعات اليوم؟',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),
      (
        input: 'قارن مبيعات الأسبوع ده بالأسبوع اللي فات',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),
      (
        input: 'ايه ايرادات الشهر',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),
      (
        input: 'ما اكثر خمس منتجات مبيعا',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),
      (
        input: 'active orders right now',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),
      (
        input: 'ملخص الخصومات والكوبونات',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),
      (
        input: 'How many coupon redemptions?',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),
      (
        input: 'ما المواد الخام منخفضة المخزون؟',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),
      (
        input: 'How many new customers this month?',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),
      (
        input: 'ايه اكتر منتجات مبيعا الاسبوع ده',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),
      (
        input: 'المنتج ده سعره كام؟',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),
      (
        input: 'هل اللاتيه متاح في الفرع؟',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),
      (
        input: 'كم طلب عندنا النهاردة',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),
      (
        input: 'اعرض الطلبات المتأخرة',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),
      (
        input: 'ايه المنتجات اللي قربت تخلص من المخزون',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),
      (
        input: 'عدد الحجوزات بكرة كام',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),
      (
        input: 'How much did we sell this week?',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),
      (
        input: 'Show low stock items',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),
      (
        input: 'What is the price of latte?',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),
      (
        input: 'List overdue orders',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),
      (
        input: 'Top selling products this month',
        intent: AdminAssistantOfflineIntent.liveBusinessData,
      ),

      // Stable coffee knowledge, including common misspellings.
      (
        input: 'يعني ايه اسبرسو',
        intent: AdminAssistantOfflineIntent.cafeKnowledge,
      ),
      (
        input: 'ايه هو الاسبريسو؟',
        intent: AdminAssistantOfflineIntent.cafeKnowledge,
      ),
      (
        input: 'ما الفرق بين القهوة المثلجة والكولد برو',
        intent: AdminAssistantOfflineIntent.compareDrinks,
      ),
      (
        input: 'طريقة تحضير V60',
        intent: AdminAssistantOfflineIntent.cafeKnowledge,
      ),
      (
        input: 'ازاي اعمل فرنش برس',
        intent: AdminAssistantOfflineIntent.cafeKnowledge,
      ),
      (
        input: 'What is an aeropress?',
        intent: AdminAssistantOfflineIntent.cafeKnowledge,
      ),
      (
        input: 'What is a flat white?',
        intent: AdminAssistantOfflineIntent.cafeKnowledge,
      ),
      (
        input: 'يعني ايه كورتادو',
        intent: AdminAssistantOfflineIntent.cafeKnowledge,
      ),
      (
        input: 'What is a macchiato?',
        intent: AdminAssistantOfflineIntent.cafeKnowledge,
      ),
      (
        input: 'ما هي الموكا',
        intent: AdminAssistantOfflineIntent.cafeKnowledge,
      ),
      (
        input: 'هل الديكاف خالي من الكافيين تماما؟',
        intent: AdminAssistantOfflineIntent.cafeKnowledge,
      ),
      (
        input: 'Does decaf still have caffeine?',
        intent: AdminAssistantOfflineIntent.cafeKnowledge,
      ),
      (
        input: 'ايه بدائل اللبن النباتي',
        intent: AdminAssistantOfflineIntent.cafeKnowledge,
      ),
      (
        input: 'هل المنتج فيه مسببات حساسية؟',
        intent: AdminAssistantOfflineIntent.cafeKnowledge,
      ),
      (
        input: 'Why does espresso have crema?',
        intent: AdminAssistantOfflineIntent.cafeKnowledge,
      ),
      (
        input: 'How do I make a pour over coffee?',
        intent: AdminAssistantOfflineIntent.cafeKnowledge,
      ),
      (
        input: 'What is the difference between arabica and robusta?',
        intent: AdminAssistantOfflineIntent.compareDrinks,
      ),

      // Missing or unclear subject.
      (
        input: 'ممكن تساعدني في حاجة؟',
        intent: AdminAssistantOfflineIntent.clarify,
      ),
      (input: 'والتاني؟', intent: AdminAssistantOfflineIntent.clarify),
      (
        input: 'Can you help with that?',
        intent: AdminAssistantOfflineIntent.clarify,
      ),
      (input: 'اعمل كده', intent: AdminAssistantOfflineIntent.clarify),
    ];

    test('classifies ${cases.length} noisy sample conversations', () {
      for (final sample in cases) {
        final result = AdminAssistantOfflineResponder.understand(sample.input);
        expect(
          result.intent,
          sample.intent,
          reason:
              'Input: "${sample.input}" normalized as "${result.normalizedText}"; entities=${result.entities}',
        );
      }
    });

    test('routes product access and order lookup to live business tools', () {
      final products = AdminAssistantOfflineResponder.understand(
        'انت عندك وصول على المنتجات كلها؟',
      );
      expect(products.intent, AdminAssistantOfflineIntent.liveBusinessData);
      expect(products.liveDataKind, 'product_catalog');

      final orders = AdminAssistantOfflineResponder.understand(
        'حالة الطلب POS-2026-000123',
      );
      expect(orders.intent, AdminAssistantOfflineIntent.liveBusinessData);
      expect(orders.liveDataKind, 'order_lookup');

      final copy = AdminAssistantOfflineResponder.understand(
        'اكتب وصف جذاب للاتيه',
      );
      expect(copy.intent, AdminAssistantOfflineIntent.productCopy);
    });

    test('routes operational questions only to grounded aggregate tools', () {
      const cases = <({String query, String kind})>[
        (query: 'توزيع حالات الطلب', kind: 'order_metrics'),
        (query: 'قارن أداء الفروع', kind: 'order_metrics'),
        (query: 'ملخص المدفوعات والفواتير', kind: 'payment_metrics'),
        (query: 'كم حجز اليوم والطاولات المتاحة؟', kind: 'dining_summary'),
        (query: 'اعرض حركات المخزون', kind: 'inventory_movements'),
        (
          query: 'أداء التصنيفات هذا الشهر',
          kind: 'unsupported_category_performance',
        ),
        (query: 'ما عدد الطلبات المتأخرة؟', kind: 'unsupported_late_orders'),
      ];
      for (final sample in cases) {
        final result = AdminAssistantOfflineResponder.understand(sample.query);
        expect(result.intent, AdminAssistantOfflineIntent.liveBusinessData);
        expect(result.liveDataKind, sample.kind, reason: sample.query);
      }
    });

    test(
      'answers order analytics with the scoped aggregate and no profit claim',
      () async {
        final businessData = AdminAssistantBusinessData(
          kind: 'orders',
          status: AdminAssistantDataStatus.ready,
          operationalRead: const AdminAssistantOperationalRead(
            kind: 'orders',
            status: AdminAssistantOperationalReadStatus.ready,
            data: {
              'from': '2026-11-01T00:00:00Z',
              'until': '2026-11-25T00:00:00Z',
              'orders': 12,
              'cancelled_orders': 2,
              'completed_orders': 8,
              'average_completed_minutes': 14.5,
              'status_counts': [
                {'status': 'completed', 'orders': 8},
                {'status': 'cancelled', 'orders': 2},
              ],
              'order_totals_by_currency': [
                {'currency_code': 'SAR', 'orders': 10, 'order_total': 360.0},
              ],
              'branch_comparison': [],
            },
          ),
        );
        final responder = AdminAssistantOfflineResponder(
          SupabaseClient('https://offline.test', 'public-test-key'),
        );

        final reply = await responder.reply(
          'توزيع حالات الطلب',
          businessData: businessData,
        );

        expect(reply, contains('12 طلبًا'));
        expect(reply, contains('ملغي: 2'));
        expect(reply, contains('14.5 دقيقة'));
        expect(reply, contains('ليست أرباحًا'));
      },
    );

    test('detects explicit order creation without confusing analytics', () {
      expect(
        AdminAssistantOfflineResponder.asksToCreateOrder(
          'اعمل طلب للعميل أحمد',
        ),
        isTrue,
      );
      expect(
        AdminAssistantOfflineResponder.asksToCreateOrder(
          'Create an order for customer Ahmed',
        ),
        isTrue,
      );
      expect(
        AdminAssistantOfflineResponder.asksToCreateOrder('كم طلب اتعمل اليوم؟'),
        isFalse,
      );
    });

    test(
      'classifies thousands of generated metric and period combinations',
      () {
        const openings = [
          'قولي',
          'ممكن أعرف',
          'عايز أعرف',
          'احسبلي',
          'لو سمحت وضح',
          'show me',
          'please tell me',
          'can you calculate',
          'what are',
        ];
        const metrics = [
          'المبيعات',
          'الإيرادات',
          'عدد الطلبات',
          'متوسط الطلب',
          'المخزون',
          'sales',
          'revenue',
          'order count',
          'average order',
          'inventory',
          'مبعات',
          'ايردات',
          'ordres',
          'reveune',
          'avrage orders',
        ];
        const periods = [
          'اليوم',
          'امبارح',
          'هذا الأسبوع',
          'من أول الشهر',
          'الشهر الحالي',
          'today',
          'yesterday',
          'this week',
          'last week',
          'this month',
        ];
        const endings = ['', '؟', ' بالأرقام'];
        var count = 0;
        for (final opening in openings) {
          for (final metric in metrics) {
            for (final period in periods) {
              for (final ending in endings) {
                final input = '$opening $metric $period$ending';
                final analysis = AdminAssistantOfflineResponder.understand(
                  input,
                );
                expect(
                  analysis.intent,
                  AdminAssistantOfflineIntent.liveBusinessData,
                  reason: 'Generated query: $input',
                );
                count++;
              }
            }
          }
        }
        expect(count, 4050);
      },
    );

    test('carries a short month-start correction into the prior metric', () {
      final resolved = AdminAssistantOfflineResponder.contextualizeQuery(
        'من أول الشهر',
        const [
          {'role': 'user', 'content': 'متوسط المبيعات اليوم'},
          {'role': 'assistant', 'content': 'متوسط الطلب اليوم 0 ريال.'},
        ],
      );
      expect(resolved, contains('متوسط المبيعات اليوم'));
      expect(resolved, contains('من أول الشهر'));
      expect(
        AdminAssistantOfflineResponder.understand(resolved).intent,
        AdminAssistantOfflineIntent.liveBusinessData,
      );
    });

    test('recognizes common Arabic and English business-data typos', () {
      const noisyQueries = [
        'مبعات النهارده',
        'مبيات هذا الشهر',
        'مبيعاات الاسبوع',
        'ايردات امبارح',
        'ايرادت الشهر الحالي',
        'How many ordres today?',
        'Show reveune this month',
        'What is the avrage order this week?',
        'sales this week please',
        'salez today',
      ];
      for (final query in noisyQueries) {
        expect(
          AdminAssistantOfflineResponder.understand(query).intent,
          AdminAssistantOfflineIntent.liveBusinessData,
          reason: 'Noisy query: $query',
        );
      }
    });

    test('detects response tone without changing the recognized intent', () {
      expect(
        AdminAssistantOfflineResponder.detectMood('النظام مش شغال وده غلط'),
        AdminAssistantMood.frustrated,
      );
      expect(
        AdminAssistantOfflineResponder.detectMood('محتاج التقرير حالًا بسرعة'),
        AdminAssistantMood.urgent,
      );
      expect(
        AdminAssistantOfflineResponder.detectMood('مش فاهم الأرقام دي اشرحها'),
        AdminAssistantMood.confused,
      );
      expect(
        AdminAssistantOfflineResponder.detectMood('ممتاز شكرًا جدًا'),
        AdminAssistantMood.positive,
      );
    });
  });

  group('offline grounded response', () {
    final responder = AdminAssistantOfflineResponder(
      SupabaseClient('https://offline.test', 'public-test-key'),
    );

    test('answers a typo-heavy latte/cappuccino comparison locally', () async {
      final answer = await responder.reply('ايه الفرق بين اللاتيه والكبتشينو؟');
      expect(answer, contains('اللاتيه'));
      expect(answer, contains('الكابتشينو'));
      expect(answer, contains('وصفة الكافيه'));
    });

    test('asks for missing ingredients before writing product copy', () async {
      final answer = await responder.reply('اكتب وصف جذاب لمنتج جديد');
      expect(answer, contains('مكوناته الأساسية'));
      expect(answer, contains('من غير ما أضيف مكونات'));
    });

    test('writes cautious copy when the product is known', () async {
      final answer = await responder.reply(
        'اكتب وصف للاتيه المثلج بحليب الشوفان',
      );
      expect(answer, contains('اللاتيه'));
      expect(answer, contains('بحليب الشوفان'));
      expect(answer, contains('تأكد من مطابقة المكونات'));
    });

    test('refuses to invent live sales figures', () async {
      final answer = await responder.reply('كم مبيعات اليوم؟');
      expect(answer, contains('لم أتمكن من جلب'));
      expect(answer, isNot(contains('ريال')));
    });

    test('resolves a short follow-up from the prior turn', () async {
      final answer = await responder.reply(
        'طيب والتاني؟',
        history: const [
          {'role': 'user', 'content': 'Compare latte and cappuccino'},
          {'role': 'assistant', 'content': 'They are both espresso drinks.'},
        ],
      );
      expect(answer, contains('الكابتشينو'));
      expect(answer, contains('اللاتيه'));
    });

    test('uses staff first name naturally in a greeting', () async {
      final answer = await responder.reply(
        'السلام عليكم',
        assistantName: 'أحمد علي',
      );
      expect(answer, contains('أهلًا يا أحمد'));
      expect(answer, isNot(contains('علي')));
    });

    test(
      'answers customer points and purchase history without identifiers',
      () async {
        final answer = await responder.reply(
          'رصيد نقاط أحمد وآخر طلباته، اشترى إيه؟',
          businessData: AdminAssistantBusinessData(
            kind: 'customer_history_and_loyalty',
            status: AdminAssistantDataStatus.ready,
            customer: AdminAssistantCustomerSnapshot(
              canReadCustomerHistory: true,
              canReadLoyalty: true,
              customerName: 'أحمد علي',
              orderCount: 4,
              totalSpent: 230,
              lastOrderAt: DateTime.utc(2026, 11, 20),
              pointsBalance: 75,
              lifetimePoints: 120,
              orders: [
                AdminAssistantCustomerOrder(
                  date: DateTime.utc(2026, 11, 20),
                  status: 'delivered',
                  total: 60,
                  branchName: 'فرع وسط البلد',
                  items: ['لاتيه × 2'],
                ),
              ],
            ),
          ),
        );
        expect(answer, contains('75 نقطة'));
        expect(answer, contains('4 طلب'));
        expect(answer, contains('لاتيه × 2'));
        expect(answer, isNot(contains('user_id')));
        expect(answer, isNot(contains('@')));
      },
    );

    test(
      'answers recent loyalty transactions with a bounded-window caveat',
      () async {
        final answer = await responder.reply(
          'رصيد أحمد وسجل النقاط',
          businessData: AdminAssistantBusinessData(
            kind: 'customer_loyalty_activity',
            status: AdminAssistantDataStatus.ready,
            customer: AdminAssistantCustomerSnapshot(
              canReadCustomerHistory: false,
              canReadLoyalty: true,
              customerName: 'أحمد علي',
              pointsBalance: 75,
              lifetimePoints: 120,
              loyaltyActivity: [
                AdminAssistantLoyaltyActivity(
                  points: 15,
                  balanceAfter: 75,
                  date: DateTime.utc(2026, 11, 20),
                  rewardName: 'مشروب مجاني',
                ),
              ],
            ),
          ),
        );
        expect(answer, contains('75 نقطة'));
        expect(answer, contains('أحدث 300 حركة'));
        expect(answer, contains('أضيفت 15 نقطة'));
        expect(answer, isNot(contains('reference_id')));
      },
    );

    test(
      'answers live sales from permission-scoped dashboard values offline',
      () async {
        final answer = await responder.reply(
          'كم مبيعات اليوم؟',
          businessData: const AdminAssistantBusinessData(
            kind: 'sales',
            status: AdminAssistantDataStatus.ready,
            dashboard: AdminDashboardMetrics(
              todayRevenue: 1260,
              todayOrders: 35,
              yesterdayRevenue: 1000,
              yesterdayOrders: 28,
              averageOrderValue: 36,
              activeOrders: 4,
            ),
          ),
        );
        expect(answer, contains('1260'));
        expect(answer, contains('35 طلب'));
        expect(answer, isNot(contains('غير موصولة')));
      },
    );

    test('compares periods using exact dashboard baselines', () async {
      final answer = await responder.reply(
        'قارن مبيعات الأسبوع ده بالأسبوع اللي فات',
        businessData: const AdminAssistantBusinessData(
          kind: 'sales',
          status: AdminAssistantDataStatus.ready,
          dashboard: AdminDashboardMetrics(
            weekRevenue: 1200,
            prevWeekRevenue: 1000,
            weekOrders: 30,
            prevWeekOrders: 26,
          ),
        ),
      );
      expect(answer, contains('1200'));
      expect(answer, contains('1000'));
      expect(answer, contains('+20.0%'));
    });

    test('answers low-stock questions from scoped raw-material rows', () async {
      final answer = await responder.reply(
        'ما المواد الخام منخفضة المخزون؟',
        businessData: const AdminAssistantBusinessData(
          kind: 'inventory',
          status: AdminAssistantDataStatus.ready,
          inventory: AdminInventoryMetrics(total: 18, low: 2, out: 1),
          materials: [
            AdminInventoryItem(
              id: 'internal-id',
              nameAr: 'بن أرابيكا',
              nameEn: 'Arabica beans',
              quantityOnHand: 1.5,
              unit: 'kg',
              status: 'low',
            ),
          ],
        ),
      );
      expect(answer, contains('بن أرابيكا'));
      expect(answer, contains('1.5 kg'));
      expect(answer, isNot(contains('(low)')));
      expect(answer, isNot(contains('internal-id')));
    });

    test(
      'answers empty low-stock results in natural Arabic without raw keys',
      () async {
        final answer = await responder.reply(
          'مواد منخفضة المخزون؟',
          businessData: const AdminAssistantBusinessData(
            kind: 'inventory',
            status: AdminAssistantDataStatus.ready,
            inventory: AdminInventoryMetrics(total: 12, low: 0, out: 0),
            materialListRequested: true,
          ),
        );
        expect(answer, contains('لا توجد مواد منخفضة المخزون'));
        expect(answer, isNot(contains('low_stock')));
        expect(answer, isNot(contains('=0')));
      },
    );

    test(
      'answers monthly average sales from the actual monthly totals',
      () async {
        final answer = await responder.reply(
          'متوسط المبيعات من أول الشهر خالص',
          businessData: const AdminAssistantBusinessData(
            kind: 'sales',
            status: AdminAssistantDataStatus.ready,
            dashboard: AdminDashboardMetrics(
              monthRevenue: 1200,
              monthOrders: 30,
            ),
          ),
        );
        expect(answer, contains('40'));
        expect(answer, contains('منذ بداية الشهر'));
        expect(answer, isNot(contains('Asia/Riyadh')));
      },
    );

    test(
      'explains observed sales changes without asserting their cause',
      () async {
        final answer = await responder.reply(
          'ليه المبيعات قلت النهاردة؟',
          businessData: const AdminAssistantBusinessData(
            kind: 'sales',
            status: AdminAssistantDataStatus.ready,
            dashboard: AdminDashboardMetrics(
              todayRevenue: 800,
              todayOrders: 30,
              averageOrderValue: 26.67,
              yesterdayRevenue: 1000,
              yesterdayOrders: 25,
              yesterdayAverageOrderValue: 40,
            ),
          ),
        );
        expect(answer, contains('اليوم مقارنة بأمس'));
        expect(answer, contains('عدد الطلبات تغيّر من 25 إلى 30'));
        expect(answer, contains('متوسط الطلب 26.67 ريال مقابل 40 ريال'));
        expect(answer, contains('لا تثبت سببًا تشغيليًا'));
      },
    );

    test(
      'does not report a zero average when the period has no orders',
      () async {
        final answer = await responder.reply(
          'متوسط الطلب اليوم؟',
          businessData: const AdminAssistantBusinessData(
            kind: 'sales',
            status: AdminAssistantDataStatus.ready,
            dashboard: AdminDashboardMetrics(todayOrders: 0),
          ),
        );
        expect(answer, contains('لا توجد طلبات مسجلة اليوم'));
        expect(answer, isNot(contains('0 ريال')));
      },
    );

    test('business context excludes customer names and order identifiers', () {
      final data = AdminAssistantBusinessData(
        kind: 'orders',
        status: AdminAssistantDataStatus.ready,
        dashboard: AdminDashboardMetrics(
          recentOrders: [
            AdminDashboardRecentOrder(
              id: 'private-order-id',
              orderNumber: 'A-123',
              status: 'new',
              fulfillmentType: 'pickup',
              grandTotal: 50,
              itemsCount: 1,
              placedAt: DateTime.utc(2026),
              customerName: 'Private Customer',
            ),
          ],
        ),
      );

      final context = data.toPromptContext(arabic: true);
      expect(context, isNot(contains('Private Customer')));
      expect(context, isNot(contains('private-order-id')));
      expect(context, contains('اليوم:'));
      expect(context, isNot(contains('Asia/Riyadh')));
      expect(context, isNot(contains('low_stock=')));
    });

    test('explains missing role permission without guessing zero', () async {
      final answer = await responder.reply(
        'كم مبيعات اليوم؟',
        businessData: const AdminAssistantBusinessData(
          kind: 'sales',
          status: AdminAssistantDataStatus.permissionDenied,
        ),
      );
      expect(answer, contains('لا يملك صلاحية'));
      expect(answer, isNot(contains('0 ريال')));
    });

    test(
      'answers coupon questions from the permission-scoped aggregate',
      () async {
        final answer = await responder.reply(
          'ملخص الخصومات والكوبونات',
          businessData: const AdminAssistantBusinessData(
            kind: 'discounts',
            status: AdminAssistantDataStatus.ready,
            couponMetrics: AdminCouponMetrics(
              total: 12,
              active: 4,
              expiringSoon: 2,
              scheduled: 1,
              redemptions: 31,
              uniqueCustomers: 18,
              discountGiven: 245.5,
            ),
          ),
        );
        expect(answer, contains('12 كوبونًا مستخدمًا'));
        expect(answer, contains('31 استخدام'));
        expect(answer, contains('18 عميل'));
        expect(answer, contains('245.5 ريال'));
        expect(answer, contains('لا يثبت وحده'));
      },
    );

    test(
      'compares coupons from recorded per-coupon redemption aggregates',
      () async {
        final answer = await responder.reply(
          'قارن الكوبونات من حيث الاستخدام',
          businessData: const AdminAssistantBusinessData(
            kind: 'discounts',
            status: AdminAssistantDataStatus.ready,
            couponDirectoryRequested: true,
            coupons: [
              AdminCoupon(
                id: 'coupon-1',
                code: 'LATTE10',
                titleAr: 'خصم لاتيه',
                titleEn: 'Latte discount',
                redemptionsCount: 24,
                uniqueCustomers: 17,
                discountGiven: 120,
              ),
              AdminCoupon(
                id: 'coupon-2',
                code: 'MOCHA5',
                titleAr: 'خصم موكا',
                titleEn: 'Mocha discount',
                redemptionsCount: 8,
                uniqueCustomers: 6,
                discountGiven: 35,
              ),
            ],
          ),
        );
        expect(answer, contains('LATTE10'));
        expect(answer, contains('24 استخدام'));
        expect(answer, contains('MOCHA5'));
        expect(answer, contains('لا تتضمن مقارنة فترات'));
        expect(answer, contains('لا تثبت'));
      },
    );

    test(
      'does not expose coupon metrics without the required permission',
      () async {
        final answer = await responder.reply(
          'كم استخدام الكوبونات؟',
          businessData: const AdminAssistantBusinessData(
            kind: 'discounts',
            status: AdminAssistantDataStatus.permissionDenied,
          ),
        );
        expect(answer, contains('صلاحية قراءة الكوبونات'));
        expect(answer, isNot(contains('31')));
      },
    );

    test('removes customer purchase turns before replaying model context', () {
      final safe = AdminAssistantRepository.boundedModelHistory([
        {'role': 'user', 'content': 'رصيد نقاط أحمد حسن كام؟'},
        {
          'role': 'assistant',
          'content': 'رصيده 500 نقطة وآخر طلب له كان لاتيه.',
        },
        {'role': 'user', 'content': 'ما معنى متوسط قيمة الطلب؟'},
        {
          'role': 'assistant',
          'content': 'هو إجمالي قيمة الطلبات مقسومًا على عددها.',
        },
      ]);
      final serialized = safe.map((turn) => turn['content']).join(' ');
      expect(safe, hasLength(2));
      expect(serialized, isNot(contains('أحمد حسن')));
      expect(serialized, isNot(contains('500 نقطة')));
      expect(serialized, contains('متوسط قيمة الطلب'));
    });

    test('keeps unattributed loyalty and unreadable coupons unavailable to branch staff', () async {
      const session = AdminSession(
        staffId: 'staff-1',
        fullName: 'Branch Manager',
        email: 'manager@example.test',
        status: 'active',
        roles: [
          AdminRoleScope(
            roleId: 'role-1',
            roleCode: 'manager',
            branchId: 'branch-1',
          ),
        ],
        permissionScopes: [
          AdminPermissionScope(
            branchId: 'branch-1',
            permissions: ['customers.read', 'loyalty.read', 'settings.write'],
          ),
        ],
        canManageAllBranches: false,
      );
      final liveData = AdminAssistantLiveDataRepository(
        client: SupabaseClient('https://offline.test', 'public-test-key'),
        session: session,
      );

      final customer = await liveData.loadFor('أحمد حسن اشترى إيه؟');
      final coupons = await liveData.loadFor('ملخص الخصومات والكوبونات');

      expect(customer?.status, AdminAssistantDataStatus.unavailable);
      expect(coupons?.status, AdminAssistantDataStatus.permissionDenied);
    });
  });
}
