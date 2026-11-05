# Independent integration core

These files are newly authored infrastructure. They do not copy or modify either upstream implementation and do not activate Spotify hooks or claim feature preservation.

USHookRegistry installs an explicitly provided replacement after checking runtime method existence, the exact reviewed Objective-C type encoding and expected original IMP. Ownership is shared across registry instances and keyed by actual Class identity and selector. Pass the metaclass to register a class method. The caller owns a correctly typed original function pointer; this registry does not invent calling conventions or compose arbitrary interceptors. Installing an inherited method adds a subclass override, protecting the superclass. Registrations through this registry are serialized; external swizzlers do not participate in its lock. Do not load the original tweaks beside a future integrated implementation or claim protection against unrelated concurrent runtime mutation.

USPreferences reads typed legacy values and performs an explicit, non-overwriting copy into a unified key. It retains the source. This is a migration primitive, not a complete migration schema, transaction or unified settings UI. No undocumented preference mapping has been invented.

Run the macOS Foundation tests with `bash scripts/test-core-macos.sh`. They exercise inherited hooks, superclass isolation, ABI rejection, duplicate ownership across instances, typed preference copying and non-overwriting behavior. Run `bash scripts/build-core.sh` on macOS with an iPhoneOS 27+ SDK to compile the ARM64 static library. Both operations remain unexecuted here because the required Apple toolchain is unavailable. Bash syntax checks alone are not compilation or runtime tests.
