// cc -I../../tweak/Sources minimize-check.c -lm -o minimize-check && ./minimize-check
#include <assert.h>
#include <stdio.h>
#include "Redesigned/Navbar/MinimizeStep.h"

int main(void) {
    SGRMinimizeTrack t = {0, false};
    assert(!SGRMinimizeStep(&t, 23, 0, 1000));
    assert(SGRMinimizeStep(&t, 24, 0, 1000));
    assert(SGRMinimizeStep(&t, 100, 0, 1000));
    assert(SGRMinimizeStep(&t, 77, 0, 1000));
    assert(!SGRMinimizeStep(&t, 76, 0, 1000));
    assert(SGRMinimizeStep(&t, 100, 0, 1000));
    // Bottom overscroll and its spring-back must not look like a direction reversal.
    assert(SGRMinimizeStep(&t, 1100, 0, 1000));
    assert(SGRMinimizeStep(&t, 1000, 0, 1000));
    assert(!SGRMinimizeStep(&t, 976, 0, 1000));
    // Insets and a bounce at the top always restore the original navbar.
    t = (SGRMinimizeTrack){200, true};
    assert(!SGRMinimizeStep(&t, -120, -64, 1000));
    assert(!SGRMinimizeStep(&t, -64, -64, 1000));
    // A short page does not collapse. A shortened page at its top must still expand.
    t = (SGRMinimizeTrack){0, false};
    assert(!SGRMinimizeStep(&t, 100, 0, 119));
    t = (SGRMinimizeTrack){200, true};
    assert(!SGRMinimizeStep(&t, 0, 0, 50));
    t = (SGRMinimizeTrack){200, true};
    assert(!SGRMinimizeStep(&t, 0, 0, -50));
    // Rapid reversals remain repeatable; sub-threshold jitter does not change state.
    t = (SGRMinimizeTrack){0, false};
    for (int i = 0; i < 100; i++) {
        assert(SGRMinimizeStep(&t, 24, 0, 1000));
        assert(SGRMinimizeStep(&t, 20, 0, 1000));
        assert(!SGRMinimizeStep(&t, 0, 0, 1000));
    }
    puts("PASS: collapse, reversal, jitter, insets, overscroll, short pages, repeated transitions");
    return 0;
}
