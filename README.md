# Amphetanim

Just playing with different ideas for composition

## Current Composition Idea

Container ref object = Amphetanim

Principally this is just so that the container ref can be aligned to cache lines
according to the measured cache line size and size of the object variant/composed
object.

Amphetanim contains 2 fields, the true AmphetanimObj (which is a variable object)
and the second field is simply the padding field.

Initial amphetanim variant is just the simple cubby concept.

The cubby contains an aligned atomic pointer to a Slot. The alignment is filled
with a counter. Pushing onto the cubby increases the counter. Popping off the
cubby decreases the counter. This is used to measure backpressure.

- A counter value of 0 means the slot is empty with no pressure.
- A counter value of 1 means the slot is filled with no pressure.
- A counter value > 1 means the slot is filled with push backpressure
  - This means there are threads waiting for the value to be popped so they can resume
- A counter value < 0 means the slot is empty with pop backpressure
  - This means there are threads waiting for the value to be pushed so they can resume

Futex is the primitive used for building backpressure.

When a thread is allowed to push, they will visit the slot, and perform a fetchAdd
of the element with a writer bit. It will then ensure the value was empty before.
If not then it will have to be handled as necessary.

When a thread is allowed to pull, they will visit the slot, and perform a fetchAdd
of the element with a read bit. It will ensure it has sole read ownership of the slot. It will then consume the slot, and clear it. If it did not have sole read
ownership, or nothing had yet been written to the slot, then it will have to handle
that as necessary.
Once completed with its operation of the slot, should there have been backpressure, the thread will wake the next operation pending.

In this scenario, we want the counter and slot to be on separate cache lines.
Contention on the counter will not prevent threads consuming the slots since only the counter cache line will be invalidated by contention. For this reason, the cubby contains an aligned pointer to a slot rather than a slot and a counter on the same line.

Current issues: This does not handle unbalanced backpressure safely yet. Should there be 5 pushes pending, and then 5 pops occur simultaneously, each thread will recognise that it should be safe to consume the slot. However, all 5 threads cannot consume the slot at the same time, the realistic order of operations should be that each pop thread has to cycle and take turns in a round robbin fashion consuming the slot and then resuming the pending push operation before consuming and so on and so on.

Of course at low contention, there will be no issues with this design.