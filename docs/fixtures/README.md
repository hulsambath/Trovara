# Fixtures

Reference files for documentation and debugging.

## `generativelanguage-api-error-403.json`

Sample error response from the Google Generative Language API (e.g. when listing models). Used to document or handle API permission/blocking errors (e.g. `API_KEY_SERVICE_BLOCKED`, `PERMISSION_DENIED`). Project-specific metadata is redacted; replace with your own values when testing.

## `generativelanguage-api-error-403-generatecontent.json`

Same 403/permission-blocked pattern for the **GenerateContent** method (e.g. chat/generation). For debugging or documenting blocked-generation errors; project IDs are redacted.

## `generativelanguage-api-error-403-embedcontent.json`

Same 403/permission-blocked pattern for the **EmbedContent** method (e.g. embeddings). For debugging or documenting blocked-embedding errors; project IDs are redacted.
