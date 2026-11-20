# R8 runs on every release build with proguard-android-optimize.txt.
#
# No app-specific keep rules are needed today:
# - kotlinx.serialization: models use the compiler plugin's generated serializers
#   (reified decodeFromString/encodeToString), and the library's bundled consumer
#   rules keep the generated serializer() accessors. JSON keys come from the
#   generated descriptors, so renaming does not change stored state.
# - The only manifest component (MainActivity) is kept by AAPT's generated rules.
# - androidx.graphics.path's JNI methods are kept by the default
#   "keepclasseswithmembernames ... native <methods>" rule.
# - No Class.forName, ServiceLoader, Resources.getIdentifier or other reflection.
#
# Add a precise -keep rule here, with a reason, if that changes.
