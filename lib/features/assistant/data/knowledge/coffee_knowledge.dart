class KnowledgeArticle {
  const KnowledgeArticle({
    required this.id,
    required this.title,
    required this.keywords,
    required this.body,
    required this.topic,
  });

  final String id;
  final String title;
  final List<String> keywords;
  final String body;
  final String topic;
}

const List<KnowledgeArticle> coffeeKnowledge = [
  KnowledgeArticle(
    id: 'espresso-basics',
    title: 'Espresso basics',
    keywords: ['espresso', 'shot', 'strong', 'intense', 'crema', 'bold'],
    body:
        'Espresso is a concentrated 25 to 30 ml shot brewed by forcing hot water through finely ground coffee. '
        'Look for a thick golden crema on top: that is the sign of a fresh, well-pulled shot.',
    topic: 'brewing',
  ),
  KnowledgeArticle(
    id: 'cappuccino-guide',
    title: 'What is a cappuccino?',
    keywords: ['cappuccino', 'foam', 'classic', 'milk foam'],
    body:
        'A cappuccino is one part espresso, one part steamed milk and one part airy milk foam. '
        'It tastes stronger and drier than a latte, and it is best enjoyed fresh while the foam holds.',
    topic: 'drinks',
  ),
  KnowledgeArticle(
    id: 'latte-guide',
    title: 'What is a latte?',
    keywords: ['latte', 'milky', 'mild', 'smooth', 'creamy'],
    body:
        'A latte is mostly steamed milk with a single or double espresso shot, finished with a thin layer of foam. '
        'Pick it when you want something smooth, mild and creamy.',
    topic: 'drinks',
  ),
  KnowledgeArticle(
    id: 'mocha-guide',
    title: 'What is a mocha?',
    keywords: ['mocha', 'chocolate', 'sweet', 'cocoa', 'dessert'],
    body:
        'A mocha is espresso mixed with chocolate and steamed milk, often topped with whipped cream. '
        'It is the sweetest espresso drink we make, great as an afternoon treat.',
    topic: 'drinks',
  ),
  KnowledgeArticle(
    id: 'cold-coffee-guide',
    title: 'Cold coffee options',
    keywords: ['cold', 'iced', 'summer', 'hot weather', 'refreshing', 'cold brew'],
    body:
        'For hot days, go for an Iced Latte for creamy refreshment, or a Chocolate Milkshake when you want '
        'something indulgent. Cold drinks keep their flavor best when served over plenty of ice.',
    topic: 'drinks',
  ),
  KnowledgeArticle(
    id: 'arabica-vs-robusta',
    title: 'Arabica vs Robusta',
    keywords: ['arabica', 'robusta', 'beans', 'bean', 'origin', 'blend'],
    body:
        'Arabica beans taste sweeter and more aromatic with less caffeine. Robusta is bolder, more bitter '
        'and has almost twice the caffeine. Most specialty drinks here use 100% Arabica.',
    topic: 'beans',
  ),
  KnowledgeArticle(
    id: 'grind-guide',
    title: 'Grind size guide',
    keywords: ['grind', 'grinder', 'fine', 'coarse', 'grounds'],
    body:
        'Match the grind to the brew: fine like sugar for espresso, medium for drip, and coarse like sea salt '
        'for French press. Too fine tastes bitter, too coarse tastes sour and weak.',
    topic: 'brewing',
  ),
  KnowledgeArticle(
    id: 'french-press',
    title: 'French press at home',
    keywords: ['french press', 'press', 'home', 'brew at home', 'plunger'],
    body:
        'Use coarse coffee, 1 part coffee to 15 parts water just off the boil. Steep 4 minutes, break the '
        'crust, skim the foam, then press slowly. Full-bodied and forgiving.',
    topic: 'brewing',
  ),
  KnowledgeArticle(
    id: 'pour-over',
    title: 'Pour over at home',
    keywords: ['pour over', 'v60', 'drip', 'filter', 'pourover'],
    body:
        'Use medium-fine coffee and water around 92 to 94 C. Bloom with a little water for 30 seconds, then '
        'pour in slow circles. Total brew time is about 2 and a half to 3 minutes for a clean, bright cup.',
    topic: 'brewing',
  ),
  KnowledgeArticle(
    id: 'caffeine-guide',
    title: 'Caffeine guide',
    keywords: ['caffeine', 'energy', 'awake', 'sleep', 'mg', 'strong', 'wired'],
    body:
        'A single espresso shot has about 60 to 75 mg of caffeine, a milk-based cup has 60 to 150 mg depending '
        'on the shots, and a cola has around 30 to 40 mg. Avoid caffeine 6 hours before bed if it keeps you up.',
    topic: 'caffeine',
  ),
  KnowledgeArticle(
    id: 'decaf-guide',
    title: 'Decaf options',
    keywords: ['decaf', 'decaffeinated', 'low caffeine', 'no caffeine', 'evening', 'night'],
    body:
        'Want the taste without the buzz? Ask for any milk drink decaf, or try our Green Tea and Masala Tea, '
        'which are naturally much lower in caffeine than coffee.',
    topic: 'caffeine',
  ),
  KnowledgeArticle(
    id: 'milk-guide',
    title: 'Milk options',
    keywords: ['milk', 'oat', 'almond', 'soy', 'lactose', 'dairy', 'skim'],
    body:
        'Whole milk gives the creamiest foam, while oat milk steams closest to dairy. Tell us if you are '
        'lactose intolerant and we will happily swap your milk at no fuss.',
    topic: 'drinks',
  ),
  KnowledgeArticle(
    id: 'tea-guide',
    title: 'Tea options',
    keywords: ['tea', 'green tea', 'masala', 'chai', 'herbal'],
    body:
        'Our Green Tea is light and calming with natural antioxidants. Masala Tea is warm and spiced with '
        'cardamom, ginger and cinnamon, blended with milk for comfort.',
    topic: 'drinks',
  ),
  KnowledgeArticle(
    id: 'bean-storage',
    title: 'Keeping beans fresh',
    keywords: ['store', 'storage', 'fresh', 'keep', 'beans', 'stale'],
    body:
        'Keep beans in an airtight container at room temperature, away from light and moisture. '
        'Buy small amounts often and grind right before brewing for the best flavor.',
    topic: 'beans',
  ),
  KnowledgeArticle(
    id: 'snacks-pairing',
    title: 'What to eat with coffee',
    keywords: ['snack', 'eat', 'food', 'pair', 'cookie', 'croissant', 'cake', 'brownie', 'hungry'],
    body:
        'Chocolate Chip Cookies and Brownies pair perfectly with espresso, while a Butter Croissant is the '
        'classic match for a morning Latte or Cappuccino.',
    topic: 'food',
  ),
];
