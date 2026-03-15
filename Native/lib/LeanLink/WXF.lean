/-
  WXF (Wolfram Exchange Format) binary serializer for Lean 4.
  Implements the WXF 1.0 format as documented in:
  https://reference.wolfram.com/language/tutorial/WXFFormatDescription.html

  Token bytes:
    f = 0x66 (102) — function: varint(argCount), head, arg₁, ..., argₙ
    s = 0x73 (115) — symbol:   varint(len), UTF-8 bytes
    S = 0x53 (83)  — string:   varint(len), UTF-8 bytes
    C = 0x43 (67)  — int8:     1 byte signed
    D = 0x44 (68)  — int16:    2 bytes LE
    E = 0x45 (69)  — int32:    4 bytes LE
    F = 0x46 (70)  — int64:    8 bytes LE
    A = 0x41 (65)  — association: varint(count), rule₁, ..., ruleₙ
    - = 0x2D (45)  — rule (in association): key, value
    : = 0x3A (58)  — rule delayed: key, value
-/
import Lean

namespace WXF

/-- WXF header: version 1.0 -/
def header : ByteArray :=
  ⟨#[56, 58]⟩  -- "8:"

/-- Encode a non-negative integer as a varint (LEB128-style) -/
def encodeVarint (n : Nat) : ByteArray :=
  if n < 128 then
    ⟨#[n.toUInt8]⟩
  else
    let lo : UInt8 := (n % 128).toUInt8 ||| 128
    ⟨#[lo]⟩ ++ encodeVarint (n / 128)

/-- Token for WL Symbol: 's' + varint(len) + UTF-8 bytes -/
def symbol (name : String) : ByteArray :=
  let bytes := name.toUTF8
  ⟨#[115]⟩ ++ encodeVarint bytes.size ++ bytes

/-- Token for WL String: 'S' + varint(len) + UTF-8 bytes -/
def string (s : String) : ByteArray :=
  let bytes := s.toUTF8
  ⟨#[83]⟩ ++ encodeVarint bytes.size ++ bytes

/-- Token for machine int8: 'C' + 1 byte -/
def int8 (n : Int) : ByteArray :=
  ⟨#[67, (n % 256).toNat.toUInt8]⟩

/-- Token for machine int32: 'E' + 4 bytes LE -/
def int32 (n : Int) : ByteArray :=
  let v := n.toNat
  ⟨#[69,
    (v % 256).toUInt8,
    ((v / 256) % 256).toUInt8,
    ((v / 65536) % 256).toUInt8,
    ((v / 16777216) % 256).toUInt8]⟩

/-- Token for machine int64: 'F' + 8 bytes LE -/
def int64 (n : Int) : ByteArray :=
  let v := n.toNat
  ⟨#[70,
    (v % 256).toUInt8,
    ((v / 256) % 256).toUInt8,
    ((v / 65536) % 256).toUInt8,
    ((v / 16777216) % 256).toUInt8,
    ((v / (2^32)) % 256).toUInt8,
    ((v / (2^40)) % 256).toUInt8,
    ((v / (2^48)) % 256).toUInt8,
    ((v / (2^56)) % 256).toUInt8]⟩

/-- Encode an integer using the smallest representation -/
def integer (n : Int) : ByteArray :=
  if -128 ≤ n && n ≤ 127 then int8 n
  else if -2147483648 ≤ n && n ≤ 2147483647 then int32 n
  else int64 n

/-- Token for function: 'f' + varint(argCount) + head + args -/
def function (argCount : Nat) : ByteArray :=
  ⟨#[102]⟩ ++ encodeVarint argCount

/-- Token for association: 'A' + varint(count) -/
def association (count : Nat) : ByteArray :=
  ⟨#[65]⟩ ++ encodeVarint count

/-- Token for Rule in association: '-' -/
def rule : ByteArray := ⟨#[45]⟩

/-- Build a complete WXF message with header -/
def serialize (body : ByteArray) : ByteArray :=
  header ++ body

-- ============================================================================
-- High-level builders
-- ============================================================================

/-- Build a WL symbol like "LeanLink`LeanConst" -/
def wlSymbol (ctx : String) (name : String) : ByteArray :=
  symbol (ctx ++ "`" ++ name)

/-- Build a WL function application: Head[arg1, arg2, ...] -/
def wlFunction (head : ByteArray) (args : Array ByteArray) : ByteArray :=
  function args.size ++ head ++ args.foldl (· ++ ·) ByteArray.empty

/-- Build a WL List: {a, b, c} = List[a, b, c] -/
def wlList (elems : Array ByteArray) : ByteArray :=
  wlFunction (symbol "List") elems

/-- Build a WL Rule: key -> value -/
def wlRule (key : ByteArray) (val : ByteArray) : ByteArray :=
  wlFunction (symbol "Rule") #[key, val]

/-- Build a WL Association: <|key1 -> val1, ...| > -/
def wlAssociation (entries : Array (ByteArray × ByteArray)) : ByteArray :=
  association entries.size ++ entries.foldl (fun acc (k, v) => acc ++ rule ++ k ++ v) ByteArray.empty

-- ============================================================================
-- Lean-specific serializers
-- ============================================================================

def ctx := "LeanLink"

/-- Serialize a Lean Name to WXF string -/
def nameToWXF (n : Lean.Name) : ByteArray :=
  string n.toString

/-- Serialize a Lean universe Level to WXF -/
partial def levelToWXF (l : Lean.Level) : ByteArray := match l with
  | .zero => wlFunction (wlSymbol ctx "LeanLevelZero") #[]
  | .succ inner => wlFunction (wlSymbol ctx "LeanLevelSucc") #[levelToWXF inner]
  | .max l1 l2 => wlFunction (wlSymbol ctx "LeanLevelMax") #[levelToWXF l1, levelToWXF l2]
  | .imax l1 l2 => wlFunction (wlSymbol ctx "LeanLevelIMax") #[levelToWXF l1, levelToWXF l2]
  | .param n => wlFunction (wlSymbol ctx "LeanLevelParam") #[nameToWXF n]
  | .mvar n => wlFunction (wlSymbol ctx "LeanLevelMVar") #[nameToWXF n.name]

/-- Convert BinderInfo to string -/
def binderInfoStr (bi : Lean.BinderInfo) : String := match bi with
  | .default => "default"
  | .implicit => "implicit"
  | .strictImplicit => "strictImplicit"
  | .instImplicit => "instImplicit"

/-- Serialize a Lean Expr to WXF (with depth limit).
    At depth 0, terminal nodes (bvar, const, sort, lit) serialize fully.
    Compound nodes serialize as 0-arg heads to preserve identity. -/
partial def exprToWXF (e : Lean.Expr) (depth : Nat := 100) : ByteArray :=
  if depth == 0 then match e with
    -- Terminals: always serialize fully (no children)
    | .bvar idx => wlFunction (wlSymbol ctx "LeanBVar") #[integer idx]
    | .fvar id => wlFunction (wlSymbol ctx "LeanFVar") #[nameToWXF id.name]
    | .mvar id => wlFunction (wlSymbol ctx "LeanMVar") #[nameToWXF id.name]
    | .sort level => wlFunction (wlSymbol ctx "LeanSort") #[levelToWXF level]
    | .const name levels =>
      wlFunction (wlSymbol ctx "LeanConst") #[
        nameToWXF name, wlList (levels.map levelToWXF).toArray]
    | .lit (.natVal n) => wlFunction (wlSymbol ctx "LeanLitNat") #[integer n]
    | .lit (.strVal s) => wlFunction (wlSymbol ctx "LeanLitStr") #[string s]
    -- Compound: head only, no children
    | .app _ _ => wlFunction (wlSymbol ctx "LeanApp") #[]
    | .lam name _ _ bi =>
      wlFunction (wlSymbol ctx "LeanLam") #[nameToWXF name, string (binderInfoStr bi)]
    | .forallE name _ _ bi =>
      wlFunction (wlSymbol ctx "LeanForall") #[nameToWXF name, string (binderInfoStr bi)]
    | .letE name _ _ _ _ =>
      wlFunction (wlSymbol ctx "LeanLet") #[nameToWXF name]
    | .proj typeName idx _ =>
      wlFunction (wlSymbol ctx "LeanProj") #[nameToWXF typeName, integer idx]
    | .mdata _ inner => exprToWXF inner 0
  else match e with
  | .bvar idx =>
    wlFunction (wlSymbol ctx "LeanBVar") #[integer idx]
  | .fvar id =>
    wlFunction (wlSymbol ctx "LeanFVar") #[nameToWXF id.name]
  | .mvar id =>
    wlFunction (wlSymbol ctx "LeanMVar") #[nameToWXF id.name]
  | .sort level =>
    wlFunction (wlSymbol ctx "LeanSort") #[levelToWXF level]
  | .const name levels =>
    wlFunction (wlSymbol ctx "LeanConst") #[
      nameToWXF name,
      wlList (levels.map levelToWXF).toArray]
  | .app fn arg =>
    wlFunction (wlSymbol ctx "LeanApp") #[
      exprToWXF fn (depth - 1),
      exprToWXF arg (depth - 1)]
  | .lam name ty body bi =>
    wlFunction (wlSymbol ctx "LeanLam") #[
      nameToWXF name,
      exprToWXF ty (depth - 1),
      exprToWXF body (depth - 1),
      string (binderInfoStr bi)]
  | .forallE name ty body bi =>
    wlFunction (wlSymbol ctx "LeanForall") #[
      nameToWXF name,
      exprToWXF ty (depth - 1),
      exprToWXF body (depth - 1),
      string (binderInfoStr bi)]
  | .letE name ty val body _ =>
    wlFunction (wlSymbol ctx "LeanLet") #[
      nameToWXF name,
      exprToWXF ty (depth - 1),
      exprToWXF val (depth - 1),
      exprToWXF body (depth - 1)]
  | .lit (.natVal n) =>
    wlFunction (wlSymbol ctx "LeanLitNat") #[integer n]
  | .lit (.strVal s) =>
    wlFunction (wlSymbol ctx "LeanLitStr") #[string s]
  | .proj typeName idx struct =>
    wlFunction (wlSymbol ctx "LeanProj") #[
      nameToWXF typeName,
      integer idx,
      exprToWXF struct (depth - 1)]
  | .mdata _ e =>
    exprToWXF e (depth - 1)  -- skip metadata

/-- Serialize a ConstantInfo kind string -/
def constantKind (ci : Lean.ConstantInfo) : String := match ci with
  | .axiomInfo _ => "axiom"
  | .defnInfo _ => "def"
  | .thmInfo _ => "theorem"
  | .opaqueInfo _ => "opaque"
  | .quotInfo _ => "quot"
  | .inductInfo _ => "inductive"
  | .ctorInfo _ => "constructor"
  | .recInfo _ => "recursor"

/-- Serialize a ConstantInfo to WXF as LeanTheorem[name, kind, type, value] -/
def constantToWXF (ci : Lean.ConstantInfo) : ByteArray :=
  let name := nameToWXF ci.name
  let kind := string (constantKind ci)
  let type := exprToWXF ci.type
  let value := match ci.value? with
    | some v => exprToWXF v
    | none => wlFunction (wlSymbol ctx "LeanNoValue") #[]
  wlFunction (wlSymbol ctx "LeanConstant") #[name, kind, type, value]

-- ============================================================================
-- WXF Deserializer: ByteArray → Lean.Expr
-- ============================================================================

structure ParseState where
  data : ByteArray
  pos : Nat
  deriving Inhabited

abbrev Parser (α : Type) := ParseState → Option (α × ParseState)

def peek (s : ParseState) : Option UInt8 :=
  if s.pos < s.data.size then some (s.data.get! s.pos) else none

def readByte (s : ParseState) : Option (UInt8 × ParseState) :=
  if s.pos < s.data.size then some (s.data.get! s.pos, { s with pos := s.pos + 1 })
  else none

def readVarint (s : ParseState) : Option (Nat × ParseState) :=
  let rec go (shift : Nat) (acc : Nat) (st : ParseState) : (fuel : Nat) → Option (Nat × ParseState)
    | 0 => none
    | fuel + 1 => match readByte st with
      | none => none
      | some (b, st') =>
        let val := acc + ((b.toNat &&& 0x7F) <<< shift)
        if b.toNat &&& 0x80 == 0 then some (val, st')
        else go (shift + 7) val st' fuel
  go 0 0 s 10

def readString (s : ParseState) : Option (String × ParseState) :=
  match readVarint s with
  | none => none
  | some (len, s') =>
    if s'.pos + len > s'.data.size then none
    else
      let bytes := s'.data.extract s'.pos (s'.pos + len)
      some (String.fromUTF8! bytes, { s' with pos := s'.pos + len })

def readInt (s : ParseState) (nbytes : Nat) : Option (Int × ParseState) :=
  if s.pos + nbytes > s.data.size then none
  else
    let val := (List.range nbytes).foldl (fun acc i =>
      acc + (s.data.get! (s.pos + i)).toNat <<< (i * 8)) 0
    let signed : Int := if nbytes > 0 && val >= (1 <<< (nbytes * 8 - 1))
      then (val : Int) - (1 <<< (nbytes * 8))
      else (val : Int)
    some (signed, { s with pos := s.pos + nbytes })

/-- A parsed WXF value -/
inductive WVal where
  | sym : String → WVal
  | str : String → WVal
  | int : Int → WVal
  | fn : String → Array WVal → WVal  -- head symbol name + args
  | list : Array WVal → WVal
  deriving Inhabited

/-- Parse a single WXF value -/
partial def parseWVal (s : ParseState) : Option (WVal × ParseState) :=
  match readByte s with
  | none => none
  | some (tag, s') =>
    if tag == 115 then -- 's' = symbol
      match readString s' with
      | none => none
      | some (name, s'') => some (.sym name, s'')
    else if tag == 83 then -- 'S' = string
      match readString s' with
      | none => none
      | some (str, s'') => some (.str str, s'')
    else if tag == 67 then -- 'C' = int8
      match readInt s' 1 with
      | none => none
      | some (n, s'') => some (.int n, s'')
    else if tag == 68 then -- 'D' = int16
      match readInt s' 2 with
      | none => none
      | some (n, s'') => some (.int n, s'')
    else if tag == 69 then -- 'E' = int32
      match readInt s' 4 with
      | none => none
      | some (n, s'') => some (.int n, s'')
    else if tag == 70 then -- 'F' = int64
      match readInt s' 8 with
      | none => none
      | some (n, s'') => some (.int n, s'')
    else if tag == 102 then -- 'f' = function
      match readVarint s' with
      | none => none
      | some (argCount, s'') =>
        match parseWVal s'' with -- parse head
        | none => none
        | some (head, s''') =>
          let headName := match head with | .sym n => n | _ => ""
          let rec parseArgs (remaining : Nat) (acc : Array WVal) (st : ParseState) : Option (Array WVal × ParseState) :=
            if remaining == 0 then some (acc, st)
            else match parseWVal st with
            | none => none
            | some (v, st') => parseArgs (remaining - 1) (acc.push v) st'
          match parseArgs argCount #[] s''' with
          | none => none
          | some (args, s4) =>
            if headName == "List" then some (.list args, s4)
            else some (.fn headName args, s4)
    else none  -- unsupported token

/-- Convert parsed WVal to Lean Level -/
partial def wvalToLevel : WVal → Option Lean.Level
  | .fn "LeanLink`LeanLevelZero" _ => some .zero
  | .fn "LeanLink`LeanLevelSucc" #[inner] => do
    let l ← wvalToLevel inner; return .succ l
  | .fn "LeanLink`LeanLevelMax" #[a, b] => do
    let la ← wvalToLevel a; let lb ← wvalToLevel b; return .max la lb
  | .fn "LeanLink`LeanLevelIMax" #[a, b] => do
    let la ← wvalToLevel a; let lb ← wvalToLevel b; return .imax la lb
  | .fn "LeanLink`LeanLevelParam" #[.str name] => some (.param name.toName)
  | .fn "LeanLink`LeanLevelMVar" #[.str name] => some (.mvar ⟨name.toName⟩)
  | _ => none

/-- Convert parsed WVal to BinderInfo -/
def wvalToBinderInfo : WVal → Lean.BinderInfo
  | .str "implicit" => .implicit
  | .str "strictImplicit" => .strictImplicit
  | .str "instImplicit" => .instImplicit
  | _ => .default

/-- Convert parsed WVal to Lean Expr -/
partial def wvalToExpr : WVal → Option Lean.Expr
  | .fn "LeanLink`LeanBVar" #[.int idx] => some (.bvar idx.toNat)
  | .fn "LeanLink`LeanFVar" #[.str name] => some (.fvar ⟨name.toName⟩)
  | .fn "LeanLink`LeanMVar" #[.str name] => some (.mvar ⟨name.toName⟩)
  | .fn "LeanLink`LeanSort" #[lvl] => do
    let l ← wvalToLevel lvl; return .sort l
  | .fn "LeanLink`LeanConst" #[.str name, .list levels] => do
    let ls ← levels.mapM wvalToLevel
    return .const name.toName ls.toList
  | .fn "LeanLink`LeanApp" #[fn, arg] => do
    let f ← wvalToExpr fn; let a ← wvalToExpr arg; return .app f a
  | .fn "LeanLink`LeanForall" #[.str name, dom, body, bi] => do
    let d ← wvalToExpr dom; let b ← wvalToExpr body
    return .forallE name.toName d b (wvalToBinderInfo bi)
  | .fn "LeanLink`LeanLam" #[.str name, ty, body, bi] => do
    let t ← wvalToExpr ty; let b ← wvalToExpr body
    return .lam name.toName t b (wvalToBinderInfo bi)
  | .fn "LeanLink`LeanLet" #[.str name, ty, val, body] => do
    let t ← wvalToExpr ty; let v ← wvalToExpr val; let b ← wvalToExpr body
    return .letE name.toName t v b false
  | .fn "LeanLink`LeanLitNat" #[.int n] => some (.lit (.natVal n.toNat))
  | .fn "LeanLink`LeanLitStr" #[.str s] => some (.lit (.strVal s))
  | .fn "LeanLink`LeanProj" #[.str name, .int idx, struct] => do
    let s ← wvalToExpr struct; return .proj name.toName idx.toNat s
  | _ => none

/-- Deserialize WXF bytes (without header) into Lean Expr -/
def deserializeExpr (bytes : ByteArray) : Option Lean.Expr :=
  -- Skip WXF header "8:" (2 bytes)
  let startPos := if bytes.size >= 2 && bytes.get! 0 == 56 && bytes.get! 1 == 58
    then 2 else 0
  match parseWVal ⟨bytes, startPos⟩ with
  | none => none
  | some (wval, _) => wvalToExpr wval

end WXF
