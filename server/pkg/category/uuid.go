package category

import "github.com/google/uuid"

// Namespace for deterministic category UUID v5 generation.
// Both Go server and Flutter client use this same namespace.
const NamespaceStr = "6ba7b810-9dad-11d1-80b4-00c04fd430c8"

var Namespace = uuid.MustParse(NamespaceStr)

// UUID generates a deterministic UUID v5 for a category.
// Input format: "{type}:{name}", e.g. "expense:餐饮", "income:工资".
func UUID(categoryType, name string) uuid.UUID {
	return uuid.NewSHA1(Namespace, []byte(categoryType+":"+name))
}
