---
Template: Symbol
Name: LeanProj
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanProj
Keywords: [Lean, projection, structure, field, CIC]
SeeAlso: [LeanConst, LeanFVar, LeanApp]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanProj]()[*typeName*, *fieldIndex*, *struct*]</code> represents a structure-field projection: the field at *fieldIndex* of the structure *struct*, whose type is *typeName*.

## Details & Options

- *fieldIndex* is 0-based. Projections are how Lean accesses the components of a structure (the two sides of an `And`, the fields of a record).
- It renders as `struct.fieldIndex`.

## Basic Examples

Project the first field of an `And` hypothesis `h`:

```wl
LeanProj["And", 0, LeanFVar["h"]]
```

<!-- => renders as: h.0 -->
