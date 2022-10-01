Require Import Coq.ZArith.ZArith.
Require Import Coq.FSets.FMapPositive.
Require Import Coq.MSets.MSetPositive.
Require Import Coq.Lists.List.
Require Import Ltac2.Ltac2.
Require Import Ltac2.Printf.
Require Import Ltac2.Bool.
Require Import Rewriter.Util.Option.
Require Import Rewriter.Util.OptionList.
Require Import Rewriter.Util.Bool.Reflect.
Require Rewriter.Util.PrimitiveProd.
Require Rewriter.Util.PrimitiveHList.
Require Import Rewriter.Language.Language.
Require Import Rewriter.Language.Reify.
Require Import Rewriter.Language.UnderLets.
Require Import Rewriter.Language.IdentifiersLibrary.
Require Import Rewriter.Language.IdentifiersBasicGenerate. (* For reify*_via_reify_package *)
Require Import Rewriter.Rewriter.Rewriter.
Require Import Rewriter.Util.LetIn.
Require Import Rewriter.Util.Tactics.BreakMatch.
Require Import Rewriter.Util.Tactics.DestructHead.
Require Import Rewriter.Util.Tactics.ConstrFail.
Require Import Rewriter.Util.Tactics.Head.
Require Import Rewriter.Util.Tactics.CacheTerm.
Require Import Rewriter.Util.Tactics.DebugPrint.
Require Import Rewriter.Util.CPSNotations.
Require Import Rewriter.Util.Notations.
Require Import Rewriter.Util.Tactics2.Head.
Require Import Rewriter.Util.Tactics2.Constr.Unsafe.MakeAbbreviations.
Require Import Rewriter.Util.Tactics2.ReplaceByPattern.
Require Import Rewriter.Util.Tactics2.FixNotationsForPerformance.
Require Import Rewriter.Util.Tactics2.InFreshContext.
Require Import Rewriter.Util.Tactics2.Notations.
Require Rewriter.Util.Tactics2.Ltac1.
Require Rewriter.Util.Tactics2.Constr.
Import ListNotations. Local Open Scope bool_scope. Local Open Scope Z_scope.

Local Set Primitive Projections.
Local Set Default Proof Mode "Classic".
Import EqNotations.
Module Compilers.
  Export Language.Compilers.
  Export Language.Reify.Compilers.
  Export UnderLets.Compilers.
  Export IdentifiersLibrary.Compilers.
  Export IdentifiersBasicGenerate.Compilers.
  Import invert_expr.
  Export Rewriter.Compilers.

  Module RewriteRules.
    Export Rewriter.Compilers.RewriteRules.

    Module Reify.
      Export Rewriter.Compilers.RewriteRules.Reify.
      Import Compile.
      Local Notation EvarMap := pattern.EvarMap.
      Local Notation EvarMap_at base := (pattern.EvarMap_at base).

      Inductive dynlist := dynnil | dyncons {T} (x : T) (xs : dynlist).

      Section with_var.
        Local Notation type_of_list
          := (fold_right (fun a b => prod a b) unit).
        Local Notation type_of_list_cps
          := (fold_right (fun a K => a -> K)).
        Context {base : Type}.
        Local Notation base_type := (base.type base).
        Local Notation pattern_base_type := (pattern.base.type base).
        Local Notation type := (type.type base_type).
        Local Notation ptype := (type.type pattern_base_type).
        Context {try_make_transport_base_cps : type.try_make_transport_cpsT base}
                {ident var : type -> Type}
                {pident : ptype -> Type}
                (pident_arg_types : forall t, pident t -> list Type)
                (pident_type_of_list_arg_types_beq : forall t idc, type_of_list (pident_arg_types t idc) -> type_of_list (pident_arg_types t idc) -> bool)
                (pident_of_typed_ident : forall t, ident t -> pident (pattern.type.relax t))
                (pident_arg_types_of_typed_ident : forall t (idc : ident t), type_of_list (pident_arg_types _ (pident_of_typed_ident t idc)))
                (reflect_ident_iota : forall t (idc : ident t), option (@value base_type ident var t)).

        Local Notation expr := (@expr.expr base_type ident var).
        Local Notation pattern := (@pattern.pattern base pident).
        Local Notation value := (@Compile.value base_type ident var).
        Local Notation value_with_lets := (@Compile.value_with_lets base_type ident var).
        Local Notation UnderLets := (UnderLets.UnderLets base_type ident var).
        Local Notation reify_expr_beta_iota := (@reify_expr_beta_iota base ident var reflect_ident_iota).
        Local Notation unification_resultT' := (@unification_resultT' base pident pident_arg_types).
        Local Notation with_unif_rewrite_ruleTP_gen' := (@with_unif_rewrite_ruleTP_gen' base ident var pident pident_arg_types value).
        Local Notation lam_unification_resultT' := (@lam_unification_resultT' base pident pident_arg_types).
        Local Notation expr_value_to_rewrite_rule_replacement := (@expr_value_to_rewrite_rule_replacement base ident var reflect_ident_iota).

        Local Notation expr_maybe_do_again should_do_again
          := (@expr.expr base_type ident (if should_do_again then value else var)).

        Inductive pattern_of_expr_error_messages {t} :=
        | ILLEGAL_ABS_ON_LHS (e : @expr.expr base_type ident (fun _ => positive) t)
        | ILLEGAL_LET_IN_ON_LHS (e : @expr.expr base_type ident (fun _ => positive) t)
        .

        Fixpoint pattern_of_expr (var' := fun _ => positive) evm (invalid : forall t, @pattern_of_expr_error_messages t -> { p : pattern (pattern.type.relax t) & @unification_resultT' var' _ p evm })
                 {t} (e : @expr.expr base_type ident var' t)
          : { p : pattern (pattern.type.relax t) & @unification_resultT' var' _ p evm }
          := match e in expr.expr t return { p : pattern (pattern.type.relax t) & @unification_resultT' var' _ p evm } with
             | expr.Ident t idc
               => existT _ (pattern.Ident (pident_of_typed_ident _ idc))
                         (pident_arg_types_of_typed_ident _ idc)
             | expr.Var t v
               => existT _ (pattern.Wildcard _) v
             | expr.App s d f x
               => let 'existT fp fv := @pattern_of_expr evm invalid _ f in
                  let 'existT xp xv := @pattern_of_expr evm invalid _ x in
                  existT _ (pattern.App fp xp)
                         (fv, xv)
             | expr.Abs _ _ _ as e
               => invalid _ (ILLEGAL_ABS_ON_LHS e)
             | expr.LetIn _ _ _ _ as e
               => invalid _ (ILLEGAL_LET_IN_ON_LHS e)
             end.

        Fixpoint pair'_unification_resultT' {A evm t p}
          : @unification_resultT' (fun _ => positive) t p evm -> @unification_resultT' value t p evm -> PositiveMap.t { t : _ & value t } * (A -> list bool) -> PositiveMap.t { t : _ & value t } * (A -> list bool)
          := match p return @unification_resultT' (fun _ => positive) _ p evm -> @unification_resultT' value _ p evm -> PositiveMap.t { t : _ & value t } * (A -> list bool) -> PositiveMap.t { t : _ & value t } * (A -> list bool) with
             | pattern.Wildcard t => fun p v '(m, l) => (PositiveMap.add p (existT value _ v) m, l)
             | pattern.Ident t idc => fun v1 v2 '(m, l) => (m, fun a => pident_type_of_list_arg_types_beq t idc v2 v1 :: l a)
             | pattern.App _ _ F X
               => fun x y '(m, l)
                  => let '(m, l) := @pair'_unification_resultT' _ _ _ F (fst x) (fst y) (m, l) in
                     let '(m, l) := @pair'_unification_resultT' _ _ _ X (snd x) (snd y) (m, l) in
                     (m, l)
             end.

        Inductive expr_pos_to_expr_value_error_message :=
        | MISSING_VAR (_ : positive * type * PositiveMap.t { t : _ & value t })
        .

        Fixpoint expr_pos_to_expr_value
                 (invalid : forall t, expr_pos_to_expr_value_error_message -> @expr.expr base_type ident value t)
                 {t} (e : @expr.expr base_type ident (fun _ => positive) t) (m : PositiveMap.t { t : _ & value t }) (cur_i : positive)
          : @expr.expr base_type ident value t
          := match e in expr.expr t return expr.expr t with
             | expr.Ident t idc => expr.Ident idc
             | expr.App s d f x
               => expr.App (@expr_pos_to_expr_value invalid _ f m cur_i)
                           (@expr_pos_to_expr_value invalid _ x m cur_i)
             | expr.Var t v
               => match option_map
                          (fun tv => type.try_transport value _ t (projT2 tv))
                          (PositiveMap.find v m) with
                  | Some (Some res) => expr.Var res
                  | Some None | None => invalid _ (MISSING_VAR (v, t, m))
                  end
             | expr.Abs s d f
               => expr.Abs (fun v => @expr_pos_to_expr_value invalid _ (f cur_i) (PositiveMap.add cur_i (existT value _ v) m) (Pos.succ cur_i))
             | expr.LetIn A B x f
               => expr.LetIn (@expr_pos_to_expr_value invalid _ x m cur_i)
                             (fun v => @expr_pos_to_expr_value invalid _ (f cur_i) (PositiveMap.add cur_i (existT value _ v) m) (Pos.succ cur_i))
             end.

        Inductive lookup_gets_inlined_error_messages :=
        | NO_SUCH_EXPRESSION_TO_CHECK (p : positive) (m : PositiveMap.t { t : _ & value t })
        | TYPE_IS_NOT_BASE (p : positive) (m : PositiveMap.t { t : _ & value t }) (t : type).

        Definition lookup_expr_gets_inlined
                   (invalid : lookup_gets_inlined_error_messages -> bool)
                   (gets_inlined : forall t, value (type.base t) -> bool)
                   (m : PositiveMap.t { t : _ & value t })
                   (p : positive)
          : bool
          := Eval cbv -[value] in
              match PositiveMap.find p m with
              | Some (existT t e)
                => match t return value t -> _ with
                   | type.base t => gets_inlined t
                   | _ => fun _ => invalid (TYPE_IS_NOT_BASE p m t)
                   end e
              | None => invalid (NO_SUCH_EXPRESSION_TO_CHECK p m)
              end.

        Definition expr_to_pattern_and_replacement
                   (gets_inlined : forall t, value (type.base t) -> bool)
                   (should_do_again : bool) evm
                   (invalid : forall A B, A -> B)
                   {t} (lhs rhs : @expr.expr base_type ident (fun _ => positive) t)
                   (side_conditions : (positive -> bool) -> list bool)
          : { p : pattern (pattern.type.relax t) & @with_unif_rewrite_ruleTP_gen' _ p should_do_again true true evm }
          := let (p, unif_data_lhs) := @pattern_of_expr evm (fun _ => invalid _ _) t lhs in
             existT
               _
               p
               (pattern.type.subst_default_relax
                  (fun t'
                   => with_unification_resultT'
                        pident_arg_types p evm
                        (option (UnderLets (expr_maybe_do_again should_do_again t'))))
                  (lam_unification_resultT'
                     (fun unif_data_new
                      => let '(value_map, side_conditions) := pair'_unification_resultT' unif_data_lhs unif_data_new (PositiveMap.empty _, side_conditions) in
                         let side_conditions := side_conditions (lookup_expr_gets_inlined (invalid _ _) gets_inlined value_map) in
                         let start_i := Pos.succ (PositiveMap.fold (fun k _ max => Pos.max k max) value_map 1%positive) in
                         let replacement := expr_pos_to_expr_value (fun _ => invalid _ _) rhs value_map start_i in
                         let replacement := expr_value_to_rewrite_rule_replacement should_do_again replacement in
                         if fold_left andb (List.rev side_conditions) true
                         then Some replacement
                         else None))).


        Definition expr_to_pattern_and_replacement_unfolded gets_inlined should_do_again evm invalid {t} lhs rhs side_conditions
          := Eval cbv beta iota delta [expr_to_pattern_and_replacement lookup_expr_gets_inlined pattern_of_expr lam_unification_resultT' Pos.succ pair'_unification_resultT' PositiveMap.empty PositiveMap.fold Pos.max expr_pos_to_expr_value (* expr_value_to_rewrite_rule_replacement*) fold_left List.rev List.app value PositiveMap.add PositiveMap.xfoldi Pos.compare Pos.compare_cont FMapPositive.append projT1 projT2 PositiveMap.find Base_value (*UnderLets.map reify_expr_beta_iota reflect_expr_beta_iota*) lam_type_of_list fold_right list_rect pattern.type.relax pattern.type.subst_default pattern.type.subst_default_relax pattern.type.unsubst_default_relax option_map unification_resultT' with_unification_resultT' with_unif_rewrite_ruleTP_gen']
            in @expr_to_pattern_and_replacement gets_inlined should_do_again evm invalid t lhs rhs side_conditions.

        Definition partial_lam_unif_rewrite_ruleTP_gen_unfolded should_do_again {t} p
          := Eval cbv beta iota delta [partial_lam_unif_rewrite_ruleTP_gen pattern.collect_vars pattern.type.lam_forall_vars partial_lam_unification_resultT pattern.type.collect_vars pattern.base.collect_vars PositiveSet.union PositiveSet.add PositiveSet.empty pattern.type.lam_forall_vars_gen List.rev PositiveSet.elements PositiveSet.xelements PositiveSet.rev PositiveSet.rev_append List.app orb fold_right PositiveMap.add PositiveMap.empty]
            in @partial_lam_unif_rewrite_ruleTP_gen base ident var pident pident_arg_types value t p should_do_again true true.
      End with_var.

      Ltac2 Type exn ::= [ Cannot_eliminate_functional_dependencies (constr) ].
      Ltac2 strip_functional_dependency (term : constr) : constr :=
        lazy_match! term with
        | fun _ => ?p => p
        | _ => Control.zero (Cannot_eliminate_functional_dependencies term)
        end.

      Ltac2 rec refine_reify_under_forall_types' (base : constr) (base_type : constr) (base_type_interp : constr) (ty_ctx : constr) (avoid : Fresh.Free.t) (cur_i : constr) (lem : constr) (cont : Fresh.Free.t -> constr (* ty_ctx *) -> constr (* cur_i *) -> constr (* lem *) -> unit) : unit :=
        Reify.debug_wrap
          "refine_reify_under_forall_types'" Message.of_constr lem
          Reify.should_debug_fine_grained Reify.should_debug_fine_grained None
          (fun ()
           => let debug_Constr_check := Reify.Constr.debug_check_strict "refine_reify_under_forall_types'" in
              let default () := cont avoid ty_ctx cur_i lem in
              match Constr.Unsafe.kind_nocast lem with
              | Constr.Unsafe.Prod b p
                => let n := Fresh.fresh avoid (Option.default @T (Constr.Binder.name b)) in
                   if Constr.is_sort (Constr.Binder.type b)
                   then
                     Control.refine
                       (fun ()
                        => strip_functional_dependency
                             (Constr.in_context
                                n base_type
                                (fun ()
                                 => let avoid := Fresh.Free.union avoid (Fresh.Free.of_ids [n]) in
                                    let rt := mkVar n in
                                    let ty_ctx := debug_Constr_check (fun () => mkApp '@PositiveMap.add [base_type; cur_i; rt; ty_ctx]) in
                                    let t := debug_Constr_check (fun () => mkApp base_type_interp [mkApp '@pattern.base.lookup_default [base; cur_i; ty_ctx] ]) in
                                    let p := debug_Constr_check (fun () => Constr.Unsafe.substnl [t] 0 p) in
                                    let cur_i := (eval vm_compute in (mkApp 'Pos.succ [cur_i])) in
                                    refine_reify_under_forall_types' base base_type base_type_interp ty_ctx avoid cur_i p cont)))
                   else
                     default ()
              | _ => default ()
              end).

      Ltac2 refine_reify_under_forall_types (base_type : constr) (base_type_interp : constr) (avoid : Fresh.Free.t) (lem : constr) (cont : Fresh.Free.t -> constr (* ty_ctx *) -> constr (* cur_i *) -> constr (* lem *) -> unit) : unit :=
        let err () := Control.throw (Reification_panic (fprintf "refine_reify_under_forall_types: Invalid Argument: base_type (%t) not of the form `%t ?base`" base_type 'base.type)) in
        lazy_match! base_type with
        | base.type ?base
          => refine_reify_under_forall_types' base base_type base_type_interp '(@PositiveMap.empty $base_type) avoid '(1%positive) lem cont
        | _ => err ()
        end.
      Ltac2 reify_under_forall_types (base_type : constr) (base_type_interp : constr) (avoid : Fresh.Free.t) (lem : constr) (cont : Fresh.Free.t -> constr (* ty_ctx *) -> constr (* cur_i *) -> constr (* lem *) -> constr) : constr :=
        '(ltac2:(refine_reify_under_forall_types base_type base_type_interp avoid lem (fun avoid ty_ctx cur_i lem => Control.refine (fun () => cont avoid ty_ctx cur_i lem)))).

      #[deprecated(since="8.15",note="Use Ltac2 instead.")]
       Ltac reify_under_forall_types base_type base_type_interp lem cont :=
        let f := ltac2:(base_type base_type_interp lem cont
                        |- let cont avoid ty_ctx cur_i lem
                             := Ltac1.apply cont [Ltac1.of_constr ty_ctx; Ltac1.of_constr cur_i; Ltac1.of_constr lem] Ltac1.run in
                           refine_reify_under_forall_types (Ltac1.get_to_constr "base_type" base_type) (Ltac1.get_to_constr "base_type_interp" base_type_interp) (Fresh.Free.of_goal ()) (Ltac1.get_to_constr "lem" lem) cont) in
        constr:(ltac:(f base_type base_type_interp lem ltac:(fun ty_ctx cur_i lem => let v := cont ty_ctx cur_i lem in refine v))).

      (* uses typeclass resolution *)
      Ltac2 prop_to_bool (h : constr) : constr := eval cbv [decb] in constr:(decb $h).

      Ltac2 push_side_conditions (h : constr) (side_conditions : constr) : constr :=
        Reify.Constr.debug_check_strict "push_side_conditions" (fun () => mkApp '@cons ['bool; h; side_conditions]).

      Ltac2 Type exn ::= [ Reification_missing_reflect_instance (constr, exn) ].
      Ltac2 rec equation_to_parts' (avoid : Fresh.Free.t) (lem : constr) (side_conditions : constr) : constr :=
        Reify.debug_wrap
          "equation_to_parts'" (fun (lem, side_conditions) => fprintf "%t (side: %t)" lem side_conditions) (lem, side_conditions)
          Reify.should_debug_fine_grained Reify.should_debug_fine_grained (Some Message.of_constr)
          (fun ()
           => let debug_Constr_check := Reify.Constr.debug_check_strict "equation_to_parts'" in
              lazy_match! lem with
              | ?h -> ?p
                => let t := Constr.type h in
                   (if Constr.equal t 'Prop
                    then ()
                    else Control.zero (Reification_failure (fprintf "Invalid non-Prop non-dependent hypothesis of type %t : %t when reifying a lemma of type %t" h t lem)));
                   let h := match Control.case (fun () => prop_to_bool h) with
                            | Val h => let (h, _) := h in h
                            | Err err => Control.zero (Reification_failure (fprintf "Missing Bool.reflect instance for %t: %a" lem (fun () => Message.of_exn) err))
                            end in
                   let side_conditions := push_side_conditions h side_conditions in
                   equation_to_parts' avoid p side_conditions
              | @eq ?t ?a ?b
                => '((@eq $t $a $b, $side_conditions))
              | ?t
                => match Constr.Unsafe.kind_nocast t with
                   | Constr.Unsafe.Prod b p
                     => (* we use in_context so we can do typeclass resolution later *)
                       Constr.in_fresh_context_avoiding
                         @x false (Some avoid) [b]
                         (fun ns
                          => let ns := List.map (fun (n, _) => n) ns in
                             let avoid := Fresh.Free.union avoid (Fresh.Free.of_ids ns) in
                             let p := debug_Constr_check (fun () => Constr.Unsafe.substnl (List.map mkVar ns) 0 p) in
                             let res := equation_to_parts' avoid p side_conditions in
                             Control.refine (fun () => res))
                   | _ => Control.zero (Reification_failure (fprintf "Invalid type of equation: %t" t))
                   end
              end).
      Ltac2 equation_to_parts (avoid : Fresh.Free.t) (lem : constr) : constr :=
        equation_to_parts' avoid lem '(@nil bool).
      #[deprecated(since="8.15",note="Use Ltac2 instead.")]
      Ltac equation_to_parts lem :=
        let f := ltac2:(lem
                        |- Control.refine (fun () => equation_to_parts (Fresh.Free.of_goal ()) (Ltac1.get_to_constr "lem" lem))) in
        constr:(ltac:(f lem)).

      Ltac2 preadjust_pattern_type_variables (pat : constr) : constr :=
        Reify.debug_wrap
          "preadjust_pattern_type_variables'" Message.of_constr pat
          Reify.should_debug_fine_grained Reify.should_debug_fine_grained (Some Message.of_constr)
          (fun ()
           => let s := strategy:([pattern.type.relax pattern.type.subst_default pattern.type.subst_default_relax pattern.type.unsubst_default_relax]) in
              let pat := Std.eval_cbv s pat in
              let pat := Std.eval_cbn s pat in
              pat).

      Ltac2 rec adjust_pattern_type_variables' (pat : constr) : constr :=
        Reify.debug_wrap
          "adjust_pattern_type_variables'" Message.of_constr pat
          Reify.should_debug_fine_grained Reify.should_debug_fine_grained (Some Message.of_constr)
          (fun ()
           => let debug_Constr_check := Reify.Constr.debug_check_strict "adjust_pattern_type_variables'" in
              let t_base_p_evm' := match! pat with
                                   | context[?t]
                                     => lazy_match! t with
                                        | @pattern.base.relax ?base (@pattern.base.lookup_default ?base ?p ?evm')
                                          => Some (t, base, p, evm')
                                        end
                                   | _ => None
                                   end in
              match t_base_p_evm' with
              | Some t_base_p_evm'
                => let (t, base, p, evm') := t_base_p_evm' in
                   let pat := debug_Constr_check (fun () => Constr.Unsafe.replace_by_pattern [t] [mkApp '@pattern.base.type.var [base; p] ] pat) in
                   adjust_pattern_type_variables' pat
              | None => pat
              end).

      Ltac2 adjust_pattern_type_variables (pat : constr) : constr :=
        let pat := preadjust_pattern_type_variables pat in
        adjust_pattern_type_variables' pat.
      #[deprecated(since="8.15",note="Use Ltac2 instead.")]
      Ltac adjust_pattern_type_variables pat :=
        let f := ltac2:(pat
                        |- Control.refine (fun () => adjust_pattern_type_variables (Ltac1.get_to_constr "pat" pat))) in
        constr:(ltac:(f pat)).

      (* this is fancy but probably too complicated to maintain *)
      Ltac2 walk_term_under_binders_fail_invalid_fast (term : constr) (free : Fresh.Free.t) (invalid : ident) (fv : constr) : unit :=
        Reify.debug_wrap
          "walk_term_under_binders_fail_invalid_fast" Message.of_constr fv
          Reify.should_debug_fine_grained Reify.should_debug_fine_grained None
          (fun ()
           => let res : (int (* len *) * message) list ref := { contents := [] } in
              let check_var i args k :=
                if Ident.equal i invalid
                then res.(contents) := match args with
                                       | None => (0, Message.of_string "")
                                       | Some args
                                         => let len := Array.length args in
                                            (len, (fprintf "%t" (Array.get args (Int.sub len 1))))
                                       end
                                         :: res.(contents)
                else k () in
              let subst_ns (ns : ident list) :=
                let ns := List.map mkVar ns in
                Constr.Unsafe.substnl ns 0 in
              let rec aux (fv : constr) : unit :=
                Reify.debug_wrap
                  "walk_term_under_binders_fail_invalid_fast:aux" Message.of_constr fv
                  Reify.should_debug_fine_grained Reify.should_debug_fine_grained None
                  (fun ()
                   => let under (bs : binder list) (k : ident list -> unit) :=
                        let __ := Constr.in_fresh_context_avoiding
                                    @UNNAMED_BINDER false (Some free) bs
                                    (fun ns => List.iter (fun (_, t) => aux t) ns;
                                               k (List.map (fun (n, _) => n) ns);
                                               Control.refine (fun () => 'I)) in
                        () in
                      match Constr.Unsafe.kind fv with
                      | Constr.Unsafe.Rel _ => () | Constr.Unsafe.Meta _ => () | Constr.Unsafe.Sort _ => () | Constr.Unsafe.Constant _ _ => () | Constr.Unsafe.Ind _ _ => ()
                      | Constr.Unsafe.Constructor _ _ => () | Constr.Unsafe.Uint63 _ => () | Constr.Unsafe.Float _ => ()
                      | Constr.Unsafe.Var v => check_var v None (fun () => ())
                      | Constr.Unsafe.Cast c _ t => aux c; aux t
                      | Constr.Unsafe.Prod b c
                        => under [b] (fun ns => aux (subst_ns ns c))
                      | Constr.Unsafe.Lambda b c
                        => under [b] (fun ns => aux (subst_ns ns c))
                      | Constr.Unsafe.LetIn b v c
                        => aux v;
                           under [b] (fun ns => aux (subst_ns ns c))
                      | Constr.Unsafe.App c l
                        => let default () := aux c; Array.iter aux l in
                           match Constr.Unsafe.kind c with
                           | Constr.Unsafe.Var v
                             => check_var v (Some l) default
                           | _ => default ()
                           end
                      | Constr.Unsafe.Case _ x iv y bl
                        => Array.iter aux bl;
                           Constr.Unsafe.Case.iter_invert aux iv;
                           aux x;
                           aux y
                      | Constr.Unsafe.Proj _p c => aux c
                      | Constr.Unsafe.Array _u t def ty =>
                          Array.iter aux t; aux def; aux ty
                      | Constr.Unsafe.Fix _ _ tl bl =>
                          under (Array.to_list tl)
                                (fun ns => let subst_ns := subst_ns ns in
                                           Array.iter (fun c => aux (subst_ns c)) bl)
                      | Constr.Unsafe.CoFix _ tl bl =>
                          under (Array.to_list tl)
                                (fun ns => let subst_ns := subst_ns ns in
                                           Array.iter (fun c => aux (subst_ns c)) bl)
                      | Constr.Unsafe.Evar _ l => () (* not possible to iter in Ltac2... *)
                      end) in
              aux fv;
              match res.(contents) with
              | [] => Control.zero
                        (Reification_failure
                           (fprintf
                              "Invalid (unknown location): %t" term))
              | v :: vs
                => Control.zero
                     (Reification_failure
                        (fprintf
                           "Invalid (in %t):%s%a"
                           term (String.newline ())
                           (fun ()
                            => List.fold_right
                                 (fun (argn, msg) rest
                                  => (fprintf "Invalid (arg %i): %a%s%a"
                                              argn
                                              (fun () x => x) msg
                                              (String.newline ())
                                              (fun () x => x) rest))
                                 (Message.of_string ""))
                           (v :: vs)))
              end).

      Ltac2 rec walk_term_under_binders_fail_invalid (term : constr) (free : Fresh.Free.t) (invalid : ident) (fv : constr) : unit :=
        Reify.debug_wrap
          "walk_term_under_binders_fail_invalid" Message.of_constr fv
          Reify.should_debug_fine_grained Reify.should_debug_fine_grained None
          (fun ()
           => let recr ns :=
                walk_term_under_binders_fail_invalid
                  term
                  (Fresh.Free.union free (Fresh.Free.of_ids ns))
                  invalid in
              let under (b : binder) (k : ident -> unit) : unit :=
                let __ := Constr.in_fresh_context_avoiding
                            @UNNAMED_BINDER false (Some free) [b]
                            (fun ns =>
                               let (n, t) := List.nth ns 0 in
                               recr [] (* [] because we haven't added the name to the context at this point *) t;
                               k n;
                               Control.refine (fun () => 'I)) in
                () in
              let invalid := mkVar invalid in
              (* recurse first?, err option *)
              let (recurse_first, res)
                := match! fv with
                   | context[?invalid' _ _ ?x]
                     => if Constr.equal_nounivs invalid' invalid
                        then (false, Some (Reification_failure (fprintf "Invalid (in %t): Invalid:%s%t" term (String.newline ()) x)))
                        else Control.zero Match_failure
                   | context[?invalid' _ ?x]
                     => if Constr.equal_nounivs invalid' invalid
                        then (true, Some (Reification_failure (fprintf "Invalid (second arg) (in %t): Invalid:%s%t" term (String.newline ()) x)))
                        else Control.zero Match_failure
                   | context[?invalid']
                     => if Constr.equal_nounivs invalid' invalid
                        then (true, None)
                        else Control.zero Match_failure
                   | _ => (false, None)
                   end in
              (if recurse_first
               then match Constr.Unsafe.kind_nocast fv with
                    | Constr.Unsafe.App f xs
                      => recr [] f;
                         Array.iter (recr []) xs
                    | Constr.Unsafe.Lambda b f
                      => under b (fun n => recr [n] (Constr.Unsafe.substnl [mkVar n] 0 f))
                    | Constr.Unsafe.Prod b f
                      => under b (fun n => recr [n] (Constr.Unsafe.substnl [mkVar n] 0 f))
                    | Constr.Unsafe.LetIn b v f
                      => recr [] v;
                         under b (fun n => recr [n] (Constr.Unsafe.substnl [mkVar n] 0 f))
                    | _ => ()
                    end
               else ());
              match res with
              | Some err => Control.zero err
              | None => ()
              end).

      Ltac2 strip_invalid_or_fail (term : constr) : constr :=
        lazy_match! term with
        | fun _ => ?f => f
        | _
          => match Constr.Unsafe.kind_nocast term with
             | Constr.Unsafe.Lambda b f
               => let free := Fresh.Free.union (Fresh.Free.of_goal ()) (Fresh.Free.of_constr term) in
                  let invalid := Fresh.fresh free @INVALID in
                  let free := Fresh.Free.union free (Fresh.Free.of_ids [invalid]) in
                  let f := Constr.Unsafe.substnl [mkVar invalid] 0 f in
                  let __ := Constr.in_context
                              invalid (Constr.Binder.type b)
                              (fun () => walk_term_under_binders_fail_invalid term free invalid f; Control.refine (fun () => 'I)) in
                  Control.zero (Reification_failure (fprintf "Invalid (unknown subterm): %t" term))
             | _
               => Control.throw (Reification_panic (fprintf "strip_invalid_or_fail given non-lambda: %t" term))
             end
        end.

      #[deprecated(since="8.15",note="Use Ltac2 instead.")]
      Ltac strip_invalid_or_fail term :=
        let f := ltac2:(term
                        |- Control.refine (fun () => strip_invalid_or_fail (Ltac1.get_to_constr "term" term))) in
        constr:(ltac:(f term)).

      Definition pattern_base_subst_default_relax' {base} t evm P
        := @pattern.base.subst_default_relax base P t evm.
      Definition pattern_base_unsubst_default_relax' {base} t evm P
        := @pattern.base.unsubst_default_relax base P t evm.
      Definition pattern_base_subst_default_relax'_reordered {base} P t evm
        := @pattern_base_subst_default_relax' base t evm P.
      Definition pattern_base_unsubst_default_relax'_reordered {base} P t evm
        := @pattern_base_unsubst_default_relax' base t evm P.

      Ltac2 change_pattern_base_subst_default_relax (term : constr) : constr :=
        Reify.debug_wrap
          "change_pattern_base_subst_default_relax" Message.of_constr term
          Reify.should_debug_fine_grained Reify.should_debug_fine_grained (Some Message.of_constr)
          (fun ()
           => let debug_Constr_check := Reify.Constr.debug_check_strict "change_pattern_base_subst_default_relax" in
              lazy_match! (eval pattern '@pattern.base.subst_default_relax, '@pattern.base.unsubst_default_relax in term) with
              | ?f _ _
                => (eval cbv beta delta [pattern_base_subst_default_relax'_reordered pattern_base_unsubst_default_relax'_reordered] in
                     (debug_Constr_check (fun () => mkApp f ['@pattern_base_subst_default_relax'_reordered; '@pattern_base_unsubst_default_relax'_reordered])))
              end).

      #[deprecated(since="8.15",note="Use Ltac2 instead.")]
      Ltac change_pattern_base_subst_default_relax term :=
        let f := ltac2:(term
                        |- Control.refine (fun () => change_pattern_base_subst_default_relax (Ltac1.get_to_constr "term" term))) in
        constr:(ltac:(f term)).

      Definition pattern_base_subst_default_reordered base p evm
        := @pattern.base.subst_default base (pattern.base.type.var p) evm.
      Ltac2 adjust_lookup_default (rewr : constr) : constr :=
        Reify.debug_wrap
          "adjust_lookup_default" Message.of_constr rewr
          Reify.should_debug_fine_grained Reify.should_debug_fine_grained (Some Message.of_constr)
          (fun ()
           => let debug_Constr_check := Reify.Constr.debug_check_strict "adjust_lookup_default" in
              lazy_match! (eval pattern '@pattern.base.lookup_default in rewr) with
              | ?rewr _
                => (eval cbv beta delta [pattern_base_subst_default_reordered] in
                     (debug_Constr_check (fun () => mkApp rewr ['@pattern_base_subst_default_reordered])))
              end).
      #[deprecated(since="8.15",note="Use Ltac2 instead.")]
      Ltac adjust_lookup_default rewr :=
        let f := ltac2:(rewr
                        |- Control.refine (fun () => adjust_lookup_default (Ltac1.get_to_constr "rewr" rewr))) in
        constr:(ltac:(f rewr)).

      Ltac replace_evar_map_internal evm rewr :=
        let evm' := match rewr with
                    | context[pattern.base.lookup_default _ ?evm']
                      => let __ := match goal with _ => tryif constr_eq evm evm' then fail else idtac end in
                         evm'
                    | context[pattern.base.subst_default _ ?evm']
                      => let __ := match goal with _ => tryif constr_eq evm evm' then fail else idtac end in
                         evm'
                    | _ => tt
                    end in
        lazymatch evm' with
        | tt => rewr
        | _
          => let rewr := lazymatch (eval pattern evm' in rewr) with
                         | ?rewr _ => (eval cbv beta in (rewr evm))
                         end in
             replace_evar_map_internal evm rewr
        end.
      Ltac replace_evar_map evm rewr :=
        constr:(ltac:(let v := replace_evar_map_internal evm rewr in refine v)).

      Ltac adjust_type_variables_internal rewr :=
        lazymatch rewr with
        | context[@pattern.base.subst_default ?base (pattern.base.relax ?t) ?evm'']
          => let t' := constr:(@pattern.base.subst_default base (pattern.base.relax t) evm'') in
             let rewr :=
                 lazymatch (eval pattern
                                 t',
                            (@pattern_base_subst_default_relax' base t evm''),
                            (@pattern_base_unsubst_default_relax' base t evm'')
                             in rewr)
                 with
                 | ?rewr _ _ _
                   => (eval cbv beta in (rewr t (fun P x => x) (fun P x => x)))
                 end in
             adjust_type_variables_internal rewr
        | _ => rewr
        end.
      Ltac adjust_type_variables rewr :=
        constr:(ltac:(let v := adjust_type_variables_internal rewr in refine v)).

      Ltac replace_type_try_transport_internal term :=
        lazymatch term with
        | context[@type.try_transport ?base_type ?try_make_transport_base_type_cps ?P ?t ?t]
          => let v := constr:(@type.try_transport base_type try_make_transport_base_type_cps P t t) in
             let term := lazymatch (eval pattern v in term) with
                         | ?term _ => (eval cbv beta in (term (@Some _)))
                         end in
             replace_type_try_transport_internal term
        | _ => term
        end.
      Ltac replace_type_try_transport term :=
        constr:(ltac:(let v := replace_type_try_transport_internal term in refine v)).

      Ltac under_binders payload term cont ctx :=
        lazymatch term with
        | (fun x : ?T => ?f)
          => let ctx' := fresh in
             let f' := fresh in
             let payload' := fresh in (* COQBUG(https://github.com/coq/coq/issues/7210#issuecomment-470009463) *)
             constr:(match payload return _ with
                     | payload'
                       => fun x : T
                          => match f, dyncons x ctx return _ with
                             | f', ctx'
                               => ltac:(let ctx := (eval cbv delta [ctx'] in ctx') in
                                        let f := (eval cbv delta [f'] in f') in
                                        let payload := (eval cbv delta [payload'] in payload') in
                                        clear f' ctx' payload';
                                        let res := under_binders payload f cont ctx in
                                        exact res)
                             end
                     end)
        | ?term => cont payload ctx term
        end.
      Ltac substitute_with term x y :=
        lazymatch (eval pattern y in term) with
        | (fun z => ?term) _ => constr:(match x return _ with z => term end)
        end.
      Ltac substitute_beq_with base_interp_beq only_eliminate_in_ctx full_ctx term beq x :=
        let is_good y :=
            lazymatch full_ctx with
            | context[dyncons y _] => fail
            | _ => is_var y;
                   lazymatch only_eliminate_in_ctx with
                   | context[y] => idtac
                   end
            end in
        let y := match term with
                 | context term' [beq x ?y]
                   => let __ := is_good y in
                      constr:(Some (beq x y))
                 | context term' [@base.interp_beq ?base ?base_interp ?base_interp_beq ?t x ?y]
                   => let __ := is_good y in
                      constr:(Some (@base.interp_beq base base_interp base_interp_beq t x y))
                 | context term' [base_interp_beq ?t x ?y]
                   => let __ := is_good y in
                      constr:(Some (base_interp_beq t x y))
                 | context term' [base_interp_beq ?t1 ?t2 x ?y] (* heterogenous form *)
                   => let __ := is_good y in
                      constr:(Some (base_interp_beq t1 t2 x y))
                 | _ => constr:(@None unit)
                 end in
        lazymatch y with
        | Some (?beq x ?y)
          => lazymatch term with
             | context term'[beq x y]
               => let term := context term'[true] in
                  substitute_with term x y
             end
        | None => term
        end.
      Ltac remove_andb_true term :=
        let term := lazymatch (eval pattern andb, (andb true) in term) with
                    | ?f _ _ => (eval cbn [andb] in (f (fun x y => andb y x) (fun b => b)))
                    end in
        let term := lazymatch (eval pattern andb, (andb true) in term) with
                    | ?f _ _ => (eval cbn [andb] in (f (fun x y => andb y x) (fun b => b)))
                    end in
        term.
      Ltac adjust_if_negb term :=
        lazymatch term with
        | context term'[if negb ?x then ?a else ?b]
          => let term := context term'[if x then b else a] in
             adjust_if_negb term
        | _ => term
        end.
      Ltac substitute_bool_eqb term :=
        lazymatch term with
        | context term'[Bool.eqb ?x true]
          => let term := context term'[x] in
             substitute_bool_eqb term
        | context term'[Bool.eqb ?x false]
          => let term := context term'[negb x] in
             substitute_bool_eqb term
        | context term'[Bool.eqb true ?x]
          => let term := context term'[x] in
             substitute_bool_eqb term
        | context term'[Bool.eqb false ?x]
          => let term := context term'[negb x] in
             substitute_bool_eqb term
        | _ => term
        end.

      Ltac substitute_beq base_interp_beq only_eliminate_in_ctx full_ctx ctx term :=
        let base_interp_beq_head := head base_interp_beq in
        lazymatch ctx with
        | dynnil
          => let term := (eval cbv [base.interp_beq base_interp_beq_head] in term) in
             let term := substitute_bool_eqb term in
             let term := remove_andb_true term in
             let term := adjust_if_negb term in
             term
        | dyncons ?v ?ctx
          => let term := substitute_beq_with base_interp_beq only_eliminate_in_ctx full_ctx term Z.eqb v in
             let term := match constr:(Set) with
                         | _ => let T := type of v in
                                let beq := (eval cbv beta delta [Reflect.decb_rel] in (Reflect.decb_rel (@eq T))) in
                                substitute_beq_with base_interp_beq only_eliminate_in_ctx full_ctx term beq v
                         | _ => term
                         end in
             substitute_beq base_interp_beq only_eliminate_in_ctx full_ctx ctx term
        end.

      Ltac deep_substitute_beq base_interp_beq only_eliminate_in_ctx term :=
        lazymatch term with
        | context term'[@Build_rewrite_rule_data ?base ?ident ?var ?pident ?pident_arg_types ?t ?p ?sda ?wo ?ul ?subterm]
          => let subterm := under_binders only_eliminate_in_ctx subterm ltac:(fun only_eliminate_in_ctx ctx term => substitute_beq base_interp_beq only_eliminate_in_ctx ctx ctx term) dynnil in
             let term := context term'[@Build_rewrite_rule_data base ident var pident pident_arg_types t p sda wo ul subterm] in
             term
        end.

      Ltac clean_beq_internal base_interp_beq only_eliminate_in_ctx term :=
        let base_interp_beq_head := head base_interp_beq in
        let term := (eval cbn [Prod.prod_beq] in term) in
        let term := (eval cbv [ident.literal] in term) in
        let term := deep_substitute_beq base_interp_beq only_eliminate_in_ctx term in
        let term := (eval cbv [base.interp_beq base_interp_beq_head] in term) in
        let term := remove_andb_true term in
        term.
      Ltac clean_beq base_interp_beq only_eliminate_in_ctx term :=
        constr:(ltac:(let v := clean_beq_internal base_interp_beq only_eliminate_in_ctx term in refine v)).

      Ltac adjust_side_conditions_for_gets_inlined' value_ctx side_conditions lookup_gets_inlined :=
        lazymatch side_conditions with
        | context sc[ident.gets_inlined _ ?x]
          => lazymatch value_ctx with
             | context[expr.var_context.cons x ?p _]
               => let rep := constr:(lookup_gets_inlined p) in
                  let side_conditions := context sc[rep] in
                  adjust_side_conditions_for_gets_inlined' value_ctx side_conditions lookup_gets_inlined
             | _ => constr_fail_with ltac:(fun _ => fail 1 "Could not find an expression corresponding to" x "in context" value_ctx)
             end
        | _ => side_conditions
        end.

      Ltac adjust_side_conditions_for_gets_inlined value_ctx side_conditions :=
        let lookup_gets_inlined := fresh in
        constr:(fun lookup_gets_inlined : positive -> bool
                => ltac:(let v := adjust_side_conditions_for_gets_inlined' value_ctx side_conditions lookup_gets_inlined in
                         exact v)).

      Ltac reify_to_pattern_and_replacement_in_context base reify_base base_interp base_interp_beq try_make_transport_base_cps ident reify_ident pident pident_arg_types pident_type_of_list_arg_types_beq pident_of_typed_ident pident_arg_types_of_typed_ident reflect_ident_iota type_ctx var gets_inlined should_do_again cur_i term value_ctx :=
        let base_type := constr:(base.type base) in
        let reify_base_type := ltac:(Compilers.base.reify base reify_base) in
        let base_interp_head := head base_interp in
        let t := fresh "t" in
        let p := fresh "p" in
        let reify_rec_gen type_ctx := reify_to_pattern_and_replacement_in_context base reify_base base_interp base_interp_beq try_make_transport_base_cps ident reify_ident pident pident_arg_types pident_type_of_list_arg_types_beq pident_of_typed_ident pident_arg_types_of_typed_ident reflect_ident_iota type_ctx var gets_inlined should_do_again in
        let var_pos := constr:(fun _ : type base_type => positive) in
        let value := constr:(@value base_type ident var) in
        let cexpr_to_pattern_and_replacement_unfolded := constr:(@expr_to_pattern_and_replacement_unfolded base try_make_transport_base_cps ident var pident pident_arg_types pident_type_of_list_arg_types_beq pident_of_typed_ident pident_arg_types_of_typed_ident (reflect_ident_iota var) gets_inlined should_do_again type_ctx) in
        let cpartial_lam_unif_rewrite_ruleTP_gen := constr:(@partial_lam_unif_rewrite_ruleTP_gen_unfolded base ident var pident pident_arg_types should_do_again) in
        let cwith_unif_rewrite_ruleTP_gen := constr:(fun t p => @with_unif_rewrite_ruleTP_gen base ident var pident pident_arg_types value t p should_do_again true true) in
        lazymatch term with
        | (fun x : ?T => ?f)
          => let rT := Compilers.type.reify reify_base_type base_type T in
             let not_x1 := fresh in
             let not_x2 := fresh in
             let next_i := (eval vm_compute in (Pos.succ cur_i)) in
             let type_ctx' := fresh in (* COQBUG(https://github.com/coq/coq/issues/7210#issuecomment-470009463) *)
             let rf0 :=
                 constr:(
                   match type_ctx return _ with
                   | type_ctx'
                     => fun (x : T)
                        => match f, @expr.var_context.cons base_type var_pos T rT x cur_i value_ctx return _ with (* c.f. COQBUG(https://github.com/coq/coq/issues/6252#issuecomment-347041995) for [return _] *)
                           | not_x1, not_x2
                             => ltac:(
                                  let f := (eval cbv delta [not_x1] in not_x1) in
                                  let value_ctx := (eval cbv delta [not_x2] in not_x2) in
                                  let type_ctx := (eval cbv delta [type_ctx'] in type_ctx') in
                                  clear not_x1 not_x2 type_ctx';
                                  let rf := reify_rec_gen type_ctx next_i f value_ctx in
                                  exact rf)
                           end
                   end) in
             lazymatch rf0 with
             | (fun _ => ?f) => f
             | _
               => constr_fail_with ltac:(fun _ => fail 1 "Failure to eliminate functional dependencies of" rf0)
             end
        | (@eq ?T ?A ?B, ?side_conditions)
          => let rA := expr.reify_in_context base_type ident reify_base_type reify_ident var_pos A value_ctx tt in
             let rB := expr.reify_in_context base_type ident reify_base_type reify_ident var_pos B value_ctx tt in
             let side_conditions := adjust_side_conditions_for_gets_inlined value_ctx side_conditions in
             let invalid := fresh "invalid" in
             let res := constr:(fun invalid => cexpr_to_pattern_and_replacement_unfolded invalid _ rA rB side_conditions) in
             let res := (eval cbv [expr_to_pattern_and_replacement_unfolded pident_arg_types pident_of_typed_ident pident_type_of_list_arg_types_beq pident_arg_types_of_typed_ident (*reflect_ident_iota*)] in res) in
             let res := (eval cbn [fst snd andb pattern.base.relax pattern.base.subst_default pattern.base.subst_default_relax] in res) in
             let res := change_pattern_base_subst_default_relax res in
             let p := (eval cbv [projT1] in (fun invalid => projT1 (res invalid))) in
             let p := strip_invalid_or_fail p in
             let p := adjust_pattern_type_variables p in
             let res := (eval cbv [projT2] in (fun invalid => projT2 (res invalid))) in
             let evm' := fresh "evm" in
             let res' := fresh in
             let res :=
                 constr:(
                   fun invalid (evm' : EvarMap_at base)
                   => match res invalid return _ with
                      | res'
                        => ltac:(let res := (eval cbv beta delta [res'] in res') in
                                 clear res';
                                 let res := adjust_lookup_default res in
                                 let res := adjust_type_variables res in
                                 let res := replace_evar_map evm' res in
                                 let res := replace_type_try_transport res in
                                 exact res)
                      end) in
             let res := (eval cbv [UnderLets.map UnderLets.flat_map reify_expr_beta_iota reflect_expr_beta_iota reify_to_UnderLets] in res) in
             let res := (eval cbn [reify reflect UnderLets.of_expr UnderLets.to_expr UnderLets.splice value' Base_value invert_Literal invert_ident_Literal splice_under_lets_with_value] in res) in
             let res := strip_invalid_or_fail res in
             (* cbv here not strictly needed *)
             let res := (eval cbv [partial_lam_unif_rewrite_ruleTP_gen_unfolded] in
                            (existT
                               (cwith_unif_rewrite_ruleTP_gen _)
                               p
                               (cpartial_lam_unif_rewrite_ruleTP_gen _ p res))) in
             (* not strictly needed *)
             let res := (eval cbn [pattern.base.subst_default pattern.base.lookup_default PositiveMap.find type.interp base.interp base_interp_head] in res) in
             let res := (eval cbv [projT1 projT2] in
                            (existT
                               (@rewrite_ruleTP base ident var pident pident_arg_types)
                               {| pattern.pattern_of_anypattern := projT1 res |}
                               {| rew_replacement := projT2 res |})) in
             let res := clean_beq base_interp_beq value_ctx res in
             res
        end.

      Ltac reify base reify_base base_interp base_interp_beq try_make_transport_base_cps ident reify_ident pident pident_arg_types pident_type_of_list_arg_types_beq pident_of_typed_ident pident_arg_types_of_typed_ident reflect_ident_iota var gets_inlined should_do_again lem :=
        let base_type := constr:(Compilers.base.type base) in
        let base_type_interp := constr:(@Compilers.base.interp base base_interp) in
        reify_under_forall_types
          base_type
          base_type_interp
          lem
          ltac:(
          fun ty_ctx cur_i lem
          => let lem := equation_to_parts lem in
             let res := reify_to_pattern_and_replacement_in_context base reify_base base_interp base_interp_beq try_make_transport_base_cps ident reify_ident pident pident_arg_types pident_type_of_list_arg_types_beq pident_of_typed_ident pident_arg_types_of_typed_ident reflect_ident_iota ty_ctx var gets_inlined should_do_again constr:(1%positive) lem (@expr.var_context.nil (base.type base) (fun _ => positive)) in
             res).

      Ltac Reify base reify_base base_interp base_interp_beq try_make_transport_base_cps ident reify_ident pident pident_arg_types pident_type_of_list_arg_types_beq pident_of_typed_ident pident_arg_types_of_typed_ident reflect_ident_iota gets_inlined should_do_again lem :=
        let var := fresh "var" in
        constr:(fun var : Compilers.type.type (Compilers.base.type base) -> Type
                => ltac:(let res := reify base reify_base base_interp base_interp_beq try_make_transport_base_cps ident reify_ident pident pident_arg_types pident_type_of_list_arg_types_beq pident_of_typed_ident pident_arg_types_of_typed_ident reflect_ident_iota var (gets_inlined var) should_do_again lem in
                         exact res)).

      (* lems is either a list of [Prop]s, or a list of [bool (* should_do_again *) * Prop] *)
      Ltac reify_list base reify_base base_interp base_interp_beq try_make_transport_base_cps ident reify_ident pident pident_arg_types pident_type_of_list_arg_types_beq pident_of_typed_ident pident_arg_types_of_typed_ident reflect_ident_iota var gets_inlined lems :=
        let reify' := reify base reify_base base_interp base_interp_beq try_make_transport_base_cps ident reify_ident pident pident_arg_types pident_type_of_list_arg_types_beq pident_of_typed_ident pident_arg_types_of_typed_ident reflect_ident_iota var gets_inlined in
        let reify_list_rec := reify_list base reify_base base_interp base_interp_beq try_make_transport_base_cps ident reify_ident pident pident_arg_types pident_type_of_list_arg_types_beq pident_of_typed_ident pident_arg_types_of_typed_ident reflect_ident_iota var gets_inlined in
        lazymatch (eval hnf in lems) with
        | (?b, ?lem) :: ?lems
          => let rlem := reify' b lem in
             let rlems := reify_list_rec lems in
             constr:(rlem :: rlems)
        | nil => constr:(@nil (@rewrite_ruleT base ident var pident pident_arg_types))
        | _
          => let List_map := (eval cbv delta [List.map] in (@List.map)) in
             let lems := (eval cbv beta iota in
                             (List_map _ _ (fun p : Prop => (false, p)) lems)) in
             reify_list_rec lems
        end.

      Ltac Reify_list base reify_base base_interp base_interp_beq try_make_transport_base_cps ident reify_ident pident pident_arg_types pident_type_of_list_arg_types_beq pident_of_typed_ident pident_arg_types_of_typed_ident reflect_ident_iota gets_inlined lems :=
        let var := fresh "var" in
        constr:(fun var : Compilers.type.type (Compilers.base.type base) -> Type
                => ltac:(let res := reify_list base reify_base base_interp base_interp_beq try_make_transport_base_cps ident reify_ident pident pident_arg_types pident_type_of_list_arg_types_beq pident_of_typed_ident pident_arg_types_of_typed_ident reflect_ident_iota var (gets_inlined var) lems in
                         exact res)).
    End Reify.

    Module Make.
      Export Rewriter.Compilers.RewriteRules.Make.
      Import pattern.ident.GoalType.

      Ltac build_pident_pair exprExtraInfo pkg :=
        let v := (eval vm_compute in
                     (fun A B => @of_typed_ident_of pkg _ (@ident.ident_pair _ _ _ (@Classes.buildIdent _ exprExtraInfo) A B))) in
        let h := lazymatch v with fun A B => ?f _ _ => f end in
        h.
      Section make_rewrite_rules.
        Import Compile.
        Section expanded.
          Context {base : Type}.
          Local Notation base_type := (base.type base).
          Local Notation type := (type.type base_type).
          Context {base_interp : base -> Type}
                  {ident : type -> Type}
                  {ident_interp : forall t, ident t -> type.interp (base.interp base_interp) t}
                  {BuildIdentT : @ident.BuildIdentT base base_interp ident}
                  {baseDefault : @DefaultValue.type.base.DefaultT base base_interp}
                  {pkg : @package base ident}
                  {var : type -> Type}.
          Local Notation expr := (@expr.expr base_type ident var).
          Local Notation value := (@value base_type ident var).
          Local Notation pattern := (@pattern.pattern base pattern_ident).
          Local Notation UnderLets := (@UnderLets.UnderLets base_type ident var).
          Local Notation pbase_type := (pattern.base.type base).
          Local Notation ptype := (type.type pbase_type).
          Let type_base {base} (t : base.type base) : type.type (base.type base) := type.base t.
          Let ptype_base {base} (t : pattern.base.type base) : type.type (pattern.base.type base) := type.base t.
          Let type_base' (t : base) : base_type := base.type.type_base t.
          Let ptype_base' (t : base) : pbase_type := pattern.base.type.type_base t.
          Let type_base'' (t : base) : type := type.base (base.type.type_base t).
          Let ptype_base'' (t : base) : ptype := type.base (pattern.base.type.type_base t).
          Coercion ptype_base'' : base >-> ptype.
          Coercion type_base : base_type >-> type.
          Coercion ptype_base : pbase_type >-> ptype.
          Local Notation collect_vars := (@pattern.collect_vars base pattern_ident).
          Local Notation with_unification_resultT' := (@with_unification_resultT' base pattern_ident (@arg_types) value).
          Local Notation with_unification_resultT := (@with_unification_resultT base pattern_ident (@arg_types) value).
          Local Notation under_with_unification_resultT' := (@under_with_unification_resultT' base pattern_ident (@arg_types) value).
          Local Notation under_with_unification_resultT := (@under_with_unification_resultT base pattern_ident (@arg_types) value).
          Local Notation rewrite_ruleTP := (@rewrite_ruleTP base ident var pattern_ident (@arg_types)).
          Local Notation rewrite_ruleT := (@rewrite_ruleT base ident var pattern_ident (@arg_types)).
          Local Notation rewrite_rule_data := (@rewrite_rule_data base ident var pattern_ident (@arg_types)).

          Definition make_base_Literal_pattern_folded (t : base) : pattern t
            := (*Eval cbv [of_typed_ident_unfolded] in*)
              pattern.Ident (of_typed_ident_unfolded (type_base'' t) (ident.ident_Literal (t:=t) (DefaultValue.type.base.default (t:=type_base' t)))).

          Context (pident_pair : forall A B : pbase_type, pattern_ident (A -> B -> A * B)%ptype).

          Fixpoint make_Literal_pattern (t : pbase_type) : option (pattern t)
            := match t return option (pattern t) with
               | pattern.base.type.var _ => None
               | pattern.base.type.type_base t => Some (make_base_Literal_pattern_folded t)
               | pattern.base.type.prod A B
                 => (a <- make_Literal_pattern A;
                       b <- make_Literal_pattern B;
                       Some ((#(pident_pair _ _) @ a @ b)%pattern))
               | pattern.base.type.unit => None
               | pattern.base.type.list A => None
               | pattern.base.type.option A => None
               end%option.

          Fixpoint make_interp_rewrite_pattern {t}
            : pattern t -> option (pattern (type.final_codomain t))
            := match t return pattern t -> option (pattern (type.final_codomain t)) with
               | type.base t
                 => fun p => Some p
               | type.arrow (type.base s) d
                 => fun p => (x <- make_Literal_pattern s; @make_interp_rewrite_pattern d (pattern.App p x))%option
               | type.arrow _ _ => fun _ => None
               end.

          Lemma collect_vars_literal_empty {t}
            : match make_Literal_pattern t with
              | Some p => collect_vars p = PositiveSet.empty /\ pattern.base.collect_vars t = PositiveSet.empty
              | None => True
              end.
          Proof using Type.
            induction t; cbn; cbv [Option.bind ptype_base] in *; break_innermost_match; cbn; auto.
            destruct_head'_and.
            repeat match goal with H : _ |- _ => rewrite H end; cbn; auto.
          Qed.

          Context (cast_Literal_base_pattern_interp
                   : forall (evm : EvarMap) (t : base),
                      unification_resultT' (var:=var) (@arg_types) (make_base_Literal_pattern_folded t) evm
                      -> base.interp base_interp (pattern.base.subst_default (ptype_base' t) evm)).

          Fixpoint make_Literal_pattern_interp_helper {t evm T}
                   {struct t}
            : match make_Literal_pattern t with
              | Some x
                => (base.interp base_interp (pattern.base.subst_default t evm) -> T)
                   -> with_unification_resultT' x evm T
              | None => True
              end.
          Proof.
            refine match t return match make_Literal_pattern t with
                                  | Some x
                                    => (base.interp base_interp (pattern.base.subst_default t evm) -> T)
                                       -> with_unification_resultT' x evm T
                                  | None => True
                                  end
                   with
                   | pattern.base.type.var _
                   | pattern.base.type.list _
                   | pattern.base.type.option _
                   | pattern.base.type.unit
                     => I
                   | pattern.base.type.type_base t
                     => fun f => lam_unification_resultT' _ (fun x => f (cast_Literal_base_pattern_interp _ _ x))
                   | pattern.base.type.prod A B
                     => let recA := @make_Literal_pattern_interp_helper
                                      A evm
                                      (match make_Literal_pattern A, make_Literal_pattern B return Type with
                                       | Some a, Some b => _
                                       | _, _ => unit
                                       end) in
                        let recB := @make_Literal_pattern_interp_helper
                                      B evm
                                      (match make_Literal_pattern A, make_Literal_pattern B return Type with
                                       | Some a, Some b => _
                                       | _, _ => unit
                                       end) in
                        _
                   end;
              clearbody recA recB;
              cbn [make_Literal_pattern] in *.
            destruct (make_Literal_pattern A) as [a|], (make_Literal_pattern B) as [b|]; try exact I; cbn [Option.bind with_unification_resultT'].
            refine (fun f
                    => lam_type_of_list
                         (fun _ => recA (fun a' => recB (fun b' => f (a', b'))))).
          Defined.

          (** We can only do this because we're dealing with literal patterns that have no variables *)
          Definition strip_collect_vars
                     {s : pbase_type} {d : ptype}
                     {p : pattern (type.base s -> d)%ptype}
                     (p_res : pattern.type.forall_vars
                                (collect_vars p)
                                (fun evm =>
                                   with_unification_resultT'
                                     p evm
                                     (type.interp (base.interp base_interp) (pattern.type.subst_default (type.base s -> d)%ptype evm))))
            : forall (rec : forall x : pattern (type.base s),
                         pattern.type.forall_vars (PositiveSet.union (collect_vars x) (collect_vars p))
                                                  (fun evm =>
                                                     with_unification_resultT'
                                                       p evm
                                                       (with_unification_resultT'
                                                          x evm
                                                          (type.interp (base.interp base_interp) (pattern.type.subst_default d evm))))
                         -> match make_interp_rewrite_pattern (p @ x) with
                            | Some p' => @rewrite_rule_data _ p'
                            | None => True
                            end),
              match (x <- make_Literal_pattern s;
                       make_interp_rewrite_pattern (p @ x))%option with
              | Some p' => @rewrite_rule_data _ p'
              | None => True
              end.
          Proof.
            intro rec_call.
            pose proof (@collect_vars_literal_empty s) as H.
            pose proof (@make_Literal_pattern_interp_helper s) as F.
            destruct (make_Literal_pattern s) as [x|]; [ | exact I ]; cbn [Option.bind].
            cbv [ptype_base] in *.
            refine (rec_call x _); clear rec_call.
            destruct (pattern.collect_vars x); [ | exfalso; clear -H; abstract (destruct H as [H _]; cbv in H; discriminate) ].
            refine (pattern.type.under_forall_vars (fun evm => under_with_unification_resultT' (F _ _)) p_res).
          Defined.

          Fixpoint make_interp_rewrite'_helper {t}
            : forall (p : pattern t)
                     (base_rewrite : with_unification_resultT p (type.interp (base.interp base_interp)))
                     (p' := make_interp_rewrite_pattern p),
              match p' return Type with
              | Some p' => rewrite_ruleTP {| pattern.pattern_of_anypattern := p' |}
              | None => True
              end
            := match t return (forall (p : pattern t)
                                      (base_rewrite : with_unification_resultT p (type.interp (base.interp base_interp)))
                                      (p' := make_interp_rewrite_pattern p),
                                  match p' return Type with
                                  | Some p' => rewrite_ruleTP {| pattern.pattern_of_anypattern := p' |}
                                  | None => True
                                  end)
               with
               | type.base t
                 => fun p base_rewrite
                    => {| rew_should_do_again := false;
                          rew_with_opt := false;
                          rew_under_lets := false;
                          rew_replacement
                          := under_with_unification_resultT
                               (fun evm v => ident.smart_Literal v)
                               base_rewrite |}
               | type.arrow (type.base s) d
                 => fun p base_rewrite
                    => let rec_call
                           := fun x => @make_interp_rewrite'_helper d (p @ x)%pattern in
                       strip_collect_vars base_rewrite rec_call
               | type.arrow _ _
                 => fun _ _ => I
               end.

          Definition make_interp_rewrite' {t} (idc : ident t)
                     (pidc := pattern.Ident (@of_typed_ident _ idc))
                     (val : with_unification_resultT pidc (type.interp (base.interp base_interp)))
            : option rewrite_ruleT
            := match make_interp_rewrite_pattern pidc as p
                     return match p return Type with
                            | Some p' => rewrite_ruleTP {| pattern.pattern_of_anypattern := p' |}
                            | None => True
                            end
                            -> option rewrite_ruleT
               with
               | Some p'
                 => fun r
                    => Some (existT _ {| pattern.pattern_of_anypattern := p' |} r)
               | None => fun _ => None
               end (make_interp_rewrite'_helper pidc val).

          Definition make_default_with_unification_resultT {t vs ls} (v : type.interp (base.interp base_interp) t)
            : pattern.type.forall_vars
                vs
                (fun evm =>
                   fold_right (fun a K : Type => a -> K)
                              (type.interp (base.interp base_interp) (pattern.type.subst_default (pattern.type.relax t) evm))
                              ls)
            := pattern.type.lam_forall_vars
                 (fun evm
                  => list_rect
                       (fun ls => fold_right (fun a K => a -> K) _ ls)
                       (pattern.type.subst_default_relax (t:=t) _ v)
                       (fun x xs rec _ => rec)
                       _).

          Definition make_interp_rewrite'' {t} (idc : ident t) : option rewrite_ruleT
            := @make_interp_rewrite'
                 t idc (make_default_with_unification_resultT (ident_interp _ idc)).

          Definition interp_rewrite_rules_folded' : list _
            := Option.List.map
                 (fun tidc => make_interp_rewrite'' (PrimitiveSigma.Primitive.projT2 tidc))
                 simple_idents.
        End expanded.

        Section bundled.
          Context {exprInfo : Classes.ExprInfoT}
                  {exprExtraInfo : Classes.ExprExtraInfoT}
                  {pkg : @package Classes.base Classes.ident}.

          Definition interp_rewrite_rules_folded {var} pident_pair cast_Literal_base_pattern_interp : list _
            := @interp_rewrite_rules_folded' _ _ _ Classes.ident_interp _ _ _ var pident_pair cast_Literal_base_pattern_interp.
        End bundled.
      End make_rewrite_rules.

      Ltac build_interp_rewrite_rules exprInfo exprExtraInfo pkg :=
        let exprInfo := (eval hnf in exprInfo) in
        let exprExtraInfo := (eval hnf in exprExtraInfo) in
        let pident_pair := build_pident_pair exprExtraInfo pkg in
        let ident_interp := (eval cbv [Classes.ident_interp] in (@Classes.ident_interp exprInfo)) in
        let ident_interp_head := head ident_interp in
        let base_interp_beq := (eval cbv [Classes.base_interp_beq] in (@Classes.base_interp_beq exprInfo exprExtraInfo)) in
        let base_interp_beq_head := head base_interp_beq in
        let x := fresh "x" in
        let v := (eval cbv -[ident_interp_head ident.smart_Literal base_interp_beq_head] in
                     (fun var
                      => @interp_rewrite_rules_folded
                           exprInfo exprExtraInfo pkg var pident_pair (fun evm t x => Datatypes.fst x))) in
        let v := (eval cbv [ident_interp_head ident.smart_Literal ident.ident_Literal ident.ident_tt ident.ident_pair] in v) in
        v.

      Module Import AdjustRewriteRulesForReduction.
        Import PrimitiveHList.
        (* N.B. The [combine_hlist] call MUST eta-expand
           [pr2_rewrite_rules].  That is, it MUST NOT block reduction
           of the resulting list of cons cells on the pair-structure
           of [pr2_rewrite_rules].  This is required so that we can
           use [cbv -] to unfold the entire decision tree
           evaluation, including choosing which rewrite rule to apply
           and binding its arguments, without unfolding any of the
           identifiers used to define the replacement value.  (The
           symptom of messing this up is that the [cbv -] will run out
           of memory when trying to reduce things.)  We accomplish
           this by making [hlist] based on a primitive [prod] type
           with judgmental η, so that matching on its structure never
           blocks reduction. *)
        Ltac make_split_rewrite_rules rewrite_rules :=
          let split_rewrite_rules := fresh "split_rewrite_rules" in
          let v := constr:(fun var => split_list (rewrite_rules var)) in
          let h := head rewrite_rules in
          let do_reduce_rules := lazymatch h with
                                 | @cons => false
                                 | @nil => false
                                 | _ => true
                                 end in
          let v := lazymatch do_reduce_rules with
                   | true => (eval cbv [split_list projT1 projT2 h] in v)
                   | false => (eval cbv [split_list projT1 projT2] in v)
                   end in
          cache_term v split_rewrite_rules.
        Ltac make_pr1_rewrite_rules split_rewrite_rules :=
          let var := fresh "var" in
          constr:(fun var => ltac:(let v := (eval hnf in (projT1 (split_rewrite_rules var))) in
                                   exact v)).
        Ltac make_pr2_rewrite_rules split_rewrite_rules :=
          let pr2_rewrite_rules := fresh "pr2_rewrite_rules" in
          let var := fresh "var" in
          let v :=
              constr:(fun var
                      => ltac:(let v := (eval hnf in (projT2 (split_rewrite_rules var))) in
                               exact v)) in
          cache_term v pr2_rewrite_rules.

        Ltac make_all_rewrite_rules pkg pr1_rewrite_rules pr2_rewrite_rules :=
          let pkg_type := type of pkg in
          let ident := lazymatch (eval hnf in pkg_type) with @package ?base ?ident => ident end in
          let all_rewrite_rules := fresh "all_rewrite_rules" in
          let var := fresh "var" in
          cache_term
            (fun var
             => combine_hlist (P:=@Compile.rewrite_ruleTP _ ident var (@pattern_ident _ _ pkg) (@arg_types_of pkg)) (pr1_rewrite_rules var) (pr2_rewrite_rules var))
            all_rewrite_rules.
      End AdjustRewriteRulesForReduction.

      Ltac Reify reify_base reify_ident exprInfo exprExtraInfo pkg ident_is_var_like include_interp specs :=
        let exprInfo := (eval hnf in exprInfo) in
        let exprExtraInfo := (eval hnf in exprExtraInfo) in
        let pkg := (eval hnf in pkg) in
        lazymatch constr:((exprInfo, exprExtraInfo, pkg)) with
        | ({| Classes.base := ?base
              ; Classes.ident := ?ident
              ; Classes.base_interp := ?base_interp
           |}
           , {| Classes.base_interp_beq := ?base_interp_beq
                ; Classes.try_make_transport_base_cps := ?try_make_transport_base_cps
                ; Classes.baseHasNat := ?baseTypeHasNat
                ; Classes.buildIdent := ?buildIdent
                ; Classes.toRestrictedIdent := ?toRestrictedIdent
                ; Classes.buildEagerIdent := ?buildEagerIdent
                ; Classes.invertIdent := ?invertIdent
                ; Classes.baseHasNatCorrect := ?baseHasNatCorrect
                ; Classes.toFromRestrictedIdent := ?toFromRestrictedIdent
             |}
           , {| pattern_ident := ?pattern_ident
                ; arg_types_unfolded := ?arg_types_unfolded
                ; type_of_list_arg_types_beq_unfolded := ?type_of_list_arg_types_beq_unfolded
                ; of_typed_ident_unfolded := ?of_typed_ident_unfolded
                ; arg_types_of_typed_ident_unfolded := ?arg_types_of_typed_ident_unfolded
             |})
          => let base_type := constr:(Compilers.base.type base) in
             let reflect_ident_iota := constr:(@Compile.reflect_ident_iota base ident base_interp baseTypeHasNat buildIdent buildEagerIdent toRestrictedIdent toFromRestrictedIdent invertIdent baseHasNatCorrect try_make_transport_base_cps) in
             let lems := Reify.Reify_list base reify_base base_interp base_interp_beq try_make_transport_base_cps ident reify_ident pattern_ident arg_types_unfolded type_of_list_arg_types_beq_unfolded of_typed_ident_unfolded arg_types_of_typed_ident_unfolded reflect_ident_iota (fun var t => @SubstVarLike.is_recursively_var_or_ident base_type ident var ident_is_var_like (type.base t)) specs in
             lazymatch include_interp with
             | true
               => let myapp := (eval cbv [List.app] in (@List.app)) in
                  let interp_rewrite_rules := build_interp_rewrite_rules exprInfo exprExtraInfo pkg in
                  let res := (eval cbv beta iota in
                                 (fun var => myapp _ (@interp_rewrite_rules var) (lems var))) in
                  let len := lazymatch (eval compute in (fun var => List.length (@interp_rewrite_rules var))) with (fun _ => ?n) => n end in
                  let adjusted_specs := (eval cbv [List.app List.repeat] in
                                            (List.app
                                               (List.repeat (false, forall A (x : A), x = x) len))) in
                  constr:((len, adjusted_specs specs, res))
             | false => constr:((O, specs, lems))
             | _ => constr_fail_with ltac:(fun _ => fail 1 "Invalid value for include_interp (must be either true or false):" include_interp)
             end
        end.

      Ltac make_rewrite_head1 base_interp try_make_transport_base_cps base_beq pident_unify_unknown invert_bind_args_unknown rewrite_head0 pr2_rewrite_rules :=
        time_tac_in_constr_if_debug1
          ltac:(fun _
                => let rewrite_head1
                       := (eval cbv -[pr2_rewrite_rules
                                        base_interp try_make_transport_base_cps (*base_beq*)
                                        base.interp base.try_make_transport_cps
                                        type.try_make_transport_cps
                                        pattern.type.unify_extracted
                                        Compile.option_type_type_beq
                                        Let_In Option.sequence Option.sequence_return
                                        UnderLets.splice UnderLets.to_expr
                                        Compile.option_bind' pident_unify_unknown invert_bind_args_unknown Compile.normalize_deep_rewrite_rule
                                        Compile.reflect UnderLets.reify_and_let_binds_base_cps Compile.reify Compile.reify_and_let_binds_cps
                                        Compile.value'
                                        SubstVarLike.is_recursively_var_or_ident
                                     ] in rewrite_head0) in
                   let rewrite_head1
                       := (eval cbn [type.try_make_transport_cps base.try_make_transport_cps]
                            in rewrite_head1) in
                   rewrite_head1).
      Ltac make_rewrite_head2 pident_unify_unknown invert_bind_args_unknown rewrite_head1 pr2_rewrite_rules :=
        time_tac_in_constr_if_debug1
          ltac:(fun _
                => let rewrite_head2
                       := (eval cbv [id
                                       pr2_rewrite_rules
                                       projT1 projT2
                                       cpsbind cpscall cps_option_bind cpsreturn
                                       PrimitiveProd.Primitive.fst PrimitiveProd.Primitive.snd
                                       pattern.type.subst_default pattern.base.subst_default pattern.base.lookup_default
                                       PositiveMap.add PositiveMap.find PositiveMap.empty
                                       PositiveSet.rev PositiveSet.rev_append
                                       Compile.eval_decision_tree
                                       Compile.eval_rewrite_rules
                                       Compile.expr_of_rawexpr
                                       Compile.normalize_deep_rewrite_rule
                                       Compile.option_bind' pident_unify_unknown invert_bind_args_unknown Compile.normalize_deep_rewrite_rule
                                       Compile.reveal_rawexpr_cps
                                       Compile.reveal_rawexpr_cps_gen
                                       Compile.rew_should_do_again
                                       Compile.rew_with_opt
                                       Compile.rew_under_lets
                                       Compile.rew_replacement
                                       Compile.rValueOrExpr
                                       Compile.swap_list
                                       Compile.type_of_rawexpr
                                       Compile.option_type_type_beq
                                       Compile.value
                                       Compile.value_of_rawexpr
                                       Compile.value_with_lets
                                       ident.smart_Literal
                                       type.try_transport_cps
                                    ] in rewrite_head1) in
                   rewrite_head2).
      Ltac make_rewrite_head3 base_interp try_make_transport_base_cps base_beq rewrite_head2 :=
        time_tac_in_constr_if_debug1
          ltac:(fun _
                => let rewrite_head3
                       := (eval cbn [id
                                       base_interp try_make_transport_base_cps base_beq
                                       cpsbind cpscall cps_option_bind cpsreturn
                                       Compile.reify Compile.reify_and_let_binds_cps Compile.reflect Compile.value'
                                       Option.sequence Option.sequence_return Option.bind
                                       UnderLets.reify_and_let_binds_base_cps
                                       UnderLets.splice UnderLets.splice_list UnderLets.to_expr
                                       base.interp
                                       option_beq
                                       type.try_make_transport_cps base.try_make_transport_cps
                                       Datatypes.fst Datatypes.snd
                                    ] in rewrite_head2) in
                   rewrite_head3).
      Ltac make_rewrite_head' base_interp try_make_transport_base_cps base_beq pident_unify_unknown invert_bind_args_unknown rewrite_head0 pr2_rewrite_rules :=
        let base_interp := head base_interp in
        let try_make_transport_base_cps := head try_make_transport_base_cps in
        let base_beq := head base_beq in
        let __ := debug2 ltac:(fun _ => idtac "rewrite_head0 ===" pr2_rewrite_rules) in
        let rewrite_head1 := make_rewrite_head1 base_interp try_make_transport_base_cps base_beq pident_unify_unknown invert_bind_args_unknown rewrite_head0 pr2_rewrite_rules in
        let __ := debug2 ltac:(fun _ => idtac "rewrite_head1 ===" rewrite_head1) in
        let rewrite_head2 := make_rewrite_head2 pident_unify_unknown invert_bind_args_unknown rewrite_head1 pr2_rewrite_rules in
        let __ := debug2 ltac:(fun _ => idtac "rewrite_head2 ===" rewrite_head2) in
        let rewrite_head3 := make_rewrite_head3 base_interp try_make_transport_base_cps base_beq rewrite_head2 in
        let __ := debug2 ltac:(fun _ => idtac "rewrite_head3 ===" rewrite_head3) in
        rewrite_head3.

      Ltac make_rewrite_head base_interp try_make_transport_base_cps base_beq ident pident_unify_unknown invert_bind_args_unknown skip_early_reduction rewrite_head0 pr2_rewrite_rules :=
        let rewrite_head := fresh "rewrite_head" in
        let var := fresh "var" in
        let do_again := fresh "do_again" in
        let t := fresh "t" in
        let idc := fresh "idc" in
        let v :=
            constr:(
              fun var (do_again : forall t, @expr.expr _ ident (@Compile.value _ ident var) (type.base t) -> @UnderLets.UnderLets _ ident var (@expr.expr _ ident var (type.base t)))
                  t (idc : ident t)
              => ltac:(
                   let rewrite_head0 := constr:(rewrite_head0 var do_again t idc) in
                   let pr2_rewrite_rules := head pr2_rewrite_rules in
                   let v := lazymatch skip_early_reduction with
                            | true => rewrite_head0
                            | false => make_rewrite_head' base_interp try_make_transport_base_cps base_beq pident_unify_unknown invert_bind_args_unknown rewrite_head0 pr2_rewrite_rules
                            | ?v => constr_fail_with ltac:(fun _ => fail 1 "Invalid non-literal-boolean for skip_early_reduction:" v)
                            end in
                   exact v)) in
        cache_term v rewrite_head.

      Ltac Build_rewriter_dataT reify_package exprInfo exprExtraInfo pkg ident_is_var_like include_interp skip_early_reduction skip_early_reduction_no_dtree specs :=
        let pkg_type := type of pkg in
        let base := lazymatch (eval hnf in pkg_type) with @package ?base ?ident => base end in
        let ident := lazymatch (eval hnf in pkg_type) with @package ?base ?ident => ident end in
        let base_interp := lazymatch (eval hnf in exprInfo) with {| Classes.base_interp := ?base_interp |} => base_interp end in
        let try_make_transport_base_cps := lazymatch (eval hnf in exprExtraInfo) with {| Classes.try_make_transport_base_cps := ?try_make_transport_base_cps |} => try_make_transport_base_cps end in
        let base_beq := lazymatch (eval hnf in exprExtraInfo) with {| Classes.base_beq := ?base_beq |} => base_beq end in
        let invert_bind_args_unknown := lazymatch (eval hnf in pkg) with {| invert_bind_args_unknown := ?v |} => v end in
        let pident_unify_unknown := lazymatch (eval hnf in pkg) with {| unify_unknown := ?v |} => v end in
        let __ := debug1 ltac:(fun _ => idtac "Reifying...") in
        let specs_lems :=
          let reify_base := Basic.Tactic.reify_base_via_reify_package reify_package in
          let reify_ident := Basic.Tactic.reify_ident_via_reify_package reify_package in

          Reify reify_base reify_ident exprInfo exprExtraInfo pkg ident_is_var_like include_interp specs in
        let dummy_count := lazymatch specs_lems with (?n, ?specs, ?lems) => n end in
        let specs := lazymatch specs_lems with (?n, ?specs, ?lems) => specs end in
        let rewrite_rules := lazymatch specs_lems with (?n, ?specs, ?lems) => lems end in
        let rewrite_rules_names := fresh "rewrite_rules" in
        let rewrite_rules := cache_term rewrite_rules rewrite_rules_names in
        let __ := debug1 ltac:(fun _ => idtac "Compiling decision tree...") in
        let dtree := Compile.CompileRewrites base ident (@pattern_ident _ _ pkg) (@arg_types_of pkg) (@raw_ident _ _ pkg) (@strip_types_of pkg) (@raw_ident_beq_of pkg) rewrite_rules in
        let default_fuel := (eval compute in (List.length specs)) in
        let __ := debug1 ltac:(fun _ => idtac "Splitting rewrite rules...") in
        let split_rewrite_rules := make_split_rewrite_rules rewrite_rules in
        let pr1_rewrite_rules := make_pr1_rewrite_rules split_rewrite_rules in
        let pr2_rewrite_rules := make_pr2_rewrite_rules split_rewrite_rules in
        let all_rewrite_rules := make_all_rewrite_rules pkg pr1_rewrite_rules pr2_rewrite_rules in
        let __ := debug1 ltac:(fun _ => idtac "Assembling rewrite_head...") in
        let rewrite_head0 := fresh "rewrite_head0" in
        let var := fresh "var" in
        let rewrite_head0
            := cache_term
                 (fun var
                  => @Compile.assemble_identifier_rewriters base (@Classes.try_make_transport_base_cps exprInfo exprExtraInfo) (@Classes.base_beq exprInfo exprExtraInfo) ident var (@eta_ident_cps _ _ pkg) (@pattern_ident _ _ pkg) (@arg_types_of pkg) (@unify _ _ pkg) pident_unify_unknown (@raw_ident _ _ pkg) (@full_types_of pkg) (@invert_bind_args _ _ pkg) invert_bind_args_unknown (@type_of_of pkg) (@raw_to_typed_of pkg) (@is_simple_of pkg) (Some dtree) (all_rewrite_rules var))
                 rewrite_head0 in
        let __ := debug1 ltac:(fun _ => idtac "Reducing rewrite_head...") in
        let rewrite_head := make_rewrite_head base_interp try_make_transport_base_cps base_beq ident pident_unify_unknown invert_bind_args_unknown skip_early_reduction rewrite_head0 pr2_rewrite_rules in
        let __ := debug1 ltac:(fun _ => idtac "Assembling rewrite_head_no_dtree...") in
        let rewrite_head_no_dtree0 := fresh "rewrite_head_no_dtree0" in
        let var := fresh "var" in
        let rewrite_head_no_dtree0
            := cache_term
                 (fun var
                  => @Compile.assemble_identifier_rewriters base (@Classes.try_make_transport_base_cps exprInfo exprExtraInfo) (@Classes.base_beq exprInfo exprExtraInfo) ident var (@eta_ident_cps _ _ pkg) (@pattern_ident _ _ pkg) (@arg_types_of pkg) (@unify _ _ pkg) pident_unify_unknown (@raw_ident _ _ pkg) (@full_types_of pkg) (@invert_bind_args _ _ pkg) invert_bind_args_unknown (@type_of_of pkg) (@raw_to_typed_of pkg) (@is_simple_of pkg) None (all_rewrite_rules var))
                 rewrite_head_no_dtree0 in
        let __ := debug1 ltac:(fun _ => idtac "Reducing rewrite_head_no_dtree...") in
        let rewrite_head_no_dtree := make_rewrite_head base_interp try_make_transport_base_cps base_beq ident pident_unify_unknown invert_bind_args_unknown skip_early_reduction_no_dtree rewrite_head_no_dtree0 pr2_rewrite_rules in
        constr:(@Build_rewriter_dataT'
                  exprInfo exprExtraInfo
                  pkg
                  ident_is_var_like
                  specs dummy_count dtree
                  rewrite_rules all_rewrite_rules eq_refl
                  default_fuel
                  rewrite_head eq_refl
                  rewrite_head_no_dtree eq_refl).

      Module Export Tactic.
        Module Export Settings.
          Global Arguments base.try_make_transport_cps _ !_ !_.
          Global Arguments type.try_make_transport_cps _ _ _ !_ !_.
          Global Arguments Option.sequence A !v1 v2.
          Global Arguments Option.sequence_return A !v1 v2.
          Global Arguments Option.bind A B !_ _.
          Global Arguments id / .
        End Settings.

        Tactic Notation "make_rewriter_data" constr(reify_package) constr(exprInfo) constr(exprExtraInfo) constr(pkg) constr(ident_is_var_like) constr(include_interp) constr(skip_early_reduction) constr(skip_early_reduction_no_dtree) constr(specs) :=
          let res := Build_rewriter_dataT reify_package exprInfo exprExtraInfo pkg ident_is_var_like include_interp skip_early_reduction skip_early_reduction_no_dtree specs in refine res.
      End Tactic.
    End Make.
    Export Make.GoalType.
    Import Make.Tactic.

    Ltac Build_RewriterT reify_package exprInfo exprExtraInfo pkg ident_is_var_like include_interp skip_early_reduction skip_early_reduction_no_dtree specs :=
      let pkg := (eval hnf in pkg) in
      let rewriter_data := fresh "rewriter_data" in
      let data := Make.Build_rewriter_dataT reify_package exprInfo exprExtraInfo pkg ident_is_var_like include_interp skip_early_reduction skip_early_reduction_no_dtree specs in
      let Rewrite_name := fresh "Rewriter" in
      let Rewrite := (eval cbv [Make.Rewrite rewrite_head Make.GoalType.ident_is_var_like Classes.base Classes.base_interp Classes.ident Classes.buildIdent Classes.invertIdent Classes.try_make_transport_base_cps default_fuel] in (@Make.Rewrite exprInfo exprExtraInfo pkg data)) in
      let Rewrite := cache_term Rewrite Rewrite_name in
      constr:(@Build_RewriterT exprInfo exprExtraInfo pkg data Rewrite eq_refl).

    Module Export Tactic.
      Module Export Settings.
        Export Make.Tactic.Settings.
      End Settings.

      Tactic Notation "make_Rewriter" constr(reify_package) constr(exprInfo) constr(exprExtraInfo) constr(pkg) constr(ident_is_var_like) constr(include_interp) constr(skip_early_reduction) constr(skip_early_reduction_no_dtree) constr(specs) :=
        let res := Build_RewriterT reify_package exprInfo exprExtraInfo pkg ident_is_var_like include_interp skip_early_reduction skip_early_reduction_no_dtree specs in refine res.
    End Tactic.
  End RewriteRules.
End Compilers.
