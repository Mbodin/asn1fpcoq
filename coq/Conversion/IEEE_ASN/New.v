Require Import ZArith PArith.
Require Import ASN1FP.Types.ASNDef ASN1FP.Types.IEEEAux
        ASN1FP.Aux.Roundtrip ASN1FP.Aux.StructTactics ASN1FP.Aux.Aux
        ASN1FP.Aux.Tactics ASN1FP.Aux.Option.

Require Import Flocq.Core.Zaux Flocq.IEEE754.Binary.

Section Conversion.

  Variable prec emax : Z.
  Variable prec_gt_1 : prec > 1.

  Definition IEEE_float := binary_float prec emax.
  Definition valid_IEEE := bounded prec emax.
  Definition valid_IEEE_sumbool := binary_bounded_sumbool prec emax.

  Section Defs.

    Section BER.
  
      (* TODO: recursive definition *)
      Definition normalize_BER_finite (m : positive) (e : Z) : (positive * Z) :=
        let t := N.log2 (((Pos.lxor m (m-1)) + 1) / 2) in
        (Pos.shiftr m t, e + (Z.of_N t)).
  
      Definition make_BER_finite (s : bool) (b : radix) (ff : Z) (m : positive) (e : Z)
        : option BER_float :=
      let '(mx, ex) := normalize_BER_finite m e in
      match valid_BER_sumbool b ff mx ex with
      | left V => Some (BER_finite s b ff mx ex V)
      | right _ => None
      end.
      
      (* TODO: radix, scaling (determine `b` and `ff`) *)
      Definition BER_of_IEEE (scaled : bool) (f : IEEE_float) : option BER_float :=
        let b := radix2 in
        let ff := 0%Z in
        match f with
        | B754_zero _ _ s => Some (BER_zero s)
        | B754_infinity _ _ s => Some (BER_infinity s)
        | B754_nan _ _ _ _ _ => Some (BER_nan)
        | B754_finite _ _ s m e _ => make_BER_finite s b ff m e
        end.
  
    End BER.
  
    Section IEEE.
  
      (* 1 can always be the payload of a NaN *)
      Lemma def_NaN :
        nan_pl prec 1 = true.
      Proof.
        unfold nan_pl. simpl.
        apply Z.ltb_lt, Z.gt_lt, prec_gt_1.
      Qed.
  
      Definition normalize_IEEE_finite := shl_align_fexp prec emax.
  
      Definition make_IEEE_finite (s : bool) (m : positive) (e : Z) : option IEEE_float :=
        let '(mx, ex) := normalize_IEEE_finite m e in
        match (valid_IEEE_sumbool mx ex) with
        | left V => Some (B754_finite _ _ s mx ex V)
        | right _ => None
        end.
  
      (* TODO: radix, scaling (remove `if`, handle conversion properly *)
      Definition IEEE_of_BER (f : BER_float) : option IEEE_float := 
        match f with
        | BER_zero s => Some (B754_zero _ _ s)
        | BER_infinity s => Some (B754_infinity _ _ s)
        | BER_nan => Some (B754_nan _ _ false 1 def_NaN)
        | BER_finite s b f m e _ =>
          if andb (b =? 2) (f =? 0) then
            make_IEEE_finite s m e
          else None
        end.
  
    End IEEE.
  
  End Defs.

  Section Proofs.
  
    (* TODO: meaningful supported formats *)
    Variable supported_format : prec < 1000 /\ emax < 1000.

    Lemma arithmetic_roundtrip {m : positive} {e : Z} (V : valid_IEEE m e = true) :
      uncurry normalize_IEEE_finite (normalize_BER_finite m e) = (m, e).
    Admitted.

    Lemma forward_pass_guarantee (scaled : bool) (f : IEEE_float) :
      is_Some_b (BER_of_IEEE scaled f) = true.
    Admitted.

    Let l1 {A B : Type } (f : A -> option B) : (option A -> option B) :=
      fun x : option A =>
        match x with
        | Some a => f a
        | None => None
        end.
    
    Lemma backward_pass_guarantee (scaled : bool) (f : IEEE_float) :
      is_Some_b ((l1 IEEE_of_BER) (BER_of_IEEE scaled f)) = true.
    Admitted.

    Ltac inv_make_BER_finite :=
      match goal with
      | [ H : make_BER_finite _ _ _ _ _ = Some _ |- _ ] =>
        unfold make_BER_finite in H;
        destruct normalize_BER_finite;
        destruct valid_BER_sumbool;
        inversion H
      end.

    Theorem main_roundtrip (scaled : bool) (f : IEEE_float):
      roundtrip_option
        IEEE_float BER_float IEEE_float
        (BER_of_IEEE scaled)
        IEEE_of_BER
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
            generalize dependent (arithmetic_roundtrip e0); intros.
            rewrite -> NB in H.
            simpl in H.
            rewrite -> NI in H.
            inversion H; clear H; subst.
            unfold float_eqb_nan_t, Bcompare.
            repeat break_match; (repeat try some_inv);
              try compare_nrefl; try reflexivity.

        + (* backward pass unsuccessful *)
          exfalso.
          generalize dependent (backward_pass_guarantee scaled f); intros.
          rewrite -> Heqo in H; simpl in H.
          rewrite -> Heqo0 in H; inversion H.
      - (* forward pass unsuccessful *)
        inversion FPT.
    Qed.
  
  End Proofs.

End Conversion.