# SHU - Shell Script Utils

SHU is a shell script framework that brings reusable architecture patterns to Bash scripts, especially:

- Object-oriented style helpers
- Structured return and error conventions
- Utility functions for argument parsing, stack traces, and output
- Streams, channels, scheduler helpers, tests, logging, and serialization

The core of SHU is [common/misc.sh](common/misc.sh), which provides the object system and foundational helpers used by the other modules.

## Core conventions

These conventions are central to SHU and should be followed in all modules:

- `_r` is the default return value channel for functions.
- `_error` is the default error channel for functions.
- Functions should append context to `_error` and return non-zero on failure.
- Capitalized function names are considered public.
- Lowercase function names are considered private.

In SHU style, visibility is applied by convention and naming. Keep APIs explicit and consistent.

## Project structure

- [common/misc.sh](common/misc.sh): Core runtime (object system, import mechanism, interfaces, diagnostics, utilities)
- [common/channel.sh](common/channel.sh): File-backed channel for shell/subshell communication
- [common/stream.sh](common/stream.sh): In-memory event stream (pub/sub)
- [common/tests.sh](common/tests.sh): Lightweight test/assertion utilities
- [logger/logger.sh](logger/logger.sh): Logger facade and named loggers
- [logger/drivers/console.sh](logger/drivers/console.sh): Console logger driver
- [logger/drivers/filewriter.sh](logger/drivers/filewriter.sh): File logger driver with compaction
- [serializers/jsonserializer.sh](serializers/jsonserializer.sh): JSON serializer (requires `jq`)
- [gittools/gittools.sh](gittools/gittools.sh): Git-oriented utilities (work in progress)

## Quick start

### 1. Load SHU

```bash
#!/usr/bin/env bash

source "./common/misc.sh"
source "./common/stream.sh"
source "./common/channel.sh"
source "./common/tests.sh"
source "./serializers/jsonserializer.sh"
```

You can load modules directly, or use `misc.import`/`misc.using` to resolve by filename recursively.

### 2. Create and use an object

```bash
#!/usr/bin/env bash
source "./common/misc.sh"

o.New "MyClass"; obj="$_r"
o.Set "$obj.name" "SHU"
o.Get "$obj.name"
echo "name=$_r"
```

### 3. Standard return/error flow

```bash
my.Function(){
	local input="$1"
	if [ -z "$input" ]; then
		_error="input is required"
		_r=""
		return 1
	fi

	_r="ok:$input"
	_error=""
	return 0
}
```

## `common/misc.sh` highlights

### Import helpers

- `misc.import <filename> [ignoreAlreadyLoaded=true] [rootPath=$PWD]`
- `misc.using` and `using` aliases

### Object helpers (`o.*`)

- `o.New [ClassName]`
- `o.Set <obj[.path]> <value>`
- `o.Get <obj[.path]>`
- `o.Has <obj[.path]>`
- `o.Delete <obj[.path]>`
- `o.ListProps <obj>`
- `o.Destroy <obj> [destroyChildren=false]`
- `o.Call <obj> <Method> [args...]` or `o.Call <obj.Method> [args...]`
- `o.Implements <objOrClass> <Interface...>`
- `o.Serialize` / `o.Deserialize`

### Interface and anonymous class support

- `o.DeclareInterface <InterfaceName> <Method...>`
- `o.NewAnon` / `o.NewAnonymous`

### Diagnostics and utility

- `misc.StackTraceToString`
- `misc.Call` / `Call` / `misc.Eval`
- `misc.PrintError` and color helpers
- `misc.GetArgByName`, `misc.FindArg`, `misc.ParseOptions`
- `misc.SourceUrl` (download and cache script from URL)

## Modules

### Channels (`common/channel.sh`)

Channel is designed for communication across subshells and process boundaries.

Main API:

- `Channel.New [sharedFilename]`
- `Channel.Set <ch> <prop> <value>`
- `Channel.Send <ch>`
- `Channel.WaitNext <ch> [asObject=false]`
- `Channel.Get <ch> <prop>`
- `Channel.Restart <ch>`

Example:

```bash
source "./common/misc.sh"
source "./common/channel.sh"

Channel.New; ch="$_r"

(
	Channel.Set "$ch" "message" "hello"
	Channel.Set "$ch" "id" "42"
	Channel.Send "$ch"
) &

Channel.WaitNext "$ch" true; payload="$_r"
o.Get "$payload.message"; echo "message=$_r"
o.Get "$payload.id"; echo "id=$_r"
```

### Streams (`common/stream.sh`)

In-memory publish/subscribe mechanism.

Main API:

- `Stream.New`
- `Stream.Listen <stream> <callback>`
- `Stream.Post <stream> <data...>`
- `Stream.GetLast <stream>`

Aliases: `Stream.Subscribe`, `Stream.Publish`, `Stream.Emit`, `Stream.Write`.

### Scheduler (`common/scheduler.sh`)

Provides queue and periodic task execution helpers.

Main API:

- `Scheduler.New`
- `Scheduler.Run <scheduler> <task>`
- `Scheduler.Periodic <scheduler> <task> <intervalMs> [firstShotImmediately=false]`
- `Scheduler.DelayedTask <scheduler> <task> <delayMs>`
- `Scheduler.RunOnRound <scheduler>`
- `Scheduler.RunLoop <scheduler> <sleepSeconds>`

Note: this module appears to be evolving and may need fixes/cleanup before production usage.

### Tests (`common/tests.sh`)

Simple test output and assertion helpers.

Main API:

- `Tests.BeginGroup` / `Tests.EndGroup`
- `Tests.BeginTest` / `Tests.EndTest`
- Assertions like:
  - `Tests.AreEquals`
  - `Tests.IsTrue`
  - `Tests.Contains`
  - `Tests.FileExists`
- `Tests.PrintSummary`

### Logger (`logger/`)

Driver-based logger architecture with console/file drivers.

Main API:

- `logger.New [--drv ...]`
- `logger.WithConsole [allowedSeverities] [allowColors=true]`
- `logger.WithFile <filename> <maxSizeBytes> [allowedSeverities]`
- `logger.GetNamedLogger <logObj> <name>`
- `logger.Trace|Debug|Info|Warn|Error|Fatal`

Drivers:

- `logger.consoleDriver` in [logger/drivers/console.sh](logger/drivers/console.sh)
- `logger.fileDriver` in [logger/drivers/filewriter.sh](logger/drivers/filewriter.sh)

### JSON serializer (`serializers/jsonserializer.sh`)

Implements serializer operations with dotted keys and nested JSON via `jq`.

Main API:

- `JsonSerializer.New`
- `JsonSerializer.Set <serializer> <key> <value>`
- `JsonSerializer.Get <serializer> <key>`
- `JsonSerializer.List <serializer>`
- `JsonSerializer.Serialize <serializer>`
- `JsonSerializer.Deserialize <serializer> <json>`

Dependency:

- `jq` must be installed.

## Error handling guidance

Recommended pattern for SHU functions:

1. Validate inputs early.
2. Set `_error` with contextual message on failures.
3. Return `1` (or non-zero) when failing.
4. Use `_r` for result output when successful.
5. Clear `_error` (`_error=""`) on success paths.

Example with contextual propagation:

```bash
my.Parent(){
	my.Child "$1"
	if [ "$?" -ne 0 ]; then
		_error="my.Parent failed: $_error"
		return 1
	fi
}
```

## Notes on maturity

Some modules contain TODOs and partially implemented APIs (notably [gittools/gittools.sh](gittools/gittools.sh), and parts of scheduler/logger internals). SHU already provides useful primitives, but verify behavior for your target use case and add tests for critical paths.

## Suggested next improvements

- Add runnable examples under an `examples/` folder.
- Add integration tests for channel/scheduler/logger modules.
- Normalize naming/typos across modules (for example, `PriodicTask` naming).
- Add a top-level loader script that sources modules in a stable order.
