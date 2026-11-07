#ifndef US_FEED_BRIDGE_H
#define US_FEED_BRIDGE_H
#include <stdbool.h>
#ifdef __cplusplus
extern "C" {
#endif
// The argument is a borrowed USResponseTransaction Objective-C instance.
// Swift exports this exact C symbol; no Objective-C class symbol is required.
bool USAttachEeveeFeed(void *transaction);
#ifdef __cplusplus
}
#endif
#endif
