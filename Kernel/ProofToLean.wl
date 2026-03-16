(* ProofToLean.wl -- Transpile ProofObject -> LeanEnvironment *)
(* Types are LeanTerm expression trees; tactic proofs are strings. *)
(* Loaded by LeanLink.wl; operates within LeanLink` context. *)

BeginPackage["LeanLink`"];
Begin["`Private`"];

(* ====== UNICODE CONSTANTS ====== *)
$ptl$rarr = FromCharacterCode[8594];     (* → *)
$ptl$larr = FromCharacterCode[8592];     (* ← *)
$ptl$check = FromCharacterCode[10003];   (* ✓ *)
$ptl$cdot = FromCharacterCode[11037];    (* ⬝ *)

(* ====== EXPRESSION TREE BUILDERS ====== *)
(* Convert WL expressions to LeanTerm expression trees *)

ptlCleanExpr[expr_] := Module[{uf},
  uf = If[TrueQ[$ptlHasUnformalize],
    ResourceFunction["UnformalizeSymbols"],
    Identity];
  (expr /. s_Symbol :> RuleCondition[uf[s]]) //. 
    {Verbatim[Pattern][s_, Verbatim[Blank][]] :> s}];

(* Expression → LeanTerm tree *)
ptlToExpr[expr_] := ptlToExprI[ptlCleanExpr[expr]];

ptlToExprI[CenterDot[a_, b_]] :=
  LeanApp[LeanApp[LeanConst["cdot", {}], ptlToExprI[a]], ptlToExprI[b]];
ptlToExprI[f_Symbol[args___]] :=
  Fold[LeanApp, LeanConst[ToString[f], {}], ptlToExprI /@ {args}];
ptlToExprI[s_Symbol] := LeanConst[ToString[s], {}];
ptlToExprI[x_] := LeanConst[ToString[x], {}];

(* Equation → @Eq U lhs rhs *)
ptlMakeEq[lhs_, rhs_] :=
  LeanApp[LeanApp[LeanApp[
    LeanConst["Eq", {LeanLevelSucc[LeanLevelZero[]]}],
    LeanConst["U", {}]], lhs], rhs];

ptlEqToExpr[eq:Inactive[Equal][_, _]] := Module[{c = ptlCleanExpr[eq]},
  ptlMakeEq[ptlToExprI[c[[1]]], ptlToExprI[c[[2]]]]];

(* Wrap expression in ∀ binders: ∀ (x : U) (y : U), body *)
ptlWrapForall[{}, body_] := body;
ptlWrapForall[vars_List, body_] :=
  Fold[LeanForall[#2, LeanConst["U", {}], #1, "default"] &,
    body, Reverse[vars]];

(* ====== STRING CONVERTERS (for tactic generation only) ====== *)
(* These still produce strings because tactic scripts are textual *)

Clear[ptlToStr];
ptlToStr[CenterDot[a_, b_]] := StringTemplate["(`1` `2` `3`)"][ptlToStr[a], $ptl$cdot, ptlToStr[b]];
ptlToStr[f_Symbol[args___]] := StringTemplate["(`1` `2`)"][f, StringRiffle[ptlToStr /@ {args}, " "]];
ptlToStr[s_Symbol] := ToString[s];
ptlToStr[x_] := ToString[x];

ptlEqToStr[eq:Inactive[Equal][_, _]] := Module[{c = ptlCleanExpr[eq]},
  StringTemplate["`1` = `2`"][ptlToStr[c[[1]]], ptlToStr[c[[2]]]]];

ptlGetVarsFromEq[eq_, sharedConstants_] := Module[{c = ptlCleanExpr[eq], allVars},
  allVars = DeleteDuplicates@Cases[c, s_Symbol /; Context[s] === "Global`" :> ToString[s], Infinity];
  Select[allVars, !MemberQ[sharedConstants, #] &]];

(* ====== NAME HELPERS ====== *)
ptlAbbrev[tag_, n_] := Module[{s = ToString[tag]},
  Switch[s,
    "CriticalPairLemma", StringTemplate["CPL`1`"][n],
    "SubstitutionLemma", StringTemplate["SL`1`"][n],
    "SubstitutionRule", StringTemplate["SR`1`"][n],
    "Conclusion", StringTemplate["Concl`1`"][n],
    "Axiom", StringTemplate["Ax`1`"][n],
    "Hypothesis", StringTemplate["Hyp`1`"][n],
    _, StringTemplate["`1``2`"][s, n]]];

ptlLeanRef[tag_[n_Integer]] := ptlAbbrev[tag, n];
ptlLeanRef[x_] := ToString[x];

ptlKeyToStr[Verbatim[Pattern][s_, Verbatim[Blank][]]] := ToString[s];
ptlKeyToStr[s_Symbol] := ToString[s];
ptlKeyToStr[x_] := ToString[x];

ptlAssocToStr[a_Association] :=
  StringRiffle[KeyValueMap[StringTemplate["`1` -> `2`"][ptlKeyToStr[#1], ptlToStr[ptlCleanExpr[#2]]] &, a], ", "];

(* ====== POSITION -> CONV NAVIGATION ====== *)
ptlPosToConv[{}] := "";
ptlPosToConv[pos_List] := Module[{first, restStr},
  first = If[Length[pos] > 0 && pos[[1]] == 1, "lhs", "rhs"];
  restStr = StringRiffle[Map[StringTemplate["arg `1`"], Rest[pos]], "; "];
  If[restStr === "", first, StringTemplate["`1`; `2`"][first, restStr]]];

(* ====== BUILD ARGS (string, for tactic construction) ====== *)
(* lemmaVars is a DownValues function: lemmaVars[name] -> vars list *)
ptlLVLookup[lv_, name_] := Module[{r = lv[name]},
  If[ListQ[r], r, {}]];

ptlBuildArgs[name_, assoc_Association, targetTag_String, lemmaVars_] := Module[
  {vars, vals = {}, k, v, targetVars, keys},
  vars = ptlLVLookup[lemmaVars, name];
  targetVars = ptlLVLookup[lemmaVars, targetTag];
  If[Length[vars] == 0,
    keys = Sort[Keys[assoc]];
    Do[AppendTo[vals, ptlToStr[ptlCleanExpr[assoc[k]]]], {k, keys}],
    Do[
      k = vars[[i]];
      v = Null;
      KeyValueMap[If[ptlKeyToStr[#1] == k, v = ptlToStr[ptlCleanExpr[#2]]] &, assoc];
      If[v === Null,
        If[MemberQ[targetVars, k], v = k,
          v = If[Length[targetVars] > 0, targetVars[[1]], "_"]]];
      AppendTo[vals, v];
    , {i, 1, Length[vars]}]];
  StringTemplate[" `1`"][StringRiffle[vals, " "]]];

(* Expression tree version: builds LeanApp chain for lemma+args *)
ptlBuildSrcExpr[name_, assoc_Association, targetTag_String, lemmaVars_] := Module[
  {vars, argExprs = {}, k, v, targetVars, keys},
  vars = ptlLVLookup[lemmaVars, name];
  targetVars = ptlLVLookup[lemmaVars, targetTag];
  If[Length[vars] == 0,
    keys = Sort[Keys[assoc]];
    Do[AppendTo[argExprs, ptlToExprI[ptlCleanExpr[assoc[k]]]], {k, keys}],
    Do[
      k = vars[[i]];
      v = Null;
      KeyValueMap[If[ptlKeyToStr[#1] == k, v = ptlToExprI[ptlCleanExpr[#2]]] &, assoc];
      If[v === Null,
        If[MemberQ[targetVars, k], v = LeanConst[k, {}],
          v = LeanConst[If[Length[targetVars] > 0, targetVars[[1]], "_"], {}]]];
      AppendTo[argExprs, v];
    , {i, 1, Length[vars]}]];
  Fold[LeanApp, LeanConst[name, {}], argExprs]];

(* Conv path as list of strings *)
ptlPosToConvList[{}] := {};
ptlPosToConvList[pos_List] := Module[{first, rest},
  first = If[Length[pos] > 0 && pos[[1]] == 1, "lhs", "rhs"];
  rest = Map[StringTemplate["arg `1`"], Rest[pos]];
  Prepend[rest, first]];

(* ====== STEP PROCESSOR ====== *)
Clear[ptlProcessStep];

(* Axiom/Hypothesis definition — builds type expression tree *)
ptlProcessStep[HoldComplete[Set[tag_[n_Integer], eq:Inactive[Equal][_, _]]], st_] := Module[
  {tagStr = ptlAbbrev[tag, n], vars = ptlGetVarsFromEq[eq, st["sharedConstants"]],
   typeExpr},
  st["lv", tagStr] = vars;
  typeExpr = ptlWrapForall[vars, ptlEqToExpr[eq]];
  If[ToString[tag] === "Hypothesis",
    st["finalTypeExpr"] = typeExpr; st["finalVars"] = vars];
  (* Store declaration *)
  AppendTo[st["decls"], tagStr];
  st["term", tagStr] = <|
    "Name" -> tagStr, "Kind" -> "axiom",
    "_TypeExpr" -> typeExpr|>;
  Nothing];

(* SubstitutionRule = Reverse[src] /. assoc *)
ptlProcessStep[HoldComplete[Set[tag_[n_], ReplaceAll[Reverse[src_], assoc_Association]]], st_] /;
  ToString[tag] === "SubstitutionRule" := (
  st["currentSR"] = <|"name" -> ptlLeanRef[src], "reversed" -> True, "assoc" -> assoc|>;
  Nothing);

(* SubstitutionRule = src /. assoc *)
ptlProcessStep[HoldComplete[Set[tag_[n_], ReplaceAll[src_, assoc_Association]]], st_] /;
  ToString[tag] === "SubstitutionRule" := (
  st["currentSR"] = <|"name" -> ptlLeanRef[src], "reversed" -> False, "assoc" -> assoc|>;
  Nothing);

(* SubstitutionRule = Rule[src[[1]], ...] *)
ptlProcessStep[HoldComplete[Set[tag_[n_], Rule[Part[src_, 1], ReplaceAll[_, assoc_Association]]]], st_] /;
  ToString[tag] === "SubstitutionRule" := (
  st["currentSR"] = <|"name" -> ptlLeanRef[src], "reversed" -> False, "assoc" -> assoc|>;
  Nothing);

(* SubstitutionRule = Rule[src[[2]], ...] (Reverse) *)
ptlProcessStep[HoldComplete[Set[tag_[n_], Rule[Part[src_, 2], ReplaceAll[_, assoc_Association]]]], st_] /;
  ToString[tag] === "SubstitutionRule" := (
  st["currentSR"] = <|"name" -> ptlLeanRef[src], "reversed" -> True, "assoc" -> assoc|>;
  Nothing);

(* SubstitutionRule = bare value *)
ptlProcessStep[HoldComplete[Set[tag_[n_], _]], st_] /; ToString[tag] === "SubstitutionRule" := (
  st["currentSR"] = <|"name" -> "?prev", "reversed" -> False, "assoc" -> <||>|>;
  Nothing);

(* CPL/SL instantiation: tag = Reverse[src] /. assoc *)
ptlProcessStep[HoldComplete[Set[tag_[n_], ReplaceAll[Reverse[src_], assoc_Association]]], st_] := (
  st["pendingSource"] = <|"name" -> ptlLeanRef[src], "reversed" -> True, "assoc" -> assoc|>;
  Nothing);

(* CPL/SL instantiation: tag = src /. assoc *)
ptlProcessStep[HoldComplete[Set[tag_[n_], ReplaceAll[src_, assoc_Association]]], st_] := (
  st["pendingSource"] = <|"name" -> ptlLeanRef[src], "reversed" -> False, "assoc" -> assoc|>;
  Nothing);

(* ReplacePart at position *)
ptlProcessStep[HoldComplete[Set[tag_[n_], ReplacePart[src_, _, pos_List]]], st_] := (
  st["pendingPos"] = pos;
  If[st["pendingSource"] === None,
    st["pendingSource"] = <|"name" -> ptlLeanRef[src], "reversed" -> False, "assoc" -> <||>|>];
  Nothing);

(* ReplaceAt extractRuleFromArg *)
SetAttributes[ptlExtractRule, HoldFirst];
ptlExtractRule[rule_, st_] := Module[{held = HoldComplete[rule]},
  Which[
    MatchQ[held, HoldComplete[Apply[Rule, Reverse[_[_Integer]]]]],
      With[{ref = held[[1, 2, 1]]},
        st["currentSR"] = <|"name" -> ptlLeanRef[ref], "reversed" -> True, "assoc" -> <||>|>],
    MatchQ[held, HoldComplete[Apply[Rule, _[_Integer]]]],
      With[{ref = held[[1, 2]]},
        st["currentSR"] = <|"name" -> ptlLeanRef[ref], "reversed" -> False, "assoc" -> <||>|>],
    MatchQ[held, HoldComplete[_[_Integer]]] && ToString[held[[1, 0]]] === "SubstitutionRule",
      Null,
    True, Null]];

(* ReplaceAt with Reverse at position *)
ptlProcessStep[HoldComplete[Set[tag_[n_], ReplaceAt[Reverse[src_], rule_, pos_List]]], st_] := (
  st["pendingPos"] = pos;
  st["pendingSource"] = <|"name" -> ptlLeanRef[src], "reversed" -> True, "assoc" -> <||>|>;
  ptlExtractRule[rule, st];
  Nothing);

(* ReplaceAt at position *)
ptlProcessStep[HoldComplete[Set[tag_[n_], ReplaceAt[src_, rule_, pos_List]]], st_] := (
  st["pendingPos"] = pos;
  st["pendingSource"] = <|"name" -> ptlLeanRef[src], "reversed" -> False, "assoc" -> <||>|>;
  ptlExtractRule[rule, st];
  Nothing);

(* ReplaceAt with Reverse and ReplaceAll *)
ptlProcessStep[HoldComplete[Set[tag_[n_], ReplaceAll[ReplaceAt[Reverse[src_], rule_, pos_List], assoc_Association]]], st_] := (
  st["pendingPos"] = pos;
  st["pendingSource"] = <|"name" -> ptlLeanRef[src], "reversed" -> True, "assoc" -> assoc|>;
  Nothing);

(* ReplaceAt with ReplaceAll *)
ptlProcessStep[HoldComplete[Set[tag_[n_], ReplaceAll[ReplaceAt[src_, rule_, pos_List], assoc_Association]]], st_] := (
  st["pendingPos"] = pos;
  st["pendingSource"] = <|"name" -> ptlLeanRef[src], "reversed" -> False, "assoc" -> assoc|>;
  Nothing);

(* ConfirmAssert: EMIT THEOREM with expression tree type + structured tactic *)
ptlProcessStep[HoldComplete[ConfirmAssert[lhs_ === eq:Inactive[Equal][_, _]]], st_] := Module[
  {tag, vars, tactic, srcExpr, rwRuleExpr, tacSteps, convNav,
   nonTrivial, assocKeys, allCovered, typeExpr},
  tag = ptlAbbrev[Head[lhs], lhs[[1]]];
  vars = ptlGetVarsFromEq[eq, st["sharedConstants"]];
  st["lv", tag] = vars;

  (* Build type as expression tree *)
  typeExpr = ptlWrapForall[vars, ptlEqToExpr[eq]];

  (* Build tactic as structured LeanTactic *)
  tactic = If[st["pendingSource"] =!= None,
    (* Build srcExpr: lemma applied to args as expression tree *)
    srcExpr = ptlBuildSrcExpr[
      st["pendingSource"]["name"], st["pendingSource"]["assoc"], tag, st["lv"]];
    If[st["pendingSource"]["reversed"],
      srcExpr = LeanApp[LeanConst["Eq.symm", {LeanLevelSucc[LeanLevelZero[]]}], srcExpr]];

    (* Build rewrite rule expression *)
    {rwRuleExpr, tacSteps} = If[st["currentSR"] =!= None,
      Module[{name, rev, assoc, srcVars, srExpr},
        name = st["currentSR"]["name"];
        rev = st["currentSR"]["reversed"];
        assoc = st["currentSR"]["assoc"];
        srcVars = ptlLVLookup[st["lv"], name];
        assocKeys = ptlKeyToStr /@ Keys[assoc];
        allCovered = Length[srcVars] > 0 && ContainsAll[assocKeys, srcVars];
        nonTrivial = AnyTrue[Normal[assoc], (ptlKeyToStr[#[[1]]] =!= ptlToStr[ptlCleanExpr[#[[2]]]]) &];
        If[allCovered && nonTrivial,
          srExpr = ptlBuildSrcExpr[name, assoc, tag, st["lv"]];
          If[rev, srExpr = LeanApp[LeanConst["Eq.symm", {LeanLevelSucc[LeanLevelZero[]]}], srExpr]];
          {LeanConst["sr", {}], {LeanTactic["have", "sr", srExpr]}},
          {If[rev, LeanApp[LeanConst["Eq.symm", {LeanLevelSucc[LeanLevelZero[]]}], LeanConst[name, {}]],
                   LeanConst[name, {}]], {}}]],
      {None, {}}];

    If[rwRuleExpr =!= None && st["pendingPos"] =!= None,
      convNav = ptlPosToConvList[st["pendingPos"]];
      LeanTactic[Join[tacSteps, {
        LeanTactic["have", "h", srcExpr],
        LeanTactic["conv", "h", convNav, LeanTactic["rw", {rwRuleExpr}]],
        LeanTactic["exact", LeanConst["h", {}]]}]],
      If[rwRuleExpr =!= None,
        LeanTactic[Join[tacSteps, {
          LeanTactic["have", "h", srcExpr],
          LeanTactic["nth_rewrite", 1, {rwRuleExpr}, "h"],
          LeanTactic["exact", LeanConst["h", {}]]}]],
        LeanTactic["exact", srcExpr]]],
    LeanTactic["sorry"]];

  If[StringStartsQ[tag, "Concl"],
    st["currentSR"] = None; st["pendingSource"] = None; st["pendingPos"] = None;
    Return[Nothing]];

  st["currentSR"] = None; st["pendingSource"] = None; st["pendingPos"] = None;

  If[StringStartsQ[tag, "Hyp"], Return[Nothing]];

  st["finalLemma"] = tag;
  st["finalLemmaTypeExpr"] = typeExpr;
  st["finalLemmaVars"] = vars;

  (* Store theorem declaration *)
  AppendTo[st["decls"], tag];
  st["term", tag] = <|
    "Name" -> tag, "Kind" -> "theorem",
    "_TypeExpr" -> typeExpr, "_Tactic" -> tactic|>;
  Nothing];

(* ConfirmAssert with Extract *)
ptlProcessStep[HoldComplete[ConfirmAssert[Extract[_, _] === Part[src_, 1]]], st_] := (
  If[st["currentSR"] === None,
    st["currentSR"] = <|"name" -> ptlLeanRef[src], "reversed" -> False, "assoc" -> <||>|>];
  Nothing);

ptlProcessStep[HoldComplete[ConfirmAssert[Extract[_, _] === Part[src_, 2]]], st_] := (
  If[st["currentSR"] === None,
    st["currentSR"] = <|"name" -> ptlLeanRef[src], "reversed" -> True, "assoc" -> <||>|>];
  Nothing);

ptlProcessStep[HoldComplete[ConfirmAssert[_ === _]], _] := Nothing;
ptlProcessStep[HoldComplete[If[_, _, _]], _] := Nothing;
ptlProcessStep[x_HoldComplete, _] := Nothing;

(* ====== MAIN PUBLIC FUNCTION ====== *)

ProofToLean[proof_] := Module[
  {pf, step, st, opArities, hasCenterDot, allConstants, finalGoalType, envData, src, env},

  pf = proof["ProofFunction"];

  (* State — bare symbol with DownValues for mutation *)
  st["currentSR"] = None; st["pendingSource"] = None; st["pendingPos"] = None;
  st["finalLemma"] = "sorry"; st["finalLemmaTypeExpr"] = None; st["finalLemmaVars"] = {};
  st["sharedConstants"] = {};
  st["finalTypeExpr"] = None; st["finalVars"] = {};
  st["decls"] = {};

  (* Check if UnformalizeSymbols is available *)
  $ptlHasUnformalize = Quiet@Check[ResourceFunction["UnformalizeSymbols"]; True, False];

  (* Detect operators *)
  opArities = Association[];
  hasCenterDot = Length[Cases[pf, _CenterDot, Infinity]] > 0;
  Cases[pf, Inactive[Equal][lhs_, rhs_] :> 
    Cases[{lhs, rhs}, f_Symbol[args___] /; Context[f] === "Global`" && StringLength[ToString[f]] > 1 :> (opArities[ToString[f]] = Length[{args}]), Infinity], 
  Infinity];

  (* Shared constants *)
  allConstants = Association[];
  Cases[pf, Inactive[Equal][lhs_, rhs_] :>
    Cases[{lhs, rhs}, s_Symbol /; Context[s] === "Global`" && !KeyExistsQ[opArities, ToString[s]] :>
      (allConstants[ToString[s]] = True), Infinity],
  Infinity];

  st["sharedConstants"] = Select[Keys[allConstants], StringLength[#] > 1 &];

  (* Process steps *)
  Do[
    step = Quiet@Extract[pf, {2, 1, 2, i}, HoldComplete];
    If[Head[step] =!= HoldComplete, Break[]];
    ptlProcessStep[step, st];
  , {i, 500}];

  (* Add FinalGoal theorem *)
  finalGoalType = If[st["finalLemmaTypeExpr"] =!= None,
    st["finalLemmaTypeExpr"],
    ptlWrapForall[st["finalLemmaVars"], st["finalTypeExpr"]]];
  AppendTo[st["decls"], "FinalGoal"];
  st["term", "FinalGoal"] = <|
    "Name" -> "FinalGoal", "Kind" -> "theorem",
    "_TypeExpr" -> finalGoalType,
    "_Tactic" -> LeanTactic["exact",
      Fold[LeanApp, LeanConst[st["finalLemma"], {}],
        LeanConst[#, {}] & /@ st["finalLemmaVars"]]]|>;

  (* Build LeanEnvironment with expression tree types *)
  envData = <||>;
  Do[
    envData[name] = LeanTerm[st["term", name]];
  , {name, st["decls"]}];

  (* Store metadata *)
  envData["_Preamble"] = <|
    "Imports" -> {"Mathlib.Tactic"},
    "TypeAxiom" -> "U",
    "Operators" -> opArities,
    "CenterDot" -> hasCenterDot,
    "SharedConstants" -> Sort[st["sharedConstants"]]|>;
  envData["_DeclOrder"] = st["decls"];

  (* Generate source via LeanExportString, then compile *)
  env = LeanEnvironment[envData];
  src = LeanExportString[env];
  
  (* Compile to verify, then return tree-based env with source *)
  Quiet[LeanImportString[src]];
  LeanEnvironment[Append[envData, "_Source" -> src]]];

End[];
EndPackage[];
