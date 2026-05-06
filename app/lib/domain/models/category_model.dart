import '../../core/utils/category_uuid.dart';
import 'transaction_model.dart';

class CategoryModel {
  final String id;
  final String name;
  final String icon; // emoji fallback
  final String iconKey; // built-in icon key (e.g. "food_breakfast")
  final TransactionType type;
  final bool isPreset;
  final int sortOrder;
  final String? parentId;
  final List<CategoryModel> children;

  const CategoryModel({
    required this.id,
    required this.name,
    this.icon = '',
    this.iconKey = '',
    required this.type,
    this.isPreset = true,
    this.sortOrder = 0,
    this.parentId,
    this.children = const [],
  });

  bool get hasChildren => children.isNotEmpty;
  bool get isSubcategory => parentId != null && parentId!.isNotEmpty;
}

/// 预设分类
class PresetCategories {
  PresetCategories._();

  static final expense = [
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '餐饮'), name: '餐饮', icon: '🍜', iconKey: 'food', type: TransactionType.expense, sortOrder: 1),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '交通'), name: '交通', icon: '🚗', iconKey: 'transport', type: TransactionType.expense, sortOrder: 2),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '购物'), name: '购物', icon: '🛍️', iconKey: 'shopping', type: TransactionType.expense, sortOrder: 3),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '居住'), name: '居住', icon: '🏠', iconKey: 'housing', type: TransactionType.expense, sortOrder: 4),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '娱乐'), name: '娱乐', icon: '🎮', iconKey: 'entertainment', type: TransactionType.expense, sortOrder: 5),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '医疗'), name: '医疗', icon: '🏥', iconKey: 'medical', type: TransactionType.expense, sortOrder: 6),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '教育'), name: '教育', icon: '📚', iconKey: 'education', type: TransactionType.expense, sortOrder: 7),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '通讯'), name: '通讯', icon: '📱', iconKey: 'communication', type: TransactionType.expense, sortOrder: 8),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '人情'), name: '人情', icon: '🎁', iconKey: 'gift', type: TransactionType.expense, sortOrder: 9),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '服饰'), name: '服饰', icon: '👔', iconKey: 'clothing', type: TransactionType.expense, sortOrder: 10),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '日用'), name: '日用', icon: '🧴', iconKey: 'daily', type: TransactionType.expense, sortOrder: 11),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '旅行'), name: '旅行', icon: '✈️', iconKey: 'travel', type: TransactionType.expense, sortOrder: 12),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '宠物'), name: '宠物', icon: '🐱', iconKey: 'pet', type: TransactionType.expense, sortOrder: 13),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '其他'), name: '其他', icon: '📦', iconKey: 'other', type: TransactionType.expense, sortOrder: 14),
  ];

  static final income = [
    CategoryModel(id: CategoryUUID.generate('_preset_', 'income', '工资'), name: '工资', icon: '💰', iconKey: 'salary', type: TransactionType.income, sortOrder: 1),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'income', '奖金'), name: '奖金', icon: '🏆', iconKey: 'bonus', type: TransactionType.income, sortOrder: 2),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'income', '投资收益'), name: '投资收益', icon: '📈', iconKey: 'investment_income', type: TransactionType.income, sortOrder: 3),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'income', '兼职'), name: '兼职', icon: '💼', iconKey: 'freelance', type: TransactionType.income, sortOrder: 4),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'income', '红包'), name: '红包', icon: '🧧', iconKey: 'red_packet', type: TransactionType.income, sortOrder: 5),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'income', '报销'), name: '报销', icon: '🧾', iconKey: 'reimbursement', type: TransactionType.income, sortOrder: 6),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'income', '其他'), name: '其他', icon: '💵', iconKey: 'other', type: TransactionType.income, sortOrder: 7),
  ];

  static List<CategoryModel> get all => [...expense, ...income];
}
