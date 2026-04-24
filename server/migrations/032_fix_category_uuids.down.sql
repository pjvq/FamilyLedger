-- Down migration: no-op (cannot reverse UUID changes without storing old values)
-- The UUIDs are still valid, just different values.
SELECT 1;
