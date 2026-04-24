import '../../core/utils/category_uuid.dart';
import 'transaction_model.dart';

class CategoryModel {
  final String id;
  final String name;
  final String icon; // emoji or icon name
  final TransactionType type;
  final bool isPreset;
  final int sortOrder;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
    this.isPreset = true,
    this.sortOrder = 0,
  });
}

/// 预设分类
class PresetCategories {
  PresetCategories._();

  static final expense = [
    CategoryModel(id: CategoryUUID.generate('expense', '餐饮'), name: '餐饮', icon: '🍜', type: TransactionType.expense, sortOrder: 1),
    CategoryModel(id: CategoryUUID.generate('expense', '交通'), name: '交通', icon: '🚗', type: TransactionType.expense, sortOrder: 2),
    CategoryModel(id: CategoryUUID.generate('expense', '购物'), name: '购物', icon: '🛍️', type: TransactionType.expense, sortOrder: 3),
    CategoryModel(id: CategoryUUID.generate('expense', '居住'), name: '居住', icon: '🏠', type: TransactionType.expense, sortOrder: 4),
    CategoryModel(id: CategoryUUID.generate('expense', '娱乐'), name: '娱乐', icon: '🎮', type: TransactionType.expense, sortOrder: 5),
    CategoryModel(id: CategoryUUID.generate('expense', '医疗'), name: '医疗', icon: '🏥', type: TransactionType.expense, sortOrder: 6),
    CategoryModel(id: CategoryUUID.generate('expense', '教育'), name: '教育', icon: '📚', type: TransactionType.expense, sortOrder: 7),
    CategoryModel(id: CategoryUUID.generate('expense', '通讯'), name: '通讯', icon: '📱', type: TransactionType.expense, sortOrder: 8),
    CategoryModel(id: CategoryUUID.generate('expense', '人情'), name: '人情', icon: '🎁', type: TransactionType.expense, sortOrder: 9),
    CategoryModel(id: CategoryUUID.generate('expense', '服饰'), name: '服饰', icon: '👔', type: TransactionType.expense, sortOrder: 10),
    CategoryModel(id: CategoryUUID.generate('expense', '日用'), name: '日用', icon: '🧴', type: TransactionType.expense, sortOrder: 11),
    CategoryModel(id: CategoryUUID.generate('expense', '旅行'), name: '旅行', icon: '✈️', type: TransactionType.expense, sortOrder: 12),
    CategoryModel(id: CategoryUUID.generate('expense', '宠物'), name: '宠物', icon: '🐱', type: TransactionType.expense, sortOrder: 13),
    CategoryModel(id: CategoryUUID.generate('expense', '其他'), name: '其他', icon: '📦', type: TransactionType.expense, sortOrder: 14),
  ];

  static final income = [
    CategoryModel(id: CategoryUUID.generate('income', '工资'), name: '工资', icon: '💰', type: TransactionType.income, sortOrder: 1),
    CategoryModel(id: CategoryUUID.generate('income', '奖金'), name: '奖金', icon: '🏆', type: TransactionType.income, sortOrder: 2),
    CategoryModel(id: CategoryUUID.generate('income', '投资收益'), name: '投资收益', icon: '📈', type: TransactionType.income, sortOrder: 3),
    CategoryModel(id: CategoryUUID.generate('income', '兼职'), name: '兼职', icon: '💼', type: TransactionType.income, sortOrder: 4),
    CategoryModel(id: CategoryUUID.generate('income', '红包'), name: '红包', icon: '🧧', type: TransactionType.income, sortOrder: 5),
    CategoryModel(id: CategoryUUID.generate('income', '报销'), name: '报销', icon: '🧾', type: TransactionType.income, sortOrder: 6),
    CategoryModel(id: CategoryUUID.generate('income', '其他'), name: '其他', icon: '💵', type: TransactionType.income, sortOrder: 7),
  ];

  static List<CategoryModel> get all => [...expense, ...income];
}
