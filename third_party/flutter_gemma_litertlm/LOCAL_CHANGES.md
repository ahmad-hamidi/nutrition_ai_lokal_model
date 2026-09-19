Based on flutter_gemma_litertlm 1.7.0 (pub.dev), preserving its LICENSE.
Only lib/, hook/, and package configuration are included.

Local adapter changes:
- litert_lm_client.dart detects Android /proc/self/fd document links and duplicates
  the descriptor instead of asking LiteRT-LM to reopen a protected path.
- litert_lm_bindings.dart exposes the existing C API
  litert_lm_engine_settings_create_from_raw_file_descriptor. This API takes
  ownership of the duplicate; the app retains the original for its URI grant.
- Removed pub workspace resolution for standalone path dependency use.

Native API ownership contract:
https://github.com/google-ai-edge/LiteRT-LM/blob/main/c/engine.h
No model bytes or native binaries are vendored here.
