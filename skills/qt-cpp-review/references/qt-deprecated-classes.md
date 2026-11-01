# Qt/std Classes That Should Not Be Used in Qt Implementation

Reference for the `lint-deprecated.sh` script and deep analysis.

## Qt Classes → Replacements

| Deprecated | Replacement | Rationale |
|------------|-------------|-----------|
| Java-style iterators | STL iterators | `QT_NO_JAVA_STYLE_ITERATORS` |
| `Q_FOREACH` | Range-based for | `QT_NO_FOREACH` |
| `QScopedPointer` | `std::unique_ptr` | Can't be moved; use `const unique_ptr` for scoped semantics |
| `QSharedPointer` / `QWeakPointer` | `std::shared_ptr` / `std::weak_ptr` | QSP needs 2× atomic ops on copy |
| `QAtomic*` | `std::atomic` | Exception: static `QBasicAtomic*` (no runtime init) |
| `q(v)nprintf()` | `std::(v)snprintf()` | Platform-dependent fallbacks; must `#include <cstdio>` |
| `qMin`/`qMax`/`qBound` | `(std::min)()` / `(std::max)()` / `std::clamp()` | Mixed-type args are harder to understand; note arg order difference |
| `count()` / `length()` | `size()` | Consistency with std library |

Not flagged in Qt 5 code: `QPair` (idiomatic in Qt 5; `std::pair` also
works), `QSharedDataPointer` (the normal Qt 5 COW idiom), `QChar`
(the normal Qt 5 character type), `QRegExp` (still shipped in Qt 5 —
though `QRegularExpression` is preferred for new code), and
`Q_DECLARE_METATYPE` (required in Qt 5 for custom types in
`QVariant`/queued signal arguments).

## std Classes → Replacements

| Deprecated | Replacement | Rationale |
|------------|-------------|-----------|
| `std::mutex` | `QMutex` | QMutex uses futexes (faster). Exception: std::mutex + std::condition_variable combo is more efficient than QMutex + QWaitCondition |

## Anti-Patterns (not class-specific)

| Pattern | Fix | Rule |
|---------|-----|------|
| `std::optional::value()` | Use `*opt`, `opt->foo`, `if (opt)` | Throws on empty; use pointer-compatible subset |
| `std::optional{}` default ctor | Use `std::nullopt` explicitly | GCC maybe-unused warning bug |
| `std::has_alternative<T>` + `get<T>` | Use `get_if<T>` or `std::visit` | DRY; Coverity false positives |
| `p = realloc(p, ...)` | `tmp = realloc(p, ...); check; p = tmp;` | Leaks on failure |
| `std::make_unique<T[]>(n)` for scalar T | `std::vector<T>` or `std::unique_ptr<T[]>` with explicit fill policy | Value-init zeros memory unnecessarily |
| `value_or()` with non-trivial arg | Ternary or if/else | Arg always evaluated |
| `QDateTime::currentDateTime()` | `currentDateTimeUtc()` | 100× faster, stable across DST |
| `QThreadPool::globalInstance()` + blocking | Dedicated pool or `releaseThread()` | Deadlock risk |
