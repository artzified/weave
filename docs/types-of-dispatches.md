# Types of Job Dispatches

Weave has four ways to dispatch a job. They all distribute work across actors the same way. The difference is what happens after the workers finish.

---

## Dispatch

The standard dispatch. The master sends work out, workers process it and send results back, and the master calls your callback once every actor has reported in.

```lua
dispatcher:Dispatch(name, threadCount, callback, batchSize?, ...)
```

Internally, each worker writes its results into a shared buffer as it finishes. The bridge tracks how many responses it expects based on how many actors were assigned work, and fires the callback the moment that count is met.

```lua
dispatcher:Dispatch("trackedJob", 1000, function(buf)
    -- buf[i] is the return value from thread i
    -- buf is guaranteed to be fully populated by the time this runs
    for i, result in buf do
        processResult(i, result)
    end
end)
```

**When to use it:** Any time you need the results. Raycasts, pathfinding queries, sensor sweeps, anything where the worker computes a value the master needs to act on.

:::note
The callback fires on the main thread, so it's safe to read and write to shared game state inside it.
:::

---

## DispatchDetached

A fire-and-forget dispatch. Workers run the job, and the master is never notified. No result buffer is allocated, no registry entry is created, and no callback is ever fired.

```lua
dispatcher:DispatchDetached(name, threadCount, batchSize?, ...)
```

```lua
-- Returns immediately. Workers run the job silently.
dispatcher:DispatchDetached("updateParticles", 10000, nil, dt)
```

Because there is no completion signal, the worker side uses `OnDetached` rather than `On`. The kernel handler discards the return value and never fires the messenger back to the master.

```lua
-- worker
kernel:OnDetached("updateParticles", function(id, dt)
    simulateParticle(id, dt)
    -- return value is silently dropped
end)
```

**When to use it:** Side-effect work where the master doesn't need to know when it's done or what the result was. Terrain generation, particle simulation, audio occlusion updates, any fire-and-forget computation.

### Why not just ignore the callback in Dispatch?

Skipping the callback isn't the same thing. A normal `Dispatch` still allocates a result buffer (`table.create(threadCount)`), registers an entry in the bridge registry, and has every worker fire the messenger on completion. For a 10,000-thread dispatch running every frame, that's a 10,000-slot table being allocated and garbage collected 60 times a second, plus constant registry churn on the main thread.

`DispatchDetached` doesn't do any of that. The cost difference is most visible in memory profiles over time rather than in single-frame timing.


## Deferred Dispatches

Identical to their `Dispatch` counterparts in every way except the dispatch itself is queued with `task.defer` rather than running immediately. The job is scheduled to start at the next resumption opportunity rather than the current frame.

```lua
dispatcher:DispatchDeferred(name, threadCount, callback, batchSize?, ...)
dispatcher:DispatchDetachedDeferred(name, threadCount, callback, batchSize?)
```

```lua
-- This returns immediately. The actual dispatch happens on the next step.
dispatcher:DispatchDeferred("trackedJob", 1000, function(buf)
    processResults(buf)
end)

-- This returns immediately. The actual dispatch happens on the next step.
dispatcher:DispatchDetachedDeferred("detachedJob", 1000, function(buf)
    processResults(buf)
end)
```

:::tip
`DispatchDeferred` and `Dispatch` have identical performance characteristics once the job actually starts. The only difference is the scheduling delay before dispatch begins.
:::

---

## Comparison

| Method | `Dispatch` | `DispatchDetached` |
|---|---|---|
| Result buffer allocated | ✓ | ✗ |
| Callback fires on completion | ✓ | ✗ |
| Worker uses | `kernel:On` | `kernel:OnDetached` |
| Main thread overhead | Registry + Callback | None |

---

## Passing Arguments to Workers

All dispatch types forward extra arguments to the worker handler. These are passed after the required parameters.

```lua
-- Extra args come after batchSize (pass nil to use the default)
dispatcher:Dispatch("myJob", 1000, callback, nil, argA, argB)
dispatcher:DispatchDetached("myJob", 1000, nil, argA, argB)
```

Inside the worker, they arrive after `id`:

```lua
kernel:On("myJob", function(id, argA, argB)
    -- argA and argB are available on every thread
end)
```

:::caution
Arguments are sent via `Actor:SendMessage`, which means they must be serializable Roblox types. Functions, metatables, and non-serializable userdata will error.
:::