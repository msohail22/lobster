# Everything Used in the ClickHouse Codebase

A ranked reference of every C++ feature, standard-library name, printing/logging idiom, ClickHouse class,
macro, CMake command, test helper and tool used in the [ClickHouse](https://github.com/ClickHouse/ClickHouse)
repository — counted from the real code, most-used first.

> How to use this file: give it to an AI tutor and say *"Teach me the rows of section X one by one: explain
> what it is, show me the real example, then quiz me."* Or search it (`Ctrl+F`) when you meet a name you
> don't know while reading ClickHouse code.

## How this was made

- **Source:** ClickHouse `master` as of 2026-09-28 (commit `1e5291bf9d4`).
- **Counted:** `*.cpp` / `*.h` in `src/`, `programs/`, `base/`, `utils/` with `ripgrep`; CMake files, tests and CI
  files separately. `contrib/` (third-party code, 150+ submodules) is **excluded**.
- **"Uses" = number of matching lines**, not a perfect semantic count. Common names (`next`, `get`, `Context`)
  can be inflated by unrelated matches; rows where this matters say so.
- **Examples are real lines** copied from the repository (shortened to ≤ 80 characters where needed).
- Nothing is too small: `std::endl`, `<< '\n'` and `<< "\n"` are separate rows on purpose.

## The repository in numbers

| What | Count |
|---|---|
| C++ source files (`.cpp`) | 5,529 |
| C++ headers (`.h`) | 4,706 |
| Lines of C++ in `src/` | ~2.4 million |
| SQL test files (`.sql`) | 11,990 |
| Test reference files (`.reference`) | 15,847 |
| Shell scripts (`.sh`) | 4,108 |
| Python files (`.py`) | 2,779 |
| Documentation pages (`.mdx`) | 24,324 |
| Third-party submodules in `contrib/` | 154 |

## Contents

1. [C++ language and standard library](#1-c-language-and-standard-library) — language features, `std::` by category, third-party libraries, ClickHouse replacements for `std` things
2. [Printing, logging, formatting, errors and I/O buffers](#2-printing-logging-formatting-errors-and-io-buffers) — every variant of `cout`/`cerr`/`fmt`, `WriteBuffer`/`ReadBuffer`, `LOG_*`, exceptions, error codes, metrics
3. [ClickHouse's own concepts, classes and functions](#3-clickhouses-own-concepts-classes-and-functions) — map of `src/`, columns and data types, query path, storage, functions, infrastructure, most-called methods, macros
4. [Build system, tests, CI and other languages](#4-build-system-tests-ci-and-other-languages) — file types, CMake commands and options, tooling, stateless/integration/perf/unit/fuzz tests, CI jobs

---

## 1. C++ language and standard library

ClickHouse is compiled as **C++23**: the top-level `CMakeLists.txt` sets `set (CMAKE_CXX_STANDARD 23)` and `set (CMAKE_CXX_STANDARD_REQUIRED ON)`. The compiler is Clang and the standard library is LLVM `libc++` (bundled in `contrib/`), which is why `std::__1` appears in some stack-trace strings.

Counts are the number of matching lines in `*.cpp` / `*.h` under `src/`, `programs/`, `base/`, `utils/` (third-party `contrib/` excluded). They are regex matches, so treat them as "how common", not exact. Coroutines (`co_await`, `co_yield`, `co_return`) have **0** uses; `std::format` has 2 (ClickHouse uses `fmt::format` instead); `std::regex` has 0 (ClickHouse uses `re2`).

### 1.1 Language features

| Name | Uses | What it is | Example |
|---|---|---|---|
| `auto x = ...` | 47132 | Let the compiler deduce a variable's type | `auto buffer = snapshot_manager->deserializeLatestSnapshotBufferFromDisk();` |
| `override` | 24183 | Marks a virtual function as overriding a base one | `void cancel() noexcept override;` |
| `const auto &` | 20350 | Read-only reference with deduced type, avoids copies | `const auto & settings = context->getSettingsRef();` |
| `static_cast<T>` | 13100 | Checked, compile-time type conversion | `host.original_index = static_cast<UInt8>(connection_info_idx);` |
| `class` | 13057 | Declares a type with private-by-default members | `class DataTypeLowCardinality final : public IDataType` |
| `constexpr` | 12267 | Value or function computable at compile time | `constexpr auto clock_type = CLOCK_MONOTONIC;` |
| `nullptr` | 11184 | Typed null pointer literal (never `NULL`/`0`) | `ThreadImpl * ThreadImpl::currentImpl() { return nullptr; }` |
| `const String &` parameter | 10787 | Pass large objects by const reference | `void validateMode(const std::string & mode)` |
| `for (const auto & x : c)` | 9586 | Range-based for loop, read-only elements | `for (const auto & column : header)` |
| `case X:` / `switch` | 9441 | Multi-way branch on an integer or enum | `case Coordination::OpNum::Set:` |
| `template <...>` | 8867 | Generic code parameterised by types or values | `template <typename T>` |
| `using X = Y;` alias | 8677 | Modern replacement for `typedef` | `using TopicPartitionOffsets = std::vector<TopicPartitionOffset>;` |
| `struct` | 8541 | Declares a type with public-by-default members | `struct ClusterFunctionReadTaskResponse;` |
| `R"(...)"` raw string | 7920 | String literal without escape processing | `DECLARE(Bool, compile_sort_description, true, R"(` |
| `public:` / `private:` / `protected:` | 6604 | Access specifiers inside classes | `private: // IAccessStorage implementations.` |
| `? :` ternary | 6654 | Inline if-else expression | `.withType(data.type ? codebook_type : nullptr)` |
| `const auto *` | 6239 | Pointer-to-const with deduced type | `if (const auto * literal = dynamic_cast<const ASTLiteral *>(&node))` |
| `template <typename T>` | 5882 | Template taking a type parameter | `template <typename Data>` |
| `[&]` lambda capture | 5410 | Lambda captures everything by reference | `const auto has_more = [&]() -> bool` |
| `static constexpr` member | 5318 | Class-level compile-time constant | `static constexpr int32_t LOG_HEADER = 1514884167;` |
| `auto &` (non-const) | 5174 | Mutable reference with deduced type | `auto & ranges = parts_with_ranges[part_index];` |
| `virtual` | 4866 | Function dispatched at run time via vtable | `virtual ~IServer() = default;` |
| `const char *` | 4827 | C string pointer, still common for names | `extern const char * GIT_HASH;` |
| Designated initializers `.a = x` | 4261 | Initialise struct fields by name (C++20) | `.authenticated_user = inserter.authenticated_user,` |
| `#pragma once` | 4175 | Include guard in every header | `#pragma once` |
| `if constexpr` | 3910 | Compile-time branch, discarded branch not instantiated | `if constexpr (std::is_same_v<ReturnType, void>)` |
| `inline` | 3801 | Allows definition in header; inlining hint | `inline bool mulOverflow(UInt128 x, UInt128 y, UInt128 & res)` |
| `explicit` | 3627 | Forbids implicit conversions via constructor | `explicit ParserAlias(bool allow_alias_without_as_keyword_)` |
| `this->` | 3516 | Explicit member access, needed in dependent templates | `if (this->pptr() && this->pptr() > this->pbase())` |
| `sizeof(...)` | 3367 | Size of a type or object in bytes | `constexpr auto q = sizeof(T);` |
| `if (auto x = ...)` | 3168 | Declare variable in the if condition | `if (auto original = columns.tryGetByName(required_column.name))` |
| `try` block | 3122 | Start of exception-handling region | `try` |
| `return *this;` | 3081 | Return self, e.g. from `operator=` or builders | `return *this;` |
| `[]` lambda (no capture) | 2942 | Stateless lambda, convertible to function pointer | `auto call_reads_representation = [](const Node * node)` |
| `reinterpret_cast<T>` | 2911 | Reinterpret bits of a pointer as another type | `_mm_store_si128((reinterpret_cast<__m128i*>(dst) + 3), c3);` |
| `constexpr auto` | 2770 | Compile-time constant with deduced type | `static constexpr auto DEFAULT_ZOOKEEPER_BASE_PATH = "/clickhouse/acme";` |
| `for (auto & x : c)` | 2493 | Range-based for loop, mutable elements | `for (auto & key : grouping_sets_parameter.used_keys)` |
| `if (const auto * p = cast)` | 2409 | Cast-and-test idiom in one line | `if (const auto * col_str = typeid_cast<const ColumnString *>(column.get()))` |
| `auto *` | 2295 | Mutable pointer with deduced type | `auto * cast_function = getSourceExpression()->as<FunctionNode>();` |
| `class X : public Base` | 2266 | Public inheritance | `class KeeperStorage : public std::enable_shared_from_this<KeeperStorage>` |
| `catch (...)` | 1910 | Catch any exception | `catch (...) // Ok: handle_unexpected_exception logs all details` |
| `final` class | 1868 | Class cannot be inherited from; enables devirtualisation | `class DataTypeLowCardinality final : public IDataType` |
| `static const` | 1862 | Function-local or class constant initialised once | `static const VersionToSettingsChangesMap history = []` |
| `= default` | 1774 | Ask compiler to generate special member | `QueryPipelineBuilder(QueryPipelineBuilder &&) = default;` |
| `requires` | 1703 | Constrain templates (C++20 concepts) | `requires std::is_fundamental_v<std::decay_t<T>>` |
| `[x]` single capture | 1653 | Capture one named variable (or `this`) | `[this](ReadBuffer & payload_in)` |
| `noexcept` | 1612 | Promise the function never throws | `void cancel() noexcept override;` |
| `for (const auto & [k, v] : m)` | 1567 | Structured binding in range-for over maps | `for (const auto & [old_id, server_config] : old_ids)` |
| `new T` | 1520 | Raw heap allocation (rare outside low-level code) | `return boost::intrusive_ptr<T>(new T(std::forward<Args>(args)...));` |
| `#if defined` / `#ifdef` | 1480 | Conditional compilation per platform/feature | `#if defined(OS_DARWIN)` |
| `[](auto & x)` generic lambda | 1302 | Lambda with `auto` parameters (template lambda) | `[&](auto & frame_node)` |
| `operator()` | 1306 | Makes an object callable (functor, visitor) | `String operator() (const Int128 & x) const;` |
| `mutable` | 1284 | Member modifiable in const method; mutable lambda | `mutable std::mutex mutex;` |
| `__restrict` | 1262 | Promise pointers do not alias (optimisation) | `ConstAggregateDataPtr __restrict place,` |
| `throw;` rethrow | 1260 | Rethrow the current exception unchanged | `throw; /// Re-throw hardware errors so the caller can handle them` |
| `if (init; cond)` | 1170 | If with initializer statement (C++17) | `if (auto it = values.find(String{name}); it != values.end())` |
| `constexpr bool` | 1100 | Compile-time boolean flag, often a template switch | `static constexpr bool return_timestamp = return_timestamp_;` |
| `auto [a, b] = ...` | 1095 | Structured bindings: unpack pair/tuple/struct | `auto [pipeline_builder, parallel_replicas_info] = ...` |
| `catch (const E & e)` | 1090 | Catch by const reference | `catch (const std::exception & e)` |
| `dynamic_cast<T>` | 1009 | Runtime-checked downcast (ClickHouse prefers `typeid_cast`) | `if (dynamic_cast<const ReadFromPreparedSource *>(&step))` |
| `[[maybe_unused]]` | 1003 | Silence unused-variable warnings | `[[maybe_unused]] size_t max_parser_backtracks;` |
| `typedef` | 934 | Old-style type alias (mostly in Poco-derived code) | `typedef RunnableAdapter<C> RunnableAdapterType;` |
| `enum class` | 864 | Scoped, strongly typed enumeration | `enum class Mode` |
| `template class X<T>;` | 855 | Explicit template instantiation in a `.cpp` | `template class IntervalTree<Interval<UInt128>, IntervalTreeVoidValue>;` |
| `using namespace` | 851 | Bring a namespace's names into scope | `using namespace DB;` |
| `operator=` | 834 | Copy/move assignment operator | `OAuth20Credentials & operator=(const OAuth20Credentials &);` |
| `template <>` specialization | 783 | Full specialization of a template | `template <> struct std::hash<DB::JoinActionRef>` |
| `friend` | 713 | Grants another class/function private access | `friend class iterator;` |
| Fold expressions `(... op x)` | 661 | Apply an operator over a parameter pack | `return ((token == tokens) \|\| ...);` |
| `enum class X : uint8_t` | 660 | Scoped enum with explicit underlying type | `enum class InputType : uint8_t` |
| `[this]` capture | 610 | Lambda captures the enclosing object pointer | `[this] (AsyncLoader &, const LoadJobPtr &)` |
| `[[fallthrough]]` | 591 | Intentional fall-through between `case` labels | `[[fallthrough]];` |
| `template <bool B>` | 567 | Non-type template parameter used as a compile-time switch | `template <bool _enable>` |
| `decltype(expr)` | 541 | Type of an expression | `using Key = std::decay_t<decltype(std::declval<Value>().first)>;` |
| `::template` / `.template` | 835 | Disambiguate dependent member templates | `ArrayElementArrayNumImpl<DataType, mode>::template vector<IndexType, true>(` |
| `template <class T>` | 528 | Same as `typename` form, older style | `template <class T>` |
| `while (true)` | 525 | Infinite loop with explicit `break` | `while (true)` |
| `static_assert` | 523 | Compile-time assertion | `static_assert(sizeof(WasmBuffer) == 8, "WasmBuffer size must be 8 bytes");` |
| `extern template` | 453 | Suppress implicit instantiation (faster builds) | `extern template class FunctionComparison<EqualsOp, NameEquals, true>;` |
| `operator==` | 410 | Equality comparison operator | `bool operator==(const DeleteBitmapCacheKey & other) const` |
| Init capture `[x = std::move(y)]` | 406 | Capture by value with a new name / move | `[my_backup_entries = std::move(backup_entries),` |
| `thread_local` | 385 | One variable instance per thread | `static thread_local pcg64_fast random_generator{randomSeed()};` |
| `= delete` | 373 | Forbid a function (e.g. copying) | `Handle(const Handle &) = delete;` |
| `[&x]` reference capture | 367 | Capture one variable by reference | `waiting_pool.scheduleOrThrowOnError([&pool] { pool.wait(); });` |
| `typename T::member` | 354 | Name a dependent nested type | `using ValueType = typename MultiPolygon::value_type;` |
| `static inline` member | 345 | Inline static data member (C++17) | `static inline const char * name;` |
| `[[nodiscard]]` | 333 | Warn if return value is ignored | `[[nodiscard]] std::shared_ptr<Aws::Http::HttpRequest>` |
| `[[noreturn]]` | 290 | Function never returns (throws/aborts) | `[[noreturn]] void fail(const String & message) const;` |
| `typeid(x)` | 287 | Runtime type information | `if (root.type() != typeid(Poco::JSON::Object::Ptr))` |
| `const_cast<T>` | 269 | Remove `const` (use sparingly) | `ReadBuffer buffer(const_cast<char *>(value.data()), value.size(), 0);` |
| `[this, x]` capture | 269 | Capture `this` plus specific variables | `StopCallback stop_callback(stop_token, [this, stop_requested]` |
| `[&, x]` capture | 237 | All by reference, some by value | `workers.emplace_back([&, t]()` |
| `typename...` variadic template | 214 | Template accepting any number of types | `template <typename... Args>` |
| `template <size_t N>` | 190 | Integer non-type template parameter | `template <size_t size>` |
| `auto &&` forwarding reference | 189 | Binds to anything; used in generic loops | `for (auto && column_transformer : column_transformers_)` |
| `const auto [a, b]` | 184 | Read-only structured binding | `const auto [shared_data_paths, _] = column.getSharedDataPathsAndValues();` |
| `[[unlikely]]` | 184 | Branch-probability hint (C++20) | `if (added_columns.match_stats) [[unlikely]]` |
| CRTP (`Base<Derived>`) | 208 | Base class templated on derived for static dispatch | `class AggregateFunctionNullBase : public IAggregateFunctionHelper<Derived>` |
| `inline constexpr` variable | 170 | Header-defined compile-time constant | `template <> inline constexpr bool IsString<DataTypeString> = true;` |
| `extern "C"` | 162 | C linkage for interop with C libraries | `extern "C" {` |
| `noexcept override` | 159 | Non-throwing override | `void destroy(AggregateDataPtr __restrict) const noexcept override` |
| `__attribute__((...))` | 154 | GCC/Clang attribute syntax | `inline __attribute__((always_inline)) bool dictionaryIndexForConstant(` |
| `[]<typename T>` template lambda | 147 | Lambda with explicit template parameters (C++20) | `auto dispatchMyers = [&]<typename F>()` |
| `mutable` lambda | 154 | Lambda may modify its by-value captures | `auto match = [&pos, end](const char * str) mutable` |
| `operator[]` | 218 | Subscript operator | `KeyValuePair operator[](size_t index) const` |
| `operator<<` | 106 | Stream output operator | `inline std::ostream & operator<< (std::ostream & ostr, const Query & query)` |
| `[=]` capture | 104 | Capture everything by value (rare) | `threads.emplace_back([=] () { func(pool_size, round); });` |
| `volatile` | 94 | Prevent compiler optimising accesses away | `volatile int y = 1;` |
| `union` | 93 | Overlapping storage for different types | `union ldshape {` |
| `alignof` | 85 | Alignment requirement of a type | `static constexpr size_t MALLOC_MIN_ALIGNMENT = alignof(std::max_align_t);` |
| `alignas` | 81 | Force alignment (e.g. cache line) | `struct alignas(CH_CACHE_LINE_SIZE) ParsedValue` |
| `concept` | 77 | Named compile-time type predicate (C++20) | `concept FLOAT = std::is_same_v<T, Float32> \|\| std::is_same_v<T, Float64>;` |
| `Args && ... args` | 73 | Variadic perfect-forwarding parameters | `explicit WrapperGuard(std::unique_ptr<Holder> holder_, Args && ... args)` |
| `explicit operator bool` | 69 | Safe boolean conversion | `explicit operator bool() const { return !isEmpty(); }` |
| `asm` / `__asm__` | 68 | Inline assembly | `__asm__ volatile ("nop");` |
| `goto` | 62 | Jump to label (used in hot decompression loops) | `goto decompress_match;` |
| `char8_t` / `u8""` | 57 | UTF-8 character type and literal (C++20) | `for (char8_t local_discr : local_discriminators)` |
| `[[likely]]` | 43 | Branch-probability hint (C++20) | `if (xirr.has_value()) [[likely]]` |
| `constinit` | 37 | Guarantee static init at compile time (C++20) | `static constinit bool can_use_cache = false;` |
| `consteval` | 35 | Function must run at compile time (C++20) | `static consteval size_t getDefaultMaxSize() { return 1048576; }` |
| `sizeof...(pack)` | 29 | Number of elements in a parameter pack | `new_arguments.reserve(sizeof...(args));` |
| `offsetof` | 21 | Byte offset of a struct member | `static constexpr size_t denominator_offset = offsetof(Fraction, denominator);` |
| `operator<=>` | 20 | Three-way "spaceship" comparison (C++20) | `auto operator<=>(const PartitionCursor & other) const = default;` |
| `[=, this]` capture | 20 | By value plus explicit `this` (C++20 style) | `res.addAfterEvictStateCallback([=, this](const CacheStateGuard::Lock & lk)` |
| SFINAE `std::enable_if` | 20 | Pre-concepts template constraint trick | `const typename std::enable_if<true, T>::type & src)` |
| `decltype(auto)` | 13 | Deduce type preserving references | `decltype(auto) castToNearestFieldType(T && x)` |
| User-defined literal `operator""` | 7 | Custom literal suffix such as `_MiB` | `constexpr size_t operator""_TiB(unsigned long long val) { return val * TiB; }` |
| Class template argument deduction | 78 | Omit template args, e.g. `std::pair{a, b}` | `res.dependencies.emplace(id, std::pair{name, type});` |

### 1.2 Containers

| Name | Uses | What it is | Example |
|---|---|---|---|
| `.push_back` | 10166 | Append a copy/move to a sequence container | `tables.push_back(table_name);` |
| `std::vector` | 9916 | Dynamic contiguous array | `std::vector<std::pair<ASTPtr, StoragePtr>> result;` |
| `.emplace_back` | 5488 | Construct element in place at the end | `sort_description.emplace_back(key_name);` |
| `.data()` | 4890 | Raw pointer to contiguous storage | `ReadBuffer buffer(const_cast<char *>(value.data()), value.size(), 0);` |
| `.find` | 3132 | Look up a key in a map/set or substring | `auto it = scope.table_expression_node_to_data.find(source);` |
| `.contains` | 2975 | Membership test for maps/sets (C++20) | `return !reserved_param_names.contains(name);` |
| `.reserve` | 2932 | Pre-allocate capacity to avoid reallocations | `offsets.reserve(hierarchy_keys_size);` |
| `.emplace` | 2228 | Construct element in place (map/set/optional) | `held_entry.emplace(std::move(prepared->entry));` |
| `std::unordered_map` | 2071 | Hash table keyed map | `std::unordered_map<const IAST *, ASTPtr> debug_visited_nodes;` |
| `.resize` | 2038 | Change element count | `temp_buffer.resize(num_values);` |
| `std::unordered_set` | 1219 | Hash set | `std::unordered_set<std::string> replacement_names_set;` |
| `std::map` | 679 | Ordered (red-black tree) map | `std::map<String, PartBlockNumberRanges> ranges;` |
| `std::set` | 540 | Ordered set | `std::set<IASTHash> hashes;` |
| `std::array` | 429 | Fixed-size array with value semantics | `std::array<UInt64 *, 2> signal_queue{&signal_queue_size, &signal_queue_limit};` |
| `std::span` | 414 | Non-owning view over contiguous data (C++20) | `std::span<const std::string_view> suffixesForType(std::string_view type)` |
| `std::list` | 209 | Doubly linked list (LRU queues) | `using LRUQueue = std::list<EntryPtr>;` |
| `std::initializer_list` | 143 | Brace-list parameter type | `::testing::ValuesIn(std::initializer_list<TimeRangeParam>{` |
| `.try_emplace` | 131 | Insert only if key is absent | `table_it = table_mixers.try_emplace(key).first;` |
| `std::deque` | 112 | Double-ended queue, stable references | `using NullmapList = std::deque<NullMapHolder>;` |
| `std::stack` | 87 | LIFO adaptor | `std::stack<const ActionsDAG::Node *> nodes;` |
| `.insert_or_assign` | 47 | Insert or overwrite a map entry | `it = granted_role_ids.insert_or_assign(role_name, *role_id).first;` |
| `std::queue` | 44 | FIFO adaptor | `std::queue<const ActionsDAG::Node *> queue;` |
| `.shrink_to_fit` | 19 | Release unused capacity | `getOffsets().shrink_to_fit();` |
| `std::priority_queue` | 18 | Heap-based priority queue | `using DistanceIndexQueue = std::priority_queue<DistanceIndex>;` |
| `std::multiset` | 18 | Ordered set allowing duplicates | `std::multiset<QueryToTrack, CompareEndTime> query_set;` |
| `std::bitset` | 14 | Fixed-size bit array | `using Flags = std::bitset<AccessFlags::SIZE>;` |
| `std::multimap` | 13 | Ordered map allowing duplicate keys | `using ElementsByIdentifier = std::multimap<ElementIdentifier, Node *>;` |
| `std::piecewise_construct` | 13 | Construct pair members from separate tuples | `auto [it, inserted] = cells.emplace(std::piecewise_construct,` |
| `std::unordered_multimap` | 3 | Hash map allowing duplicate keys | `static const std::unordered_multimap<std::type_index, const std::type_info &>` |
| `std::forward_list` | 2 | Singly linked list | `using Container = std::forward_list<BufferBase::Buffer>;` |

### 1.3 Smart pointers and memory

| Name | Uses | What it is | Example |
|---|---|---|---|
| `std::make_shared` | 13526 | Allocate object and control block in one go | `return std::make_shared<MessageQueueSink>(` |
| `std::shared_ptr` | 4905 | Reference-counted shared ownership | `using ObjectIterator = std::shared_ptr<IObjectIterator>;` |
| `std::make_unique` | 3534 | Allocate object owned by a `unique_ptr` | `data.set(std::make_unique<BlocksWithCounts>());` |
| `std::unique_ptr` | 3181 | Exclusive ownership, deletes on scope exit | `void setPreviousReadBuffer(std::unique_ptr<ReadBuffer> buffer) override` |
| `std::static_pointer_cast` | 182 | `static_cast` for `shared_ptr` | `return std::static_pointer_cast<ChunkInfo>(cloneSelf());` |
| `std::dynamic_pointer_cast` | 114 | Checked downcast of a `shared_ptr` | `std::dynamic_pointer_cast<MergeTreeData>(table.table);` |
| `std::weak_ptr` | 111 | Non-owning observer of a `shared_ptr` | `mutable std::weak_ptr<const IDictionary> cached_dict;` |
| `std::enable_shared_from_this` | 43 | Lets an object get a `shared_ptr` to itself | `class RefreshTask : public std::enable_shared_from_this<RefreshTask>` |
| `std::make_unique_for_overwrite` | 17 | `make_unique` without zero-initialisation (C++20) | `auto final_flags = std::make_unique_for_overwrite<UInt8[]>(row_end);` |
| `std::const_pointer_cast` | 11 | `const_cast` for `shared_ptr` | `std::const_pointer_cast<const IMergeTreeDataPart>(part), mutations_snapshot);` |
| `std::nothrow` | 7 | Non-throwing `new` tag | `std::size_t actual_size = Memory::trackMemory(size, trace, std::nothrow);` |
| `std::to_address` | 5 | Raw pointer from iterator or fancy pointer | `value_type * end = std::to_address(last);` |
| `std::launder` | 4 | Access object created in reused storage | `return std::launder(reinterpret_cast<Cell *>(&zero_value_storage));` |
| `std::addressof` | 4 | Real address even if `operator&` overloaded | `if (std::addressof(source) == std::addressof(destination))` |
| `std::destroy_at` | 1 | Call destructor in place | `std::destroy_at(reinterpret_cast<typename FunctionImpl::State *>(place));` |

### 1.4 Strings and text

| Name | Uses | What it is | Example |
|---|---|---|---|
| `std::string` | 18697 | Owning mutable string (aliased as `String`) | `std::string table_name = part.substr(0, bracket_pos);` |
| `std::string_view` | 5698 | Non-owning read-only view of characters | `auto accumulate = [&](std::string_view ngram)` |
| `std::to_string` | 1167 | Number to `std::string` | `getLogEntry(std::to_string(i) + "_hello_world", (i + 44) * 10);` |
| `.substr` | 1098 | Copy a substring | `std::string table_name = part.substr(0, bracket_pos);` |
| `.starts_with` | 693 | Prefix test (C++20) | `type.starts_with("double") \|\| type == "real")` |
| `.c_str()` | 513 | NUL-terminated pointer for C APIs | `fd = ::open(file_name.c_str(), O_RDONLY \| O_CLOEXEC);` |
| `std::string::npos` | 382 | "Not found" value for string searches | `if (closing == std::string::npos)` |
| `.ends_with` | 259 | Suffix test (C++20) | `if (!storage_type.ends_with("_encrypted"))` |
| `std::string::size_type` | 163 | Index/length type of strings | `std::string::size_type length;` |
| `std::string::const_iterator` | 157 | Read-only iterator over chars | `for (std::string::const_iterator it = path.begin(); it != end; ++it)` |
| `"..."sv` / `std::string_view` literal | 148 | Compile-time `string_view` constant | `static constexpr std::string_view distinct_suffix = "distinct";` |
| `std::string_view::npos` | 95 | "Not found" for `string_view` | `if (qpos != std::string_view::npos)` |
| `std::char_traits` | 37 | Character operations used by streams/strings | `return std::char_traits<char>::eof();` |
| `std::stol` / `stoi` / `stoul` / `stoull` / `stod` | 94 | Parse number from `std::string`, throws on error | `range_start = std::stoull(value.substr(eq_pos + 1));` |
| `std::literals` | 30 | Enable `s`, `sv`, `ms` suffixes | `using namespace std::literals;` |
| `std::tolower` / `std::toupper` | 36 | Change ASCII letter case | `ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));` |
| `std::isdigit` / `isspace` / `isalnum` | 44 | Classify characters | `if (!std::isdigit(static_cast<unsigned char>(c)))` |
| `std::from_chars` | 19 | Fast locale-free string to number | `auto [ptr, ec] = std::from_chars(begin, end, result);` |
| `std::strlen` | 19 | Length of a C string | `auto pos_to_bucket = pos + std::strlen("://");` |
| `std::u16string` | 18 | UTF-16 string | `const std::u16string text = u"SELECT 1; SELECT * FRM u";` |
| `std::basic_string` | 12 | Underlying string template | `typedef std::basic_string<char, i_char_traits<char>> istring;` |
| `std::to_chars` | 8 | Fast locale-free number to string | `const auto result = std::to_chars(buffer, buffer + sizeof(buffer), number);` |
| `std::wstring` | 8 | Wide-character string | `// Define if std::wstring is not available` |

### 1.5 Utilities and vocabulary types

| Name | Uses | What it is | Example |
|---|---|---|---|
| `std::move` | 16709 | Cast to rvalue so resources can be moved | `res.push_back(std::move(new_path));` |
| `std::optional` | 6569 | Value that may be absent | `const std::optional<String> & default_session_user = {});` |
| `std::nullopt` | 2206 | The "empty" value of an optional | `return std::nullopt;` |
| `.has_value()` | 1766 | Test whether an optional is set | `if (!column.has_value())` |
| `std::pair` | 1763 | Two values bundled together | `std::pair<IcebergDataSnapshotPtr, TableStateSnapshot>` |
| `std::function` | 1186 | Type-erased callable holder | `using ResponseCallback = std::function<void(const ZooKeeperResponsePtr &)>;` |
| `std::forward` | 483 | Perfect forwarding in templates | `fmt::format(format, std::forward<Types>(args)...);` |
| `std::get` | 416 | Access tuple element or variant alternative | `std::get<RefFilter>(default_or_filter).get();` |
| `std::swap` | 347 | Exchange two values | `std::swap(x.items[0], x.items[1]);` |
| `.value_or` | 289 | Optional's value or a default | `ssize_t index = index_arg.value_or(capture == 0 ? 0 : 1);` |
| `std::make_pair` | 286 | Build a pair with deduced types | `map.insert(std::make_pair(data[i], value));` |
| `std::tie` | 224 | Assign tuple elements into variables | `std::tie(user_name, realm) = extractNameAndRealm(initiator_name);` |
| `std::exchange` | 179 | Replace a value and return the old one | `time_scale = std::exchange(src.time_scale, 0);` |
| `std::holds_alternative` | 165 | Which alternative a variant holds | `if (std::holds_alternative<String>(arg))` |
| `std::tuple` | 139 | Fixed-size heterogeneous collection | `std::tuple<size_t, size_t> getDroppedTablesCountAndInuseCount();` |
| `std::get_if` | 135 | Pointer to variant alternative or null | `if (const auto * val = std::get_if<IPv6AddrType>(&addr))` |
| `std::hash` | 105 | Standard hash functor | `std::hash<std::string_view> hash_impl;` |
| `std::variant` | 104 | Type-safe tagged union | `using AuthMethod = std::variant<` |
| `std::unexpected` | 89 | Error value for `std::expected` | `return std::unexpected(fmt::format("Watch '{}' already exists", id));` |
| `std::make_optional` | 80 | Build an optional with deduced type | `return std::make_optional(std::pair{` |
| `std::visit` | 75 | Call a visitor on the active variant alternative | `return std::visit(` |
| `std::ignore` | 72 | Placeholder to discard in `std::tie` | `std::tie(it, std::ignore) = partition_id_to_sink.emplace(key, sink);` |
| `std::expected` | 71 | Value or error, no exceptions (C++23) | `using Int64OrError = std::expected<Int64, ErrorCodeAndMessage>;` |
| `std::make_tuple` | 53 | Build a tuple with deduced types | `std::make_tuple(highlight_pos, matching_brace_pos);` |
| `std::reference_wrapper` | 52 | Copyable, rebindable reference | `std::optional<std::reference_wrapper<std::atomic<int64_t>>> atomic_var;` |
| `std::less` / `std::greater` | 75 | Comparison functors; `std::less<>` enables heterogeneous lookup | `using FieldMap = MapWithMemoryTracking<String, Field, std::less<>>;` |
| `std::forward_as_tuple` | 48 | Tuple of references, for lexicographic compare | `< std::forward_as_tuple(rhs.az_info, rhs.priority, rhs.random);` |
| `std::monostate` | 42 | Empty alternative for a variant | `if constexpr (std::same_as<TResponses, std::monostate>)` |
| `std::bind_front` | 32 | Bind leading arguments of a callable (C++20) | `std::bind_front(&Instruction<T>::jodaClockHourOfHalfDay, repetitions),` |
| `std::declval` | 23 | Fake value for use inside `decltype` | `using Key = std::decay_t<decltype(std::declval<Value>().first)>;` |
| `std::equal_to` | 15 | Equality functor; `<>` for transparent keys | `using transparent_key_equal = std::equal_to<>;` |
| `std::type_index` | 15 | Hashable wrapper around `type_info` | `typename Records::const_iterator getImpl(std::type_index type_idx) const` |
| `std::tuple_size_v` | 14 | Number of tuple elements | `if constexpr (index == std::tuple_size_v<Tuple>)` |
| `std::source_location` | 13 | File/line of the caller (C++20) | `std::source_location source_ = std::source_location::current())` |
| `std::any` | 12 | Type-erased holder of any value | `std::any aggregateResult(std::any aggregate, std::any next_result) override` |
| `std::invoke` | 12 | Uniformly call any callable | `: std::invoke(func_joda, dest, source, fractional_second, scale, tz);` |
| `std::unreachable` | 12 | Mark code path impossible (C++23) | `std::unreachable();` |
| `std::in_place_type` / `std::in_place` | 13 | Construct variant/optional contents in place | `std::optional<mongocxx::instance> inst{std::in_place};` |
| `std::integer_sequence` / `index_sequence` | 26 | Compile-time integer packs for unrolling | `}(std::make_index_sequence<padding_offset>());` |
| `std::ref` / `std::cref` | 14 | Wrap a reference for by-value APIs | `return std::make_pair(std::ref(shard.queue), std::move(lock));` |
| `std::to_underlying` | 6 | Enum to its integer value (C++23) | `constexpr auto Index = std::to_underlying(WasmValKind::T);` |
| `std::cmp_less` / `std::cmp_greater` | 9 | Safe signed/unsigned comparison (C++20) | `if (std::cmp_less(seconds, 0))` |
| `std::any_cast` | 5 | Extract value from `std::any` | `if (const auto * data = std::any_cast<WasmTimeStoreData>(&ctx_data))` |
| `std::as_const` | 4 | View an object as const | `context.checkSettingsConstraints(std::as_const(segment), source);` |
| `std::apply` | 3 | Call a function with tuple elements as args | `std::apply(my_func, my_args);` |
| `std::not_fn` | 1 | Negate a predicate | `std::erase_if(projections, std::not_fn(is_preferred));` |

### 1.6 Algorithms, iterators and ranges

| Name | Uses | What it is | Example |
|---|---|---|---|
| `std::min` | 1412 | Smaller of two values | `return std::min(day_of_month, days_in_month);` |
| `std::max` | 959 | Larger of two values | `time = std::max<time_t>(time, 0);` |
| `std::ranges::` (all) | 384 | Range-based algorithms taking whole containers | `auto it = std::ranges::find(all_column_names, added_virtual_column.name);` |
| `std::sort` | 229 | Sort a range (ClickHouse often uses `::sort`) | `std::sort(intervals.begin(), intervals.end());` |
| `std::find` | 159 | First element equal to a value | `if (std::find(b.begin(), b.end(), m) != b.end())` |
| `std::erase_if` | 150 | Remove matching elements from a container (C++20) | `std::erase_if(approx_dag.getOutputs(), [&](const ActionsDAG::Node * node)` |
| `std::clamp` | 149 | Limit a value to a range | `std::clamp(ratio, 0.0, 1.0)` |
| `std::views::` (all) | 139 | Lazy range adaptors | `fmt::join(expression \| std::views::transform(&JoinActionRef::dump), ", ")` |
| `std::back_inserter` | 129 | Output iterator that calls `push_back` | `std::ranges::move(settings_from_auth_server, std::back_inserter(settings));` |
| `std::size` | 114 | Size of array or container | `quota_maxes[fuzz_rand() % std::size(quota_maxes)];` |
| `std::find_if` | 108 | First element matching a predicate | `if (std::find_if(tags.begin(), tags.end(), is_tag_name_empty) != tags.end())` |
| `std::all_of` | 98 | Predicate holds for every element | `!std::all_of(password.begin(), password.end(), ::isdigit)` |
| `std::shuffle` | 96 | Random permutation | `std::shuffle(its.begin(), its.end(), generator);` |
| `std::any_of` | 95 | Predicate holds for some element | `bool in_except_list = std::any_of(` |
| `std::begin` / `std::end` | 147 | Free-function iterators, work on C arrays | `::sort(std::begin(segments), std::end(segments));` |
| `std::ranges::any_of` | 82 | Range version of `any_of` | `if (std::ranges::any_of(raw_value, isWhitespaceASCII))` |
| `std::views::transform` | 80 | Lazily map each element | `\| std::views::transform([](auto && sv) { return parse<UInt64>(sv); });` |
| `std::next` / `std::prev` | 116 | Iterator advanced by n, returns copy | `auto next_column_it = std::next(ctx->it_name_and_type);` |
| `std::lower_bound` | 73 | First element not less than value (binary search) | `it = std::lower_bound(it, hashes.end(), probe);` |
| `std::fill` | 70 | Assign a value to every element | `std::fill(counts.begin(), counts.end(), 0);` |
| `std::make_move_iterator` | 59 | Iterator that moves instead of copies | `std::make_move_iterator(columns.end()));` |
| `std::ranges::find` | 57 | Range version of `find` | `std::ranges::find(arg, '=')` |
| `std::reverse` | 48 | Reverse a range in place | `std::reverse(selects.begin(), selects.end());` |
| `std::unique` | 47 | Collapse adjacent duplicates | `indexes_mapping.erase(std::unique(` |
| `std::distance` | 45 | Number of steps between iterators | `std::distance(offsets.begin(), it),` |
| `std::ranges::all_of` | 44 | Range version of `all_of` | `&& std::ranges::all_of(task_readers.prewhere, [](const auto & reader)` |
| `std::copy` | 43 | Copy a range | `std::copy(entities.begin(), entities.end(), std::back_inserter(all_entities));` |
| `std::transform` | 39 | Map a range into an output | `std::transform(input.begin(), input.end(), input.begin(), ::tolower);` |
| `std::upper_bound` | 33 | First element greater than value | `std::upper_bound(nodes.begin(), nodes.end(), node.logical_offset,` |
| `std::remove_if` | 32 | Erase-remove idiom (pre-C++20 style) | `args.erase(std::remove_if(args.begin(), args.end(), is_marker), args.end());` |
| `std::ranges::find_if` | 31 | Range version of `find_if` | `= std::ranges::find_if(` |
| `std::ranges::to` | 29 | Materialise a view into a container (C++23) | `\| std::ranges::to<DataTypes>();` |
| `std::ranges::contains` | 28 | Whether a range contains a value (C++23) | `if (!std::ranges::contains(columns, source_column))` |
| `std::iota` | 28 | Fill with increasing values | `std::iota(all_outputs.begin(), all_outputs.end(), 0);` |
| `std::advance` | 27 | Move an iterator in place | `std::advance(possible_prefix_setting, -1);` |
| `std::erase` | 26 | Remove all equal elements (C++20) | `std::erase(config_keys, "allow_distributed_ddl_queries");` |
| `std::replace` | 25 | Replace matching values | `std::replace(init_name.begin(), init_name.end(), '_', ' ');` |
| `std::remove` | 24 | Erase-remove idiom for values | `ch.erase(std::remove(ch.begin(), ch.end(), replaced), ch.end());` |
| `std::inserter` | 23 | Output iterator that calls `insert` | `std::inserter(regexp_intersection, regexp_intersection.begin()));` |
| `std::views::reverse` | 19 | Iterate in reverse | `for (const std::string & pending : pending_nodes \| std::views::reverse)` |
| `std::count` | 18 | Count equal elements | `if (std::count(parts[1].begin(), parts[1].end(), ':') == 1)` |
| `std::min_element` / `max_element` | 32 | Iterator to smallest/largest element | `return *std::max_element(array.begin(), array.end());` |
| `std::ranges::sort` | 16 | Range version of `sort` | `std::ranges::sort(result);` |
| `std::push_heap` / `pop_heap` / `make_heap` | 41 | Binary heap on a vector | `std::push_heap(heap.begin(), heap.end(), better);` |
| `std::is_sorted` | 16 | Check sortedness (often inside `chassert`) | `chassert(std::is_sorted(snapshots_in_use.begin(), snapshots_in_use.end()));` |
| `std::ranges::none_of` | 14 | No element matches | `if (std::ranges::none_of(search_queries, needs_fallback_for_query))` |
| `std::adjacent_find` | 13 | First pair of equal neighbours | `auto uniq_it = std::adjacent_find(records.begin(), records.end());` |
| `std::fill_n` | 12 | Assign value to first n elements | `std::fill_n(dst, count, src[i]);` |
| `std::equal` | 12 | Element-wise range equality | `return std::equal(` |
| `std::stable_sort` | 11 | Sort keeping equal elements' order | `std::stable_sort(ranked.begin(), ranked.end(),` |
| `std::set_intersection` / `set_difference` | 21 | Set operations on sorted ranges | `std::set_difference(` |
| `std::views::zip` | 10 | Iterate several ranges in lockstep (C++23) | `for (auto [removal, task] : std::views::zip(removals, tasks))` |
| `std::binary_search` | 10 | Whether a sorted range contains a value | `if (std::binary_search(winners.begin(), winners.end(), mapped))` |
| `std::for_each` | 10 | Call a function on each element | `std::for_each(thread_frame_pointers.rbegin(), thread_frame_pointers.rend(),` |
| `std::inplace_merge` | 9 | Merge two consecutive sorted halves | `std::inplace_merge(to.begin(), middle, to.end(), comp);` |
| `std::ssize` | 9 | Signed size of a container (C++20) | `if (const auto argument_count = std::ssize(arguments);` |
| `std::views::filter` | 9 | Lazily keep matching elements | `\| std::views::filter([](const auto & inode) { return inode.is_regular_file(); })` |
| `std::views::keys` / `values` | 12 | Iterate map keys or values | `fmt::join(std::views::keys(drivers), ", "));` |
| `std::partition_point` | 8 | End of the true-part of a partitioned range | `auto file_it = std::partition_point(` |
| `std::iterator_traits` | 8 | Traits describing an iterator type | `using diff_t = typename std::iterator_traits<Iter>::difference_type;` |
| `std::rotate` | 7 | Rotate elements left | `std::rotate(replicas.begin(), replicas.begin() + i + 1, replicas.end());` |
| `std::ranges::reverse_view` | 7 | View iterating backwards | `for (const auto & symbol : std::ranges::reverse_view(*symbols))` |
| `std::ranges::for_each` | 7 | Range version of `for_each` | `std::ranges::for_each(tasks_to_cancel, cancelTask);` |
| `std::copy_if` / `std::count_if` | 12 | Copy/count elements matching a predicate | `static_cast<size_t>(std::count_if(` |
| `std::views::split` | 5 | Lazily split a range on a delimiter | `\| std::views::split('/')` |
| `std::lexicographical_compare` | 5 | Dictionary-order comparison | `return std::lexicographical_compare(` |
| `std::partial_sort` / `nth_element` | 8 | Partial ordering (top-k, median) | `std::nth_element(container.begin(), nth, container.end(), compare);` |
| `std::minmax` | 4 | Both min and max at once | `auto res = std::minmax(a, b);` |
| `std::default_sentinel_t` | 4 | End marker for custom iterators | `bool operator != (std::default_sentinel_t) const { return ok(); }` |
| `std::views::iota` | 1 | Lazy integer sequence | `const auto rows = std::views::iota(size_t{0}, chunk.getNumRows());` |

### 1.7 Numeric, math and random

| Name | Uses | What it is | Example |
|---|---|---|---|
| `std::numeric_limits` | 1744 | Min/max/properties of numeric types | `return std::numeric_limits<UInt8>::is_specialized;` |
| `std::size_t` | 581 | Unsigned size type (usually just `size_t`) | `std::size_t Foundation_API hash(UInt64 n);` |
| `std::uniform_int_distribution` | 279 | Uniform random integers | `std::uniform_int_distribution<UInt32> cp_dist(0, 0x10FFFF);` |
| `std::isfinite` | 86 | Not NaN and not infinity | `if (!std::isfinite(ticks) \|\| std::abs(ticks) > 9.2e18)` |
| `std::isnan` | 67 | Test for NaN | `\|\| std::isnan(latitude_max))` |
| `std::sqrt` | 58 | Square root | `zstat = diff / std::sqrt(p_pooled * (1.0 - p_pooled) * trials_fact);` |
| `std::abs` | 56 | Absolute value | `std::abs(enum_descriptor->value(i)->number())` |
| `std::floor` / `std::ceil` | 86 | Round down / up | `const size_t lower = static_cast<size_t>(std::floor(rank));` |
| `std::pow` | 45 | Power function | `Float64 bit_contribution = std::pow(2.0, int(i) - int(fraction_bit_num));` |
| `std::mt19937` / `mt19937_64` | 78 | Mersenne Twister random engines | `std::mt19937_64 random_engine(std::random_device{}());` |
| `std::numbers` | 32 | Math constants such as `pi`, `e` (C++20) | `constexpr double PI = std::numbers::pi_v<double>;` |
| `std::bernoulli_distribution` | 29 | Random true/false with probability p | `auto distribution = std::bernoulli_distribution(p);` |
| `std::uniform_real_distribution` | 28 | Uniform random floats | `std::uniform_real_distribution<Float64> distribution2(min, max);` |
| `std::accumulate` | 26 | Fold a range with `+` or a function | `return std::accumulate(cashflows.begin(), cashflows.end(), 0.0);` |
| `std::isinf` | 24 | Test for infinity | `else if (std::isinf(x))` |
| `std::exp` / `std::log` / `log2` / `log10` | 53 | Exponent and logarithms | `multiplier = 1 / std::log(gamma);` |
| `std::sin` / `cos` / `tan` | 30 | Trigonometry | `oklab[2] = chroma * std::sin(hue_rad);` |
| `std::lround` / `std::llround` | 25 | Round to nearest integer | `auto fraction = std::llround(decimal * fraction_pow);` |
| `std::random_device` | 14 | Non-deterministic seed source | `std::random_device rd;` |
| `std::fabs` / `fmax` / `fma` | 22 | Floating-point abs, max, fused multiply-add | `state.dist = std::fmax(state.dist, std::fabs(x - y));` |
| `std::div` | 11 | Quotient and remainder at once | `auto d = std::div(t, multiplier);` |
| `std::binomial_distribution` | 10 | Random binomial counts | `std::binomial_distribution<pcg64_fast::result_type> binomial48(100, 0.48);` |
| `std::trunc` / `std::round` | 12 | Truncate or round floats | `result->getData()[i] = static_cast<Int64>(std::trunc(product));` |
| `std::signbit` | 6 | Sign bit of a float, works for -0.0 | `if (std::signbit(value))` |
| `std::normal_distribution` | 6 | Gaussian random values | `auto distribution = std::normal_distribution<>(mean, stddev);` |
| `std::gcd` | 5 | Greatest common divisor | `return std::gcd(static_cast<UInt64>(num), first_15_primes_product) > 1;` |
| `std::default_random_engine` | 5 | Implementation-chosen engine | `std::default_random_engine rng(13); // NOLINT` |
| `std::lerp` | 1 | Linear interpolation (C++20) | `return std::lerp(min, max, ratio);` |

### 1.8 `std::chrono` (time)

| Name | Uses | What it is | Example |
|---|---|---|---|
| `std::chrono` (all) | 1515 | Type-safe durations, clocks and time points | `if (update_time != std::chrono::system_clock::from_time_t(0))` |
| `std::chrono::system_clock` | 430 | Wall-clock time, convertible to `time_t` | `const std::chrono::time_point<std::chrono::system_clock> create_time;` |
| `std::chrono::milliseconds` | 419 | Duration in milliseconds | `std::chrono::milliseconds max_sleep_time,` |
| `std::chrono::seconds` | 301 | Duration in seconds | `const std::chrono::seconds stop_timeout(30);` |
| `std::chrono::steady_clock` | 243 | Monotonic clock for measuring intervals | `const auto now = std::chrono::steady_clock::now();` |
| `std::chrono::duration_cast` | 134 | Convert between duration units | `return std::chrono::duration_cast<std::chrono::microseconds>(` |
| `std::chrono::microseconds` | 81 | Duration in microseconds | `std::this_thread::sleep_for(std::chrono::microseconds(delay_us));` |
| `std::chrono::time_point` | 51 | A point in time on a given clock | `std::chrono::time_point<std::chrono::system_clock> last_connection_time;` |
| `std::chrono::nanoseconds` | 35 | Duration in nanoseconds | `std::chrono::nanoseconds throttling_duration{0};` |
| `std::chrono::duration<Rep, Period>` | 31 | Generic duration template | `void tryLockAndProfileWait(std::chrono::duration<Rep, Period> timeout)` |
| `std::chrono::sys_seconds` | 22 | System time point with seconds precision (C++20) | `static std::chrono::sys_seconds startOfAbsoluteMonth(Int64 absolute_month)` |
| `std::chrono_literals` | 19 | Enables `100ms`, `5s` literals | `using namespace std::chrono_literals;` |
| `std::milli` (ratio) | 16 | Ratio 1/1000 used as a duration period | `sleep_for(duration<Float64, std::milli>(duration_ms));` |
| `std::chrono::sys_time` | 9 | System time point of any precision | `std::chrono::sys_time<std::chrono::nanoseconds> max_time {};` |
| `std::chrono::floor` | 9 | Round a time point/duration down | `znode.last_attempt_time = std::chrono::floor<std::chrono::seconds>(now);` |
| `std::chrono::minutes` / `hours` | 8 | Durations in minutes/hours | `start_of_day_time_point_if_no_transitions += std::chrono::hours(24);` |
| `std::chrono::year_month_day` | 3 | Calendar date (C++20) | `std::chrono::year_month_day ymd(std::chrono::floor<std::chrono::days>(t));` |
| `std::chrono::time_point_cast` | 2 | Change a time point's precision | `auto seconds = std::chrono::time_point_cast<std::chrono::seconds>(time);` |
| `std::chrono::days` | 2 | Duration in days (C++20) | `std::chrono::floor<std::chrono::days>(t)` |
| `std::chrono::high_resolution_clock` | 1 | Highest-precision clock (usually steady) | `auto now_high_res = std::chrono::high_resolution_clock::now();` |
| `std::chrono::file_clock` | 1 | Clock of filesystem timestamps (C++20) | `auto sys_time = std::chrono::file_clock::to_sys(file_time);` |
| `std::time` / `std::time_t` / `std::tm` | 52 | C time API | `std::time_t now_time_t = std::chrono::system_clock::to_time_t(now);` |

### 1.9 `std::filesystem` (`fs::`)

Most code writes `fs::` after `namespace fs = std::filesystem;` (154 files declare this alias); `fs::` appears 2349 times, `std::filesystem` 875 times.

| Name | Uses | What it is | Example |
|---|---|---|---|
| `fs::` (all) | 2349 | Short alias for `std::filesystem` | `namespace fs = std::filesystem;` |
| `fs::path` / `std::filesystem::path` | 1836 | Portable path with `/` join operator | `std::ifstream f(std::filesystem::path(*cgroup_path) / "memory.oom.group");` |
| `fs::exists` | 412 | Does the path exist | `return fs::exists(getPath(file_name));` |
| `fs::create_directories` | 167 | `mkdir -p` | `fs::create_directories(path);` |
| `fs::remove` | 173 | Delete one file or empty directory | `bool existed = fs::remove(file_path);` |
| `fs::directory_iterator` | 72 | Iterate directory entries | `for (const auto & entry : std::filesystem::directory_iterator(log_dir))` |
| `fs::remove_all` | 36 | `rm -rf` | `std::filesystem::remove_all(create_result.previous_working_dir, ec_cleanup);` |
| `fs::temp_directory_path` | 30 | System temp directory | `const std::string path = (std::filesystem::temp_directory_path()` |
| `fs::is_directory` | 11 | Is the path a directory | `else if (!std::filesystem::is_directory(dest_dir_path))` |
| `fs::weakly_canonical` | 9 | Normalise a path that may not exist | `path = std::filesystem::weakly_canonical(path);` |
| `fs::is_regular_file` | 9 | Is the path a regular file | `if (std::filesystem::is_regular_file(file_path))` |
| `fs::current_path` | 6 | Get/set working directory | `std::filesystem::current_path(old_cwd);` |
| `fs::absolute` | 6 | Make a path absolute | `path = std::filesystem::absolute(path);` |
| `fs::last_write_time` | 5 | File modification time | `std::filesystem::last_write_time(path_b, now);` |
| `fs::rename` | 4 | Atomically rename/move | `std::filesystem::rename(tmp_file_path, file_path);` |
| `fs::canonical` | 4 | Resolve symlinks, path must exist | `absolute_path = std::filesystem::canonical(absolute_path);` |
| `fs::is_empty` | 4 | Is a file/directory empty | `return std::filesystem::exists(path) && !std::filesystem::is_empty(path);` |
| `fs::file_size` | 3 | Size of a file in bytes | `auto file_size = std::filesystem::file_size(finalPath(), ec);` |
| `fs::filesystem_error` | 3 | Exception thrown by filesystem calls | `catch (const std::filesystem::filesystem_error & e)` |
| `fs::recursive_directory_iterator` | 3 | Walk a directory tree | `std::filesystem::recursive_directory_iterator end;` |
| `fs::space` | 2 | Free/total disk space | `writeIntText(std::filesystem::space(server_data_path).free, json);` |

### 1.10 Concurrency

| Name | Uses | What it is | Example |
|---|---|---|---|
| `std::lock_guard` | 2852 | Scoped lock of a mutex (most common lock) | `std::lock_guard lock{mutex};` |
| `std::atomic` | 1297 | Lock-free shared variable | `mutable std::atomic<size_t> hit_count{0};` |
| `std::mutex` | 1117 | Basic exclusive mutex | `mutable std::mutex mutex;` |
| `std::memory_order_relaxed` | 1096 | Atomic op with no ordering guarantees | `value.store(new_value, std::memory_order_relaxed);` |
| `std::unique_lock` | 833 | Movable lock, needed for condition variables | `std::unique_lock lock{mutex};` |
| `std::thread` | 274 | OS thread (ClickHouse prefers `ThreadFromGlobalPool`) | `std::thread sender([&] { sending_code = run(sending, streams); });` |
| `std::this_thread` (all) | 227 | Functions acting on the current thread | `std::this_thread::yield();` |
| `std::this_thread::sleep_for` | 156 | Sleep the current thread (tests, backoff) | `std::this_thread::sleep_for(std::chrono::milliseconds(1000));` |
| `std::atomic_bool` | 154 | Alias for `std::atomic<bool>` | `void ExecutionThreadContext::wait(std::atomic_bool & finished)` |
| `std::future` | 146 | Handle to a result produced later | `std::future<MarkCache::MappedPtr> future;` |
| `std::condition_variable` | 141 | Wait until another thread signals | `std::condition_variable flush_condvar;` |
| `std::shared_lock` | 132 | Scoped reader (shared) lock | `std::shared_lock shutdown_lock(*_shutdown, std::try_to_lock);` |
| `std::memory_order_acquire` | 124 | Load that sees writes before a release | `if (!shared.initialized.load(std::memory_order_acquire))` |
| `std::promise` | 116 | Producer side of a future | `std::make_shared<std::promise<Coordination::RemoveResponse>>();` |
| `std::memory_order_release` | 91 | Store that publishes earlier writes | `send_malformed_record.store(true, std::memory_order_release);` |
| `std::this_thread::yield` | 54 | Give up the CPU slice | `std::this_thread::yield();` |
| `std::barrier` | 48 | Reusable thread rendezvous (C++20) | `std::barrier<std::__empty_completion> sync(readers + 1);` |
| `std::scoped_lock` | 44 | Lock one or more mutexes deadlock-free | `std::scoped_lock lock(mutex);` |
| `std::future_status` | 41 | Result of `wait_for` on a future | `if (futures[i].wait_for(std::chrono::seconds(0)) != std::future_status::ready)` |
| `std::defer_lock` | 33 | Construct a lock without locking yet | `std::unique_lock lk(mutex, std::defer_lock);` |
| `std::memory_order_seq_cst` | 29 | Strongest (default) atomic ordering | `if (is_cancelled.load(std::memory_order_seq_cst))` |
| `std::atomic_size_t` | 28 | Alias for `std::atomic<size_t>` | `std::atomic_size_t total_bytes = 0;` |
| `std::call_once` / `std::once_flag` | 53 | Run initialisation exactly once | `std::call_once(instance_flag, []` |
| `std::recursive_mutex` | 23 | Mutex the same thread can re-lock | `std::recursive_mutex mutex;` |
| `std::shared_future` | 20 | Future readable by many consumers | `std::shared_future<void> ready_future;` |
| `std::memory_order_acq_rel` | 18 | Read-modify-write with both orderings | `ptr->ref_counter.fetch_sub(1, std::memory_order_acq_rel)` |
| `std::shared_timed_mutex` | 16 | Reader/writer mutex with timeouts | `std::shared_timed_mutex dynamic_resize_lock;` |
| `std::thread::id` / `get_id` | 31 | Identifier of a thread | `populating_thread = std::this_thread::get_id();` |
| `std::try_to_lock` | 14 | Construct a lock with a non-blocking attempt | `std::shared_lock shutdown_lock(*_shutdown, std::try_to_lock);` |
| `std::thread::hardware_concurrency` | 14 | Number of hardware threads | `return std::thread::hardware_concurrency();` |
| `std::timed_mutex` | 12 | Mutex with `try_lock_for` | `std::unique_lock<std::timed_mutex> table_lock;` |
| `std::latch` | 12 | One-shot countdown for threads (C++20) | `std::latch finish{1};` |
| `std::atomic_flag` | 11 | Simplest guaranteed lock-free atomic | `std::atomic_flag is_set;` |
| `std::async` / `std::launch` | 20 | Run a callable asynchronously, get a future | `auto reserved_slot = std::async(std::launch::async, [&]` |
| `std::cv_status` | 9 | Result of timed condition-variable wait | `condvar.wait_until(lock, deadline) == std::cv_status::timeout;` |
| `std::memory_order::relaxed` | 8 | Scoped-enum spelling of the ordering (C++20) | `Int64 fake = scheduling.fake_clock.load(std::memory_order::relaxed);` |
| `std::packaged_task` | 7 | Callable wrapped with a future for its result | `auto package = std::packaged_task<void()>(std::move(callback));` |
| `std::atomic_store_explicit` / `load_explicit` | 12 | Free-function atomic ops with ordering | `std::atomic_store_explicit(&current_state, state, std::memory_order_release);` |
| `std::atomic_ref` | 6 | Atomic operations on a plain object (C++20) | `static_assert(std::atomic_ref<Count>::is_always_lock_free);` |
| `std::adopt_lock` | 5 | Lock takes an already-locked mutex | `std::unique_lock<std::mutex> cv_lk(*lk.mutex(), std::adopt_lock);` |
| `std::atomic_signal_fence` | 5 | Compiler-only fence for signal handlers | `std::atomic_signal_fence(std::memory_order_seq_cst);` |
| `std::condition_variable_any` | 4 | Condition variable for any lock type | `std::condition_variable_any cv;` |
| `std::shared_mutex` | 4 | Standard reader/writer mutex (replaced by `SharedMutex`) | `TestSharedMutex<std::shared_mutex>();` |
| `std::counting_semaphore` | 2 | Counting semaphore (C++20) | `std::counting_semaphore<> merge_requests{0};` |
| `std::jthread` | 2 | Auto-joining thread (C++20) | `std::jthread server_thread([&]` |

### 1.11 Type traits and concepts

| Name | Uses | What it is | Example |
|---|---|---|---|
| `std::is_same_v` | 1539 | Are two types identical | `static constexpr bool throw_exception = std::is_same_v<ReturnType, void>;` |
| `std::decay_t` | 314 | Strip references/cv, array-to-pointer | `requires std::is_fundamental_v<std::decay_t<T>>` |
| `std::conditional_t` | 268 | Pick one of two types by a bool | `using SymbolT = std::conditional_t<is_utf8, UInt32, UInt8>;` |
| `std::common_type_t` | 61 | Type both arguments convert to | `using CommonType = std::common_type_t<BeginType, EndType>;` |
| `std::same_as` | 60 | Concept form of `is_same` | `requires std::same_as<T, double> \|\| std::same_as<T, QuotaValue>` |
| `std::true_type` / `std::false_type` | 71 | Base classes for boolean traits | `struct IsUniqExactSet<UniqExactSet<T1, T2>> : std::true_type` |
| `std::is_integral_v` | 48 | Is an integer type | `static_assert(std::is_integral_v<T>);` |
| `std::is_floating_point_v` | 40 | Is a floating-point type | `if constexpr (std::is_floating_point_v<ValueType>)` |
| `std::is_signed_v` / `is_unsigned_v` | 63 | Signedness of arithmetic types | `if constexpr (std::is_signed_v<T>)` |
| `std::type_identity` | 36 | Wrap a type; block template deduction | `void setValue(T * typed_ptr, std::type_identity_t<T> val)` |
| `std::integral` | 27 | Concept: integer type | `template <std::integral To, std::integral From>` |
| `std::integral_constant` | 26 | Value as a type | `std::integral_constant<std::underlying_type_t<WasmValKind>, index>,` |
| `std::is_base_of_v` | 22 | Is one class a base of another | `else if constexpr (std::is_base_of_v<AddMillisecondsImpl, Transform>)` |
| `std::underlying_type_t` | 18 | Integer type behind an enum | `std::underlying_type_t<WasmValKind>` |
| `std::is_convertible_v` | 16 | Implicitly convertible check | `requires std::is_convertible_v<G, F>` |
| `std::make_unsigned_t` / `make_signed_t` | 19 | Signed/unsigned counterpart of an int | `using UnsignedT = std::make_unsigned_t<T>;` |
| `std::is_trivially_destructible_v` | 15 | Destructor does nothing | `if (!std::is_trivially_destructible_v<Cell>)` |
| `std::remove_reference_t` | 14 | Strip `&` / `&&` | `using T = std::remove_reference_t<decltype(out)>;` |
| `std::enable_if_t` | 14 | SFINAE switch (older style) | `std::enable_if_t<!std::is_same_v<std::decay_t<Function>, ThreadWithStackSize>` |
| `std::derived_from` | 13 | Concept: publicly derived from | `concept ZooKeeperResponse = std::derived_from<T, Coordination::Response>;` |
| `std::unsigned_integral` | 13 | Concept: unsigned integer | `template <std::unsigned_integral TUInt>` |
| `std::is_void_v` | 13 | Is `void` | `if constexpr (!std::is_void_v<typename BitfieldStruct::ParentFlags>)` |
| `std::remove_cvref_t` | 12 | Strip const/volatile and references | `std::remove_cvref_t<decltype(x)>` |
| `std::is_enum_v` | 12 | Is an enumeration | `requires std::is_enum_v<T> \|\| std::is_scoped_enum_v<T>` |
| `std::invoke_result_t` | 12 | Return type of calling a callable | `if constexpr (!std::is_same_v<std::invoke_result_t<Operation>, void>)` |
| `std::is_standard_layout_v` / `is_trivial_v` | 21 | C-compatible memory layout checks | `static_assert(std::is_trivial_v<T> && std::is_standard_layout_v<T>);` |
| `std::is_trivially_copyable_v` | 10 | Safe to `memcpy` | `static_assert(std::is_trivially_copyable_v<Cell>);` |
| `std::bool_constant` | 7 | `integral_constant<bool, B>` | `func(std::bool_constant<false>{}, std::bool_constant<true>{});` |
| `std::is_pointer_v` / `is_arithmetic_v` | 18 | Pointer / arithmetic type checks | `if constexpr (std::is_pointer_v<T>)` |
| `std::is_constructible_v` | 8 | Can be constructed from given args | `requires std::is_constructible_v<Base, ContextPtr>` |
| `std::is_nothrow_move_constructible_v` | 10 | Move never throws (plus assignable form) | `static_assert(std::is_nothrow_move_constructible_v<LogElement>);` |
| `std::void_t` | 5 | Detection idiom helper for SFINAE | `struct HasUnderlyingType<T, std::void_t<typename T::UnderlyingType>>` |
| `std::is_invocable_r_v` | 5 | Callable returning a given type | `requires std::is_invocable_r_v<String, GetRow>` |
| `std::variant_alternative_t` | 4 | Type of the n-th variant alternative | `using TVal = std::variant_alternative_t<index, WasmVal>;` |
| `std::convertible_to` / `floating_point` | 4 | Standard concepts | `template <std::convertible_to<T> U>` |
| `std::is_constant_evaluated` | 2 | Running at compile time? | `if (!std::is_constant_evaluated())` |

### 1.12 Exceptions and error codes

| Name | Uses | What it is | Example |
|---|---|---|---|
| `std::exception_ptr` | 313 | Holds a caught exception to rethrow later | `std::exception_ptr exception;` |
| `std::current_exception` | 237 | Capture the exception being handled | `last_exception = std::current_exception();` |
| `std::exception` | 232 | Root of standard exceptions | `catch (const std::exception & e)` |
| `std::rethrow_exception` | 147 | Rethrow a stored `exception_ptr` | `std::rethrow_exception(exception);` |
| `std::runtime_error` | 108 | Generic runtime failure | `throw std::runtime_error("Cannot parse LocalDate: " + std::string(s, length));` |
| `std::error_code` | 97 | Non-throwing OS/library error value | `std::error_code ec;` |
| `std::terminate` | 77 | Abort the program immediately | `std::terminate();` |
| `std::make_exception_ptr` | 67 | Create `exception_ptr` without throwing | `promise.set_exception(std::make_exception_ptr(` |
| `std::errc` | 59 | Portable error-condition enum | `if (ec == std::errc::no_such_file_or_directory)` |
| `std::uncaught_exceptions` | 41 | Are we unwinding? (safe destructors) | `if (!std::uncaught_exceptions() && std::current_exception() == nullptr)` |
| `std::bad_alloc` | 31 | Allocation failure | `catch (const std::bad_alloc &)` |
| `std::abort` | 31 | Abnormal termination with core dump | `std::abort();` |
| `std::logic_error` | 26 | Programming-error exception | `catch (const std::logic_error & e)` |
| `std::out_of_range` | 23 | Index/number out of range | `catch (const std::out_of_range&)` |
| `std::_Exit` | 18 | Exit without running destructors | `std::_Exit(0);` |
| `std::invalid_argument` | 13 | Bad argument (e.g. from `std::stoi`) | `catch (const std::invalid_argument &)` |
| `std::future_error` | 10 | Error from future/promise misuse | `catch (const std::future_error & e)` |
| `std::system_error` / `generic_category` | 18 | Exception wrapping an `errno` | `throw std::system_error(ec, std::generic_category(), "thread::detach failed");` |
| `std::length_error` | 9 | Size exceeds max size | `/// Guard against absurdly large values that would cause std::length_error` |
| `std::type_info` | 59 | Result of `typeid` | `const std::type_info * column_type = nullptr;` |

### 1.13 Streams and C library (brief)

Most I/O goes through ClickHouse `ReadBuffer`/`WriteBuffer` (see section on idioms); `std::stringstream` needs a `STYLE_CHECK_ALLOW_STD_STRING_STREAM` comment to pass the style check.

| Name | Uses | What it is | Example |
|---|---|---|---|
| `std::cerr` | 1048 | Unbuffered error output (tools, tests) | `std::cerr << std::endl;` |
| `std::endl` | 870 | Newline plus flush | `std::cout << "TEST_RANDOM_SEED=" << seed << std::endl;` |
| `std::ostream` | 421 | Output stream base class | `std::ostream & operator<<(std::ostream & out, const VectorOfStrings & strs)` |
| `std::cout` | 349 | Standard output | `std::cout << e.message() << std::endl;` |
| `std::istream` | 342 | Input stream base class | `std::istream & istr;` |
| `std::ios` flags | 177 | Stream mode/state bits (`in`, `out`, `binary`, `badbit`) | `os.exceptions(std::ios::badbit);` |
| `std::memcpy` | 177 | Copy raw bytes | `std::memcpy(&res, fixed_binary_array.GetValue(i), 16);` |
| `std::streamsize` | 167 | Signed count of stream characters | `body.read(out.data(), static_cast<std::streamsize>(size));` |
| `std::ostringstream` | 91 | Build a string with `<<` | `std::ostringstream oss; // STYLE_CHECK_ALLOW_STD_STRING_STREAM` |
| `std::memset` | 87 | Fill raw bytes | `std::memset(out, 0, final_count * 64);` |
| `std::setprecision` / `std::fixed` | 153 | Floating-point formatting manipulators | `std::cerr << std::fixed << std::setprecision(3);` |
| `std::ofstream` / `std::ifstream` | 107 | File output/input streams | `std::ifstream detail_file(fuzzer_out_file, std::ios::in);` |
| `std::stringstream` | 46 | Read/write string stream | `std::stringstream ss; // STYLE_CHECK_ALLOW_STD_STRING_STREAM` |
| `std::getenv` | 44 | Read an environment variable | `const char * value = std::getenv(name); /// NOLINT(concurrency-mt-unsafe)` |
| `std::memcmp` | 43 | Compare raw bytes | `EXPECT_EQ(std::memcmp(str.data(), "a\0b", 3), 0);` |
| `std::getline` | 37 | Read a line into a string | `std::getline(std::cin, answer);` |
| `std::setw` / `std::setfill` / `std::hex` | 48 | Width, fill and base manipulators | `oss << std::hex << std::setfill('0');` |
| `std::istringstream` | 23 | Parse from a string with `>>` | `std::istringstream stream(xml.str());` |
| `std::streambuf` | 17 | Low-level stream buffer (bridged to ClickHouse buffers) | `: static_cast<std::streambuf *>(good_stream_buf.get());` |
| `std::istreambuf_iterator` | 12 | Iterate chars of a stream (read whole file) | `std::istreambuf_iterator<char>());` |

### 1.14 Bits, bytes and endianness

| Name | Uses | What it is | Example |
|---|---|---|---|
| `std::endian` | 202 | Byte-order enum (`native`, `little`, `big`) (C++20) | `if (std::endian::native != endian)` |
| `std::endian::native` | 143 | Byte order of the current CPU | `transformEndianness<std::endian::native, std::endian::little>(result);` |
| `std::endian::little` | 113 | Little-endian marker | `readBinaryEndian<std::endian::little>(x, buf);` |
| `std::endian::big` | 68 | Big-endian marker (s390x support) | `if constexpr (std::endian::native == std::endian::big)` |
| `std::countr_zero` | 66 | Count trailing zero bits | `const char * candidate = block + std::countr_zero(candidates);` |
| `std::bit_cast` | 57 | Reinterpret bits between same-size types | `return wasmtime::Val(std::bit_cast<Type>(std::get<Index>(val)));` |
| `std::byte` | 50 | Byte type without arithmetic | `auto * start = reinterpret_cast<std::byte *>(&value);` |
| `std::byteswap` | 38 | Reverse byte order (C++23) | `return std::byteswap(value);` |
| `std::uintptr_t` | 32 | Integer that can hold a pointer | `reinterpret_cast<const std::uintptr_t>(&ast_generator)` |
| `std::popcount` | 30 | Number of set bits | `pc += static_cast<UInt64>(std::popcount(cw));` |
| `std::align_val_t` | 26 | Alignment argument for aligned `new` | `template <std::same_as<std::align_val_t>... TAlign>` |
| `std::nullptr_t` | 21 | Type of `nullptr` | `JoinActionRef(std::nullptr_t) : node_ptr(nullptr) {}` |
| `std::countl_zero` | 15 | Count leading zero bits | `return static_cast<UInt32>(1) << (32 - std::countl_zero(x - 1));` |
| `std::ptrdiff_t` | 11 | Signed pointer difference | `using difference_type = std::ptrdiff_t;` |
| `std::bit_width` | 6 | Bits needed to represent a value | `const int bytes = (std::bit_width(v) + 7) / 8;` |
| `std::max_align_t` | 6 | Type with the largest scalar alignment | `alignof(std::max_align_t)` |
| `std::to_integer` | 6 | `std::byte` to an integer | `auto compressed_level = std::to_integer<UInt8>(compressed_data[1]);` |
| `std::rotl` | 4 | Rotate bits left (hashing) | `v1 = std::rotl(v1, 17);` |
| `std::has_single_bit` / `bit_ceil` | 4 | Power-of-two test / round up | `if (length % m == 0 && std::has_single_bit(length / m))` |

### 1.15 Most-included standard headers

Uses = number of files that `#include` the header.

| Name | Uses | What it is | Example |
|---|---|---|---|
| `<memory>` | 839 | Smart pointers | `#include <memory>` |
| `<vector>` | 655 | `std::vector` | `#include <vector>` |
| `<optional>` | 604 | `std::optional` | `#include <optional>` |
| `<algorithm>` | 528 | Sorting/searching algorithms | `#include <algorithm>` |
| `<string>` | 475 | `std::string` | `#include <string>` |
| `<mutex>` | 392 | Mutexes and locks | `#include <mutex>` |
| `<unordered_map>` | 322 | Hash map | `#include <unordered_map>` |
| `<atomic>` | 296 | Atomics | `#include <atomic>` |
| `<limits>` | 286 | `std::numeric_limits` | `#include <limits>` |
| `<filesystem>` | 279 | `std::filesystem` | `#include <filesystem>` |
| `<string_view>` | 250 | `std::string_view` | `#include <string_view>` |
| `<functional>` | 223 | `std::function`, functors | `#include <functional>` |
| `<cstring>` | 221 | `memcpy`, `strlen` | `#include <cstring>` |
| `<utility>` | 210 | `move`, `pair`, `exchange` | `#include <utility>` |
| `<chrono>` | 161 | Time utilities | `#include <chrono>` |
| `<cmath>` | 142 | Math functions | `#include <cmath>` |
| `<type_traits>` | 138 | Type traits | `#include <type_traits>` |
| `<thread>` | 129 | `std::thread`, `this_thread` | `#include <thread>` |
| `<ranges>` | 93 | Ranges and views | `#include <ranges>` |
| `<bit>` | 76 | Bit manipulation, `std::endian` | `#include <bit>` |
| `<random>` | 75 | Random engines/distributions | `#include <random>` |
| `<variant>` | 59 | `std::variant` | `#include <variant>` |
| `<span>` | 53 | `std::span` | `#include <span>` |
| `<future>` | 46 | Futures and promises | `#include <future>` |
| `<shared_mutex>` | 39 | `shared_lock`, `shared_timed_mutex` | `#include <shared_mutex>` |

### 1.16 Third-party libraries used from C++ code

| Name | Uses | What it is | Example |
|---|---|---|---|
| `Poco::` | 9295 | Networking, config, logging, JSON, XML framework | `throw Poco::SystemException("cannot get local time DST offset");` |
| `fmt::` | 2697 | Fast `{}`-style formatting (instead of `std::format`) | `auto path = fmt::format("{}.{}", config_prefix, field.getName());` |
| `Poco::Net` | 1932 | HTTP/TCP sockets, servers, SSL | `} // namespace Poco::Net` |
| `boost::` | 1724 | Assorted utilities, containers, algorithms | `boost::multi_index::indexed_by<` |
| `Poco::JSON` | 1183 | JSON parsing/objects | `Poco::JSON::Array::Ptr elements;` |
| `arrow::` | 1086 | Apache Arrow columnar format (Parquet/Arrow I/O) | `M(INT64, arrow::Int64Type) \` |
| `Poco::Util::AbstractConfiguration` | 1044 | XML/YAML server config access | `Poco::Util::AbstractConfiguration & to_config, const std::string & to_path);` |
| `llvm::` | 916 | JIT compilation of expressions | `llvm::IRBuilder<> & b = static_cast<llvm::IRBuilder<> &>(builder);` |
| `Aws::` | 811 | AWS SDK for S3 access | `if (client_configuration.scheme == Aws::Http::Scheme::HTTP)` |
| jemalloc (`mallctl`) | 541 | Memory allocator and its control API | `LOG_INFO(log, "Purged jemalloc arenas");` |
| `Poco::Timespan` | 513 | Time interval type for timeouts | `Poco::Timespan HTTPContext::getSendTimeout() const` |
| `Poco::URI` | 479 | URI parsing | `catch (const Poco::URISyntaxException & invalid_uri_exception)` |
| `nuraft::` | 458 | Raft consensus used by ClickHouse Keeper | `explicit RaftServerConfig(const nuraft::srv_config & cfg) noexcept;` |
| `testing::` | 451 | GoogleTest unit test framework | `EXPECT_EXIT(checkNothingBuildsTheIndex(), ::testing::ExitedWithCode(0), ".*");` |
| `orc::` | 346 | Apache ORC file format | `case orc::STRUCT:` |
| `fmt::join` | 323 | Format a range with a separator | `fmt::join(result.column_names_to_read, ","));` |
| `boost::intrusive_ptr` | 325 | Ref-counted pointer with counter inside object (`ASTPtr`) | `using ASTPtr = boost::intrusive_ptr<IAST>;` |
| `avro::` | 323 | Apache Avro format (Iceberg metadata, Kafka) | `avro::DecoderPtr decoder;` |
| `Poco::AutoPtr` | 276 | Poco's intrusive smart pointer | `Poco::AutoPtr<Poco::XML::Document> document = dom_parser.parseString(xml);` |
| `rocksdb::` | 273 | Embedded key-value store (`EmbeddedRocksDB` engine) | `rocksdb::IngestExternalFileOptions ingest_options;` |
| `magic_enum::` | 273 | Enum-to-string reflection | `return String(magic_enum::enum_name(scheme));` |
| `Azure::` | 244 | Azure Blob Storage SDK | `catch (const Azure::Core::Credentials::AuthenticationException &)` |
| `capnp::` | 241 | Cap'n Proto format | `capnp::StructSchema schema;` |
| `boost::noncopyable` | 248 | Base class that deletes copy operations | `class IMetadataStorage : private boost::noncopyable` |
| `parquet::` | 204 | Apache Parquet format | `namespace parq = parquet::format;` |
| `re2::` | 200 | Google RE2 regular expressions | `re2::RE2::UNANCHORED,` |
| `pqxx::` | 184 | PostgreSQL client | `class PostgreSQLSource<pqxx::ReadTransaction>;` |
| `pcg64` / `pcg64_fast` | 179 | Fast PCG random generator | `pcg64_fast rng(randomSeed());` |
| `fmt::print` / `fmt::println` | 174 | Formatted printing to stdout | `fmt::println("checksum {}", checksum);` |
| `ZSTD_*` | 173 | Zstandard compression C API | `ZSTD_maxCLevel());` |
| `cppkafka::` | 138 | Kafka client wrapper | `using LogCallback = cppkafka::Configuration::LogCallback;` |
| `CityHash_v1_0_2::` | 129 | Frozen CityHash version for stable hashes | `hash = CityHash_v1_0_2::CityHash64(value.data(), value.size());` |
| `mysqlxx::` | 127 | MySQL client wrapper | `mysqlxx::Connection connection("mysql_params");` |
| `roaring::` | 125 | Roaring compressed bitmaps (`groupBitmap`) | `*r64 = roaring::Roaring64Map::readSafe(body.get(), body_size_u32);` |
| `cctz::` | 120 | Time-zone database and conversions | `cctz::time_zone validated_tz;` |
| `boost::geometry` | 119 | Polygons and geo algorithms | `boost::geometry::correct(geom);` |
| `benchmark::` | 118 | Google Benchmark micro-benchmarks | `void test(benchmark::State & st)` |
| `absl::` | 116 | Abseil containers such as `InlinedVector` | `absl::InlinedVector<BoolMask, 16> rpn_stack;` |
| `google::protobuf` | 108 | Protocol Buffers format | `std::function<bool(google::protobuf::Message &)> handler;` |
| `boost::program_options` | 100 | Command-line argument parsing | `namespace po = boost::program_options;` |
| `boost::iequals` | 84 | Case-insensitive string compare | `if (boost::iequals(field_name, name))` |
| `wide::integer` | 77 | ClickHouse's own 128/256-bit integers | `struct AccumulateResultType<wide::integer<256, unsigned>>` |
| `replxx::` | 66 | Readline-like line editor for `clickhouse-client` | `return replxx::Replxx::completions_t(matched.begin(), matched.end());` |
| `LZ4_*` | 66 | LZ4 compression C API | `M(618, LZ4_DECODER_FAILED) \` |
| `XXH*` | 65 | xxHash hashing | `auto hash = XXH_INLINE_XXH3_128bits_digest(&state);` |
| `boost::container::flat_set` | 61 | Sorted-vector set, cache friendly | `const boost::container::flat_set<UUID> & enabled_roles,` |
| `boost::multi_index` | 60 | Container with several indexes | `boost::multi_index::composite_key<` |
| `usearch::` | 60 | Vector similarity index | `metric_kind = unum::usearch::metric_kind_t::hamming_k;` |
| `simdjson::` | 47 | SIMD JSON parser | `simdjson::dom::parser parser;` |
| `grpc::` | 47 | gRPC protocol server | `std::unique_ptr<grpc::ServerCompletionQueue> queue;` |
| `boost::algorithm::join` / `boost::split` | 92 | String join/split helpers | `boost::split(split, std::string(*it), [](char c) { return c == '/'; });` |
| `fmt::formatter` | 45 | Specialise to make a type formattable | `struct fmt::formatter<DB::NamedCollectionValidateKey<T>>` |
| `boost::hash_combine` | 34 | Combine hashes of several fields | `boost::hash_combine(hash, edit_distance);` |
| `fmt::format_to` | 34 | Format into an output iterator/buffer | `fmt::format_to(std::back_inserter(msg),` |
| `rapidjson::` | 25 | Alternative JSON parser | `rapidjson::MemoryStream ms(json.data(), json.size());` |
| `simdutf::` | 20 | SIMD UTF-8 validation/transcoding | `if (res.error != simdutf::SUCCESS)` |
| `double_conversion::` | 19 | Exact float to/from string | `double_conversion::StringBuilder builder{buffer, sizeof(buffer)};` |
| `sparsehash` | 19 | Google sparse/dense hash maps | `#include <sparsehash/sparse_hash_map>` |
| `boost::dynamic_bitset` | 13 | Run-time sized bitset | `boost::dynamic_bitset<> mask;` |
| `miniselect::` | 2 | Fast selection / partial sort (behind `::partial_sort`) | `::miniselect::floyd_rivest_partial_sort(first, middle, last, compare_wrapper);` |

### 1.17 ClickHouse idioms that replace std things

| Name | Uses | What it is | Example |
|---|---|---|---|
| `String` (`base/base/types.h`) | 38837 | Alias `using String = std::string;` | `answer = [&]() -> std::vector<String>` |
| `Int64` / `UInt64` / `UInt8` / `Float64` (`base/base/types.h`) | 61359 | Fixed-width aliases instead of `int64_t` etc. | `static constexpr UInt8 PACKED_PAGE_SIZE_DEGREE = 10;` |
| `ErrorCodes::` + `throw Exception(...)` (`src/Common/Exception.h`) | 19684 | `DB::Exception` with numeric error code and `fmt` message | `throw Exception(ErrorCodes::NOT_IMPLEMENTED,` |
| `ContextPtr` (`src/Interpreters/Context_fwd.h`) | 7302 | `std::shared_ptr<const Context>` passed everywhere | `void parseArguments(const ASTPtr & ast_function, ContextPtr context)` |
| `ASTPtr` (`src/Parsers/IAST_fwd.h`) | 6578 | `boost::intrusive_ptr<IAST>` for syntax trees | `void optimizeAggregationFunctions(ASTPtr & query)` |
| `Field` (`src/Core/Field.h`) | 5705 | Variant-like value for any SQL type (like `std::variant`) | `case Field::Types::Tuple:` |
| `DataTypePtr` | 5281 | `std::shared_ptr<const IDataType>` | `DataTypePtr element_type;` |
| `ColumnPtr` / `MutableColumnPtr` (`src/Columns/IColumn_fwd.h`) | 5695 | Copy-on-write column pointers built on `COW<IColumn>` | `MutableColumnPtr col_size = ColumnUInt64::create();` |
| `chassert` (`base/base/defines.h`) | 4578 | `assert` that also runs in CI builds, throws `LOGICAL_ERROR` | `chassert(boundary.tie_run_start_chunk_idx == 0);` |
| `ErrorCodes::LOGICAL_ERROR` | 3881 | Exception for "should never happen" bugs | `throw Exception(ErrorCodes::LOGICAL_ERROR,` |
| `assert_cast` (`src/Common/assert_cast.h`) | 3558 | `static_cast` in release, checked cast in debug | `assert_cast<ColumnUInt64 &>(column).insertValue(value.getUInt());` |
| `typeid_cast` (`src/Common/typeid_cast.h`) | 3528 | Fast exact-type cast via `typeid`, replaces `dynamic_cast` | `if (auto * low_cardinality = typeid_cast<ColumnLowCardinality *>(&column))` |
| `UUID` (`base/base/UUID.h`) | 2737 | Strong typedef over `UInt128` | `static void transformUUID(const UUID & src_uuid, UUID & dst_uuid, UInt64 seed)` |
| `ProfileEvents::` (`src/Common/ProfileEvents.h`) | 2608 | Global/per-query event counters | `ProfileEvents::increment(metrics.created);` |
| `VectorWithMemoryTracking` (`src/Common/VectorWithMemoryTracking.h`) | 2247 | `std::vector` with memory-tracked allocator | `#include <Common/VectorWithMemoryTracking.h>` |
| `Int128` / `UInt128` / `UInt256` (`base/base/extended_types.h`) | 4290 | Wide integers via `wide::integer` | `static_assert(sizeof(UInt256) == 32);` |
| `Names` / `NameSet` / `Strings` (`src/Core/Names.h`, `src/Core/Types.h`) | 4597 | Aliases for vector/set of strings | `using NameSet = std::unordered_set<std::string>;` |
| `PODArray` / `PaddedPODArray` (`src/Common/PODArray.h`) | 1686 | `std::vector` for trivial types: no init, padding for SIMD | `PaddedPODArray<AggregateDataPtr> winners;` |
| `LOG_TRACE` / `LOG_DEBUG` / `LOG_INFO` / `LOG_WARNING` / `LOG_ERROR` (`src/Common/logger_useful.h`) | 5195 | `fmt`-style logging macros instead of `std::cout` | `LOG_DEBUG(log, "Table doesn't exist (endpoint: {})", endpoint);` |
| `DateLUT` (`src/Common/DateLUT.h`) | 1455 | Precomputed time-zone lookup tables | `#include <Common/DateLUT.h>` |
| `checkAndGetColumn` (`src/Columns/IColumn.h`) | 1404 | Cast `IColumn` to concrete column or null | `checkAndGetColumn<ColumnString>(to_string.get());` |
| `ThreadPool` family (`src/Common/ThreadPool.h`) | 1385 | Thread pools with metrics and memory tracking | `ThreadPoolCallbackRunnerLocal(PoolT & pool_, ThreadName thread_name_)` |
| `Arena` (`src/Common/Arena.h`) | 1371 | Bump allocator freed all at once | `Arena * arena) const` |
| `IPv4` / `IPv6` (`base/base/IPv4andIPv6.h`) | 1237 | Strong types for IP addresses | `struct IPv4 : StrongTypedef<UInt32, struct IPv4Tag>` |
| `CurrentMetrics::` (`src/Common/CurrentMetrics.h`) | 1138 | Gauges of current activity | `CurrentMetrics::Increment metric_increment{CurrentMetrics::OpenFileForRead};` |
| `LoggerPtr` (`src/Common/Logger.h`) | 1075 | `std::shared_ptr` to a Poco logger | `LoggerPtr log_)` |
| `SipHash` (`src/Common/SipHash.h`) | 1045 | Keyed 128-bit hash used for checksums | `void ColumnDecimal<T>::updateHashFast(SipHash & hash) const` |
| `ALWAYS_INLINE` (`base/base/defines.h`) | 874 | `__attribute__((__always_inline__))` | `void ALWAYS_INLINE forEachMapped(Func && func)` |
| `tryLogCurrentException` (`src/Common/Exception.h`) | 866 | Log the in-flight exception inside `catch (...)` | `DB::tryLogCurrentException(log);` |
| `Stopwatch` (`src/Common/Stopwatch.h`) | 836 | Monotonic timer instead of raw `chrono` | `Stopwatch watch_a;` |
| `Decimal32/64/128/256` (`base/base/Decimal.h`) | 793 | Fixed-point decimal types | `testDecimalFromComponents<Decimal64>(GetParam());` |
| `WriteBufferFromOwnString` (`src/IO/WriteBufferFromString.h`) | 738 | Replaces `std::ostringstream` | `WriteBufferFromOwnString wb;` |
| `DayNum` (`base/base/DayNum.h`) | 704 | Strong typedef for days since epoch | `start_day = calendar.toFirstDayNumOfMonth(point_day);` |
| `TSA_GUARDED_BY` (`base/base/defines.h`) | 647 | Clang thread-safety annotation: member needs mutex | `bool is_writing_file TSA_GUARDED_BY(mutex) = false;` |
| `ReadBufferFromString` (`src/IO/ReadBufferFromString.h`) | 632 | Replaces `std::istringstream` | `ReadBufferFromString in(bytes);` |
| x86 SIMD intrinsics `_mm_*` / `__m128i` | 580 | SSE/AVX vector operations | `crc = _mm_crc32_u64(crc, x.items[2]);` |
| `unlikely` / `likely` (`base/base/defines.h`) | 612 | Macros over `__builtin_expect` branch hints | `if (unlikely(value >= 10000000000000000ULL))` |
| `getCurrentExceptionMessage` (`src/Common/Exception.h`) | 412 | Text of the in-flight exception | `getCurrentExceptionMessage(true /* with_stacktrace */);` |
| `SCOPE_EXIT` (`base/base/scope_guard.h`) | 407 | Run code at scope exit (RAII guard) | `SCOPE_EXIT({ inside_main = false; });` |
| `TSA_REQUIRES` (`base/base/defines.h`) | 295 | Function must be called with mutex held | `void connect() const TSA_REQUIRES(mutex);` |
| `PreformattedMessage` (`src/Common/LoggingFormatStringHelpers.h`) | 292 | Message with its format string kept for logs | `error_message = PreformattedMessage::create(` |
| `thread_local_rng` (`src/Common/thread_local_rng.h`) | 268 | Per-thread `pcg64` random generator | `std::uniform_int_distribution<UInt64>(0, period_ns)(thread_local_rng);` |
| `NO_INLINE` (`base/base/defines.h`) | 263 | `__attribute__((__noinline__))` | `MULTITARGET_FUNCTION_HEADER(void NO_INLINE),` |
| `SharedLockGuard` (`src/Common/SharedLockGuard.h`) | 261 | Shared lock for `SharedMutex`, with TSA annotations | `SharedLockGuard lock(mutex);` |
| `SharedMutex` (`src/Common/SharedMutex.h`) | 252 | Faster reader/writer mutex replacing `std::shared_mutex` | `SharedMutex Data::mutex;` |
| `boost::noncopyable` | 248 | Base class forbidding copy | `class IMetadataStorage : private boost::noncopyable` |
| `ThreadFromGlobalPool` (`src/Common/ThreadPool.h`) | 208 | Replaces `std::thread`; uses global pool, propagates context | `std::unique_ptr<ThreadFromGlobalPool> cleanup_thread;` |
| `HashMap` / `HashSet` (`src/Common/HashTable/HashMap.h`) | 284 | Open-addressing hash tables replacing `std::unordered_map` | `using Entries = HashMap<UInt64, Pair>;` |
| `formatReadableSizeWithBinarySuffix` (`src/Common/formatReadable.h`) | 172 | Bytes to "1.00 GiB" text | `formatReadableSizeWithBinarySuffix(*available_system_memory));` |
| `UNREACHABLE` (`base/base/defines.h`) | 169 | Marks impossible code paths | `UNREACHABLE();` |
| `isNaN` (`base/base/DecomposedFloat.h`) | 167 | NaN check usable for all numeric types | `return DecomposedFloat<T>(x).isNaN();` |
| `collections::range` (`base/base/range.h`) | 165 | Integer range for range-for loops | `for (const auto type : collections::range(AccessEntityType::MAX))` |
| `magic_enum::enum_name` (`base/base/EnumReflection.h`) | 163 | Enum value to its name | `magic_enum::enum_name(state)` |
| `IColumn::mutate` (`src/Columns/IColumn.h`) | 158 | Get a mutable copy-on-write column | `auto mut_column = IColumn::mutate(std::move(column));` |
| `ThreadPoolCallbackRunner` (`src/Common/threadPoolCallbackRunner.h`) | 158 | Schedule callbacks on a pool, get futures | `ThreadPoolCallbackRunnerUnsafe<void> async_runner;` |
| `_KiB` / `_MiB` / `_GiB` literals (`base/base/unit.h`) | 150 | Readable byte-size constants | `CurrentThread::get().memory_tracker.setHardLimit(128_MiB);` |
| `::sort` (`base/base/sort.h`) | 145 | Replaces `std::sort` (pdqsort, shuffled in debug) | `::sort(ordered_buckets.begin(), ordered_buckets.end(),` |
| `common::addOverflow` / `mulOverflow` (`base/base/arithmeticOverflow.h`) | 140 | Overflow-checked integer arithmetic | `if (common::addOverflow(*limit, offset, max_rows))` |
| `NameToNameMap` (`src/Core/Names.h`) | 137 | `std::unordered_map<String, String>` alias | `NameToNameMap query_params;` |
| `MemoryTrackerBlockerInThread` (`src/Common/MemoryTrackerBlockerInThread.h`) | 121 | Temporarily disable memory tracking | `MemoryTrackerBlockerInThread memory_blocker;` |
| `accurate::` comparisons (`src/Core/AccurateComparison.h`) | 121 | Correct compare across signed/unsigned/float | `if (accurate::equalsOp(v, std::numeric_limits<T>::lowest()))` |
| `MULTITARGET_FUNCTION_*` (`src/Common/TargetSpecific.h`) | 109 | Compile one function for several CPU targets | `MULTITARGET_FUNCTION_HEADER(` |
| `TSA_NO_THREAD_SAFETY_ANALYSIS` (`base/base/defines.h`) | 103 | Opt a function out of thread-safety checks | `auto check_if_hosts_reach_stage = [&]() TSA_NO_THREAD_SAFETY_ANALYSIS` |
| `demangle` (`base/base/demangle.h`) | 94 | Readable name from `typeid(T).name()` | `demangle(typeid(ValueType).name())` |
| `USE_MULTITARGET_CODE` (`src/Common/TargetSpecific.h`) | 88 | Build flag guarding multi-target SIMD code | `#if USE_MULTITARGET_CODE` |
| `CacheBase` (`src/Common/CacheBase.h`) | 84 | LRU/SLRU cache replacing ad-hoc maps | `using ReaderAnchorCache = CacheBase<String, ReadBufferFromFileBase>;` |
| `TargetSpecific::` / `isArchSupported` (`src/Common/TargetSpecific.h`) | 160 | Runtime CPU dispatch for SIMD variants | `if (isArchSupported(TargetArch::x86_64_v4))` |
| `unalignedLoad` / `unalignedStore` (`base/base/unaligned.h`) | 108 | Safe unaligned memory access via `memcpy` | `const Int64 nanos = unalignedLoad<Int64>(data.data() + i * 12);` |
| `COWHelper` / `COW` (`src/Common/COW.h`) | 99 | Copy-on-write base for columns | `friend class COWHelper<IColumn, ConcreteColumn>;` |
| `ConcurrentBoundedQueue` (`src/Common/ConcurrentBoundedQueue.h`) | 77 | Thread-safe bounded blocking queue | `#include <Common/ConcurrentBoundedQueue.h>` |
| `TypeList` (`base/base/TypeList.h`) | 67 | Compile-time list of types for dispatch | `TypeList<Derived, VisitorBase>,` |
| `transformEndianness` (`src/Common/transformEndianness.h`) | 63 | Portable byte-order conversion | `transformEndianness<std::endian::little>(stream_hash);` |
| `OpenTelemetry::SpanHolder` (`src/Common/OpenTelemetryTraceContext.h`) | 57 | RAII tracing span | `OpenTelemetry::SpanHolder span("MergeTreePrefetchedReadPool::getTask");` |
| `SCOPE_EXIT_SAFE` (`src/Common/scope_guard_safe.h`) | 54 | `SCOPE_EXIT` that never throws from destructors | `SCOPE_EXIT_SAFE(stopWatchingThread());` |
| ARM NEON `vld1*` intrinsics | 51 | ARM SIMD loads | `const auto bytes0 = vld1q_u8(reinterpret_cast<const uint8_t *>(data + i));` |
| `ClearableHashSet` (`src/Common/HashTable/ClearableHashSet.h`) | 49 | Hash set with O(1) clear via versioning | `using Set = ClearableHashSetWithStackMemory<UInt128, UInt128TrivialHash,` |
| `getThreadId` (`base/base/getThreadId.h`) | 38 | Cheap OS thread id | `auto current_tid = getThreadId();` |
| `PODArrayWithStackMemory` (`src/Common/PODArray.h`) | 32 | Small-buffer-optimised `PODArray` | `using Array = PODArrayWithStackMemory<Value, bytes_in_arena>;` |
| `AlignedBuffer` (`src/Common/AlignedBuffer.h`) | 31 | Raw aligned memory block | `AlignedBuffer place(function->sizeOfData(), function->alignOfData());` |
| `insertAtEnd` (`base/base/insertAtEnd.h`) | 30 | Append one container to another | `insertAtEnd(result, std::move(grant_queries));` |
| `DECLARE_MULTITARGET_CODE` (`src/Common/TargetSpecific.h`) | 20 | Compile a code block for each SIMD target | `DECLARE_MULTITARGET_CODE(` |
| `STRONG_TYPEDEF` (`base/base/strong_typedef.h`) | 12 | Distinct type wrapping a value type | `STRONG_TYPEDEF(NoDefaultCtor, MyStruct)` |
| `CopyableAtomic` (`src/Common/CopyableAtomic.h`) | 8 | `std::atomic` that can be copied | `CopyableAtomic & operator=(U && value_)` |
| `__builtin_expect` (raw) | 5 | Compiler branch hint behind `likely`/`unlikely` | `#    define unlikely(x) (__builtin_expect(!!(x), 0))` |

---

## 2. Printing, logging, formatting, errors and I/O buffers

How ClickHouse turns values into text, sends text to a person or a log, reports failures, and moves raw bytes around.

**How to read the "Uses" column.** Each number is the count of matches (ripgrep, `*.cpp` and `*.h`) in `src/`, `programs/`, `base/` and `utils/`, including unit tests and examples, excluding `contrib/`. Where the pre-computed count was a false match, the corrected number is used and the note says so. Every example is a real line copied from the repository.

**The one rule to remember.** The server (`src/`) never talks to a terminal. It writes **logs** (`LOG_*`), throws **exceptions** (`throw Exception(...)`), and counts **metrics** (`ProfileEvents`, `CurrentMetrics`). Printing with `std::cout`/`std::cerr` is for command-line tools in `programs/` and `utils/`, for tests, and for examples.

### 2.1 Console output

**Why server code avoids `std::cout`/`std::cerr`.** When the server runs as a daemon, nobody reads its stdout. Its logs go to `clickhouse-server.log`, to `system.text_log`, and to the client that set `send_logs_level`. A `std::cerr` line would miss all three. It would also skip the log level filter and the query id tag, and it could interleave with other threads' output. The style check enforces this. Rule 09 in `ci/jobs/scripts/check_style/check_cpp.sh` is titled "Forbid std::cerr/std::cout in src (fine in programs/utils)". It fails for any uncommented `std::cerr` or `std::cout` in `src/` outside `/tests/`, `/examples/`, fuzzers and an allow-list of about 20 files. The allow-listed files include `src/Client/*`, `src/Daemon/BaseDaemon.cpp` (it prints before logging is set up), `src/Loggers/Loggers.cpp` and `src/IO/Ask.cpp`.

**Where `std::cerr` actually appears.** 781 matches are in `src/`. Of these, 681 are in tests, examples, fuzzers and benchmarks. Most of the remaining ~100 are commented-out debug lines, such as `//std::cerr << "====== Added fixed column "` in `optimizeReadInOrder.cpp`, or are in allow-listed files. `programs/`, `utils/` and `base/` have 267 more.

**Tools print through ClickHouse buffers too.** A tool can wrap a file descriptor in a buffer, for example `WriteBufferFromFileDescriptor out(STDOUT_FILENO);`, and then use the `write*` helpers from section 2.2. This skips iostreams and is fast for large output. `programs/format/Format.cpp` uses `WriteBufferFromOStream res_cout(std::cout, 4096);` to feed the AST formatter into `std::cout`.

| Name | Uses | What it does | Example |
|---|---|---|---|
| `std::cerr <<` | 1048 | Unbuffered stream to stderr, for errors and diagnostics in tools | `std::cerr << DB::getCurrentExceptionMessage(true) << '\n';` |
| `std::endl` | 932 | Writes a newline and flushes the stream | `std::cout << desc << std::endl;` |
| `<< "\n"` | 503 | Newline without a flush (faster). Also used on `WriteBuffer` | `std::cerr << "\t" << name << "\n";` |
| `std::ostream &` parameter | 490 | A function that prints to any stream the caller passes | `std::ostream & output_stream_ = std::cout,` |
| `<< '\n'` | 368 | Newline as one `char`. The usual style in ClickHouse | `settings.out << prefix << "Limit " << limit << '\n';` |
| `std::cout <<` | 349 | Buffered stream to stdout, for normal tool output | `std::cout << "=== Snapshot: " << snapshot_file << " ===\n";` |
| `fmt::print(...)` | 156 | Formats with `{}` and writes to stdout (`Install.cpp` has 73) | `fmt::print("The process with pid = {} is running.\n", pid);` |
| `std::setprecision(n)` | 78 | Sets the number of digits for later floating-point output | `std::cerr << std::fixed << std::setprecision(2)` |
| `std::fixed` | 75 | Prints floats as `1.50`, never in scientific notation | `std::cerr << std::fixed << std::setprecision(3);` |
| `perror("...")` | 64 | C call that prints text plus the `errno` reason to stderr | `perror("fork");` |
| `fmt::print(stderr, ...)` | 60 | Same as `fmt::print`, but writes to stderr | `fmt::print(stderr, "(query: {})\n", query);` |
| `WriteBufferFromOStream` | 39 | ClickHouse `WriteBuffer` on top of a `std::ostream` | `WriteBufferFromOStream res_cout(std::cout, 4096);` |
| `std::getline(in, line)` | 37 | Reads one text line from an `std::istream` | `while (std::getline(in, line))` |
| `ReadBufferFromFileDescriptor in(STDIN_FILENO)` | 30 | Reads stdin through a fast ClickHouse buffer | `ReadBufferFromFileDescriptor in(STDIN_FILENO)` |
| `writeRetry(STDERR_FILENO, ...)` | 27 | Raw `write` that retries on `EINTR`. Safe when logging is broken | `writeRetry(STDERR_FILENO, "\n");` |
| `std::setw(n)` | 27 | Pads the next value to a column width | `<< std::setw(6) << m.hits << std::setw(12) << m.overRead()` |
| `WriteBufferFromFileDescriptor out(STDOUT_FILENO)` | 18 | Fast buffered stdout for tools that print a lot | `WriteBufferFromFileDescriptor out(STDOUT_FILENO);` |
| `std::hex` | 17 | Prints the following integers in base 16 | `oss << std::hex << std::setfill('0');` |
| `fmt::println(...)` | 16 | `fmt::print` that adds a newline at the end | `fmt::println("checksum {}", checksum);` |
| `printf(...)` | 16 | C `printf`. Only in the self-extracting decompressor, marked `NOLINT` | `printf("Compression failed.\n"); // NOLINT(modernize-use-std-print)` |
| `::write(STDERR_FILENO, ...)` | 14 | Raw syscall with no allocation. Used in signal handlers and `LOG_IMPL` | `(void)::write(STDERR_FILENO, message.data(), message.size());` |
| `std::cin` | 13 | Standard input stream. Mostly a default parameter in tools | `std::istream & input_stream_ = std::cin,` |
| `std::flush` | 13 | Flushes without a newline, for progress dots | `std::cout << "." << std::flush;` |
| `std::setfill('0')` | 12 | Character that `setw` pads with | `oss << std::hex << std::setfill('0');` |
| `fprintf(out, ...)` | 11 | C formatted print to a `FILE *` (compressor only) | `(void)fprintf(out,` |
| `strerror(errno)` | 9 | C text for an `errno` value. Server code uses `errnoToString` | `std::cerr << "docker-init: warning: lchown " << path_str << ": "` |
| `snprintf(buf, size, ...)` | 7 | C formatted print into a fixed-size `char` array | `(void)snprintf(buf, sizeof(buf), "%08zu", value);` |
| `std::dec` | 6 | Switches integer output back to base 10 | `<< ", at bit position: " << std::dec << reader.count()` |
| `WriteBufferFromFileDescriptor out(STDERR_FILENO)` | 5 | Fast buffered stderr, used in crash and stack-trace printing | `WriteBufferFromFileDescriptor out(STDERR_FILENO, 4096);` |
| `std::clog` | 4 | Buffered stderr stream. Only in vendored `base/poco`, not used by ClickHouse code | none outside `base/poco` |
| `std::left` / `std::right` | 2 / 2 | Aligns `setw` padding to the left or right | `<< std::right << std::setw(6) << "reqs" << std::setw(8) << "incompl"` |
| `std::format(...)` | 2 | C++20 formatting. Forbidden by style check rule 15; use `fmt::format` | `std::format("{:%a, %d %b %Y %H:%M:%S} GMT"` |
| `puts(...)` | 2 | C "print line". Only in `base/poco`. The pre-computed 1216 matched `inputs(` | none outside `base/poco` |
| `write(STDOUT_FILENO, ...)` | 1 | Raw syscall to stdout, in one IO example | `write(STDOUT_FILENO, out.data(), zstr.total_out)` |
| `std::scientific`, `sprintf` | 2, 1 | Only in `base/poco`. `sprintf` is unsafe; never use it | none outside `base/poco` |
| `std::boolalpha` | 0 | Not used. `writeBoolText` or `fmt` prints `true`/`false` instead | none |

### 2.2 Building strings and formatting values

The ClickHouse way to build a string is a `WriteBufferFromOwnString` plus the `write*` helpers from `src/IO/WriteHelpers.h`, or `fmt::format`. `std::stringstream` is banned by style check `check_cpp.sh`, with the message "Use WriteBufferFromOwnString or ReadBufferFromString instead of std::stringstream". The only exceptions are lines marked `// STYLE_CHECK_ALLOW_STD_STRING_STREAM`, which appears 91 times. `src/IO/Operators.h` defines `operator<<` on `WriteBuffer` as `writeText(x, buf)`. It also adds manipulators such as `DB::escape`, `DB::quote`, `DB::double_quote` and `DB::binary`, which change how the next value is written.

| Name | Uses | What it does | Example |
|---|---|---|---|
| `toString(x)` | 2925 | Converts a number, enum or type to `String` (`Common/`, `IO/`) | `DB::writeText(DB::toString(default_desc.kind), buf);` |
| `fmt::format("...{}...", args)` | 2099 | Builds a `String` from a `{}` template. The default choice | `auto filename = fmt::format("{}.txt", i);` |
| `ostr << x` (on `WriteBuffer`) | 1279 | `operator<<` from `IO/Operators.h`. Calls `writeText`. Used in AST formatting | `ostr << " RENAME TO " << backQuoteIfNeed(new_name);` |
| `std::to_string(x)` | 1224 | Standard number-to-string. Common in tests and fuzzers | `res += std::to_string(dimensions);` |
| `writeChar(c, buf)` | 851 | Appends one character to a `WriteBuffer` | `writeChar('{', ostr);` |
| `writeString(s, buf)` | 773 | Appends a string exactly as it is, with no escaping | `writeString(", ", buf);` |
| `WriteBufferFromOwnString` | 739 | `WriteBuffer` that owns a `String`. Read the result with `.str()` | `DB::WriteBufferFromOwnString canonical_part;` |
| `WriteBufferFromString` | 500 | `WriteBuffer` that writes into a `String` you already have | `WriteBufferFromString wb(serialized_key);` |
| `backQuoteIfNeed(name)` | 464 | Wraps an identifier in backticks only if it needs them | `ostr << backQuoteIfNeed(database) << ".";` |
| `writeCString("lit", buf)` | 432 | Appends a C string literal (no `strlen` at runtime) | `writeCString("null", ostr);` |
| `writeText(x, buf)` | 383 | Writes any value in human-readable text form | `writeText('\n', ret);` |
| `fmt::join(range, sep)` | 353 | Formats a container with a separator inside `fmt::format` | `return fmt::format("{}", fmt::join(path, " -> "));` |
| `backQuote(name)` | 329 | Always wraps an identifier in backticks, escaping inside | `return backQuote(name);` |
| `quoteString(s)` | 286 | Returns `s` in single quotes, escaped: `'it\'s'` | `ostr << quoteString(name);` |
| `settings.out <<` | 246 | Writes `EXPLAIN` and plan-dump text into a `WriteBuffer` | `settings.out << prefix << "Offset " << offset << '\n';` |
| `formatWithSecretsOneLine()` | 201 | AST to SQL text including passwords. Banned inside `LOG_*` | `return ast->formatWithSecretsOneLine();` |
| `ReadableSize(x)` | 191 | Wraps bytes so `{}` prints `1.00 MiB` | `upload_part_size_multiply_factor, ReadableSize(max_upload_part_size));` |
| `formatForErrorMessage()` | 180 | AST to short SQL text for error messages, secrets hidden | `column_ast->formatForErrorMessage());` |
| `formatReadableSizeWithBinarySuffix(n)` | 173 | Bytes to `String` like `3.50 GiB` | `formatReadableSizeWithBinarySuffix(query_memory_usage),` |
| `writeIntText(n, buf)` | 152 | Writes an integer in decimal (fast path) | `writeIntText(ref_count, buf);` |
| `dumpStructure()` | 138 | Debug text of a column or block: names, types, sizes | `step_name, output_header->dumpStructure());` |
| `writeJSONString(s, buf, settings)` | 128 | Writes a JSON string literal with escapes | `writeJSONString(e.database_name, out, fs);` |
| `std::ostringstream` | 91 | Standard string stream. Needs the style-check allow marker | `std::ostringstream log_output; // STYLE_CHECK_ALLOW_STD_STRING_STREAM` |
| `WriteBufferFromVector<T>` | 85 | `WriteBuffer` that appends to a `PODArray` or `std::vector` | `WriteBufferFromVector<PODArray<char>> out(parse_buf);` |
| `writeQuoted(x, buf)` | 65 | Writes a value in SQL literal form (strings in quotes) | `writeQuoted(part_names_checksums, out);` |
| `fmt::formatter<T>` specialization | 58 | Teaches `fmt` how to print your own type | `struct fmt::formatter<DB::Identifier>` |
| `dumpTree()` | 55 | Multi-line debug dump of an AST or query tree | `query_tree_node->dumpTree());` |
| `writeEscapedString(s, buf)` | 46 | Writes a string with `\t`, `\n` and `\\` escaped (TSV style) | `writeEscapedString(object.remote_path, buf);` |
| `std::stringstream` | 46 | Read-write string stream. Allowed only with the marker | `std::stringstream out; // STYLE_CHECK_ALLOW_STD_STRING_STREAM` |
| `fmt::runtime(str)` | 44 | Uses a format string known only at runtime (skips compile check) | `LOG_DEBUG(trace_log, fmt::runtime(msg)); break;` |
| `formatReadableQuantity(n)` | 37 | Number to `String` like `1.23 million` | `return formatReadableQuantity(numeric);` |
| `doubleQuoteString(s)` | 34 | Returns `s` in double quotes, escaped | `doubleQuoteString(publication_name));` |
| `fmt::format_to(out, ...)` | 33 | Formats into an existing output iterator or buffer | `return fmt::format_to(ctx.out(), "{}:{}", x.block, x.row);` |
| `writeDateTimeText(t, buf)` | 26 | Writes `YYYY-MM-DD hh:mm:ss` | `writeDateTimeText(value, ostr, time_zone);` |
| `writeDoubleQuoted(x, buf)` | 25 | Like `writeQuoted` but uses double quotes | `writeDoubleQuoted(it->first, wb);` |
| `formatReadableSizeWithDecimalSuffix(n)` | 25 | Bytes to `String` like `3.50 GB` (powers of 1000) | `formatReadableSizeWithDecimalSuffix(value, out, precision);` |
| `writeQuotedString(s, buf)` | 24 | Writes a string in single quotes with escapes | `writeQuotedString(field, quoted);` |
| `<< DB::quote << x` | 21 | Manipulator: the next value is written quoted | `ostr << " FROM " << DB::quote << from;` |
| `formatAST(ast)` | 20 | AST to SQL `String` (tests and fuzzers) | `String ref_sql = formatAST(ref_ast);` |
| `writeFloatText(x, buf)` | 20 | Writes a float in the shortest exact form | `writeFloatText(x, buf, force_decimal_point);` |
| `formatReadableTime(ns)` | 18 | Nanoseconds to `String` like `1.50 ms` | `return formatReadableTime(value * 1e6);` |
| `<< escape << x` | 17 | Manipulator: the next string is written escaped | `out << "from_table: " << escape << from_table << "\n";` |
| `writeDoubleQuotedString(s, buf)` | 15 | Writes a string in double quotes with escapes | `writeDoubleQuotedString(label_values[i], wb);` |
| `writeDateText(d, buf)` | 14 | Writes `YYYY-MM-DD` | `writeDateText(x, buf);` |
| `writeXMLStringForTextElement(s, buf)` | 13 | Escapes `<`, `>` and `&` for XML output | `writeXMLStringForTextElement(field.name, *ostr);` |
| `writeBackQuotedString(s, buf)` | 13 | Writes an identifier in backticks | `writeBackQuotedString(name_and_type.name, buf);` |
| `writeBoolText(b, buf)` | 13 | Writes `true` or `false` | `writeBoolText(is_remote, buffer);` |
| `writePointerHex(p, buf)` | 11 | Writes a pointer as `0x...` | `writePointerHex(func.get(), buf);` |
| `fmt::to_string(x)` | 10 | Formats a single value to `String` | `return fmt::to_string(fmt::join(` |
| `escapeString(s)` | 10 | Returns `s` with escapes applied, as a new `String` | `String table = escapeString(query.table);` |
| `writeUUIDText(u, buf)` | 9 | Writes a UUID in `8-4-4-4-12` form | `writeUUIDText(id, out);` |
| `writeJSONNumber(x, buf, s)` | 6 | Writes a number as JSON (may quote 64-bit ints) | `writeJSONNumber(x, wb, settings);` |
| `writeProbablyBackQuotedString(s, buf)` | 5 | Backticks only when `s` is not a plain identifier | `writeProbablyBackQuotedString(name, ostr);` |
| `<< DB::double_quote << x` | 3 | Manipulator: the next value is written in double quotes | `out << "\n\t" << DB::double_quote << p.first << ": "` |
| `fmt::ptr(p)` | 3 | Formats any pointer as hex in `fmt` | `fmt::ptr(node_ptr));` |
| `<< DB::flush` | 3 | Manipulator: calls `buf.next()` to push bytes out | `<< DB::double_quote << "Hello, world!" << '\n' << DB::flush;` |
| `fmt::memory_buffer` | 1 | Growable `char` buffer for `fmt::format_to` | `auto out = fmt::memory_buffer();` |

### 2.3 Reading, parsing and binary I/O

**The buffer concept in three lines** (from the comment in `src/IO/BufferBase.h`, which `src/IO/ReadBuffer.h` and `src/IO/WriteBuffer.h` both extend):

1. A buffer is a memory range, `buffer()` (`working_buffer`), plus a cursor, `position()` (`pos`). Reading and writing just move `pos`, with no virtual call per byte, and that is why ClickHouse does not use `iostream`.
2. When `pos` reaches `buffer().end()`, `next()` calls the single virtual method `nextImpl()`. A `ReadBuffer` then refills from its source (file, socket, string). A `WriteBuffer` flushes to its sink.
3. `eof()` on a `ReadBuffer` means "`next()` found no more data". On a `WriteBuffer` you must call `finalize()` before destruction to write the tail; destructors must not do this.

Text helpers (`readText`, `assertChar`) live in `src/IO/ReadHelpers.h`. The binary ones (`writeBinary`, `writeVarUInt`) are in `ReadHelpers.h` and `WriteHelpers.h`, and `VarInt.h` holds the variable-length integer code.

| Name | Uses | What it does | Example |
|---|---|---|---|
| `buf.position()` | 1490 | The cursor, as a `char *&`. You can move it directly | `cur_out->position() += size;` |
| `buf.finalize()` | 1003 | Flushes the last bytes and closes a `WriteBuffer`. Mandatory | `buffer->finalize();` |
| `buf.eof()` | 950 | True when a `ReadBuffer` has no more data | `if (istr.eof())` |
| `buf.next()` | 804 | Refills (read) or flushes (write) the working buffer (count is approximate) | `compressed_out->next();` |
| `ReadBufferFromString` | 632 | Reads from a `String` or `string_view` without copying | `ReadBufferFromString in{str};` |
| `ReadBufferFromFile` | 506 | Reads a local file through `read(2)` with a buffer | `level.current_buf = std::make_unique<ReadBufferFromFile>(...);` |
| `writeVarUInt(n, buf)` | 504 | Writes an unsigned int in 1 to 10 bytes (LEB128). Used on the wire | `writeVarUInt(result.size(), ostr);` |
| `writeBinary(x, buf)` | 466 | Writes a value in the native binary layout | `writeBinary(batch_size, buf);` |
| `readVarUInt(n, buf)` | 419 | Reads what `writeVarUInt` wrote | `readVarUInt(x, in);` |
| `readBinary(x, buf)` | 396 | Reads what `writeBinary` wrote | `readBinary(size, buf);` |
| `buf.buffer()` | 377 | The working memory range; `.end()` is one past the last byte | `buf.position() = buf.buffer().end();` |
| `ReadBufferFromMemory` | 363 | Reads from a raw `char *` and a size, without copying | `ReadBufferFromMemory istr("[1]");` |
| `skipWhitespaceIfAny(buf)` | 291 | Skips spaces, tabs and newlines at the cursor | `skipWhitespaceIfAny(*in);` |
| `writeStringBinary(s, buf)` | 278 | Writes a VarUInt length and then the bytes | `writeStringBinary("default.dist", header_buf);` |
| `readText(x, buf)` | 273 | Parses a value from text (number, date, UUID, and so on) | `readText(x, istr);` |
| `writeBinaryLittleEndian(x, buf)` | 246 | Binary write with a fixed byte order (portable on disk) | `writeBinaryLittleEndian(y0, buf);` |
| `WriteBufferFromFile` | 240 | Writes a local file | `std::shared_ptr<WriteBufferFromFile> w` |
| `assertChar(c, buf)` | 236 | Consumes `c` or throws `CANNOT_PARSE_INPUT_ASSERTION_FAILED` | `assertChar('\t', *metadata_buf);` |
| `readStringBinary(s, buf)` | 225 | Reads a VarUInt length and then the bytes | `readStringBinary(name, in);` |
| `PeekableReadBuffer` | 221 | Wrapper that can set a checkpoint and roll back (look-ahead) | `void PeekableReadBuffer::rollbackToCheckpoint(bool drop)` |
| `buf.readStrict(ptr, n)` | 212 | Reads exactly `n` bytes or throws `CANNOT_READ_ALL_DATA` | `buf.readStrict(win.data(), BLOCK);` |
| `parse<T>(str)` | 206 | Parses a whole string to `T` or throws | `UInt64 synced_followers = parse<UInt64>(it->second);` |
| `readBinaryLittleEndian(x, buf)` | 205 | Reads what `writeBinaryLittleEndian` wrote | `readBinaryLittleEndian(data.seen, buf);` |
| `readStringUntilEOF(s, buf)` | 164 | Reads everything that is left into a `String` | `readStringUntilEOF(text, in);` |
| `ReadBufferFromFileDescriptor` | 162 | Reads from any `fd`: pipe, stdin, file | `DB::ReadBufferFromFileDescriptor in1(STDIN_FILENO);` |
| `checkChar(c, buf)` | 158 | Consumes `c` if present and returns `bool`. Never throws | `if (checkChar('"', istr))` |
| `CompressedReadBuffer` | 139 | Decompresses ClickHouse-framed blocks while reading | `CompressedReadBuffer compressed_buf(body);` |
| `CompressedWriteBuffer` | 132 | Compresses with a codec while writing | `std::unique_ptr<CompressedWriteBuffer> index_compressor_stream;` |
| `writeIntBinary(n, buf)` | 124 | Writes an integer as raw fixed-size bytes | `writeIntBinary(rows, buf);` |
| `WriteBufferFromFileDescriptor` | 114 | Writes to any `fd`: stdout, pipe, file | `WriteBufferFromFileDescriptor out(STDOUT_FILENO);` |
| `checkString("lit", buf)` | 113 | Consumes a literal if present and returns `bool` | `else if (!checkString("true", buf))` |
| `LimitReadBuffer` | 90 | Stops reading after N bytes of an inner buffer | `size_t LimitReadBuffer::getEffectiveBufferSize() const` |
| `assertString("lit", buf)` | 88 | Consumes a literal or throws | `assertString("rchar:", in_thread_io);` |
| `readIntText(n, buf)` | 78 | Parses a decimal integer | `readIntText(keys_count, buf);` |
| `readString(s, buf)` | 67 | Reads up to a tab or newline (unescaped TSV field) | `readString(error_message, payload);` |
| `HashingWriteBuffer` | 64 | Computes a checksum of everything written through it | `HashingWriteBuffer marks_hashing;` |
| `WriteBufferFromPocoSocket` | 63 | Writes to a network socket (TCP protocol) | `: WriteBufferFromPocoSocket(socket_, buf_size)` |
| `WriteBufferFromHTTPServerResponse` | 55 | Writes an HTTP response body plus progress headers | `void WriteBufferFromHTTPServerResponse::writeExceptionCode()` |
| `writeBinaryBigEndian(x, buf)` | 54 | Binary write in network byte order (MySQL/PG protocols) | `writeBinaryBigEndian(size(), out);` |
| `std::ofstream` | 54 | Standard file output. Tests only | `std::ofstream(root / "file") << "hello";` |
| `std::ifstream` | 53 | Standard file input. Tests and fuzzers only | `std::ifstream infile(fuzzer_out_file, std::ios::in);` |
| `assertEOF(buf)` | 44 | Throws if any unread bytes remain | `assertEOF(buf);` |
| `writePODBinary(x, buf)` | 44 | Copies the raw bytes of a trivially-copyable struct | `writePODBinary(uuid.items[0], buf);` |
| `parseFromString<T>(s)` | 42 | Parses a string to `T`. Throws if unparsed bytes remain | `num_hosts = parseFromString<size_t>(num_hosts_str);` |
| `readBinaryBigEndian(x, buf)` | 40 | Reads network-byte-order binary | `readBinaryBigEndian(max_rows, payload_in);` |
| `readPODBinary(x, buf)` | 40 | Reads raw struct bytes | `readPODBinary(stack_trace, in);` |
| `ConcatReadBuffer` | 38 | Reads several buffers one after another as one stream | `ConcatReadBuffer in(part1, part2);` |
| `writeVarInt` / `readVarInt` | 34 / 29 | Signed VarInt (zig-zag encoded) | `writeVarInt(equality_id, out);` |
| `ReadBufferFromOwnString` | 31 | `ReadBufferFromString` that owns a copy of the string | `return std::make_unique<ReadBufferFromOwnString>(payload);` |
| `ReadBufferFromPocoSocket` | 31 | Reads from a network socket | `auto in = std::make_shared<ReadBufferFromPocoSocket>(socket);` |
| `readChar(c, buf)` | 30 | Reads one byte or throws at EOF | `readChar(c, limit_buf);` |
| `readEscapedString(s, buf)` | 30 | Reads a TSV-escaped string | `readEscapedString(field, buf);` |
| `ReadBufferFromIStream` | 20 | `ReadBuffer` on top of a `std::istream` (S3 SDK bodies) | `class ReadBufferFromIStream : public BufferWithOwnMemory<ReadBuffer>` |
| `readJSONString(s, buf, s)` | 18 | Reads a JSON string literal and unescapes it | `readJSONString(value, in, settings);` |
| `readQuotedString(s, buf)` | 9 | Reads a `'...'` string literal | `readQuotedString(res.data, data_buf);` |
| `tryParse<T>(x, str)` | 9 | Like `parse<T>` but returns `false` instead of throwing | `if (!tryParse<UInt64>(parsed, csn_part))` |
| `writeFloatBinary(x, buf)` | 8 | Writes a float's raw bytes | `writeFloatBinary(bin_count, buf);` |

### 2.4 Logging

**Where logs go.** Every class keeps a `LoggerPtr log` (a `std::shared_ptr` to a `Poco::Logger`), made once with `getLogger("ClassName")`. The macros in `src/Common/logger_useful.h` send each message to the server log file, to `system.text_log` (through `OwnSplitChannel`), and to the client if the query's `send_logs_level` is at least that level.

**Format-string rules**, enforced by `LOG_IMPL` and `LoggingFormatStringHelpers.h`:

- The first argument after the logger is a string literal with `{}` placeholders, in `fmt` syntax. It is **not** `printf` `%d`.
- The number of `{}` must equal the number of arguments. `formatStringCheckArgsNum` checks this at compile time (`consteval`), so a mismatch fails the build.
- With a single argument, it is logged as-is and no substitution is done.
- A message that is only known at runtime must be wrapped in `fmt::runtime(msg)`.
- `LOG_IMPL` contains `static_assert(!constexprContains(#__VA_ARGS__, "formatWithSecretsOneLine"), "Think twice!")`, which stops secrets from reaching logs.
- The macro checks the level first. Arguments are not evaluated when the level is disabled, so `LOG_TRACE` in a hot path costs almost nothing.
- The literal is stored separately as `format_string`, so `system.text_log` can group messages by pattern (`message_format_string`).

**Levels, from most to least verbose.** Configure them with `<logger><level>` in `config.xml`.

| Level (macro) | Uses | Meaning | Example |
|---|---|---|---|
| `LOG_TRACE` | 1531 | Step-by-step detail for developers. Off in production | `LOG_TRACE(log, "Updating own tail_ptr from {} to {}", old_tail, new_tail);` |
| `LOG_DEBUG` | 1451 | Useful internal events (loaded, selected, pulled N entries) | `LOG_DEBUG(log, "Pushed log entry: {}", log_znode_path);` |
| `LOG_INFO` | 1009 | Normal notable events (startup, leader change) | `LOG_INFO(log, "LeaderElection: leader suddenly changed, will retry");` |
| `LOG_WARNING` | 781 | Something odd that the server recovered from | `LOG_WARNING(getLogger(), "File {} doesn't exist", file_path);` |
| `LOG_TEST` | 756 | Most verbose (`PRIO_TEST`). Only shown when level is `test` | `LOG_TEST(log, "Iterator is exhausted");` |
| `LOG_ERROR` | 378 | A real failure that needs attention | `LOG_ERROR(log, "Clear certificates {}", Poco::Net::Utility::getLastError());` |
| `LOG_FATAL` | 50 | Server cannot continue. Maps to `LogsLevel::error` for clients | `LOG_FATAL(trace_log, fmt::runtime(msg)); break;` |

| Name | Uses | What it does | Example |
|---|---|---|---|
| `LOG_*(log, ...)` | 3916 | The common form: a class member named `log` | `LOG_TRACE(log, "Failed to get {}", description);` |
| `getLogger("Name")` | 1431 | Returns a shared `LoggerPtr` by name (`Common/Logger.h`) | `, log(getLogger("KeeperTCPHandler"))` |
| `LoggerPtr` | 1072 | `std::shared_ptr<Poco::Logger>`. Store it as a member | `explicit IMessageProducer(LoggerPtr log_);` |
| `tryLogCurrentException(log, "msg")` | 858 | Inside `catch`, logs the in-flight exception. Never throws | `tryLogCurrentException(log, __PRETTY_FUNCTION__);` |
| `LOG_*(getLogger("X"), ...)` | 464 | One-off log from a free function, with no member | `LOG_TEST(getLogger("RestoreChunks"), "Restoring chunk infos, result: {}",` |
| `getCurrentExceptionMessage(bool)` | 374 | In `catch`, returns the message text (`true` adds a stack trace) | `std::string message = getCurrentExceptionMessage(true);` |
| `Poco::Logger` | 248 | The underlying logger class (older code uses a raw pointer) | `virtual Poco::Logger & logger() const = 0;` |
| `LogsLevel` | 222 | ClickHouse enum: `none`, `fatal`, `error`, ... `test` | `return LogsLevel::error;` |
| `Poco::Message` | 186 | One log record: text, priority, source file, line | `void format(const Poco::Message & msg, std::string & text) override;` |
| `&Poco::Logger::get("X")` | 74 | Old way to get a raw logger. Prefer `getLogger` | `Poco::Logger * log = &Poco::Logger::get("checkDataPart");` |
| `Poco::Logger::root()` | 54 | Root logger. Set its channel or level in tools and tests | `Poco::Logger::root().setLevel(Poco::Message::PRIO_WARNING);` |
| `Poco::ConsoleChannel` | 45 | Log channel that prints to the console (tools, tests, early daemon) | `Poco::AutoPtr<Poco::ConsoleChannel> channel(new Poco::ConsoleChannel);` |
| `LogSeriesLimiter` | 42 | Logs only some messages of a repeating series | `LogSeriesLimiter & series_log) const override;` |
| `getCurrentExceptionMessageAndPattern` | 35 | Like `getCurrentExceptionMessage`, but keeps the format pattern too | `PreformattedMessage message = getCurrentExceptionMessageAndPattern(` |
| `send_logs_level` (setting) | 33 | Client setting that streams server logs back to the client | `extern const SettingsLogsLevel send_logs_level;` |
| `LoggerRawPtr` | 29 | `Poco::Logger *`, for hot paths without refcounting | `LoggerRawPtr log);` |
| `LogToStr(out, log)` | 24 | Logs a message and also copies it into a `String` | `LOG_TRACE(LogToStr(out_postpone_reason, log), fmt_string, entry.znode_name,` |
| `OwnSplitChannel` | 20 | Sends each record to the file, `text_log` and client queues | `void OwnSplitChannel::log(const Poco::Message & msg)` |
| `LogFrequencyLimiter(log, sec)` | 20 | Logs the same message at most once per `sec` seconds | `LOG_TRACE(LogFrequencyLimiter(log, 30), "Cleanup is cancelled, exiting");` |
| `LOG_IMPL(log, level, prio, ...)` | 19 | The macro under all `LOG_*`. Used directly for a dynamic level | `LOG_IMPL(log, db_level, LEVELS.at(db_level), fmt::runtime(msg));` |
| `createLogger(name, channel)` | 15 | Makes a logger with its own channel (tests) | `auto log = createLogger("TestLogger", my_channel.get());` |
| `getRawLogger("X")` | 8 | Returns `LoggerRawPtr` instead of a shared pointer | `, log(getRawLogger("GRPCServer"))` |

### 2.5 Errors and exceptions

**The pattern.** Nearly all errors are reported with one form:

```cpp
namespace DB
{
namespace ErrorCodes
{
    extern const int BAD_ARGUMENTS;   // declare each code you use, at the top of the .cpp
}

throw Exception(ErrorCodes::BAD_ARGUMENTS, "Script name cannot be empty");
throw Exception(ErrorCodes::INCORRECT_DATA, "{} is not a JSON object", what);
}
```

- Codes are defined once in `src/Common/ErrorCodes.cpp` as `M(number, NAME)`, for example `M(36, BAD_ARGUMENTS)` and `M(49, LOGICAL_ERROR)`.
- Each `.cpp` file re-declares only the codes it uses. That is why `extern const int X;` appears 7370 times.
- The message follows the same compile-checked `{}` rules as logging. `Exception(int code, FormatStringHelper<Args...> fmt, Args &&... args)` is the constructor that checks it.
- The code number reaches the client and appears in `system.errors`.

**`LOGICAL_ERROR` is special.** It means "internal bug: this should never happen", not "the user made a mistake". `Exception::handleErrorCode` in `src/Common/Exception.cpp` calls `abortOnFailedAssertion` for this code in debug and sanitizer builds, so CI catches the bug with a core dump. In release builds it is thrown as a normal exception: the query fails, and the server keeps running. The style check rejects messages that start with `"Logical error:"`, because the code already says it.

**Class hierarchy** (verified in `src/Common/*.h`):

```text
std::exception
└── Poco::Exception                     (base/poco)
    └── DB::Exception                   src/Common/Exception.h: code + message + stack trace
        ├── DB::ErrnoException          src/Common/ErrnoException.h: adds errno text
        ├── DB::NetException            src/Common/NetException.h
        ├── DB::S3Exception, DB::HTTPException, ReadInterruptedException, TestException
        └── Coordination::Exception     (Keeper errors)
            └── zkutil::KeeperException
                └── KeeperMultiException
```

There is no `throwFromErrno` in this tree. The current names are `ErrnoException::throwWithErrno`, `throwFromPath` and `throwFromPathWithErrno`, or plain `throw ErrnoException(...)`, which reads `errno` itself. `ParsingException` has been removed (0 uses).

**Assertions compared** (see `base/base/defines.h`):

| Macro | Debug or sanitizer build | Release build | Use for |
|---|---|---|---|
| `chassert(cond)` | `abortOnFailedAssertion` with the condition text | Not evaluated: `(void)sizeof(!(x))` | Cheap internal invariants |
| `chassert(cond, "comment")` | Aborts with the comment as the message | Not evaluated | The same, with a readable reason |
| `assert(cond)` | C assert. Effectively unused (47 matches, mostly comments and `base/poco`) | Removed by `NDEBUG` | Do not use; use `chassert` |
| `static_assert(cond)` | Compile-time error | Compile-time error | Types, sizes, constants |
| `UNREACHABLE()` | `abort()` | `__builtin_unreachable()` (undefined behavior if reached) | `default:` of an exhaustive `switch` |
| `throw Exception(ErrorCodes::LOGICAL_ERROR, ...)` | Aborts | Throws an exception, query fails | Bugs that must not silently continue in release |
| `abortOnFailedAssertion(msg)` | Aborts with message and stack trace | Aborts too | When continuing is unsafe |

**`try`/`catch` idioms.**

- Catch the narrowest type you need.
- `catch (...)` together with `tryLogCurrentException(log)` is the standard way to say "log it and keep going". Use it in destructors, background tasks and cleanup code, where throwing is not allowed.
- `catch (Exception & e) { e.addMessage("while X"); throw; }` adds context and rethrows the same object.
- Do not swallow exceptions to fall back to a slower path.

| Name | Uses | What it does | Example |
|---|---|---|---|
| `throw Exception(ErrorCodes::X, "fmt {}", a)` | 17417 | The standard way to report any error | `throw Exception(ErrorCodes::LOGICAL_ERROR, "Some ready chunks expected");` |
| `extern const int X;` | 7370 | Declares an error code in `namespace ErrorCodes` | `extern const int BAD_ARGUMENTS;` |
| `chassert(cond)` | 4582 | Debug-only invariant check (see table above) | `chassert(child->parent == nullptr);` |
| `throw Exception(ErrorCodes::LOGICAL_ERROR, ...)` | 3137 | Reports an internal bug. Aborts in debug | `throw Exception(ErrorCodes::LOGICAL_ERROR, "Expected pulling pipeline");` |
| `catch (...)` | 1910 | Catches everything. Usually followed by `tryLogCurrentException` | `catch (...) /// NOLINT(bugprone-empty-catch)` |
| `throw;` | 1241 | Rethrows the current exception, keeping its type | `throw; /// Oracle mismatch — propagate so CI sees it` |
| `DB::Exception` | 1205 | Fully qualified name. Also appears in text like `DB::Exception: ...` | `catch (const DB::Exception & e)` |
| `throw DB::Exception(...)` | 697 | Same as `throw Exception`, used outside `namespace DB` | `throw DB::Exception(DB::ErrorCodes::S3_ERROR, "AWS SigV4 signing failed");` |
| `e.code()` | 612 | The numeric error code of a caught exception | `ASSERT_EQ(ErrorCodes::S3_ERROR, e.code());` |
| `static_assert(...)` | 515 | Compile-time check | `static_assert(sizeof(Base) <= base_memory_reserved_size);` |
| `ErrnoException` | 419 | Exception whose message includes `errno` text | `throw ErrnoException(ErrorCodes::CANNOT_OPEN_FILE, "Cannot create pipe");` |
| `catch (const Exception & e)` | 408 | Catches ClickHouse errors only | `catch (const Exception & e)` |
| `std::exception_ptr` | 318 | Stores an exception to rethrow later or on another thread | `std::exception_ptr background_exception = nullptr;` |
| `NetException` | 309 | Network errors (`DB::` and `Poco::Net::` together) | `throw Poco::Net::NetException("Connection reset by peer");` |
| `PreformattedMessage` | 295 | Message text plus its format pattern, passed around before use | `const PreformattedMessage & help_message,` |
| `e.addMessage("ctx {}", x)` | 258 | Appends context to a caught exception before rethrowing | `e.addMessage("while parsing aggregate function '{}'", function_name);` |
| `Poco::Exception` | 251 | Base of `DB::Exception`. Poco library errors | `catch (const Poco::Exception & e)` |
| `fiu_do_on(FailPoints::x, ...)` | 235 | Failpoint: injects an error in tests (`Common/FailPoint.h`) | `fiu_do_on(FailPoints::mt_throw_after_mutation_commit,` |
| `std::current_exception()` | 235 | Grabs the in-flight exception as an `exception_ptr` | `if (isRetryableException(std::current_exception()))` |
| `std::exception` | 233 | Base of all C++ exceptions | `catch (const std::exception & e)` |
| `FailPointInjection` | 225 | Enables and disables failpoints (`SYSTEM ENABLE FAILPOINT`) | `void FailPointInjection::disableAllFailPoints()` |
| `KeeperException` | 210 | ZooKeeper or Keeper error (`zkutil::`) | `catch (const zkutil::KeeperException & e)` |
| `e.what()` | 203 | Message as `const char *` (standard interface) | `LOG_ERROR(log, "Unable to update connection: {}", e.what());` |
| `e.displayText()` | 186 | Poco message including the class name | `std::string text = e.displayText();` |
| `UNREACHABLE()` | 169 | Marks code that cannot run (see table above) | `default: UNREACHABLE();` |
| `PreformattedMessage::create(fmt, args)` | 149 | Formats a message now, keeping its pattern for logs | `help_message = PreformattedMessage::create(` |
| `std::rethrow_exception(p)` | 147 | Rethrows a stored `exception_ptr` | `std::rethrow_exception(e);` |
| `catch (const DB::Exception & e)` | 124 | Catches ClickHouse errors, qualified | `catch (const DB::Exception & e)` |
| `catch (const std::exception & e)` | 120 | Catches standard-library errors | `catch (const std::exception & e)` |
| `Coordination::Exception` | 117 | Keeper client protocol errors | `catch (const Coordination::Exception & e)` |
| `std::runtime_error` | 108 | Standard runtime error. Mostly tests and tools | `throw std::runtime_error("trigger shutdown_on_exception");` |
| `getCurrentExceptionCode()` | 97 | In `catch`, returns the error code | `auto code = getCurrentExceptionCode();` |
| `abort()` | 85 | Kills the process with `SIGABRT` right away | `case P_COUNT: std::abort();` |
| `catch (const Poco::Exception &)` | 80 | Catches Poco library errors | `catch (const Poco::Exception & e)` |
| `ErrnoException::throwFromPath(code, path, ...)` | 78 | Throws with `errno` and the file path attached | `ErrnoException::throwFromPath(` |
| `errnoToString(errno)` | 75 | Thread-safe `strerror` replacement | `error_message = errnoToString();` |
| `S3Exception` | 69 | S3 SDK error with the S3 error type | `class S3Exception : public Exception` |
| `getExceptionMessage(e, bool)` | 69 | Message of a given exception or `exception_ptr` | `getExceptionMessage(e, /* with_stacktrace = */ true));` |
| `std::terminate()` | 49 | Hard stop. Used when an invariant is broken beyond repair | `std::terminate();` |
| `HTTPException` | 42 | HTTP error that carries the status code | `class HTTPException : public Exception` |
| `fs::filesystem_error` | 32 | Thrown by `std::filesystem` calls | `catch (const fs::filesystem_error & e)` |
| `std::bad_alloc` | 31 | Out of memory (also thrown by the memory tracker) | `throw std::bad_alloc{};` |
| `FormatStringHelper<Args...>` | 28 | Parameter type that compile-checks `{}` versus the arguments | `ErrnoException(int code, FormatStringHelper<Args...> fmt, Args &&... args)` |
| `std::logic_error` | 26 | Standard "programmer error" type | `catch (const std::logic_error & e)` |
| `std::out_of_range` | 23 | Standard range error (`.at()`) | `throw std::out_of_range("actions chain access is out of range");` |
| `catch (const ErrnoException &)` | 21 | Catches only system-call failures | `catch (const ErrnoException & e)` |
| `Exception::createDeprecated(msg, code)` | 20 | Builds from a ready string without a format check | `throw Exception::createDeprecated(e.what(), ErrorCodes::INCORRECT_DATA);` |
| `ErrorCodes::getName(code)` | 20 | Code number to name, such as `"LOGICAL_ERROR"` | `String error_code_name(ErrorCodes::getName(getCurrentExceptionCode()));` |
| `StackTrace().toString()` | 20 | Captures the current stack as text, for logs | `LOG_ERROR(log, "Backup is not opened for writing. Stack trace: {}",` |
| `ReadInterruptedException` | 18 | Thrown when a read is cancelled | `class ReadInterruptedException final : public Exception` |
| `abortOnFailedAssertion(msg)` | 15 | Logs the message and stack, then aborts | `abortOnFailedAssertion("Unexpected exception in refresh scheduling");` |
| `e.getStackTraceString()` | 15 | Stack trace captured when the exception was built | `std::cout << e.getStackTraceString() << std::endl;` |
| `Exception::createRuntime(code, msg)` | 14 | Builds from a runtime `String` message | `throw Exception::createRuntime(` |
| `writeException` / `readException` | 14 / 5 | Serializes an exception over the wire or reads it back | `readException(buf, additional_message).rethrow();` |
| `std::invalid_argument` | 13 | Standard bad-input error | `throw std::invalid_argument("Invalid characters in input");` |
| `getExceptionStackTraceString(p)` | 11 | Stack trace of an `exception_ptr` | `return getExceptionStackTraceString(exception);` |
| `e.rethrow()` | 7 | Rethrows a copy, keeping the dynamic type | `readException(buf, additional_message).rethrow();` |
| `ErrnoException::throwWithErrno(code, errno, ...)` | 6 | Throws with an explicitly given `errno` value | `DB::ErrnoException::throwWithErrno(` |
| `ErrnoException::throwFromPathWithErrno` | 2 | Path plus explicit `errno` | `ErrnoException::throwFromPathWithErrno(` |

**Top 40 error codes.** Counts are `ErrorCodes::NAME` references, which are mostly throw sites. The `extern` declarations are not included.

| Name | Uses | What it does | Example |
|---|---|---|---|
| `LOGICAL_ERROR` | 3881 | Internal bug; should never happen | `throw Exception(ErrorCodes::LOGICAL_ERROR, "Expected pulling pipeline");` |
| `BAD_ARGUMENTS` | 3770 | User passed an invalid argument or option | `throw Exception(ErrorCodes::BAD_ARGUMENTS, "Script name cannot be empty");` |
| `NOT_IMPLEMENTED` | 1150 | Valid request, but not supported yet | `throw Exception(ErrorCodes::NOT_IMPLEMENTED, "Unsupported type of ALTER query");` |
| `ILLEGAL_TYPE_OF_ARGUMENT` | 1112 | Function got an argument of the wrong type | `"Function {} table '{}' should have engine StorageJoin. In scope {}",` |
| `INCORRECT_DATA` | 898 | Input data is malformed | `throw Exception(ErrorCodes::INCORRECT_DATA, "{} is not a JSON object", what);` |
| `ILLEGAL_COLUMN` | 662 | Column has an unexpected internal kind | `throw Exception(ErrorCodes::ILLEGAL_COLUMN, "Unexpected type of cut column");` |
| `NUMBER_OF_ARGUMENTS_DOESNT_MATCH` | 442 | Function got too many or too few arguments | `"Incorrect argument count for table function '{}'. Usage: "` |
| `SUPPORT_IS_DISABLED` | 338 | Feature is turned off by a setting or build | `throw Exception(ErrorCodes::SUPPORT_IS_DISABLED, "Not implemented");` |
| `UNSUPPORTED_METHOD` | 207 | This object does not support this operation | `throw Exception(ErrorCodes::UNSUPPORTED_METHOD, "Original AST was not set");` |
| `CORRUPTED_DATA` | 188 | Stored data failed a sanity check | `throw Exception(ErrorCodes::CORRUPTED_DATA, "header_size too small");` |
| `ARGUMENT_OUT_OF_BOUND` | 175 | Numeric argument is outside the allowed range | `throw Exception(ErrorCodes::ARGUMENT_OUT_OF_BOUND, "Negative sample size");` |
| `TYPE_MISMATCH` | 159 | Two types that must agree do not | `throw Exception(ErrorCodes::TYPE_MISMATCH, "Expected a ColumnString column");` |
| `INCORRECT_QUERY` | 151 | Query parsed but is semantically wrong | `throw Exception(ErrorCodes::INCORRECT_QUERY, "TYPE is required for index");` |
| `OPENSSL_ERROR` | 135 | TLS or crypto library failure | `throw Exception(ErrorCodes::OPENSSL_ERROR, "SSL connection required.");` |
| `SYNTAX_ERROR` | 132 | Text could not be parsed | `throw Exception(ErrorCodes::SYNTAX_ERROR, "Invalid host ID '{}'", content);` |
| `CANNOT_DECOMPRESS` | 120 | Compressed block is broken | `throw Exception(ErrorCodes::CANNOT_DECOMPRESS, "Cannot LZ4_decompress_fast");` |
| `CANNOT_PARSE_DATETIME` | 116 | Date or time text is invalid | `throw Exception(ErrorCodes::CANNOT_PARSE_DATETIME, "Cannot parse Time64 value");` |
| `FILE_DOESNT_EXIST` | 95 | Path not found | `throw Exception(ErrorCodes::FILE_DOESNT_EXIST, "File does not exist: {}", path);` |
| `TOO_LARGE_ARRAY_SIZE` | 91 | Array or state exceeds its size limit | `throw Exception(ErrorCodes::TOO_LARGE_ARRAY_SIZE, "Too large node state size");` |
| `CANNOT_READ_ALL_DATA` | 87 | Input ended before the expected bytes arrived | `throw Exception(ErrorCodes::CANNOT_READ_ALL_DATA, "Stream is in bad state");` |
| `TIMEOUT_EXCEEDED` | 86 | Operation took longer than allowed | `throw Exception(ErrorCodes::TIMEOUT_EXCEEDED, "Lock timeout exceeded");` |
| `INVALID_CONFIG_PARAMETER` | 85 | Bad value in the server config | `throw Exception(ErrorCodes::INVALID_CONFIG_PARAMETER, "boom");` |
| `ABORTED` | 80 | Operation was cancelled (often by shutdown) | `throw Exception(ErrorCodes::ABORTED, "Shutdown is called for table");` |
| `UNKNOWN_TABLE` | 78 | Table does not exist | `throw Exception(ErrorCodes::UNKNOWN_TABLE, "{}", message);` |
| `VALUE_IS_OUT_OF_RANGE_OF_DATA_TYPE` | 77 | Value does not fit the target type | `"The count argument of function {} is out of range for Int64: {}",` |
| `INVALID_SETTING_VALUE` | 69 | Setting has an invalid value | ``"Setting `tags_to_columns` has duplicate tag name `{}`", tag_name);`` |
| `FAULT_INJECTED` | 69 | Deliberate failure from a failpoint or test | `throw Exception(ErrorCodes::FAULT_INJECTED, "Failed to startup");` |
| `CANNOT_EXECUTE_PROMQL_QUERY` | 68 | PromQL query cannot be evaluated | `"Binary operator '{}' doesn't allow bool modifier",` |
| `SIZES_OF_COLUMNS_DOESNT_MATCH` | 64 | Columns in one block have different row counts | `"Size of indexes ({}) is less than required ({})", indexes_size, limit);` |
| `DECIMAL_OVERFLOW` | 64 | Decimal arithmetic overflowed | `throw Exception(ErrorCodes::DECIMAL_OVERFLOW, "Decimal math overflow");` |
| `ACCESS_DENIED` | 62 | Missing permission (SQL grant or OS) | `throw Exception(ErrorCodes::ACCESS_DENIED, "Cannot list directory {}: {}",` |
| `SYSTEM_ERROR` | 61 | Generic operating-system failure | `{ throw Exception(ErrorCodes::SYSTEM_ERROR, "Injected shutdown failure"); });` |
| `QUERY_WAS_CANCELLED` | 60 | User or server cancelled the query | `throw Exception(ErrorCodes::QUERY_WAS_CANCELLED, "Consumption was interrupted");` |
| `ICEBERG_SPECIFICATION_VIOLATION` | 58 | Iceberg metadata breaks the spec | `"Iceberg table metadata file '{}' doesn't contain required field '{}'",` |
| `DATALAKE_DATABASE_ERROR` | 55 | Data lake catalog failure | `throw DB::Exception(DB::ErrorCodes::DATALAKE_DATABASE_ERROR, "{}", message);` |
| `AUTHENTICATION_FAILED` | 53 | Wrong credentials or token | `throw Exception(ErrorCodes::AUTHENTICATION_FAILED, "bad exchange token");` |
| `TOO_LARGE_STRING_SIZE` | 51 | String length exceeds its limit | `throw Exception(ErrorCodes::TOO_LARGE_STRING_SIZE, "Too large string size.");` |
| `NETWORK_ERROR` | 48 | Socket or connection failure | `throw Exception(ErrorCodes::NETWORK_ERROR, "Failed to listen for {}: {}",` |
| `CANNOT_CONVERT_TYPE` | 47 | Type conversion is not possible | `"Conversion from {} to {} is not supported",` |
| `UNEXPECTED_AST_STRUCTURE` | 44 | Parser produced an AST shape the code did not expect | `throw Exception(ErrorCodes::UNEXPECTED_AST_STRUCTURE, "AST node is nullptr");` |

### 2.6 Metrics: the server's other output

Besides logs, the server reports what it is doing through counters. Users read them with SQL, not from a console.

- `ProfileEvents` are monotonically increasing counters, kept per query, per thread and globally. They appear in `system.events` and in `system.query_log.ProfileEvents`.
- `CurrentMetrics` are gauges of "how many right now". They appear in `system.metrics`.
- Error counts per code appear in `system.errors`.
- Log lines appear in `system.text_log`.
- Every `LOG_*` call also increments a `ProfileEvents` counter for its level (`ProfileEvents::incrementForLogMessage`).

| Name | Uses | What it does | Example |
|---|---|---|---|
| `ProfileEvents::increment(ev, n)` | 1382 | Adds `n` (default 1) to an event counter | `ProfileEvents::increment(ProfileEvents::StorageBufferPassedRowsMaxThreshold);` |
| `Stopwatch` | 806 | Measures elapsed time, often fed into a `ProfileEvents` counter | `Stopwatch watch;` |
| `ProfileEvents::Event` | 330 | Type of an event id, declared `extern` like error codes | `ProfileEvents::Event write_event;` |
| `AsynchronousMetrics` | 219 | Periodically computed gauges (memory, CPU, disks) | `class AsynchronousMetrics;` |
| `CurrentMetrics::Metric` | 127 | Type of a gauge id | `CurrentMetrics::Metric count_metric,` |
| `CurrentMetrics::Increment` | 113 | RAII: +1 now, −1 when the scope ends | `CurrentMetrics::Increment metric_increment{CurrentMetrics::DictCacheRequests};` |
| `CurrentMetrics::sub(m, n)` | 100 | Decrements a gauge by hand | `CurrentMetrics::sub(CurrentMetrics::PartsActive);` |
| `system.query_log` | 96 | Table with one row per query, including its `ProfileEvents` | ``"Not adding query to 'system.query_log' since setting `log_queries` is false"`` |
| `ProfileEvents::Counters` | 87 | A set of counters (per thread, per query, per user) | `std::vector<std::unique_ptr<ProfileEvents::Counters>> users;` |
| `text_log` (config) | 79 | Config section that enables `system.text_log` | `if (allowTextLog() && config.has("text_log"))` |
| `CurrentMetrics::add(m, n)` | 76 | Increments a gauge by hand | `CurrentMetrics::add(CurrentMetrics::ReadonlyReplica);` |
| `OpenTelemetry::SpanHolder` | 60 | RAII tracing span exported to `system.opentelemetry_span_log` | `OpenTelemetry::SpanHolder span(__FUNCTION__);` |
| `system.trace_log` | 40 | Sampling profiler stacks and memory traces | `/// meaningless empty row to system.trace_log and inflate the sample count.` |
| `system.events` | 32 | SQL view of global `ProfileEvents` | `SELECT * FROM system.events WHERE event='QueryMemoryLimitExceeded';` |
| `CurrentMetrics::set(m, v)` | 23 | Sets a gauge to an exact value | `CurrentMetrics::set(CurrentMetrics::KeeperAliveConnections, 0);` |
| `system.metrics` | 20 | SQL view of `CurrentMetrics` | `SELECT * FROM system.metrics LIMIT 10` |
| `system.asynchronous_metrics` | 20 | SQL view of `AsynchronousMetrics` | `` `TotalIndexGranularityBytesInMemory` metric in `system.asynchronous_metrics`, `` |
| `system.errors` | 14 | Count of each error code since startup | `FROM system.errors` |
| `system.text_log` | 11 | Server log lines stored as a table | `SELECT * FROM system.text_log LIMIT 1 \G` |

---

## 3. ClickHouse's own concepts, classes and functions

Counts are whole-word occurrences in `*.cpp`/`*.h` under `src/`, `programs/`, `base/`, `utils/` (no `contrib/`). They include declarations, comments and `#include` paths, so treat them as "how often you will bump into this name", not as exact call counts. Names that double as directory names (`Columns`, `DataTypes`, `Processors`) or collide with Poco types (`Context`, `Pipe`, `Stopwatch`, `ThreadPool`) are inflated.

### 3.1 Map of `src/`

Most C++ code lives in `src/`; `programs/` holds the entry points (`clickhouse-server`, `clickhouse-client`, `clickhouse-local`, `keeper`, ...), `base/` holds low-level headers (`base/base/types.h`, `base/base/defines.h`) and a vendored Poco, `utils/` holds helper tools.

| Directory | Files (`.cpp`/`.h`) | What lives there |
|---|---|---|
| `src/Storages` | 1582 | Table engines: `MergeTree` family, `Distributed`, `Kafka`, S3, system tables |
| `src/Functions` | 1187 | All regular SQL functions (`plus`, `length`, `toDate`, ...) |
| `src/Processors` | 1019 | Pipeline processors, formats, transforms, `QueryPlan` steps and optimizations |
| `src/Common` | 1011 | Shared utilities: hash tables, `PODArray`, `Arena`, thread pools, ZooKeeper client |
| `src/Interpreters` | 796 | Query interpreters, `Context`, `ActionsDAG`, joins, `Aggregator`, caches |
| `src/Parsers` | 604 | SQL lexer, parsers and AST node classes |
| `src/IO` | 449 | `ReadBuffer`/`WriteBuffer` hierarchy, S3/HTTP clients, text/binary helpers |
| `src/DataTypes` | 254 | `IDataType` implementations and their `ISerialization`s |
| `src/AggregateFunctions` | 239 | `IAggregateFunction` implementations and combinators (`-If`, `-State`, ...) |
| `src/Disks` | 204 | `IDisk` abstraction: local, object storage (S3, Azure), caches, encryption |
| `src/Server` | 198 | Protocol handlers: TCP, HTTP, MySQL, PostgreSQL, gRPC, Arrow Flight |
| `src/Analyzer` | 190 | New query analyzer: query tree nodes, name resolution, rewrite passes |
| `src/Core` | 177 | Fundamental types: `Block`, `Field`, `Settings`, `ServerSettings`, protocol constants |
| `src/Dictionaries` | 137 | External dictionaries (`flat`, `hashed`, `cache`, ...) and their sources |
| `src/Access` | 132 | Users, roles, grants, quotas, row policies, authentication |
| `src/Databases` | 120 | Database engines: `Atomic`, `Replicated`, `MySQL`, `PostgreSQL`, `DataLake` |
| `src/Backups` | 120 | `BACKUP`/`RESTORE` implementation |
| `src/Client` | 118 | `clickhouse-client` core (`ClientBase`), `Connection`, BuzzHouse fuzzer |
| `src/Coordination` | 100 | ClickHouse Keeper: Raft-based ZooKeeper replacement (`KeeperStorage`, `KeeperServer`) |
| `src/Columns` | 94 | `IColumn` and every in-memory column implementation |
| `src/Formats` | 88 | Format registry (`FormatFactory`), `FormatSettings`, schema inference helpers |
| `src/Compression` | 80 | Compression codecs (`LZ4`, `ZSTD`, `Delta`, `Gorilla`, ...) and compressed buffers |
| `src/TableFunctions` | 73 | Table functions: `s3`, `file`, `remote`, `numbers`, `url`, ... |
| `src/QueryPipeline` | 45 | `QueryPipeline`, `QueryPipelineBuilder`, `Pipe`, `BlockIO`, `Chain` |
| `src/Planner` | 41 | Turns an analyzed query tree into a `QueryPlan` |
| `src/Loggers` | 12 | Logger setup, formatting channels, text log |
| `src/Daemon` | 6 | `BaseDaemon`: signal handling, crash writer, Graphite |
| `src/BridgeHelper` | 4 | Talks to `clickhouse-library-bridge` / `odbc-bridge` processes |
| `src/Examples` | 4 | Small example programs linked against the library |

### 3.2 The data model

How values flow: a single SQL value (a literal, a setting, a partition key) is a `Field`, a tagged union (`UInt64`, `String`, `Array`, `Tuple`, ...). Real query data is never processed value by value: it is held in an `IColumn`, a typed vector of values for one column (`ColumnUInt64` wraps a `PaddedPODArray<UInt64>`). An `IDataType` describes the SQL type and knows how to create and (de)serialize matching columns. A `Block` is a set of `ColumnWithTypeAndName` (column + type + name) and is the unit passed between interpreters, storages and formats; inside the processor pipeline the unit is `Chunk` (columns + row count, no names), with names/types carried separately in a header `Block`. Columns are copy-on-write (`COW`): `ColumnPtr` is immutable and shareable, `IColumn::mutate` gives a `MutableColumnPtr`.

| Name | Uses | Where (header) | What it is |
|---|---|---|---|
| `DataTypes` | 7600 | `src/DataTypes/IDataType_fwd.h` | `std::vector<DataTypePtr>`, also the directory name |
| `IColumn` | 6797 | `src/Columns/IColumn.h` | Abstract base for every in-memory column |
| `Field` | 6371 | `src/Core/Field.h` | Variant holding one value of any SQL type |
| `DataTypePtr` | 5610 | `src/DataTypes/IDataType_fwd.h` | `shared_ptr<const IDataType>`, types are immutable and shared |
| `Columns` | 5067 | `src/Columns/IColumn_fwd.h` | `std::vector<ColumnPtr>`; count inflated by include paths |
| `Block` | 4780 | `src/Core/Block.h` | Ordered columns with names and types |
| `ColumnPtr` | 4024 | `src/Columns/IColumn_fwd.h` | Immutable shared pointer to a column (COW) |
| `ColumnString` | 3141 | `src/Columns/ColumnString.h` | Strings as one `chars` buffer plus `offsets` |
| `TypeIndex` | 2926 | `src/Core/TypeId.h` | Enum of type ids for fast type switches |
| `DataTypeString` | 2679 | `src/DataTypes/DataTypeString.h` | The `String` SQL type |
| `ColumnArray` | 2440 | `src/Columns/ColumnArray.h` | Arrays: nested data column plus offsets column |
| `ColumnsWithTypeAndName` | 2411 | `src/Core/ColumnsWithTypeAndName.h` | Vector of `ColumnWithTypeAndName`; function arguments use it |
| `ColumnsDescription` | 1668 | `src/Storages/ColumnsDescription.h` | Table column list with defaults, codecs, comments, TTL |
| `ColumnVector` | 1559 | `src/Columns/ColumnVector.h` | Template column of fixed-size numbers |
| `DataTypeArray` | 1521 | `src/DataTypes/DataTypeArray.h` | The `Array(T)` SQL type |
| `SharedHeader` | 1483 | `src/Core/Block_fwd.h` | `shared_ptr<const Block>` used as a pipeline header |
| `ColumnNullable` | 1337 | `src/Columns/ColumnNullable.h` | Nested column plus `UInt8` null map |
| `ISerialization` | 1335 | `src/DataTypes/Serializations/ISerialization.h` | Reads/writes a column in text or binary formats |
| `ColumnConst` | 1316 | `src/Columns/ColumnConst.h` | One value logically repeated N times |
| `ColumnWithTypeAndName` | 1297 | `src/Core/ColumnWithTypeAndName.h` | Struct: `column`, `type`, `name` |
| `IDataType` | 1159 | `src/DataTypes/IDataType.h` | Abstract SQL data type; creates columns, serializations |
| `DataTypeUInt64` | 1066 | `src/DataTypes/DataTypesNumber.h` | The `UInt64` SQL type |
| `NamesAndTypesList` | 1015 | `src/Core/NamesAndTypes.h` | `std::list` of `NameAndTypePair` for schemas |
| `ColumnUInt8` | 1007 | `src/Columns/ColumnsNumber.h` | `ColumnVector<UInt8>`; also filters and booleans |
| `DataTypeNullable` | 1006 | `src/DataTypes/DataTypeNullable.h` | The `Nullable(T)` SQL type |
| `DataTypeTuple` | 962 | `src/DataTypes/DataTypeTuple.h` | The `Tuple(...)` SQL type |
| `MutableColumns` | 926 | `src/Columns/IColumn_fwd.h` | `std::vector<MutableColumnPtr>` being filled |
| `ColumnTuple` | 843 | `src/Columns/ColumnTuple.h` | One sub-column per tuple element |
| `DataTypeLowCardinality` | 819 | `src/DataTypes/DataTypeLowCardinality.h` | Dictionary-encoded `LowCardinality(T)` type |
| `MutableColumnPtr` | 781 | `src/Columns/IColumn_fwd.h` | Unique mutable pointer to a column being built |
| `DataTypeFactory` | 777 | `src/DataTypes/DataTypeFactory.h` | Creates types from names like `"Array(UInt8)"` |
| `WhichDataType` | 757 | `src/DataTypes/IDataType.h` | Helper with `isUInt64`, `isString`... checks on `TypeIndex` |
| `ColumnVariant` | 744 | `src/Columns/ColumnVariant.h` | Column for `Variant(T1, T2, ...)` |
| `ColumnUInt64` | 743 | `src/Columns/ColumnsNumber.h` | `ColumnVector<UInt64>` |
| `ColumnFixedString` | 634 | `src/Columns/ColumnFixedString.h` | Fixed-length strings in one buffer |
| `DataTypeDateTime` | 620 | `src/DataTypes/DataTypeDateTime.h` | `DateTime` type, seconds since epoch with time zone |
| `DataTypeDateTime64` | 591 | `src/DataTypes/DataTypeDateTime64.h` | `DateTime64(scale)` sub-second timestamps |
| `DataTypeUInt8` | 587 | `src/DataTypes/DataTypesNumber.h` | The `UInt8` SQL type |
| `DataTypeMap` | 451 | `src/DataTypes/DataTypeMap.h` | The `Map(K, V)` SQL type |
| `DecimalField` | 435 | `src/Core/Field.h` | `Field` payload for decimals: value plus scale |
| `ColumnLowCardinality` | 430 | `src/Columns/ColumnLowCardinality.h` | Dictionary plus index column |
| `ColumnDynamic` | 408 | `src/Columns/ColumnDynamic.h` | Column for `Dynamic` type, variant with open type set |
| `ColumnDecimal` | 396 | `src/Columns/ColumnDecimal.h` | Decimals stored as scaled integers |
| `NameAndTypePair` | 391 | `src/Core/NamesAndTypes.h` | Column name and its `DataTypePtr` |
| `ColumnMap` | 385 | `src/Columns/ColumnMap.h` | Map stored as `Array(Tuple(key, value))` |
| `ColumnObject` | 372 | `src/Columns/ColumnObject.h` | Column for the `JSON` type |
| `ColumnReplicated` | 370 | `src/Columns/ColumnReplicated.h` | Lazily replicated column: indexes into a nested column |
| `DataTypeDate` | 365 | `src/DataTypes/DataTypeDate.h` | `Date` type, `UInt16` days since epoch |
| `DataTypeFloat64` | 326 | `src/DataTypes/DataTypesNumber.h` | The `Float64` SQL type |
| `ColumnAggregateFunction` | 309 | `src/Columns/ColumnAggregateFunction.h` | Column of aggregate-function states |
| `ColumnRawPtrs` | 291 | `src/Columns/IColumn_fwd.h` | `std::vector<const IColumn *>` for hot loops |
| `ColumnSparse` | 282 | `src/Columns/ColumnSparse.h` | Stores only non-default values plus offsets |
| `DataTypeInt64` | 278 | `src/DataTypes/DataTypesNumber.h` | The `Int64` SQL type |
| `NullMap` | 261 | `src/Columns/ColumnNullable.h` | `PaddedPODArray<UInt8>`, 1 means NULL |
| `FieldVisitorToString` | 249 | `src/Common/FieldVisitorToString.h` | Visitor that prints a `Field` as SQL literal |
| `DataTypeVariant` | 246 | `src/DataTypes/DataTypeVariant.h` | The `Variant(...)` SQL type |
| `DataTypeFixedString` | 243 | `src/DataTypes/DataTypeFixedString.h` | The `FixedString(N)` SQL type |
| `DataTypeUInt32` | 241 | `src/DataTypes/DataTypesNumber.h` | The `UInt32` SQL type |
| `ColumnFloat64` | 236 | `src/Columns/ColumnsNumber.h` | `ColumnVector<Float64>` |
| `IColumn::Filter` | 231 | `src/Columns/IColumn.h` | `PaddedPODArray<UInt8>` mask for `IColumn::filter` |
| `ColumnUInt32` | 229 | `src/Columns/ColumnsNumber.h` | `ColumnVector<UInt32>` |
| `DataTypeDecimal` | 227 | `src/DataTypes/DataTypesDecimal.h` | `Decimal(P, S)` SQL type template |
| `DataTypeAggregateFunction` | 224 | `src/DataTypes/DataTypeAggregateFunction.h` | `AggregateFunction(f, T)` state type |
| `DataTypeNumber` | 218 | `src/DataTypes/DataTypesNumber.h` | Template base for all numeric types |
| `DataTypeObject` | 200 | `src/DataTypes/DataTypeObject.h` | The `JSON` SQL type |
| `IColumn::Offsets` | 172 | `src/Columns/IColumn.h` | `PaddedPODArray<UInt64>` of cumulative end positions |
| `ColumnDescription` | 160 | `src/Storages/ColumnsDescription.h` | One table column: name, type, default, codec, comment |
| `IColumn::Permutation` | 158 | `src/Columns/IColumn.h` | Row order produced by sorting |
| `ColumnInt64` | 149 | `src/Columns/ColumnsNumber.h` | `ColumnVector<Int64>` |
| `SerializationInfo` | 145 | `src/DataTypes/Serializations/SerializationInfo.h` | Chooses dense or sparse serialization per column |
| `ColumnFunction` | 119 | `src/Columns/ColumnFunction.h` | Deferred function application; lambdas, short-circuit |
| `DataTypeDynamic` | 106 | `src/DataTypes/DataTypeDynamic.h` | The `Dynamic` SQL type |
| `ColumnSet` | 97 | `src/Columns/ColumnSet.h` | Holds a prepared set for `IN` |
| `COWHelper` | 79 | `src/Common/COW.h` | CRTP helper implementing `create`/`clone` for columns |
| `ColumnUUID` | 63 | `src/Columns/ColumnsNumber.h` | `ColumnVector<UUID>` |
| `COW` | 47 | `src/Common/COW.h` | Copy-on-write base with intrusive refcount |
| `ColumnNothing` | 43 | `src/Columns/ColumnNothing.h` | Column of type `Nothing` (only size) |

### 3.3 Query path

A query goes: text → `Lexer`/`IParser` → `IAST` tree → `InterpreterFactory` picks an `IInterpreter` → for `SELECT` with the analyzer, `QueryTreeBuilder` turns AST into `IQueryTreeNode`s, `QueryAnalyzer` resolves names, passes rewrite the tree → `Planner` builds a `QueryPlan` of `IQueryPlanStep`s (expressions as `ActionsDAG`) → plan optimizations → `QueryPlan::buildQueryPipeline` produces a `QueryPipelineBuilder` of `IProcessor`s connected by `Port`s → `PipelineExecutor` runs it on threads. Every step gets a `ContextPtr` carrying settings, current database, user and caches.

Settings are declared once in a list macro and accessed through a typed handle. In `src/Core/Settings.cpp`: `DECLARE(MaxThreads, max_threads, 0, R"(doc...)", 0)` inside `COMMON_SETTINGS`. A user declares the handle in its own `.cpp`: `namespace Setting { extern const SettingsUInt64 max_threads_for_indexes; }` and reads it as `context->getSettingsRef()[Setting::max_threads]`. `MergeTreeSettings` (`MergeTreeSetting::name`) and `ServerSettings` (`ServerSetting::name`) follow the same pattern. The doc string in `DECLARE` is the source of truth for the settings documentation.

| Name | Uses | Where (header) | What it is |
|---|---|---|---|
| `ContextPtr` | 6929 | `src/Interpreters/Context_fwd.h` | `shared_ptr<const Context>` passed almost everywhere |
| `ASTPtr` | 6913 | `src/Parsers/IAST_fwd.h` | `boost::intrusive_ptr<IAST>` to an AST node |
| `Setting::` access | 4784 | `src/Core/Settings.h` | `settings[Setting::name]` typed setting lookups |
| `Processors` | 4217 | `src/Processors/IProcessor.h` | `std::vector<ProcessorPtr>`; also directory name |
| `FormatSettings` | 3951 | `src/Formats/FormatSettings.h` | Options for input/output formats (CSV delimiter...) |
| `QueryPlan` | 3676 | `src/Processors/QueryPlan/QueryPlan.h` | Tree of logical plan steps for a query |
| `ActionsDAG` | 3520 | `src/Interpreters/ActionsDAG.h` | DAG of expression nodes: inputs, functions, outputs |
| `Context` | 3417 | `src/Interpreters/Context.h` | Server/session/query state: settings, catalogs, caches |
| `Settings` | 2347 | `src/Core/Settings.h` | All query-level settings (`max_threads`, ...) |
| `ASTLiteral` | 1941 | `src/Parsers/ASTLiteral.h` | AST node holding a constant `Field` |
| `StorageID` | 1871 | `src/Interpreters/StorageID.h` | Database, table name and UUID of a table |
| `ASTIdentifier` | 1624 | `src/Parsers/ASTIdentifier.h` | AST node for names like `db.table.col` |
| `QueryTreeNodePtr` | 1595 | `src/Analyzer/IQueryTreeNode.h` | `shared_ptr<IQueryTreeNode>` in analyzer trees |
| `Expected` | 1554 | `src/Parsers/IParser.h` | Collects what the parser expected, for error messages |
| `ASTFunction` | 1521 | `src/Parsers/ASTFunction.h` | AST node for function calls and operators |
| `SettingsBool` | 1424 | `src/Core/Settings.h` | Typed handle for a `Bool` setting |
| `ParserKeyword` | 1285 | `src/Parsers/CommonParsers.h` | Parses one SQL keyword like `SELECT` |
| `IAST` | 1196 | `src/Parsers/IAST.h` | Abstract AST node: children, `formatImpl`, `clone` |
| `TokenType` | 1094 | `src/Parsers/Lexer.h` | Enum of lexer token kinds |
| `QueryPipeline` | 1062 | `src/QueryPipeline/QueryPipeline.h` | Finished, executable graph of processors |
| `SettingsUInt64` | 1015 | `src/Core/Settings.h` | Typed handle for a `UInt64` setting |
| `ASTSelectQuery` | 986 | `src/Parsers/ASTSelectQuery.h` | AST of one `SELECT` with its clauses |
| `Pipe` | 972 | `src/QueryPipeline/Pipe.h` | Set of processors with open output ports |
| `ASTExpressionList` | 812 | `src/Parsers/ASTExpressionList.h` | AST list of expressions (select list, args) |
| `QueryPipelineBuilder` | 739 | `src/QueryPipeline/QueryPipelineBuilder.h` | Mutable pipeline being assembled from plan steps |
| `IProcessor` | 671 | `src/Processors/IProcessor.h` | Pipeline node: `prepare` then `work` state machine |
| `QueryTreeNodeType` | 613 | `src/Analyzer/IQueryTreeNode.h` | Enum: `QUERY`, `FUNCTION`, `COLUMN`, `CONSTANT`, ... |
| `ContextMutablePtr` | 603 | `src/Interpreters/Context_fwd.h` | `shared_ptr<Context>` when you must change settings |
| `ReadFromMergeTree` | 595 | `src/Processors/QueryPlan/ReadFromMergeTree.h` | Plan step reading `MergeTree` parts with index analysis |
| `ASTCreateQuery` | 589 | `src/Parsers/ASTCreateQuery.h` | AST of `CREATE TABLE/VIEW/DATABASE` |
| `SortDescription` | 576 | `src/Core/SortDescription.h` | List of sort columns with direction and collation |
| `QueryProcessingStage` | 576 | `src/Core/QueryProcessingStage.h` | How far to process: `FetchColumns`, `WithMergeableState`, `Complete` |
| `FunctionNode` | 570 | `src/Analyzer/FunctionNode.h` | Analyzer node for function call |
| `IParserBase` | 534 | `src/Parsers/IParserBase.h` | Base for parsers; implement `parseImpl` |
| `SelectQueryInfo` | 507 | `src/Storages/SelectQueryInfo.h` | What a storage gets for reading: filters, prewhere, tree |
| `BlockIO` | 505 | `src/QueryPipeline/BlockIO.h` | Result of `executeQuery`: pipeline plus callbacks |
| `ExpressionActions` | 468 | `src/Interpreters/ExpressionActions.h` | Linearized, executable form of an `ActionsDAG` |
| `SettingsChanges` | 452 | `src/Common/SettingsChanges.h` | List of `name = value` setting changes |
| `ConstantNode` | 429 | `src/Analyzer/ConstantNode.h` | Analyzer node for a constant value |
| `QueryNode` | 426 | `src/Analyzer/QueryNode.h` | Analyzer node for a whole `SELECT` |
| `MergeTreeSettings` | 418 | `src/Storages/MergeTree/MergeTreeSettings.h` | Per-table `MergeTree` settings |
| `ISource` | 388 | `src/Processors/ISource.h` | Processor producing chunks; implement `generate` |
| `IParser` | 378 | `src/Parsers/IParser.h` | Parser interface: `parse(Pos &, ASTPtr &, Expected &)` |
| `ASTSelectWithUnionQuery` | 359 | `src/Parsers/ASTSelectWithUnionQuery.h` | Top-level `SELECT ... UNION ...` AST |
| `Port` | 355 | `src/Processors/Port.h` | Connection point between processors carrying chunks |
| `ExpressionStep` | 351 | `src/Processors/QueryPlan/ExpressionStep.h` | Plan step that computes an `ActionsDAG` |
| `WithContext` | 349 | `src/Interpreters/Context_fwd.h` | Mixin storing a weak `ContextPtr`, gives `getContext` |
| `ColumnNode` | 347 | `src/Analyzer/ColumnNode.h` | Analyzer node for a resolved column |
| `InterpreterFactory` | 338 | `src/Interpreters/InterpreterFactory.h` | Picks the interpreter class for an AST |
| `IQueryPlanStep` | 335 | `src/Processors/QueryPlan/IQueryPlanStep.h` | Base of plan steps; `updatePipeline` adds processors |
| `IParser::Pos` | 328 | `src/Parsers/IParser.h` | Token iterator with depth/backtrack limits |
| `SortingStep` | 316 | `src/Processors/QueryPlan/SortingStep.h` | Plan step for `ORDER BY` |
| `IQueryTreeNode` | 309 | `src/Analyzer/IQueryTreeNode.h` | Base analyzer node: children, hash, `toAST` |
| `FilterStep` | 303 | `src/Processors/QueryPlan/FilterStep.h` | Plan step for `WHERE`/`HAVING` filter |
| `executeQuery` | 287 | `src/Interpreters/executeQuery.h` | Entry point: parse, interpret, return `BlockIO` |
| `TableNode` | 286 | `src/Analyzer/TableNode.h` | Analyzer node for a table in `FROM` |
| `ParserToken` | 274 | `src/Parsers/CommonParsers.h` | Parses one token type like `(` |
| `Planner` | 271 | `src/Planner/Planner.h` | Builds a `QueryPlan` from a query tree |
| `IdentifierResolveScope` | 237 | `src/Analyzer/Resolve/IdentifierResolveScope.h` | Scope for name lookup during analysis |
| `SelectQueryOptions` | 236 | `src/Interpreters/SelectQueryOptions.h` | Flags for how to interpret a `SELECT` |
| `ListNode` | 231 | `src/Analyzer/ListNode.h` | Analyzer node holding a list of nodes |
| `ITransformingStep` | 230 | `src/Processors/QueryPlan/ITransformingStep.h` | Plan step with one input and one output |
| `QueryPlanStepPtr` | 230 | `src/Processors/QueryPlan/IQueryPlanStep.h` | `unique_ptr<IQueryPlanStep>` |
| `PullingPipelineExecutor` | 224 | `src/Processors/Executors/PullingPipelineExecutor.h` | Runs a pipeline and lets you `pull` blocks |
| `AggregatingStep` | 217 | `src/Processors/QueryPlan/AggregatingStep.h` | Plan step for `GROUP BY` aggregation |
| `ISimpleTransform` | 217 | `src/Processors/ISimpleTransform.h` | One-in one-out processor; implement `transform(Chunk &)` |
| `ASTInsertQuery` | 214 | `src/Parsers/ASTInsertQuery.h` | AST of `INSERT` |
| `ServerSettings` | 198 | `src/Core/ServerSettings.h` | Server-wide settings from `config.xml` |
| `ExpressionActionsPtr` | 195 | `src/Interpreters/ExpressionActions.h` | `shared_ptr<ExpressionActions>` |
| `OutputPort` | 188 | `src/Processors/Port.h` | Port a processor pushes chunks into |
| `UnionNode` | 170 | `src/Analyzer/UnionNode.h` | Analyzer node for `UNION`/`INTERSECT`/`EXCEPT` |
| `BaseSettings` | 162 | `src/Core/BaseSettings.h` | Template base behind all settings collections |
| `ParserIdentifier` | 160 | `src/Parsers/ExpressionElementParsers.h` | Parses an identifier |
| `ASTTablesInSelectQuery` | 156 | `src/Parsers/ASTTablesInSelectQuery.h` | AST of `FROM` / `JOIN` part |
| `InterpreterSelectQuery` | 156 | `src/Interpreters/InterpreterSelectQuery.h` | Old-analyzer `SELECT` interpreter |
| `InterpreterSelectQueryAnalyzer` | 152 | `src/Interpreters/InterpreterSelectQueryAnalyzer.h` | `SELECT` interpreter using the new analyzer |
| `InterpreterCreateQuery` | 151 | `src/Interpreters/InterpreterCreateQuery.h` | Executes `CREATE` |
| `IInterpreter` | 146 | `src/Interpreters/IInterpreter.h` | Base interpreter: `execute` returns `BlockIO` |
| `SettingChange` | 145 | `src/Common/SettingsChanges.h` | One `name = Field` setting change |
| `InputPort` | 144 | `src/Processors/Port.h` | Port a processor pulls chunks from |
| `ASTAlterQuery` | 139 | `src/Parsers/ASTAlterQuery.h` | AST of `ALTER` with its commands |
| `JoinStep` | 139 | `src/Processors/QueryPlan/JoinStep.h` | Plan step joining two inputs |
| `JoinNode` | 138 | `src/Analyzer/JoinNode.h` | Analyzer node for a `JOIN` |
| `Pipes` | 123 | `src/QueryPipeline/Pipe.h` | `std::vector<Pipe>` |
| `ProcessorPtr` | 122 | `src/Processors/IProcessor.h` | `shared_ptr<IProcessor>` |
| `InDepthQueryTreeVisitorWithContext` | 119 | `src/Analyzer/InDepthQueryTreeVisitor.h` | Tree visitor with context; base of most passes |
| `PlannerContext` | 118 | `src/Planner/PlannerContext.h` | Shared state while planning: column identifiers, sets |
| `QueryAnalyzer` | 117 | `src/Analyzer/Resolve/QueryAnalyzer.h` | Resolves identifiers, functions, types in the tree |
| `Lexer` | 105 | `src/Parsers/Lexer.h` | Splits SQL text into tokens |
| `ISourceStep` | 104 | `src/Processors/QueryPlan/ISourceStep.h` | Plan step with no inputs (reading) |
| `PipelineExecutor` | 102 | `src/Processors/Executors/Runtime/PipelineExecutor.h` | Multi-threaded scheduler that runs processors |
| `InterpreterInsertQuery` | 101 | `src/Interpreters/InterpreterInsertQuery.h` | Executes `INSERT` |
| `IQueryTreePass` | 99 | `src/Analyzer/IQueryTreePass.h` | Base of a rewrite pass (98 files in `src/Analyzer/Passes`) |
| `CompletedPipelineExecutor` | 98 | `src/Processors/Executors/CompletedPipelineExecutor.h` | Runs a pipeline with no output to completion |
| `WithMutableContext` | 97 | `src/Interpreters/Context_fwd.h` | Mixin like `WithContext` but mutable |
| `InDepthQueryTreeVisitor` | 93 | `src/Analyzer/InDepthQueryTreeVisitor.h` | Generic recursive query-tree visitor |
| `IdentifierNode` | 80 | `src/Analyzer/IdentifierNode.h` | Unresolved identifier before analysis |
| `PushingPipelineExecutor` | 78 | `src/Processors/Executors/PushingPipelineExecutor.h` | Lets you `push` blocks into a pipeline (inserts) |
| `ParserExpression` | 77 | `src/Parsers/ExpressionListParsers.h` | Parses any expression with operators |
| `QueryPipelineBuilderPtr` | 69 | `src/QueryPipeline/QueryPipelineBuilder.h` | `unique_ptr<QueryPipelineBuilder>` |
| `ISink` | 58 | `src/Processors/ISink.h` | Processor consuming chunks; implement `consume` |
| `InterpreterAlterQuery` | 48 | `src/Interpreters/InterpreterAlterQuery.h` | Executes `ALTER` |
| `LambdaNode` | 47 | `src/Analyzer/LambdaNode.h` | Analyzer node for `x -> expr` |
| `IAccumulatingTransform` | 45 | `src/Processors/IAccumulatingTransform.h` | Consumes all input, then generates output |
| `ParserSelectQuery` | 32 | `src/Parsers/ParserSelectQuery.h` | Parser for one `SELECT` |
| `QueryTreePassManager` | 31 | `src/Analyzer/QueryTreePassManager.h` | Runs the ordered list of analyzer passes |
| `IInflatingTransform` | 21 | `src/Processors/IInflatingTransform.h` | One input chunk to many output chunks |

### 3.4 Storage

One line each: a part is an immutable directory of column files for a sorted range of rows, named like `all_1_5_2`; a merge combines small parts of a partition into a bigger one in the background; a mutation (`ALTER UPDATE/DELETE`) rewrites parts producing new versions. `IStorage` is the table interface, `MergeTreeData` is the shared engine core, `IDisk` hides where the bytes live.

| Name | Uses | Where (header) | What it is |
|---|---|---|---|
| `WriteBuffer` | 3878 | `src/IO/WriteBuffer.h` | Buffered output stream base, `next` flushes |
| `ReadBuffer` | 3874 | `src/IO/ReadBuffer.h` | Buffered input stream base, `next` refills |
| `MergeTreeData` | 1447 | `src/Storages/MergeTree/MergeTreeData.h` | Core of `MergeTree` engines: parts set, loading, merges |
| `DatabaseCatalog` | 1021 | `src/Interpreters/DatabaseCatalog.h` | Global registry of databases and tables |
| `StoragePtr` | 983 | `src/Storages/IStorage_fwd.h` | `shared_ptr<IStorage>` |
| `StorageMetadataPtr` | 796 | `src/Storages/StorageInMemoryMetadata.h` | Snapshot pointer to table metadata (columns, keys) |
| `WriteBufferFromOwnString` | 739 | `src/IO/WriteBufferFromString.h` | Write into an internal `String`, get via `str` |
| `IMergeTreeDataPart` | 655 | `src/Storages/MergeTree/IMergeTreeDataPart.h` | One data part: columns, checksums, index, marks |
| `ReadBufferFromString` | 632 | `src/IO/ReadBufferFromString.h` | Read from an in-memory string |
| `DiskObjectStorage` | 579 | `src/Disks/DiskObjectStorage/DiskObjectStorage.h` | Disk backed by S3/Azure/HDFS plus metadata |
| `StorageSnapshotPtr` | 578 | `src/Storages/StorageSnapshot.h` | Consistent view of metadata and parts for a query |
| `ReadSettings` | 573 | `src/IO/ReadSettings.h` | Options for reads: buffer size, cache, throttling |
| `DiskPtr` | 542 | `src/Disks/IDisk.h` | `shared_ptr<IDisk>` |
| `StoredObject` | 537 | `src/Disks/DiskObjectStorage/ObjectStorages/StoredObject.h` | One blob in object storage: remote path, size |
| `MergeTreePartInfo` | 534 | `src/Storages/MergeTree/MergeTreePartInfo.h` | Parsed part name: partition, min/max block, level |
| `StorageInMemoryMetadata` | 524 | `src/Storages/StorageInMemoryMetadata.h` | Columns, keys, TTLs, indices, projections of a table |
| `WriteBufferFromString` | 500 | `src/IO/WriteBufferFromString.h` | Write into a caller-provided `String` |
| `IStorage` | 469 | `src/Storages/IStorage.h` | Table interface: `read`, `write`, `alter`, `drop` |
| `KeyCondition` | 452 | `src/Storages/MergeTree/KeyCondition.h` | Evaluates filters on primary key ranges for pruning |
| `StorageReplicatedMergeTree` | 444 | `src/Storages/StorageReplicatedMergeTree.h` | `ReplicatedMergeTree`: replication via Keeper log |
| `IStorageSystemOneBlock` | 420 | `src/Storages/System/IStorageSystemOneBlock.h` | Base for simple `system.*` tables |
| `ReadBufferFromFileBase` | 397 | `src/IO/ReadBufferFromFileBase.h` | Seekable file read buffer base |
| `ObjectStoragePtr` | 363 | `src/Disks/DiskObjectStorage/ObjectStorages/IObjectStorage.h` | `shared_ptr<IObjectStorage>` |
| `StorageFactory` | 361 | `src/Storages/StorageFactory.h` | Registry mapping `ENGINE = X` to constructors |
| `MarkRanges` | 342 | `src/Storages/MergeTree/MarkRange.h` | Ranges of granules (marks) to read from a part |
| `WriteSettings` | 340 | `src/IO/WriteSettings.h` | Options for writes: cache, throttling |
| `FileSegment` | 335 | `src/Interpreters/FileCache/FileSegment.h` | Cached byte range of a remote file |
| `IDisk` | 321 | `src/Disks/IDisk.h` | Filesystem-like interface over local or remote storage |
| `DataPartsVector` | 315 | `src/Storages/MergeTree/MergeTreeData.h` | `std::vector<DataPartPtr>` |
| `MutationCommand` | 270 | `src/Storages/MutationCommands.h` | One `UPDATE`/`DELETE`/`MATERIALIZE` command |
| `VirtualColumnsDescription` | 269 | `src/Storages/VirtualColumnsDescription.h` | Virtual columns like `_part`, `_path` |
| `DataPartPtr` | 263 | `src/Storages/MergeTree/MergeTreeData.h` | `shared_ptr<const IMergeTreeDataPart>` |
| `DiskLocal` | 252 | `src/Disks/DiskLocal.h` | `IDisk` on the local filesystem |
| `SeekableReadBuffer` | 249 | `src/IO/SeekableReadBuffer.h` | `ReadBuffer` supporting `seek` |
| `IDatabase` | 245 | `src/Databases/IDatabase.h` | Database interface: list, attach, create tables |
| `DatabaseReplicated` | 232 | `src/Databases/DatabaseReplicated.h` | Database replicating DDL through Keeper |
| `WriteBufferFromFileBase` | 233 | `src/IO/WriteBufferFromFileBase.h` | File write buffer base |
| `MutationCommands` | 226 | `src/Storages/MutationCommands.h` | Vector of `MutationCommand` |
| `CompressionCodecPtr` | 206 | `src/Compression/ICompressionCodec.h` | `shared_ptr<ICompressionCodec>` |
| `StorageMergeTree` | 193 | `src/Storages/StorageMergeTree.h` | Non-replicated `MergeTree` engine |
| `IDataPartStorage` | 186 | `src/Storages/MergeTree/IDataPartStorage.h` | File access for one part, independent of disk |
| `CompressionCodecFactory` | 177 | `src/Compression/CompressionFactory.h` | Creates codecs from `CODEC(...)` AST or method byte |
| `StorageDistributed` | 169 | `src/Storages/StorageDistributed.h` | `Distributed` engine: fans queries to shards |
| `IObjectStorage` | 168 | `src/Disks/DiskObjectStorage/ObjectStorages/IObjectStorage.h` | Blob store interface: S3, Azure, local |
| `ReplicatedMergeTreeQueue` | 154 | `src/Storages/MergeTree/ReplicatedMergeTreeQueue.h` | Replica's queue of fetch/merge/mutate entries |
| `DatabasePtr` | 142 | `src/Databases/IDatabase.h` | `shared_ptr<IDatabase>` |
| `MutableDataPartPtr` | 134 | `src/Storages/MergeTree/MergeTreeData.h` | Pointer to a part still being written |
| `StorageMaterializedView` | 124 | `src/Storages/StorageMaterializedView.h` | Materialized view: insert trigger plus target table |
| `MergeTreeDataPartState` | 124 | `src/Storages/MergeTree/MergeTreeDataPartState.h` | Enum: `Temporary`, `PreActive`, `Active`, `Outdated`, ... |
| `MergeTreeReadTask` | 123 | `src/Storages/MergeTree/MergeTreeReadTask.h` | Unit of reading: a part plus mark ranges |
| `ICompressionCodec` | 120 | `src/Compression/ICompressionCodec.h` | Codec interface: `compress`/`decompress` |
| `StorageSnapshot` | 120 | `src/Storages/StorageSnapshot.h` | See `StorageSnapshotPtr` |
| `CompressedWriteBuffer` | 114 | `src/Compression/CompressedWriteBuffer.h` | Compresses data written through it in blocks |
| `StorageView` | 113 | `src/Storages/StorageView.h` | Plain `VIEW`: stored query |
| `DatabaseAtomic` | 109 | `src/Databases/DatabaseAtomic.h` | Default database engine; UUID paths, atomic rename |
| `CompressedReadBuffer` | 107 | `src/Compression/CompressedReadBuffer.h` | Decompresses and checks checksums while reading |
| `MergeTreeIndexPtr` | 81 | `src/Storages/MergeTree/MergeTreeIndices.h` | Pointer to a skip index (`minmax`, `bloom_filter`) |
| `StoragePolicyPtr` | 74 | `src/Storages/IStorage_fwd.h` | Volumes and move rules for a table's disks |
| `StorageMemory` | 68 | `src/Storages/StorageMemory.h` | `Memory` engine: blocks kept in RAM |
| `IMergeTreeIndex` | 50 | `src/Storages/MergeTree/MergeTreeIndices.h` | Data skipping index interface |
| `MergeTreeMutationEntry` | 45 | `src/Storages/MergeTree/MergeTreeMutationEntry.h` | Persisted mutation record for `StorageMergeTree` |
| `MergeTreeDataMergerMutator` | 43 | `src/Storages/MergeTree/MergeTreeDataMergerMutator.h` | Selects parts to merge, creates merge/mutate tasks |
| `IVolume` | 42 | `src/Disks/IVolume.h` | Group of disks in a storage policy |
| `MergeTreeSink` | 30 | `src/Storages/MergeTree/MergeTreeSink.h` | Sink writing inserted blocks as new parts |

### 3.5 Functions

Registration pattern: each function lives in its own `.cpp` in `src/Functions/`, ends with `REGISTER_FUNCTION(Name) { FunctionDocumentation documentation = {...}; factory.registerFunction<FunctionName>(documentation); }` (see `src/Functions/plus.cpp`). `REGISTER_FUNCTION` (in `src/Common/register_objects.h`) generates a `registerFunctionName` that runs at startup. `FunctionDocumentation` (description, syntax, arguments, returned value, examples, `introduced_in`, category) is the source of truth for the generated function reference in `docs/`. A simple function derives from `IFunction` and implements `getName`, `getNumberOfArguments`, `getReturnTypeImpl`, `executeImpl`; aggregate functions derive from `IAggregateFunctionDataHelper` and register in `AggregateFunctionFactory`. Combinators (suffixes) wrap any aggregate function: `-If`, `-Array`, `-State`, `-Merge`, `-Distinct`, `-ForEach`, `-OrNull`/`-OrDefault`, `-Resample`, `-SimpleState`, `-Null` (see `src/AggregateFunctions/Combinators/`).

| Name | Uses | Where (header) | What it is |
|---|---|---|---|
| `FunctionDocumentation` | 14417 | `src/Common/FunctionDocumentation.h` | Structured docs for a function; generates reference pages |
| `FunctionFactory` | 1547 | `src/Functions/FunctionFactory.h` | Registry of SQL functions by name, case-insensitive aliases |
| `IFunction` | 1109 | `src/Functions/IFunction.h` | Easiest base for a regular function |
| `AggregateDataPtr` | 969 | `src/AggregateFunctions/IAggregateFunction_fwd.h` | `char *` to an aggregation state in an `Arena` |
| `FormatFactory` | 924 | `src/Formats/FormatFactory.h` | Registry of input/output formats (`CSV`, `Parquet`, ...) |
| `AggregateFunctionFactory` | 691 | `src/AggregateFunctions/AggregateFunctionFactory.h` | Registry of aggregate functions, applies combinators |
| `FunctionPtr` | 657 | `src/Functions/IFunction.h` | `shared_ptr<IFunction>` |
| `AggregateFunctionPtr` | 464 | `src/AggregateFunctions/IAggregateFunction_fwd.h` | `shared_ptr<const IAggregateFunction>` |
| `IAggregateFunction` | 287 | `src/AggregateFunctions/IAggregateFunction.h` | Aggregate interface: `add`, `merge`, `serialize`, `insertResultInto` |
| `FunctionOverloadResolverPtr` | 287 | `src/Functions/IFunction.h` | Pointer to a resolver that picks overload by arg types |
| `ConstAggregateDataPtr` | 275 | `src/AggregateFunctions/IAggregateFunction_fwd.h` | `const char *` to an aggregation state |
| `TableFunctionFactory` | 257 | `src/TableFunctions/TableFunctionFactory.h` | Registry of table functions (`s3`, `numbers`) |
| `FunctionArgumentDescriptors` | 250 | `src/Functions/FunctionHelpers.h` | Declarative argument type checks |
| `IAggregateFunctionDataHelper` | 181 | `src/AggregateFunctions/IAggregateFunction.h` | CRTP base binding a state struct to an aggregate |
| `IOutputFormat` | 165 | `src/Processors/Formats/IOutputFormat.h` | Processor writing chunks in a format |
| `validateFunctionArguments` | 164 | `src/Functions/FunctionHelpers.h` | Checks args against `FunctionArgumentDescriptors` |
| `IInputFormat` | 151 | `src/Processors/Formats/IInputFormat.h` | Source parsing a format into chunks |
| `FunctionBasePtr` | 128 | `src/Functions/IFunction.h` | Pointer to function bound to concrete argument types |
| `IFunctionBase` | 127 | `src/Functions/IFunction.h` | Function with resolved types; gives executable, monotonicity |
| `IRowInputFormat` | 122 | `src/Processors/Formats/IRowInputFormat.h` | Base for row-by-row text formats |
| `IFunctionOverloadResolver` | 120 | `src/Functions/IFunction.h` | Builds `IFunctionBase` from argument types |
| `ITableFunction` | 117 | `src/TableFunctions/ITableFunction.h` | Table function interface: returns a temporary `IStorage` |
| `AggregateFunctionCombinatorFactory` | 82 | `src/AggregateFunctions/Combinators/AggregateFunctionCombinatorFactory.h` | Registry of combinator suffixes |
| `IExecutableFunction` | 52 | `src/Functions/IFunction.h` | Executes on columns; handles constants/nulls defaults |
| `IAggregateFunctionHelper` | 39 | `src/AggregateFunctions/IAggregateFunction.h` | CRTP base providing batch `add` loops |
| `IAggregateFunctionCombinator` | 17 | `src/AggregateFunctions/Combinators/IAggregateFunctionCombinator.h` | Transforms a nested aggregate into a new one |

### 3.6 Infrastructure

Error handling uses `throw Exception(ErrorCodes::X, "fmt {}", arg)` with codes declared via `namespace ErrorCodes { extern const int X; }` (defined in `src/Common/ErrorCodes.cpp`). `ProfileEvents::increment(ProfileEvents::X)` counts events per query and server; `CurrentMetrics::Increment` tracks a current gauge value. Both lists are defined by `APPLY_FOR_BUILTIN_EVENTS`/`APPLY_FOR_BUILTIN_METRICS` in `src/Common/ProfileEvents.cpp` and `src/Common/CurrentMetrics.cpp`. Failpoints are listed in `APPLY_FOR_FAILPOINTS` in `src/Common/FailPoint.cpp`, injected with `fiu_do_on` or `FailPointInjection::pauseFailPoint`, and toggled in tests with `SYSTEM ENABLE FAILPOINT`.

| Name | Uses | Where (header) | What it is |
|---|---|---|---|
| `String` | 43074 | `base/base/types.h` | Alias for `std::string` |
| `ErrorCodes` | 22910 | `src/Common/ErrorCodes.h` | Namespace of numeric error codes |
| `Exception` | 22180 | `src/Common/Exception.h` | ClickHouse exception with code and stack trace |
| `UInt64` | 17830 | `base/base/types.h` | `uint64_t` |
| `UInt32` | 8150 | `base/base/types.h` | `uint32_t` |
| `Int64` | 6982 | `base/base/types.h` | `int64_t` |
| `UInt8` | 6862 | `base/base/types.h` | `uint8_t`, also `Bool` storage |
| `Float64` | 5619 | `base/base/types.h` | `double` |
| `ProfileEvents` | 4996 | `src/Common/ProfileEvents.h` | Namespace of event counters for `system.events` |
| `typeid_cast` | 3988 | `src/Common/typeid_cast.h` | Exact-type cast via `typeid`, throws or null |
| `assert_cast` | 3981 | `src/Common/assert_cast.h` | `static_cast` checked by `typeid` in debug builds |
| `UUID` | 2975 | `base/base/UUID.h` | Strong typedef over `UInt128` |
| `Int32` | 2970 | `base/base/types.h` | `int32_t` |
| `UInt16` | 2471 | `base/base/types.h` | `uint16_t` |
| `VectorWithMemoryTracking` | 2364 | `src/Common/VectorWithMemoryTracking.h` | `std::vector` whose allocations hit `MemoryTracker` |
| `CurrentMetrics` | 2125 | `src/Common/CurrentMetrics.h` | Namespace of gauges for `system.metrics` |
| `ZooKeeper` | 1888 | `src/Common/ZooKeeper/ZooKeeper.h` | Keeper/ZooKeeper client (`zkutil::ZooKeeper`) |
| `Names` | 1888 | `src/Core/Names.h` | `std::vector<std::string>` of column names |
| `Int8` | 1757 | `base/base/types.h` | `int8_t` |
| `zkutil` | 1703 | `src/Common/ZooKeeper/ZooKeeper.h` | Namespace with the synchronous ZooKeeper wrapper |
| `Strings` | 1646 | `src/Core/Types.h` | `std::vector<String>` |
| `Float32` | 1591 | `base/base/types.h` | `float` |
| `PaddedPODArray` | 1471 | `src/Common/PODArray_fwd.h` | `PODArray` with padding for SIMD over-reads |
| `AbstractConfiguration` | 1450 | `base/poco/Util/include/Poco/Util/AbstractConfiguration.h` | Poco config tree from `config.xml` |
| `Arena` | 1376 | `src/Common/Arena.h` | Bump allocator; freed all at once |
| `UInt128` | 1269 | `base/base/extended_types.h` | 128-bit unsigned wide integer |
| `DateLUTImpl` | 1266 | `src/Common/DateLUTImpl.h` | Precomputed calendar lookups for one time zone |
| `Coordination::Error` | 1212 | `src/Common/ZooKeeper/IKeeper.h` | Keeper result codes: `ZOK`, `ZNONODE`, ... |
| `checkAndGetColumn` | 1088 | `src/Columns/IColumn.h` | Cast `IColumn` to concrete type or null |
| `LoggerPtr` | 1072 | `src/Common/Logger.h` | `shared_ptr` to a Poco logger, used by `LOG_*` |
| `Int16` | 1063 | `base/base/types.h` | `int16_t` |
| `NameSet` | 1063 | `src/Core/Names.h` | `std::unordered_set<std::string>` |
| `SipHash` | 960 | `src/Common/SipHash.h` | SipHash-2-4 hasher; `update` then `get128` |
| `CurrentThread` | 945 | `src/Common/CurrentThread.h` | Static access to this thread's `ThreadStatus`, query id |
| `Int128` | 821 | `base/base/extended_types.h` | 128-bit signed wide integer |
| `Stopwatch` | 806 | `src/Common/Stopwatch.h` | Monotonic timer: `elapsedSeconds`, `elapsedMilliseconds` |
| `Decimal64` | 750 | `base/base/Decimal.h` | Decimal backed by `Int64` |
| `IPv6` | 717 | `base/base/IPv4andIPv6.h` | Strong type over `UInt128` |
| `UInt256` | 692 | `base/base/extended_types.h` | 256-bit unsigned wide integer |
| `IPv4` | 652 | `base/base/IPv4andIPv6.h` | Strong type over `UInt32` |
| `Int256` | 648 | `base/base/extended_types.h` | 256-bit signed wide integer |
| `ThreadPool` | 567 | `src/Common/ThreadPool.h` | Fixed-size pool of `ThreadFromGlobalPool` workers |
| `BFloat16` | 536 | `base/base/BFloat16.h` | 16-bit brain float |
| `Decimal256` | 530 | `base/base/Decimal.h` | Decimal backed by `Int256` |
| `PODArray` | 517 | `src/Common/PODArray.h` | `std::vector`-like array for POD, no init, tracked |
| `Decimal128` | 513 | `base/base/Decimal.h` | Decimal backed by `Int128` |
| `Decimal32` | 485 | `base/base/Decimal.h` | Decimal backed by `Int32` |
| `DateLUT` | 422 | `src/Common/DateLUT.h` | Gets `DateLUTImpl` for server or named time zone |
| `ErrnoException` | 419 | `src/Common/ErrnoException.h` | `Exception` carrying `errno` text |
| `MemoryTracker` | 416 | `src/Common/MemoryTracker.h` | Hierarchical memory accounting and limits |
| `isColumnConst` | 410 | `src/Columns/IColumn.h` | True if column is `ColumnConst` |
| `checkAndGetDataType` | 383 | `src/Functions/FunctionHelpers.h` | Cast `IDataType` to concrete type or null |
| `HashTable` | 375 | `src/Common/HashTable/HashTable.h` | Open-addressing hash table core used by aggregation |
| `ZooKeeperPtr` | 369 | `src/Common/ZooKeeper/ZooKeeper.h` | `shared_ptr<zkutil::ZooKeeper>` |
| `UnorderedMapWithMemoryTracking` | 334 | `src/Common/UnorderedMapWithMemoryTracking.h` | `std::unordered_map` tracked by `MemoryTracker` |
| `HashMap` | 332 | `src/Common/HashTable/HashMap.h` | Fast open-addressing map for aggregation keys |
| `ThreadStatus` | 322 | `src/Common/ThreadStatus.h` | Per-thread query state, counters, memory tracker |
| `DayNum` | 274 | `base/base/DayNum.h` | Strong type: days since 1970-01-01 (`UInt16`) |
| `SharedMutex` | 263 | `src/Common/SharedMutex.h` | Fast reader-writer mutex with TSA annotations |
| `SharedLockGuard` | 262 | `src/Common/SharedLockGuard.h` | Shared (read) lock RAII guard with TSA support |
| `checkAndGetColumnConst` | 260 | `src/Functions/FunctionHelpers.h` | Returns `ColumnConst` if it wraps given type |
| `AsyncLoader` | 248 | `src/Common/AsyncLoader.h` | Dependency-aware async job scheduler for startup |
| `fiu_do_on` | 237 | `src/Common/FailPoint.h` | Runs code when a failpoint is enabled |
| `FailPointInjection` | 225 | `src/Common/FailPoint.h` | Enable/disable/pause named failpoints |
| `ExtendedDayNum` | 220 | `base/base/DayNum.h` | Signed day number for `Date32` |
| `KeeperException` | 210 | `src/Common/ZooKeeper/KeeperException.h` | Exception carrying a `Coordination::Error` |
| `FailPoints` | 166 | `src/Common/FailPoint.cpp` | Namespace of failpoint names |
| `ThreadFromGlobalPool` | 163 | `src/Common/ThreadPool.h` | `std::thread`-like object running in global pool |
| `BackgroundSchedulePoolTaskHolder` | 154 | `src/Core/BackgroundSchedulePoolTaskHolder.h` | RAII handle for a scheduled background task |
| `BackgroundSchedulePool` | 142 | `src/Core/BackgroundSchedulePool.h` | Pool running re-schedulable tasks (`schedule`, `scheduleAfter`) |
| `NameToNameMap` | 137 | `src/Core/Names.h` | `std::unordered_map<String, String>` for renames |
| `HashSet` | 130 | `src/Common/HashTable/HashSet.h` | Open-addressing set, e.g. for `uniqExact` |
| `PackedStringRef` | 95 | `base/base/PackedStringRef.h` | Compact pointer+size string key for hash tables |
| `sipHash64` | 78 | `src/Common/SipHash.h` | One-shot 64-bit SipHash of bytes |
| `GlobalThreadPool` | 55 | `src/Common/ThreadPool.h` | Singleton pool backing all `ThreadFromGlobalPool`s |
| `sipHash128` | 34 | `src/Common/SipHash.h` | One-shot 128-bit SipHash |
| `HashMapWithSavedHash` | 29 | `src/Common/HashTable/HashMap.h` | `HashMap` storing each key's hash |
| `AtomicStopwatch` | 25 | `src/Common/Stopwatch.h` | Thread-safe `Stopwatch` |
| `ClearableHashSet` | 20 | `src/Common/HashTable/ClearableHashSet.h` | Set with O(1) `clear` via versioning |
| `StringHashMap` | 20 | `src/Common/HashTable/StringHashMap.h` | Map specialized for string keys by length |
| `StringRef` | 17 | (removed) | Old pointer+size string; now `std::string_view` |
| `TwoLevelHashMap` | 16 | `src/Common/HashTable/TwoLevelHashMap.h` | 256 sub-tables; enables parallel merge of aggregation |
| `ArenaWithFreeLists` | 15 | `src/Common/ArenaWithFreeLists.h` | `Arena` that can reuse freed chunks |

Other frequently met domain classes:

| Name | Uses | Where (header) | What it is |
|---|---|---|---|
| `AccessType` | 1579 | `src/Access/Common/AccessType.h` | Enum of grantable privileges (`SELECT`, `INSERT`, ...) |
| `AccessFlags` | 660 | `src/Access/Common/AccessFlags.h` | Bitset of `AccessType`s |
| `HashJoin` | 524 | `src/Interpreters/HashJoin/HashJoin.h` | In-memory hash join implementation |
| `Aggregator` | 451 | `src/Interpreters/Aggregator.h` | Runs `GROUP BY` over hash-table variants |
| `ClientInfo` | 432 | `src/Interpreters/ClientInfo.h` | Who sent the query: address, interface, user |
| `KeeperStorage` | 411 | `src/Coordination/KeeperStorage.h` | Keeper's in-memory node tree and sessions |
| `Cluster` | 319 | `src/Interpreters/Cluster.h` | Shards and replicas from `remote_servers` config |
| `AccessRights` | 313 | `src/Access/AccessRights.h` | Tree of granted privileges |
| `TableJoin` | 304 | `src/Interpreters/TableJoin.h` | Join description: kind, keys, algorithm settings |
| `ContextAccess` | 241 | `src/Access/ContextAccess.h` | Current user's effective rights; `checkAccess` |
| `DictionaryStructure` | 239 | `src/Dictionaries/DictionaryStructure.h` | Keys and attributes of a dictionary |
| `ProcessList` | 210 | `src/Interpreters/ProcessList.h` | Running queries (`system.processes`) |
| `IServer` | 187 | `src/Server/IServer.h` | Server interface given to protocol handlers |
| `IAccessStorage` | 131 | `src/Access/IAccessStorage.h` | Storage of users/roles (disk, XML, replicated) |
| `QueryStatus` | 129 | `src/Interpreters/ProcessList.h` | One running query entry; cancellation, progress |
| `TCPHandler` | 125 | `src/Server/TCPHandler.h` | Native protocol server connection handler |
| `ClientBase` | 123 | `src/Client/ClientBase.h` | Shared core of `clickhouse-client` and `-local` |
| `ThreadGroup` | 104 | `src/Common/ThreadStatus.h` | Threads of one query sharing counters and memory |
| `IDictionary` | 101 | `src/Dictionaries/IDictionary.h` | Dictionary interface: `getColumn`, `hasKeys` |
| `IBackup` | 98 | `src/Backups/IBackup.h` | A backup being written or read |
| `IJoin` | 97 | `src/Interpreters/IJoin.h` | Join algorithm interface |
| `KeeperServer` | 97 | `src/Coordination/KeeperServer.h` | Keeper Raft server wrapper around NuRaft |
| `IKeeper` | 74 | `src/Common/ZooKeeper/IKeeper.h` | Async Keeper client interface |
| `HTTPHandler` | 53 | `src/Server/HTTPHandler.h` | HTTP interface query handler |

TSA (Clang thread-safety analysis) macros live in `base/base/defines.h`:

| Name | Uses | Where (header) | What it is |
|---|---|---|---|
| `TSA_GUARDED_BY` | 647 | `base/base/defines.h` | Member may only be touched with this mutex held |
| `TSA_REQUIRES` | 293 | `base/base/defines.h` | Function must be called with the mutex held |
| `TSA_NO_THREAD_SAFETY_ANALYSIS` | 103 | `base/base/defines.h` | Disable analysis for one function |
| `TSA_SUPPRESS_WARNING_FOR_READ` | 21 | `base/base/defines.h` | Allow one unguarded read, deliberately |
| `TSA_RELEASE` | 16 | `base/base/defines.h` | Function releases the capability |
| `TSA_SUPPRESS_WARNING_FOR_WRITE` | 16 | `base/base/defines.h` | Allow one unguarded write, deliberately |
| `TSA_ACQUIRE` | 13 | `base/base/defines.h` | Function acquires the capability |
| `TSA_ACQUIRE_SHARED` | 10 | `base/base/defines.h` | Function acquires shared (read) capability |
| `TSA_SCOPED_LOCKABLE` | 8 | `base/base/defines.h` | Marks an RAII lock guard class |
| `TSA_CAPABILITY` | 7 | `base/base/defines.h` | Marks a class as a lockable mutex |

### 3.7 Most-called functions and methods

Counts are call-site matches (`name(`) from the call statistics, so generic names mix many classes; "What it is" gives the ClickHouse meaning you will usually meet.

| Name | Uses | Where (header) | What it is |
|---|---|---|---|
| `size` | 28004 | `IColumn`, containers | Number of rows in a column, or elements |
| `empty` | 13111 | `IColumn`, `Block`, containers | True if no rows / no elements |
| `get` | 11772 | smart pointers, `Field`, ZooKeeper | Raw pointer, `Field::safeGet` value, or znode read |
| `push_back` | 10518 | `PODArray`, std | Append one element |
| `getName` | 7904 | `IDataType`, `IFunction`, `IStorage`, `IProcessor` | Human-readable name like `"Nullable(String)"` |
| `data` | 7079 | `PODArray`, `ColumnVector::getData` | Raw pointer to contiguous values |
| `insert` | 6692 | `IColumn` | Append a `Field` to a column (slow path) |
| `emplace_back` | 5622 | containers | Construct element in place at end |
| `create` | 5274 | `COW` columns, `ColumnX::create` | Factory making a new `MutableColumnPtr` |
| `chassert` | 4582 | `base/base/defines.h` | Assert in debug/sanitizer builds; aborts on failure |
| `lock` | 3457 | mutexes, `weak_ptr` | Acquire mutex, or upgrade weak context pointer |
| `getData` | 3430 | `ColumnVector`, `ColumnString` | Reference to the underlying `PaddedPODArray` |
| `contains` | 3324 | containers | Key/element present check |
| `reserve` | 3323 | `IColumn`, containers | Pre-allocate for N rows |
| `format` | 3192 | `fmt`, `IAST::format` | Build strings / print AST back to SQL |
| `instance` | 3059 | factories | Singleton access, e.g. `FunctionFactory::instance` |
| `toString` | 2925 | `Common/`, `Field`, enums | Convert value or enum to `String` |
| `getContext` | 2634 | `WithContext` | Return the owned `ContextPtr` |
| `clone` | 2213 | `IAST`, `IColumn`, settings | Deep copy (AST) or copy column |
| `resize` | 2161 | `PODArray`, `IColumn` | Change element count |
| `getSettingsRef` | 2053 | `Context` | `const Settings &` of current query |
| `parse` | 1944 | `IParser`, helpers | Parse text into AST or value |
| `has` | 1860 | `Block`, config, containers | Existence check (column name, config key) |
| `path` | 1829 | disks, ZooKeeper | File or znode path |
| `update` | 1785 | `SipHash`, `IQueryTreeNode` hashing | Feed bytes into a hash |
| `ignore` | 1782 | `ReadBuffer` | Skip N bytes of input |
| `reset` | 1771 | pointers, states | Release/clear |
| `write` | 1768 | `WriteBuffer`, `IStorage::write` | Write bytes, or get an insert sink |
| `execute` | 1767 | `IInterpreter`, `ExpressionActions`, `IExecutableFunction` | Run interpreter/expression/function |
| `load` | 1653 | `std::atomic`, loaders | Atomic read or load metadata |
| `position` | 1578 | `ReadBuffer`/`WriteBuffer` | Current byte pointer in the buffer |
| `increment` | 1469 | `ProfileEvents` | Bump a profile event counter |
| `getLogger` | 1431 | `src/Common/Logger.h` | Get a named `LoggerPtr` |
| `getType` | 1430 | `Field`, AST nodes | Type tag (`Field::Types::Which`) |
| `read` | 1417 | `IStorage`, `ReadBuffer`, `IDisk` | Start reading a table, or read bytes |
| `getString` | 1236 | `AbstractConfiguration` | Read string from `config.xml` |
| `makeASTFunction` | 1149 | `src/Parsers/ASTFunction.h` | Build `ASTFunction` with given name and args |
| `finalize` | 1146 | `WriteBuffer` | Flush and complete; must be called before destruction |
| `getOffsets` | 1099 | `ColumnArray`, `ColumnString` | Reference to offsets array |
| `fuzz_rand` | 1047 | `src/Common/QueryFuzzer.h` | RNG used by the query fuzzers |
| `visit` | 1055 | AST/query-tree visitors | Visit a node in a visitor pass |
| `next` | 1021 | `ReadBuffer`/`WriteBuffer` | Refill or flush the working buffer |
| `eof` | 953 | `ReadBuffer` | True when no more input |
| `getColumns` | 937 | `Chunk`, `Block`, `StorageInMemoryMetadata` | Columns of chunk/block, or table columns description |
| `executeImpl` | 908 | `IFunction` | Main function body over `ColumnsWithTypeAndName` |
| `exists` | 895 | `IDisk`, ZooKeeper | File or znode exists |
| `tryLogCurrentException` | 858 | `src/Common/Exception.h` | Log the in-flight exception without rethrowing |
| `writeChar` | 851 | `src/IO/WriteHelpers.h` | Write one character to a `WriteBuffer` |
| `createColumn` | 838 | `IDataType` | Make empty column of this type |
| `getNodes` | 774 | `ActionsDAG` | All DAG nodes |
| `writeString` | 773 | `src/IO/WriteHelpers.h` | Write string bytes to a `WriteBuffer` |
| `merge` | 763 | `IAggregateFunction` | Combine two aggregation states |
| `getStorageID` | 754 | `IStorage` | Table's `StorageID` |
| `rows` | 744 | `Block` | Row count of a block |
| `serialize` | 724 | `IAggregateFunction`, `ISerialization` | Write state/value in binary |
| `insertDefault` | 699 | `IColumn` | Append a default value (0, empty string) |
| `getReturnTypeImpl` | 684 | `IFunction` | Compute result type from argument types |
| `getDataAt` | 674 | `IColumn` | Row as `std::string_view` of bytes |
| `deserialize` | 653 | `IAggregateFunction`, `ISerialization` | Read state/value from binary |
| `getOutputs` | 648 | `ActionsDAG` | DAG output nodes |
| `getSettings` | 643 | storages, `MergeTreeData` | Table-level settings pointer |
| `getNumberOfArguments` | 640 | `IFunction` | Fixed argument count; 0 means variadic |
| `getNestedType` | 639 | `DataTypeNullable`, `DataTypeArray` | Inner type of wrapper type |
| `isNull` | 634 | `Field`, `IColumn` | Value or row is NULL |
| `getBool` | 610 | `AbstractConfiguration` | Read boolean config value |
| `getResultType` | 609 | `IFunctionBase`, `IAggregateFunction` | Result `DataTypePtr` |
| `getHeader` | 594 | ports, formats, steps | Header `Block` (names and types, zero rows) |
| `insertData` | 590 | `IColumn` | Append a row from raw bytes |
| `removeNullable` | 576 | `src/DataTypes/DataTypeNullable.h` | Strip `Nullable` from a type |
| `getChars` | 576 | `ColumnString`, `ColumnFixedString` | Reference to character buffer |
| `isSuitableForShortCircuitArgumentsExecution` | 568 | `IFunction` | Whether lazy argument evaluation is safe |
| `getNestedColumn` | 561 | `ColumnNullable`, `ColumnArray` | Inner column of wrapper column |
| `insertValue` | 553 | `ColumnVector` | Typed fast append |
| `getInMemoryMetadataPtr` | 369 | `IStorage` | Current `StorageMetadataPtr` |
| `getNumRows` | 515 | `Chunk` | Row count of a chunk |
| `getByName` | 511 | `Block` | Column by name, throws if missing |
| `writeVarUInt` | 504 | `src/IO/VarInt.h` | Write LEB128 varint |
| `getArguments` | 488 | `FunctionNode`, `ASTFunction` | Argument list node |
| `getByPosition` | 476 | `Block` | Column by index |
| `writeBinary` | 466 | `src/IO/WriteHelpers.h` | Write value in native binary layout |
| `backQuoteIfNeed` | 464 | `src/Common/quoteString.h` | Quote identifier with backticks when necessary |
| `isGranted` | 458 | `ContextAccess`, `AccessRights` | Privilege check without throwing |
| `convertToFullColumnIfConst` | 448 | `IColumn` | Materialize `ColumnConst` into a real column |
| `cloneEmpty` | 428 | `IColumn`, `Block` | Same type, zero rows |
| `useDefaultImplementationForConstants` | 425 | `IFunction` | Auto-handle all-constant arguments |
| `readVarUInt` | 419 | `src/IO/VarInt.h` | Read LEB128 varint |
| `getDataPartStorage` | 393 | `IMergeTreeDataPart` | Part's `IDataPartStorage` |
| `getHash` | 380 | `IQueryTreeNode`, `SipHash` | Tree/structure hash |
| `getDisk` | 378 | storages, parts | Disk holding data |
| `getCurrentExceptionMessage` | 374 | `src/Common/Exception.h` | Text of in-flight exception |
| `parseQuery` | 362 | `src/Parsers/parseQuery.h` | Parse SQL string with a given parser |
| `getColumnsDescription` | 351 | `ColumnsDescription` users | Table columns description |
| `addStep` | 349 | `QueryPlan` | Append a plan step on top |
| `setCurrentComponent` | 340 | `src/Common/ZooKeeper/ZooKeeperCommon.h` | Tag Keeper requests with calling component |
| `insertFrom` | 333 | `IColumn` | Append row N of another column |
| `getOutputHeader` | 333 | `IQueryPlanStep` | Header produced by a plan step |
| `checkAccess` | 327 | `Context`, `ContextAccess` | Throw if user lacks privilege |
| `formatASTForErrorMessage` | 296 | `src/Parsers/IAST.h` | Short AST text for exceptions |
| `getZooKeeper` | 294 | `Context`, replicated storages | Current `ZooKeeperPtr` session |
| `getSampleBlock` | 294 | `StorageInMemoryMetadata` | Header `Block` of table columns |
| `createColumnConst` | 290 | `IDataType` | Make `ColumnConst` of N rows from `Field` |
| `skipWhitespaceIfAny` | 291 | `src/IO/ReadHelpers.h` | Skip whitespace in `ReadBuffer` |
| `registerFunction` | 398 | `FunctionFactory` | Register a function class under its name |
| `getTypeId` | 301 | `IDataType` | `TypeIndex` of a type |
| `isDeterministic` | 309 | `IFunction` | Same inputs always give same outputs |

### 3.8 Macros

`LOG_*` logging macros are covered in the logging section. Upper-case SQL words (`SELECT`, `FROM`, `WHERE`) and gtest macros (`EXPECT_EQ`, `TEST`) that the raw statistics also catch are left out.

| Name | Uses | Where (header) | What it is |
|---|---|---|---|
| `LOGICAL_ERROR` | 5253 | `src/Common/ErrorCodes.cpp` | Error code for "impossible" states; aborts in debug builds |
| `chassert` | 4622 | `base/base/defines.h` | Debug/sanitizer assertion; no-op in release |
| `DECLARE` | 3039 | `src/Core/Settings.cpp` etc. | Declares one setting in a settings list |
| `DOCS_MD` | 1216 | raw-string delimiter | `R"DOCS_MD(...)DOCS_MD"` for Markdown docs strings |
| `ALWAYS_INLINE` | 872 | `base/base/defines.h` | Force inlining |
| `REGISTER_FUNCTION` | 831 | `src/Common/register_objects.h` | Defines a function registration hook |
| `unlikely` | 753 | `base/base/defines.h` | Branch hint: condition is rarely true |
| `MR_MACROS` | 664 | `src/Parsers/CommonParsers.h` | Callback param of `APPLY_FOR_PARSER_KEYWORDS` keyword list |
| `TSA_GUARDED_BY` | 647 | `base/base/defines.h` | Thread-safety: guarded member |
| `likely` | 353 | `base/base/defines.h` | Branch hint: condition is usually true |
| `SCOPE_EXIT` | 340 | `base/base/scope_guard.h` | Run code at end of scope |
| `USE_SSL` | 299 | generated `config.h` | Build flag: OpenSSL enabled |
| `TSA_REQUIRES` | 293 | `base/base/defines.h` | Thread-safety: caller holds lock |
| `DISPATCH` | 264 | `src/DataTypes/IDataType.h` users | Local macro expanding per-type code branches |
| `NO_INLINE` | 263 | `base/base/defines.h` | Prevent inlining (keeps hot loops separate) |
| `DEBUG_OR_SANITIZER_BUILD` | 254 | `base/base/sanitizer_defs.h` | Defined in debug and sanitizer builds |
| `APPLY_FOR_*` | 250 | many | X-macro lists: events, metrics, errors, hash variants |
| `NO_SANITIZE_UNDEFINED` | 246 | `base/base/sanitizer_defs.h` | Disable UBSan for a function |
| `CONV_FN` | 197 | `src/Client/BuzzHouse/AST/SQLProtoStr.cpp` | BuzzHouse proto-to-SQL converter declarations |
| `USE_EMBEDDED_COMPILER` | 184 | generated `config.h` | Build flag: LLVM JIT enabled |
| `USE_AWS_S3` | 174 | generated `config.h` | Build flag: S3 support |
| `UNREACHABLE` | 169 | `base/base/defines.h` | Marks unreachable code; aborts in debug |
| `REGULAR` | 168 | `src/Common/FailPoint.cpp` | Failpoint kind: fires every time |
| `ONCE` | 146 | `src/Common/FailPoint.cpp` | Failpoint kind: fires once |
| `REGISTER_SYSTEM_TABLE_SOURCE` | 140 | `src/Storages/System/SystemTableSourceRegistry.h` | Registers a `system.*` table source |
| `MAKE_OBSOLETE` | 135 | `src/Core/SettingsObsoleteMacros.h` | Keep removed setting name accepted but ignored |
| `USE_JEMALLOC` | 94 | generated `config.h` | Build flag: jemalloc allocator |
| `IMPLEMENT_SETTING_ENUM` | 89 | `src/Core/SettingsEnums.h` | Defines string mapping for enum setting |
| `USE_MULTITARGET_CODE` | 89 | `src/Common/TargetSpecific.h` | Build flag for runtime CPU dispatch |
| `DEFINE_ICEBERG_FIELD` | 82 | `src/Storages/ObjectStorage/DataLakes/Iceberg/Constant.h` | Declares Iceberg metadata field-name constant |
| `DECLARE_SETTING_ENUM` | 78 | `src/Core/SettingsEnums.h` | Declares enum-typed setting field |
| `PAUSEABLE_ONCE` | 78 | `src/Common/FailPoint.cpp` | Failpoint kind: blocks thread once |
| `PAUSEABLE` | 63 | `src/Common/FailPoint.cpp` | Failpoint kind: blocks thread each hit |
| `DECLARE_WITH_ALIAS` | 61 | `src/Core/Settings.cpp` | Declares a setting with an alternative name |
| `VERSION_STRING` | 57 | generated `config_version.h` | ClickHouse version as text |
| `SCOPE_EXIT_SAFE` | 54 | `src/Common/scope_guard_safe.h` | `SCOPE_EXIT` that logs instead of throwing |
| `MULTITARGET_FUNCTION_HEADER` | 37 | `src/Common/TargetSpecific.h` | Declares function compiled for several CPU targets |
| `MULTITARGET_FUNCTION_BODY` | 37 | `src/Common/TargetSpecific.h` | Body for a multitarget function |
| `NOEXCEPT_SCOPE` | 37 | `src/Common/noexcept_scope.h` | Terminate if the enclosed code throws |
| `DECLARE_SETTINGS_TRAITS` | 36 | `src/Core/BaseSettings.h` | Declares a settings collection's traits |
| `MULTITARGET_FUNCTION_X86_V4` | 34 | `src/Common/TargetSpecific.h` | Multitarget variant for AVX-512 |
| `SCHED_DBG` | 34 | `src/Common/Scheduler/Debug.h` | Debug print for workload scheduler |
| `IMPLEMENT_SETTINGS_TRAITS` | 33 | `src/Core/BaseSettings.h` | Defines a settings collection's traits |
| `MAKE_OBSOLETE_MERGE_TREE_SETTING` | 33 | `src/Storages/MergeTree/MergeTreeSettings.cpp` | Obsolete `MergeTree` setting kept for compatibility |
| `TYPEID_MAP` | 30 | `src/Core/TypeId.h` | Maps C++ type to `TypeIndex` |
| `FOR_BASIC_NUMERIC_TYPES` | 27 | `src/DataTypes/IDataType.h` | X-macro over `UInt8`...`Float64` |
| `DECLARE_MULTITARGET_CODE` | 20 | `src/Common/TargetSpecific.h` | Compile a code block for each CPU target |
| `FOR_EACH_DECIMAL_TYPE` | 17 | `src/DataTypes/DataTypesDecimal.h` | X-macro over decimal types |
| `FOR_NUMERIC_TYPES` | 15 | `src/DataTypes/IDataType.h` | X-macro over all numeric types incl. wide |
| `STRONG_TYPEDEF` | 12 | `base/base/strong_typedef.h` | Distinct type wrapping another |
| `SCOPE_FAIL` | 10 | `base/base/scope_guard.h` | Run code only when scope exits by exception |
| `SCOPE_EXIT_MEMORY_SAFE` | 9 | `src/Common/scope_guard_safe.h` | `SCOPE_EXIT_SAFE` with memory tracking blocked |

---

## 4. Build system, tests, CI and other languages

C++ is only part of the repository. Most of the files are tests, docs, CMake scripts, Python and shell. Counts below come from `git ls-files` with `contrib/` left out (79,205 tracked files).

### 4.1 Languages and files in the repo

#### File extensions

| Name | Uses/Count | What it is |
|---|---|---|
| `.mdx` | 24324 | Docs pages (Markdown plus JSX) for the Mintlify docs site |
| `.reference` | 15847 | Expected output of a stateless test |
| `.sql` | 11990 | Stateless SQL tests and test data setup scripts |
| `.cpp` | 5529 | C++ source files (server, client, libraries, tests) |
| `.h` | 4706 | C++ headers |
| `.sh` | 4108 | Bash tests (`0_stateless/*.sh`), CI and helper scripts |
| `.xml` | 3014 | Server/test configs and performance test definitions |
| `.py` | 2779 | Integration tests, `clickhouse-test`, CI (praktika), utilities |
| `.webp` | 2195 | Images used by the docs |
| `.md` | 876 | Plain Markdown: READMEs, changelogs, agent notes |
| `.jsx` | 496 | React snippets/components for the docs site |
| `.json` | 375 | Test data, docs navigation, CI settings |
| `.svg` | 254 | Vector images for docs |
| `.j2` | 242 | Jinja2 templates that expand into `.sql`/`.reference` tests |
| `.parquet` | 235 | Parquet sample files for format tests |
| `.pem` | 141 | TLS keys/certs used by tests |
| `CMakeLists.txt` | 140 | CMake build scripts, one per directory |
| `.yaml` / `.yml` | 137 / 132 | GitHub workflows, docker-compose files, nfpm package specs |
| `.c` | 113 | C code (glibc compatibility, small libs in `base/`) |
| `.jpg` / `.png` | 103 / 74 | Docs images |
| `.js` | 76 | Docs site scripts, web UI bits |
| `.python` | 38 | Python helpers run by stateless `.sh` tests |
| `.avro` | 66 | Avro sample files for format tests |
| `.expect` | 62 | `expect` scripts that drive interactive `clickhouse-client` |
| `.proto` | 59 | Protobuf schemas (gRPC protocol, format tests) |
| `.puffin` / `.crc` | 56 / 54 | Iceberg / Hadoop checksum test fixtures |
| `.crt` / `.key` | 53 / 44 | TLS certificates and keys for tests |
| `.cmake` | 48 | CMake modules in `cmake/` |
| `Dockerfile` | 47 | Docker images for CI jobs and releases |
| `.arrow` | 34 | Arrow IPC sample files |
| `.capnp` | 26 | Cap'n Proto schemas for format tests |
| `.html` | 25 | Built-in web UI (`play.html`, dashboard), CI report page |
| `.clj` | 24 | Clojure: Jepsen tests for ClickHouse Keeper |
| `.csv` / `.tsv` | 20 / 12 | Tabular test data |
| `.wasm` | 19 | WebAssembly modules for WASM UDF tests |
| `.options` | 18 | libFuzzer option files in `tests/fuzz/` |
| `.rs` | 17 | Rust sources (in `rust/`) |
| `.orc` | 11 | ORC sample files |
| `.avsc` | 10 | Avro schemas |
| `.toml` | 9 | `Cargo.toml`, `pyproject.toml`, docs link checker config |
| `.S` | 9 | Assembly (e.g. context switching, memcpy) |

#### Top-level directories

| Name | Uses/Count | What it is |
|---|---|---|
| `tests/` | 38953 files | All test suites, test runner, test configs |
| `docs/` | 28596 files | User docs (English plus `ru`, `zh`, `ja`, `ko`, `es`, `fr`, `pt-BR`, `ar`) |
| `src/` | 9203 files | The DBMS itself: storages, functions, parsers, interpreters |
| `base/` | 1150 files | Low-level libs: `base/base`, `poco`, `glibc-compatibility`, `pcg-random` |
| `contrib/` | 315 dirs | Third-party libraries (git submodules) plus `*-cmake` wrappers |
| `ci/` | 525 files | Python CI system: praktika, jobs, workflows, Dockerfiles |
| `utils/` | 239 files | Dev tools: `c++expr`, `changelog`, `check-large-objects.sh`, visualizers |
| `programs/` | 227 files | Entry points: `server`, `client`, `local`, `keeper`, `benchmark`, … |
| `cmake/` | 53 files | Shared CMake modules, toolchains, sanitizer and warning setup |
| `.github/` | 53 files | GitHub Actions workflows (generated from `ci/workflows`) |
| `rust/` | 39 files | Rust crates (`prql`, `skim`, `polyglot`, `wasmtime`) and `chcache` |
| `docker/` | 23 files | Official `server`, `keeper`, `bare` images |
| `packages/` | 15 files | `nfpm` YAML specs, systemd units for `.deb`/`.rpm` |
| `.claude/` | 91 files | AI assistant tools and skills (`fetch_ci_report.js`, …) |
| `benchmark/` | 1 file | Placeholder; benchmarks live elsewhere |

### 4.2 CMake

#### Basics

| Name | Uses/Count | What it is |
|---|---|---|
| `cmake_minimum_required(VERSION 3.25)` | 1 | Minimum CMake version |
| `project(ClickHouse LANGUAGES C CXX ASM)` | 1 | Project uses C, C++ and assembly |
| `CMAKE_CXX_STANDARD 23` | 1 | C++23, extensions off, required |
| `CMAKE_C_STANDARD 11` | 1 | C11 with GNU extensions (for contrib C code) |
| Clang only | `cmake/tools.cmake` | Any other compiler fails configure; minimum Clang 21 |
| `lld` linker | `LINKER_NAME` | `gold` is rejected; `lld` is the expected linker |
| `CMAKE_BUILD_TYPE` | default `RelWithDebInfo` | Also `Debug`, `Release` |
| `CMAKE_EXPORT_COMPILE_COMMANDS 1` | 1 | Writes `compile_commands.json` for `clangd`/clang-tidy |
| `CMAKE_POLICY_DEFAULT_CMP0126 NEW` | 1 | Stops contrib cache vars overriding our normal vars |
| `cmake/block_build_time_checks.cmake` | 1 | Forbids `try_compile`/`check_*` probes; toolchain is fixed |
| `cmake/toolchain/`, `cmake/linux/` | dirs | Cross-compile toolchains and vendored sysroots |
| `CMakePresets.json` | none | Not used; flags passed with `-D` directly |
| `build_*` dirs | convention | Out-of-tree builds: `build`, `build_debug`, `build_asan`, … |
| `compile_commands.json` | generated | Compile database for editors and clang-tidy |

#### Most used CMake commands

Counted over the repo's own CMake files plus `contrib/*-cmake` wrappers (189 files).

| Name | Uses/Count | What it is |
|---|---|---|
| `set` | 899 | Set a variable (normal, `CACHE`, or `PARENT_SCOPE`) |
| `if` / `endif` | 698 | Conditional block |
| `target_link_libraries` | 244 | Link a target against libraries/other targets |
| `message` | 194 | Print `STATUS`, `WARNING` or `FATAL_ERROR` |
| `list` | 159 | Append/remove/reverse items of a list variable |
| `add_contrib` | 150 | Custom: add a third-party lib if its submodule exists |
| `add_subdirectory` | 140 | Process another directory's `CMakeLists.txt` |
| `add_headers_and_sources` | 117 | Custom: glob `*.h` and `*.cpp`/`*.c` into lists |
| `add_object_library` | 82 | Custom: add a `src/` subdir's files to `dbms` |
| `add_library` | 79 | Create a library target (static, interface, alias) |
| `else` | 77 | Else branch |
| `option` | 65 | Declare a boolean user option (`-DENABLE_X=ON`) |
| `include` | 64 | Load a `.cmake` module |
| `elseif` | 64 | Else-if branch |
| `set_source_files_properties` | 40 | Per-file compile flags |
| `target_include_directories` | 39 | Add include paths to a target |
| `target_compile_options` | 29 | Add compiler flags to a target |
| `no_warning` | 29 | Custom: add `-Wno-<flag>` globally |
| `macro` / `endmacro` | 27 | Define a macro (runs in caller's scope) |
| `file` | 27 | Glob, read, write, relative paths |
| `clickhouse_add_executable` | 26 | Custom: `add_executable` plus ClickHouse allocator hooks |
| `_ch_block_check` | 26 | Custom: replace a CMake probe with a fatal error |
| `clickhouse_program_add` | 25 | Custom: build a `programs/<name>` as a library |
| `string` | 23 | String ops: `TOUPPER`, `REPLACE`, `REGEX` |
| `get_target_property` | 23 | Read a property of a target |
| `function` / `endfunction` | 22 | Define a function (own scope) |
| `execute_process` | 22 | Run a command at configure time |
| `clickhouse_program_install` | 22 | Custom: link program and symlink `clickhouse-<name>` |
| `add_custom_target` | 22 | Target that runs commands, no output file |
| `foreach` / `endforeach` | 21 | Loop over a list |
| `add_custom_command` | 21 | Generate files or run post-build steps |
| `find_program` | 19 | Locate a tool (`ccache`, `clang-tidy`, `objcopy`) |
| `add_dependencies` | 18 | Order targets without linking |
| `install` | 17 | Install rules for packages |
| `set_target_properties` | 16 | Set several target properties |
| `return` | 16 | Leave the current file/function |
| `get_property` | 16 | Read global/directory/cache properties |
| `target_compile_definitions` | 15 | Add `-D` macros to a target |
| `set_property` | 15 | Set a property (e.g. `EXCLUDE_FROM_ALL`) |
| `include_guard` | 14 | Include a module only once |
| `extract_into_parent_list` | 14 | Custom: move files from one list to parent's list |
| `add_definitions` | 13 | Old-style global `-D` flags (mostly contrib) |
| `configure_file` | 11 | Fill `@VAR@` in a `.in` template (`config.h`) |
| `clickhouse_add_microbenchmark` | 10 | Custom: Google Benchmark executable |
| `add_link_options` | 10 | Global linker flags |
| `ch_find_program` | 9 | Custom: find a tool, prefer the toolchain's |
| `add_compile_options` | 9 | Global compiler flags |
| `add_executable` | 7 | Plain executable target |
| `enable_dummy_launchers_if_needed` | 7 | Custom: skip real linking in clang-tidy builds |
| `math` | 6 | Integer arithmetic on variables |
| `gpu_cuda_library` | 6 | Custom: build CUDA code for GPU support |
| `target_link_options` | 5 | Linker flags for one target |
| `cmake_parse_arguments` | 4 | Parse keyword arguments in functions |
| `add_warning` | 4 | Custom: add `-W<flag>` globally |
| `add_compile_definitions` | 4 | Global `-D` macros |
| `clickhouse_config_crate_flags` | 4 | Custom: set flags for Rust crates |
| `enable_language` | 3 | Enable `ASM`, `CUDA` etc. |
| `cmake_path` | 3 | Path manipulation |
| `add_test` / `enable_testing` | 3 / 2 | CTest hooks (rarely used) |
| `protobuf_generate_cpp` | 2 | Generate C++ from `.proto` |
| `protobuf_generate_grpc_cpp` | 1 | Generate gRPC stubs |
| `corrosion_import_crate` | 1 | Build Rust crates via the Corrosion CMake module |
| `find_package` | 1 | Almost unused: libraries come from `contrib/`, not the system |

#### Generator expressions

| Name | Uses/Count | What it is |
|---|---|---|
| `$<COMPILE_LANGUAGE:...>` | 12 | Apply flag only to C, C++ or ASM files |
| `$<TARGET_OBJECTS:...>` | 7 | Object files of an `OBJECT` library |
| `$<TARGET_FILE:...>` | 5 | Path of a built target file |
| `$<TARGET_PROPERTY:...>` | 4 | Read a target property at generate time |
| `$<OR:...>` | 3 | Logical or |
| `$<NOT:...>` / `$<BOOL:...>` | 2 / 2 | Logical not / convert to bool |
| `$<LINK_ONLY:...>` | 1 | Link dependency without usage requirements |
| `$<LINK_LIBRARY:...>` | 1 | Link with a special feature (e.g. whole-archive) |

#### ClickHouse custom CMake functions and macros

| Name | Uses/Count | What it is |
|---|---|---|
| `add_contrib` | `contrib/CMakeLists.txt` | Add `<lib>-cmake` wrapper if `<lib>` submodule is populated |
| `add_glob` | `cmake/dbms_glob_sources.cmake` | `file(GLOB CONFIGURE_DEPENDS)` appended to a list |
| `add_headers_and_sources` | same | Glob `.h` into `<prefix>_headers`, `.cpp`/`.c` into `<prefix>_sources` |
| `add_headers_only` | same | Glob only headers |
| `extract_into_parent_list` | same | Move listed files into a parent-scope list, strip `src/` |
| `add_object_library` | `src/CMakeLists.txt` | Shorthand for `add_headers_and_sources(dbms <dir>)` |
| `clickhouse_add_executable` | `CMakeLists.txt` | `add_executable` + `clickhouse_malloc` objects + `clickhouse_new_delete` |
| `add_native_target` | `CMakeLists.txt` | Mark a target to build for the host when cross-compiling |
| `clickhouse_program_add` | `programs/CMakeLists.txt` | Build `clickhouse-<name>-lib` from `CLICKHOUSE_<NAME>_SOURCES` |
| `clickhouse_program_add_library` | same | Worker behind `clickhouse_program_add` |
| `clickhouse_target_link_split_lib` | same | Link `clickhouse-<name>-lib` into the `clickhouse` binary |
| `clickhouse_program_install` | same | Link program, make `clickhouse-<name>` symlink, install it |
| `clickhouse_program_alias` | same | Extra symlink name for a program (e.g. `chl`) |
| `clickhouse_add_microbenchmark` | `src/CMakeLists.txt` | Google Benchmark executable against `dbms` |
| `grep_gtest_sources` | `src/CMakeLists.txt` | Collect `gtest*.cpp` files for `unit_tests_dbms` |
| `generate_system_build_options` | `src/Storages/System` | Generate data for `system.build_options` |
| `ch_find_program` | `cmake/tools.cmake` | Find tool (e.g. `llvm-objcopy`) matching compiler version |
| `add_warning` / `no_warning` | `cmake/add_warning.cmake` | Turn a `-W` warning on/off globally |
| `target_add_warning` / `target_no_warning` | same | Same, for one target |
| `_ch_block_check` | `cmake/block_build_time_checks.cmake` | Makes `check_cxx_compiler_flag` etc. a fatal error |
| `enable/disable_dummy_launchers_if_needed` | `cmake/utils.cmake` | Fake linker for clang-tidy-only builds |
| `enable/disable_heavy_build_check_if_needed` | same | Wrap compiler in `prlimit` to catch huge translation units |
| `get_all_targets` | `cmake/utils.cmake` | Recursively list all targets in a directory |
| `sanitize_link_libraries` | `cmake/sanitize_targets.cmake` | Check targets do not link forbidden libraries |
| `ensure_target_rooted_in` | `contrib/CMakeLists.txt` | Check contrib targets stay in their folder |
| `organize_ide_folders_2_level` | same | Group targets into folders for IDEs |
| `clickhouse_split_debug_symbols` | `cmake/split_debug_symbols.cmake` | Strip binary, save debug info separately |
| `clickhouse_generate_export_header` | `cmake/generate_export_header.cmake` | Generate symbol export macros header |
| `gpu_cuda_library` / `gpu_island_target` | `cmake/cuda.cmake` | Build CUDA parts in an isolated "island" |
| `configure_bash_completion` | `programs/bash-completion` | Install shell completion scripts |
| `export` (empty macro) | `CMakeLists.txt` | Disables CMake `export` that contrib would call |
| `dbms_target_link_libraries` | not found | Does not exist in the current tree |

#### Important build options

Pass with `cmake -D<NAME>=<value>`. Most `ENABLE_<LIB>` options default to `ENABLE_LIBRARIES` (ON).

| Name | Uses/Count | What it is |
|---|---|---|
| `SANITIZE` | string | `address`, `thread`, `memory`, `undefined` sanitizer builds |
| `ENABLE_TESTS` | option | Build `unit_tests_dbms` (gtest) |
| `ENABLE_EXAMPLES` | option | Build small example programs in `src/**/examples` |
| `ENABLE_BENCHMARKS` | option | Build Google Benchmark microbenchmarks |
| `ENABLE_FUZZING` | option | Build libFuzzer targets |
| `ENABLE_BUZZHOUSE` | option | Build the BuzzHouse SQL fuzzer into the client |
| `ENABLE_FUZZER_TEST` | option | Build fuzzers that test libFuzzer itself |
| `ENABLE_LIBRARIES` | option | Master switch for optional third-party libs |
| `ENABLE_CLICKHOUSE_ALL` | option | Master switch for optional programs |
| `ENABLE_CLICKHOUSE_KEEPER` | option | Build `clickhouse-keeper` |
| `ENABLE_CLICKHOUSE_KEEPER_CLIENT` | option | Build `clickhouse-keeper-client` |
| `ENABLE_CLICKHOUSE_KEEPER_CONVERTER` | option | Build ZooKeeper-to-Keeper snapshot converter |
| `BUILD_STANDALONE_KEEPER` | option | Build Keeper as its own small binary |
| `ENABLE_CLANG_TIDY` | option | Run clang-tidy while compiling |
| `ENABLE_DUMMY_LAUNCHERS` | option | Skip linking (for clang-tidy CI builds) |
| `ENABLE_CHECK_HEAVY_BUILDS` | option | Fail on files too slow/large to compile |
| `ENABLE_BUILD_PROFILING` | option | `-ftime-trace` compile-time profiling |
| `ENABLE_THINLTO` | option | Link-time optimization |
| `ENABLE_CLICKHOUSE_PGO_GENERATE` | option | Profile-guided optimization, profile collection step |
| `ENABLE_CLICKHOUSE_BOLT` | option | Post-link optimization with LLVM BOLT |
| `WITH_COVERAGE` | option | Build with code coverage instrumentation |
| `WITH_COVERAGE_XRAY` / `ENABLE_XRAY` | option | XRay instrumentation |
| `ENABLE_CFI` | option | Control-flow integrity checks |
| `WERROR` | option | Treat warnings as errors |
| `SPLIT_DEBUG_SYMBOLS` | option | Put debug info in a separate file |
| `DISABLE_ALL_DEBUG_SYMBOLS` | option | No `-g` at all (faster builds) |
| `OMIT_HEAVY_DEBUG_SYMBOLS` | option | Drop debug info for heavy files |
| `BUILD_STRIPPED_BINARY` | option | Produce a stripped binary |
| `COMPRESS_DEBUG_SECTIONS` | option | Compress DWARF sections |
| `GLIBC_COMPATIBILITY` | option | Run on older glibc versions |
| `PARALLEL_COMPILE_JOBS` / `PARALLEL_LINK_JOBS` | option | Limit parallelism based on RAM |
| `COMPILER_CACHE` | cache string | `auto`, `ccache`, `sccache`, `chcache`, `disabled` |
| `LINKER_NAME` | option | Linker to use (`lld`) |
| `ENABLE_JEMALLOC` | option | Use jemalloc allocator (recommended) |
| `ENABLE_EMBEDDED_COMPILER` | option | LLVM JIT for expressions |
| `ENABLE_RUST` | option | Build Rust crates |
| `ENABLE_PRQL` / `ENABLE_SKIM` | option | Rust: PRQL dialect / fuzzy history search |
| `ENABLE_WASMTIME` | option | Rust: WebAssembly UDF runtime |
| `ENABLE_DELTA_KERNEL_RS` | option | Rust Delta Lake reader |
| `ENABLE_AWS_S3` | option | S3 support |
| `ENABLE_AZURE_BLOB_STORAGE` | option | Azure blob storage support |
| `ENABLE_HDFS` / `ENABLE_HIVE` | option | Hadoop HDFS / Hive support |
| `ENABLE_KAFKA` / `ENABLE_NATS` / `ENABLE_AMQPCPP` | option | Kafka / NATS / RabbitMQ engines |
| `ENABLE_PARQUET` / `ENABLE_ORC` / `ENABLE_AVRO` | option | Columnar/row file formats |
| `ENABLE_PROTOBUF` / `ENABLE_CAPNP` / `ENABLE_MSGPACK` | option | Schema-based formats |
| `ENABLE_GRPC` | option | gRPC protocol interface |
| `ENABLE_SSL` / `ENABLE_OPENSSL_DYNAMIC` | option | TLS via OpenSSL |
| `ENABLE_LDAP` / `ENABLE_CYRUS_SASL` / `ENABLE_GSASL_LIBRARY` | option | Auth libraries |
| `ENABLE_MYSQL` / `ENABLE_LIBPQXX` / `USE_MONGODB` | option | External DB integrations |
| `ENABLE_ROCKSDB` / `ENABLE_SQLITE` | option | Embedded key-value / SQL engines |
| `ENABLE_ICU` / `ENABLE_NLP` / `ENABLE_MECAB` | option | Unicode and text processing |
| `ENABLE_H3` / `ENABLE_S2_GEOMETRY` | option | Geo index libraries |
| `ENABLE_USEARCH` / `ENABLE_SIMSIMD` | option | Vector similarity index |
| `ENABLE_VECTORSCAN` | option | Fast multi-regex (Hyperscan fork) |
| `ENABLE_SIMDJSON` / `ENABLE_RAPIDJSON` | option | JSON parsers |
| `ENABLE_BROTLI` / `ENABLE_BZIP2` / `ENABLE_LIBDEFLATE` | option | Compression libraries |
| `ENABLE_NURAFT` | option | Raft library for Keeper |
| `ENABLE_LIBURING` | option | `io_uring` async IO |
| `ENABLE_GPU` | option | Experimental CUDA code |
| `ENABLE_MULTITARGET_CODE` | option | Compile SIMD variants (SSE/AVX2/AVX-512) |
| `NO_ARMV81_OR_HIGHER` | option | Build for older ARMv8.0 CPUs |
| `FAIL_ON_UNSUPPORTED_OPTIONS_COMBINATION` | option | Fail configure if an `ENABLE_X` cannot be met |

#### How third-party libraries are built

| Name | Uses/Count | What it is |
|---|---|---|
| git submodules | 156 in `.gitmodules` | Upstream library sources under `contrib/<lib>` |
| `contrib/<lib>-cmake/` | 146 dirs | ClickHouse's own `CMakeLists.txt` for that library |
| `add_contrib(<lib>-cmake <lib>)` | 152 calls | Registers a wrapper in `contrib/CMakeLists.txt` |
| `ch_contrib::<lib>` | alias target | Name `src/` links against, e.g. `ch_contrib::zstd` |
| `-w` for contrib | global | Warnings silenced for third-party code |
| `EXCLUDE_FROM_ALL` | property | Contrib targets built only when something needs them |
| Hand-listed sources | e.g. `zstd-cmake` | Wrappers list `.c` files explicitly, skip upstream build |

Example from `contrib/zstd-cmake/CMakeLists.txt`:

```cmake
add_library(_zstd ${Sources} ${Headers})
add_library(ch_contrib::zstd ALIAS _zstd)
target_include_directories(_zstd BEFORE PUBLIC ${LIBRARY_DIR})
```

### 4.3 Other build and dev tooling

| Name | Uses/Count | What it is |
|---|---|---|
| Ninja | generator | `cmake -G Ninja`; run `ninja` in a `build_*` dir |
| ccache / sccache | `cmake/ccache.cmake` | Compiler caches; `auto` tries `sccache` then `ccache` |
| `chcache` | `rust/chcache` | ClickHouse's own Rust compiler cache |
| `.clang-format` | 1 | WebKit base, Allman braces, 140 columns |
| `.clang-tidy` | ~154 disabled checks | All checks on (`'*'`) minus a disable list |
| `.clangd` | 1 | Settings for the `clangd` language server |
| `.editorconfig` | 1 | LF endings, 4-space indent |
| `ci/jobs/scripts/check_style/check_cpp.sh` | 532 lines | `grep`-based C++ style rules |
| `various_checks.sh` | 1 | Misc repo checks (file names, permissions) |
| `check_submodules.sh` | 1 | Checks submodule URLs and state |
| `clickhouse_spelling.py` | 1 | Spell check with an ignore list |
| `check-mypy` | 1 | Python type checking |
| `check-settings-style` | 1 | Checks setting declarations |
| `pyproject.toml` | 2 | `pylint`, `black`, `isort`, `ruff` config |
| `.yamllint` | 1 | YAML lint rules |
| `.githooks/pre-push` | 1 | Optional local pre-push hook |
| `shellcheck` | comments | Shell lint; `# shellcheck disable=` in tests |
| Rust / Cargo | 4 crates | `rust/workspace`: `prql`, `skim`, `polyglot`, `wasmtime` |
| Corrosion | CMake module | Builds Cargo crates from CMake |
| Emscripten | `WASM64` build | Compiles `clickhouse` to WebAssembly |
| CUDA | `cmake/cuda.cmake` | Optional GPU code |
| `nfpm` | `packages/*.yaml` | Builds `.deb`, `.rpm`, `.tgz` packages |
| Docker | 47 Dockerfiles | CI job images (`ci/docker`) and release images (`docker/`) |
| `utils/c++expr` | 1 | Compile and run a C++ snippet against headers |
| `utils/changelog` | 1 | Generates release changelog |
| Clojure / Leiningen | `tests/jepsen.clickhouse` | Jepsen consistency tests for Keeper |
| Mintlify | `docs/docs.json` | Docs site generator |
| `lychee` | `docs/lychee.toml` | Broken link checker for docs |

### 4.4 Tests

#### Test suites overview

| Name | Uses/Count | What it is |
|---|---|---|
| Stateless (functional) tests | 15840 files | `tests/queries/0_stateless`, compare output to `.reference` |
| Integration tests | 919 `test_*` dirs | pytest + Docker clusters, `tests/integration` |
| Performance tests | 683 XML | `tests/performance`, compared old vs new binary |
| Unit tests (gtest) | 584 `gtest_*.cpp` | `src/**/tests/`, built into `unit_tests_dbms` |
| libFuzzer targets | 19 `*_fuzzer.cpp` | `src/**/fuzzers/`, options in `tests/fuzz/` |
| AST fuzzer | `QueryFuzzer` | Client mutates test queries' ASTs, looks for exceptions |
| BuzzHouse | `src/Client/BuzzHouse` | Random SQL generator fuzzer in the client |
| Microbenchmarks | 10 files | Google Benchmark (`benchmark::State`) |
| Stress test | `tests/docker_scripts/stress_runner.sh` | Stateless tests run in parallel with random faults |
| Upgrade check | `upgrade_runner.sh` | Start old version, upgrade, check data |
| SQLLogic test | `tests/sqllogic` | SQLite's sqllogictest suite runner |
| SQLancer / SQLStorm | CI jobs | External logic-bug finders and query corpora |
| Jepsen | `tests/jepsen.clickhouse` | Keeper linearizability under network faults |
| `tests/clickhouse-test` | 8173 lines Python | Runner for stateless tests |

#### Stateless test files

| Name | Uses/Count | What it is |
|---|---|---|
| `.reference` | 15798 | Expected stdout, compared exactly |
| `.sql` | 11640 | Queries run through `clickhouse-client` |
| `.sh` | 3939 | Bash test; sources `shell_config.sh` |
| `.j2` | 242 | Jinja2 template, expanded before running |
| `.expect` | 62 | Interactive client session scripts |
| `.python` / `.py` | 38 / 9 | Helpers called by `.sh` tests |
| `NNNNN_name` prefix | 5-digit | Number assigned by `add-test` |
| `add-test <name>[.sh]` | script | Creates next-numbered test and empty `.reference` |
| `-- Tags:` / `# Tags:` | 5743 tests | First-line tags that control where a test runs |

#### Stateless test tags

| Name | Uses/Count | What it is |
|---|---|---|
| `no-fasttest` | 2591 | Skip in the quick "Fast test" build (few libs) |
| `no-parallel` | 1065 | Must run alone, not with other tests |
| `long` | 766 | Slow test, longer timeout |
| `no-replicated-database` | 751 | Skip when run in a `Replicated` database |
| `no-random-settings` | 554 | Do not randomize session settings |
| `no-parallel-replicas` | 543 | Skip with parallel replicas enabled |
| `no-random-merge-tree-settings` | 433 | Do not randomize `MergeTree` settings |
| `no-msan` | 346 | Skip in MemorySanitizer build |
| `no-flaky-check` | 306 | Skip in repeated-runs flaky check |
| `zookeeper` | 275 | Needs ZooKeeper/Keeper |
| `no-shared-merge-tree` | 275 | Skip with `SharedMergeTree` (cloud) |
| `distributed` | 216 | Uses `Distributed` tables |
| `no-tsan` | 208 | Skip in ThreadSanitizer build |
| `no-ordinary-database` | 202 | Skip with `Ordinary` database engine |
| `shard` | 188 | Needs extra shard addresses (127.0.0.2 etc.) |
| `no-asan` | 182 | Skip in AddressSanitizer build |
| `stateful` | 149 | Needs `test.hits`/`test.visits` datasets |
| `no-object-storage` | 147 | Skip when tables live on S3/Azure |
| `no-debug` | 141 | Skip in debug build (too slow) |
| `no-ubsan` | 137 | Skip in UBSan build |
| `no-async-insert` | 83 | Skip with async inserts forced on |
| `replica` | 77 | Uses replicated tables |
| `race` | 59 | Race-condition test, often long |
| `no-azure-blob-storage` | 59 | Skip on Azure storage |
| `no-darwin` | 53 | Skip on macOS |
| `memory-engine` | 51 | Uses `Memory` engine features |
| `no-distributed-cache` | 50 | Skip with distributed cache |
| `use-rocksdb` | 40 | Needs RocksDB |
| `no-llvm-coverage` | 38 | Skip in coverage build |
| `no-s3-storage` | 37 | Skip on S3 storage |
| `no-encrypted-storage` | 29 | Skip on encrypted disk |
| `log-engine` | 29 | Uses `Log` family engines |
| `no-sanitizers` | 28 | Skip in all sanitizer builds |
| `no-old-analyzer` | 24 | Needs the new analyzer |
| `atomic-database` | 21 | Needs `Atomic` database engine |
| `use-xray` | 15 | Needs XRay build |
| `use-vectorscan` | 12 | Needs Vectorscan |
| `deadlock` | 12 | Checks for deadlocks |

#### SQL used in stateless tests

| Name | Uses/Count | What it is |
|---|---|---|
| `SELECT` | 179205 | Read data / compute expressions |
| `WHERE` | 36103 | Row filter |
| `ORDER BY` | 34858 | Sort (needed for stable output) |
| `SETTINGS` | 26228 | Per-query or per-table settings |
| `INSERT INTO` | 22426 | Write rows |
| `ENGINE` | 19709 | Table engine clause |
| `CREATE TABLE` | 19553 | Create table |
| `SET` | 19217 | Change session setting |
| `EXPLAIN` | 17428 | Show plan/AST/pipeline |
| `SYSTEM` | 16710 | Admin commands (`SYSTEM FLUSH LOGS`, …) |
| `DROP TABLE IF EXISTS` | 16120 | Cleanup |
| `WITH` | 15391 | CTEs / aliases |
| `LIMIT` | 14563 | Limit rows |
| `JOIN` | 12638 | Joins |
| `FORMAT` | 7857 | Output format (`TSV`, `JSON`, `Null`) |
| `GROUP BY` | 7016 | Aggregation |
| `ALTER TABLE` | 4582 | Schema/data changes, mutations |
| `FINAL` | 3127 | Merge-on-read for `ReplacingMergeTree` etc. |
| `UNION ALL` | 2902 | Concatenate results |
| `PREWHERE` | 1846 | Early filter before reading all columns |
| `OPTIMIZE TABLE` | 1497 | Force merge |
| `ARRAY JOIN` | 1005 | Unfold arrays into rows |

#### Top SQL functions and types in tests

| Name | Uses/Count | What it is |
|---|---|---|
| `count` | 23093 | Row count aggregate |
| `numbers` | 16470 | Table function generating 0..N-1 |
| `sum` | 9079 | Sum aggregate |
| `materialize` | 8822 | Turn constant into full column |
| `Nullable` | 7710 | Nullable type wrapper |
| `tuple` | 6851 | Build a tuple |
| `CAST` | 6760 | Type conversion |
| `currentDatabase` | 6734 | Test's unique database name |
| `Array` | 6609 | Array type |
| `toTypeName` | 5345 | Print type of expression |
| `toString` | 5119 | Convert to string |
| `toUInt64` | 4172 | Convert to `UInt64` |
| `Tuple` | 4023 | Tuple type |
| `toDateTime` | 3666 | Convert to `DateTime` |
| `toUInt8` | 3548 | Convert to `UInt8` |
| `toInt64` | 3534 | Convert to `Int64` |
| `toInt32` | 3403 | Convert to `Int32` |
| `toUInt32` | 3360 | Convert to `UInt32` |
| `toFixedString` | 3058 | Convert to `FixedString` |
| `toInt8` | 3053 | Convert to `Int8` |
| `if` | 2925 | Conditional |
| `groupArray` | 2909 | Collect values into array |
| `toDate` | 2869 | Convert to `Date` |
| `toDateTime64` | 2819 | Sub-second `DateTime64` |
| `toInt16` | 2780 | Convert to `Int16` |
| `toUInt16` | 2679 | Convert to `UInt16` |
| `toFloat64` | 2592 | Convert to `Float64` |
| `countIf` | 2584 | Conditional count |
| `LowCardinality` | 2557 | Dictionary-encoded type |
| `round` | 2432 | Round number |
| `format` | 2406 | String formatting |
| `multiIf` | 2263 | Chained conditional |
| `arrayJoin` | 2247 | Unfold array into rows |
| `arrayMap` | 2199 | Map lambda over array |
| `toFloat32` | 2091 | Convert to `Float32` |
| `cityHash64` | 1962 | Fast 64-bit hash |
| `map` | 1887 | Build a `Map` |
| `max` | 1878 | Max aggregate |
| `range` | 1821 | Array 0..N-1 |
| `remote` | 1789 | Query another server (distributed tests) |
| `concat` | 1760 | Concatenate strings |
| `length` | 1735 | String/array length |
| `intDiv` | 1721 | Integer division |
| `toNullable` | 1436 | Wrap in `Nullable` |
| `has` | 1426 | Array contains element |
| `arraySort` | 1410 | Sort array |
| `min` | 1314 | Min aggregate |
| `uniq` | 1280 | Approximate distinct count |
| `now` | 1181 | Current time |
| `file` | 1169 | Read/write local file table function |
| `toDate32` | 1129 | Convert to extended-range `Date32` |
| `Variant` | 1128 | Variant (union) type |
| `AggregateFunction` | 1080 | Stored aggregate state type |
| `unhex` / `hex` | 999 / 974 | Hex encode/decode |
| `JSON` | 979 | JSON data type |
| `formatQuery` | 424 | Pretty-print a query |
| `dictGet` | 828 | Read from dictionary |
| `numbers_mt` | 847 | Multithreaded `numbers` |
| `rand` | 742 | Random number |
| `uniqExact` | 645 | Exact distinct count |
| `finalizeAggregation` | 642 | Finish aggregate state |
| `avg` | 622 | Average |
| `isNull` | 600 | Null check |
| `JSONExtract` | 507 | Extract from JSON string |
| `toStartOfInterval` | 491 | Round time down to interval |
| `sipHash64` | 468 | Cryptographic-ish hash |
| `arrayReduce` | 406 | Apply aggregate to array |

#### Table engines used in tests

| Name | Uses/Count | What it is |
|---|---|---|
| `MergeTree` | 9982 | Main columnar engine |
| `Memory` | 2579 | In-RAM table |
| `ReplicatedMergeTree` | 420 | Replicated via Keeper |
| `TinyLog` | 410 | Simplest file engine |
| `Distributed` | 377 | Sharded table over clusters |
| `ReplacingMergeTree` | 333 | Dedup by key on merge |
| `Merge` | 243 | Union of tables by regex |
| `Log` | 192 | Small append-only tables |
| `Join` | 171 | Prebuilt join hash table |
| `SummingMergeTree` | 141 | Sum columns on merge |
| `AggregatingMergeTree` | 123 | Merge aggregate states |
| `TimeSeries` | 111 | Prometheus-style time series |
| `EmbeddedRocksDB` | 74 | Key-value on RocksDB |
| `Null` | 65 | Discards writes |
| `Buffer` | 54 | Buffers writes in RAM |
| `StripeLog` | 47 | Log engine with one file |
| `CollapsingMergeTree` | 45 | Cancel rows by sign |
| `CoalescingMergeTree` | 41 | Keep last non-null values |
| `Set` | 38 | Set for `IN` |
| `File` / `URL` | 33 / 29 | Data in file / over HTTP |
| `GenerateRandom` | 31 | Random data generator |
| `KeeperMap` | 25 | Key-value in Keeper |
| `Atomic` / `Replicated` / `Ordinary` | 31 / 28 / 21 | Database engines |

#### Shell test helpers

| Name | Uses/Count | What it is |
|---|---|---|
| `$CLICKHOUSE_CLIENT` | 23579 | Client command with test db and ports |
| `shell_config.sh` | 7812 | Sourced by every `.sh` test; defines variables |
| `$CLICKHOUSE_DATABASE` | 3806 | Unique per-test database |
| `$CLICKHOUSE_LOCAL` | 3006 | `clickhouse local` command |
| `$CLICKHOUSE_CURL` | 1734 | `curl` with sane options for HTTP tests |
| `$CLICKHOUSE_TEST_UNIQUE_NAME` | 1559 | Name for files/tables unique to the run |
| `$CLICKHOUSE_URL` | 1202 | HTTP URL with database parameter |
| `$CLICKHOUSE_TMP` | 1131 | Temp dir for the test |
| `$CLICKHOUSE_TEST_ZOOKEEPER_PREFIX` | 207 | Unique Keeper path |
| `$CLICKHOUSE_FORMAT` | 200 | `clickhouse format` command |
| `$CLICKHOUSE_KEEPER_CLIENT` | 175 | Keeper CLI |
| `wait_for_async_insert` | 169 | Wait until async inserts flush |
| `$CLICKHOUSE_PORT_HTTP` / `_TCP` | 118 / 111 | Server ports |
| `$CLICKHOUSE_BENCHMARK` | 59 | `clickhouse benchmark` command |
| `wait_for_mutation` | 52 | Wait for `ALTER` mutation to finish |
| `wait_for_query_to_start` | 43 | Wait until query appears in `system.processes` |
| `$CLICKHOUSE_USER_FILES` | 56 | Server `user_files` directory |

#### Integration tests

| Name | Uses/Count | What it is |
|---|---|---|
| `node.query` | 11057 | Run SQL on a cluster node, return text |
| `import pytest` | 1184 | pytest framework |
| `from helpers.cluster import` | 1081 | Test cluster helpers module |
| `ClickHouseCluster` | 2303 | Defines cluster, starts Docker containers |
| `TSV` | 1959 | Compare results as tab-separated rows |
| `cluster.add_instance` | 1941 | Add a ClickHouse node with configs |
| `pytest.fixture` | 1342 | Setup/teardown (usually `start_cluster`) |
| `exec_in_container` | 1198 | Run a shell command inside a container |
| `pytest.mark.parametrize` | 1016 | Run test with several inputs |
| `start_cluster` | 873 | Conventional module-scoped fixture name |
| `query_and_get_error` | 706 | Run query, expect and return error |
| `assert_eq_with_retry` | 615 | Retry until result matches (eventual consistency) |
| `restart_clickhouse` | 526 | Restart a node |
| `contains_in_log` | 353 | Check server log for a string |
| `start_clickhouse` / `stop_clickhouse` | 286 / 267 | Start/stop a node |
| `wait_for_log_line` | 208 | Block until log line appears |
| `PartitionManager` | 129 | Inject network partitions with iptables |
| `helpers.test_tools` | 243 | `TSV`, `assert_eq_with_retry` |
| `helpers.iceberg_utils` | 123 | Iceberg/data lake test helpers |
| `helpers.keeper_utils` | 75 | Keeper test helpers |
| `compose/docker_compose_*.yml` | 59 | External services: Kafka, MinIO, MySQL, … |
| `pytest.ini` | 1 | Timeouts (900 s per test), logging |
| `configs/*.xml` | per test | Server configs mounted into nodes |

#### Performance, unit and fuzz tests

| Name | Uses/Count | What it is |
|---|---|---|
| `<test>` | 683 files | Root of a performance test XML |
| `<query>` | 3306 | Query to time |
| `<create_query>` | 1447 | Table setup |
| `<drop_query>` | 1282 | Cleanup |
| `<fill_query>` | 1073 | Data load |
| `<substitutions>` | 179 | Parameter matrix expanded into queries |
| `<settings>` | 286 | Settings for all queries in the file |
| gtest in `src/Common` | 152 | Largest group of unit tests |
| gtest in `src/Storages` | 75 | Storage unit tests |
| gtest in `src/Processors` | 62 | Pipeline unit tests |
| gtest in `src/IO` | 53 | Buffer/IO unit tests |
| `unit_tests_dbms` | 1 target | Single gtest binary with all unit tests |
| `*_fuzzer.cpp` | 19 | libFuzzer entry points (`LLVMFuzzerTestOneInput`) |
| `tests/fuzz/*.options` | 18 | Per-fuzzer libFuzzer flags and dictionaries |
| `ci/jobs/scripts/fuzzer/run-fuzzer.sh` | 1 | Runs the AST fuzzer job |

### 4.5 CI

CI is a Python framework called praktika. Workflows are written in Python (`ci/workflows/*.py`) and turned into GitHub Actions YAML (`.github/workflows/*.yml`). Results are uploaded to S3 bucket `clickhouse-test-reports` and shown on a `praktika.html` report page.

#### CI layout

| Name | Uses/Count | What it is |
|---|---|---|
| `ci/praktika/` | ~45 modules | The CI framework: jobs, workflows, S3, caching, HTML reports |
| `ci/workflows/` | 30 files | Python workflow definitions (`pull_request.py`, `master.py`, `nightly*.py`) |
| `.github/workflows/` | 34 YAML | Generated GitHub Actions files |
| `ci/jobs/` | ~60 scripts | One script per job type |
| `ci/jobs/scripts/` | 57 entries | Shared job helpers, style check, fuzzer scripts |
| `ci/defs/defs.py` | 1 | `BuildTypes`, `JobNames`, runner labels |
| `ci/defs/job_configs.py` | 1 | Which jobs run, shards, dependencies |
| `ci/docker/` | 17 images | CI images: `binary-builder`, `fasttest`, `stateless-test`, `integration`, … |
| `ci/settings/settings.py` | 1 | S3 bucket names and endpoints |
| `python -m ci.praktika run "<job>"` | command | Run a CI job locally |

#### Build types (`BuildTypes`)

| Name | Uses/Count | What it is |
|---|---|---|
| `amd_debug` / `arm_debug` | build | Debug build with assertions |
| `amd_release` / `arm_release` | build | Optimized release build |
| `amd_asan_ubsan` / `arm_asan_ubsan` | build | AddressSanitizer + UndefinedBehaviorSanitizer |
| `amd_tsan` / `arm_tsan` | build | ThreadSanitizer |
| `amd_msan` / `arm_msan` | build | MemorySanitizer |
| `amd_binary` / `arm_binary` | build | Plain binary without packages |
| `amd_tidy` / `arm_tidy` | build | clang-tidy build |
| `amd_coverage`, `llvm_coverage_build` | build | Coverage instrumentation |
| `amd_darwin` / `arm_darwin` | build | macOS cross-build |
| `amd_freebsd` | build | FreeBSD cross-build |
| `amd_musl` | build | Static musl libc build |
| `amd_compat` / `arm_v80compat` | build | Old CPU compatibility builds |
| `ppc64le`, `riscv64`, `s390x`, `loongarch64` | build | Other CPU architectures |
| `wasm64`, `wasm_parser` | build | WebAssembly builds |
| `amd_fuzzers` | build | libFuzzer targets |
| `amd_cfi` | build | Control-flow integrity build |

#### Main CI jobs (`JobNames`)

| Name | Uses/Count | What it is |
|---|---|---|
| `Style check` | job | Runs `check_style` scripts |
| `Fast test` | job | Tiny build plus quick stateless subset |
| `Build` | job | Builds each `BuildTypes` variant |
| `Unit tests` | job | Runs `unit_tests_dbms` |
| `Stateless tests` | job | Functional tests, many shards and build types |
| `Stateful tests` | job | Tests on `hits`/`visits` datasets |
| `Integration tests` | job | pytest suite, sharded |
| `Stress test` | job | Parallel tests with fault injection |
| `Upgrade check` | job | Upgrade from previous release |
| `Performance Comparison` | job | Old vs new binary on `tests/performance` |
| `Compatibility check` | job | Checks glibc and other symbol versions |
| `AST fuzzer` / `BuzzHouse` | job | Query fuzzers against sanitizer builds |
| `Bugfix validation` | job | New test must fail on master, pass on PR |
| `ClickBench` | job | Standard benchmark queries |
| `SQLLogic test` / `SQLTest` / `SQLancer` | job | External SQL correctness suites |
| `Install packages` | job | Installs `.deb`/`.rpm` and starts server |
| `Docker server image` / `Docker keeper image` | job | Builds official images |
| `Docs check (Mintlify)` | job | Builds and checks docs |
| `LLVM Coverage` | job | Coverage report |
| `Code Review` | job | Automated AI review |
| S3 `clickhouse-test-reports` | bucket | Where all job reports and logs are stored |
