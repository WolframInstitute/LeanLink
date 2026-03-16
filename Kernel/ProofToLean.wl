(* ProofToLean.wl -- Transpile ProofObject -> Lean 4 source *)
(* Adapted from vibe-proof/scripts/proof_to_lean.wl *)
(* Loaded by LeanLink.wl; operates within LeanLink` context. *)

BeginPackage["LeanLink`"];
Begin["`Private`"];

(* ====== UNICODE CONSTANTS ====== *)
$ptl$nand = FromCharacterCode[8892];     (* U+22BC *)
$ptl$forall = FromCharacterCode[8704];   (* U+2200 *)
$ptl$alpha = "U";
$ptl$larr = FromCharacterCode[8592];     (* U+2190 *)
$ptl$rarr = FromCharacterCode[8594];     (* U+2192 *)
$ptl$check = FromCharacterCode[10003];   (* U+2713 *)
$ptl$cdot = FromCharacterCode[11037];    (* U+2B1D *)

(* ====== CLEAN + CONVERT ====== *)

ptlCleanExpr[expr_] := Module[{uf},
  uf = If[TrueQ[$ptlHasUnformalize],
    ResourceFunction["UnformalizeSymbols"],
    Identity];
  (expr /. s_Symbol :> RuleCondition[uf[s]]) //. 
    {Verbatim[Pattern][s_, Verbatim[Blank][]] :> s}];

Clear[ptlToLean];
ptlToLean[CenterDot[a_, b_]] := StringTemplate["(`1` `2` `3`)"][ptlToLean[a], $ptl$cdot, ptlToLean[b]];
ptlToLean[f_Symbol[args___]] := StringTemplate["(`1` `2`)"][f, StringRiffle[ptlToLean /@ {args}, " "]];
ptlToLean[s_Symbol] := ToString[s];
ptlToLean[x_] := ToString[x];

ptlEqToLean[eq:Inactive[Equal][_, _]] := Module[{c = ptlCleanExpr[eq]},
  StringTemplate["`1` = `2`"][ptlToLean[c[[1]]], ptlToLean[c[[2]]]]];

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
  StringRiffle[KeyValueMap[StringTemplate["`1` -> `2`"][ptlKeyToStr[#1], ptlToLean[ptlCleanExpr[#2]]] &, a], ", "];

(* ====== POSITION -> CONV NAVIGATION ====== *)
ptlPosToConv[{}] := "";
ptlPosToConv[pos_List] := Module[{first, restStr},
  first = If[Length[pos] > 0 && pos[[1]] == 1, "lhs", "rhs"];
  restStr = StringRiffle[Map[StringTemplate["arg `1`"], Rest[pos]], "; "];
  If[restStr === "", first, StringTemplate["`1`; `2`"][first, restStr]]];

(* ====== BUILD ARGS ====== *)
ptlBuildArgs[name_, assoc_Association, targetTag_String, lemmaVars_] := Module[
  {vars, vals = {}, k, v, targetVars, keys},
  vars = Lookup[lemmaVars, name, {}];
  targetVars = Lookup[lemmaVars, targetTag, {}];
  If[Length[vars] == 0,
    keys = Sort[Keys[assoc]];
    Do[AppendTo[vals, ptlToLean[ptlCleanExpr[assoc[k]]]], {k, keys}],
    Do[
      k = vars[[i]];
      v = Null;
      KeyValueMap[If[ptlKeyToStr[#1] == k, v = ptlToLean[ptlCleanExpr[#2]]] &, assoc];
      If[v === Null,
        If[MemberQ[targetVars, k], v = k,
          v = If[Length[targetVars] > 0, targetVars[[1]], "_"]]];
      AppendTo[vals, v];
    , {i, 1, Length[vars]}]];
  StringTemplate[" `1`"][StringRiffle[vals, " "]]];

(* ====== STEP PROCESSOR ====== *)
(* All processing uses state variables through local association passed by reference *)

Clear[ptlProcessStep];

ptlProcessStep[HoldComplete[Set[tag_[n_Integer], eq:Inactive[Equal][_, _]]], st_] := Module[
  {tagStr = ptlAbbrev[tag, n], eqStr = ptlEqToLean[eq], vars = ptlGetVarsFromEq[eq, st["sharedConstants"]]},
  st["lemmaVars"][tagStr] = vars;
  If[ToString[tag] === "Hypothesis",
    st["finalEqStr"] = eqStr; st["finalVars"] = vars;
    StringTemplate["axiom `1` `2` : `3`"][tagStr,
      If[Length[vars]>0, StringTemplate["(`1` : U)"][StringRiffle[vars, " "]], ""], eqStr],
    StringTemplate["axiom `1` `2` : `3`"][tagStr,
      If[Length[vars]>0, StringTemplate["(`1` : U)"][StringRiffle[vars, " "]], ""], eqStr]]];

(* SubstitutionRule = Reverse[src] /. assoc *)
ptlProcessStep[HoldComplete[Set[tag_[n_], ReplaceAll[Reverse[src_], assoc_Association]]], st_] /;
  ToString[tag] === "SubstitutionRule" := (
  st["currentSR"] = <|"name" -> ptlLeanRef[src], "reversed" -> True, "assoc" -> assoc|>;
  StringTemplate["  -- SR`1` `2` Reverse[`3`] /. {`4`}"][n, $ptl$larr, ptlLeanRef[src], ptlAssocToStr[assoc]]);

(* SubstitutionRule = src /. assoc *)
ptlProcessStep[HoldComplete[Set[tag_[n_], ReplaceAll[src_, assoc_Association]]], st_] /;
  ToString[tag] === "SubstitutionRule" := (
  st["currentSR"] = <|"name" -> ptlLeanRef[src], "reversed" -> False, "assoc" -> assoc|>;
  StringTemplate["  -- SR`1` `2` `3` /. {`4`}"][n, $ptl$larr, ptlLeanRef[src], ptlAssocToStr[assoc]]);

(* SubstitutionRule = Rule[src[[1]], ...] *)
ptlProcessStep[HoldComplete[Set[tag_[n_], Rule[Part[src_, 1], ReplaceAll[_, assoc_Association]]]], st_] /;
  ToString[tag] === "SubstitutionRule" := (
  st["currentSR"] = <|"name" -> ptlLeanRef[src], "reversed" -> False, "assoc" -> assoc|>;
  StringTemplate["  -- SR`1` `2` `3` /. {`4`}"][n, $ptl$larr, ptlLeanRef[src], ptlAssocToStr[assoc]]);

(* SubstitutionRule = Rule[src[[2]], ...] (Reverse) *)
ptlProcessStep[HoldComplete[Set[tag_[n_], Rule[Part[src_, 2], ReplaceAll[_, assoc_Association]]]], st_] /;
  ToString[tag] === "SubstitutionRule" := (
  st["currentSR"] = <|"name" -> ptlLeanRef[src], "reversed" -> True, "assoc" -> assoc|>;
  StringTemplate["  -- SR`1` `2` Reverse[`3`] /. {`4`}"][n, $ptl$larr, ptlLeanRef[src], ptlAssocToStr[assoc]]);

(* SubstitutionRule = bare value *)
ptlProcessStep[HoldComplete[Set[tag_[n_], _]], st_] /; ToString[tag] === "SubstitutionRule" := (
  st["currentSR"] = <|"name" -> "?prev", "reversed" -> False, "assoc" -> <||>|>;
  StringTemplate["  -- SR`1`"][n]);

(* CPL/SL instantiation: tag = Reverse[src] /. assoc *)
ptlProcessStep[HoldComplete[Set[tag_[n_], ReplaceAll[Reverse[src_], assoc_Association]]], st_] := (
  st["pendingSource"] = <|"name" -> ptlLeanRef[src], "reversed" -> True, "assoc" -> assoc|>;
  StringTemplate["  -- `1` `2` Reverse[`3`] /. {`4`}"][ptlAbbrev[tag, n], $ptl$larr, ptlLeanRef[src], ptlAssocToStr[assoc]]);

(* CPL/SL instantiation: tag = src /. assoc *)
ptlProcessStep[HoldComplete[Set[tag_[n_], ReplaceAll[src_, assoc_Association]]], st_] := (
  st["pendingSource"] = <|"name" -> ptlLeanRef[src], "reversed" -> False, "assoc" -> assoc|>;
  StringTemplate["  -- `1` `2` `3` /. {`4`}"][ptlAbbrev[tag, n], $ptl$larr, ptlLeanRef[src], ptlAssocToStr[assoc]]);

(* ReplacePart at position *)
ptlProcessStep[HoldComplete[Set[tag_[n_], ReplacePart[src_, _, pos_List]]], st_] := (
  st["pendingPos"] = pos;
  If[st["pendingSource"] === None,
    st["pendingSource"] = <|"name" -> ptlLeanRef[src], "reversed" -> False, "assoc" -> <||>|>];
  StringTemplate["  -- `1` `2` ReplacePart at `3`"][ptlAbbrev[tag, n], $ptl$larr, pos]);

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
  StringTemplate["  -- `1` `2` ReplaceAt in Reverse[`3`] at `4`"][ptlAbbrev[tag, n], $ptl$larr, ptlLeanRef[src], pos]);

(* ReplaceAt at position *)
ptlProcessStep[HoldComplete[Set[tag_[n_], ReplaceAt[src_, rule_, pos_List]]], st_] := (
  st["pendingPos"] = pos;
  st["pendingSource"] = <|"name" -> ptlLeanRef[src], "reversed" -> False, "assoc" -> <||>|>;
  ptlExtractRule[rule, st];
  StringTemplate["  -- `1` `2` ReplaceAt in `3` at `4`"][ptlAbbrev[tag, n], $ptl$larr, ptlLeanRef[src], pos]);

(* ReplaceAt with Reverse and ReplaceAll *)
ptlProcessStep[HoldComplete[Set[tag_[n_], ReplaceAll[ReplaceAt[Reverse[src_], rule_, pos_List], assoc_Association]]], st_] := (
  st["pendingPos"] = pos;
  st["pendingSource"] = <|"name" -> ptlLeanRef[src], "reversed" -> True, "assoc" -> assoc|>;
  StringTemplate["  -- `1` `2` ReplaceAt in Reverse[`3`] at `4` /. {`5`}"][ptlAbbrev[tag, n], $ptl$larr, ptlLeanRef[src], pos, ptlAssocToStr[assoc]]);

(* ReplaceAt with ReplaceAll *)
ptlProcessStep[HoldComplete[Set[tag_[n_], ReplaceAll[ReplaceAt[src_, rule_, pos_List], assoc_Association]]], st_] := (
  st["pendingPos"] = pos;
  st["pendingSource"] = <|"name" -> ptlLeanRef[src], "reversed" -> False, "assoc" -> assoc|>;
  StringTemplate["  -- `1` `2` ReplaceAt in `3` at `4` /. {`5`}"][ptlAbbrev[tag, n], $ptl$larr, ptlLeanRef[src], pos, ptlAssocToStr[assoc]]);

(* ConfirmAssert: EMIT TACTIC *)
ptlProcessStep[HoldComplete[ConfirmAssert[lhs_ === eq:Inactive[Equal][_, _]]], st_] := Module[
  {tag, eqStr, vars, tactic, srcCall, rwRule, rwPreamble, convNav, nonTrivial, assocKeys, allCovered},
  tag = ptlAbbrev[Head[lhs], lhs[[1]]];
  eqStr = ptlEqToLean[eq];
  vars = ptlGetVarsFromEq[eq, st["sharedConstants"]];
  st["lemmaVars"][tag] = vars;

  tactic = If[st["pendingSource"] =!= None,
    srcCall = StringTemplate["`1``2`"][st["pendingSource"]["name"],
      ptlBuildArgs[st["pendingSource"]["name"], st["pendingSource"]["assoc"], tag, st["lemmaVars"]]];
    If[st["pendingSource"]["reversed"], srcCall = StringTemplate["(`1`).symm"][srcCall]];

    {rwRule, rwPreamble} = If[st["currentSR"] =!= None,
      Module[{name, rev, assoc, srcVars, srArgs, preamble = ""},
        name = st["currentSR"]["name"];
        rev = st["currentSR"]["reversed"];
        assoc = st["currentSR"]["assoc"];
        srcVars = Lookup[st["lemmaVars"], name, {}];
        assocKeys = ptlKeyToStr /@ Keys[assoc];
        allCovered = Length[srcVars] > 0 && ContainsAll[assocKeys, srcVars];
        nonTrivial = AnyTrue[Normal[assoc], (ptlKeyToStr[#[[1]]] =!= ptlToLean[ptlCleanExpr[#[[2]]]]) &];
        If[allCovered && nonTrivial,
          srArgs = ptlBuildArgs[name, assoc, tag, st["lemmaVars"]];
          preamble = If[rev,
            StringTemplate["  have sr := (`1``2`).symm\n"][name, srArgs],
            StringTemplate["  have sr := `1``2`\n"][name, srArgs]];
          {"sr", preamble},
          {If[rev, StringTemplate["`1` `2`"][$ptl$larr, name], name], ""}]],
      {None, ""}];

    If[rwRule =!= None && st["pendingPos"] =!= None,
      convNav = ptlPosToConv[st["pendingPos"]];
      If[rwPreamble =!= "",
        StringTemplate["`4`  have h := `1`\n  conv at h => `2`; rw [`3`]\n  exact h"][srcCall, convNav, rwRule, rwPreamble],
        StringTemplate["  have h := `1`\n  conv at h => `2`; rw [`3`]\n  exact h"][srcCall, convNav, rwRule]],
      If[rwRule =!= None,
        If[rwPreamble =!= "",
          StringTemplate["`3`  have h := `1`\n  simp only [`2`] at h\n  exact h"][srcCall, rwRule, rwPreamble],
          StringTemplate["  have h := `1`\n  nth_rewrite 1 [`2`] at h\n  exact h"][srcCall, rwRule]],
        StringTemplate["  exact `1`"][srcCall]]],
    "    sorry"];

  If[StringStartsQ[tag, "Concl"],
    st["currentSR"] = None; st["pendingSource"] = None; st["pendingPos"] = None;
    Return[Nothing]];

  st["currentSR"] = None; st["pendingSource"] = None; st["pendingPos"] = None;

  If[StringStartsQ[tag, "Hyp"], Return[Nothing]];

  st["finalLemma"] = tag;
  st["finalLemmaEqStr"] = eqStr;
  st["finalLemmaVars"] = vars;

  If[Length[vars] > 0,
    StringTemplate["theorem `1` (`2` : `3`) : `4` := by\n`5`\n"][tag, StringRiffle[vars, " "], $ptl$alpha, eqStr, tactic],
    StringTemplate["theorem `1` : `2` := by\n`3`\n"][tag, eqStr, tactic]]];

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
ptlProcessStep[HoldComplete[If[_, _, _]], _] := StringTemplate["  -- QED `1`"][$ptl$check];
ptlProcessStep[x_HoldComplete, _] := StringTemplate["  -- [?] `1`"][Head[x[[1]]]];

(* ====== MAIN PUBLIC FUNCTION ====== *)

ProofToLean[proof_] := Module[
  {pf, step, lines = {}, st, opArities, hasCenterDot, allConstants, line},

  pf = proof["ProofFunction"];

  (* State association — avoids global mutable state *)
  st = <|
    "currentSR" -> None, "pendingSource" -> None, "pendingPos" -> None,
    "finalLemma" -> "sorry", "finalLemmaEqStr" -> "", "finalLemmaVars" -> {},
    "lemmaVars" -> <||>, "sharedConstants" -> {},
    "finalEqStr" -> "", "finalVars" -> {}|>;

  (* Check if UnformalizeSymbols is available *)
  $ptlHasUnformalize = Quiet@Check[ResourceFunction["UnformalizeSymbols"]; True, False];

  AppendTo[lines, "import Mathlib.Tactic\n"];
  AppendTo[lines, "axiom U : Type\n"];

  (* Detect operators *)
  opArities = Association[];
  hasCenterDot = Length[Cases[pf, _CenterDot, Infinity]] > 0;
  Cases[pf, Inactive[Equal][lhs_, rhs_] :> 
    Cases[{lhs, rhs}, f_Symbol[args___] /; Context[f] === "Global`" && StringLength[ToString[f]] > 1 :> (opArities[ToString[f]] = Length[{args}]), Infinity], 
  Infinity];

  If[hasCenterDot,
    AppendTo[lines, StringTemplate["axiom cdot : U `1` U `1` U"][$ptl$rarr]];
    AppendTo[lines, StringTemplate["infixl:70 \" `1` \" => cdot"][$ptl$cdot]]];
  KeyValueMap[
    AppendTo[lines, StringTemplate["axiom `1` : `2`U"][#1, StringJoin[Table["U " <> $ptl$rarr <> " ", {#2}]]]] &,
    opArities];

  (* Shared constants *)
  allConstants = Association[];
  Cases[pf, Inactive[Equal][lhs_, rhs_] :>
    Cases[{lhs, rhs}, s_Symbol /; Context[s] === "Global`" && !KeyExistsQ[opArities, ToString[s]] :>
      (allConstants[ToString[s]] = True), Infinity],
  Infinity];

  st["sharedConstants"] = Select[Keys[allConstants], StringLength[#] > 1 &];
  Do[AppendTo[lines, StringTemplate["axiom `1` : U"][c]], {c, Sort[st["sharedConstants"]]}];
  AppendTo[lines, ""];

  (* Process steps *)
  Do[
    step = Quiet@Extract[pf, {2, 1, 2, i}, HoldComplete];
    If[Head[step] =!= HoldComplete, Break[]];
    line = ptlProcessStep[step, st];
    If[line =!= Nothing, AppendTo[lines, line]];
  , {i, 500}];

  AppendTo[lines, "\n-- Find the last lemma to prove the goal --"];
  AppendTo[lines, StringTemplate["theorem FinalGoal `1` : `2` := by"][
    If[Length[st["finalLemmaVars"]]>0, StringTemplate["(`1` : U)"][StringRiffle[st["finalLemmaVars"], " "]], ""],
    st["finalLemmaEqStr"]]];
  AppendTo[lines, StringTemplate["  exact `1``2`"][
    st["finalLemma"],
    If[Length[st["finalLemmaVars"]]>0, StringTemplate[" `1`"][StringRiffle[st["finalLemmaVars"], " "]], ""]]];

  Module[{src, env},
    src = StringRiffle[lines, "\n"];
    env = LeanImportString[src];
    If[Head[env] === LeanEnvironment,
      (* Stash source in the env *)
      LeanEnvironment[Append[env[[1]], "_Source" -> src]],
      (* Compilation failed — return bare source *)
      env]]];

End[];
EndPackage[];
