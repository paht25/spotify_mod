# feed-c-bridge-v2

This repair is based on the actual cloud-main.zip supplied by the user.
The archive already contained the runtime-lookup hook revision. The earlier
undefined ObjC class-symbol screenshot cannot establish the failure of that
specific source revision without the run's commit and current logs.

This version replaces class-symbol/runtime-name linkage with an explicit Swift
C export, USAttachEeveeFeed. Objective-C calls that function with a borrowed
transaction pointer. The hook tests exercise the C bridge, including a null
argument. The test script checks the emitted native symbol before linking the
hook executable. Logs include revision, commit and hashes of the two bridge
sources. The workflow name includes feed-c-bridge-v2 so old runs are distinct.

Bash syntax validation passed locally. Apple compilation and runtime tests have
not been rerun here. No .deb has been fabricated or declared successfully built.
The package remains an isolated experimental feed test, not full Chroma/Eevee.

Upload the contents of this ZIP to the repository root, replace matching files,
commit to main, and start a NEW workflow run. Confirm the workflow name/revision
contains feed-c-bridge-v2. Re-running an older commit will not test this repair.
