package category

import "github.com/google/uuid"

// Namespace for deterministic category UUID v5 generation.
// Both Go server and Flutter client use this same namespace.
const NamespaceStr = "6ba7b810-9dad-11d1-80b4-00c04fd430c8"

var Namespace = uuid.MustParse(NamespaceStr)

// UUID generates a deterministic UUID v5 for a category.
// ownerID is the user ID (personal mode) or family ID (family mode).
// This ensures different users/families have different UUIDs for the same category name.
//
// Input format: "{ownerID}:{type}:{name}"
func UUID(ownerID, categoryType, name string) uuid.UUID {
	return uuid.NewSHA1(Namespace, []byte(ownerID+":"+categoryType+":"+name))
}
