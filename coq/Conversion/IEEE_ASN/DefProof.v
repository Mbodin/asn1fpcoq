Require Import ZArith PArith.
Require Import ASN1FP.Types.ASNDef ASN1FP.Types.IEEEAux
        ASN1FP.Aux.Roundtrip ASN1FP.Aux.StructTactics ASN1FP.Aux.Aux
        ASN1FP.Aux.Tactics ASN1FP.Aux.Option.

Require Import Flocq.Core.Zaux Flocq.IEEE754.Binary.
Require Import Flocq.Core.Defs.

Open Scope Z.

Section Base2.

  Fixpoint normalize (m : positive) (e : Z) : positive * Z :=
    match m with
    | xO p => normalize p (e + 1)
    | _ => (m, e)
    end.

  Variable prec emax : Z.
  Variable prec_gt_1 : prec > 1.

  (* only radix = 2 is considered for both formats in this section
   * scaling factor is, therefore, not required in BER
   * TODO: for arbitrary radix/scaling combinations, refer to another section
   *)
  Let r := radix2.
  Let scl := 0.

  (* can a given (m,e) pair be represented in IEEE/BER exactly *)
  Let valid_IEEE := bounded prec emax.
  Let valid_BER := valid_BER r scl.

  (* aux: apply variables *)
  Let IEEE_float := binary_float prec emax.
  Let valid_IEEE_sumbool := binary_bounded_sumbool prec emax.
  Let BER_finite_b2 := BER_finite r scl.
  Let valid_BER_sumbool := valid_BER_sumbool r scl.

  (* 1 can always be the payload of a NaN *)
  Lemma def_NaN :
    nan_pl prec 1 = true.
  Proof.
    unfold nan_pl. simpl.
    apply Z.ltb_lt, Z.gt_lt, prec_gt_1.
  Qed.

  Lemma prec_gt_0 : Flocq.Core.FLX.Prec_gt_0 prec.
  Proof.
    unfold Flocq.Core.FLX.Prec_gt_0.
    apply (Z.lt_trans 0 1 prec).
    - (* 1 < 0 *)
      reflexivity.
    - (* 1 < prec *)
      apply Z.gt_lt.
      apply prec_gt_1.
  Qed.

  Section Def.

    (* TODO: recursive definition *)
    (*
     * given a pair (m,e), return (mx, ex) such that
     *   m*2^e = mx*2^ex
     * and
     *   m is odd
     *)
    Definition normalize_BER_finite (m : positive) (e : Z) : (positive * Z) :=
      let t := N.log2 (((Pos.lxor m (m-1)) + 1) / 2) in
      (Pos.shiftr m t, e + (Z.of_N t)).

    (*
     * given all meaningful parts of a BER real, construct it, if possible
     * The content is normalized in accordance with [ 11.3.1 ] if possible
     *)
    Definition make_BER_finite (s : bool) (m : positive) (e : Z)
      : option BER_float :=
      let '(mx, ex) := normalize_BER_finite m e in
      match valid_BER_sumbool mx ex with
      | left V => Some (BER_finite_b2 s mx ex V)
      | right _ => None
      end.
    
    (* TODO: radix, scaling (determine `b` and `ff`) *)
    (*
     * exact conversion from IEEE to BER
     * no rounding is performed: if conversion is impossible without rounding
     * `None` is returned
     *)
    Definition BER_of_IEEE_exact (f : IEEE_float) : option BER_float :=
      match f with
      | B754_zero _ _ s => Some (BER_zero s)
      | B754_infinity _ _ s => Some (BER_infinity s)
      | B754_nan _ _ _ _ _ => Some (BER_nan)
      | B754_finite _ _ s m e _ => make_BER_finite s m e
      end.

    (*
     * turn any pair (m,e) into a pair (mx,ex), representable in
     * IEEE 745 if possible. No rounding is performed,
     * (m,e) remains unchanged if normalization is impossible without rounding
     *)
    Definition normalize_IEEE_finite : positive -> Z -> (positive * Z) :=
      shl_align_fexp prec emax.

    (* given all meaningful parts of an IEEE float, construct it, if possible *)
    Definition make_IEEE_finite (s : bool) (m : positive) (e : Z) : option IEEE_float :=
      let '(mx, ex) := normalize_IEEE_finite m e in
      match (valid_IEEE_sumbool mx ex) with
      | left V => Some (B754_finite _ _ s mx ex V)
      | right _ => None
      end.

    (*
     * exact conversion from BER to IEEE
     * radix2 with no scaling asssumed: if input does not match, 'None' returned
     * no rounding is performed: if conversion is impossible without rounding
     * `None` is returned
     *)
    Definition IEEE_of_BER_exact (f : BER_float) : option IEEE_float := 
      match f with
      | BER_zero s => Some (B754_zero _ _ s)
      | BER_infinity s => Some (B754_infinity _ _ s)
      | BER_nan => Some (B754_nan _ _ false 1 def_NaN)
      | BER_finite b f s m e _ =>
        if andb (b =? 2) (f =? 0) then
          make_IEEE_finite s m e
        else None
      end.

    (*
     *  given a triple (s,m,e) standing for s*m*2^e,
     *  return a corresponding binary_float,
     *  correctly rounded in accordance with the specified rounding mode
     *)
    Definition round_finite
               (Hmax : prec < emax) (rounding : mode)
               (s : bool) (m : positive) (e : Z) : IEEE_float :=
      binary_normalize
        prec emax prec_gt_0 Hmax
        rounding
        (cond_Zopp s (Zpos m)) e s.

    (*
     *  for any ASN.1 BER-encoded real number s*m*(b^e)
     *  return the number's representation in the target IEEE format
     *  rounded in accordnace with the provided rounding mode if necessary
     *
     *  NOTE:
     *  1) If initial BER encoding has radix /= 2 or scaling factor /= 0
     *     `None` is returned
     *  2) If the ASN encoding is a NaN,
     *     float's NaN payload is set to 1
     *)
    Definition IEEE_of_BER_rounded (Hmax : prec < emax) (rounding : mode) (r : BER_float) : option (IEEE_float) :=
      match r with
      | BER_zero s => Some (B754_zero _ _ s)
      | BER_infinity s => Some (B754_infinity _ _ s)
      | BER_nan => Some (B754_nan _ _ false 1 def_NaN)
      | BER_finite b f s m e x =>
        if andb (b =? 2) (f =? 0)
        then Some (round_finite Hmax rounding s m e)
        else None
      end.
    
    (*
     *  given a binary_float and a rounding mode
     *  convert it to target format, rounding if necessary
     *
     *  NaN payload is set to 1 uncoditionally
     *)
    Definition IEEE_of_IEEE_round_reset_nan (Hmax : prec < emax) (rounding : mode) (f : IEEE_float) : IEEE_float :=
      match f with
      | B754_nan _ _ _ _ _ => B754_nan _ _ false 1 def_NaN
      | B754_infinity _ _ s => B754_infinity _ _ s
      | B754_zero _ _ s => B754_zero _ _ s
      | B754_finite _ _ s m e _ => round_finite Hmax rounding s m e
      end.

  End Def.

  Section Proof.
    
    Theorem arithmetic_roundtrip (m : positive) (e : Z) :
      valid_IEEE m e = true ->
      uncurry normalize_IEEE_finite (normalize_BER_finite m e) = (m, e).
    Proof.
      intros H.
      unfold uncurry.
      break_let.
      rename p into mx, z into ex.
      unfold normalize_BER_finite in *.
      unfold normalize_IEEE_finite, shl_align_fexp, shl_align.
      subst valid_IEEE valid_BER.
      clear IEEE_float valid_IEEE_sumbool valid_BER_sumbool BER_finite_b2 r scl.
      unfold bounded, canonical_mantissa in *.
      split_andb.
      apply Zeq_bool_eq in H0.
      apply Zle_bool_imp_le in H1.
      tuple_inversion.
      unfold FLT.FLT_exp in *.

    Admitted.

    Ltac inv_make_BER_finite :=
      match goal with
      | [ H : make_BER_finite _ _ _ = Some _ |- _ ] =>
        unfold make_BER_finite in H;
        destruct normalize_BER_finite;
        destruct valid_BER_sumbool;
        inversion H
    end.

    Ltac bcompare_nrefl :=
      match goal with
      | [ H: Bcompare _ _ _ _ = _ |- _] =>
        assert (H1 := H); rewrite -> Bcompare_swap in H1; rewrite -> H in H1; inversion H1
      end.
    
    Theorem main_roundtrip (scaled : bool) (f : IEEE_float):
      roundtrip_option
        IEEE_float BER_float IEEE_float
        (BER_of_IEEE_exact)
        IEEE_of_BER_exact
        (float_eqb_nan_t)
        f.
    Proof.
      intros FPT.
      unfold bool_het_inverse'; simpl.
      break_match.
      - (* forward pass successful *)
        clear FPT.
        break_match.
        + (* backward pass successful *)
          destruct f; destruct b; simpl in *; repeat try some_inv; try auto.
          (* structural errors *)
          * unfold float_eqb_nan_t, Bcompare.
            repeat break_match; (repeat try some_inv);
              try compare_nrefl; try reflexivity.
          * inv_make_BER_finite.
          * inv_make_BER_finite.
          * inv_make_BER_finite.
          * (* arithmetic_roundtrip comes in play *)
             destruct ((b =? 2) && (f =? 0))%bool; inversion Heqo0; clear H0.
    
            (* simplify forward conversions *)
            unfold make_BER_finite in *.
            destruct normalize_BER_finite eqn:NB.
            destruct valid_BER_sumbool; inversion Heqo.
            clear Heqo; subst.
    
            (* simplify backward conversions *)
            unfold make_IEEE_finite in *.
            destruct normalize_IEEE_finite eqn:NI.
            destruct valid_IEEE_sumbool; inversion Heqo0.
            clear Heqo0; subst.
    
            (* apply arithmetic roundtrip *)
            copy_apply (arithmetic_roundtrip m e) e0.
            rewrite -> NB in H.
            simpl in H.
            rewrite -> NI in H.
            inversion H; subst.
            unfold float_eqb_nan_t, Bcompare.
            repeat break_match; (repeat try some_inv);
              try compare_nrefl; try reflexivity.
    
        + (* backward pass unsuccessful *)
          destruct f; simpl in Heqo; inversion Heqo; subst; inversion Heqo0.
          clear H0 H1; exfalso.
          unfold make_BER_finite in Heqo.
          destruct normalize_BER_finite eqn:NB, valid_BER_sumbool;
            inversion Heqo; clear Heqo.
          subst.
          unfold BER_finite_b2 in Heqo0.
          simpl in Heqo0.
          unfold make_IEEE_finite in Heqo0.
          destruct normalize_IEEE_finite eqn:NI.
          destruct valid_IEEE_sumbool; inversion Heqo0; clear Heqo0.
          copy_apply (arithmetic_roundtrip m e) e0.
          rewrite -> NB in H.
          simpl in H.
          rewrite -> NI in H.
          inversion H; subst.
          rewrite e0 in e2; inversion e2.
      - (* forward pass unsuccessful *)
        inversion FPT.
    Qed.
    
  End Proof.

End Base2.