import '../../core/utils/category_uuid.dart';
import 'transaction_model.dart';

class CategoryModel {
  final String id;
  final String name;
  final String iconKey; // icon key (e.g. "food_breakfast" or "emoji:🍜")
  final TransactionType type;
  final bool isPreset;
  final int sortOrder;
  final String? parentId;
  final List<CategoryModel> children;

  const CategoryModel({
    required this.id,
    required this.name,
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
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '餐饮'), name: '餐饮', iconKey: 'food', type: TransactionType.expense, sortOrder: 1),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '交通'), name: '交通', iconKey: 'transport', type: TransactionType.expense, sortOrder: 2),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '购物'), name: '购物', iconKey: 'shopping', type: TransactionType.expense, sortOrder: 3),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '居住'), name: '居住', iconKey: 'housing', type: TransactionType.expense, sortOrder: 4),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '娱乐'), name: '娱乐', iconKey: 'entertainment', type: TransactionType.expense, sortOrder: 5),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '医疗'), name: '医疗', iconKey: 'medical', type: TransactionType.expense, sortOrder: 6),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '教育'), name: '教育', iconKey: 'education', type: TransactionType.expense, sortOrder: 7),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '通讯'), name: '通讯', iconKey: 'communication', type: TransactionType.expense, sortOrder: 8),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '人情'), name: '人情', iconKey: 'gift', type: TransactionType.expense, sortOrder: 9),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '服饰'), name: '服饰', iconKey: 'clothing', type: TransactionType.expense, sortOrder: 10),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '日用'), name: '日用', iconKey: 'daily', type: TransactionType.expense, sortOrder: 11),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '旅行'), name: '旅行', iconKey: 'travel', type: TransactionType.expense, sortOrder: 12),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '宠物'), name: '宠物', iconKey: 'pet', type: TransactionType.expense, sortOrder: 13),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'expense', '其他'), name: '其他', iconKey: 'other', type: TransactionType.expense, sortOrder: 14),
  ];

  static final income = [
    CategoryModel(id: CategoryUUID.generate('_preset_', 'income', '工资'), name: '工资', iconKey: 'salary', type: TransactionType.income, sortOrder: 1),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'income', '奖金'), name: '奖金', iconKey: 'bonus', type: TransactionType.income, sortOrder: 2),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'income', '投资收益'), name: '投资收益', iconKey: 'investment_income', type: TransactionType.income, sortOrder: 3),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'income', '兼职'), name: '兼职', iconKey: 'freelance', type: TransactionType.income, sortOrder: 4),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'income', '红包'), name: '红包', iconKey: 'red_packet', type: TransactionType.income, sortOrder: 5),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'income', '报销'), name: '报销', iconKey: 'reimbursement', type: TransactionType.income, sortOrder: 6),
    CategoryModel(id: CategoryUUID.generate('_preset_', 'income', '其他'), name: '其他', iconKey: 'other', type: TransactionType.income, sortOrder: 7),
  ];

  static List<CategoryModel> get all => [...expense, ...income];
}
