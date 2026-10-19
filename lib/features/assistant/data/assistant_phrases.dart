import 'package:new_coffee/features/assistant/data/assistant_intents.dart';

/// Large stock of trigger phrases per intent across Arabic dialects
/// (Egyptian / Levantine / Gulf / MSA), Arabizi and English.
///
/// All matching normalizes text first (see `assistant_language.dart`),
/// so spellings like "عاوز/عايز/أبغى" collapse to the same intent.
class AssistantPhrases {
  const AssistantPhrases._();

  /// Full-sentence (or long-phrase) triggers, matched with `contains`.
  static const Map<AssistantIntent, List<String>> intentPhrases = {
    AssistantIntent.greeting: [
      // English
      'hello', 'hi there', 'hey', 'good morning', 'good evening',
      'good afternoon', 'how are you', 'whats up',
      // MSA / shared
      'سلام عليكم', 'السلام عليكم', 'صباح الخير', 'مساء الخير',
      'اهلا', 'أهلا', 'مرحبا', 'ازيك', 'ازيك', 'عامل ايه', 'اخبارك',
      // Egyptian
      'صباح الفل', 'مساء الفل', 'ازيك يا', 'عاملين ايه', 'اهلا بيك',
      // Levantine
      'مرحبا', 'كيفك', 'شو اخبارك', 'صباحو', 'مسا الخير', 'اهلين',
      // Gulf / Saudi
      'هلا', 'هلا والله', 'صباح النور', 'مساء النور', 'شحالك', 'شلونك',
      'الله يحييك', 'ياهلا فيك',
      // Arabizi
      'salam', 'sabah el kheir', 'masa el kheir', 'ezayak', '3amel eh',
      'ahlan', 'marhaba', 'keefak', 'hala wallah',
    ],
    AssistantIntent.suggestDrink: [
      // English
      'suggest', 'recommend', 'best drink', 'your favorite', 'surprise me',
      'what should i try', 'something new', 'i am bored', 'any ideas',
      'strong coffee', 'something sweet', 'something cheap', 'something light',
      // MSA / shared
      'اقترح', 'رشح', 'افضل مشروب', 'احسن حاجه', 'فاجئني', 'عايز اجرب',
      'حاجه جديده', 'زهقت', 'عندك افكار', 'قهوه قويه', 'حاجه حلوه',
      'حاجه رخيصه', 'حاجه خفيفه',
      // Egyptian
      'عاوز اشرب ايه', 'عايز اشرب ايه', 'رشحلي حاجه', 'اقترح عليا',
      'عاوز حاجه قويه', 'عاوز حاجه مسكره', 'نفسك في ايه', 'تشرب ايه',
      'حاجه تظبط الدماغ', 'عاوز افوق', 'عايز افوق',
      // Levantine
      'بدي اشرب شي', 'شو بتنصحني', 'شو طيب عندكم', 'بدي شي قوي',
      'بدي شي حلو', 'شو الجديد',
      // Gulf / Saudi
      'ابي شي', 'وش تنصح', 'وش احسن شي', 'ابي قهوه قويه', 'ابي شي حلو',
      'ابغى اطلب', 'ابي اطلب', 'ودي اطلب', 'بدي اطلب',
      // Arabizi
      'ersha7', 'rash7ly', '3ayez ashrab eh', '3awz haga helwa',
      '3ayez haga helwa', 'badi shi', 'shu btnsa7ni', 'abi shi',
    ],
    AssistantIntent.orderStatus: [
      // English
      'my order', 'track my order', 'order status', 'where is my order',
      'is it delivered', 'has it arrived', 'tracking', 'my package',
      // MSA / shared
      'الاوردر', 'طلبى', 'فين طلبى', 'طلبى وصل', 'حاله الطلب', 'تتبع الطلب',
      'الطلب اتعمل', 'الطلب جاهز', 'الطلب فين',
      // Egyptian
      'الاوردر فين', 'طلبى اتعمل ولا لسه', 'الاوردر وصل', 'هو الاوردر جاهز',
      'طلبى بيتحضر', 'لسه الطلب',
      // Levantine
      'وين طلبي', 'طلبي وصل', 'جهز الطلب',
      // Gulf / Saudi
      'وين طلبي', 'طلبى وصل', 'جهز طلبى', 'وين الطلب', 'عندي طلبيه',
      // Arabizi
      'el order fein', 'talaby wesel', 'wein talaby',
    ],
    AssistantIntent.showCoupons: [
      // English
      'coupon', 'coupons', 'discount', 'promo', 'offer', 'deal', 'sale',
      'promo code', 'any codes',
      // MSA / shared
      'كوبون', 'خصم', 'عرض', 'عروض', 'كود خصم', 'تخفيض', 'برومو',
      // Egyptian
      'في خصم', 'عندكم عروض', 'كوبونات', 'بكام', 'السعر كام',
      // Levantine
      'في حسم', 'عندكم عروض', 'كوبونات',
      // Gulf / Saudi
      'في خصم', 'كود خصم', 'عروضكم', 'بكم', 'كم سعره', 'كم الحساب',
      // Arabizi
      'coupon', 'khasm', '3ard', 'fi khasm',
    ],
    AssistantIntent.thanks: [
      'thank', 'thanks', 'shokran', 'متشكر', 'تسلم', 'يسلمو',
      'ممنون', 'الف شكر', 'thx', 'merci',
      // Saudi thanks.
      'يعطيك العافيه', 'الله يعطيك العافيه', 'مشكور',
    ],
    AssistantIntent.usualOrder: [
      // The user's habitual order.
      'اللي متعود عليه', 'الي متعود عليه', 'المعتاد', 'المعتاد بتاعي',
      'طلبي المعتاد', 'زي كل مره', 'زي كل مرة', 'نفس الطلب', 'نفس طلبي',
      'اللي باخده دايما', 'اللي باخده على طول', 'عايز المعتاد',
      'عاوز المعتاد', 'هات المعتاد', 'العادة', 'my usual', 'the usual',
      'my regular', 'same as always', 'same as usual', 'like always',
      'usual order', 'my usual order', 'el mo3tad', 'zay kol mara',
      'nafs el talab', 'hat el mo3tad',
    ],
    AssistantIntent.botIdentity: [
      'انت مين', 'انتي مين', 'مين انت', 'who are you', 'what are you',
      'مين اللي بيكلمني', 'عرف نفسك', 'your name', 'اسمك ايه', 'انت ايه',
    ],
    AssistantIntent.farewell: [
      'مع السلامه', 'مع السلامة', 'اشوفك', 'اشوفك بعدين', 'باي',
      'الي اللقاء', 'goodbye', 'good bye', 'see you', 'bye',
      'يلا سلام', 'سلام يا', 'في امان الله',
    ],
    AssistantIntent.affirm: [
      'ايوه كده', 'تمام كده', 'ماشي', 'موافق', 'اكيد', 'طبعا',
      'yes please', 'sounds good', 'perfect', 'great', 'me too',
      'اكد الاوردر', 'أكد الاوردر', 'confirm order', 'confirm',
      'يلا نطلب', 'يلا اطلب',
    ],
    AssistantIntent.deny: [
      'مش عايز', 'مش عاوز', 'مش عاوز ده', 'بلاش', 'لا شكرا',
      'no thanks', 'not now', 'maybe later', 'بلاش ده',
    ],
    AssistantIntent.placeOrder: [
      // Full order requests.
      'اعملي اوردر', 'اعمل اوردر', 'عايز اطلب', 'عاوز اطلب',
      'عايز اعمل اوردر', 'عاوز اعمل اوردر', 'اطلب اوردر', 'هات اوردر',
      'اطلبلي', 'i want to order', 'place an order', 'make an order',
      'order for me', 'can i order', 'عايز اطلب اوردر', 'want to order',
    ],
    AssistantIntent.addToCart: [
      'ضيف للسلة', 'add to cart', 'حط في السلة', 'ضيف علي السلة',
      'add it to cart', 'زود علي السلة',
    ],
    AssistantIntent.cancelOrder: [
      'الغي الاوردر', 'الغي الطلب', 'كنسل الاوردر', 'امسح الاوردر',
      'cancel my order', 'cancel the order', 'بلاش الاوردر',
    ],
    AssistantIntent.payNow: [
      'ادفع دلوقتي', 'هدفع دلوقتي', 'ادفع اونلاين', 'ادفع بالكارت',
      'pay now', 'i will pay now', 'الدفع دلوقتي', 'هدفع بالفيزا',
    ],
    AssistantIntent.payCash: [
      'عند الاستلام', 'الدفع عند الاستلام', 'cash on delivery',
      'ادفع كاش', 'هدفع كاش', 'كاش عند الاستلام', 'الدفع كاش',
    ],
    AssistantIntent.complaint: [
      // Taste / quality complaints.
      'مش حلو', 'مش حلوه', 'مش عاجبني', 'مش عاجبنى', 'معجبنيش',
      'ما عجبني', 'طعمها وحش', 'طعمه وحش', 'too sweet', 'too bitter',
      'too cold', 'too hot', 'too expensive', 'too pricey', 'bad taste',
      'tastes bad', 'did not like', "didn't like", 'dont like',
      "don't like", 'terrible', 'awful',
      'not good', 'مش قد كده', 'مو حلو', 'مو حلوه', 'مو زين',
      // Price complaints.
      'السعر غالي', 'غالي اوي', 'too much money',
    ],
    AssistantIntent.selectOrdinal: [
      'اول واحد', 'تاني واحد', 'تالت واحد', 'اخر واحد',
      'the first one', 'the second one', 'the third one', 'the last one',
    ],
  };

  /// Single-word triggers per intent (exact or fuzzy matched).
  static const Map<AssistantIntent, List<String>> intentKeywords = {
    AssistantIntent.greeting: [
      'hello', 'hi', 'hey', 'morning', 'evening', 'salam', 'sabah',
      'masa', 'ahlan', 'marhaba', 'ezayak', 'keefak', 'hala', 'hello',
      'صباح', 'مساء', 'سلام', 'اهلا', 'مرحبا', 'ازيك', 'كيفك', 'هلا',
      'صباحو', 'صباحو', 'اهلين', 'شلونك', 'شحالك',
    ],
    AssistantIntent.suggestDrink: [
      'suggest', 'recommend', 'best', 'favorite', 'favourite', 'try',
      'new', 'bored', 'surprise', 'ideas', 'strong', 'sweet', 'cheap',
      'light', 'something', 'thirsty', 'mood', 'want',
      // The obvious basics (never miss these again).
      'coffee', 'drink', 'drinks', 'tea',
      'اقترح', 'رشح', 'احسن', 'افضل', 'اجرب', 'جديد', 'زهقت',
      'فاجئني', 'افكار', 'قويه', 'قوي', 'حلوه', 'حلو', 'مسكره', 'مسكر',
      'رخيصه', 'رخيص', 'خفيفه', 'خفيف', 'عطشان', 'عايز', 'عاوز',
      'بدي', 'ابي', 'نفسي', 'مزاج', 'افوق', 'تظبط',
      '3ayez', '3awz', 'haga', '7aga', 'helwa', 'helw',
      // Saudi / Gulf want-words.
      'ابغى', 'أبغى', 'يبغى', 'يبغي', 'تبغى', 'نبغى', 'ابغاه', 'يبغاه',
      'ودي', 'اود',
      // Simplified / foreigner Arabic.
      'اريد', 'أريد',
    ],
    AssistantIntent.orderStatus: [
      'order', 'status', 'where', 'delivered', 'package', 'arrived',
      'tracking', 'track', 'preparing', 'ready',
      'طلب', 'اوردر', 'وصل', 'جاهز', 'بيتحضر', 'يتحضر', 'فين',
      'وين', 'تتبع', 'استلم', 'جهز', 'طلبيه',
    ],
    AssistantIntent.showCoupons: [
      'coupon', 'discount', 'promo', 'offer', 'code', 'deal', 'sale',
      'كوبون', 'خصم', 'عرض', 'عروض', 'كود', 'تخفيض', 'بكام', 'بكم', 'سعر',
      'حسم',
    ],
    AssistantIntent.thanks: [
      'thank', 'thanks', 'thx', 'merci', 'shokran',
      'شكرا', 'متشكر', 'تسلم', 'يسلمو', 'ممنون',
      // Saudi thanks.
      'مشكور', 'يعطيك',
    ],
    AssistantIntent.usualOrder: [
      'متعود', 'معتاد', 'المعتاد', 'usual', 'regular',
      'عاده', 'معتاده', 'زي', 'نفس', 'دايما', 'علي طول',
      // Saudi: always / my habit.
      'دايم', 'عادتي',
    ],
    AssistantIntent.botIdentity: [
      'مين', 'who', 'اسمك', 'نفسك',
    ],
    AssistantIntent.farewell: [
      'باي', 'bye', 'goodbye', 'اشوفك', 'السلامه',
    ],
    AssistantIntent.affirm: [
      'ايوه', 'ايوا', 'اه', 'yes', 'yeah', 'yep', 'ok', 'okay',
      'تمام', 'ماشي', 'طبعا', 'اكيد', 'حاضر', 'موافق', 'اكد',
      // Saudi / Gulf yes-words.
      'ايه', 'طيب', 'يلا', 'سم', 'لبيه', 'تم', 'ممتاز', 'كويس',
      'اوكي', 'أوكيه',
    ],
    AssistantIntent.deny: [
      'لا', 'لاء', 'no', 'nope', 'بلاش', 'مش عايز', 'مش عاوز',
      // Saudi denials.
      'مابي', 'ماني', 'لا مش هو', 'not this one',
    ],
    AssistantIntent.placeOrder: [
      'اوردر', 'اطلب', 'طلب', 'اعمل', 'اعملي', 'هات',
      'order', 'ordering',
      // Saudi: "give me / bring me".
      'عطني', 'عطن', 'جيب', 'جب', 'نطلب',
    ],
    AssistantIntent.addToCart: [
      'ضيف', 'زود', 'حط', 'cart', 'السلة', 'للسلة', 'للعربية', 'العربية',
    ],
    AssistantIntent.cancelOrder: [
      'الغي', 'كنسل', 'امسح',
    ],
    AssistantIntent.payNow: [
      'ادفع', 'فيزا', 'كارت', 'visa', 'card', 'اونلاين',
    ],
    AssistantIntent.payCash: [
      'كاش', 'cash', 'الاستلام',
    ],
    AssistantIntent.complaint: [
      'وحش', 'وحشه', 'سيء', 'سيئه', 'سئ', 'بشع', 'يقرف',
      'غالي', 'غاليه', 'مقرف', 'خايس',
    ],
    AssistantIntent.selectOrdinal: [
      'الاول', 'التاني', 'التالت', 'الاخير',
      'first', 'second', 'third',
    ],
  };

  /// Taste / mood words (any dialect) mapped to canonical tokens the
  /// suggestion engine already understands.
  static const Map<String, String> tasteSynonyms = {
    // sweet
    'مسكر': 'sweet', 'مسكره': 'sweet', 'حلو': 'sweet', 'حلوه': 'sweet',
    'سكري': 'sweet', 'حال': 'sweet', 'sweet': 'sweet', 'sugary': 'sweet',
    'شوكولاته': 'chocolate', 'شيكولاته': 'chocolate', 'شوكولا': 'chocolate',
    'كاكاو': 'chocolate',
    // strong (incl. plain/black coffee)
    'قوي': 'strong', 'قويه': 'strong', 'تقيل': 'strong', 'تقيله': 'strong',
    'مر': 'strong', 'مره': 'strong', 'مركز': 'strong', 'يفوق': 'strong',
    'افوق': 'strong', 'strong': 'strong', 'intense': 'strong',
    'ساده': 'strong',
    // cheap (incl. "no money" talk)
    'رخيص': 'cheap', 'رخيصه': 'cheap', 'cheap': 'cheap', 'اقتصادي': 'cheap',
    'فلوس': 'cheap', 'قروش': 'cheap',
    // light
    'خفيف': 'light', 'خفيفه': 'light', 'light': 'light',
    // hot / cold (incl. Saudi حار and ice talk)
    'سخن': 'hot', 'سخنه': 'hot', 'دافي': 'hot', 'hot': 'hot', 'حار': 'hot',
    'ساقع': 'cold', 'ساقعه': 'cold', 'مثلج': 'cold', 'متلج': 'cold',
    'بارد': 'cold', 'بارده': 'cold', 'cold': 'cold', 'iced': 'cold',
    'ثلج': 'cold',
  };

  /// Product-name synonyms (dialects + common misspellings) mapped to the
  /// exact English menu names.
  static const Map<String, String> productSynonyms = {
    'اسبريسو': 'Espresso', 'اسبرسو': 'Espresso', 'إسبريسو': 'Espresso',
    'كابتشينو': 'Cappuccino', 'كبتشينو': 'Cappuccino',
    'لاتيه': 'Latte', 'لاته': 'Latte', 'لاتي': 'Latte', 'لا تيه': 'Latte',
    'موكا': 'Mocha', 'موكة': 'Mocha', 'موك': 'Mocha', 'موكہ': 'Mocha',
    'امريكانو': 'Americano', 'أمريكانو': 'Americano',
    'ايس لاتيه': 'Iced Latte', 'لاتيه مثلج': 'Iced Latte', 'ايس كوفي': 'Iced Latte',
    'شاي اخضر': 'Green Tea', 'جرين تي': 'Green Tea',
    'شاي': 'Tea', 'تشاي': 'Tea', 'شاى': 'Tea', 'اتاي': 'Tea',
    'بياله': 'Tea',
    'شاي مسالا': 'Masala Tea', 'مسالا': 'Masala Tea', 'كرك': 'Masala Tea',
    'شاي حليب': 'Masala Tea', 'حليب شاي': 'Masala Tea',
    'كرك شاي': 'Masala Tea', 'زنجبيل': 'Masala Tea',
    'قهوه حليب': 'Latte', 'حليب قهوه': 'Latte', 'نسكافيه': 'Latte',
    'تشيز كيك': 'Cheesecake', 'تشيزكيك': 'Cheesecake',
    'براونيز': 'Chocolate Brownie', 'براوني': 'Chocolate Brownie',
    'كوكيز': 'Chocolate Chip Cookie', 'كوكي': 'Chocolate Chip Cookie', 'بسكوت': 'Chocolate Chip Cookie',
    'كرواسون': 'Butter Croissant', 'كرواسان': 'Butter Croissant',
    'ميلك شيك': 'Chocolate Milkshake', 'ميلكشيك': 'Chocolate Milkshake', 'شيك': 'Chocolate Milkshake',
    'كولا': 'Cola', 'بيبسي': 'Cola', 'حاجه ساقعه': 'Cola',
    'توست': 'Butter Bread', 'عيش': 'Butter Bread',
    'دونات': 'Glazed Donut', 'دونتس': 'Glazed Donut',
    'قهوه': 'coffee', 'قهوة': 'coffee', 'كوفي': 'coffee',
    'هيل': 'coffee',
    'فنجان': 'coffee', 'فنجال': 'coffee', 'كوب': 'coffee',
    'كاسه': 'coffee', 'كاس': 'coffee',
  };

  /// Generic category words (Saudi حلا, etc.) mapped to the category slugs
  /// they boost. Slugs are stable; display names are not.
  static const Map<String, Set<String>> categoryBoosts = {
    'حلا': {'desserts', 'snacks', 'bakery', 'donuts'},
    'حلويات': {'desserts', 'snacks', 'bakery', 'donuts'},
    'ديزيرت': {'desserts', 'snacks', 'bakery', 'donuts'},
    'dessert': {'desserts', 'snacks', 'bakery', 'donuts'},
    'desserts': {'desserts', 'snacks', 'bakery', 'donuts'},
    'سناك': {'snacks'},
    'سناكس': {'snacks'},
    'تسالي': {'snacks'},
    'حلو': {'desserts', 'snacks', 'bakery', 'donuts'},
    'قهوه': {'hot-coffee', 'cold-coffee'},
    'قهوة': {'hot-coffee', 'cold-coffee'},
    'كوفي': {'hot-coffee', 'cold-coffee'},
  };

  /// Markers of a follow-up / refinement to the previous answer
  /// ("something else?", "stronger?", "تاني؟").
  static const List<String> followUpMarkers = [
    'else', 'other', 'another', 'stronger', 'sweeter', 'cheaper',
    'lighter', 'more', 'ager', 'again', 'instead',
    'تاني', 'غيره', 'غيرها', 'اقوى', 'احلى', 'ارخص', 'اخف',
    'كمان', 'بدل', 'تانى',
  ];

  /// Negation markers that attach to a product mention to reject it
  /// ("مش عايز لاتيه", "بلاش موكا", "no latte"). The product must appear
  /// within a few words AFTER the marker.
  static const List<String> productNegations = [
    'مش عايز', 'مش عاوز', 'مبحبش', 'مبحبهاش', 'بلاش', 'غير',
    'مابي', 'ما ابي', 'ما ابغى',
    'not', 'dont', "don't", 'no', 'without', 'except',
  ];

  /// Rotating clarification questions asked when a suggestion request has
  /// zero constraints and the bot knows nothing about the user yet.
  static const List<String> tasteQuestions = [
    ' Want it hot or cold — strong or sweet?',
    ' Hot or cold today? Strong or on the sweet side?',
    ' Tell me hot or cold, strong or sweet, and I will nail it next time.',
  ];
}
