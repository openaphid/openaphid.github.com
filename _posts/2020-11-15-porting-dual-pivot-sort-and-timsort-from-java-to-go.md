---
layout: post
title: "Porting Dual-Pivot Sort and Timsort from Java to Go"
date: 2020-11-15 00:23 -0800
cover-img: "/assets/etc/poker-sort.jpeg"
tags: [Algorithm, Go]
---

Most programming languages provide sorting APIs in their built-in libraries. Java and Go use different sorting algorithms, I implemented Java's algorithms in Go with different approaches as an exercise. It's a fun way to understand some design choices in both languages.

# TLDR

- Go uses a mixed algorithm with **quicksort**, **heap sort**, and **shell sort** for unstable sorts.
- Go uses **insertion sort** and **stable minimum storage merging** for stable sorts.
- Java uses **dual-pivot sort** for primitives, which is an unstable sort.
- Java uses **timsort**, a stable sorting algorithm for objects.
- I created a Go package **`jsort`** by porting the algorithms from Java. It can be imported from [github.com/openaphid/jsort](https://github.com/openaphid/jsort)
  - Public APIs for sorting slices are compatible with Go's built-in `sort` package, such as `jsort.Sort`, `jsort.Stable`, `jsort.Slice`, `jsort.SliceStable`, etc. They are all stable sorts using timsort, which could be 2-5x times faster than `sort.Stable` in the cost of extra space.
  - Specialized functions for primitive slices are provided using dual-pivot sort, such as `jsort.Ints`, `jsort.Int64s`, etc. They could be up to 3x times faster than `sort.Sort` and don't use extra space as well.

# Go's Sorting Algorithms

Sorting APIs need to support arbitrary slice types whose elements can be compared. It's usually straightforward to achieve it if a language supports generics. Go doesn't have generics for now and it's expected to be included in [v1.18 betas](https://blog.golang.org/11years) by the end of 2021. There are [alternatives ways](https://appliedgo.net/generics/) for generics in Go: code generation, type assertions, reflection, and interface abstraction.

Go's built-in [`sort`](https://golang.org/src/sort/) package mainly uses the interface abstraction approach combined with other techniques. The sorting algorithms depend on an interface [`sort.Interface`](https://golang.org/src/sort/sort.go) for three basic operations: Len, Less, and Swap.

```go
package sort

type Interface interface {
	Len() int
	Less(i, j int) bool
	Swap(i, j int)
}
```

`sort.Slice` function is present if we don't want to implement the interface sometimes. It leverages reflection to derive Len and Swap operations.

```go
func Slice(slice interface{}, less func(i, j int) bool) {
	rv := reflectValueOf(slice)
	swap := reflectSwapper(slice)
	length := rv.Len()
	quickSort_func(lessSwap{less, swap}, 0, length, maxDepth(length))
}

type lessSwap struct {
	Less func(i, j int) bool
	Swap func(i, j int)
}
```

`quickSort_func` function can be found in [zfuncversion.go](https://golang.org/src/sort/zfuncversion.go) that is generated from the `Interface` version of `quicksort` function by [genzfunc.go](https://golang.org/src/sort/genzfunc.go).

```go
// sort.go
//go:generate go run genzfunc.go
func quickSort(data Interface, a, b, maxDepth int) {}

// zfuncversion.go, generated by genzfunc.go from sort.go
func quickSort_func(data lessSwap, a, b, maxDepth int) {}
// 
```

"sort.go" implements two hybrid algorithms for unstable and stable sorts. The unstable algorithm in [`sort.Sort`](https://golang.org/pkg/sort/#Sort) has the following characteristics:
- It's a recursive in-place algorithm with logarithmic additional stack space, no explicit `make` calls for temporary space. 
- The implementation loosely follows `qsort` in glibc.
- The recursion depth is bound by `2*ceil(lg(n+1))`. It switches to heap sort once reaching the limit.
- If a subproblem has fewer than 12 elements, it runs one shell sort pass with gap 6, then applies insertion sort.

The stable algorithm in [`sort.Stable`](https://golang.org/pkg/sort/#Stable) uses another approach:
- It's also a recursive in-place algorithm with logarithmic additional stack space.
- It divides the input data into blocks with size 20, then runs insertion sort on all blocks.
- Sorted blocks are merged by `symMerge` function, which implements the [stable minimum storage merging](http://itbe.hanyang.ac.kr/ak/papers/esa2004.pdf) algorithm.

# JDK's Sorting Algorithms

In old JDK versions, Java uses a [tuned quicksort](http://hg.openjdk.java.net/jdk6/jdk6/jdk/file/8deef18bb749/src/share/classes/java/util/Arrays.java#l112) for primitive arrays. Sorting `Object[]` uses a [modified merge sort](http://hg.openjdk.java.net/jdk6/jdk6/jdk/file/8deef18bb749/src/share/classes/java/util/Arrays.java#l1090). Starting from JDK 1.7, the quicksort was upgraded to [dual-pivot sort](http://hg.openjdk.java.net/jdk7/jdk7/jdk/file/9b8c96f96a0f/src/share/classes/java/util/Arrays.java#l99) and the merge sort was replaced by [timsort](http://hg.openjdk.java.net/jdk7/jdk7/jdk/file/9b8c96f96a0f/src/share/classes/java/util/Arrays.java#l468).

Dual-pivot sort was first introduced to be faster in practice than the single-pivot variant by [Yaroslavskiy-Bloch-Bentley](https://mail.openjdk.java.net/pipermail/core-libs-dev/2009-September/002630.html) in 2009. It doesn't reduce the number of compare or swap operations. It's faster because of [fewer CPU cache misses](https://algs4.cs.princeton.edu/lectures/keynote/23Quicksort.pdf).

Timsort is an adaptive stable merge sort that takes advantage of existing orders in its input. It was invented by Time Peters in 2002 for Python. Besides Java, it's also adopted by [V8](https://v8.dev/blog/array-sort), [Swift](https://github.com/apple/swift/pull/19717), and [Rust](https://github.com/rust-lang/rust/pull/38192). It's proved to be faster in practice with a requirement of O(n/2) extra space. It's also a relatively complex sorting algorithm, several implementations were found to be [broken](http://www.envisage-project.eu/proving-android-java-and-python-sorting-algorithm-is-broken-and-how-to-fix-it/).

`jsort` is built upon the code of [DualPivotQuickSort.java](https://github.com/AdoptOpenJDK/openjdk-jdk11u/blob/master/src/java.base/share/classes/java/util/DualPivotQuicksort.java) and [TimSort.java](https://github.com/AdoptOpenJDK/openjdk-jdk11u/blob/master/src/java.base/share/classes/java/util/TimSort.java) in OpenJDK 11.

# Porting from Java to Go

Besides porting the algorithms in Go's idiomatic ways, I also played with some experimental solutions for evaluation only, such as using type assertions and Go2 generics.

## Primitive Types

[DualPivotQuicksort.java](https://github.com/AdoptOpenJDK/openjdk-jdk11u/blob/master/src/java.base/share/classes/java/util/DualPivotQuicksort.java) replicates the algorithm code for each primitive type as [Java doesn't support specializations](https://cr.openjdk.java.net/~briangoetz/valhalla/specialization.html). It's easier to accomplish it by using `go generate` in Go. A template file [sort_primitive.go](https://github.com/openaphid/jsort/blob/main/sort_primitive.go) implements the algorithm by utilizing some handy Go features:

```go
// +build ignore
//go:generate go run sort_primitive_gen.go

type primitive = int64 // Type placeholder to be replaced

func Sort(a []primitive) {} // dual-pivot sort

func IsSorted(a []primitive) bool {}
```

The `// +build ignore` flag excludes the template from the normal `go build`, and the alias `type primitive` creates a placeholder that's easy to be replaced by [sort_primitive_gen.go](https://github.com/openaphid/jsort/blob/main/sort_primitive_gen.go). The generator creates an internal package with specialized code and tests per primitive type, such as [internal/sort_int](https://github.com/openaphid/jsort/tree/main/internal/sort_int), [internal/sort_int64](https://github.com/openaphid/jsort/tree/main/internal/sort_int64), etc. Then [sort_export.go](https://github.com/openaphid/jsort/blob/main/sort_export.go) exports the internal symbols, such as `jsort.Ints` and `jsort.Int64s` functions. One beautiful feature of `go generate` is that generated code can be formatted before writing to files.

## Generic Slice Types

### #1 Attempt: Type Assertions

To support sorting generic slice types, I first experimented with type assertions in packages [sort_slice_dps_ts](https://github.com/openaphid/jsort/tree/main/internal/sort_slice_dps_ts) and [sort_slice_tim_ts](https://github.com/openaphid/jsort/tree/main/internal/sort_slice_tim_ts). The sort functions expect the data parameter to be a `[]interface{}` and a compare function. It looks like using `Object[]` and `Comparator<Object>` in Java.

```go
type CompareFunc = func(i, j interface{}) int

func SortInterfaces(a []interface{}, compare CompareFunc) {}
```

In Java, `Object[]` and `SomeClass[]` can be cast directly to each other without overhead costs. It's not the case for Go as `[]interface{}` and `[]SomeStruct` are two different types. We need a temporary space to help with the conversion by reflection:

```go
func Sort(a interface{}, compare CompareFunc) {
	rt := reflect.TypeOf(a)
	rv := reflect.ValueOf(a)
	elm := rt.Elem()
	n := rv.Len()
	interfaces := make([]interface{}, n)
	for i := 0; i < n; i++ {
		interfaces[i] = rv.Index(i).Interface()
	}

	SortInterfaces(interfaces, compare)

	for i := 0; i < n; i++ {
		rv.Index(i).Set(reflect.ValueOf(interfaces[i]).Convert(elm))
	}
}
```

Besides the additional space of `[]interface{}`, it requires extra cast operations from `interface{}` to the concrete type in the compare function, which is not cost-free. The two packages are not exported as using type assertions is not ideal both in speed and memory.

### #2 Approach: Interface Abstraction

My first thought was that timsort can't be built upon the built-in `sort.Interface` as the algorithm depends on more operations, such as indexed [read](https://github.com/AdoptOpenJDK/openjdk-jdk11u/blob/master/src/java.base/share/classes/java/util/TimSort.java#L283) and [write](https://github.com/AdoptOpenJDK/openjdk-jdk11u/blob/master/src/java.base/share/classes/java/util/TimSort.java#L318), [typed array creation](https://github.com/AdoptOpenJDK/openjdk-jdk11u/blob/master/src/java.base/share/classes/java/util/TimSort.java#L933), etc.

After reading the source code of Go's `sort` package more thoroughly, I realized that the key to interface abstraction is to not leak data type into sort algorithms. I came up with a better idea in the package [sort_slice_tim_interface](https://github.com/openaphid/jsort/tree/main/internal/sort_slice_tim_interface) for timsort to use `sort.Interface`:

```go
// sort_slice_tim_interface.go
func Sort(data sort.Interface) {
	// 1. Create a temporary `[]int` to hold the indices.
	n := data.Len()
	indices := make([]index, n)
	for i, _ := range indices {
		indices[i] = i
	}

	// 2. Run timsort on indices with data.Less function.
	sortInternal(indices, 0, n, data, nil, 0, 0)

	// 3. Rearrange data with data.Swap according to the sorted indices.
	for i, j := range indices {
		if i == j {
			continue
		}

		for indices[j] < 0 {
			j = -indices[j]
		}

		if i != j {
			data.Swap(i, j)
			indices[i] = -j
		}
	}
}
```

Now the function signature of `jsort.Sort` is the same as Go's `sort.Sort`. We can extend it to support `sort.Slice` with a helper struct [`lessSwap`](https://github.com/openaphid/jsort/blob/main/internal/sort_slice_tim_interface/sort_slice_tim_interface.go#L67):

```go
func Slice(data interface{}, less func(i, j int) bool) {
	rv := reflect.ValueOf(data)
	swap := reflect.Swapper(data)

	Sort(lessSwap{
		length: rv.Len(),
		less:   less,
		swap:   swap,
	})
}

type lessSwap struct {
	length int
	less   func(i, j int) bool
	swap   func(i, j int)
}

func (l lessSwap) Len() int {
	return l.length
}

func (l lessSwap) Less(i, j int) bool {
	return l.less(i, j)
}

func (l lessSwap) Swap(i, j int) {
	l.swap(i, j)
}

var _ sort.Interface = (*lessSwap)(nil)
```

Interface abstraction is usually the idiomatic techniques to solve tasks that need generics in Go. I'm happy that `jsort` can export timsort using the same APIs as Go's `sort` package. One thing to note is that `jsort.Sort` and `jsort.Stable` are the same functions of timsort while `sort.Sort` and `sort.Stable` are different, the rule applies to the functions of `Slice` and `SliceStable` too.

## #3 Experiment: Go2 Generics

Go team released an [experimentation tool](https://blog.golang.org/generics-next-step) **go2go** in June 2020. I built the tool locally by checking out a dev branch of Go, and wrote the two algorithms with generics syntax. It's impressive that I can build a full binary of a language in less than 5 minutes. 

The go2go tool translates a **".go2"** code file to a type specialized version in ".go" files. It is a heterogeneous translation, where different specializations have no typing relationship with each other. The translated code can be built and ran by Go 1.x. 

For example, we can declare the sort functions for dual-pivot sort and timsort with generics:

```go
// sort_slice_dps_go2.go2
type Primitive interface {
    type int, int8, int16, int32, int64,
      uint, uint8, uint16, uint32, uint64, uintptr,
      float32, float64,
      string
}

func DualPivotSort[T Primitive](a []T) {}

// sort_slice_tim_go2.go2
func Timsort[T any](a []T, compare func(i, j T) int) {}
```

As I wrote tests by calling the functions with `[]int` or `[]Person`, go2go generates specialized functions:

```go
// sort_slice_go2_test.go

// specialized dual-pivot sort for int
func instantiate୦୦DualPivotSort୦int(a []int,)

// timsort for Person
func instantiate୦୦Timsort୦sort_slice_go2୮aPerson(a []Person, compare func(i, j Person,) int){}
```

Oriya digit zero [୦ (U+0B66)](https://www.fileformat.info/info/unicode/char/0b66/index.htm) and Oriya digit eight [୮ (U+0B6E)](https://www.fileformat.info/info/unicode/char/0b6e/index.htm) are used as separators by go2go. The two characters are valid to use in Go's identifiers, go2go assumes no one uses these in their own code.

You can find the ".go2" code and the translated ".go" code in the package [sort_slice_go2](https://github.com/openaphid/jsort/tree/main/internal/sort_slice_go2). For this specific task, writing in Go's new generics syntax feels the same way as using Java's generics.

As go2go turns off `GO111MODULE`, it's not easy to make the go2 files share code with other packages. I can only play with the code inside the package.

# Mistakes

Most parts of porting were straightforward, I did make some mistakes that are worth noting:

- **`++` and `--` operators**. The Java code uses `a++` and `++a` in many places. As increment and decrement operators are not expressions in Go, it needs to be represented by two statements in Go. For example, the following Java code embeds an increment operator in an if statement:

```java
if (c.compare(a[runHi++], a[lo]) < 0) {
}
```

As the semantic is to increase `runHi` and use the old value in the if condition, the equivalent Go code is:

```go
runHi++
if c(a[runHi-1], a[lo]) < 0 {
}
```

- **loops**. Go has only one keyword for loops while Java has several alternatives. It gets trickier when it comes with increment and decrement operators. The following code is the insertion sort path in Java's dual-pivot sort:

```java
for (int i = left, j = i; i < right; j = ++i) {
    double ai = a[i + 1];
    while (ai < a[j]) {
        a[j + 1] = a[j];
        if (j-- == left) {
            break;
        }
    }
    a[j + 1] = ai;
}
```

The afterthought part has an increment operation and an assignment on two variables, it's translated to Go as below:

```go
for i, j := left, left; i < right; {
	var ai = a[i+1]
	for ai < a[j] {
		a[j+1] = a[j]
		j--
		if j+1 == left { // the condition needs the value before decrement
			break
		}
	}
	a[j+1] = ai

	// afterthought part
	i++
	j = i
}
```

- **switch**. Switch statements have implicit fall through behavior in Java, Go requires it to be explicitly declared. The following piece of timsort is an optimization for array copy when n is small.

```java
switch (n) {
    case 2:  a[left + 2] = a[left + 1];
    case 1:  a[left + 1] = a[left];
             break;
    default: System.arraycopy(a, left, a, left + 1, n);
}
```

I was fooled by it and wrote the wrong code in Go. The correct version is:

```go
switch {
case n <= 2:
	if n == 2 {
		a[left+2] = a[left+1]
	}
	if n != 0 {
		a[left+1] = a[left]
	}
default:
	copy(a[left+1:], a[left:left+n])
}
```

- **`>>>` operator**. There is no equivalent in Go for the unsigned right shift operation. There are two scenarios in Java code with it. One is to get the middle point without integer overflow, which is a [famous bug](https://ai.googleblog.com/2006/06/extra-extra-read-all-about-it-nearly.html) existing for years in history:

```java
int mid = (left + right) >>> 1
```

In Go, it should be converted to unsigned int first and then converted back:

```go
int(uint(left+right) >> 1)
```

Another place in Java is to compute the next smallest power of 2:

```java
// Compute smallest power of 2 > minCapacity
int newSize = -1 >>> Integer.numberOfLeadingZeros(minCapacity);
```

I don't know how to do it in one line Go, and use the idea from [bit twiddling hacks](https://graphics.stanford.edu/~seander/bithacks.html#RoundUpPowerOf2):

```go
newSize := minCapacity
newSize |= newSize >> 1
newSize |= newSize >> 2
newSize |= newSize >> 4
newSize |= newSize >> 8
newSize |= newSize >> 16
newSize++
```

# Benchmark

I must say that writing benchmarks in Go is more natural as it's built into Go's toolchain, while Java needs to setup [jmh](https://openjdk.java.net/projects/code-tools/jmh/) manually. 

[sort_benchmark_test.go](https://github.com/openaphid/jsort/blob/main/sort_benchmark_test.go) setups benchmarks on sorting int slice and struct slice. Two types of datasets are using in each benchmark scenario. One is random data, which means the elements are mostly unsorted with few duplicated data. The other uses XOR operation to compute data from index values, which makes the data partially sorted. The size of a dataset ranges from 256 to 65536.

```go
// random data
func prepareRandomInts(src []int) {
	rand.Seed(time.Now().Unix())
	for i := range src {
		src[i] = rand.Int()
	}
}

// xor data, eg. [716 717 718 719 712 713 714 715 708 709 710 711...]
func prepareXorInts(src []int) {
	for i := range src {
		src[i] = i ^ 0x2cc
	}
}
```

## #1 Benchmark: Number of Compares

Let's first check out the number of compares for each sorting algorithm by [sort_op_test.go](https://github.com/openaphid/jsort/blob/main/sort_op_test.go). You can run `make operation_stats` to see the numbers by yourself. We can find out that:

- Timsort always uses fewer compares than others. Its advantage is more significant in xor dataset benchmarks.
- Dual-Pivot sort needs more compares than others. 
- `sort.Sort` is not adaptive to data patterns. It uses almost the same amount of comparisons on random and xor datasets.
- `sort.Stable` uses fewer compares than `sort.Sort` on xor dataset and a bit more on random dataset.

<iframe title="Number of Compares" aria-label="Split Bars" id="datawrapper-chart-PlofX" src="https://datawrapper.dwcdn.net/PlofX/3/" scrolling="no" frameborder="0" style="width: 0; min-width: 100% !important; border: none;" height="514"></iframe><script type="text/javascript">!function(){"use strict";window.addEventListener("message",(function(a){if(void 0!==a.data["datawrapper-height"])for(var e in a.data["datawrapper-height"]){var t=document.getElementById("datawrapper-chart-"+e)||document.querySelector("iframe[src*='"+e+"']");t&&(t.style.height=a.data["datawrapper-height"][e]+"px")}}))}();
</script>

Theoretically speaking, timsort seems faster than others. But performance in the real world is affected by many other metrics. Let's run performance benchmarks to look into it.

## #2 Benchmark: Sort Ints

The [first set of benchmarks](https://github.com/openaphid/jsort/blob/main/sort_benchmark_test.go#L74) are for int slices. I tried to test all applicable APIs:

- **Dps-SpecializedInts** uses `jsort.Ints` which is the specialized dual-pivot sort for int.
- **BuiltinSort-SpecializedInts** uses a specialized version of Go's built-in unstable sorting algorithm, which I created manually in [sort_builtin_specialized_test.go](https://github.com/openaphid/jsort/blob/main/sort_builtin_specialized_test.go).
- **BuiltinSort-Slice** uses the built-in `sort.Slice` function.
- **BuiltinSort-Sort** uses `sort.Sort` function.
- **TimSort-Interface** calls `jsort.Sort` which is timsort.
- **TimSort-Slice** calls `jsort.Slice` function.
- **BuiltinSort-SliceStable** uses `sort.SliceStable` function. It's present for evaluation only as it doesn't make sense to use stable sort for primitives.
- **BuiltinSort-Stable** uses `sort.Stable` function.
- **Dps-TypeAssertion** and **TimSort-TypeAssertion** use the type assertions variants of dual-pivot sort and timsort. They are expected to be less efficient.

"Dps-SpecializedInts" and "BuiltinSort-Sort" are the recommended APIs to sort int slice in practice. I highlighted them in the chart. 

<iframe title="Sort Ints" aria-label="Split Bars" id="datawrapper-chart-PusM1" src="https://datawrapper.dwcdn.net/PusM1/3/" scrolling="no" frameborder="0" style="width: 0; min-width: 100% !important; border: none;" height="946"></iframe><script type="text/javascript">!function(){"use strict";window.addEventListener("message",(function(a){if(void 0!==a.data["datawrapper-height"])for(var e in a.data["datawrapper-height"]){var t=document.getElementById("datawrapper-chart-"+e)||document.querySelector("iframe[src*='"+e+"']");t&&(t.style.height=a.data["datawrapper-height"][e]+"px")}}))}();
</script>

The numbers on sorting random ints could give us some findings:

- `jsort.Ints` can be 3x times faster than Go's `sort.Ints` function. Both use zero extra space as they sort in-place. It explains well why Java adopted dual-pivot sort.
- The performance hit of interface abstraction can not be ignored. "BuiltinSort-SpecializedInts" is much faster by shedding the overhead, although it's 10%~20% slower than `jsort.Ints`.
- Timsort is not faster on random data when the comparison cost is low.
- Using type assertions is the slowest as expected, and it also consumes the most extra space due to the type conversions.
- `sort.Slice` is faster than `sort.Sort` on int slices while the result is reversed on `jsort.Slice` and `jsort.Sort`. I don't know the reason yet.
- `sort.Stable` is the slowest.

Tests on xor data tell us more stories: 

- `jsort.Ints` can be 5x times faster than `sort.Ints`.
- Both dual-pivot sort and timsort perform much better. Timsort can be faster than the built-in sorting algorithms.

## #3 Benchmark: Sort Structs

[Another set of benchmarks](https://github.com/openaphid/jsort/blob/main/sort_benchmark_test.go#L319) are sorting slice of a struct that has one int field and one string field:

```go
type Person struct {
	Age  int
	Name string
}
```

The benchmarks test all APIs that can sort `[]Person` by the `Name` field, its value is a string from random int or XOR computed int.

- **Unstable-BuiltinSort-Sort** uses Go's `sort.Sort`, which is an unstable sort.
- **Stable-TimSort-Interface** uses `jsort.Sort`, which is a stable sort.
- **Unstable-BuiltinSort-Slice** uses `sort.Slice`, which is also an unstable sort.
- **Stable-TimSort-Slice** calls `jsort.Slice`.
- **Stable-BuiltinSort-Stable** calls `sort.Stable`.
- **Unstable-Dps-TypeAssertion** and **Stable-TimSort-TypeAssertion** test the type assertions version of the two algorithms.
- **Stable-BuiltinSort-SliceStable** calls `sort.SliceStable`.

Stable sorts are preferred for structs in practice. They are highlighted in the chart.

<iframe title="Sort By Name" aria-label="Split Bars" id="datawrapper-chart-ZH9Hu" src="https://datawrapper.dwcdn.net/ZH9Hu/1/" scrolling="no" frameborder="0" style="width: 0; min-width: 100% !important; border: none;" height="802"></iframe><script type="text/javascript">!function(){"use strict";window.addEventListener("message",(function(a){if(void 0!==a.data["datawrapper-height"])for(var e in a.data["datawrapper-height"]){var t=document.getElementById("datawrapper-chart-"+e)||document.querySelector("iframe[src*='"+e+"']");t&&(t.style.height=a.data["datawrapper-height"][e]+"px")}}))}();
</script>

From the random names dataset benchmarks, we can collect some insights:

- `jsort.Sort` is the fastest among all stable sort APIs. It's 15% slower than `sort.Sort` which is an unstable sort, and it's 50%~100% faster than `sort.Stable`.
- Timsort needs extra space.
- `sort.SliceStable` can be 100% slower than `sort.Stable`, while the gap is 20% for `jsort.Slice` and `jsort.Sort`.

On the xor names dataset, `jsort.Sort` is the clearing winner on speed. It's even faster than `sort.Sort`.

## #4 Benchmark: Go2 Generics

How does the experimental Go2 generics perform on the same tasks? As GO111MODULE is turned off by go2go, I can't import `jsort` package in a go2 file. The benchmark only compares the go2 version of dual-pivot sort and timsort to the built-in sort functions.

<iframe title="Go2 - Sort Ints" aria-label="Split Bars" id="datawrapper-chart-e8FOA" src="https://datawrapper.dwcdn.net/e8FOA/2/" scrolling="no" frameborder="0" style="width: 0; min-width: 100% !important; border: none;" height="514"></iframe><script type="text/javascript">!function(){"use strict";window.addEventListener("message",(function(a){if(void 0!==a.data["datawrapper-height"])for(var e in a.data["datawrapper-height"]){var t=document.getElementById("datawrapper-chart-"+e)||document.querySelector("iframe[src*='"+e+"']");t&&(t.style.height=a.data["datawrapper-height"][e]+"px")}}))}();
</script>

<iframe title="Go2 - Sort By Name" aria-label="Split Bars" id="datawrapper-chart-jv7KV" src="https://datawrapper.dwcdn.net/jv7KV/2/" scrolling="no" frameborder="0" style="width: 0; min-width: 100% !important; border: none;" height="586"></iframe><script type="text/javascript">!function(){"use strict";window.addEventListener("message",(function(a){if(void 0!==a.data["datawrapper-height"])for(var e in a.data["datawrapper-height"]){var t=document.getElementById("datawrapper-chart-"+e)||document.querySelector("iframe[src*='"+e+"']");t&&(t.style.height=a.data["datawrapper-height"][e]+"px")}}))}();
</script>

- The translated code of "Dps-Go2" is basically the same as "Dps-SpecializedInts", it's no surprise that it's the fastest for int slice. 
- The speed of "Timsort-Go2" is on par with "Stable-TimSort-Interface", but it uses more extra space as it internally allocates `[]Person` instead of `[]int`. If the size of the struct `Person` increases, more space would be needed.

# Conclusion

Go's sort functions can be improved for better performance by using other algorithms. If sorting speed is critical to your application, please give [jsort](https://github.com/openaphid/jsort) package a try.
